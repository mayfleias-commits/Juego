class_name TestSim
extends TestBase
## Tests del núcleo de simulación.

# ------------------------------------------------------------ datos
func test_datos_integridad() -> void:
	var s := fresh()
	var db := s.db
	for id in db["buildings"]:
		var b: Dictionary = db["buildings"][id]
		if b.has("req_research"):
			check(db["research"].has(b["req_research"]), "edificio %s pide investigación inexistente" % id)
		if b.has("req_law"):
			check(db["laws"].has(b["req_law"]), "edificio %s pide ley inexistente" % id)
		if b.has("upgrade_to"):
			check(db["buildings"].has(b["upgrade_to"]), "mejora inexistente en %s" % id)
	for id in db["research"]:
		for r in db["research"][id].get("req", []):
			check(db["research"].has(r), "investigación %s requiere %s inexistente" % [id, r])
	for id in db["laws"]:
		for r in db["laws"][id].get("req", []) + db["laws"][id].get("excl", []):
			check(db["laws"].has(r), "ley %s referencia %s inexistente" % [id, r])
	for id in db["locations"]:
		var L: Dictionary = db["locations"][id]
		for r in L.get("reveals", []):
			check(db["locations"].has(r), "ubicación %s revela %s inexistente" % [id, r])
		if L.has("event"):
			check(db["events"].has(L["event"]), "ubicación %s con evento inexistente" % id)
	for id in db["events"]:
		var ev: Dictionary = db["events"][id]
		check((ev["choices"] as Array).size() >= 1, "evento %s sin opciones" % id)
		for ch in ev["choices"]:
			_check_effects(db, ch.get("effects", []), id)
	check(db["events"].size() >= 40, "hay al menos 40 eventos")
	check(db["locations"].size() >= 15 and db["locations"].size() <= 20, "entre 15 y 20 ubicaciones")
	var paths := {"orden": 0, "fe": 0}
	for id in db["laws"]:
		var p: String = db["laws"][id].get("path", "")
		if p != "":
			paths[p] += 1
	check(paths["orden"] >= 8 and paths["orden"] <= 10, "Senda del Orden con 8-10 leyes")
	check(paths["fe"] >= 8 and paths["fe"] <= 10, "Senda de la Fe con 8-10 leyes")
	var branches := {}
	for id in db["research"]:
		var r: Dictionary = db["research"][id]
		branches[r["branch"]] = maxi(int(branches.get(r["branch"], 0)), int(r["tier"]))
	eq(branches.size(), 4, "4 ramas de investigación")
	for br in branches:
		eq(int(branches[br]), 4, "rama %s con 4 niveles" % br)

func _check_effects(db: Dictionary, effs: Array, ctx: String) -> void:
	var known := ["mod", "perm_mod", "hope", "disc", "res", "flag", "unflag", "refugees", "sick", "kill", "followup", "stress", "hunt_zone", "reveal", "autos", "law_cd", "rand", "note", "cure", "leave"]
	for e in effs:
		check(e["k"] in known, "efecto desconocido %s en %s" % [e["k"], ctx])
		if e["k"] == "followup":
			check(db["events"].has(e["id"]), "followup inexistente en " + ctx)
		if e["k"] == "reveal":
			check(db["locations"].has(e["v"]), "reveal inexistente en " + ctx)
		if e["k"] == "rand":
			_check_effects(db, e.get("then", []), ctx)
			_check_effects(db, e.get("else", []), ctx)

# ------------------------------------------------------------ determinismo
func _run_scripted(seed: int, hours: int, chunks: Array = []) -> Simulation:
	var s := fresh(seed)
	var bot := BotCompetent.new()
	bot.setup(s, seed)
	var h := 0
	while h < hours and s.st["status"] == "playing":
		bot.act()
		s.step()
		h += 1
	return s

func test_determinismo_misma_semilla() -> void:
	var a := _run_scripted(42, 24 * 12)
	var b := _run_scripted(42, 24 * 12)
	eq(a.state_hash(), b.state_hash(), "misma semilla y órdenes => mismo estado")
	var c := _run_scripted(43, 24 * 12)
	check(a.state_hash() != c.state_hash(), "otra semilla => otro estado")

func test_guardar_cargar_continuar() -> void:
	var s := fresh(99)
	var bot := BotCompetent.new()
	bot.setup(s, 99)
	for i in 24 * 6:
		bot.act()
		s.step()
	var saved := s.serialize()
	var bot_rs := bot.rs
	for i in 24 * 6:
		bot.act()
		s.step()
	var h1 := s.state_hash()
	var s2 := Simulation.new()
	check(s2.deserialize(saved), "carga la partida")
	var bot2 := BotCompetent.new()
	bot2.setup(s2, 99)
	bot2.rs = bot_rs
	# El bot vuelve a planificar en el mismo tick que el original (cada 2 h desde el inicio)
	bot2.last_plan = _last_plan_at(24 * 6)
	for i in 24 * 6:
		bot2.act()
		s2.step()
	eq(s2.state_hash(), h1, "cargar y continuar da el mismo resultado (el azar se guarda)")

func _last_plan_at(t: int) -> int:
	# El bot planifica en ticks pares: el último plan antes de t fue en t-2.
	return t - 2

func test_estado_solo_enteros() -> void:
	var s := _run_scripted(5, 24 * 5)
	check(_no_floats(s.st), "el estado no contiene floats")

func _no_floats(v) -> bool:
	match typeof(v):
		TYPE_FLOAT:
			return false
		TYPE_DICTIONARY:
			for k in v:
				if not _no_floats(v[k]):
					return false
		TYPE_ARRAY:
			for x in v:
				if not _no_floats(x):
					return false
	return true

func test_pausa_y_velocidad_no_cambian_resultado() -> void:
	# Simula el reloj real con distintos patrones de pausa/velocidad: la simulación
	# solo avanza por pasos enteros y las órdenes se aplican entre pasos.
	var hashes := []
	var patterns := [[[1, 16]], [[3, 33], [0, 16], [2, 100]], [[0, 50], [1, 7], [3, 16], [2, 41]], [[2, 16], [3, 250]]]
	for pattern in patterns:
		var s := fresh(77)
		var bot := BotCompetent.new()
		bot.setup(s, 77)
		var clock := SimClock.new()
		clock.sim = s
		clock.pre_step = bot.act
		clock.stop_at = 24 * 8
		var i := 0
		while s.tick() < 24 * 8:
			var pr: Array = pattern[i % pattern.size()]
			i += 1
			clock.speed = pr[0]
			clock.advance_ms(pr[1] * 40) # cuadros de distinto largo
		hashes.append(s.state_hash())
	for h in hashes:
		eq(h, hashes[0], "mismo resultado con pausa/x1/x2/x3")

# ------------------------------------------------------------ economía
func test_recoleccion_mitad_que_edificio() -> void:
	var s := fresh(11)
	var post_r: Dictionary = s.bdef("puesto_rec")["rates_m"]
	var pairs := {"carbon": "extractor", "madera": "aserradero", "metal": "mina_hierro"}
	for r in pairs:
		var b: Dictionary = s.bdef(pairs[r])
		eq(int(post_r[r]) * 2, int(b["rate_m"]), "recolección de %s = 50%% del edificio básico" % r)
		eq(b.get("outdoor", false), true, "%s es de exterior (misma curva de frío)" % pairs[r])
	# Verificación en marcha: misma hora, mismo personal llegado, misma temperatura.
	var site: Dictionary = s.free_sites("veta_carbon")[0]
	var ex := place_done(s, "extractor", site["x"], site["y"])
	var node: Dictionary = {}
	for n in s.st["nodes"]:
		if n["kind"] == "carbon":
			node = n
			break
	var p := s.find_spot_near("puesto_rec", node["x"], node["y"])
	var post := place_done(s, "puesto_rec", p.x, p.y)
	post["focus"] = "carbon"
	for b in [ex, post]:
		b["do"] = 10
		b["o"] = 10
		b["bat"] = [10, 0]
	s.st["res"]["carbon"] = 0
	s.caps["carbon"] = 1 << 40
	var before_site: int = site["amt"]
	var before_node: int = node["amt"]
	s.st["hour"] = 10
	s.st["outdoor"] = -25
	s.production_update()
	var got_ex: int = before_site - int(site["amt"])
	var got_post: int = before_node - int(node["amt"])
	check(got_ex > 0, "el extractor produce")
	eq(got_post * 2, got_ex, "en la misma hora el puesto rinde exactamente la mitad")

func test_almacen_limitado() -> void:
	var s := fresh()
	var cap := s.cap("madera")
	s.st["res"]["madera"] = cap - 5 * FX.ONE
	var stored := s.add_res("madera", 50 * FX.ONE)
	eq(stored, 5 * FX.ONE, "solo entra lo que cabe")
	eq(s.res("madera"), cap, "el stock no supera la capacidad")
	eq(int(s.st["wasted"]["madera"]), 45 * FX.ONE, "el excedente se pierde")

func test_demoler_devuelve_maximo_50() -> void:
	var s := fresh()
	s.st["res"]["madera"] = 200 * FX.ONE
	s.st["res"]["metal"] = 100 * FX.ONE
	for t in ["carpa", "deposito", "taller", "cocina"]:
		var p := free_spot(s, t)
		var before := s.res("madera") + s.res("metal")
		eq(s.command({"c": "build", "type": t, "x": p.x, "y": p.y}), "", "construye " + t)
		var bid: int = int(s.st["next_bid"]) - 1
		eq(s.command({"c": "demolish", "bid": bid}), "", "demuele " + t)
		var after := s.res("madera") + s.res("metal")
		var cost := 0
		for r in s.bdef(t)["cost"]:
			cost += int(s.bdef(t)["cost"][r]) * FX.ONE
		check(before - after >= cost / 2, "%s: construir+demoler pierde al menos 50%%" % t)

func test_viaje_y_reasignacion() -> void:
	var s := fresh(3)
	var node: Dictionary = {}
	for n in s.st["nodes"]:
		if n["kind"] == "carbon":
			node = n
			break
	var p := s.find_spot_near("puesto_rec", node["x"], node["y"])
	var post := place_done(s, "puesto_rec", p.x, p.y)
	post["focus"] = "carbon"
	s.st["hour"] = 9
	s.command({"c": "staff", "bid": post["id"], "o": 10})
	var c0 := s.res("carbon") + int(s.st["day_acc"]["cons"].get("carbon", 0))
	s.staff_fill()
	eq(int(post["o"]), 10, "10 obreros asignados")
	eq(s.bat_arrived(post), 0, "todavía viajando")
	s.st["res"]["carbon"] = 0
	s.production_update()
	eq(s.res("carbon"), 0, "mientras viajan no producen")
	s.st["tick"] += s.travel_hours(post)
	s.production_update()
	check(s.res("carbon") > 0, "al llegar producen")
	# Reasignar a otro lugar y volver: vuelve a viajar.
	s.command({"c": "staff", "bid": post["id"], "o": 0})
	s.staff_fill()
	s.command({"c": "staff", "bid": post["id"], "o": 10})
	s.staff_fill()
	eq(s.bat_arrived(post), 0, "reasignar obliga a viajar otra vez")

func test_pilas_finitas() -> void:
	var s := fresh(4)
	var node: Dictionary = {}
	for n in s.st["nodes"]:
		if n["kind"] == "carbon":
			node = n
			break
	var initial: int = node["amt"]
	var p := s.find_spot_near("puesto_rec", node["x"], node["y"])
	var post := place_done(s, "puesto_rec", p.x, p.y)
	post["focus"] = "carbon"
	post["o"] = 10
	post["do"] = 10
	post["bat"] = [10, 0]
	s.caps["carbon"] = 1 << 40
	s.st["res"]["carbon"] = 0
	var total := 0
	s.st["hour"] = 10
	s.st["outdoor"] = -15
	for i in 2000:
		var before := s.res("carbon")
		s.production_update()
		total += s.res("carbon") - before
	check(total <= initial, "no se puede sacar más de lo que hay en las pilas cercanas")
	var left := 0
	for nid in post["nodes"]:
		if s.st["nodes"][nid]["kind"] == "carbon":
			left += int(s.st["nodes"][nid]["amt"])
	eq(left, 0, "las pilas de carbón se agotan")

func test_sin_negativos_y_ordenes_invalidas() -> void:
	var s := fresh(8)
	var bad := [
		{"c": "build", "type": "carpa", "x": -999999999, "y": 5},
		{"c": "build", "type": "no_existe", "x": 1, "y": 1},
		{"c": "staff", "bid": 999, "o": 5},
		{"c": "gen_level", "v": 999999},
		{"c": "gen_level", "v": -3},
		{"c": "research", "id": "nada"},
		{"c": "law", "id": "nada"},
		{"c": "event", "inst": -1, "choice": 99},
		{"c": "auto_assign", "bid": 1, "v": 1 << 40},
		{"c": "", "x": "texto"},
		{},
	]
	for c in bad:
		check(s.command(c) != "", "orden inválida rechazada: " + str(c))
	# Personal con números enormes o negativos se recorta.
	var p := free_spot(s, "taller")
	s.command({"c": "build", "type": "taller", "x": p.x, "y": p.y})
	var bid: int = int(s.st["next_bid"]) - 1
	s.command({"c": "staff", "bid": bid, "o": 1 << 50, "i": 1 << 50, "n": -(1 << 50)})
	var b := s.building(bid)
	check(int(b["di"]) <= 5 and int(b["do"]) == 0 and int(b["dn"]) == 0, "personal recortado al máximo permitido")
	# Clics repetidos: construir 50 veces en el mismo lugar solo construye una vez.
	var p2 := free_spot(s, "carpa")
	var ok := 0
	for i in 50:
		if s.command({"c": "build", "type": "carpa", "x": p2.x, "y": p2.y}) == "":
			ok += 1
	eq(ok, 1, "clics rápidos no duplican edificios")
	# Vaciar recursos y comprobar que nunca son negativos tras muchas horas.
	for r in Simulation.RES:
		s.st["res"][r] = 0
	for i in 24 * 5:
		s.step()
		for r in Simulation.RES:
			check(s.res(r) >= 0, "recurso %s no negativo" % r)

func test_generador_estres_no_se_resetea() -> void:
	var s := fresh()
	s.st["res"]["carbon"] = 5000 * FX.ONE
	s.caps["carbon"] = 1 << 40
	s.command({"c": "gen_over", "v": 1})
	for i in 10:
		s.gen_update()
	var stress: int = s.st["gen"]["stress"]
	check(stress > 0, "la sobrecarga acumula estrés")
	s.command({"c": "gen_over", "v": 0})
	s.command({"c": "gen_over", "v": 1})
	check(int(s.st["gen"]["stress"]) == stress, "apagar/prender la sobrecarga no resetea el estrés")
	s.command({"c": "gen_on", "v": 0})
	s.gen_update()
	check(int(s.st["gen"]["stress"]) >= stress - int(s.B["gen"]["stress_down_m"]), "baja lento")
	s.st["gen"]["stress"] = 99 * FX.ONE
	s.command({"c": "gen_on", "v": 1})
	s.st["gen"]["warm"] = 0
	s.command({"c": "gen_over", "v": 1})
	s.step()
	s.step()
	eq(s.st["status"], "lost", "al 100% explota")
	eq(s.st["end_reason"], "explosion", "derrota por explosión")

func test_leyes_permanentes_exclusivas_y_espera() -> void:
	var s := fresh()
	eq(s.command({"c": "law", "id": "ley_cementerio"}), "", "promulga ley")
	check(s.command({"c": "law", "id": "ley_jornada"}) != "", "hay que esperar entre leyes")
	s.st["tick"] += int(s.B["laws"]["cooldown_h"])
	check(s.command({"c": "law", "id": "ley_fosa"}) != "", "leyes excluyentes")
	eq(s.command({"c": "law", "id": "fe_circulo"}), "", "elige la senda de la fe")
	s.st["tick"] += int(s.B["laws"]["cooldown_h"])
	check(s.command({"c": "law", "id": "ord_patrulla"}) != "", "no se puede cambiar de senda")
	check(s.command({"c": "law", "id": "fe_circulo"}) != "", "no se repite una ley")
	check(s.cooldown_ok_range(), "espera entre leyes entre 24 y 36 h")

func test_eventos_unicos_y_repetibles() -> void:
	var s := fresh()
	var unique_id := "ev_canciones"
	s.fire_event(unique_id)
	check(not s._event_eligible(unique_id, s.db["events"][unique_id]), "un evento único no se repite")
	var rep := "ev_accidente_rec"
	s.fire_event(rep)
	check(not s._event_eligible(rep, s.db["events"][rep]), "un repetible respeta su enfriamiento")
	s.st["tick"] += int(s.db["events"][rep]["cooldown_days"]) * 24 + 1
	s.st["day"] = 30
	check(s._event_eligible(rep, s.db["events"][rep]), "pasado el enfriamiento puede volver")

func test_exploracion_ubicaciones_finitas() -> void:
	var s := fresh()
	s.st["research"]["done"].append("exp_faro")
	var p := free_spot(s, "faro")
	place_done(s, "faro", p.x, p.y)
	s.teams_sync()
	var t: Dictionary = s.st["teams"][0]
	s.st["res"]["raciones"] = 200 * FX.ONE
	s.st["day"] = 2
	eq(s.send_expedition(t["bid"], "loc_aldea"), "", "parte la expedición")
	var guard := 0
	while t["state"] != "home" and guard < 200:
		s.st["tick"] += 1
		s.expeditions_update()
		guard += 1
	eq(t["state"], "home", "el equipo vuelve")
	check(s.send_expedition(t["bid"], "loc_aldea") != "", "una ubicación no se puede explorar dos veces")

func test_automatas_cuestan() -> void:
	var s := fresh()
	s.st["research"]["done"].append("aut_fabrica")
	var p := free_spot(s, "fabrica_aut")
	var f := place_done(s, "fabrica_aut", p.x, p.y)
	s.st["res"]["nucleos"] = 0
	s.st["res"]["metal"] = 500 * FX.ONE
	s.st["res"]["madera"] = 500 * FX.ONE
	check(s.command({"c": "auto_build", "bid": f["id"]}) != "", "sin núcleo no hay autómata")
	s.st["res"]["nucleos"] = 1 * FX.ONE
	eq(s.command({"c": "auto_build", "bid": f["id"]}), "", "con núcleo se encola")
	eq(s.res("nucleos"), 0, "consume el núcleo")
	check(s.command({"c": "auto_assign", "bid": f["id"], "v": 1}) != "", "sin autómatas libres no se asignan")

func test_clima_oleadas() -> void:
	var s := fresh(21)
	var C: Dictionary = s.db["climate"]
	var targets := [-45, -55, -65, -75, -90]
	for i in (C["waves"] as Array).size():
		var w: Dictionary = C["waves"][i]
		var lo := 999
		for d in range(int(w["start"]), int(w["start"]) + (w["profile"] as Array).size()):
			for h in 24:
				lo = mini(lo, s.temp_at(d, h))
		check(abs(lo - int(targets[i])) <= 2, "oleada %d con pico %d (objetivo %d ±2)" % [i + 1, lo, targets[i]])
		check(int(w["announce"]) >= 2 and int(w["announce"]) <= 3, "se anuncia 2-3 días antes")
	check(s.temp_at(50, 12) < s.temp_at(2, 12), "la temperatura base baja con los días")

func test_derrotas_y_victoria() -> void:
	var s := fresh()
	s.st["hope"] = 0
	s._check_end()
	eq(s.st["end_reason"], "esperanza", "esperanza 0 = derrota")
	s = fresh()
	s.st["disc"] = 100 * FX.ONE
	s._check_end()
	eq(s.st["end_reason"], "expulsion", "descontento 100 = expulsión")
	s = fresh()
	for c in Simulation.CLASSES:
		s.st["pop"][c] = {"h": 0, "sl": 0, "sg": 0}
	s._check_end()
	eq(s.st["end_reason"], "extincion", "sin población = derrota")
	s = fresh()
	s.st["day"] = int(s.B["days"]) + 1
	s._check_end()
	eq(s.st["status"], "won", "llegar al final con generador y gente = victoria")
	check(int(s.st["stars"]) >= 1 and int(s.st["stars"]) <= 5, "estrellas entre 1 y 5")
	check((s.st["epilogue"] as Array).size() > 0, "hay epílogo")

func test_enfermos_no_se_mueven() -> void:
	# No existe orden para mover enfermos; apagar/prender un edificio médico no acelera la cura.
	var base := fresh(31)
	for c in Simulation.CLASSES:
		base.st["pop"][c]["sl"] = 10
		base.st["pop"][c]["h"] -= 10
	var p := free_spot(base, "puesto_medico")
	var m := place_done(base, "puesto_medico", p.x, p.y)
	m["o"] = 4
	m["do"] = 4
	var a := base.clone()
	var b := base.clone()
	var mb := b.building(m["id"])
	for i in 48:
		a._treatment()
		if i % 2 == 0:
			mb["on"] = 0
		else:
			mb["on"] = 1
		b._treatment()
	check(b.total_sick() >= a.total_sick() - 3, "alternar el edificio médico no cura más rápido")
