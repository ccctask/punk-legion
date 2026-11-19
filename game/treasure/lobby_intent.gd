extends RefCounted
# M24-only value policy. The page owns pending state and HTTP/lifecycle.

func _whole(value:Variant) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value)>=0 and float(value)==floor(float(value))

func _ids(value:Variant) -> bool:
	if not value is Array:return false
	var found:={}
	for id:Variant in value:
		if not id is String or id.is_empty() or found.has(id):return false
		found[id]=true
	return true

func _sorted(ids:Array) -> Array:
	var result:=ids.duplicate()
	result.sort()
	return result

func _receipt(value:Variant) -> bool:
	if value==null:return true
	if not value is Dictionary:return false
	if not value.get("cargo") is Array or not value.get("cargo_changes") is Dictionary or not value.get("outcome") is String:return false
	for amount:Variant in value.cargo_changes.values():
		if not _whole(amount):return false
	var reward:Variant=value.get("participation")
	var salvage:Variant=value.get("salvage")
	if not reward is Dictionary or not salvage is Dictionary:return false
	if not reward.get("eligible") is bool or not reward.get("already_claimed") is bool or not _whole(reward.get("credited")):return false
	if not salvage.get("status") is String or not _whole(salvage.get("misses")):return false
	return salvage.status!="awarded" or salvage.get("part_id") is String

func valid_view(value:Variant) -> bool:
	if not value is Dictionary:return false
	var event:Variant=value.get("event")
	if not event is Dictionary or not event.get("id") is String or event.id.is_empty() or not event.get("name") is String or not event.get("active") is bool:return false
	if not value.get("played") is bool or not value.get("roster") is Array or not value.has("group") or not value.has("last") or not _receipt(value.last):return false
	var seen:={}
	for row:Variant in value.roster:
		if not row is Dictionary or not row.get("id") is String or row.id.is_empty() or seen.has(row.id) or not row.get("name") is String or not _whole(row.get("points")):return false
		seen[row.id]=true
	var salvage:Variant=value.get("salvage")
	if not salvage is Dictionary:return false
	for key:String in ["day","misses","chance_percent","part_space"]:
		if not _whole(salvage.get(key)):return false
	if not salvage.get("available") is bool or not salvage.get("guaranteed") is bool:return false
	var group:Variant=value.group
	if group!=null:
		if not group is Dictionary or not group.get("id") is String or group.id.is_empty() or group.get("phase") not in ["forming","queued","matched"]:return false
		if not _whole(group.get("revision")) or not _whole(group.get("point_cap")) or not _whole(group.get("unit_cap")) or group.point_cap<=0 or group.unit_cap<=0:return false
		if not group.get("confirmed") is bool or not group.get("members") is Array or group.members.size() not in [1,2]:return false
		var mine:=0
		var names:={}
		for member:Variant in group.members:
			if not member is Dictionary or not member.get("name") is String or member.name.is_empty() or names.has(member.name):return false
			if not member.get("mine") is bool or not member.get("confirmed") is bool or not _ids(member.get("robots")) or not _whole(member.get("points")) or not member.get("names") is Dictionary:return false
			names[member.name]=true
			mine+=int(member.mine)
		if mine!=1:return false
	if value.has("admission"):
		var admission:Variant=value.admission
		if not admission is Dictionary or not admission.get("id") is String or admission.id.is_empty() or not admission.get("secret") is String or admission.secret.is_empty():return false
	return true

func _mine(group:Dictionary) -> Dictionary:
	for member:Dictionary in group.members:
		if member.mine:return member
	return {}

func _members(group:Dictionary, rosters:bool) -> Array:
	var result:=[]
	for member:Dictionary in group.members:
		var row:={"name":member.name,"mine":member.mine}
		if rosters:
			row.robots=_sorted(member.robots)
			row.points=int(member.points)
		result.append(row)
	result.sort_custom(func(a:Dictionary,b:Dictionary):return str(a.name)<str(b.name))
	return result

func _selection(view:Dictionary, selected:Array, group:Dictionary) -> Dictionary:
	if not _ids(selected) or selected.is_empty() or selected.size()>int(group.unit_cap):return {}
	var available:={}
	for row:Dictionary in view.roster:available[row.id]=int(row.points)
	var points:={}
	var total:=0
	for id:String in selected:
		if not available.has(id):return {}
		points[id]=available[id]
		total+=int(available[id])
	if total>int(group.point_cap):return {}
	return {"ids":_sorted(selected),"points":points}

func capture(action:String, view:Dictionary, selected:Array, friend_name:String) -> Dictionary:
	if not valid_view(view) or view.has("admission"):return {}
	var group:Dictionary=view.group if view.group is Dictionary else {}
	var body:={}
	var context:={}
	var kind:=action
	match action:
		"create":
			if not group.is_empty() or not view.event.active or view.played:return {}
			body={"event":view.event.id,"friend":friend_name.strip_edges()}
			context=body.duplicate(true)
		"cancel":
			if group.is_empty() or group.phase not in ["forming","queued"]:return {}
			body={"group":group.id}
			context=body.duplicate(true)
		"select","confirm":
			if group.is_empty() or group.phase!="forming":return {}
			var mine:=_mine(group)
			var selection:=_selection(view,selected,group)
			if selection.is_empty():return {}
			context={"group":group.id,"selection":selection}
			if action=="select":
				if group.members.size()!=2:return {}
				body={"group":group.id,"revision":int(group.revision),"robots":selected.duplicate()}
				context.revision=int(group.revision)
				context.members=_members(group,false)
			else:
				if mine.confirmed:return {}
				body={"group":group.id,"risk":true}
				if group.members.size()==1:
					kind="confirm_solo"
					body.robots=selected.duplicate()
					context.members=_members(group,false)
				else:
					if _sorted(selected)!=_sorted(mine.robots):return {}
					for member:Dictionary in group.members:
						if member.robots.is_empty():return {}
					kind="confirm_duo"
					body.revision=int(group.revision)
					context.revision=int(group.revision)
					context.members=_members(group,true)
		_:
			return {}
	return {"kind":kind,"suffix":"/"+action,"body":body.duplicate(true),"context":context.duplicate(true)}

func revalidate(intent:Dictionary, view:Dictionary, selected:Array, friend_name:String) -> Dictionary:
	var discard:={"decision":"discard","reason":"队伍或阵容已变化，请核对后重新确认。"}
	if not valid_view(view) or not intent.get("kind") is String or not intent.get("suffix") is String or not intent.get("body") is Dictionary or not intent.get("context") is Dictionary:return discard
	if view.has("admission"):return {"decision":"observed","reason":"入场状态已更新。"}
	var kind:String=intent.kind
	var group:Dictionary=view.group if view.group is Dictionary else {}
	if kind=="create" and not group.is_empty():return {"decision":"observed","reason":"当前队伍已刷新，请核对。"}
	if kind=="cancel" and group.is_empty():return {"decision":"observed","reason":"当前没有待处理队伍。"}
	if kind in ["confirm_solo","confirm_duo"] and not group.is_empty() and group.id==intent.body.get("group"):
		if _mine(group).confirmed or group.phase=="queued":return {"decision":"observed","reason":"当前确认与排队状态已刷新。"}
	var action:="confirm" if kind in ["confirm_solo","confirm_duo"] else kind
	var current:=capture(action,view,selected,friend_name)
	if current.is_empty() or current.kind!=kind or current.context!=intent.context:return discard
	return {"decision":"send","suffix":intent.suffix,"body":intent.body.duplicate(true)}
