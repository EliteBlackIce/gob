class_name DungeonGen
extends RefCounted
## Procedural dungeon layout. Pure data (no nodes) so it is trivially testable:
## a grid of room slots is grown into a connected tree plus a few loops, every room gets a
## random shape and size, corridors link them, and rooms get roles (start / combat / treasure /
## shrine / rest / merchant / trap / boss / customer).

const SLOTS := 5
const SLOT := 26                  # tiles per slot side
const CORRIDOR_W := 3
const T_VOID := 0
const T_FLOOR := 1
const T_LAVA := 2
const T_POISON := 3

const SHAPES := ["rect", "rect", "rect", "cross", "round", "pillars", "l"]


class DRoom extends RefCounted:
	var id := 0
	var kind := "combat"
	var slot := Vector2i.ZERO
	var x := 0
	var y := 0
	var w := 0
	var h := 0
	var shape := "rect"
	var depth := 0
	var links: Array[int] = []
	var doors: Array = []            # {tile: Vector2i, dir: Vector2i, to: int}
	var tiles: Dictionary = {}       # Vector2i -> true (floor tiles inside this room)
	var pillars: Array[Vector2i] = []

	func center() -> Vector2i:
		return Vector2i(x + w / 2, y + h / 2)

	func rect() -> Rect2i:
		return Rect2i(x, y, w, h)

	func area() -> int:
		return tiles.size()


var seed_value := 0
var theme := "crypt"
var tier := 1
var width := SLOTS * SLOT
var height := SLOTS * SLOT
var tiles := PackedByteArray()
var rooms: Array[DRoom] = []
var start_id := 0
var boss_id := -1
var customer_id := -1
var edges: Array = []              # [a, b]
var corridor_tiles: Dictionary = {}


static func generate(seed_v: int, theme_id: String, tier_n: int, opts := {}) -> DungeonGen:
	var g := DungeonGen.new()
	g.seed_value = seed_v
	g.theme = theme_id
	g.tier = tier_n
	g._build(opts)
	return g


func idx(x: int, y: int) -> int:
	return y * width + x


func tile(x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= width or y >= height:
		return T_VOID
	return tiles[idx(x, y)]


func is_floor(x: int, y: int) -> bool:
	return tile(x, y) != T_VOID


func _build(opts: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	tiles.resize(width * height)
	tiles.fill(T_VOID)
	var want := int(opts.get("rooms", rng.randi_range(9, 12)))
	var no_customer: bool = opts.get("no_customer", false)
	# --- grow a tree on the slot grid
	var occupied := {}
	var start_slot := Vector2i(rng.randi_range(0, SLOTS - 1), rng.randi_range(0, SLOTS - 1))
	var slot_list: Array[Vector2i] = [start_slot]
	occupied[start_slot] = 0
	edges = []
	var guard := 0
	while slot_list.size() < want and guard < 500:
		guard += 1
		var from: Vector2i = slot_list[rng.randi_range(0, slot_list.size() - 1)]
		var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
		var d: Vector2i = dirs[rng.randi_range(0, 3)]
		var to := from + d
		if to.x < 0 or to.y < 0 or to.x >= SLOTS or to.y >= SLOTS or occupied.has(to):
			continue
		occupied[to] = slot_list.size()
		slot_list.append(to)
		edges.append([occupied[from], occupied[to]])
	# --- a couple of loops between adjacent rooms not yet linked
	var loops := rng.randi_range(1, 3)
	for i in loops:
		var a := rng.randi_range(0, slot_list.size() - 1)
		for dd in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]:
			var nb: Vector2i = slot_list[a] + dd
			if occupied.has(nb):
				var b: int = occupied[nb]
				if not _has_edge(a, b):
					edges.append([a, b])
					break
	# --- rooms
	for i in slot_list.size():
		var r := DRoom.new()
		r.id = i
		r.slot = slot_list[i]
		_shape_room(r, rng, 10, 18)
		rooms.append(r)
	for e in edges:
		rooms[e[0]].links.append(e[1])
		rooms[e[1]].links.append(e[0])
	start_id = rng.randi_range(0, rooms.size() - 1)
	# prefer a start with few links (a dead end)
	var best_links := 99
	for r in rooms:
		if r.links.size() < best_links:
			best_links = r.links.size()
	var starts: Array[int] = []
	for r in rooms:
		if r.links.size() == best_links:
			starts.append(r.id)
	start_id = starts[rng.randi_range(0, starts.size() - 1)]
	_compute_depth()
	# --- boss: deepest room that has a free neighbouring slot for the customer room
	var order: Array = []
	for r in rooms:
		order.append(r)
	order.sort_custom(func(a: DRoom, b: DRoom) -> bool: return a.depth > b.depth)
	for cand in order:
		var c: DRoom = cand
		if c.id == start_id:
			continue
		var free_dirs: Array[Vector2i] = []
		for dd2 in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var ns: Vector2i = c.slot + dd2
			if ns.x >= 0 and ns.y >= 0 and ns.x < SLOTS and ns.y < SLOTS and not occupied.has(ns):
				free_dirs.append(dd2)
		if free_dirs.is_empty():
			continue
		boss_id = c.id
		# a bigger arena for the boss
		_shape_room(c, rng, 17, 22, "rect")
		var cr := DRoom.new()
		cr.id = rooms.size()
		cr.slot = c.slot + free_dirs[rng.randi_range(0, free_dirs.size() - 1)]
		_shape_room(cr, rng, 11, 14, "rect")
		rooms.append(cr)
		edges.append([c.id, cr.id])
		c.links.append(cr.id)
		cr.links.append(c.id)
		customer_id = cr.id
		break
	if boss_id < 0:
		boss_id = order[0].id
	_compute_depth()
	# --- roles
	for r in rooms:
		r.kind = "combat"
	rooms[start_id].kind = "start"
	rooms[boss_id].kind = "boss"
	if customer_id >= 0:
		rooms[customer_id].kind = "stairs" if no_customer else "customer"
	var free: Array[DRoom] = []
	for r in rooms:
		if r.kind == "combat":
			free.append(r)
	for i in range(free.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: DRoom = free[i]
		free[i] = free[j]
		free[j] = tmp
	var plan: Array[String] = ["treasure", "rest", "shrine"]
	if tier >= 2 or rooms.size() >= 11:
		plan.append("trap")
	if rooms.size() >= 10:
		plan.append("merchant")
	plan.append("treasure")
	var n_special := mini(plan.size(), maxi(int(free.size() * 0.5), 2))
	for i in mini(n_special, free.size() - 1):
		free[i].kind = plan[i]
	# --- floors + corridors
	for r in rooms:
		_carve_room(r)
	for e in edges:
		_carve_corridor(rooms[e[0]], rooms[e[1]], rng)
	_hazards(rng)


func _has_edge(a: int, b: int) -> bool:
	for e in edges:
		if (e[0] == a and e[1] == b) or (e[0] == b and e[1] == a):
			return true
	return false


func _shape_room(r: DRoom, rng: RandomNumberGenerator, lo: int, hi: int, force_shape := "") -> void:
	r.w = rng.randi_range(lo, hi)
	r.h = rng.randi_range(lo, hi)
	r.shape = force_shape if force_shape != "" else SHAPES[rng.randi_range(0, SHAPES.size() - 1)]
	var margin := 3
	r.x = r.slot.x * SLOT + margin + rng.randi_range(0, SLOT - 2 * margin - r.w)
	r.y = r.slot.y * SLOT + margin + rng.randi_range(0, SLOT - 2 * margin - r.h)


func _compute_depth() -> void:
	for r in rooms:
		r.depth = -1
	var q: Array[int] = [start_id]
	rooms[start_id].depth = 0
	while not q.is_empty():
		var cur: int = q.pop_front()
		for nb in rooms[cur].links:
			if rooms[nb].depth < 0:
				rooms[nb].depth = rooms[cur].depth + 1
				q.append(nb)


func _put(x: int, y: int, v: int) -> void:
	if x < 1 or y < 1 or x >= width - 1 or y >= height - 1:
		return
	tiles[idx(x, y)] = v


func _carve_room(r: DRoom) -> void:
	r.tiles.clear()
	var cx := r.w * 0.5
	var cy := r.h * 0.5
	for ly in r.h:
		for lx in r.w:
			var inside := true
			var fx := (float(lx) + 0.5 - cx) / cx
			var fy := (float(ly) + 0.5 - cy) / cy
			match r.shape:
				"cross":
					inside = absf(fx) < 0.42 or absf(fy) < 0.42
				"round":
					inside = fx * fx + fy * fy <= 1.0
				"l":
					inside = not (fx > 0.05 and fy > 0.05)
			if r.id == start_id and r.shape == "l":
				inside = true
			if inside:
				r.tiles[Vector2i(r.x + lx, r.y + ly)] = true
				_put(r.x + lx, r.y + ly, T_FLOOR)
	if r.shape == "pillars":
		for ly2 in range(3, r.h - 3, 4):
			for lx2 in range(3, r.w - 3, 4):
				r.pillars.append(Vector2i(r.x + lx2, r.y + ly2))
	elif r.kind == "boss" or r.kind == "combat":
		pass
	# the room centre must always be floor (cross/round/l shapes are all centred, but be safe)
	var c := r.center()
	r.tiles[c] = true
	_put(c.x, c.y, T_FLOOR)


func _carve_corridor(a: DRoom, b: DRoom, rng: RandomNumberGenerator) -> void:
	var ca := a.center()
	var cb := b.center()
	var pts: Array[Vector2i] = []
	var d := b.slot - a.slot
	if d.x != 0:
		var bx := (maxi(a.slot.x, b.slot.x)) * SLOT        # the shared slot border
		pts = [ca, Vector2i(bx, ca.y), Vector2i(bx, cb.y), cb]
	elif d.y != 0:
		var by := (maxi(a.slot.y, b.slot.y)) * SLOT
		pts = [ca, Vector2i(ca.x, by), Vector2i(cb.x, by), cb]
	else:
		pts = [ca, cb]
	var line: Array[Vector2i] = []
	for i in range(1, pts.size()):
		var p0 := pts[i - 1]
		var p1 := pts[i]
		var step := Vector2i(signi(p1.x - p0.x), signi(p1.y - p0.y))
		var cur := p0
		if step == Vector2i.ZERO:
			continue
		while cur != p1:
			line.append(cur)
			cur += step
		line.append(p1)
	# find door positions: first line tile outside room A / last tile before entering B
	var door_a := -1
	var door_b := -1
	var ra := a.rect()
	var rb := b.rect()
	for i in line.size():
		if door_a < 0 and not ra.has_point(line[i]):
			door_a = i
			break
	for j in range(line.size() - 1, -1, -1):
		if not rb.has_point(line[j]):
			door_b = j
			break
	for i in line.size():
		var p := line[i]
		var dirv := Vector2i.ZERO
		if i + 1 < line.size():
			dirv = line[i + 1] - p
		elif i > 0:
			dirv = p - line[i - 1]
		var perp := Vector2i(dirv.y, dirv.x) if dirv.x != 0 or dirv.y != 0 else Vector2i(1, 0)
		perp = Vector2i(absi(perp.x), absi(perp.y))
		for o in range(-(CORRIDOR_W / 2), CORRIDOR_W / 2 + 1):
			var t := p + perp * o
			if tile(t.x, t.y) == T_VOID:
				corridor_tiles[t] = true
			_put(t.x, t.y, maxi(tile(t.x, t.y), T_FLOOR))
	if door_a >= 0:
		var pa := line[door_a]
		var da := line[mini(door_a + 1, line.size() - 1)] - pa
		if da == Vector2i.ZERO:
			da = pa - line[maxi(door_a - 1, 0)]
		a.doors.append({"tile": pa, "dir": da, "to": b.id})
	if door_b >= 0:
		var pb := line[door_b]
		var db := line[maxi(door_b - 1, 0)] - pb
		if db == Vector2i.ZERO:
			db = pb - line[mini(door_b + 1, line.size() - 1)]
		b.doors.append({"tile": pb, "dir": db, "to": a.id})


func _hazards(rng: RandomNumberGenerator) -> void:
	if theme != "furnace" and theme != "sewer":
		return
	var kind := T_LAVA if theme == "furnace" else T_POISON
	for r in rooms:
		if r.kind != "combat" and r.kind != "trap" and r.kind != "boss":
			continue
		if rng.randf() < 0.55 or r.kind == "boss":
			var pools := 1 + (1 if r.area() > 220 else 0)
			for p in pools:
				var pw := rng.randi_range(3, 5)
				var ph := rng.randi_range(3, 4)
				var px := r.x + rng.randi_range(3, maxi(r.w - pw - 3, 3))
				var py := r.y + rng.randi_range(3, maxi(r.h - ph - 3, 3))
				var ok := true
				for yy in ph:
					for xx in pw:
						if not r.tiles.has(Vector2i(px + xx, py + yy)) or Vector2i(px + xx, py + yy).distance_to(Vector2(r.center())) < 3.0:
							ok = false
				if ok:
					for yy2 in ph:
						for xx2 in pw:
							_put(px + xx2, py + yy2, kind)


## Which room (if any) contains this tile?
func room_at(x: int, y: int) -> DRoom:
	var v := Vector2i(x, y)
	for r in rooms:
		if r.tiles.has(v):
			return r
	return null


## Every room must be reachable from the start by walking floor tiles. Used by tests.
func reachable_rooms() -> int:
	var seen := {}
	var q: Array[Vector2i] = [rooms[start_id].center()]
	seen[q[0]] = true
	while not q.is_empty():
		var c: Vector2i = q.pop_back()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if not seen.has(n) and is_floor(n.x, n.y):
				seen[n] = true
				q.append(n)
	var count := 0
	for r in rooms:
		if seen.has(r.center()):
			count += 1
	return count


func signature() -> int:
	return hash(tiles) ^ (rooms.size() * 977) ^ (boss_id * 31)


func floor_count() -> int:
	var n := 0
	for b in tiles:
		if b != T_VOID:
			n += 1
	return n
