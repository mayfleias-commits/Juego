extends Node
## Partida en curso: simulación + reloj + guardado. La interfaz solo lee el estado
## y manda órdenes con `Session.cmd()`, que se aplican entre pasos de simulación.

signal stepped(notes: Array)
signal day_ended(report: Dictionary)
signal game_over(status: String, reason: String)
signal speed_changed(speed: int)
signal loaded
signal commanded

const SAVE_DIR := "user://partidas"
## Ranuras de guardado. "auto" es el automático de fin de día y rota en auto_1..auto_3;
## "salida" es el de cierre, segundo plano o salida al menú y no rota (así no borra
## el historial diario); "manual" es el del jugador.
const AUTO_COPIES := 3
const SLOT_NAMES := {"manual": "Guardado manual", "auto": "Automático (último día)", "salida": "Guardado al salir"}

## Versión del juego (la de project.godot). No confundir con Simulation.SAVE_VERSION,
## que es la del formato de guardado.
var GAME_VERSION: String = str(ProjectSettings.get_setting("application/config/version", "0.0.0"))

var sim: Simulation
var clock: SimClock
var speed := 1
var paused := true
var autosave_enabled := true
## Motivo legible del último guardado o carga que falló.
var last_error := ""
var _last_day := 0
var _ended := false
## Resto fraccionario de milisegundos entre cuadros: sin esto la velocidad del juego
## dependería de los FPS (a 60 FPS se perdían 0,67 ms por cuadro).
var _ms_acc := 0.0
## Tick del último guardado de "salida", para no guardar dos veces lo mismo
## (en Android llegan FOCUS_OUT y PAUSED juntos al pasar a segundo plano).
## Cada orden aceptada lo vuelve a -1, porque cambia la partida sin avanzar el tick.
var _exit_saved_tick := -1
## Ranuras cuya cabecera parecía buena pero que no se pudieron cargar: se listan como
## dañadas (y "Continuar" las saltea) hasta que se vuelva a guardar en ellas.
var _broken := {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	get_tree().auto_accept_quit = false
	_clean_temp_files()

func has_game() -> bool:
	return sim != null

func new_game(seed: int = -1) -> void:
	if seed < 0:
		seed = int(Time.get_unix_time_from_system()) % 1000000
	sim = Simulation.new()
	sim.new_game(seed)
	_setup()

func _setup() -> void:
	clock = SimClock.new()
	clock.sim = sim
	clock.max_steps_per_frame = 3
	_ms_acc = 0.0
	_exit_saved_tick = -1
	_last_day = sim.day()
	_ended = sim.st["status"] != "playing"
	set_speed(1)
	set_paused(true)
	loaded.emit()

func set_speed(s: int) -> void:
	speed = clampi(s, 1, 3)
	speed_changed.emit(speed if not paused else 0)

func set_paused(p: bool) -> void:
	paused = p
	speed_changed.emit(0 if paused else speed)

func toggle_pause() -> void:
	set_paused(not paused)

func cmd(c: Dictionary) -> String:
	if sim == null:
		return "sin partida"
	var r := sim.command(c)
	if r == "":
		# Una orden cambia la partida sin avanzar el tick: el próximo guardado de salida vale.
		_exit_saved_tick = -1
		commanded.emit()
	return r

func _process(delta: float) -> void:
	if sim == null or paused or _ended:
		return
	clock.speed = speed
	_ms_acc += delta * 1000.0
	var ms := int(_ms_acc)
	_ms_acc -= ms
	var n := clock.advance_ms(ms)
	if n <= 0:
		return
	stepped.emit(sim.notes.duplicate())
	if sim.day() != _last_day:
		_last_day = sim.day()
		var reps: Array = sim.st["reports"]
		if reps.size() > 0:
			day_ended.emit(reps[reps.size() - 1])
		if autosave_enabled:
			save_game("auto", true)
	if sim.st["status"] != "playing" and not _ended:
		_ended = true
		paused = true
		game_over.emit(sim.st["status"], sim.st["end_reason"])

func hour_fraction() -> float:
	if clock == null:
		return 0.0
	return clock.hour_fraction() / 1000.0

# ---------------------------------------------------------------- guardado
func _slot_path(slot: String) -> String:
	return "%s/%s.brasa" % [SAVE_DIR, slot]

func _fail(msg: String) -> bool:
	last_error = msg
	push_warning("Guardado/carga: " + msg)
	return false

## Guarda con cabecera versionada y de forma atómica: escribe en un temporal, lo relee
## para verificarlo y recién entonces lo pone en lugar del anterior. Si algo falla, el
## guardado anterior queda intacto y devuelve false (con el motivo en `last_error`).
## `rotate` (solo el automático diario) corre auto -> auto_1 -> ... -> auto_3.
func save_game(slot: String = "manual", rotate: bool = false) -> bool:
	last_error = ""
	if sim == null:
		return _fail("No hay ninguna partida en curso.")
	var path := _slot_path(slot)
	var tmp := path + ".tmp"
	var body := sim.serialize()
	var header := {
		"magic": "BRASA", "save_version": Simulation.SAVE_VERSION, "game_version": GAME_VERSION,
		"date": Time.get_datetime_string_from_system(), "ts": Time.get_unix_time_from_system(),
		"day": sim.day(), "hour": sim.hour(),
		"pop": sim.total_pop(), "seed": sim.st["seed"], "status": sim.st["status"],
	}
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return _fail("No se pudo crear el archivo (%s)." % error_string(FileAccess.get_open_error()))
	var ok := f.store_var(header)
	ok = f.store_var(body) and ok
	ok = ok and f.get_error() == OK
	f.close()
	if not ok or not _verify(tmp, body.size()):
		DirAccess.remove_absolute(tmp)
		return _fail("No se pudo escribir la partida. ¿Queda espacio libre?")
	if rotate and slot == "auto":
		_rotate_autos()
	# rename reemplaza el destino (en Windows Godot borra el anterior antes de mover).
	var err := DirAccess.rename_absolute(tmp, path)
	if err != OK:
		DirAccess.remove_absolute(tmp)
		return _fail("No se pudo reemplazar el guardado anterior (%s)." % error_string(err))
	_broken.erase(slot)
	return true

## Relee un guardado recién escrito: cabecera válida y cuerpo completo.
func _verify(path: String, body_size: int) -> bool:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	var h = _read_var(f)
	var b = _read_var(f)
	f.close()
	return typeof(h) == TYPE_DICTIONARY and h.get("magic", "") == "BRASA" \
		and typeof(b) == TYPE_PACKED_BYTE_ARRAY and (b as PackedByteArray).size() == body_size

## get_var() que controla el largo antes de leer: un archivo dañado o cortado
## no tiene que pedir gigas de memoria ni leer de más.
func _read_var(f: FileAccess) -> Variant:
	var pos := f.get_position()
	if pos + 4 > f.get_length():
		return null
	var n := f.get_32()
	if n == 0 or pos + 4 + n > f.get_length():
		return null
	f.seek(pos)
	return f.get_var()

func _rotate_autos() -> void:
	for i in range(AUTO_COPIES - 1, 0, -1):
		var a := _slot_path("auto_%d" % i)
		if FileAccess.file_exists(a):
			DirAccess.rename_absolute(a, _slot_path("auto_%d" % (i + 1)))
	if FileAccess.file_exists(_slot_path("auto")):
		DirAccess.rename_absolute(_slot_path("auto"), _slot_path("auto_1"))

## Temporales que quedaron de un guardado interrumpido (el original sigue intacto).
func _clean_temp_files() -> void:
	var d := DirAccess.open(SAVE_DIR)
	if d == null:
		return
	for fn in d.get_files():
		if fn.ends_with(".brasa.tmp"):
			DirAccess.remove_absolute(SAVE_DIR + "/" + fn)

## Partidas guardadas, la más nueva primero. Cada una trae la cabecera más:
## "slot", "ok" (se puede cargar) y "problem" ("" | "version" | "danada").
## Las incompatibles o dañadas se listan igual, para avisarle al jugador, pero con ok = false.
func list_saves() -> Array:
	var out := []
	var d := DirAccess.open(SAVE_DIR)
	if d == null:
		return out
	for fn in d.get_files():
		if fn.ends_with(".brasa"):
			out.append(_read_header(SAVE_DIR + "/" + fn, fn.get_basename()))
	out.sort_custom(func(a, b):
		if str(a["date"]) != str(b["date"]):
			return str(a["date"]) > str(b["date"])
		return float(a.get("ts", 0.0)) > float(b.get("ts", 0.0)))
	return out

## La partida más nueva que se puede cargar (vacío si no hay ninguna).
func latest_save() -> Dictionary:
	for s in list_saves():
		if s["ok"]:
			return s
	return {}

func _read_header(path: String, slot: String) -> Dictionary:
	var h := {"slot": slot, "ok": false, "problem": "danada", "date": "", "day": 0, "pop": 0}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return h
	var v = _read_var(f)
	if typeof(v) != TYPE_DICTIONARY or v.get("magic", "") != "BRASA":
		f.close()
		return h
	h.merge(v, true)
	h["slot"] = slot
	# El cuerpo tiene que estar completo: un archivo cortado a la mitad no se ofrece.
	var body_len := f.get_32()
	var complete := body_len > 0 and f.get_position() + body_len <= f.get_length()
	f.close()
	if int(h.get("save_version", 0)) > Simulation.SAVE_VERSION:
		h["problem"] = "version"
	elif complete and not _broken.has(slot):
		h["ok"] = true
		h["problem"] = ""
	return h

## Nombre legible de una ranura ("auto_2" -> "Automático (anterior 2)").
func slot_label(slot: String) -> String:
	if SLOT_NAMES.has(slot):
		return SLOT_NAMES[slot]
	if slot.begins_with("auto_") and slot.substr(5).is_valid_int():
		return "Automático (anterior %d)" % slot.substr(5).to_int()
	return slot.capitalize()

## Texto de dos líneas para las listas de carga: nombre y detalle (o el motivo si no se puede cargar).
func save_text(s: Dictionary) -> String:
	var name := slot_label(str(s["slot"]))
	match str(s.get("problem", "")):
		"version":
			return "%s\nDe una versión más nueva del juego (v%s): no se puede cargar" % [name, str(s.get("game_version", "?"))]
		"danada":
			return "%s\nArchivo dañado: no se puede cargar" % name
	return "%s\nDía %d · %d personas · %s" % [name, int(s["day"]), int(s["pop"]), short_date(str(s["date"]))]

## "2026-10-13T04:56:41" -> "13/10 04:56"
func short_date(iso: String) -> String:
	if iso.length() < 16:
		return iso
	return "%s/%s %s" % [iso.substr(8, 2), iso.substr(5, 2), iso.substr(11, 5)]

func _broken_slot(slot: String) -> bool:
	_broken[slot] = true
	return _fail("El archivo de la partida está dañado.")

func load_game(slot: String) -> bool:
	last_error = ""
	var path := _slot_path(slot)
	if not FileAccess.file_exists(path):
		return _fail("No se encontró la partida.")
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return _fail("No se pudo abrir la partida (%s)." % error_string(FileAccess.get_open_error()))
	var h = _read_var(f)
	var body = _read_var(f)
	f.close()
	if typeof(h) != TYPE_DICTIONARY or h.get("magic", "") != "BRASA":
		return _broken_slot(slot)
	if int(h.get("save_version", 0)) > Simulation.SAVE_VERSION:
		return _fail("La partida es de una versión más nueva del juego (v%s)." % str(h.get("game_version", "?")))
	if typeof(body) != TYPE_PACKED_BYTE_ARRAY:
		return _broken_slot(slot)
	var s := Simulation.new()
	if not s.deserialize(body):
		return _broken_slot(slot)
	sim = s
	_setup()
	return true

func quit_to_menu() -> void:
	sim = null
	clock = null
	paused = true

## Guardado de cierre o de segundo plano: una sola vez por estado (sin rotar los diarios).
func save_on_exit() -> bool:
	if sim == null or _ended:
		return false
	if sim.tick() == _exit_saved_tick:
		return true
	if save_game("salida"):
		_exit_saved_tick = sim.tick()
		return true
	return false

# ---------------------------------------------------------------- ciclo de vida
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST:
			save_on_exit()
			get_tree().quit()
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED:
			# Celular: al pasar a segundo plano se pausa y se guarda una vez en "salida"
			# (llegan las dos notificaciones; la segunda ya encuentra el mismo tick guardado).
			# En PC perder el foco (alt-tab) no guarda: el cierre ya lo cubre.
			if Settings.is_mobile() and sim != null and not _ended:
				set_paused(true)
				save_on_exit()
