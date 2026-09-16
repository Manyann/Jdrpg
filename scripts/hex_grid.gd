extends Node2D

# ============================================================
# hex_grid.gd
# Grille de combat hexagonale avec rendu isométrique.
#
# PRINCIPE :
# 1) On utilise des coordonnées "axiales" (q, r) pour représenter
#    chaque case hexagonale de façon mathématiquement simple
#    (voisins, distance, pathfinding... tout devient facile).
# 2) On convertit ces coordonnées en position à l'écran (pixels)
#    avec une formule hexagonale classique.
# 3) On "aplatit" verticalement le résultat (iso_squash) pour
#    donner l'illusion d'une vue isométrique, comme dans Dofus.
# ============================================================

# ---------- Paramètres réglables dans l'inspecteur Godot ----------

## Rayon de la grille en nombre d'anneaux autour du centre.
## Ex: 4 => grille d'environ 61 cases (classique en tactical RPG).
@export var grid_radius: int = 4

## Taille d'un hexagone (distance du centre à un sommet), en pixels.
@export var hex_size: float = 40.0

## Facteur d'aplatissement vertical pour l'effet isométrique.
## 1.0 = grille hexagonale plate normale (vue du dessus).
## 0.5 = fortement aplatie, effet isométrique marqué.
@export var iso_squash: float = 0.58

## Couleurs
@export var line_color: Color = Color(0.3, 0.3, 0.35)
@export var fill_color: Color = Color(0.15, 0.16, 0.2, 0.6)
@export var hover_color: Color = Color(0.9, 0.8, 0.2, 0.5)
@export var selected_color: Color = Color(0.2, 0.8, 0.4, 0.6)

## Si activé, centre automatiquement la grille au milieu de la fenêtre
## au lancement (évite que la moitié de la grille sorte de l'écran
## en haut à gauche, puisque le dessin se fait autour de position (0,0)
## du node). Désactive si tu préfères positionner le node toi-même
## dans l'éditeur.
@export var auto_center: bool = true

# ---------- Zones de départ et unités ----------

## Couleur de la colonne de départ du joueur (bord gauche de la grille).
@export var player_zone_color: Color = Color(0.25, 0.45, 0.9, 0.35)

## Couleur de la colonne de départ des ennemis (bord droit de la grille).
@export var enemy_zone_color: Color = Color(0.9, 0.3, 0.3, 0.35)

## Couleur des cases atteignables par l'unité actuellement sélectionnée.
@export var reachable_color: Color = Color(0.2, 0.9, 0.7, 0.4)

## Liste des unités joueur à faire apparaître automatiquement au
## lancement (une par case disponible dans la zone, dans l'ordre).
@export var player_units: Array[String] = ["Barbare", "Haut Elfe", "Walkyrie"]

## Liste des unités ennemies à faire apparaître automatiquement.
@export var enemy_units: Array[String] = ["Bouftou", "Bouftou", "Bouftou"]

## Courage de chaque unité joueur (même ordre que player_units).
## Détermine l'ordre de passage : plus haut = joue plus tôt.
@export var player_courage: Array[int] = [12, 9, 6]

## Courage de chaque unité ennemie (même ordre que enemy_units).
@export var enemy_courage: Array[int] = [10, 7, 4]

## Scène/script de l'unité à instancier. CombatUnit.new() attache déjà
## automatiquement son script grâce à class_name, donc plus besoin de
## preload manuel ici.

# ---------- Données internes ----------

# Toutes les cases de la grille, indexées par coordonnées axiales.
# Clé : Vector2i(q, r)  ->  Valeur : dictionnaire de données de case.
var _cells: Dictionary = {}

# Case actuellement survolée par la souris (null si aucune).
var _hovered_coord = null

# Unité actuellement sélectionnée (null si aucune).
var _selected_unit: CombatUnit = null

# Cases atteignables par l'unité sélectionnée, avec le coût en PM
# pour y arriver. Clé : Vector2i -> Valeur : distance (int).
var _reachable_cells: Dictionary = {}

# Toutes les unités présentes sur la grille (joueur + ennemis confondus).
var _all_units: Array = []

# Unité dont c'est le tour actuellement. Contrôlée par TurnManager via
# set_active_unit(). Seule cette unité peut être sélectionnée/déplacée.
var active_unit: CombatUnit = null

## Chemin vers le node TurnManager dans la scène (glisse-le depuis
## l'éditeur une fois le node ajouté). Laisse vide si tu ne veux pas
## encore de système de tours.
@export var turn_manager_path: NodePath

var _turn_manager = null

# Sort en cours de ciblage (null si on n'est pas en train de viser).
var _casting_spell: Spell = null

# Cases à portée du sort en cours de ciblage. Clé : Vector2i -> Valeur : distance.
var _spell_range_cells: Dictionary = {}

## Couleur des cases à portée pendant le ciblage d'un sort.
@export var spell_range_color: Color = Color(0.95, 0.55, 0.15, 0.45)

# Les 6 directions voisines en coordonnées axiales (utile pour plus tard :
# déplacement, portée de sorts, pathfinding).
const DIRECTIONS = [
	Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
	Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)
]

# ---------- Cycle de vie Godot ----------

func _ready() -> void:
	if auto_center:
		position = get_viewport_rect().size / 2.0

	generate_grid()
	setup_starting_units()
	queue_redraw()

	if turn_manager_path != NodePath(""):
		_turn_manager = get_node(turn_manager_path)
		_turn_manager.start_combat(_all_units)

# Devient vrai dès qu'une équipe n'a plus d'unité en vie. Bloque
# alors toute interaction (plus de sélection, déplacement, sort).
var combat_ended: bool = false

func _unhandled_input(event: InputEvent) -> void:
	if combat_ended:
		return

	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if _casting_spell != null:
			cancel_targeting_mode()
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if _casting_spell != null:
			cancel_targeting_mode()
		return

	if event is InputEventMouseMotion:
		var local_pos = get_local_mouse_position()
		var coord = pixel_to_axial(local_pos)

		if _cells.has(coord):
			if _hovered_coord != coord:
				_hovered_coord = coord
				queue_redraw()
		elif _hovered_coord != null:
			_hovered_coord = null
			queue_redraw()

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var local_pos = get_local_mouse_position()
		var coord = pixel_to_axial(local_pos)

		if not _cells.has(coord):
			return

		# En mode ciblage de sort, le clic sert uniquement à choisir la cible.
		if _casting_spell != null:
			_handle_spell_target_click(coord)
			return

		var occupant = _cells[coord]["occupant"]

		if occupant != null:
			# On affiche toujours sa fiche récapitulative (haut à droite),
			# que ce soit ou non son tour — simple consultation.
			if _turn_manager != null:
				_turn_manager.show_character_panel(occupant)

			if occupant != active_unit:
				# Ce n'est pas le tour de cette unité : pas de sélection ni
				# de déplacement possible, seulement la consultation ci-dessus.
				return

			if occupant == _selected_unit:
				_deselect_unit()
			else:
				_select_unit(occupant)
		elif _selected_unit != null and _reachable_cells.has(coord):
			# Clic sur une case accessible : on déplace l'unité sélectionnée.
			var move_cost = _reachable_cells[coord]
			if move_unit(_selected_unit, coord):
				_selected_unit.current_pm -= move_cost
				spawn_floating_text(_selected_unit.position, "-%d PM" % move_cost, Color(0.4, 0.75, 1.0))
				if _selected_unit.current_pm <= 0:
					_deselect_unit()
				else:
					_reachable_cells = get_reachable_cells(_selected_unit.hex_coord, _selected_unit.current_pm)
			queue_redraw()
		else:
			# Clic dans le vide (case hors de portée, sans unité) : on désélectionne.
			_deselect_unit()

# ---------- Génération de la grille ----------

func generate_grid() -> void:
	_cells.clear()

	# On génère un hexagone de cases centré en (0,0).
	# Classique en grille hexagonale : pour chaque q dans [-N, N],
	# r varie dans une plage qui dépend de q pour former un hexagone
	# (et non un losange ou un carré).
	for q in range(-grid_radius, grid_radius + 1):
		var r_min = max(-grid_radius, -q - grid_radius)
		var r_max = min(grid_radius, -q + grid_radius)

		for r in range(r_min, r_max + 1):
			var coord = Vector2i(q, r)
			_cells[coord] = {
				"coord": coord,
				"is_walkable": true,
				"occupant": null  # Contiendra une référence vers un CombatUnit une fois placé.
			}

	print("Grille générée : %d cases." % _cells.size())

# ---------- Conversions coordonnées <-> pixels ----------

# Coordonnées axiales -> position pixel (hexagones "pointy-top",
# c'est-à-dire avec une pointe en haut, look classique tactique).
func axial_to_pixel(coord: Vector2i) -> Vector2:
	var x = hex_size * (sqrt(3.0) * coord.x + sqrt(3.0) / 2.0 * coord.y)
	var y = hex_size * (3.0 / 2.0 * coord.y)

	# Aplatissement isométrique : on compresse l'axe Y.
	y *= iso_squash

	return Vector2(x, y)

# Position pixel -> coordonnées axiales les plus proches.
# On "dé-aplatit" d'abord le Y, puis on applique la formule
# inverse classique avec un arrondi en coordonnées cubiques
# (nécessaire car un simple arrondi (q,r) donnerait des résultats
# faux près des bords des hexagones).
func pixel_to_axial(pixel: Vector2) -> Vector2i:
	var y = pixel.y / iso_squash
	var x = pixel.x

	var q = (sqrt(3.0) / 3.0 * x - 1.0 / 3.0 * y) / hex_size
	var r = (2.0 / 3.0 * y) / hex_size

	return cube_round(q, r)

# Arrondit des coordonnées axiales fractionnaires vers la case
# hexagonale la plus proche (algorithme standard "cube rounding").
func cube_round(q: float, r: float) -> Vector2i:
	var x = q
	var z = r
	var y = -x - z

	var rx = round(x)
	var ry = round(y)
	var rz = round(z)

	var x_diff = abs(rx - x)
	var y_diff = abs(ry - y)
	var z_diff = abs(rz - z)

	if x_diff > y_diff and x_diff > z_diff:
		rx = -ry - rz
	elif y_diff > z_diff:
		ry = -rx - rz
	else:
		rz = -rx - ry

	return Vector2i(int(rx), int(rz))

# Distance en nombre de cases entre deux coordonnées axiales
# (utile plus tard pour la portée de déplacement / de sorts).
func hex_distance(a: Vector2i, b: Vector2i) -> int:
	return int((abs(a.x - b.x) + abs(a.x + a.y - b.x - b.y) + abs(a.y - b.y)) / 2)

# Renvoie la coordonnée voisine dans une direction (0 à 5).
func hex_neighbor(coord: Vector2i, direction: int) -> Vector2i:
	return coord + DIRECTIONS[direction]

# ---------- Zones de départ ----------

# Renvoie toutes les cases dont la coordonnée q correspond à la
# colonne demandée, triées de haut en bas (utile pour distribuer
# les unités dans l'ordre sur une même colonne).
func get_column_cells(q_value: int) -> Array:
	var result: Array = []
	for coord in _cells.keys():
		if coord.x == q_value:
			result.append(coord)
	result.sort_custom(func(a, b): return a.y < b.y)
	return result

func get_player_zone_cells() -> Array:
	return get_column_cells(-grid_radius)

func get_enemy_zone_cells() -> Array:
	return get_column_cells(grid_radius)

# ---------- Gestion des unités ----------

func is_occupied(coord: Vector2i) -> bool:
	return _cells.has(coord) and _cells[coord]["occupant"] != null

# ---------- Sélection d'unité ----------

func _select_unit(unit: CombatUnit) -> void:
	_selected_unit = unit
	_reachable_cells = get_reachable_cells(unit.hex_coord, unit.current_pm)
	queue_redraw()

func _deselect_unit() -> void:
	_selected_unit = null
	_reachable_cells.clear()
	queue_redraw()

# Appelée par TurnManager au début du tour de chaque unité : réinitialise
# ses PM et la sélectionne automatiquement (affiche tout de suite sa
# zone de déplacement, comme dans Dofus).
func set_active_unit(unit: CombatUnit) -> void:
	active_unit = unit

	if unit != null:
		unit.reset_turn_resources()
		_select_unit(unit)
		if _turn_manager != null:
			_turn_manager.show_character_panel(unit)
	else:
		_deselect_unit()

func get_all_units() -> Array:
	return _all_units

# ---------- Pathfinding ----------

# Calcule toutes les cases atteignables depuis une case de départ avec
# un budget de déplacement donné, en contournant les obstacles et les
# unités déjà présentes (BFS classique : comme chaque pas coûte 1 PM,
# pas besoin de Dijkstra, un simple parcours en largeur suffit).
#
# Renvoie un dictionnaire Vector2i -> int (coût en PM pour atteindre
# cette case). La case de départ elle-même n'est pas incluse.
func get_reachable_cells(start: Vector2i, max_range: int) -> Dictionary:
	var visited: Dictionary = {start: 0}
	var frontier: Array = [start]
	var current_range = 0

	while current_range < max_range and frontier.size() > 0:
		var next_frontier: Array = []

		for coord in frontier:
			for dir in range(6):
				var neighbor = hex_neighbor(coord, dir)

				if not _cells.has(neighbor):
					continue  # Hors de la grille.
				if visited.has(neighbor):
					continue  # Déjà atteint avec un coût égal ou moindre.
				if not _cells[neighbor]["is_walkable"]:
					continue  # Case bloquée (obstacle/terrain infranchissable).
				if is_occupied(neighbor):
					continue  # Une autre unité bloque le passage.

				visited[neighbor] = current_range + 1
				next_frontier.append(neighbor)

		frontier = next_frontier
		current_range += 1

	visited.erase(start)
	return visited

# ---------- Sorts / attaques ----------

# Renvoie toutes les cases dont la distance au centre est comprise
# entre min_r et max_r (inclus). Distance "à vol d'oiseau" : ne prend
# pas en compte les obstacles ni les unités (pas de ligne de vue pour
# l'instant, ce sera une amélioration future pour les sorts à distance).
func get_cells_in_range(center: Vector2i, min_r: int, max_r: int) -> Dictionary:
	var result: Dictionary = {}
	for coord in _cells.keys():
		if coord == center:
			continue
		var dist = hex_distance(center, coord)
		if dist >= min_r and dist <= max_r:
			result[coord] = dist
	return result

# Active le mode ciblage pour le sort donné : calcule et affiche les
# cases à portée depuis l'unité active. Appelé par TurnManager quand
# le joueur clique un bouton de sort.
func enter_targeting_mode(spell: Spell) -> void:
	if active_unit == null:
		return

	var ea_cost = spell.get_effective_ea_cost()

	if active_unit.current_ea < ea_cost:
		print("Pas assez d'Énergie Astrale pour lancer %s." % spell.spell_name)
		return

	if not active_unit.can_perform_action(spell):
		print("Une seule action par tour (ou 2 attaques mêlée avec Ambidextrie).")
		return

	_casting_spell = spell
	_spell_range_cells = get_cells_in_range(active_unit.hex_coord, spell.min_range, spell.max_range)
	queue_redraw()

func cancel_targeting_mode() -> void:
	_casting_spell = null
	_spell_range_cells.clear()
	queue_redraw()

# ---------- Texte flottant (dégâts, soins, PM/EA dépensés) ----------

# Fait apparaître un petit texte qui monte et s'efface au-dessus d'une
# position donnée (en coordonnées locales à HexGrid, donc utiliser
# directement unit.position). Réutilisé pour les dégâts, les soins,
# le coût en PM d'un déplacement, et le coût en EA d'un sort.
func spawn_floating_text(world_pos: Vector2, text: String, color: Color) -> void:
	var label = Label.new()
	label.text = text
	label.modulate = color
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	label.z_index = 100  # Toujours au-dessus de la grille et des unités.

	# Petit décalage horizontal aléatoire pour éviter que plusieurs
	# textes se superposent parfaitement en cas de coups rapprochés.
	var jitter_x = randf_range(-12, 12)
	label.position = world_pos + Vector2(-20 + jitter_x, -55)

	add_child(label)

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 36, 0.9)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.7).set_delay(0.25)
	tween.set_parallel(false)
	tween.tween_callback(label.queue_free)

# Traite un clic pendant le mode ciblage : vérifie que la case est à
# portée et contient une cible, puis lance le sort.
func _handle_spell_target_click(coord: Vector2i) -> void:
	if not _spell_range_cells.has(coord):
		return  # Hors de portée, clic ignoré.

	var target = _cells[coord]["occupant"]
	if target == null:
		return  # Pas de cible sur cette case.

	if target == active_unit:
		return  # Pas d'auto-ciblage pour l'instant (utile plus tard pour les soins).

	_cast_spell(active_unit, _casting_spell, target)

func _cast_spell(caster: CombatUnit, spell: Spell, target: CombatUnit) -> void:
	caster.record_action_taken(spell)

	var ea_cost = spell.get_effective_ea_cost()
	caster.current_ea -= ea_cost
	target.take_damage(spell.damage)

	print("%s lance %s sur %s (%d dégâts)" % [caster.unit_name, spell.spell_name, target.unit_name, spell.damage])

	# L'attaque mêlée est gratuite (0 EA) : pas la peine d'afficher "-0 EA".
	if ea_cost > 0:
		spawn_floating_text(caster.position, "-%d EA" % ea_cost, Color(0.65, 0.45, 0.95))

	if spell.damage >= 0:
		spawn_floating_text(target.position, "-%d" % spell.damage, Color(0.95, 0.3, 0.3))
	else:
		spawn_floating_text(target.position, "+%d" % abs(spell.damage), Color(0.35, 0.9, 0.5))

	cancel_targeting_mode()

	if _turn_manager != null:
		_turn_manager.refresh_ui()

	queue_redraw()

# ---------- Gestion de la mort d'une unité ----------

# Appelé automatiquement via le signal "died" émis par CombatUnit.
# Libère sa case et la retire de la file de tours pour éviter tout
# crash (référence à une unité détruite).
func _on_unit_died(unit: CombatUnit) -> void:
	if _cells.has(unit.hex_coord) and _cells[unit.hex_coord]["occupant"] == unit:
		_cells[unit.hex_coord]["occupant"] = null

	_all_units.erase(unit)

	if unit == _selected_unit:
		_deselect_unit()

	if unit == active_unit:
		active_unit = null

	var just_ended = check_combat_end()

	if _turn_manager != null:
		if just_ended:
			# Le combat vient de se terminer : on retire juste l'unité de la
			# file d'affichage, sans laisser TurnManager démarrer un tour
			# suivant (il n'y en a plus).
			_turn_manager.remove_unit_after_combat_end(unit)
		else:
			_turn_manager.remove_unit(unit)

	queue_redraw()

# Vérifie si une équipe n'a plus aucune unité en vie. Si c'est le cas,
# déclenche la fin du combat (victoire/défaite/égalité) et bloque les
# interactions. Renvoie true si le combat vient de se terminer.
func check_combat_end() -> bool:
	if combat_ended:
		return false

	var has_player = false
	var has_enemy = false

	for unit in _all_units:
		if unit.team == CombatUnit.Team.PLAYER:
			has_player = true
		elif unit.team == CombatUnit.Team.ENEMY:
			has_enemy = true

	if has_player and has_enemy:
		return false  # Combat toujours en cours.

	combat_ended = true

	var result: String
	if not has_player and not has_enemy:
		result = "draw"
	elif not has_player:
		result = "defeat"
	else:
		result = "victory"

	_deselect_unit()
	cancel_targeting_mode()
	active_unit = null

	if _turn_manager != null:
		_turn_manager.show_combat_end(result)

	return true

# Crée une unité et la place sur une case donnée. Renvoie null si la
# case n'existe pas ou est déjà occupée.
#
# `template_name` doit correspondre à une clé de UnitDatabase.TEMPLATES
# (ex: "Barbare", "Haut Elfe", "Bouftou"...) : détermine les stats de base et les
# sorts de l'unité. `courage_override` permet de personnaliser le
# Courage d'une instance précise sans toucher au Courage par défaut de
# la classe (utile pour varier l'ordre d'initiative entre unités
# identiques, ex: plusieurs Bouftous).
func spawn_unit(coord: Vector2i, team: int, template_name: String, courage_override: int = -1) -> CombatUnit:
	if not _cells.has(coord):
		push_warning("spawn_unit: case %s hors grille." % [coord])
		return null

	if is_occupied(coord):
		push_warning("spawn_unit: case %s déjà occupée." % [coord])
		return null

	var unit := CombatUnit.new()
	unit.team = team
	unit.unit_name = template_name
	unit.hex_coord = coord
	unit.position = axial_to_pixel(coord)

	# On applique les stats et sorts de la classe AVANT add_child : comme
	# _ready() s'exécute dès l'entrée dans l'arbre de scène, il faut que
	# ces valeurs soient déjà en place pour que l'unité démarre avec les
	# bons PV/PM/EA et sans se voir attribuer un sort par défaut.
	var stats = UnitDatabase.get_base_stats(template_name)
	if not stats.is_empty():
		unit.max_hp = stats.get("max_hp", unit.max_hp)
		unit.max_pm = stats.get("max_pm", unit.max_pm)
		unit.max_ea = stats.get("max_ea", unit.max_ea)
		unit.courage = stats.get("courage", unit.courage)
		unit.has_ambidextrie = stats.get("ambidextrie", false)
		unit.spells = UnitDatabase.build_spells(template_name)
		unit.equipped_weapon = UnitDatabase.build_weapon(template_name, "weapon")
		unit.off_hand_weapon = UnitDatabase.build_weapon(template_name, "weapon_off_hand")
		unit.inventory_arrows = UnitDatabase.build_arrows(template_name)
		unit.inventory_potions = UnitDatabase.build_potions(template_name)
		unit.inventory_weapons = UnitDatabase.build_inventory_weapons(template_name)

	if courage_override >= 0:
		unit.courage = courage_override

	add_child(unit)
	_cells[coord]["occupant"] = unit
	_all_units.append(unit)
	unit.died.connect(_on_unit_died)

	return unit

# Déplace une unité déjà existante d'une case vers une autre (fera
# l'objet d'une vraie logique de portée/pathfinding à l'étape suivante ;
# pour l'instant c'est un placement direct, sans vérification de PM).
func move_unit(unit: CombatUnit, target_coord: Vector2i) -> bool:
	if not _cells.has(target_coord) or is_occupied(target_coord):
		return false

	_cells[unit.hex_coord]["occupant"] = null
	unit.hex_coord = target_coord
	unit.move_to_pixel(axial_to_pixel(target_coord))
	_cells[target_coord]["occupant"] = unit

	return true

# Fait apparaître les unités de départ définies dans l'inspecteur
# (player_units / enemy_units) sur leurs zones respectives.
func setup_starting_units() -> void:
	var player_cells = get_player_zone_cells()
	var enemy_cells = get_enemy_zone_cells()

	for i in range(min(player_units.size(), player_cells.size())):
		var courage_override = player_courage[i] if i < player_courage.size() else -1
		spawn_unit(player_cells[i], CombatUnit.Team.PLAYER, player_units[i], courage_override)

	for i in range(min(enemy_units.size(), enemy_cells.size())):
		var courage_override = enemy_courage[i] if i < enemy_courage.size() else -1
		spawn_unit(enemy_cells[i], CombatUnit.Team.ENEMY, enemy_units[i], courage_override)

# ---------- Rendu ----------

func _draw() -> void:
	for coord in _cells.keys():
		var center = axial_to_pixel(coord)

		var fill = fill_color
		if coord.x == -grid_radius:
			fill = player_zone_color
		elif coord.x == grid_radius:
			fill = enemy_zone_color

		if _casting_spell != null:
			if _spell_range_cells.has(coord):
				fill = spell_range_color
		elif _reachable_cells.has(coord):
			fill = reachable_color

		if _selected_unit != null and coord == _selected_unit.hex_coord:
			fill = selected_color
		if _hovered_coord != null and coord == _hovered_coord:
			fill = hover_color

		_draw_hexagon(center, fill)

# Dessine un hexagone rempli + son contour à une position donnée.
func _draw_hexagon(center: Vector2, fill: Color) -> void:
	var points = PackedVector2Array()

	for i in range(6):
		# "Pointy-top" : on démarre l'angle à -90° + décalage de 60°.
		var angle_deg = 60.0 * i - 90.0
		var angle_rad = deg_to_rad(angle_deg)

		var px = center.x + hex_size * cos(angle_rad)
		var py = center.y + hex_size * sin(angle_rad) * iso_squash

		points.append(Vector2(px, py))

	draw_colored_polygon(points, fill)

	# Contour : on referme la boucle en ajoutant le premier point à la fin.
	var outline = points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, line_color, 1.5, true)
