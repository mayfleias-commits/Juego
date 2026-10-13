class_name SimBase
extends RefCounted
## Capa base de la simulación: estado, datos, azar, recursos, modificadores.
## Todo el estado persistente vive en `st` (Dictionary de enteros/strings/arrays)
## para que guardar, cargar y comparar (hash) sea trivial y determinista.

const SAVE_VERSION := 1
const RES := ["carbon", "madera", "metal", "nucleos", "crudo", "raciones"]
const CLASSES := ["obreros", "ingenieros", "ninos"]
const LEVELS := 5 # 0 Congelante, 1 Muy frío, 2 Frío, 3 Fresco, 4 Confortable
const HOURS_PER_DAY := 24

var db: Dictionary
var B: Dictionary # balance.json
var st: Dictionary = {}
var rng: int = 1

# --- Derivados (se reconstruyen tras cargar) ---
var mods: Dictionary = {}
var caps: Dictionary = {}
var grid: PackedInt32Array = PackedInt32Array()
var notes: Array = [] # notificaciones del último paso (no persistentes)

func _init(data_path: String = "res://data") -> void:
	db = DataDB.get_db(data_path)
	B = db["balance"]

# ---------------------------------------------------------------- azar
func rnd_u32() -> int:
	rng = SimRng.step(rng)
	return rng

func rnd(n: int) -> int:
	if n <= 1:
		return 0
	return rnd_u32() % n

## true con probabilidad p/100000
func chance_pcm(p: int) -> bool:
	if p <= 0:
		return false
	if p >= 100000:
		return true
	return rnd(100000) < p

## Redondeo estocástico de una cantidad esperada en FP -> entero.
func stoch(expected_fp: int) -> int:
	if expected_fp <= 0:
		return 0
	var whole := expected_fp / FX.ONE
	var frac := expected_fp % FX.ONE
	if frac > 0 and rnd(FX.ONE) < frac:
		whole += 1
	return whole

# ---------------------------------------------------------------- tiempo
func tick() -> int:
	return st["tick"]

func day() -> int:
	return st["day"]

func hour() -> int:
	return st["hour"]

# ---------------------------------------------------------------- notas
func note(kind: String, text: String, extra: Dictionary = {}) -> void:
	var n := {"tick": st.get("tick", 0), "kind": kind, "text": text}
	n.merge(extra)
	notes.append(n)
	var log: Array = st["log"]
	log.append(n)
	if log.size() > 200:
		log.remove_at(0)

# ---------------------------------------------------------------- recursos
func res(r: String) -> int:
	return st["res"][r]

func cap(r: String) -> int:
	return caps.get(r, 0)

## Agrega hasta el límite de almacenamiento. Devuelve lo realmente guardado.
func add_res(r: String, amount: int, src: String = "") -> int:
	if amount <= 0:
		return 0
	var cur: int = st["res"][r]
	var room: int = maxi(0, cap(r) - cur)
	var stored := mini(amount, room)
	st["res"][r] = cur + stored
	st["obtained"][r] += stored
	st["day_acc"]["prod"][r] = st["day_acc"]["prod"].get(r, 0) + stored
	if amount > stored:
		st["wasted"][r] += amount - stored
	return stored

## Quita si alcanza (todo o nada). Devuelve true si pudo.
func take_res(r: String, amount: int) -> bool:
	if amount < 0:
		return false
	var cur: int = st["res"][r]
	if cur < amount:
		return false
	st["res"][r] = cur - amount
	st["day_acc"]["cons"][r] = st["day_acc"]["cons"].get(r, 0) + amount
	return true

## Quita lo que haya hasta `amount`. Devuelve lo quitado.
func take_upto(r: String, amount: int) -> int:
	if amount <= 0:
		return 0
	var cur: int = st["res"][r]
	var t := mini(cur, amount)
	st["res"][r] = cur - t
	st["day_acc"]["cons"][r] = st["day_acc"]["cons"].get(r, 0) + t
	return t

## Costo en unidades enteras {madera: 20, ...} -> FP
func cost_fp(cost: Dictionary) -> Dictionary:
	var out := {}
	for r in cost:
		out[r] = int(cost[r]) * FX.ONE
	return out

func can_afford(cost: Dictionary) -> bool:
	for r in cost:
		if st["res"].get(r, 0) < int(cost[r]) * FX.ONE:
			return false
	return true

func pay(cost: Dictionary) -> bool:
	if not can_afford(cost):
		return false
	for r in cost:
		take_res(r, int(cost[r]) * FX.ONE)
	return true

# ---------------------------------------------------------------- modificadores
func mod(key: String) -> int:
	return mods.get(key, 0)

func flag(name: String) -> int:
	return st["flags"].get(name, 0)

func set_flag(name: String, v: int = 1) -> void:
	st["flags"][name] = v

func rebuild_mods() -> void:
	mods = {}
	for lid in st["laws"]:
		_apply_mod_list(db["laws"][lid].get("effects", []))
	for rid in st["research"]["done"]:
		_apply_mod_list(db["research"][rid].get("effects", []))
	for m in st["perm_mods"]:
		mods[m[0]] = mods.get(m[0], 0) + int(m[1])

func _apply_mod_list(effects: Array) -> void:
	for e in effects:
		if e.get("k", "") == "mod":
			mods[e["key"]] = mods.get(e["key"], 0) + int(e["v"])

# ---------------------------------------------------------------- población
func pop_class(c: String) -> Dictionary:
	return st["pop"][c]

func healthy(c: String) -> int:
	return st["pop"][c]["h"]

func total_pop() -> int:
	var t := 0
	for c in CLASSES:
		var p: Dictionary = st["pop"][c]
		t += p["h"] + p["sl"] + p["sg"] + st["away"][c]
	return t

func total_sick() -> int:
	var t := 0
	for c in CLASSES:
		t += st["pop"][c]["sl"] + st["pop"][c]["sg"]
	return t

func total_grave() -> int:
	var t := 0
	for c in CLASSES:
		t += st["pop"][c]["sg"]
	return t

## Personas presentes en la ciudad (excluye exploradores fuera).
func present_pop() -> int:
	var t := 0
	for c in CLASSES:
		var p: Dictionary = st["pop"][c]
		t += p["h"] + p["sl"] + p["sg"]
	return t

# ---------------------------------------------------------------- esperanza
func add_hope(v: int, cause: String) -> void:
	if v == 0:
		return
	st["hope"] = FX.clampi(st["hope"] + v, 0, 100 * FX.ONE)
	var c: Dictionary = st["day_acc"]["hope_causes"]
	c[cause] = c.get(cause, 0) + v

func add_disc(v: int, cause: String) -> void:
	if v == 0:
		return
	st["disc"] = FX.clampi(st["disc"] + v, 0, 100 * FX.ONE)
	var c: Dictionary = st["day_acc"]["disc_causes"]
	c[cause] = c.get(cause, 0) + v

# ---------------------------------------------------------------- virtuales
## Implementados en capas superiores (SimSociety / SimWorld).
func apply_effects(_list: Array, _ctx: Dictionary = {}) -> void:
	pass

func reveal_location(_id: String) -> void:
	pass

# ---------------------------------------------------------------- utilidades
func bdef(type: String) -> Dictionary:
	return db["buildings"][type]

func text(key: String) -> String:
	return db["texts"].get(key, key)
