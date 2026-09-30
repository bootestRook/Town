class_name TownHeroNeeds
extends RefCounted

# Source c89_jhzl row 1: one defeated monster adds one magic, one power removes one.
# The existing local needs model uses a normalized 0..100 range.
const MAGIC_CAPACITY := 1100

static func purify(hero: Dictionary, state: Dictionary) -> void:
	var amount := mini(int(hero.needs.magic), int(state.main.energy))
	if amount <= 0: return
	hero.needs.magic -= amount
	state.main.energy -= amount

static func attack(hero: Dictionary) -> bool:
	if hero.needs.energy <= 0 or hero.needs.tired <= 0: return false
	consume_energy(hero, 0.32)
	return true

static func consume_energy(hero: Dictionary, amount: float) -> void:
	var capacity := 1.0 + TownEquipmentRules.total(hero.equipment, "energy_up") / 10000.0
	hero.needs.energy = maxf(0, hero.needs.energy - amount / capacity)

static func injured(hero: Dictionary) -> void:
	hero.needs.mood = maxf(0, hero.needs.mood - 0.2)

static func attack_multiplier(hero: Dictionary) -> float:
	return 0.9 if hero.needs.mood <= 0 else 1.0
