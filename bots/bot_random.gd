class_name BotRandom
extends BotBase
## Bot aleatorio: cada hora, con cierta probabilidad, hace una acción válida al azar.

func _init() -> void:
	name = "aleatorio"

func act() -> void:
	if brnd(100) >= 35:
		return
	match brnd(11):
		0, 1, 2:
			var types: Array = sim.db["buildings"].keys()
			var t: String = types[brnd(types.size())]
			if sim.bdef(t).has("site"):
				try_build_site(t)
			else:
				try_build_near(t, brnd(sim.msize), brnd(sim.msize))
		3, 4:
			var arr: Array = sim.st["buildings"]
			if arr.size() > 0:
				var b: Dictionary = arr[brnd(arr.size())]
				var mx := sim.staff_max(sim.bdef(b["type"]))
				cmd({"c": "staff", "bid": b["id"], "o": brnd(mx + 1), "i": brnd(mx + 1), "n": brnd(mx + 1)})
		5:
			cmd({"c": "gen_level", "v": 1 + brnd(4)})
			if brnd(10) == 0:
				cmd({"c": "gen_over", "v": brnd(2)})
			if brnd(20) == 0:
				cmd({"c": "gen_on", "v": brnd(2)})
		6:
			var ids: Array = sim.db["research"].keys()
			cmd({"c": "research", "id": ids[brnd(ids.size())]})
		7:
			var lids: Array = sim.db["laws"].keys()
			cmd({"c": "law", "id": lids[brnd(lids.size())]})
		8:
			for p in sim.st["ev_pending"].duplicate():
				cmd({"c": "event", "inst": p["inst"], "choice": brnd(3)})
			cmd({"c": "request", "accept": brnd(2)})
		9:
			var locs: Array = sim.st["locs"].keys()
			for t in sim.st["teams"]:
				cmd({"c": "expedition", "bid": t["bid"], "loc": locs[brnd(locs.size())]})
		10:
			var arr2: Array = sim.st["buildings"]
			if arr2.size() > 0 and brnd(4) == 0:
				cmd({"c": "demolish", "bid": arr2[brnd(arr2.size())]["id"]})
