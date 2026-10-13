class_name GeneratorPanel
extends SidePanel
## Panel del generador: encendido, potencia, sobrecarga, estrés, calefactores.

var _sig := ""

func _title() -> String:
	return "Generador"

func _build() -> void:
	_rebuild()

func refresh() -> void:
	var g: Dictionary = sim.st["gen"]
	var sig := "%d%d%d%d%d%d%d" % [g["on"], g["level"], g["over"], int(g["stress"]) / 1000, g["heaters"], sim.gen_max_level(), sim.res("carbon") / 10000]
	if sig != _sig:
		_sig = sig
		_rebuild()

func _rebuild() -> void:
	UiKit.clear(body)
	var g: Dictionary = sim.st["gen"]
	var on := int(g["on"]) == 1
	body.add_child(UiKit.label("El corazón de la ciudad. Más potencia = más calor en su radio, pero más carbón por hora.", 14, UiKit.TXT_DIM, true))
	body.add_child(row("Estado", ("Encendido" if on else "APAGADO") + (" (calentando)" if int(g["warm"]) > 0 else ""), UiKit.GOOD if on else UiKit.BAD))
	body.add_child(UiKit.button("Apagar el generador" if on else "Encender (%d de carbón)" % (int(sim.B["gen"]["ignite_coal_m"]) / 1000), "generador", func(): Session.cmd({"c": "gen_on", "v": 0 if on else 1})))
	body.add_child(UiKit.sep())
	body.add_child(UiKit.label("Potencia", 17, UiKit.ACCENT))
	var lh := UiKit.hbox(6)
	for l in range(1, 5):
		var lv := l
		var b := UiKit.button(str(l), "", func(): Session.cmd({"c": "gen_level", "v": lv}))
		b.toggle_mode = true
		b.button_pressed = int(g["level"]) == l
		b.disabled = l > sim.gen_max_level()
		b.custom_minimum_size = Vector2(UiKit.btn_h() + 16, UiKit.btn_h())
		if b.disabled:
			b.tooltip_text = "Requiere investigación (rama Calor)"
		lh.add_child(b)
	body.add_child(lh)
	body.add_child(row("Calor en el radio", "+%d °C" % sim.gen_heat()))
	body.add_child(row("Radio de calor", "%d casillas" % sim.gen_radius()))
	var per := sim.gen_coal_per_hour()
	body.add_child(row("Consumo", "%s carbón por hora" % FX.fmt(per, 1)))
	if per > 0:
		body.add_child(row("El carbón alcanza", "~%d horas" % (sim.res("carbon") / maxi(1, per)), UiKit.BAD if sim.res("carbon") < per * 12 else UiKit.TXT))
	body.add_child(UiKit.sep())
	body.add_child(UiKit.label("Sobrecarga", 17, UiKit.ACCENT))
	body.add_child(UiKit.label("+%d °C extra y 50%% más de carbón. El estrés sube rápido y baja muy lento; al 100%% el generador explota." % int(sim.B["gen"]["over_heat"]), 14, UiKit.TXT_DIM, true))
	var stress: int = int(g["stress"]) / 1000
	var sc := UiKit.GOOD if stress < 50 else (UiKit.ACCENT if stress < 80 else UiKit.BAD)
	body.add_child(row("Estrés", "%d%%" % stress, sc))
	body.add_child(UiKit.bar(stress, sc, 300, 12))
	var ob := UiKit.button("Desactivar sobrecarga" if int(g["over"]) == 1 else "Activar sobrecarga", "alerta", func(): Session.cmd({"c": "gen_over", "v": 1 - int(g["over"])}))
	ob.disabled = not on
	body.add_child(ob)
	if sim.mod("heaters") > 0:
		body.add_child(UiKit.sep())
		body.add_child(UiKit.label("Calefactores domésticos", 17, UiKit.ACCENT))
		body.add_child(UiKit.label("+%d °C en todas las viviendas a cambio de carbón." % int(sim.B["heat"]["heater_heat"]), 14, UiKit.TXT_DIM, true))
		body.add_child(UiKit.button("Apagar calefactores" if int(g["heaters"]) == 1 else "Encender calefactores", "", func(): Session.cmd({"c": "heaters", "v": 1 - int(g["heaters"])})))
