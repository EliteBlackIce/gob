class_name UI
extends CanvasLayer
## All 2D: HUD, parchment menus, skill tree, riddle panel, stamp QTE and the
## "clip" banner that fires when something hilarious happens.

const INK := Color("#120d0a")
const TEXT := Color("#e4e4e4")
const PARCH := Color("#1c1612")
const PARCH_DARK := Color("#120d0a")
const WOOD := Color("#4a4038")
const GOLD := Color("#f3c14a")

var modal_open := false
var modal_tag := ""
var capture_wanted := false
var hud_player: Player = null

var _root: Control
var _hud: Control
var _prompt: Label
var _toasts: VBoxContainer
var _timer: Label
var _dest: Label
var _compass: Control
var _parcel_name: Label
var _parcel_bar: ProgressBar
var _parcel_status: Label
var combat: CombatHud
var _mandate: Label
var _crosshair: Control
var _fade: ColorRect
var _dmg: ColorRect
var _pause_label: Label
var _modal: Control
var _banner: Control
var _banner_title: Label
var _banner_sub: Label
var _qte: Control
var _qte_ring: Control
var _theme: Theme

var _hint_panel: PanelContainer
var _hint_label: Label
var _hint_queue: Array = []
var _hint_busy := false
var _qte_cb: Callable
var _qte_t := 0.0
var _qte_total := 1.15
var _qte_window := 0.4
var _qte_active := false
var _slow_tw: Tween
var compass_angle := 0.0
var show_compass := false


class Compass extends Control:
	var angle := 0.0

	func _draw() -> void:
		var c := size * 0.5
		draw_circle(c, 26, Color(0.1, 0.07, 0.04, 0.7))
		var dir := Vector2(sin(angle), -cos(angle))
		var perp := Vector2(-dir.y, dir.x)
		draw_colored_polygon(PackedVector2Array([c + dir * 20, c - dir * 10 + perp * 11, c - dir * 4, c - dir * 10 - perp * 11]), Color("#f3c14a"))


class QteRing extends Control:
	var t := 0.0
	var total := 1.0
	var window := 0.3
	var flash := Color(1, 1, 1, 0)

	func _draw() -> void:
		var c := size * 0.5
		var target := 46.0
		var r := lerpf(150.0, target, clampf(t / total, 0.0, 1.2))
		draw_circle(c, 60.0, Color(0.1, 0.07, 0.04, 0.55))
		var wr := window / total * (150.0 - target)
		draw_arc(c, target, 0, TAU, 48, Color("#9dffa0"), maxf(4.0, wr * 0.9), true)
		draw_arc(c, r, 0, TAU, 64, Color("#f3c14a"), 6.0, true)
		draw_string(ThemeDB.fallback_font, c + Vector2(-26, 8), "STAMP", HORIZONTAL_ALIGNMENT_CENTER, 52, 18, Color.WHITE)


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_theme = _make_theme()
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = _theme
	_root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_root)
	_build_hud()
	_build_banner()
	_build_qte()
	_dmg = ColorRect.new()
	_dmg.color = Color(0.85, 0.08, 0.05, 0.0)
	_dmg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dmg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_dmg)
	_pause_label = _label("Click to resume", 24, Color("#fff3cf"), true, _root)
	_pause_label.visible = false
	_pause_label.set_anchors_preset(Control.PRESET_CENTER)
	_pause_label.offset_left = -330
	_pause_label.offset_right = 330
	_pause_label.offset_top = -20
	_pause_label.offset_bottom = 20
	_pause_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pause_label.visible = false
	_fade = ColorRect.new()
	_fade.color = Color(0.04, 0.03, 0.05, 1.0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_fade)
	Game.moment_recorded.connect(_on_moment)


# ---------- theme helpers ----------

func _box(color: Color, border := INK, bw := 3, radius := 0, pad := 14) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = pad * 0.6
	sb.content_margin_bottom = pad * 0.6
	return sb


static var _panel_tex: ImageTexture
static var _btn_tex := {}


static func _stone_noise(x: int, y: int, base: Color, amt := 0.1) -> Color:
	var f := 1.0 + (Vox.hash3(x, y, 5) - 0.5) * 2.0 * amt
	var big := 1.0 + (Vox.hash3(x / 3, y / 3, 9) - 0.5) * amt * 1.6
	return Color(base.r * f * big, base.g * f * big, base.b * f * big)


## Minecraft-menu container: flat dark stone with a black outline and a light/dark bevel.
static func panel_texture() -> ImageTexture:
	if _panel_tex != null:
		return _panel_tex
	var n := 24
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var c := Color("#363636")
			var dl := x                      # distance from each edge
			var dr := n - 1 - x
			var dt := y
			var db := n - 1 - y
			var d := mini(mini(dl, dr), mini(dt, db))
			if d < 2:
				c = Color("#050505")
			elif d < 5:
				if (dt == d and dt < db) or (dl == d and dl < dr):
					c = Color("#6d6d6d")        # light top/left
				else:
					c = Color("#1c1c1c")        # dark bottom/right
			img.set_pixel(x, y, c)
	_panel_tex = ImageTexture.create_from_image(img)
	return _panel_tex


## Minecraft button. state: 0 normal, 1 hover, 2 pressed, 3 disabled.
static func button_texture(state: int) -> ImageTexture:
	if _btn_tex.has(state):
		return _btn_tex[state]
	var n := 24
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var base: Color = [Color("#6f6f6f"), Color("#7d86a6"), Color("#555555"), Color("#3a3a3a")][state]
	for y in n:
		for x in n:
			var dl := x
			var dr := n - 1 - x
			var dt := y
			var db := n - 1 - y
			var d := mini(mini(dl, dr), mini(dt, db))
			var c: Color = base
			if d < 2:
				c = Color("#ffffff") if state == 1 else Color("#050505")
			elif d < 4:
				var top_left := (dt == d and dt < db) or (dl == d and dl < dr)
				if (top_left and state != 2 and state != 3) or (not top_left and state == 2):
					c = base.lightened(0.28)
				else:
					c = base.darkened(0.34)
			elif y > n - 8 and state != 2:
				c = base.darkened(0.08)
			img.set_pixel(x, y, c)
	var t := ImageTexture.create_from_image(img)
	_btn_tex[state] = t
	return t


static var _dirt_tex: ImageTexture


## 16x16 dirt tile scaled up 6x (nearest): the classic menu background.
static func dirt_texture() -> ImageTexture:
	if _dirt_tex != null:
		return _dirt_tex
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for y in 16:
		for x in 16:
			var h := Vox.hash3(x, y, 21)
			var base := Color("#5c4128")
			if h < 0.2:
				base = Color("#4a3320")
			elif h > 0.82:
				base = Color("#6e5030")
			elif h > 0.7 and Vox.hash3(x / 2, y / 2, 3) > 0.5:
				base = Color("#524e4a")
			img.set_pixel(x, y, base)
	img.resize(96, 96, Image.INTERPOLATE_NEAREST)
	_dirt_tex = ImageTexture.create_from_image(img)
	return _dirt_tex


static var _grab_tex: Array = []


static func slider_grabber(hover: bool) -> ImageTexture:
	if _grab_tex.is_empty():
		for h in 2:
			var img := Image.create(16, 36, false, Image.FORMAT_RGBA8)
			var base := Color("#7d86a6") if h == 1 else Color("#8a8a8a")
			for y in 36:
				for x in 16:
					var d := mini(mini(x, 15 - x), mini(y, 35 - y))
					var c := base
					if d < 2:
						c = Color("#050505")
					elif d < 4:
						c = base.lightened(0.3) if (x < 4 or y < 4) else base.darkened(0.35)
					img.set_pixel(x, y, c)
			_grab_tex.append(ImageTexture.create_from_image(img))
	return _grab_tex[1 if hover else 0]


func _make_theme() -> Theme:
	var th := Theme.new()
	th.default_font = PixelFont.get_font()
	th.default_font_size = 16
	for st in [["normal", 0], ["hover", 1], ["pressed", 2], ["disabled", 3]]:
		var sb := StyleBoxTexture.new()
		sb.texture = button_texture(st[1])
		sb.texture_margin_left = 4
		sb.texture_margin_right = 4
		sb.texture_margin_top = 4
		sb.texture_margin_bottom = 4
		sb.content_margin_left = 14
		sb.content_margin_right = 14
		sb.content_margin_top = 8
		sb.content_margin_bottom = 10
		th.set_stylebox(st[0], "Button", sb)
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	th.set_color("font_color", "Button", Color("#e8e8e8"))
	th.set_color("font_hover_color", "Button", Color("#ffffa0"))
	th.set_color("font_pressed_color", "Button", Color("#ffffa0"))
	th.set_color("font_disabled_color", "Button", Color("#9a9a9a"))
	th.set_color("font_shadow_color", "Button", Color("#2a2a2a"))
	th.set_constant("shadow_offset_x", "Button", 2)
	th.set_constant("shadow_offset_y", "Button", 2)
	th.set_font_size("font_size", "Button", 16)
	var psb := StyleBoxTexture.new()
	psb.texture = panel_texture()
	psb.texture_margin_left = 5
	psb.texture_margin_right = 5
	psb.texture_margin_top = 5
	psb.texture_margin_bottom = 5
	psb.content_margin_left = 26
	psb.content_margin_right = 26
	psb.content_margin_top = 20
	psb.content_margin_bottom = 20
	th.set_stylebox("panel", "PanelContainer", psb)
	th.set_stylebox("fill", "ProgressBar", _box(Color("#7ed957"), Color(0, 0, 0, 0), 0, 0, 0))
	th.set_stylebox("background", "ProgressBar", _box(Color(0.1, 0.1, 0.1, 0.9), INK, 2, 0, 0))
	# sliders (Options screen)
	var track := StyleBoxFlat.new()
	track.bg_color = Color("#101010")
	track.border_color = Color("#6d6d6d")
	track.set_border_width_all(2)
	track.content_margin_top = 12
	track.content_margin_bottom = 12
	th.set_stylebox("slider", "HSlider", track)
	th.set_stylebox("grabber_area", "HSlider", StyleBoxEmpty.new())
	th.set_stylebox("grabber_area_highlight", "HSlider", StyleBoxEmpty.new())
	th.set_icon("grabber", "HSlider", slider_grabber(false))
	th.set_icon("grabber_highlight", "HSlider", slider_grabber(true))
	th.set_icon("grabber_disabled", "HSlider", slider_grabber(false))
	th.set_constant("center_grabber", "HSlider", 1)
	return th


## The bitmap font is only crisp at whole multiples of its 8px design size.
static func snap_size(size: int) -> int:
	if size < 24:
		return 16
	if size < 36:
		return 24
	if size < 48:
		return 32
	return 48


func _label(text: String, size := 20, color := Color.WHITE, outline := true, parent: Node = null) -> Label:
	size = snap_size(size)
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0.12, 0.12, 0.12, 0.95))
	var so := maxi(2, size / 8)
	l.add_theme_constant_override("shadow_offset_x", so)
	l.add_theme_constant_override("shadow_offset_y", so)
	if parent != null:
		parent.add_child(l)
	return l


func _ink(text: String, size := 20, parent: Node = null) -> Label:
	var l := _label(text, size, TEXT, false, parent)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if size >= 30:
		l.add_theme_color_override("font_color", Color("#ffffa0"))
	return l


# ---------- HUD ----------

func _build_hud() -> void:
	_hud = Control.new()
	_hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_hud)

	combat = CombatHud.new()
	_hud.add_child(combat)

	var top := VBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_CENTER_TOP)
	top.position = Vector2(-200, 12)
	top.custom_minimum_size = Vector2(400, 0)
	top.alignment = BoxContainer.ALIGNMENT_BEGIN
	_hud.add_child(top)
	_dest = _label("", 22, Color.WHITE, true, top)
	_dest.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_compass = Compass.new()
	_compass.custom_minimum_size = Vector2(60, 60)
	_compass.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	top.add_child(_compass)
	_mandate = _label("", 16, Color("#ffd89a"), true, top)
	_mandate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mandate.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_mandate.custom_minimum_size = Vector2(400, 0)

	_timer = _label("", 34, Color.WHITE, true, _hud)
	_timer.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_timer.position = Vector2(-160, 12)

	var bl := VBoxContainer.new()
	bl.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	bl.position = Vector2(20, -100)
	bl.custom_minimum_size = Vector2(300, 0)
	_hud.add_child(bl)
	_parcel_name = _label("", 20, Color.WHITE, true, bl)
	_parcel_bar = ProgressBar.new()
	_parcel_bar.custom_minimum_size = Vector2(300, 18)
	_parcel_bar.show_percentage = false
	_parcel_bar.max_value = 100.0
	bl.add_child(_parcel_bar)
	_parcel_status = _label("", 18, Color("#ffd89a"), true, bl)

	_prompt = _label("", 26, Color.WHITE, true, _hud)
	_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.position = Vector2(-300, -130)
	_prompt.custom_minimum_size = Vector2(600, 0)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_toasts = VBoxContainer.new()
	_toasts.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toasts.position = Vector2(-300, 215)
	_toasts.custom_minimum_size = Vector2(600, 0)
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_toasts)

	_hint_panel = PanelContainer.new()
	_hint_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint_panel.anchor_left = 0.5
	_hint_panel.anchor_right = 0.5
	_hint_panel.offset_left = -330
	_hint_panel.offset_right = 330
	_hint_panel.offset_top = -250
	_hint_panel.offset_bottom = -170
	_hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_panel.self_modulate = Color(1, 1, 1, 0.9)
	_hint_label = _label("", 21, Color("#fff3cf"), false, _hint_panel)
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hint_panel.visible = false
	_hud.add_child(_hint_panel)

	_crosshair = Control.new()
	_crosshair.set_anchors_preset(Control.PRESET_CENTER)
	_hud.add_child(_crosshair)
	for r in [Rect2(-9, -2, 18, 4), Rect2(-2, -9, 4, 18)]:
		var edge := ColorRect.new()
		edge.color = Color(0, 0, 0, 0.55)
		edge.position = r.position - Vector2(1, 1)
		edge.size = r.size + Vector2(2, 2)
		_crosshair.add_child(edge)
	for r in [Rect2(-8, -1, 16, 2), Rect2(-1, -8, 2, 16)]:
		var arm := ColorRect.new()
		arm.color = Color(1, 1, 1, 0.85)
		arm.position = r.position
		arm.size = r.size
		_crosshair.add_child(arm)
	_hud.visible = false


var _sock_ov: Control = null


## A Ceiling Sock is on your face: chunky knitted overlay with two eye holes.
func set_sock(on: bool) -> void:
	if on and _sock_ov == null:
		_sock_ov = Control.new()
		_sock_ov.set_anchors_preset(Control.PRESET_FULL_RECT)
		_sock_ov.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var img := Image.create(64, 36, false, Image.FORMAT_RGBA8)
		for y in 36:
			for x in 64:
				var c := Color("#c8282a") if (y / 3) % 2 == 0 else Color("#efe6d2")
				if (x + y) % 4 == 0:
					c = c.darkened(0.12)                       # knit texture
				var a := 1.0
				for e in [Vector2(23, 16), Vector2(41, 16)]:
					var dx: float = (x + 0.5 - e.x) / 6.5
					var dy: float = (y + 0.5 - e.y) / 4.5
					var r: float = dx * dx + dy * dy
					if r < 1.0:
						a = 0.0
					elif r < 1.5:
						c = Color("#3a1414")
				img.set_pixel(x, y, Color(c.r, c.g, c.b, a))
		var tr := TextureRect.new()
		tr.texture = ImageTexture.create_from_image(img)
		tr.stretch_mode = TextureRect.STRETCH_SCALE
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_sock_ov.add_child(tr)
		var l := _label("THERE IS A SOCK ON YOUR FACE!\n[LMB] punch it     [SHIFT] roll it off", 24, Color("#ffffff"), true, _sock_ov)
		l.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		l.offset_left = -400
		l.offset_right = 400
		l.offset_top = -210
		l.offset_bottom = -140
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_hud.add_child(_sock_ov)
		_hud.move_child(_sock_ov, 1)
	if _sock_ov != null:
		_sock_ov.visible = on


func show_hud(v: bool) -> void:
	_hud.visible = v


func flash_damage(strength := 0.4) -> void:
	_dmg.color.a = strength
	var tw := _dmg.create_tween().set_ignore_time_scale(true)
	tw.tween_property(_dmg, "color:a", 0.0, 0.5)


## A couple of frames of freeze on a big hit. Skipped if slow-mo is already running.
func hitstop(secs := 0.07) -> void:
	if Engine.time_scale < 0.99:
		return
	Engine.time_scale = 0.06
	await get_tree().create_timer(secs, true, false, true).timeout
	if Engine.time_scale < 0.2:
		Engine.time_scale = 1.0


func configure_hud(mode: Variant) -> void:
	if typeof(mode) == TYPE_BOOL:
		mode = "route" if mode else "hub"
	var island_mode: bool = str(mode) == "route"
	combat.dungeon = null
	combat.boss = null
	set_sock(false)
	combat.objective = ""
	_dest.visible = island_mode
	_compass.visible = island_mode
	_timer.visible = island_mode
	_parcel_name.visible = island_mode
	_parcel_bar.visible = island_mode
	_parcel_status.visible = island_mode
	show_compass = island_mode
	_mandate.visible = island_mode
	_mandate.text = "Grubnik says: " + str(Game.mandate["text"])
	_mandate.modulate.a = 1.0
	if island_mode:
		var tw := _mandate.create_tween()
		tw.tween_interval(12.0)
		tw.tween_property(_mandate, "modulate:a", 0.0, 1.5)


func set_dest(text: String) -> void:
	_dest.text = text


func set_timer(sec: float) -> void:
	var s := int(ceil(maxf(sec, 0.0)))
	_timer.text = "%d:%02d" % [s / 60, s % 60]
	_timer.add_theme_color_override("font_color", Color("#ff6a5a") if sec < 30.0 else Color.WHITE)


func _process(delta: float) -> void:
	if _pause_label != null:
		_pause_label.visible = capture_wanted and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and not modal_open and _hud != null and _hud.visible
	if _hud == null or not _hud.visible:
		return
	var p := hud_player
	combat.player = p if (p != null and is_instance_valid(p)) else null
	if p != null and is_instance_valid(p):
		_crosshair.visible = p.mode != "hub" or true
		if p.interact_target != null and not modal_open:
			_prompt.text = "[E]  " + p.interact_target.prompt
		else:
			_prompt.text = ""
		var parcel: Parcel = p.carried
		if parcel != null and is_instance_valid(parcel):
			_parcel_name.text = parcel.title
			_parcel_bar.value = parcel.condition
			_parcel_status.text = parcel.status_text()
		elif show_compass:
			_parcel_name.text = "NO PARCEL!"
			_parcel_bar.value = 0.0
			_parcel_status.text = "find it, quickly"
		(_compass as Compass).angle = compass_angle
		_compass.queue_redraw()
	if _qte_active:
		_qte_t += delta
		(_qte_ring as QteRing).t = _qte_t
		_qte_ring.queue_redraw()
		if _qte_t > _qte_total + _qte_window * 0.6:
			_finish_qte(false)


## Tutorial tip. Each id shows once per save; tips queue up so they never overlap.
func hint(id: String, text: String, secs := 7.0) -> void:
	if Game.hints_seen.has(id):
		return
	Game.hints_seen[id] = true
	_hint_queue.append([text, secs])
	_pump_hints()


func _pump_hints() -> void:
	if _hint_busy or _hint_queue.is_empty():
		return
	_hint_busy = true
	var item: Array = _hint_queue.pop_front()
	_hint_label.text = str(item[0])
	_hint_panel.modulate.a = 0.0
	_hint_panel.visible = true
	Sfx.play("blip", -6.0, 1.3)
	var tw := create_tween().set_ignore_time_scale(true)
	tw.tween_property(_hint_panel, "modulate:a", 1.0, 0.25)
	tw.tween_interval(float(item[1]))
	tw.tween_property(_hint_panel, "modulate:a", 0.0, 0.4)
	await tw.finished
	_hint_panel.visible = false
	_hint_busy = false
	Game.save_game()
	_pump_hints()


func toast(text: String, color := Color.WHITE) -> void:
	var l := _label(text, 26, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toasts.add_child(l)
	var tw := l.create_tween()
	tw.tween_interval(2.0)
	tw.tween_property(l, "modulate:a", 0.0, 0.5)
	tw.tween_callback(l.queue_free)
	while _toasts.get_child_count() > 4:
		_toasts.get_child(0).queue_free()
		_toasts.remove_child(_toasts.get_child(0))


# ---------- fade / slow-mo / banner ----------

func fade_to(alpha: float, dur := 0.4) -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", alpha, dur)
	await tw.finished


func slowmo(scale: float, real_secs: float) -> void:
	if _slow_tw != null and _slow_tw.is_valid():
		_slow_tw.kill()
	Engine.time_scale = scale
	_slow_tw = create_tween().set_ignore_time_scale(true)
	_slow_tw.tween_interval(real_secs)
	_slow_tw.tween_method(func(v): Engine.time_scale = v, scale, 1.0, 0.5)


func _build_banner() -> void:
	_banner = Control.new()
	_banner.set_anchors_preset(Control.PRESET_FULL_RECT)
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.modulate.a = 0.0
	_root.add_child(_banner)
	var strip := ColorRect.new()
	strip.color = Color(0.08, 0.04, 0.02, 0.72)
	strip.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	strip.anchor_right = 1.0
	strip.offset_top = -190
	strip.offset_bottom = -90
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.add_child(strip)
	_banner_title = _label("", 54, GOLD, true, _banner)
	_banner_title.anchor_left = 0.0
	_banner_title.anchor_right = 1.0
	_banner_title.anchor_top = 0.5
	_banner_title.anchor_bottom = 0.5
	_banner_title.offset_left = 0
	_banner_title.offset_right = 0
	_banner_title.offset_top = -190
	_banner_title.offset_bottom = -128
	_banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner_sub = _label("", 20, Color("#f3e3b5"), true, _banner)
	_banner_sub.anchor_left = 0.0
	_banner_sub.anchor_right = 1.0
	_banner_sub.offset_left = 0
	_banner_sub.offset_right = 0
	_banner_sub.anchor_top = 0.5
	_banner_sub.anchor_bottom = 0.5
	_banner_sub.offset_top = -128
	_banner_sub.offset_bottom = -96
	_banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


## Big centre-screen banner for dungeon events ("ROOM CLEARED", boss intros, level ups).
func announce(title_text: String, sub := "", color := GOLD, secs := 2.2) -> void:
	_banner_title.text = title_text
	_banner_title.add_theme_color_override("font_color", color)
	_banner_title.add_theme_font_size_override("font_size", 54 if title_text.length() <= 24 else (42 if title_text.length() <= 36 else 32))
	_banner_sub.text = sub
	var tw := create_tween().set_ignore_time_scale(true)
	tw.tween_property(_banner, "modulate:a", 1.0, 0.15)
	tw.tween_interval(secs)
	tw.tween_property(_banner, "modulate:a", 0.0, 0.5)


func _on_moment(caption: String) -> void:
	_banner_title.add_theme_color_override("font_color", GOLD)
	_banner_title.text = caption
	_banner_title.add_theme_font_size_override("font_size", 54 if caption.length() <= 24 else (42 if caption.length() <= 36 else 32))
	_banner_sub.text = "CLIP SAVED  -  press C to open your clips folder"
	Sfx.play("clip")
	var tw := create_tween().set_ignore_time_scale(true)
	tw.tween_property(_banner, "modulate:a", 1.0, 0.12)
	tw.tween_interval(1.9)
	tw.tween_property(_banner, "modulate:a", 0.0, 0.5)
	if Engine.time_scale >= 0.99:
		slowmo(0.45, 0.7)


# ---------- stamp QTE ----------

func _build_qte() -> void:
	_qte = Control.new()
	_qte.set_anchors_preset(Control.PRESET_CENTER)
	_qte.visible = false
	_root.add_child(_qte)
	_qte_ring = QteRing.new()
	_qte_ring.size = Vector2(320, 320)
	_qte_ring.position = Vector2(-160, -160)
	_qte.add_child(_qte_ring)
	var hint := _label("Press E on the green ring!", 26, Color.WHITE, true, _qte)
	hint.position = Vector2(-170, 120)


func qte(cb: Callable) -> void:
	_qte_cb = cb
	_qte_window = 0.42 * (1.6 if Game.has_skill("stamp") else 1.0)
	_qte_total = 1.15
	_qte_t = 0.0
	(_qte_ring as QteRing).total = _qte_total
	(_qte_ring as QteRing).window = _qte_window
	_qte_active = true
	_qte.visible = true
	Sfx.play("squelch", -6.0, 1.5)


func _finish_qte(ok: bool) -> void:
	if not _qte_active:
		return
	_qte_active = false
	_qte.visible = false
	if _qte_cb.is_valid():
		_qte_cb.call(ok)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory") and _hud != null and _hud.visible:
		var pl := hud_player
		if modal_open and modal_tag == "inv":
			close_modal()
			get_viewport().set_input_as_handled()
			return
		if not modal_open and pl != null and is_instance_valid(pl) and not pl.dead and pl.mode != "route":
			Menus.show_inventory(self, "pack")
			get_viewport().set_input_as_handled()
			return
	if _qte_active and event.is_action_pressed("interact"):
		var d := absf(_qte_t - _qte_total)
		_finish_qte(d <= _qte_window * 0.5 or (_qte_t > _qte_total - _qte_window * 0.5 and _qte_t < _qte_total + _qte_window * 0.3))
		get_viewport().set_input_as_handled()


# ---------- modal windows ----------

func _open_screen(dirt_bg := true) -> void:
	close_modal(false)
	_modal = Control.new()
	_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	_modal.process_mode = Node.PROCESS_MODE_ALWAYS
	_root.add_child(_modal)
	_root.move_child(_fade, _root.get_child_count() - 1)
	modal_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if dirt_bg:
		_modal_dirt()


func _modal_dirt() -> void:
	var dirt := TextureRect.new()
	dirt.texture = dirt_texture()
	dirt.stretch_mode = TextureRect.STRETCH_TILE
	dirt.set_anchors_preset(Control.PRESET_FULL_RECT)
	dirt.modulate = Color(0.32, 0.32, 0.32, 0.9)
	dirt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_modal.add_child(dirt)


func _open_modal(min_width := 640, dim := false) -> VBoxContainer:
	_open_screen(not dim)
	if dim:
		var shade := ColorRect.new()
		shade.color = Color(0, 0, 0, 0.62)
		shade.set_anchors_preset(Control.PRESET_FULL_RECT)
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_modal.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(min_width, 0)
	center.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	panel.add_child(vb)
	return vb


func close_modal(recapture := true) -> void:
	if _modal != null and is_instance_valid(_modal):
		_modal.queue_free()
	_modal = null
	modal_open = false
	modal_tag = ""
	title_open = false
	if get_tree() != null:
		get_tree().paused = false
	if recapture and capture_wanted:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _button(text: String, parent: Node, cb: Callable, enabled := true, center := false) -> Button:
	var b := Button.new()
	b.text = text
	b.disabled = not enabled
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER if center else HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(func():
		Sfx.play("click")
		cb.call())
	parent.add_child(b)
	return b


func show_menu(title: String, subtitle: String, entries: Array, close_text := "Close", on_close := Callable()) -> void:
	var vb := _open_modal(700)
	_ink(title, 34, vb)
	if subtitle != "":
		_ink(subtitle, 18, vb)
	for e in entries:
		var d: Dictionary = e
		var lbl: String = str(d["label"])
		if d.has("desc") and str(d["desc"]) != "":
			lbl += "\n" + str(d["desc"])
		var cb: Callable = d["cb"]
		_button(lbl, vb, func():
			cb.call(), bool(d.get("enabled", true)))
	if close_text != "":
		_button(close_text, vb, func():
			close_modal()
			if on_close.is_valid():
				on_close.call())


func show_letter(title: String, text: String, button := "Understood (sigh)", on_close := Callable()) -> void:
	var vb := _open_modal(640)
	_ink(title, 30, vb)
	var body := _ink(text, 22, vb)
	body.custom_minimum_size = Vector2(560, 0)
	Sfx.play("blip")
	_button(button, vb, func():
		close_modal()
		if on_close.is_valid():
			on_close.call())


func show_riddle(heading: String, question: String, answers: Array, cb: Callable) -> void:
	var vb := _open_modal(660)
	_ink(heading, 24, vb)
	_ink(question, 28, vb)
	for i in answers.size():
		var idx := i
		_button("%d.  %s" % [i + 1, answers[i]], vb, func():
			close_modal()
			cb.call(idx))


func show_skills(on_close := Callable()) -> void:
	var vb := _open_modal(1260)
	_ink("THE CELLAR  -  Skill Tree", 34, vb)
	_ink("Skill points: %d   (one per level up!)" % Game.skill_points, 18, vb)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 12)
	vb.add_child(cols)
	for branch in Game.BRANCHES:
		var col := VBoxContainer.new()
		col.custom_minimum_size = Vector2(196, 0)
		col.add_theme_constant_override("separation", 8)
		cols.add_child(col)
		_ink(branch.to_upper(), 24, col)
		for tier in [1, 2, 3, 4]:
			for id in Game.SKILLS:
				var s: Dictionary = Game.SKILLS[id]
				if s["branch"] != branch or s["tier"] != tier:
					continue
				var owned := Game.has_skill(id)
				var can := Game.can_buy(id)
				var label := ("[x] " if owned else ("[ ] " if can else "[-] ")) + str(s["name"]) + "\n" + str(s["desc"])
				var b := _button(label, col, func():
					if Game.buy_skill(id):
						Sfx.play("coin")
						show_skills(on_close), can)
				b.custom_minimum_size = Vector2(196, 96)
				b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				b.clip_text = false
	_button("Back upstairs", vb, func():
		close_modal()
		if on_close.is_valid():
			on_close.call())


class Logo extends Control:
	var lines: Array = ["GOBLIN", "DELIVERY CO."]
	var font: Font

	func _draw() -> void:
		if font == null:
			return
		var y := 52.0
		for i in lines.size():
			var sz := 64 if i == 0 else 40
			var w := font.get_string_size(lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
			var x := (size.x - w) * 0.5
			var q := float(sz) / 16.0
			for d in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1), Vector2(-1, -1), Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1)]:
				draw_string(font, Vector2(x, y) + d * q * 2.0 + Vector2(q, q), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Color("#0a0a0a"))
			draw_string(font, Vector2(x, y) + Vector2(q, q), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Color("#5a5a5a"))
			draw_string(font, Vector2(x, y), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Color("#bdbdbd") if i == 0 else Color("#a9b894"))
			y += float(sz) + 22.0


const SPLASHES := [
	"Now with 40% more goblin!", "Parcels may scream!", "Grubnik is watching.", "Also try Minecraft!", "100% pure copper!",
	"Quota is life!", "Don't feed the mimic!", "Fragile: contents are your friends.", "Friend slop certified!", "Not liable for stairs!",
	"The dungeon bites back!", "Hold E to deliver!", "Voxels everywhere!", "Bring a buddy (or two)!", "Please don't lick the slime.",
	"Parry or perish!", "Employee of the month: you?", "Scrap is money!", "Rated G for Goblin!", "Insurance not included.",
]

var title_open := false
var _splash: Label = null


func show_title(on_start: Callable, on_reset: Callable) -> void:
	_open_screen(false)
	title_open = true
	show_hud(false)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.42)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_modal.add_child(shade)
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.add_theme_constant_override("separation", 0)
	_modal.add_child(vb)
	var top := Control.new()
	top.custom_minimum_size = Vector2(0, 40)
	vb.add_child(top)
	var logo := Logo.new()
	logo.font = PixelFont.get_font()
	logo.custom_minimum_size = Vector2(0, 190)
	vb.add_child(logo)
	_splash = _label(SPLASHES[randi() % SPLASHES.size()], 24, Color("#ffff55"), true, _modal)
	_splash.anchor_left = 0.5
	_splash.anchor_right = 0.5
	_splash.offset_left = 150
	_splash.offset_top = 150
	_splash.rotation = -0.3
	_splash.pivot_offset = Vector2(0, 12)
	var tw := _splash.create_tween().set_loops()
	tw.tween_property(_splash, "scale", Vector2(1.12, 1.12), 0.45).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_splash, "scale", Vector2(0.95, 0.95), 0.45).set_trans(Tween.TRANS_SINE)
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(440, 0)
	col.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_theme_constant_override("separation", 8)
	vb.add_child(col)
	var sub := _label("You are a goblin. Your boss doesn't care. The parcels are screaming.", 16, Color("#dddddd"), true, col)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 14)
	col.add_child(gap)
	_button("Clock In", col, func():
		title_open = false
		close_modal(false)
		show_hud(true)
		on_start.call(), true, true)
	_button("Options...", col, func():
		show_options(func(): show_title(on_start, on_reset)), true, true)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	col.add_child(row)
	var b1 := _button("Wipe Save", row, func():
		on_reset.call()
		toast("Save wiped. Grubnik has forgotten you.", Color("#ffd89a")), true, true)
	b1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var b2 := _button("Quit Game", row, func(): get_tree().quit(), true, true)
	b2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(fill)
	var foot := HBoxContainer.new()
	foot.custom_minimum_size = Vector2(0, 32)
	vb.add_child(foot)
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(10, 0)
	foot.add_child(pad)
	var fl := _label("Day %d  -  Level %d  -  %d copper" % [Game.day, Game.level, Game.copper], 16, Color("#ffffff"), true, foot)
	fl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var fr := _label("Copyright Grubnik Industries. Do not distribute the parcels.", 16, Color("#ffffff"), true, foot)
	fr.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var pad2 := Control.new()
	pad2.custom_minimum_size = Vector2(10, 0)
	foot.add_child(pad2)


func show_pause(on_resume: Callable, on_title: Callable) -> void:
	var vb := _open_modal(420, true)
	modal_tag = "pause"
	get_tree().paused = true
	var t := _ink("Game Menu", 24, vb)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var back := func():
		close_modal()
		on_resume.call()
	_button("Back to Game", vb, back, true, true)
	_button("Options...", vb, func():
		show_options(func():
			show_pause(on_resume, on_title), true), true, true)
	_button("Open Clips Folder", vb, func():
		var dir := ProjectSettings.globalize_path("user://clips")
		DirAccess.make_dir_recursive_absolute(dir)
		OS.shell_open(dir), true, true)
	_button("Save and Quit to Title", vb, func():
		close_modal(false)
		Game.save_game()
		on_title.call(), true, true)


func _slider_row(vb: Control, title: String, key: String, lo: float, hi: float, step: float, fmt: Callable) -> void:
	var lbl := _label("", 16, Color("#e0e0e0"), true, vb)
	var sl := HSlider.new()
	sl.min_value = lo
	sl.max_value = hi
	sl.step = step
	sl.value = float(Game.settings[key])
	sl.custom_minimum_size = Vector2(0, 36)
	sl.focus_mode = Control.FOCUS_NONE
	var upd := func(v: float):
		lbl.text = "%s: %s" % [title, fmt.call(v)]
	upd.call(sl.value)
	sl.value_changed.connect(func(v: float):
		Game.settings[key] = v
		upd.call(v)
		Game.apply_settings()
		Game.save_settings())
	vb.add_child(sl)


func show_options(on_done: Callable, dim := false) -> void:
	var vb := _open_modal(560, dim)
	modal_tag = "options"
	var t := _ink("Options", 24, vb)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var pct := func(v: float): return "%d%%" % int(round(v * 100.0))
	_slider_row(vb, "Master Volume", "master", 0.0, 1.0, 0.05, pct)
	_slider_row(vb, "Music", "music", 0.0, 1.0, 0.05, pct)
	_slider_row(vb, "Sound Effects", "sfx", 0.0, 1.0, 0.05, pct)
	_slider_row(vb, "FOV", "fov", 60.0, 110.0, 1.0, func(v: float): return "%d" % int(v))
	_slider_row(vb, "Mouse Sensitivity", "sens", 0.25, 2.5, 0.05, pct)
	var cam_btn := _button("", vb, func(): pass, true, true)
	var upd := func():
		cam_btn.text = "Camcorder Filter: %s" % ("ON" if Game.settings["camcorder"] else "OFF")
	upd.call()
	cam_btn.pressed.connect(func():
		Game.settings["camcorder"] = not Game.settings["camcorder"]
		Game.save_settings()
		upd.call())
	var ctl := _label("WASD move  SPACE jump  E interact  TAB pack  LMB attack  RMB block\nSHIFT roll  F kick  Q bottle  R grog  Z holler  V scan  B dance", 16, Color("#a0a0a0"), true, vb)
	ctl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_button("Done", vb, func():
		close_modal(false)
		on_done.call(), true, true)


func show_result(data: Dictionary, on_close: Callable) -> void:
	var vb := _open_modal(720)
	_ink(str(data["title"]), 38, vb)
	_ink(str(data["lines"]), 22, vb)
	if data.has("loot") and (data["loot"] as Array).size() > 0:
		_ink("LOOT", 20, vb).add_theme_color_override("font_color", GOLD)
		var shown := 0
		for it in data["loot"]:
			var item: Dictionary = it
			if shown >= 8:
				break
			shown += 1
			var ll := _label("  %s  %s" % [ItemDB.rarity_name(int(item["rarity"])), ItemDB.title(item)], 18, ItemDB.rarity_color(int(item["rarity"])), true, vb)
			ll.autowrap_mode = TextServer.AUTOWRAP_OFF
		if (data["loot"] as Array).size() > 8:
			_ink("  ...and %d more" % ((data["loot"] as Array).size() - 8), 16, vb)
	if (data["moments"] as Array).size() > 0:
		_ink("CLIPS FROM THIS SHIFT", 20, vb)
		var ml := _ink("- " + "\n- ".join(data["moments"]), 20, vb)
		ml.add_theme_color_override("font_color", Color("#ffb070"))
	var q := _ink(str(data["quote"]), 20, vb)
	q.add_theme_color_override("font_color", Color("#c8b890"))
	_button(str(data.get("button", "Back to the tavern")), vb, func():
		close_modal(false)
		on_close.call())
