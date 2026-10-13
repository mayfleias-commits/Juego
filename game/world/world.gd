class_name World
extends Node3D
## Escena 3D del valle. Solo LEE el estado de la simulación.
## Edificios, pilas y yacimientos: un MultiMesh por tipo (1 llamada de dibujo por tipo).

const T := Models.TILE
const SMOKE_TYPES := {"cocina": 1.0, "horno_carbon": 1.2, "fundicion": 1.5, "estacion_vapor": 1.3, "casa_piedra": 0.6,
	"extractor": 0.8, "taller": 0.6, "mina_profunda": 1.0, "banos": 0.8, "barracon": 0.5, "fabrica_aut": 1.2, "aserradero": 0.6}

var sim: Simulation
var mat_building: ShaderMaterial
var mat_static: ShaderMaterial
var env: Environment
var sun: DirectionalLight3D
var gen_light: OmniLight3D
var gen_node: MeshInstance3D
var gen_glow: MeshInstance3D
var snow: MultiMeshInstance3D
var smoke: MultiMeshInstance3D
var overlay: MeshInstance3D
var overlay_img: Image
var overlay_tex: ImageTexture
var overlay_mode := -1
var ghost: MeshInstance3D
var ghost_mat: StandardMaterial3D
var citizens: Citizens
var camera_rig: CameraRig

var _bmm := {} # tipo -> MultiMeshInstance3D
var _nmm := {} # look de pila -> MultiMeshInstance3D
var _smm := {} # tipo de yacimiento -> MultiMeshInstance3D
var _bver := ""
var _nver := ""
var _selected := -1
var _station_glows: Array = []
var _extra_lights: Array = []
var _time_acc := 0.0

func setup(s: Simulation) -> void:
	sim = s
	for c in get_children():
		c.queue_free()
	_bmm.clear(); _nmm.clear(); _smm.clear(); _bver = ""; _nver = ""
	_station_glows.clear(); _extra_lights.clear()
	var sh := load("res://game/shaders/building.gdshader") as Shader
	mat_building = ShaderMaterial.new()
	mat_building.shader = sh
	mat_static = ShaderMaterial.new()
	mat_static.shader = sh
	mat_static.set_shader_parameter("use_instance", false)
	_make_environment()
	_make_terrain()
	_make_generator()
	_make_snow()
	_make_smoke()
	_make_overlay()
	_make_ghost()
	citizens = Citizens.new()
	add_child(citizens)
	citizens.setup(self)
	camera_rig = CameraRig.new()
	add_child(camera_rig)
	apply_settings()
	refresh(true)

# ---------------------------------------------------------------- coordenadas
func tile_to_world(x: float, y: float) -> Vector3:
	var c := sim.msize / 2.0
	return Vector3((x - c) * T, 0.0, (y - c) * T)

func rect_center(x: int, y: int, w: int, h: int) -> Vector3:
	return tile_to_world(x + w / 2.0, y + h / 2.0)

func world_to_tile(p: Vector3) -> Vector2i:
	var c := sim.msize / 2.0
	return Vector2i(int(floor(p.x / T + c)), int(floor(p.z / T + c)))

## Punto del suelo bajo una posición de pantalla.
func ground_at(screen: Vector2) -> Vector3:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return Vector3.INF
	var o := cam.project_ray_origin(screen)
	var d := cam.project_ray_normal(screen)
	if absf(d.y) < 0.0001:
		return Vector3.INF
	var t := -o.y / d.y
	if t < 0:
		return Vector3.INF
	return o + d * t

# ---------------------------------------------------------------- escena
func _make_environment() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	if Settings.p("sky"):
		var sky_mat := ProceduralSkyMaterial.new()
		sky_mat.sky_top_color = Color(0.32, 0.42, 0.55)
		sky_mat.sky_horizon_color = Color(0.68, 0.74, 0.8)
		sky_mat.ground_horizon_color = Color(0.68, 0.74, 0.8)
		sky_mat.ground_bottom_color = Color(0.5, 0.55, 0.6)
		var sky := Sky.new()
		sky.sky_material = sky_mat
		env.background_mode = Environment.BG_SKY
		env.sky = sky
	else:
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0.6, 0.67, 0.75)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.62, 0.75)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = Settings.p("fog")
	env.fog_light_color = Color(0.72, 0.78, 0.86)
	env.fog_density = 0.002
	env.fog_sky_affect = 0.6
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.light_energy = 1.0
	sun.shadow_enabled = Settings.shadows
	sun.directional_shadow_max_distance = 140.0
	add_child(sun)

func _terrain_height(x: float, z: float) -> float:
	var r := Vector2(x, z).length()
	var basin := (sim.mradius + 1) * T
	var rim := basin + 40.0
	var h := 0.0
	if r > basin:
		var t := clampf((r - basin) / (rim - basin), 0.0, 1.0)
		h = t * t * (3.0 - 2.0 * t) * 26.0
		h += (sin(x * 0.11) + cos(z * 0.13) + sin((x + z) * 0.05)) * 2.2 * t
	else:
		h = -0.15 + (r / basin) * 0.15
	return h

func _make_terrain() -> void:
	var n: int = Settings.p("terrain_res")
	var size := 300.0
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step := size / n
	var heights := []
	for j in n + 1:
		for i in n + 1:
			var x := -size / 2 + i * step
			var z := -size / 2 + j * step
			heights.append(_terrain_height(x, z))
	var snowc := Color(0.86, 0.9, 0.96)
	var rock := Color(0.42, 0.44, 0.5)
	var trampled := Color(0.66, 0.64, 0.63)
	for j in n:
		for i in n:
			var idx := [j * (n + 1) + i, j * (n + 1) + i + 1, (j + 1) * (n + 1) + i + 1, (j + 1) * (n + 1) + i]
			var pts := []
			for k in 4:
				var ii := i + (1 if k == 1 or k == 2 else 0)
				var jj := j + (1 if k >= 2 else 0)
				pts.append(Vector3(-size / 2 + ii * step, heights[idx[k]], -size / 2 + jj * step))
			for tri in [[0, 1, 2], [0, 2, 3]]:
				var a: Vector3 = pts[tri[0]]
				var b: Vector3 = pts[tri[1]]
				var c: Vector3 = pts[tri[2]]
				var nn := (c - a).cross(b - a).normalized()
				if nn.y < 0:
					nn = -nn
				var steep := clampf((1.0 - nn.y) * 3.0, 0.0, 1.0)
				var col := snowc.lerp(rock, steep)
				# Plaza pisoteada alrededor del generador y senderos radiales.
				var mid := (a + b + c) / 3.0
				var rr := Vector2(mid.x, mid.z).length()
				var ang := atan2(mid.z, mid.x)
				var path := absf(sin(ang * 3.0)) < 0.08 and rr < (sim.mradius - 2) * T
				var tr := clampf(1.0 - (rr - 11.0) / 6.0, 0.0, 1.0)
				if path:
					tr = maxf(tr, 0.55)
				col = col.lerp(trampled, tr * 0.8)
				for v in [a, c, b]:
					st.set_color(col)
					st.set_normal(nn)
					st.add_vertex(v)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := ShaderMaterial.new()
	m.shader = load("res://game/shaders/terrain.gdshader")
	m.set_shader_parameter("sparkle", 0.6 if Settings.p("detail") >= 2 else 0.0)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

func _make_generator() -> void:
	gen_node = MeshInstance3D.new()
	gen_node.mesh = Models.get_mesh("generador")
	gen_node.material_override = mat_static
	add_child(gen_node)
	gen_glow = _glow_sprite(Color(1.0, 0.5, 0.18), 22.0)
	gen_glow.position = Vector3(0, 6.0, 0)
	add_child(gen_glow)
	gen_light = OmniLight3D.new()
	gen_light.position = Vector3(0, 8.0, 0)
	gen_light.light_color = Color(1.0, 0.6, 0.3)
	gen_light.omni_range = 40.0
	gen_light.light_energy = 2.0
	gen_light.shadow_enabled = false
	add_child(gen_light)

func _glow_sprite(col: Color, size: float) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	var mi := MeshInstance3D.new()
	mi.mesh = q
	var m := ShaderMaterial.new()
	m.shader = load("res://game/shaders/glow.gdshader")
	m.set_shader_parameter("color", col)
	m.set_shader_parameter("pulse", 1.0)
	mi.material_override = m
	mi.scale = Vector3.ONE * size
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

func _make_snow() -> void:
	snow = MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	mm.mesh = q
	mm.instance_count = 3000
	mm.visible_instance_count = Settings.p("snow")
	snow.multimesh = mm
	var m := ShaderMaterial.new()
	m.shader = load("res://game/shaders/snow.gdshader")
	snow.material_override = m
	snow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	snow.extra_cull_margin = 500.0
	add_child(snow)

func _make_smoke() -> void:
	smoke = MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	mm.mesh = q
	mm.instance_count = 320
	mm.visible_instance_count = 0
	smoke.multimesh = mm
	var m := ShaderMaterial.new()
	m.shader = load("res://game/shaders/smoke.gdshader")
	smoke.material_override = m
	smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	smoke.extra_cull_margin = 500.0
	add_child(smoke)

func _make_overlay() -> void:
	overlay = MeshInstance3D.new()
	var p := PlaneMesh.new()
	var span := sim.msize * T
	p.size = Vector2(span, span)
	overlay.mesh = p
	overlay.position = Vector3(0, 0.12, 0)
	overlay_img = Image.create(sim.msize, sim.msize, false, Image.FORMAT_RGBA8)
	overlay_tex = ImageTexture.create_from_image(overlay_img)
	var m := ShaderMaterial.new()
	m.shader = load("res://game/shaders/overlay.gdshader")
	m.set_shader_parameter("data_tex", overlay_tex)
	overlay.material_override = m
	overlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	overlay.visible = false
	add_child(overlay)

func _make_ghost() -> void:
	ghost = MeshInstance3D.new()
	ghost_mat = StandardMaterial3D.new()
	ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ghost_mat.albedo_color = Color(0.3, 1.0, 0.4, 0.45)
	ghost.material_override = ghost_mat
	ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ghost.visible = false
	add_child(ghost)

func apply_settings() -> void:
	if sun:
		sun.shadow_enabled = Settings.shadows
	if snow:
		snow.multimesh.visible_instance_count = Settings.p("snow") if Settings.effects else 0
	if env:
		env.fog_enabled = Settings.p("fog")
	if gen_light:
		gen_light.visible = int(Settings.p("lights")) >= 2
	if citizens:
		citizens.max_visible = Settings.p("citizens")
	refresh(true)

# ---------------------------------------------------------------- actualización
func _mm_for(dict: Dictionary, key: String, model: String, shadows: bool = true) -> MultiMeshInstance3D:
	if dict.has(key):
		return dict[key]
	var mmi := MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true # en Compatibility el color de vértice se multiplica por el de instancia
	mm.use_custom_data = true
	mm.mesh = Models.get_mesh(model)
	mmi.multimesh = mm
	mmi.material_override = mat_building
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	dict[key] = mmi
	return mmi

## Rota algunos modelos para variar el aspecto (determinista por id).
func _basis_for(id: int) -> Basis:
	return Basis(Vector3.UP, (id % 4) * PI * 0.5)

func refresh(force: bool = false) -> void:
	if sim == null:
		return
	_refresh_buildings(force)
	_refresh_nodes(force)
	_refresh_smoke()
	if overlay_mode >= 0:
		update_overlay()

func _refresh_buildings(force: bool) -> void:
	var groups := {}
	var ver := ""
	for b in sim.st["buildings"]:
		var t: String = b["type"]
		if not groups.has(t):
			groups[t] = []
		groups[t].append(b)
		ver += "%d%s%d%d%d|" % [b["id"], t, b["state"], int(b["left"]) / 250, b["on"]]
	ver += str(_selected)
	if ver == _bver and not force:
		return
	_bver = ver
	for t in _bmm:
		if not groups.has(t):
			_bmm[t].multimesh.instance_count = 0
	var station_pos := []
	for t in groups:
		var arr: Array = groups[t]
		var mmi := _mm_for(_bmm, t, t)
		var mm := mmi.multimesh
		mm.instance_count = arr.size()
		var hgt := Models.height_of(t)
		var d: Dictionary = sim.bdef(t)
		for i in arr.size():
			var b: Dictionary = arr[i]
			var pos := rect_center(b["x"], b["y"], b["w"], b["h"])
			var basis := _basis_for(b["id"]) if int(b["w"]) == int(b["h"]) else Basis()
			mm.set_instance_transform(i, Transform3D(basis, pos))
			var cut := 999.0
			if int(b["state"]) == 0:
				var total: float = float(d["build_h"]) * 1000.0
				var prog := 1.0 - float(b["left"]) / maxf(1.0, total)
				cut = maxf(0.3, prog * hgt)
			var lit := 1.0 if (int(b["on"]) == 1 and int(b["state"]) == 1) else 0.0
			mm.set_instance_color(i, Color.WHITE)
			mm.set_instance_custom_data(i, Color(cut, 1.0 if int(b["id"]) == _selected else 0.0, lit, 0.0))
			if d.get("kind", "") == "station" and int(b.get("lit", 0)) == 1:
				station_pos.append(pos)
	# Brillos y luces de estaciones de vapor
	for g in _station_glows:
		g.queue_free()
	_station_glows.clear()
	for l in _extra_lights:
		l.queue_free()
	_extra_lights.clear()
	var max_lights: int = int(Settings.p("lights")) - 2
	for p in station_pos:
		var gl := _glow_sprite(Color(1.0, 0.55, 0.25), 9.0)
		gl.position = p + Vector3(0, 2.0, 0)
		add_child(gl)
		_station_glows.append(gl)
		if _extra_lights.size() < max_lights:
			var ol := OmniLight3D.new()
			ol.position = p + Vector3(0, 4, 0)
			ol.light_color = Color(1.0, 0.6, 0.3)
			ol.omni_range = 16.0
			ol.light_energy = 1.2
			add_child(ol)
			_extra_lights.append(ol)

func _refresh_nodes(force: bool) -> void:
	var ver := ""
	for n in sim.st["nodes"]:
		ver += "1" if int(n["amt"]) > 0 else "0"
	for s in sim.st["sites"]:
		ver += "s%d" % int(s["bid"])
	if ver == _nver and not force:
		return
	_nver = ver
	var groups := {}
	for n in sim.st["nodes"]:
		if int(n["amt"]) <= 0:
			continue
		var look: String = n.get("look", n["kind"])
		if not groups.has(look):
			groups[look] = []
		groups[look].append(rect_center(n["x"], n["y"], 2, 2))
	for k in _nmm:
		if not groups.has(k):
			_nmm[k].multimesh.instance_count = 0
	for look in groups:
		var mm := _mm_for(_nmm, look, look).multimesh
		var arr: Array = groups[look]
		mm.instance_count = arr.size()
		for i in arr.size():
			mm.set_instance_transform(i, Transform3D(_basis_for(i * 7 + 1), arr[i]))
			mm.set_instance_color(i, Color.WHITE)
			mm.set_instance_custom_data(i, Color(999.0, 0.0, 0.0, 0.0))
	var sg := {}
	for s in sim.st["sites"]:
		if int(s["bid"]) != 0:
			continue
		if not sg.has(s["kind"]):
			sg[s["kind"]] = []
		sg[s["kind"]].append(rect_center(s["x"], s["y"], 3, 3))
	for k in _smm:
		if not sg.has(k):
			_smm[k].multimesh.instance_count = 0
	for kind in sg:
		var mm2 := _mm_for(_smm, kind, kind).multimesh
		var arr2: Array = sg[kind]
		mm2.instance_count = arr2.size()
		for i in arr2.size():
			mm2.set_instance_transform(i, Transform3D(Basis(), arr2[i]))
			mm2.set_instance_color(i, Color.WHITE)
			mm2.set_instance_custom_data(i, Color(999.0, 0.0, 0.0, 0.0))

func _refresh_smoke() -> void:
	var emitters := []
	if int(sim.st["gen"]["on"]) == 1:
		emitters.append([Vector3(0, 23.5, 0), 1.6 + 0.4 * int(sim.st["gen"]["level"])])
	for b in sim.st["buildings"]:
		if int(b["state"]) != 1 or int(b["on"]) != 1:
			continue
		var t: String = b["type"]
		if SMOKE_TYPES.has(t):
			var active: bool = int(b["o"]) + int(b["i"]) + int(b["n"]) + int(b["auto"]) > 0 or int(sim.bdef(t).get("housing", 0)) > 0 or t == "estacion_vapor"
			if active:
				var p := rect_center(b["x"], b["y"], b["w"], b["h"])
				emitters.append([p + Vector3(0, Models.height_of(t) + 0.5, 0), SMOKE_TYPES[t]])
	var cap: int = int(Settings.p("smoke")) if Settings.effects else 0
	var per := 5
	var n := mini(emitters.size() * per, cap)
	var mm := smoke.multimesh
	mm.visible_instance_count = n
	for i in n:
		var e: Array = emitters[i / per]
		var phase := float(i % per) / per + float(i / per) * 0.13
		var k: float = e[1]
		var pos: Vector3 = e[0]
		mm.set_instance_transform(i, Transform3D(Basis(), pos))
		mm.set_instance_custom_data(i, Color(pos.x, pos.y, pos.z, floor(k * 10.0) + fmod(phase, 1.0)))

func set_selected(bid: int) -> void:
	_selected = bid
	_refresh_buildings(true)

# ---------------------------------------------------------------- superposiciones
func set_overlay(mode: int) -> void:
	overlay_mode = mode
	overlay.visible = mode >= 0
	if mode >= 0:
		overlay.material_override.set_shader_parameter("mode", mode)
		update_overlay()

func update_overlay() -> void:
	var n := sim.msize
	overlay_img.fill(Color(0, 0, 0, 0))
	match overlay_mode:
		0:
			var out := sim.outdoor()
			for y in n:
				for x in n:
					if not sim.tile_in_bounds(x, y):
						continue
					var z := sim.zone_heat_at(2 * x + 1, 2 * y + 1)
					var t := out + z
					var v := clampf((t + 40.0) / 45.0, 0.0, 1.0)
					overlay_img.set_pixel(x, y, Color(v, 0, 0, 1.0 if z > 0 else 0.45))
		1:
			for b in sim.st["buildings"]:
				var d: Dictionary = sim.bdef(b["type"])
				if int(d.get("housing", 0)) <= 0 and sim.staff_max(d) <= 0:
					continue
				var risk := 1.0 - float(b["lvl"]) / 4.0
				for yy in range(b["y"], b["y"] + b["h"]):
					for xx in range(b["x"], b["x"] + b["w"]):
						overlay_img.set_pixel(xx, yy, Color(risk, 0, 0, 1))
		2:
			for nd in sim.st["nodes"]:
				var f := float(nd["amt"]) / maxf(1.0, float(nd["max"]))
				for yy in range(nd["y"], nd["y"] + 2):
					for xx in range(nd["x"], nd["x"] + 2):
						overlay_img.set_pixel(xx, yy, Color(f, 0, 0, 1 if f > 0 else 0.5))
			for s in sim.st["sites"]:
				var f2 := float(s["amt"]) / maxf(1.0, float(s["max"]))
				for yy in range(s["y"], s["y"] + 3):
					for xx in range(s["x"], s["x"] + 3):
						overlay_img.set_pixel(xx, yy, Color(f2, 0, 0, 1))
	overlay_tex.update(overlay_img)

# ---------------------------------------------------------------- fantasma de construcción
func show_ghost(type: String, tile: Vector2i) -> bool:
	if type == "":
		ghost.visible = false
		return false
	var d: Dictionary = sim.bdef(type)
	var w: int = d["size"][0]
	var h: int = d["size"][1]
	var x := tile.x - w / 2
	var y := tile.y - h / 2
	if d.has("site"):
		# Imán: el yacimiento libre más cercano del tipo pedido.
		var best := Vector2i(-1, -1)
		var bd := 1 << 30
		for s in sim.free_sites(d["site"]):
			var dd: int = (int(s["x"]) + 1 - tile.x) ** 2 + (int(s["y"]) + 1 - tile.y) ** 2
			if dd < bd:
				bd = dd
				best = Vector2i(s["x"], s["y"])
		if best.x >= 0 and bd <= 64:
			x = best.x
			y = best.y
	ghost.mesh = Models.get_mesh(type)
	ghost.position = rect_center(x, y, w, h)
	ghost.visible = true
	var ok := sim.check_place(type, x, y) == ""
	ghost_mat.albedo_color = Color(0.3, 1.0, 0.4, 0.45) if ok else Color(1.0, 0.25, 0.2, 0.45)
	ghost.set_meta("place", Vector2i(x, y))
	return ok

func ghost_place() -> Vector2i:
	return ghost.get_meta("place", Vector2i(-1, -1))

func building_at_tile(t: Vector2i) -> int:
	if t.x < 0 or t.y < 0 or t.x >= sim.msize or t.y >= sim.msize:
		return 0
	var v: int = sim.grid[sim.gidx(t.x, t.y)]
	return v if v > 0 else 0

# ---------------------------------------------------------------- por cuadro
func _process(delta: float) -> void:
	if sim == null:
		return
	_time_acc += delta
	var hf := Session.hour_fraction() if Session.sim == sim else 0.0
	var h := float(sim.hour()) + hf
	_update_daylight(h)
	var cam := get_viewport().get_camera_3d()
	var smat := snow.material_override as ShaderMaterial
	if cam:
		var target := camera_rig.target if camera_rig else cam.global_position
		smat.set_shader_parameter("center", Vector3(target.x, 0, target.z))
	var cold := clampf((-sim.outdoor() - 15.0) / 60.0, 0.0, 1.0)
	smat.set_shader_parameter("fall_speed", 2.5 + cold * 5.0)
	smat.set_shader_parameter("wind", Vector2(1.5 + cold * 9.0, 0.5 + cold * 3.0))
	var wave := sim.in_wave()
	var base_n: int = Settings.p("snow") if Settings.effects else 0
	# En oleada la nevada se duplica, pero nunca pasa el tope del preset de celular (300).
	var snow_cap := 300 if Settings.preset in ["muy_bajo", "bajo"] else 3000
	snow.multimesh.visible_instance_count = mini(snow_cap, base_n * (2 if wave else 1)) if base_n > 0 else 0
	if env:
		env.fog_density = 0.0012 + cold * 0.0025 + (0.003 if wave else 0.0)
	# Generador
	var g: Dictionary = sim.st["gen"]
	var on := int(g["on"]) == 1
	var lvl := float(g["level"]) + (1.0 if int(g["over"]) == 1 else 0.0)
	var gm := gen_glow.material_override as ShaderMaterial
	gm.set_shader_parameter("intensity", (0.35 + 0.18 * lvl) if on else 0.05)
	gen_glow.scale = Vector3.ONE * (14.0 + lvl * 4.0)
	gen_light.light_energy = (0.8 + 0.5 * lvl) if on else 0.0
	if citizens:
		citizens.tick(delta, h)

func _update_daylight(h: float) -> void:
	# Sol: sale ~7 h, se pone ~18 h. Noche azulada.
	var day_t := clampf((h - 6.5) / 12.0, 0.0, 1.0)
	var is_day := h >= 6.5 and h <= 18.5
	var elev := sin(day_t * PI)
	var night := 1.0 - clampf(elev * 2.5, 0.0, 1.0)
	if not is_day:
		night = 1.0
	sun.rotation_degrees = Vector3(-10.0 - 55.0 * elev, 30.0 + day_t * 120.0, 0.0)
	sun.light_energy = lerpf(0.12, 1.05, 1.0 - night)
	sun.light_color = Color(0.55, 0.62, 0.9).lerp(Color(1.0, 0.95, 0.88), 1.0 - night)
	env.ambient_light_energy = lerpf(0.28, 0.6, 1.0 - night)
	env.ambient_light_color = Color(0.32, 0.4, 0.62).lerp(Color(0.62, 0.68, 0.78), 1.0 - night)
	env.fog_light_color = Color(0.2, 0.25, 0.38).lerp(Color(0.74, 0.8, 0.88), 1.0 - night)
	if env.background_mode == Environment.BG_COLOR:
		env.background_color = Color(0.1, 0.12, 0.2).lerp(Color(0.62, 0.68, 0.76), 1.0 - night)
	mat_building.set_shader_parameter("night", night)
	mat_static.set_shader_parameter("night", night)
	var snow_amt := clampf(0.55 + (-sim.outdoor() - 20.0) / 80.0, 0.4, 0.95)
	mat_building.set_shader_parameter("snow_amount", snow_amt)
	mat_static.set_shader_parameter("snow_amount", snow_amt * 0.5)
