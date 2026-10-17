class_name ExplorePanel
extends SidePanel
## Mapa del páramo: ubicaciones y expediciones.

var map: ExploreMap
var selected := ""
var detail: VBoxContainer
var _sig := ""

func _title() -> String:
	return "Exploración del páramo"

func _build() -> void:
	map = ExploreMap.new()
	map.panel = self
	map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map.clip_contents = true
	# PASS: un arrastre que empieza sobre el mapa llega al contenedor con scroll.
	map.mouse_filter = Control.MOUSE_FILTER_PASS
	detail = UiKit.vbox(6)
	if UiKit.mobile:
		# La hoja inferior es baja: mapa y detalle lado a lado, así el detalle de la
		# ubicación y el botón de enviar siempre quedan a la vista.
		var h := maxf(150.0, hud.panel_host.size.y - UiKit.btn_h() - 34.0)
		var hb := UiKit.hbox(10)
		map.custom_minimum_size = Vector2(0, h)
		map.size_flags_stretch_ratio = 1.3 # algo más de ancho para los nombres del mapa
		hb.add_child(map)
		var sc := UiKit.scroll(detail)
		sc.custom_minimum_size = Vector2(0, h)
		hb.add_child(sc)
		body.add_child(hb)
	else:
		map.custom_minimum_size = Vector2(0, 300)
		body.add_child(map)
		body.add_child(detail)
	_rebuild_detail()

func refresh() -> void:
	var sig := selected
	for t in sim.st["teams"]:
		sig += "%s%s%d" % [t["state"], t["loc"], int(t["eta"])]
		if t["state"] != "home":
			sig += "@%d" % sim.tick() # "faltan N h" y el punto del mapa avanzan cada hora
	for id in sim.st["locs"]:
		sig += str(sim.st["locs"][id]["state"])
	sig += str(sim.in_wave())
	if sig != _sig:
		_sig = sig
		_rebuild_detail()
		map.queue_redraw()

func select(id: String) -> void:
	selected = id
	_sig = ""
	refresh()
	_show_detail_end()

## Lleva a la vista el final del detalle (el botón de enviar o el motivo): en PC queda
## debajo del mapa. Espera un cuadro para que el contenedor ya haya acomodado lo nuevo.
func _show_detail_end() -> void:
	await get_tree().process_frame
	if not is_instance_valid(detail) or detail.get_child_count() == 0:
		return
	var n: Node = detail.get_parent()
	while n and not (n is ScrollContainer):
		n = n.get_parent()
	if n:
		(n as ScrollContainer).ensure_control_visible(detail.get_child(detail.get_child_count() - 1) as Control)

func _rebuild_detail() -> void:
	UiKit.clear(detail)
	var teams: Array = sim.st["teams"]
	if teams.is_empty():
		detail.add_child(UiKit.label("Para explorar hace falta una %s (investigación: %s)." % [sim.bdef("faro")["name"], sim.db["research"]["exp_faro"]["name"]], 15, UiKit.TXT_DIM, true))
	var n_team := 0
	for t in teams:
		n_team += 1
		var st: String = {"home": "En la base", "out": "Viajando a %s", "back": "Volviendo de %s"}[t["state"]]
		if "%s" in st:
			st = st % sim.db["locations"][t["loc"]]["name"]
		var eta := ""
		if t["state"] != "home":
			eta = " · faltan %d h" % maxi(0, int(t["eta"]) - sim.tick())
		detail.add_child(UiKit.label("Expedición #%d: %s%s" % [n_team, st, eta], 15, UiKit.TXT, true))
	if sim.in_wave():
		detail.add_child(UiKit.label("Hay una oleada: no sale ninguna expedición y las que están afuera esperan a resguardo.", 15, UiKit.COLD, true))
	if selected == "":
		detail.add_child(UiKit.label("Tocá una ubicación del mapa para ver detalles.", 15, UiKit.TXT_DIM, true))
		return
	var L: Dictionary = sim.db["locations"][selected]
	var s: Dictionary = sim.st["locs"][selected]
	detail.add_child(UiKit.label(L["name"], 18, UiKit.ACCENT))
	detail.add_child(UiKit.label(L["desc"], 14, UiKit.TXT_DIM, true))
	detail.add_child(row("Viaje", "%d h de ida" % sim.travel_time(selected)))
	var state_txt: String = ["sin descubrir", "descubierta", "explorada"][int(s["state"])]
	detail.add_child(row("Estado", state_txt))
	var why := sim.loc_accessible(selected)
	for t in teams:
		if t["state"] == "home":
			var tb: int = t["bid"]
			var b := UiKit.button("Enviar expedición (5 obreros, %d raciones)" % (int(sim.B["explore"]["food_m"]) / 1000), "exploracion", func():
				cmd({"c": "expedition", "bid": tb, "loc": selected})
				_sig = "")
			b.disabled = why != "" or sim.in_wave()
			b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			detail.add_child(b)
			break
	if why != "" and int(s["state"]) != 2:
		detail.add_child(UiKit.label("No disponible: " + why, 14, UiKit.BAD, true))

class ExploreMap extends Control:
	var panel: ExplorePanel

	func _gui_input(ev: InputEvent) -> void:
		if UiKit.is_emulated(ev):
			return # el toque llega como ScreenTouch
		var pressed: bool = (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT) or (ev is InputEventScreenTouch and ev.pressed)
		if not pressed:
			return
		var best := ""
		var bd := 1e9
		for id in panel.sim.st["locs"]:
			if int(panel.sim.st["locs"][id]["state"]) == 0:
				continue
			var p := _pos(id)
			var d: float = p.distance_to(ev.position)
			if d < bd:
				bd = d
				best = id
		if best != "" and bd < 40:
			panel.select(best)
			accept_event()

	## Escala del mapa: en un recuadro apaisado (la hoja del celular) se estira a lo ancho
	## hasta 1,6 veces para que las ubicaciones no queden amontonadas.
	func _scale() -> Vector2:
		var sy := minf(size.x, size.y) / 22.0
		return Vector2(minf(size.x, size.y * 1.6) / 22.0, sy)

	func _pos(id: String) -> Vector2:
		var L: Dictionary = panel.sim.db["locations"][id]
		var p: Array = L.get("pos", [0, 0])
		var c := size / 2.0
		return c + Vector2(float(p[0]), float(p[1])) * _scale()

	func _draw() -> void:
		var sim := panel.sim
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.08, 0.11, 0.15, 0.9))
		var c := size / 2.0
		var sc := _scale()
		for r in [3, 6, 9]:
			var pts := PackedVector2Array()
			for i in 49:
				var a := TAU * i / 48.0
				pts.append(c + Vector2(cos(a) * sc.x, sin(a) * sc.y) * r)
			draw_polyline(pts, Color(0.25, 0.3, 0.38, 0.5), 1.0)
		for id in sim.st["locs"]:
			if int(sim.st["locs"][id]["state"]) == 0:
				continue
			for nb in sim.db["locations"][id].get("reveals", []):
				if int(sim.st["locs"][nb]["state"]) > 0:
					draw_line(_pos(id), _pos(nb), Color(0.4, 0.45, 0.55, 0.5), 2.0)
		draw_circle(c, 9.0, Color(1.0, 0.6, 0.25))
		var font := get_theme_default_font()
		for id in sim.st["locs"]:
			var st: int = sim.st["locs"][id]["state"]
			if st == 0:
				continue
			var p := _pos(id)
			var col := Color(0.6, 0.85, 1.0) if st == 1 else Color(0.5, 0.55, 0.6)
			if sim.loc_accessible(id) == "requiere investigación":
				col = Color(0.7, 0.5, 0.9)
			draw_circle(p, 8.0 if id != panel.selected else 11.0, col)
			if id == panel.selected:
				draw_arc(p, 14.0, 0, TAU, 24, UiKit.ACCENT, 2.0)
			# Nombres solo de lo seleccionado o lo pendiente de explorar (evita amontonar texto).
			if id == panel.selected or st == 1:
				var nm: String = sim.db["locations"][id]["name"]
				var fsz := UiKit.fs(12)
				var tw := font.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz).x
				var off := Vector2(12, -8) if p.x + 12 + tw < size.x - 4 else Vector2(-12 - tw, -8)
				draw_string(font, p + off, nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, Color(0.85, 0.9, 0.95) if st == 1 else UiKit.ACCENT)
		for t in sim.st["teams"]:
			if t["state"] == "home" or t["loc"] == "":
				continue
			var total: float = maxf(1.0, float(sim.travel_time(t["loc"])))
			var left: float = float(int(t["eta"]) - sim.tick())
			var k := clampf(1.0 - left / total, 0.0, 1.0)
			if t["state"] == "back":
				k = 1.0 - k
			draw_circle(c.lerp(_pos(t["loc"]), k), 6.0, UiKit.ACCENT)
