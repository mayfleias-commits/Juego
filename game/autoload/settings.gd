extends Node
## Ajustes del jugador y presets gráficos (Muy bajo, Bajo, Medio, Alto).
## Se guardan en user://ajustes.cfg. El primer arranque elige el preset solo.

signal changed

const PATH := "user://ajustes.cfg"
const PRESETS := ["muy_bajo", "bajo", "medio", "alto"]
const PRESET_NAMES := {"muy_bajo": "Muy bajo", "bajo": "Bajo", "medio": "Medio", "alto": "Alto"}

## Parámetros por preset. Celular: muy_bajo/bajo. PC mínima: bajo. PC normal: medio/alto.
const P := {
	"muy_bajo": {"scale": 0.6, "fps": 30, "shadows": false, "msaa": 0, "snow": 150, "citizens": 30, "lights": 1,
		"smoke": 24, "fog": true, "detail": 0, "frost_fx": 0, "terrain_res": 48, "sky": false},
	"bajo": {"scale": 0.8, "fps": 30, "shadows": false, "msaa": 0, "snow": 300, "citizens": 60, "lights": 2,
		"smoke": 48, "fog": true, "detail": 1, "frost_fx": 1, "terrain_res": 64, "sky": false},
	"medio": {"scale": 1.0, "fps": 60, "shadows": true, "msaa": 0, "snow": 1200, "citizens": 150, "lights": 4,
		"smoke": 160, "fog": true, "detail": 2, "frost_fx": 2, "terrain_res": 96, "sky": true},
	"alto": {"scale": 1.0, "fps": 60, "shadows": true, "msaa": 2, "snow": 3000, "citizens": 250, "lights": 8,
		"smoke": 320, "fog": true, "detail": 3, "frost_fx": 2, "terrain_res": 128, "sky": true},
}

var preset := "medio"
var render_scale := 1.0
var fps_limit := 60
var shadows := true
var effects := true # partículas, humo, viñeta de escarcha
var show_fps := false
var vol_master := 80
var vol_music := 60
var vol_sfx := 80
var ui_scale := 100 # porcentaje
var tutorial := true
var first_run := true
var autosave_hours := 24

func _ready() -> void:
	load_cfg()

func is_mobile() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("web_android")

func p(key: String):
	return P[preset][key]

func load_cfg() -> void:
	var c := ConfigFile.new()
	if c.load(PATH) != OK:
		first_run = true
		preset = "bajo" if is_mobile() else "medio"
		_from_preset()
		return
	first_run = false
	preset = c.get_value("graficos", "preset", preset)
	if not P.has(preset):
		preset = "medio"
	render_scale = c.get_value("graficos", "escala", P[preset]["scale"])
	fps_limit = c.get_value("graficos", "fps", P[preset]["fps"])
	shadows = c.get_value("graficos", "sombras", P[preset]["shadows"])
	effects = c.get_value("graficos", "efectos", true)
	show_fps = c.get_value("graficos", "contador", false)
	vol_master = c.get_value("audio", "general", 80)
	vol_music = c.get_value("audio", "musica", 60)
	vol_sfx = c.get_value("audio", "efectos", 80)
	ui_scale = c.get_value("interfaz", "escala", 100)
	tutorial = c.get_value("interfaz", "tutorial", true)

func save_cfg() -> void:
	var c := ConfigFile.new()
	c.set_value("graficos", "preset", preset)
	c.set_value("graficos", "escala", render_scale)
	c.set_value("graficos", "fps", fps_limit)
	c.set_value("graficos", "sombras", shadows)
	c.set_value("graficos", "efectos", effects)
	c.set_value("graficos", "contador", show_fps)
	c.set_value("audio", "general", vol_master)
	c.set_value("audio", "musica", vol_music)
	c.set_value("audio", "efectos", vol_sfx)
	c.set_value("interfaz", "escala", ui_scale)
	c.set_value("interfaz", "tutorial", tutorial)
	c.save(PATH)
	first_run = false

func _from_preset() -> void:
	render_scale = P[preset]["scale"]
	fps_limit = P[preset]["fps"]
	shadows = P[preset]["shadows"]
	effects = true

func set_preset(name: String) -> void:
	if not P.has(name):
		return
	preset = name
	_from_preset()
	apply()
	save_cfg()

## Aplica los ajustes al motor (FPS, escala de render, MSAA).
func apply() -> void:
	Engine.max_fps = fps_limit
	var vp := get_viewport()
	if vp:
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		vp.scaling_3d_scale = clampf(render_scale, 0.5, 1.0)
		var msaa: int = P[preset]["msaa"]
		vp.msaa_3d = Viewport.MSAA_2X if msaa == 2 else Viewport.MSAA_DISABLED
	_apply_audio()
	changed.emit()

func _apply_audio() -> void:
	var m := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(m, linear_to_db(maxf(0.0001, vol_master / 100.0)))
	for pair in [["Musica", vol_music], ["Efectos", vol_sfx]]:
		var i := AudioServer.get_bus_index(pair[0])
		if i >= 0:
			AudioServer.set_bus_volume_db(i, linear_to_db(maxf(0.0001, pair[1] / 100.0)))

## Elección automática del primer arranque (antes del mini benchmark).
func auto_detect() -> String:
	var mem: Dictionary = OS.get_memory_info()
	var ram_mb: int = int(mem.get("physical", 0)) / (1024 * 1024)
	var gpu := RenderingServer.get_video_adapter_name().to_lower()
	if is_mobile():
		if ram_mb > 0 and ram_mb < 3000:
			return "muy_bajo"
		return "bajo"
	if "intel" in gpu or "llvmpipe" in gpu or (ram_mb > 0 and ram_mb < 6000):
		return "bajo"
	return "medio"
