extends "res://expedition/tests/solo_peer.gd"

var pending_seq:=0
var sent_at:=0
var next_ping:=0
var samples:=PackedInt32Array()
var miss:=0

func _process(delta:float) -> bool:
	var now:=Time.get_ticks_msec()
	if net!=null and not net.state.is_empty() and pending_seq>0:
		if int(net.state.seq)>=pending_seq:
			samples.append(now-sent_at)
			pending_seq=0
		elif now-sent_at>2000:
			miss+=1
			pending_seq=0
	var before:int=net.seq if net!=null else 0
	var stop:=super._process(delta)
	if stop:
		print("M22_ACK ",JSON.stringify({"ms":Array(samples),"timeouts":miss,"rejoined":dropped}))
		return true
	if net!=null and not net.state.is_empty() and net.receipt.is_empty() and str(net.state.outcome).is_empty():
		if now>=next_ping and pending_seq==0 and net.seq==before:
			var ids:Array=net.state.units.keys().filter(func(k): return net.state.units[k].side==0 and net.state.units[k].hp>0)
			if not ids.is_empty():
				net.command("route",ids,net.state.goals[0])
			next_ping=now+2000
		if net.seq>before and pending_seq==0:
			pending_seq=net.seq
			sent_at=now
	elif due>0:
		pending_seq=0
	return false
