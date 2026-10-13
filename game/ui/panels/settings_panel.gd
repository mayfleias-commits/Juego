class_name SettingsPanel
extends SidePanel
## Opciones gráficas, de audio e interfaz.

func _title() -> String:
	return "Ajustes"

func _build() -> void:
	_rebuild()

func _rebuild() -> void:
	UiKit.clear(body)
	body.add_child(UiKit.label("Calidad gráfica", 17, UiKit.ACCENT))
	var ph := HFlowContainer.new()
	for p in Settings.PRESETS:
		var pid: String = p
		var b := UiKit.button(Settings.PRESET_NAMES[p], "", func():
			Settings.set_preset(pid)
			_apply_world()
			_rebuild())
		b.toggle_mode = true
		b.button_pressed = Settings.preset == p
		ph.add_child(b)
	body.add_child(ph)
	body.add_child(_slider("Escala de render", Settings.render_scale * 100.0, 50, 100, 5, func(v):
		Settings.render_scale = v / 100.0
		Settings.apply()
		Settings.save_cfg(), "%d%%"))
	var fh := UiKit.hbox(6)
	fh.add_child(UiKit.label("Límite de FPS:", 15, UiKit.TXT_DIM))
	for f in [30, 45, 60, 0]:
		var fv: int = f
		var b2 := UiKit.button(str(f) if f > 0 else "Sin límite", "", func():
			Settings.fps_limit = fv
			Settings.apply()
			Settings.save_cfg()
			_rebuild())
		b2.toggle_mode = true
		b2.button_pressed = Settings.fps_limit == f
		fh.add_child(b2)
	body.add_child(fh)
	body.add_child(_toggle("Sombras", Settings.shadows, func(v):
		Settings.shadows = v
		Settings.save_cfg()
		_apply_world()))
	body.add_child(_toggle("Efectos (nieve, humo, escarcha)", Settings.effects, func(v):
		Settings.effects = v
		Settings.save_cfg()
		_apply_world()))
	body.add_child(_toggle("Contador de FPS y memoria", Settings.show_fps, func(v):
		Settings.show_fps = v
		Settings.save_cfg()))
	body.add_child(UiKit.sep())
	body.add_child(UiKit.label("Audio", 17, UiKit.ACCENT))
	body.add_child(_slider("Volumen general", Settings.vol_master, 0, 100, 5, func(v):
		Settings.vol_master = int(v)
		Settings.apply()
		Settings.save_cfg(), "%d"))
	body.add_child(_slider("Música", Settings.vol_music, 0, 100, 5, func(v):
		Settings.vol_music = int(v)
		Settings.apply()
		Settings.save_cfg(), "%d"))
	body.add_child(_slider("Efectos de sonido", Settings.vol_sfx, 0, 100, 5, func(v):
		Settings.vol_sfx = int(v)
		Settings.apply()
		Settings.save_cfg(), "%d"))
	body.add_child(UiKit.sep())
	body.add_child(_slider("Tamaño de la interfaz", Settings.ui_scale, 75, 150, 5, func(v):
		Settings.ui_scale = int(v)
		Settings.apply()
		Settings.save_cfg(), "%d%%"))
	body.add_child(_toggle("Mostrar el tutorial", Settings.tutorial, func(v):
		Settings.tutorial = v
		Settings.save_cfg()))
	body.add_child(UiKit.button("Ejecutar benchmark (20 s)", "reloj", func():
		if hud and hud.screen:
			hud.screen.run_benchmark()))

func _apply_world() -> void:
	Settings.apply()
	if hud and hud.screen and hud.screen.world:
		hud.screen.world.apply_settings()

func _toggle(text: String, val: bool, cb: Callable) -> CheckButton:
	var c := CheckButton.new()
	c.text = text
	c.button_pressed = val
	c.custom_minimum_size = Vector2(0, UiKit.btn_h())
	c.focus_mode = Control.FOCUS_NONE
	c.toggled.connect(cb)
	return c

func _slider(text: String, val: float, lo: float, hi: float, step: float, cb: Callable, fmt: String) -> VBoxContainer:
	var v := UiKit.vbox(2)
	var l := UiKit.label("%s: %s" % [text, fmt % int(val)], 15)
	v.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = val
	s.custom_minimum_size = Vector2(260, UiKit.btn_h() - 8)
	s.value_changed.connect(func(x):
		l.text = "%s: %s" % [text, fmt % int(x)]
		cb.call(x))
	v.add_child(s)
	return v
