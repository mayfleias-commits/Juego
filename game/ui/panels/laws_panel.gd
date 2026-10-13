class_name LawsPanel
extends SidePanel
## Libro de leyes: adaptación y propósito (Senda del Orden o de la Fe).

const GROUPS := {"turnos": "Turnos", "ninos": "Niños", "comida": "Comida", "medicina": "Medicina", "muertos": "Muertos",
	"sociedad": "Sociedad", "orden": "Senda del Orden", "fe": "Senda de la Fe"}
var tab := "adaptacion"
var _sig := ""

func _title() -> String:
	return "Libro de leyes"

func _build() -> void:
	_rebuild()

func refresh() -> void:
	var sig := "%s|%d|%d" % [tab, (sim.st["laws"] as Array).size(), maxi(0, int(sim.st["law_ready"]) - sim.tick())]
	if sig != _sig:
		_sig = sig
		_rebuild()

func _rebuild() -> void:
	UiKit.clear(body)
	var th := UiKit.hbox(6)
	for t in [["adaptacion", "Adaptación"], ["proposito", "Propósito"]]:
		var id: String = t[0]
		var b := UiKit.button(t[1], "", func(): tab = id; _sig = ""; refresh())
		b.toggle_mode = true
		b.button_pressed = tab == id
		th.add_child(b)
	body.add_child(th)
	var wait := int(sim.st["law_ready"]) - sim.tick()
	if wait > 0:
		body.add_child(UiKit.label("El consejo podrá votar otra ley en %d horas." % wait, 15, UiKit.ACCENT, true))
	else:
		body.add_child(UiKit.label("El consejo está listo para votar una ley. Las leyes son permanentes.", 15, UiKit.GOOD, true))
	if tab == "proposito":
		var p: String = sim.st["path"]
		body.add_child(UiKit.label("Senda elegida: " + ({"orden": "del Orden", "fe": "de la Fe"}.get(p, "ninguna todavía (elegir una cierra la otra)")), 15, UiKit.TXT_DIM, true))
	var current := ""
	for id in sim.db["laws"]:
		var L: Dictionary = sim.db["laws"][id]
		if L["cat"] != tab:
			continue
		if L["group"] != current:
			current = L["group"]
			body.add_child(UiKit.label(GROUPS.get(current, current), 18, UiKit.ACCENT))
		body.add_child(_law_item(id, L))

func _law_item(id: String, L: Dictionary) -> Control:
	var p := PanelContainer.new()
	var enacted: bool = id in sim.st["laws"]
	var why := sim.law_check(id)
	var col := Color(0.12, 0.2, 0.14, 0.95) if enacted else UiKit.BG2
	p.add_theme_stylebox_override("panel", UiKit._sb(col, 6, Color(0.25, 0.3, 0.38), 1, 8))
	var v := UiKit.vbox(3)
	p.add_child(v)
	var h := UiKit.hbox(6)
	var nl := UiKit.label(L["name"] + (" ✔" if enacted else ""), 16, UiKit.GOOD if enacted else (Color(1, 0.6, 0.6) if L.get("extreme", false) else UiKit.TXT))
	nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(nl)
	if not enacted:
		var b := UiKit.button("Promulgar", "leyes", func(): _confirm(id, L))
		b.disabled = why != ""
		h.add_child(b)
	v.add_child(h)
	v.add_child(UiKit.label(L["desc"], 14, UiKit.TXT_DIM, true))
	var eff := Fmt.effects(L.get("effects", []))
	if eff != "":
		v.add_child(UiKit.label("Al promulgar: " + eff, 13, UiKit.TXT_DIM, true))
	if not enacted and why != "" and why != "el consejo aún delibera":
		v.add_child(UiKit.label("No disponible: " + why, 13, UiKit.BAD, true))
	return p

func _confirm(id: String, L: Dictionary) -> void:
	var txt: String = L["desc"] + "\n\nLas leyes no se pueden revocar."
	if L.get("path", "") != "" and sim.st["path"] == "":
		txt += "\nElegir esta senda cierra la otra para siempre."
	var ok := func():
		var r := Session.cmd({"c": "law", "id": id})
		if r != "":
			hud.toast(r, UiKit.BAD)
		_sig = ""
	hud.push_modal(ConfirmDialog.make("¿Promulgar «%s»?" % L["name"], txt, ok, "Promulgar"))
