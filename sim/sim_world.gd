class_name SimWorld
extends SimSociety
## Exploración del páramo: equipos de exploradores, viajes con duración,
## ubicaciones finitas (se visitan una sola vez), botín, núcleos y sobrevivientes.

func locations_init() -> void:
	var locs := {}
	for id in db["locations"]:
		var L: Dictionary = db["locations"][id]
		# Variación por semilla del botín (±25%) y de los sobrevivientes.
		var loot := {}
		for r in L.get("loot", {}):
			var base: int = L["loot"][r]
			if r == "nucleos":
				loot[r] = base
			else:
				loot[r] = base * (75 + rnd(51)) / 100
		var surv := {}
		for c in L.get("survivors", {}):
			var b2: int = L["survivors"][c]
			surv[c] = maxi(0, b2 * (70 + rnd(61)) / 100)
		locs[id] = {"state": 1 if L.get("start_known", false) else 0, "loot": loot, "surv": surv}
	st["locs"] = locs

func reveal_location(id: String) -> void:
	if st["locs"].has(id) and int(st["locs"][id]["state"]) == 0:
		st["locs"][id]["state"] = 1
		note("exploracion", text("ubicacion_descubierta") % db["locations"][id]["name"], {"loc": id})

func loc_accessible(id: String) -> String:
	if not st["locs"].has(id):
		return "desconocida"
	var s: Dictionary = st["locs"][id]
	if int(s["state"]) == 0:
		return "sin descubrir"
	if int(s["state"]) >= 2:
		return "ya explorada"
	var L: Dictionary = db["locations"][id]
	if L.has("req_research") and not (L["req_research"] in st["research"]["done"]):
		return "requiere investigación"
	for t in st["teams"]:
		if t["loc"] == id and t["state"] != "home":
			return "ya hay un equipo en camino"
	return ""

func travel_time(id: String) -> int:
	var L: Dictionary = db["locations"][id]
	var t: int = int(L["dist"]) * int(B["explore"]["hours_per_dist"])
	return maxi(2, t * maxi(20, 100 + mod("travel_pct")) / 100)

## Equipo de un faro (se crea al terminar el edificio).
func team_of(bid: int) -> Dictionary:
	for t in st["teams"]:
		if int(t["bid"]) == bid:
			return t
	return {}

func teams_sync() -> void:
	# Crear equipo para cada faro terminado; eliminar si el faro ya no existe.
	var teams: Array = st["teams"]
	for b in st["buildings"]:
		if b["state"] == 1 and bdef(b["type"]).get("kind", "") == "scouts" and team_of(b["id"]).is_empty():
			teams.append({"bid": b["id"], "state": "home", "loc": "", "eta": 0, "cargo": {}, "n": 0})

func send_expedition(bid: int, loc: String) -> String:
	var t := team_of(bid)
	if t.is_empty():
		return "sin equipo"
	if t["state"] != "home":
		return "equipo ocupado"
	if in_wave():
		return "oleada en curso"
	var why := loc_accessible(loc)
	if why != "":
		return why
	var n: int = B["explore"]["team_size"]
	if healthy("obreros") - assigned_total("obreros") < n and healthy("obreros") < n:
		return "faltan obreros sanos"
	if healthy("obreros") < n:
		return "faltan obreros sanos"
	var food: int = int(B["explore"]["food_m"])
	if not take_res("raciones", food):
		return "faltan raciones para el viaje"
	st["pop"]["obreros"]["h"] -= n
	st["away"]["obreros"] += n
	t["n"] = n
	t["state"] = "out"
	t["loc"] = loc
	t["eta"] = st["tick"] + travel_time(loc)
	note("exploracion", text("expedicion_parte") % db["locations"][loc]["name"])
	return ""

func expeditions_update() -> void:
	var wave := in_wave()
	for t in st["teams"]:
		if t["state"] == "home":
			continue
		if wave:
			t["eta"] = int(t["eta"]) + 1 # se refugian y esperan
			continue
		if st["tick"] < int(t["eta"]):
			continue
		if t["state"] == "out":
			_arrive(t)
		elif t["state"] == "back":
			_return_home(t)

func _arrive(t: Dictionary) -> void:
	var id: String = t["loc"]
	var L: Dictionary = db["locations"][id]
	var s: Dictionary = st["locs"][id]
	s["state"] = 2
	st["explored"] += 1
	t["cargo"] = s["loot"].duplicate()
	s["loot"] = {}
	var surv: Dictionary = s["surv"]
	var tot := 0
	for c in surv:
		tot += int(surv[c])
	if tot > 0:
		add_arrival(travel_time(id) + int(B["explore"]["survivor_extra_h"]), int(surv.get("obreros", 0)), int(surv.get("ingenieros", 0)), int(surv.get("ninos", 0)), int(surv.get("sick", 0)))
		s["surv"] = {}
	for nb in L.get("reveals", []):
		reveal_location(nb)
	note("exploracion", text("expedicion_llega") % L["name"], {"loc": id})
	if L.has("event"):
		fire_event(L["event"], {"loc": id})
	t["state"] = "back"
	t["eta"] = st["tick"] + travel_time(id)

func _return_home(t: Dictionary) -> void:
	var n: int = t["n"]
	st["away"]["obreros"] -= n
	st["pop"]["obreros"]["h"] += n
	var cargo: Dictionary = t["cargo"]
	for r in cargo:
		var amt: int = int(cargo[r]) * FX.ONE
		add_res(r, amt, "exploracion")
	t["cargo"] = {}
	t["n"] = 0
	t["state"] = "home"
	t["loc"] = ""
	note("exploracion", text("expedicion_vuelve"))
