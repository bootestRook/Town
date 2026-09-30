extends RefCounted

func run(test: TestSupport) -> void:
	var data := DataRegistry.new()
	assert(data.load_default().is_empty())
	var skills := TownExpeditionSkills.new()
	skills.configure(data,RngSet.new(6619).stream("town.expedition"))
	var combat := skills.combat
	combat.rules[1077] = 1.0
	combat.rules[1078] = 1.0
	var source: Dictionary = data.rows("main_heroes")[0].duplicate(true)
	source.critical = 0
	source.element = 1
	var actor := _actor(skills,source,"a","1000;1|1003;1")
	var target := _actor(skills,source,"b","1000;1")
	test.assert_equal(combat.base_damage(actor,target),1200.0,"source base formula without defense")
	test.assert_equal(combat.damage(actor,target,2.4,false),2880.0,"source skill multiplier")
	target.hp = target.max_hp
	target.element = 3
	test.assert_equal(combat.damage(actor,target,1,false),1440.0,"fire restrains wind by source 20 percent")
	target.element = 1
	target.hp = target.max_hp
	actor.properties.critical = 10000
	actor.properties.bonus = 15000
	test.assert_equal(combat.damage(actor,target,1,true),1800.0,"guaranteed critical uses source bonus")
	actor.properties.critical = 0
	actor.properties.hit = -combat.rules[1174]
	test.assert_equal(combat.damage(actor,target,1,true),0.0,"zero hit chance misses")
	actor.properties.hit = source.hit
	var defense_hero := _actor(skills,source,"c","1000;1|1003;1|3001;1")
	defense_hero.defense = 1000
	var plain := _actor(skills,source,"d","1000;1")
	plain.defense = 1000
	test.assert_true(combat.base_damage(actor,defense_hero) < combat.base_damage(actor,plain),"source defense passive affects incoming damage")
	var health_hero := _actor(skills,source,"e","1000;1|1003;1|3005;1")
	test.assert_equal(health_hero.max_hp,11700.0,"source 17 percent max HP passive")
	var invincible := _actor(skills,source,"f","1000;1|1003;1|3129;1")
	invincible.hp = 4000
	combat.tick(invincible)
	test.assert_equal(invincible.invincible_remaining,3.0,"source low HP invincibility duration")
	test.assert_equal(combat.damage(actor,invincible,1,false),0.0,"invincibility blocks damage")
	for i in 61: combat.tick(invincible)
	test.assert_true(combat.damage(actor,invincible,1,false)>0,"invincibility expires while cooldown remains")
	combat.apply_buff(actor,target,2002,1)
	test.assert_true(not combat.tick(target),"stun blocks actor action")
	for i in 55: combat.tick(target)
	test.assert_true(combat.tick(target),"stun expires on source duration")
	var dot_id := 0
	for row: Dictionary in combat.buffs.values():
		if row.kind == 16: dot_id = int(row.source_id); break
	combat.buffs[dot_id].chance = "10000"
	combat.apply_buff(actor,target,dot_id,1)
	var before: float = target.hp
	combat.tick(target)
	test.assert_true(target.hp < before,"source bleed deals periodic damage")
	var effects_before: int = target.effects.size()
	combat.apply_buff(actor,target,dot_id,1)
	test.assert_equal(target.effects.size(),effects_before,"same buff refreshes without unlimited stacking")
	var boss := _actor(skills,source,"boss","1000;1")
	boss.role = "boss"
	combat.apply_buff(actor,boss,2002,1)
	test.assert_true(boss.effects.is_empty(),"source boss immune flag rejects stun")
	var valid := true
	for row: Dictionary in data.rows("main_enemies"):
		for token: String in String(row.skills).split("|"):
			var id := int(token.get_slice(";",0))
			valid = valid and (skills.definitions.has(id) or combat.passives.has(id) or combat.buffs.has(id))
	test.assert_true(valid,"all imported enemy loadouts resolve to client skill tables")
	test.assert_true(skills.descriptions().has(3005) and skills.descriptions().has(2002),"UI includes passive and buff skill descriptions")
	var op := TownOperations.new(data,RngSet.new(331))
	var before_state := op.snapshot()
	test.assert_true(not op.main_command({"type":"battle_start","mode":"modes.6"}).accepted,"boss dungeon gate blocks summon")
	test.assert_equal(op.snapshot(),before_state,"failed summon consumes nothing")
	op._state.main.progress.dungeon = 12
	test.assert_true(not op.main_command({"type":"battle_start","mode":"modes.6"}).accepted,"boss summon requires source material")
	op._state.inventory["item.12001"] = 1
	var energy: int = op.snapshot().main.energy
	test.assert_true(op.main_command({"type":"battle_start","mode":"modes.6"}).accepted,"source boss material starts summon")
	test.assert_equal(op.snapshot().main.energy,energy,"boss has no invented energy fee")
	test.assert_equal(op.snapshot().inventory["item.12001"],0,"source summon material consumed")
	op._main_systems.advance(op._state,15)
	test.assert_equal(op.snapshot().main.battle.elapsed,0.0,"preparation does not consume battle clock")
	op.main_command({"type":"battle_close"})
	op.main_command({"type":"battle_start","mode":"modes.2"})
	op._state.main.battle.status = "won"
	test.assert_true(op.main_command({"type":"battle_claim"}).accepted,"fairy victory pays random egg reward")
	var eggs: int = op.snapshot().inventory.get("item.200001",0)
	test.assert_true(eggs in [2,3],"source first fairyland weighted quantity")
	op.main_command({"type":"battle_close"})
	test.assert_true(op.main_command({"type":"item_use","item":200001}).accepted,"earned egg flows to owned pet")
	actor = _actor(skills,source,"pet_owner","1000;1")
	target = _actor(skills,source,"pet_target","1000;1")
	skills.pets.prepare(actor,"101001;1")
	for i in 8: skills.pets.step(actor,[actor],[target],[])
	test.assert_equal(combat.prop(actor,"attack_up"),500.0,"source bee timed attack buff after delay")
	skills.pets.prepare(actor,"202001;1")
	for i in 3: skills.pets.trigger(actor,true,1000.0)
	test.assert_equal(actor.pet_actions[0].delay,-1.0,"pet followup waits for fourth normal")
	skills.pets.trigger(actor,true,1000.0)
	var pet_before: float = target.hp
	for i in 8: skills.pets.step(actor,[actor],[target],[])
	test.assert_true(target.hp < pet_before,"fourth normal triggers recorded damage pet attack")
	skills.pets.prepare(actor,"203001;1")
	skills.pets.trigger(actor,false,1000.0)
	pet_before = target.hp
	for i in 8: skills.pets.step(actor,[actor],[target],[])
	test.assert_equal(pet_before-target.hp,100.0,"flying cat copies source active damage fraction")
	skills.pets.prepare(actor,"200101;1")
	actor.defense = 1000
	pet_before = target.hp
	for i in 9: skills.pets.step(actor,[actor],[target],[])
	test.assert_equal(pet_before-target.hp,1200.0,"phoenix damage uses owner defense")
	var hp_before: float = actor.max_hp
	combat.apply_buff(actor,actor,116001,1)
	test.assert_true(actor.max_hp > hp_before,"elephant buff raises maximum HP")

func _actor(skills: TownExpeditionSkills, source: Dictionary, id: String, loadout: String) -> Dictionary:
	var actor := {"id":id,"name":id,"attack":1000.0,"defense":0.0,"max_hp":10000.0,"hp":10000.0}
	skills.prepare(actor,source,loadout)
	return actor
