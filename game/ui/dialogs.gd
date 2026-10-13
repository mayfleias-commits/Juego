class_name ConfirmDialog
extends PanelContainer
## Diálogo de confirmación genérico.

static func make(title: String, text: String, on_ok: Callable, ok_text: String = "Aceptar") -> ConfirmDialog:
	var d := ConfirmDialog.new()
	d.custom_minimum_size = Vector2(420 if not UiKit.mobile else 600, 0)
	var v := UiKit.vbox(10)
	d.add_child(v)
	v.add_child(UiKit.title(title))
	v.add_child(UiKit.label(text, 16, UiKit.TXT, true))
	var h := UiKit.hbox(10)
	h.alignment = BoxContainer.ALIGNMENT_END
	h.add_child(UiKit.button("Cancelar", "cerrar", func(): d._close()))
	h.add_child(UiKit.button(ok_text, "ok", func():
		on_ok.call()
		d._close()))
	v.add_child(h)
	return d

func _close() -> void:
	var hud := _find_hud()
	if hud:
		hud.close_modal()

func _find_hud() -> Hud:
	var n: Node = self
	while n:
		if n is Hud:
			return n
		n = n.get_parent()
	return null
