extends "res://tests/capture_main_ui.gd"

func _run() -> void:
	root.unfocusable = true
	root.position = Vector2i(-4000,0)
	root.size = Vector2i(750,1334)
	_app = load("res://scenes/main.tscn").instantiate()
	root.add_child(_app)
	await _settle()
	_app.set_process(false)
	_hud = _app.get_node("Interface/MainHUD")
	var op = _app._operations
	var page = _hud.get_node("Stage/Recruitment")
	var overlay = _hud.get_node("Stage/RecruitOverlay")
	for dimensions in [Vector2i(750,1334),Vector2i(360,640),Vector2i(750,1624)]:
		root.size = dimensions
		op._state.inventory["item.10001"]=54
		op._state.diamonds=1605
		op._state.main.pool=["heroes.1008002","heroes.1036003","heroes.1005001"]
		op._state.main.recruited=[]
		op._state.main.recruit_level=3
		op._state.main.recruit_exp=35
		op._state.main.recruit_total=10
		op._state.main.daily.clear()
		_hud.render(op.snapshot());_hud.navigate("recruit",false)
		await _settle()
		_check(page.visible and not _hud.get_node("Stage/Bottom").visible,"recruit drawer replaces primary footer")
		await _shot("main",dimensions)
		for pair in [["Help","help"],["Wish","wish"],["Tickets","purchase"],["Refresh","refresh"]]:
			_click(page.get_node("Body/"+pair[0]));await _settle()
			_check(overlay.kind==pair[1],"source entrance opens "+pair[1])
			await _shot(pair[1],dimensions)
			if pair[1]=="purchase":
				_click(overlay.get_node("Panel/Purchase/Ten"));_check(overlay.quantity==11,"ticket plus ten")
				_click(overlay.get_node("Panel/Purchase/Hundred"));_check(overlay.quantity==111,"ticket plus hundred")
				_click(overlay.get_node("Panel/Purchase/Reset"));_check(overlay.quantity==1,"ticket reset")
				_click(overlay.get_node("Panel/Purchase/Buy"));await _settle()
				_check(op.snapshot().inventory["item.10001"]==55,"ticket purchase writes inventory")
			elif pair[1]=="refresh":
				_click(overlay.get_node("Panel/Refresh/Privilege"));await _settle()
				_check(overlay.kind=="privilege","free-ad privilege banner opens its details")
				_outside()
			else: _outside()
			await _settle()
			_check(not overlay.visible,"modal dismissed")
		var frame: int = page.get_node("Body/Hero1/Portrait").frame
		for i in 12: await process_frame
		_check(frame!=page.get_node("Body/Hero1/Portrait").frame,"candidate source idle moves")
		var before: Dictionary = op.snapshot()
		_click(page.get_node("Body/Recruit"));await _settle()
		_check(overlay.kind=="animation","draw starts source-door animation")
		_check(op.snapshot().inventory["item.10001"]==before.inventory["item.10001"]-1,"draw charges exactly once")
		await create_timer(0.7).timeout
		await _shot("animation",dimensions)
		_outside();await _settle()
		_check(overlay.kind=="success","skip leads to success receipt")
		_check(op.snapshot().inventory["item.10001"]==before.inventory["item.10001"]-1,"skip does not charge again")
		await _shot("success",dimensions)
		_outside();await _settle()
		_check(not overlay.visible and page.get_node("Body/Finish").visible,"close receipt reveals next draw and finish")
		await _shot("remaining",dimensions)
		_click(page.get_node("Body/Finish"));await _settle()
		_check(overlay.kind=="finish","finish opens source confirmation")
		await _shot("finish",dimensions)
		_click(overlay.get_node("Panel/Finish/Cancel"));await _settle()
		_check(op.snapshot().main.recruited.size()==1,"cancel preserves recruited batch")
		_click(page.get_node("Body/Finish"));_click(overlay.get_node("Panel/Finish/Remember"));_click(overlay.get_node("Panel/Finish/Accept"));await _settle()
		_check(op.snapshot().main.recruited.is_empty() and op.snapshot().main.recruitment.finish_silent,"confirmed finish replaces batch and remembers day")
		_click(page.get_node("Back"));await _settle()
		_check(_hud.route.is_empty(),"source arrow returns to town")
	# Let another animation complete naturally; no skip means the same single receipt.
	root.size = Vector2i(750,1334)
	op._state.inventory["item.10001"]=3
	op._state.diamonds=1000
	op._state.main.recruit_ad_remaining=0
	op._state.main.recruit_refreshes=0
	op._state.main.daily.clear()
	_hud.render(op.snapshot());_hud.navigate("recruit",false);await _settle()
	_click(page.get_node("Body/Refresh"));_click(overlay.get_node("Panel/Refresh/Free"));await _settle()
	_check(not overlay.visible and op.snapshot().main.recruitment.ad_left==2,"free refresh updates candidates and daily quota")
	_click(page.get_node("Body/Refresh"));_click(overlay.get_node("Panel/Refresh/Paid"));await _settle()
	_check(not overlay.visible and op.snapshot().diamonds==950,"paid refresh deducts displayed price")
	_click(page.get_node("Body/Recruit"));await create_timer(5.5).timeout
	_check(overlay.kind=="success" and op.snapshot().inventory["item.10001"]==2,"natural completion displays a single settled receipt")
	_outside();await _settle()
	_click(page.get_node("Body/Finish"));_click(overlay.get_node("Panel/Finish/Remember"));_click(overlay.get_node("Panel/Finish/Accept"));await _settle()
	_click(page.get_node("Body/Recruit"));await _settle();_outside();_outside();await _settle()
	_click(page.get_node("Body/Finish"));await _settle()
	_check(not overlay.visible and op.snapshot().main.recruited.is_empty(),"same-day finish skips confirmation after checkbox")
	op._state.inventory["item.10001"]=0;_hud.render(op.snapshot())
	_click(page.get_node("Body/Recruit"));await _settle()
	_check(overlay.kind=="purchase","zero scroll draw opens ticket purchase")
	_outside();await _settle()
	if _failures.is_empty(): print("[OK] Recruitment real input, costs, skip, receipt, finish; 27 native captures")
	else:
		for failure in _failures: push_error(failure)
	_app.queue_free();await process_frame
	quit(0 if _failures.is_empty() else 1)

func _outside() -> void:
	var point := root.get_final_transform() * Vector2(root.get_visible_rect().size.x * 0.5,55)
	for pressed in [true,false]:
		var event := InputEventMouseButton.new();event.position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed
		Input.parse_input_event(event);Input.flush_buffered_events()

func _shot(state: String, dimensions: Vector2i) -> void:
	await _capture("recruit_%s_%d_%d" % [state,dimensions.x,dimensions.y])
