class_name ReportPanel
extends SidePanel
## Reporte del último día, causas de esperanza/descontento y pronóstico.

var _sig := -1

func _title() -> String:
	return "Reporte"

func _build() -> void:
	_rebuild()

func refresh() -> void:
	var n: int = (sim.st["reports"] as Array).size()
	if n != _sig:
		_sig = n
		_rebuild()

func _rebuild() -> void:
	UiKit.clear(body)
	var reps: Array = sim.st["reports"]
	body.add_child(UiKit.label("Pronóstico", 18, UiKit.ACCENT))
	# La oleada se marca recién cuando la ciudad recibió el aviso (2-3 días antes).
	for f in sim.forecast(5):
		var known := Fmt.wave_announced(sim, int(f[0]))
		body.add_child(row("Día %d" % f[0], "%d / %d °C%s" % [f[1], f[2], "  OLEADA" if known else ""], UiKit.COLD if known else UiKit.TXT))
	if reps.is_empty():
		body.add_child(UiKit.label("Todavía no terminó ningún día.", 15, UiKit.TXT_DIM))
		return
	var r: Dictionary = reps[reps.size() - 1]
	body.add_child(UiKit.sep())
	body.add_child(UiKit.label("Día %d" % int(r["day"]), 18, UiKit.ACCENT))
	body.add_child(row("Mínima", "%d °C" % int(r["tmin"])))
	body.add_child(row("Población", "%d (%d enfermos)" % [int(r["pop"]), int(r["sick"])]))
	body.add_child(row("Muertes", str(int(r["deaths"])), UiKit.BAD if int(r["deaths"]) > 0 else UiKit.TXT))
	body.add_child(row("Nuevos enfermos", str(int(r["new_sick"]))))
	body.add_child(row("Llegaron", str(int(r["arrived"]))))
	body.add_child(row("Edificios terminados", str(int(r["built"]))))
	body.add_child(row("Carbón quemado por el generador", str(int(r["gen_coal"]) / 1000)))
	body.add_child(UiKit.label("Recursos (producido / consumido)", 16, UiKit.ACCENT))
	for res in Simulation.RES:
		var p: int = int(r["prod"].get(res, 0)) / 1000
		var c: int = int(r["cons"].get(res, 0)) / 1000
		if p == 0 and c == 0:
			continue
		body.add_child(row(UiKit.RES_NAMES[res], "+%d / −%d" % [p, c], UiKit.GOOD if p >= c else UiKit.BAD))
	body.add_child(UiKit.label("Esperanza %d (%s) · Descontento %d (%s)" % [int(r["hope"]) / 1000, Fmt.sgn(int(r["hope_delta"]) / 1000), int(r["disc"]) / 1000, Fmt.sgn(int(r["disc_delta"]) / 1000)], 15, UiKit.TXT, true))
	# Golpes inmediatos del día (eventos, leyes, pedidos, muertes...), además de la deriva.
	var hits: Array = []
	for k in r.get("hope_causes", {}):
		var hv: int = int(r["hope_causes"][k])
		if absi(hv) >= 100:
			hits.append(row("Esperanza · " + Hud.HIT_NAMES.get(k, Hud.CAUSE_NAMES.get(k, k)), _sgn1(hv), UiKit.GOOD if hv > 0 else UiKit.BAD))
	for k in r.get("disc_causes", {}):
		var dv: int = int(r["disc_causes"][k])
		if absi(dv) >= 100:
			hits.append(row("Descontento · " + Hud.HIT_NAMES.get(k, Hud.CAUSE_NAMES.get(k, k)), _sgn1(dv), UiKit.BAD if dv > 0 else UiKit.GOOD))
	if not hits.is_empty():
		body.add_child(UiKit.label("Golpes del día", 16, UiKit.ACCENT))
		for hrow in hits:
			body.add_child(hrow)
	var m: Dictionary = sim.st.get("mood", {})
	if not m.is_empty():
		body.add_child(UiKit.label("Qué pesa hoy en el ánimo", 16, UiKit.ACCENT))
		for k in m["hp"]:
			var v: int = int(m["hp"][k]) / 1000
			if v != 0 and k != "base":
				body.add_child(row("Esperanza · " + Hud.CAUSE_NAMES.get(k, k), Fmt.sgn(v), UiKit.GOOD if v > 0 else UiKit.BAD))
		for k in m["dp"]:
			var v2: int = int(m["dp"][k]) / 1000
			if v2 != 0 and k != "base":
				body.add_child(row("Descontento · " + Hud.CAUSE_NAMES.get(k, k), Fmt.sgn(v2), UiKit.BAD if v2 > 0 else UiKit.GOOD))
	# Pedido activo
	for a in sim.st["req"]["active"]:
		var d: Dictionary = sim.db["requests"][a["id"]]
		body.add_child(UiKit.sep())
		body.add_child(UiKit.label("Pedido del pueblo: " + d["name"], 16, UiKit.ACCENT, true))
		body.add_child(UiKit.label(d["text"], 14, UiKit.TXT_DIM, true))
		body.add_child(row("Plazo", "%d h" % maxi(0, int(a["deadline"]) - sim.tick())))

## Valor FP con signo y un decimal ("+0,3", "-6,0").
func _sgn1(v: int) -> String:
	return ("+" if v > 0 else "") + FX.fmt(v, 1)
