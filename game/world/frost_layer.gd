class_name FrostLayer
extends CanvasLayer
## Viñeta de escarcha en pantalla: crece con el frío exterior.
## Se vuelve a aplicar sola cuando cambian los ajustes (efectos o preset), aunque el juego
## esté en pausa y no corra ningún paso de la simulación.
var rect: ColorRect
var mat: ShaderMaterial
var _temp := 0
var _wave := false
var _has_cold := false

func _ready() -> void:
	layer = 1
	rect = ColorRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mat = ShaderMaterial.new()
	mat.shader = load("res://game/shaders/frost.gdshader")
	rect.material = mat
	add_child(rect)
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.visible = false
	Settings.changed.connect(_on_settings_changed)
	_on_settings_changed()

func set_cold(temp_c: int, wave: bool) -> void:
	_temp = temp_c
	_wave = wave
	_has_cold = true
	if rect == null:
		return
	var q: int = Settings.p("frost_fx")
	if not Settings.effects:
		rect.visible = false
		return
	var k := clampf((-float(temp_c) - 25.0) / 60.0, 0.0, 1.0)
	if wave:
		k = minf(1.0, k + 0.15)
	rect.visible = k > 0.02
	mat.set_shader_parameter("intensity", k)
	mat.set_shader_parameter("quality", q)

func _on_settings_changed() -> void:
	if _has_cold:
		set_cold(_temp, _wave)
