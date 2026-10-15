extends Node
## Audio procedural (generado por tools/make_audio.py): música, viento y generador en bucle,
## y efectos puntuales. Buses: Master > Musica, Efectos.

var music: AudioStreamPlayer
var wind: AudioStreamPlayer
var hum: AudioStreamPlayer
var sfx: Array = []
var _streams := {}
var _wind_target := -12.0
var _hum_target := -40.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for b in ["Musica", "Efectos"]:
		if AudioServer.get_bus_index(b) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, b)
			AudioServer.set_bus_send(i, "Master")
	music = _player("musica", "Musica", true, -10.0)
	wind = _player("viento", "Efectos", true, -14.0)
	hum = _player("generador", "Efectos", true, -40.0)
	for i in 4:
		var p := AudioStreamPlayer.new()
		p.bus = "Efectos"
		add_child(p)
		sfx.append(p)
	music.play()
	wind.play()
	hum.play()
	Settings.apply()

func _stream(name: String, loop: bool) -> AudioStream:
	var key := name + str(loop)
	if _streams.has(key):
		return _streams[key]
	var s: AudioStream = load("res://assets/audio/%s.wav" % name)
	if s is AudioStreamWAV and loop:
		s = s.duplicate()
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		# En cuadros, desde la duración real: los WAV se importan comprimidos (QOA),
		# así que el tamaño de `data` no dice cuántas muestras hay.
		s.loop_end = int(round(s.get_length() * s.mix_rate))
	_streams[key] = s
	return s

func _player(name: String, bus: String, loop: bool, db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = _stream(name, loop)
	p.bus = bus
	p.volume_db = db
	add_child(p)
	return p

func play(name: String, db: float = -6.0) -> void:
	for p in sfx:
		if not p.playing:
			p.stream = _stream(name, false)
			p.volume_db = db
			p.play()
			return

func click() -> void:
	play("clic", -14.0)

## Ambiente según el estado de la partida (frío, oleada, generador).
func _process(delta: float) -> void:
	var sim: Simulation = Session.sim
	if sim != null:
		var cold := clampf((-float(sim.outdoor()) - 15.0) / 70.0, 0.0, 1.0)
		_wind_target = lerpf(-22.0, -6.0, cold) + (4.0 if sim.in_wave() else 0.0)
		var g: Dictionary = sim.st["gen"]
		_hum_target = -40.0 if int(g["on"]) == 0 else -24.0 + 2.0 * float(g["level"]) + (3.0 if int(g["over"]) == 1 else 0.0)
	else:
		_wind_target = -16.0
		_hum_target = -32.0
	wind.volume_db = move_toward(wind.volume_db, _wind_target, delta * 6.0)
	hum.volume_db = move_toward(hum.volume_db, _hum_target, delta * 8.0)
