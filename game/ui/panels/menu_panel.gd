class_name MenuPanel
extends SidePanel
## Menú de partida: guardar, cargar, ajustes, ayuda y salir.

func _title() -> String:
	return "Menú"

func _build() -> void:
	body.add_child(UiKit.button("Guardar partida", "ok", func():
		if Session.save_game("manual"):
			hud.toast("Partida guardada.")
		else:
			hud.toast("No se pudo guardar: %s" % Session.last_error, UiKit.BAD)))
	body.add_child(UiKit.button("Cargar partida guardada", "", func(): _load_list()))
	body.add_child(UiKit.button("Ajustes", "menu", func(): hud.open_panel("settings")))
	body.add_child(UiKit.button("Ayuda / tutorial", "pedido", func():
		hud.close_panel()
		hud.screen.show_help()))
	body.add_child(UiKit.button("Salir al menú principal", "cerrar", func():
		hud.push_modal(ConfirmDialog.make("¿Salir al menú?", "Se guardará automáticamente.", func():
			if not Session.save_on_exit():
				hud.toast("No se pudo guardar: %s" % Session.last_error, UiKit.BAD)
				return
			hud.screen.exit_to_menu()))))
	body.add_child(UiKit.sep())
	body.add_child(UiKit.label("Atajos (PC): Espacio pausa · 1/2/3 velocidad · WASD/flechas mover · Q/E rotar · rueda o R/F zoom · B construir · G generador · L leyes · I investigar · M mapa · H capas · F3 rendimiento · F5 guardar · Esc cancelar · pasar el mouse sobre un edificio muestra su detalle y el clic abre su panel", 13, UiKit.TXT_DIM, true))

func _load_list() -> void:
	UiKit.clear(body)
	body.add_child(UiKit.label("Cargar partida", 17, UiKit.ACCENT))
	var saves := Session.list_saves()
	if saves.is_empty():
		body.add_child(UiKit.label("No hay partidas guardadas.", 15, UiKit.TXT_DIM, true))
	for s in saves:
		var slot: String = s["slot"]
		body.add_child(MainMenu.save_button(s, func():
			if Session.load_game(slot):
				hud.screen.reload_from_session()
			else:
				hud.toast("No se pudo cargar: %s" % Session.last_error, UiKit.BAD)))
	body.add_child(UiKit.button("Volver", "cerrar", func(): hud.open_panel("menu")))
