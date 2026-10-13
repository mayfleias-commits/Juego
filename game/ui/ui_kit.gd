class_name UiKit
extends RefCounted
## Tema y utilidades de interfaz construidos por código.
## En celular la escala base es menor (960x540) para que los botones midan >= 48 dp.

const ACCENT := Color(0.95, 0.63, 0.28)
const ACCENT_D := Color(0.62, 0.38, 0.16)
const BG := Color(0.07, 0.09, 0.12, 0.88)
const BG2 := Color(0.12, 0.15, 0.2, 0.95)
const TXT := Color(0.92, 0.94, 0.97)
const TXT_DIM := Color(0.65, 0.7, 0.78)
const GOOD := Color(0.55, 0.9, 0.55)
const BAD := Color(1.0, 0.45, 0.4)
const COLD := Color(0.55, 0.78, 1.0)
const LEVEL_COLORS := [Color(0.35, 0.55, 1.0), Color(0.45, 0.8, 1.0), Color(0.85, 0.95, 1.0), Color(1.0, 0.85, 0.45), Color(1.0, 0.55, 0.25)]
const LEVEL_NAMES := ["Congelante", "Muy frío", "Frío", "Fresco", "Confortable"]
const RES_NAMES := {"carbon": "Carbón", "madera": "Madera", "metal": "Metal", "nucleos": "Núcleos de vapor", "crudo": "Comida cruda", "raciones": "Raciones"}

static var mobile := false
static var _icons := {}
static var theme: Theme

static func btn_h() -> int:
	return 58 if mobile else 40

static func fs(base: int) -> int:
	return base + (3 if mobile else 0)

static func icon(name: String) -> Texture2D:
	if _icons.has(name):
		return _icons[name]
	var path := "res://assets/icons/%s.svg" % name
	var tex: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_icons[name] = tex
	return tex

static func _sb(col: Color, radius: int = 6, border: Color = Color(0, 0, 0, 0), bw: int = 0, pad: int = 8) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = col
	s.set_corner_radius_all(radius)
	if bw > 0:
		s.border_color = border
		s.set_border_width_all(bw)
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad * 0.6
	s.content_margin_bottom = pad * 0.6
	return s

static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = fs(17)
	t.set_color("font_color", "Label", TXT)
	t.set_color("font_color", "Button", TXT)
	t.set_color("font_hover_color", "Button", Color(1, 1, 1))
	t.set_color("font_pressed_color", "Button", Color(0.1, 0.08, 0.05))
	t.set_color("font_disabled_color", "Button", Color(0.5, 0.52, 0.56))
	t.set_stylebox("normal", "Button", _sb(Color(0.18, 0.22, 0.29, 0.95), 6, Color(0.3, 0.36, 0.45), 1, 10))
	t.set_stylebox("hover", "Button", _sb(Color(0.26, 0.31, 0.4, 0.98), 6, ACCENT, 1, 10))
	t.set_stylebox("pressed", "Button", _sb(ACCENT, 6, ACCENT, 1, 10))
	t.set_stylebox("disabled", "Button", _sb(Color(0.13, 0.15, 0.19, 0.8), 6, Color(0.2, 0.22, 0.26), 1, 10))
	t.set_stylebox("focus", "Button", _sb(Color(0, 0, 0, 0), 6, ACCENT, 2, 10))
	t.set_stylebox("panel", "PanelContainer", _sb(BG, 8, Color(0.3, 0.36, 0.45, 0.8), 1, 10))
	t.set_stylebox("panel", "Panel", _sb(BG, 8))
	t.set_stylebox("panel", "TooltipPanel", _sb(BG2, 6, ACCENT_D, 1, 8))
	t.set_color("font_color", "TooltipLabel", TXT)
	t.set_stylebox("background", "ProgressBar", _sb(Color(0.1, 0.12, 0.16), 4, Color(0, 0, 0, 0), 0, 0))
	t.set_stylebox("fill", "ProgressBar", _sb(ACCENT, 4, Color(0, 0, 0, 0), 0, 0))
	t.set_stylebox("tab_selected", "TabBar", _sb(ACCENT_D, 6, ACCENT, 1, 12))
	t.set_stylebox("tab_unselected", "TabBar", _sb(Color(0.15, 0.18, 0.24), 6, Color(0, 0, 0, 0), 0, 12))
	t.set_stylebox("tab_hovered", "TabBar", _sb(Color(0.22, 0.26, 0.34), 6, Color(0, 0, 0, 0), 0, 12))
	t.set_constant("separation", "HBoxContainer", 6)
	t.set_constant("separation", "VBoxContainer", 6)
	var grab := _sb(ACCENT, 8, Color(0, 0, 0, 0), 0, 0)
	t.set_stylebox("grabber", "VScrollBar", grab)
	t.set_stylebox("grabber_highlight", "VScrollBar", grab)
	t.set_stylebox("scroll", "VScrollBar", _sb(Color(0.1, 0.12, 0.16, 0.6), 8, Color(0, 0, 0, 0), 0, 0 if not mobile else 6))
	t.set_stylebox("slider", "HSlider", _sb(Color(0.2, 0.24, 0.3), 4, Color(0, 0, 0, 0), 0, 4))
	theme = t
	return t

static func label(text: String, size: int = 17, col: Color = TXT, wrap: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fs(size))
	l.add_theme_color_override("font_color", col)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

static func title(text: String) -> Label:
	var l := label(text, 22, ACCENT)
	return l

static func button(text: String, ic: String = "", cb: Callable = Callable(), min_w: int = 0) -> Button:
	var b := Button.new()
	b.text = text
	if ic != "":
		b.icon = icon(ic)
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", 34 if mobile else 24)
	b.custom_minimum_size = Vector2(min_w, btn_h())
	b.focus_mode = Control.FOCUS_NONE
	if cb.is_valid():
		b.pressed.connect(cb)
	return b

static func icon_rect(name: String, size: int = 22) -> TextureRect:
	var r := TextureRect.new()
	r.texture = icon(name)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var s := size + (6 if mobile else 0)
	r.custom_minimum_size = Vector2(s, s)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

static func hbox(sep: int = 6) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h

static func vbox(sep: int = 6) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v

static func panel() -> PanelContainer:
	return PanelContainer.new()

static func scroll(child: Control) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.add_child(child)
	return s

static func sep() -> HSeparator:
	return HSeparator.new()

static func bar(value: float, col: Color, w: int = 120, h: int = 10) -> ProgressBar:
	var p := ProgressBar.new()
	p.min_value = 0
	p.max_value = 100
	p.value = value
	p.show_percentage = false
	p.custom_minimum_size = Vector2(w, h + (4 if mobile else 0))
	var f := _sb(col, 4, Color(0, 0, 0, 0), 0, 0)
	p.add_theme_stylebox_override("fill", f)
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	return p

static func clear(n: Node) -> void:
	for c in n.get_children():
		c.queue_free()

## Costo como texto: "20 madera, 10 metal"
static func cost_text(cost: Dictionary) -> String:
	var parts := []
	for r in cost:
		parts.append("%d %s" % [int(cost[r]), RES_NAMES.get(r, r).to_lower()])
	return ", ".join(parts) if parts.size() > 0 else "gratis"

static func fmt_res(v_fp: int) -> String:
	return str(v_fp / 1000)

static func hour_text(h: int) -> String:
	return "%02d:00" % h
