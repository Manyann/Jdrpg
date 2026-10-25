extends Control

# ============================================================
# tower_team_select.gd — Écran de création d'équipe pour la Tour de
# l'infini, sous forme de CARTES. À attacher à un node Control dans une
# scène dédiée — construit toute son interface par code à _ready().
#
# Disposition en 3 colonnes : liste des RACES (gauche, avec leur token), fiche du
# personnage sélectionné (centre : nom, niveau, caractéristiques, métiers,
# équipement), emplacements de l'ÉQUIPE (droite). Un clic sur un emplacement
# vide puis sur une race crée le personnage (1 point) ; un clic sur une race
# change celle du personnage sélectionné.
# En bas : bouton « Valider », qui lance l'ascension (étage 1 dans
# la scène de combat, voir TowerManager.start_run).
#
# Dépend de TowerManager (autoload, voir tower_manager.gd) pour TOUTE la
# logique — cet écran ne fait que de l'affichage et du câblage.
# ============================================================

const CARD_WIDTH: int = 400

## Hauteur FIXE d'une carte de personnage : elle ne change plus selon le
## contenu (métiers choisis, 2e arme...). Si le contenu dépasse, la carte
## défile à l'intérieur (voir _build_character_card).
const CARD_HEIGHT: int = 700

## Illustrations de race : <slug>.png dans ce dossier, slug = nom de la
## race en minuscules, sans accents, espaces remplacés par "_" (ex:
## haut_elfe.png, homme_des_sables.png). Image absente = le nom de la
## race s'affiche à la place.
const RACE_IMAGE_DIR: String = "res://assets/races/"

var _validate_button: Button
var _warning_label: Label

## Message à afficher UNE fois dans la zone d'avertissement au prochain
## rafraîchissement (ex: pourquoi un changement de métier a été refusé).
var _notice: String = ""

var _equip_popup: PopupPanel

# Sauvegarde / chargement (voir TowerManager.save_to_slot / load_from_slot).
var _save_popup: PopupPanel
var _save_popup_box: VBoxContainer
var _continue_button: Button
var _pending_overwrite_slot: int = -1  # Emplacement dont l'écrasement attend une confirmation.
var _equip_popup_index: int = -1
var _equip_popup_content: VBoxContainer
var _equip_popup_gold_label: Label

func _ready() -> void:
	# Garde-fou : si l'Autoload "TowerManager" pointe par erreur vers un
	# AUTRE script au lieu de tower_manager.gd, tout le reste planterait
	# avec des erreurs obscures — on le dit clairement.
	if not TowerManager.has_method("add_character"):
		push_error("Autoload 'TowerManager' mal configuré : son chemin doit être res://scripts/tower_manager.gd (PAS tower_team_select.gd). Voir Projet > Paramètres du projet > Autoload.")
		return
	TowerManager.reset()
	# Un texte de restriction sans règle dans equipment_rules.gd ne serait
	# JAMAIS appliqué : on le dit dès l'ouverture plutôt que de le taire.
	var unmapped: Array = TowerManager.get_unmapped_equipment_restrictions()
	if not unmapped.is_empty():
		push_warning("Restrictions d'équipement sans règle dans equipment_rules.gd (donc non appliquées) : %s" % ", ".join(unmapped))
	_build_ui()
	_fit_to_viewport()
	get_viewport().size_changed.connect(_fit_to_viewport)
	_refresh()

# Impose la taille de l'écran = celle de la fenêtre, À LA MAIN, plutôt
# que de compter sur les ancres : un Control placé sous un Node2D (ex:
# la scène de la grille hexagonale) n'a PAS de rectangle parent, donc
# ses ancres donnent une taille nulle.
func _fit_to_viewport() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2.ZERO
	size = get_viewport_rect().size

# ---------- Construction de l'interface ----------
# Disposition en 3 colonnes : liste des races (gauche), fiche du personnage
# sélectionné (centre), emplacements de l'équipe (droite).

const GOLD := UITheme.GOLD
const GOLD_DIM := UITheme.GOLD_DIM
const CREAM := UITheme.CREAM
const SLOT_COUNT_MIN: int = 6

## Chemin de la scène de l'écran précédent (bouton « Retour »). Vide = pas de bouton.
const BACK_SCENE_PATH: String = ""
## Image de fond facultative (res://assets/ui/team_bg.png) ; sinon un fond uni sombre.
const BACKGROUND_PATH: String = "res://assets/ui/team_bg.png"

var _points_label: Label
var _gold_label: Label
var _race_list: VBoxContainer
var _center_scroll: ScrollContainer
var _center_box: VBoxContainer
var _slot_grid: GridContainer
var _slot_scroll: ScrollContainer

## Emplacement sélectionné : un index >= team.size() = emplacement vide.
var _selected_index: int = 0

func _make_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	return l

func _card_style(border: Color, background: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(10)
	return style

func _panel_style(border: Color = GOLD_DIM, radius: int = 6, margin: int = 12) -> StyleBoxFlat:
	return UITheme.panel_style(border, radius, margin)

func _button_style(bg: Color, border: Color) -> StyleBoxFlat:
	return UITheme.button_style(bg, border)

# Thème sombre et or (voir UITheme) appliqué à tout l'écran.
func _build_theme() -> Theme:
	return UITheme.build_theme()

func _section_title(text: String, size: int = 20) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(0.95, 0.85, 0.6))
	return l

func _build_ui() -> void:
	theme = _build_theme()

	# Fond : image facultative, sinon aplat sombre.
	var bg_tex = load(BACKGROUND_PATH) if ResourceLoader.exists(BACKGROUND_PATH) else null
	if bg_tex is Texture2D:
		var bg := TextureRect.new()
		bg.texture = bg_tex
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(bg)
	else:
		var bg := ColorRect.new()
		bg.color = Color(0.03, 0.04, 0.07)
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	# --- Bandeau du haut : titre à gauche, points et or à droite ---
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	root.add_child(top)

	var title_panel := PanelContainer.new()
	title_panel.add_theme_stylebox_override("panel", _panel_style(GOLD_DIM, 8, 8))
	top.add_child(title_panel)
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 10)
	title_panel.add_child(title_row)
	var star := _section_title("✦", 34)
	star.add_theme_color_override("font_color", GOLD)
	title_row.add_child(star)
	var title_box := VBoxContainer.new()
	title_box.add_theme_constant_override("separation", 0)
	title_row.add_child(title_box)
	title_box.add_child(_section_title("Création de l'équipe", 28))
	var subtitle := _make_label("Tour de l'infini")
	subtitle.add_theme_font_size_override("font_size", 12)
	subtitle.modulate = Color(0.8, 0.75, 0.6)
	title_box.add_child(subtitle)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)

	var info_panel := PanelContainer.new()
	info_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info_panel.add_theme_stylebox_override("panel", _panel_style(GOLD_DIM, 20, 10))
	top.add_child(info_panel)
	var info_row := HBoxContainer.new()
	info_row.add_theme_constant_override("separation", 22)
	info_panel.add_child(info_row)
	_points_label = _make_label("")
	_points_label.add_theme_font_size_override("font_size", 16)
	info_row.add_child(_points_label)
	_gold_label = _make_label("")
	_gold_label.add_theme_font_size_override("font_size", 16)
	_gold_label.add_theme_color_override("font_color", Color(0.95, 0.8, 0.35))
	info_row.add_child(_gold_label)

	# --- Trois colonnes ---
	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 12)
	root.add_child(columns)

	# Gauche : races
	var left := PanelContainer.new()
	left.custom_minimum_size = Vector2(230, 0)
	left.add_theme_stylebox_override("panel", _panel_style())
	columns.add_child(left)
	var left_box := VBoxContainer.new()
	left_box.add_theme_constant_override("separation", 8)
	left.add_child(left_box)
	left_box.add_child(_section_title("Races"))
	var race_scroll := ScrollContainer.new()
	race_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	race_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_box.add_child(race_scroll)
	_race_list = VBoxContainer.new()
	_race_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_race_list.add_theme_constant_override("separation", 4)
	race_scroll.add_child(_race_list)

	# Centre : fiche du personnage sélectionné
	var center := PanelContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_theme_stylebox_override("panel", _panel_style())
	columns.add_child(center)
	var center_holder := Control.new()
	center_holder.clip_contents = true
	center.add_child(center_holder)
	_center_scroll = ScrollContainer.new()
	_center_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_center_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center_holder.add_child(_center_scroll)
	_center_box = VBoxContainer.new()
	_center_box.add_theme_constant_override("separation", 8)
	_center_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_center_scroll.add_child(_center_box)

	# Droite : équipe
	var right := PanelContainer.new()
	right.custom_minimum_size = Vector2(330, 0)
	right.add_theme_stylebox_override("panel", _panel_style())
	columns.add_child(right)
	var right_box := VBoxContainer.new()
	right_box.add_theme_constant_override("separation", 8)
	right.add_child(right_box)
	right_box.add_child(_section_title("Équipe"))
	_slot_scroll = ScrollContainer.new()
	_slot_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_slot_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_box.add_child(_slot_scroll)
	_slot_grid = GridContainer.new()
	_slot_grid.columns = 3
	_slot_grid.add_theme_constant_override("h_separation", 8)
	_slot_grid.add_theme_constant_override("v_separation", 8)
	_slot_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slot_scroll.add_child(_slot_grid)

	_warning_label = Label.new()
	_warning_label.add_theme_font_size_override("font_size", 12)
	_warning_label.add_theme_color_override("font_color", Color(0.95, 0.65, 0.3))
	_warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_warning_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right_box.add_child(_warning_label)

	# --- Bas : Retour / Valider ---
	var bottom := HBoxContainer.new()
	root.add_child(bottom)
	if BACK_SCENE_PATH != "":
		var back := Button.new()
		back.text = "←  Retour"
		back.custom_minimum_size = Vector2(150, 40)
		back.pressed.connect(func(): get_tree().change_scene_to_file(BACK_SCENE_PATH))
		bottom.add_child(back)
	var save_button := Button.new()
	save_button.text = "Sauvegarder"
	save_button.tooltip_text = "Enregistre cette équipe dans un emplacement"
	save_button.custom_minimum_size = Vector2(150, 40)
	save_button.pressed.connect(func(): _open_save_popup(true))
	bottom.add_child(save_button)
	var load_button := Button.new()
	load_button.text = "Charger"
	load_button.tooltip_text = "Reprend une équipe ou une ascension sauvegardée"
	load_button.custom_minimum_size = Vector2(150, 40)
	load_button.pressed.connect(func(): _open_save_popup(false))
	bottom.add_child(load_button)
	_continue_button = Button.new()
	_continue_button.custom_minimum_size = Vector2(260, 40)
	_continue_button.visible = false
	UITheme.style_primary_button(_continue_button)
	_continue_button.pressed.connect(func(): _load_slot(TowerSave.AUTO_SLOT))
	bottom.add_child(_continue_button)
	var bottom_spacer := Control.new()
	bottom_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(bottom_spacer)
	_validate_button = Button.new()
	_validate_button.text = "✓  Valider"
	_validate_button.tooltip_text = "Lance l'ascension avec cette équipe"
	_validate_button.custom_minimum_size = Vector2(220, 44)
	_validate_button.add_theme_font_size_override("font_size", 18)
	_validate_button.add_theme_stylebox_override("normal", _button_style(Color(0.45, 0.30, 0.10), GOLD))
	_validate_button.add_theme_stylebox_override("hover", _button_style(Color(0.58, 0.39, 0.13), Color(1, 0.85, 0.45)))
	_validate_button.add_theme_stylebox_override("pressed", _button_style(Color(0.35, 0.23, 0.07), GOLD))
	_validate_button.pressed.connect(_on_validate_pressed)
	bottom.add_child(_validate_button)

	_build_equip_popup()
	_build_save_popup()

# ---------- Rafraîchissement ----------

# Reconstruit la liste des races, la fiche centrale et les emplacements. Le
# défilement de la fiche est conservé : sans ça, chaque clic sur un +/-
# renverrait la vue en haut.
func _refresh() -> void:
	if _center_box == null:
		return
	var keep_v: int = _center_scroll.scroll_vertical
	var keep_race_v: int = (_race_list.get_parent() as ScrollContainer).scroll_vertical

	if TowerManager.team.is_empty():
		_selected_index = 0
	elif _selected_index > TowerManager.team.size():
		_selected_index = TowerManager.team.size() - 1

	_points_label.text = "Points restants : %d / %d" % [TowerManager.points_remaining, TowerManager.TOTAL_POINTS]
	_gold_label.text = "●  Or : %d PO" % TowerManager.gold
	if TowerManager.last_run_floors_cleared >= 0:
		_points_label.text += "   —   Dernière ascension : %d étage(s)" % TowerManager.last_run_floors_cleared

	_rebuild_race_list()
	_rebuild_slots()
	_rebuild_center()

	var equipment_notice: String = TowerManager.take_equipment_notice()
	if equipment_notice != "":
		_notice = equipment_notice if _notice == "" else _notice + " " + equipment_notice

	_update_validate_state()

	if is_inside_tree():
		await get_tree().process_frame  # Le contenu doit être remesuré avant de restaurer le défilement.
		_center_scroll.scroll_vertical = keep_v
		(_race_list.get_parent() as ScrollContainer).scroll_vertical = keep_race_v

func _clear_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)  # Retiré TOUT DE SUITE (pas seulement libéré en fin d'image).
		child.queue_free()

func _update_validate_state() -> void:
	var ready_to_start: bool = TowerManager.is_team_ready()
	_validate_button.disabled = not ready_to_start
	_update_continue_button()
	_warning_label.text = ""
	if _notice != "":
		_warning_label.text = _notice
		_notice = ""
		return
	if ready_to_start:
		return
	if TowerManager.team.is_empty():
		_warning_label.text = "Choisis une race pour créer ton premier personnage."
	elif TowerManager.points_remaining > 0:
		_warning_label.text = "Il reste %d point(s) à dépenser en niveaux." % TowerManager.points_remaining
	else:
		for i in range(TowerManager.team.size()):
			var reason: String = TowerManager.get_incomplete_reason(i)
			if reason != "":
				_warning_label.text = "%s : %s." % [TowerManager.team[i].character_name, reason]
				return

func _selected_character():
	if _selected_index >= 0 and _selected_index < TowerManager.team.size():
		return TowerManager.team[_selected_index]
	return null

# ---------- Colonne de gauche : races ----------

func _race_icon(race_name: String) -> Texture2D:
	return TokenDatabase.texture_by_name(race_name)

func _rebuild_race_list() -> void:
	_clear_children(_race_list)
	var current = _selected_character()
	for race_name in TowerManager.get_available_races():
		var btn := Button.new()
		btn.text = race_name
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(0, 40)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.clip_text = true
		var icon := _race_icon(race_name)
		if icon != null:
			btn.icon = icon
			btn.expand_icon = true
			btn.add_theme_constant_override("icon_max_width", 32)
		var race = RaceDatabase.build(race_name)
		btn.tooltip_text = race.get_display_text() if race != null else race_name
		if current != null and current.race_name == race_name:
			var sel := _button_style(Color(0.16, 0.12, 0.05), GOLD)
			sel.set_border_width_all(2)
			for state in ["normal", "hover", "pressed"]:
				btn.add_theme_stylebox_override(state, sel)
		btn.pressed.connect(func(): _on_race_clicked(race_name))
		_race_list.add_child(btn)

func _on_race_clicked(race_name: String) -> void:
	if _selected_character() == null:
		# Emplacement vide : choisir une race crée le personnage (1 point).
		var c = TowerManager.add_character()
		if c == null:
			_notice = "Plus aucun point disponible pour un nouveau personnage."
			_refresh()
			return
		_selected_index = TowerManager.team.size() - 1
	TowerManager.set_race(_selected_index, race_name)
	_refresh()

# ---------- Colonne de droite : emplacements ----------

func _rebuild_slots() -> void:
	_clear_children(_slot_grid)
	var count: int = maxi(SLOT_COUNT_MIN, TowerManager.team.size() + 1)
	for i in range(count):
		_slot_grid.add_child(_build_slot(i))

func _build_slot(i: int) -> Control:
	var filled: bool = i < TowerManager.team.size()
	var selected: bool = i == _selected_index
	var border := GOLD if selected else Color(0.3, 0.26, 0.16)
	if filled and not selected:
		border = Color(0.35, 0.65, 0.45) if TowerManager.is_character_complete(i) else Color(0.8, 0.5, 0.25)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(92, 118)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := _card_style(border, Color(0.07, 0.08, 0.11, 0.95))
	style.set_corner_radius_all(6)
	style.set_content_margin_all(6)
	if selected:
		style.set_border_width_all(3)
	panel.add_theme_stylebox_override("panel", style)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_child(box)

	if filled:
		var c = TowerManager.team[i]
		var icon := TextureRect.new()
		icon.texture = _race_icon(c.race_name)
		icon.custom_minimum_size = Vector2(0, 62)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_PASS
		box.add_child(icon)
		var name_label := _make_label(c.character_name)
		name_label.add_theme_font_size_override("font_size", 12)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.clip_text = true
		name_label.mouse_filter = Control.MOUSE_FILTER_PASS
		box.add_child(name_label)
		var info := _make_label("Niv. %d" % c.level)
		info.add_theme_font_size_override("font_size", 11)
		info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		info.modulate = Color(0.8, 0.78, 0.7)
		info.mouse_filter = Control.MOUSE_FILTER_PASS
		box.add_child(info)
		var metier_code: String = c.get_current_metier_code()
		var metier_label := _make_label(metier_code if metier_code != "" else "—")
		metier_label.add_theme_font_size_override("font_size", 11)
		metier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		metier_label.modulate = Color(0.9, 0.78, 0.45)
		metier_label.mouse_filter = Control.MOUSE_FILTER_PASS
		box.add_child(metier_label)
	else:
		var center := CenterContainer.new()
		center.size_flags_vertical = Control.SIZE_EXPAND_FILL
		center.mouse_filter = Control.MOUSE_FILTER_PASS
		box.add_child(center)
		var plus := _make_label("+")
		plus.add_theme_font_size_override("font_size", 38)
		plus.modulate = Color(0.55, 0.5, 0.38) if TowerManager.points_remaining > 0 else Color(0.3, 0.3, 0.3)
		plus.mouse_filter = Control.MOUSE_FILTER_PASS
		center.add_child(plus)
		panel.tooltip_text = "Sélectionner cet emplacement (choisis ensuite une race)"
	var number := _make_label(str(i + 1))
	number.add_theme_font_size_override("font_size", 11)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number.modulate = Color(0.7, 0.62, 0.4)
	number.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_child(number)

	panel.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_selected_index = mini(i, TowerManager.team.size())
			_refresh()
	)
	return panel

# ---------- Colonne centrale : fiche du personnage ----------

func _rebuild_center() -> void:
	_clear_children(_center_box)
	var index: int = _selected_index
	var c = _selected_character()
	if c == null:
		var hint := _make_label("Choisis une race dans la liste de gauche\npour créer le personnage de cet emplacement.")
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hint.modulate = Color(0.7, 0.66, 0.55)
		hint.size_flags_vertical = Control.SIZE_EXPAND_FILL
		hint.custom_minimum_size = Vector2(0, 240)
		_center_box.add_child(hint)
		return

	_center_box.add_child(_build_card_header(index))

	var race = RaceDatabase.build(c.race_name)
	var race_line := _make_label(race.get_display_text() if race != null else c.race_name)
	race_line.add_theme_font_size_override("font_size", 12)
	race_line.modulate = Color(0.8, 0.75, 0.6)
	_center_box.add_child(race_line)

	# PV / EA de départ du personnage (race, métiers, niveaux) ; détail au survol.
	var progression: Dictionary = TowerManager.get_hp_ea_progression(index)
	var vitals := _make_label("PV : %d     EA : %d" % [progression["hp"], progression["ea"]])
	vitals.add_theme_font_size_override("font_size", 14)
	vitals.add_theme_color_override("font_color", Color(0.95, 0.85, 0.6))
	vitals.mouse_filter = Control.MOUSE_FILTER_STOP
	vitals.tooltip_text = str(progression["detail"])
	_center_box.add_child(vitals)

	var main := HBoxContainer.new()
	main.add_theme_constant_override("separation", 12)
	_center_box.add_child(main)

	# Portrait : illustration de la race si elle existe, sinon le token en grand.
	var portrait_frame := PanelContainer.new()
	portrait_frame.custom_minimum_size = Vector2(204, 0)
	portrait_frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	portrait_frame.add_theme_stylebox_override("panel", _panel_style(GOLD_DIM, 6, 6))
	main.add_child(portrait_frame)
	var portrait := TextureRect.new()
	var art := _get_race_texture(c.race_name)
	portrait.texture = art if art != null else _race_icon(c.race_name)
	portrait.custom_minimum_size = Vector2(190, 183 if art != null else 178)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait_frame.add_child(portrait)

	var side := VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.add_theme_constant_override("separation", 6)
	main.add_child(side)
	side.add_child(_build_level_row(index))
	side.add_child(HSeparator.new())
	side.add_child(_build_stats_block(index))

	_center_box.add_child(HSeparator.new())
	_center_box.add_child(_build_metier_block(index))
	_center_box.add_child(HSeparator.new())
	_center_box.add_child(_build_abilities_block(index))
	_center_box.add_child(HSeparator.new())
	_center_box.add_child(_build_equipment_block(index))
	_constrain_width(_center_box)

# Aucun texte ne doit pouvoir élargir la carte : un Label posé directement
# dans une colonne passe à la ligne s'il est trop long, les autres sont
# coupés (l'infobulle donne le texte complet).
func _constrain_width(node: Node) -> void:
	for child in node.get_children():
		if child is Label:
			var label := child as Label
			if node is VBoxContainer:
				if label.autowrap_mode == TextServer.AUTOWRAP_OFF:
					label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			elif label.size_flags_horizontal & Control.SIZE_EXPAND:
				label.clip_text = true
		_constrain_width(child)

# Nom (modifiable) et retrait du personnage.
func _build_card_header(index: int) -> Control:
	var c = TowerManager.team[index]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	var name_edit := LineEdit.new()
	name_edit.text = c.character_name
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.text_submitted.connect(func(new_text): _on_name_changed(index, new_text))
	name_edit.focus_exited.connect(func():
		if is_instance_valid(name_edit):
			_on_name_changed(index, name_edit.text)
	)
	row.add_child(name_edit)

	var remove_btn := Button.new()
	remove_btn.text = "✕"
	remove_btn.tooltip_text = "Retirer ce personnage (récupère ses points et son équipement)"
	remove_btn.pressed.connect(func():
		TowerManager.remove_character(index)
		_refresh()
	)
	row.add_child(remove_btn)
	return row

# Illustration de la race si le fichier existe (voir RACE_IMAGE_DIR), sinon null.
func _get_race_texture(race_name: String) -> Texture2D:
	var slug := _normalize_text(race_name).replace(" ", "_")
	var path := "%s%s.png" % [RACE_IMAGE_DIR, slug]
	if ResourceLoader.exists(path):
		var resource = load(path)
		if resource is Texture2D:
			return resource
	return null

# Niveau, avec - / +. Chaque niveau coûte 1 point du total (les 16 de
# l'équipe). Les niveaux 2, 5 et 8 donnent AUSSI 1 point de
# caractéristique et relèvent la limite des stats, rappelée dessous.
func _build_level_row(index: int) -> Control:
	var c = TowerManager.team[index]

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	box.add_child(row)

	var label := Label.new()
	label.text = "Niveau %d" % c.level
	label.add_theme_font_size_override("font_size", 16)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)

	var down := Button.new()
	down.text = "−"
	down.custom_minimum_size = Vector2(34, 0)
	down.disabled = not TowerManager.can_level_down(index)
	if down.disabled and c.level > 1:
		down.tooltip_text = TowerManager.get_level_down_block_reason(index)
	down.pressed.connect(func():
		TowerManager.level_down(index)
		_refresh()
	)
	row.add_child(down)

	var up := Button.new()
	up.text = "+"
	up.custom_minimum_size = Vector2(34, 0)
	up.disabled = not TowerManager.can_level_up(index)
	if not up.disabled:
		var next_level: int = c.level + 1
		var gained_points: int = TowerManager.get_level_bonus_points(next_level) - TowerManager.get_level_bonus_points(c.level)
		var tip := "Monter d'un niveau (coûte 1 point)"
		if gained_points > 0:
			tip += " : +%d point(s) de caractéristique, limite des stats %d" % [gained_points, TowerManager.get_level_stat_cap(next_level)]
		up.tooltip_text = tip
	elif c.level >= TowerManager.MAX_LEVEL:
		up.tooltip_text = "Niveau maximum"
	else:
		up.tooltip_text = "Plus aucun point disponible"
	up.pressed.connect(func():
		TowerManager.level_up(index)
		_refresh()
	)
	row.add_child(up)

	# Rappel de la limite des caractéristiques à ce niveau (et des stats
	# que la race en exempte).
	var caption := Label.new()
	var exempt_names: Array = []
	for stat in TowerManager.STAT_KEYS:
		if TowerManager.get_stat_level_cap(index, stat) < 0:
			exempt_names.append(TowerManager.STAT_LABELS[stat])
	if exempt_names.size() == TowerManager.STAT_KEYS.size():
		caption.text = "Aucune limite de niveau sur les caractéristiques"  # Humain.
	else:
		caption.text = "Limite des caractéristiques : %d" % TowerManager.get_level_stat_cap(c.level)
		if not exempt_names.is_empty():
			caption.text += " (%s : aucune)" % ", ".join(exempt_names)
	caption.add_theme_font_size_override("font_size", 11)
	caption.modulate = Color(0.75, 0.75, 0.8)
	box.add_child(caption)
	return box

# Caractéristiques : valeur actuelle, - / +, et points restant à répartir
# (sur 19 par personnage ; les stats partent de 8, la chance de 1). Un
# MINIMUM imposé par la race s'affiche "min N" (la stat part de là, sans
# pouvoir descendre dessous, l'écart déjà décompté des points), un
# MAXIMUM "max N" (la stat ne peut pas le dépasser).
func _build_stats_block(index: int) -> Control:
	var c = TowerManager.team[index]
	var unspent: int = TowerManager.get_stat_points_unspent(index)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)

	var title := Label.new()
	title.text = "Caractéristiques — %d / %d point(s) à répartir" % [unspent, TowerManager.get_stat_pool(index)]
	title.tooltip_text = TowerManager.get_stat_pool_breakdown(index)
	title.mouse_filter = Control.MOUSE_FILTER_PASS
	title.add_theme_font_size_override("font_size", 13)
	title.modulate = Color(1.0, 0.85, 0.4) if unspent > 0 else Color(0.7, 0.7, 0.75)
	box.add_child(title)

	for stat in TowerManager.STAT_KEYS:
		var allocated: int = int(c.stat_points.get(stat, 0))
		var value: int = TowerManager.get_stat_value(index, stat)
		var floor_value: int = TowerManager.get_race_stat_floor(c.race_name, stat)
		var cap_value: int = TowerManager.get_race_stat_cap(c.race_name, stat)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)

		var name_label := Label.new()
		name_label.text = TowerManager.STAT_LABELS[stat]
		name_label.custom_minimum_size = Vector2(88, 0)
		row.add_child(name_label)

		# Rappel des contraintes propres à cette stat : minimum/maximum de
		# race, et absence de limite de niveau (Ogre, en Force).
		var level_cap_value: int = TowerManager.get_stat_level_cap(index, stat)
		var hint_parts: Array = []
		var hint_tips: Array = []
		if floor_value > 0:
			hint_parts.append("min %d" % floor_value)
			hint_tips.append("Minimum imposé par la race : %d (l'écart avec la valeur par défaut est déjà décompté des points)" % floor_value)
		elif cap_value >= 0:
			hint_parts.append("max %d" % cap_value)
			hint_tips.append("Maximum imposé par la race : %d" % cap_value)
		if level_cap_value < 0:
			hint_parts.append("illimité")
			hint_tips.append("Cette race n'est pas limitée sur cette caractéristique par son niveau")

		var hint := Label.new()
		hint.text = " · ".join(hint_parts)
		hint.tooltip_text = "\n".join(hint_tips)
		hint.add_theme_font_size_override("font_size", 11)
		hint.modulate = Color(0.95, 0.7, 0.35)
		hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hint.clip_text = true  # Ne doit jamais élargir la carte ; l'infobulle donne le texte complet.
		hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		hint.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_child(hint)

		var value_label := Label.new()
		value_label.text = str(value)
		value_label.custom_minimum_size = Vector2(28, 0)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value_label.mouse_filter = Control.MOUSE_FILTER_PASS
		var start_value: int = TowerManager.get_stat_baseline(c.race_name, stat)
		if floor_value > 0:
			value_label.tooltip_text = "Départ %d (minimum de la race) + %d réparti(s)" % [start_value, allocated]
		else:
			value_label.tooltip_text = "Départ %d + %d réparti(s)" % [start_value, allocated]
		if level_cap_value >= 0:
			value_label.tooltip_text += "\nLimite du niveau : %d" % level_cap_value
		row.add_child(value_label)

		var minus := Button.new()
		minus.text = "−"
		minus.custom_minimum_size = Vector2(30, 0)
		minus.disabled = not TowerManager.can_decrease_stat(index, stat)
		if minus.disabled:
			minus.tooltip_text = TowerManager.get_stat_decrease_block_reason(index, stat)
		minus.pressed.connect(func():
			TowerManager.decrease_stat(index, stat)
			_refresh()
		)
		row.add_child(minus)

		var plus := Button.new()
		plus.text = "+"
		plus.custom_minimum_size = Vector2(30, 0)
		plus.disabled = not TowerManager.can_increase_stat(index, stat)
		if plus.disabled:
			plus.tooltip_text = TowerManager.get_stat_increase_block_reason(index, stat)
		plus.pressed.connect(func():
			TowerManager.increase_stat(index, stat)
			_refresh()
		)
		row.add_child(plus)

		box.add_child(row)
	return box

# Métier de base (niveau 1) puis les métiers de niveau 4 / 7 / 10.
# Aperçu des sorts et compétences du personnage (race + métiers + niveau),
# d'après une unité de combat temporaire construite comme en combat.
func _build_abilities_block(index: int) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var title := Label.new()
	title.text = "Sorts et compétences"
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", GOLD)
	box.add_child(title)

	var character = TowerManager.team[index]
	var unit := CombatUnit.new()
	unit.team = CombatUnit.Team.PLAYER
	unit.unit_name = character.character_name
	unit.spells = []
	unit.equipped_race = RaceDatabase.build(character.race_name)
	var chain: Array = TowerManager.get_metier_chain_codes(index)
	if not chain.is_empty():
		unit.equipped_metier = MetierDatabase.build(str(chain.back()))
		var top_first: Array = chain.duplicate()
		top_first.reverse()
		unit.forced_metier_chain = top_first
	unit.level = character.level
	unit.pretre_order = character.pretre_order
	unit.base_courage = TowerManager.get_stat_value(index, "courage")
	unit.base_intelligence_stat = TowerManager.get_stat_value(index, "intelligence")
	unit.base_charisme_stat = TowerManager.get_stat_value(index, "charisme")
	unit.base_adresse_stat = TowerManager.get_stat_value(index, "adresse")
	unit.base_force_stat = TowerManager.get_stat_value(index, "force")
	unit.base_chance_stat = TowerManager.get_stat_value(index, "chance")
	add_child(unit)  # Déclenche _ready() : sorts de race et de métiers.
	unit.visible = false

	var skill_codes: Array = unit.get_skill_codes()
	var spell_list: Array = []
	for sp in unit.spells:
		if not sp.is_weapon_attack:
			spell_list.append(sp)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 170)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 2)
	scroll.add_child(inner)

	var seen: Dictionary = {}
	var sk_count := 0
	for code in skill_codes:
		var skill = SkillDatabase.build(code)
		if skill == null:
			continue
		sk_count += 1
		var l := Label.new()
		l.text = "• " + skill.skill_name
		l.add_theme_font_size_override("font_size", 12)
		l.modulate = Color(0.75, 0.85, 0.75)
		l.mouse_filter = Control.MOUSE_FILTER_STOP
		l.tooltip_text = skill.get_tooltip_text()
		inner.add_child(l)
	if sk_count > 0 and not spell_list.is_empty():
		inner.add_child(HSeparator.new())
	for sp in spell_list:
		if seen.has(sp.spell_name):
			continue
		seen[sp.spell_name] = true
		var l2 := Label.new()
		l2.text = "✦ " + sp.spell_name
		l2.add_theme_font_size_override("font_size", 12)
		l2.modulate = Color(0.9, 0.85, 0.7)
		l2.mouse_filter = Control.MOUSE_FILTER_STOP
		l2.tooltip_text = sp.get_tooltip_text(unit)
		inner.add_child(l2)
	if sk_count == 0 and spell_list.is_empty():
		var none := Label.new()
		none.text = "Aucun sort ni compétence spéciale."
		none.add_theme_font_size_override("font_size", 12)
		none.modulate = Color(0.6, 0.6, 0.6)
		inner.add_child(none)

	unit.queue_free()
	return box

func _build_metier_block(index: int) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)

	var caption := Label.new()
	caption.text = "Métier"
	caption.add_theme_font_size_override("font_size", 13)
	box.add_child(caption)
	box.add_child(_build_metier_row(index, 1))

	var caption_more := Label.new()
	caption_more.text = "Autres métiers"
	caption_more.add_theme_font_size_override("font_size", 13)
	box.add_child(caption_more)
	for threshold in [4, 7, 10]:
		box.add_child(_build_metier_row(index, threshold))
	if TowerManager.has_pretre(index):
		box.add_child(_build_pretre_order_row(index))
	return box

# Choix de l'Ordre du Prêtre (une fois le métier choisi).
func _build_pretre_order_row(index: int) -> Control:
	var c = TowerManager.team[index]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var label := Label.new()
	label.text = "Ordre"
	label.custom_minimum_size = Vector2(46, 0)
	label.add_theme_font_size_override("font_size", 12)
	label.modulate = Color(0.75, 0.75, 0.8)
	row.add_child(label)
	var opt := OptionButton.new()
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opt.clip_text = true
	opt.fit_to_longest_item = false
	var orders := ["Ordre de l'harmonie", "Ordre du néant", "Ordre du cycle éternel"]
	for o in orders:
		opt.add_item(o)
	opt.selected = maxi(0, orders.find(c.pretre_order))
	opt.item_selected.connect(func(i):
		TowerManager.set_pretre_order(index, orders[i])
		_refresh()
	)
	row.add_child(opt)
	return row

func _build_metier_row(index: int, threshold: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	var level_label := Label.new()
	level_label.text = "Niv. %d" % threshold
	level_label.custom_minimum_size = Vector2(46, 0)
	level_label.add_theme_font_size_override("font_size", 12)
	level_label.modulate = Color(0.75, 0.75, 0.8)
	row.add_child(level_label)

	row.add_child(_build_metier_option(index, threshold))
	return row

# Liste déroulante du métier d'un palier (1, 4, 7 ou 10). Les métiers
# interdits à la race n'y figurent pas ; ceux dont les caractéristiques
# ne suffisent pas y sont GRISÉS, avec ce qu'il leur manque. Désactivée
# (avec la raison en texte) tant que le palier n'est pas atteignable.
func _build_metier_option(index: int, threshold: int) -> OptionButton:
	var c = TowerManager.team[index]

	var current := ""
	var choices: Array = []
	var disabled_reason := ""
	match threshold:
		1:
			current = c.metier_code_l1
			choices = TowerManager.get_base_metier_choices(index)
		4:
			current = c.metier_code_l4
		7:
			current = c.metier_code_l7
		10:
			current = c.metier_code_l10
	if threshold > 1:
		if c.level < threshold:
			disabled_reason = "Niveau %d requis" % threshold
		elif TowerManager.get_previous_tier_metier_code(index, threshold) == "":
			disabled_reason = "Choisis d'abord le métier précédent"
		else:
			choices = TowerManager.get_evolution_choices(index, threshold)
			if choices.is_empty():
				disabled_reason = "Aucune évolution"

	var opt := OptionButton.new()
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opt.clip_text = true  # Un nom long ne doit pas élargir la carte.
	opt.fit_to_longest_item = false  # Par défaut la liste prend la largeur de son plus long choix : c'est ce qui élargissait la carte.
	opt.add_item("— Aucun —")
	opt.set_item_metadata(0, "")

	if disabled_reason != "":
		opt.set_item_text(0, disabled_reason)
		opt.disabled = true
		return opt

	var selected_idx := 0
	for choice in choices:
		var label: String = choice["name"]
		if not choice["available"]:
			label += "  (%s)" % choice["missing"]
		opt.add_item(label)
		var item_idx: int = opt.item_count - 1
		opt.set_item_metadata(item_idx, choice["code"])
		if not choice["available"]:
			opt.set_item_disabled(item_idx, true)
		if choice["code"] == current:
			selected_idx = item_idx
	opt.selected = selected_idx

	opt.item_selected.connect(func(item_idx):
		var chosen_code := str(opt.get_item_metadata(item_idx))
		var refusal: String = TowerManager.get_set_metier_block_reason(index, threshold, chosen_code)
		if refusal != "":
			_notice = refusal  # Refusé : la liste se reconstruit sur le choix actuel, et le message s'affiche.
		else:
			TowerManager.set_metier(index, threshold, chosen_code)
		_refresh()
	)
	return opt

# Résumé de l'équipement porté + accès à la boutique.
func _build_equipment_block(index: int) -> Control:
	var c = TowerManager.team[index]
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)

	var caption := Label.new()
	caption.text = "Équipement"
	caption.add_theme_font_size_override("font_size", 13)
	box.add_child(caption)

	box.add_child(_gear_line("Arme", c.equipped_weapon.weapon_name if c.equipped_weapon != null else ""))
	if TowerManager.can_dual_wield(index):
		box.add_child(_gear_line("2e arme", c.equipped_off_hand.weapon_name if c.equipped_off_hand != null else ""))
	# Un emplacement par ligne : les 5 pièces d'armure, puis le bouclier, à part.
	for piece_slot in EquipmentRules.ARMOR_SLOTS + [EquipmentRules.SHIELD_SLOT]:
		var piece = c.equipped_armor.get(piece_slot)
		box.add_child(_gear_line(EquipmentRules.SLOT_LABELS[piece_slot], piece.armor_name if piece != null else ""))
	var accessory_names: Array = []
	for acc in c.equipped_accessories:
		if acc != null:
			accessory_names.append(acc.accessory_name)
	box.add_child(_gear_line("Accessoires", ", ".join(accessory_names)))

	# Armes de réserve : emportées au combat, équipées au double-clic.
	if not c.spare_weapons.is_empty():
		var spare_title := Label.new()
		spare_title.text = "Réserve (%d)" % c.spare_weapons.size()
		spare_title.add_theme_font_size_override("font_size", 12)
		box.add_child(spare_title)
		for i in range(c.spare_weapons.size()):
			var spare_row := HBoxContainer.new()
			var spare_label := Label.new()
			spare_label.text = "  %s (%d PO)" % [c.spare_weapons[i].weapon_name, c.spare_weapons[i].price]
			spare_label.add_theme_font_size_override("font_size", 12)
			spare_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			spare_row.add_child(spare_label)
			var sell_btn := Button.new()
			sell_btn.text = "Vendre"
			sell_btn.custom_minimum_size = Vector2(64, 0)
			var spare_index: int = i
			sell_btn.pressed.connect(func():
				TowerManager.sell_spare_weapon(index, spare_index)
				_refresh()
			)
			spare_row.add_child(sell_btn)
			box.add_child(spare_row)

	# Pièces obligatoires du métier qui manquent encore (Gladiateur : casque
	# et bouclier) : le personnage reste incomplet tant qu'elles manquent.
	var missing: Array = TowerManager.get_missing_equipment(index)
	if not missing.is_empty():
		var missing_label := Label.new()
		missing_label.text = "Obligatoire : %s" % ", ".join(missing)
		missing_label.add_theme_font_size_override("font_size", 12)
		missing_label.modulate = Color(0.95, 0.6, 0.35)
		missing_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(missing_label)

	var shop_btn := Button.new()
	shop_btn.text = "Acheter / équiper..."
	shop_btn.pressed.connect(func(): _open_equip_popup(index))
	box.add_child(shop_btn)
	return box

func _gear_line(title: String, value: String) -> Label:
	var line := Label.new()
	line.text = "%s : %s" % [title, value if value != "" else "—"]
	line.add_theme_font_size_override("font_size", 12)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return line

# ---------- Popup d'équipement ----------
#
# Trois onglets (Armes / Armures / Accessoires), puis des filtres :
# catégorie (propre à l'onglet), portée (armes seulement), recherche par
# nom, "abordable", et tri. Chaque ligne montre CE QU'ON ACHÈTE (dés de
# dégâts + bonus) et l'effet spécial éventuel, pas seulement un nom.

## Libellés des bonus (clés des catalogues) — l'ordre ici = l'ordre d'affichage.
const BONUS_LABELS := {
	"bonus_vie": "PV", "bonus_mana": "EA",
	"bonus_attaque": "AT", "bonus_parade": "PRD", "bonus_armure": "PR",
	"bonus_courage": "COU", "bonus_intelligence": "INT", "bonus_charisme": "CHA",
	"bonus_adresse": "AD", "bonus_force": "FO", "bonus_chance": "CHN",
}

const EQUIP_TYPES := [
	{"id": "weapons", "label": "Armes"},
	{"id": "armors", "label": "Armures"},
	{"id": "accessories", "label": "Accessoires"},
]

var _equip_type: String = "weapons"
var _equip_category: String = ""        # "" = toutes les catégories
var _equip_search: String = ""          # normalisé : minuscules, sans accents (voir _normalize_text)
var _equip_affordable_only: bool = false
var _equip_only_allowed: bool = true    # Masque ce que la race/le métier de ce personnage interdit.
var _equip_sort: int = 0                # 0 prix croissant, 1 prix décroissant, 2 nom
var _equip_range: int = 0               # 0 toutes, 1 corps à corps, 2 distance (armes)
var _equip_slot: String = ""            # "" = tous les emplacements (armures)

var _equip_type_buttons: Dictionary = {}
var _equip_category_option: OptionButton
var _equip_range_box: HBoxContainer
var _equip_range_option: OptionButton
var _equip_slot_box: HBoxContainer
var _equip_slot_option: OptionButton
var _equip_search_edit: LineEdit
var _equip_affordable_check: CheckBox
var _equip_allowed_check: CheckBox
var _equip_sort_option: OptionButton
var _equip_count_label: Label

func _build_equip_popup() -> void:
	_equip_popup = PopupPanel.new()
	add_child(_equip_popup)
	# Ferme par clic extérieur OU bouton : dans les deux cas l'écran
	# principal doit se rafraîchir (équipement affiché, or restant).
	_equip_popup.popup_hide.connect(_refresh)

	var popup_vbox := VBoxContainer.new()
	popup_vbox.add_theme_constant_override("separation", 6)
	_equip_popup.add_child(popup_vbox)

	_equip_popup_gold_label = Label.new()
	_equip_popup_gold_label.add_theme_font_size_override("font_size", 14)
	popup_vbox.add_child(_equip_popup_gold_label)

	# --- Onglets de type ---
	var type_row := HBoxContainer.new()
	type_row.add_theme_constant_override("separation", 6)
	popup_vbox.add_child(type_row)
	var type_group := ButtonGroup.new()
	for t in EQUIP_TYPES:
		var type_id: String = t["id"]
		var b := Button.new()
		b.text = t["label"]
		b.toggle_mode = true
		b.button_group = type_group
		b.button_pressed = (type_id == _equip_type)
		b.pressed.connect(func(): _on_equip_type_selected(type_id))
		type_row.add_child(b)
		_equip_type_buttons[type_id] = b

	# --- Filtres, ligne 1 : catégorie, portée ---
	var filter_row1 := HBoxContainer.new()
	filter_row1.add_theme_constant_override("separation", 8)
	popup_vbox.add_child(filter_row1)

	filter_row1.add_child(_make_label("Catégorie :"))
	_equip_category_option = OptionButton.new()
	_equip_category_option.item_selected.connect(func(i):
		_equip_category = _equip_category_option.get_item_metadata(i)
		_populate_equip_list()
	)
	filter_row1.add_child(_equip_category_option)

	_equip_range_box = HBoxContainer.new()
	_equip_range_box.add_theme_constant_override("separation", 6)
	_equip_range_box.add_child(_make_label("Portée :"))
	_equip_range_option = OptionButton.new()
	_equip_range_option.add_item("Toutes")
	_equip_range_option.add_item("Corps à corps")
	_equip_range_option.add_item("Distance")
	_equip_range_option.item_selected.connect(func(i):
		_equip_range = i
		_populate_equip_list()
	)
	_equip_range_box.add_child(_equip_range_option)
	filter_row1.add_child(_equip_range_box)

	# Armures : filtre par EMPLACEMENT (casque, plastron...). Sans lui, les 68
	# pièces de tous les matériaux se mélangent.
	_equip_slot_box = HBoxContainer.new()
	_equip_slot_box.add_theme_constant_override("separation", 6)
	_equip_slot_box.add_child(_make_label("Emplacement :"))
	_equip_slot_option = OptionButton.new()
	_equip_slot_option.add_item("Tous")
	_equip_slot_option.set_item_metadata(0, "")
	for piece_slot in EquipmentRules.ARMOR_SLOTS + [EquipmentRules.SHIELD_SLOT]:
		_equip_slot_option.add_item(EquipmentRules.SLOT_LABELS[piece_slot])
		_equip_slot_option.set_item_metadata(_equip_slot_option.item_count - 1, piece_slot)
	_equip_slot_option.item_selected.connect(func(i):
		_equip_slot = str(_equip_slot_option.get_item_metadata(i))
		_populate_equip_list()
	)
	_equip_slot_box.add_child(_equip_slot_option)
	filter_row1.add_child(_equip_slot_box)

	# --- Filtres, ligne 2 : recherche, abordable, tri ---
	var filter_row2 := HBoxContainer.new()
	filter_row2.add_theme_constant_override("separation", 8)
	popup_vbox.add_child(filter_row2)

	_equip_search_edit = LineEdit.new()
	_equip_search_edit.placeholder_text = "Rechercher un nom..."
	_equip_search_edit.custom_minimum_size = Vector2(170, 0)
	_equip_search_edit.clear_button_enabled = true
	_equip_search_edit.text_changed.connect(func(t):
		_equip_search = _normalize_text(t.strip_edges())
		_populate_equip_list()
	)
	filter_row2.add_child(_equip_search_edit)

	_equip_affordable_check = CheckBox.new()
	_equip_affordable_check.text = "Abordable"
	_equip_affordable_check.toggled.connect(func(pressed):
		_equip_affordable_only = pressed
		_populate_equip_list()
	)
	filter_row2.add_child(_equip_affordable_check)

	_equip_allowed_check = CheckBox.new()
	_equip_allowed_check.text = "Équipables"
	_equip_allowed_check.tooltip_text = "Masque ce que la race ou le métier de ce personnage interdit. Décochée : ces objets restent visibles, grisés, avec la raison."
	_equip_allowed_check.button_pressed = true
	_equip_allowed_check.toggled.connect(func(pressed):
		_equip_only_allowed = pressed
		_rebuild_category_options()  # Les effectifs par catégorie suivent ce qui est visible.
		_populate_equip_list()
	)
	filter_row2.add_child(_equip_allowed_check)

	filter_row2.add_child(_make_label("Tri :"))
	_equip_sort_option = OptionButton.new()
	_equip_sort_option.add_item("Prix croissant")
	_equip_sort_option.add_item("Prix décroissant")
	_equip_sort_option.add_item("Nom (A-Z)")
	_equip_sort_option.item_selected.connect(func(i):
		_equip_sort = i
		_populate_equip_list()
	)
	filter_row2.add_child(_equip_sort_option)

	# --- Compteur + liste ---
	_equip_count_label = Label.new()
	_equip_count_label.add_theme_font_size_override("font_size", 12)
	_equip_count_label.modulate = Color(0.75, 0.75, 0.8)
	popup_vbox.add_child(_equip_count_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(580, 260)
	popup_vbox.add_child(scroll)

	_equip_popup_content = VBoxContainer.new()
	_equip_popup_content.add_theme_constant_override("separation", 4)
	_equip_popup_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_equip_popup_content)

	var close_btn := Button.new()
	close_btn.text = "Fermer"
	close_btn.pressed.connect(func(): _equip_popup.hide())
	popup_vbox.add_child(close_btn)

func _open_equip_popup(index: int) -> void:
	_equip_popup_index = index
	_equip_type = "weapons"
	_equip_type_buttons["weapons"].set_pressed_no_signal(true)
	_reset_equip_filters()
	_populate_equip_list()
	# Taille bornée par la fenêtre : 700x640 déborderait d'un écran de 648 px.
	var vp := get_viewport_rect().size
	_equip_popup.popup_centered(Vector2i(int(min(700.0, vp.x - 40.0)), int(min(640.0, vp.y - 40.0))))

func _on_equip_type_selected(type_id: String) -> void:
	if type_id == _equip_type:
		return
	_equip_type = type_id
	_reset_equip_filters()
	_populate_equip_list()

# Remet tous les filtres à zéro et reconstruit la liste des catégories
# pour le type courant (les catégories d'armes n'ont rien à voir avec
# celles d'armures) — appelé à l'ouverture et à chaque changement d'onglet.
func _reset_equip_filters() -> void:
	_equip_category = ""
	_equip_search = ""
	_equip_affordable_only = false
	_equip_only_allowed = true
	_equip_sort = 0
	_equip_range = 0
	_equip_slot = ""
	_equip_slot_option.select(0)
	_equip_search_edit.text = ""
	_equip_affordable_check.set_pressed_no_signal(false)
	_equip_allowed_check.set_pressed_no_signal(true)
	_equip_sort_option.select(0)
	_equip_range_option.select(0)
	_equip_range_box.visible = (_equip_type == "weapons")
	_equip_slot_box.visible = (_equip_type == "armors")
	_rebuild_category_options()

# Pourquoi le personnage du popup ne peut pas équiper cet objet ("" = il peut).
func _equip_block_reason(data: Dictionary) -> String:
	return TowerManager.get_equipment_block_reason(_equip_popup_index, _equip_type, data)

# Reconstruit la liste des catégories du type courant, avec le nombre
# d'objets VISIBLES : sans ceux que la race ou le métier interdisent tant
# que « Équipables » est coché (sinon « Arbalètes (8) » promettrait 8
# objets là où il n'y en a aucun).
func _rebuild_category_options() -> void:
	_equip_category = ""
	var items: Array = []
	for data in _get_equip_items():
		if not _equip_only_allowed or _equip_block_reason(data) == "":
			items.append(data)

	var counts: Dictionary = {}
	var order: Array = []
	for data in items:
		var cat: String = str(data.get("category", ""))
		if cat == "":
			continue
		if not counts.has(cat):
			counts[cat] = 0
			order.append(cat)  # Ordre du catalogue conservé : regroupe naturellement les familles proches.
		counts[cat] += 1

	_equip_category_option.clear()
	_equip_category_option.add_item("Toutes (%d)" % items.size())
	_equip_category_option.set_item_metadata(0, "")
	for cat in order:
		_equip_category_option.add_item("%s (%d)" % [cat, counts[cat]])
		_equip_category_option.set_item_metadata(_equip_category_option.item_count - 1, cat)
	_equip_category_option.select(0)

# Minuscules SANS accents, pour que "epee" comme "épée" trouvent
# "Epée pérave" (les noms du catalogue mélangent majuscules accentuées
# ou non, ex: "Epée" sans accent sur le E).
func _normalize_text(s: String) -> String:
	var result := s.to_lower()
	for pair in [["é", "e"], ["è", "e"], ["ê", "e"], ["ë", "e"], ["à", "a"], ["â", "a"], ["ä", "a"],
			["î", "i"], ["ï", "i"], ["ô", "o"], ["ö", "o"], ["ù", "u"], ["û", "u"], ["ü", "u"],
			["ç", "c"], ["œ", "oe"]]:
		result = result.replace(pair[0], pair[1])
	return result

func _get_equip_items() -> Array:
	match _equip_type:
		"weapons":
			return WeaponCatalog.get_all()
		"armors":
			return ArmorCatalog.get_all()
	return AccessoryCatalog.get_all()

func _build_item_from_data(data: Dictionary):
	match _equip_type:
		"weapons":
			return ShopGenerator.build_weapon_from_data(data)
		"armors":
			return ShopGenerator.build_armor_from_data(data)
	return ShopGenerator.build_accessory_from_data(data)

# Objets du type courant qui passent TOUS les filtres, triés.
func _filter_equip_items() -> Array:
	var result: Array = []
	for data in _get_equip_items():
		if _equip_category != "" and str(data.get("category", "")) != _equip_category:
			continue
		if _equip_type == "weapons" and _equip_range != 0:
			var is_ranged: bool = str(data.get("weapon_type", "melee")) == "ranged"
			if (_equip_range == 1 and is_ranged) or (_equip_range == 2 and not is_ranged):
				continue
		if _equip_type == "armors" and _equip_slot != "" and EquipmentRules.get_armor_slot(data) != _equip_slot:
			continue
		if _equip_search != "" and not _normalize_text(str(data.get("name", ""))).contains(_equip_search):
			continue
		if _equip_affordable_only and not TowerManager.can_afford(_equip_popup_index, _equip_type, int(data.get("price", 0)), data):
			continue
		if _equip_only_allowed and _equip_block_reason(data) != "":
			continue
		result.append(data)

	result.sort_custom(func(a, b):
		var pa: int = int(a.get("price", 0))
		var pb: int = int(b.get("price", 0))
		var na: String = str(a.get("name", ""))
		var nb: String = str(b.get("name", ""))
		match _equip_sort:
			1:
				return pa > pb if pa != pb else na < nb
			2:
				return na < nb
		return pa < pb if pa != pb else na < nb
	)
	return result

func _populate_equip_list() -> void:
	if _equip_popup_index < 0 or _equip_popup_index >= TowerManager.team.size():
		return
	var c = TowerManager.team[_equip_popup_index]
	_equip_popup_gold_label.text = "%s — Or disponible : %d PO" % [c.character_name, TowerManager.gold]

	for child in _equip_popup_content.get_children():
		child.queue_free()

	var items := _filter_equip_items()
	_equip_count_label.text = "%d objet(s)" % items.size()
	if items.is_empty():
		var empty := Label.new()
		empty.text = "Aucun objet ne correspond à ces filtres."
		empty.modulate = Color(0.8, 0.7, 0.5)
		_equip_popup_content.add_child(empty)
		return
	for data in items:
		_equip_popup_content.add_child(_build_equip_row(data, c))

# Vrai si le personnage porte déjà un objet de ce nom dans le slot courant.
# Vrai si ces deux entrées de catalogue sont le même objet (nom ET catégorie).
func _same_catalog_item(a: Dictionary, b: Dictionary) -> bool:
	return str(a.get("name", "")) == str(b.get("name", "")) and str(a.get("category", "")) == str(b.get("category", ""))

func _is_equipped(c, item_name: String) -> bool:
	match _equip_type:
		"weapons":
			return (c.equipped_weapon != null and c.equipped_weapon.weapon_name == item_name) \
				or (c.equipped_off_hand != null and c.equipped_off_hand.weapon_name == item_name)
		"armors":
			for piece in c.equipped_armor.values():
				if piece != null and piece.armor_name == item_name:
					return true
			return false
	for acc in c.equipped_accessories:
		if acc != null and acc.accessory_name == item_name:
			return true
	return false

# Résumé compact de ce qu'apporte l'objet : dés de dégâts (armes) puis
# tous les bonus non nuls, ex: "1D+3  +1 AD  -1 PRD".
func _format_item_stats(data: Dictionary) -> String:
	var parts: Array = []
	if _equip_type == "weapons":
		var dice := int(data.get("dice_count", 0))
		var modifier := int(data.get("dice_modifier", 0))
		if dice > 0:
			parts.append(("%dD%+d" % [dice, modifier]) if modifier != 0 else ("%dD" % dice))
		else:
			parts.append(str(modifier))  # Pas de dés : valeur fixe.
	elif _equip_type == "armors":
		var piece_slot: String = EquipmentRules.get_armor_slot(data)
		if piece_slot != "":
			parts.append(EquipmentRules.SLOT_LABELS[piece_slot])
	for key in BONUS_LABELS:
		var value := int(data.get(key, 0))
		if value != 0:
			parts.append("%+d %s" % [value, BONUS_LABELS[key]])
	return "  ".join(parts)

# Une ligne d'objet : nom, bonus, prix, bouton ; puis l'effet spécial
# (champ "info" du catalogue) en petit dessous, s'il y en a un.
func _build_equip_row(data: Dictionary, c) -> Control:
	var price := int(data.get("price", 0))
	var item_name := str(data.get("name", "?"))
	var is_equipped := _is_equipped(c, item_name)
	var block_reason: String = _equip_block_reason(data)  # Restriction de race/métier.

	# Armes : on distingue les deux mains. Comparaison par nom ET catégorie,
	# car deux catégories portent des noms identiques ("Hache pérave").
	var in_main_hand := false
	var in_off_hand := false
	var dual_wield := false
	if _equip_type == "weapons":
		in_main_hand = c.equipped_weapon != null and _same_catalog_item(c.equipped_weapon_data, data)
		in_off_hand = c.equipped_off_hand != null and _same_catalog_item(c.equipped_off_hand_data, data)
		is_equipped = in_main_hand or in_off_hand
		dual_wield = TowerManager.can_dual_wield(_equip_popup_index)

	# Accessoires : on peut en porter 2, racheter le même n'est pas absurde.
	var blocked_as_duplicate: bool = in_main_hand if _equip_type == "weapons" else (is_equipped and _equip_type != "accessories")

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)

	var name_label := Label.new()
	name_label.text = ("✔ " if is_equipped else "") + item_name
	name_label.custom_minimum_size = Vector2(170, 0)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.mouse_filter = Control.MOUSE_FILTER_PASS  # Pour que l'infobulle (nom complet) s'affiche.
	name_label.tooltip_text = item_name
	if is_equipped:
		name_label.modulate = Color(0.55, 0.9, 0.55)
	elif block_reason != "":
		name_label.modulate = Color(0.6, 0.6, 0.6)
	row.add_child(name_label)

	var stats_label := Label.new()
	stats_label.text = _format_item_stats(data)
	stats_label.add_theme_font_size_override("font_size", 12)
	stats_label.modulate = Color(0.8, 0.85, 0.95)
	row.add_child(stats_label)

	var price_label := Label.new()
	price_label.text = "%d PO" % price
	price_label.custom_minimum_size = Vector2(72, 0)
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(price_label)

	var buy_btn := Button.new()
	var main_label := "Main" if dual_wield else "Acheter"
	buy_btn.text = "Équipé" if blocked_as_duplicate else ("Interdit" if block_reason != "" else main_label)
	buy_btn.custom_minimum_size = Vector2(76, 0)
	buy_btn.disabled = blocked_as_duplicate or block_reason != "" or not TowerManager.can_afford(_equip_popup_index, _equip_type, price, data, "main")
	if block_reason != "":
		buy_btn.tooltip_text = "Interdit — " + block_reason
	elif dual_wield:
		buy_btn.tooltip_text = "Équiper dans la main principale"
	buy_btn.pressed.connect(func():
		var item = _build_item_from_data(data)
		if TowerManager.buy_and_equip(_equip_popup_index, item, data, "main"):
			_populate_equip_list()
	)
	row.add_child(buy_btn)

	# Personnage à deux armes (Ambidextrie, ou Pirate) : un second bouton
	# pour la seconde main, avec la raison quand elle est refusée.
	if dual_wield:
		var off_reason: String = TowerManager.get_off_hand_block_reason(_equip_popup_index, data)
		var off_btn := Button.new()
		off_btn.text = "Équipé" if in_off_hand else ("Interdit" if block_reason != "" else "2e main")
		off_btn.custom_minimum_size = Vector2(76, 0)
		off_btn.disabled = in_off_hand or block_reason != "" or off_reason != "" or not TowerManager.can_afford(_equip_popup_index, _equip_type, price, data, "off_hand")
		if block_reason != "":
			off_btn.tooltip_text = "Interdit — " + block_reason
		elif off_reason != "":
			off_btn.tooltip_text = off_reason
		else:
			off_btn.tooltip_text = "Équiper dans la seconde main"
		off_btn.pressed.connect(func():
			var off_item = _build_item_from_data(data)
			if TowerManager.buy_and_equip(_equip_popup_index, off_item, data, "off_hand"):
				_populate_equip_list()
		)
		row.add_child(off_btn)

	# Armes : un bouton pour en acheter autant que voulu en RÉSERVE (inventaire de
	# combat, équipables au double-clic pendant le combat).
	if _equip_type == "weapons":
		var spare_btn := Button.new()
		spare_btn.text = "+ Sac"
		spare_btn.custom_minimum_size = Vector2(64, 0)
		spare_btn.disabled = block_reason != "" or TowerManager.gold < price
		spare_btn.tooltip_text = "Acheter en réserve (autant que tu veux) : équipable pendant le combat."
		spare_btn.pressed.connect(func():
			var spare_item = _build_item_from_data(data)
			if TowerManager.buy_spare_weapon(_equip_popup_index, spare_item, data):
				_populate_equip_list()
		)
		row.add_child(spare_btn)

	if block_reason != "":
		var block_label := Label.new()
		block_label.text = "      Interdit — " + block_reason
		block_label.add_theme_font_size_override("font_size", 11)
		block_label.modulate = Color(0.95, 0.6, 0.35)
		box.add_child(block_label)

	var info := str(data.get("info", ""))
	if info != "":
		var info_label := Label.new()
		info_label.text = "      " + info
		info_label.add_theme_font_size_override("font_size", 11)
		info_label.modulate = Color(0.7, 0.7, 0.75)
		info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # Un effet long passe à la ligne au lieu d'être coupé.
		info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_child(info_label)

	return box

# ---------- Signaux divers ----------

func _on_name_changed(index: int, new_text: String) -> void:
	if index < 0 or index >= TowerManager.team.size():
		return  # Personnage retiré entre-temps (carte reconstruite).
	if new_text.strip_edges() != "":
		TowerManager.team[index].character_name = new_text.strip_edges()

func _on_add_character_pressed() -> void:
	TowerManager.add_character()
	_refresh()

func _on_validate_pressed() -> void:
	if not TowerManager.is_team_ready():
		return
	# Lance l'ascension : étage 1, dans la scène de combat (voir
	# TowerManager.start_run). En cas de problème (étages absents, scène
	# introuvable), rien n'est démarré et la raison s'affiche sous les cartes.
	var error: String = TowerManager.start_run()
	if error != "":
		_notice = error
		_refresh()
		return
	_validate_button.disabled = true  # Un second clic relancerait le changement de scène.

# ---------- Sauvegarde / chargement ----------

func _build_save_popup() -> void:
	_save_popup = PopupPanel.new()
	add_child(_save_popup)
	_save_popup_box = VBoxContainer.new()
	_save_popup_box.add_theme_constant_override("separation", 8)
	_save_popup_box.custom_minimum_size = Vector2(640, 0)
	_save_popup.add_child(_save_popup_box)
	_save_popup.popup_hide.connect(func(): _pending_overwrite_slot = -1)

# Bouton « Continuer l'ascension » : visible seulement s'il existe une
# sauvegarde automatique d'ascension.
func _update_continue_button() -> void:
	if _continue_button == null:
		return
	var info: Dictionary = TowerSave.summary(TowerSave.AUTO_SLOT)
	var resumable: bool = not info.is_empty() and str(info.get("phase", "")) == "run"
	_continue_button.visible = resumable
	if resumable:
		_continue_button.text = "Continuer l'ascension (étage %d)" % int(info.get("floor", 1))

# Texte de présentation d'un emplacement.
func _slot_description(info: Dictionary) -> String:
	if info.is_empty():
		return "Vide"
	var members: Array = []
	for member in info.get("team", []):
		members.append("%s (%s, niv. %d)" % [str(member.get("name", "?")), str(member.get("race", "?")), int(member.get("level", 1))])
	var kind: String = "Ascension — étage %d" % int(info.get("floor", 1)) if str(info.get("phase", "")) == "run" else "Équipe en préparation"
	return "%s\n%s\n%s" % [kind, ", ".join(members), str(info.get("saved_at", ""))]

# Ouvre la fenêtre des emplacements : `saving` vrai pour enregistrer, faux pour charger.
func _open_save_popup(saving: bool) -> void:
	_pending_overwrite_slot = -1
	_rebuild_save_popup(saving)
	_save_popup.popup_centered()

func _rebuild_save_popup(saving: bool) -> void:
	_clear_children(_save_popup_box)
	_save_popup_box.add_child(UITheme.section_title("Sauvegarder l'équipe" if saving else "Charger"))

	var slots: Array = []
	if not saving:
		slots.append(TowerSave.AUTO_SLOT)  # La sauvegarde automatique ne s'écrase pas à la main.
	for n in range(1, TowerSave.SLOT_COUNT + 1):
		slots.append(n)

	for slot in slots:
		var info: Dictionary = TowerSave.summary(slot)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		_save_popup_box.add_child(row)

		var text_box := VBoxContainer.new()
		text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text_box)
		var title := Label.new()
		title.text = TowerSave.slot_label(slot)
		title.add_theme_color_override("font_color", GOLD)
		text_box.add_child(title)
		var detail := Label.new()
		detail.text = _slot_description(info)
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail.custom_minimum_size = Vector2(420, 0)
		detail.add_theme_font_size_override("font_size", 12)
		text_box.add_child(detail)

		var action := Button.new()
		action.custom_minimum_size = Vector2(120, 36)
		if saving:
			action.text = "Écraser ?" if _pending_overwrite_slot == slot else ("Écraser" if not info.is_empty() else "Sauvegarder")
			action.pressed.connect(func(): _on_save_slot_pressed(slot, not info.is_empty()))
		else:
			action.text = "Charger"
			action.disabled = info.is_empty()
			action.pressed.connect(func(): _load_slot(slot))
		row.add_child(action)

		var erase := Button.new()
		erase.text = "Suppr."
		erase.custom_minimum_size = Vector2(70, 36)
		erase.disabled = info.is_empty()
		erase.pressed.connect(func():
			TowerSave.delete(slot)
			_pending_overwrite_slot = -1
			_rebuild_save_popup(saving)
			_update_continue_button())
		row.add_child(erase)

		_save_popup_box.add_child(HSeparator.new())
	_save_popup.reset_size()

func _on_save_slot_pressed(slot: int, occupied: bool) -> void:
	# Écraser une sauvegarde existante demande un second clic.
	if occupied and _pending_overwrite_slot != slot:
		_pending_overwrite_slot = slot
		_rebuild_save_popup(true)
		return
	var error: String = TowerManager.save_to_slot(slot)
	_save_popup.hide()
	_notice = error if error != "" else "Équipe sauvegardée (%s)." % TowerSave.slot_label(slot).to_lower()
	_refresh()

# Charge un emplacement : une équipe remplit l'écran de création ; une
# ascension est reprise au début de son étage.
func _load_slot(slot: int) -> void:
	var phase: String = TowerManager.saved_phase(slot)
	var error: String = TowerManager.load_from_slot(slot)
	if error == "":
		if phase == "ascension":
			error = TowerManager.resume_run()
		else:
			_selected_index = 0
	_save_popup.hide()
	if error != "":
		_notice = error
	elif phase != "ascension":
		_notice = "Équipe chargée."
	_refresh()
