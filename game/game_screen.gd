class_name GameScreen
extends Node
## Pantalla de juego: mundo 3D + interfaz. Coordina selección, construcción y diálogos.

signal exit_requested
signal new_game_requested
signal benchmark_requested

var world: World
var hud: Hud
var hud_layer: CanvasLayer
var frost: FrostLayer
var tutorial: Tutorial
var placing := ""
var selected := 0
var _shown_events := {}
var _last_hover := Vector2.ZERO

func start() -> void:
	world = World.new()
	add_child(world)
	world.setup(Session.sim)
	frost = FrostLayer.new()
	add_child(frost)
	hud_layer = CanvasLayer.new()
	hud_layer.layer = 10
	add_child(hud_layer)
	hud = Hud.new()
	hud_layer.add_child(hud)
	hud.setup(self)
	hud.build_selected.connect(begin_place)
	hud.overlay_changed.connect(func(m): world.set_overlay(m))
	world.camera_rig.tapped.connect(_on_tap)
	world.camera_rig.long_pressed.connect(_on_long)
	world.camera_rig.hovered.connect(_on_hover)
	world.camera_rig.cancelled.connect(cancel_place)
	Session.stepped.connect(_on_stepped)
	Session.game_over.connect(_on_game_over)
	tutorial = Tutorial.new()
	tutorial.screen = self
	hud_layer.add_child(tutorial)
	frost.set_cold(Session.sim.outdoor(), Session.sim.in_wave())
	_check_pending()
	if Session.sim.st["status"] != "playing":
		_on_game_over(Session.sim.st["status"], Session.sim.st["end_reason"])

func reload_from_session() -> void:
	for c in get_children():
		c.queue_free()
	placing = ""
	selected = 0
	_shown_events.clear()
	await get_tree().process_frame
	start()

func _on_stepped(_notes: Array) -> void:
	world.refresh()
	frost.set_cold(Session.sim.outdoor(), Session.sim.in_wave())
	_check_pending()

## Eventos o pedidos esperando decisión (también tras cargar).
func _check_pending() -> void:
	var sim := Session.sim
	for p in sim.st["ev_pending"]:
		var inst: int = p["inst"]
		if not _shown_events.has(inst):
			_shown_events[inst] = true
			var d := EventDialogs.event(hud, inst)
			if d:
				Session.set_paused(true)
				hud.push_modal(d)
	var off: Dictionary = sim.st["req"]["offer"]
	if not off.is_empty() and not _shown_events.has("req" + str(off["expires"])):
		_shown_events["req" + str(off["expires"])] = true
		var r := EventDialogs.request(hud)
		if r:
			Session.set_paused(true)
			hud.push_modal(r)

func on_event(_n: Dictionary) -> void:
	_check_pending()

func on_request() -> void:
	_check_pending()

func _on_game_over(_status: String, _reason: String) -> void:
	Session.set_paused(true)
	cancel_place()
	hud.close_panel()
	hud.push_modal(EventDialogs.game_over(self))

# ---------------------------------------------------------------- selección
func _tile_at(pos: Vector2) -> Vector2i:
	var g := world.ground_at(pos)
	if g == Vector3.INF:
		return Vector2i(-1, -1)
	return world.world_to_tile(g)

func _on_tap(pos: Vector2) -> void:
	if hud.modal_open:
		return
	if placing != "":
		if UiKit.mobile:
			var g := world.ground_at(pos)
			if g != Vector3.INF:
				world.camera_rig.focus_on(g)
		else:
			confirm_place()
		return
	var t := _tile_at(pos)
	var bid := world.building_at_tile(t)
	if bid > 0:
		select_building(bid, false)
	else:
		deselect()
		hud.close_panel()
		var txt := _tile_text(t)
		if txt != "":
			hud.toast(txt)

func _on_long(pos: Vector2) -> void:
	var t := _tile_at(pos)
	var bid := world.building_at_tile(t)
	var txt := ""
	if bid > 0:
		var b := Session.sim.building(bid)
		var d: Dictionary = Session.sim.bdef(b["type"])
		txt = "%s · %s · %d/%d trabajando" % [d["name"], UiKit.LEVEL_NAMES[int(b["lvl"])], int(b["o"]) + int(b["i"]) + int(b["n"]), Session.sim.staff_max(d)]
	else:
		txt = _tile_text(t)
	if txt != "":
		hud.toast(txt)

func _tile_text(t: Vector2i) -> String:
	var sim := Session.sim
	for n in sim.st["nodes"]:
		if int(n["amt"]) > 0 and t.x >= int(n["x"]) and t.x < int(n["x"]) + 2 and t.y >= int(n["y"]) and t.y < int(n["y"]) + 2:
			return "Pila de %s: quedan %d (recolectar con un puesto cercano)" % [Fmt.RES[n["kind"]], int(n["amt"]) / 1000]
	for s in sim.st["sites"]:
		if t.x >= int(s["x"]) and t.x < int(s["x"]) + 3 and t.y >= int(s["y"]) and t.y < int(s["y"]) + 3:
			var names := {"veta_carbon": "Veta de carbón (extractor)", "veta_profunda": "Veta profunda (pozo)", "bosque": "Bosque helado (aserradero)", "muro_hielo": "Muro de hielo (perforadora)", "veta_metal": "Veta de hierro (mina)"}
			return "%s: quedan %d" % [names.get(s["kind"], s["kind"]), int(s["amt"]) / 1000]
	if absi(t.x - sim.msize / 2) <= 2 and absi(t.y - sim.msize / 2) <= 2:
		hud.open_panel("generator")
	return ""

func select_building(bid: int, focus: bool) -> void:
	selected = bid
	world.set_selected(bid)
	hud.open_panel("building", bid)
	if focus:
		var b := Session.sim.building(bid)
		if not b.is_empty():
			world.camera_rig.focus_on(world.rect_center(b["x"], b["y"], b["w"], b["h"]))

func deselect() -> void:
	if selected != 0:
		selected = 0
		world.set_selected(-1)

# ---------------------------------------------------------------- construcción
func begin_place(type: String) -> void:
	placing = type
	if UiKit.mobile:
		hud.close_panel()
	hud.show_place_bar(true)
	hud.toast("Elegí dónde construir: %s" % Session.sim.bdef(type)["name"] + ("" if UiKit.mobile else " (clic derecho o Esc para cancelar)"))
	_update_ghost()

func _on_hover(pos: Vector2) -> void:
	_last_hover = pos
	if placing != "" and not UiKit.mobile:
		_update_ghost()

func _update_ghost() -> void:
	if placing == "":
		world.show_ghost("", Vector2i.ZERO)
		return
	var p := _last_hover
	if UiKit.mobile:
		p = get_viewport().get_visible_rect().size / 2.0
	var t := _tile_at(p)
	world.show_ghost(placing, t)

func confirm_place() -> void:
	if placing == "":
		return
	var pl := world.ghost_place()
	var r := Session.cmd({"c": "build", "type": placing, "x": pl.x, "y": pl.y})
	if r != "":
		hud.toast("No se puede: " + r, UiKit.BAD)
		return
	world.refresh()
	if not (Input.is_key_pressed(KEY_SHIFT) and not UiKit.mobile):
		cancel_place()
	else:
		_update_ghost()

func cancel_place() -> void:
	placing = ""
	hud.show_place_bar(false)
	world.show_ghost("", Vector2i.ZERO)

func _process(_d: float) -> void:
	if placing != "" and UiKit.mobile:
		_update_ghost()

func _unhandled_key_input(ev: InputEvent) -> void:
	if not (ev is InputEventKey) or not ev.pressed or ev.echo:
		return
	match ev.keycode:
		KEY_SPACE:
			Session.toggle_pause()
		KEY_1, KEY_2, KEY_3:
			Session.set_speed(ev.keycode - KEY_0)
			Session.set_paused(false)
		KEY_ESCAPE:
			if placing != "":
				cancel_place()
			elif hud.current_panel:
				hud.close_panel()
			else:
				hud.open_panel("menu")
		KEY_B:
			hud.open_panel("build")
		KEY_G:
			hud.open_panel("generator")
		KEY_L:
			hud.open_panel("laws")
		KEY_I:
			hud.open_panel("research")
		KEY_M:
			hud.open_panel("explore")
		KEY_H:
			hud.cycle_overlay()
		KEY_F5:
			if Session.save_game("manual"):
				hud.toast("Partida guardada.")

func show_help() -> void:
	tutorial.show_help()

func exit_to_menu() -> void:
	exit_requested.emit()

func new_game() -> void:
	new_game_requested.emit()

func run_benchmark() -> void:
	benchmark_requested.emit()
