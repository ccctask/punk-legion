extends Node

# Derived pose history only. The host owns context and calls sample explicitly.
var enabled := false
var _delay := 0.0
var _max_gap := 0.0
var _capacity := 0
var _guard := Callable()
var _context: StringName = &""
var _samples: Array[Dictionary] = []
var _clock_started := false
var _anchor_time := 0.0
var _anchor_usec := 0
var _cursor := 0.0
var _last_now := 0
var _last_pose := {}
var _proof_a := -1.0
var _proof_b := -1.0
var _proof_clear := false
var _guard_checks := 0
var _snaps := 0
var _resets := 0
var _reset_reason: StringName = &"initial"

func configure(delay_seconds: float, max_gap_seconds: float, capacity: int, segment_guard: Callable) -> bool:
	clear()
	if not is_finite(delay_seconds) or not is_finite(max_gap_seconds) or delay_seconds<=0 or max_gap_seconds<=delay_seconds or capacity<2 or capacity>64 or not segment_guard.is_valid():
		return false
	_delay=delay_seconds
	_max_gap=max_gap_seconds
	_capacity=capacity
	_guard=segment_guard
	enabled=true
	return true

func clear() -> void:
	enabled=false
	_samples.clear()
	_context=&""
	_guard=Callable()
	_clock_started=false
	_last_pose={}
	_last_now=0
	_proof_a=-1.0
	_proof_b=-1.0
	_guard_checks=0
	_snaps=0
	_resets=0
	_reset_reason=&"disabled"

func _valid(server_time: float, pos: Vector2, heading: Vector2, arrival_usec: int) -> bool:
	return enabled and is_finite(server_time) and server_time>=0 and pos.is_finite() and heading.is_finite() and arrival_usec>=0

func reset(context: StringName, server_time: float, pos: Vector2, heading: Vector2, walking: bool, arrival_usec: int) -> void:
	if context==&"" or not _valid(server_time,pos,heading,arrival_usec):return
	_context=context
	_install(server_time,pos,heading,walking,arrival_usec,&"context")

func _install(server_time: float, pos: Vector2, heading: Vector2, walking: bool, arrival_usec: int, reason: StringName) -> void:
	_samples=[{"time":server_time,"pos":pos,"heading":heading,"walking":walking,"arrival":arrival_usec}]
	_cursor=server_time
	_clock_started=false
	_last_now=arrival_usec
	_last_pose={"pos":pos,"heading":heading,"walking":walking,"sampled_time":server_time,"kind":&"hold","reason":reason}
	_proof_a=-1.0
	_proof_b=-1.0
	_reset_reason=reason
	_resets+=1

func push(context: StringName, server_time: float, pos: Vector2, heading: Vector2, walking: bool, arrival_usec: int) -> bool:
	if context!=_context or _samples.is_empty() or not _valid(server_time,pos,heading,arrival_usec):return false
	var latest: Dictionary=_samples[-1]
	if server_time<float(latest.time) or arrival_usec<int(latest.arrival):return false
	if server_time==float(latest.time):
		if pos==latest.pos and heading==latest.heading and walking==latest.walking:return false
		_install(server_time,pos,heading,walking,arrival_usec,&"same_time_correction")
		return true
	if server_time-float(latest.time)>_max_gap or float(arrival_usec-int(latest.arrival))/1000000.0>_max_gap:
		_install(server_time,pos,heading,walking,arrival_usec,&"receive_gap")
		return true
	while _samples.size()>=_capacity and _samples.size()>1 and float(_samples[1].time)<=_cursor:
		_samples.pop_front()
	if _samples.size()>=_capacity:
		_install(server_time,pos,heading,walking,arrival_usec,&"capacity")
		return true
	_samples.append({"time":server_time,"pos":pos,"heading":heading,"walking":walking,"arrival":arrival_usec})
	return true

func _pose(row: Dictionary, kind: StringName, reason: StringName) -> Dictionary:
	_last_pose={"pos":row.pos,"heading":row.heading,"walking":row.walking,"sampled_time":_cursor,"kind":kind,"reason":reason}
	return _last_pose.duplicate()

func _snap(now_usec: int, reason: StringName) -> Dictionary:
	var latest: Dictionary=_samples[-1].duplicate()
	_install(latest.time,latest.pos,latest.heading,latest.walking,int(latest.arrival),reason)
	_clock_started=true
	_anchor_time=float(latest.time)
	_anchor_usec=now_usec
	_last_now=now_usec
	_snaps+=1
	return _pose(latest,&"authority_snap",reason)

func _check(start: Vector2, finish: Vector2) -> bool:
	_guard_checks+=1
	return _guard.is_valid() and bool(_guard.call(start,finish))

func sample(now_usec: int) -> Dictionary:
	if not enabled or _samples.is_empty():return {}
	if now_usec<_last_now:return _last_pose.duplicate()
	var latest: Dictionary=_samples[-1]
	if float(now_usec-int(latest.arrival))/1000000.0>_max_gap:
		_last_now=now_usec
		var stopped: Dictionary=_last_pose.duplicate()
		stopped.walking=false
		return _pose(stopped,&"hold",&"receive_starved")
	if not _clock_started:
		_clock_started=true
		_anchor_time=float(latest.time)
		_anchor_usec=now_usec
	if float(now_usec-_last_now)/1000000.0>_max_gap or float(latest.time)-_cursor>_max_gap:
		return _snap(now_usec,&"display_gap")
	_last_now=now_usec
	var desired:=_anchor_time+float(now_usec-_anchor_usec)/1000000.0-_delay
	_cursor=maxf(_cursor,minf(desired,float(latest.time)))
	while _samples.size()>1 and float(_samples[1].time)<=_cursor:
		_samples.pop_front()
	var a: Dictionary=_samples[0]
	if _samples.size()==1:
		if not _last_pose.is_empty() and a.pos!=_last_pose.pos:
			if not (_proof_clear and _proof_b==float(a.time)) and not _check(_last_pose.pos,a.pos):return _snap(now_usec,&"unsafe_hold_transition")
			return _pose(a,&"interpolated",&"endpoint")
		return _pose(a,&"hold",&"latest")
	var b: Dictionary=_samples[1]
	var span:=float(b.time)-float(a.time)
	if span<=0:return _snap(now_usec,&"invalid_span")
	var alpha:=clampf((_cursor-float(a.time))/span,0,1)
	var pos: Vector2=a.pos.lerp(b.pos,alpha)
	var moved: bool=not _last_pose.is_empty() and pos!=_last_pose.pos
	var new_bracket:=_proof_a!=float(a.time) or _proof_b!=float(b.time)
	if new_bracket:
		_proof_a=float(a.time)
		_proof_b=float(b.time)
		_proof_clear=_check(a.pos,b.pos)
	if not _proof_clear:return _snap(now_usec,&"unsafe_bracket")
	if moved and new_bracket and not _check(_last_pose.pos,pos):return _snap(now_usec,&"unsafe_transition")
	var heading: Vector2=b.heading if a.heading.is_zero_approx() else a.heading
	if not a.heading.is_zero_approx() and not b.heading.is_zero_approx():
		heading=Vector2.from_angle(lerp_angle(a.heading.angle(),b.heading.angle(),alpha))
	var moving: bool=a.pos.distance_squared_to(b.pos)>0.00000001 and (bool(a.walking) or bool(b.walking))
	return _pose({"pos":pos,"heading":heading,"walking":moving},&"interpolated" if moved else &"hold",&"timeline")

func observation() -> Dictionary:
	return {"enabled":enabled,"context":String(_context),"queue_size":_samples.size(),"guard_checks":_guard_checks,
		"snaps":_snaps,"resets":_resets,"kind":_last_pose.get("kind",&"disabled"),
		"reason":_last_pose.get("reason",&"disabled"),"reset_reason":_reset_reason,"sampled_time":_last_pose.get("sampled_time",0.0)}
