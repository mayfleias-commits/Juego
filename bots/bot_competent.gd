class_name BotCompetent
extends BotBase
## Bot competente: juega como un jugador cuidadoso. Planifica vivienda, comida,
## carbón, salud e investigación según el pronóstico; usa leyes con criterio y
## evita las extremas salvo emergencia. Sirve de referencia para el balance.

var research_order := [
	"rec_extractor", "viv_barracones", "cal_conductos", "rec_aserradero", "com_invernadero",
	"sal_higiene", "exp_faro", "rec_mina_hierro", "cal_fieltro", "cal_valvulas", "viv_casas",
	"cal_calefactores", "sal_enfermeria", "com_trampas", "cal_combustion",
	"cal_red", "rec_herramientas", "cal_paneles", "rec_fundicion", "rec_perforadora",
	"exp_trineos", "rec_pozo", "cal_sobrepresion", "exp_cartografia", "aut_fabrica", "sal_antisepticos",
	"cal_anillo", "com_invernadero_ind", "rec_horno", "exp_profundas",
	"cal_estaciones", "rec_maquinaria", "sal_cirugia", "cal_calderas", "aut_reforzados",
	"com_cocina_vapor", "rec_logistica", "exp_rutas",
]
var path := "fe"
var ignore_wave := 0 # variante: no prepararse para la oleada N (1..5)
var stop_dev_day := 999 # variante: dejar de construir/investigar desde este día
var reserved := {}
var _last_cost := {}

## ¿Alcanza el costo sin tocar lo reservado para deseos críticos?
var CORE_RESERVE := 2

func affordable(cost: Dictionary) -> bool:
	for r in cost:
		if r == "nucleos":
			if res_units("nucleos") < int(cost[r]) + CORE_RESERVE:
				return false
			continue
		if res_units(r) - int(reserved.get(r, 0)) < int(cost[r]):
			return false
	return true

## Devuelve 2 (bloqueado) y anota el costo para reservarlo, o 0 si falta un núcleo (no reservable).
func _blocked(cost: Dictionary) -> int:
	if int(cost.get("nucleos", 0)) + CORE_RESERVE > res_units("nucleos"):
		return 0
	_last_cost = cost
	return 2
var last_plan := -99
var weights := {"carbon": 3, "madera": 4, "metal": 8, "nucleos": 400, "crudo": 5, "raciones": 3}

func _init() -> void:
	name = "competente"

func act() -> void:
	CORE_RESERVE = 2 if int(sim.st["obtained"]["nucleos"]) >= 9 * FX.ONE else 1
	_events()
	_requests()
	_generator()
	var t := sim.tick()
	var dev := sim.day() < stop_dev_day
	if t - last_plan >= 3:
		last_plan = t
		if dev:
			_cleanup()
			_plan_builds()
		_staff()
	if dev:
		_research()
		_laws()
		_explore()
		_automatons()

# ================================================================ estimaciones
func pop() -> int:
	return sim.total_pop()

func coal_need_day() -> int:
	var g: Dictionary = sim.st["gen"]
	var per_h := sim.gen_coal_per_hour(maxi(1, int(g["level"])), int(g["over"]))
	var n := per_h * 24
	for b in sim.st["buildings"]:
		var d: Dictionary = sim.bdef(b["type"])
		var k: String = d.get("kind", "")
		if k == "station" and b["on"] == 1:
			n += int(d["coal_m"]) * 24
		elif k == "greenhouse":
			n += int(d["coal_m"]) * 10
		n += int(b["auto"]) * int(sim.B["auto"]["coal_m"]) * 24
	if int(g["heaters"]) == 1:
		n += housing_count() * int(sim.B["heat"]["heater_coal_m"]) * 24
	return n / FX.ONE

func housing_count() -> int:
	var n := 0
	for b in sim.st["buildings"]:
		if int(sim.bdef(b["type"]).get("housing", 0)) > 0:
			n += 1
	return n

var _pot_cache := {}
var _pot_tick := -1

## Producción diaria potencial (unidades) de un recurso con el personal actual.
func potential(r: String) -> int:
	if _pot_tick != sim.tick():
		_pot_tick = sim.tick()
		_pot_cache = {}
	if _pot_cache.has(r):
		return _pot_cache[r]
	var v := _potential(r)
	_pot_cache[r] = v
	return v

func _potential(r: String) -> int:
	var total := 0
	var om := sim.outdoor_mult(sim.temp_at(sim.day(), 12))
	for b in sim.st["buildings"]:
		var d: Dictionary = sim.bdef(b["type"])
		var k: String = d.get("kind", "")
		var staff: int = int(b["o"]) + int(b["i"]) + int(b["n"])
		if k == "extract" and d["res"] == r and sim.st["sites"][b["site"]]["amt"] > 0:
			total += staff * int(d["rate_m"]) * 10 / FX.ONE * om / FX.ONE
		elif k == "gather" and _post_target(b) == r:
			total += staff * int(d["rates_m"][r]) * 10 / FX.ONE * om / FX.ONE
		elif k == "convert" and d["out"] == r:
			total += staff * int(d["out_m"]) * 10 / FX.ONE
		if int(b["auto"]) > 0 and k == "extract" and d["res"] == r:
			total += int(b["auto"]) * int(sim.B["auto"]["eq_m"]) * int(d["rate_m"]) * 24 / FX.ONE / FX.ONE
	return total

func _post_target(b: Dictionary) -> String:
	var f: String = b.get("focus", "auto")
	for nid in b["nodes"]:
		var n0: Dictionary = sim.st["nodes"][nid]
		if n0["amt"] > 0 and (f == "auto" or n0["kind"] == f):
			return n0["kind"]
	if f != "auto":
		return ""
	for nid in b["nodes"]:
		var n: Dictionary = sim.st["nodes"][nid]
		if n["amt"] > 0:
			return n["kind"]
	return ""

func node_left(r: String) -> int:
	var t := 0
	for n in sim.st["nodes"]:
		if n["kind"] == r:
			t += int(n["amt"])
	return t / FX.ONE

func hunt_stock_pct() -> int:
	var s := 0
	var m := 0
	for z in sim.st["hunt"]:
		s += int(z["stock"])
		m += int(z["max"])
	return s * 100 / maxi(1, m)

func _wave_len() -> int:
	var w := sim.wave_next(sim.day())
	if w.is_empty() or int(w["id"]) == ignore_wave:
		return 0
	return (w["profile"] as Array).size()

func days_to_wave() -> int:
	var w := sim.wave_next(sim.day())
	if w.is_empty():
		return 99
	return int(w["start"]) - sim.day()

func idle(c: String) -> int:
	return int(sim.st.get("idle", {}).get(c, 0))

func workers_total() -> int:
	return sim.healthy("obreros") + sim.healthy("ingenieros")

func staff_slots(kinds: Array) -> int:
	var n := 0
	for b in sim.st["buildings"]:
		var d: Dictionary = sim.bdef(b["type"])
		if d.get("kind", "") in kinds:
			n += sim.staff_max(d)
	return n

## Carbón total que queda (stock + pilas + yacimientos) frente a lo que falta de partida.
func coal_reserve() -> int:
	var t := res_units("carbon") + node_left("carbon")
	for st2 in sim.st["sites"]:
		if st2["kind"] in ["veta_carbon", "veta_profunda"]:
			t += int(st2["amt"]) / FX.ONE
	return t

## Carbón que conviene tener almacenado al empezar la próxima oleada.
func wave_coal_target() -> int:
	var w := sim.wave_next(sim.day() - 1)
	var cur := sim.wave_on(sim.day())
	if not cur.is_empty():
		w = cur
	if w.is_empty() or int(w["id"]) == ignore_wave:
		return 0
	var ins := _min_house_insul() + (int(sim.B["heat"]["heater_heat"]) if sim.mod("heaters") > 0 else 0)
	var mx := sim.gen_max_level()
	var total := 0
	var start: int = w["start"]
	var prof: Array = w["profile"]
	for i in prof.size():
		var d: int = start + i
		if d < sim.day():
			continue
		var tmin := 999
		for h in 24:
			tmin = mini(tmin, sim.temp_at(d, h))
		var need := -20 - (tmin + ins)
		var lvl := clampi((need + 7) / 8, 1, mx)
		var over := 1 if need > int(sim.B["gen"]["heat"][mx]) else 0
		total += sim.gen_coal_per_hour(lvl, over) * 24 / FX.ONE
	# Lo que siguen produciendo los edificios de interior (pozo profundo, hornos).
	var indoor := 0
	for b in sim.st["buildings"]:
		if b["type"] in ["mina_profunda", "horno_carbon"]:
			indoor += 1
	return maxi(0, total * 110 / 100 - indoor * 150 * prof.size())

var _frugal_tick := -1
var _frugal := false

func frugal() -> bool:
	if _frugal_tick == sim.tick():
		return _frugal
	_frugal_tick = sim.tick()
	var days_left: int = int(sim.B["days"]) - sim.day() + 1
	_frugal = coal_reserve() < days_left * coal_need_day() * 13 / 10
	return _frugal

# ================================================================ generador
func _min_house_insul() -> int:
	var m := 99
	for b in sim.st["buildings"]:
		var d: Dictionary = sim.bdef(b["type"])
		if int(d.get("housing", 0)) > 0 and b["state"] == 1:
			m = mini(m, int(d.get("insul", 0)))
	if m == 99:
		m = 0
	return m + sim.mod("heat_housing")

func _coldest_ahead(hours: int) -> int:
	var tmin := 999
	var d := sim.day()
	var h := sim.hour()
	for i in hours:
		tmin = mini(tmin, sim.temp_at(d, h))
		h += 1
		if h >= 24:
			h = 0
			d += 1
	return tmin

func _ignoring_wave() -> bool:
	if ignore_wave <= 0:
		return false
	var w := sim.wave_on(sim.day())
	return not w.is_empty() and int(w["id"]) == ignore_wave

func _generator() -> void:
	var g: Dictionary = sim.st["gen"]
	var coal := sim.res("carbon")
	if _ignoring_wave():
		# Variante "ignorar oleada": se sigue como un día normal.
		if int(g["on"]) == 0 and coal >= int(sim.B["gen"]["ignite_coal_m"]) + sim.gen_coal_per_hour(1, 0) * 2:
			cmd({"c": "gen_on", "v": 1})
		if int(g["level"]) != 1:
			cmd({"c": "gen_level", "v": 1})
		if int(g["over"]) == 1:
			cmd({"c": "gen_over", "v": 0})
		if int(g["heaters"]) == 1:
			cmd({"c": "heaters", "v": 0})
		return
	if int(g["on"]) == 0:
		if coal >= int(sim.B["gen"]["ignite_coal_m"]) + sim.gen_coal_per_hour(1, 0) * 2:
			cmd({"c": "gen_on", "v": 1})
		return
	var tmin := _coldest_ahead(6)
	var ins := _min_house_insul()
	var heaters_on := int(g["heaters"]) == 1
	var extra := int(sim.B["heat"]["heater_heat"]) if heaters_on else 0
	var coal_days := coal * 24 / maxi(1, sim.gen_coal_per_hour() * 24) # en horas
	var saving := days_to_wave() <= 8 and not sim.in_wave() and res_units("carbon") < wave_coal_target()
	var target := -10 if (coal_days > 36 and not frugal() and not saving) else -20
	var need := target - (tmin + ins + extra)
	var mx := sim.gen_max_level()
	var step: int = maxi(1, int(sim.B["gen"]["heat"][1]))
	var lvl := clampi((need + step - 1) / step, 1, mx)
	# No vaciar el depósito: si queda poco carbón, bajar potencia.
	while lvl > 1 and coal < sim.gen_coal_per_hour(lvl, 0) * 8:
		lvl -= 1
	if lvl != int(g["level"]):
		cmd({"c": "gen_level", "v": lvl})
	var max_heat: int = int(sim.B["gen"]["heat"][mx])
	var want_over := need > max_heat and int(g["stress"]) < 55 * FX.ONE and coal > sim.gen_coal_per_hour(mx, 1) * 10
	if int(g["over"]) == 1 and (int(g["stress"]) > 80 * FX.ONE or need <= max_heat - 5):
		cmd({"c": "gen_over", "v": 0})
	elif int(g["over"]) == 0 and want_over:
		cmd({"c": "gen_over", "v": 1})
	# Calefactores
	if sim.mod("heaters") > 0:
		var want_heat := tmin + ins + int(sim.B["gen"]["heat"][lvl]) < -12 and coal_days > 24
		if want_heat != heaters_on:
			cmd({"c": "heaters", "v": 1 if want_heat else 0})

# ================================================================ construcción
func _cleanup() -> void:
	# Reorientar puestos cuyo recurso se agotó; demoler los que ya no tienen pilas
	# y los extractores de yacimientos agotados (recupera 50%).
	for b in sim.st["buildings"].duplicate():
		var d: Dictionary = sim.bdef(b["type"])
		var k: String = d.get("kind", "")
		if k == "gather" and b["state"] == 1 and _post_target(b) == "":
			var best := ""
			var ba := 0
			for nid in b["nodes"]:
				var n: Dictionary = sim.st["nodes"][nid]
				var val: int = int(n["amt"]) * (3 if n["kind"] != "carbon" else 1)
				if n["amt"] > 0 and val > ba:
					ba = val
					best = n["kind"]
			if best != "":
				cmd({"c": "focus", "bid": b["id"], "v": best})
			else:
				cmd({"c": "demolish", "bid": b["id"]})
		elif k == "extract" and b["state"] == 1 and int(sim.st["sites"][b["site"]]["amt"]) <= 0:
			cmd({"c": "demolish", "bid": b["id"]})

## Planificador por deseos: cada deseo devuelve 0 (no hace falta), 1 (construido)
## o 2 (hace falta pero no alcanza). Si un deseo crítico queda bloqueado se
## detiene la planificación para no gastar en cosas menos importantes.
func _plan_builds() -> void:
	var wishes := [
		["coal", true], ["wood", true], ["metal_min", true], ["cook", true], ["food", true], ["housing_half", true],
		["workshop1", true], ["medical1", true], ["burial", true], ["housing", true],
		["food2", false], ["medical", false], ["metal", false], ["factory", false], ["workshops", false],
		["end_reserve", false], ["storage", false], ["faro", false], ["shelter", false], ["social", false],
		["upgrades", false], ["coal_buffer", false], ["kiln_surplus", false], ["wood2", false], ["late_spend", false],
	]
	reserved = {}
	for w in wishes:
		_last_cost = {}
		var r := _wish(w[0])
		if r == 2 and w[1]:
			# Reservar lo que falta para el deseo crítico y seguir con los demás.
			for k in _last_cost:
				reserved[k] = int(reserved.get(k, 0)) + int(_last_cost[k])

func _wish(id: String) -> int:
	var P := pop()
	var c := center()
	match id:
		"coal":
			if potential("carbon") < coal_need_day() * 115 / 100 + 15:
				return _add_producer("carbon")
		"kiln_surplus":
			if res_units("madera") > 350 and sim.is_unlocked("horno_carbon") and buildings_of(["horno_carbon"]).size() < 3:
				return _build("horno_carbon", c, c)
		"coal_buffer":
			if potential("carbon") < coal_need_day() * 140 / 100 + 30 and days_to_wave() <= 6:
				return _add_producer("carbon")
		"wood":
			if potential("madera") < 40 + P / 5:
				return _add_producer("madera")
		"wood2":
			if potential("madera") < 70 + P / 3:
				return _add_producer("madera")
		"metal":
			if potential("metal") < 30 + P / 6:
				return _add_producer("metal")
		"metal_min":
			if potential("metal") < 12 and sim.day() >= 2:
				return _add_producer("metal")
		"cook":
			if buildings_of(["cocina"]).size() < maxi(1, (P + 60) / 100):
				return _build("cocina", c, c)
		"food", "food2":
			var hunters := buildings_of(["cazadores"]).size()
			var greenh := buildings_of(["invernadero"]).size()
			var greenh2 := buildings_of(["invernadero_ind"]).size()
			var hp := hunt_stock_pct()
			var food_cap := hunters * 60 * mini(100, hp * 2) / 100 + greenh * 45 + greenh2 * 85
			var need := P + 8 if id == "food" else P + 25
			# Antes de una oleada (sin caza) hace falta producir de más para acumular.
			var dw := days_to_wave()
			if dw <= 6:
				var wl := _wave_len()
				var stock := res_units("raciones") + res_units("crudo") * 2
				var gap := P * (wl + 1) - stock
				if gap > 0:
					need += gap / maxi(1, dw)
			if food_cap < need and (_labor_ok(6) or id == "food"):
				if hp > 35 and hunters < 4 and (hunters < 2 or days_to_wave() > 4):
					return _build("cazadores", c + 6, c - 6)
				if sim.is_unlocked("invernadero_ind") and res_units("nucleos") >= 2:
					return _build("invernadero_ind", c, c)
				if sim.is_unlocked("invernadero"):
					return _build("invernadero", c, c)
				if hunters < 5:
					return _build("cazadores", c + 6, c - 6)
		"housing_half", "housing":
			var need_beds := P + incoming_people() + 2
			if id == "housing_half":
				need_beds = need_beds * 6 / 10
			var cap := housing_capacity(true)
			var guard := 0
			while cap < need_beds and guard < 5:
				guard += 1
				var t := "carpa"
				if sim.is_unlocked("barracon") and res_units("madera") >= 60 and res_units("metal") >= 20:
					t = "barracon"
				var r := _build(t, c, c)
				if r != 1:
					return r
				cap += 10
		"workshop1":
			if buildings_of(["taller"]).is_empty():
				return _build("taller", c, c)
		"workshops":
			var eng := sim.healthy("ingenieros")
			var want_shops := clampi((eng - 2) / 5, 1, 4)
			if sim.day() < 4:
				want_shops = 1
			if buildings_of(["taller"]).size() < want_shops:
				return _build("taller", c, c)
		"medical1":
			if _beds_total() == 0 and (sim.total_sick() > 0 or sim.day() >= 2):
				return _build("puesto_medico", c, c)
		"medical":
			var beds := _beds_total()
			var bed_target := maxi(6, sim.total_sick() + P * 4 / 100)
			if days_to_wave() <= 3:
				bed_target += P * 4 / 100
			if beds < bed_target:
				if sim.is_unlocked("enfermeria") and sim.healthy("ingenieros") >= 14:
					return _build("enfermeria", c, c)
				return _build("puesto_medico", c, c)
		"burial":
			if int(sim.st["bodies"]) > 0 or int(sim.st["dead"]) > 0:
				var cap_left := 0
				for b in buildings_of(["cementerio", "fosa"]):
					cap_left += int(sim.bdef(b["type"])["graves"])
				cap_left -= int(sim.st["buried"])
				if cap_left < int(sim.st["bodies"]) + 3:
					if sim.is_unlocked("cementerio"):
						return _build("cementerio", c + 12, c + 12)
					if sim.is_unlocked("fosa"):
						return _build("fosa", c + 12, c + 12)
		"storage":
			for r in ["carbon", "madera", "metal", "raciones"]:
				if sim.res(r) * 100 / maxi(1, sim.cap(r)) > 85:
					return _build("carbonera" if r == "carbon" else "deposito", c - 8, c + 8)
			if days_to_wave() <= 10 and sim.cap("carbon") / FX.ONE < wave_coal_target() + 100:
				return _build("carbonera", c - 8, c + 8)
		"faro":
			if sim.is_unlocked("faro") and buildings_of(["faro"]).size() < (2 if sim.day() > 20 else 1):
				return _build("faro", c + 8, c)
		"shelter":
			if sim.is_unlocked("refugio_inf") and buildings_of(["refugio_inf"]).size() * 15 < sim.healthy("ninos"):
				return _build("refugio_inf", c, c)
		"social":
			_social_builds()
		"factory":
			if sim.is_unlocked("fabrica_aut") and buildings_of(["fabrica_aut"]).is_empty() and res_units("nucleos") >= 1:
				return _build("fabrica_aut", c, c)
		"end_reserve":
			# Recta final: guardar una reserva de madera para emergencias.
			if sim.day() >= 46:
				reserved["madera"] = int(reserved.get("madera", 0)) + int(sim.st["obtained"]["madera"]) / FX.ONE * 16 / 100
		"late_spend":
			# Recta final: invertir excedentes en mejoras de vivienda y producción.
			if sim.day() >= 38 and res_units("metal") > 120:
				_upgrades()
				if sim.is_unlocked("invernadero_ind") and res_units("nucleos") >= 2 and res_units("metal") > 150:
					return _build("invernadero_ind", c, c)
		"upgrades":
			_upgrades()
	return 0

func _build(type: String, x: int, y: int) -> int:
	if not sim.is_unlocked(type):
		return 0
	var cost: Dictionary = sim.bdef(type).get("cost", {})
	if not affordable(cost):
		return _blocked(cost)
	return 1 if not try_build_near(type, x, y).is_empty() else 0

var flex := 0 # trabajadores en puestos "extra" (baja prioridad) que se pueden mover

func _labor_ok(n: int) -> bool:
	return idle("obreros") + idle("ingenieros") + flex >= n or sim.day() <= 2

func _beds_total() -> int:
	var n := 0
	for b in sim.st["buildings"]:
		var d: Dictionary = sim.bdef(b["type"])
		if d.get("kind", "") == "medical":
			n += int(d["beds"])
	return n

func _upgrades() -> void:
	var wood := res_units("madera")
	var metal := res_units("metal")
	var urgent := days_to_wave() <= 5
	var n := 0
	for b in sim.st["buildings"]:
		if n >= (3 if urgent else 1):
			break
		if b["state"] != 1 or b["up"] != "":
			continue
		var nt: String = sim.bdef(b["type"]).get("upgrade_to", "")
		if nt == "" or not sim.is_unlocked(nt):
			continue
		var cost := sim.upgrade_cost(b)
		var reserve_w := 30 if not urgent else 10
		if wood - int(cost.get("madera", 0)) < reserve_w or metal - int(cost.get("metal", 0)) < 10:
			continue
		if cmd({"c": "upgrade", "bid": b["id"]}):
			n += 1
			wood = res_units("madera")
			metal = res_units("metal")

func _add_producer(r: String) -> int:
	var c := center()
	var blocked := false
	match r:
		"carbon":
			for t in ["extractor", "mina_profunda"]:
				var rr := _site_build(t)
				if rr == 1:
					return 1
				blocked = blocked or rr == 2
			var rp := _build_post_for("carbon") if _labor_ok(6) else 0
			if rp == 1:
				return 1
			blocked = blocked or rp == 2
			if res_units("madera") > 120 and buildings_of(["horno_carbon"]).size() < 1 + res_units("madera") / 300:
				return _build("horno_carbon", c, c)
		"madera":
			for t in ["aserradero", "perforadora"]:
				var rr := _site_build(t)
				if rr == 1:
					return 1
				blocked = blocked or rr == 2
			var rp := _build_post_for("madera") if _labor_ok(6) else 0
			if rp == 1:
				return 1
			blocked = blocked or rp == 2
		"metal":
			var rr := _site_build("mina_hierro")
			if rr == 1:
				return 1
			blocked = blocked or rr == 2
			var rp := _build_post_for("metal") if _labor_ok(6) else 0
			if rp == 1:
				return 1
			blocked = blocked or rp == 2
			if sim.is_unlocked("fundicion") and buildings_of(["fundicion"]).size() < 2 and res_units("carbon") > 300 and not frugal():
				return _build("fundicion", c, c)
	return 2 if blocked else 0

func _site_build(type: String) -> int:
	if not sim.is_unlocked(type):
		return 0
	if sim.free_sites(sim.bdef(type)["site"]).is_empty():
		return 0
	var cost: Dictionary = sim.bdef(type).get("cost", {})
	var wood_prod: bool = sim.bdef(type).get("res", "") == "madera"
	if not (sim.can_afford(cost) if wood_prod else affordable(cost)):
		return _blocked(cost)
	return 1 if not try_build_site(type).is_empty() else 0

func _build_post_for(r: String) -> int:
	# Pila con más recurso que no esté ya cubierta por un puesto.
	var covered := {}
	for b in buildings_of(["puesto_rec"]):
		for nid in b["nodes"]:
			covered[nid] = true
	var best: Dictionary = {}
	for n in sim.st["nodes"]:
		if n["kind"] != r or n["amt"] <= 0 or covered.has(n["id"]):
			continue
		if best.is_empty() or n["amt"] > best["amt"]:
			best = n
	if best.is_empty():
		return 0
	var pc: Dictionary = sim.bdef("puesto_rec")["cost"]
	if not (sim.can_afford(pc) if r == "madera" else affordable(pc)):
		return _blocked(pc)
	var b := try_build_near("puesto_rec", best["x"], best["y"])
	if b.is_empty():
		return 0
	cmd({"c": "focus", "bid": b["id"], "v": r})
	return 1

func _social_builds() -> void:
	var c := center()
	var hope: int = sim.st["hope"] / FX.ONE
	var disc: int = sim.st["disc"] / FX.ONE
	if not _labor_ok(3):
		return
	if hope < 55:
		for t in ["templo", "capilla", "proclamas", "santuario"]:
			var lim := 1 if t == "templo" else 2
			if sim.is_unlocked(t) and buildings_of([t]).size() < lim:
				if not try_build_near(t, c, c).is_empty():
					return
	if disc > 30:
		for t in ["guardia", "taberna", "santuario", "prision", "torre_vigia", "banos"]:
			if sim.is_unlocked(t) and buildings_of([t]).size() < 1:
				if not try_build_near(t, c, c).is_empty():
					return

# ================================================================ personal
## Producción diaria esperada por trabajador en un edificio (unidades, aprox.).
func per_worker_day(b: Dictionary) -> int:
	var d: Dictionary = sim.bdef(b["type"])
	var k: String = d.get("kind", "")
	var om := sim.outdoor_mult(sim.temp_at(sim.day(), 12))
	var hours := 14 if int(b["shift"]) == 1 else 10
	match k:
		"extract":
			if int(sim.st["sites"][b["site"]]["amt"]) <= 0:
				return 0
			var m := om if d.get("outdoor", false) else FX.ONE
			return int(d["rate_m"]) * hours * m / FX.ONE / FX.ONE * (100 + sim.mod("prod_" + str(d["res"]) + "_pct")) / 100
		"gather":
			var r := _post_target(b)
			if r == "":
				return 0
			return int(d["rates_m"][r]) * hours * om / FX.ONE / FX.ONE
		"convert":
			return int(d["out_m"]) * hours / FX.ONE
		"greenhouse":
			return int(d["rate_m"]) * hours / FX.ONE
		"hunt":
			if hunt_stock_pct() < 3 or sim.in_wave():
				return 0
			return int(sim.B["food"]["hunt_trip_m"]) * om / FX.ONE / FX.ONE
	return 0

## Reserva "sana" de un recurso: ~18% de lo obtenido (con un mínimo).
func _reserve_of(r: String) -> int:
	var ob: int = int(sim.st["obtained"][r]) / FX.ONE
	match r:
		"madera":
			return ob * 18 / 100 + 150
		"metal":
			return ob * 18 / 100 + 100
		"carbon":
			return maxi(ob * 18 / 100, wave_coal_target() + 300)
	return 0

func _res_of(b: Dictionary) -> String:
	var d: Dictionary = sim.bdef(b["type"])
	match d.get("kind", ""):
		"extract":
			return d["res"]
		"gather":
			return _post_target(b)
		"convert":
			return d["out"]
		"greenhouse", "hunt":
			return "crudo"
	return ""

func _staff() -> void:
	var P := pop()
	var ratio := sim.cook_ratio() / FX.ONE
	var coal_stock_days := sim.res("carbon") / maxi(1, coal_need_day() * FX.ONE)
	var needs := {
		"crudo": (P + 6) / maxi(1, ratio) + 4,
		"carbon": coal_need_day() * 110 / 100 + (coal_need_day() / 2 if coal_stock_days < 2 else 0),
		"madera": maxi(0 if res_units("madera") > 600 else 15, 40 + P / 6 + (300 - res_units("madera")) / 4),
		"metal": maxi(0 if res_units("metal") > 250 else 15, 25 + P / 6 + (150 - res_units("metal")) / 3),
	}
	var food_days := (res_units("raciones") / maxi(1, ratio) + res_units("crudo")) * ratio / maxi(1, P)
	if days_to_wave() > 6 or sim.wave_next(sim.day()).is_empty():
		if food_days > 6:
			needs["crudo"] = 0
		elif food_days > 3:
			needs["crudo"] = needs["crudo"] / 2
	var dw := days_to_wave()
	if dw <= 9 and not sim.in_wave():
		var gap := wave_coal_target() - res_units("carbon")
		if gap > 0:
			needs["carbon"] += gap / maxi(1, dw)
		# Comida para aguantar la oleada sin caza (en crudo equivalente).
		var food_stock := res_units("raciones") / maxi(1, ratio) + res_units("crudo")
		var gh_day := 0
		for gb in buildings_of(["invernadero", "invernadero_ind"], true):
			gh_day += int(sim.bdef(gb["type"])["rate_m"]) * 10 * (int(gb["o"]) + int(gb["i"]) + int(gb["n"])) / FX.ONE
		var extra_days := -1 if int(sim.wave_next(sim.day()).get("id", 0)) == (sim.db["climate"]["waves"] as Array).size() else 1
		var fgap := (P * (_wave_len() + extra_days)) / maxi(1, ratio) - food_stock - gh_day * _wave_len()
		if fgap > 0:
			needs["crudo"] += fgap / maxi(1, dw)
	var ess_score := {"crudo": 96, "carbon": 95, "madera": 78, "metal": 80}
	var extra_score := {"crudo": 40, "carbon": 55, "madera": 45, "metal": 52}
	# Sin trabajo "extra" cuando ya sobra ese recurso.
	if res_units("metal") > 250:
		extra_score["metal"] = 0
	if res_units("madera") > 600:
		extra_score["madera"] = 0
	if res_units("raciones") / maxi(1, ratio) + res_units("crudo") > P * 3 / maxi(1, ratio) and days_to_wave() > 6:
		extra_score["crudo"] = 0
	if res_units("carbon") > maxi(1200, wave_coal_target() + 400):
		extra_score["carbon"] = 0
	if coal_stock_days < 1:
		ess_score["carbon"] = 98
	if days_to_wave() <= 4:
		extra_score["carbon"] = 70
	var entries := [] # [score, bid, amount]
	var sick := sim.total_sick()
	var producers := {"crudo": [], "carbon": [], "madera": [], "metal": []}
	for b in sim.st["buildings"]:
		if b["state"] != 1:
			continue
		var d: Dictionary = sim.bdef(b["type"])
		var k: String = d.get("kind", "")
		var mx := sim.staff_max(d)
		if mx <= 0:
			continue
		match k:
			"medical":
				var beds: int = int(d["beds"])
				var want := clampi((sick * mx + beds - 1) / maxi(1, beds), 0, mx)
				if sick > 0:
					want = maxi(want, 1)
				entries.append([100, b["id"], want])
			"cook":
				var raw_day: int = mini(res_units("crudo") + 30, (P + 6) / maxi(1, ratio) + 6)
				if res_units("raciones") > P * 3:
					raw_day = raw_day / 3
				var per: int = int(d["in_m"]) * 10 / FX.ONE
				entries.append([97, b["id"], clampi((raw_day + per - 1) / maxi(1, per), 1, mx)])
			"research":
				entries.append([90, b["id"], mx])
			"social":
				var hope: int = sim.st["hope"] / FX.ONE
				var disc: int = sim.st["disc"] / FX.ONE
				entries.append([85 if (hope < 50 or disc > 40) else 58, b["id"], mx])
			"factory":
				entries.append([92 if int(b.get("queue", 0)) > 0 else 0, b["id"], mx])
			_:
				var r := _res_of(b)
				if producers.has(r):
					producers[r].append(b)
	var pwc := {}
	for r in producers:
		for b in producers[r]:
			pwc[b["id"]] = per_worker_day(b)
			# Los conversores (horno, fundición) gastan otro recurso: solo si sobra la entrada.
			if sim.bdef(b["type"]).get("kind", "") == "convert":
				var rin0: String = sim.bdef(b["type"])["in"]
				var rout0: String = sim.bdef(b["type"])["out"]
				if res_units(rin0) <= (250 if rin0 == "madera" else 600):
					pwc[b["id"]] = 0
				elif rout0 == "carbon" and res_units("carbon") > maxi(800, wave_coal_target()):
					pwc[b["id"]] = 0
	for r in producers:
		var list: Array = producers[r]
		list.sort_custom(func(a, bb): return pwc[a["id"]] > pwc[bb["id"]] or (pwc[a["id"]] == pwc[bb["id"]] and a["id"] < bb["id"]))
		var remaining: int = needs[r]
		for b in list:
			var mx := sim.staff_max(sim.bdef(b["type"]))
			var pw: int = pwc[b["id"]]
			var conv: bool = sim.bdef(b["type"]).get("kind", "") == "convert"
			if conv:
				# Conversores: esenciales solo si falta el producto; extra si sobra la entrada.
				var rin: String = sim.bdef(b["type"])["in"]
				var surplus_in := res_units(rin) > _reserve_of(rin) and res_units(r) < _reserve_of(r)
				var real_pw := per_worker_day(b)
				var n2 := 0
				if pw > 0 and remaining > 0:
					n2 = clampi((remaining + real_pw - 1) / maxi(1, real_pw), 0, mx)
					remaining -= n2 * real_pw
				entries.append([ess_score[r] - 20, b["id"], n2])
				if surplus_in and mx - n2 > 0:
					entries.append([30, b["id"], mx - n2])
				continue
			if pw <= 0:
				entries.append([0, b["id"], 0])
				continue
			if res_units(r) * 100 / maxi(1, sim.cap(r) / FX.ONE) > 92:
				entries.append([15, b["id"], mx])
				continue
			var n := 0
			if remaining > 0:
				n = clampi((remaining + pw - 1) / pw, 0, mx)
				remaining -= n * pw
			entries.append([ess_score[r], b["id"], n])
			if extra_score[r] > 0:
				entries.append([extra_score[r], b["id"], mx - n])
	entries.sort_custom(func(a, bb): return a[0] > bb[0] or (a[0] == bb[0] and a[1] < bb[1]))
	var pool := {}
	for cl in Simulation.CLASSES:
		pool[cl] = sim.healthy(cl)
	var alloc := {}
	var flex_now := 0
	for e in entries:
		if not alloc.has(e[1]):
			alloc[e[1]] = {"o": 0, "i": 0, "n": 0}
	# 1) Ingenieros a edificios que solo aceptan ingenieros
	for e in entries:
		if e[0] <= 0:
			continue
		var b := sim.building(e[1])
		if sim.staff_types(sim.bdef(b["type"])) == ["ingenieros"]:
			var t := mini(int(e[2]), pool["ingenieros"])
			alloc[e[1]]["i"] += t
			pool["ingenieros"] -= t
	# 2) Obreros por prioridad; si faltan, ingenieros sobrantes
	for e in entries:
		if e[0] <= 0:
			continue
		var b := sim.building(e[1])
		var types := sim.staff_types(sim.bdef(b["type"]))
		if types == ["ingenieros"]:
			continue
		var want: int = e[2]
		var tw := mini(want, pool["obreros"]) if "obreros" in types else 0
		pool["obreros"] -= tw
		var ti := mini(want - tw, pool["ingenieros"]) if "ingenieros" in types else 0
		pool["ingenieros"] -= ti
		alloc[e[1]]["o"] += tw
		alloc[e[1]]["i"] += ti
		if e[0] < 60:
			flex_now += tw + ti
	# 3) Niños (si la ley lo permite) en huecos restantes
	for e in entries:
		if e[0] <= 0:
			continue
		var b := sim.building(e[1])
		var d: Dictionary = sim.bdef(b["type"])
		if not sim.child_allowed(d):
			continue
		var used: int = alloc[e[1]]["o"] + alloc[e[1]]["i"] + alloc[e[1]]["n"]
		var tn := mini(sim.staff_max(d) - used, mini(int(e[2]), pool["ninos"]))
		if tn > 0:
			alloc[e[1]]["n"] += tn
			pool["ninos"] -= tn
	flex = flex_now + pool["obreros"] + pool["ingenieros"]
	for bid in alloc:
		var b := sim.building(bid)
		var a: Dictionary = alloc[bid]
		if int(b["do"]) != a["o"] or int(b["di"]) != a["i"] or int(b["dn"]) != a["n"]:
			cmd({"c": "staff", "bid": bid, "o": a["o"], "i": a["i"], "n": a["n"]})
	# Turnos prolongados en carbón si hace falta y la ley lo permite
	if sim.shift_max_allowed() >= 1:
		var low_coal := coal_stock_days < 2 or (days_to_wave() <= 8 and res_units("carbon") < wave_coal_target())
		for b in sim.st["buildings"]:
			var d2: Dictionary = sim.bdef(b["type"])
			if b["state"] != 1 or not (1 in d2.get("shifts", [0])):
				continue
			var want_sh := 1 if (_res_of(b) == "carbon" and low_coal and sim.st["disc"] < 55 * FX.ONE) else 0
			if int(b["shift"]) != want_sh:
				cmd({"c": "shift", "bid": b["id"], "v": want_sh})

# ================================================================ investigación y leyes
func _dynamic_order() -> Array:
	var order: Array = []
	var done: Array = sim.st["research"]["done"]
	if res_units("metal") < 40 and buildings_of(["mina_hierro"]).is_empty():
		order.append("rec_mina_hierro")
	if frugal():
		if res_units("madera") > 200:
			order.append("rec_horno")
		order.append_array(["rec_fundicion", "rec_pozo", "cal_combustion"])
	if res_units("madera") > 400 and "rec_horno" not in done:
		order.append("rec_horno")
	order.append_array(research_order)
	return order

func _research() -> void:
	if sim.st["research"]["cur"] != "":
		return
	if buildings_of(["taller"], true).is_empty():
		return
	var tried := 0
	for id in _dynamic_order():
		if id in sim.st["research"]["done"]:
			continue
		var why := sim.research_check(id)
		if why == "requiere investigación previa":
			continue
		tried += 1
		if tried > 3:
			return
		if why == "":
			# reservar recursos de construcción básicos
			var cost: Dictionary = sim.db["research"][id].get("cost", {})
			if int(cost.get("madera", 0)) > 0 and res_units("madera") - int(cost["madera"]) < 20:
				continue
			if int(cost.get("metal", 0)) > 0 and res_units("metal") - int(cost["metal"]) < 20:
				continue
			if int(cost.get("nucleos", 0)) > 0 and res_units("nucleos") - int(cost["nucleos"]) < CORE_RESERVE:
				continue
			if cmd({"c": "research", "id": id}):
				return

func _law_wanted(id: String) -> bool:
	var L: Dictionary = sim.db["laws"][id]
	if L.get("extreme", false):
		return sim.st["hope"] < 12 * FX.ONE or sim.st["disc"] > 88 * FX.ONE
	var p: String = L.get("path", "")
	if p != "" and p != path:
		return false
	match id:
		"ley_cementerio":
			return true
		"ley_fosa", "ley_abono", "ley_manos", "ley_jornada_inf", "ley_serrin", "ley_racionamiento", "ley_turno_continuo":
			return false
		"ley_caldo":
			return res_units("raciones") + res_units("crudo") * 2 < pop() * 2 and sim.day() > 10
		"ley_camillas":
			return sim.total_sick() > _beds_total()
		"ley_cuidados":
			return sim.total_grave() >= 3 or sim.day() > 15
		"ley_banos", "ley_taberna":
			return sim.st["disc"] > 25 * FX.ONE or sim.day() > 20
	return true

func _laws() -> void:
	if sim.tick() < int(sim.st["law_ready"]):
		return
	# Orden de preferencia
	var order := ["ley_cementerio", "ley_refugios", "ley_jornada", "fe_circulo" if path == "fe" else "ord_patrulla",
		"ley_aprendices", "ley_cuidados", "fe_sanadores", "ord_proclamas", "ley_convalecencia", "ley_ultimo_fuego",
		"fe_vigilias", "ord_celdas", "ley_banos", "ley_taberna", "fe_templo", "ord_toque", "fe_santuario", "ord_ojo",
		"ley_camillas", "ley_caldo", "fe_custodios", "ord_juramento", "fe_penitencia", "ord_brigadas"]
	for id in order:
		if sim.law_check(id) == "" and _law_wanted(id):
			cmd({"c": "law", "id": id})
			return
	for id in sim.db["laws"]:
		if sim.db["laws"][id].get("extreme", false) and sim.law_check(id) == "" and _law_wanted(id):
			cmd({"c": "law", "id": id})
			return

# ================================================================ eventos y pedidos
func effect_value(effs: Array) -> int:
	var v := 0
	for e in effs:
		var k: String = e["k"]
		var x: int = int(e.get("v", 0)) if typeof(e.get("v", 0)) == TYPE_INT else 0
		match k:
			"hope":
				v += x * 40
			"disc":
				v -= x * 30
			"res":
				v += x * int(weights.get(e["r"], 3))
			"refugees":
				v += (int(e.get("o", 0)) + int(e.get("n", 0))) * 20 + int(e.get("i", 0)) * 30 - int(e.get("sick", 0)) * 10
			"sick":
				v -= x * (40 if int(e.get("grave", 0)) == 1 else 20)
			"kill":
				v -= x * 150
			"leave":
				v -= x * 60
			"stress":
				v -= x * 15
			"perm_mod":
				v += 120 if int(e["v"]) > 0 and e["key"] != "gen_coal_pct" else 120
			"hunt_zone":
				v += x
			"reveal":
				v += 30
			"rand":
				var p: int = e.get("pct", 50)
				v += (effect_value(e.get("then", [])) * p + effect_value(e.get("else", [])) * (100 - p)) / 100
	return v

func _events() -> void:
	for p in sim.st["ev_pending"].duplicate():
		var best := best_choice(p)
		if best >= 0:
			cmd({"c": "event", "inst": p["inst"], "choice": best})

## Opción de un evento pendiente con mejor valor esperado (-1 si ninguna es posible).
func best_choice(p: Dictionary) -> int:
	var ev: Dictionary = sim.db["events"][p["id"]]
	var best := -1
	var bv := -999999
	for i in (ev["choices"] as Array).size():
		if not sim.choice_ok(p["id"], i):
			continue
		var val := effect_value(ev["choices"][i].get("effects", []))
		if val > bv:
			bv = val
			best = i
	return best

func _requests() -> void:
	var off: Dictionary = sim.st["req"]["offer"]
	if off.is_empty():
		return
	var d: Dictionary = sim.db["requests"][off["id"]]
	cmd({"c": "request", "accept": 1 if _request_feasible(d["goal"]) else 0})

func _request_feasible(g: Dictionary) -> bool:
	match g["k"]:
		"no_homeless":
			return pop() + incoming_people() - housing_capacity(true) <= 10 and res_units("madera") >= 25
		"count_delta":
			for t in g["types"]:
				if sim.is_unlocked(t) and sim.can_afford(sim.bdef(t).get("cost", {})):
					return true
			return false
		"res_min":
			return res_units(g["r"]) * 100 >= int(g["v"]) * 70
		"heat_homes_min":
			return sim.cond_ok(g) or (int(sim.st["gen"]["level"]) < sim.gen_max_level())
		"sick_max":
			return _beds_total() >= sim.total_sick()
		"research_delta":
			return not buildings_of(["taller"], true).is_empty()
		"explore_delta":
			return not buildings_of(["faro"], true).is_empty()
		"gen_level_min":
			return sim.gen_max_level() >= int(g["v"])
		"no_bodies":
			return not buildings_of(["cementerio", "fosa"]).is_empty()
	return false

# ================================================================ exploración y autómatas
func _explore() -> void:
	if sim.in_wave():
		return
	for t in sim.st["teams"]:
		if t["state"] != "home":
			continue
		var best := ""
		var bd := 999
		for id in sim.st["locs"]:
			if sim.loc_accessible(id) != "":
				continue
			var dd: int = sim.db["locations"][id]["dist"]
			if dd < bd:
				bd = dd
				best = id
		if best == "":
			return
		# Evitar quedar atrapados por una oleada inminente
		if days_to_wave() * 24 < sim.travel_time(best) * 2 + 6 and days_to_wave() < 99:
			return
		if sim.healthy("obreros") < 12:
			return
		cmd({"c": "expedition", "bid": t["bid"], "loc": best})

func _automatons() -> void:
	for f in buildings_of(["fabrica_aut"], true):
		var keep := CORE_RESERVE
		if int(f.get("queue", 0)) == 0 and res_units("nucleos") > keep and res_units("metal") >= 45:
			cmd({"c": "auto_build", "bid": f["id"]})
	if int(sim.st["autos_free"]) <= 0:
		return
	for type in ["mina_profunda", "extractor", "perforadora", "aserradero", "mina_hierro", "invernadero"]:
		for b in buildings_of([type], true):
			if int(b["auto"]) == 0 and int(sim.st["autos_free"]) > 0:
				cmd({"c": "auto_assign", "bid": b["id"], "v": 1})
