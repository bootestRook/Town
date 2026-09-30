extends Node2D

signal open_requested
signal chest_requested
var _phase := "idle"
var _has_chest := false

func render(state: Dictionary) -> void:
	var h: Dictionary = state.horn
	position = h.origin
	_phase = h.phase
	_has_chest = not h.chest.is_empty()
	visible = _phase != "idle" or _has_chest
	$Prepare.visible = _phase != "idle"
	$Chest.visible = _has_chest
	if _phase == "prepare": $Prepare/Title.text = "集结中 %d/%d" % [h.ready.size(), h.participants.size()]
	elif _phase == "fight": $Prepare/Title.text = "%s  %d%%" % [h.levels[h.level].display_name, ceili(h.boss_hp / h.levels[h.level].max_hp * 100)]
	$Prepare/Time.text = "%02d:%02d" % [ceili(h.remaining) / 60, ceili(h.remaining) % 60]

func pick(world_point: Vector2) -> bool:
	if not visible: return false
	var local := world_point - position
	if _has_chest and Rect2(-80,-100,160,160).has_point(local):
		chest_requested.emit()
		return true
	if _phase != "idle" and Rect2(-185,90,370,125).has_point(local):
		open_requested.emit()
		return true
	return false
