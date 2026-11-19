extends RefCounted

const SETTINGS := "user://development_endpoints.cfg"
const RELEASE := "res://runtime_endpoints.cfg"
const PORTS := {"room":24567,"solo":24568,"party":24569,"camp":24570,"treasure":24571}
const LABELS := {"room":"双人房间","solo":"单人探索","party":"组队探索","camp":"营地争夺","treasure":"限时秘宝","profile":"玩家档案"}

static func development() -> bool:
	return OS.is_debug_build() and not OS.has_feature("private_beta")

static func headers(token: String="") -> PackedStringArray:
	var output:=PackedStringArray(["Content-Type: application/json"])
	if not token.is_empty():
		output.append("Authorization: Bearer "+token)
	if OS.has_feature("private_beta"):
		output.append("X-Punk-Beta-Protocol: "+str(ProjectSettings.get_setting("beta/protocol",2)))
	return output

static func issue(service:String) -> String:
	return "%s服务地址或端口无效，请检查%s配置" % [LABELS[service],"调试" if development() else "发布"]

static func release_value(section:String,key:String,empty:Variant) -> Variant:
	var config:=ConfigFile.new()
	if not FileAccess.file_exists(RELEASE) or config.load(RELEASE)!=OK:
		return empty
	return config.get_value(section,key,empty)

static func read(key: String, fallback: String) -> String:
	var settings := ConfigFile.new()
	if settings.load(SETTINGS) != OK:
		return fallback
	return str(settings.get_value("network",key,fallback))

static func remember(key: String, value: String) -> void:
	if not development():
		return
	var settings := ConfigFile.new()
	settings.load(SETTINGS)
	settings.set_value("network",key,value)
	settings.save(SETTINGS)

static func room_host() -> String:
	if not development():
		var address:=transport("room")
		if address.is_empty():
			return ""
		var host:=str(address.host)
		return ("%s:%d" % ["["+host+"]" if ":" in host else host,address.port])
	var override:=OS.get_environment("ROOM_HOST")
	if not override.is_empty():
		return override
	return read("room","10.0.2.2" if OS.get_name() == "Android" else "127.0.0.1")

static func valid_host(host:String) -> bool:
	if host.is_valid_ip_address():
		return true
	if host.replace(".","").is_valid_int():
		return false
	var regex:=RegEx.new()
	regex.compile("^(?:[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)(?:\\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$")
	return host.length()<=253 and regex.search(host)!=null

# Unbracketed IPv6 remains a complete host. An explicit IPv6 port requires [host]:port.
static func parse_room(address: String, fallback: int) -> Dictionary:
	var host := address.strip_edges()
	var port := fallback
	var suffix := ""
	if host.begins_with("["):
		var end := host.find("]")
		if end < 2:
			return {}
		suffix = host.substr(end+1)
		host = host.substr(1,end-1)
	elif host.count(":") == 1:
		var split := host.find(":")
		suffix = host.substr(split)
		host = host.left(split)
	if not suffix.is_empty():
		if not suffix.begins_with(":") or not suffix.substr(1).is_valid_int():
			return {}
		port = suffix.substr(1).to_int()
	if not valid_host(host) or port < 1 or port > 65535:
		return {}
	return {"host":host,"port":port}

static func profile_url() -> String:
	if not development():
		var configured:Variant=release_value("profile","url","")
		return str(configured).trim_suffix("/") if configured is String and valid_url(configured) else ""
	var override := OS.get_environment("PROFILE_URL")
	if not override.is_empty():
		return override
	var host := str(parse_room(room_host(),24567).get("host","127.0.0.1"))
	if ":" in host and not host.begins_with("["):
		host = "[" + host + "]"
	return read("profile","http://" + host + ":24670")

static func valid_url(url:String) -> bool:
	if not (url.begins_with("https://") or url.begins_with("http://")):
		return false
	if "@" in url or "?" in url or "#" in url or " " in url:
		return false
	var authority:=url.trim_prefix("https://").trim_prefix("http://").get_slice("/",0)
	if authority.count(":")>1 and not authority.begins_with("["):
		return false
	return not parse_room(authority,80).is_empty()

static func transport(service:String, profile:="", input:="") -> Dictionary:
	if not PORTS.has(service):
		return {}
	if not development():
		var host:Variant=release_value(service,"host","")
		var port:Variant=release_value(service,"port",0)
		if host is String and valid_host(host) and port is int and port>=1 and port<=65535:
			return {"host":host,"port":port}
		return {}
	var raw:=OS.get_environment(service.to_upper()+"_PORT")
	if not raw.is_empty() and (not raw.is_valid_int() or int(raw)<1 or int(raw)>65535):
		return {}
	var port:=int(PORTS[service]) if raw.is_empty() else int(raw)
	if service=="room":
		return parse_room(room_host() if input.is_empty() else input,port)
	var host:=OS.get_environment(service.to_upper()+"_HOST")
	if host.is_empty():
		var url:=profile_url() if profile.is_empty() else profile
		if not valid_url(url):
			return {}
		var authority:=parse_room(url.get_slice("://",1).get_slice("/",0),80)
		host=str(authority.host)
	return {"host":host,"port":port} if valid_host(host) else {}
