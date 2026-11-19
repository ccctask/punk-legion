extends RefCounted

const RESOURCE_NAMES := preload("res://profile/inventory.gd").RESOURCES

static func read(data:Dictionary, stock:Dictionary) -> Dictionary:
	var price:Dictionary=data.get("price",{})
	if price.is_empty() or stock.is_empty():
		return {"affordable":false,"text":"正在取得当前材料报价。"}
	var lines:=PackedStringArray()
	if data.get("aid_repair_battle"):
		lines.append("本次协防战损 · 已抵扣 1 结构材料")
	var affordable:=true
	for resource:String in price:
		if not stock.has(resource):
			return {"affordable":false,"text":"正在取得当前材料报价。"}
		var need:=-int(price[resource])
		var owned:=int(stock[resource])
		var missing:=maxi(0,need-owned)
		affordable=affordable and missing==0
		lines.append("%s　需 %d · 有 %d · %s" % [RESOURCE_NAMES.get(resource,resource),need,owned,"缺 %d" % missing if missing else "已足额"])
	return {"affordable":affordable,"text":"\n".join(lines)}
