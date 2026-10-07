class_name CombatHud
extends Control
## Everything you glance at mid-fight: HP, XP, hotbar with cooldowns, boss bar and a fog-of-war
## minimap. Drawn with _draw() so it stays crisp and pixel-chunky.

const INK := Color("#120d0a")
const GOLD := Color("#f3c14a")
const TEXT := Color("#eadfc4")

var player: Player = null
var dungeon: Node = null           # Dungeon (optional)
var boss: Mob = null
var boss_name := ""
var boss_title := ""
var objective := ""
var _hp_trail := 1.0
var _t := 0.0
var _font: Font
var _xp_flash := 0.0
var _last_level := 1
var _level_t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_font = ThemeDB.fallback_font
	_last_level = Game.level


func _process(delta: float) -> void:
	_t += delta
	size = get_viewport_rect().size
	position = Vector2.ZERO
	if player != null and is_instance_valid(player):
		var f := player.hp / maxf(player.max_hp, 1.0)
		_hp_trail = move_toward(_hp_trail, f, delta * 0.35) if _hp_trail > f else f
	if Game.level != _last_level:
		_last_level = Game.level
		_level_t = 2.0
	_level_t = maxf(0.0, _level_t - delta)
	queue_redraw()


func _txt(pos: Vector2, s: String, font_size := 18, col := TEXT, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	var p := pos
	if align == HORIZONTAL_ALIGNMENT_CENTER and width <= 0.0:
		p.x -= _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x * 0.5
	draw_string_outline(_font, p, s, HORIZONTAL_ALIGNMENT_LEFT, width, font_size, maxi(4, font_size / 4), INK)
	draw_string(_font, p, s, HORIZONTAL_ALIGNMENT_LEFT, width, font_size, col)


func _bar(r: Rect2, frac: float, fill: Color, back := Color(0.1, 0.06, 0.05, 0.85), trail := -1.0, trail_col := Color(1, 1, 1, 0.8)) -> void:
	draw_rect(r.grow(3), INK)
	draw_rect(r, back)
	if trail > frac:
		draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(trail, 0, 1), r.size.y)), trail_col)
	draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(frac, 0, 1), r.size.y)), fill)
	draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(frac, 0, 1), r.size.y * 0.35)), fill.lightened(0.28))
	var segs := int(r.size.x / 28.0)
	for i in range(1, segs):
		draw_rect(Rect2(r.position.x + r.size.x * float(i) / segs - 1, r.position.y, 2, r.size.y), Color(0, 0, 0, 0.35))


func _draw() -> void:
	if player == null or not is_instance_valid(player):
		return
	var vp := size
	# ---- HP / XP (top left)
	var hp_r := Rect2(24, 20, 300, 24)
	_bar(hp_r, player.hp / maxf(player.max_hp, 1.0), Color("#d83a30"), Color(0.1, 0.06, 0.05, 0.85), _hp_trail)
	_txt(Vector2(hp_r.position.x + 8, hp_r.position.y + 19), "%d / %d" % [int(ceil(player.hp)), int(round(player.max_hp))], 17, Color.WHITE)
	var xp_r := Rect2(24, 54, 300, 10)
	var need := Stats.xp_needed(Game.level)
	_bar(xp_r, float(Game.xp) / float(need), Color("#7ed957"))
	_txt(Vector2(24, 86), "LEVEL %d" % Game.level, 20, GOLD)
	_txt(Vector2(120, 86), "%d copper" % Game.copper, 20, Color("#ffd24a"))
	if Game.skill_points > 0:
		_txt(Vector2(24, 110), "%d skill point%s!  (visit the cellar)" % [Game.skill_points, "s" if Game.skill_points > 1 else ""], 16, Color("#9dffa0"))
	# statuses
	var sx := 24.0
	for s in player.statuses:
		var col := Color("#ff9a3a") if s == "burn" else (Color("#7aff6a") if s == "poison" else Color("#9fd8ff"))
		draw_rect(Rect2(sx, 124, 78, 22), INK)
		draw_rect(Rect2(sx + 2, 126, 74, 18), col.darkened(0.45))
		_txt(Vector2(sx + 6, 142), str(s).to_upper(), 14, col)
		sx += 84.0
	# ---- hotbar (bottom center)
	_hotbar(vp)
	# ---- boss bar
	if boss != null and is_instance_valid(boss) and not boss.dead and boss.awake:
		var bw := minf(vp.x * 0.5, 720.0)
		var br := Rect2((vp.x - bw) * 0.5, 54, bw, 20)
		_txt(Vector2(vp.x * 0.5, 40), boss_name.to_upper(), 26, Color("#ffd89a"), HORIZONTAL_ALIGNMENT_CENTER, 0)
		_bar(br, boss.hp / boss.max_hp, Color("#c02a2a"), Color(0.1, 0.05, 0.05, 0.9))
		_txt(Vector2(vp.x * 0.5, br.end.y + 20), boss_title, 15, Color("#c8b890"), HORIZONTAL_ALIGNMENT_CENTER, 0)
		if boss is Boss and (boss as Boss).phase == 2:
			draw_rect(Rect2(br.position.x + bw * 0.5 - 1, br.position.y - 4, 2, 28), Color(1, 1, 1, 0.5))
	elif objective != "":
		_txt(Vector2(vp.x * 0.5, 40), objective, 22, Color("#ffd89a"), HORIZONTAL_ALIGNMENT_CENTER, 0)
	# ---- minimap
	if dungeon != null and is_instance_valid(dungeon) and dungeon.has_method("minimap_texture"):
		_minimap(vp)
	# ---- level-up flash
	if _level_t > 0.0:
		var a := clampf(_level_t, 0.0, 1.0)
		_txt(Vector2(vp.x * 0.5, vp.y * 0.32), "LEVEL UP!", 54, Color(1.0, 0.9, 0.3, a), HORIZONTAL_ALIGNMENT_CENTER, 0)


func _hotbar(vp: Vector2) -> void:
	var slots := []
	var st := player.stats
	var w: Dictionary = Game.equipped.get("weapon", {})
	var cd := player.cooldowns()
	slots.append({"key": "LMB", "label": ItemDB.WEAPONS[w["base"]]["name"] if w.has("base") else "Fists", "col": ItemDB.rarity_color(int(w.get("rarity", 0))) if w.has("rarity") else TEXT, "cd": 0.0, "max": 1.0})
	slots.append({"key": "RMB", "label": "Block", "col": TEXT, "cd": 0.0, "max": 1.0})
	slots.append({"key": "SHIFT", "label": "Roll", "col": Color("#9fd8ff"), "cd": cd["roll"], "max": cd["roll_max"]})
	slots.append({"key": "F", "label": "Kick", "col": TEXT, "cd": cd["kick"], "max": 0.7})
	if player.mode != "hub":
		slots.append({"key": "Q", "label": "Bottle x%d" % player.bottles, "col": Color("#9fe6b0") if player.bottles > 0 else Color("#6a6a6a"), "cd": 0.0, "max": 1.0})
	slots.append({"key": "R", "label": "Grog x%d" % Game.grog_stock, "col": Color("#ffd89a") if Game.grog_stock > 0 else Color("#6a6a6a"), "cd": 0.0, "max": 1.0})
	if player.mode == "dungeon":
		slots.append({"key": "Z", "label": "Holler", "col": Color("#ffe97a"), "cd": cd["holler"], "max": cd["holler_max"]})
	var sw := 96.0
	var gap := 8.0
	var total := slots.size() * sw + (slots.size() - 1) * gap
	var x0 := (vp.x - total) * 0.5
	var y0 := vp.y - 76.0
	for i in slots.size():
		var s: Dictionary = slots[i]
		var r := Rect2(x0 + i * (sw + gap), y0, sw, 56)
		draw_rect(r.grow(3), INK)
		draw_rect(r, Color(0.14, 0.1, 0.08, 0.9))
		_txt(Vector2(r.position.x + 6, r.position.y + 18), str(s["key"]), 14, GOLD)
		_txt(Vector2(r.position.x + 6, r.position.y + 42), str(s["label"]), 14, s["col"], HORIZONTAL_ALIGNMENT_LEFT, sw - 8)
		if float(s["cd"]) > 0.01:
			var f := clampf(float(s["cd"]) / maxf(float(s["max"]), 0.01), 0.0, 1.0)
			draw_rect(Rect2(r.position.x, r.position.y + r.size.y * (1.0 - f), r.size.x, r.size.y * f), Color(0, 0, 0, 0.55))
	if player.mode == "dungeon" and player.parcel_cond < 99.9:
		var pr := Rect2(24, vp.y - 40, 200, 12)
		_bar(pr, player.parcel_cond / 100.0, Color("#e0b040"))
		_txt(Vector2(24, vp.y - 50), "PARCEL  %d%%" % int(player.parcel_cond), 15, Color("#ffd89a"))


func _minimap(vp: Vector2) -> void:
	var sz := 180.0
	var org := Vector2(vp.x - sz - 24, 24)
	draw_rect(Rect2(org, Vector2(sz, sz)).grow(4), INK)
	draw_rect(Rect2(org, Vector2(sz, sz)), Color(0.05, 0.04, 0.06, 0.85))
	var tex: Texture2D = dungeon.minimap_texture()
	if tex == null:
		return
	var view_tiles := 56.0
	var p: Vector2 = dungeon.player_tile()
	var scale_px := sz / view_tiles
	var src_tiles := Vector2(view_tiles, view_tiles)
	var top_left := p - src_tiles * 0.5
	# draw the visible slice of the map texture
	var tsize := tex.get_size()
	var src := Rect2(top_left, src_tiles)
	var dst := Rect2(org, Vector2(sz, sz))
	# clip source to texture bounds
	var clip := src.intersection(Rect2(Vector2.ZERO, tsize))
	if clip.size.x > 0 and clip.size.y > 0:
		var d2 := Rect2(org + (clip.position - src.position) * scale_px, clip.size * scale_px)
		draw_texture_rect_region(tex, d2, clip)
	# mobs + player
	for m in get_tree().get_nodes_in_group("mob"):
		var mob := m as Mob
		if mob == null or mob.dead or not mob.awake:
			continue
		var mp := Vector2(mob.global_position.x, mob.global_position.z)
		var d: Vector2 = (mp - p) * scale_px + dst.get_center()
		if dst.has_point(d):
			draw_rect(Rect2(d - Vector2(2, 2), Vector2(4, 4)), Color("#ff4a3a") if not mob.is_boss else Color("#ffd24a"))
	for tgt in dungeon.minimap_markers():
		var d3: Vector2 = (tgt["pos"] - p) * scale_px + dst.get_center()
		if dst.has_point(d3):
			draw_rect(Rect2(d3 - Vector2(3, 3), Vector2(6, 6)), tgt["col"])
	var c := dst.get_center()
	var fwd := Vector2(-sin(player.yaw), -cos(player.yaw))
	var perp := Vector2(-fwd.y, fwd.x)
	draw_colored_polygon(PackedVector2Array([c + fwd * 7, c - fwd * 4 + perp * 5, c - fwd * 4 - perp * 5]), Color("#7ed957"))
