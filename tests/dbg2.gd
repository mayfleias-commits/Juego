extends SceneTree
func _init():
	var seed := int(OS.get_cmdline_user_args()[0]) if OS.get_cmdline_user_args().size() > 0 else 1000
	var sim := Simulation.new()
	sim.new_game(seed)
	var bot := BotCompetent.new()
	bot.setup(sim, seed)
	while sim.st["status"] == "playing" and sim.day() < 61:
		bot.act()
		sim.step()
		if sim.hour() == 12:
			var staff := {"crudo": 0, "carbon": 0, "madera": 0, "metal": 0, "cook": 0, "med": 0, "res": 0, "otros": 0}
			for b in sim.st["buildings"]:
				var n: int = b["o"] + b["i"] + b["n"]
				var r := bot._res_of(b)
				var k: String = sim.bdef(b["type"]).get("kind", "")
				if staff.has(r):
					staff[r] += n
				elif k == "cook":
					staff["cook"] += n
				elif k == "medical":
					staff["med"] += n
				elif k == "research":
					staff["res"] += n
				else:
					staff["otros"] += n
			var rep: Dictionary = sim.st["reports"][-1] if sim.st["reports"].size() > 0 else {}
			var prod: Dictionary = rep.get("prod", {})
			print("d%d pop%d H%d D%d | coal %d(+%d) wood %d(+%d) metal %d(+%d) raw %d(+%d) rat %d | staff %s | sick %d hunt%% %d waveTgt %d dw %d" % [sim.day(), sim.total_pop(), sim.st["hope"]/1000, sim.st["disc"]/1000, sim.res("carbon")/1000, prod.get("carbon",0)/1000, sim.res("madera")/1000, prod.get("madera",0)/1000, sim.res("metal")/1000, prod.get("metal",0)/1000, sim.res("crudo")/1000, prod.get("crudo",0)/1000, sim.res("raciones")/1000, str(staff), sim.total_sick(), bot.hunt_stock_pct(), bot.wave_coal_target(), bot.days_to_wave()])
	print(sim.st["end_reason"], " ", sim.day())
	quit()
