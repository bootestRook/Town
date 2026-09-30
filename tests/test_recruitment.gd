extends RefCounted

func run(test: TestSupport) -> void:
	var op = preload("res://tests/test_main_systems.gd").new().fresh()
	var state: Dictionary = op._state
	var recruitment = op._main_systems.recruitment
	var original: Dictionary = state.duplicate(true)
	test.assert_true(not op.main_command({"type":"recruit"}).accepted, "zero tickets reject first draw")
	test.assert_equal(state.main.pool, original.main.pool, "rejected draw preserves candidates")
	for quantity in [-1,0,10000]: test.assert_true(not op.main_command({"type":"recruit_tickets","quantity":quantity}).accepted, "invalid ticket quantity rejected")
	test.assert_true(op.main_command({"type":"recruit_tickets","quantity":3}).accepted, "ticket purchase accepted")
	test.assert_equal(state.diamonds, original.diamonds-300, "tickets charge exactly 100 each")
	test.assert_equal(state.inventory["item.10001"], 3, "tickets reach existing bag inventory")
	state.main.pool = ["heroes.1008002", "heroes.1036003", "heroes.1005001"]
	state.main.recruited = []
	state.main.recruit_level = 3
	state.main.recruit_exp = 35
	state.main.recruit_total = 10
	var chance: Dictionary = recruitment.chances(state)
	test.assert_true(absf(chance["heroes.1008002"]-310.0/1010.0)<0.000001, "source blue conditional weight")
	test.assert_true(absf(chance["heroes.1036003"]-140.0/1010.0)<0.000001, "source purple conditional weight")
	var coins: int = state.diamonds
	var result: Dictionary = op.main_command({"type":"recruit"})
	test.assert_true(result.accepted and result.has("recruitment"), "draw returns authoritative receipt")
	test.assert_equal(state.diamonds, coins, "first draw does not spend diamonds")
	test.assert_equal(state.inventory["item.10001"], 2, "first draw spends one scroll")
	test.assert_equal(state.main.recruit_exp, 40, "draw grants five experience")
	test.assert_equal(recruitment.chances(state)[result.recruitment.hero], 0.0, "recruited candidate removed from probability")
	test.assert_true(result.recruitment.hero in result.recruitment.pool, "animation candidates retain awarded hero")
	# Reference after Andrew is drawn: 180 -> 125, weights 310:140.
	state.main.recruited = ["heroes.1005001"]
	chance = recruitment.chances(state)
	test.assert_true(absf(chance["heroes.1008002"]-310.0/450.0)<0.000001, "remaining source weights renormalize")
	test.assert_equal(recruitment.offer(state).original,180,"second draw uses highest remaining quality")
	test.assert_equal(recruitment.offer(state).amount,125,"daily discount matches reference rounding")
	state.diamonds = 0
	var before := state.duplicate(true)
	test.assert_true(not op.main_command({"type":"recruit"}).accepted,"second draw rejects insufficient diamonds")
	test.assert_equal(state.main,before.main,"insufficient funds leave recruitment atomic")
	state.diamonds = 5000
	result = op.main_command({"type":"recruit"})
	test.assert_equal(state.diamonds,4875,"second draw spends displayed discounted cost")
	test.assert_equal(state.main.daily.recruit_discount_1,1,"discount consumed once per day")
	op.main_command({"type":"recruit"})
	test.assert_equal(state.main.recruited.size(),0,"third draw automatically replaces batch")
	test.assert_equal(state.main.pool.size(),3,"automatic replacement has three unique candidates")
	test.assert_true(state.main.pool[0]!=state.main.pool[1] and state.main.pool[1]!=state.main.pool[2] and state.main.pool[0]!=state.main.pool[2],"batch candidates unique")
	test.assert_true(not op.main_command({"type":"recruit_finish"}).accepted,"cannot finish untouched batch")
	op.main_command({"type":"recruit"})
	before=state.duplicate(true)
	test.assert_true(op.main_command({"type":"recruit_finish","remember":true}).accepted,"finish replaces partially recruited batch")
	test.assert_equal(state.diamonds,before.diamonds,"finish batch is free")
	test.assert_true(recruitment.snapshot(state).finish_silent,"today checkbox stored in daily owner")
	for i in 3:
		test.assert_true(op.main_command({"type":"recruit_refresh","method":"ad"}).accepted,"three free refreshes accepted")
		recruitment.advance(state,1)
	test.assert_true(not op.main_command({"type":"recruit_refresh","method":"ad"}).accepted,"fourth free refresh blocked")
	coins=state.diamonds
	test.assert_true(op.main_command({"type":"recruit_refresh","method":"diamond"}).accepted,"paid refresh accepted")
	test.assert_equal(state.diamonds,coins-50,"refresh consumes fifty diamonds")
	state.main.recruit_refreshes=10
	test.assert_true(not op.main_command({"type":"recruit_refresh","method":"diamond"}).accepted,"per-visit refresh cap enforced")
	state.main.day_time=86399
	op._main_systems.advance(state,2)
	test.assert_true(not recruitment.snapshot(state).finish_silent,"next game day restores finish confirmation")
	test.assert_equal(recruitment.snapshot(state).ad_left,3,"next game day resets free refresh count")
	state.main.refresh_remaining=0.5
	op._main_systems.advance(state,1)
	test.assert_equal(state.main.recruit_refreshes,0,"timed ship arrival resets visit cap")
	test.assert_true(state.main.refresh_remaining>0,"timer creates a new batch automatically")
	# Force an existing hero: duplicate conversion changes fragment count, never duplicates roster.
	var id: String = state.main.roster[0].definition
	state.main.pool=[id];state.main.recruited=[];state.inventory["item.10001"]=2
	var roster_size: int = state.main.roster.size()
	var fragments := int(state.main.fragments.get(id,0))
	result=op.main_command({"type":"recruit"})
	test.assert_true(not result.recruitment.new,"owned hero produces duplicate receipt")
	test.assert_equal(state.main.roster.size(),roster_size,"duplicate leaves roster size unchanged")
	test.assert_equal(state.main.fragments[id],fragments+20,"duplicate grants source twenty fragments")
	var snapshot: Dictionary = op.snapshot()
	snapshot.main.recruitment.offer.amount=999
	test.assert_equal(recruitment.offer(state).amount,1,"UI offer snapshot cannot mutate domain")
	# New acquisition and the explicitly local wishlist rule share the real roster owner.
	op = preload("res://tests/test_main_systems.gd").new().fresh()
	state = op._state
	recruitment = op._main_systems.recruitment
	test.assert_true(not recruitment.wish_unlocked(state), "unowned wishlist hero remains locked")
	test.assert_true(not op.main_command({"type":"recruit_wish"}).accepted, "locked wishlist cannot activate")
	state.main.pool=["heroes.1075004"]
	state.inventory["item.10001"]=1
	state.main.recruit_exp=38
	roster_size=state.main.roster.size()
	result=op.main_command({"type":"recruit"})
	test.assert_true(result.recruitment.new, "new hero receipt differs from duplicate fragments")
	test.assert_equal(state.main.roster.size(),roster_size+1,"first acquisition enters owned roster")
	test.assert_equal(state.main.recruit_level,2,"source experience threshold advances ship level")
	test.assert_equal(state.main.recruit_exp,3,"experience overflow survives ship level increase")
	test.assert_true(recruitment.wish_unlocked(state),"acquired wishlist hero unlocks selection")
	test.assert_true(op.main_command({"type":"recruit_wish"}).accepted and state.main.recruit_wish,"owned wishlist selection toggles on")
	var wish_entry: Dictionary = recruitment.pool_entries.filter(func(e): return e.hero=="heroes.1075004")[0]
	test.assert_equal(recruitment._pool_weight(state,wish_entry),100.0,"wishlist activates otherwise zero-weight source entry")
	op.main_command({"type":"recruit_wish"})
	test.assert_equal(recruitment._pool_weight(state,wish_entry),0.0,"deselection restores original source pool exclusion")
	state.diamonds=49
	before=state.duplicate(true)
	test.assert_true(not op.main_command({"type":"recruit_refresh","method":"diamond"}).accepted,"paid refresh rejects insufficient diamonds")
	test.assert_equal(state,before,"failed refresh preserves all state")
