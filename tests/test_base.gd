class_name TestBase
extends RefCounted
## Mini framework de tests headless.

var failures: Array = []
var checks := 0
var current := ""

func check(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		failures.append("%s: %s" % [current, msg])

func eq(a, b, msg: String) -> void:
	check(a == b, "%s (esperado %s, obtenido %s)" % [msg, str(b), str(a)])

func run_all() -> void:
	for m in get_method_list():
		var n: String = m["name"]
		if n.begins_with("test_"):
			current = n
			var before := failures.size()
			call(n)
			print(("  OK   " if failures.size() == before else "  FALLA ") + n)

## Simulación nueva con el mapa limpio para pruebas controladas.
func fresh(seed: int = 7) -> Simulation:
	var s := Simulation.new()
	s.new_game(seed)
	return s

## Coloca un edificio ya terminado sin cobrar (solo para pruebas).
func place_done(s: Simulation, type: String, x: int, y: int) -> Dictionary:
	var b: Dictionary = s._create_building(type, x, y)
	b["state"] = 1
	b["left"] = 0
	s.recompute_caps()
	return b

func free_spot(s: Simulation, type: String) -> Vector2i:
	var c := s.msize / 2
	return s.find_spot_near(type, c, c)
