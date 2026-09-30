extends "res://tests/capture_main_ui.gd"

func _run() -> void:
	root.unfocusable=true
	root.position=Vector2i(-4000,0)
	_app=load("res://scenes/main.tscn").instantiate()
	root.add_child(_app)
	await _settle()
	_app.set_process(false)
	_hud=_app.get_node("Interface/MainHUD")
	var op=_app._operations
	var page=_hud.get_node("Stage/DiamondShop")
	for dimensions in [Vector2i(750,1334),Vector2i(360,640),Vector2i(750,1624)]:
		root.size=dimensions
		op._state.diamonds=1605;op._state.coins=814000
		op._state.main.diamond_purchases.clear()
		_hud.close();_hud.render(op.snapshot());await _settle()
		_click(_hud.get_node("Stage/Top/Diamonds"));await _settle()
		_check(page.visible and not _hud.get_node("Stage/Bottom").visible,"diamond shortcut replaces footer")
		_check(page.get_node("Offers/Card5").get_global_rect().end.y < page.get_node("Footer").get_global_rect().position.y,"all six cards clear footer")
		await _shot("initial",dimensions)
		_click(page.get_node("Header/Help"));await _settle()
		_check(page.get_node("HelpPanel").visible,"help explains local recharge and first bonus")
		await _shot("help",dimensions)
		_outside();await _settle()
		var orders: int=op._state.main.orders.size()
		_click(page.get_node("Offers/Card0"))
		_check(page.get_node("Reward").visible,"purchase opens native reward immediately")
		_check(page.get_node("RewardSound").playing,"source reward sound begins with receipt")
		_check(op._state.diamonds==1725,"first 60 tier grants exactly 120 diamonds")
		# Rapid repeat inputs cannot click through the reward to buy again.
		for i in 6:_click(page.get_node("Offers/Card0"))
		_check(op._state.main.orders.size()==orders+1,"rapid tapping creates exactly one order")
		await create_timer(0.42).timeout
		await _shot("burst",dimensions)
		var frame: int=page.get_node("Reward/Body/Ribbon").frame
		await create_timer(0.2).timeout
		_check(frame!=page.get_node("Reward/Body/Ribbon").frame,"original reward entrance advances")
		await create_timer(2.2).timeout
		await _shot("reward",dimensions)
		_check(page.get_node("Reward/Body/Ribbon").texture==page._loop,"source entrance hands off to loop")
		_check(page.get_node("Reward/Body/Item/Amount").text=="120","reward displays actual doubled grant")
		_outside();await _settle()
		_check(not page.get_node("Reward").visible and not page.get_node("Offers/Card0/First").visible,"receipt dismisses and tier first bonus disappears")
		_check(page.get_node("Offers/Card1/First").visible,"other first bonuses remain")
		await _shot("after_first",dimensions)
		_click(page.get_node("Offers/Card0"));await create_timer(0.4).timeout
		_check(op._state.diamonds==1785 and page._receipt.total==60,"second purchase grants only base diamonds")
		_outside();await _settle()
		_click(page.get_node("Header/Coins"));await _settle()
		_check(_hud.get_node("Stage/Dialogs").visible,"shop coin shortcut remains operable")
		_click(_hud.get_node("Stage/Dialogs/Panel/Close"));await _settle()
		_check(page.visible,"coin popup returns to recharge page")
		_click(page.get_node("Back"));await _settle()
		_check(not page.visible and _hud.route.is_empty(),"back from town shortcut restores map")
		_click(_hud.get_node("Stage/Bottom/Nav2"));await _settle()
		_click(_hud.get_node("Stage/HeroRoster/Scroll/Grid").get_child(0).get_node("Open"));await _settle()
		var hero=_hud.get_node("Stage/HeroDetail")
		var id: String=hero.hero_id
		_click(hero.get_node("Header/Diamonds"));await _settle()
		_check(page.visible and not hero.visible,"hero diamond shortcut opens full recharge")
		_click(page.get_node("Back"));await _settle()
		_check(hero.visible and hero.hero_id==id,"return restores same hero detail")
		await _shot("hero_return",dimensions)
		_hud.close();_hud.navigate("recruit",false);await _settle()
		_click(_hud.get_node("Stage/Top/Diamonds"));await _settle()
		_click(page.get_node("Back"));await _settle()
		_check(_hud.route=="recruit" and _hud.get_node("Stage/Recruitment").visible,"return restores recruitment drawer")
	# Every card is a real purchase entrance, including bottom row; muted audio respects settings.
	op._state.main.sound=false
	_hud.close();_hud.render(op.snapshot())
	_click(_hud.get_node("Stage/Bottom/Nav4"));await _settle()
	for i in range(1,6):
		var balance: int=op._state.diamonds
		_click(page.get_node("Offers/Card%d"%i));await create_timer(0.4).timeout
		_check(op._state.diamonds==balance+int(page._products[i].diamonds)*2,"tier %d visible purchase works"%i)
		_outside();await _settle()
	_check(not page.get_node("RewardSound").playing,"muted reward never starts audio")
	if _failures.is_empty():print("[OK] Diamond recharge native input, six tiers, first/repeat, rapid tap, animation, shortcuts; 18 captures")
	else:
		for failure in _failures:push_error(failure)
	_app.queue_free();await process_frame
	quit(0 if _failures.is_empty() else 1)

func _outside() -> void:
	var point:=root.get_final_transform()*Vector2(root.get_visible_rect().size.x*0.8,75)
	for pressed in [true,false]:
		var event:=InputEventMouseButton.new();event.position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed
		Input.parse_input_event(event);Input.flush_buffered_events()

func _shot(state: String, dimensions: Vector2i) -> void:
	await _capture("diamond_%s_%d_%d"%[state,dimensions.x,dimensions.y])
