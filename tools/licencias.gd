extends SceneTree
## Escribe LICENCIAS.txt: la licencia del juego, la de Godot Engine y los avisos de copyright
## y textos de licencia de los componentes de terceros que trae el motor (FreeType, HarfBuzz,
## ICU, mbedTLS, Open Sans, etc.). La licencia MIT de Godot exige que ese aviso viaje con cada
## copia del juego: tools/export.sh lo mete en el .zip de Windows junto al .exe (en Android
## se ve en el juego, en Créditos → Licencias).
## Uso: godot --headless --path . --script res://tools/licencias.gd -- <ruta de salida>
## Sin ruta escribe build/windows/LICENCIAS.txt. Una ruta relativa es relativa a la raíz del proyecto.

const SEP := "================================================================================"

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out := str(args[0]) if args.size() > 0 else "build/windows/LICENCIAS.txt"
	if not out.is_absolute_path():
		out = ProjectSettings.globalize_path("res://").path_join(out)
	quit(0 if _write(out) else 1)

func _write(path: String) -> bool:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		printerr("No se pudo crear %s (%s)" % [path, error_string(FileAccess.get_open_error())])
		return false
	# BOM y finales de línea de Windows: el archivo se abre con el Bloc de notas.
	f.store_buffer(PackedByteArray([0xEF, 0xBB, 0xBF]))
	f.store_string(_text().replace("\r\n", "\n").replace("\n", "\r\n"))
	var ok := f.get_error() == OK
	f.close()
	if ok:
		print("LICENCIAS escrito en ", path)
	return ok

func _text() -> String:
	var version := str(ProjectSettings.get_setting("application/config/version", ""))
	var gv: Dictionary = Engine.get_version_info()
	var L: PackedStringArray = []
	L.append("Última Brasa %s — licencias y avisos de terceros" % version)
	L.append(SEP)
	L.append("")
	L.append("CONTENIDO DEL JUEGO")
	L.append("El diseño, la programación, los textos, los modelos 3D (generados por código), los")
	L.append("shaders, los íconos, el sonido y la música se hicieron para este proyecto y se publican")
	L.append("como CC0 1.0 (dominio público): https://creativecommons.org/publicdomain/zero/1.0/")
	L.append("No se usaron assets de terceros. Detalle en CREDITOS.md, en el repositorio del juego.")
	L.append("")
	L.append("MOTOR: GODOT ENGINE %s" % str(gv.get("string", "")))
	L.append("Este juego usa Godot Engine, disponible bajo la siguiente licencia:")
	L.append("")
	L.append(Engine.get_license_text().strip_edges())
	L.append("")
	L.append(SEP)
	L.append("COMPONENTES DE TERCEROS INCLUIDOS EN EL MOTOR")
	L.append("(componente, titulares del copyright y licencia; los textos completos van al final)")
	L.append(SEP)
	for e in Engine.get_copyright_info():
		var name := str(e.get("name", ""))
		if name == "":
			continue
		L.append("")
		L.append(name)
		for part in e.get("parts", []):
			for c in part.get("copyright", []):
				L.append("  © " + str(c))
			var lic := str(part.get("license", ""))
			if lic != "":
				L.append("  Licencia: " + lic)
	L.append("")
	L.append(SEP)
	L.append("TEXTOS DE LAS LICENCIAS")
	L.append(SEP)
	var info: Dictionary = Engine.get_license_info()
	var keys := info.keys()
	keys.sort()
	for k in keys:
		L.append("")
		L.append("----- %s -----" % str(k))
		L.append("")
		L.append(str(info[k]).strip_edges())
	L.append("")
	return "\n".join(L)
