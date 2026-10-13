class_name MainMenu
extends Control
## Menú principal con la ciudad de fondo.

signal new_game
signal continue_game(slot: String)
signal benchmark

var content: VBoxContainer
var panel: PanelContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiKit.theme
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit._sb(Color(0.04, 0.05, 0.08, 0.86), 10, UiKit.ACCENT_D, 1, 18))
	panel.custom_minimum_size = Vector2(440 if not UiKit.mobile else 560, 0)
	add_child(panel)
	content = UiKit.vbox(10)
	panel.add_child(content)
	_main()

func _place() -> void:
	panel.reset_size()
	var vp := get_viewport_rect().size
	panel.position = Vector2(vp.x * 0.06, (vp.y - panel.size.y) / 2)

func _main() -> void:
	UiKit.clear(content)
	var t := UiKit.label("ÚLTIMA BRASA", 40, UiKit.ACCENT)
	content.add_child(t)
	content.add_child(UiKit.label("Sesenta días de invierno eterno.", 16, UiKit.TXT_DIM))
	var saves := Session.list_saves()
	if saves.size() > 0:
		var last: Dictionary = saves[0]
		var slot: String = last["slot"]
		content.add_child(UiKit.button("Continuar (día %d)" % int(last["day"]), "x1", func(): continue_game.emit(slot)))
	content.add_child(UiKit.button("Nueva partida", "ok", func(): new_game.emit()))
	if saves.size() > 0:
		content.add_child(UiKit.button("Cargar partida", "reporte", func(): _load()))
	content.add_child(UiKit.button("Ajustes", "menu", func(): _settings()))
	content.add_child(UiKit.button("Benchmark", "reloj", func(): benchmark.emit()))
	content.add_child(UiKit.button("Créditos", "estrella", func(): _credits()))
	if not Settings.is_mobile():
		content.add_child(UiKit.button("Salir", "cerrar", func(): get_tree().quit()))
	content.add_child(UiKit.label("v%s · Dificultad media" % Session.GAME_VERSION, 12, UiKit.TXT_DIM))
	call_deferred("_place")

func _load() -> void:
	UiKit.clear(content)
	content.add_child(UiKit.title("Cargar partida"))
	var list := UiKit.vbox(6)
	for s in Session.list_saves():
		var slot: String = s["slot"]
		list.add_child(UiKit.button("%s · día %d · %d personas · %s" % [slot, int(s["day"]), int(s["pop"]), str(s["date"]).replace("T", " ")], "", func(): continue_game.emit(slot)))
	var sc := UiKit.scroll(list)
	sc.custom_minimum_size = Vector2(0, 300)
	content.add_child(sc)
	content.add_child(UiKit.button("Volver", "cerrar", func(): _main()))
	call_deferred("_place")

func _settings() -> void:
	UiKit.clear(content)
	var sp := SettingsPanel.new()
	sp.sim = null
	var holder := UiKit.vbox(6)
	content.add_child(holder)
	sp.body = holder
	sp._rebuild()
	content.add_child(UiKit.button("Volver", "cerrar", func(): _main()))
	call_deferred("_place")

func _credits() -> void:
	UiKit.clear(content)
	content.add_child(UiKit.title("Créditos"))
	var txt := "Diseño, programación, modelos, íconos y sonido: generados para este proyecto (licencia propia).\nMotor: Godot Engine 4 (licencia MIT).\nTipografía: la fuente por defecto de Godot.\nVer CREDITOS.md para el detalle completo."
	content.add_child(UiKit.label(txt, 15, UiKit.TXT, true))
	content.add_child(UiKit.button("Volver", "cerrar", func(): _main()))
	call_deferred("_place")
