extends Node
## Global state: wallet, character, loot, house, contracts, boss moods, save file.

signal moment_recorded(caption: String)
signal leveled_up(level: int)

const SAVE_PATH := "user://gob_save.json"
const SETTINGS_PATH := "user://settings.json"

## Options screen values (persisted separately from the save so wiping a goblin keeps your volume).
var settings := {"master": 0.8, "music": 0.7, "sfx": 1.0, "fov": 80.0, "sens": 1.0, "camcorder": true}
const INV_CAP := 28

const SKILLS := {
	"quick_feet": {"branch": "Courier", "tier": 1, "name": "Quick Feet", "desc": "+12% run speed. Fear is a great coach."},
	"roll_master": {"branch": "Courier", "tier": 2, "name": "Roll Master", "desc": "Dodge roll cooldown -30%, longer invulnerability, holler recharges faster."},
	"second_wind": {"branch": "Courier", "tier": 3, "name": "Second Wind", "desc": "Survive the first lethal hit each run at 40% HP."},
	"perfect_dodge": {"branch": "Courier", "tier": 4, "name": "Perfect Dodge", "desc": "Rolling through an attack resets your roll cooldown."},
	"power_strikes": {"branch": "Brawler", "tier": 1, "name": "Power Strikes", "desc": "+12% weapon damage."},
	"keen_edge": {"branch": "Brawler", "tier": 2, "name": "Keen Edge", "desc": "+8% crit chance, +25% crit damage."},
	"bloodthirst": {"branch": "Brawler", "tier": 3, "name": "Bloodthirst", "desc": "+4% lifesteal. Ew."},
	"berserker": {"branch": "Brawler", "tier": 4, "name": "Berserker", "desc": "+30% damage while below 40% HP. Rage is a feature."},
	"bandolier": {"branch": "Scrapper", "tier": 1, "name": "Bandolier", "desc": "+3 throwing bottles every run."},
	"power_boot": {"branch": "Scrapper", "tier": 2, "name": "Power Boot", "desc": "Kicks hit twice as hard and stagger bosses."},
	"bomb_maker": {"branch": "Scrapper", "tier": 3, "name": "Bomb Maker", "desc": "Throwables +40% damage, bigger splash, +2 bottles."},
	"pyro": {"branch": "Scrapper", "tier": 4, "name": "Pyromaniac", "desc": "Thrown bottles set enemies on fire. Everything is on fire."},
	"lucky": {"branch": "Gambler", "tier": 1, "name": "Lucky Stamp", "desc": "+15% loot luck: better rarities more often."},
	"pickpocket": {"branch": "Gambler", "tier": 2, "name": "Sticky Fingers", "desc": "+25% copper from everything."},
	"appraiser": {"branch": "Gambler", "tier": 3, "name": "Appraiser", "desc": "Gruk pays 20% more for your junk."},
	"jackpot": {"branch": "Gambler", "tier": 4, "name": "Jackpot", "desc": "Every chest holds one more item."},
	"padding": {"branch": "Pack Rat", "tier": 1, "name": "Padding", "desc": "Your parcel takes 35% less damage."},
	"tough": {"branch": "Pack Rat", "tier": 2, "name": "Tough Hide", "desc": "+20% max HP."},
	"pocket": {"branch": "Pack Rat", "tier": 3, "name": "Secret Pocket", "desc": "(Island) the first theft each run fails. Crows are offended."},
	"grog_lover": {"branch": "Pack Rat", "tier": 4, "name": "Grog Lover", "desc": "+1 grog flask carry, grog heals 55% instead of 40%."},
	"stamp": {"branch": "Postal", "tier": 1, "name": "Stamp Mastery", "desc": "(Island) inspection timing window +60%."},
	"riddle": {"branch": "Postal", "tier": 2, "name": "Paperwork Sense", "desc": "(Island) eliminates one wrong riddle answer."},
	"forged": {"branch": "Postal", "tier": 3, "name": "Forged Papers", "desc": "(Island) first inspection each run auto-passes."},
}
const BRANCHES := ["Courier", "Brawler", "Scrapper", "Gambler", "Pack Rat", "Postal"]

## Daily mandate from Grubnik: a flat modifier to everything that day.
const MANDATES := [
	{"id": "normal", "text": "No special rules today. Try not to enjoy it.", "pay": 1.0, "funeral": 1.0, "speed": 1.0, "time": 1.0, "xp": 1.0, "luck": 0.0},
	{"id": "double", "text": "DOUBLE PAY today. Funerals also cost double. Synergy!", "pay": 2.0, "funeral": 2.0, "speed": 1.0, "time": 1.0, "xp": 1.0, "luck": 0.0},
	{"id": "budget", "text": "Budget cuts: copper -25%, but XP is doubled. Learning is its own reward.", "pay": 0.75, "funeral": 1.0, "speed": 1.0, "time": 1.0, "xp": 2.0, "luck": 0.0},
	{"id": "heavy", "text": "All parcels are 'a bit heavier' today. Don't ask what's in them.", "pay": 1.3, "funeral": 1.0, "speed": 0.9, "time": 1.0, "xp": 1.0, "luck": 0.0},
	{"id": "lucky", "text": "Grubnik is in a good mood. Loot luck +40%. Enjoy it. It won't last.", "pay": 1.0, "funeral": 1.0, "speed": 1.0, "time": 1.0, "xp": 1.0, "luck": 40.0},
	{"id": "rush", "text": "Deadlines are 30% shorter. Your time is my money.", "pay": 1.5, "funeral": 1.0, "speed": 1.0, "time": 0.7, "xp": 1.0, "luck": 0.0},
]

## Overworld (island) parcels.
const JOBS := [
	{"id": "cheese", "title": "Screaming Cheese", "trait": "screamer", "base": 60, "note": "It screams when it's quiet. It's never quiet. Crows love it."},
	{"id": "potato", "title": "Hot Potato (Literal)", "trait": "hot", "base": 80, "note": "Gets hotter every second. Seawater helps. Panic helps less."},
	{"id": "crate", "title": "Wiggly Crate", "trait": "wiggly", "base": 70, "note": "Contents: alive. Contents: has opinions. Will run away."},
	{"id": "vase", "title": "Grandma's Vase", "trait": "glass", "base": 90, "note": "Fragile. Cursed. Fragile again. Don't jump. Don't roll."},
	{"id": "anvil", "title": "Ceremonial Anvil", "trait": "heavy", "base": 75, "note": "Slows you down. The customer wants it 'to arrive gently'."},
]
const DESTS := [
	{"id": "marl", "name": "Old Marl's Hut", "mult": 1.0, "time": 140.0},
	{"id": "light", "name": "Gull Point Lighthouse", "mult": 1.8, "time": 210.0},
]

## Dungeon themes unlock one tier at a time. boss ids live in scripts/mobs/boss.gd.
const THEMES := {
	"crypt": {"name": "The Dusty Crypt", "tier": 1, "boss": "auditor", "desc": "Skeletons, cobwebs and unpaid interns.", "color": Color("#8a8a9a")},
	"sewer": {"name": "The Soggy Sewers", "tier": 2, "boss": "mimic_king", "desc": "Rats, slime and questionable puddles.", "color": Color("#5a9a6a")},
	"caves": {"name": "Glowshroom Caves", "tier": 3, "boss": "landlord", "desc": "Spores, bats and one grumpy landlord.", "color": Color("#a05ad0")},
	"furnace": {"name": "The Ember Foundry", "tier": 4, "boss": "dragon", "desc": "Lava, imps and a dragon with a complaint.", "color": Color("#e8602a")},
	"ice": {"name": "Frostbite Mines", "tier": 5, "boss": "landlord", "desc": "Cold. Very cold. Also a landlord.", "color": Color("#7ac8f0")},
}
const THEME_ORDER := ["crypt", "sewer", "caves", "furnace", "ice"]

const MODIFIERS := {
	"elites": {"name": "Elite Parade", "text": "More elite enemies. Better loot.", "elite": 0.25, "luck": 25.0, "pay": 1.2},
	"dark": {"name": "Power Outage", "text": "The torches are out. Bring courage.", "dark": true, "luck": 15.0, "pay": 1.15},
	"tough": {"name": "Beefy Boys", "text": "Enemies have +30% HP.", "hp": 1.3, "pay": 1.25},
	"swift": {"name": "Caffeinated", "text": "Enemies move +20% faster.", "speed": 1.2, "pay": 1.2},
	"bountiful": {"name": "Bountiful", "text": "Chests everywhere. Rarer loot.", "luck": 40.0, "chests": 1.6, "pay": 1.0},
	"explosive": {"name": "Powder Keg Party", "text": "Explosive barrels are everywhere.", "barrels": 2.5, "pay": 1.1},
	"tax": {"name": "Goblin Tax", "text": "Copper -40%, but XP +40%.", "gold": 0.6, "xp": 1.4, "pay": 0.9},
	"haunted": {"name": "Haunted", "text": "Ghosts. So many ghosts.", "ghosts": true, "pay": 1.2},
}

const PARCEL_NAMES := ["Screaming Cheese", "Hot Potato (Literal)", "Wiggly Crate", "Grandma's Vase", "Ceremonial Anvil"]
const CUSTOMERS := ["Skeleton Dave", "Lady Mildew", "Old Marl's Cousin", "The Thing in the Wall", "Gary (Ghost)", "Sir Reginald Moss", "Mum (Lich)", "A Very Polite Rat", "Mortimer the Unfinished"]

const HOUSES := [
	{"name": "Cardboard Box", "cost": 0, "stash": 6, "hp": 0, "grog": 0, "xp": 0, "text": "It's a box. It's yours."},
	{"name": "Wonky Shack", "cost": 400, "stash": 12, "hp": 10, "grog": 0, "xp": 0, "text": "Has a roof. Mostly."},
	{"name": "Cozy Cottage", "cost": 1800, "stash": 20, "hp": 20, "grog": 1, "xp": 5, "text": "A chimney! Smoke! Dignity!"},
	{"name": "Proper House", "cost": 6000, "stash": 28, "hp": 35, "grog": 1, "xp": 10, "text": "Two floors. Grubnik is jealous."},
	{"name": "Grand Manor", "cost": 16000, "stash": 40, "hp": 50, "grog": 2, "xp": 15, "text": "It has a library. You can't read."},
	{"name": "The Castle", "cost": 40000, "stash": 60, "hp": 80, "grog": 3, "xp": 25, "text": "Retire. Finally. Forever."},
]

const LETTERS := [
	"Goblin,\nYou are late. You are always late. Even when early, you are late.\n- G.",
	"To whom it may concern (the goblin),\nThe last goblin to sit in your spot was a legend. We don't know where they are now. We don't ask.\n- Grubnik",
	"Goblin,\nA reminder that 'hazard pay' is a myth invented by people who've never been paid.\n- G.",
	"Dear Employee #7 (formerly #6),\nCustomer satisfaction is up 3%. Goblin survival is down 40%. Net positive.\n- Management",
	"Goblin,\nThe parcel is probably fine. You, however...\n- Grubnik",
	"Goblin,\nI have installed a mail slot in my door so I don't have to hear your complaints.\n- G.",
	"Hey Kiddo,\nThe dragon in the foundry is 'between customers'. Be nice. He bites. He also tips.\n- G. (do not call me kiddo back)",
	"Goblin,\nI've noticed you've been alive for a while now. Is that a performance issue?\n- Grubnik",
	"Goblin,\nYour funeral fee has been deducted in advance. This is called 'efficiency'.\n- Accounting (also me)",
	"Goblin,\nSomeone has been saving up for a house. Do you know how many parcels that means? Neither do I. Keep going.\n- G.",
]
const ROAST_DEATH := [
	"You dropped the parcel. And your life. Mostly the parcel.",
	"We will say a few words at the funeral. 'Late' was one.",
	"Death is not an excuse. It's barely a delay.",
	"I've put your name on the wall. Spelled wrong, as is tradition.",
	"The loot you were carrying has been 'reclaimed by the dungeon'. Legally.",
]
const ROAST_OK := [
	"Adequate. Do not expect a thank-you.",
	"The customer lived. So did the parcel. How rare.",
	"Payment enclosed. Subtracted: gratitude.",
	"You're still alive? Update the paperwork.",
]

const NAMES := ["Snik", "Grub", "Mogwort", "Pib", "Nubbin", "Skrimp", "Tok", "Wobble", "Fennick", "Zib", "Grimble", "Pog", "Dribble", "Yarp", "Bonk", "Splud", "Nib", "Quoff"]

# ---- character
var copper := 30
var level := 1
var xp := 0
var skill_points := 1
var owned: Dictionary = {}
var inventory: Array = []          # unequipped items (Dictionaries)
var equipped: Dictionary = {}      # slot -> item
var stash: Array = []
var grog_stock := 2                # flasks carried into the next run
var house_tier := 0
var trophies: Array = []           # boss ids defeated (display in the house)
var max_tier := 1
var best_floor := 0
var kills := 0
var items_found := 0
# ---- world / run
var day := 1
var deliveries := 0
var deaths := 0
var shame: Array = []
## Lethal-Company-style junk you haul home: [{id, value, run}]. run = picked up this trip (lost on death).
var scrap: Array = []
## Grubnik's quota: pay `target` copper-equivalent by `deadline` (a day number) or get "adjusted".
var quota := {"n": 1, "target": 150, "paid": 0, "deadline": 5, "fails": 0}
var perk_hp := 0
var perk_bottles := 0
var today_jobs: Array = []         # contracts
var mandate: Dictionary = MANDATES[0]
var current_job: Dictionary = {}
var goblin_name := "Snik"
var clips: Array = []
var seen_intro := false
var hints_seen: Dictionary = {}
var run_loot: Array = []           # item uids picked up this run (lost on death)
var won := false
var shop_stock: Array = []         # Gruk's wares today
var gear_rev := 0                  # bumped whenever equipment changes (player re-reads its stats)


func touch_gear() -> void:
	gear_rev += 1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	load_game()
	if equipped.is_empty() and inventory.is_empty():
		give_starter_kit()
	new_day(false)


func _setup_input() -> void:
	var map := {
		"move_forward": [KEY_W, KEY_UP], "move_back": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"jump": [KEY_SPACE], "dash": [KEY_SHIFT], "interact": [KEY_E], "toss": [KEY_G],
		"kick": [KEY_F], "scan": [KEY_V], "emote": [KEY_B], "bottle": [KEY_Q], "grog": [KEY_R], "slap": [KEY_X], "pause": [KEY_ESCAPE], "clip": [KEY_C],
		"inventory": [KEY_TAB, KEY_I], "ability": [KEY_Z],
	}
	for action in map:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for k in map[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)
	for pair in [["attack", MOUSE_BUTTON_LEFT], ["block", MOUSE_BUTTON_RIGHT], ["throw", MOUSE_BUTTON_MIDDLE]]:
		if not InputMap.has_action(pair[0]):
			InputMap.add_action(pair[0])
		var mb := InputEventMouseButton.new()
		mb.button_index = pair[1]
		InputMap.action_add_event(pair[0], mb)


# ---------------------------------------------------------------- skills

func has_skill(id: String) -> bool:
	return owned.has(id)


func can_buy(id: String) -> bool:
	if owned.has(id) or skill_points <= 0:
		return false
	var s: Dictionary = SKILLS[id]
	if s["tier"] == 1:
		return true
	for other in SKILLS:
		var o: Dictionary = SKILLS[other]
		if o["branch"] == s["branch"] and o["tier"] == s["tier"] - 1:
			return owned.has(other)
	return false


func buy_skill(id: String) -> bool:
	if not can_buy(id):
		return false
	owned[id] = true
	skill_points -= 1
	save_game()
	return true


# ---------------------------------------------------------------- character & loot

func give_starter_kit() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var w := ItemDB.roll(1, rng, "weapon", 0)
	w["base"] = "club"
	w["name"] = "Trusty Bonk Stick"
	w["stats"] = {"w_dmg": 15.0}
	equipped["weapon"] = w
	var h := ItemDB.roll(1, rng, "hat", 0)
	h["base"] = "cap"
	h["name"] = "Regulation Postal Cap"
	h["stats"] = {"armor": 2.0, "hp": 6.0}
	equipped["hat"] = h


# ---------------------------------------------------------------- quota & scrap

const QUOTA_DAYS := 4
const SCRAP_BONUS := 1.2


func quota_target_for(n: int) -> int:
	return 150 + 110 * (n - 1) + 20 * (n - 1) * (n - 1)


func quota_days_left() -> int:
	return maxi(0, int(quota["deadline"]) - day)


func scrap_total() -> int:
	var t := 0
	for sc in scrap:
		t += int(sc["value"])
	return t


func scrap_speed_mult() -> float:
	var units := 0
	for sc in scrap:
		units += 3 if Scrap.DB.get(str(sc["id"]), {}).get("heavy", false) else 1
	return maxf(0.7, 1.0 - 0.035 * float(units))


## A hit rattles your sack: fragile scrap loses a quarter of its value. Returns what cracked.
func scrap_take_hit() -> Array:
	var cracked: Array = []
	for sc in scrap:
		if Scrap.DB.get(str(sc["id"]), {}).get("fragile", false):
			var loss := maxi(1, int(round(float(sc["value"]) * 0.25)))
			sc["value"] = maxi(1, int(sc["value"]) - loss)
			cracked.append([str(Scrap.DB[str(sc["id"])]["name"]), loss])
	return cracked


## Sell the whole sack at the desk. Scrap counts 20% extra toward the quota.
func sell_scrap() -> int:
	var worth := int(round(float(scrap_total()) * SCRAP_BONUS))
	quota["paid"] = int(quota["paid"]) + worth
	scrap.clear()
	touch_gear()
	save_game()
	return worth


func pay_quota(amount: int) -> int:
	var pay := mini(amount, copper)
	if pay <= 0:
		return 0
	copper -= pay
	quota["paid"] = int(quota["paid"]) + pay
	save_game()
	return pay


## Called once per day tick. Returns {} until the deadline, then a verdict for the UI.
func resolve_quota() -> Dictionary:
	if day < int(quota["deadline"]):
		return {}
	var n: int = int(quota["n"])
	var target: int = int(quota["target"])
	var paid: int = int(quota["paid"])
	var verdict := {}
	if paid >= target:
		var over := paid - target
		var bonus := int(round(float(target) * 0.25)) + int(over * 0.5)
		copper += bonus
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		var it := ItemDB.roll(maxi(1, level + n), rng, "", mini(4, 1 + (1 if n >= 3 else 0) + (1 if rng.randf() < 0.2 else 0)), 0.0)
		var got := add_item(it, false)
		add_xp(60.0 + 40.0 * n)
		verdict = {"ok": true, "title": "QUOTA MET!", "text": "Grubnik reviews the ledger.\n\"Adequate. I felt something. It was brief.\"\n\nBonus: +%d copper%s\nNew quota (#%d): %d copper in %d days." % [bonus, ("\nReward: %s" % ItemDB.title(it)) if got else "\n(Your pack was full, so Grubnik kept the reward.)", n + 1, quota_target_for(n + 1), QUOTA_DAYS]}
		quota = {"n": n + 1, "target": quota_target_for(n + 1), "paid": 0, "deadline": day + QUOTA_DAYS, "fails": 0}
	else:
		var cut := int(round(float(copper) * 0.35))
		copper -= cut
		var fails := int(quota["fails"]) + 1
		shame.push_front({"name": goblin_name, "cause": "missed quota #%d" % n, "day": day})
		if shame.size() > 12:
			shame.resize(12)
		verdict = {"ok": false, "title": "QUOTA MISSED", "text": "You paid %d of %d.\nGrubnik \"adjusts\" your wages: -%d copper.\n\nThe same quota is due again in %d days. He is smiling. It's awful." % [paid, target, cut, QUOTA_DAYS]}
		quota = {"n": n, "target": target, "paid": 0, "deadline": day + QUOTA_DAYS, "fails": fails}
	save_game()
	return verdict


func add_xp(amount: float) -> int:
	var s := Stats.compute()
	var gain := int(round(amount * (1.0 + s["xp_pct"] / 100.0) * float(mandate.get("xp", 1.0))))
	xp += gain
	var ups := 0
	while level < Stats.MAX_LEVEL and xp >= Stats.xp_needed(level):
		xp -= Stats.xp_needed(level)
		level += 1
		skill_points += 1
		ups += 1
		leveled_up.emit(level)
	if level >= Stats.MAX_LEVEL:
		xp = 0
	return ups


func add_item(it: Dictionary, from_run := true) -> bool:
	if inventory.size() >= INV_CAP:
		return false
	inventory.append(it)
	items_found += 1
	if from_run:
		run_loot.append(it["uid"])
	return true


func equip(it: Dictionary) -> void:
	var slot: String = it["slot"]
	var old: Variant = equipped.get(slot)
	inventory.erase(it)
	equipped[slot] = it
	if old != null:
		inventory.append(old)
	touch_gear()


func unequip(slot: String) -> bool:
	var it: Variant = equipped.get(slot)
	if it == null or inventory.size() >= INV_CAP:
		return false
	equipped.erase(slot)
	inventory.append(it)
	touch_gear()
	return true


func sell_price(it: Dictionary) -> int:
	var mult := 0.5 + (0.2 if has_skill("appraiser") else 0.0)
	return int(round(float(it["value"]) * mult))


func sell(it: Dictionary) -> int:
	var p := sell_price(it)
	inventory.erase(it)
	copper += p
	return p


func stash_cap() -> int:
	return int(HOUSES[house_tier]["stash"])


func to_stash(it: Dictionary) -> bool:
	if stash.size() >= stash_cap():
		return false
	inventory.erase(it)
	stash.append(it)
	return true


func from_stash(it: Dictionary) -> bool:
	if inventory.size() >= INV_CAP:
		return false
	stash.erase(it)
	inventory.append(it)
	return true


func house_perk(key: String) -> float:
	return float(HOUSES[house_tier].get(key, 0))


func house_next() -> Dictionary:
	return HOUSES[house_tier + 1] if house_tier + 1 < HOUSES.size() else {}


func buy_house() -> bool:
	var nx := house_next()
	if nx.is_empty() or copper < int(nx["cost"]):
		return false
	copper -= int(nx["cost"])
	house_tier += 1
	if house_tier >= HOUSES.size() - 1:
		won = true
	save_game()
	return true


func ilvl_now() -> int:
	return ItemDB.ilvl_for(max_tier, 1, level)


# ---------------------------------------------------------------- contracts

func theme_unlocked(id: String) -> bool:
	return int(THEMES[id]["tier"]) <= max_tier


func new_day(advance := true) -> void:
	if advance:
		day += 1
	goblin_name = NAMES[randi() % NAMES.size()]
	mandate = MANDATES[0] if day == 1 else MANDATES[randi() % MANDATES.size()]
	today_jobs = make_contracts()
	shop_stock = make_shop()


func make_contracts() -> Array:
	var out: Array = []
	# one safe overworld route
	var rj: Dictionary = JOBS[randi() % JOBS.size()].duplicate()
	var d: Dictionary = DESTS[0] if (day <= 2 or randf() < 0.55) else DESTS[1]
	rj["kind"] = "route"
	rj["dest"] = d["id"]
	rj["dest_name"] = d["name"]
	rj["pay"] = int(round(rj["base"] * d["mult"] * mandate["pay"]))
	rj["time"] = d["time"] * mandate["time"]
	rj["tier"] = 0
	out.append(rj)
	# three dungeon contracts of rising difficulty
	var themes: Array = []
	for t in THEME_ORDER:
		if theme_unlocked(t):
			themes.append(t)
	for i in 3:
		var tier := clampi(max_tier - 1 + i, 1, 12) if i > 0 else clampi(max_tier - 1, 1, 12)
		tier = maxi(1, tier)
		var theme: String = themes[randi() % themes.size()]
		if i == 2 and max_tier >= 2:
			theme = themes[themes.size() - 1]
		var pj: Dictionary = JOBS[randi() % JOBS.size()]
		var mods: Array = []
		var mkeys: Array = MODIFIERS.keys()
		mkeys.shuffle()
		var nmods := 0 if (tier <= 1 and i == 0) else (1 if randf() < 0.65 else 2)
		for k in nmods:
			mods.append(mkeys[k])
		var pay_mult := 1.0
		for m in mods:
			pay_mult *= float(MODIFIERS[m].get("pay", 1.0))
		var base_pay := int(round((140.0 + 90.0 * tier) * pay_mult * mandate["pay"]))
		var customer: String = CUSTOMERS[randi() % CUSTOMERS.size()]
		out.append({
			"kind": "dungeon", "id": pj["id"], "title": pj["title"], "trait": pj["trait"], "note": pj["note"],
			"theme": theme, "tier": tier, "mods": mods, "pay": base_pay, "customer": customer,
			"dest_name": "%s (%s)" % [customer, THEMES[theme]["name"]], "seed": randi(),
		})
	return out


func make_shop() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var out: Array = []
	for i in 5:
		var slot: String = ["weapon", "weapon", "hat", "vest", "boots", "trinket"][i % 6]
		var r := ItemDB.roll_rarity(rng, 0.0, 0.2)
		r = mini(r, 3)
		out.append(ItemDB.roll(ilvl_now() + (1 if i == 4 else 0), rng, slot, r))
	return out


func funeral_cost() -> int:
	return int(round((15 + 6 * max_tier) * mandate["funeral"]))


func record_death(cause: String) -> void:
	deaths += 1
	shame.push_front({"name": goblin_name, "cause": cause, "day": day})
	if shame.size() > 12:
		shame.resize(12)
	copper = maxi(0, copper - funeral_cost())
	# the dungeon keeps what you found this run
	for uid in run_loot:
		for it in inventory.duplicate():
			if it["uid"] == uid:
				inventory.erase(it)
	run_loot.clear()
	for sc in scrap.duplicate():
		if sc.get("run", false):
			scrap.erase(sc)
	save_game()


## Marks a viral moment: banner + slow-mo handled by the UI, screenshot saved here.
func moment(caption: String) -> void:
	clips.append(caption)
	moment_recorded.emit(caption)
	_save_clip(caption)


func _save_clip(caption: String) -> void:
	var vp := get_viewport()
	if vp == null or DisplayServer.get_name() == "headless":
		return
	var img := vp.get_texture().get_image()
	if img == null:
		return
	DirAccess.make_dir_recursive_absolute("user://clips")
	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	var safe := caption.to_lower().replace(" ", "_").substr(0, 28)
	img.save_png("user://clips/%s_%s.png" % [stamp, safe])


# ---------------------------------------------------------------- settings

func load_settings() -> void:
	if FileAccess.file_exists(SETTINGS_PATH):
		var f := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
		if f != null:
			var d: Variant = JSON.parse_string(f.get_as_text())
			if typeof(d) == TYPE_DICTIONARY:
				for k in settings:
					if d.has(k):
						settings[k] = d[k]
	apply_settings()


func save_settings() -> void:
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(settings))


func apply_settings() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(clampf(float(settings["master"]), 0.0001, 1.0)))
	Sfx.refresh_volume()


# ---------------------------------------------------------------- save / load

func save_game() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({
		"copper": copper, "level": level, "xp": xp, "skill_points": skill_points, "owned": owned.keys(), "day": day,
		"deliveries": deliveries, "deaths": deaths, "shame": shame, "seen_intro": seen_intro, "hints_seen": hints_seen.keys(),
		"inventory": inventory, "equipped": equipped, "stash": stash, "grog_stock": grog_stock, "house_tier": house_tier,
		"trophies": trophies, "scrap": scrap, "quota": quota, "max_tier": max_tier, "best_floor": best_floor, "kills": kills, "items_found": items_found, "won": won,
	}))


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var data: Variant = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return
	copper = int(data.get("copper", copper))
	level = int(data.get("level", 1))
	xp = int(data.get("xp", 0))
	skill_points = int(data.get("skill_points", skill_points))
	day = int(data.get("day", day))
	deliveries = int(data.get("deliveries", 0))
	deaths = int(data.get("deaths", 0))
	shame = data.get("shame", [])
	seen_intro = bool(data.get("seen_intro", false))
	hints_seen = {}
	for h in data.get("hints_seen", []):
		hints_seen[str(h)] = true
	owned = {}
	for k in data.get("owned", []):
		if SKILLS.has(str(k)):
			owned[str(k)] = true
	inventory = _fix_items(data.get("inventory", []))
	stash = _fix_items(data.get("stash", []))
	equipped = {}
	var eq: Dictionary = data.get("equipped", {})
	for slot in eq:
		var one := _fix_items([eq[slot]])
		if not one.is_empty():
			equipped[slot] = one[0]
	grog_stock = int(data.get("grog_stock", 2))
	house_tier = clampi(int(data.get("house_tier", 0)), 0, HOUSES.size() - 1)
	trophies = data.get("trophies", [])
	max_tier = maxi(1, int(data.get("max_tier", 1)))
	best_floor = int(data.get("best_floor", 0))
	kills = int(data.get("kills", 0))
	items_found = int(data.get("items_found", 0))
	won = bool(data.get("won", false))
	scrap = []
	for sc in data.get("scrap", []):
		if typeof(sc) == TYPE_DICTIONARY and Scrap.DB.has(str(sc.get("id", ""))):
			scrap.append({"id": str(sc["id"]), "value": int(sc.get("value", 10)), "run": false})
	var q: Variant = data.get("quota", null)
	if typeof(q) == TYPE_DICTIONARY:
		quota = {"n": int(q.get("n", 1)), "target": int(q.get("target", 150)), "paid": int(q.get("paid", 0)), "deadline": int(q.get("deadline", day + QUOTA_DAYS)), "fails": int(q.get("fails", 0))}


func _fix_items(arr: Array) -> Array:
	var out: Array = []
	for it in arr:
		if typeof(it) != TYPE_DICTIONARY or not it.has("slot") or not it.has("stats"):
			continue
		it["rarity"] = int(it.get("rarity", 0))
		it["ilvl"] = int(it.get("ilvl", 1))
		it["plus"] = int(it.get("plus", 0))
		it["value"] = int(it.get("value", 10))
		if it["slot"] == "weapon" and not ItemDB.WEAPONS.has(it.get("base", "")):
			continue
		out.append(it)
	return out


func reset_save() -> void:
	copper = 30
	level = 1
	xp = 0
	skill_points = 1
	owned = {}
	inventory = []
	equipped = {}
	stash = []
	grog_stock = 2
	house_tier = 0
	trophies = []
	max_tier = 1
	best_floor = 0
	kills = 0
	items_found = 0
	won = false
	day = 1
	deliveries = 0
	deaths = 0
	shame = []
	scrap = []
	quota = {"n": 1, "target": 150, "paid": 0, "deadline": 1 + QUOTA_DAYS, "fails": 0}
	seen_intro = false
	hints_seen = {}
	run_loot = []
	give_starter_kit()
	save_game()
