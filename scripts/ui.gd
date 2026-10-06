class_name UI
extends CanvasLayer
## All 2D: HUD, parchment menus, skill tree, riddle panel, stamp QTE and the
## "clip" banner that fires when something hilarious happens.

const INK := Color("#2a1a0d")
const PARCH := Color("#ead7a4")
const PARCH_DARK := Color("#cdb47a")
const WOOD := Color("#6a4a2d")
const GOLD := Color("#f3c14a")

var modal_open := false
var capture_wanted := false
var hud_player: Player = null

var _root: Control
var _hud: Control
var _prompt: Label
var _toasts: VBoxContainer
var _copper: Label
var _day: Label
var _timer: Label
var _dest: Label
var _compass: Control
var _parcel_name: Label
var _parcel_bar: ProgressBar
var _parcel_status: Label
var _bottles: Label
var _hearts: Control
var _mandate: Label
var _crosshair: Control
var _fade: ColorRect
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


class Hearts extends Control:
	var hp := 3
	var max_hp := 3

	func _draw() -> void:
		for i in max_hp:
			var c := Vector2(20 + i * 38, 20)
			var col := Color("#e0453a") if i < hp else Color("#4a2a2a")
			draw_circle(c + Vector2(-6, -3), 8, col)
			draw_circle(c + Vector2(6, -3), 8, col)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-13, 0), c + Vector2(13, 0), c + Vector2(0, 16)]), col)


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
	add_child(_root)
	_build_hud()
	_build_banner()
	_build_qte()
	_fade = ColorRect.new()
	_fade.color = Color(0.04, 0.03, 0.05, 1.0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_fade)
	Game.moment_recorded.connect(_on_moment)


# ---------- theme helpers ----------

func _box(color: Color, border := INK, bw := 3, radius := 8, pad := 14) -> StyleBoxFlat:
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


func _make_theme() -> Theme:
	var th := Theme.new()
	th.default_font_size = 20
	th.set_stylebox("normal", "Button", _box(WOOD.lightened(0.1)))
	th.set_stylebox("hover", "Button", _box(WOOD.lightened(0.3), GOLD))
	th.set_stylebox("pressed", "Button", _box(WOOD.darkened(0.1), GOLD))
	th.set_stylebox("disabled", "Button", _box(Color("#4a3a2a"), Color("#2a1f15")))
	th.set_stylebox("focus", "Button", _box(Color(0, 0, 0, 0), GOLD, 2))
	th.set_color("font_color", "Button", Color("#fff3cf"))
	th.set_color("font_hover_color", "Button", Color.WHITE)
	th.set_color("font_disabled_color", "Button", Color("#9a8a6a"))
	th.set_font_size("font_size", "Button", 19)
	th.set_stylebox("panel", "PanelContainer", _box(PARCH, INK, 4, 10, 22))
	th.set_stylebox("fill", "ProgressBar", _box(Color("#7ed957"), Color(0, 0, 0, 0), 0, 4, 0))
	th.set_stylebox("background", "ProgressBar", _box(Color(0.1, 0.07, 0.04, 0.8), INK, 2, 5, 0))
	return th


func _label(text: String, size := 20, color := Color.WHITE, outline := true, parent: Node = null) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if outline:
		l.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.03))
		l.add_theme_constant_override("outline_size", maxi(4, size / 5))
	if parent != null:
		parent.add_child(l)
	return l


func _ink(text: String, size := 20, parent: Node = null) -> Label:
	var l := _label(text, size, INK, false, parent)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


# ---------- HUD ----------

func _build_hud() -> void:
	_hud = Control.new()
	_hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_hud)

	var tl := VBoxContainer.new()
	tl.position = Vector2(20, 14)
	_hud.add_child(tl)
	_hearts = Hearts.new()
	_hearts.custom_minimum_size = Vector2(180, 40)
	tl.add_child(_hearts)
	_copper = _label("", 24, GOLD, true, tl)
	_day = _label("", 18, Color("#f3e3b5"), true, tl)
	_bottles = _label("", 20, Color("#9fe6b0"), true, tl)

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
	_hint_panel.add_theme_stylebox_override("panel", _box(Color(0.1, 0.06, 0.03, 0.82), GOLD, 3, 10, 14))
	_hint_label = _label("", 21, Color("#fff3cf"), false, _hint_panel)
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hint_panel.visible = false
	_hud.add_child(_hint_panel)

	_crosshair = Control.new()
	_crosshair.set_anchors_preset(Control.PRESET_CENTER)
	_hud.add_child(_crosshair)
	var dot := ColorRect.new()
	dot.color = Color(1, 1, 1, 0.75)
	dot.size = Vector2(5, 5)
	dot.position = Vector2(-2, -2)
	_crosshair.add_child(dot)
	_hud.visible = false


func show_hud(v: bool) -> void:
	_hud.visible = v


func configure_hud(island_mode: bool) -> void:
	_dest.visible = island_mode
	_compass.visible = island_mode
	_timer.visible = island_mode
	_parcel_name.visible = island_mode
	_parcel_bar.visible = island_mode
	_parcel_status.visible = island_mode
	show_compass = island_mode
	_mandate.text = "Grubnik says: " + str(Game.mandate["text"])


func set_dest(text: String) -> void:
	_dest.text = text


func set_timer(sec: float) -> void:
	var s := int(ceil(maxf(sec, 0.0)))
	_timer.text = "%d:%02d" % [s / 60, s % 60]
	_timer.add_theme_color_override("font_color", Color("#ff6a5a") if sec < 30.0 else Color.WHITE)


func _process(delta: float) -> void:
	if _hud == null or not _hud.visible:
		return
	_copper.text = "COPPER  %d" % Game.copper
	_day.text = "Day %d  -  %s the Goblin" % [Game.day, Game.goblin_name]
	var p := hud_player
	if p != null and is_instance_valid(p):
		(_hearts as Hearts).hp = p.hp
		(_hearts as Hearts).max_hp = p.max_hp
		_hearts.queue_redraw()
		var bt := ""
		if Game.has_skill("bottle") and p.island != null:
			bt = "BOTTLES  x%d" % p.bottles
		_bottles.text = bt
		_crosshair.visible = Game.has_skill("bottle") and p.island != null
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


func _on_moment(caption: String) -> void:
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
	if _qte_active and event.is_action_pressed("interact"):
		var d := absf(_qte_t - _qte_total)
		_finish_qte(d <= _qte_window * 0.5 or (_qte_t > _qte_total - _qte_window * 0.5 and _qte_t < _qte_total + _qte_window * 0.3))
		get_viewport().set_input_as_handled()


# ---------- modal windows ----------

func _open_modal(min_width := 640) -> VBoxContainer:
	close_modal(false)
	_modal = Control.new()
	_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.04, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_modal.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(min_width, 0)
	center.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	panel.add_child(vb)
	_root.add_child(_modal)
	_root.move_child(_fade, _root.get_child_count() - 1)
	modal_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	return vb


func close_modal(recapture := true) -> void:
	if _modal != null and is_instance_valid(_modal):
		_modal.queue_free()
	_modal = null
	modal_open = false
	if recapture and capture_wanted:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _button(text: String, parent: Node, cb: Callable, enabled := true) -> Button:
	var b := Button.new()
	b.text = text
	b.disabled = not enabled
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
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
	var vb := _open_modal(1040)
	_ink("THE CELLAR  -  Skill Tree", 34, vb)
	_ink("Skill points: %d   (earn one per delivery, two for a spotless one)" % Game.skill_points, 18, vb)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 12)
	vb.add_child(cols)
	for branch in Game.BRANCHES:
		var col := VBoxContainer.new()
		col.custom_minimum_size = Vector2(230, 0)
		col.add_theme_constant_override("separation", 8)
		cols.add_child(col)
		_ink(branch.to_upper(), 24, col)
		for tier in [1, 2, 3]:
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
				b.custom_minimum_size = Vector2(230, 96)
				b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				b.clip_text = false
	_button("Back upstairs", vb, func():
		close_modal()
		if on_close.is_valid():
			on_close.call())


func show_title(on_start: Callable, on_reset: Callable) -> void:
	var vb := _open_modal(760)
	_ink("GOBLIN DELIVERY CO.", 54, vb)
	_ink("You are a goblin. Your boss doesn't care. The parcels are screaming.\nDeliver them anyway.", 22, vb)
	_ink("WASD move   Mouse look   SPACE jump   E interact   LMB throw bottle   F kick   G toss parcel\nSHIFT dash* and Q parcel-slap* are learned in the cellar   ESC release mouse   C open clips folder", 17, vb)
	_button("Clock in", vb, func():
		close_modal(false)
		on_start.call())
	_button("Wipe save (new goblin dynasty)", vb, func():
		on_reset.call()
		toast("Save wiped. Grubnik has forgotten you.", Color("#ffd89a")))


func show_result(data: Dictionary, on_close: Callable) -> void:
	var vb := _open_modal(720)
	_ink(str(data["title"]), 38, vb)
	_ink(str(data["lines"]), 22, vb)
	if (data["moments"] as Array).size() > 0:
		_ink("CLIPS FROM THIS SHIFT", 20, vb)
		var ml := _ink("- " + "\n- ".join(data["moments"]), 20, vb)
		ml.add_theme_color_override("font_color", Color("#8a2a10"))
	var q := _ink(str(data["quote"]), 20, vb)
	q.add_theme_color_override("font_color", Color("#4a3320"))
	_button("Back to the tavern", vb, func():
		close_modal(false)
		on_close.call())
