class_name MenuPanel
extends SidePanel
## Menú de partida: guardar, cargar, ajustes, ayuda y salir.

func _title() -> String:
	return "Menú"

func _build() -> void:
	body.add_child(UiKit.button("Guardar partida", "ok", func():
		if Session.save_game("manual"):
			hud.toast("Partida guardada.")))
	body.add_child(UiKit.button("Cargar partida guardada", "", func(): _load_list()))
	body.add_child(UiKit.button("Ajustes", "menu", func(): hud.open_panel("settings")))
	body.add_child(UiKit.button("Ayuda / tutorial", "pedido", func(): hud.screen.show_help()))
	body.add_child(UiKit.button("Salir al menú principal", "cerrar", func():
		hud.push_modal(ConfirmDialog.make("¿Salir al menú?", "Se guardará automáticamente.", func():
			Session.save_game("auto")
			hud.screen.exit_to_menu()))))
	body.add_child(UiKit.sep())
	body.add_child(UiKit.label("Atajos (PC): Espacio pausa · 1/2/3 velocidad · WASD/flechas mover · Q/E rotar · rueda o R/F zoom · B construir · G generador · L leyes · I investigar · M mapa · H capas · F3 rendimiento · Esc cancelar", 13, UiKit.TXT_DIM, true))

func _load_list() -> void:
	UiKit.clear(body)
	for s in Session.list_saves():
		var slot: String = s["slot"]
		body.add_child(UiKit.button("%s · día %d · %d personas · %s" % [slot, int(s["day"]), int(s["pop"]), str(s["date"]).replace("T", " ")], "", func():
			if Session.load_game(slot):
				hud.screen.reload_from_session()))
	body.add_child(UiKit.button("Volver", "cerrar", func(): hud.open_panel("menu")))
