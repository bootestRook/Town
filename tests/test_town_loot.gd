extends RefCounted

func fresh(seed_value: int = 47115):
	return preload("res://tests/test_town_heroes.gd").new().fresh(seed_value)

func run(t: TestSupport) -> void:
	_distribution(t)
	_pickup(t)
	_lifetimes(t)
	_references(t)
	_boss(t)
	_natural(t)

func _distribution(t: TestSupport) -> void:
	var op = fresh()
	var s: Dictionary = op._state
	var combat = op._simulation.combat
	var monster: Dictionary = s.monsters[0]
	var a: Dictionary = s.heroes[0]
	var b: Dictionary = s.heroes[1]
	var a_gold: int = a.wallet
	var b_gold: int = b.wallet
	var other: int = s.heroes[2].wallet
	var impact: String = combat.sequence.definitions[a.visual].impact
	combat.sequence.impact(a, monster, s, combat, op, impact, 1)
	combat.sequence.impact(b, monster, s, combat, op, impact, 1)
	combat.sequence.impact(a, monster, s, combat, op, impact, 1)
	t.assert_equal(monster.contributors, [b.id,a.id], "source participants unique in last-hit order")
	combat.defeat(monster, a, op)
	t.assert_equal(a.wallet-a_gold,500,"killer receives equal gold share")
	t.assert_equal(b.wallet-b_gold,500,"earlier contributor receives gold share")
	t.assert_equal(s.heroes[2].wallet,other,"nonparticipant receives no hero reward")
	t.assert_equal(a.experience,25,"source 50 experience split between contributors")
	t.assert_equal(b.experience,25,"experience is not last-hit exclusive")
	var snapshot: Dictionary = op.snapshot()
	combat.defeat(monster, a, op)
	t.assert_equal(s.ground_drops,snapshot.ground_drops,"repeat death never rerolls ground reward")
	t.assert_equal(a.wallet,a_gold+500,"repeat death never duplicates hero gold")
	for hero: Dictionary in s.heroes: hero.bag["item.20101"] = 0
	combat.loot.grant_heroes({"item.20101":8},s.heroes,monster.position,0,0,op)
	t.assert_equal(s.heroes.reduce(func(sum,h):return sum+h.bag["item.20101"],0),8,"distribution conserves quantities with remainder")
	t.assert_true(s.heroes.all(func(h):return h.bag["item.20101"]>=2),"whole groups distributed equally before random remainder")
	op.gain_hero_experience(a.id,75)
	t.assert_equal(a.level,2,"source level one threshold automatically upgrades locally")
	t.assert_equal(a.experience,0,"level threshold consumed once")
	t.assert_equal(s.main.roster[0].level,2,"map and hero detail share level")
	combat.population.respawn(monster,s)
	t.assert_true(monster.contributors.is_empty(),"respawn never inherits previous participants")

func _pickup(t: TestSupport) -> void:
	var op = fresh()
	var s: Dictionary = op._state
	var loot = op._simulation.combat.loot
	var before: int = s.inventory["item.20101"]
	var bags: Array = s.heroes.map(func(h):return h.bag.duplicate())
	loot.spawn({"item.20101":2},Vector2(200,400),false)
	var id: int = s.ground_drops[0].id
	t.assert_equal(s.inventory["item.20101"],before,"spawn does not silently credit player inventory")
	t.assert_true(not op.pickup_drop(id).accepted,"jumping drop is not yet clickable")
	s.time += 0.5
	t.assert_true(op.pickup_drop(id).accepted,"landed drop grants player item")
	t.assert_equal(s.inventory["item.20101"],before+2,"exact drop count enters public inventory")
	t.assert_true(s.ground_drops.is_empty(),"picked drop removed immediately")
	t.assert_true(not op.pickup_drop(id).accepted,"rapid repeated pickup rejected")
	t.assert_true(not op.pickup_drop(-100).accepted,"unknown drop ID rejected")
	t.assert_equal(s.heroes.map(func(h):return h.bag),bags,"player pickup never changes hero private bags")
	loot.spawn({"item.20101":1},Vector2.ZERO,false)
	s.time += 0.5
	id = s.ground_drops[0].id
	s.inventory["item.20101"] = loot.items["item.20101"].max_count
	t.assert_true(not op.pickup_drop(id).accepted,"full item stack rejects pickup")
	t.assert_equal(s.ground_drops.size(),1,"rejected pickup keeps drop available")
	s.inventory["item.20101"] -= 1
	t.assert_true(op.pickup_drop(id).accepted,"pickup succeeds after space is available")
	var copy: Dictionary = op.snapshot()
	copy.inventory["item.20101"] = 0
	t.assert_equal(s.inventory["item.20101"],loot.items["item.20101"].max_count,"snapshots cannot mutate inventory")

func _lifetimes(t: TestSupport) -> void:
	var op = fresh()
	var s: Dictionary = op._state
	var loot = op._simulation.combat.loot
	loot.spawn({"item.20101":2},Vector2.ZERO,false)
	loot.spawn({"item.20102":3},Vector2.ZERO,true)
	var normal: int = s.ground_drops[0].id
	s.time = 60
	t.assert_true(not op.pickup_drop(normal).accepted,"expired drop rejected even before cleanup tick")
	loot.step()
	t.assert_equal(s.ground_drops.size(),1,"only regular drops expire at sixty seconds")
	t.assert_equal(s.missed_loot["item.20101"],2,"missed quantity recorded without granting")
	s.time = 300
	loot.step()
	t.assert_true(s.ground_drops.is_empty(),"boss drops expire at three hundred seconds")
	loot.step()
	t.assert_equal(s.missed_loot["item.20102"],3,"expiration counted once")
	t.assert_true(s.loot_cues.is_empty(),"temporary cue queue has bounded retention")

func _references(t: TestSupport) -> void:
	var first = fresh(181)
	var second = fresh(181)
	var a = first._simulation.combat.loot
	var b = second._simulation.combat.loot
	for i in 50:
		t.assert_equal(a.roll("wolf","hero"),b.roll("wolf","hero"),"seeded hero loot reproducible")
		t.assert_equal(a.roll("wolf","ground"),b.roll("wolf","ground"),"seeded player loot reproducible")
	var row: Dictionary = a._drops[0]
	var saved: Dictionary = row.duplicate()
	row.item = "item.missing"
	t.assert_true(not a.validation_error().is_empty(),"invalid item reference diagnosed")
	row.item = saved.item
	row.maximum = 0
	t.assert_true(not a.validation_error().is_empty(),"reversed quantity range diagnosed")
	row.maximum = saved.maximum
	row.chance = 10001
	t.assert_true(not a.validation_error().is_empty(),"out-of-range probability diagnosed")
	t.assert_true(b.validation_error().is_empty(),"other instance definitions remain immutable")
	var definitions: Dictionary = first.main_definitions()
	for id: String in b.items:
		t.assert_true(definitions.bag_items.has(id),"every obtainable item can appear in hero backpack")

func _boss(t: TestSupport) -> void:
	var op = fresh()
	var s: Dictionary = op._state
	op.horn_command({"action":"summon","level":1,"confirmed":true})
	var inventory: Dictionary = s.inventory.duplicate()
	op.horn.finish("won",op)
	for id: int in s.horn.rewards:
		var key := "item."+str(id)
		t.assert_equal(s.inventory.get(key,0),inventory.get(key,0),"actual boss ground rewards await player pickup")
	t.assert_true(s.ground_drops.all(func(d):return d.lifetime==300),"boss drops use source lifetime")
	var count: int = s.ground_drops.size()
	op.horn.finish("won",op)
	t.assert_equal(s.ground_drops.size(),count,"repeat boss completion cannot duplicate drops")

func _natural(t: TestSupport) -> void:
	var op = fresh()
	for i in 900:
		op.advance(0.5)
		if not op._state.ground_drops.is_empty(): break
	t.assert_true(not op._state.ground_drops.is_empty(),"natural hero path attack death creates clickable loot")
	t.assert_true(op._state.heroes.any(func(h):return h.kills>0),"loot follows a real kill")
	t.assert_true(op._state.heroes.any(func(h):return h.bag.values().any(func(n):return n>0)),"natural kills supply hero bag")
