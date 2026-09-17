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

	_spell_buttons_container = HBoxContainer.new()
	_spell_buttons_container.add_theme_constant_override("separation", 6)
	vbox.add_child(_spell_buttons_container)

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
	stance_row.add_child(_stance_parry_button)

	_stance_dodge_button = Button.new()
	_stance_dodge_button.text = "↯"
	_stance_dodge_button.tooltip_text = "Esquive — annule n'importe quelle attaque si le jet réussit, 1 attaque sur 2 seulement."
	_stance_dodge_button.custom_minimum_size = Vector2(44, 44)
	_stance_dodge_button.add_theme_font_size_override("font_size", 20)
	_stance_dodge_button.toggle_mode = true
	_stance_dodge_button.button_group = _stance_group
	_stance_dodge_button.pressed.connect(func(): _set_active_unit_stance(CombatUnit.DefensiveStance.DODGE))
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
	bottom_row.add_child(_inventory_button)

	_end_turn_button = Button.new()
	_end_turn_button.text = "➡"
	_end_turn_button.tooltip_text = "Fin de tour"
	_end_turn_button.custom_minimum_size = Vector2(44, 44)
	_end_turn_button.add_theme_font_size_override("font_size", 20)
	_end_turn_button.pressed.connect(_on_end_turn_pressed)
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
			augmented.damage = spell.damage + arrow.damage_bonus
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

	_turn_order = units.duplicate()
	_turn_order.sort_custom(func(a, b): return a.courage > b.courage)

	_current_index = 0
	_start_current_turn()

func _start_current_turn() -> void:
	if _turn_order.is_empty():
		_update_ui()
		return

	var unit = _turn_order[_current_index]
	_hex_grid.set_active_unit(unit)
	_update_ui()

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
	_turn_label.text = "Tour de : %s (%s) — PM: %d | EA: %d" % [
		unit.unit_name, team_label, unit.current_pm, unit.current_ea
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

	for spell in unit.spells:
		var button = Button.new()
		button.text = spell.get_icon_text()
		button.tooltip_text = spell.get_display_text()  # Affiché nativement au survol par Godot.
		button.custom_minimum_size = Vector2(48, 48)
		button.add_theme_font_size_override("font_size", 22)

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

	_show_center_banner(message, color)

# Bannière centrée à l'écran, plus visible qu'un simple label en coin.
func _show_center_banner(message: String, color: Color) -> void:
	var overlay = CanvasLayer.new()
	add_child(overlay)

	var full_rect = Control.new()
	full_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	full_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(full_rect)

	var banner = Label.new()
	banner.text = message
	banner.add_theme_font_size_override("font_size", 48)
	banner.modulate = color
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner.set_anchors_preset(Control.PRESET_FULL_RECT)
	full_rect.add_child(banner)
