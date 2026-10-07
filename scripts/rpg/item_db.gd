class_name ItemDB
extends RefCounted
## Procedural loot. An item is a plain Dictionary so it saves as JSON:
##   {uid, slot, base, name, rarity (0-4), ilvl, plus, stats: {key: value}, unique: "", value}
## stats are *final* numbers (already scaled by item level and rarity).

const RARITY := [
	{"name": "Common", "color": Color("#e4e4e4"), "mult": 1.0, "affixes": 0, "value": 1.0},
	{"name": "Uncommon", "color": Color("#5fe05f"), "mult": 1.12, "affixes": 1, "value": 2.4},
	{"name": "Rare", "color": Color("#4aa4ff"), "mult": 1.28, "affixes": 2, "value": 6.0},
	{"name": "Epic", "color": Color("#bc6aff"), "mult": 1.5, "affixes": 3, "value": 14.0},
	{"name": "Legendary", "color": Color("#ffa42a"), "mult": 1.85, "affixes": 4, "value": 34.0},
]
const SLOTS := ["weapon", "hat", "vest", "boots", "trinket"]
const SLOT_NAMES := {"weapon": "Weapon", "hat": "Hat", "vest": "Vest", "boots": "Boots", "trinket": "Trinket"}

## Weapons. speed = swings per second, reach in metres, arc in degrees.
const WEAPONS := {
	"opener": {"name": "Letter Opener", "dmg": 9.0, "speed": 2.5, "reach": 2.1, "arc": 55.0, "swing": "stab", "crit": 0.14, "knock": 1.6,
		"desc": "Fast. Pointy. Passive-aggressive."},
	"club": {"name": "Bonk Club", "dmg": 17.0, "speed": 1.25, "reach": 2.3, "arc": 95.0, "swing": "overhead", "crit": 0.05, "knock": 5.5,
		"desc": "Subtle as a brick."},
	"cleaver": {"name": "Mail Cleaver", "dmg": 12.0, "speed": 1.8, "reach": 2.3, "arc": 105.0, "swing": "slash", "crit": 0.08, "knock": 3.0,
		"desc": "Opens envelopes. And other things."},
	"pencil": {"name": "Giant Pencil", "dmg": 11.0, "speed": 1.6, "reach": 3.4, "arc": 36.0, "swing": "stab", "crit": 0.08, "knock": 2.2,
		"desc": "Long reach. Number 2 in your heart."},
	"pan": {"name": "Frying Pan", "dmg": 10.0, "speed": 1.7, "reach": 2.1, "arc": 115.0, "swing": "slash", "crit": 0.06, "knock": 3.6,
		"desc": "BONG. Blocks better than it should."},
	"stamp": {"name": "Stamp Hammer", "dmg": 25.0, "speed": 0.9, "reach": 2.5, "arc": 130.0, "swing": "slam", "crit": 0.06, "knock": 7.0, "aoe": 2.6,
		"desc": "APPROVED. Violently."},
	"stapler": {"name": "Heavy Stapler", "dmg": 8.0, "speed": 2.0, "reach": 18.0, "arc": 12.0, "swing": "shoot", "crit": 0.10, "knock": 1.0, "ranged": true,
		"desc": "Fires staples. Staples hurt."},
}

const ARMOR := {
	"hat": {
		"cap": {"name": "Postal Cap", "armor": 2.0, "hp": 6.0},
		"bag": {"name": "Paper Bag", "armor": 1.0, "hp": 16.0},
		"bucket": {"name": "Bucket", "armor": 4.5, "hp": 0.0},
		"cone": {"name": "Traffic Cone", "armor": 1.5, "move": 4.0},
		"crown": {"name": "Crown of Late Fees", "armor": 2.5, "hp": 10.0, "luck": 6.0},
	},
	"vest": {
		"leather": {"name": "Leather Vest", "armor": 5.0, "hp": 8.0},
		"sack": {"name": "Mail Sack", "armor": 2.0, "hp": 28.0},
		"cardboard": {"name": "Cardboard Armor", "armor": 3.5, "hp": 16.0},
		"bubble": {"name": "Bubble Wrap Plate", "armor": 7.5, "hp": 0.0},
		"chain": {"name": "Chain Letter Mail", "armor": 9.0, "hp": 10.0, "move": -3.0},
	},
	"boots": {
		"boots": {"name": "Sturdy Boots", "armor": 1.5, "move": 4.0},
		"skates": {"name": "Roller Skates", "armor": 0.0, "move": 11.0},
		"slippers": {"name": "Fuzzy Slippers", "armor": 0.5, "hp": 14.0, "move": 3.0},
		"waders": {"name": "Sewer Waders", "armor": 4.0, "move": 1.0},
	},
	"trinket": {
		"stamp": {"name": "Lucky Stamp", "luck": 10.0},
		"mailbox": {"name": "Tiny Mailbox", "hp": 18.0},
		"duck": {"name": "Rubber Duck", "hp": 12.0, "regen": 0.6},
		"envelope": {"name": "Golden Envelope", "gold_pct": 12.0},
		"pigeon": {"name": "Haunted Pigeon", "crit": 4.0, "luck": 5.0},
	},
}

## Affixes: id -> [stat key, min, max, label format]. Values scale with item level.
const AFFIXES := {
	"dmg_pct": ["dmg_pct", 6.0, 14.0, "+%d%% Damage"],
	"crit": ["crit", 3.0, 8.0, "+%d%% Crit Chance"],
	"crit_dmg": ["crit_dmg", 12.0, 30.0, "+%d%% Crit Damage"],
	"atk_speed": ["atk_speed", 5.0, 12.0, "+%d%% Attack Speed"],
	"hp": ["hp", 10.0, 24.0, "+%d Max HP"],
	"hp_pct": ["hp_pct", 5.0, 11.0, "+%d%% Max HP"],
	"armor": ["armor", 2.0, 5.0, "+%d Armor"],
	"move": ["move", 3.0, 7.0, "+%d%% Move Speed"],
	"lifesteal": ["lifesteal", 1.5, 3.5, "+%d%% Lifesteal"],
	"luck": ["luck", 6.0, 14.0, "+%d%% Loot Luck"],
	"regen": ["regen", 0.4, 1.2, "+%.1f HP/s Regen"],
	"throw_dmg": ["throw_dmg", 12.0, 28.0, "+%d%% Throwable Damage"],
	"roll_cd": ["roll_cd", 6.0, 14.0, "-%d%% Roll Cooldown"],
	"knock": ["knock", 10.0, 24.0, "+%d%% Knockback"],
	"burn": ["burn", 8.0, 16.0, "%d%% chance to Burn"],
	"poison": ["poison", 8.0, 16.0, "%d%% chance to Poison"],
	"stun": ["stun", 4.0, 9.0, "%d%% chance to Stun"],
	"thorns": ["thorns", 3.0, 8.0, "Reflects %d damage"],
	"xp_pct": ["xp_pct", 6.0, 14.0, "+%d%% XP"],
	"gold_pct": ["gold_pct", 8.0, 20.0, "+%d%% Copper"],
}
const WEAPON_AFFIXES := ["dmg_pct", "crit", "crit_dmg", "atk_speed", "lifesteal", "knock", "burn", "poison", "stun", "luck", "hp"]
const ARMOR_AFFIXES := ["hp", "hp_pct", "armor", "move", "regen", "roll_cd", "thorns", "luck", "xp_pct", "gold_pct", "throw_dmg", "crit", "dmg_pct", "lifesteal"]

## Legendary uniques. effect ids are interpreted by Stats/Combat.
const UNIQUES := [
	{"slot": "weapon", "base": "club", "name": "The Eviction", "effect": "shockwave", "text": "Every swing sends out a shockwave.", "stats": {"dmg_pct": 15.0, "knock": 30.0}},
	{"slot": "weapon", "base": "cleaver", "name": "Return To Sender", "effect": "coin_kill", "text": "Kills burst into copper.", "stats": {"dmg_pct": 10.0, "gold_pct": 25.0}},
	{"slot": "weapon", "base": "stapler", "name": "The Infinite Staple", "effect": "pierce", "text": "Staples pierce every enemy.", "stats": {"atk_speed": 20.0, "crit": 6.0}},
	{"slot": "weapon", "base": "pan", "name": "Pan of Destiny", "effect": "stun_crit", "text": "BONG: crits stun the target.", "stats": {"crit": 8.0, "hp": 30.0}},
	{"slot": "weapon", "base": "opener", "name": "The Dead Letter", "effect": "poison_crit", "text": "Crits poison. Allegedly it's a love letter.", "stats": {"crit": 10.0, "crit_dmg": 30.0}},
	{"slot": "weapon", "base": "pencil", "name": "Pencil of Pettiness", "effect": "chain", "text": "Hits arc to a nearby enemy.", "stats": {"dmg_pct": 12.0, "luck": 10.0}},
	{"slot": "weapon", "base": "stamp", "name": "Final Approval", "effect": "execute", "text": "Executes enemies below 20% HP.", "stats": {"dmg_pct": 18.0}},
	{"slot": "hat", "base": "crown", "name": "Crown of Mild Authority", "effect": "gold_aura", "text": "Enemies drop extra copper.", "stats": {"gold_pct": 35.0, "luck": 12.0}},
	{"slot": "vest", "base": "bubble", "name": "Wrap of Eternal Popping", "effect": "thorns_big", "text": "Hits against you pop back for damage.", "stats": {"armor": 10.0, "thorns": 14.0}},
	{"slot": "boots", "base": "skates", "name": "Skates of Express Delivery", "effect": "roll_fast", "text": "Rolling leaves a trail of sparks.", "stats": {"move": 12.0, "roll_cd": 25.0}},
	{"slot": "trinket", "base": "pigeon", "name": "Gerald, Haunted Pigeon", "effect": "pigeon", "text": "Gerald occasionally attacks for you.", "stats": {"crit": 6.0, "dmg_pct": 10.0, "luck": 8.0}},
	{"slot": "trinket", "base": "duck", "name": "The Duck of Second Chances", "effect": "revive", "text": "Revives you once per dungeon.", "stats": {"hp": 40.0, "regen": 1.0}},
]

const PREFIXES := {
	0: ["Rusty", "Dented", "Used", "Overdue", "Lumpy", "Soggy", "Damp", "Plain"],
	1: ["Sturdy", "Decent", "Polished", "Fresh", "Stamped", "Registered"],
	2: ["Sharp", "Gilded", "Haunted", "Express", "Certified", "Premium"],
	3: ["Cursed", "Spectral", "Roaring", "Dastardly", "Imperial", "Overnight"],
	4: ["Mythic", "Grubnik-Approved", "Unpaid-For", "Eldritch", "Forbidden"],
}
const SUFFIXES := ["of Pettiness", "of Unpaid Bills", "of Mild Inconvenience", "of Return to Sender", "of the Landlord", "of Bad Directions",
	"of Late Fees", "of Fine Print", "of Questionable Origin", "of Express Shipping", "of Many Staples", "of the Dead Letter Office",
	"of Last Resort", "of Insufficient Postage", "of Great Annoyance"]
const FLAVOR := [
	"Smells faintly of old mail.", "Previous owner: a very tired goblin.", "Do not ask where it's been.", "Warranty void. Everything is void.",
	"It hums when you're not looking.", "Handle with care. Or don't.", "Found in the lost-and-found of the underworld.",
]

static var _uid := 1


static func rarity_color(r: int) -> Color:
	return RARITY[clampi(r, 0, 4)]["color"]


static func rarity_name(r: int) -> String:
	return RARITY[clampi(r, 0, 4)]["name"]


static func roll_rarity(rng: RandomNumberGenerator, luck := 0.0, boost := 0.0) -> int:
	# luck in percent. Base odds: 62 / 24 / 9.5 / 3.5 / 1.0, tilted up by luck and boost
	var l := 1.0 + luck / 100.0 + boost
	var w := [62.0 / l, 24.0, 9.5 * l, 3.5 * l * l, 1.0 * l * l * l]
	var tot := 0.0
	for x in w:
		tot += x
	var r := rng.randf() * tot
	for i in 5:
		r -= w[i]
		if r <= 0.0:
			return i
	return 0


static func _scale(ilvl: int) -> float:
	return 1.0 + 0.11 * float(ilvl - 1)


static func _next_uid() -> int:
	_uid += 1
	return _uid * 1000 + randi() % 1000


## Roll an item. slot "" = random. rarity -1 = roll it.
static func roll(ilvl: int, rng: RandomNumberGenerator, slot := "", rarity := -1, luck := 0.0) -> Dictionary:
	if slot == "":
		slot = "weapon" if rng.randf() < 0.34 else SLOTS[1 + rng.randi() % 4]
	if rarity < 0:
		rarity = roll_rarity(rng, luck)
	var sc := _scale(ilvl)
	var rar: Dictionary = RARITY[rarity]
	var it := {"uid": _next_uid(), "slot": slot, "rarity": rarity, "ilvl": ilvl, "plus": 0, "stats": {}, "unique": "", "base": "", "name": "", "flavor": FLAVOR[rng.randi() % FLAVOR.size()]}
	# legendary: chance to be a hand-made unique
	if rarity == 4:
		var pool: Array = []
		for u in UNIQUES:
			if u["slot"] == slot:
				pool.append(u)
		if not pool.is_empty() and rng.randf() < 0.6:
			var u: Dictionary = pool[rng.randi() % pool.size()]
			it["base"] = u["base"]
			it["name"] = u["name"]
			it["unique"] = u["effect"]
			it["unique_text"] = u["text"]
			_apply_base(it, sc, rar)
			for k in u["stats"]:
				it["stats"][k] = float(it["stats"].get(k, 0.0)) + float(u["stats"][k]) * (1.0 + 0.04 * ilvl)
			it["value"] = _value(it)
			return it
	var base_keys: Array
	if slot == "weapon":
		base_keys = WEAPONS.keys()
	else:
		base_keys = (ARMOR[slot] as Dictionary).keys()
	it["base"] = base_keys[rng.randi() % base_keys.size()]
	_apply_base(it, sc, rar)
	var pool2: Array = (WEAPON_AFFIXES if slot == "weapon" else ARMOR_AFFIXES).duplicate()
	if slot == "trinket":
		pool2 = ARMOR_AFFIXES.duplicate()
	for i in range(pool2.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Variant = pool2[i]
		pool2[i] = pool2[j]
		pool2[j] = tmp
	var picked: Array = []
	for i in int(rar["affixes"]):
		if i >= pool2.size():
			break
		var aid: String = pool2[i]
		var a: Array = AFFIXES[aid]
		var v: float = lerpf(a[1], a[2], rng.randf()) * (1.0 + 0.045 * ilvl) * (0.9 + 0.1 * rarity)
		if aid in ["burn", "poison", "stun", "lifesteal", "roll_cd", "crit"]:
			v = minf(v, 35.0)
		it["stats"][a[0]] = float(it["stats"].get(a[0], 0.0)) + v
		picked.append(aid)
	it["name"] = _make_name(it, picked, rng)
	it["value"] = _value(it)
	return it


static func _apply_base(it: Dictionary, sc: float, rar: Dictionary) -> void:
	var slot: String = it["slot"]
	var base: String = it["base"]
	var m: float = rar["mult"]
	if slot == "weapon":
		var w: Dictionary = WEAPONS[base]
		it["stats"]["w_dmg"] = float(w["dmg"]) * sc * m
	else:
		var a: Dictionary = (ARMOR[slot] as Dictionary)[base]
		for k in a:
			if k == "name":
				continue
			var v: float = float(a[k])
			var scaled: float = v
			if k in ["armor", "hp"]:
				scaled = v * (1.0 + 0.1 * float(it["ilvl"] - 1)) * (1.0 + 0.1 * float(it["rarity"]))
			else:
				scaled = v * (1.0 + 0.05 * float(it["rarity"]))
			it["stats"][k] = float(it["stats"].get(k, 0.0)) + scaled
	if it["name"] == "":
		it["name"] = base_name(it)


static func base_name(it: Dictionary) -> String:
	if it["slot"] == "weapon":
		return WEAPONS[it["base"]]["name"]
	return ((ARMOR[it["slot"]] as Dictionary)[it["base"]] as Dictionary)["name"]


static func _make_name(it: Dictionary, picked: Array, rng: RandomNumberGenerator) -> String:
	var r: int = it["rarity"]
	var n: String = base_name(it)
	var pre: Array = PREFIXES[r]
	var out := "%s %s" % [pre[rng.randi() % pre.size()], n]
	if r >= 2 and not " of " in n:
		out += " " + SUFFIXES[rng.randi() % SUFFIXES.size()]
	return out


static func _value(it: Dictionary) -> int:
	var r: Dictionary = RARITY[it["rarity"]]
	return int(round((8.0 + 6.0 * float(it["ilvl"])) * float(r["value"]) * (1.0 + 0.3 * float(it.get("plus", 0)))))


# ------------------------------------------------------------------ display

const STAT_LABEL := {
	"w_dmg": ["Damage", "%d"], "armor": ["Armor", "+%d"], "hp": ["Max HP", "+%d"], "move": ["Move Speed", "%+d%%"], "luck": ["Loot Luck", "+%d%%"],
	"regen": ["HP/s", "+%.1f"], "crit": ["Crit Chance", "+%d%%"], "crit_dmg": ["Crit Damage", "+%d%%"], "dmg_pct": ["Damage", "+%d%%"],
	"atk_speed": ["Attack Speed", "+%d%%"], "hp_pct": ["Max HP", "+%d%%"], "lifesteal": ["Lifesteal", "+%d%%"], "throw_dmg": ["Throwable Damage", "+%d%%"],
	"roll_cd": ["Roll Cooldown", "-%d%%"], "knock": ["Knockback", "+%d%%"], "burn": ["Burn Chance", "%d%%"], "poison": ["Poison Chance", "%d%%"],
	"stun": ["Stun Chance", "%d%%"], "thorns": ["Thorns", "%d"], "xp_pct": ["XP", "+%d%%"], "gold_pct": ["Copper", "+%d%%"],
}


static func stat_line(key: String, v: float) -> String:
	var d: Array = STAT_LABEL.get(key, [key, "%d"])
	var fmt: String = d[1]
	var num := fmt % (v if "." in fmt else int(round(v)))
	return "%s %s" % [num, d[0]]


## Lines for a tooltip. Weapon damage line includes DPS.
static func describe(it: Dictionary) -> Array:
	var lines: Array = []
	var slot: String = it["slot"]
	if slot == "weapon":
		var w: Dictionary = WEAPONS[it["base"]]
		var dmg: float = it["stats"].get("w_dmg", 0.0)
		var dps: float = dmg * float(w["speed"])
		lines.append("%d damage   (%.0f DPS)   %.1f swings/s" % [round(dmg), dps, w["speed"]])
		lines.append("Reach %.1fm  -  %s" % [w["reach"], w["desc"]])
	for k in it["stats"]:
		if k == "w_dmg":
			continue
		lines.append(stat_line(k, it["stats"][k]))
	if it.get("unique", "") != "":
		lines.append("UNIQUE: %s" % it.get("unique_text", ""))
	if it.get("plus", 0) > 0:
		lines.append("Enhanced +%d" % it["plus"])
	return lines


static func title(it: Dictionary) -> String:
	var plus: int = it.get("plus", 0)
	return "%s%s" % [it["name"], (" +%d" % plus) if plus > 0 else ""]


static func ilvl_for(depth_tier: int, floor_no: int, player_level: int) -> int:
	return maxi(1, int(round(depth_tier * 2.0 + floor_no + player_level * 0.25)))


## Enhance: +1 up to +5. Raises numeric stats by 8% each step.
static func enhance_cost(it: Dictionary) -> int:
	return int((30 + it["ilvl"] * 12) * (1 + it.get("plus", 0)) * (1.0 + 0.5 * it["rarity"]))


static func enhance(it: Dictionary) -> void:
	var plus: int = it.get("plus", 0)
	if plus >= 5:
		return
	for k in it["stats"]:
		it["stats"][k] = float(it["stats"][k]) * 1.08
	it["plus"] = plus + 1
	it["value"] = _value(it)
