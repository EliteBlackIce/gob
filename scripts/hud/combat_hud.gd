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
var _hearts: Array = []
var _panel_sb: StyleBoxTexture

const HEART := [
	"..XX.XX..",
	".XXXXXXX.",
	"XXXXXXXXX",
	"XXXXXXXXX",
	"XXXXXXXXX",
	".XXXXXXX.",
	"..XXXXX..",
	"...XXX...",
	"....X....",
]


## 9x9 MC heart. mode: 0 empty, 1 half, 2 full, 3 white (damage trail).
func _make_heart(mode: int) -> ImageTexture:
	var img := Image.create(11, 11, false, Image.FORMAT_RGBA8)
	var inside := {}
	for y in 9:
		for x in 9:
			if HEART[y][x] == "X":
				inside[Vector2i(x + 1, y + 1)] = true
	for y in 11:
		for x in 11:
			var v := Vector2i(x, y)
			if inside.has(v):
				var col := Color("#3b1212")
				if mode == 3:
					col = Color("#ffffff")
				elif mode == 2 or (mode == 1 and x <= 5):
					col = Color("#e8302a")
					if (x == 3 and y == 3) or (x == 4 and y == 2) or (x == 3 and y == 2):
						col = Color("#ff9a9a")
					elif y >= 6 and x > 5:
						col = Color("#b01818")
				img.set_pixelv(v, col)
			else:
				var edge := false
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
					if inside.has(v + d):
						edge = true
				if edge:
					img.set_pixelv(v, Color("#000000"))
	return ImageTexture.create_from_image(img)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_font = PixelFont.get_font()
	_last_level = Game.level
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for m in 4:
		_hearts.append(_make_heart(m))
	_panel_sb = StyleBoxTexture.new()
	_panel_sb.texture = UI.panel_texture()
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		_panel_sb.set_texture_margin(side, 5)


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
	font_size = UI.snap_size(font_size)
	var p := pos
	if align == HORIZONTAL_ALIGNMENT_CENTER and width <= 0.0:
		p.x -= _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x * 0.5
	var so := float(font_size) / 8.0
	draw_string(_font, p + Vector2(so, so), s, HORIZONTAL_ALIGNMENT_LEFT, width, font_size, Color(0.1, 0.1, 0.1, 0.9))
	draw_string(_font, p, s, HORIZONTAL_ALIGNMENT_LEFT, width, font_size, col)


func _bar(r: Rect2, frac: float, fill: Color, back := Color(0.1, 0.06, 0.05, 0.85), trail := -1.0, trail_col := Color(1, 1, 1, 0.8)) -> void:
	draw_rect(r.grow(2), Color("#000000"))
	draw_rect(r, back)
	if trail > frac:
		draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(trail, 0, 1), r.size.y)), trail_col)
	draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(frac, 0, 1), r.size.y)), fill)
	draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(frac, 0, 1), maxf(2.0, r.size.y * 0.3))), fill.lightened(0.3))
	var segs := int(r.size.x / 36.0)
	for i in range(1, segs):
		draw_rect(Rect2(r.position.x + r.size.x * float(i) / segs - 1, r.position.y, 2, r.size.y), Color(0, 0, 0, 0.45))


func _draw() -> void:
	if player == null or not is_instance_valid(player):
		return
	var vp := size
	# ---- hearts (top left) - ten of them, whatever your max HP is
	var maxhp := maxf(player.max_hp, 1.0)
	var units := clampf(player.hp / maxhp, 0.0, 1.0) * 10.0
	var trail_units := clampf(_hp_trail, 0.0, 1.0) * 10.0
	var low := player.hp / maxhp < 0.3
	for i in 10:
		var m := 0
		if units >= i + 0.99:
			m = 2
		elif units >= i + 0.4:
			m = 1
		elif trail_units > i + 0.05:
			m = 3
		var hp_pos := Vector2(24 + i * 29, 20)
		if low:
			hp_pos.y += randi_range(-1, 1) * 2.0
		draw_texture_rect(_hearts[m], Rect2(hp_pos, Vector2(33, 33)), false)
	_txt(Vector2(24 + 10 * 29 + 12, 44), "%d/%d" % [int(ceil(player.hp)), int(round(player.max_hp))], 16, Color.WHITE)
	_txt(Vector2(24, 82), "Lv %d" % Game.level, 16, Color("#80ff20"))
	_txt(Vector2(100, 82), "%d copper" % Game.copper, 16, Color("#ffd24a"))
	var ly := 106.0
	var days := Game.quota_days_left()
	var qcol := Color("#ffe27a") if int(Game.quota["paid"]) < int(Game.quota["target"]) else Color("#9dffa0")
	if days <= 1 and int(Game.quota["paid"]) < int(Game.quota["target"]):
		qcol = Color("#ff7a6a")
	_txt(Vector2(24, ly), "Quota #%d: %d/%d  (%d day%s)" % [Game.quota["n"], Game.quota["paid"], Game.quota["target"], days, "" if days == 1 else "s"], 16, qcol)
	ly += 24.0
	if not Game.scrap.is_empty():
		_txt(Vector2(24, ly), "Sack %d/%d  (~%d copper)" % [Game.scrap.size(), Scrap.MAX_CARRY, Game.scrap_total()], 16, Color("#ffe27a"))
		ly += 24.0
	if Game.skill_points > 0:
		_txt(Vector2(24, ly), "%d skill point%s!  (visit the cellar)" % [Game.skill_points, "s" if Game.skill_points > 1 else ""], 16, Color("#9dffa0"))
		ly += 24.0
	# statuses
	var sx := 24.0
	var sy := ly + 4.0
	for s in player.statuses:
		var col := Color("#ff9a3a") if s == "burn" else (Color("#7aff6a") if s == "poison" else Color("#9fd8ff"))
		draw_rect(Rect2(sx, sy, 78, 22), INK)
		draw_rect(Rect2(sx + 2, sy + 2, 74, 18), col.darkened(0.45))
		_txt(Vector2(sx + 6, sy + 18), str(s).to_upper(), 16, col)
		sx += 84.0
	# ---- hotbar (bottom center)
	_hotbar(vp)
	# ---- boss bar
	if boss != null and is_instance_valid(boss) and not boss.dead and boss.awake:
		var bw := minf(vp.x * 0.5, 720.0)
		var br := Rect2((vp.x - bw) * 0.5, 84, bw, 20)
		_txt(Vector2(vp.x * 0.5, 72), boss_name.to_upper(), 26, Color("#ffd89a"), HORIZONTAL_ALIGNMENT_CENTER, 0)
		_bar(br, boss.hp / boss.max_hp, Color("#c02a2a"), Color(0.1, 0.05, 0.05, 0.9))
		_txt(Vector2(vp.x * 0.5, br.end.y + 20), boss_title, 15, Color("#c8b890"), HORIZONTAL_ALIGNMENT_CENTER, 0)
		if boss is Boss and (boss as Boss).phase == 2:
			draw_rect(Rect2(br.position.x + bw * 0.5 - 1, br.position.y - 4, 2, 28), Color(1, 1, 1, 0.5))
	elif objective != "":
		_txt(Vector2(vp.x * 0.5, 72), objective, 22, Color("#ffd89a"), HORIZONTAL_ALIGNMENT_CENTER, 0)
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
	var sw := 88.0
	var gap := 4.0
	var total := slots.size() * sw + (slots.size() - 1) * gap
	var x0 := (vp.x - total) * 0.5
	var y0 := vp.y - 84.0
	# experience bar sits just above the hotbar, like the real thing
	var need := Stats.xp_needed(Game.level)
	var xr := Rect2(x0, y0 - 22, total, 8)
	draw_rect(xr.grow(2), Color.BLACK)
	draw_rect(xr, Color("#2a3a1a"))
	draw_rect(Rect2(xr.position, Vector2(xr.size.x * clampf(float(Game.xp) / float(need), 0.0, 1.0), xr.size.y)), Color("#80ff20"))
	draw_rect(Rect2(xr.position, Vector2(xr.size.x * clampf(float(Game.xp) / float(need), 0.0, 1.0), 3)), Color("#c0ff80"))
	for i in range(1, 20):
		draw_rect(Rect2(xr.position.x + xr.size.x * i / 20.0 - 1, xr.position.y, 2, xr.size.y), Color(0, 0, 0, 0.5))
	_txt(Vector2(vp.x * 0.5, y0 - 30), str(Game.level), 16, Color("#80ff20"), HORIZONTAL_ALIGNMENT_CENTER, 0)
	for i in slots.size():
		var s: Dictionary = slots[i]
		var r := Rect2(x0 + i * (sw + gap), y0, sw, 64)
		draw_rect(r, Color("#000000"))
		draw_rect(r.grow(-2), Color("#555555"))
		draw_rect(Rect2(r.position + Vector2(2, 2), Vector2(r.size.x - 4, r.size.y - 4)), Color("#8b8b8b"))
		draw_rect(Rect2(r.position + Vector2(2, 2), Vector2(r.size.x - 6, 2)), Color("#c6c6c6"))
		draw_rect(Rect2(r.position + Vector2(2, r.size.y - 4), Vector2(r.size.x - 4, 2)), Color("#373737"))
		draw_rect(Rect2(r.position + Vector2(r.size.x - 4, 2), Vector2(2, r.size.y - 4)), Color("#373737"))
		draw_rect(Rect2(r.position + Vector2(4, 4), Vector2(r.size.x - 8, r.size.y - 8)), Color(0.07, 0.07, 0.08, 0.72))
		_txt(Vector2(r.position.x + 7, r.position.y + 22), str(s["key"]), 16, GOLD)
		var lab := str(s["label"])
		_txt(Vector2(r.position.x + 7, r.position.y + 52), lab.substr(0, 7), 16, s["col"])
		if float(s["cd"]) > 0.01:
			var f := clampf(float(s["cd"]) / maxf(float(s["max"]), 0.01), 0.0, 1.0)
			draw_rect(Rect2(r.position.x + 4, r.position.y + 4 + (r.size.y - 8) * (1.0 - f), r.size.x - 8, (r.size.y - 8) * f), Color(1, 1, 1, 0.4))
	if player.mode == "dungeon" and player.parcel_cond < 99.9:
		var pr := Rect2(24, vp.y - 40, 200, 12)
		_bar(pr, player.parcel_cond / 100.0, Color("#e0b040"))
		_txt(Vector2(24, vp.y - 50), "PARCEL  %d%%" % int(player.parcel_cond), 16, Color("#ffd89a"))


func _minimap(vp: Vector2) -> void:
	var sz := 180.0
	var org := Vector2(vp.x - sz - 24, 24)
	draw_style_box(_panel_sb, Rect2(org, Vector2(sz, sz)).grow(6))
	draw_rect(Rect2(org, Vector2(sz, sz)), Color(0.02, 0.02, 0.03, 0.9))
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
