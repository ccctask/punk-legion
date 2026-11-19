extends VBoxContainer
const Endpoints:=preload("res://client/endpoints.gd")

signal chosen(action:String,robot:String)
const NAMES := {"structure":"结构","components":"零件","energy":"能源"}
var continuing := false
var last_guide := {}
var current := ""
var destination := ""
var damaged := ""
var endpoint := ""
var token := ""
var summary := {}
var loaded := false
var reading := false
var refresh_after_read := false

func _ready() -> void:
	$Fold.pressed.connect(func(): $Content.visible=not $Content.visible)
	$Content/Go.pressed.connect(func():
		if not loaded:
			refresh()
		elif destination == "continue":
			continuing = true
			apply_guide(last_guide)
		else:
			chosen.emit(destination,damaged))
	$Content/Solo.pressed.connect(func(): chosen.emit("solo",""))
	$Content/Recovery.pressed.connect(func(): chosen.emit("repair",damaged))
	$Content/Party.pressed.connect(func(): chosen.emit("party",""))
	$Content/Return.pressed.connect(func(): $Content/Statement.visible=not $Content/Statement.visible)
	$HTTP.request_completed.connect(_response)

func refresh(after_claim := false) -> void:
	if endpoint.is_empty() or token.is_empty():
		return
	if reading:
		refresh_after_read = refresh_after_read or after_claim
		return
	reading = true
	$Content/Go.disabled=true
	if not loaded:$Content/Next.text="正在读取机组进度…"
	if not loaded:$Content/Daily.text="正在读取今日目标…"
	var err:Error=$HTTP.request(endpoint+"/v1/onboarding",Endpoints.headers(token))
	if err!=OK:
		reading = false
		print("BASE_READ_FAILED op=guide err=",err)
		_failed()

func _response(result:int,status:int,_headers:PackedStringArray,body:PackedByteArray) -> void:
	reading = false
	if refresh_after_read:
		refresh_after_read = false
		refresh()
		return
	var data:Variant=JSON.parse_string(body.get_string_from_utf8()) if not body.is_empty() else null
	if result!=HTTPRequest.RESULT_SUCCESS or status!=200 or not data is Dictionary or not data.get("guide") is Dictionary:
		print("BASE_READ_FAILED op=guide result=",result," status=",status)
		_failed()
		return
	apply_guide(data.guide)

func _failed() -> void:
	loaded=false
	$Content/Recovery.hide()
	$Content/Next.text="指引未更新，请重试读取。"
	$Content/Daily.text="今日目标未更新。"
	$Content/Go.text="重试读取"
	$Content/Go.disabled=false

func apply_guide(guide:Dictionary) -> void:
	loaded=true
	$Content/Go.disabled=false
	damaged=str(guide.damaged)
	last_guide=guide
	var facts:Dictionary=guide.facts
	var active:String=guide.active_mode
	var step:Array
	if not facts.name:
		step=["name","给第一台机体起个名字，之后可查看它的累计战绩。","为机体命名"]
	elif not active.is_empty():
		step=[active,"你的探索还在进行，可回到原场继续指挥。","返回进行中的探索"]
	elif not facts.reward:
		if guide.ready_count==0 and not damaged.is_empty():
			step=["repair","机体受损或正在维修。到检修工位查看，再派它出战。","查看检修工位"]
		elif guide.entry_source=="unavailable":
			step=["repair","出征能源已用尽。可查看基础救援资格，或领取基地能源。","查看检修与救援"]
		else:
			step=["solo","带现有机体去锈轨回收场，点「前往废轨堆」下达指令。清除守卫、采集，再从出口撤离。","进入锈轨回收场"]
	elif not continuing:
		step=["continue","锈轨首胜已完成。可以在这里收工，也可以继续改装与造机。","继续改装／组建小队"]
	elif guide.fit_route=="claim_drill":
		step=["solo","首胜钻头待领。腾出一个背包格，在回收场入口领取。","领取首胜钻头"]
	elif not facts.fit:
		if guide.fit_route=="install_drill":
			step=["fit","在机库选择武器或工具接口，用背包中的钻头替换气炮。","去机库安装钻头"]
		else:
			step=["fit","在机库选一个接口，安装背包中的适配部件。","选择实装部件"]
	elif not facts.build:
		step=["build","到工坊选好底盘和部件，保存方案，核对用料后制造。任选一台即可。","去工坊制造机体"]
	elif guide.ready_count>=3:
		step=["solo","有三台待命机体。进入出征列表，手动勾选第三台，核对指挥点再出发。","打开出征列表"]
	elif guide.ready_count==0 and not damaged.is_empty() or guide.entry_source=="unavailable":
		step=["repair","到检修工位查看机况、维修和基础救援资格。","查看检修与救援"]
	else:
		step=["solo","改装和制造均已完成。可以带待命机体回收，或回基地经营。","进入锈轨回收场"]
	current=step[0]
	$Content/Recovery.visible=current!="repair" and (not damaged.is_empty() or guide.entry_source=="unavailable")
	destination=current
	$Content/Next.text=step[1]
	$Content/Go.text=step[2]
	var daily:Dictionary=guide.get("daily",{})
	if daily.get("complete",false):
		var credited:=PackedStringArray()
		for resource:String in NAMES:
			var amount:=int(daily.changes.get(resource,0))
			if amount>0:
				credited.append("%s +%d" % [NAMES[resource],amount])
		var source:String={"production":"基地生产","party":"组队探索","solo":"单人探索"}.get(daily.mode,"物资回收")
		var actual:="入库 " + "、".join(credited) if not credited.is_empty() else "仓库已满，入库 0"
		$Content/Daily.text="今日目标 1/1 · 可收工\n%s\n%s\n收据 #%s" % [source,actual,str(daily.receipt).left(8)]
	else:
		$Content/Daily.text="今日目标 0/1 · 在「生产与研究」领取产出入库，或独行、组队带回采集物。每天 00:00 UTC 刷新。"
	summary=guide.summary
	$Content/Statement.text=_statement()

func _statement() -> String:
	if summary.is_empty():
		return "尚无离开 15 分钟以上的经营记录。下次回归后可查看物资、维修和袭击明细。"
	var rows:=PackedStringArray()
	rows.append("%s 至 %s（UTC）" % [Time.get_datetime_string_from_unix_time(int(summary.start),true),Time.get_datetime_string_from_unix_time(int(summary.end),true)])
	rows.append("离开 %.1f 小时，产线最多计 %.0f 小时。" % [(summary.end-summary.start)/3600.0,summary.cap_seconds/3600.0])
	for key:String in NAMES:
		var p:Dictionary=summary.production[key]
		var accrued:="" if p.get("before")==null else "（本次 %+d）" % (int(p.pending)-int(p.before))
		rows.append("%s 库存 %d → %d，可领 %d%s，暂存上限 %d。" % [NAMES[key],summary.before[key],summary.after[key],p.pending,accrued,mini(int(p.free),int(p.capacity))])
	for repair:Dictionary in summary.repairs:
		rows.append("%s 已于 %s（UTC）修复。" % [repair.name,Time.get_datetime_string_from_unix_time(int(repair.at),true)])
	for receipt:Dictionary in summary.ledger:
		var items:=PackedStringArray()
		for key:String in receipt.changes:
			items.append("%s %+d" % [NAMES.get(key,key),int(receipt.changes[key])])
		if receipt.operation=="wild_raid":
			rows.append("野生袭击 %s：%s，战报 %s。" % ["守住" if receipt.outcome=="win" else "失守","、".join(items) if not items.is_empty() else "物资无损",str(receipt.raid).left(8)])
		elif not items.is_empty():
			rows.append("收据 %s：%s。" % [str(receipt.id).left(8),"、".join(items)])
	rows.append("可领取的产出保存在产线。到「生产与研究」领取。")
	return "\n".join(rows)

