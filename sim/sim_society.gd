class_name SimSociety
extends SimEconomy
## Esperanza y descontento, libro de leyes, pedidos del pueblo y eventos.
## Incluye el motor genérico de condiciones y efectos que usan leyes,
## eventos, pedidos y ubicaciones de exploración.

# ---------------------------------------------------------------- ánimo por hora
## La esperanza y el descontento se acercan cada hora a un objetivo que depende de
## las condiciones actuales. Eventos, leyes y muertes además dan golpes inmediatos.
func mood_update() -> void:
	var M: Dictionary = B["mood"]
	var pop := present_pop()
	if pop <= 0:
		return
	var hp := {}
	var dp := {}
	var d := day()
	hp["base"] = int(M["base_hope"]) * FX.ONE - d * FX.ONE / int(M["hope_per_day_div"])
	dp["base"] = int(M["base_disc"]) * FX.ONE + d * FX.ONE / int(M["disc_per_day_div"])
	var homeless: int = st.get("homeless", 0)
	if homeless > 0:
		var f := homeless * FX.ONE / pop
		hp["sin_techo"] = -int(M["homeless_hope_pts"]) * f
		dp["sin_techo"] = int(M["homeless_disc_pts"]) * f
	var dist: Array = st.get("home_dist", [0, 0, 0, 0, FX.ONE, 0])
	var w: Array = M["cold_weights"]
	var cold := 0
	for l in LEVELS:
		cold += int(dist[l]) * int(w[l]) / 100
	if cold > 0:
		hp["frio"] = -int(M["cold_hope_pts"]) * cold
		dp["frio"] = int(M["cold_disc_pts"]) * cold
	var hungry: int = st["hungry"]
	if hungry > 0:
		var fh := mini(FX.ONE, hungry * FX.ONE / pop)
		hp["hambre"] = -int(M["hunger_hope_pts"]) * fh
		dp["hambre"] = int(M["hunger_disc_pts"]) * fh
	var untreated := maxi(0, total_sick() - int(st.get("treated", 0)))
	if untreated > 0:
		var fs := untreated * FX.ONE / pop
		hp["enfermos"] = -int(M["sick_hope_pts"]) * fs
		dp["enfermos"] = int(M["sick_disc_pts"]) * fs
	var bodies: int = mini(int(st["bodies"]), int(M["bodies_cap"]))
	if bodies > 0:
		hp["cuerpos"] = -bodies * int(M["bodies_hope_each_m"])
		dp["cuerpos"] = bodies * int(M["bodies_disc_each_m"])
	# Muertes recientes
	var dl: Array = st["death_log"]
	var win: int = st["tick"] - int(M["recent_death_hours"])
	while dl.size() > 0 and int(dl[0][0]) < win:
		dl.remove_at(0)
	var recent := 0
	for e in dl:
		recent += int(e[1])
	if recent > 0:
		var fr := recent * FX.ONE / pop
		var cap: int = int(M["recent_death_cap"]) * FX.ONE
		hp["muertes"] = -mini(cap, int(M["recent_death_hope_pts"]) * fr)
		dp["muertes"] = mini(cap, int(M["recent_death_disc_pts"]) * fr)
	if in_wave():
		hp["oleada"] = -int(M["wave_hope"]) * FX.ONE
		dp["oleada"] = int(M["wave_disc"]) * FX.ONE
	# Turnos largos: edificios con personal en turno prolongado o continuo, o que
	# trabajaron horas de ese turno en las últimas 24 h (cambiar el turno un rato
	# no esquiva el descontento).
	var sh := 0
	var tk: int = st["tick"]
	for b in st["buildings"]:
		var s2: int = 0
		if b["o"] + b["i"] + b["n"] > 0 and b["state"] == 1 and b["on"] == 1:
			s2 = b["shift"]
		if tk - int(b.get("sx2", -SHIFT_MEMORY_H)) < SHIFT_MEMORY_H:
			s2 = 2
		elif tk - int(b.get("sx1", -SHIFT_MEMORY_H)) < SHIFT_MEMORY_H:
			s2 = maxi(s2, 1)
		if s2 > 0:
			sh += int(M["shift_ext_disc"]) if s2 == 1 else int(M["shift_cont_disc"])
	if sh > 0:
		dp["turnos"] = mini(sh, int(M["shift_cap"])) * FX.ONE
	if st["gen"]["on"] == 0 and outdoor() < int(M["gen_off_temp"]):
		hp["generador"] = -int(M["gen_off_hope"]) * FX.ONE
		dp["generador"] = int(M["gen_off_disc"]) * FX.ONE
	var sc: int = int(M["social_cap"]) * FX.ONE
	if int(st.get("social_h", 0)) != 0:
		hp["edificios"] = clampi(int(st["social_h"]), -sc, sc)
	if int(st.get("social_d", 0)) != 0:
		dp["edificios"] = clampi(int(st["social_d"]), -sc, sc)
	if mod("hope_t_m") != 0:
		hp["leyes"] = mod("hope_t_m")
	if mod("disc_t_m") != 0:
		dp["leyes"] = mod("disc_t_m")
	if homeless == 0 and hungry == 0 and cold == 0 and untreated * 20 <= pop and int(st["bodies"]) == 0:
		hp["bienestar"] = int(M["good_hope"]) * FX.ONE
		dp["bienestar"] = -int(M["good_disc"]) * FX.ONE
	var th := 0
	for k in hp:
		th += int(hp[k])
	var td := 0
	for k in dp:
		td += int(dp[k])
	var lo: int = int(M["target_min"]) * FX.ONE
	var hi: int = int(M["target_max"]) * FX.ONE
	th = clampi(th, lo, hi)
	td = clampi(td, lo, hi)
	st["mood"] = {"ht": th, "dt": td, "hp": hp, "dp": dp}
	var rd: int = M["relax_div"]
	# Paso hacia el objetivo (sin pasar los límites 0..100 salvo para perder).
	var nh: int = st["hope"] + (th - int(st["hope"])) / rd
	var nd: int = st["disc"] + (td - int(st["disc"])) / rd
	st["hope"] = clampi(nh, 0, 100 * FX.ONE)
	st["disc"] = clampi(nd, 0, 100 * FX.ONE)

## Horas que el descontento por turnos largos sigue contando después de trabajarlas.
const SHIFT_MEMORY_H := 24
## Horas por día que solo cubre el turno de 24 h (de 22 a 8).
const CONT_ONLY_H := 10

## Fatiga por turno continuo: se tira una vez al día sobre las horas-persona que
## cada clase trabajó de verdad en horario continuo (obreros, ingenieros y niños).
## Un día completo en turno de 24 h equivale a cont_death_pcm por persona.
func fatigue_update() -> void:
	var pcm: int = B["shift"]["cont_death_pcm"]
	var fat: Array = st["fat"]
	for k in 3:
		var wh: int = fat[k]
		fat[k] = 0
		if wh <= 0:
			continue
		var d := stoch(wh * pcm * FX.ONE / 100000 / CONT_ONLY_H)
		if d > 0:
			kill_healthy(CLASSES[k], d, "agotamiento")

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
				if _ctx_rnd(ctx, 100) < int(e.get("pct", 50)):
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

## Azar de los efectos 'rand'. Un evento lleva su propia semilla ("rs"), fijada al
## aparecer y guardada con la partida: su desenlace no cambia según cuándo ni en qué
## orden se resuelva (recargar y esperar no sirve para volver a tirar). Sin semilla,
## usa el azar global (que también va en el guardado).
func _ctx_rnd(ctx: Dictionary, n: int) -> int:
	if not ctx.has("rs"):
		return rnd(n)
	var r: int = SimRng.step(int(ctx["rs"]))
	ctx["rs"] = r
	return r % maxi(1, n)

## Semilla propia de una instancia de evento: depende solo de la semilla de la
## partida, del número de instancia y del evento (no consume el azar global).
func _event_seed(id: String, seq: int) -> int:
	var h: int = (int(st["seed"]) & SimRng.MASK) * 1000003 + seq * 7919 + id.length() * 104729
	for i in id.length():
		h = (h * 31 + id.unicode_at(i)) & SimRng.MASK
	return SimRng.seed_state(h)

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

func cooldown_ok_range() -> bool:
	var cd: int = B["laws"]["cooldown_h"]
	return cd >= 24 and cd <= 36

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
	var inst := {"inst": st["ev_seq"], "id": id, "deadline": st["tick"] + int(ev.get("timeout_h", B["events"]["timeout_h"])), "ctx": ctx, "rs": _event_seed(id, int(st["ev_seq"]))}
	var choices: Array = ev.get("choices", [])
	if choices.size() <= 1:
		# Evento informativo: se aplica de inmediato.
		if choices.size() == 1:
			apply_effects(choices[0].get("effects", []), {"cause": "eventos", "rs": inst["rs"]})
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
		var ctx := {"cause": "eventos"}
		if p.has("rs"):
			# Misma secuencia de azar para cualquier opción y cualquier momento.
			ctx["rs"] = int(p["rs"])
		apply_effects(c.get("effects", []), ctx)
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
			# La espera hasta el próximo pedido se tira al ofrecerlo: contestar antes o
			# después no consume azar (no sirve para cambiar lo que viene).
			var gap: int = int(RB["gap_h"]) + rnd(int(RB["gap_rand_h"]) + 1)
			R["offer"] = {"id": id, "expires": st["tick"] + int(RB["offer_hours"]), "gap": gap}
			note("pedido", text("pedido_nuevo") % db["requests"][id]["name"], {"id": id})

func answer_request(accept: bool) -> bool:
	var R: Dictionary = st["req"]
	if (R["offer"] as Dictionary).is_empty():
		return false
	var id: String = R["offer"]["id"]
	var d: Dictionary = db["requests"][id]
	var gap: int = int(R["offer"].get("gap", -1))
	if gap < 0:
		gap = int(B["requests"]["gap_h"]) + rnd(int(B["requests"]["gap_rand_h"]) + 1)
	R["offer"] = {}
	R["done"][id] = 1
	R["next"] = st["tick"] + gap
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
