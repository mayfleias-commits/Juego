class_name Models
extends RefCounted
## Modelos procedurales (sin assets externos). Cada modelo es un ArrayMesh de una sola
## superficie con color por vértice; COLOR.a marca ventanas (0.5) y núcleos (0.1).
## Unidad: metros. Una casilla del mapa mide TILE metros. Origen = centro de la huella, y=0 suelo.

const TILE := 3.0

const WOOD := Color(0.45, 0.31, 0.2)
const WOOD_D := Color(0.3, 0.21, 0.14)
const STONE := Color(0.56, 0.56, 0.6)
const STONE_D := Color(0.38, 0.38, 0.42)
const RUST := Color(0.48, 0.32, 0.24)
const IRON := Color(0.3, 0.31, 0.34)
const BRASS := Color(0.68, 0.52, 0.26)
const CANVAS := Color(0.78, 0.72, 0.58)
const ROOF := Color(0.26, 0.23, 0.24)
const COAL := Color(0.12, 0.12, 0.13)
const ICE := Color(0.68, 0.84, 0.95)
const SNOWC := Color(0.92, 0.95, 1.0)
const RED := Color(0.78, 0.14, 0.12)
const PINE := Color(0.16, 0.3, 0.26)
const WIN := Color(1.0, 0.75, 0.4, 0.5)
const GLASS := Color(0.55, 0.85, 0.8, 0.68)
const CORE := Color(1.0, 0.55, 0.15, 0.1)

static var _cache := {}
## Material por color base (va en UV.x): 0 genérico, 1 metal, 2 hielo, 3 piedra, 4 madera, 5 nieve, 6 tela.
static var MAT_OF := {}

static func _mat_id(col: Color) -> float:
	if MAT_OF.is_empty():
		for c in [RUST, IRON, BRASS]:
			MAT_OF[c] = 1.0
		MAT_OF[ICE] = 2.0
		for c in [STONE, STONE_D, COAL]:
			MAT_OF[c] = 3.0
		for c in [WOOD, WOOD_D]:
			MAT_OF[c] = 4.0
		MAT_OF[SNOWC] = 5.0
		MAT_OF[CANVAS] = 6.0
	var key := Color(col.r, col.g, col.b, 1.0)
	if MAT_OF.has(key):
		return MAT_OF[key]
	# variantes oscurecidas: por tono aproximado
	if absf(col.r - col.g) < 0.04 and absf(col.g - col.b) < 0.06 and col.r < 0.7:
		return 3.0
	return 0.0

var st := SurfaceTool.new()
var _inside := Vector3.ZERO # punto interior del primitivo actual (para orientar caras)
const FLIP := false # convención de cara frontal de Godot (verificada con render de prueba)

func _init() -> void:
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

func finish() -> ArrayMesh:
	return st.commit()

# ---------------------------------------------------------------- primitivas
## Triángulo orientado hacia afuera del primitivo actual (según _inside).
func tri(a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
	var n := (b - a).cross(c - a)
	var cen := (a + b + c) / 3.0
	if n.dot(cen - _inside) < 0.0:
		var tmp := b
		b = c
		c = tmp
		n = -n
	n = n.normalized()
	var order := [a, c, b] if not FLIP else [a, b, c]
	var mid := _mat_id(col)
	for v in order:
		st.set_color(col)
		st.set_normal(n)
		st.set_uv(Vector2(mid, 0.0))
		st.add_vertex(v)

func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color) -> void:
	tri(a, b, c, col)
	tri(a, c, d, col)

## Caja con centro en la base (x,z) y altura desde y0.
func box(c: Vector3, s: Vector3, col: Color, top: Color = Color(-1, 0, 0)) -> void:
	_inside = c + Vector3(0, s.y / 2, 0)
	var x0 := c.x - s.x / 2; var x1 := c.x + s.x / 2
	var z0 := c.z - s.z / 2; var z1 := c.z + s.z / 2
	var y0 := c.y; var y1 := c.y + s.y
	var tc := col if top.r < 0 else top
	quad(Vector3(x0, y1, z0), Vector3(x1, y1, z0), Vector3(x1, y1, z1), Vector3(x0, y1, z1), tc)
	quad(Vector3(x0, y0, z1), Vector3(x1, y0, z1), Vector3(x1, y1, z1), Vector3(x0, y1, z1), col)
	quad(Vector3(x1, y0, z0), Vector3(x0, y0, z0), Vector3(x0, y1, z0), Vector3(x1, y1, z0), col)
	quad(Vector3(x1, y0, z1), Vector3(x1, y0, z0), Vector3(x1, y1, z0), Vector3(x1, y1, z1), col)
	quad(Vector3(x0, y0, z0), Vector3(x0, y0, z1), Vector3(x0, y1, z1), Vector3(x0, y1, z0), col)

## Techo a dos aguas (cumbrera sobre el eje X).
func roof(c: Vector3, s: Vector3, col: Color) -> void:
	_inside = c + Vector3(0, s.y * 0.3, 0)
	var x0 := c.x - s.x / 2; var x1 := c.x + s.x / 2
	var z0 := c.z - s.z / 2; var z1 := c.z + s.z / 2
	var y0 := c.y; var y1 := c.y + s.y
	quad(Vector3(x0, y0, z1), Vector3(x1, y0, z1), Vector3(x1, y1, c.z), Vector3(x0, y1, c.z), col)
	quad(Vector3(x1, y0, z0), Vector3(x0, y0, z0), Vector3(x0, y1, c.z), Vector3(x1, y1, c.z), col)
	tri(Vector3(x1, y0, z1), Vector3(x1, y0, z0), Vector3(x1, y1, c.z), col.darkened(0.15))
	tri(Vector3(x0, y0, z0), Vector3(x0, y0, z1), Vector3(x0, y1, c.z), col.darkened(0.15))

func pyramid(c: Vector3, s: Vector3, col: Color) -> void:
	_inside = c + Vector3(0, s.y * 0.25, 0)
	var x0 := c.x - s.x / 2; var x1 := c.x + s.x / 2
	var z0 := c.z - s.z / 2; var z1 := c.z + s.z / 2
	var top := Vector3(c.x, c.y + s.y, c.z)
	tri(Vector3(x0, c.y, z1), Vector3(x1, c.y, z1), top, col)
	tri(Vector3(x1, c.y, z1), Vector3(x1, c.y, z0), top, col.darkened(0.08))
	tri(Vector3(x1, c.y, z0), Vector3(x0, c.y, z0), top, col.darkened(0.15))
	tri(Vector3(x0, c.y, z0), Vector3(x0, c.y, z1), top, col.darkened(0.08))

func cyl(c: Vector3, r: float, h: float, col: Color, seg: int = 8, r_top: float = -1.0, cap: bool = true) -> void:
	if r_top < 0:
		r_top = r
	_inside = c + Vector3(0, h * 0.5, 0)
	for i in seg:
		var a0 := TAU * i / seg
		var a1 := TAU * (i + 1) / seg
		var p0 := Vector3(cos(a0), 0, sin(a0))
		var p1 := Vector3(cos(a1), 0, sin(a1))
		var b0 := c + p0 * r
		var b1 := c + p1 * r
		var t0 := c + p0 * r_top + Vector3(0, h, 0)
		var t1 := c + p1 * r_top + Vector3(0, h, 0)
		quad(b1, b0, t0, t1, col)
		if cap and r_top > 0.01:
			tri(c + Vector3(0, h, 0), t1, t0, col)

func cone(c: Vector3, r: float, h: float, col: Color, seg: int = 8) -> void:
	_inside = c + Vector3(0, h * 0.25, 0)
	for i in seg:
		var a0 := TAU * i / seg
		var a1 := TAU * (i + 1) / seg
		tri(c + Vector3(cos(a1), 0, sin(a1)) * r, c + Vector3(cos(a0), 0, sin(a0)) * r, c + Vector3(0, h, 0), col.darkened(0.1 * (i % 2)))

## Ventana (cara emisiva delgada) en la fachada +Z o -Z.
func window(c: Vector3, w: float, h: float, z_face: float) -> void:
	var z := z_face + (0.02 if z_face >= 0 else -0.02)
	_inside = Vector3(c.x, c.y + h / 2, 0.0 if absf(z_face) > 0.01 else -1.0)
	var x0 := c.x - w / 2; var x1 := c.x + w / 2
	if z_face >= 0:
		quad(Vector3(x0, c.y, z), Vector3(x1, c.y, z), Vector3(x1, c.y + h, z), Vector3(x0, c.y + h, z), WIN)
	else:
		quad(Vector3(x1, c.y, z), Vector3(x0, c.y, z), Vector3(x0, c.y + h, z), Vector3(x1, c.y + h, z), WIN)

func windows_row(y: float, z_face: float, xs: Array, w: float = 0.6, h: float = 0.7) -> void:
	for x in xs:
		window(Vector3(x, y, 0), w, h, z_face)

## Casa genérica: cuerpo + techo + ventanas + chimenea opcional.
func house(sx: float, sz: float, h: float, wall: Color, rf: Color, chimney: bool = true, nwin: int = 2) -> void:
	box(Vector3(0, 0, 0), Vector3(sx, h, sz), wall)
	roof(Vector3(0, h, 0), Vector3(sx + 0.4, sx * 0.35, sz + 0.4), rf)
	var xs := []
	for i in nwin:
		xs.append(-sx / 2 + sx * (i + 0.5) / nwin)
	windows_row(h * 0.4, sz / 2, xs)
	windows_row(h * 0.4, -sz / 2, xs)
	if chimney:
		box(Vector3(sx * 0.3, h, sz * 0.15), Vector3(0.5, sx * 0.45 + 0.8, 0.5), STONE_D)

# ---------------------------------------------------------------- catálogo
static func get_mesh(kind: String) -> ArrayMesh:
	if _cache.has(kind):
		return _cache[kind]
	var m := Models.new()
	m._build(kind)
	var mesh := m.finish()
	_cache[kind] = mesh
	return mesh

## Altura aproximada (para el recorte de obra y la ubicación del humo).
static func height_of(kind: String) -> float:
	var mesh := get_mesh(kind)
	return mesh.get_aabb().end.y

func _build(kind: String) -> void:
	var t := TILE
	match kind:
		"carpa":
			pyramid(Vector3(-1.2, 0, 0), Vector3(3.0, 2.6, 4.2), CANVAS)
			pyramid(Vector3(1.6, 0, 0.4), Vector3(2.4, 2.2, 3.0), CANVAS.darkened(0.08))
			box(Vector3(-1.2, 0, 2.05), Vector3(0.6, 1.0, 0.05), Color(0.2, 0.15, 0.1))
		"barracon":
			house(5.0, 4.2, 2.6, WOOD, ROOF, true, 3)
		"casa_piedra":
			house(5.0, 4.4, 3.2, STONE, ROOF, true, 2)
			box(Vector3(-1.4, 3.2, 0), Vector3(0.6, 2.2, 0.6), STONE_D)
		"puesto_rec":
			box(Vector3(0, 0, -1.0), Vector3(4.0, 2.2, 2.4), WOOD_D)
			roof(Vector3(0, 2.2, -1.0), Vector3(4.4, 1.0, 2.8), ROOF)
			for i in 3:
				box(Vector3(-1.5 + i * 1.3, 0, 1.6), Vector3(0.9, 0.7, 0.9), WOOD)
			cyl(Vector3(1.8, 0, 1.6), 0.08, 3.2, WOOD_D, 4)
			box(Vector3(2.1, 2.6, 1.6), Vector3(0.6, 0.45, 0.05), RED)
		"extractor":
			box(Vector3(0, 0, 0), Vector3(7.0, 0.6, 7.0), STONE_D)
			box(Vector3(-1.5, 0.6, 0), Vector3(3.2, 3.0, 4.0), RUST)
			roof(Vector3(-1.5, 3.6, 0), Vector3(3.6, 1.2, 4.4), ROOF)
			cyl(Vector3(1.8, 0.6, 0), 1.0, 6.5, IRON, 8)
			box(Vector3(1.8, 7.1, 0), Vector3(2.6, 0.5, 0.8), BRASS)
			cyl(Vector3(1.8, 0.6, 0), 0.35, 8.0, IRON, 6)
			windows_row(1.8, 2.0, [-2.3, -0.7])
			cyl(Vector3(-2.6, 3.6, 1.2), 0.3, 2.5, IRON, 6)
		"aserradero":
			box(Vector3(-1.0, 0, 0), Vector3(4.6, 3.0, 5.0), WOOD)
			roof(Vector3(-1.0, 3.0, 0), Vector3(5.0, 1.5, 5.4), ROOF)
			for i in 4:
				cyl(Vector3(2.4, 0.3 + i * 0.55, -2.0 + i * 0.2), 0.3, 4.0, WOOD_D, 6)
			windows_row(1.3, 2.5, [-2.2, 0.2])
			cyl(Vector3(-2.5, 4.0, 1.5), 0.25, 2.0, IRON, 6)
		"mina_hierro":
			box(Vector3(0, 0, 0), Vector3(7.0, 0.5, 7.0), RUST.darkened(0.3))
			for dx in [-1.6, 1.6]:
				box(Vector3(dx, 0.5, 0), Vector3(0.4, 7.0, 0.4), IRON)
			box(Vector3(0, 7.2, 0), Vector3(4.0, 0.4, 0.6), IRON)
			cyl(Vector3(0, 7.5, 0), 0.9, 0.3, BRASS, 10)
			box(Vector3(-2.2, 0.5, 2.0), Vector3(2.4, 2.4, 2.4), WOOD)
			window(Vector3(-2.2, 1.4, 0), 0.7, 0.7, 3.2)
		"horno_carbon":
			cyl(Vector3(0, 0, 0), 2.2, 2.2, Color(0.55, 0.3, 0.22), 10, 1.0)
			cyl(Vector3(0.8, 0, 0.8), 0.35, 5.0, STONE_D, 6)
			window(Vector3(0, 0.4, 0), 0.9, 0.7, 2.21)
		"perforadora":
			box(Vector3(0, 0, 0), Vector3(7.0, 0.6, 7.0), STONE_D)
			for a in 3:
				var ang := TAU * a / 3.0
				box(Vector3(cos(ang) * 1.6, 0.6, sin(ang) * 1.6), Vector3(0.35, 8.0, 0.35), IRON)
			cyl(Vector3(0, 0.6, 0), 0.6, 7.0, BRASS, 8)
			cone(Vector3(0, 8.4, 0), 1.2, 1.6, RUST)
			box(Vector3(-2.4, 0.6, 2.2), Vector3(2.0, 2.0, 2.0), RUST)
			window(Vector3(-2.4, 1.2, 0), 0.6, 0.6, 3.2)
		"mina_profunda":
			box(Vector3(0, 0, 0), Vector3(8.0, 0.6, 8.0), STONE_D)
			box(Vector3(-1.8, 0.6, 0), Vector3(3.6, 4.0, 6.0), STONE)
			roof(Vector3(-1.8, 4.6, 0), Vector3(4.0, 1.4, 6.4), ROOF)
			for dx in [0.8, 3.2]:
				for dz in [-1.2, 1.2]:
					box(Vector3(dx, 0.6, dz), Vector3(0.4, 10.0, 0.4), IRON)
			box(Vector3(2.0, 10.6, 0), Vector3(3.2, 0.5, 3.2), IRON)
			cyl(Vector3(2.0, 11.1, 0), 1.2, 0.4, BRASS, 10)
			windows_row(2.0, 3.0, [-2.8, -1.8, -0.8])
			cyl(Vector3(-3.0, 4.6, -2.0), 0.4, 4.0, IRON, 6)
		"fundicion":
			box(Vector3(0, 0, 0), Vector3(7.0, 4.5, 6.0), STONE_D)
			roof(Vector3(0, 4.5, 0), Vector3(7.4, 1.6, 6.4), ROOF)
			for dx in [-2.2, 2.2]:
				cyl(Vector3(dx, 4.5, -1.8), 0.6, 6.0, Color(0.5, 0.28, 0.2), 8)
			windows_row(1.4, 3.0, [-2.4, -0.8, 0.8, 2.4], 0.8, 1.2)
		"cazadores":
			box(Vector3(-0.6, 0, 0), Vector3(3.6, 2.2, 3.6), WOOD_D)
			roof(Vector3(-0.6, 2.2, 0), Vector3(4.0, 1.4, 4.0), ROOF)
			window(Vector3(-0.6, 1.0, 0), 0.6, 0.6, 1.8)
			for i in 3:
				cyl(Vector3(2.0, 0, -1.4 + i * 1.4), 0.08, 2.2, WOOD, 4)
			box(Vector3(2.0, 1.9, 0), Vector3(0.1, 0.1, 3.0), WOOD)
			box(Vector3(2.0, 1.1, -0.5), Vector3(0.15, 0.8, 0.6), Color(0.5, 0.2, 0.18))
		"cocina":
			house(4.8, 4.2, 2.8, WOOD, ROOF, false, 2)
			cyl(Vector3(1.2, 2.8, -0.8), 0.45, 3.2, STONE_D, 6)
		"invernadero", "invernadero_ind":
			var big := kind == "invernadero_ind"
			var sx := 7.6 if big else 7.0
			box(Vector3(0, 0, 0), Vector3(sx, 0.8, 6.6), STONE)
			box(Vector3(0, 0.8, 0), Vector3(sx, 2.0, 6.6), GLASS, GLASS)
			roof(Vector3(0, 2.8, 0), Vector3(sx, 1.8, 6.6), GLASS)
			if big:
				for dx in [-2.6, 0.0, 2.6]:
					cyl(Vector3(dx, 2.8, 2.6), 0.25, 3.0, BRASS, 6)
				cyl(Vector3(-3.2, 0.8, -3.0), 0.5, 5.0, IRON, 8)
		"puesto_medico":
			house(4.8, 4.2, 2.8, Color(0.85, 0.85, 0.82), ROOF, false, 2)
			box(Vector3(0, 1.6, 2.12), Vector3(1.0, 0.25, 0.04), RED)
			box(Vector3(0, 1.22, 2.12), Vector3(0.25, 1.0, 0.04), RED)
		"enfermeria":
			box(Vector3(0, 0, 0), Vector3(7.4, 4.0, 6.4), Color(0.86, 0.86, 0.84))
			roof(Vector3(0, 4.0, 0), Vector3(7.8, 1.6, 6.8), ROOF)
			windows_row(1.0, 3.2, [-2.6, -1.0, 1.0, 2.6])
			windows_row(2.6, 3.2, [-2.6, -1.0, 1.0, 2.6])
			box(Vector3(0, 4.6, 3.25), Vector3(1.4, 0.35, 0.05), RED)
			box(Vector3(0, 4.15, 3.25), Vector3(0.35, 1.3, 0.05), RED)
		"casa_cuidados":
			house(5.0, 4.4, 3.0, Color(0.75, 0.68, 0.58), ROOF, true, 3)
		"cementerio":
			box(Vector3(0, 0, 0), Vector3(8.0, 0.15, 8.0), Color(0.75, 0.78, 0.82))
			for ix in 4:
				for iz in 3:
					var p := Vector3(-2.7 + ix * 1.8, 0.15, -2.2 + iz * 2.2)
					box(p, Vector3(0.12, 1.1, 0.12), STONE_D)
					box(p + Vector3(0, 0.7, 0), Vector3(0.6, 0.12, 0.12), STONE_D)
			for i in 8:
				box(Vector3(-4 + i * 1.14, 0, 4.0), Vector3(0.12, 1.0, 0.12), WOOD_D)
		"fosa":
			box(Vector3(0, 0, 0), Vector3(5.0, 0.1, 5.0), Color(0.15, 0.15, 0.17))
			for i in 4:
				box(Vector3(-2.5 + i * 1.66, 0, 2.6), Vector3(1.0, 0.6, 0.3), SNOWC)
		"estacion_vapor":
			cyl(Vector3(0, 0, 0), 2.0, 3.6, IRON, 10)
			cyl(Vector3(0, 3.6, 0), 2.1, 0.4, BRASS, 10)
			cyl(Vector3(0, 4.0, 0), 0.6, 4.5, RUST, 8)
			box(Vector3(0, 1.0, 1.98), Vector3(1.2, 1.0, 0.06), CORE)
		"taller":
			box(Vector3(0, 0, 0), Vector3(5.0, 3.2, 4.6), STONE)
			roof(Vector3(0, 3.2, 0), Vector3(5.4, 1.2, 5.0), ROOF)
			windows_row(1.2, 2.3, [-1.5, 0.0, 1.5], 0.7, 1.0)
			cyl(Vector3(1.8, 3.2, -1.2), 0.3, 2.6, IRON, 6)
			cyl(Vector3(-1.6, 3.6, 0), 0.7, 0.2, BRASS, 10)
		"deposito":
			box(Vector3(0, 0, 0), Vector3(5.4, 2.8, 5.0), WOOD_D)
			roof(Vector3(0, 2.8, 0), Vector3(5.8, 1.6, 5.4), ROOF)
			box(Vector3(0, 0, 2.52), Vector3(2.2, 2.0, 0.05), WOOD)
		"carbonera":
			cyl(Vector3(0, 0, 0), 2.5, 1.6, WOOD_D, 10)
			cone(Vector3(0, 1.6, 0), 2.4, 1.8, COAL, 10)
			for a in 4:
				var ang := TAU * a / 4.0 + 0.4
				box(Vector3(cos(ang) * 2.5, 0, sin(ang) * 2.5), Vector3(0.25, 3.8, 0.25), WOOD)
			pyramid(Vector3(0, 3.8, 0), Vector3(5.6, 1.2, 5.6), ROOF)
		"faro":
			box(Vector3(-1.2, 0, 0), Vector3(3.0, 2.4, 3.6), WOOD)
			roof(Vector3(-1.2, 2.4, 0), Vector3(3.4, 1.0, 4.0), ROOF)
			cyl(Vector3(1.4, 0, 0), 0.9, 9.0, STONE, 8, 0.6)
			cyl(Vector3(1.4, 9.0, 0), 0.8, 1.0, WIN, 8)
			cone(Vector3(1.4, 10.0, 0), 1.0, 1.2, RUST, 8)
		"fabrica_aut":
			box(Vector3(0, 0, 0), Vector3(8.0, 5.0, 7.0), RUST)
			roof(Vector3(0, 5.0, 0), Vector3(8.4, 1.4, 7.4), ROOF)
			for dx in [-2.6, 0.0, 2.6]:
				box(Vector3(dx, 5.6, 0), Vector3(1.4, 0.8, 7.0), GLASS)
			cyl(Vector3(3.2, 5.0, -2.6), 0.6, 5.0, IRON, 8)
			box(Vector3(0, 0, 3.52), Vector3(3.0, 3.2, 0.05), IRON)
			windows_row(3.4, 3.5, [-3.0, 3.0], 1.0, 0.8)
		"taberna":
			house(5.0, 4.4, 2.8, WOOD_D, ROOF, true, 3)
			box(Vector3(2.4, 2.2, 2.4), Vector3(0.8, 0.5, 0.06), BRASS)
		"banos":
			box(Vector3(0, 0, 0), Vector3(5.2, 2.6, 4.8), STONE)
			cyl(Vector3(0, 2.6, 0), 2.2, 1.6, STONE_D, 10, 0.4)
			windows_row(1.0, 2.4, [-1.6, 0.0, 1.6])
			cyl(Vector3(1.8, 2.6, -1.6), 0.35, 3.0, IRON, 6)
		"refugio_inf":
			house(5.0, 4.4, 2.8, Color(0.62, 0.48, 0.32), Color(0.45, 0.18, 0.16), true, 3)
		"guardia":
			box(Vector3(0, 0, 0), Vector3(4.0, 2.6, 4.0), STONE_D)
			cyl(Vector3(1.5, 0, 1.5), 0.9, 5.0, STONE, 8)
			cone(Vector3(1.5, 5.0, 1.5), 1.1, 1.4, ROOF, 8)
			window(Vector3(0, 1.2, 0), 0.8, 0.5, 2.0)
		"proclamas":
			box(Vector3(0, 0, 0), Vector3(4.6, 3.0, 4.2), STONE)
			roof(Vector3(0, 3.0, 0), Vector3(5.0, 1.0, 4.6), ROOF)
			cyl(Vector3(0, 4.0, 0), 0.15, 4.5, IRON, 4)
			for a in 3:
				var ang := TAU * a / 3.0
				cone(Vector3(cos(ang) * 0.5, 7.6, sin(ang) * 0.5), 0.45, 0.8, BRASS, 6)
			windows_row(1.2, 2.1, [-1.4, 1.4])
		"prision":
			box(Vector3(0, 0, 0), Vector3(7.6, 4.0, 7.0), STONE_D)
			box(Vector3(0, 4.0, 0), Vector3(5.0, 1.6, 4.2), STONE)
			for dx in [-3.6, 3.6]:
				for dz in [-3.3, 3.3]:
					cyl(Vector3(dx, 0, dz), 0.7, 5.6, STONE, 6)
			windows_row(2.0, 3.5, [-2.4, -0.8, 0.8, 2.4], 0.3, 0.6)
		"torre_vigia":
			cyl(Vector3(0, 0, 0), 1.6, 10.0, STONE_D, 8, 1.1)
			cyl(Vector3(0, 10.0, 0), 1.6, 1.2, IRON, 8)
			cyl(Vector3(0, 11.2, 0), 0.9, 0.8, WIN, 8)
			cone(Vector3(0, 12.0, 0), 1.7, 1.6, ROOF, 8)
		"capilla":
			box(Vector3(0, 0, 0), Vector3(4.0, 3.4, 5.2), STONE)
			roof(Vector3(0, 3.4, 0), Vector3(4.4, 2.0, 5.6), ROOF)
			box(Vector3(0, 0, 2.2), Vector3(1.4, 6.0, 1.4), STONE)
			pyramid(Vector3(0, 6.0, 2.2), Vector3(1.6, 2.4, 1.6), ROOF)
			box(Vector3(0, 3.4, 2.92), Vector3(0.6, 1.2, 0.05), CORE)
		"casa_sanacion":
			house(4.8, 4.4, 2.8, Color(0.82, 0.78, 0.66), ROOF, true, 2)
			box(Vector3(0, 2.0, 2.22), Vector3(0.7, 0.7, 0.05), CORE)
		"templo":
			box(Vector3(0, 0, 0), Vector3(7.6, 5.0, 7.0), STONE)
			roof(Vector3(0, 5.0, 0), Vector3(8.0, 2.6, 7.4), ROOF)
			box(Vector3(0, 0, 3.0), Vector3(2.4, 9.0, 2.4), STONE)
			pyramid(Vector3(0, 9.0, 3.0), Vector3(2.8, 4.0, 2.8), ROOF)
			cyl(Vector3(0, 13.0, 3.0), 0.35, 0.8, CORE, 6)
			windows_row(1.6, 3.5, [-2.6, -1.3, 1.3, 2.6], 0.6, 1.8)
		"santuario":
			cyl(Vector3(0, 0, 0), 2.4, 0.4, STONE, 10)
			for a in 6:
				var ang := TAU * a / 6.0
				box(Vector3(cos(ang) * 2.0, 0.4, sin(ang) * 2.0), Vector3(0.35, 3.4, 0.35), STONE)
			cyl(Vector3(0, 3.8, 0), 2.4, 0.4, STONE_D, 10)
			cyl(Vector3(0, 0.4, 0), 0.6, 1.2, BRASS, 8)
			cyl(Vector3(0, 1.6, 0), 0.4, 0.6, CORE, 6)
		"generador":
			cyl(Vector3(0, 0, 0), 5.8, 1.2, STONE_D, 16)
			cyl(Vector3(0, 1.2, 0), 4.6, 2.5, IRON, 16)
			cyl(Vector3(0, 3.7, 0), 3.8, 9.0, RUST, 16, 3.2)
			for y in [5.0, 8.0, 11.0]:
				cyl(Vector3(0, y, 0), 4.0 - y * 0.05, 0.5, BRASS, 16)
			for a in 8:
				var ang := TAU * a / 8.0
				box(Vector3(cos(ang) * 4.0, 3.7, sin(ang) * 4.0), Vector3(0.7, 2.2, 0.7), CORE)
			cyl(Vector3(0, 12.7, 0), 3.2, 1.0, IRON, 16, 2.0)
			cyl(Vector3(0, 13.7, 0), 1.6, 9.0, IRON.darkened(0.2), 12, 1.3)
			cyl(Vector3(0, 22.7, 0), 1.6, 0.6, BRASS, 12)
			for a in 4:
				var ang2 := TAU * a / 4.0 + 0.4
				box(Vector3(cos(ang2) * 5.2, 0, sin(ang2) * 5.2), Vector3(1.2, 4.5, 1.2), STONE)
		# ---------------- recursos
		"pila_carbon":
			cone(Vector3(-0.8, 0, -0.5), 2.0, 1.6, COAL, 7)
			cone(Vector3(1.0, 0, 0.7), 1.6, 1.2, COAL.lightened(0.05), 7)
			box(Vector3(1.5, 0, -1.4), Vector3(0.8, 0.5, 0.6), COAL)
		"cajones":
			for i in 5:
				var p := Vector3(-1.6 + (i % 3) * 1.4, (i / 3) * 1.0, -0.6 + (i % 2) * 1.2)
				box(p, Vector3(1.1, 1.0, 1.1), WOOD.lightened(0.05 * (i % 2)))
		"arboles":
			for i in 4:
				var p := Vector3(-1.4 + (i % 2) * 2.6, 0, -1.2 + (i / 2) * 2.4)
				cyl(p, 0.18, 1.0, WOOD_D, 5)
				cone(p + Vector3(0, 0.8, 0), 1.1, 3.6, PINE.lightened(0.35), 7)
		"chatarra":
			box(Vector3(-0.8, 0, 0), Vector3(1.8, 0.8, 1.2), RUST)
			box(Vector3(0.9, 0, 0.6), Vector3(1.2, 1.2, 1.0), IRON)
			cyl(Vector3(0.4, 0.2, -1.2), 0.35, 2.4, RUST.darkened(0.2), 6)
		"veta_carbon":
			for i in 6:
				var ang := TAU * i / 6.0
				cone(Vector3(cos(ang) * 2.2, 0, sin(ang) * 2.2), 1.2, 0.9 + (i % 3) * 0.4, COAL, 6)
			box(Vector3(0, 0, 0), Vector3(4.0, 0.15, 4.0), COAL)
		"veta_profunda":
			cyl(Vector3(0, 0, 0), 3.8, 0.6, STONE_D, 12, 3.0)
			cyl(Vector3(0, 0.05, 0), 2.6, 0.6, COAL, 12)
		"bosque":
			for i in 7:
				var ang := TAU * i / 7.0
				var p := Vector3(cos(ang) * 2.6, 0, sin(ang) * 2.6) * (0.6 + 0.4 * (i % 2))
				cyl(p, 0.22, 1.2, WOOD_D, 5)
				cone(p + Vector3(0, 1.0, 0), 1.3, 4.5 + (i % 3), PINE.lightened(0.3), 7)
		"muro_hielo":
			for i in 5:
				box(Vector3(-3.2 + i * 1.6, 0, -0.5 + (i % 2) * 0.8), Vector3(1.6, 4.0 + (i % 3) * 1.4, 1.8), ICE.darkened(0.05 * (i % 2)))
			for i in 3:
				cyl(Vector3(-2.0 + i * 2.0, 0.5, 0), 0.25, 2.5, WOOD_D, 5)
		"veta_metal":
			for i in 5:
				var ang := TAU * i / 5.0
				box(Vector3(cos(ang) * 2.0, 0, sin(ang) * 2.0), Vector3(1.4, 1.0 + (i % 2) * 0.8, 1.2), RUST.darkened(0.1 * (i % 2)))
			box(Vector3(0, 0, 0), Vector3(3.6, 0.2, 3.6), RUST)
		# ---------------- otros
		"ciudadano":
			box(Vector3(0, 0, 0), Vector3(0.45, 1.15, 0.32), Color(0.28, 0.24, 0.22))
			box(Vector3(0, 1.15, 0), Vector3(0.3, 0.3, 0.3), Color(0.85, 0.7, 0.6))
			box(Vector3(0, 1.38, 0), Vector3(0.36, 0.12, 0.36), Color(0.35, 0.15, 0.12))
		"ciudadano_lejos":
			box(Vector3(0, 0, 0), Vector3(0.5, 1.5, 0.05), Color(0.25, 0.22, 0.2))
		"automata":
			box(Vector3(0, 0, 0), Vector3(0.8, 1.6, 0.6), BRASS)
			box(Vector3(0, 1.6, 0), Vector3(0.5, 0.5, 0.5), IRON)
			box(Vector3(0, 1.75, 0.26), Vector3(0.3, 0.12, 0.02), CORE)
		_:
			house(4.6, 4.2, 2.6, WOOD, ROOF, false, 2)
