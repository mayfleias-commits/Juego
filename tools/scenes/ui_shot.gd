extends Node
## Recorre la interfaz y guarda capturas. Uso:
## xvfb-run godot --path . --rendering-driver opengl3 res://tools/scenes/ui_shot.tscn -- --out=/ruta --day=12 [--ui-movil]
var out := "/tmp"
var main: Node
var args := {}

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and "=" in a:
			var kv := a.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1]
	out = args.get("out", "/tmp")
	main = load("res://game/main.tscn").instantiate()
	add_child(main)
	_run()

func _shot(name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])
	print("captura ", name)

func _wait(f: int) -> void:
	for i in f:
		await get_tree().process_frame

func _run() -> void:
	while main.menu == null:
		await get_tree().process_frame
	await _wait(10)
	await _shot("01_menu")
	main._start(int(args.get("seed", "1001")), "")
	await _wait(5)
	var sim: Simulation = Session.sim
	var bot := BotCompetent.new()
	bot.setup(sim, 1001)
	var day := int(args.get("day", "12"))
	while sim.day() < day and sim.st["status"] == "playing":
		bot.act()
		sim.step()
	sim.st["ev_pending"].clear()
	var g: GameScreen = main.game
	g.world.refresh(true)
	g.hud.refresh()
	Session.set_paused(true)
	await _wait(10)
	await _shot("02_juego")
	for p in ["build", "generator", "laws", "research", "explore", "report", "menu", "settings"]:
		g.hud.open_panel(p)
		await _wait(4)
		await _shot("03_" + p)
	g.hud.close_panel()
	for b in sim.st["buildings"]:
		if b["type"] == "puesto_rec" or b["type"] == "extractor":
			g.select_building(b["id"], true)
			break
	await _wait(20)
	await _shot("04_edificio")
	g.hud.close_panel()
	g.world.set_overlay(0)
	await _wait(4)
	await _shot("05_capa_calor")
	g.world.set_overlay(-1)
	sim.fire_event("ev_comerciante")
	g._check_pending()
	await _wait(4)
	await _shot("06_evento")
	g.hud.close_modal()
	g.begin_place("carpa")
	g._on_hover(get_viewport().get_visible_rect().size / 2)
	await _wait(4)
	await _shot("07_colocar")
	g.cancel_place()
	# Noche
	while sim.hour() != 22:
		bot.act()
		sim.step()
	g.world.refresh(true)
	await _wait(6)
	await _shot("08_noche")
	get_tree().quit()
