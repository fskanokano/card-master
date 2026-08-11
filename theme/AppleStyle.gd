extends RefCounted
class_name AppleStyle
## CardMaster — Enterprise style engine.
## 玻璃拟态 + 鎏金描边 + 深色层次，替代旧浅色 HIG。

# ── Shape helpers ─────────────────────────────────────────

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

static func card_stylebox(bg: Color = ApplePalette.BG_GROUPED) -> StyleBoxFlat:
	return _flat(bg, 20, ApplePalette.SHADOW, 24, ApplePalette.SEPARATOR, 1)

static func glass_card(bg: Color = ApplePalette.SURFACE_GLASS) -> StyleBoxFlat:
	var sb := _flat(bg, 20, ApplePalette.SHADOW_SOFT, 18, ApplePalette.SEPARATOR, 1)
	# subtle warm inner glow via border
	return sb

static func hero_card() -> StyleBoxFlat:
	# hero uses elevated surface + gold hairline
	return _flat(ApplePalette.BG_ELEVATED, 24, ApplePalette.SHADOW, 28, ApplePalette.HAIRLINE_GOLD, 1)

static func elevated_card() -> StyleBoxFlat:
	return _flat(ApplePalette.BG_ELEVATED, 18, ApplePalette.SHADOW_SOFT, 20, ApplePalette.SEPARATOR, 1)

static func inset_panel() -> StyleBoxFlat:
	var sb := _flat(Color("#0D1219"), 16, Color(0, 0, 0, 0), 0, ApplePalette.SEPARATOR, 1)
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

# ── Button presets ────────────────────────────────────────

static func apply_primary_button(btn: Button) -> void:
	# Gold CTA — deep gold fill, champagne text
	var n := pill_button_style(ApplePalette.GOLD, ApplePalette.GOLD)
	var h := pill_button_style(ApplePalette.GOLD_BRIGHT, ApplePalette.GOLD_BRIGHT)
	h.bg_color = Color("#E0B070")
	var p := pill_button_style(ApplePalette.GOLD_DEEP, ApplePalette.GOLD_DEEP)
	var d := pill_button_style(Color("#1E2937"), Color("#1E2937"))
	d.bg_color = Color("#1E2937")
	btn.add_theme_stylebox_override("normal", n)
	btn.add_theme_stylebox_override("hover", h)
	btn.add_theme_stylebox_override("pressed", p)
	btn.add_theme_stylebox_override("disabled", d)
	btn.add_theme_color_override("font_color", Color("#1A1208"))
	btn.add_theme_color_override("font_hover_color", Color("#1A1208"))
	btn.add_theme_color_override("font_pressed_color", Color("#1A1208"))
	btn.add_theme_color_override("font_disabled_color", ApplePalette.LABEL_DIM)
	btn.add_theme_font_size_override("font_size", 15)

static func apply_secondary_button(btn: Button) -> void:
	# Ghost glass — translucent with hairline
	var n := pill_button_style(ApplePalette.SURFACE_GLASS, ApplePalette.SURFACE_GLASS)
	n.border_color = ApplePalette.SEPARATOR_STRONG
	n.border_width_left = 1; n.border_width_top = 1; n.border_width_right = 1; n.border_width_bottom = 1
	var h := pill_button_style(Color("#FFFFFF", 0.10), Color("#FFFFFF", 0.10))
	h.border_color = ApplePalette.HAIRLINE_GOLD
	h.border_width_left = 1; h.border_width_top = 1; h.border_width_right = 1; h.border_width_bottom = 1
	var pr := pill_button_style(Color("#FFFFFF", 0.06), Color("#FFFFFF", 0.06))
	pr.border_color = ApplePalette.HAIRLINE_GOLD_STRONG
	pr.border_width_left = 1; pr.border_width_top = 1; pr.border_width_right = 1; pr.border_width_bottom = 1
	btn.add_theme_stylebox_override("normal", n)
	btn.add_theme_stylebox_override("hover", h)
	btn.add_theme_stylebox_override("pressed", pr)
	btn.add_theme_color_override("font_color", ApplePalette.LABEL_ON_DARK)
	btn.add_theme_color_override("font_hover_color", ApplePalette.LABEL_GOLD_BRIGHT)
	btn.add_theme_color_override("font_pressed_color", ApplePalette.LABEL_GOLD)
	btn.add_theme_font_size_override("font_size", 14)

static func apply_ghost_button(btn: Button) -> void:
	apply_secondary_button(btn)

static func apply_teal_button(btn: Button) -> void:
	var n := pill_button_style(ApplePalette.TEAL, ApplePalette.TEAL)
	var h := pill_button_style(Color("#33D6C6"), Color("#33D6C6"))
	var pr := pill_button_style(ApplePalette.TEAL_DEEP, ApplePalette.TEAL_DEEP)
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
	n.bg_color = Color("#0D1219")
	n.corner_radius_top_left = 12; n.corner_radius_top_right = 12; n.corner_radius_bottom_right = 12; n.corner_radius_bottom_left = 12
	n.border_color = ApplePalette.SEPARATOR; n.border_width_left = 1; n.border_width_top = 1; n.border_width_right = 1; n.border_width_bottom = 1
	n.content_margin_left = 14; n.content_margin_top = 10; n.content_margin_right = 14; n.content_margin_bottom = 10
	var f := n.duplicate()
	f.bg_color = Color("#111A26")
	f.border_color = ApplePalette.HAIRLINE_GOLD
	var p := n.duplicate()
	p.border_color = ApplePalette.GOLD
	field.add_theme_stylebox_override("normal", n)
	field.add_theme_stylebox_override("focus", f)
	field.add_theme_stylebox_override("read_only", n)
	field.add_theme_color_override("font_color", ApplePalette.LABEL_ON_DARK)
	field.add_theme_color_override("font_placeholder_color", ApplePalette.LABEL_DIM)
	field.add_theme_color_override("selection_color", Color("#D4A574", 0.30))
	field.add_theme_font_size_override("font_size", 14)
