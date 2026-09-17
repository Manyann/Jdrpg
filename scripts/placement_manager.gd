extends Node

# ============================================================
# placement_manager.gd
# Gère la phase de placement des unités avant le début du combat :
# choix d'une configuration (Classique / Embuscade / Défense), puis
# séquence de placement interactive case par case.
#
# INSTALLATION :
# 1. Ajoute un node "Node" (simple) comme enfant du node HexGrid,
#    au même niveau que TurnManager.
# 2. Attache-lui ce script.
# 3. Sélectionne le node HexGrid, et dans l'inspecteur, glisse ce
#    nouveau node dans le champ "Placement Manager Path".
#
# Tant que ce champ n'est pas renseigné, HexGrid garde son ancien
# comportement (placement automatique instantané) — cette étape est
# donc entièrement optionnelle.
# ============================================================

enum Mode { CLASSIC, AMBUSH, DEFENSE }

var _hex_grid = null
var _mode: int = Mode.CLASSIC

# Files des unités déjà construites (stats/sorts/inventaire prêts)
# mais pas encore positionnées sur la grille.
var _player_queue: Array = []
var _enemy_queue: Array = []

# Séquence de placement à exécuter : liste de {unit, zone}, une entrée
# par unité à poser, dans l'ordre. _plan_index avance à chaque case
# cliquée avec succès (voir on_unit_placed).
var _plan: Array = []
var _plan_index: int = 0

# --- UI ---
var _mode_panel: PanelContainer
var _status_panel: PanelContainer
var _status_label: Label

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	var canvas = CanvasLayer.new()
	add_child(canvas)

	# Panneau de choix de configuration, centré à l'écran.
	var center_container = CenterContainer.new()
	center_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Important : sans ça, ce conteneur plein écran absorbe TOUS les clics
	# (y compris ceux destinés aux boutons de TurnManager) même une fois
	# son contenu masqué, puisque le filtre par défaut d'un Control est
	# MOUSE_FILTER_STOP peu importe la visibilité de ses enfants.
	center_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(center_container)

	_mode_panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.1, 0.92)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(20)
	_mode_panel.add_theme_stylebox_override("panel", style)
	_mode_panel.visible = false
	center_container.add_child(_mode_panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	_mode_panel.add_child(vbox)

	var title = Label.new()
	title.text = "Choisis une configuration de placement :"
	title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title)

	var classic_btn = Button.new()
	classic_btn.text = "Classique"
	classic_btn.tooltip_text = "Chaque camp place ses unités sur sa zone, chacun son tour."
	classic_btn.custom_minimum_size = Vector2(260, 44)
	classic_btn.pressed.connect(func(): _on_mode_chosen(Mode.CLASSIC))
	vbox.add_child(classic_btn)

	var ambush_btn = Button.new()
	ambush_btn.text = "Embuscade"
	ambush_btn.tooltip_text = "L'adversaire place d'abord ses unités au centre, puis tu places les tiennes autour."
	ambush_btn.custom_minimum_size = Vector2(260, 44)
	ambush_btn.pressed.connect(func(): _on_mode_chosen(Mode.AMBUSH))
	vbox.add_child(ambush_btn)

	var defense_btn = Button.new()
	defense_btn.text = "Défense"
	defense_btn.tooltip_text = "Tu places d'abord tes unités au centre, puis l'adversaire place les siennes autour."
	defense_btn.custom_minimum_size = Vector2(260, 44)
	defense_btn.pressed.connect(func(): _on_mode_chosen(Mode.DEFENSE))
	vbox.add_child(defense_btn)

	# Bandeau de statut ("Placement : Joueur — Barbare"), centré en haut.
	_status_panel = PanelContainer.new()
	var status_style = StyleBoxFlat.new()
	status_style.bg_color = Color(0.08, 0.08, 0.1, 0.85)
	status_style.set_corner_radius_all(8)
	status_style.set_content_margin_all(10)
	_status_panel.add_theme_stylebox_override("panel", status_style)
	_status_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_status_panel.position = Vector2(0, 16)
	_status_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_status_panel.visible = false
	canvas.add_child(_status_panel)

	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 16)
	_status_panel.add_child(_status_label)

# Appelée par HexGrid une fois la grille prête. Construit les unités
# des deux camps (à partir des tableaux déjà configurés sur HexGrid :
# player_units, enemy_units, player_courage, enemy_courage) sans les
# placer, puis affiche le choix de configuration.
func start_placement_phase(hex_grid) -> void:
	_hex_grid = hex_grid
	_build_unit_queues()
	_mode_panel.visible = true

func _build_unit_queues() -> void:
	_player_queue.clear()
	_enemy_queue.clear()

	for i in range(_hex_grid.player_units.size()):
		var courage = _hex_grid.player_courage[i] if i < _hex_grid.player_courage.size() else -1
		_player_queue.append(_hex_grid.build_unit(CombatUnit.Team.PLAYER, _hex_grid.player_units[i], courage))

	for i in range(_hex_grid.enemy_units.size()):
		var courage = _hex_grid.enemy_courage[i] if i < _hex_grid.enemy_courage.size() else -1
		_enemy_queue.append(_hex_grid.build_unit(CombatUnit.Team.ENEMY, _hex_grid.enemy_units[i], courage))

func _on_mode_chosen(mode: int) -> void:
	if _hex_grid == null:
		push_warning("PlacementManager: _hex_grid non initialisé — vérifie que le champ 'Placement Manager Path' est bien renseigné sur le node HexGrid dans l'inspecteur.")
		return

	_mode = mode
	_mode_panel.visible = false
	_status_panel.visible = true

	match mode:
		Mode.CLASSIC:
			_plan = _build_classic_plan()
		Mode.AMBUSH:
			# L'adversaire place au centre en premier, puis le joueur autour.
			_plan = _build_zone_plan(
				_enemy_queue, _hex_grid.get_center_zone_cells(_hex_grid.center_zone_radius),
				_player_queue, _hex_grid.get_outer_zone_cells(_hex_grid.center_zone_radius)
			)
		Mode.DEFENSE:
			# Le joueur place au centre en premier, puis l'adversaire autour.
			_plan = _build_zone_plan(
				_player_queue, _hex_grid.get_center_zone_cells(_hex_grid.center_zone_radius),
				_enemy_queue, _hex_grid.get_outer_zone_cells(_hex_grid.center_zone_radius)
			)

	_plan_index = 0
	_advance_plan()

# Classique : les deux camps placent sur leur colonne habituelle, en
# alternant un placement à la fois (joueur, ennemi, joueur, ennemi...).
func _build_classic_plan() -> Array:
	var plan: Array = []
	var player_zone = _hex_grid.get_player_zone_cells()
	var enemy_zone = _hex_grid.get_enemy_zone_cells()

	var i = 0
	var j = 0
	while i < _player_queue.size() or j < _enemy_queue.size():
		if i < _player_queue.size():
			plan.append({"unit": _player_queue[i], "zone": player_zone})
			i += 1
		if j < _enemy_queue.size():
			plan.append({"unit": _enemy_queue[j], "zone": enemy_zone})
			j += 1

	return plan

# Embuscade/Défense : le premier camp place TOUTES ses unités dans sa
# zone, puis le second camp place toutes les siennes dans l'autre zone.
func _build_zone_plan(first_queue: Array, first_zone: Dictionary, second_queue: Array, second_zone: Dictionary) -> Array:
	var plan: Array = []

	for unit in first_queue:
		plan.append({"unit": unit, "zone": first_zone})

	for unit in second_queue:
		plan.append({"unit": unit, "zone": second_zone})

	return plan

func _advance_plan() -> void:
	if _plan_index >= _plan.size():
		_finish_placement()
		return

	var step = _plan[_plan_index]
	var unit = step["unit"]
	var zone = step["zone"]

	_update_status_label(unit)
	_hex_grid.start_placement(unit, zone)

func _update_status_label(unit) -> void:
	var team_label = "Joueur" if unit.team == CombatUnit.Team.PLAYER else "Ennemi"
	_status_label.text = "Placement : %s — %s (clique une case en surbrillance)" % [team_label, unit.unit_name]

# Appelée par HexGrid quand l'unité en attente vient d'être posée avec
# succès sur la grille : passe à l'unité suivante du plan.
func on_unit_placed() -> void:
	_plan_index += 1
	_advance_plan()

func _finish_placement() -> void:
	_status_panel.visible = false
	_hex_grid.begin_combat_after_placement()
