class_name SimSociety
extends SimEconomy
## Esperanza y descontento, libro de leyes, pedidos del pueblo y eventos.
## Incluye el motor genérico de condiciones y efectos que usan leyes,
## eventos, pedidos y ubicaciones de exploración.

# ---------------------------------------------------------------- ánimo por hora
func mood_update() -> void:
	var S: Dictionary = B["society"]
	var pop := present_pop()
	if pop <= 0:
		return
	var homeless: int = st.get("homeless", 0)
	if homeless > 0:
		var f := homeless * FX.ONE / pop
		add_disc(int(S["homeless_disc_day_m"]) * f / FX.ONE / 24, "sin_techo")
		add_hope(-int(S["homeless_hope_day_m"]) * f / FX.ONE / 24, "sin_techo")
	var dist: Array = st.get("home_dist", [0, 0, 0, 0, FX.ONE, 0])
	var cold: int = int(dist[0]) * 2 + int(dist[1])
	if cold > 0:
		add_disc(int(S["cold_disc_day_m"]) * cold / FX.ONE / 24, "frio")
		add_hope(-int(S["cold_hope_day_m"]) * cold / FX.ONE / 24, "frio")
	var untreated := maxi(0, total_sick() - int(st.get("treated", 0)))
	if untreated > 0:
		var fs := untreated * FX.ONE / pop
		add_hope(-int(S["sick_hope_day_m"]) * fs / FX.ONE / 24, "enfermos")
		add_disc(int(S["sick_disc_day_m"]) * fs / FX.ONE / 24, "enfermos")
	# Turnos largos
	var h := hour()
	var ext := 0
	var cont := 0
	for b in st["buildings"]:
		if b["o"] + b["i"] + b["n"] == 0 or not building_works(b):
			continue
		var sh: int = b["shift"]
		if sh == 1 and h >= 18 and h < 22:
			ext += 1
		elif sh == 2 and (h >= 18 or h < 8):
			cont += 1
	if ext > 0:
		add_disc(int(S["ext_disc_bh_m"]) * ext, "turnos")
	if cont > 0:
		add_disc(int(S["cont_disc_bh_m"]) * cont, "turnos")
	# Generador apagado mientras la gente está en casa
	if st["gen"]["on"] == 0 and outdoor() < int(S["gen_off_temp"]):
		add_disc(int(S["gen_off_disc_h_m"]), "generador")
		add_hope(-int(S["gen_off_hope_h_m"]), "generador")
	# Leyes y efectos permanentes
	add_hope(mod("hope_day_m") / 24, "leyes")
	add_disc(mod("disc_day_m") / 24, "leyes")
	# Buen gobierno: si no falta nada, el ánimo mejora despacio.
	if homeless == 0 and int(st["hungry"]) == 0 and cold == 0 and untreated * 20 <= pop and int(st["bodies"]) == 0:
		add_hope(int(S["good_hope_day_m"]) / 24, "bienestar")
		add_disc(-int(S["good_disc_day_m"]) / 24, "bienestar")
	else:
		# Desgaste natural del invierno cuando algo falla.
		add_hope(-int(S["strain_hope_day_m"]) / 24, "penurias")

## Fatiga por turno continuo: se evalúa una vez al día.
func fatigue_update() -> void:
	var pcm: int = B["shift"]["cont_death_pcm"]
	for b in st["buildings"]:
		if int(b["shift"]) == 2 and building_works(b) and b["o"] > 0:
			var d := stoch(int(b["o"]) * pcm * FX.ONE / 100000)
			if d > 0:
				kill_healthy("obreros", d, "agotamiento")

# ---------------------------------------------------------------- condiciones
func cond_ok(c: Dictionary) -> bool:
	var k: String = c["k"]
	var v = c.get("v", 0)
	match k:
		"pop_min":
			return total_pop() >= int(v)
		"pop_max":
			return total_pop() <= int(v)
		"res_min":
			return res(c["r"]) >= int(v) * FX.ONE
		"res_max":
			return res(c["r"]) <= int(v) * FX.ONE
		"flag":
			return flag(v) > 0
		"noflag":
			return flag(v) == 0
		"law":
			return v in st["laws"]
		"nolaw":
			return not (v in st["laws"])
		"path":
			return st["path"] == v
		"research":
			return v in st["research"]["done"]
		"noresearch":
			return not (v in st["research"]["done"])
		"day_min":
			return day() >= int(v)
		"day_max":
			return day() <= int(v)
		"sick_min":
			return total_sick() >= int(v)
		"sick_max":
			return total_sick() <= int(v)
		"hope_min":
			return st["hope"] >= int(v) * FX.ONE
		"hope_max":
			return st["hope"] <= int(v) * FX.ONE
		"disc_min":
			return st["disc"] >= int(v) * FX.ONE
		"disc_max":
			return st["disc"] <= int(v) * FX.ONE
		"wave":
			return in_wave() == (int(v) == 1)
		"homeless_min":
			return int(st.get("homeless", 0)) >= int(v)
		"no_homeless":
			return int(st.get("homeless", 0)) == 0
		"bodies_min":
			return int(st["bodies"]) >= int(v)
		"no_bodies":
			return int(st["bodies"]) == 0
		"building":
			return count_type(c["type"], false) >= int(c.get("min", 1))
		"nobuilding":
			return count_type(c["type"], true) == 0
		"hungry":
			return int(st["hungry"]) > 0
		"gen_over":
			return int(st["gen"]["over"]) == 1
		"gen_level_min":
			return int(st["gen"]["level"]) >= int(v) and int(st["gen"]["on"]) == 1
		"deaths_min":
			return int(st["dead"]) >= int(v)
		"children_min":
			return int(st["pop"]["ninos"]["h"]) >= int(v)
		"engineers_min":
			return int(st["pop"]["ingenieros"]["h"]) >= int(v)
		"autos_min":
			return int(st["autos_total"]) >= int(v)
		"heat_homes_min":
			var dist: Array = st.get("home_dist", [])
			if dist.is_empty() or int(st.get("homeless", 0)) > 0:
				return false
			for l in range(0, int(v)):
				if int(dist[l]) > 0:
					return false
			return true
		"stress_max":
			return int(st["gen"]["stress"]) <= int(v) * FX.ONE
		"rand":
			return rnd(100) < int(v)
		"explored_min":
			return int(st["explored"]) >= int(v)
	push_warning("Condición desconocida: " + k)
	return false

func conds_ok(list: Array) -> bool:
	for c in list:
		if not cond_ok(c):
			return false
	return true

# ---------------------------------------------------------------- efectos
func apply_effects(list: Array, ctx: Dictionary = {}) -> void:
	for e in list:
		var k: String = e["k"]
		var v = e.get("v", 0)
		match k:
			"mod":
				pass # leyes/investigación: se recalculan en rebuild_mods()
			"perm_mod":
				st["perm_mods"].append([e["key"], int(v)])
				rebuild_mods()
			"hope":
				add_hope(int(v) * FX.ONE, ctx.get("cause", "eventos"))
			"disc":
				add_disc(int(v) * FX.ONE, ctx.get("cause", "eventos"))
			"res":
				var amt := int(v) * FX.ONE
				if amt >= 0:
					add_res(e["r"], amt, "evento")
				else:
					take_upto(e["r"], -amt)
			"flag":
				set_flag(v, flag(v) + 1)
			"unflag":
				st["flags"].erase(v)
			"refugees":
				add_arrival(int(e.get("hours", 12)), int(e.get("o", 0)), int(e.get("i", 0)), int(e.get("n", 0)), int(e.get("sick", 0)))
			"sick":
				var left := int(v)
				for c in CLASSES:
					left -= make_sick(c, mini(left, healthy(c) / 2 + 1), int(e.get("grave", 0)) == 1)
					if left <= 0:
						break
			"kill":
				var left2 := int(v)
				for c in ["obreros", "ingenieros", "ninos"]:
					if left2 <= 0:
						break
					left2 -= kill_healthy(c, left2, e.get("cause", "accidente"))
			"followup":
				st["ev_sched"].append({"id": e["id"], "tick": st["tick"] + int(e.get("hours", 24))})
			"stress":
				st["gen"]["stress"] = clampi(int(st["gen"]["stress"]) + int(v) * FX.ONE, 0, 99 * FX.ONE)
			"hunt_zone":
				for z in st["hunt"]:
					z["stock"] = mini(int(z["max"]), int(z["stock"]) + int(v) * FX.ONE / maxi(1, (st["hunt"] as Array).size()))
			"reveal":
				reveal_location(v)
			"autos":
				st["autos_free"] += int(v)
				st["autos_total"] += int(v)
			"law_cd":
				st["law_ready"] = maxi(int(st["law_ready"]), st["tick"]) + int(v)
			"rand":
				if rnd(100) < int(e.get("pct", 50)):
					apply_effects(e.get("then", []), ctx)
				else:
					apply_effects(e.get("else", []), ctx)
			"note":
				note("evento", v)
			"leave":
				var n0 := mini(int(v), healthy("obreros"))
				st["pop"]["obreros"]["h"] -= n0
				st["left_total"] = int(st.get("left_total", 0)) + n0
				if n0 > 0:
					note("evento", text("se_van") % n0)
			"cure":
				var n := int(v)
				for c in CLASSES:
					var p: Dictionary = st["pop"][c]
					var cl := mini(n, p["sl"])
					p["sl"] -= cl
					p["h"] += cl
					n -= cl
			_:
				push_warning("Efecto desconocido: " + k)

# ---------------------------------------------------------------- leyes
func law_check(id: String) -> String:
	if not db["laws"].has(id):
		return "ley desconocida"
	var L: Dictionary = db["laws"][id]
	if id in st["laws"]:
		return "ya promulgada"
	if st["tick"] < int(st["law_ready"]):
		return "el consejo aún delibera"
	if day() < int(L.get("min_day", 1)):
		return "todavía no"
	for r in L.get("req", []):
		if not (r in st["laws"]):
			return "requiere otra ley"
	for x in L.get("excl", []):
		if x in st["laws"]:
			return "excluida por otra ley"
	var p: String = L.get("path", "")
	if p != "" and st["path"] != "" and st["path"] != p:
		return "otra senda elegida"
	if L.has("req_research") and not (L["req_research"] in st["research"]["done"]):
		return "requiere investigación"
	if not conds_ok(L.get("conds", [])):
		return "no se cumplen las condiciones"
	return ""

func enact_law(id: String) -> bool:
	if law_check(id) != "":
		return false
	var L: Dictionary = db["laws"][id]
	st["laws"].append(id)
	var p: String = L.get("path", "")
	if p != "" and st["path"] == "":
		st["path"] = p
	st["law_ready"] = st["tick"] + int(B["laws"]["cooldown_h"])
	rebuild_mods()
	apply_effects(L.get("effects", []), {"cause": "leyes"})
	note("ley", text("ley_promulgada") % L["name"], {"id": id})
	_fire_trigger("law:" + id)
	return true

# ---------------------------------------------------------------- eventos
func events_daily_roll() -> void:
	var E: Dictionary = B["events"]
	if (st["ev_pending"] as Array).size() > 0:
		return
	if rnd(100) >= int(E["roll_pct"]):
		return
	var pool := []
	var total := 0
	for id in db["events"]:
		var ev: Dictionary = db["events"][id]
		if ev.get("trigger", "daily") != "daily":
			continue
		if not _event_eligible(id, ev):
			continue
		var w: int = int(ev.get("weight", 10))
		pool.append([id, w])
		total += w
	if total <= 0:
		return
	var r := rnd(total)
	for p in pool:
		r -= int(p[1])
		if r < 0:
			fire_event(p[0])
			return

func _event_eligible(id: String, ev: Dictionary) -> bool:
	var fired: Dictionary = st["ev_fired"]
	if ev.get("unique", true) and fired.has(id):
		return false
	if fired.has(id):
		var cd: int = int(ev.get("cooldown_days", 5)) * 24
		if st["tick"] - int(fired[id]) < cd:
			return false
	if day() < int(ev.get("day_min", 1)) or day() > int(ev.get("day_max", 999)):
		return false
	return conds_ok(ev.get("conds", []))

func fire_event(id: String, ctx: Dictionary = {}) -> void:
	if not db["events"].has(id):
		return
	var ev: Dictionary = db["events"][id]
	st["ev_fired"][id] = st["tick"]
	st["ev_seq"] += 1
	var inst := {"inst": st["ev_seq"], "id": id, "deadline": st["tick"] + int(ev.get("timeout_h", B["events"]["timeout_h"])), "ctx": ctx}
	var choices: Array = ev.get("choices", [])
	if choices.size() <= 1:
		# Evento informativo: se aplica de inmediato.
		if choices.size() == 1:
			apply_effects(choices[0].get("effects", []), {"cause": "eventos"})
		note("evento", ev["title"], {"event": id, "info": 1})
		return
	st["ev_pending"].append(inst)
	note("evento", ev["title"], {"event": id, "inst": inst["inst"]})

func choice_ok(id: String, idx: int) -> bool:
	var ev: Dictionary = db["events"].get(id, {})
	var ch: Array = ev.get("choices", [])
	if idx < 0 or idx >= ch.size():
		return false
	var c: Dictionary = ch[idx]
	if not conds_ok(c.get("req", [])):
		return false
	return can_afford(c.get("cost", {}))

func resolve_event(inst_id: int, idx: int) -> bool:
	var pend: Array = st["ev_pending"]
	for i in pend.size():
		var p: Dictionary = pend[i]
		if int(p["inst"]) != inst_id:
			continue
		if not choice_ok(p["id"], idx):
			return false
		var c: Dictionary = db["events"][p["id"]]["choices"][idx]
		pay(c.get("cost", {}))
		pend.remove_at(i)
		apply_effects(c.get("effects", []), {"cause": "eventos"})
		st["ev_choices"].append([p["id"], idx])
		return true
	return false

func events_update() -> void:
	# Vencimientos: se aplica la opción por defecto (o la primera válida).
	var pend: Array = st["ev_pending"]
	var i := 0
	while i < pend.size():
		var p: Dictionary = pend[i]
		if st["tick"] >= int(p["deadline"]):
			var ev: Dictionary = db["events"][p["id"]]
			var idx: int = int(ev.get("default", 0))
			if not choice_ok(p["id"], idx):
				idx = -1
				for j in (ev["choices"] as Array).size():
					if choice_ok(p["id"], j):
						idx = j
						break
			if idx < 0:
				pend.remove_at(i)
				continue
			if resolve_event(int(p["inst"]), idx):
				note("evento", text("evento_vencido") % ev["title"])
				continue
		i += 1
	# Eventos encadenados programados
	var sch: Array = st["ev_sched"]
	i = 0
	while i < sch.size():
		if st["tick"] >= int(sch[i]["tick"]):
			var id: String = sch[i]["id"]
			sch.remove_at(i)
			var ev2: Dictionary = db["events"].get(id, {})
			if not ev2.is_empty() and conds_ok(ev2.get("conds", [])):
				fire_event(id)
		else:
			i += 1
	var h := hour()
	if h in B["events"]["roll_hours"]:
		events_daily_roll()

func _fire_trigger(trig: String) -> void:
	for id in db["events"]:
		var ev: Dictionary = db["events"][id]
		if ev.get("trigger", "daily") == trig and _event_eligible(id, ev):
			fire_event(id)

# ---------------------------------------------------------------- pedidos
func requests_update() -> void:
	var R: Dictionary = st["req"]
	var RB: Dictionary = B["requests"]
	# Oferta vencida = rechazada.
	if not (R["offer"] as Dictionary).is_empty() and st["tick"] >= int(R["offer"]["expires"]):
		answer_request(false)
	# Activos
	var act: Array = R["active"]
	var i := 0
	while i < act.size():
		var a: Dictionary = act[i]
		var def: Dictionary = db["requests"][a["id"]]
		if goal_met(def["goal"], a):
			apply_effects(def.get("reward", []), {"cause": "pedidos"})
			note("pedido", text("pedido_cumplido") % def["name"], {"ok": 1})
			st["req_ok"] += 1
			act.remove_at(i)
			continue
		if st["tick"] >= int(a["deadline"]):
			apply_effects(def.get("penalty", []), {"cause": "pedidos"})
			note("pedido", text("pedido_fallido") % def["name"], {"ok": 0})
			st["req_fail"] += 1
			act.remove_at(i)
			continue
		i += 1
	if hour() == int(RB["offer_hour"]) and (R["offer"] as Dictionary).is_empty() and act.is_empty() and st["tick"] >= int(R["next"]):
		var pool := []
		for id in db["requests"]:
			var d: Dictionary = db["requests"][id]
			if day() < int(d.get("day_min", 1)) or day() > int(d.get("day_max", 999)):
				continue
			if R["done"].has(id) and not d.get("repeat", false):
				continue
			if not conds_ok(d.get("conds", [])):
				continue
			if goal_met(d["goal"], {"base": _goal_base(d["goal"])}):
				continue
			pool.append(id)
		if pool.size() > 0:
			var id: String = pool[rnd(pool.size())]
			R["offer"] = {"id": id, "expires": st["tick"] + int(RB["offer_hours"])}
			note("pedido", text("pedido_nuevo") % db["requests"][id]["name"], {"id": id})

func answer_request(accept: bool) -> bool:
	var R: Dictionary = st["req"]
	if (R["offer"] as Dictionary).is_empty():
		return false
	var id: String = R["offer"]["id"]
	var d: Dictionary = db["requests"][id]
	R["offer"] = {}
	R["done"][id] = 1
	R["next"] = st["tick"] + int(B["requests"]["gap_h"]) + rnd(int(B["requests"]["gap_rand_h"]) + 1)
	if accept:
		R["active"].append({"id": id, "deadline": st["tick"] + int(d["hours"]), "base": _goal_base(d["goal"])})
		add_hope(int(B["requests"]["accept_hope_m"]), "pedidos")
	else:
		add_disc(int(B["requests"]["decline_disc_m"]), "pedidos")
	return true

func _goal_base(g: Dictionary) -> int:
	match g["k"]:
		"count_delta":
			var n := 0
			for t in g["types"]:
				n += count_type(t, false)
			return n
		"research_delta":
			return (st["research"]["done"] as Array).size()
		"explore_delta":
			return int(st["explored"])
	return 0

func goal_met(g: Dictionary, a: Dictionary) -> bool:
	match g["k"]:
		"count_delta":
			var n := 0
			for t in g["types"]:
				n += count_type(t, false)
			return n - int(a.get("base", 0)) >= int(g["v"])
		"count_min":
			var n2 := 0
			for t in g["types"]:
				n2 += count_type(t, false)
			return n2 >= int(g["v"])
		"research_delta":
			return (st["research"]["done"] as Array).size() - int(a.get("base", 0)) >= int(g["v"])
		"explore_delta":
			return int(st["explored"]) - int(a.get("base", 0)) >= int(g["v"])
		_:
			return cond_ok(g)
	return false
