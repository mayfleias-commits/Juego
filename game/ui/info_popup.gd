class_name InfoPopup
extends PanelContainer
## Ventanita de detalle: aparece al pasar el mouse o al tocar un control.
var lbl: RichTextLabel
var _owner_ctl: Control = null

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

func show_for(ctl: Control, text: String) -> void:
	_owner_ctl = ctl
	lbl.text = text
	visible = true
	reset_size()
	await get_tree().process_frame
	if not is_instance_valid(ctl):
		return
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

## Conecta un control para que muestre `text_fn.call()` al pasar el mouse o al tocarlo.
func attach(ctl: Control, text_fn: Callable) -> void:
	ctl.mouse_filter = Control.MOUSE_FILTER_STOP
	ctl.mouse_entered.connect(func(): show_for(ctl, text_fn.call()))
	ctl.mouse_exited.connect(func(): hide_for(ctl))
	ctl.gui_input.connect(func(ev):
		if ev is InputEventScreenTouch and ev.pressed:
			if visible and _owner_ctl == ctl:
				hide_for(ctl)
			else:
				show_for(ctl, text_fn.call()))
