class_name ExplorePanel
extends SidePanel
## Mapa del páramo: ubicaciones, equipos y expediciones.

var map: ExploreMap
var selected := ""
var detail: VBoxContainer
var _sig := ""

func _title() -> String:
	return "Exploración del páramo"

func _build() -> void:
	map = ExploreMap.new()
	map.panel = self
	map.custom_minimum_size = Vector2(0, 300 if not UiKit.mobile else 240)
	map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map.clip_contents = true
	body.add_child(map)
	detail = UiKit.vbox(6)
	body.add_child(detail)
	_rebuild_detail()

func refresh() -> void:
	var sig := selected
	for t in sim.st["teams"]:
		sig += "%s%s%d" % [t["state"], t["loc"], int(t["eta"])]
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

func _rebuild_detail() -> void:
	UiKit.clear(detail)
	var teams: Array = sim.st["teams"]
	if teams.is_empty():
		detail.add_child(UiKit.label("Para explorar hace falta un Faro de exploradores (investigación: Faros de exploración).", 15, UiKit.TXT_DIM, true))
	for t in teams:
		var st: String = {"home": "En la base", "out": "Viajando a %s", "back": "Volviendo de %s"}[t["state"]]
		if "%s" in st:
			st = st % sim.db["locations"][t["loc"]]["name"]
		var eta := ""
		if t["state"] != "home":
			eta = " · faltan %d h" % maxi(0, int(t["eta"]) - sim.tick())
		detail.add_child(UiKit.label("Equipo del faro #%d: %s%s" % [int(t["bid"]), st, eta], 15, UiKit.TXT, true))
	if sim.in_wave():
		detail.add_child(UiKit.label("Hay una oleada: nadie sale y los equipos afuera esperan refugiados.", 15, UiKit.COLD, true))
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
			var b := UiKit.button("Enviar equipo (5 obreros, %d raciones)" % (int(sim.B["explore"]["food_m"]) / 1000), "exploracion", func():
				var r := Session.cmd({"c": "expedition", "bid": tb, "loc": selected})
				if r != "":
					hud.toast(r, UiKit.BAD)
				_sig = "")
			b.disabled = why != "" or sim.in_wave()
			detail.add_child(b)
			break
	if why != "" and int(s["state"]) != 2:
		detail.add_child(UiKit.label("No disponible: " + why, 14, UiKit.BAD, true))

class ExploreMap extends Control:
	var panel: ExplorePanel

	func _gui_input(ev: InputEvent) -> void:
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

	func _pos(id: String) -> Vector2:
		var L: Dictionary = panel.sim.db["locations"][id]
		var p: Array = L.get("pos", [0, 0])
		var c := size / 2.0
		var sc := minf(size.x, size.y) / 22.0
		return c + Vector2(float(p[0]), float(p[1])) * sc

	func _draw() -> void:
		var sim := panel.sim
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.08, 0.11, 0.15, 0.9))
		var c := size / 2.0
		for r in [3, 6, 9]:
			draw_arc(c, minf(size.x, size.y) / 22.0 * r, 0, TAU, 48, Color(0.25, 0.3, 0.38, 0.5), 1.0)
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
				var off := Vector2(10, -6) if p.x < size.x * 0.6 else Vector2(-10 - nm.length() * UiKit.fs(12) * 0.5, -6)
				draw_string(font, p + off, nm, HORIZONTAL_ALIGNMENT_LEFT, -1, UiKit.fs(12), Color(0.85, 0.9, 0.95) if st == 1 else UiKit.ACCENT)
		for t in sim.st["teams"]:
			if t["state"] == "home" or t["loc"] == "":
				continue
			var total: float = maxf(1.0, float(sim.travel_time(t["loc"])))
			var left: float = float(int(t["eta"]) - sim.tick())
			var k := clampf(1.0 - left / total, 0.0, 1.0)
			if t["state"] == "back":
				k = 1.0 - k
			draw_circle(c.lerp(_pos(t["loc"]), k), 6.0, UiKit.ACCENT)
