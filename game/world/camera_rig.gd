class_name CameraRig
extends Node3D
## Cámara aérea orbital. Mouse/teclado y táctil:
## arrastrar = mover, rueda/pellizco = zoom, botón derecho/dos dedos = rotar.
## Emite tap (seleccionar), long_press (info) y hover (posición del puntero).
## El táctil se maneja solo con ScreenTouch/ScreenDrag: los clics de mouse que Godot
## emula a partir de cada toque (emulate_mouse_from_touch) se ignoran.

signal tapped(screen_pos: Vector2)
signal long_pressed(screen_pos: Vector2)
signal hovered(screen_pos: Vector2)
signal cancelled

var cam: Camera3D
var target := Vector3(0, 0, 6)
var yaw := 0.7
var pitch := 0.9
var dist := 78.0
var _t_target := Vector3(0, 0, 6)
var _t_yaw := 0.7
var _t_pitch := 0.9
var _t_dist := 78.0
const DIST_MIN := 16.0
const DIST_MAX := 175.0
const PITCH_MIN := 0.35
const PITCH_MAX := 1.38
const LIMIT := 66.0 # radio de la cuenca plana (22 casillas de 3 m); afuera sube la ladera
const CLEAR_CAM := 4.0 # altura mínima de la cámara sobre el terreno (m)
const CLEAR_RAY := 2.0 # margen del rayo cámara-objetivo sobre la ladera (m)
const CAM_R_MAX := 138.0 # distancia máxima de la cámara al centro (la malla del terreno llega a 150 m)
const PINCH_ROT_START := 0.12 # giro (rad) a partir del cual dos dedos rotan además de hacer zoom

var _touches := {}
var _press_pos := Vector2.ZERO
var _press_time := 0
var _moved := false
var _long_sent := false
var _pressing := false
var _rot_drag := false
var _pinch_d := 0.0
var _pinch_a := 0.0
var _pinch_rot_acc := 0.0
var _pinch_rotating := false
var _height_fn: Callable # altura del terreno en (x, z), la da el World padre
var _limit := LIMIT
var input_enabled := true
var drag_pan_enabled := true # se desactiva mientras se coloca un edificio con mouse

func _ready() -> void:
	cam = Camera3D.new()
	cam.fov = 50.0
	cam.near = 0.5
	cam.far = 900.0
	add_child(cam)
	cam.current = true
	var w := get_parent()
	if w:
		if w.has_method("terrain_height"):
			_height_fn = Callable(w, "terrain_height")
		elif w.has_method("_terrain_height"):
			_height_fn = Callable(w, "_terrain_height")
		var s = w.get("sim")
		if s != null and "mradius" in s:
			_limit = float(s.mradius) * Models.TILE
	_apply()

func focus_on(p: Vector3) -> void:
	var flat := Vector2(p.x, p.z)
	# Un poco más allá del límite del pan se permite (enfocar algo del borde con la hoja abierta).
	if flat.length() > _limit * 1.25:
		flat = flat.normalized() * _limit * 1.25
	_t_target = Vector3(flat.x, 0, flat.y)

## Enfoca p de modo que quede a la altura `frac` de la pantalla (0 = arriba, 0,5 = centro),
## con el zoom y la inclinación actuales. Sirve para que una hoja inferior no lo tape.
func focus_on_at(p: Vector3, frac: float) -> void:
	if absf(frac - 0.5) < 0.01:
		focus_on(p)
		return
	var half := deg_to_rad((cam.fov if cam else 50.0) * 0.5)
	var a := atan((0.5 - frac) * 2.0 * tan(half)) # ángulo sobre el centro de la vista
	var pt := clampf(_t_pitch, PITCH_MIN, PITCH_MAX)
	var dep := clampf(pt - a, 0.1, 1.5) # depresión con la que hay que ver p
	var x := _t_dist * sin(pt) / tan(dep) - _t_dist * cos(pt)
	var fwd := Vector3(sin(_t_yaw), 0, cos(_t_yaw))
	focus_on(p + fwd * x)

func _process(delta: float) -> void:
	# Teclado
	var mv := Vector2.ZERO
	if input_enabled:
		# Las flechas son también las acciones ui_* de la interfaz: si un control tiene el
		# foco (p. ej. un deslizador de Ajustes) las usa él y la cámara no se mueve.
		var arrows := get_viewport().gui_get_focus_owner() == null
		if (arrows and Input.is_action_pressed("ui_left")) or Input.is_key_pressed(KEY_A):
			mv.x -= 1
		if (arrows and Input.is_action_pressed("ui_right")) or Input.is_key_pressed(KEY_D):
			mv.x += 1
		if (arrows and Input.is_action_pressed("ui_up")) or Input.is_key_pressed(KEY_W):
			mv.y -= 1
		if (arrows and Input.is_action_pressed("ui_down")) or Input.is_key_pressed(KEY_S):
			mv.y += 1
		if Input.is_key_pressed(KEY_Q):
			_t_yaw -= delta * 1.6
		if Input.is_key_pressed(KEY_E):
			_t_yaw += delta * 1.6
		if Input.is_key_pressed(KEY_R) or Input.is_key_pressed(KEY_EQUAL):
			_t_dist = maxf(DIST_MIN, _t_dist - delta * 60.0)
		if Input.is_key_pressed(KEY_F) or Input.is_key_pressed(KEY_MINUS):
			_t_dist = minf(DIST_MAX, _t_dist + delta * 60.0)
	if mv != Vector2.ZERO:
		_pan(mv.normalized() * delta * (20.0 + _t_dist * 0.8))
	# Pulsación larga
	if _pressing and not _moved and not _long_sent and Time.get_ticks_msec() - _press_time > 550:
		_long_sent = true
		long_pressed.emit(_press_pos)
	var k := clampf(delta * 10.0, 0.0, 1.0)
	target = target.lerp(_t_target, k)
	yaw = lerp_angle(yaw, _t_yaw, k)
	pitch = lerpf(pitch, _t_pitch, k)
	dist = lerpf(dist, _t_dist, k)
	_apply()

func _apply() -> void:
	if cam == null:
		return
	var off := Vector3(cos(pitch) * sin(yaw), sin(pitch), cos(pitch) * cos(yaw)) * _fit_dist()
	var p := target + off
	p.y = maxf(p.y, _min_cam_y(target, p))
	cam.global_position = p
	cam.look_at(target, Vector3.UP)

## Distancia efectiva: la cámara no sale del terreno modelado (la malla llega a 150 m del
## centro). Con el zoom al máximo y poca inclinación se acerca sobre la misma línea de vista.
func _fit_dist() -> float:
	var hd := Vector2(sin(yaw), cos(yaw))
	var tf := Vector2(target.x, target.z)
	var h := cos(pitch) * dist
	var b := tf.dot(hd)
	var disc := b * b - tf.length_squared() + CAM_R_MAX * CAM_R_MAX
	if disc <= 0.0 or h <= 0.001:
		return dist
	var h_max := -b + sqrt(disc)
	if h <= h_max:
		return dist
	return dist * maxf(h_max, 1.0) / h

## Altura mínima de la cámara para no quedar dentro de la ladera del cráter y para que
## el borde no tape el objetivo: se muestrea el terreno a lo largo del rayo.
func _min_cam_y(t: Vector3, p: Vector3) -> float:
	if not _height_fn.is_valid():
		return -INF
	var need := float(_height_fn.call(p.x, p.z)) + CLEAR_CAM
	for i in range(1, 8):
		var f := i / 8.0
		var h := float(_height_fn.call(lerpf(t.x, p.x, f), lerpf(t.z, p.z, f)))
		# Solo cuenta la ladera (en la cuenca plana el terreno está a la altura del objetivo).
		if h > t.y + 0.5:
			need = maxf(need, t.y + (h + CLEAR_RAY - t.y) / f)
	return need

func _pan(v: Vector2) -> void:
	var right := Vector3(cos(_t_yaw), 0, -sin(_t_yaw))
	var fwd := Vector3(sin(_t_yaw), 0, cos(_t_yaw))
	_t_target += right * v.x + fwd * v.y
	var flat := Vector2(_t_target.x, _t_target.z)
	if flat.length() > _limit:
		flat = flat.normalized() * _limit
		_t_target = Vector3(flat.x, 0, flat.y)

func _zoom(f: float) -> void:
	_t_dist = clampf(_t_dist * f, DIST_MIN, DIST_MAX)

func _unhandled_input(ev: InputEvent) -> void:
	if not input_enabled:
		return
	# Mouse emulado desde un toque: el toque real llega como ScreenTouch/ScreenDrag.
	# Procesarlo también duplicaba el arrastre y hacía derivar el pellizco.
	if UiKit.is_emulated(ev):
		return
	# ---------------- táctil
	if ev is InputEventScreenTouch:
		if ev.pressed:
			_touches[ev.index] = ev.position
			if _touches.size() == 1:
				# Pantalla táctil en PC: el fantasma de construcción sigue al dedo (antes lo
				# movía el mouse emulado, que ahora se ignora).
				hovered.emit(ev.position)
				_begin_press(ev.position)
			else:
				_moved = true
				_pinch_reset()
		else:
			_touches.erase(ev.index)
			if _touches.size() == 0:
				_end_press(ev.position)
			else:
				_pinch_reset()
		get_viewport().set_input_as_handled()
		return
	if ev is InputEventScreenDrag:
		_touches[ev.index] = ev.position
		if _touches.size() == 1:
			hovered.emit(ev.position)
			if (ev.position - _press_pos).length() > 14.0:
				_moved = true
			if _moved:
				_drag_pan(ev.relative)
		elif _touches.size() >= 2:
			_pinch_update()
		get_viewport().set_input_as_handled()
		return
	# ---------------- mouse
	if ev is InputEventMouseButton:
		match ev.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if ev.pressed:
					_zoom(0.9)
			MOUSE_BUTTON_WHEEL_DOWN:
				if ev.pressed:
					_zoom(1.1)
			MOUSE_BUTTON_LEFT:
				if ev.pressed:
					# Clic en el mundo: la interfaz suelta el foco (las flechas vuelven a la cámara).
					get_viewport().gui_release_focus()
					_begin_press(ev.position)
				else:
					_end_press(ev.position)
			MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE:
				if ev.pressed:
					_rot_drag = true
					_press_pos = ev.position
					_moved = false
				else:
					_rot_drag = false
					if not _moved and ev.button_index == MOUSE_BUTTON_RIGHT:
						cancelled.emit()
	if ev is InputEventMouseMotion:
		hovered.emit(ev.position)
		if _rot_drag:
			if (ev.position - _press_pos).length() > 4.0:
				_moved = true
			_t_yaw -= ev.relative.x * 0.006
			_t_pitch = clampf(_t_pitch + ev.relative.y * 0.004, PITCH_MIN, PITCH_MAX)
		elif _pressing and drag_pan_enabled:
			if (ev.position - _press_pos).length() > 6.0:
				_moved = true
			if _moved:
				_drag_pan(ev.relative)
	if ev is InputEventMagnifyGesture:
		_zoom(1.0 / ev.factor)
	if ev is InputEventPanGesture:
		_pan(ev.delta * 2.0)

func _begin_press(p: Vector2) -> void:
	_pressing = true
	_press_pos = p
	_press_time = Time.get_ticks_msec()
	_moved = false
	_long_sent = false

func _end_press(p: Vector2) -> void:
	if _pressing and not _moved and not _long_sent:
		tapped.emit(p)
	_pressing = false

func _drag_pan(rel: Vector2) -> void:
	var k := _t_dist / 520.0
	_pan(Vector2(-rel.x, -rel.y) * k)

func _pinch_reset() -> void:
	var ps := _touches.values()
	_pinch_rot_acc = 0.0
	_pinch_rotating = false
	if ps.size() >= 2:
		_pinch_d = (ps[0] as Vector2).distance_to(ps[1])
		_pinch_a = ((ps[1] as Vector2) - (ps[0] as Vector2)).angle()

func _pinch_update() -> void:
	var ps := _touches.values()
	if ps.size() < 2:
		return
	var d := (ps[0] as Vector2).distance_to(ps[1])
	var a := ((ps[1] as Vector2) - (ps[0] as Vector2)).angle()
	if _pinch_d > 1.0 and d > 1.0:
		_zoom(_pinch_d / d)
	# El pellizco casi nunca es perfectamente recto: la rotación arranca recién cuando
	# el giro acumulado supera un umbral, así el zoom no hace girar la vista.
	var da := wrapf(a - _pinch_a, -PI, PI)
	if _pinch_rotating:
		_t_yaw -= da
	else:
		_pinch_rot_acc += da
		if absf(_pinch_rot_acc) > PINCH_ROT_START:
			_pinch_rotating = true
			_t_yaw -= _pinch_rot_acc
	_pinch_d = d
	_pinch_a = a
