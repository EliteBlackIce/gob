class_name Menus
extends RefCounted
## The RPG screens: inventory/equipment (also the blacksmith's sell+enhance mode and the stash),
## the shop, the contract board, the Realtor and the end-of-run summary. All built from the UI's
## stone-themed modal helpers.

static var _sel_uid := -1
static var _sel_where := ""


# ---------------------------------------------------------------- helpers

static func _rarity_box(c: Color, bg := Color("#1a1410"), bw := 3) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = c
	sb.set_border_width_all(bw)
	sb.content_margin_left = 4
	sb.content_margin_right = 4
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	return sb


static func _icon_button(it: Variant, size: float, selected := false) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(size, size)
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	var col := Color("#4a4038")
	if it != null:
		col = ItemDB.rarity_color(int((it as Dictionary)["rarity"]))
		b.icon = ItemModels.icon(it)
	var bg := Color("#241a14") if not selected else Color("#3c3020")
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := _rarity_box(col if st != "hover" else col.lightened(0.35), bg, 3 if not selected else 4)
		if st == "focus":
			sb = _rarity_box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0)
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_constant_override("icon_max_width", int(size - 10))
	return b


static func stats_summary(extra := {}) -> String:
	var s := Stats.compute()
	return "HP %d    DPS %d    Damage %d    Crit %d%% (x%.1f)    Armor %d (%d%% less dmg)    Move +%d%%    Luck +%d%%" % [
		round(s["max_hp"]), round(s["dps"]), round(s["dmg"]), round(minf(s["crit"], 100.0)), s["crit_dmg"] / 100.0,
		round(s["armor"]), round(s["armor_red"] * 100.0), round(s["move"]), round(s["luck"])]


static func _find(uid: int, where: String) -> Variant:
	match where:
		"pack":
			for it in Game.inventory:
				if it["uid"] == uid:
					return it
		"stash":
			for it in Game.stash:
				if it["uid"] == uid:
					return it
		"equip":
			for slot in Game.equipped:
				if Game.equipped[slot]["uid"] == uid:
					return Game.equipped[slot]
		"shop":
			for it in Game.shop_stock:
				if it["uid"] == uid:
					return it
	return null


## Writes a tooltip for an item into a VBox (cleared first).
static func fill_detail(ui: UI, box: VBoxContainer, it: Variant, compare := true) -> void:
	for c in box.get_children():
		c.queue_free()
	if it == null:
		var hint := ui._ink("Hover or click an item.\n\nFind loot in dungeons: rarer items have more affixes, and Legendaries have unique effects.", 17, box)
		hint.add_theme_color_override("font_color", Color("#a89a82"))
		return
	var item: Dictionary = it
	var rc := ItemDB.rarity_color(int(item["rarity"]))
	var t := ui._label(ItemDB.title(item), 24, rc, true, box)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size = Vector2(300, 0)
	ui._ink("%s %s   -   item level %d" % [ItemDB.rarity_name(int(item["rarity"])), ItemDB.SLOT_NAMES[item["slot"]], item["ilvl"]], 16, box).add_theme_color_override("font_color", Color("#c8b890"))
	for line in ItemDB.describe(item):
		var l := ui._ink(str(line), 18, box)
		if str(line).begins_with("UNIQUE"):
			l.add_theme_color_override("font_color", Color("#ffa42a"))
	var fl := ui._ink("\"%s\"" % item.get("flavor", ""), 15, box)
	fl.add_theme_color_override("font_color", Color("#8a7e6a"))
	if compare and _find(item["uid"], "equip") == null:
		var cur := Stats.compute()
		var nw := Stats.preview_stats(item)
		var parts: Array[String] = []
		var d_dps: float = nw["dps"] - cur["dps"]
		var d_hp: float = nw["max_hp"] - cur["max_hp"]
		var d_arm: float = nw["armor"] - cur["armor"]
		if absf(d_dps) >= 1.0:
			parts.append("DPS %+d" % int(round(d_dps)))
		if absf(d_hp) >= 1.0:
			parts.append("HP %+d" % int(round(d_hp)))
		if absf(d_arm) >= 1.0:
			parts.append("Armor %+d" % int(round(d_arm)))
		var d_move: float = nw["move"] - cur["move"]
		if absf(d_move) >= 1.0:
			parts.append("Move %+d%%" % int(round(d_move)))
		if not parts.is_empty():
			var better := d_dps + d_hp * 0.4 + d_arm * 2.0 >= 0.0
			var cl := ui._ink("If equipped:  " + "   ".join(parts), 17, box)
			cl.add_theme_color_override("font_color", Color("#7aff7a") if better else Color("#ff8a7a"))
		var worth := ui._ink("Worth %d copper" % item["value"], 15, box)
		worth.add_theme_color_override("font_color", Color("#e6b840"))


# ---------------------------------------------------------------- inventory

## mode: "pack" (anywhere), "smith" (sell + enhance), "stash" (move between pack and stash)
static func show_inventory(ui: UI, mode := "pack", on_close := Callable()) -> void:
	var vb := ui._open_modal(1180)
	ui.modal_tag = "inv"
	var title := "BACKPACK"
	match mode:
		"smith":
			title = "GRUK'S ANVIL  -  sell & enhance"
		"stash":
			title = "THE STASH  -  safe at home"
	ui._ink(title, 32, vb)
	var top := ui._ink(stats_summary(), 16, vb)
	top.add_theme_color_override("font_color", Color("#c8b890"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	vb.add_child(row)

	# ---- equipment column
	var eq := VBoxContainer.new()
	eq.custom_minimum_size = Vector2(250, 0)
	eq.add_theme_constant_override("separation", 6)
	row.add_child(eq)
	ui._ink("EQUIPPED", 18, eq).add_theme_color_override("font_color", Color("#e6b840"))

	var detail := VBoxContainer.new()
	detail.custom_minimum_size = Vector2(340, 0)
	detail.add_theme_constant_override("separation", 6)

	for slot in ItemDB.SLOTS:
		var it: Variant = Game.equipped.get(slot)
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 8)
		eq.add_child(hb)
		var ib := _icon_button(it, 54, it != null and _sel_uid == (it as Dictionary)["uid"])
		hb.add_child(ib)
		var lab := ui._ink("%s\n%s" % [ItemDB.SLOT_NAMES[slot], ItemDB.title(it) if it != null else "(empty)"], 15, hb)
		lab.custom_minimum_size = Vector2(170, 0)
		if it != null:
			lab.add_theme_color_override("font_color", ItemDB.rarity_color(int((it as Dictionary)["rarity"])))
		else:
			lab.add_theme_color_override("font_color", Color("#7a6e5a"))
		var cap_it: Variant = it
		ib.mouse_entered.connect(func(): fill_detail(ui, detail, cap_it))
		ib.pressed.connect(func():
			if cap_it != null:
				_sel_uid = (cap_it as Dictionary)["uid"]
				_sel_where = "equip"
				Sfx.play("click")
				show_inventory(ui, mode, on_close))

	# ---- backpack grid
	var mid := VBoxContainer.new()
	mid.add_theme_constant_override("separation", 6)
	row.add_child(mid)
	ui._ink("BACKPACK  %d / %d" % [Game.inventory.size(), Game.INV_CAP], 18, mid).add_theme_color_override("font_color", Color("#e6b840"))
	var grid := GridContainer.new()
	grid.columns = 7
	grid.add_theme_constant_override("h_separation", 5)
	grid.add_theme_constant_override("v_separation", 5)
	mid.add_child(grid)
	for i in Game.INV_CAP:
		var item: Variant = Game.inventory[i] if i < Game.inventory.size() else null
		var b := _icon_button(item, 58, item != null and _sel_uid == (item as Dictionary)["uid"])
		grid.add_child(b)
		if item != null:
			var cap_item: Dictionary = item
			b.mouse_entered.connect(func(): fill_detail(ui, detail, cap_item))
			b.pressed.connect(func():
				_sel_uid = cap_item["uid"]
				_sel_where = "pack"
				Sfx.play("click")
				show_inventory(ui, mode, on_close))
			b.gui_input.connect(func(ev: InputEvent):
				if ev is InputEventMouseButton and ev.pressed and ev.double_click and ev.button_index == MOUSE_BUTTON_LEFT:
					Game.equip(cap_item)
					Sfx.play("blip")
					show_inventory(ui, mode, on_close))
	if mode == "stash":
		ui._ink("STASH  %d / %d" % [Game.stash.size(), Game.stash_cap()], 18, mid).add_theme_color_override("font_color", Color("#e6b840"))
		var sg := GridContainer.new()
		sg.columns = 7
		sg.add_theme_constant_override("h_separation", 5)
		sg.add_theme_constant_override("v_separation", 5)
		mid.add_child(sg)
		for i2 in Game.stash_cap():
			var sitem: Variant = Game.stash[i2] if i2 < Game.stash.size() else null
			var sb := _icon_button(sitem, 50, sitem != null and _sel_uid == (sitem as Dictionary)["uid"])
			sg.add_child(sb)
			if sitem != null:
				var cap_s: Dictionary = sitem
				sb.mouse_entered.connect(func(): fill_detail(ui, detail, cap_s))
				sb.pressed.connect(func():
					_sel_uid = cap_s["uid"]
					_sel_where = "stash"
					Sfx.play("click")
					show_inventory(ui, mode, on_close))

	# ---- detail + actions
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	row.add_child(right)
	right.add_child(detail)
	var sel: Variant = _find(_sel_uid, _sel_where)
	fill_detail(ui, detail, sel)
	if sel != null:
		var item_s: Dictionary = sel
		if _sel_where == "pack" or _sel_where == "stash":
			if _sel_where == "pack":
				ui._button("Equip", right, func():
					Game.equip(item_s)
					Sfx.play("blip")
					show_inventory(ui, mode, on_close))
		if _sel_where == "equip":
			ui._button("Unequip", right, func():
				if Game.unequip(item_s["slot"]):
					Sfx.play("click")
				show_inventory(ui, mode, on_close))
		if mode == "smith" and _sel_where != "stash":
			var price := Game.sell_price(item_s)
			ui._button("Sell for %d copper" % price, right, func():
				if _sel_where == "equip":
					Game.unequip(item_s["slot"])
					Game.touch_gear()
				Game.sell(item_s)
				_sel_uid = -1
				Sfx.play("coin")
				show_inventory(ui, mode, on_close), _sel_where != "equip" or Game.inventory.size() < Game.INV_CAP)
			var plus: int = item_s.get("plus", 0)
			if plus < 5:
				var cost := ItemDB.enhance_cost(item_s)
				ui._button("Enhance +%d  (%d copper)" % [plus + 1, cost], right, func():
					if Game.copper >= cost:
						Game.copper -= cost
						ItemDB.enhance(item_s)
						Game.touch_gear()
						Sfx.play("stamp")
						ui.toast("CLANG! +%d" % item_s["plus"], Color("#ffd89a"))
					show_inventory(ui, mode, on_close), Game.copper >= cost)
			else:
				ui._ink("Fully enhanced.", 16, right).add_theme_color_override("font_color", Color("#9dffa0"))
		if mode == "stash":
			if _sel_where == "pack":
				ui._button("Move to stash", right, func():
					if Game.to_stash(item_s):
						Sfx.play("click")
					else:
						ui.toast("Stash full. Upgrade your house!", Color("#ff9a7a"))
					_sel_uid = -1
					show_inventory(ui, mode, on_close))
			elif _sel_where == "stash":
				ui._button("Take out", right, func():
					if Game.from_stash(item_s):
						Sfx.play("click")
					_sel_uid = -1
					show_inventory(ui, mode, on_close))
		if _sel_where == "pack":
			ui._button("Throw in the bin", right, func():
				Game.inventory.erase(item_s)
				_sel_uid = -1
				Sfx.play("thud")
				show_inventory(ui, mode, on_close))
	ui._button("Close", vb, func():
		ui.close_modal()
		if on_close.is_valid():
			on_close.call())


# ---------------------------------------------------------------- shop

static func show_shop(ui: UI, on_close := Callable()) -> void:
	var vb := ui._open_modal(900)
	ui._ink("GRUK'S WARES", 32, vb)
	ui._ink("Gruk: \"Fresh from the dungeon. Don't ask whose.\"       You have %d copper." % Game.copper, 17, vb)
	var detail := VBoxContainer.new()
	detail.custom_minimum_size = Vector2(320, 0)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	vb.add_child(row)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	row.add_child(col)
	for it in Game.shop_stock:
		var item: Dictionary = it
		var price := shop_price(item)
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 8)
		col.add_child(hb)
		var ib := _icon_button(item, 54)
		hb.add_child(ib)
		ib.mouse_entered.connect(func(): fill_detail(ui, detail, item))
		var b := ui._button("%s\n%d copper" % [ItemDB.title(item), price], hb, func():
			if Game.copper >= price and Game.inventory.size() < Game.INV_CAP:
				Game.copper -= price
				Game.shop_stock.erase(item)
				Game.inventory.append(item)
				Sfx.play("coin")
				show_shop(ui, on_close)
			elif Game.inventory.size() >= Game.INV_CAP:
				ui.toast("Your pack is full.", Color("#ff9a7a")), Game.copper >= price)
		b.custom_minimum_size = Vector2(300, 54)
		b.add_theme_color_override("font_color", ItemDB.rarity_color(int(item["rarity"])))
		b.add_theme_color_override("font_hover_color", ItemDB.rarity_color(int(item["rarity"])).lightened(0.3))
		b.mouse_entered.connect(func(): fill_detail(ui, detail, item))
	row.add_child(detail)
	fill_detail(ui, detail, null)
	var tools := HBoxContainer.new()
	vb.add_child(tools)
	ui._button("Sell & enhance...", tools, func(): show_inventory(ui, "smith", func(): show_shop(ui, on_close)))
	ui._button("Leave", tools, func():
		ui.close_modal()
		if on_close.is_valid():
			on_close.call())


static func shop_price(it: Dictionary) -> int:
	return int(round(float(it["value"]) * 2.4))


# ---------------------------------------------------------------- contracts

static func show_contracts(ui: UI, on_pick: Callable, on_close := Callable()) -> void:
	var vb := ui._open_modal(1040)
	ui._ink("CONTRACT BOARD", 34, vb)
	ui._ink("Day %d.  Grubnik: \"%s\"" % [Game.day, Game.mandate["text"]], 17, vb)
	ui._ink("You are level %d.  The dungeons get harder (and pay better) as you unlock tiers by beating their bosses." % Game.level, 16, vb).add_theme_color_override("font_color", Color("#c8b890"))
	for j in Game.today_jobs:
		var job: Dictionary = j
		var sel: bool = Game.current_job.get("seed", -1) == job.get("seed", -2) and Game.current_job.get("id", "") == job["id"] and Game.current_job.get("kind", "") == job["kind"]
		var label := ""
		var desc := ""
		if job["kind"] == "route":
			label = "ISLAND ROUTE:  %s  ->  %s" % [job["title"], job["dest_name"]]
			desc = "Safe-ish overland delivery. Carry it in your arms, dodge crows. Pay %d copper, %d:%02d on the clock. (No combat: just run.)" % [job["pay"], int(job["time"]) / 60, int(job["time"]) % 60]
		else:
			var th: Dictionary = Game.THEMES[job["theme"]]
			var mods: Array[String] = []
			for m in job["mods"]:
				mods.append("%s (%s)" % [Game.MODIFIERS[m]["name"], Game.MODIFIERS[m]["text"]])
			label = "DUNGEON:  %s  -  Tier %d    [%s]" % [th["name"], job["tier"], job["title"]]
			desc = "%s\nDeliver to %s. Boss: %s. Pay %d+ copper.%s" % [th["desc"], job["customer"], Boss.BOSSES[th["boss"]]["name"], job["pay"],
				("\nModifiers: " + ", ".join(mods)) if mods.size() > 0 else ""]
		var b := ui._button(("[x] " if sel else "") + label + "\n" + desc, vb, func():
			on_pick.call(job)
			ui.close_modal()
			Sfx.play("coin"))
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.custom_minimum_size = Vector2(960, 0)
		if job["kind"] == "dungeon":
			b.add_theme_color_override("font_color", (Game.THEMES[job["theme"]]["color"] as Color).lightened(0.4))
	ui._button("Leave them (cowardly)", vb, func():
		ui.close_modal()
		if on_close.is_valid():
			on_close.call())


# ---------------------------------------------------------------- realtor

static func show_realtor(ui: UI, on_close := Callable()) -> void:
	var vb := ui._open_modal(900)
	var cur: Dictionary = Game.HOUSES[Game.house_tier]
	ui._ink("MS. DEED  -  Goblin Realty", 32, vb)
	ui._ink("Ms. Deed: \"Everyone deserves a home. Not you specifically. But everyone.\"", 17, vb)
	ui._ink("Your home:  %s    (%s)" % [cur["name"], cur["text"]], 22, vb).add_theme_color_override("font_color", Color("#e6b840"))
	ui._ink(house_perks_text(cur), 16, vb)
	var nx := Game.house_next()
	if nx.is_empty():
		ui._ink("You live in THE CASTLE. There is nothing left to buy. Ms. Deed is crying a little.", 20, vb).add_theme_color_override("font_color", Color("#9dffa0"))
	else:
		ui._ink("\nNEXT:  %s  -  %d copper" % [nx["name"], nx["cost"]], 24, vb)
		ui._ink("\"%s\"\n%s" % [nx["text"], house_perks_text(nx)], 16, vb)
		ui._button("Buy the %s  (%d copper)" % [nx["name"], nx["cost"]], vb, func():
			if Game.buy_house():
				Sfx.play("deliver")
				ui.toast("You bought the %s!" % nx["name"], Color("#9dffa0"))
				Game.moment("Bought the %s" % nx["name"])
				ui.close_modal()
				if Game.won:
					show_victory(ui, on_close)
				else:
					show_realtor(ui, on_close), Game.copper >= int(nx["cost"]))
	ui._button("Leave", vb, func():
		ui.close_modal()
		if on_close.is_valid():
			on_close.call())


static func house_perks_text(h: Dictionary) -> String:
	var bits: Array[String] = ["Stash %d slots" % h["stash"]]
	if h["hp"] > 0:
		bits.append("+%d max HP" % h["hp"])
	if h["grog"] > 0:
		bits.append("+%d grog flask carry" % h["grog"])
	if h["xp"] > 0:
		bits.append("+%d%% XP" % h["xp"])
	return "Perks:  " + "   -   ".join(bits)


static func show_victory(ui: UI, on_close := Callable()) -> void:
	var vb := ui._open_modal(820)
	ui._ink("YOU RETIRED.", 54, vb)
	ui._ink("You bought THE CASTLE.\n\nGrubnik is furious. The crows are throwing a parade. Skeleton Dave sent a fruit basket. The Overdue Dragon says congratulations (he means it).\n\nDeliveries: %d    Deaths: %d    Kills: %d    Level: %d\n\nThe dungeons are still open if you want more loot. They always are." % [
		Game.deliveries, Game.deaths, Game.kills, Game.level], 20, vb)
	Game.moment("BOUGHT THE CASTLE. YOU WIN.")
	ui._button("Keep delivering anyway", vb, func():
		ui.close_modal()
		if on_close.is_valid():
			on_close.call())


# ---------------------------------------------------------------- shrine / blessing picker

static func show_choice(ui: UI, heading: String, sub: String, options: Array, cb: Callable) -> void:
	var vb := ui._open_modal(720)
	ui._ink(heading, 32, vb)
	ui._ink(sub, 18, vb)
	for o in options:
		var opt: Dictionary = o
		ui._button("%s\n%s" % [opt["name"], opt["desc"]], vb, func():
			ui.close_modal()
			cb.call(opt))
