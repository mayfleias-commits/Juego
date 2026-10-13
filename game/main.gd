extends Node
## Raíz del juego: arranque, detección automática de calidad, menú y partida.

var menu: MainMenu
var menu_layer: CanvasLayer
var menu_world: World
var game: GameScreen
var perf: PerfOverlay
var _idle := 0.0

func _ready() -> void:
	UiKit.mobile = Settings.is_mobile() or "--ui-movil" in OS.get_cmdline_user_args()
	if UiKit.mobile:
		get_window().content_scale_size = Vector2i(960, 540)
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_LANDSCAPE)
	UiKit.make_theme()
	Settings.apply()
	perf = PerfOverlay.new()
	add_child(perf)
	if "--benchmark" in OS.get_cmdline_user_args():
		_benchmark(true)
		return
	if Settings.first_run:
		_first_run()
	else:
		show_menu()

## Primer arranque: preset según plataforma/RAM/GPU + mini benchmark de 5 s.
func _first_run() -> void:
	var preset := Settings.auto_detect()
	Settings.preset = preset
	Settings._from_preset()
	var cap := Settings.fps_limit
	Settings.fps_limit = 0
	Settings.apply()
	var lbl := UiKit.label("Ajustando la calidad gráfica para este equipo...", 20, UiKit.ACCENT)
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	var p := PanelContainer.new()
	p.add_child(lbl)
	layer.add_child(p)
	p.position = Vector2(20, 20)
	var b := BenchMode.new()
	b.seconds = 5.0
	b.save_file = false
	add_child(b)
	var r: Dictionary = await b.finished
	b.queue_free()
	layer.queue_free()
	var fps: float = r["fps_promedio"]
	var idx := Settings.PRESETS.find(preset)
	var target := 28.0 if Settings.is_mobile() else 40.0
	if fps < target and idx > 0:
		idx -= 1
	elif not Settings.is_mobile() and fps >= 75.0 and idx < 3:
		idx += 1
	Settings.fps_limit = cap
	Settings.set_preset(Settings.PRESETS[idx])
	show_menu()

func show_menu() -> void:
	if game:
		game.queue_free()
		game = null
	Session.quit_to_menu()
	Engine.max_fps = mini(Settings.fps_limit if Settings.fps_limit > 0 else 30, 30)
	menu_world = World.new()
	add_child(menu_world)
	menu_world.setup(DemoCity.build(777, 20))
	menu_world.camera_rig.input_enabled = false
	menu_layer = CanvasLayer.new()
	menu_layer.layer = 10
	add_child(menu_layer)
	menu = MainMenu.new()
	menu_layer.add_child(menu)
	menu.new_game.connect(func(): _start(-1, ""))
	menu.continue_game.connect(func(slot): _start(-1, slot))
	menu.benchmark.connect(func(): _benchmark(false))

func _clear_menu() -> void:
	if menu_layer:
		menu_layer.queue_free()
		menu_layer = null
	if menu_world:
		menu_world.queue_free()
		menu_world = null

func _start(seed: int, slot: String) -> void:
	_clear_menu()
	if slot != "":
		if not Session.load_game(slot):
			show_menu()
			return
	else:
		Session.new_game(seed)
	Settings.apply()
	game = GameScreen.new()
	add_child(game)
	game.start()
	game.exit_requested.connect(func(): show_menu())
	game.new_game_requested.connect(func():
		game.queue_free()
		game = null
		_start(-1, ""))
	game.benchmark_requested.connect(func():
		Session.save_game("auto")
		game.queue_free()
		game = null
		_benchmark(false))

func _benchmark(quit_after: bool) -> void:
	_clear_menu()
	var b := BenchMode.new()
	b.seconds = 20.0
	add_child(b)
	var r: Dictionary = await b.finished
	b.queue_free()
	print(JSON.stringify(r))
	if quit_after:
		get_tree().quit()
		return
	show_menu()
	var layer := menu_layer
	var p := PanelContainer.new()
	var txt := "Benchmark (%s): %.1f FPS promedio, %.1f mínimo, %d llamadas de dibujo, %dk triángulos, %.0f MB.\nGuardado en %s" % [Settings.PRESET_NAMES[Settings.preset], r["fps_promedio"], r["fps_minimo"], r["draw_calls_max"], int(r["triangulos_max"]) / 1000, r["memoria_pico_mb"], r.get("archivo", "")]
	var l := UiKit.label(txt, 15, UiKit.TXT, true)
	l.custom_minimum_size = Vector2(600, 0)
	p.add_child(l)
	layer.add_child(p)
	p.position = Vector2(20, 20)

## Batería: bajar los FPS cuando el juego está en pausa o nadie toca la pantalla.
func _process(delta: float) -> void:
	if menu_world and is_instance_valid(menu_world) and menu_world.camera_rig:
		menu_world.camera_rig._t_yaw += delta * 0.04
	if game == null:
		return
	_idle += delta
	var limit := Settings.fps_limit
	if Settings.is_mobile() or UiKit.mobile:
		if Session.paused:
			limit = 15 if _idle > 3.0 else 30
		elif _idle > 20.0:
			limit = 20
	Engine.max_fps = limit

## Botón "atrás" de Android: cierra paneles/diálogos, abre el menú o sale desde el menú principal.
func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_GO_BACK_REQUEST:
		return
	if game and game.hud:
		if game.placing != "":
			game.cancel_place()
		elif game.hud.modal_open:
			pass
		elif game.hud.current_panel:
			game.hud.close_panel()
		else:
			game.hud.open_panel("menu")
	elif menu:
		get_tree().quit()

func _input(ev: InputEvent) -> void:
	if ev is InputEventScreenTouch or ev is InputEventMouseButton or ev is InputEventKey or ev is InputEventScreenDrag:
		_idle = 0.0
