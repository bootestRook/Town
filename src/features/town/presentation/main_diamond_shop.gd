extends Control

signal closed
signal intent(command: Dictionary)
signal detail_requested(kind: String, data: Dictionary)

const ENTER_DURATION := 2.6667
const LOOP_DURATION := 10.6
var _state: Dictionary = {}
var _products: Array = []
var _bursts: Array = []
var _enter: Texture2D
var _loop: Texture2D
var _elapsed := 0.0
var _busy := false
var _receipt: Dictionary = {}
var _press_tweens: Dictionary = {}


func _ready() -> void:
	$Back.pressed.connect(close)
	$Header/Help.pressed.connect(func(): _sound($Click); $HelpPanel.show())
	$Header/Coins.pressed.connect(func(): detail_requested.emit("coins", {}))
	$HelpPanel.gui_input.connect(_help_input)
	$Reward.gui_input.connect(_reward_input)
	for i in 6:
		var card := get_node("Offers/Card%d" % i)
		card.pressed.connect(func(): _buy(i))
		card.button_down.connect(func(): _press(i,0.96))
		card.button_up.connect(func(): _press(i,1.0))
	visibility_changed.connect(func():
		if not visible:
			$Reward.hide(); $HelpPanel.hide(); _busy = false
			for i in 6: _press(i,1.0))


func configure(catalog, definitions: Dictionary) -> void:
	_products = definitions.shop.duplicate(true)
	_products.sort_custom(func(a,b): return a.source_id < b.source_id)
	for i in 6:
		var card := get_node("Offers/Card%d" % i)
		card.get_node("Frame").texture = catalog.load_resource(_products[i].background_id)
		card.get_node("Icon").texture = catalog.load_resource(_products[i].resource_id)
		card.get_node("Amount").text = "%d 钻石" % _products[i].diamonds
		card.get_node("Bonus").text = "+%d 钻石" % _products[i].first_bonus
		card.get_node("Price").text = "CNY %d" % _products[i].price
	for i in 16: _bursts.append(catalog.load_resource("diamond_shop.burst_%d" % i))
	_enter = catalog.load_resource("diamond_shop.reward_enter")
	_loop = catalog.load_resource("diamond_shop.reward_loop")


func open(state: Dictionary) -> void:
	_receipt.clear()
	_busy = false
	show()
	render(state)


func render(state: Dictionary) -> void:
	_state = state
	if not visible: return
	$Header/Coins/Value.text = MainHUD.compact(state.coins)
	_balance()
	for i in 6:
		var card := get_node("Offers/Card%d" % i)
		var first: bool = state.main.diamond_purchases.get(_products[i].id,0) == 0
		for name: String in ["Bonus","First","Ribbon"]: card.get_node(name).visible = first


func resize_page(height: float) -> void:
	size.y = height
	# Extend painted card grounds on tall phones; icon and type sizes remain fixed.
	var extra := maxf(0,height-1280)
	$Banner.size.y = 298 + minf(52,extra*0.19)
	$Offers.position.y = 404 + minf(52,extra*0.19)
	var card_height := 350 + maxf(0,extra-52) * 0.5
	for i in 6:
		var card := get_node("Offers/Card%d" % i)
		card.position.y = (i/3) * (card_height+5)
		card.size.y = card_height
		card.pivot_offset.y = card_height*0.5
		card.get_node("Frame").size.y = card_height
		card.get_node("Icon").position.y = card_height*0.194
		card.get_node("Amount").position.y = card_height*0.503
		card.get_node("Bonus").position.y = card_height*0.609
		# The green source frame has its price slot two pixels above the other frames.
		var price_center := 305.5 if i == 0 else 307.5
		card.get_node("Price").position.y = card_height*(price_center/350.0)-20.0
	$Footer.position.y = height - 103
	$Back.position.y = height - 174
	for overlay: String in ["Reward","HelpPanel"]:
		get_node(overlay).size.y = height
		get_node(overlay+"/Body").position.y = (height - (378 if overlay == "Reward" else 510)) * 0.5
		get_node(overlay+"/Hint").position.y = height - 240


func close() -> void:
	if $HelpPanel.visible:
		$HelpPanel.hide()
		return
	if $Reward.visible:
		_dismiss_reward()
		return
	if _busy: return
	_sound($Click)
	hide()
	closed.emit()


func _buy(index: int) -> void:
	if _busy or not visible or $HelpPanel.visible: return
	_busy = true
	_sound($Click)
	intent.emit({"type":"shop_buy","product":_products[index].id,"order":_state.main.order_serial+1})


func action_result(command: Dictionary, result: Dictionary) -> void:
	if command.type != "shop_buy" or not visible: return
	if not result.accepted:
		_busy = false
		return
	_receipt = result.recharge.duplicate(true)
	_elapsed = 0.0
	$Reward/Body/Ribbon.texture = _enter
	$Reward/Body/Ribbon.vframes = 20
	$Reward/Body/Ribbon.frame = 0
	$Reward/Body/Item/Amount.text = str(_receipt.total)
	$Reward.show()
	_update_reward()
	_sound($RewardSound)


func _reward_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_dismiss_reward()
		accept_event()


func _help_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		$HelpPanel.hide()
		accept_event()


func _dismiss_reward() -> void:
	# Do not let the purchase release event instantly dismiss its own receipt.
	if _elapsed < 0.35: return
	_sound($Click)
	$Reward.hide()
	_busy = false
	_balance()


func _press(index: int, amount: float) -> void:
	if _press_tweens.has(index): _press_tweens[index].kill()
	var tween := create_tween()
	tween.tween_property(get_node("Offers/Card%d" % index),"scale",Vector2.ONE*amount,0.09)
	_press_tweens[index] = tween


func _process(delta: float) -> void:
	if not visible or not $Reward.visible: return
	_elapsed += delta
	_update_reward()
	_balance()


func _balance() -> void:
	var balance: int = _state.diamonds
	if $Reward.visible and not _receipt.is_empty():
		balance -= int(_receipt.total * (1.0-clampf((_elapsed-0.333)/0.65,0.0,1.0)))
	$Header/Diamonds/Value.text = MainHUD.compact(balance)


func _update_reward() -> void:
	if _elapsed < ENTER_DURATION:
		$Reward/Body/Ribbon.frame = mini(79,int(_elapsed/ENTER_DURATION*80))
	else:
		if $Reward/Body/Ribbon.texture != _loop:
			$Reward/Body/Ribbon.frame = 0
			$Reward/Body/Ribbon.vframes = 16
			$Reward/Body/Ribbon.texture = _loop
		$Reward/Body/Ribbon.frame = int(fmod(_elapsed-ENTER_DURATION,LOOP_DURATION)/LOOP_DURATION*64)
	$Reward/Body/Title.scale = Vector2.ONE * _title_scale(_elapsed)
	$Reward/Body/Rays.rotation = _elapsed * 0.12
	$Reward/Body/Rays.modulate.a = minf(0.6,_elapsed*1.5)
	$Reward/Body/Item.visible = _elapsed >= 0.333
	var bounce := 1.0 + 0.05*sin(clampf((_elapsed-0.333)/0.133,0,1)*PI)
	$Reward/Body/Item.scale = Vector2.ONE * bounce
	var frame := int((_elapsed-0.3)*30)
	$Reward/Body/Burst.visible = _elapsed >= 0.3 and frame < 16
	if $Reward/Body/Burst.visible: $Reward/Body/Burst.texture = _bursts[maxi(0,frame)]
	$Reward/Hint.modulate.a = clampf((_elapsed-0.65)*3,0,1)


func _title_scale(time: float) -> float:
	# Original jiesuan_ziti_01 keyframes, 30 Hz.
	if time < 0.1: return lerpf(0,0.65,time/0.1)
	if time < 0.1667: return lerpf(0.65,1,(time-0.1)/0.0667)
	if time < 0.2: return lerpf(1,1.1,(time-0.1667)/0.0333)
	if time < 0.2333: return lerpf(1.1,1,(time-0.2)/0.0333)
	return 1.0


func _sound(player: AudioStreamPlayer) -> void:
	if not _state.is_empty() and _state.main.sound: player.play()
