extends "res://expedition/expedition.gd"

func _ready() -> void:
	super()
	$HUD/Lobby/Scroll/Body/Title.text="旧武器库"
	%Rules.text="独行探索 · 正面清除守卫，或绕到侧闸断电再进箱区。靠近武器箱回收，再把箱子运到撤离门。主动撤退会放弃战利品。"
	%PartyMode.hide()
	%QuickSalvage.hide()
	%Claim.text="领取保留的烟囱炮臂"

func _same_outing() -> bool:
	return active.get("location","")=="old_armory"

func _request(path:String,data:Dictionary) -> void:
	if path=="/v1/expedition/start":
		data=data.merged({"location":"old_armory"})
	if path=="/v1/expedition/claim-first":
		path="/v1/expedition/claim-armory"
	super(path,data)

func _update_solo_quote() -> void:
	super()
	if not lobby.get("old_armory",{}).get("unlocked",false):
		%Start.disabled=true

func _solo_lobby(data:Dictionary) -> void:
	lobby=data.expedition
	active=lobby.active if lobby.active is Dictionary else {}
	var armory:Dictionary=lobby.old_armory
	var last:Dictionary=armory.last if armory.last is Dictionary else {}
	_set_previous(last)
	%Claim.visible=armory.pending_part
	var prize:="首胜奖励 · 烟囱炮臂"
	if armory.pending_part:
		prize="烟囱炮臂已保留 · 在机库腾出部件仓位后回此领取"
	elif armory.first_cleared:
		prize="首胜奖励已发放 · 烟囱炮臂"
	%Pity.text=prize+"\n"+("当日首胜可获 1 通用零件" if armory.daily_available else "当日通用零件额度已用")
	_refresh_solo_squad()
	%LobbyStatus.text=_summary(last) if not last.is_empty() else "选择待命机体。"
	if not armory.unlocked:
		%Start.disabled=true
		%LobbyStatus.text="完成封闭工厂护送、开放南地后可出击。"
	var operation:String=data.get("receipt",{}).get("operation","")
	if operation=="expedition_start" and _same_outing():
		_join()
	elif operation=="armory_claim":
		%LobbyStatus.text="烟囱炮臂已存入机库。"

func _swap_goal() -> void:
	goal="armory_cache" if goal=="armory_breaker" else "armory_breaker"
	_send("route",goal)
	_objectives(net.state)

func _objectives(state:Dictionary) -> void:
	var carrying:=int(state.stage)>0
	var can_divert:bool="armory_breaker" in state.goals
	if carrying:goal="armory_exit"
	elif goal!="armory_breaker" or not can_divert:goal="armory_cache"
	var at_switch:=goal=="armory_breaker"
	var alive:=int(state.armory.guards)
	%Route.text="前往撤离门" if carrying else "前往武器箱"
	%Collect.text="携箱撤离" if carrying else "回收武器箱"
	%Collect.disabled=(not carrying and alive>0) or not state.outcome.is_empty()
	if at_switch:
		%Route.text="前往断电闸"
		%Collect.text="拉下电闸"
		%Collect.disabled=not state.outcome.is_empty()
	%Alt.visible=can_divert
	%Alt.text="改走箱区" if at_switch else "绕行断电闸"
	%Repair.text="维修 ×%d" % int(state.repairs)
	%Repair.disabled=state.repairs==0
	%Goal.text="旧武器库 · "+("携箱撤离" if carrying else ("清除守卫 · 剩余 %d 台" % alive if alive else "回收武器箱"))
	if state.armory.breaker:%Goal.text+=" · 已断电"
	%Hint.text=net.message if not net.message.is_empty() else ("靠近撤离门后点「携箱撤离」。" if carrying else "清完守卫，派机体靠近武器箱，点「回收武器箱」。")

	if at_switch:%Hint.text="靠近侧闸后点「拉下电闸」，再前往箱区。"

	var rejection: String = net.movement_feedback()
	if not rejection.is_empty():
		%Hint.text = rejection
	if not str(state.outcome).is_empty():
		%Hint.text = "正在核对回收物与战损…"

func _reward_summary(r:Dictionary) -> String:
	if r.get("outcome","")!="win":return ""
	var lines:=PackedStringArray()
	if r.get("part") is Dictionary:
		lines.append("烟囱炮臂 #%s 已入库，可在机库工具槽实装。" % str(r.part.id).left(8))
	elif r.get("pending_part",false):
		lines.append("部件仓已满，首胜炮臂已保留。腾出仓位后回出击页领取。")
	lines.append("通用零件实际入库 %d" % int(r.get("changes",{}).get("components",0)))
	return "\n".join(lines)
