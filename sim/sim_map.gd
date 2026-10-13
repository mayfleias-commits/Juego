class_name SimMap
extends SimBase
## Mapa en cuadrícula: generador central, pilas recolectables, yacimientos
## (sitios donde van los edificios de extracción) y colocación de edificios.

const G_FREE := 0
const G_GEN := -1
const G_NODE := -2
const G_SITE := -3

var msize: int = 48
var mcenter2: int = 48 # centro del generador en coordenadas dobles
var mradius: int = 22

func map_init_consts() -> void:
	msize = B["map"]["size"]
	mcenter2 = msize # (2*24) para size 48
	mradius = B["map"]["radius"]

func gidx(x: int, y: int) -> int:
	return y * msize + x

## Distancia al cuadrado (coords dobles) entre el centro de una huella y el generador.
func dist2_center(x: int, y: int, w: int, h: int) -> int:
	var cx := 2 * x + w - mcenter2
	var cy := 2 * y + h - mcenter2
	return cx * cx + cy * cy

## Distancia aproximada en casillas (entera) al generador.
func dist_tiles(x: int, y: int, w: int, h: int) -> int:
	return isqrt(dist2_center(x, y, w, h)) / 2

static func isqrt(n: int) -> int:
	if n <= 0:
		return 0
	var x := n
	var y := (x + 1) / 2
	while y < x:
		x = y
		y = (x + n / x) / 2
	return x

func tile_in_bounds(x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= msize or y >= msize:
		return false
	var cx := 2 * x + 1 - mcenter2
	var cy := 2 * y + 1 - mcenter2
	return cx * cx + cy * cy <= (2 * mradius) * (2 * mradius)

func rect_in_bounds(x: int, y: int, w: int, h: int) -> bool:
	return tile_in_bounds(x, y) and tile_in_bounds(x + w - 1, y) and tile_in_bounds(x, y + h - 1) and tile_in_bounds(x + w - 1, y + h - 1)

func rect_free(x: int, y: int, w: int, h: int) -> bool:
	if not rect_in_bounds(x, y, w, h):
		return false
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			if grid[gidx(xx, yy)] != G_FREE:
				return false
	return true

func fill_rect(x: int, y: int, w: int, h: int, v: int) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			grid[gidx(xx, yy)] = v

# ---------------------------------------------------------------- generación
func generate_map() -> void:
	map_init_consts()
	grid = PackedInt32Array()
	grid.resize(msize * msize)
	var c := msize / 2 - 2
	fill_rect(c, c, 4, 4, G_GEN)
	st["nodes"] = []
	st["sites"] = []
	var mg: Dictionary = B["map"]
	# Yacimientos primero (huella 3x3, más lejos), luego pilas (2x2).
	for spec in mg["sites"]:
		var kind: String = spec["kind"]
		for i in int(spec["n"]):
			var pos := _random_spot(3, 3, int(spec["r"][0]), int(spec["r"][1]), 1)
			if pos.x < 0:
				continue
			var amt := _rand_between(int(spec["amt"][0]), int(spec["amt"][1])) * FX.ONE
			var s := {"id": st["sites"].size(), "kind": kind, "x": pos.x, "y": pos.y, "w": 3, "h": 3, "amt": amt, "max": amt, "bid": 0}
			st["sites"].append(s)
			fill_rect(pos.x, pos.y, 3, 3, G_SITE)
	for spec in mg["piles"]:
		var kind: String = spec["kind"]
		for i in int(spec["n"]):
			var pos := _random_spot(2, 2, int(spec["r"][0]), int(spec["r"][1]), 1)
			if pos.x < 0:
				continue
			var amt := _rand_between(int(spec["amt"][0]), int(spec["amt"][1])) * FX.ONE
			var n := {"id": st["nodes"].size(), "kind": kind, "look": spec.get("look", kind), "x": pos.x, "y": pos.y, "w": 2, "h": 2, "amt": amt, "max": amt}
			st["nodes"].append(n)
			fill_rect(pos.x, pos.y, 2, 2, G_NODE)

func _rand_between(a: int, b: int) -> int:
	if b <= a:
		return a
	return a + rnd(b - a + 1)

func _random_spot(w: int, h: int, rmin: int, rmax: int, margin: int) -> Vector2i:
	for attempt in 600:
		var x := rnd(msize - w)
		var y := rnd(msize - h)
		var d2 := dist2_center(x, y, w, h)
		if d2 < (2 * rmin) * (2 * rmin) or d2 > (2 * rmax) * (2 * rmax):
			continue
		if rect_free(x - margin, y - margin, w + 2 * margin, h + 2 * margin):
			return Vector2i(x, y)
	return Vector2i(-1, -1)

## Reconstruye la cuadrícula a partir de nodos, sitios y edificios (tras cargar).
func rebuild_grid() -> void:
	map_init_consts()
	grid = PackedInt32Array()
	grid.resize(msize * msize)
	var c := msize / 2 - 2
	fill_rect(c, c, 4, 4, G_GEN)
	for s in st["sites"]:
		fill_rect(s["x"], s["y"], 3, 3, G_SITE)
	for n in st["nodes"]:
		if n["amt"] > 0:
			fill_rect(n["x"], n["y"], 2, 2, G_NODE)
	for b in st["buildings"]:
		fill_rect(b["x"], b["y"], b["w"], b["h"], b["id"])

# ---------------------------------------------------------------- consultas
func building(bid: int) -> Dictionary:
	var idx: int = st["bindex"].get(bid, -1)
	if idx < 0:
		return {}
	return st["buildings"][idx]

func reindex_buildings() -> void:
	var bi := {}
	var arr: Array = st["buildings"]
	for i in arr.size():
		bi[arr[i]["id"]] = i
	st["bindex"] = bi

func count_type(type: String, include_building: bool = true) -> int:
	var n := 0
	for b in st["buildings"]:
		if b["type"] == type and (include_building or b["state"] == 1):
			n += 1
	return n

func site_at(x: int, y: int) -> Dictionary:
	for s in st["sites"]:
		if s["x"] == x and s["y"] == y:
			return s
	return {}

func free_sites(kind: String) -> Array:
	var out := []
	for s in st["sites"]:
		if s["kind"] == kind and s["bid"] == 0 and s["amt"] > 0:
			out.append(s)
	return out

func is_unlocked(type: String) -> bool:
	var d: Dictionary = db["buildings"].get(type, {})
	if d.is_empty():
		return false
	if d.get("hidden", false):
		return false
	if d.has("req_research") and not (d["req_research"] in st["research"]["done"]):
		return false
	if d.has("req_law") and not (d["req_law"] in st["laws"]):
		return false
	return true

## Valida la colocación (sin cobrar). Devuelve "" si es válida o el motivo.
func check_place(type: String, x: int, y: int) -> String:
	if not db["buildings"].has(type):
		return "tipo desconocido"
	var d: Dictionary = bdef(type)
	if not is_unlocked(type):
		return "bloqueado"
	if d.has("limit") and count_type(type) >= int(d["limit"]):
		return "límite alcanzado"
	var w: int = d["size"][0]
	var h: int = d["size"][1]
	if d.has("site"):
		var s := site_at(x, y)
		if s.is_empty() or s["kind"] != d["site"]:
			return "debe ir sobre un yacimiento"
		if s["bid"] != 0:
			return "yacimiento ocupado"
		if s["amt"] <= 0:
			return "yacimiento agotado"
		return ""
	if not rect_free(x, y, w, h):
		return "lugar ocupado"
	return ""

## Busca un lugar libre en espiral alrededor de (tx, ty). Devuelve (-1,-1) si no hay.
func find_spot_near(type: String, tx: int, ty: int, max_r: int = 30) -> Vector2i:
	var d: Dictionary = bdef(type)
	var w: int = d["size"][0]
	var h: int = d["size"][1]
	if check_place(type, tx, ty) == "":
		return Vector2i(tx, ty)
	for r in range(1, max_r):
		# recorrer el perímetro del cuadrado de radio r
		for i in range(-r, r + 1):
			for p in [Vector2i(tx + i, ty - r), Vector2i(tx + i, ty + r), Vector2i(tx - r, ty + i), Vector2i(tx + r, ty + i)]:
				if p.x < 0 or p.y < 0 or p.x + w > msize or p.y + h > msize:
					continue
				if rect_free(p.x, p.y, w, h):
					return p
	return Vector2i(-1, -1)

func nodes_in_radius(cx2: int, cy2: int, r: int) -> Array:
	var out := []
	for n in st["nodes"]:
		var dx: int = 2 * n["x"] + 2 - cx2
		var dy: int = 2 * n["y"] + 2 - cy2
		if dx * dx + dy * dy <= (2 * r) * (2 * r):
			out.append(n["id"])
	return out
