class_name BenchRunner
extends RefCounted
## Ejecuta una partida completa con un bot y devuelve las métricas.

static func make_bot(name: String) -> BotBase:
	match name:
		"competente":
			return BotCompetent.new()
		"pasivo":
			return BotPassive.new()
		"aleatorio":
			return BotRandom.new()
	var b := CheatBots.make(name)
	if b != null:
		return b
	push_error("bot desconocido: " + name)
	return BotPassive.new()

static func run_game(bot_name: String, seed: int, verbose: bool = false) -> Dictionary:
	var sim := Simulation.new()
	sim.new_game(seed)
	var bot := make_bot(bot_name)
	bot.setup(sim, seed)
	var guard := 0
	while sim.st["status"] == "playing" and guard < 24 * 70:
		bot.act()
		if bot.has_method("drive"):
			bot.drive()
		else:
			sim.step()
		guard += 1
		if verbose and sim.hour() == 0:
			print("d%d pop %d hope %d disc %d coal %d wood %d metal %d food %d/%d sick %d dead %d homeless %d lvl %d b %d" % [sim.day(), sim.total_pop(), sim.st["hope"] / 1000, sim.st["disc"] / 1000, sim.res("carbon") / 1000, sim.res("madera") / 1000, sim.res("metal") / 1000, sim.res("crudo") / 1000, sim.res("raciones") / 1000, sim.total_sick(), sim.st["dead"], sim.st["homeless"], sim.st["gen"]["level"], sim.st["buildings"].size()])
			print("   ", dump_buildings(sim), " idle ", sim.st.get("idle", {}), " R ", sim.st["research"]["cur"])
	var r := {
		"bot": bot_name, "seed": seed, "status": sim.st["status"], "reason": sim.st["end_reason"],
		"day": sim.day(), "pop": sim.total_pop(), "dead": sim.st["dead"], "stars": sim.st["stars"],
		"hope": sim.st["hope"] / FX.ONE, "disc": sim.st["disc"] / FX.ONE,
		"left": sim.leftovers_pct(),
		"obtained": {}, "wasted": {}, "end_res": {},
		"arrived": sim.st["arrived_total"], "explored": sim.st["explored"],
		"research": (sim.st["research"]["done"] as Array).size(), "laws": (sim.st["laws"] as Array).size(),
		"buildings": (sim.st["buildings"] as Array).size(), "path": sim.st["path"],
		"hash": sim.state_hash().substr(0, 16),
	}
	for res in Simulation.RES:
		r["obtained"][res] = sim.st["obtained"][res] / FX.ONE
		r["wasted"][res] = sim.st["wasted"][res] / FX.ONE
		r["end_res"][res] = sim.st["res"][res] / FX.ONE
	if bot.has_method("extra_metrics"):
		r["extra"] = bot.extra_metrics()
	return r

static func dump_buildings(sim: Simulation) -> String:
	var s := ""
	for b in sim.st["buildings"]:
		s += "%s#%d[%d %d/%d/%d d%d/%d/%d] " % [b["type"], b["id"], b["state"], b["o"], b["i"], b["n"], b["do"], b["di"], b["dn"]]
	return s
