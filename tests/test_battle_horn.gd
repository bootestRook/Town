extends RefCounted

func fresh(): return preload("res://tests/test_town_heroes.gd").new().fresh(5123)
func summon(op, level: int = 1, sweep: bool = false, count: int = 1, confirmed: bool = false) -> Dictionary:
	return op.horn_command({"action":"summon", "level":level, "sweep":sweep, "count":count, "confirmed":confirmed})

func run(t: TestSupport) -> void:
	var op = fresh()
	var s: Dictionary = op._state
	var origin: Vector2 = op.horn.encounter.origin
	t.assert_true(op._simulation.navigation.passable(origin), "source boss spawn is walkable")
	t.assert_equal(op.horn.levels.size(), 30, "all thirty source boss levels")
	t.assert_equal(op.horn.levels[2].max_hp, 103617.0, "level two source HP")
	t.assert_equal(op.horn.levels[2].attack, 516.0, "level two source attack")
	t.assert_true(not summon(op,2).accepted, "locked boss cannot be summoned")
	t.assert_true(not summon(op,1,true).accepted, "sweep requires actual victory")
	t.assert_true(not op.upgrade(TownBattleHorn.BUILDING).accepted, "horn source dungeon upgrade condition")
	s.main.progress.dungeon = 12
	s.coins = 30000
	t.assert_true(op.upgrade(TownBattleHorn.BUILDING).accepted, "upgrade spends source price after source gate")
	t.assert_equal(s.coins,0,"upgrade exact price")
	t.assert_equal(s.buildings[TownBattleHorn.BUILDING],2,"real upgraded level")
	var positions: Array = s.heroes.map(func(h): return h.position)
	op.regions.sync_unlocked()
	var population: int = s.monsters.size()
	t.assert_true(summon(op).accepted,"free summon accepted")
	t.assert_equal(s.horn.free,3,"charge free attempt exactly once")
	t.assert_equal(s.monsters.size(),0,"ordinary monsters removed during gathering")
	t.assert_equal(s.heroes.map(func(h): return h.position),positions,"summon never teleports heroes")
	t.assert_true(not summon(op).accepted,"no concurrent boss")
	t.assert_true(not op.main_command({"type":"hero_team","hero":s.main.team[0]}).accepted,"participants cannot be withdrawn")
	t.assert_true(not op.main_command({"type":"hero_dispatch", "assignments":{s.main.team[0]:"town"}}).accepted,"participants cannot escape by city dispatch")
	t.assert_true(not op.main_command({"type":"battle_start","mode":"dungeon"}).accepted,"expedition cannot overlap boss")
	op.advance(2)
	t.assert_true(s.heroes.map(func(h): return h.position) != positions,"participants follow real paths")
	t.assert_true(s.monsters.is_empty(),"no boss damage during preparation")
	t.assert_true(op.horn_command({"action":"cancel"}).accepted,"cancel gathering")
	t.assert_equal(s.horn.free,4,"cancel refunds free count")
	t.assert_equal(s.monsters.size(),population,"normal population resumes")
	t.assert_true(not op.horn_command({"action":"cancel"}).accepted,"double refund rejected")
	t.assert_true(not summon(op).accepted,"five second cooldown")
	op.advance(5.1)
	s.horn.free = 0
	s.inventory["item.12001"] = 1
	t.assert_true(summon(op).accepted,"ticket used after free exhaustion")
	t.assert_equal(s.inventory["item.12001"],0,"ticket charged")
	op.horn_command({"action":"cancel"})
	t.assert_equal(s.inventory["item.12001"],1,"ticket refunded")
	op.advance(5.1)
	s.inventory["item.12001"] = 0
	var diamonds: int = s.diamonds
	t.assert_true(summon(op).get("confirm",false),"diamond summon asks confirmation")
	t.assert_equal(s.diamonds,diamonds,"confirmation never charges")
	t.assert_true(summon(op,1,false,1,true).accepted,"confirmed diamond summon")
	t.assert_equal(s.diamonds,diamonds-50,"source first paid cost")
	op.horn_command({"action":"cancel"})
	t.assert_equal(s.diamonds,diamonds,"diamond refund")
	t.assert_equal(s.horn.paid,0,"paid price step refund")
	_gather_and_combat(t)
	_day_and_sweep(t)
	var natural = fresh()
	summon(natural)
	for second in 630:
		natural.advance(1)
		if natural._state.horn.phase == "idle": break
	t.assert_equal(natural._state.horn.result,"won","real starting team can defeat first boss without fixture damage")

func _gather_and_combat(t) -> void:
	var op = fresh()
	var s: Dictionary = op._state
	summon(op)
	for h: Dictionary in s.heroes:
		h.position = op.horn.encounter._goals[h.id]
		h.path.clear()
	op.advance(0.1)
	t.assert_equal(s.horn.ready.size(),3,"arrival count comes from positions")
	t.assert_true(s.horn.remaining <= 3.0,"everyone ready shortens countdown to three")
	op.advance(3.1)
	t.assert_equal(s.horn.phase,"fight","prepare transitions to fight")
	t.assert_equal(s.monsters.size(),1,"one real boss actor replaces field population")
	t.assert_equal(s.monsters[0].visual,"boss1","original giant art bound")
	var start_hp: float = s.monsters[0].hp
	op.advance(6)
	t.assert_true(s.monsters[0].hp < start_hp,"existing attacks really damage boss")
	t.assert_true(s.heroes.any(func(h): return h.needs.hp < 100),"boss really attacks participants")
	s.monsters[0].hp = 0
	op.advance(0.1)
	t.assert_equal(s.horn.result,"won","boss death settles victory")
	t.assert_equal(s.horn.cleared,1,"victory unlocks sweep")
	t.assert_equal(s.horn.free,3,"victory keeps attempt consumed")
	t.assert_true(not s.horn.chest.is_empty(),"victory drops actual chest")
	var coins: int = s.coins
	t.assert_true(op.horn_command({"action":"chest"}).accepted,"chest claims rewards")
	t.assert_equal(s.coins,coins+12800,"source level one ordinary chest coin award")
	t.assert_true(not op.horn_command({"action":"chest"}).accepted,"chest cannot be claimed twice")
	op.advance(5.1)
	summon(op)
	op.advance(30.1)
	t.assert_equal(s.horn.phase,"fight","thirty second maximum preparation")
	s.horn.remaining = 0.05
	op.advance(0.1)
	t.assert_equal(s.horn.result,"timeout","combat timeout ends and refunds")
	t.assert_equal(s.horn.free,3,"timeout refunds only current attempt")
	op.advance(5.1)
	summon(op)
	op.advance(30.1)
	for h: Dictionary in s.heroes: h.needs.hp = 0
	op.advance(0.1)
	t.assert_equal(s.horn.result,"lost","all participants down settles defeat")
	t.assert_equal(s.horn.free,3,"failure refund")

func _day_and_sweep(t) -> void:
	var op = fresh()
	var s: Dictionary = op._state
	op.horn.set_day(100 * 86400)
	summon(op)
	op.horn.set_day(101 * 86400)
	op.horn_command({"action":"cancel"})
	t.assert_equal(s.horn.free,4,"cross-day refund never exceeds daily four")
	op.advance(5.1)
	s.horn.cleared = 1
	s.inventory["item.12001"] = 10
	t.assert_true(summon(op,1,true,5).accepted,"five sweep sequence accepted")
	op.advance(1.6)
	t.assert_equal(s.horn.phase,"fight","source sweep spawns boss after 1.5 seconds")
	op.advance(0.4)
	t.assert_equal(s.horn.result,"won","source sweep defeats boss after 0.3 seconds")
	t.assert_equal(s.horn.queue,4,"four queued attempts remain")
	op.advance(29)
	t.assert_equal(s.horn.queue,0,"five sweeps complete sequentially")
	t.assert_equal(s.horn.free,0,"sweep consumes four daily free attempts")
	t.assert_equal(s.inventory["item.12001"],9,"fifth sweep consumes one ticket")
	t.assert_true(s.horn.chest.is_empty(),"sweep collects each chest")
	op.advance(5.1)
	s.horn.free = 0
	s.inventory["item.12001"] = 0
	s.diamonds = 1050
	var coins: int = s.coins
	t.assert_true(summon(op,1,true,5).get("confirm",false),"paid batch quotes total before starting")
	t.assert_equal(s.diamonds,1050,"batch quote never precharges")
	t.assert_true(summon(op,1,true,5,true).accepted,"single confirmation authorizes exact paid batch")
	op.advance(32)
	t.assert_equal(s.horn.queue,0,"confirmed paid batch completes all five")
	t.assert_equal(s.diamonds,300,"paid batch charges 50+100+150+200+250")
	t.assert_equal(s.coins,coins+64000,"all five paid sweep chests settled")
