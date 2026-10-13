extends SceneTree
func _init():
	var seed := 1003
	var sim := Simulation.new()
	sim.new_game(seed)
	var bot := BotCompetent.new()
	bot.setup(sim, seed)
	while sim.day() < 14:
		bot.act()
		sim.step()
	for b in sim.st["buildings"]:
		var r := bot._res_of(b)
		if r != "":
			print(b["type"], "#", b["id"], " res ", r, " pw ", bot.per_worker_day(b), " staff ", b["o"], "/", b["i"], " want ", b["do"], "/", b["di"], " nodes ", b["nodes"])
	for n in sim.st["nodes"]:
		print("node ", n["id"], " ", n["kind"], " amt ", n["amt"] / 1000, " at ", n["x"], ",", n["y"], " d ", sim.dist_tiles(n["x"], n["y"], 2, 2))
	for s in sim.st["sites"]:
		print("site ", s["kind"], " amt ", s["amt"] / 1000, " bid ", s["bid"])
	print("research ", sim.st["research"]["done"], " cur ", sim.st["research"]["cur"])
	print("potential madera ", bot.potential("madera"), " flex ", bot.flex, " idle ", sim.st["idle"])
	quit()
