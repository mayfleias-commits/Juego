class_name DataDB
## Carga y normaliza todo el contenido del juego desde res://data/*.json.
## Regla: los datos usan solo enteros. Los valores con sufijo "_m" están en
## milésimas (punto fijo, escala 1000). Cualquier número no entero es un error.

static var _cache: Dictionary = {}

const FILES := ["balance", "buildings", "research", "laws", "events", "requests", "locations", "climate", "texts"]

static func get_db(path: String = "res://data") -> Dictionary:
	if _cache.has(path):
		return _cache[path]
	var db := {}
	for f in FILES:
		var p := "%s/%s.json" % [path, f]
		var txt := FileAccess.get_file_as_string(p)
		if txt == "":
			push_error("DataDB: no se pudo leer " + p)
			db[f] = {}
			continue
		var parsed = JSON.parse_string(txt)
		if parsed == null:
			push_error("DataDB: JSON inválido en " + p)
			db[f] = {}
			continue
		db[f] = _norm(parsed, p)
	_index(db)
	_cache[path] = db
	return db

static func _norm(v, ctx: String):
	match typeof(v):
		TYPE_FLOAT:
			var i := int(v)
			if float(i) != v:
				push_error("DataDB: número no entero %s en %s" % [str(v), ctx])
			return i
		TYPE_ARRAY:
			var out := []
			for x in v:
				out.append(_norm(x, ctx))
			return out
		TYPE_DICTIONARY:
			var d := {}
			for k in v:
				d[k] = _norm(v[k], ctx)
			return d
	return v

## Convierte listas con "id" en diccionarios id -> def (manteniendo el orden).
static func _index(db: Dictionary) -> void:
	for f in ["buildings", "research", "laws", "events", "requests", "locations"]:
		var raw = db.get(f, {})
		if raw is Dictionary and raw.has("list"):
			var by := {}
			for item in raw["list"]:
				by[item["id"]] = item
			db[f] = by
