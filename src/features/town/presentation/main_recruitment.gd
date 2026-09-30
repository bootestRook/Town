extends Control

# Source-pinned recruitment: town and captain above a three-candidate stage.
# Source navy/orange modal grammar and source idle characters are the authority.
# Draw -> animation -> receipt -> remaining candidates -> next batch.
# Fixed 720-point, bottom-anchored 708-point drawer; no promotional map icons.
# FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance.
signal closed
signal intent(command: Dictionary)
signal popup_requested(kind: String)
signal detail_requested(kind: String, data: Dictionary)
var _catalog
var _definitions: Dictionary = {}
var _state: Dictionary = {}
var tab := 0
var busy := false

func _ready() -> void:
	$Back.pressed.connect(func(): closed.emit())
	$Body/Recruit.pressed.connect(func():
		if busy: return
		if _state.main.recruitment.offer.item != 102 and _state.main.recruitment.tickets == 0: popup_requested.emit("purchase")
		else: intent.emit({"type":"recruit"}))
	$Body/Refresh.pressed.connect(func(): popup_requested.emit("refresh"))
	$Body/Finish.pressed.connect(func():
		if _state.main.recruitment.finish_silent: intent.emit({"type":"recruit_finish"})
		else: popup_requested.emit("finish"))
	$Body/Tickets.pressed.connect(func(): popup_requested.emit("purchase"))
	$Body/Help.pressed.connect(func(): popup_requested.emit("help"))
	$Body/Probability.pressed.connect(func(): popup_requested.emit("probability"))
	$Body/Wish.pressed.connect(func(): popup_requested.emit("wish"))
	$Body/Illustration.pressed.connect(func(): detail_requested.emit("hero_management", {"page":2}))
	$Dragon/DragonInfo.pressed.connect(func(): popup_requested.emit("dragon"))
	for i in 2:
		get_node("Bottom/Tab%d" % i).pressed.connect(func(): tab = i; render(_state))
	for i in 3:
		get_node("Body/Hero%d" % i).pressed.connect(func():
			if i < _state.main.pool.size(): detail_requested.emit("catalog_hero", {"definition": _state.main.pool[i]}))

func configure(catalog, definitions: Dictionary) -> void:
	_catalog = catalog
	_definitions = definitions

func open(state: Dictionary) -> void:
	tab = 0
	show()
	render(state)

func render(state: Dictionary) -> void:
	_state = state
	if not visible: return
	var main: Dictionary = state.main
	var info: Dictionary = main.recruitment
	var count: int = main.recruited.size()
	$Body.visible = tab == 0
	$Dragon.visible = tab == 1
	$Captain.visible = tab == 0
	$Bottom/Tab0/Art.texture = _catalog.load_resource("main_ui.nav_3_selected" if tab == 0 else "main_ui.nav_3")
	$Bottom/Tab1/Art.texture = _catalog.load_resource("recruitment.tab_dragon_selected" if tab == 1 else "recruitment.tab_dragon")
	$Captain/Speech.text = ["只需付出少量钻石,强力英雄就能带回家", "点击招募,您将获得两位英雄中的一位", "最后一名英雄在等待您的招募"][mini(count,2)]
	$Body/Xp.max_value = main.recruit_required
	$Body/Xp.value = main.recruit_exp
	$Body/XpText.text = "%d/%d" % [main.recruit_exp, main.recruit_required]
	$Body/Illustration/Text.text = "LV.%d" % main.recruit_level
	$Body/Tickets/Value.text = str(info.tickets)
	var seconds := ceili(main.refresh_remaining)
	$Body/Countdown.text = "[center]招募船将在 [color=#34cd3f]%02d:%02d[/color] 后刷新[/center]" % [seconds / 60, seconds % 60]
	$Body/Wish/Text.text = "已激活" if main.recruit_wish else "未激活"
	$Body/Wish/Text.modulate = Color(0.2,1,0.25) if main.recruit_wish else Color.WHITE
	for i in 3:
		var node := get_node("Body/Hero%d" % i)
		node.visible = i < main.pool.size()
		if not node.visible: continue
		var id: String = main.pool[i]
		var hero: Dictionary = _definitions.heroes[id]
		node.get_node("Portrait").configure(hero.appearance, _catalog, _definitions)
		node.get_node("Element").texture = _catalog.load_resource("hero_roster.element_%d" % hero.element)
		node.get_node("Name").text = hero.display_name
		node.get_node("Name").modulate = MainRecruitmentOverlay.COLORS[int(hero.quality)]
		node.get_node("Chance").text = "%.2f%%" % (info.chances.get(id,0) * 100)
		node.get_node("Chance").visible = id not in main.recruited
		node.get_node("Check").visible = id in main.recruited
	$Body/Recruit.position.x = 214 if count == 0 else 47
	$Body/Recruit/Text.text = "招募" if count == 0 else "再来一次"
	$Body/Recruit.disabled = busy
	$Body/Refresh.visible = count == 0
	$Body/Finish.visible = count > 0
	$Body/Recruit/Cost/Icon.texture = _catalog.load_resource("main_ui.diamond_icon" if info.offer.item == 102 else "recruitment.ticket")
	var enough: bool = state.diamonds >= info.offer.amount if info.offer.item == 102 else info.tickets > 0
	var amount: String = "[color=%s]%d[/color]" % ["#34cd3f" if enough else "#ff3650", info.offer.amount]
	if info.offer.amount < info.offer.original: amount = "[s]%d[/s] " % info.offer.original + amount
	$Body/Recruit/Cost/Value.text = amount
	$Body/Recruit/Cost/Strike.visible = info.offer.amount < info.offer.original
