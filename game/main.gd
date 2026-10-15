extends Node
## Raíz del juego: arranque, detección automática de calidad, menú y partida.

var menu: MainMenu
var menu_layer: CanvasLayer
var menu_world: World
var game: GameScreen
var perf: PerfOverlay
var _idle := 0.0
## true mientras corre un benchmark (el de 20 s o el mini del primer arranque):
## nadie más toca Engine.max_fps y el botón atrás no hace nada.
var _benchmarking := false
## Panel con el resultado del último benchmark (se cierra con su botón o con atrás).
var _result_layer: CanvasLayer

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

## Mide sin vsync y con el tope de FPS indicado (0 = sin límite). Devuelve el vsync anterior.
func _begin_measure(max_fps: int) -> DisplayServer.VSyncMode:
	_benchmarking = true
	var vs := DisplayServer.window_get_vsync_mode()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = max_fps
	return vs

func _end_measure(vs: DisplayServer.VSyncMode) -> void:
	DisplayServer.window_set_vsync_mode(vs)
	_benchmarking = false
	Settings.apply()

## Primer arranque: preset según plataforma/RAM/GPU + mini benchmark de 5 s.
## Mide sin tope de FPS y sin vsync, así puede tanto bajar como subir un escalón.
func _first_run() -> void:
	var preset := Settings.auto_detect()
	Settings.preset = preset
	Settings._from_preset()
	Settings.apply()
	var vs := _begin_measure(0)
	var lbl := UiKit.label("Ajustando la calidad gráfica para este equipo...", 20, UiKit.ACCENT)
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	var p := PanelContainer.new()
	p.theme = UiKit.theme
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
	_end_measure(vs)
	var fps: float = r["fps_promedio"]
	var options: Array = Settings.available_presets()
	var idx := options.find(preset)
	if idx < 0:
		idx = 0
	if Settings.is_mobile():
		# Celular: hace falta sostener 30; solo se sube a Bajo con mucho margen.
		if fps < 28.0 and idx > 0:
			idx -= 1
		elif fps >= 55.0 and idx < options.size() - 1:
			idx += 1
	else:
		if fps < 40.0 and idx > 0:
			idx -= 1
		elif fps >= 75.0 and idx < options.size() - 1:
			idx += 1
	Settings.set_preset(options[idx])
	show_menu()

func show_menu() -> void:
	if game:
		game.queue_free()
		game = null
	Session.quit_to_menu()
	_idle = 0.0
	Engine.max_fps = _menu_fps()
	menu_world = World.new()
	add_child(menu_world)
	menu_world.setup(DemoCity.build(777, 20))
	menu_world.camera_rig.input_enabled = false
	menu_layer = CanvasLayer.new()
	menu_layer.layer = 10
	add_child(menu_layer)
	menu = MainMenu.new()
	menu.world = menu_world
	menu_layer.add_child(menu)
	menu.new_game.connect(func(): _start(-1, ""))
	menu.continue_game.connect(func(slot): _start(-1, slot))
	menu.benchmark.connect(func(): _benchmark(false))

## El menú no necesita más de 30 FPS; en el celular, sin tocar la pantalla, baja a 15.
func _menu_fps() -> int:
	var cap := Settings.effective_fps()
	var limit := mini(cap if cap > 0 else 30, 30)
	if (Settings.is_mobile() or UiKit.mobile) and _idle > 10.0:
		limit = mini(limit, 15)
	return limit

func _clear_menu() -> void:
	if menu_layer:
		menu_layer.queue_free()
		menu_layer = null
	menu = null
	if menu_world:
		menu_world.queue_free()
		menu_world = null

func _start(seed: int, slot: String) -> void:
	_close_result()
	if slot != "":
		if not Session.load_game(slot):
			var msg := "No se pudo cargar «%s»: %s" % [Session.slot_label(slot), Session.last_error]
			if menu == null:
				_clear_menu()
				show_menu()
			menu.show_notice(msg)
			return
	else:
		Session.new_game(seed)
	_clear_menu()
	_open_game()

## Crea la pantalla de juego sobre la partida que ya está en Session.
func _open_game() -> void:
	Settings.apply()
	_idle = 0.0
	game = GameScreen.new()
	add_child(game)
	game.start()
	game.exit_requested.connect(func(): show_menu())
	game.new_game_requested.connect(func():
		game.queue_free()
		game = null
		_start(-1, ""))
	game.benchmark_requested.connect(_benchmark_from_game)

## Benchmark lanzado desde la partida: la simulación queda en pausa mientras se mide
## (no avanza sin interfaz) y al terminar se vuelve a la misma partida.
func _benchmark_from_game() -> void:
	if _benchmarking:
		return
	var was_paused := Session.paused
	Session.set_paused(true)
	Session.save_on_exit()
	if game:
		game.queue_free()
		game = null
	_benchmark(false, true, was_paused)

func _benchmark(quit_after: bool, from_game: bool = false, was_paused: bool = true) -> void:
	if _benchmarking:
		return
	_close_result()
	_clear_menu()
	# Se mide con el tope de FPS del ajuste (no el de 30 del menú) y sin vsync.
	Settings.apply()
	var vs := _begin_measure(Settings.effective_fps())
	var b := BenchMode.new()
	b.seconds = 20.0
	add_child(b)
	var r: Dictionary = await b.finished
	b.queue_free()
	_end_measure(vs)
	print(JSON.stringify(r))
	if quit_after:
		get_tree().quit()
		return
	if from_game and Session.has_game():
		_open_game()
		# La partida sigue en pausa mientras se lee el resultado; al cerrarlo vuelve como estaba
		# (salvo que haya un diálogo esperando decisión, que deja la partida en pausa).
		_show_result(r, func():
			if not was_paused and game and game.hud and not game.hud.modal_open:
				Session.set_paused(false))
	else:
		show_menu()
		_show_result(r, Callable())

## Resultado del benchmark en pantalla, con botón para copiarlo (en Android el archivo
## queda en el almacenamiento privado de la app y el jugador no puede abrirlo).
func _show_result(r: Dictionary, on_close: Callable) -> void:
	_close_result()
	_result_layer = CanvasLayer.new()
	_result_layer.layer = 40
	add_child(_result_layer)
	var root := Control.new()
	root.theme = UiKit.theme
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_result_layer.add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiKit._sb(Color(0.04, 0.05, 0.08, 0.95), 10, UiKit.ACCENT_D, 1, 18))
	center.add_child(p)
	var v := UiKit.vbox(10)
	p.add_child(v)
	v.add_child(UiKit.title("Resultado del benchmark"))
	var l := UiKit.label(_result_text(r), 15, UiKit.TXT, true)
	l.custom_minimum_size = Vector2(500 if UiKit.mobile else 620, 0)
	# Desplazable: con la interfaz agrandada en un celular el texto no entra entero.
	var sc := UiKit.scroll(l)
	v.add_child(sc)
	var h := UiKit.hbox(8)
	var copy := UiKit.button("Copiar resultados", "reporte", Callable())
	copy.pressed.connect(func():
		DisplayServer.clipboard_set(JSON.stringify(r, "  "))
		copy.text = "Copiado al portapapeles")
	h.add_child(copy)
	h.add_child(UiKit.button("Cerrar", "cerrar", func():
		_close_result()
		if on_close.is_valid():
			on_close.call()))
	v.add_child(h)
	_result_layer.set_meta("on_close", on_close)
	_fit_result.call_deferred(sc, l, p)

## Alto del texto del resultado: todo si entra; si no, lo que deja libre la pantalla.
func _fit_result(sc: ScrollContainer, l: Label, p: PanelContainer) -> void:
	if not is_instance_valid(sc):
		return
	var vp := sc.get_viewport_rect().size
	var other := p.get_combined_minimum_size().y - sc.get_combined_minimum_size().y
	var avail := maxf(80.0, vp.y - 24.0 - other)
	sc.custom_minimum_size = Vector2(0, minf(l.get_combined_minimum_size().y, avail))

func _result_text(r: Dictionary) -> String:
	var lim := int(r.get("limite_fps", 0))
	var lines := [
		"Preset %s · escala de render %d %% · límite de FPS: %s · vsync %s" % [
			Settings.PRESET_NAMES.get(str(r.get("preset", "")), str(r.get("preset", ""))),
			int(round(float(r.get("escala_render", 1.0)) * 100.0)),
			str(lim) if lim > 0 else "sin límite", str(r.get("vsync", "?"))],
		"FPS promedio: %.1f · 1 %% más bajo: %.1f · mínimo: %.1f" % [
			float(r["fps_promedio"]), float(r.get("fps_1pct_bajo", 0.0)), float(r["fps_minimo"])],
		"Llamadas de dibujo (máx.): %d · triángulos (máx.): %dk" % [int(r["draw_calls_max"]), int(r["triangulos_max"]) / 1000],
		"Memoria del proceso (pico): %.0f MB · video: %.0f MB" % [float(r["memoria_pico_mb"]), float(r.get("video_mb", 0.0))],
		"Resolución: %s (3D: %s)" % [str(r.get("resolucion", "?")), str(r.get("resolucion_3d", "?"))],
		"%s · %s" % [str(r.get("gpu", "")), str(r.get("modelo", ""))],
	]
	if r.has("archivo"):
		lines.append("Guardado en: %s" % str(r["archivo"]))
	return "\n".join(lines)

func _close_result() -> void:
	if _result_layer and is_instance_valid(_result_layer):
		_result_layer.queue_free()
	_result_layer = null

## Batería: bajar los FPS cuando el juego está en pausa o nadie toca la pantalla.
func _process(delta: float) -> void:
	if _benchmarking:
		return
	_idle += delta
	if game == null:
		if menu_world and is_instance_valid(menu_world) and menu_world.camera_rig:
			menu_world.camera_rig._t_yaw += delta * 0.04
		if menu:
			Engine.max_fps = _menu_fps()
		return
	var limit := Settings.effective_fps()
	if Settings.is_mobile() or UiKit.mobile:
		if limit <= 0:
			limit = 30
		if Session.paused:
			limit = mini(limit, 15 if _idle > 3.0 else 30)
		elif _idle > 20.0:
			limit = mini(limit, 20)
	Engine.max_fps = limit

## Botón "atrás" de Android: cierra el resultado del benchmark, paneles y diálogos, abre el
## menú de la partida, vuelve de una subpantalla del menú principal o sale desde su raíz.
func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_GO_BACK_REQUEST:
		return
	if _benchmarking:
		return
	if _result_layer and is_instance_valid(_result_layer):
		var cb: Callable = _result_layer.get_meta("on_close", Callable())
		_close_result()
		if cb.is_valid():
			cb.call()
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
	elif menu and is_instance_valid(menu):
		if not menu.go_back():
			get_tree().quit()

func _input(ev: InputEvent) -> void:
	if ev is InputEventScreenTouch or ev is InputEventMouseButton or ev is InputEventKey or ev is InputEventScreenDrag:
		_idle = 0.0
