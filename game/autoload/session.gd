extends Node
## Partida en curso: simulación + reloj + guardado. La interfaz solo lee el estado
## y manda órdenes con `Session.cmd()`, que se aplican entre pasos de simulación.

signal stepped(notes: Array)
signal day_ended(report: Dictionary)
signal game_over(status: String, reason: String)
signal speed_changed(speed: int)
signal loaded

const SAVE_DIR := "user://partidas"
const GAME_VERSION := "1.0.0"

var sim: Simulation
var clock: SimClock
var speed := 1
var paused := true
var autosave_enabled := true
var _last_day := 0
var _ended := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	get_tree().auto_accept_quit = false

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
	return sim.command(c)

func _process(delta: float) -> void:
	if sim == null or paused or _ended:
		return
	clock.speed = speed
	var before := sim.tick()
	var n := clock.advance_ms(int(delta * 1000.0))
	if n <= 0:
		return
	stepped.emit(sim.notes.duplicate())
	if sim.day() != _last_day:
		_last_day = sim.day()
		var reps: Array = sim.st["reports"]
		if reps.size() > 0:
			day_ended.emit(reps[reps.size() - 1])
		if autosave_enabled:
			save_game("auto")
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

## Guarda con cabecera versionada. Los automáticos rotan en 3 copias.
func save_game(slot: String = "manual") -> bool:
	if sim == null:
		return false
	if slot == "auto":
		for i in range(2, 0, -1):
			var a := _slot_path("auto_%d" % i)
			var b := _slot_path("auto_%d" % (i + 1))
			if FileAccess.file_exists(a):
				DirAccess.rename_absolute(a, b)
		if FileAccess.file_exists(_slot_path("auto")):
			DirAccess.rename_absolute(_slot_path("auto"), _slot_path("auto_1"))
	var f := FileAccess.open(_slot_path(slot), FileAccess.WRITE)
	if f == null:
		return false
	var header := {
		"magic": "BRASA", "save_version": Simulation.SAVE_VERSION, "game_version": GAME_VERSION,
		"date": Time.get_datetime_string_from_system(), "day": sim.day(), "hour": sim.hour(),
		"pop": sim.total_pop(), "seed": sim.st["seed"], "status": sim.st["status"],
	}
	f.store_var(header)
	f.store_var(sim.serialize())
	f.close()
	return true

func list_saves() -> Array:
	var out := []
	var d := DirAccess.open(SAVE_DIR)
	if d == null:
		return out
	for fn in d.get_files():
		if not fn.ends_with(".brasa"):
			continue
		var f := FileAccess.open(SAVE_DIR + "/" + fn, FileAccess.READ)
		if f == null:
			continue
		var h = f.get_var()
		f.close()
		if typeof(h) == TYPE_DICTIONARY and h.get("magic", "") == "BRASA":
			h["slot"] = fn.get_basename()
			out.append(h)
	out.sort_custom(func(a, b): return str(a["date"]) > str(b["date"]))
	return out

func load_game(slot: String) -> bool:
	var f := FileAccess.open(_slot_path(slot), FileAccess.READ)
	if f == null:
		return false
	var h = f.get_var()
	var body = f.get_var()
	f.close()
	if typeof(h) != TYPE_DICTIONARY or int(h.get("save_version", 0)) > Simulation.SAVE_VERSION:
		return false
	var s := Simulation.new()
	if not s.deserialize(body):
		return false
	sim = s
	_setup()
	return true

func quit_to_menu() -> void:
	sim = null
	clock = null
	paused = true

# ---------------------------------------------------------------- ciclo de vida
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST:
			if sim != null and not _ended:
				save_game("auto")
			get_tree().quit()
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			# En el celular: guardar al pasar a segundo plano y pausar.
			if sim != null and not _ended:
				save_game("auto")
				if Settings.is_mobile():
					set_paused(true)
		NOTIFICATION_WM_GO_BACK_REQUEST:
			if sim != null and not _ended:
				save_game("auto")
