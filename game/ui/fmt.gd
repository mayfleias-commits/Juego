class_name Fmt
extends RefCounted
## Textos legibles para efectos, condiciones y estados.

const RES := {"carbon": "carbón", "madera": "madera", "metal": "metal", "nucleos": "núcleos", "crudo": "comida cruda", "raciones": "raciones"}
const MOD_NAMES := {
	"research_pct": "investigación", "prod_metal_pct": "producción de metal", "gen_coal_pct": "consumo del generador",
	"cure_pct": "curación", "greenhouse_pct": "invernaderos", "prod_all_pct": "toda la producción",
}

static func sgn(v: int) -> String:
	return ("+" if v > 0 else "") + str(v)

## Cantidad con singular o plural: pl(1, "muerte", "muertes") = "1 muerte".
static func pl(n: int, one: String, many: String) -> String:
	return "%d %s" % [n, one if absi(n) == 1 else many]

static func effects(list: Array) -> String:
	var parts := []
	for e in list:
		var k: String = e["k"]
		var v = e.get("v", 0)
		match k:
			"hope":
				parts.append("%s esperanza" % sgn(int(v)))
			"disc":
				parts.append("%s descontento" % sgn(int(v)))
			"res":
				parts.append("%s %s" % [sgn(int(v)), RES.get(e["r"], e["r"])])
			"refugees":
				var n: int = int(e.get("o", 0)) + int(e.get("i", 0)) + int(e.get("n", 0))
				parts.append("llega 1 persona" if n == 1 else "llegan %d personas" % n)
			"sick":
				var grave := int(e.get("grave", 0)) == 1
				if grave:
					parts.append(pl(int(v), "enfermo grave", "enfermos graves"))
				else:
					parts.append(pl(int(v), "enfermo", "enfermos"))
			"kill":
				parts.append(pl(int(v), "muerte", "muertes"))
			"leave":
				parts.append("1 persona se va" if int(v) == 1 else "%d personas se van" % int(v))
			"stress":
				parts.append("%s%% estrés del generador" % sgn(int(v)))
			"perm_mod":
				parts.append("%s%% %s (permanente)" % [sgn(int(v)), MOD_NAMES.get(e["key"], e["key"])])
			"hunt_zone":
				parts.append("más presas para cazar")
			"reveal":
				parts.append("descubre una ubicación")
			"cure":
				parts.append("1 enfermo se cura" if int(v) == 1 else "%d enfermos se curan" % int(v))
			"autos":
				parts.append("%s %s" % [sgn(int(v)), "autómata" if absi(int(v)) == 1 else "autómatas"])
			"law_cd":
				parts.append("la próxima ley espera %d h más" % int(v))
			"rand":
				var a := effects(e.get("then", []))
				var b := effects(e.get("else", []))
				parts.append("%d%%: %s / si no: %s" % [int(e.get("pct", 50)), a if a != "" else "nada", b if b != "" else "nada"])
			"mod":
				pass
	return ", ".join(parts)

static func cost(c: Dictionary) -> String:
	var parts := []
	for r in c:
		parts.append("%d %s" % [int(c[r]), RES.get(r, r)])
	return ", ".join(parts) if parts.size() > 0 else "sin costo"

static func temp(t: int) -> String:
	return "%d °C" % t

## Día y hora. Al ganar, el reloj ya pasó al día 61 a las 00:00: se muestra "Día 60 completado".
static func day_hour(sim: Simulation) -> String:
	if sim.day() > int(sim.B["days"]):
		return "Día %d completado" % int(sim.B["days"])
	return "Día %d · %02d:00" % [sim.day(), sim.hour()]

## Último día jugado (la victoria deja el contador en días + 1).
static func last_day(sim: Simulation) -> int:
	return mini(sim.day(), int(sim.B["days"]))

## true si la ciudad ya recibió el aviso de la oleada w (o ya empezó).
static func wave_known(sim: Simulation, w: Dictionary) -> bool:
	if w.is_empty():
		return false
	return int(w["start"]) - sim.day() <= int(w.get("announce", 3))

## true si el día d cae en una oleada ya anunciada (para marcar el pronóstico).
static func wave_announced(sim: Simulation, d: int) -> bool:
	return wave_known(sim, sim.wave_on(d))

## Consumo de carbón por hora (FP) de todo lo que lo quema, con el estado actual:
## generador, calefactores, estaciones de vapor, autómatas e invernaderos con gente.
static func coal_burn(sim: Simulation) -> Dictionary:
	var g: Dictionary = sim.st["gen"]
	var out := {"gen": 0, "heaters": 0, "stations": 0, "autos": 0, "greenhouses": 0}
	if int(g["on"]) == 1:
		out["gen"] = sim.gen_coal_per_hour()
	var houses := 0
	var auto_per: int = int(sim.B["auto"]["coal_m"]) * maxi(10, 100 + sim.mod("auto_coal_pct")) / 100
	for b in sim.st["buildings"]:
		if int(b["state"]) != 1:
			continue
		var d: Dictionary = sim.bdef(b["type"])
		if int(d.get("housing", 0)) > 0:
			houses += 1
		if int(b["on"]) != 1:
			continue
		var k: String = d.get("kind", "")
		if k == "station":
			out["stations"] += int(d.get("coal_m", 0))
		elif k == "greenhouse" and int(b["lvl"]) >= int(d.get("min_lvl", 0)) and int(b["o"]) + int(b["i"]) + int(b["n"]) + int(b["auto"]) > 0:
			out["greenhouses"] += int(d.get("coal_m", 0))
		if int(b["auto"]) > 0 and int(b.get("auto_stall", 0)) == 0:
			out["autos"] += auto_per * int(b["auto"])
	if int(g["heaters"]) == 1:
		out["heaters"] = houses * int(sim.B["heat"]["heater_coal_m"])
	var tot := 0
	for k2 in out:
		tot += int(out[k2])
	out["total"] = tot
	return out

## Desglose legible de coal_burn() (solo lo que consume algo).
static func coal_burn_detail(burn: Dictionary) -> String:
	var names := {"gen": "Generador", "heaters": "Calefactores", "stations": "Estaciones de vapor", "autos": "Autómatas", "greenhouses": "Invernaderos (en turno)"}
	var parts := []
	for k in names:
		if int(burn.get(k, 0)) > 0:
			parts.append("%s %s" % [names[k], FX.fmt(int(burn[k]), 1)])
	return " · ".join(parts) if parts.size() > 0 else "Nada consume carbón ahora."
