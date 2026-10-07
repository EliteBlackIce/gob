class_name MobDB
extends RefCounted
## Mob archetypes, per-theme spawn tables and tier scaling.

## ai: how it moves.  atk: what it does when in range.
const KINDS := {
	"skeleton": {"name": "Skeleton Clerk", "ai": "walk", "atk": "swing", "hp": 34.0, "dmg": 12.0, "speed": 3.3, "range": 1.9, "windup": 0.5, "cd": 1.3,
		"h": 1.8, "r": 0.45, "xp": 7, "model": "humanoid", "pack": 1},
	"archer": {"name": "Skeleton Sniper", "ai": "keep", "atk": "shoot", "hp": 24.0, "dmg": 9.0, "speed": 2.9, "range": 11.0, "keep": 7.0, "windup": 0.7, "cd": 2.1,
		"h": 1.8, "r": 0.42, "xp": 8, "model": "humanoid", "pack": 1, "proj_speed": 17.0},
	"rat": {"name": "Mail Rat", "ai": "walk", "atk": "swing", "hp": 13.0, "dmg": 6.0, "speed": 5.6, "range": 1.2, "windup": 0.22, "cd": 0.8,
		"h": 0.5, "r": 0.28, "xp": 3, "model": "quad", "pack": 3},
	"slime": {"name": "Soggy Slime", "ai": "hop", "atk": "contact", "hp": 42.0, "dmg": 9.0, "speed": 3.6, "range": 1.1, "windup": 0.0, "cd": 0.9,
		"h": 1.1, "r": 0.6, "xp": 6, "model": "blob", "pack": 1, "split": "slime_small"},
	"slime_small": {"name": "Soggy Slimelet", "ai": "hop", "atk": "contact", "hp": 14.0, "dmg": 5.0, "speed": 4.2, "range": 0.8, "windup": 0.0, "cd": 0.8,
		"h": 0.55, "r": 0.32, "xp": 2, "model": "blob", "pack": 1, "scale": 0.5},
	"bat": {"name": "Junk Mail Bat", "ai": "fly", "atk": "dive", "hp": 12.0, "dmg": 7.0, "speed": 6.0, "range": 1.2, "windup": 0.45, "cd": 2.2,
		"h": 0.5, "r": 0.28, "xp": 4, "model": "bat", "pack": 3, "hover": 2.0},
	"mushroom": {"name": "Spore Shroom", "ai": "keep", "atk": "lob", "hp": 38.0, "dmg": 8.0, "speed": 1.8, "range": 12.0, "keep": 8.0, "windup": 0.8, "cd": 2.8,
		"h": 1.3, "r": 0.5, "xp": 9, "model": "mushroom", "pack": 1, "proj_speed": 11.0},
	"intern": {"name": "Unpaid Intern", "ai": "walk", "atk": "swing", "hp": 74.0, "dmg": 19.0, "speed": 2.3, "range": 2.0, "windup": 0.85, "cd": 1.9,
		"h": 1.9, "r": 0.55, "xp": 12, "model": "humanoid", "pack": 1},
	"imp": {"name": "Pay-Cut Imp", "ai": "fly_keep", "atk": "shoot", "hp": 22.0, "dmg": 11.0, "speed": 4.2, "range": 14.0, "keep": 8.0, "windup": 0.6, "cd": 2.3,
		"h": 1.0, "r": 0.35, "xp": 9, "model": "humanoid", "pack": 1, "proj_speed": 12.0, "hover": 2.2, "aoe": 1.6, "scale": 0.85},
	"hound": {"name": "Overdue Hound", "ai": "charge", "atk": "dash", "hp": 48.0, "dmg": 17.0, "speed": 4.2, "range": 9.0, "windup": 0.7, "cd": 3.0,
		"h": 1.0, "r": 0.55, "xp": 11, "model": "quad", "pack": 1},
	"bomber": {"name": "Powder Pete", "ai": "walk", "atk": "explode", "hp": 22.0, "dmg": 26.0, "speed": 4.7, "range": 2.4, "windup": 0.9, "cd": 1.0,
		"h": 1.3, "r": 0.45, "xp": 8, "model": "keg", "pack": 1, "aoe": 3.4},
	"golem": {"name": "Rubble Clerk", "ai": "walk", "atk": "slam", "hp": 160.0, "dmg": 27.0, "speed": 2.0, "range": 3.0, "windup": 1.0, "cd": 3.2,
		"h": 2.6, "r": 0.85, "xp": 24, "model": "humanoid", "pack": 1, "aoe": 3.4, "scale": 1.05},
	"ghost": {"name": "Gary (Ghost)", "ai": "ghost", "atk": "dive", "hp": 32.0, "dmg": 12.0, "speed": 3.6, "range": 1.6, "windup": 0.6, "cd": 2.6,
		"h": 1.6, "r": 0.45, "xp": 9, "model": "humanoid", "pack": 1, "hover": 0.6},
	"mimic": {"name": "Mimic", "ai": "walk", "atk": "swing", "hp": 95.0, "dmg": 22.0, "speed": 4.0, "range": 1.9, "windup": 0.45, "cd": 1.4,
		"h": 1.0, "r": 0.6, "xp": 26, "model": "chest", "pack": 1},
	# --- roamers: not part of room waves, they wander the floor (see Dungeon._spawn_roamers)
	"gnome": {"name": "Lawn Gnome", "ai": "statue", "atk": "contact", "hp": 80.0, "dmg": 18.0, "speed": 8.0, "range": 1.4, "windup": 0.0, "cd": 1.1,
		"h": 1.2, "r": 0.4, "xp": 16, "model": "humanoid", "pack": 1, "scale": 0.8},
	"thief": {"name": "Sack Thief", "ai": "thief", "atk": "swing", "hp": 30.0, "dmg": 5.0, "speed": 5.4, "range": 1.6, "windup": 0.3, "cd": 1.2,
		"h": 1.4, "r": 0.4, "xp": 10, "model": "humanoid", "pack": 1, "scale": 0.8},
	"sock": {"name": "Ceiling Sock", "ai": "ceiling", "atk": "latch", "hp": 26.0, "dmg": 4.0, "speed": 2.6, "range": 1.3, "windup": 0.0, "cd": 1.0,
		"h": 0.9, "r": 0.35, "xp": 7, "model": "sock", "pack": 1, "hover": 3.6},
}

## weight tables per theme. Entries: [kind, weight, min_tier]
const TABLES := {
	"crypt": [["skeleton", 4, 1], ["archer", 2, 1], ["intern", 2, 2], ["rat", 1, 1], ["bat", 1, 1], ["ghost", 1, 3]],
	"sewer": [["rat", 4, 1], ["slime", 3, 1], ["bomber", 2, 1], ["intern", 1, 2], ["bat", 1, 1], ["skeleton", 1, 1]],
	"caves": [["mushroom", 3, 1], ["bat", 3, 1], ["rat", 1, 1], ["slime", 1, 1], ["hound", 2, 2], ["golem", 1, 3]],
	"furnace": [["imp", 3, 1], ["hound", 3, 1], ["skeleton", 2, 1], ["bomber", 2, 1], ["slime", 2, 1], ["golem", 1, 2]],
	"ice": [["skeleton", 3, 1], ["archer", 2, 1], ["hound", 2, 1], ["golem", 2, 2], ["bat", 1, 1], ["slime", 2, 1]],
}

## Per-theme colours for model families: main, accent.
const PALETTES := {
	"crypt": {"main": Color("#d8d4c0"), "accent": Color("#6a5a8a"), "glow": Color("#8affb0")},
	"sewer": {"main": Color("#6aa05a"), "accent": Color("#8a7a3a"), "glow": Color("#c8ff6a")},
	"caves": {"main": Color("#9a6ad0"), "accent": Color("#5a3a8a"), "glow": Color("#d28aff")},
	"furnace": {"main": Color("#c8502a"), "accent": Color("#3a2a2a"), "glow": Color("#ffb040")},
	"ice": {"main": Color("#a8d8f0"), "accent": Color("#5a88b8"), "glow": Color("#c8f4ff")},
}

const ELITE_AFFIXES := {
	"swift": {"name": "Swift", "speed": 1.35, "color": Color("#6adfff")},
	"armored": {"name": "Armored", "hp": 1.6, "color": Color("#c8c8d8")},
	"vampiric": {"name": "Vampiric", "lifesteal": 0.5, "color": Color("#e8304a")},
	"explosive": {"name": "Volatile", "death_boom": 3.4, "color": Color("#ff8a2a")},
	"burning": {"name": "Flaming", "burn_hit": 1.0, "color": Color("#ff6a1a")},
	"giant": {"name": "Gigantic", "hp": 1.4, "scale": 1.35, "dmg": 1.25, "color": Color("#9aff6a")},
}


const BARKS := {
	"skeleton": ["I'M ON MY BREAK", "Per my last email...", "*rattles in HR*", "It's not a bone, it's a lifestyle", "Have you tried bonking less?"],
	"archer": ["Pew. (professionally)", "Reply-all arrow!", "Sniping is my passion", "I'll be CC'ing you"],
	"rat": ["SQUEAK (unpaid)", "Cheese?", "*chews the mailbox*", "squeak squeak (union rates)"],
	"slime": ["blorp", "I am 70% legal", "squelch?", "gloop (gloop)"],
	"slime_small": ["blip", "mini blorp", "me too!"],
	"bat": ["SCREEE (junk mail)", "Ask me about warranties", "*flap flap*", "Have you seen my car's extended..."],
	"mushroom": ["Spores, but make it fun", "Don't breathe.", "We're a fun-guy", "I'm a fungi, fun-guy get it"],
	"intern": ["Is this paid?", "I have 3 degrees", "Coffee... coffee...", "I'll circle back", "This is not in my job description"],
	"imp": ["Pay cut incoming!", "Synergy!", "Restructuring you!", "Let's take this offline"],
	"hound": ["WOOF (overdue)", "Fetch the invoice!", "BORK", "grrr (past due)"],
	"bomber": ["Hold my fuse!", "BOOM?", "Is this thing on?", "I have a good feeling about this"],
	"golem": ["Rubble rubble.", "Clerical error.", "STAMP.", "*grinding noises*"],
	"ghost": ["Boo. (formal)", "I'm Gary.", "Whooo ordered you?", "I've been dead for years, still no PTO"],
	"mimic": ["Free chest!", "Open me ;)", "Not a mimic.", "Definitely a chest"],
	"thief": ["Finders keepers!", "Ooh, shiny!", "Is that a DUCK?", "*rustles sack*", "Nothing to see here"],
	"sock": ["*sniff*", "Hello, face!", "I've been in a boot for YEARS", "Snuggle time"],
}
const ELITE_BARKS := ["I'M A BIG DEAL", "Do you know who I AM?", "Middle management!", "I have a LANYARD"]
const BOSS_BARKS := {
	"auditor": ["Your timesheet is a DISGRACE", "AUDIT TIME!", "Pay stub or perish", "Receipts. RECEIPTS."],
	"mimic_king": ["BOW TO THE CHEST", "Your gold is MY gold", "I'm technically a monarch", "Open wide!"],
	"landlord": ["RENT IS DUE", "Your lease is TERMINATED", "No pets (that includes you)", "I'm raising the rent. On everything."],
	"dragon": ["WHERE IS MY PARCEL", "I ordered this on TUESDAY", "Customer service is DEAD to me", "Signature required!"],
}


static func pick_kind(theme: String, tier: int, rng: RandomNumberGenerator) -> String:
	var table: Array = TABLES[theme]
	var total := 0.0
	for e in table:
		if tier >= int(e[2]):
			total += float(e[1])
	var r := rng.randf() * total
	for e in table:
		if tier < int(e[2]):
			continue
		r -= float(e[1])
		if r <= 0.0:
			return e[0]
	return table[0][0]


static func scaled(kind: String, tier: int, mods: Array) -> Dictionary:
	var d: Dictionary = (KINDS[kind] as Dictionary).duplicate()
	var t := float(maxi(tier, 1) - 1)
	d["hp"] = float(d["hp"]) * (1.0 + 0.30 * t)
	d["dmg"] = float(d["dmg"]) * (1.0 + 0.16 * t)
	d["xp"] = int(round(float(d["xp"]) * (1.0 + 0.12 * t)))
	for m in mods:
		var md: Dictionary = Game.MODIFIERS.get(m, {})
		d["hp"] = float(d["hp"]) * float(md.get("hp", 1.0))
		d["speed"] = float(d["speed"]) * float(md.get("speed", 1.0))
	return d
