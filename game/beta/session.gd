extends RefCounted

static func path() -> String:
	var custom:=OS.get_environment("PL_BASE_SESSION_FILE") if OS.is_debug_build() and not OS.has_feature("private_beta") else ""
	return custom if not custom.is_empty() else "user://base-session.cfg"

static func load_for(endpoint:String) -> Dictionary:
	var cfg:=ConfigFile.new()
	if cfg.load(path())!=OK or cfg.get_value("session","endpoint","")!=endpoint:return {}
	return {"endpoint":endpoint,"name":cfg.get_value("session","name",""),"owner":cfg.get_value("session","owner",""),
		"token":cfg.get_value("session","token",""),"pending_robot":cfg.get_value("session","pending_robot",""),
		"pending_name":cfg.get_value("session","pending_name","")}

static func store(data:Dictionary) -> Error:
	var cfg:=ConfigFile.new()
	for key:String in data:cfg.set_value("session",key,data[key])
	return cfg.save(path())

static func forget() -> void:
	if FileAccess.file_exists(path()):DirAccess.remove_absolute(ProjectSettings.globalize_path(path()))
