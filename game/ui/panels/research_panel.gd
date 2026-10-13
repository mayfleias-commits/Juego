class_name ResearchPanel
extends SidePanel
## Árbol de investigación: 4 ramas x 4 niveles.

const BRANCHES := [["calor", "Calor"], ["recursos", "Recursos"], ["comida_salud", "Comida y salud"], ["exploracion", "Exploración y autómatas"]]
var branch := "calor"
var _sig := ""
var prog_bar: ProgressBar
var prog_lbl: Label

func _title() -> String:
	return "Investigación"

func _build() -> void:
	_rebuild()

func refresh() -> void:
	var R: Dictionary = sim.st["research"]
	var sig := "%s|%s|%d|%d|%d" % [branch, R["cur"], (R["done"] as Array).size(), sim.res("madera") / 10000, sim.res("metal") / 10000]
	if sig != _sig:
		_sig = sig
		_rebuild()
	elif prog_bar and R["cur"] != "":
		var need: int = int(sim.db["research"][R["cur"]]["rp"]) * 1000
		prog_bar.value = 100.0 * float(R["progs"].get(R["cur"], 0)) / need

func _rebuild() -> void:
	UiKit.clear(body)
	prog_bar = null
	var R: Dictionary = sim.st["research"]
	var shops := 0
	for b in sim.st["buildings"]:
		if b["type"] == "taller" and int(b["state"]) == 1:
			shops += 1
	if shops == 0:
		body.add_child(UiKit.label("Construí un Taller de ingenios y asigná ingenieros para investigar.", 15, UiKit.BAD, true))
	if R["cur"] != "":
		var d: Dictionary = sim.db["research"][R["cur"]]
		body.add_child(UiKit.label("Investigando: " + d["name"], 16, UiKit.ACCENT))
		prog_bar = UiKit.bar(100.0 * float(R["progs"].get(R["cur"], 0)) / (int(d["rp"]) * 1000), UiKit.ACCENT, 320, 12)
		body.add_child(prog_bar)
		body.add_child(UiKit.button("Detener", "", func(): Session.cmd({"c": "research", "id": ""}); _sig = ""))
	var th := HFlowContainer.new()
	for br in BRANCHES:
		var id: String = br[0]
		var b := UiKit.button(br[1], "", func(): branch = id; _sig = ""; refresh())
		b.toggle_mode = true
		b.button_pressed = branch == id
		th.add_child(b)
	body.add_child(th)
	for tier in range(1, 5):
		body.add_child(UiKit.label("Nivel %d" % tier, 16, UiKit.TXT_DIM))
		for id in sim.db["research"]:
			var d: Dictionary = sim.db["research"][id]
			if d["branch"] != branch or int(d["tier"]) != tier:
				continue
			body.add_child(_node(id, d))

func _node(id: String, d: Dictionary) -> Control:
	var R: Dictionary = sim.st["research"]
	var done: bool = id in R["done"]
	var cur: bool = R["cur"] == id
	var why := sim.research_check(id)
	var p := PanelContainer.new()
	var col := Color(0.12, 0.2, 0.14, 0.95) if done else (Color(0.25, 0.18, 0.08, 0.95) if cur else UiKit.BG2)
	p.add_theme_stylebox_override("panel", UiKit._sb(col, 6, Color(0.25, 0.3, 0.38), 1, 8))
	var v := UiKit.vbox(2)
	p.add_child(v)
	var h := UiKit.hbox(6)
	var nl := UiKit.label(d["name"] + (" ✔" if done else ""), 16, UiKit.GOOD if done else UiKit.TXT)
	nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(nl)
	if not done and not cur:
		var b := UiKit.button("Investigar", "investigacion", func():
			var r := Session.cmd({"c": "research", "id": id})
			if r != "":
				hud.toast(r, UiKit.BAD)
			_sig = "")
		b.disabled = why != ""
		h.add_child(b)
	v.add_child(h)
	v.add_child(UiKit.label(d["desc"], 14, UiKit.TXT_DIM, true))
	var paid: bool = R["paid"].has(id)
	v.add_child(UiKit.label("%d puntos · %s%s" % [int(d["rp"]), Fmt.cost(d.get("cost", {})), " (pagado)" if paid else ""], 13, UiKit.TXT_DIM, true))
	if not done and why != "" and not cur:
		var req_names := []
		for r in d.get("req", []):
			req_names.append(sim.db["research"][r]["name"])
		v.add_child(UiKit.label(why + (": " + ", ".join(req_names) if why == "requiere investigación previa" else ""), 13, UiKit.BAD, true))
	return p
