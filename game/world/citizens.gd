class_name Citizens
extends Node3D
## Ciudadanos decorativos: caminan entre casas, trabajos y el generador.
## La economía NO depende de ellos. MultiMesh + LOD (impostor de un quad a distancia).

var world: World
var mmi_near: MultiMeshInstance3D
var mmi_far: MultiMeshInstance3D
var max_visible := 60
const CAP := 250

var pos: Array = []
var tgt: Array = []
var spd: Array = []
var homes: Array = []
var works: Array = []
var _acc := 10.0
var _rs := 12345
var _far := false

func setup(w: World) -> void:
	world = w
	mmi_near = _mk("ciudadano")
	mmi_far = _mk("ciudadano_lejos")
	mmi_far.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	max_visible = Settings.p("citizens")

func _mk(model: String) -> MultiMeshInstance3D:
	var mmi := MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = Models.get_mesh(model)
	mm.instance_count = CAP
	mm.visible_instance_count = 0
	var coats := [Color(1, 1, 1), Color(0.75, 0.85, 1.1), Color(1.2, 0.9, 0.8), Color(0.8, 1.0, 0.85), Color(1.1, 1.05, 0.7)]
	for i in CAP:
		mm.set_instance_color(i, coats[i % coats.size()])
		mm.set_instance_custom_data(i, Color(999.0, 0, 0, 0))
	mmi.multimesh = mm
	mmi.material_override = world.mat_building
	mmi.extra_cull_margin = 200.0
	add_child(mmi)
	return mmi

func _rnd() -> float:
	_rs = SimRng.step(_rs)
	return float(_rs % 10000) / 10000.0

func _refresh_places() -> void:
	homes.clear()
	works.clear()
	for b in world.sim.st["buildings"]:
		if int(b["state"]) != 1:
			continue
		var p := world.rect_center(b["x"], b["y"], b["w"], b["h"])
		var d: Dictionary = world.sim.bdef(b["type"])
		if int(d.get("housing", 0)) > 0:
			homes.append(p)
		elif int(b["o"]) + int(b["i"]) + int(b["n"]) > 0:
			works.append(p)
	works.append(Vector3(0, 0, 9))

func _pick(h: float) -> Vector3:
	var day := h >= 7.0 and h < 19.0
	var src: Array = works if (day and _rnd() < 0.75) else homes
	if src.is_empty():
		src = works if not works.is_empty() else [Vector3.ZERO]
	var p: Vector3 = src[int(_rnd() * src.size()) % src.size()]
	return p + Vector3((_rnd() - 0.5) * 6.0, 0, (_rnd() - 0.5) * 6.0)

func tick(delta: float, h: float) -> void:
	_acc += delta
	if _acc > 2.0:
		_acc = 0.0
		_refresh_places()
	var sim := world.sim
	var want := mini(max_visible, sim.present_pop() / 2)
	if h < 6.0 or h >= 21.0:
		want = want / 6 # de noche casi todos en casa
	want = mini(want, CAP)
	while pos.size() < want:
		var start := _pick(h)
		pos.append(start)
		tgt.append(_pick(h))
		spd.append(1.1 + _rnd() * 0.6)
	if pos.size() > want:
		pos.resize(want); tgt.resize(want); spd.resize(want)
	var game_speed := float(Session.speed) if (Session.sim == sim and not Session.paused) else 0.0
	var mult := 3.0 * game_speed
	var rig := world.camera_rig
	var far := rig != null and rig.dist > 95.0
	if far != _far:
		_far = far
		mmi_near.multimesh.visible_instance_count = 0
		mmi_far.multimesh.visible_instance_count = 0
	var mm := (mmi_far if far else mmi_near).multimesh
	for i in pos.size():
		var p: Vector3 = pos[i]
		var t: Vector3 = tgt[i]
		var dv := t - p
		dv.y = 0
		var dist := dv.length()
		var step: float = spd[i] * delta * mult
		var face := Vector3.FORWARD
		if dist < 0.5:
			tgt[i] = _pick(h)
		elif step > 0.0:
			face = dv / dist
			p += face * minf(step, dist)
			pos[i] = p
		var basis := Basis.looking_at(face, Vector3.UP) if face.length() > 0.1 else Basis()
		mm.set_instance_transform(i, Transform3D(basis, p))
	mm.visible_instance_count = pos.size()
