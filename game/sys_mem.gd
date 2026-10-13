class_name SysMem
extends RefCounted
## Memoria real del proceso (en las builds de release Godot no lleva la cuenta propia).
## Android/Linux: /proc/self/status. Windows: `tasklist` en un hilo aparte cada pocos segundos.

static var _win_mb := -1.0
static var _thread: Thread
static var _last_ms := 0

static func process_mb() -> float:
	var dbg := Performance.get_monitor(Performance.MEMORY_STATIC)
	var os := OS.get_name()
	if os == "Android" or os == "Linux":
		# Los archivos de /proc dicen medir 0 bytes: hay que leerlos línea por línea.
		var f := FileAccess.open("/proc/self/status", FileAccess.READ)
		if f:
			var guard := 0
			while guard < 200:
				guard += 1
				var line := f.get_line()
				if line.begins_with("VmRSS:"):
					f.close()
					return float(line.split(":")[1].strip_edges().split(" ")[0]) / 1024.0
				if f.eof_reached():
					break
			f.close()
	elif os == "Windows":
		_poll_windows()
		if _win_mb > 0:
			return _win_mb
	return dbg / 1048576.0

static func _poll_windows() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_ms < 4000:
		return
	if _thread and _thread.is_alive():
		return
	if _thread:
		_thread.wait_to_finish()
	_last_ms = now
	_thread = Thread.new()
	_thread.start(_win_worker)

static func _win_worker() -> void:
	var out := []
	var pid := OS.get_process_id()
	OS.execute("tasklist", ["/FI", "PID eq %d" % pid, "/FO", "CSV", "/NH"], out, false, false)
	if out.size() > 0:
		var parts: PackedStringArray = str(out[0]).split("\",\"")
		if parts.size() >= 5:
			var kb := parts[4].replace("\"", "").replace(".", "").replace(",", "").replace("K", "").replace("k", "").strip_edges()
			_win_mb = float(kb.to_int()) / 1024.0
