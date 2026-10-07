class_name Stats
extends RefCounted
## Turns level + gear + skills + house into the numbers combat uses.

const BASE_HP := 100.0
const HP_PER_LEVEL := 11.0
const UNARMED_DMG := 5.0
const MAX_LEVEL := 30


static func xp_needed(level: int) -> int:
	return int(round(45.0 + level * 38.0 + level * level * 4.5))


static func compute() -> Dictionary:
	var s := {
		"max_hp": BASE_HP + HP_PER_LEVEL * (Game.level - 1) + float(Game.house_perk("hp")),
		"w_dmg": UNARMED_DMG, "dmg_pct": 0.0, "crit": 5.0, "crit_dmg": 150.0, "atk_speed": 0.0, "armor": 0.0, "move": 0.0,
		"lifesteal": 0.0, "luck": 0.0, "regen": 0.0, "throw_dmg": 0.0, "roll_cd": 0.0, "knock": 0.0,
		"burn": 0.0, "poison": 0.0, "stun": 0.0, "thorns": 0.0, "xp_pct": 0.0, "gold_pct": 0.0, "hp_pct": 0.0,
		"speed": 1.6, "reach": 1.9, "arc": 80.0, "swing": "overhead", "weapon": "", "knock_base": 2.5,
		"ranged": false, "aoe": 0.0, "uniques": [], "bottles": 3, "grog": 1 + int(Game.house_perk("grog")),
	}
	s["xp_pct"] += float(Game.house_perk("xp"))
	var hp_flat := 0.0
	for slot in ItemDB.SLOTS:
		var it: Variant = Game.equipped.get(slot)
		if it == null:
			continue
		var st: Dictionary = (it as Dictionary)["stats"]
		for k in st:
			if k == "w_dmg":
				s["w_dmg"] = st[k]
			elif k == "hp":
				hp_flat += st[k]
			else:
				s[k] = float(s.get(k, 0.0)) + float(st[k])
		if (it as Dictionary).get("unique", "") != "":
			s["uniques"].append((it as Dictionary)["unique"])
		if slot == "weapon":
			var w: Dictionary = ItemDB.WEAPONS[(it as Dictionary)["base"]]
			s["speed"] = w["speed"]
			s["reach"] = w["reach"]
			s["arc"] = w["arc"]
			s["swing"] = w["swing"]
			s["weapon"] = (it as Dictionary)["base"]
			s["crit"] += float(w["crit"]) * 100.0 - 5.0
			s["knock_base"] = w["knock"]
			s["ranged"] = w.get("ranged", false)
			s["aoe"] = w.get("aoe", 0.0)
	s["max_hp"] = (s["max_hp"] + hp_flat) * (1.0 + s["hp_pct"] / 100.0)
	# skills
	if Game.has_skill("quick_feet"):
		s["move"] += 12.0
	if Game.has_skill("roll_master"):
		s["roll_cd"] += 30.0
	if Game.has_skill("power_strikes"):
		s["dmg_pct"] += 12.0
	if Game.has_skill("keen_edge"):
		s["crit"] += 8.0
		s["crit_dmg"] += 25.0
	if Game.has_skill("bloodthirst"):
		s["lifesteal"] += 4.0
	if Game.has_skill("bandolier"):
		s["bottles"] += 3
	if Game.has_skill("bomb_maker"):
		s["throw_dmg"] += 40.0
		s["bottles"] += 2
	if Game.has_skill("lucky"):
		s["luck"] += 15.0
	if Game.has_skill("pickpocket"):
		s["gold_pct"] += 25.0
	if Game.has_skill("tough"):
		s["max_hp"] *= 1.2
	if Game.has_skill("grog_lover"):
		s["grog"] += 1
	s["bottles"] += int(Game.perk_bottles)
	s["atk_rate"] = s["speed"] * (1.0 + s["atk_speed"] / 100.0)
	s["dmg"] = s["w_dmg"] * (1.0 + s["dmg_pct"] / 100.0)
	s["dps"] = s["dmg"] * s["atk_rate"] * (1.0 + minf(s["crit"], 100.0) / 100.0 * (s["crit_dmg"] / 100.0 - 1.0))
	s["move_mult"] = 1.0 + s["move"] / 100.0
	s["armor_red"] = s["armor"] / (s["armor"] + 60.0)           # diminishing returns, never 100%
	s["roll_cd_mult"] = clampf(1.0 - s["roll_cd"] / 100.0, 0.3, 1.0)
	return s


static func has_unique(s: Dictionary, effect: String) -> bool:
	return (s["uniques"] as Array).has(effect)


## Quick DPS estimate for an item as if it were equipped (used for comparisons).
static func preview_dps(item: Dictionary) -> float:
	var saved: Variant = Game.equipped.get(item["slot"])
	Game.equipped[item["slot"]] = item
	var s := compute()
	Game.equipped[item["slot"]] = saved
	return s["dps"]


static func preview_stats(item: Dictionary) -> Dictionary:
	var saved: Variant = Game.equipped.get(item["slot"])
	Game.equipped[item["slot"]] = item
	var s := compute()
	Game.equipped[item["slot"]] = saved
	return s
