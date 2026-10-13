class_name FrostLayer
extends CanvasLayer
## Viñeta de escarcha en pantalla: crece con el frío exterior.
var rect: ColorRect
var mat: ShaderMaterial

func _ready() -> void:
	layer = 1
	rect = ColorRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mat = ShaderMaterial.new()
	mat.shader = load("res://game/shaders/frost.gdshader")
	rect.material = mat
	add_child(rect)
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func set_cold(temp_c: int, wave: bool) -> void:
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
