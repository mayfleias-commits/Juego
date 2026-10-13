extends SceneTree
func _init():
	var seed := int(OS.get_cmdline_user_args()[0])
	var sim := Simulation.new()
	sim.new_game(seed)
	var bot := BotCompetent.new()
	bot.setup(sim, seed)
	var last := 0
	while sim.st["status"] == "playing":
		bot.act()
		sim.step()
		var n: int = sim.res("nucleos") / 1000
		if n != last:
			print("d", sim.day(), " h", sim.hour(), " nucleos ", last, " -> ", n, " metal ", sim.res("metal") / 1000, " fab ", bot.buildings_of(["fabrica_aut"]).size(), " autos ", sim.st["autos_total"])
			last = n
	print(sim.st["research"]["done"])
	quit()
