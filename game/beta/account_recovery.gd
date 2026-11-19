extends VBoxContainer

signal closed(account_name: String, notice: String)
signal session_expired

const Endpoints := preload("res://client/endpoints.gd")
var endpoint := ""
var token := ""
var issuing := false
var busy := false
var concealed := false

func _ready() -> void:
	%Submit.pressed.connect(_submit)
	%Done.pressed.connect(_close)
	%NewPassword.text_submitted.connect(func(_value: String): _submit())
	%CurrentPassword.text_submitted.connect(func(_value: String): _submit())
	$HTTP.request_completed.connect(_reply)

func open(url: String, session_token: String, account_name: String) -> void:
	endpoint=url
	token=session_token
	issuing=not token.is_empty()
	concealed=false
	%RecoveryAccount.text=account_name
	%RecoveryAccount.visible=not issuing
	%RecoveryCode.visible=not issuing
	%NewPassword.visible=not issuing
	%CurrentPassword.visible=issuing
	%Output.text=""
	%Output.hide()
	%Explanation.text=("输入当前密码即可生成恢复码。生成后，之前保存的恢复码将立即失效。请准备好纸笔或离线保管位置。"
		if issuing else "填写原指挥官账号、保存的恢复码和新密码。成功后用新密码登录原基地。")
	%Submit.text="生成并替换恢复码" if issuing else "重设密码"
	%Done.text="返回账号菜单" if issuing else "返回登录"
	%Submit.show()
	%Inputs.show()
	show()

func _clear_fields() -> void:
	for field: LineEdit in [%CurrentPassword,%RecoveryCode,%NewPassword]:
		field.clear()
	%Output.text=""
	%Output.hide()

func _close(account_name := "", notice := "") -> void:
	if busy:return
	_clear_fields()
	%RecoveryAccount.clear()
	token=""
	concealed=false
	hide()
	closed.emit(account_name,notice)

func _submit() -> void:
	if busy or not visible or not %Submit.visible:return
	var data: Dictionary
	if issuing:
		if %CurrentPassword.text.is_empty():
			%Explanation.text="请先输入当前账号的密码。"
			return
		data={"password":%CurrentPassword.text}
	else:
		if %RecoveryAccount.text.strip_edges().is_empty() or %RecoveryCode.text.strip_edges().is_empty():
			%Explanation.text="请填写账号和已保存的恢复码。"
			return
		if %NewPassword.text.length()<8:
			%Explanation.text="新密码需要 8–128 个字符。"
			return
		data={"name":%RecoveryAccount.text.strip_edges(),"code":%RecoveryCode.text.strip_edges(),"new_password":%NewPassword.text}
	get_viewport().gui_release_focus()
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):DisplayServer.virtual_keyboard_hide()
	busy=true
	%Done.disabled=true
	%Submit.disabled=true
	%Inputs.hide()
	concealed=false
	var path: String="/v1/account/recovery-code" if issuing else "/v1/account/recover"
	%Explanation.text="正在核对账号…"
	var err: Error=$HTTP.request(endpoint+path,Endpoints.headers(token),HTTPClient.METHOD_POST,JSON.stringify(data))
	_clear_fields()
	if err!=OK:_reply(HTTPRequest.RESULT_CANT_CONNECT,0,PackedStringArray(),PackedByteArray())

func _reply(result: int, status: int, _headers: PackedStringArray, raw: PackedByteArray) -> void:
	if not busy:return
	busy=false
	%Done.disabled=false
	%Submit.disabled=false
	%Inputs.show()
	var parsed:=JSON.new()
	var valid:=result==HTTPRequest.RESULT_SUCCESS and parsed.parse(raw.get_string_from_utf8())==OK and parsed.data is Dictionary
	if not valid or status>=500:
		if issuing:
			%Explanation.text="未能确认本次生成结果。请重新输入当前密码生成一枚新码，保存最新的一枚。"
		else:
			_close(%RecoveryAccount.text.strip_edges(),"重设结果尚未确认，请先用新密码登录。")
		return
	if status==401 and issuing:
		_clear_fields()
		hide()
		token=""
		session_expired.emit()
		return
	if status!=200:
		var reason: String=str(parsed.data.get("error",""))
		%Explanation.text=str({"invalid_credentials":"当前密码不正确，请重新输入。","invalid_password":"新密码需要 8–128 个字符。",
			"recovery_rate_limited":"尝试次数过多，请稍后重试。"}.get(reason,"账号或恢复码有误，请核对后重试。"))
		return
	if not issuing:
		_close(%RecoveryAccount.text.strip_edges(),"请用新密码登录原基地。" if parsed.data.get("recovered")==true else "重设结果尚未确认，请先用新密码登录。")
		return
	var code: Variant=parsed.data.get("code")
	if concealed or not code is String or code.is_empty():
		%Explanation.text="恢复码未能显示。请重新输入当前密码生成一枚新码。"
		return
	%Inputs.hide()
	%Submit.hide()
	%Output.text=code
	%Output.show()
	%Explanation.text="请立即离线保存下方恢复码。离开此页后即隐藏，一枚码可重设一次密码。"
	%Done.text="已保存，返回账号菜单"

func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_PAUSED and is_node_ready() and visible:
		concealed=true
		_clear_fields()
		if not busy and not %Submit.visible:
			_close()
