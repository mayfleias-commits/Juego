class_name MainMenu
extends Control
## Menú principal con la ciudad de fondo. Las subpantallas (Cargar, Ajustes, Créditos,
## Licencias) reemplazan el contenido del mismo panel; el botón atrás de Android vuelve
## al menú raíz (ver go_back) y desde la raíz pide un segundo toque para salir.

signal new_game
signal continue_game(slot: String)
signal benchmark

## Ciudad de fondo (la pone main.gd): los cambios de Ajustes se le aplican al momento.
var world: World
var content: VBoxContainer
var panel: PanelContainer
## Página actual: "main", "load", "settings", "credits" o "licenses".
var page := "main"
## Contenedor desplazable de la página actual (su alto se ajusta a la pantalla).
var _scroll: ScrollContainer
var _notice := ""
var _back_ms := -100000

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
	get_viewport().size_changed.connect(_queue_place)
	Settings.changed.connect(_queue_place)
	_main()

## Botón de una partida guardada: dos líneas (nombre y detalle) que no ensanchan el panel.
## Las incompatibles o dañadas aparecen deshabilitadas, con el motivo.
static func save_button(s: Dictionary, cb: Callable) -> Button:
	var b := UiKit.button(Session.save_text(s), "", cb)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.clip_text = true
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, UiKit.btn_h() + (26 if UiKit.mobile else 18))
	b.disabled = not bool(s.get("ok", false))
	return b

## Atrás de Android. Devuelve false si hay que cerrar la app.
func go_back() -> bool:
	match page:
		"main":
			var now := Time.get_ticks_msec()
			if now - _back_ms < 2500:
				return false
			_back_ms = now
			show_notice("Tocá «atrás» otra vez para salir del juego.")
		"licenses":
			_credits()
		_:
			_main()
	return true

## Aviso en la portada del menú (p. ej. una partida que no se pudo cargar):
## vuelve a la portada para que se vea y para que la lista de partidas se actualice.
func show_notice(text: String) -> void:
	_notice = text
	_main()

func _queue_place() -> void:
	call_deferred("_place")

func _place() -> void:
	if not is_inside_tree():
		return
	var vp := get_viewport_rect().size
	_fit_scroll(vp)
	panel.reset_size()
	panel.position = Vector2(vp.x * 0.06, maxf(8.0, (vp.y - panel.size.y) / 2))

## El alto del área desplazable es lo que queda de pantalla después del resto del panel.
func _fit_scroll(vp: Vector2) -> void:
	if _scroll == null or not is_instance_valid(_scroll) or _scroll.get_child_count() == 0:
		return
	var used := 0.0
	var n := 0
	for c in content.get_children():
		if c is Control and c.visible and c != _scroll:
			used += (c as Control).get_combined_minimum_size().y
			n += 1
	used += content.get_theme_constant("separation") * n
	var pad := panel.get_theme_stylebox("panel").get_minimum_size().y
	var avail := maxf(120.0, vp.y - 16.0 - pad - used)
	var want: float = (_scroll.get_child(0) as Control).get_combined_minimum_size().y
	if _scroll.has_meta("fill"):
		want = avail
	_scroll.custom_minimum_size = Vector2(0, clampf(want, 120.0, avail))

## Vacía el panel. Los nodos viejos se ocultan ya (y se liberan al final del cuadro)
## para que no cuenten en el tamaño del panel al reubicarlo.
func _clear(new_page: String) -> void:
	page = new_page
	_scroll = null
	for c in content.get_children():
		if c is CanvasItem:
			(c as CanvasItem).visible = false
		c.queue_free()

func _add_scroll(child: Control, fill: bool = false) -> ScrollContainer:
	_scroll = UiKit.scroll(child)
	_scroll.size_flags_vertical = Control.SIZE_FILL
	if fill:
		_scroll.set_meta("fill", true)
	content.add_child(_scroll)
	return _scroll

func _main() -> void:
	_clear("main")
	var t := UiKit.label("ÚLTIMA BRASA", 40, UiKit.ACCENT)
	content.add_child(t)
	content.add_child(UiKit.label("Sesenta días de invierno eterno.", 16, UiKit.TXT_DIM))
	if _notice != "":
		content.add_child(UiKit.label(_notice, 15, UiKit.BAD, true))
		_notice = ""
	# Los botones van en un área desplazable: con la interfaz al 150 % en un celular
	# no entran en la pantalla y si no, los de abajo quedarían inalcanzables.
	var btns := UiKit.vbox(10)
	var saves := Session.list_saves()
	var last := Session.latest_save()
	if not last.is_empty():
		var slot: String = last["slot"]
		btns.add_child(UiKit.button("Continuar (día %d)" % int(last["day"]), "x1", func(): continue_game.emit(slot)))
	btns.add_child(UiKit.button("Nueva partida", "ok", func(): new_game.emit()))
	var more := []
	if saves.size() > 0:
		more.append(UiKit.button("Cargar partida", "reporte", func(): _load()))
	more.append(UiKit.button("Ajustes", "menu", func(): _settings()))
	more.append(UiKit.button("Benchmark", "reloj", func(): benchmark.emit()))
	more.append(UiKit.button("Créditos", "estrella", func(): _credits()))
	if not Settings.is_mobile():
		more.append(UiKit.button("Salir", "cerrar", func(): get_tree().quit()))
	if UiKit.mobile:
		# En 960x540 los botones de 62 u no entran uno debajo del otro: van de a dos.
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 10)
		for b in more:
			(b as Button).size_flags_horizontal = Control.SIZE_EXPAND_FILL
			grid.add_child(b)
		btns.add_child(grid)
	else:
		for b in more:
			btns.add_child(b)
	_add_scroll(btns)
	content.add_child(UiKit.label("v%s · Dificultad media" % Session.GAME_VERSION, 12, UiKit.TXT_DIM))
	_queue_place()

func _load() -> void:
	_clear("load")
	content.add_child(UiKit.title("Cargar partida"))
	var list := UiKit.vbox(6)
	for s in Session.list_saves():
		var slot: String = s["slot"]
		list.add_child(save_button(s, func(): continue_game.emit(slot)))
	_add_scroll(list)
	content.add_child(UiKit.button("Volver", "cerrar", func(): _main()))
	_queue_place()

func _settings() -> void:
	_clear("settings")
	content.add_child(UiKit.title("Ajustes"))
	var sp := SettingsPanel.new()
	sp.sim = null
	sp.world_ref = world
	sp.bench_cb = func(): benchmark.emit()
	# Oculto dentro del panel: los botones usan sus métodos y se libera junto con la página.
	sp.visible = false
	content.add_child(sp)
	var holder := UiKit.vbox(6)
	sp.body = holder
	sp._rebuild()
	_add_scroll(holder)
	content.add_child(UiKit.button("Volver", "cerrar", func(): _main()))
	_queue_place()

func _credits() -> void:
	_clear("credits")
	content.add_child(UiKit.title("Créditos"))
	var txt := "Código fuente, diseño, textos, modelos, íconos, sonido y música: hechos para este proyecto y publicados como CC0 1.0 (dominio público). El texto legal está en el archivo LICENSE del repositorio.\n" \
		+ "Motor: Godot Engine, licencia MIT.\n© 2014-presente, colaboradores de Godot Engine.\n© 2007-2014, Juan Linietsky, Ariel Manzur.\n" \
		+ "Tipografía: Open Sans, la fuente que trae Godot (licencia OFL 1.1).\n" \
		+ "El motor incluye componentes de terceros (FreeType, HarfBuzz, ICU, mbedTLS y otros) con sus propias licencias libres: están en «Licencias».\n" \
		+ "El APK de Android incluye además AndroidX, Kotlin y kotlinx.coroutines (Apache-2.0) y libc++ de LLVM; también están en «Licencias»."
	_add_scroll(UiKit.label(txt, 15, UiKit.TXT, true))
	content.add_child(UiKit.button("Licencias", "reporte", func(): _licenses()))
	content.add_child(UiKit.button("Volver", "cerrar", func(): _main()))
	_queue_place()

## Avisos de copyright y licencias del motor y de sus componentes de terceros
## (la licencia MIT de Godot exige incluirlos en el juego distribuido).
func _licenses() -> void:
	_clear("licenses")
	content.add_child(UiKit.title("Licencias"))
	var v := UiKit.vbox(8)
	v.add_child(UiKit.label("Godot Engine", 17, UiKit.ACCENT))
	v.add_child(UiKit.label(_reflow(Engine.get_license_text()), 13, UiKit.TXT, true))
	v.add_child(UiKit.sep())
	v.add_child(UiKit.label("Componentes del APK de Android", 17, UiKit.ACCENT))
	v.add_child(UiKit.label("Solo en la versión para Android (vienen con la plantilla de exportación de Godot).\nAndroidX (core, fragment, lifecycle, activity y relacionados): © The Android Open Source Project, licencia Apache-2.0.\nKotlin (biblioteca estándar) y kotlinx.coroutines: © JetBrains s.r.o. y colaboradores, licencia Apache-2.0.\nlibc++_shared.so (biblioteca C++ de LLVM): © colaboradores de LLVM, licencia Apache-2.0 con excepciones LLVM.\nEl texto de la Apache-2.0 está más abajo, en «Textos de las licencias».", 13, UiKit.TXT, true))
	v.add_child(UiKit.sep())
	v.add_child(UiKit.label("Componentes de terceros incluidos en el motor", 17, UiKit.ACCENT))
	v.add_child(UiKit.label(_components_text(), 13, UiKit.TXT_DIM, true))
	v.add_child(UiKit.sep())
	v.add_child(UiKit.label("Textos de las licencias", 17, UiKit.ACCENT))
	var info: Dictionary = Engine.get_license_info()
	var names: Array = info.keys()
	names.sort()
	for k in names:
		var lic: String = k
		var box := UiKit.vbox(4)
		var b := UiKit.button("Ver licencia %s" % lic, "", Callable())
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(func():
			# El texto se crea recién al abrirlo: son unos 77 000 caracteres en total.
			if box.get_child_count() > 1:
				var old_l := box.get_child(1) as Label
				old_l.visible = false
				box.remove_child(old_l)
				old_l.queue_free()
				b.text = "Ver licencia %s" % lic
			else:
				box.add_child(UiKit.label(_reflow(str(info[lic])), 12, UiKit.TXT, true))
				b.text = "Ocultar licencia %s" % lic)
		box.add_child(b)
		v.add_child(box)
	_add_scroll(v, true)
	content.add_child(UiKit.button("Volver", "cerrar", func(): _credits()))
	_queue_place()

## Los textos de licencia vienen cortados a 80 columnas: se unen las líneas de cada
## párrafo para que el ajuste de línea del panel no deje renglones partidos.
static func _reflow(text: String) -> String:
	var paras := []
	for para in text.replace("\r", "").split("\n\n"):
		var lines := []
		for ln in para.split("\n"):
			var t := ln.strip_edges()
			if t != "":
				lines.append(t)
		paras.append(" ".join(lines))
	return "\n\n".join(paras)

## Lista compacta de Engine.get_copyright_info(): componente, titulares y licencia.
func _components_text() -> String:
	var lines := []
	for e in Engine.get_copyright_info():
		var holders := []
		var lics := []
		for part in e.get("parts", []):
			for c in part.get("copyright", []):
				if str(c) not in holders:
					holders.append(str(c))
			var li := str(part.get("license", ""))
			if li != "" and li not in lics:
				lics.append(li)
		var line := "• %s — %s." % [str(e.get("name", "")), ", ".join(lics)]
		if holders.size() > 0:
			line += " © " + "; ".join(holders).trim_suffix(".") + "."
		lines.append(line)
	return "\n".join(lines)
