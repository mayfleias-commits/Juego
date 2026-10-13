extends SceneTree
func _init():
	var t0 := Time.get_ticks_msec()
	var s := Simulation.new()
	s.new_game(12345)
	print("buildings ", s.st["buildings"].size(), " nodes ", s.st["nodes"].size(), " sites ", s.st["sites"].size(), " ms ", Time.get_ticks_msec() - t0)
	for d in 61:
		s.run_hours(24)
		print("day ", s.day(), " status ", s.st["status"], " pop ", s.total_pop(), " hope ", s.st["hope"], " disc ", s.st["disc"], " coal ", s.res("carbon"), " ms ", Time.get_ticks_msec() - t0)
		if s.st["status"] != "playing":
			break
	print("status ", s.st["status"], " reason ", s.st["end_reason"], " day ", s.day(), " pop ", s.total_pop(), " dead ", s.st["dead"])
	quit()
