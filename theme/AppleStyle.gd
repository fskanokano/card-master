extends RefCounted
class_name AppleStyle

## Helpers to apply Apple HIG styling at runtime (rounded fills, shadows, vibrancy tints).
## Keeps visual policy in one place so Lobby/Board/Game chrome stay consistent.

static func card_stylebox(bg: Color = ApplePalette.BG_GROUPED) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.corner_radius_top_left = 16
	sb.corner_radius_top_right = 16
	sb.corner_radius_bottom_right = 16
	sb.corner_radius_bottom_left = 16
	sb.shadow_color = ApplePalette.SHADOW
	sb.shadow_size = 12
	sb.shadow_offset = Vector2(0, 6)
	sb.content_margin_left = 16
	sb.content_margin_top = 16
	sb.content_margin_right = 16
	sb.content_margin_bottom = 16
	return sb

static func pill_button_style(bg: Color, pressed_bg: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.corner_radius_top_left = 12
	sb.corner_radius_top_right = 12
	sb.corner_radius_bottom_right = 12
	sb.corner_radius_bottom_left = 12
	sb.content_margin_left = 14
	sb.content_margin_top = 10
	sb.content_margin_right = 14
	sb.content_margin_bottom = 10
	return sb

static func apply_primary_button(btn: Button) -> void:
	var normal := pill_button_style(ApplePalette.BLUE, ApplePalette.BLUE)
	var hover := pill_button_style(ApplePalette.BLUE, ApplePalette.BLUE)
	hover.bg_color = Color("#0A84FF")
	var pressed := pill_button_style(ApplePalette.BLUE_PRESSED, ApplePalette.BLUE_PRESSED)
	var disabled := pill_button_style(Color("#E5E5EA"), Color("#E5E5EA"))
	disabled.bg_color = ApplePalette.GRAY_FILL
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	btn.add_theme_color_override("font_disabled_color", ApplePalette.LABEL_TERTIARY)

static func apply_secondary_button(btn: Button) -> void:
	var normal := pill_button_style(ApplePalette.GRAY_FILL, ApplePalette.GRAY_FILL)
	var hover := pill_button_style(Color("#DCE0E6"), Color("#DCE0E6"))
	var pressed := pill_button_style(ApplePalette.GRAY_FILL_PRESSED, ApplePalette.GRAY_FILL_PRESSED)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_color_override("font_color", ApplePalette.BLUE)
	btn.add_theme_color_override("font_hover_color", ApplePalette.BLUE)
	btn.add_theme_color_override("font_pressed_color", ApplePalette.BLUE_PRESSED)

static func apply_card(panel: Panel) -> void:
	panel.add_theme_stylebox_override("panel", card_stylebox())

static func apply_vibrancy_overlay(panel: Panel, alpha: float = 0.72) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, alpha)
	sb.corner_radius_top_left = 16
	sb.corner_radius_top_right = 16
	sb.corner_radius_bottom_right = 16
	sb.corner_radius_bottom_left = 16
	panel.add_theme_stylebox_override("panel", sb)
