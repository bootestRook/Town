class_name TownSalvage
extends RefCounted

var sites: Array = []
var rewards: Dictionary = {}
var rules: Dictionary = {}

func configure(data) -> void:
	sites = data.rows("main_sea").duplicate(true)
	for row: Dictionary in data.rows("main_sea_rewards"): rewards[int(row.source_id)] = row.duplicate(true)
	for row: Dictionary in data.rows("main_rules"): rules[row.id] = row.value

func initialize(main: Dictionary) -> void:
	main["salvage"] = {"power": rules["rules.1228"], "clock": 0.0, "jobs": {}, "records": []}

func advance(state: Dictionary, seconds: float) -> void:
	var sea: Dictionary = state.main.salvage
	if sea.power < rules["rules.1228"]:
		sea.clock += seconds
		while sea.clock >= rules["rules.1229"]:
			sea.clock -= rules["rules.1229"]
			sea.power = mini(rules["rules.1228"], sea.power + rules["rules.1230"])
	else: sea.clock = 0.0
	for job: Dictionary in sea.jobs.values(): job.remaining = maxf(0.0, job.remaining - seconds)

func command(state: Dictionary, command: Dictionary) -> Dictionary:
	var matches := sites.filter(func(s): return s.id == command.get("site", ""))
	if matches.is_empty(): return TownOperations.reject("遗迹不存在")
	var site: Dictionary = matches[0]
	var sea: Dictionary = state.main.salvage
	match command.type:
		"sea_start":
			if sea.jobs.has(site.id): return TownOperations.reject("该遗迹正在打捞")
			if state.main.expedition_team.is_empty(): return TownOperations.reject("请先配置守卫队伍")
			if sea.power < site.cost: return TownOperations.reject("打捞体力不足")
			sea.power -= int(site.cost)
			sea.jobs[site.id] = {"remaining": float(site.seconds), "reward": rewards[state.city_level][["low", "middle", "high"][site.source_id - 1]], "team": state.main.expedition_team.duplicate()}
		"sea_claim":
			if not sea.jobs.has(site.id) or sea.jobs[site.id].remaining > 0: return TownOperations.reject("打捞尚未完成")
			var job: Dictionary = sea.jobs[site.id]
			TownExpedition.grant(state, job.reward)
			sea.records.push_front({"site": site.display_name, "reward": job.reward})
			sea.jobs.erase(site.id)
			state.main.progress["modes.5"] = state.main.progress.get("modes.5", 0) + 1
		_:
			return TownOperations.reject("无效打捞操作")
	return {"accepted": true}
