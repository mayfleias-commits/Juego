extends SceneTree
## Ejecuta todos los tests headless. Sale con código 1 si alguno falla.

func _init() -> void:
	var t0 := Time.get_ticks_msec()
	var suites := [TestSim.new()]
	var failures := []
	var checks := 0
	for s in suites:
		print("== ", s.get_script().get_global_name())
		s.run_all()
		failures.append_array(s.failures)
		checks += s.checks
	print("")
	print("Comprobaciones: %d, fallas: %d, tiempo: %d ms" % [checks, failures.size(), Time.get_ticks_msec() - t0])
	for f in failures:
		print("  ✗ ", f)
	quit(1 if failures.size() > 0 else 0)
