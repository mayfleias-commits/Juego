class_name BuildingPanel
extends SidePanel
## Detalle de un edificio: personal, turnos, encendido, mejora, demolición, autómatas.

var bid := 0
var _sig := ""
var _prog_bar: ProgressBar
var _prog_val: Label

func _title() -> String:
	var b := sim.building(bid)
	return sim.bdef(b["type"])["name"] if not b.is_empty() else "Edificio"

func _build() -> void:
	_rebuild()

func refresh() -> void:
	var b := sim.building(bid)
	if b.is_empty():
		hud.close_panel()
		return
	if _sig_of(b) != _sig:
		_rebuild()
	elif _prog_bar and is_instance_valid(_prog_bar):
		# El avance de la obra cambia cada hora: se actualiza en el lugar, sin reconstruir
		# el panel (una reconstrucción entre el press y el release se come el clic).
		var p := _progress(b)
		_prog_bar.value = p
		_prog_val.text = "%d%%" % int(p)

## Firma de lo que obliga a reconstruir el panel (no incluye valores que solo cambian textos).
func _sig_of(b: Dictionary) -> String:
	return "%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%s|%d|%d|%d|%d|%s|%d|%d" % [b["state"], b["on"], b["do"], b["di"], b["dn"], b["o"], b["i"], b["n"], b["shift"], b["prio"], b.get("up", ""), b["auto"], int(sim.st["autos_free"]), b["lvl"], int(b.get("queue", 0)), b.get("focus", ""), int(b.get("used", 0)), sim.shift_max_allowed()]

func _progress(b: Dictionary) -> float:
	var total: float = float(sim.bdef(b["type"])["build_h"]) * 1000.0
	return 100.0 * (1.0 - float(b["left"]) / maxf(1.0, total))

func _rebuild() -> void:
	var b := sim.building(bid)
	if b.is_empty():
		return
	_sig = ""
	UiKit.clear(body)
	var d: Dictionary = sim.bdef(b["type"])
	title_lbl.text = d["name"]
	body.add_child(UiKit.label(d.get("desc", ""), 14, UiKit.TXT_DIM, true))
	# Estado
	_prog_bar = null
	_prog_val = null
	if int(b["state"]) == 0:
		var prog := _progress(b)
		var pr_row := row("En construcción", "%d%%" % int(prog), UiKit.ACCENT)
		_prog_val = pr_row.get_child(pr_row.get_child_count() - 1) as Label
		body.add_child(pr_row)
		_prog_bar = UiKit.bar(prog, UiKit.ACCENT, 300, 10)
		body.add_child(_prog_bar)
	elif b.get("up", "") != "":
		body.add_child(row("Mejorando a", sim.bdef(b["up"])["name"], UiKit.ACCENT))
	var lvl: int = b["lvl"]
	# Al aire libre sin personal (cementerio, fosa) no hay nadie a quien abrigar.
	var outdoor: bool = d.get("outdoor", false)
	if not outdoor or sim.staff_max(d) > 0:
		body.add_child(row("Temperatura de trabajo" if outdoor else "Temperatura interior", "%d °C · %s" % [int(b["temp"]), UiKit.LEVEL_NAMES[lvl]], UiKit.LEVEL_COLORS[lvl]))
	var k: String = d.get("kind", "")
	match k:
		"housing":
			body.add_child(row("Camas", str(int(d["housing"]))))
		"medical":
			body.add_child(row("Camas (con personal completo)", str(int(d["beds"]))))
			body.add_child(row("Enfermos en la ciudad", "%d (%d graves)" % [sim.total_sick(), sim.total_grave()]))
		"extract":
			var s: Dictionary = sim.st["sites"][b["site"]]
			body.add_child(row("Queda en el yacimiento", "%d / %d" % [int(s["amt"]) / 1000, int(s["max"]) / 1000]))
			body.add_child(row("Rinde por trabajador", "%s por hora" % _rate(int(d["rate_m"]))))
		"gather":
			var left := {"carbon": 0, "madera": 0, "metal": 0}
			for nid in b["nodes"]:
				var n: Dictionary = sim.st["nodes"][nid]
				left[n["kind"]] += int(n["amt"]) / 1000
			body.add_child(row("Pilas en el radio", "carbón %d · madera %d · metal %d" % [left["carbon"], left["madera"], left["metal"]]))
			var fh := UiKit.hbox(4)
			for f in [["auto", "Auto"], ["carbon", "Carbón"], ["madera", "Madera"], ["metal", "Metal"]]:
				var fid: String = f[0]
				var fb := UiKit.button(f[1], "", func(): cmd({"c": "focus", "bid": bid, "v": fid}))
				fb.toggle_mode = true
				fb.button_pressed = b.get("focus", "auto") == fid
				fh.add_child(fb)
			body.add_child(fh)
		"research":
			var cur: String = sim.st["research"]["cur"]
			body.add_child(row("Investigando", sim.db["research"][cur]["name"] if cur != "" else "nada (abrí Investigar)"))
		"hunt":
			body.add_child(row("Última cacería", "%d de carne" % (int(b.get("last_hunt", 0)) / 1000)))
			body.add_child(row("Presas en el páramo", "%d%%" % _hunt_pct()))
		"scouts":
			var t := sim.team_of(bid)
			var st := "sin equipo (termina la obra)"
			if not t.is_empty():
				st = {"home": "en la base", "out": "de viaje", "back": "volviendo"}.get(t["state"], t["state"])
			body.add_child(row("Expedición", st))
			body.add_child(UiKit.button("Abrir el mapa", "exploracion", func(): hud.open_panel("explore")))
		"factory":
			body.add_child(row("En cola", str(int(b.get("queue", 0)))))
			var ab := UiKit.button("Fabricar autómata (%s)" % Fmt.cost(sim.B["auto"]["cost"]), "automata", func(): cmd({"c": "auto_build", "bid": bid}))
			ab.disabled = not sim.can_afford(sim.B["auto"]["cost"]) or int(b["state"]) != 1
			body.add_child(ab)
		"station":
			body.add_child(row("Calor en radio %d" % int(d["radius"]), "+%d °C, %s carbón/h" % [int(sim.B["heat"]["station_heat"]) + sim.mod("station_heat"), _rate(int(d["coal_m"]))]))
		"storage":
			body.add_child(row("Capacidad extra", Fmt.cost(d["storage"])))
		"burial":
			var used: int = int(b.get("used", 0))
			var graves: int = int(d.get("graves", 0))
			body.add_child(row("Tumbas ocupadas", "%d / %d" % [used, graves], UiKit.BAD if used >= graves else UiKit.TXT))
			if used >= graves:
				body.add_child(why_label("Está lleno: los cuerpos nuevos necesitan otro lugar."))
			body.add_child(row("Cuerpos sin enterrar en la ciudad", str(int(sim.st["bodies"]))))
		"social":
			body.add_child(row("Efecto", "esperanza %+d · descontento %+d (los siguientes del mismo tipo rinden la mitad)" % [int(d.get("hope_t_m", 0)) / 1000, int(d.get("disc_t_m", 0)) / 1000]))
	# Personal
	var mx := sim.staff_max(d)
	if mx > 0 and int(b["state"]) == 1:
		body.add_child(UiKit.sep())
		body.add_child(UiKit.label("Personal (%d/%d)" % [int(b["o"]) + int(b["i"]) + int(b["n"]), mx], 17, UiKit.ACCENT))
		var types := sim.staff_types(d)
		for cl in [["obreros", "o", "Obreros"], ["ingenieros", "i", "Ingenieros"], ["ninos", "n", "Niños"]]:
			if cl[0] == "ninos" and not sim.child_allowed(d):
				continue
			if cl[0] != "ninos" and not (cl[0] in types):
				continue
			body.add_child(_staff_row(b, cl[0], cl[1], cl[2], mx))
		var arrived := sim.bat_arrived(b)
		var tot: int = int(b["o"]) + int(b["i"]) + int(b["n"])
		if tot > arrived:
			body.add_child(UiKit.label("%d en camino (no producen mientras viajan)" % (tot - arrived), 14, UiKit.TXT_DIM))
		body.add_child(row("Personas sin trabajo", "%s · %s" % [Fmt.pl(int(sim.st["idle"].get("obreros", 0)), "obrero", "obreros"), Fmt.pl(int(sim.st["idle"].get("ingenieros", 0)), "ingeniero", "ingenieros")]))
		# Turnos
		var shifts: Array = d.get("shifts", [0])
		if shifts.size() > 1:
			var sh := UiKit.hbox(4)
			sh.add_child(UiKit.label("Turno:", 15, UiKit.TXT_DIM))
			var locked := false
			for s in [[0, "Normal"], [1, "Largo"], [2, "24 h"]]:
				if not (s[0] in shifts):
					continue
				var sv: int = s[0]
				var bt := UiKit.button(s[1], "", func(): cmd({"c": "shift", "bid": bid, "v": sv}))
				bt.toggle_mode = true
				bt.button_pressed = int(b["shift"]) == sv
				bt.disabled = sv > sim.shift_max_allowed()
				if bt.disabled:
					bt.tooltip_text = "Requiere una ley de turnos"
					locked = true
				sh.add_child(bt)
			body.add_child(sh)
			if locked:
				body.add_child(why_label("Los turnos más largos requieren una ley de turnos (Libro de leyes)."))
		var pr := UiKit.button("Prioridad alta" if int(b["prio"]) == 0 else "Quitar prioridad", "", func(): cmd({"c": "prio", "bid": bid, "v": 1 - int(b["prio"])}))
		body.add_child(pr)
	# Autómatas
	if d.get("auto_ok", false) and int(b["state"]) == 1 and int(sim.st["autos_total"]) > 0:
		var ah := UiKit.hbox(6)
		ah.add_child(UiKit.icon_rect("automata", 22))
		ah.add_child(UiKit.label("Autómata: %s" % ("trabajando" if int(b["auto"]) > 0 else "ninguno"), 15))
		var want := 0 if int(b["auto"]) > 0 else 1
		var abt := UiKit.button("Quitar" if want == 0 else "Asignar", "", func(): cmd({"c": "auto_assign", "bid": bid, "v": want}))
		abt.disabled = want == 1 and int(sim.st["autos_free"]) <= 0
		ah.add_child(abt)
		body.add_child(ah)
	# Acciones
	body.add_child(UiKit.sep())
	var acts := HFlowContainer.new()
	if int(b["state"]) == 1 and mx > 0 or k in ["station", "medical"]:
		acts.add_child(UiKit.button("Apagar" if int(b["on"]) == 1 else "Encender", "", func(): cmd({"c": "toggle", "bid": bid, "on": 1 - int(b["on"])})))
	var up: String = d.get("upgrade_to", "")
	var up_why := ""
	if up != "" and int(b["state"]) == 1 and b.get("up", "") == "":
		var cost := sim.upgrade_cost(b)
		var ub := UiKit.button("Mejorar a %s (%s)" % [sim.bdef(up)["name"], Fmt.cost(cost)], "mejorar", func(): cmd({"c": "upgrade", "bid": bid}))
		ub.disabled = not sim.is_unlocked(up) or not sim.can_afford(cost)
		if not sim.is_unlocked(up):
			ub.tooltip_text = "Requiere investigación"
		acts.add_child(ub)
		var udef: Dictionary = sim.bdef(up)
		if not sim.is_unlocked(up):
			var rn := ""
			if udef.has("req_research"):
				rn = ": " + str(sim.db["research"][udef["req_research"]]["name"])
			up_why = "Mejorar requiere investigar%s." % rn
		elif not sim.can_afford(cost):
			up_why = "No alcanzan los materiales para mejorar."
	var refund := {}
	for r in d.get("cost", {}):
		if r != "nucleos":
			refund[r] = int(d["cost"][r]) * int(sim.B["build"]["refund_pct"]) / 100
	acts.add_child(UiKit.button("Demoler (devuelve %s)" % Fmt.cost(refund), "demoler", func(): _confirm_demolish()))
	body.add_child(acts)
	if up_why != "":
		body.add_child(why_label(up_why))
	_sig = _sig_of(sim.building(bid))

func _rate(m: int) -> String:
	return FX.fmt(m, 1)

func _hunt_pct() -> int:
	var s := 0
	var m := 0
	for z in sim.st["hunt"]:
		s += int(z["stock"])
		m += int(z["max"])
	return s * 100 / maxi(1, m)

func _staff_row(b: Dictionary, cls: String, key: String, name: String, mx: int) -> HBoxContainer:
	var h := UiKit.hbox(6)
	var l := UiKit.label("%s: %d (pedidos %d)" % [name, int(b[key]), int(b["d" + key])], 15)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	for delta in [-5, -1, 1, 5]:
		var dd: int = delta
		var bt := UiKit.button(("%+d" % dd), "", func(): _set_staff(key, dd))
		bt.custom_minimum_size = Vector2(UiKit.btn_h() + 6, UiKit.btn_h())
		h.add_child(bt)
	var full := UiKit.button("Máx", "", func(): _set_staff(key, mx))
	h.add_child(full)
	return h

func _set_staff(key: String, delta: int) -> void:
	var b := sim.building(bid)
	var c := {"o": int(b["do"]), "i": int(b["di"]), "n": int(b["dn"])}
	c[key] = maxi(0, c[key] + delta)
	cmd({"c": "staff", "bid": bid, "o": c["o"], "i": c["i"], "n": c["n"]})
	_sig = ""

func _confirm_demolish() -> void:
	var dlg := ConfirmDialog.make("¿Demoler este edificio?", "Se recupera como máximo la mitad de los materiales. Los núcleos de vapor se pierden.", func():
		cmd({"c": "demolish", "bid": bid})
		hud.close_panel())
	hud.push_modal(dlg)
