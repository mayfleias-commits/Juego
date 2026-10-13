class_name SimEconomy
extends SimPeople
## Producción por edificio y por hora trabajada, almacenes, construcción,
## investigación, autómatas, caza e invernaderos.

func recompute_caps() -> void:
	caps = {}
	for r in RES:
		caps[r] = int(B["storage"]["base"][r]) * FX.ONE
	for b in st["buildings"]:
		if b["state"] != 1:
			continue
		var sto: Dictionary = bdef(b["type"]).get("storage", {})
		for r in sto:
			caps[r] += int(sto[r]) * FX.ONE

func level_mult(lvl: int) -> int:
	return int(B["prod"]["level_mult"][lvl])

## Multiplicador de productividad (FP) de un edificio en esta hora.
func prod_mult(b: Dictionary, d: Dictionary, res_key: String, building_bonus: bool) -> int:
	var m := outdoor_mult() if d.get("outdoor", false) else level_mult(b["lvl"])
	var pct := 100 + mod("prod_all_pct")
	if building_bonus and res_key != "":
		pct += mod("prod_" + res_key + "_pct")
	return m * maxi(0, pct) / 100

# ---------------------------------------------------------------- construcción
func construction_update() -> void:
	var om := maxi(int(B["build"]["min_speed_m"]), outdoor_mult())
	var changed := false
	for b in st["buildings"]:
		if b["state"] == 0:
			b["left"] -= om
			if b["left"] <= 0:
				b["left"] = 0
				b["state"] = 1
				changed = true
				st["day_acc"]["built"] = st["day_acc"].get("built", 0) + 1
				note("obra", text("obra_terminada") % bdef(b["type"])["name"], {"bid": b["id"]})
		elif b.get("up", "") != "":
			b["up_left"] -= om
			if b["up_left"] <= 0:
				var nt: String = b["up"]
				b["type"] = nt
				b["up"] = ""
				b["up_left"] = 0
				changed = true
				note("obra", text("mejora_terminada") % bdef(nt)["name"], {"bid": b["id"]})
	if changed:
		recompute_caps()

# ---------------------------------------------------------------- autómatas
func autos_update() -> void:
	var A: Dictionary = B["auto"]
	var per: int = int(A["coal_m"]) * maxi(10, 100 + mod("auto_coal_pct")) / 100
	var any := false
	for b in st["buildings"]:
		var n: int = b["auto"]
		if n <= 0:
			continue
		any = true
		# Un autómata parado por falta de mantenimiento no consume carbón.
		if building_works(b) and int(b.get("auto_stall", 0)) == 0 and take_res("carbon", per * n):
			b["auto_ok"] = 1
		else:
			b["auto_ok"] = 0
	if any and hour() == 0:
		for b in st["buildings"]:
			var n2: int = b["auto"]
			if n2 > 0:
				b["auto_stall"] = 0 if take_res("metal", int(A["maint_metal_m"]) * n2) else 1
				if int(b["auto_stall"]) == 1:
					note("alerta", text("autom_sin_mant"))

# ---------------------------------------------------------------- producción
func production_update() -> void:
	var h := hour()
	var social_seen := {}
	st["social_h"] = 0
	st["social_d"] = 0
	for b in st["buildings"]:
		if not building_works(b):
			# Cabaña apagada con la partida de caza afuera: vuelven sin presa.
			if int(b.get("trip", 0)) > 0:
				b["trip"] = 0
			continue
		var d: Dictionary = bdef(b["type"])
		var kind: String = d.get("kind", "")
		if d.has("hope_t_m") and kind != "social":
			_social(b, d, social_seen)
		if kind == "" or kind == "housing" or kind == "storage" or kind == "medical" or kind == "burial" or kind == "shelter" or kind == "station" or kind == "scouts":
			continue
		var human := 0
		if shift_active(b, h):
			human = staff_eq(b)
			if human > 0 and (h < 8 or h >= 18) and kind != "hunt":
				_worked_extra(b, h)
		var eq := human
		if int(b["auto"]) > 0 and int(b.get("auto_ok", 0)) == 1:
			eq += int(b["auto"]) * auto_eq()
		match kind:
			"gather":
				if eq > 0:
					_gather(b, d, eq)
			"extract":
				if eq > 0:
					_extract(b, d, eq)
			"convert":
				if eq > 0:
					_convert(b, d, eq)
			"cook":
				if eq > 0:
					_cook(b, d, eq)
			"greenhouse":
				if eq > 0:
					_greenhouse(b, d, eq)
			"hunt":
				_hunt(b, d, h)
			"research":
				if eq > 0:
					_research(b, d, eq)
			"social":
				_social(b, d, social_seen)
			"factory":
				if eq > 0:
					_factory(b, d, eq)

## Registra que el personal de b trabajó esta hora fuera del turno normal (8 a 18).
## Las penalidades de los turnos largos se calculan sobre lo efectivamente trabajado,
## no sobre el turno elegido en un instante: cambiar el turno justo antes de que se
## evalúen no las evita.
func _worked_extra(b: Dictionary, h: int) -> void:
	b["sx1"] = st["tick"]
	if h < 8 or h >= 22:
		# Horas que solo cubre el turno de 24 h: cuentan para la fatiga de cada clase.
		b["sx2"] = st["tick"]
		var a := bat_arrived3(b)
		var fat: Array = st["fat"]
		for k in 3:
			fat[k] = int(fat[k]) + mini(int(a[k]), int(b[SKEYS[k]]))

func _gather(b: Dictionary, d: Dictionary, eq: int) -> void:
	var focus: String = b.get("focus", "auto")
	var rates: Dictionary = d["rates_m"]
	for nid in b["nodes"]:
		var n: Dictionary = st["nodes"][nid]
		if n["amt"] <= 0:
			continue
		if focus != "auto" and n["kind"] != focus:
			continue
		var r: String = n["kind"]
		var amount: int = eq * int(rates[r]) / FX.ONE * prod_mult(b, d, r, false) / FX.ONE
		amount = mini(amount, n["amt"])
		amount = mini(amount, maxi(0, cap(r) - res(r)))
		if amount <= 0:
			return
		n["amt"] -= amount
		add_res(r, amount, "recoleccion")
		if n["amt"] <= 0:
			n["amt"] = 0
			fill_rect(n["x"], n["y"], 2, 2, G_FREE)
			note("recurso", text("pila_agotada"), {"node": nid})
		return

func _extract(b: Dictionary, d: Dictionary, eq: int) -> void:
	var s: Dictionary = st["sites"][b["site"]]
	if s["amt"] <= 0:
		return
	var r: String = d["res"]
	var amount: int = eq * int(d["rate_m"]) / FX.ONE * prod_mult(b, d, r, true) / FX.ONE
	amount = mini(amount, s["amt"])
	# No extraer por encima de la capacidad: el yacimiento no se pierde.
	amount = mini(amount, maxi(0, cap(r) - res(r)))
	if amount <= 0:
		return
	s["amt"] -= amount
	add_res(r, amount, "extraccion")
	if s["amt"] <= 0:
		note("recurso", text("yacimiento_agotado") % d["name"], {"bid": b["id"]})

func _convert(b: Dictionary, d: Dictionary, eq: int) -> void:
	var rin: String = d["in"]
	var rout: String = d["out"]
	var in_rate: int = d["in_m"]
	var out_rate: int = d["out_m"]
	var mult := prod_mult(b, d, rout, true)
	var cap_in: int = eq * in_rate / FX.ONE * mult / FX.ONE
	# No convertir si no hay lugar para el producto.
	var room := maxi(0, cap(rout) - res(rout))
	cap_in = mini(cap_in, room * in_rate / maxi(1, out_rate))
	var used := take_upto(rin, cap_in)
	if used > 0:
		add_res(rout, used * out_rate / in_rate, "conversion")

func cook_ratio() -> int:
	return int(B["food"]["cook_ratio_m"]) + mod("cook_ratio_m")

func _cook(b: Dictionary, d: Dictionary, eq: int) -> void:
	var mult := level_mult(b["lvl"]) * maxi(0, 100 + mod("cook_pct")) / 100
	var cap_in: int = eq * int(d["in_m"]) / FX.ONE * mult / FX.ONE
	var ratio := cook_ratio()
	var room := maxi(0, cap("raciones") - res("raciones"))
	cap_in = mini(cap_in, room * FX.ONE / ratio)
	var used := take_upto("crudo", cap_in)
	if used > 0:
		add_res("raciones", used * ratio / FX.ONE, "cocina")

func _greenhouse(b: Dictionary, d: Dictionary, eq: int) -> void:
	var lvl: int = b["lvl"]
	if lvl < int(d["min_lvl"]):
		return
	if not take_res("carbon", int(d["coal_m"])):
		return
	var gm: int = int(B["food"]["greenhouse_level_m"][lvl])
	var amount: int = eq * int(d["rate_m"]) / FX.ONE * gm / FX.ONE * maxi(0, 100 + mod("greenhouse_pct")) / 100
	add_res("crudo", amount, "invernadero")

func _hunt(b: Dictionary, d: Dictionary, h: int) -> void:
	var F: Dictionary = B["food"]
	if int(b.get("trip", 0)) > 0:
		# Los que se reasignan durante la partida de caza la abandonan (no cazan
		# y trabajan en otro lado a la vez).
		b["trip"] = mini(int(b["trip"]), int(b["o"]))
		if int(b["trip"]) > 0 and h >= 18:
			b["sx1"] = st["tick"] # afuera después de las 18: turno largo trabajado
	if h == 8 and int(b.get("trip", 0)) == 0:
		var hunters: int = bat_arrived3(b)[0]
		hunters = mini(hunters, int(b["o"]))
		var t := outdoor()
		# Durante las oleadas la caza se suspende (y con mucho frío tampoco se sale).
		if hunters > 0 and t >= int(F["hunt_min_temp"]) and not in_wave():
			b["trip"] = hunters
			b["trip_m"] = outdoor_mult(t)
			b["trip_ret"] = 22 if int(b["shift"]) >= 1 else 18
		return
	if int(b.get("trip", 0)) > 0 and h == int(b.get("trip_ret", 18)):
		var n: int = b["trip"]
		var y: int = n * int(F["hunt_trip_m"]) * int(b["trip_m"]) / FX.ONE
		y = y * maxi(0, 100 + mod("hunt_pct") + mod("prod_all_pct")) / 100
		if int(b["trip_ret"]) == 22:
			y = y * int(F["hunt_ext_pct"]) / 100
		var got := _take_hunt(y)
		add_res("crudo", got, "caza")
		b["trip"] = 0
		b["last_hunt"] = got

func _take_hunt(amount: int) -> int:
	var zones: Array = st["hunt"]
	var got := 0
	# De la zona más rica a la más pobre; el rendimiento cae cuando la zona está agotada.
	while amount > 0:
		var best := -1
		var best_amt := 0
		for i in zones.size():
			if zones[i]["stock"] > best_amt:
				best_amt = zones[i]["stock"]
				best = i
		if best < 0:
			break
		var z: Dictionary = zones[best]
		var t := mini(amount, z["stock"])
		z["stock"] -= t
		got += t
		amount -= t
	return got

func hunt_regen() -> void:
	for z in st["hunt"]:
		z["stock"] = mini(int(z["max"]), int(z["stock"]) + int(z["regen"]))

func _research(b: Dictionary, d: Dictionary, eq: int) -> void:
	var R: Dictionary = st["research"]
	var cur: String = R["cur"]
	if cur == "":
		return
	var pts: int = eq * int(d["rp_m"]) / FX.ONE * level_mult(b["lvl"]) / FX.ONE
	pts = pts * maxi(0, 100 + mod("research_pct")) / 100
	var progs: Dictionary = R["progs"]
	progs[cur] = progs.get(cur, 0) + pts
	var need: int = int(db["research"][cur]["rp"]) * FX.ONE
	if progs[cur] >= need:
		complete_research(cur)

func complete_research(id: String) -> void:
	var R: Dictionary = st["research"]
	R["done"].append(id)
	R["cur"] = ""
	R["progs"].erase(id)
	rebuild_mods()
	recompute_caps()
	apply_effects(db["research"][id].get("effects", []), {"cause": "investigacion"})
	add_hope(int(B["society"]["research_hope_m"]), "investigacion")
	note("investigacion", text("investigacion_lista") % db["research"][id]["name"], {"id": id})

func _social(b: Dictionary, d: Dictionary, seen: Dictionary) -> void:
	var t: String = b["type"]
	var k: int = seen.get(t, 0)
	seen[t] = k + 1
	var mx := staff_max(d)
	var ratio := FX.ONE
	if mx > 0:
		# Solo cuenta el personal que ya llegó (el viaje también cuenta aquí).
		ratio = mini(FX.ONE, mini(bat_arrived(b), b["o"] + b["i"] + b["n"]) * FX.ONE / mx)
	# Rendimientos decrecientes: el k-ésimo edificio igual rinde 1, 1/2, 1/4...
	var f := (ratio >> mini(k, 10))
	st["social_h"] = int(st.get("social_h", 0)) + int(d.get("hope_t_m", 0)) * f / FX.ONE
	st["social_d"] = int(st.get("social_d", 0)) + int(d.get("disc_t_m", 0)) * f / FX.ONE

func _factory(b: Dictionary, d: Dictionary, eq: int) -> void:
	if int(b.get("queue", 0)) <= 0:
		return
	b["prog"] = int(b.get("prog", 0)) + eq
	if b["prog"] >= int(d["work_m"]):
		b["prog"] = 0
		b["queue"] -= 1
		st["autos_free"] += 1
		st["autos_total"] += 1
		note("autom", text("automata_listo"))
