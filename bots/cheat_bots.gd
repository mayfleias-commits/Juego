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


## 2) Reasignar trabajadores al final del turno (doble conteo). Juega como el
## competente, pero a las 18, terminado el turno de día, manda a la gente de
## producción a los lugares libres de los edificios con turno largo y a cubrir los
## puestos médicos y los edificios sociales (que trabajan las 24 h) hasta llenarlos,
## y a las 7 los devuelve a producción para "trabajar dos veces". La producción es por
## hora trabajada y el viaje cuenta también en esos edificios: cada cambio cuesta el
## viaje (a la intemperie) y nadie rinde en dos lugares a la vez.
class Reasignar extends BotCompetent:
	var night := false
	var nights := 0
	var moved := 0
	func act() -> void:
		var h := sim.hour()
		if h == 18 and not night:
			night = true
			_night_shift()
		elif h == 7 and night:
			# Vuelven a producción: el competente reparte de nuevo a todos.
			night = false
			last_plan = -99
		super.act()
	func _staff() -> void:
		if night:
			return # de noche no se toca el reparto tramposo
		super._staff()
	## Terminado el turno de día, llena los médicos y sociales con la gente de producción.
	func _night_shift() -> void:
		var pool := {"o": 0, "i": 0}
		for b in sim.st["buildings"]:
			var k := kind_of(b)
			if k in ["gather", "extract", "convert", "greenhouse", "cook", "research", "factory"] and int(b["shift"]) == 0:
				var o: int = b["do"]
				var i: int = b["di"]
				if o + i > 0:
					pool["o"] += o
					pool["i"] += i
					cmd({"c": "staff", "bid": b["id"], "o": 0, "i": 0, "n": b["dn"]})
		var any := false
		for b in sim.st["buildings"]:
			var k := kind_of(b)
			var night_work := k in ["medical", "social"] or (int(b["shift"]) > 0 and k != "hunt")
			if b["state"] != 1 or b["on"] != 1 or not night_work:
				continue
			var d: Dictionary = sim.bdef(b["type"])
			var types := sim.staff_types(d)
			var room := sim.staff_max(d) - int(b["do"]) - int(b["di"]) - int(b["dn"])
			var ao := mini(room, pool["o"]) if "obreros" in types else 0
			var ai := mini(room - ao, pool["i"]) if "ingenieros" in types else 0
			if ao + ai > 0:
				pool["o"] -= ao
				pool["i"] -= ai
				moved += ao + ai
				any = true
				cmd({"c": "staff", "bid": b["id"], "o": int(b["do"]) + ao, "i": int(b["di"]) + ai, "n": b["dn"]})
		if any:
			nights += 1
	func extra_metrics() -> Dictionary:
		return {"noches": nights, "movidos": moved}


## 3) Prender y apagar la sobrecarga para resetear el estrés.
class Sobrecarga extends BotCompetent:
	func act() -> void:
		super.act()
		if sim.st["gen"]["on"] == 1:
			cmd({"c": "gen_over", "v": 1 if sim.tick() % 2 == 0 else 0})
	func extra_metrics() -> Dictionary:
		return {"estres_final": int(sim.st["gen"]["stress"]) / FX.ONE}


## 4) Recargar la partida para cambiar resultados. Ante un evento con azar (por
## ejemplo la presa: núcleo o un muerto) guarda, lo resuelve y mira el desenlace;
## después recarga (partida y memoria del bot) y prueba cambiar la suerte:
## resolverlo una hora más tarde, contestar antes el pedido pendiente o, sabiendo lo
## que pasa, elegir otra opción. Se queda con el mejor. El azar de cada evento se fija
## al aparecer y va en el guardado: esperar o cambiar el orden no cambia el desenlace.
class Recargar extends BotCompetent:
	var reloads := 0
	var changed := 0 # recargas en las que esperar o cambiar el orden dio otro desenlace
	var tries := 0
	var other_choice := 0 # veces que se quedó con otra opción por saber el desenlace
	func _events() -> void:
		for p in sim.st["ev_pending"].duplicate():
			var best := best_choice(p)
			if best < 0:
				continue
			if not _has_rand(sim.db["events"][p["id"]]["choices"][best].get("effects", [])):
				cmd({"c": "event", "inst": p["inst"], "choice": best})
				continue
			_try_luck(p, best)
	func _has_rand(effs: Array) -> bool:
		for e in effs:
			if e["k"] == "rand":
				return true
		return false
	func _try_luck(p: Dictionary, idx: int) -> void:
		tries += 1
		var saved := sim.serialize()
		var snap := _snapshot()
		var n_ch: int = (sim.db["events"][p["id"]]["choices"] as Array).size()
		# Intentos: [modo, opción]. Modo 0 = ahora, 1 = una hora después, 2 = tras el pedido.
		var plans := [[0, idx], [1, idx], [2, idx]]
		for j in n_ch:
			if j != idx:
				plans.append([0, j])
		var vals := []
		for k in plans.size():
			if k > 0:
				sim.deserialize(saved)
				_restore(snap)
				reloads += 1
			vals.append(_attempt(p, plans[k][0], plans[k][1]))
		for k in [1, 2]:
			if typeof(vals[k]) == TYPE_ARRAY and typeof(vals[0]) == TYPE_ARRAY and _sig(vals[k]) != _sig(vals[0]):
				changed += 1
		var best_k := 0
		for k in plans.size():
			if _value(vals[k]) > _value(vals[best_k]):
				best_k = k
		# Rehacer el mejor intento (todo es determinista).
		sim.deserialize(saved)
		_restore(snap)
		_attempt(p, plans[best_k][0], plans[best_k][1])
		if int(plans[best_k][1]) != idx:
			other_choice += 1
	## Resuelve el evento según el modo y devuelve el desenlace (cambios inmediatos).
	func _attempt(p: Dictionary, mode: int, choice: int):
		if mode == 1:
			sim.step()
		elif mode == 2:
			if (sim.st["req"]["offer"] as Dictionary).is_empty():
				return null
			_requests()
		if sim.st["status"] != "playing":
			return null
		var before := _outcome()
		if not cmd({"c": "event", "inst": p["inst"], "choice": choice}):
			return null
		var after := _outcome()
		var d := []
		for i in before.size():
			d.append(int(after[i]) - int(before[i]))
		return d
	## Estado que pueden tocar los efectos de un evento (se compara antes y después).
	func _outcome() -> Array:
		var o := [int(sim.st["dead"]), sim.total_sick(), incoming_people(), int(sim.st["hope"]), int(sim.st["disc"]),
			(sim.st["flags"] as Dictionary).size(), (sim.st["ev_sched"] as Array).size()]
		for r in Simulation.RES:
			o.append(sim.res(r))
		return o
	## Desenlace como signos de cada cambio (no lo afectan los topes de los almacenes).
	func _sig(d: Array) -> Array:
		var out := []
		for x in d:
			out.append(signi(int(x)))
		return out
	func _value(d) -> int:
		if typeof(d) != TYPE_ARRAY:
			return -(1 << 40)
		var v: int = -150 * int(d[0]) - 20 * int(d[1]) + 20 * int(d[2]) + int(d[3]) * 40 / FX.ONE - int(d[4]) * 30 / FX.ONE
		for i in Simulation.RES.size():
			v += int(d[7 + i]) * int(weights.get(Simulation.RES[i], 3)) / FX.ONE
		return v
	func _snapshot() -> Dictionary:
		var d := {}
		for p in get_property_list():
			if p["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE and not (p["name"] in ["sim", "reloads", "changed", "tries", "other_choice"]):
				d[p["name"]] = var_to_bytes(get(p["name"]))
		return d
	func _restore(d: Dictionary) -> void:
		for k in d:
			set(k, bytes_to_var(d[k]))
	func extra_metrics() -> Dictionary:
		return {"intentos": tries, "recargas": reloads, "resultados_distintos": changed, "otra_opcion": other_choice}


## 5) Pausar o acelerar para alterar resultados. Avanza con el reloj real del juego
## (hasta 3 pasos por cuadro, como en Session) alternando al azar cuadros en pausa
## con x1, x2 y x3 y cuadros de 16 a 250 ms. Da sus órdenes en los cuadros en pausa
## cuando le toca uno antes del paso (si no, justo antes del paso). La simulación solo
## avanza de a pasos enteros, así que debe terminar igual que el competente.
class Velocidad extends BotCompetent:
	var clock: SimClock
	var acted_tick := -1
	var frames := 0
	var paused := 0
	var paused_orders := 0
	var speed_changes := 0
	func _act_once() -> void:
		if acted_tick != sim.tick():
			acted_tick = sim.tick()
			act()
	func drive() -> void:
		if clock == null:
			clock = SimClock.new()
			clock.sim = sim
			clock.max_steps_per_frame = 3
			clock.pre_step = _act_once
		var t0 := sim.tick()
		var guard := 0
		while sim.tick() == t0 and sim.st["status"] == "playing" and guard < 2000:
			guard += 1
			frames += 1
			var sp := brnd(4) # 0 = pausa
			if sp != clock.speed:
				speed_changes += 1
			clock.speed = sp
			if sp == 0:
				paused += 1
				if acted_tick != sim.tick():
					paused_orders += 1
				_act_once() # órdenes con el juego en pausa
			clock.advance_ms(16 + brnd(235))
	func extra_metrics() -> Dictionary:
		return {"cuadros": frames, "en_pausa": paused, "ordenes_en_pausa": paused_orders, "cambios_velocidad": speed_changes}


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


## 7) Acumular sin límite. Juega como el competente (se desarrolla e investiga igual),
## pero amplía almacenes en cuanto un recurso pasa del 60 % (depósitos y carboneras
## de más, sin tope) y no gasta los excedentes en mejoras opcionales ni en convertir
## madera hasta la tormenta final (día 52), cuando recién los usa.
class Acumular extends BotCompetent:
	var stores := 0
	var peak := {}
	func act() -> void:
		super.act()
		for r in Simulation.RES:
			peak[r] = maxi(int(peak.get(r, 0)), sim.res(r) / FX.ONE)
	func _wish(id: String) -> int:
		var hoard := sim.day() < 52
		if hoard and id in ["upgrades", "late_spend", "kiln_surplus"]:
			return 0
		if id == "storage":
			for r in ["carbon", "madera", "metal", "crudo", "raciones"]:
				if sim.res(r) * 100 / maxi(1, sim.cap(r)) > 60:
					var r2 := _build("carbonera" if r == "carbon" else "deposito", center() - 8, center() + 8)
					if r2 == 1:
						stores += 1
					return r2
		return super._wish(id)
	func extra_metrics() -> Dictionary:
		var w := 0
		for r in sim.st["wasted"]:
			w += int(sim.st["wasted"][r]) / FX.ONE
		return {"desperdicio": w, "almacenes_extra": stores, "stock_maximo": peak}


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


## 14) Diferencias PC/celular: misma semilla avanzando como un celular (cuadros de
## 33 ms a x3, hasta 3 pasos por cuadro y órdenes justo antes de cada paso) que de vez
## en cuando pasa a segundo plano (pausa) y al volver recibe un cuadro largo.
## Debe dar idéntico al competente.
class Plataforma extends BotCompetent:
	var clock: SimClock
	var background := 0
	func drive() -> void:
		if clock == null:
			clock = SimClock.new()
			clock.sim = sim
			clock.max_steps_per_frame = 3
			clock.pre_step = act
			clock.speed = 3
		var t0 := sim.tick()
		var guard := 0
		while sim.tick() == t0 and sim.st["status"] == "playing" and guard < 2000:
			guard += 1
			if brnd(300) == 0:
				background += 1
				clock.speed = 0
				clock.advance_ms(5000)
				clock.speed = 3
				clock.advance_ms(1500 + brnd(3000))
			else:
				clock.advance_ms(33)
	func extra_metrics() -> Dictionary:
		return {"segundo_plano": background}
