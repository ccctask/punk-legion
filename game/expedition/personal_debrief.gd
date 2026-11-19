extends PanelContainer

signal again
signal leave

const RESOURCES := {"structure":"结构材料","components":"通用零件","energy":"能源"}
const ACTIVITIES := {"old_armory":"旧武器库","solo":"锈轨独行","party":"锈轨合作","pump_ruin":"泵站遗迹","factory_escort":"封闭工厂"}
const REASONS := {"win":"成功撤离","defeat":"战败","retreat":"主动撤退","expired":"任务超时","not_deployed":"未到场"}

const CAUSES := {"factory_gate":"检修车已抵达厂门","extracted":"成功撤离","squad_disabled":"参战机体全部失能","time_limit":"达到任务时限","voluntary_retreat":"主动撤退","session_expired":"场次到期","not_deployed":"未到场"}

static func assembly_exit(receipt:Dictionary) -> String:
	if receipt.get("debrief",{}).get("participated",true):
		return ""
	return {"retreat":"集结时主动退出","expired":"集结到期未出战"}.get(receipt.get("outcome",""),"")

func _ready() -> void:
	%Close.pressed.connect(hide)
	%Again.pressed.connect(func(): again.emit())
	%Leave.pressed.connect(func(): leave.emit())
	%Toggle.toggled.connect(func(expanded:bool):
		%Units.visible=expanded
		%Toggle.text=("收起" if expanded else "展开")+"机体明细 · %d 台" % int(%Toggle.get_meta("count")))

func present(receipt:Dictionary,live:bool,can_continue:bool,finish_text:String,rewards:String) -> void:
	var r:Dictionary=receipt.debrief
	%Rewards.text=rewards
	%Rewards.visible=not rewards.is_empty()
	var reason:=assembly_exit(receipt)
	if reason.is_empty():
		reason=CAUSES.get(r.get("cause",""),REASONS[r.reason])
	%Title.text="%s · %s" % [ACTIVITIES[r.activity],reason]
	%Round.text="个人战报  #%s  ·  %d 秒" % [str(r.mission).left(8),int(receipt.seconds)]
	for key:String in RESOURCES:
		var amount:Dictionary=r.resources[key]
		%Ledger.get_node(key).text="%d" % int(amount.credited)
		%Ledger.get_node(key+"Cost").text="%d" % int(amount.cost)
		%Ledger.get_node(key+"Net").text="%+d" % int(amount.net) if int(amount.net)!=0 else "0"
	%Voucher.text="出发另使用救援凭证 ×%d" % int(r.vouchers_used)
	%Voucher.visible=int(r.vouchers_used)>0
	var price:Dictionary=r.repair_total
	%Repairs.text="战后维修报价 · 结构材料 %d / 通用零件 %d · 尚未支付" % [int(price.structure),int(price.components)]
	for node in %Units.get_children():
		%Units.remove_child(node)
		node.queue_free()
	var short_ids:Dictionary={}
	for robot:Dictionary in r.robots:
		var prefix:=str(robot.id).left(8)
		short_ids[prefix]=int(short_ids.get(prefix,0))+1
	for robot:Dictionary in r.robots:
		var unit_label:=str(robot.id).left(8)
		if short_ids[unit_label]>1: unit_label=str(robot.id)
		var line:=Label.new()
		line.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT
		line.set_meta("robot",robot.id)
		line.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		var state:String="待维修 · 结构 %d / 零件 %d" % [int(robot.repair_cost.structure),int(robot.repair_cost.components)] if robot.damaged else "完好"
		line.text="%s  #%s\n击杀 %d  ·  实际施修 %s  ·  %s" % [robot.name,unit_label,int(robot.kills),str(float(robot.repair_output)).trim_suffix(".0"),state]
		%Units.add_child(line)
	%Toggle.set_meta("count",r.robots.size())
	%Toggle.set_pressed_no_signal(false)
	%Toggle.text="展开机体明细 · %d 台" % r.robots.size()
	%Toggle.visible=not r.robots.is_empty()
	%Units.hide()
	%Absent.visible=not r.participated
	if %Absent.visible:
		%Absent.text=("你在集结期间选择了退出。" if receipt.outcome=="retreat" else "集结截止时，你的席位未能投入战斗。")+"本席机体不计参战场次，出发支出已记录。"
	%Again.visible=live and can_continue
	%Leave.visible=live
	%Leave.text=finish_text
	%Close.text="收起战报" if live else "返回准备页"
	%Scroll.scroll_vertical=0
	update_actions("",false)
	show()

func update_actions(message:String,waiting:bool) -> void:
	%Notice.text=message
	%Notice.visible=not message.is_empty()
	%Again.disabled=waiting
	%Leave.disabled=waiting
