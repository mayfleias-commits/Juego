class_name EventDialogs
extends RefCounted
## Diálogos de eventos, pedidos del pueblo y fin de partida.

static func event(hud: Hud, inst: int) -> PanelContainer:
	var sim := Session.sim
	var p: Dictionary = {}
	for e in sim.st["ev_pending"]:
		if int(e["inst"]) == inst:
			p = e
	if p.is_empty():
		return null
	var ev: Dictionary = sim.db["events"][p["id"]]
	var d := PanelContainer.new()
	d.custom_minimum_size = Vector2(560 if not UiKit.mobile else 860, 0)
	var v := UiKit.vbox(10)
	d.add_child(v)
	var h := UiKit.hbox(8)
	h.add_child(UiKit.icon_rect("pedido", 30))
	h.add_child(UiKit.title(ev["title"]))
	v.add_child(h)
	v.add_child(UiKit.label(ev["text"], 17, UiKit.TXT, true))
	v.add_child(UiKit.label("Si no decidís en %d horas se elegirá una opción por defecto." % maxi(0, int(p["deadline"]) - sim.tick()), 13, UiKit.TXT_DIM, true))
	var choices: Array = ev["choices"]
	for i in choices.size():
		var c: Dictionary = choices[i]
		var idx := i
		var txt: String = c["text"]
		var eff := Fmt.effects(c.get("effects", []))
		var b := UiKit.button(txt, "", func():
			Session.cmd({"c": "event", "inst": inst, "choice": idx})
			hud.close_modal())
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.disabled = not sim.choice_ok(p["id"], i)
		v.add_child(b)
		if eff != "":
			v.add_child(UiKit.label("   → " + eff + ("" if not b.disabled else "  (no alcanza)"), 13, UiKit.TXT_DIM if not b.disabled else UiKit.BAD, true))
	return d

static func request(hud: Hud) -> PanelContainer:
	var sim := Session.sim
	var off: Dictionary = sim.st["req"]["offer"]
	if off.is_empty():
		return null
	var r: Dictionary = sim.db["requests"][off["id"]]
	var d := PanelContainer.new()
	d.custom_minimum_size = Vector2(520 if not UiKit.mobile else 820, 0)
	var v := UiKit.vbox(10)
	d.add_child(v)
	v.add_child(UiKit.title("El pueblo pide: " + r["name"]))
	v.add_child(UiKit.label(r["text"], 17, UiKit.TXT, true))
	v.add_child(UiKit.label("Plazo si aceptás: %d horas." % int(r["hours"]), 15, UiKit.ACCENT))
	v.add_child(UiKit.label("Si se cumple: " + Fmt.effects(r.get("reward", [])), 14, UiKit.GOOD, true))
	v.add_child(UiKit.label("Si se incumple: " + Fmt.effects(r.get("penalty", [])), 14, UiKit.BAD, true))
	v.add_child(UiKit.label("Rechazarlo ahora sube un poco el descontento.", 13, UiKit.TXT_DIM, true))
	var h := UiKit.hbox(10)
	h.alignment = BoxContainer.ALIGNMENT_END
	h.add_child(UiKit.button("Rechazar", "cerrar", func():
		Session.cmd({"c": "request", "accept": 0})
		hud.close_modal()))
	h.add_child(UiKit.button("Prometerlo", "ok", func():
		Session.cmd({"c": "request", "accept": 1})
		hud.close_modal()))
	v.add_child(h)
	return d

static func game_over(screen) -> PanelContainer:
	var sim := Session.sim
	var won: bool = sim.st["status"] == "won"
	var d := PanelContainer.new()
	d.custom_minimum_size = Vector2(620 if not UiKit.mobile else 880, 0)
	var v := UiKit.vbox(10)
	d.add_child(v)
	v.add_child(UiKit.title("¡Sobrevivieron!" if won else "La ciudad cayó"))
	if won:
		var sh := UiKit.hbox(4)
		for i in 5:
			sh.add_child(UiKit.icon_rect("estrella" if i < int(sim.st["stars"]) else "estrella_vacia", 40))
		v.add_child(sh)
	var t: String = sim.text("fin_" + sim.st["end_reason"])
	v.add_child(UiKit.label(t, 17, UiKit.TXT, true))
	var epi := ""
	for line in sim.st["epilogue"]:
		if str(line) != "":
			epi += "• " + str(line) + "\n"
	if epi != "":
		var sc := UiKit.scroll(UiKit.label(epi, 15, UiKit.TXT_DIM, true))
		sc.custom_minimum_size = Vector2(0, 200)
		v.add_child(sc)
	v.add_child(UiKit.label("Día %d · Población %d · Muertes %d · Llegaron %d · Ubicaciones exploradas %d" % [sim.day(), sim.total_pop(), int(sim.st["dead"]), int(sim.st["arrived_total"]), int(sim.st["explored"])], 14, UiKit.TXT_DIM, true))
	var h := UiKit.hbox(10)
	h.alignment = BoxContainer.ALIGNMENT_END
	h.add_child(UiKit.button("Menú principal", "menu", func(): screen.exit_to_menu()))
	h.add_child(UiKit.button("Nueva partida", "ok", func(): screen.new_game()))
	v.add_child(h)
	return d
