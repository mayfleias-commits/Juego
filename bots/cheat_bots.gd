class_name CheatBots
extends RefCounted
## Bots tramposos: cada uno juega como el competente y además intenta un exploit.
## También las variantes de control: ignorar cada oleada y dejar de desarrollarse.

const NAMES := [
	"t01_demoler", "t02_reasignar", "t03_sobrecarga", "t04_recargar", "t05_velocidad",
	"t06_esperanza", "t07_acumular", "t08_pilas", "t09_generador_noche", "t10_enfermos",
	"t11_repetir", "t12_automatas", "t13_desbordes", "t14_plataforma",
]
const VARIANTS := ["ola_1", "ola_2", "ola_3", "ola_4", "ola_5", "estancado"]

static func make(name: String) -> BotBase:
	var b: BotBase = null
	match name:
		"t01_demoler": b = Demoler.new()
		"t02_reasignar": b = Reasignar.new()
		"t03_sobrecarga": b = Sobrecarga.new()
		"t04_recargar": b = Recargar.new()
		"t05_velocidad": b = Velocidad.new()
		"t06_esperanza": b = Esperanza.new()
		"t07_acumular": b = Acumular.new()
		"t08_pilas": b = Pilas.new()
		"t09_generador_noche": b = GeneradorNoche.new()
		"t10_enfermos": b = Enfermos.new()
		"t11_repetir": b = Repetir.new()
		"t12_automatas": b = Automatas.new()
		"t13_desbordes": b = Desbordes.new()
		"t14_plataforma": b = Plataforma.new()
		"estancado":
			var e := BotCompetent.new()
			e.stop_dev_day = 15
			b = e
	if name.begins_with("ola_"):
		var w := BotCompetent.new()
		w.ignore_wave = int(name.substr(4))
		b = w
	if b != null:
		b.name = name
	return b


## 1) Demoler y reconstruir para ganar recursos.
class Demoler extends BotCompetent:
	var cycles := 0
	func act() -> void:
		super.act()
		if sim.hour() % 6 != 3:
			return
		for t in ["deposito", "carpa", "puesto_rec", "carbonera"]:
			for b in buildings_of([t], true):
				var x: int = b["x"]
				var y: int = b["y"]
				if cmd({"c": "demolish", "bid": b["id"]}):
					cmd({"c": "build", "type": t, "x": x, "y": y})
					cycles += 1
				return
	func extra_metrics() -> Dictionary:
		return {"ciclos": cycles}


## 2) Reasignar trabajadores al final del turno (doble conteo).
## Al terminar el turno de carbón mueve a todos a madera/metal para "trabajar dos veces",
## y a la mañana los devuelve. La producción es por hora trabajada y el viaje cuenta.
class Reasignar extends BotCompetent:
	var saved := {}
	func act() -> void:
		var h := sim.hour()
		if h == 17 and saved.is_empty():
			var free := 0
			for b in sim.st["buildings"]:
				if _res_of(b) == "carbon" and int(b["do"]) + int(b["di"]) > 0:
					saved[b["id"]] = [int(b["do"]), int(b["di"])]
					free += int(b["do"]) + int(b["di"])
					cmd({"c": "staff", "bid": b["id"], "o": 0, "i": 0, "n": 0})
			for b in sim.st["buildings"]:
				if free <= 0:
					break
				if _res_of(b) in ["madera", "metal"]:
					var mx := sim.staff_max(sim.bdef(b["type"]))
					var add := mini(free, mx - int(b["do"]) - int(b["di"]))
					if add > 0:
						cmd({"c": "staff", "bid": b["id"], "o": int(b["do"]) + add, "i": b["di"], "n": b["dn"]})
						free -= add
			return
		if h == 7 and not saved.is_empty():
			for bid in saved:
				cmd({"c": "staff", "bid": bid, "o": saved[bid][0], "i": saved[bid][1], "n": 0})
			saved.clear()
			last_plan = -99
		if saved.is_empty():
			super.act()
		else:
			_events()
			_requests()
			_generator()


## 3) Prender y apagar la sobrecarga para resetear el estrés.
class Sobrecarga extends BotCompetent:
	func act() -> void:
		super.act()
		if sim.st["gen"]["on"] == 1:
			cmd({"c": "gen_over", "v": 1 if sim.tick() % 2 == 0 else 0})
	func extra_metrics() -> Dictionary:
		return {"estres_final": int(sim.st["gen"]["stress"]) / FX.ONE}


## 4) Recargar la partida para cambiar resultados (el azar va dentro del guardado).
class Recargar extends BotCompetent:
	var reloads := 0
	var changed := 0
	func drive() -> void:
		if sim.hour() != 0:
			sim.step()
			return
		var saved := sim.serialize()
		var snap := _snapshot()
		var dead0: int = sim.st["dead"]
		var h1 := _play_day()
		if int(sim.st["dead"]) > dead0 and sim.st["status"] == "playing":
			# Hubo muertes: recargar (partida y memoria del bot) y volver a jugar el mismo día.
			sim.deserialize(saved)
			_restore(snap)
			reloads += 1
			var h2 := _play_day()
			if h2 != h1:
				changed += 1
	func _snapshot() -> Dictionary:
		var d := {}
		for p in get_property_list():
			if p["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE and not (p["name"] in ["sim", "reloads", "changed"]):
				d[p["name"]] = var_to_bytes(get(p["name"]))
		return d
	func _restore(d: Dictionary) -> void:
		for k in d:
			set(k, bytes_to_var(d[k]))
	func _play_day() -> String:
		act()
		sim.step()
		for i in 23:
			if sim.st["status"] != "playing":
				break
			act()
			sim.step()
		return sim.state_hash()
	func extra_metrics() -> Dictionary:
		return {"recargas": reloads, "resultados_distintos": changed}


## 5) Pausar o acelerar para alterar resultados.
class Velocidad extends BotCompetent:
	var clock: SimClock
	func drive() -> void:
		if clock == null:
			clock = SimClock.new()
			clock.sim = sim
			clock.max_steps_per_frame = 1
		clock.speed = brnd(4) # 0 = pausa
		var t0 := sim.tick()
		var guard := 0
		while sim.tick() == t0 and guard < 50:
			clock.speed = maxi(1, clock.speed)
			clock.advance_ms(1000 + brnd(20000))
			guard += 1


## 6) Spamear edificios baratos de esperanza y leyes.
class Esperanza extends BotCompetent:
	func act() -> void:
		super.act()
		var c := center()
		for t in ["capilla", "taberna", "guardia", "proclamas", "santuario", "banos"]:
			if sim.is_unlocked(t):
				try_build_near(t, c, c)
		for id in sim.db["laws"]:
			if not sim.db["laws"][id].get("extreme", false):
				cmd({"c": "law", "id": id})


## 7) Acumular sin límite (no gasta en desarrollo, solo junta).
class Acumular extends BotCompetent:
	func _wish(id: String) -> int:
		if id in ["upgrades", "late_spend", "social", "factory", "workshops", "storage"]:
			return 0
		return super._wish(id)
	func _research() -> void:
		if sim.day() > 12:
			return
		super._research()
	func extra_metrics() -> Dictionary:
		var w := 0
		for r in sim.st["wasted"]:
			w += int(sim.st["wasted"][r]) / FX.ONE
		return {"desperdicio": w}


## 8) Explotar pilas, bosques, zonas de caza o ubicaciones infinitas.
class Pilas extends BotCompetent:
	func act() -> void:
		super.act()
		if sim.hour() != 9:
			return
		# Un puesto extra en cada pila (aunque esté agotada) y gente en todos.
		for n in sim.st["nodes"]:
			var p := sim.find_spot_near("puesto_rec", n["x"], n["y"])
			if p.x >= 0 and sim.can_afford(sim.bdef("puesto_rec")["cost"]):
				cmd({"c": "build", "type": "puesto_rec", "x": p.x, "y": p.y})
		for b in buildings_of(["puesto_rec", "cazadores"], true):
			cmd({"c": "staff", "bid": b["id"], "o": 10, "i": 0, "n": 0})
		for id in sim.st["locs"]:
			for t in sim.st["teams"]:
				cmd({"c": "expedition", "bid": t["bid"], "loc": id})


## 9) Apagar el generador de noche.
class GeneradorNoche extends BotCompetent:
	func act() -> void:
		super.act()
		var h := sim.hour()
		if h >= 22 or h < 6:
			if sim.st["gen"]["on"] == 1:
				cmd({"c": "gen_on", "v": 0})
		elif sim.st["gen"]["on"] == 0:
			cmd({"c": "gen_on", "v": 1})
	func _generator() -> void:
		var h := sim.hour()
		if h >= 22 or h < 6:
			return
		super._generator()


## 10) Mover enfermos entre edificios para curarlos más rápido.
class Enfermos extends BotCompetent:
	func act() -> void:
		super.act()
		for b in buildings_of(["puesto_medico", "enfermeria"], true):
			cmd({"c": "toggle", "bid": b["id"], "on": sim.tick() % 2})
		if sim.hour() == 12:
			var meds := buildings_of(["puesto_medico"], true)
			if meds.size() > 0:
				var b: Dictionary = meds[0]
				var x: int = b["x"]
				var y: int = b["y"]
				if cmd({"c": "demolish", "bid": b["id"]}):
					cmd({"c": "build", "type": "puesto_medico", "x": x, "y": y})


## 11) Repetir eventos o expediciones para farmear.
class Repetir extends BotCompetent:
	var tries := 0
	var accepted := 0
	func act() -> void:
		var pend: Array = sim.st["ev_pending"].duplicate()
		super.act()
		# Intentar resolver dos veces el mismo evento y repetir viajes.
		for p in pend:
			for i in 3:
				tries += 1
				if cmd({"c": "event", "inst": p["inst"], "choice": i}):
					accepted += 1
		for id in sim.st["locs"]:
			if int(sim.st["locs"][id]["state"]) == 2:
				for t in sim.st["teams"]:
					tries += 1
					if cmd({"c": "expedition", "bid": t["bid"], "loc": id}):
						accepted += 1
	func extra_metrics() -> Dictionary:
		return {"intentos": tries, "aceptados": accepted}


## 12) Autómatas sin costo: pide autómatas sin núcleo/metal y asigna autómatas que no existen.
class Automatas extends BotCompetent:
	var free_tries := 0
	var free_ok := 0
	func act() -> void:
		super.act()
		var cost: Dictionary = sim.B["auto"]["cost"]
		for b in sim.st["buildings"]:
			if kind_of(b) == "factory" and not sim.can_afford(cost):
				for i in 3:
					free_tries += 1
					if cmd({"c": "auto_build", "bid": b["id"]}):
						free_ok += 1
			if int(sim.st["autos_free"]) == 0 and int(b["auto"]) == 0:
				free_tries += 1
				if cmd({"c": "auto_assign", "bid": b["id"], "v": 99}):
					free_ok += 1
	func extra_metrics() -> Dictionary:
		return {"intentos_gratis": free_tries, "aceptados": free_ok, "autos": int(sim.st["autos_total"]), "nucleos_usados": int(sim.st["obtained"]["nucleos"] - sim.st["res"]["nucleos"]) / FX.ONE}


## 13) Desbordes, negativos y duplicación por clics rápidos.
class Desbordes extends BotCompetent:
	func act() -> void:
		super.act()
		var big := 1 << 62
		var junk := [
			{"c": "staff", "bid": brnd(200), "o": big, "i": -big, "n": big},
			{"c": "gen_level", "v": big}, {"c": "gen_level", "v": -big},
			{"c": "build", "type": "carpa", "x": big, "y": -big},
			{"c": "auto_assign", "bid": brnd(200), "v": -big},
			{"c": "research", "id": 12345}, {"c": "law", "id": null},
			{"c": "event", "inst": big, "choice": -big},
			{"c": "expedition", "bid": -1, "loc": ""},
			{"c": "demolish", "bid": -big},
		]
		for c in junk:
			sim.command(c)
		# Doble clic: repetir la última construcción del bot 5 veces en el mismo lugar.
		var arr: Array = sim.st["buildings"]
		if arr.size() > 0:
			var b: Dictionary = arr[arr.size() - 1]
			for i in 5:
				sim.command({"c": "build", "type": b["type"], "x": b["x"], "y": b["y"]})
		for r in Simulation.RES:
			if sim.res(r) < 0:
				push_error("RECURSO NEGATIVO: " + r)


## 14) Diferencias PC/celular: misma semilla con cuadros de 33 ms a x3 y pausas
## (como un celular que va a segundo plano). Debe dar idéntico al competente.
class Plataforma extends BotCompetent:
	var clock: SimClock
	func drive() -> void:
		if clock == null:
			clock = SimClock.new()
			clock.sim = sim
			clock.max_steps_per_frame = 1
			clock.speed = 3
		var t0 := sim.tick()
		while sim.tick() == t0:
			clock.advance_ms(33)
