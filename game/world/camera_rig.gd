class_name CameraRig
extends Node3D
## Cámara aérea orbital. Mouse/teclado y táctil:
## arrastrar = mover, rueda/pellizco = zoom, botón derecho/dos dedos = rotar.
## Emite tap (seleccionar), long_press (info) y hover (posición del puntero).

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
const LIMIT := 95.0

var _touches := {}
var _press_pos := Vector2.ZERO
var _press_time := 0
var _moved := false
var _long_sent := false
var _pressing := false
var _rot_drag := false
var _pinch_d := 0.0
var _pinch_a := 0.0
var input_enabled := true
var drag_pan_enabled := true # se desactiva mientras se coloca un edificio con mouse

func _ready() -> void:
	cam = Camera3D.new()
	cam.fov = 50.0
	cam.near = 0.5
	cam.far = 900.0
	add_child(cam)
	cam.current = true
	_apply()

func focus_on(p: Vector3) -> void:
	_t_target = Vector3(p.x, 0, p.z)

func _process(delta: float) -> void:
	# Teclado
	var mv := Vector2.ZERO
	if input_enabled:
		if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
			mv.x -= 1
		if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
			mv.x += 1
		if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W):
			mv.y -= 1
		if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S):
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
	var off := Vector3(cos(pitch) * sin(yaw), sin(pitch), cos(pitch) * cos(yaw)) * dist
	cam.global_position = target + off
	cam.look_at(target, Vector3.UP)

func _pan(v: Vector2) -> void:
	var right := Vector3(cos(_t_yaw), 0, -sin(_t_yaw))
	var fwd := Vector3(sin(_t_yaw), 0, cos(_t_yaw))
	_t_target += right * v.x + fwd * v.y
	var flat := Vector2(_t_target.x, _t_target.z)
	if flat.length() > LIMIT:
		flat = flat.normalized() * LIMIT
		_t_target = Vector3(flat.x, 0, flat.y)

func _zoom(f: float) -> void:
	_t_dist = clampf(_t_dist * f, DIST_MIN, DIST_MAX)

func _unhandled_input(ev: InputEvent) -> void:
	if not input_enabled:
		return
	# ---------------- táctil
	if ev is InputEventScreenTouch:
		if ev.pressed:
			_touches[ev.index] = ev.position
			if _touches.size() == 1:
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
	_t_yaw -= wrapf(a - _pinch_a, -PI, PI)
	_pinch_d = d
	_pinch_a = a
