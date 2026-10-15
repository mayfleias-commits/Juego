extends Node
## Ajustes del jugador y presets gráficos (Muy bajo, Bajo, Medio, Alto).
## Se guardan en user://ajustes.cfg. El primer arranque elige el preset solo.
## En el celular los límites son fijos (no negociables): solo Muy bajo y Bajo, sin sombras,
## escala de render de 60 a 80 % y como mucho 30 FPS. `_clamp_mobile()` los impone siempre,
## también sobre ajustes viejos guardados fuera de rango.

signal changed

const PATH := "user://ajustes.cfg"
## Con --ui-movil (capturas y pruebas en PC) se simula el celular con otro archivo de
## ajustes, así no se pisan los de la PC.
const PATH_SIMULATED := "user://ajustes_movil.cfg"
## Versión del formato de ajustes.cfg. 2: en PC el tope por defecto es 60 FPS en todos los presets.
const CFG_VERSION := 2
const PRESETS := ["muy_bajo", "bajo", "medio", "alto"]
const MOBILE_PRESETS := ["muy_bajo", "bajo"]
const PRESET_NAMES := {"muy_bajo": "Muy bajo", "bajo": "Bajo", "medio": "Medio", "alto": "Alto"}
## Límite de FPS en el celular (batería y temperatura) y opciones que se ofrecen.
const MOBILE_FPS := 30
const MOBILE_FPS_OPTIONS := [20, 30]
const PC_FPS_OPTIONS := [30, 45, 60, 0]
const MOBILE_SCALE_MIN := 0.6
const MOBILE_SCALE_MAX := 0.8

## Parámetros por preset. Celular: muy_bajo/bajo. PC mínima: bajo. PC normal: medio/alto.
## "fps" es el tope por defecto en PC; en el celular siempre es MOBILE_FPS.
const P := {
	"muy_bajo": {"scale": 0.6, "fps": 60, "shadows": false, "msaa": 0, "snow": 150, "citizens": 30, "lights": 1,
		"smoke": 24, "fog": true, "detail": 0, "frost_fx": 0, "terrain_res": 48, "sky": false},
	"bajo": {"scale": 0.8, "fps": 60, "shadows": false, "msaa": 0, "snow": 200, "citizens": 60, "lights": 2,
		"smoke": 48, "fog": true, "detail": 1, "frost_fx": 1, "terrain_res": 64, "sky": false},
	"medio": {"scale": 1.0, "fps": 60, "shadows": true, "msaa": 0, "snow": 1200, "citizens": 150, "lights": 4,
		"smoke": 160, "fog": true, "detail": 2, "frost_fx": 2, "terrain_res": 96, "sky": true},
	"alto": {"scale": 1.0, "fps": 60, "shadows": true, "msaa": 2, "snow": 2500, "citizens": 250, "lights": 8,
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
## true con --ui-movil: se aplican los límites del celular en la PC (capturas y pruebas).
var simulate_mobile := false

func _ready() -> void:
	simulate_mobile = "--ui-movil" in OS.get_cmdline_user_args()
	load_cfg()

func is_mobile() -> bool:
	return simulate_mobile or OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("web_android")

func p(key: String):
	return P[preset][key]

## Presets que se ofrecen en esta plataforma.
func available_presets() -> Array:
	return MOBILE_PRESETS if is_mobile() else PRESETS

## Opciones de límite de FPS (0 = sin límite, solo en PC).
func fps_options() -> Array:
	return MOBILE_FPS_OPTIONS if is_mobile() else PC_FPS_OPTIONS

## Rango del control de escala de render, en porcentaje.
func scale_range() -> Vector2i:
	return Vector2i(60, 80) if is_mobile() else Vector2i(50, 100)

## Tope de FPS que se aplica de verdad (en el celular nunca pasa de 30 ni queda sin límite).
func effective_fps() -> int:
	if is_mobile():
		return MOBILE_FPS if fps_limit <= 0 else clampi(fps_limit, 1, MOBILE_FPS)
	return maxi(fps_limit, 0)

func _cfg_path() -> String:
	return PATH_SIMULATED if simulate_mobile else PATH

func load_cfg() -> void:
	var c := ConfigFile.new()
	if c.load(_cfg_path()) != OK:
		first_run = true
		preset = "bajo" if is_mobile() else "medio"
		_from_preset()
		return
	first_run = false
	preset = str(c.get_value("graficos", "preset", preset))
	if not P.has(preset):
		preset = "bajo" if is_mobile() else "medio"
	render_scale = float(c.get_value("graficos", "escala", P[preset]["scale"]))
	fps_limit = int(c.get_value("graficos", "fps", P[preset]["fps"]))
	shadows = bool(c.get_value("graficos", "sombras", P[preset]["shadows"]))
	effects = bool(c.get_value("graficos", "efectos", true))
	show_fps = bool(c.get_value("graficos", "contador", false))
	vol_master = int(c.get_value("audio", "general", 80))
	vol_music = int(c.get_value("audio", "musica", 60))
	vol_sfx = int(c.get_value("audio", "efectos", 80))
	ui_scale = clampi(int(c.get_value("interfaz", "escala", 100)), ui_scale_min(), 150)
	tutorial = bool(c.get_value("interfaz", "tutorial", true))
	# Ajustes de la versión 1: Muy bajo y Bajo traían 30 FPS fijos también en PC.
	if int(c.get_value("general", "version", 1)) < 2 and not is_mobile() \
			and preset in MOBILE_PRESETS and fps_limit == 30:
		fps_limit = int(P[preset]["fps"])
	_clamp_mobile()

func save_cfg() -> void:
	_clamp_mobile()
	var c := ConfigFile.new()
	c.set_value("general", "version", CFG_VERSION)
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
	c.save(_cfg_path())
	first_run = false

func _from_preset() -> void:
	render_scale = P[preset]["scale"]
	fps_limit = MOBILE_FPS if is_mobile() else int(P[preset]["fps"])
	shadows = P[preset]["shadows"]
	effects = true
	_clamp_mobile()

## Celular: recorta cualquier ajuste (guardado, de un preset o de la interfaz) al presupuesto fijo.
func _clamp_mobile() -> void:
	if not is_mobile():
		return
	if preset not in MOBILE_PRESETS:
		preset = "bajo"
	render_scale = clampf(render_scale, MOBILE_SCALE_MIN, MOBILE_SCALE_MAX)
	shadows = false
	fps_limit = 20 if (fps_limit > 0 and fps_limit <= 20) else MOBILE_FPS

func set_preset(name: String) -> void:
	if name not in available_presets():
		return
	preset = name
	_from_preset()
	apply()
	save_cfg()

## Aplica los ajustes al motor (FPS, escala de render, MSAA).
func apply() -> void:
	_clamp_mobile()
	Engine.max_fps = effective_fps()
	var vp := get_viewport()
	if vp:
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		vp.scaling_3d_scale = clampf(render_scale, 0.5, 1.0)
		var msaa: int = P[preset]["msaa"]
		vp.msaa_3d = Viewport.MSAA_2X if msaa == 2 else Viewport.MSAA_DISABLED
	_apply_audio()
	var w := get_window()
	if w:
		w.content_scale_factor = clampf(ui_scale / 100.0, ui_scale_min() / 100.0, 1.5)
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
	if "llvmpipe" in gpu or "swiftshader" in gpu or (ram_mb > 0 and ram_mb < 6000):
		return "bajo"
	# Gráficos integrados de Intel anteriores a Iris Xe (HD/UHD 6xx, Iris Plus): Bajo.
	# Iris Xe y Arc arrancan en Medio; el mini benchmark sube o baja un escalón.
	if "intel" in gpu and not ("arc" in gpu or "xe graphics" in gpu):
		return "bajo"
	return "medio"

## Tamaño mínimo de la interfaz (%): en el celular no baja de 100 para que los botones midan al menos 48 dp.
func ui_scale_min() -> int:
	return 100 if is_mobile() else 75
