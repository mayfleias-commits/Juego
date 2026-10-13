extends SceneTree
func _init():
	var seed := 1069
	var sim := Simulation.new()
	sim.new_game(seed)
	var bot := BotCompetent.new()
	bot.setup(sim, seed)
	while sim.st["status"] == "playing" and sim.day() < 56:
		bot.act()
		sim.step()
	var c := bot.center()
	print("affordable ", bot.affordable(sim.bdef("fabrica_aut")["cost"]), " reserved ", bot.reserved)
	print("spot ", sim.find_spot_near("fabrica_aut", c, c))
	var free := 0
	for y in sim.msize:
		for x in sim.msize:
			if sim.tile_in_bounds(x, y) and sim.grid[sim.gidx(x, y)] == 0:
				free += 1
	print("free tiles ", free, " buildings ", sim.st["buildings"].size())
	print("fab ", bot.buildings_of(["fabrica_aut"]).size(), " unlocked ", sim.is_unlocked("fabrica_aut"), " nuc ", sim.res("nucleos"), " res done ", sim.st["research"]["done"].size(), " autos ", sim.st["autos_total"], " free ", sim.st["autos_free"])
	for f in bot.buildings_of(["fabrica_aut"]):
		print(f)
	quit()
