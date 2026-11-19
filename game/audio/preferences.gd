extends RefCounted

const FILE := "user://audio.cfg"
const LEVELS := [0.0,0.35,0.65,1.0]

class Notifications:
	signal changed(level:int)

static var updates := Notifications.new()
static var _level := -1

static func level() -> int:
	if _level < 0:
		var cfg:=ConfigFile.new()
		_level=2
		if cfg.load(FILE)==OK:
			_level=clampi(int(cfg.get_value("effects","level",2)),0,LEVELS.size()-1)
	return _level

static func pending_path() -> String:
	return FILE+".%d.tmp" % OS.get_process_id()

static func save_level(value:int) -> Error:
	var selected:=clampi(value,0,LEVELS.size()-1)
	var cfg:=ConfigFile.new()
	cfg.set_value("effects","level",selected)
	var pending:=pending_path()
	var err:=cfg.save(pending)
	if err!=OK:
		return err
	err=DirAccess.rename_absolute(pending,FILE)
	if err!=OK:
		DirAccess.remove_absolute(pending)
		return err
	_level=selected
	updates.changed.emit(selected)
	return OK
