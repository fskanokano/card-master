extends RefCounted
class_name AppleStyle
const ApplePaletteRef = preload("res://theme/ApplePalette.gd")
## CardMaster — Warm Wood Academy style, TianTian inspired.
## 暖木棋院：厚实木纹 + 黄铜描边 + 米白纸面，替代冷玻璃。

static func _flat(bg: Color, r: float, shadow: Color = Color(0, 0, 0, 0), shadow_size: int = 0, border: Color = Color(0, 0, 0, 0), border_w: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.corner_radius_top_left = int(r)
	sb.corner_radius_top_right = int(r)
	sb.corner_radius_bottom_right = int(r)
	sb.corner_radius_bottom_left = int(r)
	sb.content_margin_left = 18
	sb.content_margin_top = 18
	sb.content_margin_right = 18
	sb.content_margin_bottom = 18
	if shadow.a > 0.001:
		sb.shadow_color = shadow
		sb.shadow_size = shadow_size
		sb.shadow_offset = Vector2(0, 8)
	if border.a > 0.001 and border_w > 0:
		sb.border_color = border
		sb.border_width_left = border_w
		sb.border_width_top = border_w
		sb.border_width_right = border_w
		sb.border_width_bottom = border_w
	return sb

static func card_stylebox(bg: Color = ApplePaletteRef.BG_GROUPED) -> StyleBoxFlat:
	return _flat(bg, 20, ApplePaletteRef.SHADOW, 24, ApplePaletteRef.SEPARATOR, 1)

static func glass_card(bg: Color = ApplePaletteRef.SURFACE_GLASS) -> StyleBoxFlat:
	return _flat(bg, 20, ApplePaletteRef.SHADOW_SOFT, 18, ApplePaletteRef.SEPARATOR, 1)

static func hero_card() -> StyleBoxFlat:
	# TianTian hero: warm elevated with thin brass hairline + soft shadow
	return _flat(ApplePaletteRef.BG_ELEVATED, 24, ApplePaletteRef.SHADOW, 28, ApplePaletteRef.HAIRLINE_GOLD, 1)

static func elevated_card() -> StyleBoxFlat:
	return _flat(ApplePaletteRef.BG_ELEVATED, 18, ApplePaletteRef.SHADOW_SOFT, 20, ApplePaletteRef.SEPARATOR, 1)

static func inset_panel() -> StyleBoxFlat:
	var sb := _flat(Color("#131A14"), 16, Color(0, 0, 0, 0), 0, ApplePaletteRef.SEPARATOR, 1)
	sb.content_margin_left = 14
	sb.content_margin_top = 12
	sb.content_margin_right = 14
	sb.content_margin_bottom = 12
	return sb

static func pill_button_style(bg: Color, _pressed_bg: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.corner_radius_top_left = 14
	sb.corner_radius_top_right = 14
	sb.corner_radius_bottom_right = 14
	sb.corner_radius_bottom_left = 14
	sb.content_margin_left = 18
	sb.content_margin_top = 12
	sb.content_margin_right = 18
	sb.content_margin_bottom = 12
	return sb

static func apply_primary_button(btn: Button) -> void:
	# Warm brass CTA — TianTian style wood button (deep brass, warm ivory text)
	var n := pill_button_style(ApplePaletteRef.GOLD, ApplePaletteRef.GOLD)
	var h := pill_button_style(Color("#D4B483"), ApplePaletteRef.GOLD)
	h.bg_color = Color("#D4B483")
	var p := pill_button_style(ApplePaletteRef.GOLD_DEEP, ApplePaletteRef.GOLD_DEEP)
	var d := pill_button_style(Color("#1E2520"), Color("#1E2520"))
	d.bg_color = Color("#1E2520")
	btn.add_theme_stylebox_override("normal", n)
	btn.add_theme_stylebox_override("hover", h)
	btn.add_theme_stylebox_override("pressed", p)
	btn.add_theme_stylebox_override("disabled", d)
	btn.add_theme_color_override("font_color", Color("#1A1208"))
	btn.add_theme_color_override("font_hover_color", Color("#1A1208"))
	btn.add_theme_color_override("font_pressed_color", Color("#F2EDE6"))
	btn.add_theme_color_override("font_disabled_color", ApplePaletteRef.LABEL_DIM)
	btn.add_theme_font_size_override("font_size", 15)

static func apply_secondary_button(btn: Button) -> void:
	# Warm charcoal ghost — like TianTian's secondary wood button
	var n := pill_button_style(Color("#1A1F18"), Color("#1A1F18"))
	n.border_color = ApplePaletteRef.SEPARATOR_STRONG
	n.border_width_left = 1; n.border_width_top = 1; n.border_width_right = 1; n.border_width_bottom = 1
	var h := pill_button_style(Color("#252B24"), Color("#252B24"))
	h.border_color = ApplePaletteRef.HAIRLINE_GOLD
	h.border_width_left = 1; h.border_width_top = 1; h.border_width_right = 1; h.border_width_bottom = 1
	var pr := pill_button_style(Color("#1A1F18"), Color("#1A1F18"))
	pr.border_color = ApplePaletteRef.HAIRLINE_GOLD_STRONG
	pr.border_width_left = 1; pr.border_width_top = 1; pr.border_width_right = 1; pr.border_width_bottom = 1
	btn.add_theme_stylebox_override("normal", n)
	btn.add_theme_stylebox_override("hover", h)
	btn.add_theme_stylebox_override("pressed", pr)
	btn.add_theme_color_override("font_color", ApplePaletteRef.LABEL_ON_DARK)
	btn.add_theme_color_override("font_hover_color", ApplePaletteRef.LABEL_GOLD_BRIGHT)
	btn.add_theme_color_override("font_pressed_color", ApplePaletteRef.LABEL_GOLD)
	btn.add_theme_font_size_override("font_size", 14)

static func apply_ghost_button(btn: Button) -> void:
	apply_secondary_button(btn)

static func apply_teal_button(btn: Button) -> void:
	var n := pill_button_style(ApplePaletteRef.TEAL, ApplePaletteRef.TEAL)
	var h := pill_button_style(Color("#4DBEB4"), Color("#4DBEB4"))
	var pr := pill_button_style(ApplePaletteRef.TEAL_DEEP, ApplePaletteRef.TEAL_DEEP)
	btn.add_theme_stylebox_override("normal", n)
	btn.add_theme_stylebox_override("hover", h)
	btn.add_theme_stylebox_override("pressed", pr)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)

static func apply_card(panel: Panel) -> void:
	panel.add_theme_stylebox_override("panel", card_stylebox())

static func apply_hero(panel: Panel) -> void:
	panel.add_theme_stylebox_override("panel", hero_card())

static func apply_glass(panel: Panel) -> void:
	panel.add_theme_stylebox_override("panel", glass_card())

static func apply_elevated(panel: Panel) -> void:
	panel.add_theme_stylebox_override("panel", elevated_card())

static func apply_vibrancy_overlay(panel: Panel, alpha: float = 0.72) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, alpha)
	sb.corner_radius_top_left = 16
	sb.corner_radius_top_right = 16
	sb.corner_radius_bottom_right = 16
	sb.corner_radius_bottom_left = 16
	panel.add_theme_stylebox_override("panel", sb)

static func apply_inset(panel: Panel) -> void:
	panel.add_theme_stylebox_override("panel", inset_panel())

static func apply_input(field: LineEdit) -> void:
	var n := StyleBoxFlat.new()
	n.bg_color = Color("#131A14")
	n.corner_radius_top_left = 12; n.corner_radius_top_right = 12; n.corner_radius_bottom_right = 12; n.corner_radius_bottom_left = 12
	n.border_color = ApplePaletteRef.SEPARATOR; n.border_width_left = 1; n.border_width_top = 1; n.border_width_right = 1; n.border_width_bottom = 1
	n.content_margin_left = 14; n.content_margin_top = 10; n.content_margin_right = 14; n.content_margin_bottom = 10
	var f := n.duplicate()
	f.bg_color = Color("#1A1F18")
	f.border_color = ApplePaletteRef.HAIRLINE_GOLD
	var p := n.duplicate()
	p.border_color = ApplePaletteRef.GOLD
	field.add_theme_stylebox_override("normal", n)
	field.add_theme_stylebox_override("focus", f)
	field.add_theme_stylebox_override("read_only", n)
	field.add_theme_color_override("font_color", ApplePaletteRef.LABEL_ON_DARK)
	field.add_theme_color_override("font_placeholder_color", ApplePaletteRef.LABEL_DIM)
	field.add_theme_color_override("selection_color", Color("#C8A46A", 0.30))
	field.add_theme_font_size_override("font_size", 14)
