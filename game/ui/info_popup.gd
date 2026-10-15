class_name InfoPopup
extends PanelContainer
## Ventanita de detalle: aparece al pasar el mouse (PC) o al tocar un control (táctil).
## Con emulate_mouse_from_touch cada toque llega también como clic de mouse emulado,
## que dispara mouse_entered en el mismo cuadro: por eso el hover se toma solo de
## movimientos de mouse reales y el toque se maneja únicamente con ScreenTouch.
var lbl: RichTextLabel
var _owner_ctl: Control = null
var _text_fn: Callable
var _acc := 0.0
var _shown_ms := 0

const TOUCH_HIDE_MS := 6000 # en táctil se cierra solo a los 6 s

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 100
	lbl = RichTextLabel.new()
	lbl.bbcode_enabled = true
	lbl.fit_content = true
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.custom_minimum_size = Vector2(300 if not UiKit.mobile else 380, 0)
	lbl.add_theme_font_size_override("normal_font_size", UiKit.fs(15))
	lbl.add_theme_font_size_override("bold_font_size", UiKit.fs(16))
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lbl)
	add_theme_stylebox_override("panel", UiKit._sb(UiKit.BG2, 6, UiKit.ACCENT_D, 1, 10))
	visible = false

func show_for(ctl: Control, text: String, text_fn: Callable = Callable()) -> void:
	_owner_ctl = ctl
	_text_fn = text_fn
	_shown_ms = Time.get_ticks_msec()
	lbl.text = text
	visible = true
	reset_size()
	await get_tree().process_frame
	if not is_instance_valid(ctl) or _owner_ctl != ctl:
		return
	_place(ctl)

func _place(ctl: Control) -> void:
	var r := ctl.get_global_rect()
	var vp := get_viewport_rect().size
	var p := Vector2(r.position.x, r.end.y + 6)
	if p.y + size.y > vp.y:
		p.y = r.position.y - size.y - 6
	p.x = clampf(p.x, 4, vp.x - size.x - 4)
	global_position = p

func hide_for(ctl: Control) -> void:
	if ctl == _owner_ctl:
		visible = false
		_owner_ctl = null
		_text_fn = Callable()

## Mientras está abierto, refresca el texto (los valores cambian con la simulación).
func _process(delta: float) -> void:
	if not visible or _owner_ctl == null:
		return
	if not is_instance_valid(_owner_ctl) or not _owner_ctl.is_visible_in_tree():
		visible = false
		_owner_ctl = null
		return
	if UiKit.mobile and Time.get_ticks_msec() - _shown_ms > TOUCH_HIDE_MS:
		hide_for(_owner_ctl)
		return
	_acc += delta
	if _acc >= 0.5 and _text_fn.is_valid():
		_acc = 0.0
		var t: String = _text_fn.call()
		if t != lbl.text:
			lbl.text = t
			reset_size()
			_place(_owner_ctl)

## Conecta un control para que muestre `text_fn.call()` al pasar el mouse o al tocarlo.
func attach(ctl: Control, text_fn: Callable) -> void:
	ctl.mouse_filter = Control.MOUSE_FILTER_STOP
	# Al tocar en otro lado el mouse emulado sale del control: eso también lo cierra.
	ctl.mouse_exited.connect(func(): hide_for(ctl))
	ctl.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseMotion and not UiKit.is_emulated(ev):
			# Hover con mouse real.
			if not (visible and _owner_ctl == ctl):
				show_for(ctl, text_fn.call(), text_fn)
		elif ev is InputEventScreenTouch and ev.pressed:
			if visible and _owner_ctl == ctl:
				hide_for(ctl)
			else:
				show_for(ctl, text_fn.call(), text_fn))
