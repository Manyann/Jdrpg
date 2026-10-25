# Design system commun (sombre et or) : écran de création d'équipe, interface
# de combat, fenêtres. Une seule source pour les couleurs, panneaux et boutons.
class_name UITheme

const GOLD := Color(0.86, 0.68, 0.30)
const GOLD_DIM := Color(0.50, 0.40, 0.20)
const CREAM := Color(0.93, 0.88, 0.76)
const TITLE := Color(0.95, 0.85, 0.60)
const PANEL_BG := Color(0.05, 0.06, 0.09, 0.93)

static func panel_style(border: Color = GOLD_DIM, radius: int = 6, margin: int = 12, alpha: float = 0.93) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(PANEL_BG.r, PANEL_BG.g, PANEL_BG.b, alpha)
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(margin)
	s.shadow_color = Color(0, 0, 0, 0.5)
	s.shadow_size = 6
	return s

static func button_style(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(4)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 5
	s.content_margin_bottom = 5
	return s

## Boutons d'action principaux (Valider, Étage suivant...) : fond doré.
static func style_primary_button(button: Button) -> void:
	button.add_theme_stylebox_override("normal", button_style(Color(0.45, 0.30, 0.10), GOLD))
	button.add_theme_stylebox_override("hover", button_style(Color(0.58, 0.39, 0.13), Color(1, 0.85, 0.45)))
	button.add_theme_stylebox_override("pressed", button_style(Color(0.35, 0.23, 0.07), GOLD))

static func section_title(text: String, size: int = 20) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", TITLE)
	return l

## Barre de PV : fond sombre, remplissage rouge, liseré doré.
static func style_hp_bar(bar: ProgressBar) -> void:
	var bg := button_style(Color(0.04, 0.05, 0.07), GOLD_DIM)
	bg.content_margin_top = 0
	bg.content_margin_bottom = 0
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.75, 0.2, 0.2)
	fill.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)

static func build_theme() -> Theme:
	var t := Theme.new()
	var normal := button_style(Color(0.08, 0.09, 0.12), Color(0.35, 0.29, 0.16))
	var hover := button_style(Color(0.13, 0.12, 0.10), GOLD)
	var pressed := button_style(Color(0.18, 0.14, 0.07), GOLD)
	var disabled := button_style(Color(0.07, 0.07, 0.09), Color(0.2, 0.19, 0.17))
	for cls in ["Button", "OptionButton", "MenuButton"]:
		t.set_stylebox("normal", cls, normal)
		t.set_stylebox("hover", cls, hover)
		t.set_stylebox("pressed", cls, pressed)
		t.set_stylebox("disabled", cls, disabled)
		t.set_stylebox("focus", cls, hover)
		t.set_color("font_color", cls, CREAM)
		t.set_color("font_hover_color", cls, Color(1, 0.93, 0.7))
		t.set_color("font_pressed_color", cls, GOLD)
		t.set_color("font_disabled_color", cls, Color(0.45, 0.43, 0.4))
	t.set_color("font_color", "Label", CREAM)
	t.set_color("font_color", "CheckBox", CREAM)
	var edit := button_style(Color(0.04, 0.05, 0.07), Color(0.35, 0.29, 0.16))
	t.set_stylebox("normal", "LineEdit", edit)
	t.set_stylebox("focus", "LineEdit", button_style(Color(0.04, 0.05, 0.07), GOLD))
	t.set_color("font_color", "LineEdit", CREAM)
	var popup := panel_style(GOLD_DIM, 4, 6)
	t.set_stylebox("panel", "PopupMenu", popup)
	t.set_stylebox("panel", "PopupPanel", popup)
	t.set_stylebox("hover", "PopupMenu", button_style(Color(0.18, 0.14, 0.07), GOLD_DIM))
	t.set_color("font_color", "PopupMenu", CREAM)
	t.set_color("font_hover_color", "PopupMenu", Color(1, 0.93, 0.7))
	var sep := StyleBoxLine.new()
	sep.color = Color(0.5, 0.4, 0.2, 0.45)
	t.set_stylebox("separator", "HSeparator", sep)
	# Infobulles (coût et effet des sorts) dans le même style.
	t.set_stylebox("panel", "TooltipPanel", panel_style(GOLD_DIM, 4, 8, 0.97))
	t.set_color("font_color", "TooltipLabel", CREAM)
	return t
