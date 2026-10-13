extends SceneTree
func _init():
	var sim := Simulation.new()
	sim.new_game(1)
	var bot := BotCompetent.new()
	bot.setup(sim, 1)
	var tb := 0
	var ts := 0
	var parts := {}
	while sim.st["status"] == "playing":
		var t0 := Time.get_ticks_usec()
		bot.act()
		var t1 := Time.get_ticks_usec()
		sim.step()
		var t2 := Time.get_ticks_usec()
		tb += t1 - t0
		ts += t2 - t1
	print("bot ms ", tb / 1000, " sim ms ", ts / 1000, " day ", sim.day())
	# Perfil de partes de la simulación en el estado final
	var names := ["gen_update", "heat_update", "construction_update", "staff_fill", "autos_update", "production_update", "compute_exposure", "mood_update", "events_update", "requests_update", "bodies_update"]
	sim.st["status"] = "playing"
	for n in names:
		var t := Time.get_ticks_usec()
		for i in 200:
			if n == "compute_exposure":
				sim.compute_exposure()
			else:
				sim.call(n)
		print(n, " us/call ", (Time.get_ticks_usec() - t) / 200)
	var t3 := Time.get_ticks_usec()
	for i in 200:
		sim.health_update(sim.compute_exposure())
	print("health+exp us/call ", (Time.get_ticks_usec() - t3) / 200)
	var bp := ["_plan_builds", "_staff", "_generator", "_research", "_laws", "_explore", "_cleanup"]
	for n in bp:
		var t := Time.get_ticks_usec()
		for i in 50:
			bot.call(n)
		print("bot ", n, " us/call ", (Time.get_ticks_usec() - t) / 50)
	quit()
