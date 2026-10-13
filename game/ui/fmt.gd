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
				parts.append("llegan %d personas" % n)
			"sick":
				parts.append("%d enferman%s" % [int(v), " grave" if int(e.get("grave", 0)) == 1 else ""])
			"kill":
				parts.append("%d muertes" % int(v))
			"leave":
				parts.append("%d se van" % int(v))
			"stress":
				parts.append("%s%% estrés del generador" % sgn(int(v)))
			"perm_mod":
				parts.append("%s%% %s (permanente)" % [sgn(int(v)), MOD_NAMES.get(e["key"], e["key"])])
			"hunt_zone":
				parts.append("más presas para cazar")
			"reveal":
				parts.append("descubre una ubicación")
			"cure":
				parts.append("%d se curan" % int(v))
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

static func day_hour(sim: Simulation) -> String:
	return "Día %d · %02d:00" % [sim.day(), sim.hour()]
