extends Node
## Prueba de resistencia de la interfaz: juega una partida completa (bot) a través del HUD real.
var main: Node
func _ready() -> void:
	Settings.preset = "muy_bajo"
	Settings._from_preset()
	main = load("res://game/main.tscn").instantiate()
	add_child(main)
	_run()

func _run() -> void:
	while main.menu == null:
		await get_tree().process_frame
	main._start(int(OS.get_cmdline_user_args()[0]) if OS.get_cmdline_user_args().size() > 0 else 1003, "")
	await get_tree().process_frame
	var sim: Simulation = Session.sim
	var bot := BotCompetent.new()
	bot.setup(sim, 1003)
	var g: GameScreen = main.game
	var panels := ["build", "generator", "laws", "research", "explore", "report", "menu"]
	var i := 0
	while sim.st["status"] == "playing":
		bot.act()
		sim.step()
		Session.stepped.emit(sim.notes.duplicate())
		if sim.hour() == 0:
			var reps: Array = sim.st["reports"]
			Session.day_ended.emit(reps[reps.size() - 1])
			g.hud.open_panel(panels[i % panels.size()])
			i += 1
			# cerrar diálogos acumulados
			while g.hud.modal_open:
				g.hud.close_modal()
			await get_tree().process_frame
			if sim.day() % 10 == 0:
				print("día ", sim.day(), " pob ", sim.total_pop())
	Session.game_over.emit(sim.st["status"], sim.st["end_reason"])
	await get_tree().process_frame
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[1] if OS.get_cmdline_user_args().size() > 1 else "/tmp/fin.png")
	print("FIN ", sim.st["status"], " ", sim.st["end_reason"], " estrellas ", sim.st["stars"])
	get_tree().quit()
