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
@export var player_units: Array[String] = ["Barbare", "Elfe", "Mage"]

## Liste des unités ennemies à faire apparaître automatiquement.
@export var enemy_units: Array[String] = ["Orc", "Orc", "Orc"]

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

## Chemin vers le node PlacementManager (optionnel). S'il est renseigné,
## HexGrid ne place plus les unités automatiquement : il attend que
## PlacementManager pilote une phase de placement interactive avant de
## démarrer le combat (voir begin_combat_after_placement()).
@export var placement_manager_path: NodePath

var _placement_manager = null

# Vrai pendant qu'on attend que le joueur clique une case pour y
# placer l'unité en attente (_pending_placement_unit).
var placement_mode_active: bool = false
var _pending_placement_unit: CombatUnit = null
var _placement_zone_cells = {}

## Couleur des cases valides pendant la phase de placement.
@export var placement_zone_color: Color = Color(0.9, 0.85, 0.25, 0.4)

## Rayon (en cases) de la zone centrale utilisée par les modes
## Embuscade/Défense (voir get_center_zone_cells / get_outer_zone_cells).
@export var center_zone_radius: int = 2

## Cases infranchissables (rochers, murs...) — bloquent le déplacement
## ET la ligne de vue des sorts/attaques à distance (voir
## has_line_of_sight). Quelques cases par défaut pour tester tout de
## suite ; ajuste/vide selon le niveau souhaité.
@export var obstacle_coords: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 1)]

## Couleur des cases d'obstacle.
@export var obstacle_color: Color = Color(0.13, 0.11, 0.1, 0.95)

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
	queue_redraw()

	if turn_manager_path != NodePath(""):
		_turn_manager = get_node(turn_manager_path)

	if placement_manager_path != NodePath(""):
		_placement_manager = get_node(placement_manager_path)
		_placement_manager.start_placement_phase(self)
	else:
		# Pas de phase de placement configurée : comportement historique,
		# placement automatique instantané sur les zones par défaut.
		print("HexGrid: 'Placement Manager Path' non renseigné — placement automatique (pas de choix de configuration).")
		setup_starting_units()
		if _turn_manager != null:
			_turn_manager.start_combat(_all_units)

# Appelée par PlacementManager une fois toutes les unités placées :
# démarre le combat proprement dit (file d'initiative, premier tour).
func begin_combat_after_placement() -> void:
	if _turn_manager != null:
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

		# En phase de placement, le clic sert uniquement à poser l'unité
		# en attente sur une case valide de la zone autorisée.
		if placement_mode_active:
			_handle_placement_click(coord)
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

	# Marque les cases d'obstacle (rochers, murs...) comme infranchissables
	# ET bloquant la ligne de vue (voir has_line_of_sight). Configurable
	# depuis l'inspecteur ; quelques cases par défaut pour pouvoir tester
	# la ligne de vue immédiatement.
	for coord in obstacle_coords:
		if _cells.has(coord):
			_cells[coord]["is_walkable"] = false

	print("Grille générée : %d cases (%d obstacles)." % [_cells.size(), obstacle_coords.size()])

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
		if coord.x == q_value and _cells[coord]["is_walkable"]:
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

# Arrondit un triplet de coordonnées cubiques fractionnaires vers la
# case hexagonale la plus proche (variante de cube_round() adaptée à
# hex_line, qui travaille en Vector3 plutôt qu'en q/r séparés).
func _cube_round_vec3(cube: Vector3) -> Vector3:
	var rx = round(cube.x)
	var ry = round(cube.y)
	var rz = round(cube.z)

	var x_diff = abs(rx - cube.x)
	var y_diff = abs(ry - cube.y)
	var z_diff = abs(rz - cube.z)

	if x_diff > y_diff and x_diff > z_diff:
		rx = -ry - rz
	elif y_diff > z_diff:
		ry = -rx - rz
	else:
		rz = -rx - ry

	return Vector3(rx, ry, rz)

# Calcule la liste des cases traversées par une ligne droite entre deux
# cases hexagonales (inclut les deux extrémités), via interpolation en
# coordonnées cubiques — l'algorithme standard de tracé de ligne sur
# grille hexagonale (voir redblobgames.com/grids/hexagons/#line-drawing).
func hex_line(a: Vector2i, b: Vector2i) -> Array:
	var n = hex_distance(a, b)
	if n == 0:
		return [a]

	var a_cube = Vector3(a.x, a.y, -a.x - a.y)
	var b_cube = Vector3(b.x, b.y, -b.x - b.y)

	var result: Array = []
	for i in range(n + 1):
		var t = float(i) / float(n)
		var lerp_cube = a_cube.lerp(b_cube, t)
		# Petit décalage pour éviter les cas ambigus pile sur une arête
		# entre deux cases (évite de "sauter" une case au hasard selon
		# les arrondis flottants).
		lerp_cube += Vector3(1e-6, 2e-6, -3e-6)
		var rounded = _cube_round_vec3(lerp_cube)
		result.append(Vector2i(int(rounded.x), int(rounded.y)))

	return result

# Vrai si rien ne bloque la ligne droite entre deux cases (aucun
# obstacle infranchissable sur les cases intermédiaires — les deux
# extrémités elles-mêmes ne sont jamais prises en compte comme
# bloquantes). Utilisé pour restreindre la portée des sorts/attaques à
# distance à ce qui est réellement visible, pas seulement à la distance
# à vol d'oiseau.
func has_line_of_sight(from: Vector2i, to: Vector2i) -> bool:
	var line = hex_line(from, to)

	for i in range(1, line.size() - 1):
		var coord = line[i]
		if _cells.has(coord) and not _cells[coord]["is_walkable"]:
			return false

	return true

# Compte le nombre d'unités (alliées ou ennemies, peu importe) présentes
# sur les cases intermédiaires de la ligne entre deux cases (extrémités
# exclues). Chaque unité gêne un tir/sort à distance : -1 au jet de
# réussite par unité sur la trajectoire (voir _resolve_weapon_attack et
# _resolve_spell_effect). Toujours 0 pour une attaque en mêlée (portée
# 1 = aucune case intermédiaire possible).
func count_units_in_line(from: Vector2i, to: Vector2i) -> int:
	var line = hex_line(from, to)
	var count = 0

	for i in range(1, line.size() - 1):
		var coord = line[i]
		if _cells.has(coord) and _cells[coord]["occupant"] != null:
			count += 1

	return count

# Renvoie toutes les cases dont la distance au centre est comprise
# entre min_r et max_r (inclus) ET dont la ligne de vue depuis center
# n'est pas bloquée par un obstacle (voir has_line_of_sight). Distance
# de portée toujours "à vol d'oiseau" (hex_distance), mais la ligne de
# vue, elle, est désormais vérifiée.
func get_cells_in_range(center: Vector2i, min_r: int, max_r: int) -> Dictionary:
	var result: Dictionary = {}
	for coord in _cells.keys():
		if coord == center:
			continue
		var dist = hex_distance(center, coord)
		if dist < min_r or dist > max_r:
			continue
		if not has_line_of_sight(center, coord):
			continue
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

	# L'attaque d'arme est gratuite (0 EA) : pas la peine d'afficher "-0 EA".
	if ea_cost > 0:
		spawn_floating_text(caster.position, "-%d EA" % ea_cost, Color(0.65, 0.45, 0.95))

	if spell.is_weapon_attack:
		_resolve_weapon_attack(caster, spell, target)
	else:
		_resolve_spell_effect(caster, spell, target)

	cancel_targeting_mode()

	if _turn_manager != null:
		_turn_manager.refresh_ui()

	queue_redraw()

# ---------- Résolution des attaques : toucher, parade, esquive ----------

# Une attaque d'arme (mêlée ou à distance) doit d'abord réussir son jet
# de toucher, puis peut être parée (mêlée uniquement) ou esquivée par
# le défenseur selon sa posture défensive.
func _resolve_weapon_attack(caster: CombatUnit, spell: Spell, target: CombatUnit) -> void:
	caster.face_direction(target.position)
	caster.play_animation("attack" if spell.is_melee_range() else "ranged_attack")

	# Chaque unité (alliée ou ennemie) sur la trajectoire gêne le tir :
	# -1 au jet de toucher par unité interposée. Toujours 0 en mêlée
	# (portée 1, aucune case intermédiaire).
	var malus = count_units_in_line(caster.hex_coord, target.hex_coord)

	# La mêlée teste l'Attaque ; une attaque à distance (arc, arbalète...)
	# teste l'Adresse à la place.
	var base_stat = caster.attack_stat if spell.is_melee_range() else caster.adresse_stat
	var effective_stat = base_stat - malus

	var hit_roll = randi_range(1, 20)

	if hit_roll >= effective_stat:
		print("%s rate son attaque (jet %d >= %s %d, malus -%d)." % [
			caster.unit_name, hit_roll,
			"Attaque" if spell.is_melee_range() else "Adresse",
			effective_stat, malus
		])
		spawn_floating_text(target.position, "Raté", Color(0.65, 0.65, 0.65))
		return

	# Touché a priori : le défenseur peut tenter de parer (mêlée
	# seulement) s'il est en posture Parade.
	if spell.is_melee_range() and target.defensive_stance == CombatUnit.DefensiveStance.PARRY:
		var parry_roll = randi_range(1, 20)
		if parry_roll < target.parade_stat:
			spawn_floating_text(target.position, "Paré !", Color(0.9, 0.8, 0.2))
			_deal_counter_attack(target, caster)
			return
		# Parade ratée : les dégâts normaux s'appliquent plus bas.

	if _try_dodge(target):
		return

	var effective_damage = spell.damage
	if spell.is_melee_range():
		effective_damage += caster.get_melee_damage_bonus()

	target.take_damage(effective_damage)
	spawn_floating_text(target.position, "-%d" % effective_damage, Color(0.95, 0.3, 0.3))

	print("%s touche %s avec %s (%d dégâts)." % [caster.unit_name, target.unit_name, spell.spell_name, effective_damage])

# Les sorts/enchantements doivent réussir un jet de lancer basé sur la
# moyenne de deux stats (Intelligence + Adresse pour un sort physique,
# Intelligence + Charisme pour un sort psychique). S'ils touchent, ils
# peuvent être esquivés comme une attaque d'arme — SAUF un sort de
# soin, qui ne peut jamais être esquivé.
func _resolve_spell_effect(caster: CombatUnit, spell: Spell, target: CombatUnit) -> void:
	caster.face_direction(target.position)
	caster.play_animation("cast")  # Ignoré silencieusement si non définie pour cette classe.

	var avg_stat: float
	if spell.spell_type == Spell.SpellType.PSYCHIC:
		avg_stat = (caster.intelligence_stat + caster.charisme_stat) / 2.0
	else:
		avg_stat = (caster.intelligence_stat + caster.adresse_stat) / 2.0

	# Chaque unité (alliée ou ennemie) sur la trajectoire gêne le sort :
	# -1 au jet de lancer par unité interposée.
	var malus = count_units_in_line(caster.hex_coord, target.hex_coord)
	avg_stat -= malus

	var cast_roll = randi_range(1, 20)
	if cast_roll >= avg_stat:
		print("%s rate son sort %s (jet %d >= moyenne %.1f, malus -%d)." % [caster.unit_name, spell.spell_name, cast_roll, avg_stat, malus])
		spawn_floating_text(target.position, "Raté", Color(0.65, 0.65, 0.65))
		return

	var is_heal = spell.damage < 0

	# Un soin ne peut jamais être esquivé ; un sort offensif, si.
	if not is_heal and _try_dodge(target):
		return

	var effective_damage = spell.damage
	var spell_bonus = caster.get_spell_damage_bonus()
	if is_heal:
		effective_damage -= spell_bonus  # Renforce le soin (plus négatif).
	else:
		effective_damage += spell_bonus

	target.take_damage(effective_damage)

	if effective_damage >= 0:
		spawn_floating_text(target.position, "-%d" % effective_damage, Color(0.95, 0.3, 0.3))
	else:
		spawn_floating_text(target.position, "+%d" % abs(effective_damage), Color(0.35, 0.9, 0.5))

	print("%s touche %s avec %s (%d dégâts)." % [caster.unit_name, target.unit_name, spell.spell_name, effective_damage])

# Tente une esquive pour le défenseur s'il est en posture Esquive et
# que sa disponibilité d'esquive n'est pas déjà consommée ce tour-ci
# (règle "1 attaque sur 2"). Renvoie true si l'attaque est esquivée.
func _try_dodge(target: CombatUnit) -> bool:
	if target.defensive_stance != CombatUnit.DefensiveStance.DODGE:
		return false

	if not target.dodge_available:
		return false  # Esquive déjà "consommée" par l'attaque précédente.

	target.dodge_available = false  # Consommée qu'elle réussisse ou non.

	var dodge_roll = randi_range(1, 20)
	if dodge_roll < target.adresse_stat:
		spawn_floating_text(target.position, "Esquivé !", Color(0.4, 0.8, 1.0))
		return true

	return false

# Le défenseur qui pare avec succès tente une riposte : elle doit
# réussir son propre jet de toucher (stat Attaque du défenseur), et ne
# peut JAMAIS être parée par l'attaquant original (sinon deux unités
# en Parade s'annuleraient indéfiniment) — mais elle reste esquivable
# normalement.
func _deal_counter_attack(defender: CombatUnit, attacker: CombatUnit) -> void:
	defender.face_direction(attacker.position)
	var is_ranged = defender.equipped_weapon != null and defender.equipped_weapon.weapon_type == Weapon.WeaponType.RANGED
	defender.play_animation("ranged_attack" if is_ranged else "attack")

	var counter_roll = randi_range(1, 20)
	if counter_roll >= defender.attack_stat:
		spawn_floating_text(attacker.position, "Riposte ratée", Color(0.65, 0.65, 0.65))
		return

	if _try_dodge(attacker):
		return

	var base_damage = defender.equipped_weapon.damage if defender.equipped_weapon != null else 5
	var counter_damage = base_damage + defender.get_melee_damage_bonus()

	attacker.take_damage(counter_damage)
	spawn_floating_text(attacker.position, "-%d (riposte)" % counter_damage, Color(0.95, 0.55, 0.2))

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

# Construit une unité de combat SANS la placer sur la grille (pas de
# position, pas d'ajout à l'arbre de scène, pas d'enregistrement dans
# _cells/_all_units). Utilisé par la phase de placement interactive :
# on construit toutes les unités à l'avance, puis on les place une par
# une au clic via place_unit_at().
#
# `template_name` doit correspondre à une clé de UnitDatabase.TEMPLATES
# (ex: "Barbare", "Elfe", "Orc"...) : détermine les stats de
# base et les sorts de l'unité. `courage_override` permet de
# personnaliser le Courage d'une instance précise sans toucher au
# Courage par défaut de la classe.
func build_unit(team: int, template_name: String, courage_override: int = -1) -> CombatUnit:
	var unit := CombatUnit.new()
	unit.team = team
	unit.unit_name = template_name

	var stats = UnitDatabase.get_base_stats(template_name)
	if not stats.is_empty():
		unit.max_hp = stats.get("max_hp", unit.max_hp)
		unit.max_pm = stats.get("max_pm", unit.max_pm)
		unit.max_ea = stats.get("max_ea", unit.max_ea)
		unit.courage = stats.get("courage", unit.courage)
		unit.has_ambidextrie = stats.get("ambidextrie", false)
		unit.attack_stat = stats.get("attack", unit.attack_stat)
		unit.parade_stat = stats.get("parade", unit.parade_stat)
		unit.adresse_stat = stats.get("adresse", unit.adresse_stat)
		unit.force_stat = stats.get("force", unit.force_stat)
		unit.intelligence_stat = stats.get("intelligence", unit.intelligence_stat)
		unit.charisme_stat = stats.get("charisme", unit.charisme_stat)
		unit.chance_stat = stats.get("chance", unit.chance_stat)
		unit.spells = UnitDatabase.build_spells(template_name)
		unit.equipped_weapon = UnitDatabase.build_weapon(template_name, "weapon")
		unit.off_hand_weapon = UnitDatabase.build_weapon(template_name, "weapon_off_hand")
		unit.inventory_arrows = UnitDatabase.build_arrows(template_name)
		unit.inventory_potions = UnitDatabase.build_potions(template_name)
		unit.inventory_weapons = UnitDatabase.build_inventory_weapons(template_name)

		var sprite_data = stats.get("sprite", null)
		if sprite_data != null:
			var sprite_path = sprite_data.get("path", "")
			if sprite_path != "" and ResourceLoader.exists(sprite_path):
				unit.sprite_sheet = load(sprite_path)
				unit.sprite_frame_size = Vector2i(
					sprite_data.get("frame_width", 32),
					sprite_data.get("frame_height", 32)
				)
				unit.sprite_scale = sprite_data.get("scale", 2.0)
				unit.sprite_y_offset = sprite_data.get("y_offset", 0.0)
				unit.sprite_animations = UnitDatabase.build_sprite_animations(template_name)
			else:
				push_warning("build_unit: sprite introuvable à '%s' pour la classe '%s' (fallback sur le disque de couleur)." % [sprite_path, template_name])

	if courage_override >= 0:
		unit.courage = courage_override

	return unit

# Place une unité déjà construite (via build_unit) sur une case de la
# grille : position, ajout à l'arbre de scène, enregistrement dans
# _cells et _all_units. Renvoie false si la case n'existe pas ou est
# déjà occupée (l'unité n'est alors ni ajoutée ni modifiée).
func place_unit_at(unit: CombatUnit, coord: Vector2i) -> bool:
	if not _cells.has(coord):
		push_warning("place_unit_at: case %s hors grille." % [coord])
		return false

	if is_occupied(coord):
		push_warning("place_unit_at: case %s déjà occupée." % [coord])
		return false

	unit.hex_coord = coord
	unit.position = axial_to_pixel(coord)

	add_child(unit)
	_cells[coord]["occupant"] = unit
	_all_units.append(unit)
	unit.died.connect(_on_unit_died)

	return true

# Construit une unité ET la place directement sur une case donnée —
# pratique quand on n'a pas besoin de phase de placement interactive
# (comportement historique, voir setup_starting_units). Renvoie null
# si le placement échoue (case invalide/occupée) ; l'unité construite
# est alors libérée immédiatement pour ne pas fuiter en mémoire.
func spawn_unit(coord: Vector2i, team: int, template_name: String, courage_override: int = -1) -> CombatUnit:
	var unit = build_unit(team, template_name, courage_override)
	if place_unit_at(unit, coord):
		return unit
	unit.queue_free()
	return null

# ---------- Phase de placement interactive ----------

# Renvoie les cases à une distance <= radius du centre de la grille
# (zone "centrale", utilisée par les modes Embuscade/Défense).
func get_center_zone_cells(radius: int) -> Dictionary:
	var result: Dictionary = {}
	var origin = Vector2i(0, 0)
	for coord in _cells.keys():
		if hex_distance(origin, coord) <= radius and _cells[coord]["is_walkable"]:
			result[coord] = true
	return result

# Renvoie toutes les cases à une distance > radius du centre (zone
# "périphérique", complémentaire de get_center_zone_cells).
func get_outer_zone_cells(radius: int) -> Dictionary:
	var result: Dictionary = {}
	var origin = Vector2i(0, 0)
	for coord in _cells.keys():
		if hex_distance(origin, coord) > radius and _cells[coord]["is_walkable"]:
			result[coord] = true
	return result

# Active le mode placement pour une unité donnée : elle sera posée sur
# la prochaine case valide (appartenant à zone_cells) cliquée par le
# joueur. Appelé par PlacementManager, une unité à la fois.
func start_placement(unit: CombatUnit, zone_cells) -> void:
	_pending_placement_unit = unit
	_placement_zone_cells = zone_cells
	placement_mode_active = true
	queue_redraw()

# Traite un clic pendant la phase de placement : vérifie que la case
# cliquée appartient à la zone autorisée et est libre, place l'unité
# en attente, puis notifie PlacementManager pour passer à la suivante.
func _handle_placement_click(coord: Vector2i) -> void:
	if not _placement_zone_cells.has(coord) or is_occupied(coord):
		return
	if not _cells.has(coord) or not _cells[coord]["is_walkable"]:
		return  # Sécurité (les zones excluent déjà les obstacles normalement).

	if not place_unit_at(_pending_placement_unit, coord):
		return

	placement_mode_active = false
	_pending_placement_unit = null
	_placement_zone_cells = {}  # Nouvelle table vide plutôt que .clear() : la
								# zone précédente est réutilisée par d'autres
								# unités du même camp, il ne faut pas la vider.
	queue_redraw()

	if _placement_manager != null:
		_placement_manager.on_unit_placed()

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

		if not _cells[coord]["is_walkable"]:
			fill = obstacle_color
		elif placement_mode_active:
			if _placement_zone_cells.has(coord):
				fill = placement_zone_color
		else:
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
