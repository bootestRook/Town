class_name MainRecruitmentOverlay
extends Control

signal closed
signal intent(command: Dictionary)
signal detail_requested(kind: String, data: Dictionary)
const COLORS := {2:Color("34cd3f"), 3:Color("269ac2"), 4:Color("c450c9"), 5:Color("f3c844")}
const HELP := "1.当船长携带可被招募英雄停留在港口时，领主可向其支付一定的报酬进行招募，同时间内只会出现3名可招募英雄。\n\n2.可招募英雄有四种刷新方式：\n①.3名英雄全部被招募入队时，会立即刷新所有可招募英雄。\n②.招募至少1名英雄入队后，可手动更换一批英雄。\n③.通过观看广告或消耗钻石的方式进行手动刷新，手动刷新每日数量有限。\n④.若3名英雄未全部招募入队，且不使用手动刷新，招募船停留时间结束后会刷新英雄。"
var kind := ""
var quantity := 1
var remember := false
var receipt: Dictionary = {}
var _catalog
var _definitions: Dictionary = {}
var _state: Dictionary = {}
var _elapsed := 0.0
var _ribbon: AtlasTexture
var _wish_id := ""
var _columns: Dictionary = {}

func _ready() -> void:
	$Shade.pressed.connect(close)
	$Panel/Finish/Cancel.pressed.connect(close)
	$Panel/Finish/Accept.pressed.connect(func(): intent.emit({"type":"recruit_finish", "remember":remember}))
	$Panel/Finish/Remember.pressed.connect(func(): remember = not remember; _render_popup())
	$Panel/Refresh/Free.pressed.connect(func(): intent.emit({"type":"recruit_refresh", "method":"ad"}))
	$Panel/Refresh/Paid.pressed.connect(func(): intent.emit({"type":"recruit_refresh", "method":"diamond"}))
	$Panel/Refresh/Privilege.pressed.connect(func(): open("privilege", _state))
	$Panel/Purchase/Minus.pressed.connect(func(): _quantity(-1))
	$Panel/Purchase/Plus.pressed.connect(func(): _quantity(1))
	$Panel/Purchase/Ten.pressed.connect(func(): _quantity(10))
	$Panel/Purchase/Hundred.pressed.connect(func(): _quantity(100))
	$Panel/Purchase/Reset.pressed.connect(func(): quantity = 1; _render_popup())
	$Panel/Purchase/Buy.pressed.connect(func(): intent.emit({"type":"recruit_tickets", "quantity":quantity}))
	$Panel/Wish/Card.pressed.connect(func():
		if _state.main.recruitment.wish_unlocked: intent.emit({"type":"recruit_wish"})
		else:
			close()
			detail_requested.emit("catalog_hero", {"definition":_wish_id}))

func configure(catalog, definitions: Dictionary) -> void:
	_catalog = catalog
	_definitions = definitions
	for row: Dictionary in definitions.heroes.values():
		if int(row.source_id) == int(definitions.recruit_rules.wish_talent): _wish_id = row.id
	_ribbon = AtlasTexture.new()
	_ribbon.atlas = catalog.load_resource("recruitment.ribbon")
	_ribbon.region = Rect2(0,0,620,180)
	$Result/Ribbon.texture = _ribbon
	$Panel/Help/Scroll/Text.text = HELP
	for quality in [4,5]:
		_columns[quality] = []
		for i in 15: _columns[quality].append(catalog.load_resource("recruitment.column_%d_%d" % [quality,i]))

func resize_page(height: float) -> void:
	size.y = height
	$Shade.size.y = height
	_layout()

func open(next: String, state: Dictionary) -> void:
	kind = next
	_state = state
	quantity = 1
	remember = false
	_elapsed = 0
	$Panel/Help/Scroll.scroll_vertical = 0
	show()
	_layout()
	_render_popup()

func render(state: Dictionary) -> void:
	_state = state
	if visible and kind not in ["animation", "success"]: _render_popup()

func close() -> void:
	if kind == "animation":
		_show_success()
		return
	hide()
	kind = ""
	closed.emit()

func action_result(command: Dictionary, result: Dictionary, state: Dictionary) -> void:
	_state = state
	if not result.accepted: return
	if result.has("recruitment"):
		receipt = result.recruitment.duplicate(true)
		open("animation", state)
		for i in 3:
			var door := get_node("Animation/Door%d" % i)
			door.visible = i < receipt.pool.size()
			if not door.visible: continue
			var hero: Dictionary = _definitions.heroes[receipt.pool[i]]
			door.get_node("Portrait").configure(hero.appearance, _catalog, _definitions)
			door.get_node("Glow").modulate = COLORS[int(hero.quality)]
			door.position.x = 210 if receipt.pool.size() == 1 else (85 + i * 340 if receipt.pool.size() == 2 else i * 210)
			door.position.y = 176 if receipt.pool.size() == 3 and i == 1 else 220
	elif command.type in ["recruit_refresh", "recruit_finish", "recruit_tickets"]: close()
	elif command.type == "recruit_wish": _render_popup()

func _quantity(delta: int) -> void:
	quantity = clampi(quantity + delta, 1, 9999)
	_render_popup()

func _layout() -> void:
	var panel_height := 530.0
	if kind == "purchase": panel_height = 748
	elif kind == "wish": panel_height = minf(1040, size.y - 225)
	$Panel.size.y = panel_height
	$Panel/Frame.size.y = panel_height
	$Panel.position.y = (size.y - panel_height) * 0.5
	$Panel.visible = kind not in ["animation", "success"]
	$Animation.visible = kind == "animation"
	$Result.visible = kind == "success"
	$Animation.position.y = size.y * 0.5 - 439
	$Result.position.y = size.y * 0.5 - 204
	$CloseTip.position.y = minf(size.y - 60, $Panel.position.y + panel_height + 90)
	if kind in ["animation", "success"]: $CloseTip.position.y = size.y - 215
	elif kind == "refresh": $CloseTip.position.y = size.y - 60
	$CloseTip.text = "点击空白处跳过招募动画" if kind == "animation" else "点击空白处关闭界面"

func _render_popup() -> void:
	for page: String in ["Help", "Refresh", "Finish", "Purchase", "Wish", "Probability", "Dragon", "Privilege"]:
		get_node("Panel/"+page).visible = page.to_lower() == kind
	$Panel/Title.text = {"help":"招募说明", "refresh":"刷新英雄", "finish":"提示", "purchase":"钻石商城", "wish":"心愿英雄选择", "probability":"招募概率", "dragon":"龙魂技能", "privilege":"免广告特权", "animation":"", "success":""}.get(kind, "")
	if _state.is_empty(): return
	var info: Dictionary = _state.main.recruitment
	$Panel/Finish/Remember/Check.visible = remember
	$Panel/Purchase/Count.text = str(quantity)
	$Panel/Purchase/Cost.text = str(quantity * int(_definitions.recruit_rules.ticket_price))
	$Panel/Purchase/Minus.disabled = quantity <= 1
	$Panel/Purchase/Plus.disabled = quantity >= 9999
	$Panel/Refresh/Count.text = "刷新次数:%d" % info.ad_left
	$Panel/Refresh/Paid/Cost.text = str(int(_definitions.recruit_rules.refresh_price))
	$Panel/Refresh/Free.disabled = info.ad_left <= 0 or info.refresh_left <= 0 or _state.main.recruit_ad_remaining > 0
	$Panel/Refresh/Paid.disabled = info.refresh_left <= 0
	$Panel/Refresh/Free.modulate = Color(0.5,0.5,0.5) if $Panel/Refresh/Free.disabled else Color.WHITE
	$Panel/Refresh/Paid.modulate = Color(0.5,0.5,0.5) if $Panel/Refresh/Paid.disabled else Color.WHITE
	var wish: Dictionary = _definitions.heroes[_wish_id]
	$Panel/Wish/Card/Portrait.configure(wish.appearance, _catalog, _definitions)
	$Panel/Wish/Card/Name.text = wish.display_name
	$Panel/Wish/Card/Job.texture = _catalog.load_resource("hero_roster.job_%d" % wish.job)
	$Panel/Wish/Card/Element.texture = _catalog.load_resource("hero_roster.element_%d" % wish.element)
	var wish_star: Dictionary = _definitions.star_display[_definitions.hero_catalog[_wish_id].star]
	for i in 4:
		var star := get_node("Panel/Wish/Card/Star%d" % i)
		star.visible = i < wish_star.count
		star.texture = _catalog.load_resource(wish_star.resource_id)
	$Panel/Wish/Card/Check.visible = _state.main.recruit_wish
	$Panel/Wish/Card/Status.text = ("已选择" if _state.main.recruit_wish else "未选择") if info.wish_unlocked else "获得后解锁"
	var level: Dictionary = _definitions.recruit_levels[_state.main.recruit_level-1]
	$Panel/Probability/Text.text = "招募等级 LV.%d\n\n优秀英雄 %.2f%%\n精英英雄 %.2f%%\n稀有英雄 %.2f%%\n史诗英雄 %.2f%%" % [_state.main.recruit_level, level.green / 100.0, level.blue / 100.0, level.purple / 100.0, level.gold / 100.0]

func _show_success() -> void:
	kind = "success"
	_elapsed = 0
	_layout()
	var hero: Dictionary = _definitions.heroes[receipt.hero]
	$Result/Portrait.configure(hero.appearance, _catalog, _definitions)
	$Result/Name.text = hero.display_name
	$Result/Name.modulate = COLORS[int(hero.quality)]
	$Result/Job.texture = _catalog.load_resource("recruitment.job_%d" % hero.job)
	$Result/Element.texture = _catalog.load_resource("hero_roster.element_%d" % hero.element)
	var display: Dictionary = _definitions.star_display[float(receipt.star)]
	for i in 4:
		var star := get_node("Result/Star%d" % i)
		star.visible = i < display.count
		star.texture = _catalog.load_resource(display.resource_id)
		star.position.x = 450 - display.count * 25 + i * 50
	var talent: Dictionary = _definitions.hero_talents[float(receipt.talent)]
	var count: int = receipt.before + receipt.fragments
	$Result/Progress.max_value = maxi(1, int(talent.fragment_count))
	$Result/Progress.value = count
	$Result/Value.text = "%d/%d" % [count, talent.fragment_count]
	$Result/Add.text = "+%d" % receipt.fragments
	for key: String in ["Progress", "Value", "Add", "Fragment"]: get_node("Result/"+key).visible = not receipt.new
	$Result/New.visible = receipt.new

func _process(delta: float) -> void:
	if not visible or kind not in ["animation", "success"]: return
	_elapsed += delta
	if kind == "success":
		var frame := int(fmod(_elapsed,10.6) / 10.6 * 16)
		_ribbon.region = Rect2((frame % 4) * 620, (frame / 4) * 180, 620,180)
		return
	# Source door composition and accelerating/decelerating marquee; receipt is already final.
	var count: int = receipt.pool.size()
	var chosen: int = receipt.pool.find(receipt.hero)
	var cursor := int(_elapsed * (3.0 + minf(_elapsed,2.0) * 4.0)) % count
	if _elapsed >= 3.8: cursor = chosen
	for i in 3:
		var door := get_node("Animation/Door%d" % i)
		if not door.visible: continue
		door.modulate.a = minf(1.0, _elapsed * 2.0)
		door.get_node("Glow").visible = i == cursor
		var quality: int = int(_definitions.heroes[receipt.pool[i]].quality)
		door.get_node("Column").visible = quality >= 4
		if quality >= 4: door.get_node("Column").texture = _columns[quality][int(_elapsed * 15) % 15]
		var beam := get_node("Animation/Beam%d" % i)
		beam.modulate.a = 0.28 + 0.15 * sin(_elapsed * 3.0 + i)
		beam.rotation = sin(_elapsed * 0.85 + i * 2.0) * 0.27
	if _elapsed >= 5.2: _show_success()
