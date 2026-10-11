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
var _turn_order: Array = []

# Index de l'unité dont c'est le tour dans _turn_order.
var _current_index: int = 0

# Référence vers le node HexGrid (son parent), assignée dans start_combat().
var _hex_grid = null

var _turn_label: Label
var _order_label: Label
var _spell_buttons_container: HBoxContainer
var _terrain_confirm_button: Button
var _zone_hint_label: Label
var _ev_cost_panel: HBoxContainer
var _ev_cost_spinbox: SpinBox
var _ev_cost_pending_spell: Spell = null

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
var _element_filter_row: HBoxContainer

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
var _inventory_button: Button

# --- Posture défensive (choisie à son tour, active jusqu'au suivant) ---
var _stance_group: ButtonGroup
var _stance_parry_button: Button
var _stance_dodge_button: Button

# --- Fiche personnage (haut à droite) ---
var _char_panel: PanelContainer
var _char_name_label: Label
var _char_team_label: Label
var _char_hp_bar: ProgressBar
var _char_hp_label: Label
var _char_ea_label: Label
var _char_stats_label: Label

# Unité actuellement affichée dans la fiche personnage (peut être
# n'importe quelle unité cliquée, pas forcément celle dont c'est le tour).
var _inspected_unit = null

## Vrai : les unités ennemies sont jouées par l'IA (voir EnemyAI) au lieu
## d'être pilotées à la main. Activé pour la Tour de l'infini ; faux pour un
## combat de test, qui reste en pilotage manuel des deux camps.
var enemy_ai_enabled: bool = false

# --- Popups (inventaire et choix de flèche) ---
var _inventory_popup: PopupPanel
var _inventory_list_container: VBoxContainer
var _arrow_popup: PopupPanel
var _arrow_list_container: VBoxContainer

func _ready() -> void:
	_build_ui()

# Construit une UI minimale en pur code : un panneau en haut à gauche
# avec le nom de l'unité active et le bouton pour finir son tour.
func _build_ui() -> void:
	var canvas = CanvasLayer.new()
	add_child(canvas)

	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_TOP_LEFT)
	margin.position = Vector2(16, 16)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	canvas.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	_turn_label = Label.new()
	_turn_label.add_theme_font_size_override("font_size", 22)
	vbox.add_child(_turn_label)

	_order_label = Label.new()
	_order_label.add_theme_font_size_override("font_size", 14)
	_order_label.modulate = Color(0.75, 0.75, 0.75)
	vbox.add_child(_order_label)

	var spells_title = Label.new()
	spells_title.text = "Sorts / Attaques :"
	spells_title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(spells_title)

	# Filtres élémentaires (voir Spell.elements) : AUCUN sort à élément
	# affiché par défaut, seuls les filtres activés en montrent —
	# plusieurs actifs à la fois montre les sorts dont TOUS les éléments
	# sont couverts (un sort Double Eau+Feu n'apparaît qu'avec les deux
	# filtres Eau ET Feu activés). Les sorts sans élément (attaque
	# d'arme, autres classes) restent toujours affichés, non filtrés.
	_element_filter_row = HBoxContainer.new()
	_element_filter_row.add_theme_constant_override("separation", 4)
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

	_spell_buttons_container = HBoxContainer.new()
	_spell_buttons_container.add_theme_constant_override("separation", 6)
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

	var stance_title = Label.new()
	stance_title.text = "Posture défensive :"
	stance_title.add_theme_font_size_override("font_size", 14)
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

	var bottom_row = HBoxContainer.new()
	bottom_row.add_theme_constant_override("separation", 8)
	vbox.add_child(bottom_row)

	_inventory_button = Button.new()
	_inventory_button.text = "☰"
	_inventory_button.tooltip_text = "Inventaire"
	_inventory_button.custom_minimum_size = Vector2(44, 44)
	_inventory_button.add_theme_font_size_override("font_size", 20)
	_inventory_button.pressed.connect(_on_inventory_pressed)
	_set_button_icon(_inventory_button, "inventaire")
	bottom_row.add_child(_inventory_button)

	_end_turn_button = Button.new()
	_end_turn_button.text = "➡"
	_end_turn_button.tooltip_text = "Fin de tour"
	_end_turn_button.custom_minimum_size = Vector2(44, 44)
	_end_turn_button.add_theme_font_size_override("font_size", 20)
	_end_turn_button.pressed.connect(_on_end_turn_pressed)
	_set_button_icon(_end_turn_button, "fin_du_tour")
	bottom_row.add_child(_end_turn_button)

	_build_character_panel(canvas)
	_build_inventory_popup(canvas)
	_build_arrow_popup(canvas)

# Construit l'encadré "fiche personnage" en haut à droite de l'écran :
# affiche le nom, l'équipe et les PV de la dernière unité cliquée
# (n'importe laquelle, active ou non — simple consultation).
func _build_character_panel(canvas: CanvasLayer) -> void:
	_char_panel = PanelContainer.new()

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.1, 0.85)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(12)
	_char_panel.add_theme_stylebox_override("panel", style)

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
	char_vbox.add_child(_char_name_label)

	_char_team_label = Label.new()
	_char_team_label.add_theme_font_size_override("font_size", 13)
	char_vbox.add_child(_char_team_label)

	_char_hp_bar = ProgressBar.new()
	_char_hp_bar.custom_minimum_size = Vector2(0, 18)
	_char_hp_bar.show_percentage = false
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

	_render_character_panel()  # État initial : placeholder "aucune unité".

# ---------- Popup Inventaire (potions + changement d'arme) ----------

func _build_inventory_popup(canvas: CanvasLayer) -> void:
	_inventory_popup = PopupPanel.new()
	_inventory_popup.min_size = Vector2(260, 0)
	canvas.add_child(_inventory_popup)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	_inventory_popup.add_child(margin)

	_inventory_list_container = VBoxContainer.new()
	_inventory_list_container.add_theme_constant_override("separation", 6)
	margin.add_child(_inventory_list_container)

func _on_inventory_pressed() -> void:
	if _turn_order.is_empty():
		return

	var unit = _turn_order[_current_index]

	for child in _inventory_list_container.get_children():
		child.queue_free()

	var has_content = false

	if not unit.inventory_potions.is_empty():
		has_content = true
		var potions_title = Label.new()
		potions_title.text = "Potions :"
		potions_title.add_theme_font_size_override("font_size", 14)
		_inventory_list_container.add_child(potions_title)

		for potion in unit.inventory_potions:
			var btn = Button.new()
			btn.text = potion.get_display_text()
			btn.disabled = not unit.can_perform_action(unit.utility_action_slot)
			btn.pressed.connect(func():
				var gained = unit.use_potion(potion)
				if gained >= 0:
					_inventory_popup.hide()
					var is_heal = potion.potion_type == Potion.PotionType.HEAL
					var color = Color(0.35, 0.9, 0.5) if is_heal else Color(0.65, 0.45, 0.95)
					var suffix = "PV" if is_heal else "EA"
					_hex_grid.spawn_floating_text(unit.position, "+%d %s" % [gained, suffix], color)
					refresh_ui()
			)
			_inventory_list_container.add_child(btn)

	if not unit.inventory_weapons.is_empty():
		has_content = true
		var weapons_title = Label.new()
		weapons_title.text = "Changer d'arme :"
		weapons_title.add_theme_font_size_override("font_size", 14)
		_inventory_list_container.add_child(weapons_title)

		for weapon in unit.inventory_weapons:
			var btn = Button.new()
			btn.text = "%s (%d dégâts)" % [weapon.weapon_name, weapon.damage]
			btn.disabled = not unit.can_perform_action(unit.utility_action_slot)
			btn.pressed.connect(func():
				if unit.equip_weapon(weapon):
					_inventory_popup.hide()
					refresh_ui()
			)
			_inventory_list_container.add_child(btn)

	if not has_content:
		var empty_label = Label.new()
		empty_label.text = "Inventaire vide."
		_inventory_list_container.add_child(empty_label)

	_inventory_popup.popup_centered()

# ---------- Popup choix de flèche (arme à distance) ----------

func _build_arrow_popup(canvas: CanvasLayer) -> void:
	_arrow_popup = PopupPanel.new()
	_arrow_popup.min_size = Vector2(240, 0)
	canvas.add_child(_arrow_popup)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	_arrow_popup.add_child(margin)

	_arrow_list_container = VBoxContainer.new()
	_arrow_list_container.add_theme_constant_override("separation", 6)
	margin.add_child(_arrow_list_container)

# Ouvre le choix de munition pour une attaque d'arme à distance. Si
# l'unité n'a aucune flèche en inventaire, on tire directement avec
# les dégâts de base de l'arme (pas de popup superflu).
func _open_arrow_popup(spell: Spell, unit) -> void:
	if unit.inventory_arrows.is_empty():
		_hex_grid.enter_targeting_mode(spell)
		return

	for child in _arrow_list_container.get_children():
		child.queue_free()

	var title = Label.new()
	title.text = "Choisis ta flèche :"
	title.add_theme_font_size_override("font_size", 14)
	_arrow_list_container.add_child(title)

	for arrow in unit.inventory_arrows:
		var btn = Button.new()
		btn.text = arrow.get_display_text()
		btn.disabled = arrow.quantity <= 0
		btn.pressed.connect(func():
			if arrow.quantity <= 0:
				return  # Sécurité (le bouton devrait déjà être désactivé).

			arrow.quantity -= 1

			var augmented: Spell = spell.duplicate()
			augmented.origin_spell = spell  # Le suivi "déjà utilisé" compte sur le sort d'origine.
			augmented.source_weapon = spell.source_weapon  # Explicite, par sécurité (ne pas dépendre du comportement de duplicate() sur les champs non-@export).
			augmented.damage = spell.damage + arrow.damage_bonus  # Pour l'affichage (tooltip) uniquement.
			augmented.flat_damage_bonus = arrow.damage_bonus  # Pour les dégâts RÉELS (voir HexGrid._resolve_weapon_attack).
			augmented.spell_name = "%s [%s]" % [spell.spell_name, arrow.arrow_name]
			_arrow_popup.hide()
			_hex_grid.enter_targeting_mode(augmented)
		)
		_arrow_list_container.add_child(btn)

	_arrow_popup.popup_centered()

# Appelée par HexGrid une fois toutes les unités de départ placées.
# Construit la file d'initiative et démarre le premier tour.
func start_combat(units: Array) -> void:
	_hex_grid = get_parent()
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
		_hex_grid.spawn_floating_text(unit.position, "-%d (%s)" % [tick["amount"], tick["label"]], Color(0.85, 0.25, 0.15))

	if not is_instance_valid(unit) or unit.current_hp <= 0:
		return  # Morte entre-temps (ex: Brûlure) — le retrait du tour s'en occupe déjà.

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
	_inventory_button.disabled = not enabled
	_stance_parry_button.disabled = not enabled
	_stance_dodge_button.disabled = not enabled

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
	if _turn_order.is_empty():
		_turn_label.text = "Combat terminé !"
		_order_label.text = ""
		_clear_spell_buttons()
		return

	var unit = _turn_order[_current_index]
	var team_label = "Joueur" if unit.team == CombatUnit.Team.PLAYER else "Ennemi"
	var floor_prefix: String = ("Étage %d — " % TowerManager.current_floor) if TowerManager.run_active else ""
	var resource_text: String = ("Rage: %d" % unit.rage) if unit.has_metier("Berzerk") else ("EA: %d" % unit.current_ea)
	_turn_label.text = floor_prefix + "Tour de : %s (%s) — PM: %d | %s" % [
		unit.unit_name, team_label, unit.current_pm, resource_text
	]

	var upcoming: Array = []
	for i in range(1, _turn_order.size()):
		var idx = (_current_index + i) % _turn_order.size()
		upcoming.append(_turn_order[idx].unit_name)
	_order_label.text = "À suivre : " + " → ".join(upcoming)

	_rebuild_spell_buttons(unit)
	_render_character_panel()
	_sync_stance_buttons(unit)

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

# Appelée depuis HexGrid après un cast de sort, pour rafraîchir
# l'affichage de l'EA restante sans changer de tour.
func refresh_ui() -> void:
	_update_ui()

func _clear_spell_buttons() -> void:
	for child in _spell_buttons_container.get_children():
		child.queue_free()

func _rebuild_spell_buttons(unit) -> void:
	_clear_spell_buttons()
	_spell_buttons_unit = unit

	# Les filtres n'ont d'intérêt que pour une classe qui a des sorts à
	# élément (le Mage) — invisibles pour les autres, pas de boutons
	# inutiles à regarder.
	var has_elemental_spells = false
	for spell in unit.spells:
		if not spell.elements.is_empty():
			has_elemental_spells = true
			break
	_element_filter_row.visible = has_elemental_spells

	for spell in unit.spells:
		# Filtre élémentaire : un sort SANS élément (attaque d'arme,
		# sorts des autres classes) n'est jamais filtré. Un sort AVEC
		# éléments n'apparaît que si TOUS ses éléments sont couverts par
		# les filtres actifs (aucun filtre actif = aucun sort à élément
		# affiché).
		# Filtre élémentaire : un sort SANS élément (attaque d'arme,
		# sorts des autres classes) n'est jamais filtré. Un sort AVEC
		# éléments n'apparaît que si l'ensemble de ses éléments correspond
		# EXACTEMENT aux filtres actifs — Feu seul montre les sorts Feu
		# uniquement, Feu+Eau montre UNIQUEMENT la Vapeur (pas Feu ni Eau
		# en plus). Aucun filtre actif = aucun sort à élément affiché.
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

		var button = Button.new()
		var icon_texture: Texture2D = spell.get_icon_texture()
		if icon_texture != null:
			button.icon = icon_texture
			button.expand_icon = true  # L'icône remplit le bouton.
			button.custom_minimum_size = Vector2(56, 56)
		else:
			button.text = spell.get_icon_text()
			button.custom_minimum_size = Vector2(48, 48)
			button.add_theme_font_size_override("font_size", 22)
		button.tooltip_text = spell.get_display_text()  # Affiché nativement au survol par Godot.

		var can_afford = unit.current_ea >= spell.get_effective_ea_cost()
		var can_act = unit.can_perform_action(spell)
		button.disabled = not (can_afford and can_act)

		# Une attaque d'arme à distance passe d'abord par le choix de la
		# flèche ; tout le reste (mêlée, sorts) va direct au ciblage.
		var is_ranged_weapon_attack = spell.is_weapon_attack and spell.source_weapon != null \
			and spell.source_weapon.weapon_type == Weapon.WeaponType.RANGED

		if is_ranged_weapon_attack:
			button.pressed.connect(func(): _open_arrow_popup(spell, unit))
		else:
			button.pressed.connect(func(): _hex_grid.enter_targeting_mode(spell))

		_spell_buttons_container.add_child(button)

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

	# Le Berzerk n'a pas d'EA : sa ressource est la Rage.
	if unit.has_metier("Berzerk"):
		_char_ea_label.text = "Rage : %d" % unit.rage
	else:
		_char_ea_label.text = "EA : %d / %d" % [unit.current_ea, unit.max_ea]

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
	_inventory_button.disabled = true
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
	_order_label.text = ""

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

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 24)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vbox)

	var banner_text: String = message
	if TowerManager.run_active:
		if result == "victory":
			banner_text += "\nÉtage %d franchi — +%d XP à chaque aventurier" % [TowerManager.current_floor, TowerFloors.get_floor_xp(TowerManager.current_floor)]
		else:
			banner_text += "\nAscension terminée — %d étage(s) franchi(s)" % TowerManager.floors_cleared

	var banner = Label.new()
	banner.text = banner_text
	banner.add_theme_font_size_override("font_size", 48)
	banner.modulate = color
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(banner)

	if WorldManager.combat_from_encounter:
		var continue_button = Button.new()
		continue_button.text = "Continuer"
		continue_button.custom_minimum_size = Vector2(160, 44)
		continue_button.pressed.connect(func(): _return_to_exploration(result))
		vbox.add_child(continue_button)
	elif TowerManager.run_active:
		var tower_button = Button.new()
		tower_button.text = "Étage suivant" if result == "victory" else "Terminer l'ascension"
		tower_button.custom_minimum_size = Vector2(220, 44)
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
