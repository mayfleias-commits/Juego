class_name SimHeat
extends SimMap
## Clima, generador central, estaciones de vapor y temperatura de cada edificio.

func gen_climate() -> void:
	var C: Dictionary = db["climate"]
	var days: int = int(B["days"]) + 3
	var means := []
	var b0: int = C["base_start"]
	var b1: int = C["base_end"]
	var nz: int = C["noise"]
	for d in range(0, days + 1):
		var dd := clampi(d, 1, int(B["days"]))
		var base := b0 + (b1 - b0) * (dd - 1) / maxi(1, int(B["days"]) - 1)
		var noise := rnd(2 * nz + 1) - nz
		means.append(base + noise)
	for w in C["waves"]:
		var prof: Array = w["profile"]
		for i in prof.size():
			var d: int = int(w["start"]) + i
			if d < means.size():
				# Variación leve por semilla (±2 °C) sin alterar el carácter de la oleada.
				means[d] = int(prof[i]) + rnd(5) - 2
	st["climate"] = {"means": means}

func diurnal(h: int) -> int:
	return int(db["climate"]["diurnal"][h])

func temp_at(d: int, h: int) -> int:
	var means: Array = st["climate"]["means"]
	d = clampi(d, 0, means.size() - 1)
	return int(means[d]) + diurnal(h)

func outdoor() -> int:
	return st["outdoor"]

## Oleada activa en el día d (o {} si no hay).
func wave_on(d: int) -> Dictionary:
	for w in db["climate"]["waves"]:
		var s: int = w["start"]
		if d >= s and d < s + (w["profile"] as Array).size():
			return w
	return {}

func wave_next(d: int) -> Dictionary:
	for w in db["climate"]["waves"]:
		if int(w["start"]) > d:
			return w
	return {}

func in_wave() -> bool:
	return not wave_on(day()).is_empty()

## Pronóstico: [ [día, mínima, máxima, es_oleada], ...] para los próximos n días.
func forecast(n: int = 5) -> Array:
	var out := []
	for i in range(1, n + 1):
		var d := day() + i
		if d > int(B["days"]):
			break
		var lo := 999
		var hi := -999
		for h in 24:
			var t := temp_at(d, h)
			lo = mini(lo, t)
			hi = maxi(hi, t)
		out.append([d, lo, hi, 0 if wave_on(d).is_empty() else 1])
	return out

# ---------------------------------------------------------------- generador
func gen_max_level() -> int:
	return mini(4, int(B["gen"]["max_level_base"]) + mod("gen_max_level"))

func gen_radius_level() -> int:
	return mini((B["gen"]["radius"] as Array).size() - 1, mod("gen_radius_lvl"))

func gen_radius() -> int:
	return int(B["gen"]["radius"][gen_radius_level()])

## Calor que aporta el generador dentro de su zona (°C).
func gen_heat() -> int:
	var g: Dictionary = st["gen"]
	if g["on"] == 0:
		return 0
	var h: int = int(B["gen"]["heat"][g["level"]])
	if g["over"] == 1:
		h += int(B["gen"]["over_heat"])
	var wt: int = B["gen"]["warm_hours"]
	if g["warm"] > 0:
		h = h * (wt - g["warm"]) / (wt + 1)
	return h

## Consumo de carbón por hora del generador en FP.
func gen_coal_per_hour(level: int = -1, over: int = -1) -> int:
	var g: Dictionary = st["gen"]
	if level < 0:
		level = g["level"]
	if over < 0:
		over = g["over"]
	if level <= 0:
		return 0
	var c: int = int(B["gen"]["coal_m"][level])
	c = c * int(B["gen"]["radius_coal_pct"][gen_radius_level()]) / 100
	if over == 1:
		c = c * int(B["gen"]["over_coal_pct"]) / 100
	c = c * maxi(10, 100 + mod("gen_coal_pct")) / 100
	return c

func gen_update() -> void:
	var g: Dictionary = st["gen"]
	var G: Dictionary = B["gen"]
	if g["on"] == 1:
		var need := gen_coal_per_hour()
		if not take_res("carbon", need):
			take_upto("carbon", need)
			g["on"] = 0
			g["over"] = 0
			g["warm"] = 0
			note("alerta", text("gen_sin_carbon"))
		else:
			st["day_acc"]["gen_coal"] = st["day_acc"].get("gen_coal", 0) + need
			if g["warm"] > 0:
				g["warm"] -= 1
	if g["on"] == 1 and g["over"] == 1:
		g["stress"] += int(G["stress_up_m"])
	else:
		g["stress"] = maxi(0, g["stress"] - int(G["stress_down_m"]))
	if g["stress"] >= 100 * FX.ONE:
		g["stress"] = 100 * FX.ONE
		st["exploded"] = 1
	# Calefactores domésticos
	if g["heaters"] == 1:
		var houses := 0
		for b in st["buildings"]:
			if b["state"] == 1 and bdef(b["type"]).get("housing", 0) > 0:
				houses += 1
		var need_h: int = houses * int(B["heat"]["heater_coal_m"])
		if not take_res("carbon", need_h):
			g["heaters"] = 0
			note("alerta", text("calefactores_sin_carbon"))

# ---------------------------------------------------------------- temperatura de edificios
func level_of(t: int) -> int:
	var th: Array = B["heat"]["thresholds"]
	var l := 0
	for x in th:
		if t >= int(x):
			l += 1
	return l

func station_heat_at(cx2: int, cy2: int) -> int:
	var best := 0
	for s in st["stations"]:
		var dx: int = cx2 - s[0]
		var dy: int = cy2 - s[1]
		var r: int = s[2]
		if dx * dx + dy * dy <= (2 * r) * (2 * r):
			best = maxi(best, int(s[3]))
	return best

func in_gen_zone(cx2: int, cy2: int) -> bool:
	var r := gen_radius()
	var dx := cx2 - mcenter2
	var dy := cy2 - mcenter2
	return dx * dx + dy * dy <= (2 * r) * (2 * r)

## Calor de zona (generador o estación) en un punto, en °C.
func zone_heat_at(cx2: int, cy2: int) -> int:
	var z := 0
	if in_gen_zone(cx2, cy2):
		z = gen_heat()
	return maxi(z, station_heat_at(cx2, cy2))

func heat_update() -> void:
	# Estaciones de vapor activas este turno (consumen carbón).
	var stations := []
	var sheat: int = int(B["heat"]["station_heat"]) + mod("station_heat")
	for b in st["buildings"]:
		if b["state"] != 1 or b["on"] == 0:
			continue
		var d: Dictionary = bdef(b["type"])
		if d.get("kind", "") == "station":
			if take_res("carbon", int(d["coal_m"])):
				stations.append([b["cx2"], b["cy2"], int(d["radius"]), sheat])
				b["lit"] = 1
			else:
				b["lit"] = 0
	st["stations"] = stations
	var out := outdoor()
	var heaters: int = int(B["heat"]["heater_heat"]) if st["gen"]["heaters"] == 1 else 0
	var hh := mod("heat_housing")
	var hw := mod("heat_work")
	var warm_rate: int = B["heat"]["warm_rate"]
	for b in st["buildings"]:
		var d: Dictionary = bdef(b["type"])
		var target: int = out + int(d.get("insul", 0)) + zone_heat_at(b["cx2"], b["cy2"])
		if int(d.get("housing", 0)) > 0:
			target += hh + heaters
		elif not d.get("outdoor", false):
			target += hw
		if d.get("kind", "") == "greenhouse" and b["on"] == 1 and b["state"] == 1:
			target += int(d.get("self_heat", 0))
		var t: int = b["temp"]
		if target > t:
			t = mini(target, t + warm_rate)
		else:
			var cool: int = maxi(2, int(B["heat"]["cool_rate"]) - int(d.get("insul", 0)) / 10)
			t = maxi(target, t - cool)
		b["temp"] = t
		b["lvl"] = level_of(t)

## Nivel de calor de la gente sin techo.
func homeless_level() -> int:
	return level_of(outdoor() + gen_heat() / 2 + int(B["heat"]["homeless_mod"]))

## Productividad al aire libre (FP) según la temperatura exterior.
func outdoor_mult(t: int = 999) -> int:
	if t == 999:
		t = outdoor()
	return FX.piecewise(B["prod"]["outdoor_curve"], t)
