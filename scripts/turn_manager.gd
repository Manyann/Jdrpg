extends Node

# ============================================================
# turn_manager.gd
# Gère la file d'initiative (triée par Courage décroissant) et
# le passage de tour entre les unités. Construit lui-même une
# petite UI (label du tour en cours + bouton "Fin de tour"),
# donc pas besoin de créer les nodes UI à la main dans l'éditeur.
#
# INSTALLATION :
# 1. Ajoute un node "Node" (simple) comme enfant du node HexGrid.
# 2. Attache-lui ce script.
# 3. Sélectionne le node HexGrid, et dans l'inspecteur, glisse ce
#    nouveau node TurnManager dans le champ "Turn Manager Path".
# ============================================================

# File d'initiative : liste de CombatUnit triée par Courage décroissant.
## Largeur (px) de la colonne « tour » de la barre du bas : les textes longs passent à la ligne
## et les rangées de boutons se replient au lieu d'élargir le panneau.
const PANEL_INNER_WIDTH := 300.0
## Hauteur fixe (px) de la barre d'actions du bas.
## Largeur commune du suivi d'équipe et du journal de combat (colonne de gauche).
const LEFT_PANEL_WIDTH := 210.0
const BAR_HEIGHT := 255.0

var _turn_order: Array = []

# Index de l'unité dont c'est le tour dans _turn_order.
var _current_index: int = 0

# Référence vers le node HexGrid (son parent), assignée dans start_combat().
var _hex_grid = null

var _turn_label: Label
var _order_label: Label
var _order_row: HFlowContainer
var _highlighted_unit = null
var _spell_buttons_container: VBoxContainer
var _terrain_confirm_button: Button
var _zone_hint_label: Label
var _ev_cost_panel: HBoxContainer
var _ev_cost_spinbox: SpinBox
var _ev_cost_pending_spell: Spell = null

var _resurrect_panel: VBoxContainer
var _resurrect_list: VBoxContainer
var _stat_picker_panel: VBoxContainer
var _stat_picker_label: Label
var _stat_picker_buttons_row: HBoxContainer
var _stat_picker_pending_spell: Spell = null
var _stat_picker_up_choice: String = ""

## Les 6 statistiques proposables (champ bonus_* sur StatusEffect,
## libellé affiché) — voir Substitution (Prestidigitateur).
const STAT_OPTIONS = [
	["bonus_courage", "Courage"], ["bonus_intelligence", "Intelligence"],
	["bonus_charisme", "Charisme"], ["bonus_adresse", "Adresse"],
	["bonus_force", "Force"], ["bonus_chance", "Chance"],
]
var _element_filter_row: HFlowContainer

# Couleurs des boutons de filtre élémentaire (voir _build_ui).
const ELEMENT_FILTER_COLORS := {
	"Feu": Color(1.0, 0.55, 0.3),
	"Eau": Color(0.4, 0.7, 1.0),
	"Air": Color(0.85, 0.9, 0.95),
	"Terre": Color(0.75, 0.6, 0.35),
}

# Éléments actuellement filtrés (voir _on_element_filter_toggled) —
# aucun actif par défaut, donc aucun sort à élément affiché tant que
# le joueur n'a rien coché.
var _active_element_filters: Dictionary = {}

# Unité dont les boutons de sorts sont actuellement affichés — permet
# de les régénérer quand un filtre change, sans dépendre du tour en
# cours (utile pour la fiche personnage en consultation aussi).
var _spell_buttons_unit = null
var _end_turn_button: Button

# --- Posture défensive (choisie à son tour, active jusqu'au suivant) ---
var _stance_group: ButtonGroup
var _stance_parry_button: Button
var _stance_dodge_button: Button

# --- Capacités à bascule (Coup décisif, Soutien du Méca Support) ---
var _ability_row: HFlowContainer
var _coup_decisif_button: Button
var _support_group: ButtonGroup
var _support_attack_button: Button
var _support_parry_button: Button

# --- Fiche personnage (haut à droite) ---
var _char_panel: PanelContainer
var _char_name_label: Label
var _char_team_label: Label
var _char_hp_bar: ProgressBar
var _char_hp_label: Label
var _char_ea_label: Label
var _char_stats_label: Label
var _char_skills_box: HFlowContainer  # Compétences de l'unité qui joue (barre du bas).

# Unité actuellement affichée dans la fiche personnage (peut être
# n'importe quelle unité cliquée, pas forcément celle dont c'est le tour).
var _inspected_unit = null

## Vrai : les unités ennemies sont jouées par l'IA (voir EnemyAI) au lieu
## d'être pilotées à la main. Activé pour la Tour de l'infini ; faux pour un
## combat de test, qui reste en pilotage manuel des deux camps.
var enemy_ai_enabled: bool = false

# --- Popups (inventaire et choix de flèche) ---

# --- Panneau d'état de l'équipe (haut gauche) ---
var _team_panel: PanelContainer
var _log_panel: PanelContainer
var _bar_panel: PanelContainer
var _log_text: RichTextLabel
var _team_rows: VBoxContainer
var _team_roster: Array = []  # Unités joueur du début de combat (gardées même mortes).

func _ready() -> void:
	_build_ui()

func _build_team_panel(canvas: CanvasLayer) -> void:
	_team_panel = PanelContainer.new()
	_team_panel.theme = UITheme.build_theme()
	_team_panel.add_theme_stylebox_override("panel", UITheme.panel_style(UITheme.GOLD_DIM, 6, 8, 0.85))
	_team_panel.position = Vector2(12, 12)
	_team_panel.custom_minimum_size = Vector2(LEFT_PANEL_WIDTH, 0)  # Même largeur que le journal de combat.
	_team_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(_team_panel)
	_team_rows = VBoxContainer.new()
	_team_rows.add_theme_constant_override("separation", 2)
	_team_panel.add_child(_team_rows)

# Journal de combat : à gauche, sous le suivi de l'équipe.
func _build_log_panel(canvas: CanvasLayer) -> void:
	_log_panel = PanelContainer.new()
	_log_panel.theme = UITheme.build_theme()
	_log_panel.add_theme_stylebox_override("panel", UITheme.panel_style(UITheme.GOLD_DIM, 6, 8, 0.85))
	_log_panel.custom_minimum_size = Vector2(LEFT_PANEL_WIDTH, 60)
	_log_panel.size = Vector2(LEFT_PANEL_WIDTH, 230)
	_log_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(_log_panel)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_log_panel.add_child(box)
	var title := Label.new()
	title.text = "Journal de combat"
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", UITheme.TITLE)
	box.add_child(title)
	_log_text = RichTextLabel.new()
	_log_text.bbcode_enabled = true
	_log_text.scroll_following = true
	_log_text.fit_content = false
	_log_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_log_text.add_theme_font_size_override("normal_font_size", 12)
	box.add_child(_log_text)
	_team_panel.resized.connect(_place_log_panel)
	_place_log_panel()

# Garde les panneaux flottants (journal, fiche personnage) au-dessus de la barre
# d'actions, même dans une petite fenêtre : le journal raccourcit (ou se masque
# s'il ne reste plus de place) et la fiche se réduit pour rester entièrement visible.
func _process(_delta: float) -> void:
	if _bar_panel == null:
		return
	var top: float = _bar_panel.get_global_rect().position.y - 8.0
	if _log_panel != null:
		var h: float = top - _log_panel.position.y
		_log_panel.visible = h >= 60.0
		if _log_panel.visible:
			_log_panel.size = Vector2(LEFT_PANEL_WIDTH, minf(h, 230.0))
	if _char_panel != null and _char_panel.visible:
		var need: float = _char_panel.get_combined_minimum_size().y + 16.0
		var k: float = clampf((top - 8.0) / maxf(need, 1.0), 0.55, 1.0)
		_char_panel.pivot_offset = Vector2(_char_panel.size.x, 0.0)
		_char_panel.scale = Vector2(k, k)

func _place_log_panel() -> void:
	if _log_panel == null or _team_panel == null:
		return
	_log_panel.position = Vector2(12, _team_panel.position.y + _team_panel.size.y + 8)

const _LOG_MAX_LINES: int = 120
var _log_lines: int = 0

func _on_combat_log(text: String, color: Color) -> void:
	if _log_text == null:
		return
	if _log_lines >= _LOG_MAX_LINES:
		_log_text.remove_paragraph(0)
		_log_lines -= 1
	_log_text.push_color(color)
	_log_text.add_text(text)
	_log_text.pop()
	_log_text.newline()
	_log_lines += 1

func _refresh_team_panel() -> void:
	if _team_rows == null:
		return
	if _team_roster.is_empty():
		for u in _turn_order:
			if u.team == CombatUnit.Team.PLAYER:
				_team_roster.append(u)
	for c in _team_rows.get_children():
		c.queue_free()
	var title := Label.new()
	title.text = "Équipe"
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", UITheme.TITLE)
	_team_rows.add_child(title)
	for u in _team_roster:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		_team_rows.add_child(row)
		var alive: bool = is_instance_valid(u) and u.current_hp > 0 and _turn_order.has(u)
		if not is_instance_valid(u):
			var ghost := Label.new()
			ghost.text = "✝ (mort)"
			ghost.modulate = Color(0.6, 0.35, 0.35)
			row.add_child(ghost)
			continue
		var tok: Control = _make_order_token(u, _turn_order.size() > 0 and _turn_order[_current_index] == u)
		if not alive:
			tok.modulate = Color(0.45, 0.3, 0.3)
		row.add_child(tok)
		var l := Label.new()
		l.add_theme_font_size_override("font_size", 13)
		if alive:
			l.text = "PV %d/%d\n%s" % [u.current_hp, u.max_hp, u.get_resource_summary(false)]
		else:
			l.text = "✝ mort"
			l.modulate = Color(0.7, 0.4, 0.4)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(l)

# Construit une UI minimale en pur code : un panneau en haut à gauche
# avec le nom de l'unité active et le bouton pour finir son tour.
func _build_ui() -> void:
	var canvas = CanvasLayer.new()
	add_child(canvas)
	_build_team_panel(canvas)
	_build_log_panel(canvas)

	# Barre d'actions SOUS la grille, pleine largeur, dans le design system
	# commun (UITheme) : tour et ordre à gauche, sorts au centre, posture et
	# boutons de fin de tour à droite.
	var bar_panel = PanelContainer.new()
	bar_panel.theme = UITheme.build_theme()
	bar_panel.add_theme_stylebox_override("panel", UITheme.panel_style(UITheme.GOLD_DIM, 8, 10, 0.92))
	bar_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar_panel.offset_left = 16
	bar_panel.offset_right = -16
	# Hauteur FIXE (ne s'adapte pas au contenu) : la colonne des actions défile
	# si besoin, voir BAR_HEIGHT.
	bar_panel.offset_top = -(BAR_HEIGHT + 12.0)
	bar_panel.offset_bottom = -12
	bar_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bar_panel.clip_contents = true
	canvas.add_child(bar_panel)
	_bar_panel = bar_panel

	var bar_row = HBoxContainer.new()
	bar_row.add_theme_constant_override("separation", 14)
	bar_panel.add_child(bar_row)

	var col_turn = VBoxContainer.new()
	col_turn.add_theme_constant_override("separation", 6)
	col_turn.custom_minimum_size = Vector2(PANEL_INNER_WIDTH, 0)
	bar_row.add_child(col_turn)
	bar_row.add_child(VSeparator.new())

	# Colonne des actions dans un conteneur à défilement vertical : la barre garde
	# sa taille quel que soit le nombre de sorts/compétences.
	var spells_scroll := ScrollContainer.new()
	spells_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spells_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spells_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	bar_row.add_child(spells_scroll)
	var col_spells = VBoxContainer.new()
	col_spells.add_theme_constant_override("separation", 6)
	col_spells.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spells_scroll.add_child(col_spells)
	bar_row.add_child(VSeparator.new())

	var col_actions = VBoxContainer.new()
	col_actions.add_theme_constant_override("separation", 6)
	bar_row.add_child(col_actions)

	var vbox = col_turn

	_turn_label = Label.new()
	_turn_label.add_theme_font_size_override("font_size", 16)
	_turn_label.add_theme_color_override("font_color", UITheme.TITLE)
	_turn_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_turn_label.custom_minimum_size = Vector2(PANEL_INNER_WIDTH, 0)
	vbox.add_child(_turn_label)

	_order_label = Label.new()
	_order_label.add_theme_font_size_override("font_size", 14)
	_order_label.modulate = Color(0.8, 0.76, 0.65)
	_order_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_order_label.custom_minimum_size = Vector2(PANEL_INNER_WIDTH, 0)
	_order_label.text = "Ordre du tour :"
	_order_label.visible = false  # Gain de place : les tokens parlent d'eux-mêmes.
	vbox.add_child(_order_label)

	# Ordre d'initiative en TOKENS : au survol, l'unité correspondante est
	# mise en surbrillance sur la grille (voir _on_order_token_hover).
	_order_row = HFlowContainer.new()
	_order_row.add_theme_constant_override("h_separation", 4)
	_order_row.add_theme_constant_override("v_separation", 4)
	_order_row.custom_minimum_size = Vector2(PANEL_INNER_WIDTH, 0)
	vbox.add_child(_order_row)

	vbox = col_spells
	var spells_title = Label.new()
	spells_title.text = "Actions"
	spells_title.add_theme_font_size_override("font_size", 14)
	spells_title.add_theme_color_override("font_color", UITheme.TITLE)
	vbox.add_child(spells_title)

	# Filtres élémentaires (voir Spell.elements) : AUCUN sort à élément
	# affiché par défaut, seuls les filtres activés en montrent —
	# plusieurs actifs à la fois montre les sorts dont TOUS les éléments
	# sont couverts (un sort Double Eau+Feu n'apparaît qu'avec les deux
	# filtres Eau ET Feu activés). Les sorts sans élément (attaque
	# d'arme, autres classes) restent toujours affichés, non filtrés.
	_element_filter_row = HFlowContainer.new()
	_element_filter_row.add_theme_constant_override("h_separation", 4)
	_element_filter_row.add_theme_constant_override("v_separation", 4)
	_element_filter_row.visible = false  # Masquée par défaut ; _rebuild_spell_buttons() la ré-affiche seulement pour une classe à sorts élémentaires.
	vbox.add_child(_element_filter_row)

	for element in ELEMENT_FILTER_COLORS.keys():
		var filter_button = Button.new()
		filter_button.text = element
		filter_button.toggle_mode = true
		filter_button.custom_minimum_size = Vector2(58, 30)
		filter_button.add_theme_font_size_override("font_size", 12)
		filter_button.modulate = ELEMENT_FILTER_COLORS[element]
		filter_button.toggled.connect(func(pressed): _on_element_filter_toggled(element, pressed))
		_element_filter_row.add_child(filter_button)

	# Sous-sections (Attaques, Sorts, Pièges, Compétences, Inventaire) remplies
	# par _rebuild_spell_buttons : un titre + une rangée de boutons chacune.
	_spell_buttons_container = VBoxContainer.new()
	_spell_buttons_container.add_theme_constant_override("separation", 4)
	vbox.add_child(_spell_buttons_container)

	# Bouton de validation pour un sort de terrain en cours de sélection
	# (Mur d'eau, Pont végétal, Évaporation d'eau...) — masqué tant
	# qu'aucun sort de ce type n'est en cours de ciblage (voir
	# HexGrid._handle_terrain_selection_click / update_terrain_selection_ui).
	_terrain_confirm_button = Button.new()
	_terrain_confirm_button.text = "Valider (0 case)"
	_terrain_confirm_button.custom_minimum_size = Vector2(0, 36)
	_terrain_confirm_button.visible = false
	_terrain_confirm_button.disabled = true
	_terrain_confirm_button.pressed.connect(func(): _hex_grid.confirm_terrain_selection())
	vbox.add_child(_terrain_confirm_button)

	# Aide affichée pendant le ciblage d'un sort de Zone orientable
	# (voir HexGrid._reset_zone_orientation / show_zone_hint).
	_zone_hint_label = Label.new()
	_zone_hint_label.text = "Zone : molette ou Q / E pour tourner la forme"
	_zone_hint_label.add_theme_font_size_override("font_size", 12)
	_zone_hint_label.modulate = Color(0.95, 0.6, 0.85)
	_zone_hint_label.visible = false
	vbox.add_child(_zone_hint_label)

	# Sélecteur de X pour un sort à coût en PV en cours (branche
	# Walkyrie — voir Spell.is_ev_cost_spell / HexGrid.enter_targeting_mode).
	# Masqué tant qu'aucun sort de ce type n'a été cliqué.
	_ev_cost_panel = HBoxContainer.new()
	_ev_cost_panel.add_theme_constant_override("separation", 6)
	_ev_cost_panel.visible = false

	var ev_label = Label.new()
	ev_label.text = "PV à investir :"
	ev_label.add_theme_font_size_override("font_size", 13)
	_ev_cost_panel.add_child(ev_label)

	_ev_cost_spinbox = SpinBox.new()
	_ev_cost_spinbox.step = 1
	_ev_cost_spinbox.custom_minimum_size = Vector2(70, 0)
	_ev_cost_panel.add_child(_ev_cost_spinbox)

	var ev_confirm = Button.new()
	ev_confirm.text = "Lancer"
	ev_confirm.pressed.connect(_on_ev_cost_confirmed)
	_ev_cost_panel.add_child(ev_confirm)

	var ev_cancel = Button.new()
	ev_cancel.text = "Annuler"
	ev_cancel.pressed.connect(func():
		_ev_cost_panel.visible = false
		_ev_cost_pending_spell = null
	)
	_ev_cost_panel.add_child(ev_cancel)

	vbox.add_child(_ev_cost_panel)

	# Sélecteur à 2 étapes pour Substitution (Prestidigitateur — voir
	# Spell.is_prestidigitateur_substitution) : choisit d'abord la
	# statistique à +4, puis celle à -4, par boutons. Masqué tant
	# qu'aucun sort de ce type n'a été cliqué.
	_stat_picker_panel = VBoxContainer.new()
	_stat_picker_panel.add_theme_constant_override("separation", 4)
	_stat_picker_panel.visible = false

	_stat_picker_label = Label.new()
	_stat_picker_label.text = "Substitution :"
	_stat_picker_label.add_theme_font_size_override("font_size", 13)
	_stat_picker_panel.add_child(_stat_picker_label)

	_stat_picker_buttons_row = HBoxContainer.new()
	_stat_picker_buttons_row.add_theme_constant_override("separation", 4)
	_stat_picker_panel.add_child(_stat_picker_buttons_row)

	var stat_picker_cancel = Button.new()
	stat_picker_cancel.text = "Annuler"
	stat_picker_cancel.pressed.connect(func():
		_stat_picker_panel.visible = false
		_stat_picker_pending_spell = null
	)
	_stat_picker_panel.add_child(stat_picker_cancel)

	vbox.add_child(_stat_picker_panel)

	# Sélecteur de résurrection (Grâce du ciel, L'équilibre du cycle) : liste
	# des alliés morts, affichée au lancement du sort.
	_resurrect_panel = VBoxContainer.new()
	_resurrect_panel.add_theme_constant_override("separation", 4)
	_resurrect_panel.visible = false
	var resurrect_title = Label.new()
	resurrect_title.text = "Qui ressusciter ?"
	resurrect_title.add_theme_font_size_override("font_size", 13)
	_resurrect_panel.add_child(resurrect_title)
	_resurrect_list = VBoxContainer.new()
	_resurrect_list.add_theme_constant_override("separation", 3)
	_resurrect_panel.add_child(_resurrect_list)
	var resurrect_cancel = Button.new()
	resurrect_cancel.text = "Annuler"
	resurrect_cancel.pressed.connect(func(): _resurrect_panel.visible = false)
	_resurrect_panel.add_child(resurrect_cancel)
	vbox.add_child(_resurrect_panel)

	# Compétences (race + métiers) de l'unité qui joue, détail au survol.
	_char_skills_box = HFlowContainer.new()
	_char_skills_box.add_theme_constant_override("h_separation", 8)
	_char_skills_box.add_theme_constant_override("v_separation", 2)
	_char_skills_box.visible = false
	vbox.add_child(_char_skills_box)

	vbox = col_actions
	var stance_title = Label.new()
	stance_title.text = "Posture défensive :"
	stance_title.add_theme_font_size_override("font_size", 14)
	stance_title.add_theme_color_override("font_color", UITheme.TITLE)
	vbox.add_child(stance_title)

	var stance_row = HBoxContainer.new()
	stance_row.add_theme_constant_override("separation", 6)
	vbox.add_child(stance_row)

	_stance_group = ButtonGroup.new()

	_stance_parry_button = Button.new()
	_stance_parry_button.text = "⛨"
	_stance_parry_button.tooltip_text = "Parade — annule une attaque d'arme en mêlée et riposte si le jet réussit."
	_stance_parry_button.custom_minimum_size = Vector2(44, 44)
	_stance_parry_button.add_theme_font_size_override("font_size", 20)
	_stance_parry_button.toggle_mode = true
	_stance_parry_button.button_group = _stance_group
	_stance_parry_button.pressed.connect(func(): _set_active_unit_stance(CombatUnit.DefensiveStance.PARRY))
	_set_button_icon(_stance_parry_button, "parade")
	stance_row.add_child(_stance_parry_button)

	_stance_dodge_button = Button.new()
	_stance_dodge_button.text = "↯"
	_stance_dodge_button.tooltip_text = "Esquive — annule n'importe quelle attaque si le jet réussit, 1 attaque sur 2 seulement."
	_stance_dodge_button.custom_minimum_size = Vector2(44, 44)
	_stance_dodge_button.add_theme_font_size_override("font_size", 20)
	_stance_dodge_button.toggle_mode = true
	_stance_dodge_button.button_group = _stance_group
	_stance_dodge_button.pressed.connect(func(): _set_active_unit_stance(CombatUnit.DefensiveStance.DODGE))
	_set_button_icon(_stance_dodge_button, "esquive")
	stance_row.add_child(_stance_dodge_button)

	# Capacités à bascule : visibles seulement pour l'unité qui les possède
	# (voir _sync_ability_buttons).
	_ability_row = HFlowContainer.new()
	_ability_row.add_theme_constant_override("h_separation", 6)
	_ability_row.add_theme_constant_override("v_separation", 6)
	_ability_row.visible = false
	vbox.add_child(_ability_row)

	_coup_decisif_button = Button.new()
	_coup_decisif_button.text = "Coup décisif"
	_coup_decisif_button.toggle_mode = true
	_coup_decisif_button.tooltip_text = "Coup décisif (ON/OFF) — tes attaques d'arme ont 1 chance sur 2 de faire des dégâts doublés, sinon 0 dégât."
	_coup_decisif_button.visible = false
	_coup_decisif_button.toggled.connect(func(on: bool):
		if _turn_order.is_empty():
			return
		_turn_order[_current_index].coup_decisif_on = on
	)
	_ability_row.add_child(_coup_decisif_button)

	_support_group = ButtonGroup.new()
	_support_attack_button = Button.new()
	_support_attack_button.text = "Soutien : Attaque"
	_support_attack_button.toggle_mode = true
	_support_attack_button.button_group = _support_group
	_support_attack_button.tooltip_text = "Le soutien de ce tour donne du bonus en Attaque."
	_support_attack_button.visible = false
	_support_attack_button.pressed.connect(func():
		if not _turn_order.is_empty():
			_turn_order[_current_index].meca_support_choice = "attaque"
	)
	_ability_row.add_child(_support_attack_button)

	_support_parry_button = Button.new()
	_support_parry_button.text = "Soutien : Parade"
	_support_parry_button.toggle_mode = true
	_support_parry_button.button_group = _support_group
	_support_parry_button.tooltip_text = "Le soutien de ce tour donne du bonus en Parade."
	_support_parry_button.visible = false
	_support_parry_button.pressed.connect(func():
		if not _turn_order.is_empty():
			_turn_order[_current_index].meca_support_choice = "parade"
	)
	_ability_row.add_child(_support_parry_button)

	var bottom_row = HBoxContainer.new()
	bottom_row.add_theme_constant_override("separation", 8)
	vbox.add_child(bottom_row)

	_end_turn_button = Button.new()
	_end_turn_button.text = "➡"
	_end_turn_button.tooltip_text = "Fin de tour"
	_end_turn_button.custom_minimum_size = Vector2(44, 44)
	_end_turn_button.add_theme_font_size_override("font_size", 20)
	_end_turn_button.pressed.connect(_on_end_turn_pressed)
	_set_button_icon(_end_turn_button, "fin_du_tour")
	bottom_row.add_child(_end_turn_button)

	_build_character_panel(canvas)

# Construit l'encadré "fiche personnage" en haut à droite de l'écran :
# affiche le nom, l'équipe et les PV de la dernière unité cliquée
# (n'importe laquelle, active ou non — simple consultation).
func _build_character_panel(canvas: CanvasLayer) -> void:
	_char_panel = PanelContainer.new()

	_char_panel.theme = UITheme.build_theme()
	_char_panel.add_theme_stylebox_override("panel", UITheme.panel_style(UITheme.GOLD_DIM, 8, 12, 0.88))

	_char_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_char_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_char_panel.position = Vector2(-16, 16)
	_char_panel.custom_minimum_size = Vector2(220, 0)
	canvas.add_child(_char_panel)

	var char_vbox = VBoxContainer.new()
	char_vbox.add_theme_constant_override("separation", 6)
	_char_panel.add_child(char_vbox)

	_char_name_label = Label.new()
	_char_name_label.add_theme_font_size_override("font_size", 20)
	_char_name_label.add_theme_color_override("font_color", UITheme.TITLE)
	char_vbox.add_child(_char_name_label)

	_char_team_label = Label.new()
	_char_team_label.add_theme_font_size_override("font_size", 13)
	char_vbox.add_child(_char_team_label)

	_char_hp_bar = ProgressBar.new()
	_char_hp_bar.custom_minimum_size = Vector2(0, 18)
	_char_hp_bar.show_percentage = false
	UITheme.style_hp_bar(_char_hp_bar)
	char_vbox.add_child(_char_hp_bar)

	_char_hp_label = Label.new()
	_char_hp_label.add_theme_font_size_override("font_size", 14)
	char_vbox.add_child(_char_hp_label)

	_char_ea_label = Label.new()
	_char_ea_label.add_theme_font_size_override("font_size", 13)
	_char_ea_label.modulate = Color(0.8, 0.8, 0.8)
	char_vbox.add_child(_char_ea_label)

	char_vbox.add_child(HSeparator.new())

	_char_stats_label = Label.new()
	_char_stats_label.add_theme_font_size_override("font_size", 13)
	_char_stats_label.modulate = Color(0.85, 0.85, 0.85)
	char_vbox.add_child(_char_stats_label)

	# Compétences (race + métiers) : une ligne par compétence, détail au survol.

	_render_character_panel()  # État initial : placeholder "aucune unité".

# ---------- Attaque à distance : munition sélectionnée ----------

# Munition utilisable pour `unit` : la sélectionnée si elle reste en carquois, sinon
# la première qui en a encore (null si plus rien ou aucun carquois).
func _current_arrow(unit):
	if unit.selected_arrow != null and unit.inventory_arrows.has(unit.selected_arrow) and unit.selected_arrow.quantity > 0:
		return unit.selected_arrow
	for arrow in unit.inventory_arrows:
		if arrow.quantity > 0:
			unit.selected_arrow = arrow
			return arrow
	return null

# Lance le ciblage d'une attaque d'arme à distance avec la munition sélectionnée
# (plus de fenêtre de choix) ; la flèche est consommée au tir, voir HexGrid._cast_spell.
func _start_ranged_attack(spell: Spell, unit) -> void:
	var arrow = _current_arrow(unit)
	if arrow == null:
		_hex_grid.enter_targeting_mode(spell)  # Pas de carquois : dégâts de base de l'arme.
		return
	var augmented: Spell = spell.duplicate()
	augmented.origin_spell = spell  # Le suivi "déjà utilisé" compte sur le sort d'origine.
	augmented.source_weapon = spell.source_weapon
	augmented.damage = spell.damage + arrow.damage_bonus  # Pour l'affichage (tooltip) uniquement.
	augmented.flat_damage_bonus = arrow.damage_bonus  # Pour les dégâts RÉELS (voir HexGrid._resolve_weapon_attack).
	augmented.spell_name = "%s [%s]" % [spell.spell_name, arrow.arrow_name]
	augmented.arrow_used = arrow
	_hex_grid.enter_targeting_mode(augmented)

# Sélecteur de munition sous les attaques d'une arme à distance : même principe que
# la posture défensive (un clic active, le choix reste jusqu'à changement).
func _add_arrow_selector(unit, holder: VBoxContainer) -> void:
	var weapon = unit.equipped_weapon
	if weapon == null or weapon.weapon_type != Weapon.WeaponType.RANGED or unit.inventory_arrows.is_empty():
		return
	var title := Label.new()
	title.text = "Munitions"
	title.add_theme_font_size_override("font_size", 12)
	title.modulate = Color(0.8, 0.76, 0.65)
	holder.add_child(title)
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 6)
	row.add_theme_constant_override("v_separation", 6)
	holder.add_child(row)
	var group := ButtonGroup.new()
	var current = _current_arrow(unit)
	for arrow in unit.inventory_arrows:
		var btn := Button.new()
		btn.text = arrow.get_display_text()
		btn.toggle_mode = true
		btn.button_group = group
		btn.custom_minimum_size = Vector2(0, 34)
		btn.disabled = arrow.quantity <= 0
		btn.button_pressed = arrow == current
		btn.tooltip_text = "Munition utilisée par tes attaques à distance (reste active tant que tu n'en changes pas)."
		btn.pressed.connect(func(): unit.selected_arrow = arrow)
		row.add_child(btn)

# Appelée par HexGrid une fois toutes les unités de départ placées.
# Construit la file d'initiative et démarre le premier tour.
func start_combat(units: Array) -> void:
	_hex_grid = get_parent()
	if not _hex_grid.combat_log.is_connected(_on_combat_log):
		_hex_grid.combat_log.connect(_on_combat_log)
	enemy_ai_enabled = TowerManager.run_active

	# Larcin (Voleur) : calculé UNE SEULE FOIS ici (pas à la fin), voir
	# la doc de HexGrid.human_enemies_fought.
	_hex_grid.human_enemies_fought = 0
	for u in units:
		if u.team == CombatUnit.Team.ENEMY and (u.equipped_race == null or u.equipped_race.race_name == "Humain"):
			_hex_grid.human_enemies_fought += 1

	# Analyste (Ingénieur) : -1 PR à UN ennemi choisi au hasard, une
	# seule fois au tout début du combat — pour chaque unité du camp
	# joueur qui a ce trait (normalement une seule, mais rien
	# n'empêche plusieurs Ingénieurs côte à côte).
	var enemies_at_start = units.filter(func(u): return u.team == CombatUnit.Team.ENEMY)
	if not enemies_at_start.is_empty():
		for u in units:
			if u.team == CombatUnit.Team.PLAYER and u.has_metier("Ingénieur"):
				var target_enemy = enemies_at_start[randi() % enemies_at_start.size()]
				var debuff := StatusEffect.new()
				debuff.effect_name = "Analyste (-1 Armure)"
				debuff.duration_remaining = -1  # Pour tout le combat.
				debuff.bonus_armure = -1
				target_enemy.add_status_effect(debuff)
				_hex_grid.spawn_floating_text(target_enemy.position, "Analysé !", Color(0.5, 0.65, 0.85))
				print("%s analyse %s (-1 Armure)." % [u.unit_name, target_enemy.unit_name])

	_turn_order = units.duplicate()

	# Chercher des noises (CDN) : joue avant tout le monde sans cette
	# compétence ; entre plusieurs qui l'ont, départage par Courage —
	# comme le reste du classement, qui se fait uniquement par Courage.
	_turn_order.sort_custom(func(a, b):
		var a_cdn = a.has_skill("CDN")
		var b_cdn = b.has_skill("CDN")
		if a_cdn != b_cdn:
			return a_cdn
		return a.courage > b.courage
	)

	_current_index = 0
	_start_current_turn()

func _start_current_turn() -> void:
	if _turn_order.is_empty():
		_update_ui()
		return

	var unit = _turn_order[_current_index]
	_hex_grid.log_event("— Tour de %s —" % unit.unit_name)

	# Nuit (Noirceur, Prêtre — voir HexGrid.is_night/_install_night) :
	# décomptée une fois par ROUND complet, pas à chaque tour individuel
	# — "un tour, c'est quand c'est de nouveau au joueur de jouer".
	if unit.team == CombatUnit.Team.PLAYER:
		_hex_grid.tick_night_if_active()

	# Effets à durée (Brûlure, buffs/debuffs...) : dégâts de tick,
	# décompte de durée — AVANT que l'unité puisse agir. Si ça la tue,
	# le mécanisme de mort existant (take_damage -> die()) s'en charge
	# normalement, comme n'importe quel autre dégât. unit.gd n'a pas
	# accès à spawn_floating_text() : c'est ici qu'on affiche chaque
	# tick renvoyé.
	var status_ticks = unit.process_status_effects_on_turn_start()
	for tick in status_ticks:
		_hex_grid.log_event("%s subit %d dégâts (%s)." % [unit.unit_name, tick["amount"], tick["label"]])
		_hex_grid.spawn_floating_text(unit.position, "-%d (%s)" % [tick["amount"], tick["label"]], Color(0.85, 0.25, 0.15))

	if not is_instance_valid(unit) or unit.current_hp <= 0:
		return  # Morte entre-temps (ex: Brûlure) — le retrait du tour s'en occupe déjà.

	# Plan parallèle (Prêtre) : décompte des tours d'isolement de cette unité.
	_hex_grid.tick_parallel_plane(unit)

	# Traits d'ennemi de la Tour déclenchés en début de tour (liane de zone,
	# invocation d'un allié...) — voir HexGrid.process_turn_start_traits.
	_hex_grid.process_trap_release(unit)
	_hex_grid.process_turn_start_traits(unit)
	if not is_instance_valid(unit) or unit.current_hp <= 0 or _hex_grid.combat_ended:
		return

	# Étourdie (Mistral, Marchand de sable) ou gelée (Cryogénisation) :
	# son tour passe intégralement, sans qu'elle puisse rien faire.
	if unit.stunned_turns_remaining > 0 or unit.is_frozen:
		if unit.stunned_turns_remaining > 0:
			unit.stunned_turns_remaining -= 1
			_hex_grid.spawn_floating_text(unit.position, "Étourdi", Color(0.9, 0.9, 0.3))
		else:
			_hex_grid.spawn_floating_text(unit.position, "Gelé", Color(0.6, 0.85, 0.95))
		refresh_ui()
		_on_end_turn_pressed()
		return

	# Canalisation en cours (DI, voir Spell.cast_delay) : ce tour ne sert
	# qu'à la faire avancer, l'unité ne peut pas agir normalement tant
	# qu'elle n'est pas terminée.
	if unit.pending_spell != null:
		unit.pending_turns_remaining -= 1
		if unit.pending_turns_remaining <= 0:
			var spell = unit.pending_spell
			# SELF/GROUP/BATTLEFIELD n'ont rien à choisir (voir
			# HexGrid.resolve_pending_spell) : résolution immédiate, tour
			# terminé comme avant. Tout le reste (cible unique, zone,
			# invocation, terrain) demande un clic du joueur MAINTENANT —
			# voir HexGrid.begin_delayed_targeting, qui NE termine PAS le
			# tour lui-même (ça se fait au clic, voir finish_delayed_cast_turn).
			var auto_resolves = spell.target_mode == Spell.TargetMode.SELF \
				or spell.target_mode == Spell.TargetMode.GROUP \
				or spell.target_mode == Spell.TargetMode.BATTLEFIELD
			if auto_resolves:
				_hex_grid.resolve_pending_spell(unit)
				refresh_ui()
				_on_end_turn_pressed()
			else:
				_hex_grid.begin_delayed_targeting(unit, spell)
				refresh_ui()
		else:
			_hex_grid.spawn_floating_text(unit.position, "Incantation... (%d)" % unit.pending_turns_remaining, Color(0.7, 0.5, 0.95))
			refresh_ui()
			_on_end_turn_pressed()
		return

	_hex_grid.set_active_unit(unit)
	_update_ui()

	# Tour de l'infini : l'IA joue les unités ennemies ; le joueur ne garde la
	# main que sur les siennes.
	if enemy_ai_enabled:
		if unit.team == CombatUnit.Team.ENEMY:
			_run_enemy_turn(unit)
		else:
			_set_player_controls_enabled(true)

# Active ou désactive les commandes du joueur (fin de tour, inventaire,
# postures) : coupées pendant le tour de l'IA, sans quoi un clic pourrait
# faire passer le tour de l'adversaire en plein milieu de son action.
func _set_player_controls_enabled(enabled: bool) -> void:
	_end_turn_button.disabled = not enabled
	_stance_parry_button.disabled = not enabled
	_stance_dodge_button.disabled = not enabled
	_coup_decisif_button.disabled = not enabled
	_support_attack_button.disabled = not enabled
	_support_parry_button.disabled = not enabled

# Joue le tour d'une unité ennemie via l'IA, puis passe la main. Coroutine :
# lancée sans `await` depuis _start_current_turn, elle rend la main à la
# première attente et reprend toute seule.
func _run_enemy_turn(unit) -> void:
	_clear_spell_buttons()
	_set_player_controls_enabled(false)
	_hex_grid.ai_turn_in_progress = true

	await EnemyAI.play_turn(_hex_grid, unit, get_tree())

	if not is_instance_valid(_hex_grid):
		return  # La scène a changé entre-temps.
	_hex_grid.ai_turn_in_progress = false
	if _hex_grid.combat_ended or not is_instance_valid(unit):
		return
	if _turn_order.is_empty() or _current_index >= _turn_order.size() or _turn_order[_current_index] != unit:
		return  # Le tour est déjà passé (l'unité est morte pendant son propre tour).
	_on_end_turn_pressed()

# Appelée par le bouton de la bannière de fin d'étage (voir
# _show_center_banner) : récapitule les aventuriers encore en vie, puis
# laisse TowerManager enchaîner sur l'étage suivant ou terminer l'ascension.
func _finish_tower_floor(result: String) -> void:
	var survivors: Array = []
	if _hex_grid != null:
		for u in _hex_grid.get_all_units():
			if u.team == CombatUnit.Team.PLAYER and u.has_meta("tower_index") and u.current_hp > 0:
				survivors.append({
					"index": int(u.get_meta("tower_index")),
					"hp": u.current_hp, "max_hp": u.max_hp,
					"ea": u.current_ea, "max_ea": u.max_ea,
				})
	TowerManager.finish_floor(result, survivors)

# Appelée par HexGrid une fois qu'un sort à canalisation différée
# (cible/zone/case choisie à la fin, voir begin_delayed_targeting) a
# été résolu par le clic du joueur — termine alors le tour, comme
# n'importe quel autre tour de canalisation.
func finish_delayed_cast_turn() -> void:
	refresh_ui()
	_on_end_turn_pressed()

func _on_end_turn_pressed() -> void:
	if _turn_order.is_empty():
		return

	# On annule un éventuel ciblage de sort en cours avant de changer de tour.
	_hex_grid.cancel_targeting_mode()

	_current_index = (_current_index + 1) % _turn_order.size()
	_start_current_turn()

func _update_ui() -> void:
	_refresh_team_panel()
	if _turn_order.is_empty():
		_turn_label.text = "Combat terminé !"
		_clear_order_row()
		_render_skill_list(null)
		_clear_spell_buttons()
		return

	var unit = _turn_order[_current_index]
	var team_label = "Joueur" if unit.team == CombatUnit.Team.PLAYER else "Ennemi"
	var floor_prefix: String = ("Étage %d — " % TowerManager.current_floor) if TowerManager.run_active else ""
	var resource_text: String = unit.get_resource_summary(true)
	_turn_label.text = floor_prefix + "Tour de : %s (%s) — PM: %d | %s" % [
		unit.unit_name, team_label, unit.current_pm, resource_text
	]

	_rebuild_order_row()

	_rebuild_spell_buttons(unit)
	_render_skill_list(unit)  # Après les sorts : une erreur ici ne doit jamais les masquer.
	_render_character_panel()
	_sync_stance_buttons(unit)
	_sync_ability_buttons(unit)

# Applique la posture défensive choisie à l'unité actuellement active
# (celle dont c'est le tour — seule autorisée à choisir sa posture).
func _set_active_unit_stance(stance: int) -> void:
	if _turn_order.is_empty():
		return
	var unit = _turn_order[_current_index]
	unit.set_defensive_stance(stance)

# Met les boutons de posture dans l'état correspondant à la posture
# actuelle de l'unité (utile quand on change de tour).
func _sync_stance_buttons(unit) -> void:
	if unit.defensive_stance == CombatUnit.DefensiveStance.DODGE:
		_stance_dodge_button.button_pressed = true
	else:
		# Par défaut (et dans tous les autres cas) : Parade.
		_stance_parry_button.button_pressed = true

# Affiche les capacités à bascule de l'unité active (Coup décisif pour les
# Chasseurs de primes/monstres, choix Attaque/Parade du Méca Support).
func _sync_ability_buttons(unit) -> void:
	var has_decisif: bool = unit.can_coup_decisif()
	_coup_decisif_button.visible = has_decisif
	_coup_decisif_button.set_pressed_no_signal(unit.coup_decisif_on)
	_support_attack_button.visible = unit.is_meca_support
	_support_parry_button.visible = unit.is_meca_support
	if unit.meca_support_choice == "parade":
		_support_parry_button.set_pressed_no_signal(true)
	else:
		_support_attack_button.set_pressed_no_signal(true)
	_ability_row.visible = has_decisif or unit.is_meca_support

# Liste des compétences de l'unité dans la fiche personnage.
# Compétences UTILES EN COMBAT de l'unité qui joue (celles qui ont un effet en
# combat, voir SkillDatabase.COMBAT_EFFECTS) ; détail au survol.
func _render_skill_list(unit) -> void:
	for child in _char_skills_box.get_children():
		_char_skills_box.remove_child(child)
		child.queue_free()
	var skills: Array = []
	if unit != null:
		for code in unit.get_skill_codes():
			if not SkillDatabase.COMBAT_EFFECTS.has(code):
				continue
			var skill = SkillDatabase.build(code)
			if skill != null:
				skills.append(skill)
	if skills.is_empty():
		_char_skills_box.visible = false
		return
	_char_skills_box.visible = true
	var title := Label.new()
	title.text = "Compétences :"
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", UITheme.TITLE)
	_char_skills_box.add_child(title)
	for skill in skills:
		var label := Label.new()
		label.text = skill.skill_name
		label.add_theme_font_size_override("font_size", 12)
		label.modulate = Color(0.85, 0.85, 0.85)
		label.mouse_filter = Control.MOUSE_FILTER_STOP
		label.tooltip_text = skill.get_tooltip_text()
		_char_skills_box.add_child(label)

# Appelée depuis HexGrid après un cast de sort, pour rafraîchir
# l'affichage de l'EA restante sans changer de tour.
# En-tête du tour (nom, PM restants, ressource) : appelée aussi après chaque
# déplacement, pour que les PM se décrémentent à l'écran pendant le tour.
func refresh_turn_header() -> void:
	if _turn_order.is_empty():
		return
	var unit = _turn_order[_current_index]
	var team_label = "Joueur" if unit.team == CombatUnit.Team.PLAYER else "Ennemi"
	var floor_prefix: String = ("Étage %d — " % TowerManager.current_floor) if TowerManager.run_active else ""
	_turn_label.text = floor_prefix + "Tour de : %s (%s) — PM: %d | %s" % [
		unit.unit_name, team_label, unit.current_pm, unit.get_resource_summary(true)
	]

func _clear_order_row() -> void:
	_set_highlight(null)
	if _order_row == null:
		return
	for child in _order_row.get_children():
		_order_row.remove_child(child)
		child.queue_free()

# Une pastille-token par unité, dans l'ordre du tour (celle qui joue est cerclée d'or).
func _rebuild_order_row() -> void:
	_clear_order_row()
	for i in range(_turn_order.size()):
		var unit = _turn_order[(_current_index + i) % _turn_order.size()]
		if not is_instance_valid(unit):
			continue
		_order_row.add_child(_make_order_token(unit, i == 0))

func _make_order_token(unit, is_current: bool) -> Control:
	var is_player: bool = unit.team == CombatUnit.Team.PLAYER
	var ring: Color = UITheme.GOLD if is_current else (unit.player_color if is_player else unit.enemy_color)
	var cell := PanelContainer.new()
	cell.custom_minimum_size = Vector2(32, 32)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.07, 0.1)
	style.border_color = ring
	style.set_border_width_all(3 if is_current else 2)
	style.set_corner_radius_all(16)
	style.set_content_margin_all(2)
	cell.add_theme_stylebox_override("panel", style)
	cell.mouse_filter = Control.MOUSE_FILTER_STOP
	cell.tooltip_text = "%s — PV %d / %d" % [unit.unit_name, unit.current_hp, unit.max_hp]

	var token := TokenDatabase.texture_for(unit)
	if token != null:
		var img := TextureRect.new()
		img.texture = token
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(img)
	else:
		var initial := Label.new()
		initial.text = unit.unit_name.substr(0, 1)
		initial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		initial.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		initial.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(initial)

	cell.mouse_entered.connect(func(): _set_highlight(unit))
	cell.mouse_exited.connect(func(): _set_highlight(null))
	return cell

# Surbrillance sur la grille — sauf pour une unité invisible aux yeux du
# joueur (ennemi invisible, cadavre retiré de la grille...).
func _set_highlight(unit) -> void:
	if _highlighted_unit != null and is_instance_valid(_highlighted_unit):
		_highlighted_unit.set_highlight(false)
	_highlighted_unit = null
	if unit == null or not is_instance_valid(unit) or not unit.is_inside_tree() or not unit.visible:
		return
	if unit.is_untargetable and unit.team != CombatUnit.Team.PLAYER:
		return
	unit.set_highlight(true)
	_highlighted_unit = unit

func refresh_ui() -> void:
	_update_ui()

func _clear_spell_buttons() -> void:
	for child in _spell_buttons_container.get_children():
		child.queue_free()

func _rebuild_spell_buttons(unit) -> void:
	_clear_spell_buttons()
	_spell_buttons_unit = unit

	# Les filtres n'ont d'intérêt que pour une classe qui a des sorts à
	# élément (le Mage) — invisibles pour les autres.
	var has_elemental_spells = false
	for spell in unit.spells:
		if not spell.elements.is_empty():
			has_elemental_spells = true
			break
	_element_filter_row.visible = has_elemental_spells

	# Rangées (une par sous-section), créées à la première utilisation.
	var sections: Dictionary = {}
	var order: Array = ["Attaques", "Sorts", "Pièges", "Compétences", "Inventaire (double-clic pour utiliser)"]
	for spell in unit.spells:
		# Filtre élémentaire : un sort SANS élément n'est jamais filtré. Un sort
		# AVEC éléments n'apparaît que si l'ensemble de ses éléments correspond
		# EXACTEMENT aux filtres actifs (aucun filtre actif = aucun sort à
		# élément affiché).
		if not spell.elements.is_empty():
			var active_count = 0
			var matches = true
			for el in _active_element_filters.keys():
				if _active_element_filters[el]:
					active_count += 1
					if not el in spell.elements:
						matches = false
			if active_count == 0 or active_count != spell.elements.size() or not matches:
				continue

		var section_name: String = _spell_section_for(spell)
		var row: HFlowContainer = _get_spell_section_row(sections, section_name)

		var button = Button.new()
		var icon_texture: Texture2D = spell.get_icon_texture()
		if icon_texture != null:
			button.icon = icon_texture
			button.expand_icon = true  # L'icône remplit le bouton.
			button.custom_minimum_size = Vector2(46, 46)
		else:
			button.text = spell.get_icon_text()
			button.custom_minimum_size = Vector2(42, 42)
			button.add_theme_font_size_override("font_size", 22)
		button.tooltip_text = spell.get_tooltip_text(unit)  # Coût + effet, affiché au survol par Godot.

		var can_afford = _hex_grid.can_afford_spell(unit, spell)
		var can_act = unit.can_perform_action(spell)
		button.disabled = not (can_afford and can_act)

		# Une attaque d'arme à distance passe d'abord par le choix de la
		# flèche ; tout le reste (mêlée, sorts) va direct au ciblage.
		var is_ranged_weapon_attack = spell.is_weapon_attack and spell.source_weapon != null \
			and spell.source_weapon.weapon_type == Weapon.WeaponType.RANGED

		if is_ranged_weapon_attack:
			button.pressed.connect(func(): _start_ranged_attack(spell, unit))
		else:
			button.pressed.connect(func(): _hex_grid.enter_targeting_mode(spell))

		row.add_child(button)

	if sections.has("Attaques"):
		_add_arrow_selector(unit, sections["Attaques"]["holder"])
	_add_inventory_section(unit, sections)

	# Ordre fixe des sous-sections (titre + rangée), quel que soit l'ordre de création.
	var idx := 0
	for name in order:
		if sections.has(name):
			var holder: Control = sections[name]["holder"]
			_spell_buttons_container.move_child(holder, idx)
			idx += 1

func _spell_section_for(spell: Spell) -> String:
	if spell.is_weapon_attack:
		return "Attaques"
	if spell.is_trap_spell:
		return "Pièges"
	if spell.is_detect_skill or spell.is_disarm_skill or spell.is_hobbit_bravoure or spell.is_hobbit_precision \
			or spell.is_ogre_pi or spell.is_samurai_concentration:
		return "Compétences"
	return "Sorts"

# Rangée de boutons d'une sous-section (crée le titre et la rangée au besoin).
func _get_spell_section_row(sections: Dictionary, section_name: String) -> HFlowContainer:
	if sections.has(section_name):
		return sections[section_name]["row"]
	var holder := VBoxContainer.new()
	holder.add_theme_constant_override("separation", 2)
	# Titre EN LIGNE devant les boutons (une ligne de moins par section).
	var title := Label.new()
	title.text = section_name.split(" (")[0] + " :"
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", UITheme.TITLE)
	title.custom_minimum_size = Vector2(0, 42)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 6)
	row.add_theme_constant_override("v_separation", 4)
	row.add_child(title)
	holder.add_child(row)
	_spell_buttons_container.add_child(holder)
	sections[section_name] = {"holder": holder, "row": row}
	return row

# Section Inventaire : potions et armes de rechange, utilisées au DOUBLE-CLIC
# (consomme l'action utilitaire du tour).
func _add_inventory_section(unit, sections: Dictionary) -> void:
	if unit.inventory_potions.is_empty() and unit.inventory_weapons.is_empty():
		return
	var row: HFlowContainer = _get_spell_section_row(sections, "Inventaire (double-clic pour utiliser)")
	var can_use: bool = unit.can_perform_action(unit.utility_action_slot) and unit.team == CombatUnit.Team.PLAYER and not _is_ai_turn_running()

	for potion in unit.inventory_potions:
		var btn := Button.new()
		btn.text = "%s %s" % [potion.get_icon_text(), potion.get_display_text()]
		btn.custom_minimum_size = Vector2(0, 36)
		btn.disabled = not can_use
		btn.tooltip_text = "Double-clic pour boire (action utilitaire du tour)."
		btn.gui_input.connect(func(event):
			if _is_double_click(event):
				_use_inventory_potion(unit, potion)
		)
		row.add_child(btn)

	for weapon in unit.inventory_weapons:
		_add_weapon_button(row, unit, weapon, false, can_use)
		# Personnage à deux armes : un second bouton pour la seconde main.
		if unit.can_equip_off_hand(weapon):
			_add_weapon_button(row, unit, weapon, true, can_use)

func _add_weapon_button(row: HFlowContainer, unit, weapon, off_hand: bool, can_use: bool) -> void:
	var can_dual: bool = unit.has_ambidextrie and not weapon.two_handed or unit.can_equip_off_hand(weapon)
	var wbtn := Button.new()
	var hand_text: String = ""
	if can_dual:
		hand_text = " · 2e main" if off_hand else " · main"
	wbtn.text = "⚔ %s (%d dégâts)%s" % [weapon.weapon_name, weapon.damage, hand_text]
	wbtn.custom_minimum_size = Vector2(0, 36)
	var block: String = unit.off_hand_block_reason(weapon) if off_hand else unit.main_hand_block_reason(weapon)
	wbtn.disabled = not can_use or block != ""
	wbtn.tooltip_text = weapon.get_display_text() + "\nDouble-clic pour équiper en %s (action utilitaire du tour)." % ("seconde main" if off_hand else "main principale")
	if weapon.two_handed:
		wbtn.text += " 🤲"
		wbtn.tooltip_text += "\nArme à 2 mains : occupe les deux mains (la seconde arme est rangée dans l'inventaire)."
	if block != "":
		wbtn.tooltip_text += "\n⛔ " + block
	wbtn.gui_input.connect(func(event):
		if _is_double_click(event):
			_equip_inventory_weapon(unit, weapon, off_hand)
	)
	row.add_child(wbtn)

func _is_double_click(event: InputEvent) -> bool:
	return event is InputEventMouseButton and event.pressed and event.double_click and event.button_index == MOUSE_BUTTON_LEFT

func _is_ai_turn_running() -> bool:
	return _hex_grid != null and _hex_grid.ai_turn_in_progress

func _use_inventory_potion(unit, potion) -> void:
	if _is_ai_turn_running() or unit.team != CombatUnit.Team.PLAYER:
		return
	var gained = unit.use_potion(potion)
	if gained >= 0:
		var is_heal = potion.potion_type == Potion.PotionType.HEAL
		var color = Color(0.35, 0.9, 0.5) if is_heal else Color(0.65, 0.45, 0.95)
		_hex_grid.spawn_floating_text(unit.position, "+%d %s" % [gained, "PV" if is_heal else "EA"], color)
		refresh_ui()

func _equip_inventory_weapon(unit, weapon, off_hand: bool = false) -> void:
	if _is_ai_turn_running() or unit.team != CombatUnit.Team.PLAYER:
		return
	var ok: bool = unit.equip_off_hand_weapon(weapon) if off_hand else unit.equip_weapon(weapon)
	if ok:
		refresh_ui()

# Remplace le symbole texte d'un bouton par l'icône d'interface `icon_name`
# (res://assets/spell_icons/ui/). Sans fichier, le symbole texte reste.
func _set_button_icon(button: Button, icon_name: String) -> void:
	var path: String = Spell.UI_ICON_FOLDER + icon_name + ".png"
	if not ResourceLoader.exists(path):
		return
	button.icon = load(path) as Texture2D
	button.expand_icon = true
	button.text = ""

# Appelée par HexGrid à chaque changement de sélection pendant un sort
# de terrain (voir _handle_terrain_selection_click) : met à jour le
# texte du bouton et l'active dès qu'au moins une case est choisie.
func update_terrain_selection_ui(count: int, max_count: int) -> void:
	_terrain_confirm_button.visible = true
	_terrain_confirm_button.text = "Valider (%d/%d case%s)" % [count, max_count, "s" if max_count > 1 else ""]
	_terrain_confirm_button.disabled = count == 0

func hide_terrain_selection_ui() -> void:
	_terrain_confirm_button.visible = false
	_terrain_confirm_button.disabled = true

func show_zone_hint(should_show: bool) -> void:
	_zone_hint_label.visible = should_show

# Appelée par HexGrid quand un sort à coût en PV vient d'être cliqué
# (voir Spell.is_ev_cost_spell) : ouvre le sélecteur, borné entre
# min_x et max_x (déjà plafonné par HexGrid à current_hp - 1 pour que
# le lanceur ne puisse jamais tomber à 0 PV en lançant).
func show_resurrection_picker(spell: Spell, corpses: Array) -> void:
	for child in _resurrect_list.get_children():
		child.queue_free()
	for corpse in corpses:
		var btn := Button.new()
		btn.text = "%s (PV max %d)" % [corpse.unit_name, corpse.max_hp]
		btn.pressed.connect(func():
			_resurrect_panel.visible = false
			_hex_grid.confirm_resurrection(spell, corpse)
		)
		_resurrect_list.add_child(btn)
	_resurrect_panel.visible = true

func show_ev_cost_picker(spell: Spell, min_x: int, max_x: int) -> void:
	_ev_cost_pending_spell = spell
	_ev_cost_spinbox.min_value = min_x
	_ev_cost_spinbox.max_value = max_x
	_ev_cost_spinbox.value = min_x
	_ev_cost_panel.visible = true

func _on_ev_cost_confirmed() -> void:
	if _ev_cost_pending_spell == null:
		return
	var spell = _ev_cost_pending_spell
	var x = int(_ev_cost_spinbox.value)
	_ev_cost_pending_spell = null
	_ev_cost_panel.visible = false
	_hex_grid.confirm_ev_cost_spell(spell, x)

# Appelée par HexGrid quand Substitution est cliquée (voir
# Spell.is_prestidigitateur_substitution) : ouvre la 1ère étape (choix
# de la stat à +4) du sélecteur.
func show_stat_picker_step1(spell: Spell) -> void:
	_stat_picker_pending_spell = spell
	_stat_picker_up_choice = ""
	_stat_picker_label.text = "Substitution : +4 à quelle statistique ?"
	_populate_stat_picker_buttons(STAT_OPTIONS, _on_stat_picker_up_chosen)
	_stat_picker_panel.visible = true

# 1ère étape validée : mémorise le choix, ouvre la 2e étape (choix de
# la stat à -4, parmi les 5 restantes — la même stat deux fois n'a pas
# de sens, s'annulerait).
func _on_stat_picker_up_chosen(field_name: String, label: String) -> void:
	_stat_picker_up_choice = field_name
	_stat_picker_label.text = "Substitution : -4 à quelle statistique ? (+4 %s déjà choisi)" % label
	var remaining = STAT_OPTIONS.filter(func(opt): return opt[0] != field_name)
	_populate_stat_picker_buttons(remaining, _on_stat_picker_down_chosen)

# 2e étape validée : les deux choix sont faits, on délègue la
# résolution (test INT, application du buff) à HexGrid.
func _on_stat_picker_down_chosen(field_name: String, label: String) -> void:
	var spell = _stat_picker_pending_spell
	var up = _stat_picker_up_choice
	_stat_picker_panel.visible = false
	_stat_picker_pending_spell = null
	_hex_grid.confirm_substitution(spell, up, field_name)

# Reconstruit la rangée de boutons du sélecteur de statistique à
# partir d'une liste d'options (voir STAT_OPTIONS) — réutilisée pour
# les deux étapes, avec des options et un callback différents.
func _populate_stat_picker_buttons(options: Array, callback: Callable) -> void:
	for child in _stat_picker_buttons_row.get_children():
		child.queue_free()
	for opt in options:
		var field_name: String = opt[0]
		var label: String = opt[1]
		var btn = Button.new()
		btn.text = label
		btn.pressed.connect(func(): callback.call(field_name, label))
		_stat_picker_buttons_row.add_child(btn)

# Appelée quand un bouton de filtre élémentaire est basculé (voir
# _build_ui) : met à jour l'état actif puis régénère les boutons de
# sorts affichés en conséquence.
func _on_element_filter_toggled(element: String, pressed: bool) -> void:
	_active_element_filters[element] = pressed
	if _spell_buttons_unit != null:
		_rebuild_spell_buttons(_spell_buttons_unit)

# ---------- Fiche personnage (consultation, indépendante du tour actif) ----------

# Appelée par HexGrid à chaque clic sur une unité (active ou non).
func show_character_panel(unit) -> void:
	_inspected_unit = unit
	_render_character_panel()

func _render_character_panel() -> void:
	if _inspected_unit == null or not is_instance_valid(_inspected_unit):
		_char_name_label.text = "Clique sur une unité"
		_char_team_label.text = ""
		_char_hp_bar.visible = false
		_char_hp_label.text = ""
		_char_ea_label.text = ""
		_char_stats_label.text = ""
		return

	var unit = _inspected_unit
	var is_player = unit.team == CombatUnit.Team.PLAYER

	_char_name_label.text = unit.unit_name
	_char_team_label.text = "Joueur" if is_player else "Ennemi"
	_char_team_label.modulate = unit.player_color if is_player else unit.enemy_color

	_char_hp_bar.visible = true
	_char_hp_bar.max_value = unit.max_hp
	_char_hp_bar.value = unit.current_hp
	_char_hp_label.text = "PV : %d / %d" % [unit.current_hp, unit.max_hp]

	# Ressource propre à la classe : Rage (Berzerk), Gloire (Gladiateur),
	# PA (Prêtre), EA sinon.
	_char_ea_label.text = unit.get_resource_summary()
	_char_stats_label.text = (
		"Courage : %d\n" +
		"Attaque : %d\n" +
		"Parade : %d\n" +
		"Adresse : %d\n" +
		"Force : %d\n" +
		"Intelligence : %d\n" +
		"Charisme : %d\n" +
		"Chance : %d"
	) % [
		unit.courage,
		unit.attack_stat,
		unit.parade_stat,
		unit.adresse_stat,
		unit.force_stat,
		unit.intelligence_stat,
		unit.charisme_stat,
		unit.chance_stat,
	]

# Appelée par HexGrid quand une unité meurt (via son signal "died") :
# on la retire de la file d'initiative et on ajuste l'index courant
# pour ne pas sauter ou répéter un tour.
# Insère une nouvelle unité dans l'ordre du tour, juste après
# `after_unit` (typiquement le lanceur d'un sort d'invocation — voir
# HexGrid._cast_summon_spell) plutôt qu'à une position basée sur son
# Courage, pour qu'elle entre en jeu rapidement après son invocation.
func add_unit_to_turn_order(unit, after_unit) -> void:
	var idx = _turn_order.find(after_unit)
	if idx == -1:
		_turn_order.append(unit)
		_update_ui()
		return

	_turn_order.insert(idx + 1, unit)

	# Ne devrait pas arriver (after_unit est censé être l'unité en train
	# de jouer, donc idx == _current_index), mais sécurité si jamais
	# l'insertion se fait avant l'index courant.
	if idx + 1 <= _current_index:
		_current_index += 1

	_update_ui()

func remove_unit(unit) -> void:
	var idx = _turn_order.find(unit)
	if idx == -1:
		return

	_turn_order.remove_at(idx)

	if _turn_order.is_empty():
		_update_ui()
		return

	if idx < _current_index:
		_current_index -= 1
	elif idx == _current_index:
		# L'unité qui vient de mourir était en train de jouer :
		# on passe simplement à la suivante (index inchangé après
		# suppression, puisque la liste s'est décalée).
		_current_index = _current_index % _turn_order.size()
		_start_current_turn()
		_render_character_panel()
		return

	_current_index = _current_index % _turn_order.size()
	_update_ui()
	_render_character_panel()

# Variante utilisée quand le combat vient tout juste de se terminer :
# on nettoie juste la file (pour l'affichage) sans jamais démarrer de
# tour suivant, puisque le combat est fini.
func remove_unit_after_combat_end(unit) -> void:
	var idx = _turn_order.find(unit)
	if idx == -1:
		return

	_turn_order.remove_at(idx)

	if idx < _current_index:
		_current_index -= 1

	if not _turn_order.is_empty():
		_current_index = _current_index % _turn_order.size()

	_render_character_panel()

# Affiche l'écran de fin de combat (victoire/défaite/égalité) et
# désactive toute interaction restante (sorts, fin de tour, inventaire).
func show_combat_end(result: String) -> void:
	_clear_spell_buttons()
	_end_turn_button.disabled = true
	_stance_parry_button.disabled = true
	_stance_dodge_button.disabled = true

	var message: String
	var color: Color

	match result:
		"victory":
			message = "Victoire !"
			color = Color(0.35, 0.9, 0.45)
		"defeat":
			message = "Défaite..."
			color = Color(0.9, 0.35, 0.35)
		_:
			message = "Match nul."
			color = Color(0.8, 0.8, 0.8)

	_turn_label.text = message
	_turn_label.modulate = color
	_clear_order_row()

	_show_center_banner(message, color, result)

# Bannière centrée à l'écran, plus visible qu'un simple label en coin.
# Si ce combat vient d'une rencontre d'exploration, ajoute un bouton
# "Continuer" qui synchronise l'état du joueur et ramène à la zone
# (voir _return_to_exploration) — sinon (test manuel de la scène de
# combat), la bannière reste seule, sans transition automatique.
func _show_center_banner(message: String, color: Color, result: String) -> void:
	var overlay = CanvasLayer.new()
	add_child(overlay)

	var full_rect = Control.new()
	full_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	full_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(full_rect)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	full_rect.add_child(center)

	full_rect.theme = UITheme.build_theme()
	var banner_panel = PanelContainer.new()
	banner_panel.add_theme_stylebox_override("panel", UITheme.panel_style(UITheme.GOLD, 10, 28, 0.9))
	center.add_child(banner_panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 24)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	banner_panel.add_child(vbox)

	var banner_text: String = message
	if TowerManager.run_active:
		if result == "victory":
			banner_text += "\nÉtage %d franchi — +%d XP à chaque aventurier" % [TowerManager.current_floor, TowerFloors.get_floor_xp(TowerManager.current_floor)]
		else:
			banner_text += "\nAscension terminée — %d étage(s) franchi(s)" % TowerManager.floors_cleared

	var banner = Label.new()
	banner.text = banner_text
	banner.add_theme_font_size_override("font_size", 40)
	banner.modulate = color
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(banner)

	if WorldManager.combat_from_encounter:
		var continue_button = Button.new()
		continue_button.text = "Continuer"
		continue_button.custom_minimum_size = Vector2(160, 44)
		UITheme.style_primary_button(continue_button)
		continue_button.pressed.connect(func(): _return_to_exploration(result))
		vbox.add_child(continue_button)
	elif TowerManager.run_active:
		var tower_button = Button.new()
		tower_button.text = "Étage suivant" if result == "victory" else "Terminer l'ascension"
		tower_button.custom_minimum_size = Vector2(220, 44)
		UITheme.style_primary_button(tower_button)
		tower_button.pressed.connect(func():
			tower_button.disabled = true  # Un double clic enchaînerait deux changements de scène.
			_finish_tower_floor(result)
		)
		vbox.add_child(tower_button)

# Synchronise l'état du joueur (PV/EA de fin de combat en cas de
# victoire) puis délègue à WorldManager le retour à la zone
# d'exploration (récompenses, réapparition en cas de défaite, etc.).
func _return_to_exploration(result: String) -> void:
	var victory = (result == "victory")
	var surviving_hp = 0
	var surviving_ea = 0
	var human_enemies_fought = 0

	if victory and _hex_grid != null:
		var player_unit = _hex_grid.get_player_unit()
		if player_unit != null:
			surviving_hp = player_unit.current_hp
			surviving_ea = player_unit.current_ea
		human_enemies_fought = _hex_grid.human_enemies_fought

	WorldManager.finish_encounter_combat(victory, surviving_hp, surviving_ea, human_enemies_fought)
