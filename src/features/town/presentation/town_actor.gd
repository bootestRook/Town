extends Node2D

const MONSTER_TRACK = preload("res://assets/runtime/heroes/ui/monster_health_track.png")
const SOUL_GRAY = preload("res://src/features/town/presentation/soul_gray.tres")
const HEALTH_GREEN := Color8(68, 227, 109)
const HEALTH_ORANGE := Color8(255, 153, 0)
const HEALTH_RED := Color8(204, 0, 51)
const ACTIVE_NAME := Color8(49, 255, 131)
const STANDBY_NAME := Color8(144, 216, 242)
const ACTIVE_OUTLINE := Color(0.03, 0.09, 0.055)
const STANDBY_OUTLINE := Color8(20, 92, 105)

@onready var body: Sprite2D = $Body
var _appearance: Dictionary = {}


func configure(actor: Dictionary, appearance: Dictionary) -> void:
	_appearance = appearance
	var human: bool = actor.has("needs")
	$Name.position = Vector2(appearance.name_x - 100, appearance.name_y - 17)
	$Name.add_theme_font_size_override("font_size", int(appearance.font_size))
	$Name.text = actor.name
	$Level.visible = human
	$Shadow.visible = human
	if human:
		$Level/Value.text = str(actor.level)
	else:
		$Name.add_theme_color_override("font_color", Color8(251, 172, 2))
		$Health.texture_under = MONSTER_TRACK
		$Health.position = Vector2(-29, 4.5)


func render(actor: Dictionary, animation: Dictionary, texture: Texture2D, remainder: float) -> void:
	var human: bool = actor.has("needs")
	position = actor.previous_position.lerp(actor.position, clampf(remainder / 0.05, 0.0, 1.0))
	visible = actor.mode not in ["serving", "reviving"]
	modulate.a = clampf(1.0 - actor.animation_time - remainder, 0.0, 1.0) if actor.mode == "dead" else 1.0
	var health: float = actor.needs.hp if human else actor.hp / actor.base.max_hp * 100.0
	$Health.value = health
	$Health.visible = health > 0 and (not human or actor.deployed)
	$Level.visible = human and actor.deployed and health > 0
	$Name.visible = human or health > 0
	$Health.tint_progress = HEALTH_RED if not human or health <= 25 else (HEALTH_ORANGE if health <= 50 else HEALTH_GREEN)
	if human:
		$Level/Value.text = str(actor.level)
		$Name.add_theme_color_override("font_color", ACTIVE_NAME if actor.deployed else STANDBY_NAME)
		$Name.add_theme_color_override("font_outline_color", ACTIVE_OUTLINE if actor.deployed else STANDBY_OUTLINE)
	body.texture = texture
	body.hframes = int(animation.columns)
	body.vframes = int(animation.rows)
	body.offset.y = animation.frame_height * 0.5 - animation.origin_y + _appearance[animation.direction + "_y"]
	var frame := int((actor.animation_time + remainder) * 30.0)
	body.frame = mini(frame, animation.frames - 1) if actor.animation in ["death", "attack"] else frame % int(animation.frames)
	body.material = SOUL_GRAY if human and actor.needs.hp <= 0 and actor.mode != "dead" else null
	if absf(actor.direction.x) > 0.1:
		body.flip_h = actor.direction.x > 0
