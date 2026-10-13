class_name BuildPanel
extends SidePanel
## Menú de construcción por categorías.

const CATS := [
	["vivienda", "Vivienda"], ["recursos", "Recursos"], ["comida", "Comida"], ["salud", "Salud"],
	["calor", "Calor"], ["investigacion", "Ciencia"], ["almacen", "Depósitos"], ["exploracion", "Exploración"],
	["sociedad", "Sociedad"], ["orden", "Orden"], ["fe", "Fe"],
]
var cat := "vivienda"
var tabs: HFlowContainer
var list: VBoxContainer

func _title() -> String:
	return "Construir"

func _build() -> void:
	tabs = HFlowContainer.new()
	body.add_child(tabs)
	list = UiKit.vbox(6)
	body.add_child(list)
	_fill()

func _fill() -> void:
	UiKit.clear(tabs)
	for c in CATS:
		var id: String = c[0]
		var any := false
		for t in sim.db["buildings"]:
			var d: Dictionary = sim.db["buildings"][t]
			if d.get("cat", "") == id and not d.get("hidden", false):
				if (id == "orden" or id == "fe") and not sim.is_unlocked(t):
					continue
				any = true
		if not any:
			continue
		var b := UiKit.button(c[1], "", func(): cat = id; _fill())
		b.toggle_mode = true
		b.button_pressed = id == cat
		tabs.add_child(b)
	UiKit.clear(list)
	for t in sim.db["buildings"]:
		var d: Dictionary = sim.db["buildings"][t]
		if d.get("cat", "") != cat:
			continue
		list.add_child(_item(t, d))

func _item(t: String, d: Dictionary) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiKit._sb(UiKit.BG2, 6, Color(0.25, 0.3, 0.38), 1, 8))
	var v := UiKit.vbox(3)
	p.add_child(v)
	var h := UiKit.hbox(8)
	var name_l := UiKit.label(d["name"], 17, UiKit.ACCENT)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(name_l)
	var unlocked := sim.is_unlocked(t)
	var afford := sim.can_afford(d.get("cost", {}))
	var why := ""
	if not unlocked:
		if d.has("req_research"):
			why = "Requiere investigar: " + sim.db["research"][d["req_research"]]["name"]
		elif d.has("req_law"):
			why = "Requiere la ley: " + sim.db["laws"][d["req_law"]]["name"]
	elif d.has("limit") and sim.count_type(t) >= int(d["limit"]):
		why = "Límite alcanzado"
	var b := UiKit.button("Elegir", "construir", func(): hud.build_selected.emit(t), 110)
	b.disabled = why != "" or not afford
	h.add_child(b)
	v.add_child(h)
	v.add_child(UiKit.label(d.get("desc", ""), 14, UiKit.TXT_DIM, true))
	var info := "Costo: %s · %d h de obra" % [Fmt.cost(d.get("cost", {})), int(d["build_h"])]
	if d.has("staff"):
		info += " · %d puestos" % int(d["staff"]["max"])
	if int(d.get("housing", 0)) > 0:
		info += " · %d camas, aislamiento %+d °C" % [int(d["housing"]), int(d.get("insul", 0))]
	if d.has("site"):
		info += " · va sobre un yacimiento"
	v.add_child(UiKit.label(info, 14, UiKit.TXT if afford else UiKit.BAD, true))
	if why != "":
		v.add_child(UiKit.label(why, 14, UiKit.BAD, true))
	return p
