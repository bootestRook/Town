class_name TownFeature
extends RefCounted

var _definitions: Dictionary = {}
var _built: Dictionary = {}


func _init(definitions: Array) -> void:
	for definition: Dictionary in definitions:
		_definitions[definition.id] = definition.duplicate(true)
		_built[definition.id] = bool(definition.initially_built)


func snapshot() -> Dictionary:
	return _built.duplicate(true)


func set_built(id: String, built: bool) -> Dictionary:
	if not _definitions.has(id):
		return {"accepted": false, "reason": "建筑不存在"}
	if not built and String(_definitions[id].before_resource).is_empty():
		return {"accepted": false, "reason": "此建筑没有建造前外观"}
	if bool(_built[id]) == built:
		return {"accepted": true, "events": []}
	_built[id] = built
	return {"accepted": true, "events": [{"type": "town.building_appearance_changed", "id": id, "built": built}]}
