class_name BotBase
extends RefCounted
## Base de los bots del banco de balance. Un bot solo usa la API pública de la
## simulación: consultas de estado y `sim.command()`. Se llama `act()` antes de cada paso.

var sim: Simulation
var name := "base"
var seed := 0
var rs := 1 # azar propio del bot (no toca el de la simulación)

func setup(s: Simulation, bot_seed: int) -> void:
	sim = s
	seed = bot_seed
	rs = SimRng.seed_state(bot_seed * 7919 + 17)

func brnd(n: int) -> int:
	rs = SimRng.step(rs)
	return rs % maxi(1, n)

func act() -> void:
	pass

func cmd(c: Dictionary) -> bool:
	return sim.command(c) == ""

# ---------------------------------------------------------------- utilidades comunes
func center() -> int:
	return sim.msize / 2 - 1

func buildings_of(types: Array, only_done: bool = false) -> Array:
	var out := []
	for b in sim.st["buildings"]:
		if b["type"] in types and (not only_done or b["state"] == 1):
			out.append(b)
	return out

func kind_of(b: Dictionary) -> String:
	return sim.bdef(b["type"]).get("kind", "")

func try_build_near(type: String, x: int, y: int) -> Dictionary:
	if not sim.is_unlocked(type) or not sim.can_afford(sim.bdef(type).get("cost", {})):
		return {}
	var d: Dictionary = sim.bdef(type)
	if d.has("limit") and sim.count_type(type) >= int(d["limit"]):
		return {}
	var p := sim.find_spot_near(type, x, y)
	if p.x < 0:
		return {}
	if cmd({"c": "build", "type": type, "x": p.x, "y": p.y}):
		return sim.building(int(sim.st["next_bid"]) - 1)
	return {}

func try_build_site(type: String) -> Dictionary:
	if not sim.is_unlocked(type) or not sim.can_afford(sim.bdef(type).get("cost", {})):
		return {}
	var kind: String = sim.bdef(type)["site"]
	var best: Dictionary = {}
	var bd := 1 << 30
	for s in sim.free_sites(kind):
		var d := sim.dist2_center(s["x"], s["y"], 3, 3)
		if d < bd:
			bd = d
			best = s
	if best.is_empty():
		return {}
	if cmd({"c": "build", "type": type, "x": best["x"], "y": best["y"]}):
		return sim.building(int(sim.st["next_bid"]) - 1)
	return {}

func res_units(r: String) -> int:
	return sim.res(r) / FX.ONE

func incoming_people() -> int:
	var n := 0
	for a in sim.st["arrivals"]:
		for c in Simulation.CLASSES:
			n += int(a.get(c, 0))
	return n

func housing_capacity(include_building: bool = true) -> int:
	var cap := 0
	for b in sim.st["buildings"]:
		var h: int = int(sim.bdef(b["type"]).get("housing", 0))
		if h > 0 and (include_building or b["state"] == 1):
			cap += h
	return cap
