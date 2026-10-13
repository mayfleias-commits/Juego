class_name SimPeople
extends SimHeat
## Población por grupos: asignación de puestos (con viaje), vivienda, exposición
## al frío, enfermedades, tratamiento, muertes, comida, cuerpos y llegadas.

# ---------------------------------------------------------------- turnos
func shift_active(b: Dictionary, h: int) -> bool:
	match int(b["shift"]):
		0:
			return h >= 8 and h < 18
		1:
			return h >= 8 and h < 22
		_:
			return true

func shift_max_allowed() -> int:
	return mini(2, mod("shift_max"))

# ---------------------------------------------------------------- lotes de llegada
func bat_arrived(b: Dictionary) -> int:
	var bat: Array = b["bat"]
	var t: int = st["tick"]
	var n := 0
	var i := 0
	while i < bat.size():
		if int(bat[i + 1]) <= t:
			n += int(bat[i])
		i += 2
	return n

func _bat_remove(b: Dictionary, n: int) -> void:
	var bat: Array = b["bat"]
	while n > 0 and bat.size() > 0:
		var last := bat.size() - 2
		var k: int = bat[last]
		if k <= n:
			n -= k
			bat.remove_at(last + 1)
			bat.remove_at(last)
		else:
			bat[last] = k - n
			n = 0

## Compacta los lotes ya llegados en uno solo.
func _bat_compact(b: Dictionary) -> void:
	var bat: Array = b["bat"]
	if bat.size() <= 2:
		return
	var t: int = st["tick"]
	var arrived := 0
	var rest := []
	var i := 0
	while i < bat.size():
		if int(bat[i + 1]) <= t:
			arrived += int(bat[i])
		else:
			rest.append(bat[i])
			rest.append(bat[i + 1])
		i += 2
	var nb := []
	if arrived > 0:
		nb.append(arrived)
		nb.append(0)
	nb.append_array(rest)
	b["bat"] = nb

func travel_hours(b: Dictionary) -> int:
	var t: int = B["staff"]["travel_base"]
	if dist_tiles(b["x"], b["y"], b["w"], b["h"]) > int(B["staff"]["travel_far_tiles"]):
		t += 1
	return t

# ---------------------------------------------------------------- asignación
func staff_types(d: Dictionary) -> Array:
	return d.get("staff", {}).get("types", [])

func child_allowed(d: Dictionary) -> bool:
	var s: Dictionary = d.get("staff", {})
	if s.is_empty():
		return false
	if mod("child_labor") > 0:
		if d.get("child_ok", false):
			return true
		if mod("child_all") > 0 and d.get("kind", "") != "medical":
			return true
	if mod("child_apprentice") > 0 and d.get("apprentice", false):
		return true
	return false

func child_eff() -> int:
	return clampi(int(B["staff"]["child_eff_m"]) + mod("child_eff_m"), 0, FX.ONE)

func staff_max(d: Dictionary) -> int:
	return int(d.get("staff", {}).get("max", 0))

func building_works(b: Dictionary) -> bool:
	return b["state"] == 1 and b["on"] == 1

## Llena los puestos según lo deseado por el jugador y la gente sana disponible.
func staff_fill() -> void:
	var avail := {}
	for c in CLASSES:
		avail[c] = maxi(0, healthy(c))
	var arr: Array = st["buildings"]
	for pass_i in 2:
		for b in arr:
			if int(b["prio"]) != (1 - pass_i):
				continue
			var ok := building_works(b)
			for c in CLASSES:
				var key: String = c.substr(0, 1) # o, i, n
				var want: int = b["d" + key] if ok else 0
				var take: int = mini(want, avail[c])
				var have: int = b[key]
				if take < have:
					_bat_remove(b, have - take)
				elif take > have:
					var bat: Array = b["bat"]
					bat.append(take - have)
					bat.append(st["tick"] + travel_hours(b))
				b[key] = take
				avail[c] -= take
			_bat_compact(b)
	st["idle"] = avail

func assigned_total(c: String) -> int:
	var key := c.substr(0, 1)
	var n := 0
	for b in st["buildings"]:
		n += int(b[key])
	return n

func desired_total(c: String) -> int:
	var key := "d" + c.substr(0, 1)
	var n := 0
	for b in st["buildings"]:
		n += int(b[key])
	return n

## Equivalentes-trabajador efectivos (FP) del personal humano presente.
func staff_eq(b: Dictionary) -> int:
	var tot: int = b["o"] + b["i"] + b["n"]
	if tot == 0:
		return 0
	var arrived := bat_arrived(b)
	var raw: int = (b["o"] + b["i"]) * FX.ONE + b["n"] * child_eff()
	return raw * arrived / tot

func auto_eq() -> int:
	return int(B["auto"]["eq_m"]) * maxi(0, 100 + mod("auto_eq_pct")) / 100

# ---------------------------------------------------------------- vivienda
## Devuelve [capacidad por nivel (0..4), total]
func housing_by_level() -> Array:
	var cap_l := [0, 0, 0, 0, 0]
	var total := 0
	for b in st["buildings"]:
		if b["state"] != 1:
			continue
		var hcap: int = int(bdef(b["type"]).get("housing", 0))
		if hcap > 0:
			cap_l[b["lvl"]] += hcap
			total += hcap
	return [cap_l, total]

## Distribución FP (suma 1000) de la gente en casa por nivel: índices 0..4 y 5 = sin techo.
func home_distribution(need: int) -> Array:
	var hb := housing_by_level()
	var cap_l: Array = hb[0]
	var dist := [0, 0, 0, 0, 0, 0]
	if need <= 0:
		dist[4] = FX.ONE
		return dist
	var left := need
	var hl := homeless_level()
	for l in range(4, -1, -1):
		var put: int = mini(left, cap_l[l])
		dist[l] += put * FX.ONE / need
		left -= put
	if left > 0:
		dist[5] = left * FX.ONE / need
	st["homeless"] = left
	return dist

# ---------------------------------------------------------------- salud
func beds_by_tier() -> Dictionary:
	var beds := {"basic": 0, "adv": 0, "care": 0}
	var pct := 100 + mod("beds_pct")
	for b in st["buildings"]:
		if not building_works(b):
			continue
		var d: Dictionary = bdef(b["type"])
		if d.get("kind", "") != "medical":
			continue
		var mx := staff_max(d)
		var staff: int = b["o"] + b["i"] + b["n"]
		var eff: int = (staff * FX.ONE) / maxi(1, mx) if mx > 0 else FX.ONE
		var nb: int = int(d["beds"]) * pct / 100 * eff / FX.ONE
		beds[d["tier"]] += nb
	return beds

func health_update(exposure: Dictionary) -> void:
	var H: Dictionary = B["health"]
	var rates: Array = H["sick_pcm"]
	var grave_pct: Array = H["grave_frac_pct"]
	var sick_mult := maxi(0, 100 + mod("sick_pct") + int(st.get("sick_bonus_pct", 0)))
	var new_sick_total := 0
	for c in CLASSES:
		var ex: Array = exposure[c]
		var p: Dictionary = st["pop"][c]
		var exp_fp := 0
		var exp_grave_fp := 0
		for l in LEVELS:
			var n: int = ex[l] # personas FP (x1000) expuestas a nivel l
			var e: int = n * int(rates[l]) / 100000 * sick_mult / 100
			exp_fp += e
			exp_grave_fp += e * int(grave_pct[l]) / 100
		var ns := mini(stoch(exp_fp), p["h"])
		if ns > 0:
			var ng := mini(ns, stoch(exp_grave_fp))
			p["h"] -= ns
			p["sg"] += ng
			p["sl"] += ns - ng
			new_sick_total += ns
	if new_sick_total > 0:
		st["day_acc"]["new_sick"] = st["day_acc"].get("new_sick", 0) + new_sick_total
	_treatment()

func _treatment() -> void:
	var H: Dictionary = B["health"]
	var beds := beds_by_tier()
	var SG := total_grave()
	var SL := total_sick() - SG
	st["treated"] = 0
	if SG + SL == 0:
		return
	# Graves: avanzada -> básica -> cuidados. Leves: avanzada sobrante -> básica sobrante.
	var gA: int = mini(SG, beds["adv"])
	var gB: int = mini(SG - gA, beds["basic"])
	var gC: int = mini(SG - gA - gB, beds["care"])
	var lA: int = mini(SL, beds["adv"] - gA)
	var lB: int = mini(SL - lA, beds["basic"] - gB)
	st["treated"] = gA + gB + gC + lA + lB
	var cure_m := maxi(0, 100 + mod("cure_pct"))
	var death_m := maxi(0, 100 + mod("death_pct"))
	# Tasas medias ponderadas (pcm) para graves y leves.
	var g_heal := 0
	var g_death := 0
	var l_heal := 0
	var l_worse := 0
	if SG > 0:
		g_heal = (gA * int(H["adv_grave_heal"]) + gB * int(H["basic_grave_heal"]) + gC * int(H["care_grave_heal"])) / SG
		var untreated_g := SG - gA - gB - gC
		g_death = (gA * int(H["adv_grave_death"]) + gB * int(H["basic_grave_death"]) + gC * int(H["care_grave_death"]) + untreated_g * int(H["untreated_grave_death"])) / SG
	if SL > 0:
		var untreated_l := SL - lA - lB
		l_heal = (lA * int(H["adv_light_heal"]) + lB * int(H["basic_light_heal"]) + untreated_l * (int(H["untreated_light_heal"]) + mod("home_heal_pcm"))) / SL
		l_worse = untreated_l * int(H["untreated_light_worsen"]) / SL
	g_heal = g_heal * cure_m / 100
	l_heal = l_heal * cure_m / 100
	g_death = g_death * death_m / 100
	var deaths := 0
	for c in CLASSES:
		var p: Dictionary = st["pop"][c]
		var sg: int = p["sg"]
		var sl: int = p["sl"]
		if sg > 0:
			var d := mini(sg, stoch(sg * g_death / 100))
			var hh := mini(sg - d, stoch(sg * g_heal / 100))
			p["sg"] -= d + hh
			p["h"] += hh
			deaths += d
			if d > 0:
				_register_deaths(c, d, "enfermedad")
		if sl > 0:
			var w := mini(sl, stoch(sl * l_worse / 100))
			var hh2 := mini(sl - w, stoch(sl * l_heal / 100))
			p["sl"] -= w + hh2
			p["sg"] += w
			p["h"] += hh2

func _register_deaths(c: String, n: int, cause: String) -> void:
	if n <= 0:
		return
	st["dead"] += n
	var dc: Dictionary = st["dead_by"]
	dc[cause] = dc.get(cause, 0) + n
	st["bodies"] += n
	st["day_acc"]["deaths"] = st["day_acc"].get("deaths", 0) + n
	var per: int = int(B["society"]["death_hope_m"]) * maxi(0, 100 + mod("death_hope_pct")) / 100
	add_hope(-per * n, "muertes")
	add_disc(int(B["society"]["death_disc_m"]) * n, "muertes")
	var key := "muertes_" + cause
	if not db["texts"].has(key):
		key = "muertes_otro"
	note("muerte", text(key) % n, {"n": n, "cause": cause})

## Mata n personas sanas de la clase c (accidentes, fatiga, eventos).
func kill_healthy(c: String, n: int, cause: String) -> int:
	var p: Dictionary = st["pop"][c]
	n = mini(n, p["h"])
	if n <= 0:
		return 0
	p["h"] -= n
	_register_deaths(c, n, cause)
	return n

## Enferma n personas sanas de la clase c (eventos).
func make_sick(c: String, n: int, grave: bool = false) -> int:
	var p: Dictionary = st["pop"][c]
	n = mini(n, p["h"])
	if n <= 0:
		return 0
	p["h"] -= n
	if grave:
		p["sg"] += n
	else:
		p["sl"] += n
	return n

# ---------------------------------------------------------------- exposición
## Calcula cuántas personas sanas (FP) de cada clase están expuestas a cada nivel.
func compute_exposure() -> Dictionary:
	var h := hour()
	var ex := {}
	var at_work := {}
	for c in CLASSES:
		ex[c] = [0, 0, 0, 0, 0]
		at_work[c] = 0
	var out_l := level_of(outdoor())
	for b in st["buildings"]:
		var tot: int = b["o"] + b["i"] + b["n"]
		if tot == 0:
			continue
		var d: Dictionary = bdef(b["type"])
		var always: bool = d.get("kind", "") == "medical" or d.get("kind", "") == "social"
		if not always and not shift_active(b, h):
			continue
		if d.get("kind", "") == "hunt":
			continue # los cazadores se cuentan en su salida
		var arrived := bat_arrived(b)
		var lvl: int = b["lvl"]
		for c in CLASSES:
			var k: int = b[c.substr(0, 1)]
			if k == 0:
				continue
			var arr_k := k * arrived / tot
			ex[c][lvl] += arr_k * FX.ONE
			ex[c][out_l] += (k - arr_k) * FX.ONE
			at_work[c] += k
	# Cazadores fuera
	for hb in st["buildings"]:
		if bdef(hb["type"]).get("kind", "") == "hunt" and int(hb.get("trip", 0)) > 0:
			ex["obreros"][out_l] += int(hb["trip"]) * FX.ONE
			at_work["obreros"] += int(hb["trip"])
	# Niños en refugios
	var shelter_cap := 0
	var shelter_lvl := 4
	for b in st["buildings"]:
		if building_works(b) and bdef(b["type"]).get("kind", "") == "shelter":
			shelter_cap += int(bdef(b["type"])["children"])
			shelter_lvl = mini(shelter_lvl, int(b["lvl"]))
	# En casa
	var need := 0
	var home := {}
	for c in CLASSES:
		var p: Dictionary = st["pop"][c]
		var at_home := maxi(0, p["h"] - at_work[c])
		if c == "ninos" and shelter_cap > 0:
			var inside := mini(at_home, shelter_cap)
			# En refugio: mitad de exposición (cuidados) al nivel del refugio.
			ex[c][shelter_lvl] += inside * FX.ONE * int(B["health"]["shelter_sick_pct"]) / 100
			at_home -= inside
		home[c] = at_home
		need += p["h"] + p["sl"] + p["sg"]
	need -= mini(need, int(st.get("treated", 0)))
	var dist := home_distribution(need)
	var hl := homeless_level()
	for c in CLASSES:
		var n: int = home[c]
		for l in LEVELS:
			ex[c][l] += n * int(dist[l])
		ex[c][hl] += n * int(dist[5])
	st["home_dist"] = dist
	return ex

# ---------------------------------------------------------------- comida
func meal() -> void:
	var F: Dictionary = B["food"]
	var eaters := present_pop()
	if eaters <= 0:
		return
	var portion: int = maxi(100, int(F["portion_m"]) + mod("portion_m"))
	var need := eaters * portion
	var got := take_upto("raciones", need)
	var short := need - got
	if short > 0:
		# Comer crudo: alimenta igual pero enferma.
		var raw := take_upto("crudo", short)
		if raw > 0:
			short -= raw
			var poisoned := stoch(raw / portion * int(F["raw_sick_pcm"]) * FX.ONE / 100000)
			var c := "obreros"
			make_sick(c, poisoned)
			note("alerta", text("comen_crudo"))
	var hungry := short / portion
	st["hungry"] = hungry
	if hungry > 0:
		st["hunger_streak"] += 1
		var frac := hungry * FX.ONE / eaters
		add_hope(-int(F["hunger_hope_m"]) * frac / FX.ONE, "hambre")
		add_disc(int(F["hunger_disc_m"]) * frac / FX.ONE, "hambre")
		note("alerta", text("hambre") % hungry)
		if st["hunger_streak"] >= int(F["starve_after"]):
			var die := stoch(hungry * int(F["starve_pcm"]) * FX.ONE / 100000)
			var left := die
			for c in CLASSES:
				if left <= 0:
					break
				left -= kill_healthy(c, left, "hambre")
	else:
		st["hunger_streak"] = 0

# ---------------------------------------------------------------- cuerpos
func bodies_update() -> void:
	var capacity := 0
	for b in st["buildings"]:
		if b["state"] == 1 and bdef(b["type"]).get("kind", "") == "burial":
			capacity += int(bdef(b["type"])["graves"])
	var room := maxi(0, capacity - int(st["buried"]))
	var mv := mini(room, int(st["bodies"]))
	if mv > 0:
		st["bodies"] -= mv
		st["buried"] += mv
	var bodies: int = st["bodies"]
	if bodies > 0:
		add_hope(-int(B["society"]["body_hope_day_m"]) * bodies / 24, "cuerpos")
		add_disc(int(B["society"]["body_disc_day_m"]) * bodies / 24, "cuerpos")

# ---------------------------------------------------------------- llegadas
func arrivals_update() -> void:
	var arr: Array = st["arrivals"]
	var i := 0
	while i < arr.size():
		var a: Dictionary = arr[i]
		if int(a["tick"]) <= st["tick"]:
			var total := 0
			for c in CLASSES:
				var n: int = a.get(c, 0)
				st["pop"][c]["h"] += n
				total += n
			var sick: int = a.get("sick", 0)
			sick = make_sick("obreros", mini(sick, st["pop"]["obreros"]["h"]))
			st["day_acc"]["arrived"] = st["day_acc"].get("arrived", 0) + total
			st["arrived_total"] += total
			if total > 0:
				add_hope(int(B["society"]["arrival_hope_m"]) * mini(total, 20) / 10, "llegadas")
				note("llegada", text("llegan_refugiados") % total, {"n": total})
			arr.remove_at(i)
		else:
			i += 1

func add_arrival(hours: int, o: int, i: int, n: int, sick: int = 0) -> void:
	st["arrivals"].append({"tick": st["tick"] + hours, "obreros": o, "ingenieros": i, "ninos": n, "sick": sick})
