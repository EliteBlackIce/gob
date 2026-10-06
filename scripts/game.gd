extends Node
## Global state: wallet, skill tree, job rolls, the boss's moods, save file.

signal moment_recorded(caption: String)

const SAVE_PATH := "user://gob_save.json"

const SKILLS := {
	"quick_feet": {"branch": "Courier", "tier": 1, "name": "Quick Feet", "desc": "+15% run speed. Fear is a great coach."},
	"dash": {"branch": "Courier", "tier": 2, "name": "Panic Dash", "desc": "SHIFT: burst of speed. Ruins glass parcels."},
	"second_wind": {"branch": "Courier", "tier": 3, "name": "Second Wind", "desc": "Survive the first lethal hit each run. Barely."},
	"bottle": {"branch": "Scrapper", "tier": 1, "name": "Bottle Toss", "desc": "LMB: throw a bottle. Stuns crows, slimes, regrets."},
	"kick": {"branch": "Scrapper", "tier": 2, "name": "Dirty Kick", "desc": "F: boot to the shins. Knocks crows out of the sky."},
	"heavy_bottles": {"branch": "Scrapper", "tier": 3, "name": "Heavy Bottles", "desc": "Bigger splash, longer stun, +2 bottles per run."},
	"stamp": {"branch": "Fixer", "tier": 1, "name": "Stamp Mastery", "desc": "Inspection timing window +60%."},
	"riddle": {"branch": "Fixer", "tier": 2, "name": "Paperwork Sense", "desc": "Eliminates one wrong riddle answer."},
	"forged": {"branch": "Fixer", "tier": 3, "name": "Forged Papers", "desc": "First inspection each run auto-passes."},
	"padding": {"branch": "Pack Rat", "tier": 1, "name": "Padding", "desc": "Parcels take 35% less damage."},
	"slap": {"branch": "Pack Rat", "tier": 2, "name": "Parcel Slap", "desc": "Hold Q: shush screamers, cool hot parcels, calm wigglers."},
	"pocket": {"branch": "Pack Rat", "tier": 3, "name": "Secret Pocket", "desc": "The first theft each run fails. Crows are offended."},
}
const BRANCHES := ["Courier", "Scrapper", "Fixer", "Pack Rat"]

const MANDATES := [
	{"id": "normal", "text": "No special rules today. Try not to enjoy it.", "pay": 1.0, "funeral": 1.0, "speed": 1.0, "time": 1.0, "nodash": false},
	{"id": "double", "text": "DOUBLE PAY today. Funerals also cost double. Synergy!", "pay": 2.0, "funeral": 2.0, "speed": 1.0, "time": 1.0, "nodash": false},
	{"id": "nodash", "text": "Running is unprofessional. No dashing on company time.", "pay": 1.2, "funeral": 1.0, "speed": 1.0, "time": 1.0, "nodash": true},
	{"id": "heavy", "text": "All parcels are 'a bit heavier' today. Don't ask what's in them.", "pay": 1.3, "funeral": 1.0, "speed": 0.86, "time": 1.0, "nodash": false},
	{"id": "rush", "text": "Deadlines are 30% shorter. Your time is my money.", "pay": 1.5, "funeral": 1.0, "speed": 1.0, "time": 0.7, "nodash": false},
]

const JOBS := [
	{"id": "cheese", "title": "Screaming Cheese", "trait": "screamer", "base": 60, "note": "It screams when it's quiet. It's never quiet. Crows love it."},
	{"id": "potato", "title": "Hot Potato (Literal)", "trait": "hot", "base": 80, "note": "Gets hotter every second. Seawater helps. Panic helps less."},
	{"id": "crate", "title": "Wiggly Crate", "trait": "wiggly", "base": 70, "note": "Contents: alive. Contents: has opinions. Will run away."},
	{"id": "vase", "title": "Grandma's Vase", "trait": "glass", "base": 90, "note": "Fragile. Cursed. Fragile again. Don't jump. Don't dash."},
	{"id": "anvil", "title": "Ceremonial Anvil", "trait": "heavy", "base": 75, "note": "Slows you down. The customer wants it 'to arrive gently'."},
]
const DESTS := [
	{"id": "marl", "name": "Old Marl's Hut", "mult": 1.0, "time": 170.0},
	{"id": "light", "name": "Gull Point Lighthouse", "mult": 1.8, "time": 270.0},
]

const LETTERS := [
	"Goblin,\nYou are late. You are always late. Even when early, you are late.\n- G.",
	"To whom it may concern (the goblin),\nThe last goblin to sit in your spot was a legend. We don't know where they are now. We don't ask.\n- Grubnik",
	"Goblin,\nA reminder that 'hazard pay' is a myth invented by people who've never been paid.\n- G.",
	"Dear Employee #7 (formerly #6),\nCustomer satisfaction is up 3%. Goblin survival is down 40%. Net positive.\n- Management",
	"Goblin,\nThe parcel is probably fine. You, however...\n- Grubnik",
	"Goblin,\nI have installed a mail slot in my door so I don't have to hear your complaints.\n- G.",
	"Hey Kiddo,\nThe ogre at the gorge is 'between jobs'. Be nice. He bites.\n- G. (do not call me kiddo back)",
	"Goblin,\nI've noticed you've been alive for a while now. Is that a performance issue?\n- Grubnik",
	"Goblin,\nYour funeral fee has been deducted in advance. This is called 'efficiency'.\n- Accounting (also me)",
]
const ROAST_DEATH := [
	"You dropped the parcel. And your life. Mostly the parcel.",
	"We will say a few words at the funeral. 'Late' was one.",
	"Death is not an excuse. It's barely a delay.",
	"I've put your name on the wall. Spelled wrong, as is tradition.",
]
const ROAST_OK := [
	"Adequate. Do not expect a thank-you.",
	"The customer lived. So did the parcel. How rare.",
	"Payment enclosed. Subtracted: gratitude.",
]

const NAMES := ["Snik", "Grub", "Mogwort", "Pib", "Nubbin", "Skrimp", "Tok", "Wobble", "Fennick", "Zib", "Grimble", "Pog", "Dribble", "Yarp", "Bonk", "Splud", "Nib", "Quoff"]

var copper := 30
var skill_points := 1
var owned: Dictionary = {}
var day := 1
var deliveries := 0
var deaths := 0
var shame: Array = []
var perk_hp := 0           # grog bought for the next run
var perk_bottles := 0      # bottle crate bought for the next run
var today_jobs: Array = []
var mandate: Dictionary = MANDATES[0]
var current_job: Dictionary = {}
var goblin_name := "Snik"
var clips: Array = []      # captions captured this run
var seen_intro := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	load_game()
	new_day(false)


func _setup_input() -> void:
	var map := {
		"move_forward": [KEY_W, KEY_UP], "move_back": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"jump": [KEY_SPACE], "dash": [KEY_SHIFT], "interact": [KEY_E],
		"kick": [KEY_F], "slap": [KEY_Q], "pause": [KEY_ESCAPE], "clip": [KEY_C],
	}
	for action in map:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for k in map[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)
	InputMap.add_action("throw")
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("throw", mb)


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


func new_day(advance := true) -> void:
	if advance:
		day += 1
	goblin_name = NAMES[randi() % NAMES.size()]
	mandate = MANDATES[0] if day == 1 else MANDATES[randi() % MANDATES.size()]
	var pool := JOBS.duplicate()
	pool.shuffle()
	today_jobs = []
	for i in 3:
		var j: Dictionary = pool[i].duplicate()
		var d: Dictionary = DESTS[0] if i < 2 else DESTS[1]
		if i == 1 and randf() < 0.4:
			d = DESTS[1]
		j["dest"] = d["id"]
		j["dest_name"] = d["name"]
		j["pay"] = int(round(j["base"] * d["mult"] * mandate["pay"]))
		j["time"] = d["time"] * mandate["time"]
		today_jobs.append(j)


func funeral_cost() -> int:
	return int(round(15 * mandate["funeral"]))


func record_death(cause: String) -> void:
	deaths += 1
	shame.push_front({"name": goblin_name, "cause": cause, "day": day})
	if shame.size() > 12:
		shame.resize(12)
	copper -= funeral_cost()
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


func save_game() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({
		"copper": copper, "skill_points": skill_points, "owned": owned.keys(), "day": day,
		"deliveries": deliveries, "deaths": deaths, "shame": shame, "seen_intro": seen_intro,
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
	skill_points = int(data.get("skill_points", skill_points))
	day = int(data.get("day", day))
	deliveries = int(data.get("deliveries", 0))
	deaths = int(data.get("deaths", 0))
	shame = data.get("shame", [])
	seen_intro = bool(data.get("seen_intro", false))
	owned = {}
	for k in data.get("owned", []):
		owned[str(k)] = true


func reset_save() -> void:
	copper = 30
	skill_points = 1
	owned = {}
	day = 1
	deliveries = 0
	deaths = 0
	shame = []
	seen_intro = false
	save_game()
