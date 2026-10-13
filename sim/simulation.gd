class_name Simulation
extends SimWorld
## Núcleo de simulación completo. Paso fijo de 1 hora de juego.
## Uso:  var s := Simulation.new(); s.new_game(semilla); s.command({...}); s.step()
## Las órdenes se aplican entre pasos, así que pausar o acelerar no cambia nada.

signal stepped

func new_game(seed: int) -> void:
	rng = SimRng.seed_state(seed)
	var S: Dictionary = B["start"]
	st = {
		"version": SAVE_VERSION, "seed": seed, "tick": 0,
		"day": 1, "hour": int(S["hour"]), "status": "playing", "end_reason": "",
		"res": {}, "obtained": {}, "wasted": {},
		"pop": {}, "away": {}, "idle": {},
		"dead": 0, "dead_by": {}, "bodies": 0, "buried": 0,
		"arrivals": [], "arrived_total": 0,
		"buildings": [], "bindex": {}, "next_bid": 1,
		"nodes": [], "sites": [],
		"gen": {"on": 1, "level": 1, "over": 0, "stress": 0, "warm": 0, "heaters": 0},
		"stations": [], "outdoor": 0, "exploded": 0,
		"hope": int(S["hope"]) * FX.ONE, "disc": int(S["disc"]) * FX.ONE,
		"laws": [], "law_ready": 0, "path": "",
		"research": {"done": [], "cur": "", "progs": {}, "paid": {}},
		"perm_mods": [], "flags": {},
		"ev_pending": [], "ev_sched": [], "ev_fired": {}, "ev_seq": 0, "ev_choices": [],
		"req": {"offer": {}, "active": [], "done": {}, "next": int(B["requests"]["first_h"])},
		"req_ok": 0, "req_fail": 0,
		"teams": [], "locs": {}, "explored": 0,
		"hunt": [], "hungry": 0, "hunger_streak": 0, "homeless": 0, "treated": 0,
		"home_dist": [0, 0, 0, 0, FX.ONE, 0],
		"autos_total": 0, "autos_free": 0, "fat": [0, 0, 0],
		"log": [], "reports": [], "day_acc": {},
		"stars": 0, "epilogue": [],
		"death_log": [], "mood": {}, "social_h": 0, "social_d": 0,
	}
	for r in RES:
		var v: int = int(S["res"][r]) * FX.ONE
		st["res"][r] = v
		st["obtained"][r] = v
		st["wasted"][r] = 0
	for c in CLASSES:
		st["pop"][c] = {"h": int(S["pop"][c]), "sl": 0, "sg": 0}
		st["away"][c] = 0
	_reset_day_acc()
	generate_map()
	gen_climate()
	for z in B["food"]["zones"]:
		var mx: int = int(z["max"]) * (85 + rnd(31)) / 100 * FX.ONE
		st["hunt"].append({"stock": mx, "max": mx, "regen": int(z["regen"]) * FX.ONE})
	locations_init()
	rebuild_mods()
	recompute_caps()
	reindex_buildings()
	st["outdoor"] = temp_at(day(), hour())
	for sb in S.get("buildings", []):
		var p := find_spot_near(sb["type"], int(sb["x"]), int(sb["y"]))
		if p.x >= 0:
			var b := _create_building(sb["type"], p.x, p.y)
			b["state"] = 1
			b["left"] = 0
	recompute_caps()

func _reset_day_acc() -> void:
	st["day_acc"] = {"prod": {}, "cons": {}, "hope_causes": {}, "disc_causes": {}, "deaths": 0, "new_sick": 0, "arrived": 0, "built": 0, "gen_coal": 0, "tmin": 999, "hope0": st["hope"], "disc0": st["disc"]}

# ---------------------------------------------------------------- paso
func step() -> void:
	if st["status"] != "playing":
		return
	notes = []
	st["outdoor"] = temp_at(day(), hour())
	st["day_acc"]["tmin"] = mini(int(st["day_acc"]["tmin"]), outdoor())
	arrivals_update()
	gen_update()
	heat_update()
	construction_update()
	teams_sync()
	staff_fill()
	autos_update()
	production_update()
	if hour() in B["food"]["meal_hours"]:
		meal()
	var ex := compute_exposure()
	health_update(ex)
	bodies_update()
	mood_update()
	expeditions_update()
	events_update()
	requests_update()
	if hour() == 23:
		fatigue_update()
	# Avanzar el reloj
	st["tick"] += 1
	st["hour"] += 1
	if st["hour"] >= 24:
		st["hour"] = 0
		_end_of_day()
		st["day"] += 1
		_start_of_day()
	_check_end()
	stepped.emit()

func run_hours(n: int) -> void:
	for i in n:
		if st["status"] != "playing":
			return
		step()

func _end_of_day() -> void:
	var a: Dictionary = st["day_acc"]
	var rep := {
		"day": day(), "tmin": a["tmin"], "prod": a["prod"], "cons": a["cons"],
		"deaths": a["deaths"], "new_sick": a["new_sick"], "arrived": a["arrived"], "built": a["built"],
		"hope": st["hope"], "disc": st["disc"],
		"hope_delta": st["hope"] - int(a["hope0"]), "disc_delta": st["disc"] - int(a["disc0"]),
		"hope_causes": a["hope_causes"], "disc_causes": a["disc_causes"], "gen_coal": a["gen_coal"],
		"pop": total_pop(), "sick": total_sick(),
	}
	st["reports"].append(rep)
	hunt_regen()
	var w := wave_on(day())
	if not w.is_empty() and day() == int(w["start"]) + (w["profile"] as Array).size() - 1:
		add_hope(int(B["society"]["wave_survived_hope_m"]), "oleada")
		note("oleada", text("oleada_superada") % w["name"])
	_reset_day_acc()

func _start_of_day() -> void:
	var nd := day()
	for w in db["climate"]["waves"]:
		var s: int = w["start"]
		if s - nd == int(w["announce"]):
			note("oleada", text("oleada_anuncio") % [w["name"], int(w["announce"]), _wave_peak(w)], {"wave": w["id"]})
		elif s == nd:
			note("oleada", text("oleada_comienza") % w["name"], {"wave": w["id"]})
			_fire_trigger("wave:" + str(w["id"]))

## Mínima que se espera en la oleada: la media diaria más fría del perfil más la
## hora más fría del día (la misma cuenta que usa el pronóstico).
func _wave_peak(w: Dictionary) -> int:
	var p := 0
	for t in w["profile"]:
		p = mini(p, int(t))
	var dm := 0
	for t in db["climate"]["diurnal"]:
		dm = mini(dm, int(t))
	return p + dm

func _check_end() -> void:
	if st["status"] != "playing":
		return
	if int(st["exploded"]) == 1:
		_finish("lost", "explosion")
	elif st["hope"] <= 0:
		_finish("lost", "esperanza")
	elif st["disc"] >= 100 * FX.ONE:
		_finish("lost", "expulsion")
	elif total_pop() <= 0:
		_finish("lost", "extincion")
	elif day() > int(B["days"]):
		if int(st["gen"]["on"]) == 1 and total_pop() > 0:
			_finish("won", "victoria")
		else:
			_finish("lost", "frio_final")

func _finish(status: String, reason: String) -> void:
	st["status"] = status
	st["end_reason"] = reason
	if status == "won":
		st["stars"] = compute_stars()
	st["epilogue"] = compute_epilogue()
	note("fin", text("fin_" + reason))

func compute_stars() -> int:
	var alive := total_pop()
	var dead: int = st["dead"]
	var surv := alive * 100 / maxi(1, alive + dead)
	var SB: Dictionary = B["stars"]
	var s := 1
	if surv >= int(SB["surv_pct"]):
		s += 1
	if alive >= int(SB["pop_end"]):
		s += 1
	if st["hope"] >= int(SB["hope_min"]) * FX.ONE and st["disc"] <= int(SB["disc_max"]) * FX.ONE:
		s += 1
	# Gobierno humano: sin leyes extremas ni trabajo infantil y casi sin muertes.
	if flag("extremo") == 0 and flag("trabajo_infantil") == 0 and surv >= int(SB["humane_surv_pct"]):
		s += 1
	return clampi(s, 1, 5)

func compute_epilogue() -> Array:
	var out := []
	var T: Dictionary = db["texts"]
	out.append(T.get("epi_" + st["end_reason"], ""))
	if st["path"] != "":
		out.append(T.get("epi_path_" + st["path"], ""))
	for lid in st["laws"]:
		var key: String = "epi_law_" + str(lid)
		if T.has(key):
			out.append(T[key])
	if int(st["arrived_total"]) >= 60:
		out.append(T.get("epi_refugios", ""))
	if int(st["dead"]) == 0:
		out.append(T.get("epi_sin_muertes", ""))
	elif int(st["dead"]) >= 60:
		out.append(T.get("epi_muchas_muertes", ""))
	if int(st["autos_total"]) > 0:
		out.append(T.get("epi_automatas", ""))
	for f in st["flags"]:
		var key2: String = "epi_flag_" + str(f)
		if T.has(key2):
			out.append(T[key2])
	return out

# ---------------------------------------------------------------- órdenes
## Aplica una orden del jugador o de un bot. Devuelve "" si se aplicó o el motivo del rechazo.
func command(c: Dictionary) -> String:
	if st["status"] != "playing":
		return "partida terminada"
	var why := _command(c)
	if why != "":
		notes.append({"tick": st["tick"], "kind": "rechazo", "text": why})
	return why

func _int(c: Dictionary, k: String, def: int = 0) -> int:
	var v = c.get(k, def)
	if typeof(v) == TYPE_INT:
		return v
	if typeof(v) == TYPE_FLOAT:
		return int(v)
	if typeof(v) == TYPE_BOOL:
		return 1 if v else 0
	return def

func _command(c: Dictionary) -> String:
	var kind: String = str(c.get("c", ""))
	match kind:
		"build":
			return _cmd_build(str(c.get("type", "")), _int(c, "x", -1), _int(c, "y", -1))
		"demolish":
			return _cmd_demolish(_int(c, "bid"))
		"upgrade":
			return _cmd_upgrade(_int(c, "bid"))
		"staff":
			return _cmd_staff(_int(c, "bid"), _int(c, "o"), _int(c, "i"), _int(c, "n"))
		"toggle":
			var b := building(_int(c, "bid"))
			if b.is_empty():
				return "edificio inexistente"
			b["on"] = 1 if _int(c, "on") != 0 else 0
			return ""
		"shift":
			var b2 := building(_int(c, "bid"))
			if b2.is_empty():
				return "edificio inexistente"
			var v := _int(c, "v")
			if v < 0 or v > shift_max_allowed():
				return "turno no permitido por las leyes"
			var allowed: Array = bdef(b2["type"]).get("shifts", [0])
			if not (v in allowed):
				return "este edificio no admite ese turno"
			b2["shift"] = v
			return ""
		"prio":
			var b3 := building(_int(c, "bid"))
			if b3.is_empty():
				return "edificio inexistente"
			b3["prio"] = 1 if _int(c, "v") != 0 else 0
			return ""
		"focus":
			var b4 := building(_int(c, "bid"))
			if b4.is_empty() or bdef(b4["type"]).get("kind", "") != "gather":
				return "no es una cuadrilla de acopio"
			var f: String = str(c.get("v", "auto"))
			if not (f in ["auto", "carbon", "madera", "metal"]):
				return "recurso inválido"
			b4["focus"] = f
			return ""
		"gen_on":
			return _cmd_gen_on(_int(c, "v"))
		"gen_level":
			var lv := _int(c, "v")
			if lv < 1 or lv > gen_max_level():
				return "nivel no disponible"
			st["gen"]["level"] = lv
			return ""
		"gen_over":
			var ov := 1 if _int(c, "v") != 0 else 0
			if ov == 1 and st["gen"]["on"] == 0:
				return "el generador está apagado"
			st["gen"]["over"] = ov
			return ""
		"heaters":
			if mod("heaters") <= 0:
				return "requiere investigación"
			st["gen"]["heaters"] = 1 if _int(c, "v") != 0 else 0
			return ""
		"research":
			return _cmd_research(str(c.get("id", "")))
		"law":
			var lid: String = str(c.get("id", ""))
			var w := law_check(lid)
			if w != "":
				return w
			enact_law(lid)
			return ""
		"event":
			return "" if resolve_event(_int(c, "inst"), _int(c, "choice")) else "opción no disponible"
		"request":
			return "" if answer_request(_int(c, "accept") != 0) else "no hay pedido"
		"expedition":
			return send_expedition(_int(c, "bid"), str(c.get("loc", "")))
		"auto_build":
			return _cmd_auto_build(_int(c, "bid"))
		"auto_assign":
			return _cmd_auto_assign(_int(c, "bid"), _int(c, "v"))
	return "orden desconocida"

func _create_building(type: String, x: int, y: int) -> Dictionary:
	var d: Dictionary = bdef(type)
	var w: int = d["size"][0]
	var h: int = d["size"][1]
	var b := {
		"id": st["next_bid"], "type": type, "x": x, "y": y, "w": w, "h": h,
		"cx2": 2 * x + w, "cy2": 2 * y + h,
		"state": 0, "left": int(d["build_h"]) * FX.ONE, "on": 1,
		"do": 0, "di": 0, "dn": 0, "o": 0, "i": 0, "n": 0, "bat": [],
		"auto": 0, "auto_ok": 0, "shift": 0, "prio": 0,
		"temp": outdoor(), "lvl": level_of(outdoor()),
		"site": -1, "nodes": [], "focus": "auto", "up": "", "up_left": 0,
	}
	st["next_bid"] += 1
	if d.has("site"):
		var s := site_at(x, y)
		s["bid"] = b["id"]
		b["site"] = s["id"]
	if d.get("kind", "") == "gather":
		var ids := nodes_in_radius(b["cx2"], b["cy2"], int(d["radius"]))
		# más cercanas primero
		ids.sort_custom(func(a, bb):
			var na: Dictionary = st["nodes"][a]
			var nb: Dictionary = st["nodes"][bb]
			var da: int = (2 * na["x"] + 2 - b["cx2"]) ** 2 + (2 * na["y"] + 2 - b["cy2"]) ** 2
			var dbb: int = (2 * nb["x"] + 2 - b["cx2"]) ** 2 + (2 * nb["y"] + 2 - b["cy2"]) ** 2
			return da < dbb or (da == dbb and a < bb))
		b["nodes"] = ids
	st["buildings"].append(b)
	reindex_buildings()
	fill_rect(x, y, w, h, b["id"])
	return b

func _cmd_build(type: String, x: int, y: int) -> String:
	var why := check_place(type, x, y)
	if why != "":
		return why
	var d: Dictionary = bdef(type)
	if not pay(d.get("cost", {})):
		return "recursos insuficientes"
	_create_building(type, x, y)
	st["built_total"] = int(st.get("built_total", 0)) + 1
	return ""

func _cmd_demolish(bid: int) -> String:
	var b := building(bid)
	if b.is_empty():
		return "edificio inexistente"
	var d: Dictionary = bdef(b["type"])
	if d.get("kind", "") == "scouts":
		var t := team_of(bid)
		if not t.is_empty() and t["state"] != "home":
			return "el equipo está de expedición"
		st["teams"].erase(t)
	# Reintegro limitado (nunca más del 50%); los núcleos no se recuperan.
	var pct: int = B["build"]["refund_pct"]
	var cost: Dictionary = d.get("cost", {})
	for r in cost:
		if r == "nucleos":
			continue
		add_res(r, int(cost[r]) * FX.ONE * pct / 100, "demolicion")
	if int(b["auto"]) > 0:
		st["autos_free"] += int(b["auto"])
	if d.get("kind", "") == "burial":
		# Los que estaban enterrados ahí ya no ocupan lugar en los demás cementerios.
		st["buried"] = maxi(0, int(st["buried"]) - int(b.get("used", 0)))
	if int(b["site"]) >= 0:
		st["sites"][b["site"]]["bid"] = 0
		fill_rect(b["x"], b["y"], b["w"], b["h"], G_SITE)
	else:
		fill_rect(b["x"], b["y"], b["w"], b["h"], G_FREE)
	st["buildings"].erase(b)
	reindex_buildings()
	recompute_caps()
	st["demolished"] = int(st.get("demolished", 0)) + 1
	return ""

func upgrade_cost(b: Dictionary) -> Dictionary:
	var d: Dictionary = bdef(b["type"])
	var nt: String = d.get("upgrade_to", "")
	if nt == "":
		return {}
	var cost := {}
	var nc: Dictionary = bdef(nt).get("cost", {})
	var oc: Dictionary = d.get("cost", {})
	var pct: int = B["build"]["refund_pct"]
	for r in nc:
		cost[r] = maxi(0, int(nc[r]) - int(oc.get(r, 0)) * pct / 100)
	return cost

func _cmd_upgrade(bid: int) -> String:
	var b := building(bid)
	if b.is_empty():
		return "edificio inexistente"
	if b["state"] != 1 or b["up"] != "":
		return "no disponible ahora"
	var nt: String = bdef(b["type"]).get("upgrade_to", "")
	if nt == "":
		return "no tiene mejora"
	if not is_unlocked(nt):
		return "mejora bloqueada"
	var cost := upgrade_cost(b)
	if not pay(cost):
		return "recursos insuficientes"
	b["up"] = nt
	b["up_left"] = int(bdef(nt)["build_h"]) * FX.ONE / 2
	return ""

func _cmd_staff(bid: int, o: int, i: int, n: int) -> String:
	var b := building(bid)
	if b.is_empty():
		return "edificio inexistente"
	var d: Dictionary = bdef(b["type"])
	var mx := staff_max(d)
	if mx <= 0:
		return "este edificio no lleva personal"
	var types := staff_types(d)
	o = clampi(o, 0, mx) if "obreros" in types else 0
	i = clampi(i, 0, mx) if "ingenieros" in types else 0
	n = clampi(n, 0, mx) if child_allowed(d) else 0
	# Recortar al máximo total (prioridad: ingenieros, obreros, niños)
	var over := o + i + n - mx
	if over > 0:
		var cut := mini(over, n)
		n -= cut
		over -= cut
		cut = mini(over, o)
		o -= cut
		over -= cut
		i -= over
	b["do"] = o
	b["di"] = i
	b["dn"] = n
	return ""

func _cmd_gen_on(v: int) -> String:
	var g: Dictionary = st["gen"]
	if v != 0 and g["on"] == 0:
		var ign: int = int(B["gen"]["ignite_coal_m"])
		if res("carbon") < ign + gen_coal_per_hour():
			return "no hay carbón para encender"
		take_res("carbon", ign)
		g["on"] = 1
		g["warm"] = int(B["gen"]["warm_hours"])
		return ""
	if v == 0:
		g["on"] = 0
		g["over"] = 0
	return ""

func research_check(id: String) -> String:
	if not db["research"].has(id):
		return "investigación desconocida"
	var R: Dictionary = st["research"]
	if id in R["done"]:
		return "ya investigada"
	var d: Dictionary = db["research"][id]
	for r in d.get("req", []):
		if not (r in R["done"]):
			return "requiere investigación previa"
	if not R["paid"].has(id) and not can_afford(d.get("cost", {})):
		return "recursos insuficientes"
	return ""

func _cmd_research(id: String) -> String:
	if id == "":
		st["research"]["cur"] = ""
		return ""
	var why := research_check(id)
	if why != "":
		return why
	var R: Dictionary = st["research"]
	if not R["paid"].has(id):
		pay(db["research"][id].get("cost", {}))
		R["paid"][id] = 1
	R["cur"] = id
	return ""

func _cmd_auto_build(bid: int) -> String:
	var b := building(bid)
	if b.is_empty() or bdef(b["type"]).get("kind", "") != "factory" or b["state"] != 1:
		return "no es una fábrica activa"
	if int(b.get("queue", 0)) >= 2:
		return "cola llena"
	if not pay(B["auto"]["cost"]):
		return "recursos insuficientes"
	b["queue"] = int(b.get("queue", 0)) + 1
	return ""

func _cmd_auto_assign(bid: int, v: int) -> String:
	var b := building(bid)
	if b.is_empty():
		return "edificio inexistente"
	var d: Dictionary = bdef(b["type"])
	if not d.get("auto_ok", false):
		return "los autómatas no pueden trabajar aquí"
	v = clampi(v, 0, int(B["auto"]["max_per_building"]))
	var cur: int = b["auto"]
	var delta := v - cur
	if delta > int(st["autos_free"]):
		return "no hay autómatas libres"
	st["autos_free"] -= delta
	b["auto"] = v
	return ""

# ---------------------------------------------------------------- guardado
func serialize() -> PackedByteArray:
	return var_to_bytes({"magic": "BRASA", "v": SAVE_VERSION, "rng": rng, "st": st})

func deserialize(bytes: PackedByteArray) -> bool:
	var d = bytes_to_var(bytes)
	if typeof(d) != TYPE_DICTIONARY or d.get("magic", "") != "BRASA":
		return false
	var v: int = d.get("v", 0)
	if v > SAVE_VERSION:
		return false
	st = _migrate(d["st"], v)
	rng = d["rng"]
	rebuild_grid()
	rebuild_mods()
	recompute_caps()
	reindex_buildings()
	notes = []
	return true

func _migrate(s: Dictionary, from: int) -> Dictionary:
	if from < 2:
		_migrate_v1(s)
	return s

## Formato 1 -> 2: lotes de personal sin clase, cementerios sin ocupación propia,
## sin acumulador de fatiga y eventos pendientes sin semilla propia.
func _migrate_v1(s: Dictionary) -> void:
	var t: int = s["tick"]
	var left: int = s.get("buried", 0)
	for b in s["buildings"]:
		# Lotes: los que todavía viajan se reparten en orden obreros, ingenieros, niños.
		var old: Array = b.get("bat", [])
		var have := [int(b["o"]), int(b["i"]), int(b["n"])]
		var nb := []
		var i := old.size() - 2
		while i >= 0:
			var n: int = old[i]
			var at: int = old[i + 1]
			if at > t:
				for k in 3:
					var m := mini(n, have[k])
					if m > 0:
						nb.append_array([m, at, k])
						have[k] -= m
						n -= m
			i -= 2
		for k in 3:
			if have[k] > 0:
				nb.append_array([have[k], 0, k])
		b["bat"] = nb
		if db["buildings"].has(b["type"]) and bdef(b["type"]).get("kind", "") == "burial" and not b.has("used"):
			var u := mini(left, int(bdef(b["type"])["graves"]))
			b["used"] = u
			left -= u
	s["buried"] = int(s.get("buried", 0)) - left
	if not s.has("fat"):
		s["fat"] = [0, 0, 0]
	var seq := 0
	for p in s.get("ev_pending", []):
		if not p.has("rs"):
			seq += 1
			p["rs"] = SimRng.seed_state((int(s["seed"]) & SimRng.MASK) * 1000003 + int(p["inst"]) * 7919 + seq)

func clone() -> Simulation:
	var s := Simulation.new()
	s.deserialize(serialize())
	return s

func state_hash() -> String:
	var hc := HashingContext.new()
	hc.start(HashingContext.HASH_SHA256)
	hc.update(var_to_bytes([rng, st]))
	return hc.finish().hex_encode()

# ---------------------------------------------------------------- métricas
## Sobrante final de cada material respecto del total obtenido (en %).
func leftovers_pct() -> Dictionary:
	var out := {}
	for r in ["carbon", "madera", "metal", "nucleos"]:
		out[r] = int(st["res"][r]) * 100 / maxi(1, int(st["obtained"][r]))
	var ratio := cook_ratio()
	var food_end: int = int(st["res"]["crudo"]) + int(st["res"]["raciones"]) * FX.ONE / ratio
	var food_ob: int = int(st["obtained"]["crudo"]) + int(B["start"]["res"]["raciones"]) * FX.ONE * FX.ONE / int(B["food"]["cook_ratio_m"])
	out["comida"] = food_end * 100 / maxi(1, food_ob)
	return out
