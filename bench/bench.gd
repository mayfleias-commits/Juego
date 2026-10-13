extends SceneTree
## Banco de balance headless.
## godot --headless --path . --script res://bench/bench.gd -- --bot=competente --from=0 --to=100 --out=res.jsonl

func _init() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and not ("=" in a):
			args[a.substr(2)] = "1"
		elif a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1]
	var bot_name: String = args.get("bot", "competente")
	var from := int(args.get("from", "0"))
	var to := int(args.get("to", "10"))
	var out_path: String = args.get("out", "")
	var verbose := args.has("verbose")
	var f: FileAccess = null
	if out_path != "":
		f = FileAccess.open(out_path, FileAccess.WRITE)
	for seed in range(from, to):
		var t0 := Time.get_ticks_msec()
		var r := BenchRunner.run_game(bot_name, seed, verbose)
		r["ms"] = Time.get_ticks_msec() - t0
		var line := JSON.stringify(r)
		if f:
			f.store_line(line)
			f.flush()
		else:
			print(line)
	if f:
		f.close()
	quit()
