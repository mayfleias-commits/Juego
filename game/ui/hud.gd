class_name Hud
extends Control
## Interfaz principal de la partida. Solo lee el estado y manda órdenes vía Session.

signal build_selected(type: String)
signal overlay_changed(mode: int)

var screen # GameScreen
var sim: Simulation
var info: InfoPopup
var top: PanelContainer
var bottom: PanelContainer
var panel_host: Control
var modal_host: Control
var notes_box: VBoxContainer
var toast_box: VBoxContainer
var place_bar: HBoxContainer
var current_panel: SidePanel = null
var res_labels := {}
var res_trend := {}
var lbl_pop: Label
var lbl_temp: Label
var lbl_clock: Label
var bar_hope: ProgressBar
var bar_disc: ProgressBar
var lbl_hope: Label
var lbl_disc: Label
var speed_btns: Array = []
var overlay_mode := -1
var history: Array = [] # stock de recursos por hora (últimas 25 h)
var _acc := 0.0
var _modal_queue: Array = []
var modal_open := false

func setup(scr) -> void:
	screen = scr
	sim = Session.sim
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UiKit.theme
	_build_top()
	_build_bottom()
	panel_host = Control.new()
	panel_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel_host)
	_layout_panel_host()
	notes_box = UiKit.vbox(4)
	notes_box.position = Vector2(8, _top_h() + (70 if UiKit.mobile else 8))
	notes_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(notes_box)
	toast_box = UiKit.vbox(4)
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(toast_box)
	_build_place_bar()
	modal_host = Control.new()
	modal_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(modal_host)
	modal_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	info = InfoPopup.new()
	add_child(info)
	Session.stepped.connect(_on_stepped)
	Session.speed_changed.connect(_on_speed)
	Session.day_ended.connect(_on_day_end)
	get_viewport().size_changed.connect(_on_resize)
	refresh()
	_on_speed(0 if Session.paused else Session.speed)

func _top_h() -> int:
	return 64 if UiKit.mobile else 50

func _bottom_h() -> int:
	return 76 if UiKit.mobile else 56

func _on_resize() -> void:
	_layout_panel_host()

func _layout_panel_host() -> void:
	var vp := get_viewport_rect().size
	if UiKit.mobile:
		# Hoja inferior: ocupa el ancho y algo más de la mitad del alto.
		panel_host.position = Vector2(0, vp.y * 0.36)
		panel_host.size = Vector2(vp.x, vp.y * 0.64 - _bottom_h())
	else:
		var w := minf(460.0, vp.x * 0.42)
		panel_host.position = Vector2(vp.x - w - 6, _top_h() + 6)
		panel_host.size = Vector2(w, vp.y - _top_h() - _bottom_h() - 12)
	if current_panel:
		current_panel.size = panel_host.size

# ---------------------------------------------------------------- barra superior
func _build_top() -> void:
	top = PanelContainer.new()
	top.custom_minimum_size = Vector2(0, _top_h())
	top.add_theme_stylebox_override("panel", UiKit._sb(Color(0.05, 0.07, 0.1, 0.9), 0, Color(0, 0, 0, 0), 0, 8))
	add_child(top)
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE, Control.PRESET_MODE_MINSIZE)
	var h := UiKit.hbox(14 if not UiKit.mobile else 8)
	top.add_child(h)
	# Margen para recortes de pantalla (notch) en celulares.
	if UiKit.mobile:
		var safe := DisplayServer.get_display_safe_area()
		var scr := DisplayServer.screen_get_size()
		if safe.size.x > 0 and scr.x > 0:
			var k := 960.0 / float(scr.x)
			var pad_l := int(safe.position.x * k)
			var pad_r := int((scr.x - safe.end.x) * k)
			top.add_theme_stylebox_override("panel", UiKit._sb(Color(0.05, 0.07, 0.1, 0.9), 0, Color(0, 0, 0, 0), 0, 8 + maxi(pad_l, pad_r)))
	for r in Simulation.RES:
		var item := UiKit.hbox(3)
		item.add_child(UiKit.icon_rect(r, 24))
		var l := UiKit.label("0", 17)
		item.add_child(l)
		var tr := UiKit.label("", 13, UiKit.TXT_DIM)
		tr.visible = not UiKit.mobile
		item.add_child(tr)
		res_labels[r] = l
		res_trend[r] = tr
		h.add_child(item)
		item.set_meta("res", r)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(spacer)
	var pop := UiKit.hbox(3)
	pop.add_child(UiKit.icon_rect("poblacion", 24))
	lbl_pop = UiKit.label("0", 17)
	pop.add_child(lbl_pop)
	h.add_child(pop)
	var hope := UiKit.hbox(3)
	hope.add_child(UiKit.icon_rect("esperanza", 22))
	var hv := UiKit.vbox(0)
	lbl_hope = UiKit.label("Esperanza", 12 if not UiKit.mobile else 9, UiKit.TXT_DIM)
	hv.add_child(lbl_hope)
	bar_hope = UiKit.bar(50, Color(1.0, 0.65, 0.25), 90 if not UiKit.mobile else 64, 8)
	hv.add_child(bar_hope)
	hope.add_child(hv)
	h.add_child(hope)
	var disc := UiKit.hbox(3)
	disc.add_child(UiKit.icon_rect("descontento", 22))
	var dv := UiKit.vbox(0)
	lbl_disc = UiKit.label("Descontento", 12 if not UiKit.mobile else 9, UiKit.TXT_DIM)
	dv.add_child(lbl_disc)
	bar_disc = UiKit.bar(20, Color(0.9, 0.32, 0.28), 90 if not UiKit.mobile else 64, 8)
	dv.add_child(bar_disc)
	disc.add_child(dv)
	h.add_child(disc)
	var temp := UiKit.hbox(3)
	temp.add_child(UiKit.icon_rect("temperatura", 22))
	lbl_temp = UiKit.label("-20 °C", 17, UiKit.COLD)
	temp.add_child(lbl_temp)
	h.add_child(temp)
	var clk := UiKit.hbox(3)
	lbl_clock = UiKit.label("Día 1 · 07:00", 16)
	clk.add_child(lbl_clock)
	# En celular el reloj y la velocidad van en un grupo aparte arriba a la derecha.
	var speed_parent: Container = h
	if UiKit.mobile:
		var cl := PanelContainer.new()
		cl.add_theme_stylebox_override("panel", UiKit._sb(Color(0.05, 0.07, 0.1, 0.85), 8, Color(0, 0, 0, 0), 0, 6))
		var ch := UiKit.hbox(6)
		cl.add_child(ch)
		ch.add_child(clk)
		add_child(cl)
		cl.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		cl.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 6)
		cl.offset_top = _top_h() + 4
		speed_parent = ch
	else:
		h.add_child(clk)
	# Los popups se conectan después de crear `info`
	call_deferred("_attach_top_tips", pop, hope, disc, temp, clk)
	for i in 4:
		var names := ["pausa", "x1", "x2", "x3"]
		var b := UiKit.button("", names[i], Callable(), 0)
		b.custom_minimum_size = Vector2(UiKit.btn_h() - 6, UiKit.btn_h() - 8)
		b.toggle_mode = true
		var idx := i
		b.pressed.connect(func(): _set_speed(idx))
		b.tooltip_text = ["Pausa (Espacio)", "Velocidad x1 (1)", "Velocidad x2 (2)", "Velocidad x3 (3)"][i]
		speed_parent.add_child(b)
		speed_btns.append(b)

func _attach_top_tips(pop, hope, disc, temp, clk) -> void:
	for r in res_labels:
		var item: Control = res_labels[r].get_parent()
		info.attach(item, func(): return _res_tip(r))
	info.attach(pop, _pop_tip)
	info.attach(hope, func(): return _mood_tip(true))
	info.attach(disc, func(): return _mood_tip(false))
	info.attach(temp, _temp_tip)
	info.attach(clk, _temp_tip)

func _set_speed(i: int) -> void:
	if i == 0:
		Session.set_paused(true)
	else:
		Session.set_speed(i)
		Session.set_paused(false)

func _on_speed(s: int) -> void:
	for i in speed_btns.size():
		speed_btns[i].button_pressed = (i == s)

# ---------------------------------------------------------------- barra inferior
func _build_bottom() -> void:
	bottom = PanelContainer.new()
	bottom.custom_minimum_size = Vector2(0, _bottom_h())
	bottom.add_theme_stylebox_override("panel", UiKit._sb(Color(0.05, 0.07, 0.1, 0.9), 0, Color(0, 0, 0, 0), 0, 6))
	add_child(bottom)
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE, Control.PRESET_MODE_MINSIZE)
	var h := UiKit.hbox(6)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_child(h)
	var items := [
		["Construir", "construir", "build"], ["Generador", "generador", "generator"], ["Leyes", "leyes", "laws"],
		["Investigar", "investigacion", "research"], ["Explorar", "exploracion", "explore"],
		["Capas", "capas", "overlay"], ["Reporte", "reporte", "report"], ["Menú", "menu", "menu"],
	]
	for it in items:
		var key: String = it[2]
		var b := UiKit.button(it[0] if not UiKit.mobile else "", it[1], func(): open_panel(key), 0)
		if UiKit.mobile:
			b.custom_minimum_size = Vector2(UiKit.btn_h() + 26, UiKit.btn_h())
		b.tooltip_text = it[0]
		b.name = "btn_" + key
		h.add_child(b)

func _build_place_bar() -> void:
	place_bar = UiKit.hbox(10)
	place_bar.visible = false
	add_child(place_bar)
	place_bar.add_child(UiKit.button("Construir aquí", "ok", func(): screen.confirm_place(), 190))
	place_bar.add_child(UiKit.button("Cancelar", "cerrar", func(): screen.cancel_place(), 150))

func show_place_bar(show: bool) -> void:
	place_bar.visible = show and UiKit.mobile
	if place_bar.visible:
		place_bar.reset_size()
		var vp := get_viewport_rect().size
		place_bar.position = Vector2((vp.x - place_bar.size.x) / 2, vp.y - _bottom_h() - place_bar.size.y - 12)

# ---------------------------------------------------------------- paneles
func open_panel(key: String, arg = null) -> void:
	if key == "overlay":
		cycle_overlay()
		return
	if current_panel and current_panel.key == key and arg == null:
		close_panel()
		return
	close_panel()
	var p: SidePanel = null
	match key:
		"build":
			p = BuildPanel.new()
		"generator":
			p = GeneratorPanel.new()
		"laws":
			p = LawsPanel.new()
		"research":
			p = ResearchPanel.new()
		"explore":
			p = ExplorePanel.new()
		"report":
			p = ReportPanel.new()
		"menu":
			p = MenuPanel.new()
		"settings":
			p = SettingsPanel.new()
		"building":
			p = BuildingPanel.new()
			p.bid = int(arg)
	if p == null:
		return
	p.key = key
	p.hud = self
	current_panel = p
	panel_host.add_child(p)
	p.position = Vector2.ZERO
	p.size = panel_host.size
	p.build()
	p.refresh()

func close_panel() -> void:
	if current_panel:
		if current_panel.key == "building" and screen:
			screen.deselect()
		current_panel.queue_free()
		current_panel = null

func cycle_overlay() -> void:
	overlay_mode += 1
	if overlay_mode > 2:
		overlay_mode = -1
	var names := ["Calor", "Salud (riesgo por frío)", "Recursos"]
	toast("Capa: " + (names[overlay_mode] if overlay_mode >= 0 else "ninguna"))
	overlay_changed.emit(overlay_mode)

# ---------------------------------------------------------------- modales
func push_modal(dlg: Control) -> void:
	_modal_queue.append(dlg)
	if not modal_open:
		_show_next_modal()

func _show_next_modal() -> void:
	if _modal_queue.is_empty():
		modal_open = false
		modal_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UiKit.clear(modal_host)
		return
	modal_open = true
	UiKit.clear(modal_host)
	modal_host.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	modal_host.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dlg: Control = _modal_queue.pop_front()
	var cc := CenterContainer.new()
	modal_host.add_child(cc)
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cc.add_child(dlg)

func close_modal() -> void:
	_show_next_modal()

# ---------------------------------------------------------------- notificaciones
const NOTE_ICONS := {"alerta": "alerta", "muerte": "muerte", "evento": "pedido", "ley": "leyes", "investigacion": "investigacion",
	"obra": "construir", "oleada": "temperatura", "llegada": "poblacion", "exploracion": "exploracion", "pedido": "pedido",
	"fin": "estrella", "recurso": "carbon", "autom": "automata"}

const NOTE_SOUNDS := {"muerte": "campana", "oleada": "oleada", "evento": "evento", "pedido": "evento",
	"investigacion": "investigacion", "ley": "ley", "obra": "obra", "alerta": "evento"}

func add_note(n: Dictionary) -> void:
	var k: String = n.get("kind", "")
	if k == "rechazo":
		toast(n["text"], UiKit.BAD)
		return
	if NOTE_SOUNDS.has(k):
		Audio.play(NOTE_SOUNDS[k], -4.0 if k in ["oleada", "muerte"] else -8.0)
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", UiKit._sb(Color(0.06, 0.08, 0.11, 0.82), 6, Color(0, 0, 0, 0), 0, 6))
	var h := UiKit.hbox(6)
	h.add_child(UiKit.icon_rect(NOTE_ICONS.get(k, "alerta"), 18))
	var col := UiKit.TXT
	if k in ["alerta", "muerte"]:
		col = Color(1.0, 0.75, 0.6)
	elif k == "oleada":
		col = UiKit.COLD
	var l := UiKit.label(n["text"], 14, col, true)
	l.custom_minimum_size = Vector2(320 if not UiKit.mobile else 380, 0)
	h.add_child(l)
	row.add_child(h)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	if n.has("bid"):
		var bid: int = n["bid"]
		row.gui_input.connect(func(ev):
			if (ev is InputEventMouseButton and ev.pressed) or (ev is InputEventScreenTouch and ev.pressed):
				screen.select_building(bid, true))
	notes_box.add_child(row)
	notes_box.move_child(row, 0)
	var max_n := 4 if UiKit.mobile else 6
	while notes_box.get_child_count() > max_n:
		var last := notes_box.get_child(notes_box.get_child_count() - 1)
		notes_box.remove_child(last)
		last.queue_free()
	var tw := row.create_tween()
	tw.tween_interval(9.0)
	tw.tween_property(row, "modulate:a", 0.0, 1.0)
	tw.tween_callback(row.queue_free)

func toast(text: String, col: Color = UiKit.TXT) -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiKit._sb(Color(0.05, 0.06, 0.09, 0.9), 6, UiKit.ACCENT_D, 1, 10))
	p.add_child(UiKit.label(text, 16, col))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(p)
	await get_tree().process_frame
	var vp := get_viewport_rect().size
	p.position = Vector2((vp.x - p.size.x) / 2, vp.y - _bottom_h() - 70 - (60 if place_bar.visible else 0))
	var tw := p.create_tween()
	tw.tween_interval(2.2)
	tw.tween_property(p, "modulate:a", 0.0, 0.6)
	tw.tween_callback(p.queue_free)

# ---------------------------------------------------------------- actualización
func _on_stepped(notes: Array) -> void:
	for n in notes:
		add_note(n)
		if n.get("kind", "") == "evento" and n.has("inst"):
			screen.on_event(n)
		if n.get("kind", "") == "pedido" and n.has("id") and not n.has("ok"):
			screen.on_request()
	var snap := {}
	for r in Simulation.RES:
		snap[r] = sim.res(r)
	history.append(snap)
	if history.size() > 25:
		history.remove_at(0)
	refresh()

var _day_card: PanelContainer

## Resumen breve al final de cada día (no bloquea; desaparece solo).
func _on_day_end(rep: Dictionary) -> void:
	if _day_card and is_instance_valid(_day_card):
		_day_card.queue_free()
	var c := PanelContainer.new()
	c.add_theme_stylebox_override("panel", UiKit._sb(Color(0.06, 0.08, 0.12, 0.92), 8, UiKit.ACCENT_D, 1, 12))
	var v := UiKit.vbox(4)
	c.add_child(v)
	v.add_child(UiKit.label("Fin del día %d" % int(rep["day"]), 18, UiKit.ACCENT))
	var deaths: int = rep["deaths"]
	var line := "Mínima %d °C · %d personas · %d enfermos" % [int(rep["tmin"]), int(rep["pop"]), int(rep["sick"])]
	if deaths > 0:
		line += " · %d muertes" % deaths
	if int(rep["arrived"]) > 0:
		line += " · llegaron %d" % int(rep["arrived"])
	v.add_child(UiKit.label(line, 15))
	var res_line := ""
	for r in ["carbon", "madera", "metal", "raciones"]:
		var net: int = (int(rep["prod"].get(r, 0)) - int(rep["cons"].get(r, 0))) / FX.ONE
		res_line += "%s %s   " % [UiKit.RES_NAMES[r], Fmt.sgn(net)]
	v.add_child(UiKit.label(res_line, 14, UiKit.TXT_DIM))
	var h := UiKit.hbox(8)
	h.add_child(UiKit.button("Ver reporte", "reporte", func():
		open_panel("report")
		if is_instance_valid(c):
			c.queue_free()))
	var xb := UiKit.button("", "cerrar", func():
		if is_instance_valid(c):
			c.queue_free())
	xb.custom_minimum_size = Vector2(UiKit.btn_h(), UiKit.btn_h())
	h.add_child(xb)
	v.add_child(h)
	add_child(c)
	move_child(c, modal_host.get_index()) # debajo de los diálogos
	_day_card = c
	await get_tree().process_frame
	if not is_instance_valid(c):
		return
	var vp := get_viewport_rect().size
	c.position = Vector2((vp.x - c.size.x) / 2, _top_h() + (70 if UiKit.mobile else 10))
	var tw := c.create_tween()
	tw.tween_interval(10.0)
	tw.tween_property(c, "modulate:a", 0.0, 1.0)
	tw.tween_callback(c.queue_free)

func _process(delta: float) -> void:
	_acc += delta
	if _acc > 0.25:
		_acc = 0.0
		if current_panel:
			current_panel.refresh()

func refresh() -> void:
	if sim == null:
		return
	for r in Simulation.RES:
		var v := sim.res(r)
		var l: Label = res_labels[r]
		l.text = str(v / FX.ONE)
		var full := sim.cap(r) > 0 and v * 100 / sim.cap(r) >= 95
		l.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4) if full else (UiKit.BAD if v < 10 * FX.ONE else UiKit.TXT))
		var tr: Label = res_trend[r]
		if history.size() >= 2:
			var old: int = history[0][r]
			var d := (v - old) / FX.ONE
			tr.text = ("▲%d" % d) if d > 0 else (("▼%d" % -d) if d < 0 else "")
			tr.add_theme_color_override("font_color", UiKit.GOOD if d > 0 else UiKit.BAD)
	lbl_pop.text = "%d" % sim.total_pop() + ("  ✚%d" % sim.total_sick() if sim.total_sick() > 0 else "")
	bar_hope.value = sim.st["hope"] / 1000.0
	bar_disc.value = sim.st["disc"] / 1000.0
	lbl_hope.text = ("Esperanza %d" if not UiKit.mobile else "Esp. %d") % (sim.st["hope"] / FX.ONE)
	lbl_disc.text = ("Descontento %d" if not UiKit.mobile else "Desc. %d") % (sim.st["disc"] / FX.ONE)
	var t := sim.outdoor()
	lbl_temp.text = Fmt.temp(t)
	lbl_temp.add_theme_color_override("font_color", UiKit.COLD if t > -40 else Color(0.6, 0.6, 1.0))
	lbl_clock.text = Fmt.day_hour(sim) + (" · OLEADA" if sim.in_wave() else "")
	if UiKit.mobile:
		lbl_clock.text = "D%d %02d:00%s" % [sim.day(), sim.hour(), " ❄" if sim.in_wave() else ""]

# ---------------------------------------------------------------- textos de detalle
func _res_tip(r: String) -> String:
	var v := sim.res(r) / FX.ONE
	var c := sim.cap(r) / FX.ONE
	var s := "[b]%s[/b]\nEn depósito: %d / %d\n" % [UiKit.RES_NAMES[r], v, c]
	var reps: Array = sim.st["reports"]
	if reps.size() > 0:
		var rep: Dictionary = reps[reps.size() - 1]
		var p: int = int(rep["prod"].get(r, 0)) / FX.ONE
		var co: int = int(rep["cons"].get(r, 0)) / FX.ONE
		s += "Ayer: +%d producido, −%d consumido (neto %s)\n" % [p, co, Fmt.sgn(p - co)]
	if history.size() >= 2:
		s += "Últimas %d h: %s\n" % [history.size() - 1, Fmt.sgn((sim.res(r) - int(history[0][r])) / FX.ONE)]
	if r == "carbon":
		var per := sim.gen_coal_per_hour() / FX.ONE
		s += "Generador: %d por hora" % per
		if per > 0:
			s += " (alcanza ~%d h)" % (v / maxi(1, per))
	if int(sim.st["wasted"][r]) > 0:
		s += "\n[color=#ffb347]Perdido por falta de espacio: %d[/color]" % (int(sim.st["wasted"][r]) / FX.ONE)
	return s

func _pop_tip() -> String:
	var s := "[b]Población: %d[/b]\n" % sim.total_pop()
	var names := {"obreros": "Obreros", "ingenieros": "Ingenieros", "ninos": "Niños"}
	for c in Simulation.CLASSES:
		var p: Dictionary = sim.st["pop"][c]
		s += "%s: %d sanos, %d leves, %d graves" % [names[c], p["h"], p["sl"], p["sg"]]
		if int(sim.st["away"][c]) > 0:
			s += ", %d explorando" % int(sim.st["away"][c])
		s += "\n"
	s += "Sin trabajo: %d obreros, %d ingenieros\n" % [int(sim.st["idle"].get("obreros", 0)), int(sim.st["idle"].get("ingenieros", 0))]
	s += "Sin techo: %d   Autómatas: %d (%d libres)\n" % [int(sim.st["homeless"]), int(sim.st["autos_total"]), int(sim.st["autos_free"])]
	s += "Muertos: %d   Cuerpos sin enterrar: %d" % [int(sim.st["dead"]), int(sim.st["bodies"])]
	return s

const CAUSE_NAMES := {"base": "Base (cansancio del invierno)", "sin_techo": "Gente sin techo", "frio": "Viviendas frías",
	"hambre": "Hambre", "enfermos": "Enfermos sin atender", "cuerpos": "Cuerpos sin enterrar", "muertes": "Muertes recientes",
	"oleada": "Oleada de frío", "turnos": "Turnos largos", "generador": "Generador apagado", "edificios": "Edificios (fe, orden, ocio)",
	"leyes": "Leyes", "bienestar": "Nada falta"}

func _mood_tip(hope: bool) -> String:
	var m: Dictionary = sim.st.get("mood", {})
	var cur: int = (sim.st["hope"] if hope else sim.st["disc"]) / FX.ONE
	var s := "[b]%s: %d[/b]\n" % ["Esperanza" if hope else "Descontento", cur]
	if m.is_empty():
		return s
	var tgt: int = int(m["ht" if hope else "dt"]) / FX.ONE
	s += "Tiende a: %d %s\n" % [tgt, "▲" if tgt > cur else ("▼" if tgt < cur else "")]
	var parts: Dictionary = m["hp" if hope else "dp"]
	for k in parts:
		var v: int = int(parts[k]) / FX.ONE
		if v == 0:
			continue
		var good := (v > 0) == hope
		s += "[color=%s]%s %s[/color]\n" % ["#8be08b" if good else "#ff8070", Fmt.sgn(v), CAUSE_NAMES.get(k, k)]
	s += "[color=#a0a8b8]%s[/color]" % ("Si llega a 0, la gente se rinde." if hope else "Si llega a 100, te expulsan.")
	return s

func _temp_tip() -> String:
	var s := "[b]Temperatura exterior: %s[/b]\n" % Fmt.temp(sim.outdoor())
	var w := sim.wave_on(sim.day())
	if not w.is_empty():
		s += "[color=#9fd0ff]Oleada en curso: %s[/color]\n" % w["name"]
	s += "Pronóstico:\n"
	for f in sim.forecast(5):
		s += "Día %d: %d / %d °C%s\n" % [f[0], f[1], f[2], "  [color=#9fd0ff]OLEADA[/color]" if int(f[3]) == 1 else ""]
	var nw := sim.wave_next(sim.day())
	if not nw.is_empty():
		s += "Próxima oleada: %s, día %d" % [nw["name"], int(nw["start"])]
	return s
