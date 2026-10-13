extends SceneTree
func _init():
	var sim := Simulation.new()
	sim.new_game(1005)
	var bot := BotCompetent.new()
	bot.setup(sim, 1005)
	while sim.day() < 54 and sim.st["status"] == "playing":
		bot.act()
		sim.step()
	# Llevar la población al peor caso pedido (400)
	sim.st["pop"]["obreros"]["h"] += maxi(0, 400 - sim.total_pop())
	var t0 := Time.get_ticks_usec()
	var n := 0
	var worst := 0
	while n < 96 and sim.st["status"] == "playing":
		var a := Time.get_ticks_usec()
		sim.step()
		worst = maxi(worst, Time.get_ticks_usec() - a)
		n += 1
	var t1 := Time.get_ticks_usec()
	var s0 := Time.get_ticks_usec()
	var bytes := sim.serialize()
	var s1 := Time.get_ticks_usec()
	print("pob ", sim.total_pop(), " edificios ", sim.st["buildings"].size(), " pasos ", n, " promedio_ms ", (t1 - t0) / 1000.0 / n, " peor_ms ", worst / 1000.0, " guardado_kb ", bytes.size() / 1024, " guardar_ms ", (s1 - s0) / 1000.0)
	quit()
