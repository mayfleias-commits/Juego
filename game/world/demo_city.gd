class_name DemoCity
extends RefCounted
## Ciudad sintética para benchmarks: se arma al instante (sin simular días),
## así el mini benchmark de 5 s funciona igual en un celular lento.

const LAYOUT := [
	["casa_piedra", 30], ["barracon", 12], ["carpa", 4], ["taller", 4], ["cocina", 3], ["puesto_medico", 3],
	["enfermeria", 2], ["deposito", 4], ["carbonera", 4], ["invernadero", 3], ["invernadero_ind", 1],
	["cazadores", 3], ["capilla", 2], ["templo", 1], ["estacion_vapor", 3], ["faro", 2], ["fundicion", 1],
	["horno_carbon", 2], ["fabrica_aut", 1], ["cementerio", 1], ["taberna", 1], ["refugio_inf", 2], ["puesto_rec", 4],
]

static func build(seed: int = 4242, day: int = 55) -> Simulation:
	var sim := Simulation.new()
	sim.new_game(seed)
	var c := sim.msize / 2 - 1
	for entry in LAYOUT:
		for i in int(entry[1]):
			var p := sim.find_spot_near(entry[0], c, c)
			if p.x < 0:
				continue
			var b: Dictionary = sim._create_building(entry[0], p.x, p.y)
			b["state"] = 1
			b["left"] = 0
			var mx := sim.staff_max(sim.bdef(entry[0]))
			b["o"] = mx
			b["do"] = mx
	for kind in ["extractor", "aserradero", "mina_hierro", "perforadora", "mina_profunda"]:
		for s in sim.free_sites(sim.bdef(kind)["site"]):
			var b2: Dictionary = sim._create_building(kind, s["x"], s["y"])
			b2["state"] = 1
			b2["o"] = 10
			break
	sim.st["pop"]["obreros"]["h"] = 200
	sim.st["pop"]["ingenieros"]["h"] = 40
	sim.st["pop"]["ninos"]["h"] = 30
	sim.st["day"] = day
	sim.st["hour"] = 20
	sim.st["gen"]["level"] = 4
	sim.st["gen"]["over"] = 1
	sim.st["outdoor"] = sim.temp_at(day, 20)
	sim.recompute_caps()
	sim.heat_update()
	return sim
