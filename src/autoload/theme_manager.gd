extends Node

const COLORS := {
	"bg_dark": Color(0.06, 0.06, 0.09, 1.0),
	"bg_medium": Color(0.10, 0.10, 0.14, 1.0),
	"bg_panel": Color(0.12, 0.12, 0.17, 0.94),
	"accent_gold": Color(0.85, 0.72, 0.35, 1.0),
	"accent_gold_dim": Color(0.55, 0.45, 0.2, 0.6),
	"text_primary": Color(0.88, 0.88, 0.90, 1.0),
	"text_secondary": Color(0.60, 0.60, 0.65, 1.0),
	"text_highlight": Color(1.0, 0.92, 0.55, 1.0),
	"border": Color(0.30, 0.25, 0.15, 0.5),
	"danger": Color(0.8, 0.25, 0.2, 1.0),
	"success": Color(0.2, 0.7, 0.35, 1.0),
}

func make_panel_style(bg_color: Color = COLORS["bg_panel"], border_color: Color = COLORS["border"], corner: int = 6) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.set_border_width_all(1)
	style.border_color = border_color
	style.set_corner_radius_all(corner)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

func make_button_style(bg_color: Color, border_color: Color, corner: int = 4) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.set_border_width_all(1)
	style.border_color = border_color
	style.set_corner_radius_all(corner)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

func style_button(btn: Button) -> void:
	var normal := make_button_style(Color(0.14, 0.14, 0.20, 0.9), COLORS["accent_gold_dim"])
	var hover := make_button_style(Color(0.18, 0.17, 0.24, 0.95), COLORS["accent_gold"])
	var pressed := make_button_style(Color(0.22, 0.20, 0.12, 0.95), COLORS["accent_gold"])
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_color_override("font_color", COLORS["text_primary"])
	btn.add_theme_color_override("font_hover_color", COLORS["text_highlight"])
	btn.add_theme_color_override("font_pressed_color", COLORS["accent_gold"])

func style_label(lbl: Label, color: Color = COLORS["text_primary"]) -> void:
	lbl.add_theme_color_override("font_color", color)

func generate_gradient_bg(width: int, height: int, top_color: Color, bottom_color: Color) -> ImageTexture:
	var img := Image.create(width, height, false, Image.FORMAT_RGBA8)
	for y in range(height):
		var t := float(y) / float(height)
		var c := top_color.lerp(bottom_color, t)
		for x in range(width):
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)

func generate_vignette_bg(width: int, height: int, base_color: Color) -> ImageTexture:
	var img := Image.create(width, height, false, Image.FORMAT_RGBA8)
	var cx := width / 2.0
	var cy := height / 2.0
	var max_dist := sqrt(cx * cx + cy * cy)
	for y in range(height):
		for x in range(width):
			var dx := (x - cx) / cx
			var dy := (y - cy) / cy
			var dist := sqrt(dx * dx + dy * dy) / 1.4
			var dark_factor := clampf(dist * 0.6, 0.0, 0.55)
			var c := base_color.darkened(dark_factor)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)

func load_external_image(path: String) -> ImageTexture:
	var abs_path := path
	if path.begins_with("res://"):
		abs_path = ProjectSettings.globalize_path(path)
	var img := Image.new()
	var err := img.load(abs_path)
	if err != OK:
		push_warning("[ThemeManager] Failed to load image: " + abs_path)
		return null
	return ImageTexture.create_from_image(img)

const SCENE_PALETTES := {
	"temple": [Color(0.08, 0.10, 0.06), Color(0.12, 0.14, 0.08), Color(0.15, 0.20, 0.10, 0.3)],
	"apartment": [Color(0.14, 0.16, 0.20), Color(0.18, 0.15, 0.12), Color(0.22, 0.24, 0.28, 0.4)],
	"mansion": [Color(0.12, 0.08, 0.06), Color(0.18, 0.12, 0.08), Color(0.25, 0.18, 0.10, 0.3)],
	"clinic": [Color(0.10, 0.12, 0.08), Color(0.14, 0.16, 0.10), Color(0.18, 0.22, 0.14, 0.3)],
	"house": [Color(0.12, 0.12, 0.14), Color(0.16, 0.14, 0.12), Color(0.20, 0.20, 0.22, 0.4)],
	"port": [Color(0.06, 0.10, 0.16), Color(0.08, 0.14, 0.22), Color(0.12, 0.18, 0.28, 0.3)],
	"bar": [Color(0.14, 0.06, 0.12), Color(0.20, 0.08, 0.16), Color(0.28, 0.10, 0.22, 0.3)],
}

func generate_crime_scene_bg(width: int, height: int, scene_type: String = "") -> ImageTexture:
	var palette: Array = SCENE_PALETTES.get(scene_type, SCENE_PALETTES["apartment"])
	var base: Color = palette[0]
	var accent: Color = palette[1]
	var grid_color: Color = palette[2]

	var img := Image.create(width, height, false, Image.FORMAT_RGBA8)
	for y in range(height):
		var row_t := float(y) / float(height)
		var row_base := base.lerp(accent, row_t * 0.6)
		for x in range(width):
			var noise_r := randf_range(-0.015, 0.015)
			var c := Color(row_base.r + noise_r, row_base.g + noise_r, row_base.b + noise_r, 1.0)
			img.set_pixel(x, y, c)

	var step := 40
	for y in range(0, height, step):
		for x in range(width):
			img.set_pixel(x, y, img.get_pixel(x, y).lerp(grid_color, 0.3))
	for x in range(0, width, step):
		for y in range(height):
			img.set_pixel(x, y, img.get_pixel(x, y).lerp(grid_color, 0.3))

	var cx := width / 2.0
	var cy := height / 2.0
	for y in range(height):
		for x in range(width):
			var dx := (float(x) - cx) / cx
			var dy := (float(y) - cy) / cy
			var dist := sqrt(dx * dx + dy * dy) / 1.4
			var dark := clampf(dist * 0.4, 0.0, 0.4)
			img.set_pixel(x, y, img.get_pixel(x, y).darkened(dark))

	return ImageTexture.create_from_image(img)
