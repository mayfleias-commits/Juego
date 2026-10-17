class_name SidePanel
extends PanelContainer
## Panel lateral (PC) u hoja inferior (celular) con título y botón de cerrar.

var key := ""
var hud: Hud
var body: VBoxContainer
var title_lbl: Label
var sim: Simulation

func build() -> void:
	sim = Session.sim
	mouse_filter = Control.MOUSE_FILTER_STOP
	var v := UiKit.vbox(8)
	add_child(v)
	var head := UiKit.hbox(8)
	title_lbl = UiKit.title(_title())
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title_lbl)
	var close := UiKit.button("", "cerrar", func(): hud.close_panel())
	close.custom_minimum_size = Vector2(UiKit.btn_h(), UiKit.btn_h())
	head.add_child(close)
	v.add_child(head)
	body = UiKit.vbox(8)
	v.add_child(UiKit.scroll(body))
	_build()

func _title() -> String:
	return ""

func _build() -> void:
	pass

func refresh() -> void:
	pass

## Manda una orden y, si la simulación la rechaza, muestra el motivo.
func cmd(c: Dictionary) -> String:
	var r := Session.cmd(c)
	if r != "" and hud:
		hud.toast(r, UiKit.BAD)
	return r

## Motivo visible bajo un control deshabilitado (en táctil no hay tooltips).
func why_label(text: String) -> Label:
	return UiKit.label(text, 13, UiKit.BAD, true)

func row(label_text: String, value: String, col: Color = UiKit.TXT) -> HBoxContainer:
	var h := UiKit.hbox(8)
	# Con salto de línea: una etiqueta larga no tiene que ensanchar el panel lateral.
	var l := UiKit.label(label_text, 15, UiKit.TXT_DIM, true)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	h.add_child(UiKit.label(value, 15, col))
	return h
