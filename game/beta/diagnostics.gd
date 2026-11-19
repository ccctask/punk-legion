extends Control
signal closed

const Endpoints:=preload("res://client/endpoints.gd")
var build_name: String
var protocol: int
var last: String
var checking := false
var retry_budget := 1

func _ready() -> void:
	build_name=str(ProjectSettings.get_setting("application/config/version","")).strip_edges()
	if build_name.is_empty():build_name="开发调试版"
	protocol=int(ProjectSettings.get_setting("beta/protocol",2))
	%Version.text="版本 %s　·　档案协议 %d" % [build_name,protocol]
	%About.text="创建测试账号后，可建基地、拼装机器人、联机探索。\n订单均为模拟交易。\n账号、机体、库存、外观和累计战绩保存在这台内测服务器。\n测试记录用于核对资产与排查故障。"
	var entries:=PackedStringArray()
	for service: String in Endpoints.PORTS:
		var addr:=Endpoints.transport(service)
		entries.append("%s %s" % [Endpoints.LABELS[service],str(addr.port) if not addr.is_empty() else "缺配置"])
	%Network.text="档案 HTTP/TCP　%s\n实时战斗 UDP　%s" % [Endpoints.profile_url()," · ".join(entries)]
	%Contact.text="反馈给邀请你内测的项目负责人：附版本、场次和复现步骤。请勿填写登录密码。"
	%Play.text="返回基地"
	%Play.pressed.connect(func():closed.emit())
	%Retry.pressed.connect(_check)
	%Feedback.pressed.connect(func():
		DisplayServer.clipboard_set("PunkLegion %s / 协议 %d / %s / %s\n复现步骤：" % [build_name,protocol,OS.get_name(),last])
		%Contact.text="已复制，可粘贴到邀请你参加本次内测的项目会话。")
	$HTTP.request_completed.connect(_result)
	_check()

func _check() -> void:
	if checking:
		return
	checking=true
	%Play.disabled=false
	%Retry.disabled=true
	var endpoint:=Endpoints.profile_url()
	if endpoint.is_empty():
		_show("档案地址缺失，请向内测负责人领取配置完整的安装包。")
		return
	%Status.text="正在检查档案服务与版本…"
	if $HTTP.request(endpoint+"/v1/beta/compat",Endpoints.headers())!=OK:
		_show("无法连接档案服务，请检查本机内测容器后重试。")

func _show(note: String) -> void:
	checking=false
	last=note
	%Status.text=note
	%Retry.disabled=false

func _result(result: int, code: int, _headers: PackedStringArray, raw: PackedByteArray) -> void:
	if code==426:
		_show("当前协议已过期，请向负责人领取新版 APK 并覆盖安装。")
		return
	var body: Variant=JSON.parse_string(raw.get_string_from_utf8()) if result==HTTPRequest.RESULT_SUCCESS and code==200 else null
	if not body is Dictionary or not body.has("protocol_min") or not body.has("protocol_max"):
		if retry_budget > 0:
			retry_budget -= 1
			await get_tree().create_timer(0.7).timeout
			checking=false
			_check()
			return
		_show("未连接到内测档案。模拟器使用 10.0.2.2 访问宿主，请确认内测容器正在运行后重试。")
		return
	if protocol<int(body.protocol_min) or protocol>int(body.protocol_max):
		_show("服务器与此版本不兼容，请领取匹配的新版安装包。")
		return
	if "base_first_naming" not in body.get("capabilities",[]):
		_show("档案服务需更新，当前未提供基地内命名。")
		return
	_show("基地档案及协议已就绪。")
	%Play.disabled=false

func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_RESUMED and is_node_ready():
		_check()
