class_name Tutorial
extends Control
## Tutorial de los primeros días: pasos guiados que se completan solos al hacerlos.

var screen
var step := 0
var box: PanelContainer
var lbl: Label
var btn_next: Button
var active := false

const STEPS := [
	{"t": "Bienvenida a Última Brasa. El invierno no termina y el generador del centro es lo único que nos mantiene vivos. Tenés 60 días por delante. Pausá cuando quieras pensar (botón de pausa, arriba a la derecha).", "pc": "Bienvenida a Última Brasa. El invierno no termina y el generador del centro es lo único que nos mantiene vivos. Tenés 60 días por delante. Pausá cuando quieras pensar (Espacio o el botón de pausa).", "next": true},
	{"t": "Primero, techo: abrí Construir → Vivienda y poné dos Carpas de lona cerca del generador, dentro de su calor.", "cond": "carpas"},
	{"t": "El generador come carbón. Construí una Cuadrilla de acopio junto a una pila de carbón (las manchas negras).", "cond": "puesto"},
	{"t": "Los edificios necesitan gente. Tocá la cuadrilla y sumá obreros con +5. Los trabajadores tardan un rato en llegar.", "pc": "Los edificios necesitan gente. Hacé clic en la cuadrilla y sumá obreros con +5. Los trabajadores tardan un rato en llegar.", "cond": "staff"},
	{"t": "Hay que comer: construí una Cabaña de cazadores y una Cocina comunal (convierte carne cruda en raciones).", "cond": "comida"},
	{"t": "Con un Taller de ingenios los ingenieros investigan. Construilo y elegí una investigación en Investigar (el Martinete de vapor es buena idea).", "cond": "investigar"},
	{"t": "El frío enferma. Un Puesto médico atiende a los enfermos antes de que empeoren.", "cond": "medico"},
	{"t": "El consejo puede votar una ley por día y medio. Abrí Leyes y promulgá una (por ejemplo, qué hacer con los muertos).", "cond": "ley"},
	{"t": "Tocá la temperatura para ver el pronóstico; cada oleada se anuncia unos días antes. Entonces juntá carbón y comida, y subí la potencia del generador. ¡Suerte!", "pc": "Pasá el mouse sobre la temperatura para ver el pronóstico; cada oleada se anuncia unos días antes. Entonces juntá carbón y comida, y subí la potencia del generador. ¡Suerte!", "next": true},
]

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Es hermano del Hud en la capa de interfaz: no hereda su tema, hay que dárselo.
	theme = UiKit.theme
	box = PanelContainer.new()
	box.add_theme_stylebox_override("panel", UiKit._sb(Color(0.1, 0.08, 0.05, 0.94), 8, UiKit.ACCENT, 2, 12))
	box.custom_minimum_size = Vector2(420 if not UiKit.mobile else 500, 0)
	var v := UiKit.vbox(8)
	box.add_child(v)
	# Encabezado con los botones a la derecha: el cuadro queda más bajo y tapa menos.
	var h := UiKit.hbox(6)
	h.add_child(UiKit.icon_rect("pedido", 24))
	var tl := UiKit.label("Consejo del ingeniero" if not UiKit.mobile else "Consejo", 17, UiKit.ACCENT)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(tl)
	h.add_child(UiKit.button("Omitir", "cerrar", func(): _finish(true)))
	btn_next = UiKit.button("Siguiente", "ok", func(): _advance())
	h.add_child(btn_next)
	v.add_child(h)
	lbl = UiKit.label("", 16, UiKit.TXT, true)
	lbl.custom_minimum_size = Vector2(400 if not UiKit.mobile else 480, 0)
	v.add_child(lbl)
	add_child(box)
	active = Settings.tutorial and Session.sim != null and Session.sim.day() <= 3
	box.visible = active
	_show()

func show_help() -> void:
	step = 0
	active = true
	box.visible = true
	_show()

func _show() -> void:
	if step >= STEPS.size():
		_finish(false)
		return
	var s: Dictionary = STEPS[step]
	# En PC hay variantes con mouse ("Hacé clic", "Pasá el mouse").
	var t: String = s["t"] if UiKit.mobile else s.get("pc", s["t"])
	lbl.text = "(%d/%d) %s" % [step + 1, STEPS.size(), t]
	btn_next.visible = s.get("next", false)
	_place_box.call_deferred()

func _place_box() -> void:
	box.reset_size()
	var vp := get_viewport_rect().size
	if UiKit.mobile:
		# Arriba a la izquierda, bajo la barra; las notificaciones pasan a la derecha mientras se ve.
		box.position = Vector2(10, (screen.hud._top_h() if screen and screen.hud else 70) + 4)
	else:
		box.position = Vector2(10, vp.y - box.size.y - 70)

func _advance() -> void:
	step += 1
	_show()

func _finish(disable: bool) -> void:
	active = false
	box.visible = false
	if disable:
		Settings.tutorial = false
		Settings.save_cfg()

func _process(_d: float) -> void:
	if screen and screen.hud:
		# En celular se oculta mientras hay una hoja inferior abierta o se elige dónde construir
		# (taparía la barra de colocación).
		box.visible = active and not screen.hud.modal_open and not (UiKit.mobile and (screen.hud.current_panel != null or screen.placing != ""))
	if not active or Session.sim == null:
		return
	var s: Dictionary = STEPS[mini(step, STEPS.size() - 1)]
	if s.has("cond") and _done(s["cond"]):
		_advance()

func _done(c: String) -> bool:
	var sim: Simulation = Session.sim
	match c:
		"carpas":
			return sim.count_type("carpa") + sim.count_type("barracon") >= 2
		"puesto":
			return sim.count_type("puesto_rec") >= 1
		"staff":
			for b in sim.st["buildings"]:
				if int(b["do"]) + int(b["di"]) >= 5:
					return true
		"comida":
			return sim.count_type("cazadores") >= 1 and sim.count_type("cocina") >= 1
		"investigar":
			return sim.st["research"]["cur"] != "" or (sim.st["research"]["done"] as Array).size() > 0
		"medico":
			return sim.count_type("puesto_medico") >= 1
		"ley":
			return (sim.st["laws"] as Array).size() >= 1
	return false
