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
## suite ; ajuste/vide selon le niveau souhaité. Type BASIC (voir
## obstacle_type.gd) — infranchissable en permanence, aucun sort ne
## peut le retirer.
@export var obstacle_coords: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 1)]

## Obstacles de type EAU (voir obstacle_type.gd) : bloquent mouvement
## ET ligne de vue comme les obstacles BASIC, mais certains sorts
## peuvent les retirer (Évaporation d'eau, Gel de l'eau).
@export var water_obstacle_coords: Array[Vector2i] = []

## Faux : l'eau ne gêne plus la ligne de vue (on ne la traverse toujours
## pas à pied). Mis à faux pour les étages de la Tour.
var water_blocks_line_of_sight: bool = true

## Obstacles de type VIDE (voir obstacle_type.gd) : un gouffre/une
## fosse — un pont végétal peut le rendre temporairement franchissable
## en ligne.
@export var void_obstacle_coords: Array[Vector2i] = []

## Couleur des cases d'obstacle, une par type.
@export var obstacle_color: Color = Color(0.13, 0.11, 0.1, 0.95)
@export var water_obstacle_color: Color = Color(0.15, 0.35, 0.65, 0.95)
@export var void_obstacle_color: Color = Color(0.05, 0.03, 0.08, 0.98)

# Sort en cours de ciblage (null si on n'est pas en train de viser).
var _casting_spell: Spell = null

## Cases choisies par le joueur pour un sort de terrain en cours de
## ciblage (voir Spell.creates_obstacle_line/creates_bridge_line/
## removes_obstacle_type) — vide tant qu'aucune sélection n'est en cours.
var _terrain_selection_cells: Array = []

## Orientation d'un sort de Zone (voir _rotate_zone) : tant que
## _zone_orientation_locked est faux, la forme s'oriente toute seule (à
## l'opposé du lanceur) ; dès que le joueur la tourne (molette ou Q/E),
## elle garde ce nombre de crans de 60° jusqu'à la fin du ciblage.
var _zone_orientation_locked: bool = false
var _zone_orientation: int = 0

## X choisi par le joueur pour le sort à coût en PV en cours (voir
## Spell.is_ev_cost_spell / TurnManager.show_ev_cost_picker /
## confirm_ev_cost_spell) — lu une seule fois dans _cast_spell.
var _pending_ev_x: int = 0

## Nuit (Noirceur, Prêtre — voir Spell.installs_night) : affecte TOUT
## le champ de bataille, pas juste le lanceur. Décomptée d'un cran à
## chaque fois que c'est RÉ-au tour du joueur (voir
## TurnManager._start_current_turn), pas à chaque tour individuel.
var is_night: bool = false
var _night_turns_remaining: int = 0

# Cases à portée du sort en cours de ciblage. Clé : Vector2i -> Valeur : distance.
var _spell_range_cells: Dictionary = {}

## Couleur des cases à portée pendant le ciblage d'un sort.
@export var spell_range_color: Color = Color(0.95, 0.55, 0.15, 0.45)
@export var terrain_selection_color: Color = Color(0.3, 0.9, 0.5, 0.65)
@export var zone_preview_color: Color = Color(0.9, 0.25, 0.75, 0.55)
@export var zone_anchor_color: Color = Color(0.55, 0.08, 0.4, 0.9)  # Case d'ancre de la zone (la plus foncée).

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

	# Si ce combat vient d'une rencontre d'exploration, on remplace la
	# composition de test par la vraie (le seul personnage du joueur vs
	# les ennemis tirés dans la zone) — voir WorldManager.start_encounter_combat.
	if WorldManager.combat_from_encounter:
		player_units = [WorldManager.party_name]
		player_courage = []
		enemy_units = Array(WorldManager.pending_encounter_enemies, TYPE_STRING, "", null)
		enemy_courage = []
	elif TowerManager.run_active:
		# Tour de l'infini : les ennemis de l'étage courant (voir TowerFloors).
		# Les aventuriers, eux, sont reconstruits depuis TowerManager.team par
		# PlacementManager (voir _build_tower_units).
		player_units = []
		player_courage = []
		enemy_units = Array(TowerManager.get_floor_enemy_ids(), TYPE_STRING, "", null)
		enemy_courage = []
		# Carte de l'étage (piliers, rivière...), à poser AVANT generate_grid().
		var layout: Dictionary = TowerFloors.get_floor_layout(TowerManager.current_floor)
		obstacle_coords.assign(layout["obstacles"])
		water_obstacle_coords.assign(layout["water"])
		void_obstacle_coords.assign(layout["void"])
		water_blocks_line_of_sight = false

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

# Renvoie l'unité du joueur actuellement en vie (utile pour synchroniser
# ses PV/EA vers WorldManager à la fin d'un combat — voir
# TurnManager._return_to_exploration). Renvoie null si aucune (le
# joueur peut avoir plusieurs unités en test manuel : renvoie la
# première trouvée).
func get_player_unit() -> CombatUnit:
	for unit in _all_units:
		if unit.team == CombatUnit.Team.PLAYER:
			return unit
	return null

# Appelée par PlacementManager une fois toutes les unités placées :
# démarre le combat proprement dit (file d'initiative, premier tour).
func begin_combat_after_placement() -> void:
	if _turn_manager != null:
		_turn_manager.start_combat(_all_units)

# Devient vrai dès qu'une équipe n'a plus d'unité en vie. Bloque
# alors toute interaction (plus de sélection, déplacement, sort).
var combat_ended: bool = false

## Vrai pendant que l'IA joue le tour d'une unité ennemie (voir EnemyAI) :
## les clics du joueur sont alors ignorés — sans quoi il pourrait déplacer
## l'unité de l'adversaire, qui est sélectionnée comme n'importe quelle
## unité dont c'est le tour.
var ai_turn_in_progress: bool = false

## Larcin (Voleur) : nombre d'ennemis HUMAINS présents AU DÉBUT du
## combat (voir TurnManager.start_combat) — calculé une seule fois,
## pas recompté à chaque mort, car un ennemi tué est retiré de
## _all_units (voir remove_unit) et deviendrait invisible au décompte
## s'il fallait le refaire à la fin. "Humain" = equipped_race null (la
## plupart des ennemis actuels n'ont pas de race assignée, traités
## comme humains par défaut) OU equipped_race.race_name == "Humain".
var human_enemies_fought: int = 0

func _unhandled_input(event: InputEvent) -> void:
	if combat_ended:
		return

	# Sort de Zone en cours de ciblage : molette ou Q/E font tourner la
	# forme autour de son ancre (la case foncée), par pas de 60°.
	if _is_orientable_zone_targeting():
		var rotation_delta = 0
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				rotation_delta = 1
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				rotation_delta = -1
		elif event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_Q:
				rotation_delta = 1
			elif event.keycode == KEY_E:
				rotation_delta = -1
		if rotation_delta != 0:
			_rotate_zone(rotation_delta)
			get_viewport().set_input_as_handled()
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

			if ai_turn_in_progress:
				return  # C'est l'IA qui joue cette unité : consultation seulement.

			if occupant == _selected_unit:
				_deselect_unit()
			else:
				_select_unit(occupant)
		elif ai_turn_in_progress:
			return  # Pas de déplacement manuel de l'unité que l'IA est en train de jouer.
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
				"obstacle_type": ObstacleType.BASIC,  # Sans effet tant que is_walkable reste true.
				"occupant": null  # Contiendra une référence vers un CombatUnit une fois placé.
			}

	# Marque les cases d'obstacle (rochers, murs...) comme infranchissables
	# ET bloquant la ligne de vue (voir has_line_of_sight), avec leur
	# type (voir obstacle_type.gd — détermine quels sorts peuvent les
	# retirer/contourner). Configurable depuis l'inspecteur ; quelques
	# cases par défaut pour pouvoir tester la ligne de vue immédiatement.
	for coord in obstacle_coords:
		if _cells.has(coord):
			_cells[coord]["is_walkable"] = false
			_cells[coord]["obstacle_type"] = ObstacleType.BASIC

	for coord in water_obstacle_coords:
		if _cells.has(coord):
			_cells[coord]["is_walkable"] = false
			_cells[coord]["obstacle_type"] = ObstacleType.EAU

	for coord in void_obstacle_coords:
		if _cells.has(coord):
			_cells[coord]["is_walkable"] = false
			_cells[coord]["obstacle_type"] = ObstacleType.VIDE

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
			if not water_blocks_line_of_sight and _cells[coord].get("obstacle_type", ObstacleType.BASIC) == ObstacleType.EAU:
				continue  # On voit et on tire par-dessus l'eau.
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

	# Coût en Gloire (Gladiateur) : remplace entièrement la vérification
	# d'EA — ce sort ne consomme aucune EA.
	if spell.gloire_cost > 0:
		if active_unit.gloire < spell.gloire_cost:
			print("%s n'a pas assez de Gloire pour lancer %s (%d requise)." % [active_unit.unit_name, spell.spell_name, spell.gloire_cost])
			return
	else:
		var ea_cost = _compute_initial_cost(active_unit, spell) if spell.is_initial_cost else spell.get_effective_ea_cost(active_unit)
		if active_unit.current_ea < ea_cost:
			print("Pas assez d'Énergie Astrale pour lancer %s." % spell.spell_name)
			return

	if not active_unit.can_perform_action(spell):
		print("Une seule action par tour (ou 2 attaques mêlée avec Ambidextrie).")
		return

	# Sort à coût en PV (branche Walkyrie) OU en PA/EA variable (branche
	# Prêtre — voir Spell.is_pa_cost_spell) : on ouvre d'abord le
	# sélecteur de X (voir TurnManager.show_ev_cost_picker) — la
	# résolution reprend dans confirm_ev_cost_spell une fois X choisi,
	# AVANT tout ciblage (clic ou immédiat). Le PA peut tomber à 0 pile
	# (contrairement au PV, qui doit rester à 1 minimum).
	if spell.is_ev_cost_spell or spell.is_pa_cost_spell or spell.is_rage_cost_spell:
		var resource: int
		if spell.is_ev_cost_spell:
			resource = active_unit.current_hp - 1
		elif spell.is_pa_cost_spell:
			resource = active_unit.current_ea
		else:
			resource = active_unit.rage
		resource -= spell.ev_extra_flat_cost
		var max_x = min(spell.ev_cost_max, resource)
		if max_x < spell.ev_cost_min:
			var resource_label = "PV" if spell.is_ev_cost_spell else ("PA" if spell.is_pa_cost_spell else "Rage")
			print("%s n'a pas assez de %s pour lancer %s." % [active_unit.unit_name, resource_label, spell.spell_name])
			return
		if _turn_manager != null:
			_turn_manager.show_ev_cost_picker(spell, spell.ev_cost_min, max_x)
		return

	# Substitution (Prestidigitateur) : ouvre le sélecteur à 2 étapes
	# (stat +4, puis stat -4) — la résolution reprend dans
	# confirm_substitution une fois les deux choix faits.
	if spell.is_prestidigitateur_substitution:
		if _turn_manager != null:
			_turn_manager.show_stat_picker_step1(spell)
		return

	# Résurrection : on propose d'abord la liste des alliés morts (voir
	# TurnManager.show_resurrection_picker) ; la résolution reprend dans
	# confirm_resurrection une fois le défunt choisi.
	if spell.is_walkyrie_resurrection or spell.is_pretre_resurrection:
		var dead_allies: Array = get_graveyard_for_team(active_unit.team)
		if dead_allies.is_empty():
			spawn_floating_text(active_unit.position, "Aucun allié mort", Color(0.65, 0.65, 0.65))
			return
		if _turn_manager != null:
			_turn_manager.show_resurrection_picker(spell, dead_allies)
		return

	# SELF/GROUP/BATTLEFIELD n'ont pas besoin d'un clic : la ou les
	# cibles sont déjà connues (le lanceur, son équipe, ou tout le monde).
	match spell.target_mode:
		Spell.TargetMode.SELF:
			_cast_spell(active_unit, spell, [active_unit])
			return
		Spell.TargetMode.GROUP:
			_cast_spell(active_unit, spell, _get_team_including_self(active_unit))
			return
		Spell.TargetMode.BATTLEFIELD:
			_cast_spell(active_unit, spell, _get_battlefield_targets(active_unit, spell))
			return
		Spell.TargetMode.ALL_ENEMIES:
			_cast_spell(active_unit, spell, _get_opposing_team(active_unit))
			return

	# DI (délai d'incantation) : la cible/zone/case n'est PAS choisie
	# maintenant — on démarre juste la canalisation (voir _cast_spell),
	# le choix se fera au dernier tour d'incantation (voir
	# TurnManager._start_current_turn -> begin_delayed_targeting).
	if spell.cast_delay > 0:
		_cast_spell(active_unit, spell, [])
		return

	_casting_spell = spell
	_spell_range_cells = get_cells_in_range(active_unit.hex_coord, spell.min_range, spell.max_range)
	_reset_zone_orientation()
	queue_redraw()

# Cibles d'un sort BATTLEFIELD : toutes les unités, ou seulement celles à
# `battlefield_radius` cases ou moins du lanceur (Détection de zone : 2),
# lanceur exclu dans ce cas.
func _get_battlefield_targets(caster: CombatUnit, spell: Spell) -> Array:
	if spell.battlefield_radius <= 0:
		return _all_units.duplicate()
	var result: Array = []
	for u in _all_units:
		if u != caster and hex_distance(caster.hex_coord, u.hex_coord) <= spell.battlefield_radius:
			result.append(u)
	return result

# Appelée par TurnManager une fois que le joueur a choisi X dans le
# sélecteur (voir show_ev_cost_picker) — reprend exactement où
# enter_targeting_mode() se serait arrêté pour un sort normal :
# résolution immédiate pour SELF/GROUP/ALL_ENEMIES, sinon ouverture du
# ciblage au clic. `_pending_ev_x` est lu une seule fois, dans
# _cast_spell, au moment de la résolution finale.
func confirm_ev_cost_spell(spell: Spell, x: int) -> void:
	_pending_ev_x = x

	match spell.target_mode:
		Spell.TargetMode.SELF:
			_cast_spell(active_unit, spell, [active_unit])
			return
		Spell.TargetMode.GROUP:
			_cast_spell(active_unit, spell, _get_team_including_self(active_unit))
			return
		Spell.TargetMode.BATTLEFIELD:
			_cast_spell(active_unit, spell, _get_battlefield_targets(active_unit, spell))
			return
		Spell.TargetMode.ALL_ENEMIES:
			_cast_spell(active_unit, spell, _get_opposing_team(active_unit))
			return

	_casting_spell = spell
	_spell_range_cells = get_cells_in_range(active_unit.hex_coord, spell.min_range, spell.max_range)
	_reset_zone_orientation()
	queue_redraw()

# Appelée par TurnManager une fois les deux étapes du sélecteur de
# statistique validées (voir show_stat_picker_step1, Spell.
# is_prestidigitateur_substitution) : jet d'Intelligence (SpellType.
# INTELLIGENCE déjà posé sur le sort, mais le jet est fait ici à la
# main — pas de cible à cliquer, donc pas de passage par
# _resolve_spell_effect) ; si réussi, +4 à `stat_up` et -4 à
# `stat_down` (deux champs bonus_* de StatusEffect, ex: "bonus_force")
# pendant 5 tours.
# Calcule le montant d'un coût "(i)" (voir Spell.is_initial_cost) —
# soit une valeur fixe (ea_cost), soit un pourcentage du max_ea ACTUEL
# du lanceur (voir initial_cost_is_percent/initial_cost_percent_value,
# ex: "50%(i)", "10%(i)").
func _compute_initial_cost(caster: CombatUnit, spell: Spell) -> int:
	if spell.initial_cost_is_percent:
		return int(round(caster.max_ea * spell.initial_cost_percent_value))
	return spell.ea_cost

# Déduit un coût "(i)" — contrairement à un coût normal (current_ea,
# temporaire, remonte avec le repos), celui-ci réduit base_max_ea
# PERMANENTEMENT (le lanceur a durablement moins d'EA max pour le
# reste du combat, voire au-delà si base_max_ea survit hors combat).
func _deduct_initial_cost(caster: CombatUnit, spell: Spell) -> void:
	var amount = _compute_initial_cost(caster, spell)
	caster.set_meta("last_initial_cost_paid", amount)  # Pour le remboursement si le sort rate (voir _refund_failed_initial_cost).
	caster.base_max_ea = max(0, caster.base_max_ea - amount)
	caster._recalculate_stats()
	caster.current_ea = min(caster.current_ea, caster.max_ea)
	spawn_floating_text(caster.position, "-%d EA max" % amount, Color(0.75, 0.25, 0.55))
	print("%s perd %d EA MAXIMUM de façon permanente pour %s." % [caster.unit_name, amount, spell.spell_name])

func confirm_substitution(spell: Spell, stat_up: String, stat_down: String) -> void:
	var caster = active_unit
	caster.record_action_taken(spell)
	var ea_cost = spell.get_effective_ea_cost(active_unit)
	caster.current_ea -= ea_cost
	if ea_cost > 0:
		spawn_floating_text(caster.position, "-%d %s" % [ea_cost, caster.get_resource_name()], Color(0.65, 0.45, 0.95))

	var roll = randi_range(1, 20)
	if roll >= caster.intelligence_stat:
		spawn_floating_text(caster.position, "Substitution ratée", Color(0.65, 0.65, 0.65))
		print("%s rate son test d'Intelligence pour Substitution (jet %d >= %d)." % [caster.unit_name, roll, caster.intelligence_stat])
		_refund_failed_cast(caster, ea_cost)
		cancel_targeting_mode()
		if _turn_manager != null:
			_turn_manager.refresh_ui()
		return

	var buff := StatusEffect.new()
	buff.effect_name = "Substitution (+4 %s, -4 %s)" % [stat_up.trim_prefix("bonus_").capitalize(), stat_down.trim_prefix("bonus_").capitalize()]
	buff.duration_remaining = 5
	buff.set(stat_up, 4)
	buff.set(stat_down, -4)
	caster.add_status_effect(buff)
	spawn_floating_text(caster.position, buff.effect_name, Color(0.8, 0.6, 0.9))
	print("%s réussit Substitution : %s." % [caster.unit_name, buff.effect_name])

	cancel_targeting_mode()
	if _turn_manager != null:
		_turn_manager.refresh_ui()

# Réouvre le ciblage d'un sort dont la canalisation vient de se
# terminer (voir TurnManager._start_current_turn) : le joueur choisit
# maintenant sa cible/zone/case, le coût ayant déjà été payé au lancer
# initial (voir _cast_spell, _cast_summon_spell, confirm_terrain_selection
# — chacun vérifie caster.pending_spell == spell pour ne pas repayer).
func begin_delayed_targeting(unit: CombatUnit, spell: Spell) -> void:
	set_active_unit(unit)
	_casting_spell = spell
	_spell_range_cells = get_cells_in_range(unit.hex_coord, spell.min_range, spell.max_range)
	_reset_zone_orientation()
	queue_redraw()

# ---------- Plan parallèle (Prêtre) ----------

var _parallel_first: CombatUnit = null  # 1re cible choisie, en attente de la 2e.

func _plane_active(u: CombatUnit) -> bool:
	return u.parallel_turns_remaining > 0 and u.parallel_partner != null \
		and is_instance_valid(u.parallel_partner) and u.parallel_partner.current_hp > 0

# Faux si `a` et `b` sont séparés par un plan parallèle : deux unités du
# même plan n'interagissent qu'entre elles, et plus avec personne d'autre.
func can_interact(a: CombatUnit, b: CombatUnit) -> bool:
	if a == b:
		return true
	var pa: bool = _plane_active(a)
	var pb: bool = _plane_active(b)
	if not pa and not pb:
		return true
	return pa and pb and a.parallel_partner == b and b.parallel_partner == a

func _set_plane_tint(u: CombatUnit, on: bool) -> void:
	u.modulate = Color(0.7, 0.55, 1.0, 0.75) if on else Color(1, 1, 1, 1)

func _apply_parallel_plane(a: CombatUnit, b: CombatUnit, turns: int) -> void:
	a.parallel_partner = b
	b.parallel_partner = a
	a.parallel_turns_remaining = turns
	b.parallel_turns_remaining = turns
	_set_plane_tint(a, true)
	_set_plane_tint(b, true)
	spawn_floating_text(a.position, "Plan parallèle (%d)" % turns, Color(0.7, 0.55, 1.0))
	spawn_floating_text(b.position, "Plan parallèle (%d)" % turns, Color(0.7, 0.55, 1.0))
	print("%s et %s sont isolés dans un plan parallèle pendant %d tours." % [a.unit_name, b.unit_name, turns])

func _end_parallel_plane(u: CombatUnit) -> void:
	var partner = u.parallel_partner
	u.parallel_partner = null
	u.parallel_turns_remaining = 0
	_set_plane_tint(u, false)
	if partner != null and is_instance_valid(partner):
		partner.parallel_partner = null
		partner.parallel_turns_remaining = 0
		_set_plane_tint(partner, false)
	spawn_floating_text(u.position, "Fin du plan parallèle", Color(0.7, 0.55, 1.0))

# Appelée par TurnManager au début du tour de `u` : décompte propre à
# chaque unité du plan (5 tours chacune) ; le plan se défait dès que l'une
# arrive à 0, ou si son partenaire est mort.
func tick_parallel_plane(u: CombatUnit) -> void:
	if u.parallel_turns_remaining <= 0:
		return
	if not _plane_active(u):
		_end_parallel_plane(u)
		return
	u.parallel_turns_remaining -= 1
	if u.parallel_turns_remaining <= 0:
		_end_parallel_plane(u)

func cancel_targeting_mode() -> void:
	_casting_spell = null
	_parallel_first = null
	_spell_range_cells.clear()
	_terrain_selection_cells.clear()
	_zone_orientation_locked = false
	if _turn_manager != null:
		_turn_manager.hide_terrain_selection_ui()
		_turn_manager.show_zone_hint(false)
	queue_redraw()

# Renvoie toutes les unités vivantes de la même équipe que `unit`, LUI
# COMPRIS — utilisé pour le ciblage GROUP (voir Spell.TargetMode).
func _get_team_including_self(unit: CombatUnit) -> Array:
	var result: Array = []
	for u in _all_units:
		if u.team == unit.team:
			result.append(u)
	return result

# Symétrique de _get_team_including_self : toutes les unités de
# l'équipe ADVERSE à `unit` — voir Spell.TargetMode.ALL_ENEMIES
# (Jugement divin, Walkyrie).
func _get_opposing_team(unit: CombatUnit) -> Array:
	var result: Array = []
	for u in _all_units:
		if u.team != unit.team:
			result.append(u)
	return result

# Renvoie toutes les unités (alliées ET ennemies) dans un rayon de
# `radius` cases autour de `center` — utilisé pour le ciblage ZONE
# (voir Spell.TargetMode). Une zone touche tout le monde dans le
# souffle, pas seulement les ennemis : positionner ses alliés à
# l'écart devient une vraie décision tactique.
func _get_units_in_radius(center: Vector2i, radius: int) -> Array:
	var result: Array = []
	for coord in _cells.keys():
		if hex_distance(center, coord) <= radius:
			var occupant = _cells[coord]["occupant"]
			if occupant != null:
				result.append(occupant)
	return result

# ---------- Zones : forme (ZoneShapes), ancre et orientation ----------

# Vrai pendant le ciblage d'un sort de Zone qui a une forme définie
# (Spell.zone_offsets) — c'est alors le seul cas où la forme est
# orientable (molette / Q / E).
func _is_orientable_zone_targeting() -> bool:
	return _casting_spell != null and _casting_spell.target_mode == Spell.TargetMode.ZONE \
		and not _casting_spell.zone_offsets.is_empty()

# À appeler dès qu'un ciblage de Zone commence : repart d'une orientation
# automatique et affiche (ou masque) l'aide "molette / Q-E".
func _reset_zone_orientation() -> void:
	_zone_orientation_locked = false
	_zone_orientation = 0
	if _turn_manager != null:
		_turn_manager.show_zone_hint(_is_orientable_zone_targeting())

# Nombre de crans de 60° à appliquer à la forme de base du sort. En
# automatique : la forme "pointe" à l'opposé du lanceur (les formes
# symétriques ne tournent pas). Une fois tournée à la main : fixe.
func _get_zone_orientation_steps(spell: Spell, caster_coord: Vector2i, anchor: Vector2i) -> int:
	if _zone_orientation_locked:
		return _zone_orientation
	var principal = ZoneShapes.principal_direction(spell.zone_offsets)
	if principal < 0 or anchor == caster_coord:
		return 0
	return posmod(_nearest_hex_direction(anchor - caster_coord) - principal, 6)

# Tourne la forme de `delta` crans de 60° (positif = sens trigonométrique)
# et la fige dans cette orientation jusqu'à la fin du ciblage.
func _rotate_zone(delta: int) -> void:
	if not _is_orientable_zone_targeting():
		return
	var anchor = _hovered_coord if _hovered_coord != null else active_unit.hex_coord
	var current = _get_zone_orientation_steps(_casting_spell, active_unit.hex_coord, anchor)
	_zone_orientation = posmod(current + delta, 6)
	_zone_orientation_locked = true
	queue_redraw()

# Cases touchées par un sort de Zone posé avec son ANCRE sur `anchor`
# (la case foncée du schéma — elle fait partie de la zone), selon la
# forme et l'orientation courantes.
func _get_zone_cells(caster_coord: Vector2i, anchor: Vector2i, spell: Spell) -> Array:
	var cells: Array = [anchor]
	if spell.zone_offsets.is_empty():
		for dir in DIRECTIONS:  # Sans forme définie : l'ancre et ses 6 voisines.
			cells.append(anchor + dir)
		return cells

	var steps = _get_zone_orientation_steps(spell, caster_coord, anchor)
	for offset in spell.zone_offsets:
		var c = anchor + ZoneShapes.rotate_offset(offset, steps)
		if not cells.has(c):
			cells.append(c)
	return cells

# Trouve, parmi les 6 DIRECTIONS, celle qui pointe le plus proche de
# `delta` (converti en position écran pour comparer des angles plutôt
# que des coordonnées axiales brutes, qui ne sont pas orthonormées).
func _nearest_hex_direction(delta: Vector2i) -> int:
	var delta_pixel = axial_to_pixel(delta) - axial_to_pixel(Vector2i.ZERO)
	var best_index = 0
	var best_dot = -INF
	for i in range(DIRECTIONS.size()):
		var dir_pixel = axial_to_pixel(DIRECTIONS[i]) - axial_to_pixel(Vector2i.ZERO)
		var dot = delta_pixel.normalized().dot(dir_pixel.normalized())
		if dot > best_dot:
			best_dot = dot
			best_index = i
	return best_index

# Convertit une liste de cellules (voir _get_zone_cells) en
# unités présentes dessus.
func _get_units_in_cells(cells: Array) -> Array:
	var result: Array = []
	for coord in cells:
		if _cells.has(coord):
			var occupant = _cells[coord]["occupant"]
			if occupant != null:
				result.append(occupant)
	return result

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

# Joue l'animation d'un sort (voir Spell.effect_sprite_path) centrée
# sur `world_pos` — une seule fois, se retire elle-même une fois
# terminée. Ne fait rien si le sort n'a pas d'animation configurée
# (comportement normal pour la grande majorité des sorts pour
# l'instant : juste le texte flottant habituel).
func _spawn_spell_effect(spell: Spell, world_pos: Vector2) -> void:
	if spell.effect_sprite_path == "" or not ResourceLoader.exists(spell.effect_sprite_path):
		return

	var texture = load(spell.effect_sprite_path)

	var frames := SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")
	frames.add_animation("play")
	frames.set_animation_loop("play", false)
	frames.set_animation_speed("play", spell.effect_fps)

	for i in range(spell.effect_frame_count):
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(
			spell.effect_start_x + i * spell.effect_frame_size.x, spell.effect_row,
			spell.effect_frame_size.x, spell.effect_frame_size.y
		)
		frames.add_frame("play", atlas)

	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = frames
	sprite.animation = "play"
	sprite.position = world_pos
	sprite.scale = Vector2(spell.effect_scale, spell.effect_scale)
	sprite.z_index = 90  # Sous le texte flottant (100), au-dessus du reste.
	sprite.animation_finished.connect(sprite.queue_free)
	add_child(sprite)
	sprite.play("play")

# Traite un clic pendant le mode ciblage : vérifie que la case est à
# portée, construit la liste de cibles selon le mode du sort (voir
# Spell.TargetMode), puis lance le sort. SELF/GROUP ne passent jamais
# par ici (gérés directement dans enter_targeting_mode, sans clic).
func _handle_spell_target_click(coord: Vector2i) -> void:
	if not _spell_range_cells.has(coord):
		return  # Hors de portée, clic ignoré.

	# Invocation : on clique une case VIDE (pas une unité existante) pour
	# y faire apparaître la créature — traitement complètement à part du
	# ciblage normal.
	if _casting_spell.is_summon:
		if is_occupied(coord) or not _cells[coord]["is_walkable"]:
			return  # Case occupée ou infranchissable, clic ignoré.
		_cast_summon_spell(active_unit, _casting_spell, coord)
		return

	# Sorts de terrain (mur, pont, retrait d'obstacle) : sélection
	# manuelle case par case par le joueur, validée via un bouton dédié
	# plutôt que résolue automatiquement au premier clic — voir
	# _handle_terrain_selection_click / confirm_terrain_selection.
	if _casting_spell.creates_obstacle_line or _casting_spell.creates_bridge_line or _casting_spell.removes_obstacle_type >= 0:
		_handle_terrain_selection_click(coord)
		return

	var clicked_unit = _cells[coord]["occupant"]
	var targets: Array = []

	# Plan parallèle : deux clics sur deux unités DIFFÉRENTES (n'importe quel
	# camp, lanceur compris, sauf invisibles ennemis).
	if _casting_spell.is_parallel_plane:
		if clicked_unit == null or (clicked_unit.is_untargetable and clicked_unit.team != active_unit.team):
			return
		if not can_interact(active_unit, clicked_unit):
			return
		if _parallel_first == null:
			_parallel_first = clicked_unit
			spawn_floating_text(clicked_unit.position, "1re cible — choisis la 2e", Color(0.7, 0.55, 1.0))
			return
		if clicked_unit == _parallel_first:
			return
		targets = [_parallel_first, clicked_unit]
		_cast_spell(active_unit, _casting_spell, targets)
		return

	match _casting_spell.target_mode:
		Spell.TargetMode.SINGLE_ENEMY:
			if clicked_unit == null or clicked_unit.team == active_unit.team:
				return  # Pas de cible, ou cible alliée — un sort offensif ne peut viser que l'ennemi.
			if clicked_unit.is_untargetable:
				return  # Invisible pour les ennemis (voir StatusEffect.grants_untargetable).
			targets = [clicked_unit]

		Spell.TargetMode.SINGLE_ALLY:
			if clicked_unit == null or clicked_unit.team != active_unit.team:
				return  # Pas de cible, ou cible ennemie — peut se cibler soi-même (utile pour les soins).
			targets = [clicked_unit]

		Spell.TargetMode.ZONE:
			var zone_cells = _get_zone_cells(active_unit.hex_coord, coord, _casting_spell)
			targets = _get_units_in_cells(zone_cells).filter(func(u): return not (u.is_untargetable and u.team != active_unit.team))
			if targets.is_empty():
				return  # Rien à toucher dans la zone, clic ignoré (pas de gâchis d'action).

		_:
			return  # SELF/GROUP/BATTLEFIELD ne devraient jamais arriver ici — sécurité.

	_cast_spell(active_unit, _casting_spell, targets)

# Construit une unité d'invocation à partir des champs summon_* d'un
# sort (voir Spell.is_summon) — PAS depuis UnitDatabase, puisque ce
# n'est pas une classe de personnage mais une créature générée par le
# sort. Pas encore placée sur la grille (voir _cast_summon_spell).
func build_summon_unit(spell: Spell, team: int, caster: CombatUnit = null) -> CombatUnit:
	if spell.is_meca_summon and caster != null:
		return _build_meca_unit(caster, spell)

	var unit := CombatUnit.new()
	unit.unit_name = spell.summon_name
	unit.team = team
	unit.custom_fallback_color = spell.summon_color

	unit.base_max_hp = spell.summon_max_hp
	unit.base_max_ea = 0  # Une invocation ne lance pas de sorts, pas besoin d'EA.
	unit.base_courage = 10  # Valeur neutre (non précisée dans le catalogue Mage).
	unit.base_attack_stat = spell.summon_attack_parade
	unit.base_parade_stat = spell.summon_attack_parade
	unit.base_adresse_stat = 10
	unit.base_force_stat = 10
	unit.base_intelligence_stat = 10
	unit.base_charisme_stat = 10
	unit.base_chance_stat = 10

	var weapon := Weapon.new()
	weapon.weapon_name = "%s (attaque naturelle)" % spell.summon_name
	weapon.dice_count = spell.summon_dice_count
	weapon.dice_modifier = spell.summon_dice_modifier
	weapon.bonus_armure = spell.summon_armor  # PR du catalogue -> armor_value, via l'équipement (voir _recalculate_stats).
	weapon.min_range = 1
	weapon.max_range = 1
	unit.equipped_weapon = weapon

	return unit

# Palier débloqué par le NIVEAU du lanceur (voir Ingénieur Automate) :
# 0 = base, 1 = Supplément 1 (niveau 7+), 2 = Supplément 2 (niveau 10+).
# Toujours le palier le plus haut déjà débloqué.
func _get_meca_tier(caster_level: int) -> int:
	if caster_level >= 10:
		return 2
	if caster_level >= 7:
		return 1
	return 0

# Construit un Méca (voir Spell.meca_type) — stats ET capacité
# spéciale dépendent du palier débloqué par le niveau du lanceur (voir
# _get_meca_tier). "Supplément 1/2" ne sont PAS de nouveaux Mécas,
# juste une version améliorée du même (confirmé) : un seul match par
# type, les 3 colonnes de stats du catalogue d'origine condensées ici.
func _build_meca_unit(caster: CombatUnit, spell: Spell) -> CombatUnit:
	var tier = _get_meca_tier(caster.level)

	var unit := CombatUnit.new()
	unit.team = caster.team
	unit.base_max_ea = 0
	unit.base_courage = 10
	unit.base_adresse_stat = 10
	unit.base_force_stat = 10
	unit.base_intelligence_stat = 10
	unit.base_charisme_stat = 10
	unit.base_chance_stat = 10

	var hp: int; var pr: int; var attaque: int; var parade: int
	var dice_count := 0; var dice_modifier := 0

	match spell.meca_type:
		"doc":
			unit.unit_name = "Méca Doc"
			unit.custom_fallback_color = Color(0.85, 0.3, 0.4)
			hp = [15, 20, 25][tier]; pr = [0, 1, 2][tier]; attaque = 0; parade = [3, 5, 7][tier]
		"tanker":
			unit.unit_name = "Méca Tanker"
			unit.custom_fallback_color = Color(0.4, 0.55, 0.85)
			hp = [35, 45, 55][tier]; pr = [3, 4, 6][tier]; attaque = 0; parade = 7
		"combat":
			unit.unit_name = "Méca Combat"
			unit.custom_fallback_color = Color(0.9, 0.6, 0.2)
			hp = [22, 28, 34][tier]; pr = [1, 2, 3][tier]; attaque = [7, 9, 12][tier]; parade = [10, 11, 12][tier]
			dice_count = 1 if tier != 1 else 2
			dice_modifier = [6, 3, 7][tier]
		"support":
			unit.unit_name = "Méca Support"
			unit.custom_fallback_color = Color(0.5, 0.8, 0.4)
			hp = [12, 16, 18][tier]; pr = [1, 2, 3][tier]; attaque = 0; parade = [0, 2, 4][tier]
		_:
			hp = 10; pr = 0; attaque = 0; parade = 0

	unit.base_max_hp = hp
	unit.base_attack_stat = attaque
	unit.base_parade_stat = parade

	var weapon := Weapon.new()
	weapon.weapon_name = "%s (attaque naturelle)" % unit.unit_name
	weapon.dice_count = dice_count
	weapon.dice_modifier = dice_modifier
	weapon.bonus_armure = pr
	weapon.min_range = 1
	weapon.max_range = 1
	unit.equipped_weapon = weapon

	return unit

# Donne au Méca fraîchement posé sa capacité spéciale, le cas échéant
# (voir Spell.meca_type) — appelée APRÈS place_unit_at (donc après
# _ready(), qui a déjà construit la liste de sorts de base) puisqu'on
# AJOUTE à cette liste plutôt que de la reconstruire.
func _attach_meca_ability(caster: CombatUnit, summon: CombatUnit, spell: Spell) -> void:
	var tier = _get_meca_tier(caster.level)

	match spell.meca_type:
		"doc":
			var heal := Spell.new()
			heal.spell_name = "Soin (Méca Doc)"
			heal.target_mode = Spell.TargetMode.SINGLE_ALLY
			heal.ea_cost = 0
			heal.is_meca_doc_heal = true
			heal.meca_tier = tier
			heal.min_range = 1
			heal.max_range = 6
			summon.spells.append(heal)

		"support":
			var buff_spell := Spell.new()
			buff_spell.spell_name = "Soutien (Méca Support)"
			buff_spell.target_mode = Spell.TargetMode.SINGLE_ALLY
			buff_spell.ea_cost = 0
			summon.is_meca_support = true
			buff_spell.is_meca_support_buff = true
			buff_spell.meca_tier = tier
			buff_spell.min_range = 1
			buff_spell.max_range = 6
			summon.spells.append(buff_spell)

		"tanker":
			# Provocation : l'IA ennemie ne peut viser que ce Méca tant qu'il
			# est en vie (voir EnemyAI._get_targets). Aucun effet sur un
			# ennemi piloté par un joueur humain.
			summon.is_taunting = true
			spawn_floating_text(summon.position, "Provoque !", Color(0.5, 0.7, 1.0))

			# Aura passive (+1 PR aux N alliés les plus proches tant que le Méca
			# est en vie) : recalculée dynamiquement (voir _refresh_tanker_auras).
			summon.tanker_aura_count = [0, 1, 2][tier]
			_refresh_tanker_auras()

		"combat":
			pass  # Juste les stats/l'attaque naturelle — déjà posées dans _build_meca_unit.

# Doc (Méca) : formule de soin par palier — 1D6 / 1D6+3 PV / 10 PV +
# 3 EA d'un coup (palier 2, trop spécifique pour le système générique
# is_heal+restores_mana, voir Spell.is_meca_doc_heal).
# Peinture de guerre (Peintre) : test Courage (1d20 < courage) ; si
# réussi, +niveau Courage ET +niveau Force à TOUT le groupe (soi-même
# compris), pour le reste du combat. Résolution sur-mesure (voir
# Spell.is_peintre_peinture_de_guerre) car le bonus dépend du niveau
# DU LANCEUR au moment précis du lancer.
# Tranquillo (Barde) : coût = 2 + (nombre d'ennemis vivants), touche
# TOUS les ennemis (simplification de "X Ennemis choisis" — pas de
# sélection multiple chez nous, voir Spell.is_barde_tranquillo) ; les
# touchés passent leur prochain tour (stun_turns = 1).
func _resolve_barde_tranquillo(caster: CombatUnit) -> void:
	var enemies = _get_opposing_team(caster)
	var cost = 2 + enemies.size()
	caster.current_ea = max(0, caster.current_ea - cost)
	spawn_floating_text(caster.position, "-%d EA" % cost, Color(0.65, 0.45, 0.95))

	for enemy in enemies:
		if _try_dodge(enemy, caster):
			continue
		var stun := StatusEffect.new()
		stun.effect_name = "Tranquillo (passe son tour)"
		stun.duration_remaining = 1
		stun.grants_frozen = true
		enemy.add_status_effect(stun)
		spawn_floating_text(enemy.position, "Endormi !", Color(0.6, 0.7, 0.95))

	print("%s lance Tranquillo sur %d ennemi(s) (%d EA)." % [caster.unit_name, enemies.size(), cost])

# Meno (Barde) : coût et durée entièrement dérivés du Charisme du
# lanceur (2×(Charisme-12), voir Spell.barde_cost_multiplier) — tous
# les ennemis subissent -2 Courage, -2 Attaque, -2 Parade.
func _resolve_barde_meno(caster: CombatUnit) -> void:
	var duration = max(1, caster.charisme_stat - 12)
	var cost = 2 * duration
	caster.current_ea = max(0, caster.current_ea - cost)
	spawn_floating_text(caster.position, "-%d EA" % cost, Color(0.65, 0.45, 0.95))

	for enemy in _get_opposing_team(caster):
		var debuff := StatusEffect.new()
		debuff.effect_name = "Meno (-2 Courage, -2 Attaque, -2 Parade)"
		debuff.duration_remaining = duration
		debuff.bonus_courage = -2
		debuff.bonus_attaque = -2
		debuff.bonus_parade = -2
		enemy.add_status_effect(debuff)
		spawn_floating_text(enemy.position, "Affaibli !", Color(0.75, 0.4, 0.3))

	print("%s lance Meno (%d tours, %d EA)." % [caster.unit_name, duration, cost])

# Slancio (Barde) : même principe que Meno (coût/durée dérivés du
# Charisme, 7×(Charisme-12)) — un allié gagne +1 Courage, +1 Attaque,
# +1 Parade.
func _resolve_barde_slancio(caster: CombatUnit, target: CombatUnit) -> void:
	var duration = max(1, caster.charisme_stat - 12)
	var cost = 7 * duration
	caster.current_ea = max(0, caster.current_ea - cost)
	spawn_floating_text(caster.position, "-%d EA" % cost, Color(0.65, 0.45, 0.95))

	var buff := StatusEffect.new()
	buff.effect_name = "Slancio (+1 Courage, +1 Attaque, +1 Parade)"
	buff.duration_remaining = duration
	buff.bonus_courage = 1
	buff.bonus_attaque = 1
	buff.bonus_parade = 1
	target.add_status_effect(buff)
	spawn_floating_text(target.position, "Élan !", Color(0.9, 0.7, 0.3))

	print("%s lance Slancio sur %s (%d tours, %d EA)." % [caster.unit_name, target.unit_name, duration, cost])

# Porte étendard (Soldat) : test Cou/Cha (1d20 < moy(Courage,
# Charisme)) ; si réussi, tout allié actuellement adjacent à `coord`
# (la case où l'étendard est "posé") gagne +1 à toutes les stats et
# +1 AT/PRD pendant 3 tours. Effet figé à cet instant — voir la note
# de Spell.is_soldat_porte_etendard sur cette simplification.
# Tourbillon (Berzerk) : attaque de base contre TOUT le monde à 1
# hexagone (alliés compris) — réutilise directement
# _resolve_weapon_attack pour chaque cible (un vrai jet, une vraie
# armure, Enragé/Coûte que coûte etc. s'appliquent normalement à
# chacun), plutôt que de dupliquer sa logique.
func _resolve_berzerk_tourbillon(caster: CombatUnit) -> void:
	if caster.equipped_weapon == null:
		return
	var attack_spell = caster.equipped_weapon.create_attack_spell()
	var targets_hit = _all_units.filter(func(u): return u != caster and hex_distance(caster.hex_coord, u.hex_coord) == 1)
	print("%s déclenche Tourbillon sur %d cible(s)." % [caster.unit_name, targets_hit.size()])
	for target in targets_hit:
		_resolve_weapon_attack(caster, attack_spell, target)

func _resolve_porte_etendard(caster: CombatUnit, spell: Spell, coord: Vector2i) -> void:
	var avg_stat = (caster.courage + caster.charisme_stat) / 2.0
	var roll = randi_range(1, 20)
	if roll >= avg_stat:
		spawn_floating_text(caster.position, "Porte étendard raté", Color(0.65, 0.65, 0.65))
		print("%s rate son test Cou/Cha pour Porte étendard (jet %d >= %.1f)." % [caster.unit_name, roll, avg_stat])
		_refund_failed_cast(caster, spell.get_effective_ea_cost(caster))
		return

	spawn_floating_text(axial_to_pixel(coord), "Étendard planté !", Color(0.85, 0.75, 0.3))
	print("%s plante un étendard." % caster.unit_name)

	for ally in _get_team_including_self(caster):
		if hex_distance(coord, ally.hex_coord) == 1:
			var buff := StatusEffect.new()
			buff.effect_name = "Porte étendard (+1 toutes stats, +1 AT/PRD)"
			buff.duration_remaining = 3
			buff.bonus_courage = 1
			buff.bonus_intelligence = 1
			buff.bonus_charisme = 1
			buff.bonus_adresse = 1
			buff.bonus_force = 1
			buff.bonus_chance = 1
			buff.bonus_attaque = 1
			buff.bonus_parade = 1
			ally.add_status_effect(buff)
			spawn_floating_text(ally.position, "Rallié !", Color(0.9, 0.8, 0.4))

func _resolve_peinture_de_guerre(caster: CombatUnit, spell: Spell = null) -> void:
	var roll = randi_range(1, 20)
	if roll >= caster.courage:
		spawn_floating_text(caster.position, "Peinture de guerre ratée", Color(0.65, 0.65, 0.65))
		print("%s rate son test de Courage pour Peinture de guerre (jet %d >= %d)." % [caster.unit_name, roll, caster.courage])
		if spell != null:
			_refund_failed_cast(caster, spell.get_effective_ea_cost(caster))
		return

	var bonus = caster.level
	for ally in _get_team_including_self(caster):
		var buff := StatusEffect.new()
		buff.effect_name = "Peinture de guerre (+%d Courage, +%d Force)" % [bonus, bonus]
		buff.duration_remaining = -1  # Pour le reste du combat.
		buff.bonus_courage = bonus
		buff.bonus_force = bonus
		ally.add_status_effect(buff)
		spawn_floating_text(ally.position, "+%d COU, +%d FO" % [bonus, bonus], Color(0.9, 0.7, 0.3))

	print("%s réussit Peinture de guerre : +%d Courage/Force au groupe." % [caster.unit_name, bonus])

# Maquillage (Peintre) : SANS effet mécanique pour l'instant (voir la
# note de Spell.is_peintre_maquillage — son vrai intérêt n'a de sens
# qu'en PvP, à revoir quand ça existera) : consomme une charge (3
# max/combat, que le test réussisse ou non), fait un jet INT/CHA pour
# la forme, et affiche juste un texte.
func _resolve_peintre_maquillage(caster: CombatUnit, spell: Spell = null) -> void:
	caster.peintre_maquillage_used += 1

	var avg_stat = (caster.intelligence_stat + caster.charisme_stat) / 2.0
	var roll = randi_range(1, 20)
	if roll < avg_stat:
		spawn_floating_text(caster.position, "Maquillage réussi !", Color(0.8, 0.6, 0.9))
		print("%s prend l'apparence de quelqu'un d'autre (cosmétique)." % caster.unit_name)
	else:
		spawn_floating_text(caster.position, "Maquillage raté", Color(0.65, 0.65, 0.65))
		print("%s rate son Maquillage (jet %d >= %.1f)." % [caster.unit_name, roll, avg_stat])
		if spell != null:
			_refund_failed_cast(caster, spell.get_effective_ea_cost(caster))

# Permutation (Ninja) : échange INSTANTANÉMENT la position du lanceur
# et d'un allié — met à jour hex_coord, la position à l'écran ET
# l'occupation des cases (voir move_unit pour le même genre de mise à
# jour, mais à sens unique). 3 fois max par combat.
# Polyvalence (Ingénieur et ses évolutions) : +1 aux tests de COMPÉTENCES
# (pas aux sorts) de tout le groupe tant qu'un allié vivant l'a.
func get_skill_test_bonus(unit: CombatUnit) -> int:
	for ally in _get_team_including_self(unit):
		if ally.current_hp > 0 and ally.has_metier("Ingénieur"):
			return 1
	return 0

# Appelée par TurnManager quand le joueur a choisi qui ressusciter.
func confirm_resurrection(spell: Spell, corpse: CombatUnit) -> void:
	if active_unit == null:
		return
	_pending_resurrection = corpse
	_cast_spell(active_unit, spell, [active_unit])

# Grâce du ciel (Walkyrie) : l'allié choisi revient à 15 PV, perd 15 PV max
# et 1 point d'une caractéristique tirée au hasard. L'équilibre du cycle
# (Prêtre) : l'allié choisi ET un ennemi mort au hasard reviennent à la
# moitié de leurs PV max (valeur non précisée dans les données d'origine).
func _resolve_resurrection(caster: CombatUnit, spell: Spell) -> void:
	var corpse = _pending_resurrection
	_pending_resurrection = null
	if corpse == null or not _graveyard.has(corpse):
		return

	if spell.is_walkyrie_resurrection:
		# Le ressuscité revient à 15 PV ; c'est la WALKYRIE qui paie : -15 PV
		# max et -1 point d'une caractéristique tirée au hasard.
		if _revive_unit(corpse, caster, 15, false):
			caster.base_max_hp = max(1, caster.base_max_hp - 15)
			var stats := ["base_courage", "base_intelligence_stat", "base_charisme_stat", "base_adresse_stat", "base_force_stat", "base_chance_stat", "base_attack_stat", "base_parade_stat"]
			var picked: String = stats[randi() % stats.size()]
			caster.set(picked, max(1, int(caster.get(picked)) - 1))
			caster._recalculate_stats()
			caster.current_hp = min(caster.current_hp, caster.max_hp)
			spawn_floating_text(caster.position, "-15 PV max, -1 %s" % picked.trim_prefix("base_").trim_suffix("_stat"), Color(0.85, 0.5, 0.3))
		return

	_revive_unit(corpse, caster, 0, false)
	var dead_enemies: Array = _graveyard.filter(func(u): return is_instance_valid(u) and u.team != caster.team)
	if not dead_enemies.is_empty():
		_revive_unit(dead_enemies[randi() % dead_enemies.size()], caster, 0, false)

# Remet `corpse` en jeu sur la case libre la plus proche de `near`. `hp` = 0
# -> moitié des PV max. `penalties` : -15 PV max de base et -1 sur une
# caractéristique au hasard (Grâce du ciel).
func _revive_unit(corpse: CombatUnit, near: CombatUnit, hp: int, penalties: bool) -> bool:
	var best_cell = null
	var best_dist := 9999
	for coord in _cells:
		if not _cells[coord]["is_walkable"] or is_occupied(coord):
			continue
		var d := hex_distance(coord, near.hex_coord)
		if d < best_dist:
			best_dist = d
			best_cell = coord
	if best_cell == null:
		print("Plus de case libre pour ressusciter %s." % corpse.unit_name)
		return false

	if penalties:
		corpse.base_max_hp = max(1, corpse.base_max_hp - 15)
		var stats := ["base_courage", "base_intelligence_stat", "base_charisme_stat", "base_adresse_stat", "base_force_stat", "base_chance_stat", "base_attack_stat", "base_parade_stat"]
		var picked: String = stats[randi() % stats.size()]
		corpse.set(picked, max(1, int(corpse.get(picked)) - 1))

	corpse.active_effects.clear()
	corpse.stunned_turns_remaining = 0
	corpse.redirect_source = null
	corpse.redirect_charges = 0
	corpse.parallel_partner = null
	corpse.parallel_turns_remaining = 0
	corpse.pending_spell = null
	corpse.keep_corpse = false

	corpse.hex_coord = best_cell
	corpse.position = axial_to_pixel(best_cell)
	corpse.visible = true
	corpse.modulate = Color(1, 1, 1, 1)
	if corpse.get_parent() == null:
		add_child(corpse)
	_cells[best_cell]["occupant"] = corpse
	if not _all_units.has(corpse):
		_all_units.append(corpse)
	if not corpse.died.is_connected(_on_unit_died):
		corpse.died.connect(_on_unit_died)
	_graveyard.erase(corpse)

	corpse._recalculate_stats()
	var new_hp: int = hp if hp > 0 else int(ceil(corpse.max_hp / 2.0))
	corpse.current_hp = clamp(new_hp, 1, corpse.max_hp)
	corpse.play_animation("idle")

	if _turn_manager != null:
		_turn_manager.add_unit_to_turn_order(corpse, active_unit if active_unit != null else near)
	spawn_floating_text(corpse.position, "Ressuscité !", Color(0.95, 0.9, 0.5))
	print("%s est ressuscité (%d PV)." % [corpse.unit_name, corpse.current_hp])
	_refresh_tanker_auras()
	queue_redraw()
	return true

# Un pour tous (Gladiateur) : -3 AT pour le gladiateur tant que la protection
# dure ; les 3 prochains dégâts de l'allié sont encaissés par le gladiateur
# (voir CombatUnit.take_damage / _redirect_damage).
func _resolve_un_pour_tous(caster: CombatUnit, ally: CombatUnit) -> void:
	var malus := StatusEffect.new()
	malus.effect_name = "Un pour tous (-3 Attaque)"
	malus.duration_remaining = -1
	malus.bonus_attaque = -3
	caster.add_status_effect(malus)
	ally.redirect_source = caster
	ally.redirect_charges = 3
	ally.redirect_effect = malus
	spawn_floating_text(ally.position, "Protégé (3)", Color(0.85, 0.75, 0.3))
	spawn_floating_text(caster.position, "-3 AT", Color(0.85, 0.5, 0.3))
	print("%s protège %s : les 3 prochains dégâts iront au gladiateur." % [caster.unit_name, ally.unit_name])

func _resolve_ninja_permutation(caster: CombatUnit, target: CombatUnit) -> void:
	var caster_coord = caster.hex_coord
	var target_coord = target.hex_coord

	_cells[caster_coord]["occupant"] = target
	_cells[target_coord]["occupant"] = caster

	caster.hex_coord = target_coord
	target.hex_coord = caster_coord
	caster.move_to_pixel(axial_to_pixel(target_coord))
	target.move_to_pixel(axial_to_pixel(caster_coord))

	caster.ninja_permutations_used += 1
	spawn_floating_text(caster.position, "Permutation !", Color(0.5, 0.4, 0.75))
	print("%s permute avec %s." % [caster.unit_name, target.unit_name])

func _resolve_meca_doc_heal(caster: CombatUnit, target: CombatUnit, tier: int) -> void:
	var healed_hp = 0
	var healed_ea = 0
	match tier:
		0:
			healed_hp = randi_range(1, 6)
		1:
			healed_hp = randi_range(1, 6) + 3
		2:
			healed_hp = 10
			healed_ea = 3

	var actual_hp = min(healed_hp, target.max_hp - target.current_hp)
	target.current_hp += actual_hp
	if actual_hp > 0:
		spawn_floating_text(target.position, "+%d" % actual_hp, Color(0.35, 0.9, 0.5))

	if healed_ea > 0:
		var actual_ea = min(healed_ea, target.max_ea - target.current_ea)
		target.current_ea += actual_ea
		if actual_ea > 0:
			spawn_floating_text(target.position + Vector2(0, -18), "+%d EA" % actual_ea, Color(0.55, 0.75, 0.95))

	print("%s soigne %s (%d PV, %d EA)." % [caster.unit_name, target.unit_name, healed_hp, healed_ea])

# Support (Méca) : +AT (choix AT/PRD non modélisé, toujours AT par
# simplicité — voir Spell.is_meca_support_buff) pendant 1 tour, +FO en
# plus au palier 2.
func _resolve_meca_support_buff(caster: CombatUnit, target: CombatUnit, tier: int) -> void:
	var amount = [1, 2, 2][tier]

	# Au choix du joueur à chaque tour du Méca (boutons Attaque/Parade).
	var stat_label := "Parade" if caster.meca_support_choice == "parade" else "Attaque"
	var buff := StatusEffect.new()
	buff.effect_name = "Soutien du Méca (+%d %s)" % [amount, stat_label]
	buff.duration_remaining = 1
	if caster.meca_support_choice == "parade":
		buff.bonus_parade = amount
	else:
		buff.bonus_attaque = amount
	if tier == 2:
		buff.bonus_force = 1
		buff.effect_name = "Soutien du Méca (+%d %s, +1 Force)" % [amount, stat_label]
	target.add_status_effect(buff)
	spawn_floating_text(target.position, buff.effect_name, Color(0.6, 0.9, 0.6))
	print("%s soutient %s." % [caster.unit_name, target.unit_name])

# Fait apparaître une invocation sur la case cliquée, dans l'équipe du
# lanceur, et l'insère dans l'ordre du tour juste après lui pour
# qu'elle entre en jeu rapidement.
func _cast_summon_spell(caster: CombatUnit, spell: Spell, coord: Vector2i) -> void:
	# Limite de 2 Mécas par combat (toutes branches confondues — voir
	# le métier Ingénieur Automate). Vérifiée avant toute consommation
	# d'action/EA : un clic refusé ne doit rien coûter.
	if spell.is_meca_summon and caster.mecas_summoned_this_combat >= 2:
		print("%s a déjà invoqué 2 Mécas ce combat (maximum)." % caster.unit_name)
		cancel_targeting_mode()
		return

	var is_delayed_resolution = caster.pending_spell == spell

	if not is_delayed_resolution:
		caster.record_action_taken(spell)
		var ea_cost = spell.get_effective_ea_cost(caster)
		caster.current_ea -= ea_cost
		if ea_cost > 0:
			spawn_floating_text(caster.position, "-%d %s" % [ea_cost, caster.get_resource_name()], Color(0.65, 0.45, 0.95))

	# Porte étendard (Soldat) : ne pose PAS de vraie unité — juste un
	# test Cou/Cha, puis le buff direct aux alliés adjacents à la case
	# cliquée (voir _resolve_porte_etendard).
	if spell.is_soldat_porte_etendard:
		_resolve_porte_etendard(caster, spell, coord)
		if is_delayed_resolution:
			caster.clear_channeling()
		cancel_targeting_mode()
		if _turn_manager != null:
			if is_delayed_resolution:
				_turn_manager.finish_delayed_cast_turn()
			else:
				_turn_manager.refresh_ui()
		return

	var summon = build_summon_unit(spell, caster.team, caster)
	summon.is_summoned = true
	place_unit_at(summon, coord)

	if spell.is_meca_summon:
		caster.mecas_summoned_this_combat += 1
		_attach_meca_ability(caster, summon, spell)

	if _turn_manager != null:
		_turn_manager.add_unit_to_turn_order(summon, caster)

	spawn_floating_text(summon.position, "Invocation !", Color(0.6, 0.9, 1.0))
	print("%s invoque %s !" % [caster.unit_name, summon.unit_name])

	if is_delayed_resolution:
		caster.clear_channeling()

	cancel_targeting_mode()

	if _turn_manager != null:
		if is_delayed_resolution:
			_turn_manager.finish_delayed_cast_turn()
		else:
			_turn_manager.refresh_ui()

	queue_redraw()

# Crée un mur de 3 cases infranchissables (voir Spell.creates_obstacle_line)
# depuis le lanceur, en ligne droite à travers la case cliquée et
# au-delà — réutilise hex_line() (déjà utilisé pour la ligne de vue)
# plutôt que de recalculer une direction hexagonale à la main.
func _handle_terrain_selection_click(coord: Vector2i) -> void:
	if not _is_valid_terrain_cell(coord, _casting_spell):
		return

	if _terrain_selection_cells.has(coord):
		_terrain_selection_cells.erase(coord)  # Re-clic sur une case déjà choisie : la désélectionne.
	elif _terrain_selection_cells.size() < _casting_spell.max_terrain_cells:
		_terrain_selection_cells.append(coord)
	# Déjà au maximum et case pas encore choisie : clic ignoré (il faut
	# d'abord en désélectionner une).

	if _turn_manager != null:
		_turn_manager.update_terrain_selection_ui(_terrain_selection_cells.size(), _casting_spell.max_terrain_cells)

	queue_redraw()

# Une case est valide pour un sort de terrain donné si : c'est un mur
# à poser (vide, franchissable, inoccupée), un pont à construire
# (obstacle VIDE précisément), ou un obstacle à retirer (du bon type).
func _is_valid_terrain_cell(coord: Vector2i, spell: Spell) -> bool:
	if not _cells.has(coord):
		return false

	if spell.creates_obstacle_line:
		return _cells[coord]["is_walkable"] and not is_occupied(coord)

	if spell.creates_bridge_line:
		return _cells[coord].get("obstacle_type", ObstacleType.BASIC) == ObstacleType.VIDE

	if spell.removes_obstacle_type >= 0:
		return not _cells[coord]["is_walkable"] and _cells[coord].get("obstacle_type", ObstacleType.BASIC) == spell.removes_obstacle_type

	return false

# Appelée par le bouton "Valider" (voir TurnManager) une fois que le
# joueur a choisi ses cases — applique l'effet à toutes les cases
# sélectionnées d'un coup, puis consomme l'EA/l'action UNE SEULE FOIS
# (pas par case).
func confirm_terrain_selection() -> void:
	if _terrain_selection_cells.is_empty() or _casting_spell == null or active_unit == null:
		return

	var caster = active_unit
	var spell = _casting_spell
	var is_delayed_resolution = caster.pending_spell == spell

	if not is_delayed_resolution:
		caster.record_action_taken(spell)
		var ea_cost = spell.get_effective_ea_cost(active_unit)
		caster.current_ea -= ea_cost
		if ea_cost > 0:
			spawn_floating_text(caster.position, "-%d %s" % [ea_cost, caster.get_resource_name()], Color(0.65, 0.45, 0.95))

	var affected = 0
	for c in _terrain_selection_cells:
		if spell.creates_obstacle_line:
			if _cells.has(c) and not is_occupied(c):
				_cells[c]["is_walkable"] = false
				_cells[c]["obstacle_type"] = ObstacleType.EAU  # Mur D'EAU — peut être retiré par Évaporation d'eau/Gel de l'eau.
				affected += 1
		elif spell.creates_bridge_line:
			if _cells.has(c) and _cells[c].get("obstacle_type", ObstacleType.BASIC) == ObstacleType.VIDE:
				_cells[c]["is_walkable"] = true
				affected += 1
		elif spell.removes_obstacle_type >= 0:
			if _cells.has(c) and _cells[c].get("obstacle_type", ObstacleType.BASIC) == spell.removes_obstacle_type:
				_cells[c]["is_walkable"] = true
				_cells[c]["obstacle_type"] = ObstacleType.BASIC
				affected += 1

	spawn_floating_text(caster.position, "%d case(s) affectée(s)" % affected, Color(0.5, 0.8, 0.95))
	print("%s valide %s sur %s." % [caster.unit_name, spell.spell_name, str(_terrain_selection_cells)])

	if is_delayed_resolution:
		caster.clear_channeling()

	cancel_targeting_mode()

	if _turn_manager != null:
		if is_delayed_resolution:
			_turn_manager.finish_delayed_cast_turn()
		else:
			_turn_manager.refresh_ui()

	queue_redraw()

# `targets` : toutes les unités affectées par ce lancer (1 pour un
# ciblage simple, plusieurs pour Zone/Groupe — voir Spell.TargetMode).
func _cast_spell(caster: CombatUnit, spell: Spell, targets: Array) -> void:
	# Résurrection : le défunt doit avoir été choisi et être toujours au cimetière.
	if spell.is_walkyrie_resurrection or spell.is_pretre_resurrection:
		if _pending_resurrection == null or not _graveyard.has(_pending_resurrection):
			_pending_resurrection = null
			cancel_targeting_mode()
			return

	# PI d'ogre : 3 PI au maximum par combat.
	if spell.is_ogre_pi and caster.ogre_pi_converted + spell.ogre_pi_x > 3:
		print("%s ne peut plus convertir autant de PI (3 maximum)." % caster.unit_name)
		cancel_targeting_mode()
		return

	# Un pour tous : il faut un allié autre que soi, pas déjà protégé.
	if spell.is_un_pour_tous:
		if targets.is_empty() or targets[0] == caster or targets[0].redirect_charges > 0:
			print("%s : Un pour tous impossible sur cette cible." % caster.unit_name)
			cancel_targeting_mode()
			return

	# Disque de lumière : seuls les ennemis tournés vers le lanceur.
	if spell.requires_facing_caster and not targets.is_empty():
		targets = targets.filter(func(t): return t.is_facing(caster.position))
		if targets.is_empty():
			spawn_floating_text(caster.position, "Personne ne regarde le lanceur", Color(0.65, 0.65, 0.65))
			cancel_targeting_mode()
			return

	# Plan parallèle : on ne peut agir que sur les unités du même plan.
	if not targets.is_empty() and not spell.is_parallel_plane:
		targets = targets.filter(func(t): return can_interact(caster, t))
		if targets.is_empty():
			print("%s ne peut atteindre personne (plan parallèle)." % caster.unit_name)
			cancel_targeting_mode()
			return
	# Ressources dédiées (Bravoure/Précision des hobbits) : vérifiées
	# AVANT toute consommation d'action/EA — un clic sur un bouton à
	# 0 utilisation restante ne doit rien coûter.
	if spell.is_hobbit_bravoure and caster.hobbit_bravoure_uses <= 0:
		print("%s n'a plus d'utilisation de Bravoure des hobbits ce combat." % caster.unit_name)
		cancel_targeting_mode()
		return
	if spell.is_detect_skill and caster.detect_uses <= 0:
		print("%s n'a plus de charge de Détecter ce combat." % caster.unit_name)
		cancel_targeting_mode()
		return
	if spell.is_hobbit_precision and caster.hobbit_stones <= 0:
		print("%s n'a plus de caillou à lancer." % caster.unit_name)
		cancel_targeting_mode()
		return
	if spell.is_ninja_permutation and caster.ninja_permutations_used >= 3:
		print("%s a déjà utilisé Permutation 3 fois ce combat (maximum)." % caster.unit_name)
		cancel_targeting_mode()
		return
	if spell.is_peintre_peinture_de_guerre and caster.peintre_peinture_de_guerre_used:
		print("%s a déjà utilisé Peinture de guerre ce combat (maximum 1 fois)." % caster.unit_name)
		cancel_targeting_mode()
		return
	if spell.is_peintre_maquillage and caster.peintre_maquillage_used >= 3:
		print("%s a déjà utilisé Maquillage 3 fois ce combat (maximum)." % caster.unit_name)
		cancel_targeting_mode()
		return
	if spell.is_corsaire_salve and caster.corsaire_salve_used:
		print("%s a déjà utilisé Salve ce combat (maximum 1 fois)." % caster.unit_name)
		cancel_targeting_mode()
		return

	# Tranquillo/Meno/Slancio (Barde) : coût calculé dynamiquement (pas
	# un ea_cost fixe) — vérifié ici, AVANT toute consommation, plutôt
	# que dans enter_targeting_mode (ces sorts n'ont pas de ciblage par
	# clic, ils résolvent directement en ALL_ENEMIES/SELF).
	if spell.is_barde_tranquillo:
		var tranquillo_cost = 2 + _get_opposing_team(caster).size()
		if caster.current_ea < tranquillo_cost:
			print("%s n'a pas assez d'EA pour Tranquillo (%d requis)." % [caster.unit_name, tranquillo_cost])
			cancel_targeting_mode()
			return
	if spell.is_barde_meno or spell.is_barde_slancio:
		var cha_duration = max(1, caster.charisme_stat - 12)
		var cha_cost = spell.barde_cost_multiplier * cha_duration
		if caster.current_ea < cha_cost:
			print("%s n'a pas assez d'EA pour %s (%d requis)." % [caster.unit_name, spell.spell_name, cha_cost])
			cancel_targeting_mode()
			return

	# Frappe puissante/Tourbillon (Berzerk) : coût fixe en Rage (pas en
	# EA) — vérifié et déduit ICI, avant toute résolution.
	if (spell.is_berzerk_frappe_puissante or spell.is_berzerk_tourbillon) and caster.rage < spell.rage_cost:
		print("%s n'a pas assez de Rage pour %s (%d requise)." % [caster.unit_name, spell.spell_name, spell.rage_cost])
		cancel_targeting_mode()
		return
	if spell.is_berzerk_grr and caster.grr_used_this_combat:
		print("%s a déjà utilisé GRRRBL ce combat (maximum 1 fois)." % caster.unit_name)
		cancel_targeting_mode()
		return
	if spell.is_berzerk_raaah and caster.raaah_used_this_combat:
		print("%s a déjà utilisé Raaah ce combat (maximum 1 fois)." % caster.unit_name)
		cancel_targeting_mode()
		return

	# Peinture de guerre : consommée ICI (avant la résolution générique
	# GROUP + effect_to_apply + SpellType.COURAGE, voir plus bas) — une
	# seule tentative par combat, que le test Courage réussisse ou non
	# (voir Spell.is_peintre_peinture_de_guerre).
	if spell.is_peintre_peinture_de_guerre:
		caster.peintre_peinture_de_guerre_used = true

	# Salve : consommée ICI, avant la résolution générique (dégâts).
	if spell.is_corsaire_salve:
		caster.corsaire_salve_used = true

	# Résolution différée : ce sort a déjà été payé/lancé (canalisation
	# en cours), on ne fait ici que choisir sa cible finale — pas de
	# nouveau coût, pas de nouvelle consommation d'action.
	var is_delayed_resolution = caster.pending_spell == spell

	if not is_delayed_resolution:
		caster.record_action_taken(spell)

		if spell.gloire_cost > 0:
			caster.gloire -= spell.gloire_cost
			spawn_floating_text(caster.position, "-%d Gloire" % spell.gloire_cost, Color(0.75, 0.6, 0.15))
		elif spell.is_initial_cost:
			_deduct_initial_cost(caster, spell)
		else:
			var ea_cost = spell.get_effective_ea_cost(caster)
			caster.current_ea -= ea_cost

			# L'attaque d'arme est gratuite (0 EA) : pas la peine d'afficher "-0 EA".
			if ea_cost > 0:
				spawn_floating_text(caster.position, "-%d %s" % [ea_cost, caster.get_resource_name()], Color(0.65, 0.45, 0.95))

	# Capacités actives propres à une race (voir Race.grants_hobbit_*/
	# grants_samurai_*) — résolution sur-mesure, indépendante du reste
	# de cette fonction (dice_terms, effets à durée génériques...).
	# Détecter (DET) : une charge est consommée, puis test d'Intelligence+2
	# (réussi si le d20 est SOUS INT+2, comme les autres tests) ; en cas de
	# réussite on continue vers la résolution normale (révélation du rayon).
	if spell.is_detect_skill:
		caster.detect_uses -= 1
		var detect_roll: int = randi_range(1, 20)
		var detect_threshold: int = caster.intelligence_stat + 2 + get_skill_test_bonus(caster)
		if detect_roll >= detect_threshold:
			spawn_floating_text(caster.position, "Détection ratée", Color(0.65, 0.65, 0.65))
			print("%s rate son test de Détecter (jet %d, seuil %d)." % [caster.unit_name, detect_roll, detect_threshold])
			cancel_targeting_mode()
			if _turn_manager != null:
				_turn_manager.refresh_ui()
			return
		print("%s réussit son test de Détecter (jet %d, seuil %d), %d charge(s) restante(s)." % [caster.unit_name, detect_roll, detect_threshold, caster.detect_uses])

	if spell.is_hobbit_bravoure:
		_resolve_hobbit_bravoure(caster, spell.bravoure_x)
		cancel_targeting_mode()
		if _turn_manager != null:
			_turn_manager.refresh_ui()
		return

	if spell.is_hobbit_precision:
		_resolve_hobbit_precision(caster, targets[0])
		cancel_targeting_mode()
		if _turn_manager != null:
			_turn_manager.refresh_ui()
		return

	if spell.is_samurai_concentration:
		_resolve_samurai_concentration(caster)
		cancel_targeting_mode()
		if _turn_manager != null:
			_turn_manager.refresh_ui()
		return

	if spell.is_meca_doc_heal:
		_resolve_meca_doc_heal(caster, targets[0], spell.meca_tier)
		cancel_targeting_mode()
		if _turn_manager != null:
			_turn_manager.refresh_ui()
		return

	if spell.is_walkyrie_resurrection or spell.is_pretre_resurrection:
		_resolve_resurrection(caster, spell)
		cancel_targeting_mode()
		if _turn_manager != null:
			_turn_manager.refresh_ui()
		return

	if spell.is_ogre_pi:
		caster.ogre_pi_converted += spell.ogre_pi_x
		caster.pi += spell.ogre_pi_x
		var ogre_malus := StatusEffect.new()
		ogre_malus.effect_name = "PI d'ogre (-%d AT/PRD)" % spell.ogre_pi_x
		ogre_malus.duration_remaining = -1
		ogre_malus.bonus_attaque = -spell.ogre_pi_x
		ogre_malus.bonus_parade = -spell.ogre_pi_x
		caster.add_status_effect(ogre_malus)
		spawn_floating_text(caster.position, "+%d PI" % spell.ogre_pi_x, Color(0.9, 0.55, 0.2))
		cancel_targeting_mode()
		if _turn_manager != null:
			_turn_manager.refresh_ui()
		return

	if spell.is_un_pour_tous:
		_resolve_un_pour_tous(caster, targets[0])
		cancel_targeting_mode()
		if _turn_manager != null:
			_turn_manager.refresh_ui()
		return

	if spell.is_parallel_plane:
		var plane_avg: float = (caster.intelligence_stat + caster.charisme_stat) / 2.0
		var plane_roll: int = randi_range(1, 20)
		if plane_roll < plane_avg and targets.size() == 2:
			_apply_parallel_plane(targets[0], targets[1], spell.parallel_plane_turns)
		else:
			spawn_floating_text(caster.position, "Plan parallèle raté", Color(0.65, 0.65, 0.65))
			print("%s rate Plan parallèle (jet %d >= %.1f)." % [caster.unit_name, plane_roll, plane_avg])
			_refund_failed_cast(caster, spell.get_effective_ea_cost(caster))
		cancel_targeting_mode()
		if _turn_manager != null:
			_turn_manager.refresh_ui()
		return

	if spell.is_ninja_permutation:
		_resolve_ninja_permutation(caster, targets[0])
		cancel_targeting_mode()
		if _turn_manager != null:
			_turn_manager.refresh_ui()
		return

	if spell.is_peintre_maquillage:
		_resolve_peintre_maquillage(caster, spell)
		cancel_targeting_mode()
		if _turn_manager != null:
			_turn_manager.refresh_ui()
		return

	if spell.is_peintre_peinture_de_guerre:
		_resolve_peinture_de_guerre(caster, spell)
		cancel_targeting_mode()
		if _turn_manager != null:
			_turn_manager.refresh_ui()
		return

	if spell.is_barde_tranquillo:
		_resolve_barde_tranquillo(caster)
		cancel_targeting_mode()
		if _turn_manager != null:
			_turn_manager.refresh_ui()
		return

	if spell.is_barde_meno:
		_resolve_barde_meno(caster)
		cancel_targeting_mode()
		if _turn_manager != null:
			_turn_manager.refresh_ui()
		return

	if spell.is_barde_slancio:
		_resolve_barde_slancio(caster, targets[0])
		cancel_targeting_mode()
		if _turn_manager != null:
			_turn_manager.refresh_ui()
		return

	if spell.is_berzerk_frappe_puissante:
		caster.rage -= spell.rage_cost
		spawn_floating_text(caster.position, "-%d Rage" % spell.rage_cost, Color(0.8, 0.2, 0.15))
		var buff := StatusEffect.new()
		buff.effect_name = "Frappe puissante (+2 dégâts)"
		buff.duration_remaining = -1  # Retiré par la prochaine attaque elle-même, pas par le temps.
		buff.grants_next_attack_flat_bonus = 2
		caster.add_status_effect(buff)
		spawn_floating_text(caster.position, "Frappe puissante !", Color(0.85, 0.3, 0.2))
		cancel_targeting_mode()
		if _turn_manager != null:
			_turn_manager.refresh_ui()
		return

	if spell.is_berzerk_tourbillon:
		caster.rage -= spell.rage_cost
		spawn_floating_text(caster.position, "-%d Rage" % spell.rage_cost, Color(0.8, 0.2, 0.15))
		_resolve_berzerk_tourbillon(caster)
		cancel_targeting_mode()
		if _turn_manager != null:
			_turn_manager.refresh_ui()
		return

	if spell.is_meca_support_buff:
		_resolve_meca_support_buff(caster, targets[0], spell.meca_tier)
		cancel_targeting_mode()
		if _turn_manager != null:
			_turn_manager.refresh_ui()
		return

	if spell.resets_all_hp:
		_resolve_equilibre_parfait(caster)
		cancel_targeting_mode()
		if _turn_manager != null:
			_turn_manager.refresh_ui()
		return

	if spell.alternates_heal_damage:
		_resolve_balance_univers(caster, spell)
		cancel_targeting_mode()
		if _turn_manager != null:
			_turn_manager.refresh_ui()
		return

	if spell.is_ev_cost_spell or spell.is_pa_cost_spell or spell.is_rage_cost_spell:
		_resolve_ev_cost_spell(caster, spell, targets, _pending_ev_x)
		cancel_targeting_mode()
		if _turn_manager != null:
			_turn_manager.refresh_ui()
		return

	# Sort importé sans mécanique automatisée (voir mage_spell_catalog.gd) :
	# coûte bien l'EA/l'action, mais n'a aucun effet — juste son texte
	# d'origine affiché, en attendant du code sur-mesure pour ce sort précis.
	if spell.is_unimplemented:
		print("%s lance %s : %s (PAS ENCORE IMPLÉMENTÉ)" % [caster.unit_name, spell.spell_name, spell.info_text])
		if not targets.is_empty():
			spawn_floating_text(targets[0].position, spell.info_text, Color(0.6, 0.6, 0.6))
		else:
			spawn_floating_text(caster.position, spell.info_text, Color(0.6, 0.6, 0.6))
		if is_delayed_resolution:
			caster.clear_channeling()
		cancel_targeting_mode()
		if _turn_manager != null:
			if is_delayed_resolution:
				_turn_manager.finish_delayed_cast_turn()
			else:
				_turn_manager.refresh_ui()
		queue_redraw()
		return

	# DI (délai d'incantation) : au premier lancer (targets vide), le
	# sort ne se résout pas tout de suite — le lanceur commence à
	# canaliser, la cible sera choisie au tour où ça se termine (voir
	# TurnManager._start_current_turn -> begin_delayed_targeting). Une
	# fois cette cible choisie, is_delayed_resolution est vrai : on
	# saute directement à la résolution normale ci-dessous.
	if spell.cast_delay > 0 and not is_delayed_resolution:
		caster.start_channeling(spell)
		spawn_floating_text(caster.position, "Incantation... (%d)" % spell.cast_delay, Color(0.7, 0.5, 0.95))
		print("%s commence à canaliser %s (%d tour(s))." % [caster.unit_name, spell.spell_name, spell.cast_delay])
	elif spell.is_weapon_attack:
		# Une attaque d'arme reste toujours un ciblage simple (1 cible) —
		# le catalogue de sorts d'armes ne connaît pas Zone/Groupe.
		_resolve_weapon_attack(caster, spell, targets[0])
	else:
		_resolve_spell_effect(caster, spell, targets)

	if is_delayed_resolution:
		caster.clear_channeling()

	cancel_targeting_mode()

	if _turn_manager != null:
		if is_delayed_resolution:
			_turn_manager.finish_delayed_cast_turn()
		else:
			_turn_manager.refresh_ui()

	queue_redraw()

# Appelée par TurnManager quand le compte à rebours de canalisation
# d'une unité atteint 0 (voir CombatUnit.pending_spell). Filtre les
# cibles encore valides (une cible SINGLE_ENEMY/SINGLE_ALLY a pu mourir
# entre-temps) avant de résoudre l'effet.
# Résout automatiquement un sort à canalisation dont la cible ne
# nécessite AUCUN choix du joueur (SELF/GROUP/BATTLEFIELD) — recalculée
# à la volée (et pas stockée au lancer) pour refléter l'état actuel
# (ex: un allié du groupe mort entre-temps n'est plus inclus). Pour
# tout le reste (cible unique, zone, invocation, terrain), voir
# begin_delayed_targeting à la place : ça, le joueur choisit lui-même.
func resolve_pending_spell(caster: CombatUnit) -> void:
	var spell = caster.pending_spell
	var targets: Array = []

	match spell.target_mode:
		Spell.TargetMode.SELF:
			targets = [caster]
		Spell.TargetMode.GROUP:
			targets = _get_team_including_self(caster)
		Spell.TargetMode.BATTLEFIELD:
			targets = _get_battlefield_targets(caster, spell)

	caster.clear_channeling()

	if spell == null or targets.is_empty():
		print("%s : la canalisation se dissipe (plus aucune cible valide)." % caster.unit_name)
		return

	print("%s termine sa canalisation : %s se déclenche !" % [caster.unit_name, spell.spell_name])
	_resolve_spell_effect(caster, spell, targets)
	queue_redraw()

# ---------- Résolution des attaques : toucher, parade, esquive ----------

# Une attaque d'arme (mêlée ou à distance) doit d'abord réussir son jet
# de toucher, puis peut être parée (mêlée uniquement) ou esquivée par
# le défenseur selon sa posture défensive.
# Bravoure des hobbits : jet de Courage avec un malus -X (X choisi via
# le bouton cliqué) ; en cas de réussite, +X Force permanent pour le
# reste du combat (StatusEffect, comme n'importe quel autre buff).
# Consomme 1 des 3 utilisations, que le jet réussisse ou non.
func _resolve_hobbit_bravoure(caster: CombatUnit, x: int) -> void:
	caster.hobbit_bravoure_uses -= 1

	var roll = randi_range(1, 20)
	if roll < caster.courage - x:
		var buff := StatusEffect.new()
		buff.effect_name = "Bravoure des hobbits (+%d Force)" % x
		buff.duration_remaining = -1  # Permanent pour le reste du combat.
		buff.bonus_force = x
		caster.add_status_effect(buff)
		spawn_floating_text(caster.position, "+%d Force !" % x, Color(0.9, 0.7, 0.3))
		print("%s réussit son test de Courage-%d (jet %d) : +%d Force." % [caster.unit_name, x, roll, x])
	else:
		spawn_floating_text(caster.position, "Test raté", Color(0.65, 0.65, 0.65))
		print("%s rate son test de Courage-%d (jet %d)." % [caster.unit_name, x, roll])

# Précision des hobbits : jet d'Adresse-3 pour toucher, dégâts
# 1D6 + Courage/2 (arrondi au dessous) en cas de réussite, réduits par
# l'armure du défenseur comme un tir classique. Consomme 1 des 6
# cailloux, que le jet réussisse ou non.
func _resolve_hobbit_precision(caster: CombatUnit, target: CombatUnit) -> void:
	caster.hobbit_stones -= 1
	caster.face_direction(target.position)
	caster.play_animation("ranged_attack")

	var hit_roll = randi_range(1, 20)
	if hit_roll >= caster.adresse_stat - 3:
		spawn_floating_text(target.position, "Raté", Color(0.65, 0.65, 0.65))
		print("%s rate son caillou sur %s (jet %d, Adresse-3 %d)." % [caster.unit_name, target.unit_name, hit_roll, caster.adresse_stat - 3])
		return

	if _try_dodge(target, caster, hit_roll == 1):
		return

	var damage = randi_range(1, 6) + int(caster.courage / 2.0)
	if hit_roll == 1:  # Critique.
		damage *= 2
		spawn_floating_text(target.position, "Critique !", Color(1.0, 0.85, 0.2))
	damage = max(0, damage - target.armor_value)
	target.take_damage(damage, hit_roll == 1)
	spawn_floating_text(target.position, "-%d" % damage, Color(0.95, 0.3, 0.3))
	print("%s touche %s avec un caillou (%d dégâts)." % [caster.unit_name, target.unit_name, damage])

# Concentration (Samurai) : renonce à toute défense (Parade/Esquive)
# jusqu'à son prochain tour, en échange d'un bonus sur sa PROCHAINE
# attaque d'arme (dégâts doublés, ignore l'armure — voir
# StatusEffect.grants_next_attack_double_damage/ignores_armor,
# consommé dans _resolve_weapon_attack).
func _resolve_samurai_concentration(caster: CombatUnit) -> void:
	caster.samurai_combo_disabled_defense = true  # Réutilise le même mécanisme d'affichage/blocage que Combo.

	var buff := StatusEffect.new()
	buff.effect_name = "Concentration"
	buff.duration_remaining = -1  # Consommé par la prochaine attaque, pas par le temps.
	buff.grants_next_attack_double_damage = true
	buff.grants_next_attack_ignores_armor = true
	caster.add_status_effect(buff)

	spawn_floating_text(caster.position, "Concentration !", Color(0.9, 0.3, 0.3))
	print("%s se concentre : sans défense jusqu'à son prochain tour, prochaine attaque doublée et perçante." % caster.unit_name)

# Noirceur (Prêtre, Ordre du néant) : la nuit s'installe sur TOUT le
# champ de bataille pendant `duration` tours (décomptés une fois par
# ROUND complet — voir TurnManager._start_current_turn, qui décrémente
# seulement quand c'est de nouveau au tour du JOUEUR). Applique "Être
# nocturne" (+niveau/2 Armure) et "Maître de la nuit" (+15 PV, +2
# AT/PRD) à tout Prêtre de l'ORDRE DU NÉANT SPÉCIFIQUEMENT déjà sur le
# champ de bataille (les deux camps : rien dans les données d'origine
# ne réserve ce bonus au lanceur — mais les Prêtres Harmonie/Cycle
# éternel n'en profitent PAS) — retirés par leur nom exact dans
# _end_night, pas par expiration de durée individuelle
# (duration_remaining=-1 ici : c'est HexGrid qui gère la fin de la
# nuit, pas CombatUnit.process_status_effects_on_turn_start).
func _install_night(caster: CombatUnit, duration: int) -> void:
	is_night = true
	_night_turns_remaining = duration

	for unit in _all_units:
		if unit.equipped_metier != null and unit.equipped_metier.metier_name == "Prêtre" and unit.pretre_order == "Ordre du néant":
			var etre_nocturne := StatusEffect.new()
			etre_nocturne.effect_name = "Être nocturne (nuit)"
			etre_nocturne.duration_remaining = -1
			etre_nocturne.bonus_armure = int(unit.level / 2.0)
			unit.add_status_effect(etre_nocturne)

			# Maître de la nuit appartient au 2e alignement (« nuit ») :
			# seulement à partir du niveau où il se débloque.
			if unit.level >= PretreSpellCatalog.tier_unlock_level(1):
				var maitre_de_la_nuit := StatusEffect.new()
				maitre_de_la_nuit.effect_name = "Maître de la nuit (nuit)"
				maitre_de_la_nuit.duration_remaining = -1
				maitre_de_la_nuit.bonus_vie = 15
				maitre_de_la_nuit.bonus_attaque = 2
				maitre_de_la_nuit.bonus_parade = 2
				unit.add_status_effect(maitre_de_la_nuit)

	spawn_floating_text(caster.position, "La nuit tombe...", Color(0.35, 0.3, 0.55))
	print("%s installe la nuit sur le champ de bataille (%d tour(s))." % [caster.unit_name, duration])

# Fin de la nuit (voir _install_night) : retire les 2 bonus de TOUT
# Prêtre qui les porte, par leur nom exact (pas par expiration
# individuelle — ces effets ont duration_remaining=-1, gérés ici).
func _end_night() -> void:
	is_night = false
	_night_turns_remaining = 0
	for unit in _all_units:
		var before = unit.active_effects.size()
		unit.active_effects = unit.active_effects.filter(func(e): return e.effect_name != "Être nocturne (nuit)" and e.effect_name != "Maître de la nuit (nuit)")
		if unit.active_effects.size() != before:
			unit._recalculate_stats()
	print("La nuit se termine sur le champ de bataille.")

# Appelée par TurnManager à chaque fois que c'est RÉ-au tour du joueur
# (un "round" complet, voir _start_current_turn) — décompte la nuit en
# cours d'un cran, la termine si elle arrive à 0. Ne fait rien si la
# nuit n'est pas active.
func tick_night_if_active() -> void:
	if not is_night:
		return
	_night_turns_remaining -= 1
	if _night_turns_remaining <= 0:
		_end_night()

# Équilibre parfait (Prêtre) : les PV de TOUTES les unités vivantes
# des deux camps sont réinitialisés à 1D100 — plafonné au max_hp de
# chacune (la donnée d'origine ne précise pas de plafond, mais
# dépasser le max semblait plus déroutant qu'utile).
func _resolve_equilibre_parfait(caster: CombatUnit) -> void:
	for unit in _all_units:
		if unit.current_hp > 0:
			unit.current_hp = min(randi_range(1, 100), unit.max_hp)
			spawn_floating_text(unit.position, "%d PV" % unit.current_hp, Color(0.85, 0.75, 0.3))
	print("%s déclenche Équilibre parfait : PV de tout le monde réinitialisés." % caster.unit_name)

# Invoque la balance de l'univers (Prêtre) : soigne tout le camp du
# lanceur et inflige les mêmes dégâts (3D, voir dice_terms) à tout le
# camp adverse — voir Spell.alternates_heal_damage pour la
# simplification par rapport à la vraie alternance d'origine.
func _resolve_balance_univers(caster: CombatUnit, spell: Spell) -> void:
	var roll = 0
	for term in spell.dice_terms:
		roll += term.get("modifier", 0)
		for i in range(term.get("count", 0)):
			roll += randi_range(1, term.get("sides", 6))

	# Un lancer sur deux : soin au camp du lanceur, puis dégâts au camp adverse
	# (le premier lancer soigne).
	if not caster.balance_next_is_damage:
		for ally in _get_team_including_self(caster):
			var healed = min(roll, ally.max_hp - ally.current_hp)
			if healed > 0:
				ally.current_hp += healed
				spawn_floating_text(ally.position, "+%d" % healed, Color(0.35, 0.9, 0.5))
		print("%s invoque la balance de l'univers : soin (%d)." % [caster.unit_name, roll])
	else:
		for enemy in _get_opposing_team(caster):
			if not can_interact(caster, enemy):
				continue
			enemy.take_damage(roll)
			spawn_floating_text(enemy.position, "-%d" % roll, Color(0.95, 0.3, 0.3))
		print("%s invoque la balance de l'univers : dégâts (%d)." % [caster.unit_name, roll])
	caster.balance_next_is_damage = not caster.balance_next_is_damage

# Sorts à coût en PV (branche Walkyrie — voir Spell.is_ev_cost_spell) :
# `x` a été choisi par le joueur avant l'appel (voir
# confirm_ev_cost_spell). Le coût en PV est déduit directement sur
# current_hp (PAS via take_damage(), qui serait bloqué par une
# éventuelle invulnérabilité du lanceur — ce n'est pas un dégât reçu,
# c'est un coût payé). x/ev_x_divisor + ev_x_flat_bonus est calculé
# UNE FOIS et sert de valeur commune à toutes les cibles ; les
# dice_terms éventuels (1D10, 2D...) sont eux relancés PAR cible.
func _resolve_ev_cost_spell(caster: CombatUnit, spell: Spell, targets: Array, x: int) -> void:
	var total_cost = x + spell.ev_extra_flat_cost
	if spell.is_pa_cost_spell:
		caster.current_ea = max(0, caster.current_ea - total_cost)
		spawn_floating_text(caster.position, "-%d EA" % total_cost, Color(0.55, 0.35, 0.85))
		print("%s paie %d PA pour %s." % [caster.unit_name, total_cost, spell.spell_name])
	elif spell.is_rage_cost_spell:
		caster.rage = max(0, caster.rage - total_cost)
		spawn_floating_text(caster.position, "-%d Rage" % total_cost, Color(0.8, 0.2, 0.15))
		print("%s dépense %d Rage pour %s." % [caster.unit_name, total_cost, spell.spell_name])
	else:
		caster.current_hp = max(1, caster.current_hp - total_cost)
		spawn_floating_text(caster.position, "-%d PV" % total_cost, Color(0.75, 0.15, 0.15))
		print("%s paie %d PV pour %s." % [caster.unit_name, total_cost, spell.spell_name])

	var bonus_value = int(x / float(spell.ev_x_divisor)) * spell.ev_x_multiplier + spell.ev_x_flat_bonus
	if spell.includes_caster_level:
		bonus_value += caster.level

	# Raaah (Berzerk) : convertit X Rage (déjà déduite ci-dessus) en
	# +X/10 dégâts PERMANENTS, 1 fois par combat.
	if spell.is_berzerk_raaah:
		caster.raaah_used_this_combat = true
		var permanent_bonus = int(x / 10.0)
		caster.berzerk_permanent_damage_bonus += permanent_bonus
		spawn_floating_text(caster.position, "+%d dégâts permanents !" % permanent_bonus, Color(0.85, 0.2, 0.1))
		print("%s convertit %d Rage en +%d dégâts permanents (Raaah)." % [caster.unit_name, x, permanent_bonus])
		return

	# GRRRBL (Berzerk) : X Rage -> X/10 PI pour le reste du combat, sur test
	# de Courage (la Rage est dépensée dans tous les cas).
	if spell.is_berzerk_grr:
		caster.grr_used_this_combat = true
		var grr_roll = randi_range(1, 20)
		if grr_roll < caster.courage:
			var gained_pi = int(x / 10.0)
			caster.pi += gained_pi
			spawn_floating_text(caster.position, "+%d PI !" % gained_pi, Color(0.85, 0.2, 0.1))
			print("%s convertit %d Rage en +%d PI (GRRRBL)." % [caster.unit_name, x, gained_pi])
		else:
			spawn_floating_text(caster.position, "GRRRBL raté", Color(0.65, 0.65, 0.65))
			print("%s rate GRRRBL (jet %d >= Courage %d)." % [caster.unit_name, grr_roll, caster.courage])
		return

	# Noirceur (Prêtre) : installe la nuit sur TOUT le champ de bataille
	# pendant X tours (pas juste sur une cible) — voir _install_night.
	if spell.installs_night:
		_install_night(caster, max(1, x))
		return

	# Le mana devient de la vie (Prêtre) : X PA du LANCEUR deviennent
	# 3*X PV pour la cible (simplification : X est retiré au lanceur,
	# pas à la cible — la formule d'origine ne précise pas qui perd le
	# mana, cette lecture évite un second ciblage pour choisir qui paie).
	if spell.mana_to_life_ratio > 0:
		for target in targets:
			var amount = x * spell.mana_to_life_ratio
			var actual = min(amount, target.max_hp - target.current_hp)
			target.current_hp += actual
			spawn_floating_text(target.position, "+%d" % actual, Color(0.3, 0.9, 0.4))
			print("%s convertit %d PA en %d PV pour %s." % [caster.unit_name, x, actual, target.unit_name])
		return

	if spell.is_heal:
		# Pas de jet de toucher pour un soin (il ne peut pas être raté) —
		# on tire quand même un dé pour vérifier le critique (jet = 1),
		# UNE SEULE FOIS pour tout le lancer (même convention que les
		# sorts à dégâts).
		var heal_is_critical = randi_range(1, 20) == 1
		if heal_is_critical:
			spawn_floating_text(caster.position, "Critique !", Color(1.0, 0.85, 0.2))
		for target in targets:
			var dice_roll = 0
			for term in spell.dice_terms:
				dice_roll += term.get("modifier", 0)
				for i in range(term.get("count", 0)):
					dice_roll += randi_range(1, term.get("sides", 6))
			var amount = dice_roll + bonus_value
			if heal_is_critical:
				amount *= 2
			var actual = min(amount, target.max_hp - target.current_hp)
			target.current_hp += actual
			spawn_floating_text(target.position, "+%d" % actual, Color(0.3, 0.9, 0.4))
			print("%s soigne %s de %d PV." % [caster.unit_name, target.unit_name, actual])
		return

	if spell.grants_weapon_magic_attacks:
		for target in targets:
			target.magic_weapon_attacks_remaining += bonus_value
			spawn_floating_text(target.position, "Arme céleste (%d)" % bonus_value, Color(0.9, 0.85, 0.4))
			print("%s : arme magique pour %d attaques." % [target.unit_name, bonus_value])
		return

	if spell.grants_shield_turns:
		for target in targets:
			var shield := StatusEffect.new()
			shield.effect_name = "Bouclier de paix"
			shield.duration_remaining = max(1, bonus_value)
			shield.grants_invulnerable = true
			target.add_status_effect(shield)
			spawn_floating_text(target.position, "Bouclier (%d tours)" % bonus_value, Color(0.6, 0.85, 1.0))
		return

	if spell.grants_armor_buff:
		for target in targets:
			var buff := StatusEffect.new()
			buff.effect_name = "Protection divine (+%d Armure)" % bonus_value
			buff.duration_remaining = -1  # Permanent pour le reste du combat, comme les sorts du Mage sans DS précisée.
			buff.bonus_armure = bonus_value
			target.add_status_effect(buff)
			spawn_floating_text(target.position, "+%d Armure" % bonus_value, Color(0.8, 0.8, 0.5))
		return

	# Bouclier de Foi (Templier) : réserve de shield_power = bonus_value
	# (2×X — voir ev_x_multiplier), remplace toute réserve existante.
	if spell.grants_shield_power:
		for target in targets:
			target.shield_power = bonus_value
			spawn_floating_text(target.position, "Bouclier (%d)" % bonus_value, Color(0.95, 0.85, 0.4))
			print("%s invoque un Bouclier de Foi de %d points sur %s." % [caster.unit_name, bonus_value, target.unit_name])
		return

	# Effet à durée générique (ex: Être de lumière, "insensible à la
	# magie") — DS:X (duration_equals_x) fixe la durée à X (le PA
	# dépensé), voir "DS : X-1" -> ev_x_flat_bonus = -1 dans le catalogue.
	if spell.effect_to_apply != null:
		for target in targets:
			var effect_instance: StatusEffect = spell.effect_to_apply.duplicate()
			if spell.duration_equals_x:
				effect_instance.duration_remaining = max(1, bonus_value)
			target.add_status_effect(effect_instance)
			spawn_floating_text(target.position, effect_instance.effect_name, Color(0.7, 0.6, 0.95))
		return

	# Sinon : sort offensif. Un seul jet de toucher pour tout le lancer
	# (même convention que _resolve_spell_effect), puis dégâts + esquive
	# évalués indépendamment par cible.
	var avg_stat: float
	if spell.spell_type == Spell.SpellType.CHANCE:
		avg_stat = caster.chance_stat  # Pas de moyenne : la Chance seule.
	elif spell.spell_type == Spell.SpellType.COURAGE:
		avg_stat = caster.courage  # Pas de moyenne : le Courage seul.
	elif spell.spell_type == Spell.SpellType.INTELLIGENCE:
		avg_stat = caster.intelligence_stat  # Pas de moyenne : l'Intelligence seule.
	elif spell.spell_type == Spell.SpellType.COURAGE_CHARISME:
		avg_stat = (caster.courage + caster.charisme_stat) / 2.0
	elif spell.spell_type == Spell.SpellType.PSYCHIC:
		avg_stat = (caster.intelligence_stat + caster.charisme_stat) / 2.0
	else:
		avg_stat = (caster.intelligence_stat + caster.adresse_stat) / 2.0

	var hit_roll = randi_range(1, 20)
	if hit_roll >= avg_stat + spell.to_hit_modifier:
		var miss_pos = targets[0].position if not targets.is_empty() else caster.position
		spawn_floating_text(miss_pos, "Raté", Color(0.65, 0.65, 0.65))
		print("%s rate %s (jet %d >= %d)." % [caster.unit_name, spell.spell_name, hit_roll, int(avg_stat + spell.to_hit_modifier)])
		if spell.is_pa_cost_spell:
			_refund_failed_cast(caster, total_cost)  # Seul le coût payé en EA est partiellement rendu.
		return

	# Critique (jet = 1) : double les dégâts uniquement (voir plus bas).
	var is_critical = hit_roll == 1
	if is_critical:
		spawn_floating_text(caster.position, "Critique !", Color(1.0, 0.85, 0.2))

	if not targets.is_empty():
		_spawn_spell_effect(spell, targets[0].position)

	for target in targets:
		if not spell.unavoidable and _try_dodge(target, caster, is_critical):
			continue

		var dice_roll = 0
		for term in spell.dice_terms:
			dice_roll += term.get("modifier", 0)
			for i in range(term.get("count", 0)):
				dice_roll += randi_range(1, term.get("sides", 6))
		# Réalité distordue (Prestidigitateur) : immunité vérifiée PAR
		# CIBLE (un sort de zone peut toucher plusieurs cibles, dont
		# certaines immunisées et d'autres non).
		var target_crit = is_critical and not (target.equipped_metier != null and target.equipped_metier.grants_prestidigitateur_realite_distordue)

		var damage = dice_roll + bonus_value
		if target_crit:
			damage *= 2

		var relevant_armor = target.magic_armor_value if spell.spell_type == Spell.SpellType.PSYCHIC else target.armor_value
		damage = max(0, damage - relevant_armor)
		target.take_damage(damage, target_crit)
		spawn_floating_text(target.position, "-%d" % damage, Color(0.95, 0.3, 0.3))
		print("%s touche %s avec %s (%d dégâts)." % [caster.unit_name, target.unit_name, spell.spell_name, damage])

# `unavoidable` : attaque imparable (ni parade ni esquive possibles) — utilisée
# pour l'attaque d'opportunité quand on quitte un corps à corps (voir move_unit).
func _resolve_weapon_attack(caster: CombatUnit, spell: Spell, target: CombatUnit, unavoidable: bool = false) -> void:
	caster.face_direction(target.position)
	caster.play_animation("attack" if spell.is_melee_range() else "ranged_attack")

	# Camouflage Naturel (Rôdeur) : attaquer révèle, quel que soit le
	# résultat du coup (touché ou raté) — retiré par son nom précis,
	# pas par expiration (duration_remaining=-1 à la pose).
	if caster.equipped_metier != null and caster.equipped_metier.grants_rodeur_camouflage:
		var before = caster.active_effects.size()
		caster.active_effects = caster.active_effects.filter(func(e): return e.effect_name != "Camouflage Naturel")
		if caster.active_effects.size() != before:
			caster._recalculate_stats()
			spawn_floating_text(caster.position, "Révélé !", Color(0.9, 0.6, 0.3))

	# Combo (Samurai) : compte cette attaque si elle est au corps à
	# corps — une éventuelle désactivation de la défense (si c'est la
	# 2e ET qu'elle rate, voir plus bas) se juge sur ce compteur.
	if spell.is_melee_range() and caster.equipped_race != null and caster.equipped_race.grants_samurai_combo:
		caster.samurai_melee_attacks_this_turn += 1

	# Concentration (Samurai) : consommée par CETTE attaque, qu'elle
	# touche ou non (voir StatusEffect.grants_next_attack_double_damage/
	# ignores_armor) — capturé maintenant en variables locales, puis
	# l'effet est retiré tout de suite pour ne pas être réutilisé.
	var concentration_double = false
	var concentration_ignores_armor = false
	for effect in caster.active_effects.duplicate():
		if effect.grants_next_attack_double_damage or effect.grants_next_attack_ignores_armor:
			concentration_double = effect.grants_next_attack_double_damage
			concentration_ignores_armor = effect.grants_next_attack_ignores_armor
			caster.active_effects.erase(effect)
			caster._recalculate_stats()
			break

	# Arme céleste (Walkyrie) : consommée par CETTE attaque, qu'elle
	# touche ou non — les dégâts sont traités comme magiques (réduits
	# par l'armure magique de la cible plutôt que physique).
	var use_magic_armor = false
	if caster.magic_weapon_attacks_remaining > 0:
		use_magic_armor = true
		caster.magic_weapon_attacks_remaining -= 1

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

		# Maître d'armes : une attaque RATÉE remet la série à 0.
		if caster.has_metier("Maitre d'armes"):
			caster.maitre_armes_streak = 0
		caster.chain_pi = 0  # Enchaînement (Ninja) : pas de dégâts, la série retombe.

		# Combo (Samurai) : la 2e attaque au CAC du tour qui rate coûte
		# la défense (Parade/Esquive) jusqu'au prochain tour du samurai.
		if spell.is_melee_range() and caster.equipped_race != null and caster.equipped_race.grants_samurai_combo \
				and caster.samurai_melee_attacks_this_turn >= 2:
			caster.samurai_combo_disabled_defense = true
			spawn_floating_text(caster.position, "Combo raté !", Color(0.85, 0.3, 0.2))
			print("%s perd sa défense jusqu'à son prochain tour (Combo raté)." % caster.unit_name)

		return

	# Critique : normalement jet = 1 (dégâts ×2). Frappe d'énergie
	# (Moine, à mains nues) étend la fenêtre à 1-5 et porte le
	# multiplicateur à ×4. Coup mortel (Assassin) étend la fenêtre à
	# 1-4 (multiplicateur normal) pour le PREMIER coup qui touche
	# chaque cible — les deux se cumulent par le plus favorable si un
	# même lanceur avait (improbablement) les deux à la fois.
	var is_unarmed = caster.equipped_weapon != null and caster.equipped_weapon.weapon_name == "Poings"
	var has_frappe_energie = is_unarmed and caster.equipped_metier != null and caster.equipped_metier.grants_moine_frappe_energie

	var has_coup_mortel = caster.equipped_metier != null and caster.equipped_metier.grants_assassin_coup_mortel
	var is_first_hit_on_target = has_coup_mortel and not caster.assassin_hit_targets.has(target)
	if has_coup_mortel and not caster.assassin_hit_targets.has(target):
		caster.assassin_hit_targets.append(target)

	var crit_threshold = 1
	var crit_multiplier = 2
	if has_frappe_energie:
		crit_threshold = max(crit_threshold, 5)
		crit_multiplier = max(crit_multiplier, 4)
	if is_first_hit_on_target:
		crit_threshold = max(crit_threshold, 4)

	# Réalité distordue (Prestidigitateur) : la CIBLE ne peut jamais
	# subir de critique, peu importe le jet de l'attaquant.
	var target_immune_to_crits = target.equipped_metier != null and target.equipped_metier.grants_prestidigitateur_realite_distordue
	var is_critical = hit_roll <= crit_threshold and not target_immune_to_crits
	if is_critical:
		spawn_floating_text(target.position, "Critique !", Color(1.0, 0.85, 0.2))
		print("%s réalise un coup critique !" % caster.unit_name)

	# Gloire (Gladiateur) : +1 par attaque réussie — le propre jet du
	# Gladiateur a touché, indépendamment de ce qu'en fait la cible
	# ensuite (parade/esquive, voir plus bas).
	if caster.has_metier("Gladiateur"):
		caster.gloire += 1

	# Touché a priori : le défenseur peut tenter de parer (mêlée
	# seulement) s'il est en posture Parade ET que sa défense n'est pas
	# désactivée (voir Combo/Concentration, Samurai).
	if not unavoidable and spell.is_melee_range() and not target.samurai_combo_disabled_defense \
			and target.defensive_stance == CombatUnit.DefensiveStance.PARRY:
		var parry_roll = randi_range(1, 20)
		# Face à un coup critique (jet d'attaque = 1), seul un 1 à la
		# parade aussi permet de la réussir — le seuil normal (< Parade)
		# ne compte plus.
		var parry_success = parry_roll == 1 if is_critical else parry_roll < target.parade_stat

		# Gloire (Gladiateur) : +2 si la parade réussit, -1 si elle
		# était tentée mais ratée (ce bloc ne s'exécute QUE quand une
		# parade a été tentée, voir la condition plus haut).
		if target.has_metier("Gladiateur"):
			target.gloire += 2 if parry_success else -1
			target.gloire = max(0, target.gloire)

		if parry_success:
			spawn_floating_text(target.position, "Paré !", Color(0.9, 0.8, 0.2))

			# Maître d'armes : une attaque PARÉE remet aussi la série à 0.
			if caster.has_metier("Maitre d'armes"):
				caster.maitre_armes_streak = 0
			caster.chain_pi = 0

			# Même paré, il y a eu contact au corps à corps : la
			# contre-attaque passive (Aura de feu) se déclenche quand
			# même — seule une ESQUIVE évite tout contact (voir plus bas).
			_apply_melee_reflect(target, caster)
			_deal_counter_attack(target, caster)
			return
		# Parade ratée : les dégâts normaux s'appliquent plus bas.

	if not unavoidable and _try_dodge(target, caster, is_critical):
		# Maître d'armes : une attaque ESQUIVÉE remet aussi la série à 0.
		if caster.has_metier("Maitre d'armes"):
			caster.maitre_armes_streak = 0
		caster.chain_pi = 0
		return

	# Maître d'armes : l'attaque n'a été ni ratée, ni parée, ni esquivée
	# — la série avance d'un cran.
	var maitre_armes_bonus = 0
	if caster.has_metier("Maitre d'armes"):
		caster.maitre_armes_streak += 1
		maitre_armes_bonus = 2 * caster.maitre_armes_streak

	# Un vrai jet de dés à chaque coup (voir Weapon.roll_damage) plutôt
	# que la moyenne figée sur le sort — source_weapon est toujours
	# défini pour une attaque d'arme (voir Weapon.create_attack_spell).
	# flat_damage_bonus s'ajoute tel quel (ex: bonus d'une flèche
	# spéciale), sans lui-même être aléatoire.
	var effective_damage = spell.source_weapon.roll_damage() + spell.flat_damage_bonus
	if spell.is_melee_range():
		effective_damage += caster.get_melee_damage_bonus()

	# Bonus de dégâts d'arme temporaire (Zéphir, Poings de terre,
	# Enchantement...) — voir StatusEffect.bonus_weapon_dice_*.
	effective_damage += _roll_weapon_bonus_dice(caster, spell.is_melee_range())

	# Bourre pif (BP) : +1 dégât si l'attaque se fait à mains nues.
	if caster.equipped_weapon != null and caster.equipped_weapon.weapon_name == "Poings" and caster.has_skill("BP"):
		effective_damage += 1

	# Salpêtre (Artificier) : +1 dégât aux armes à feu, détecté via le
	# nom de l'arme (même convention que le javelot/la dague).
	if caster.equipped_weapon != null and caster.equipped_weapon.weapon_name.begins_with("Pistolet") \
			and caster.has_metier("Artificier"):
		effective_damage += 1

	# Maître d'armes : +2 par cran de série (calculée plus haut, juste
	# après le test de parade).
	effective_damage += maitre_armes_bonus

	# Points d'Impact (PI) : dégâts supplémentaires sur chaque attaque
	# (Ogre, GRRRBL du Berzerk, Enchaînement du Ninja).
	effective_damage += caster.pi + caster.chain_pi

	# Formation (Soldat) : +1 dégât si au moins un allié (hors
	# soi-même) est sur une case adjacente.
	if caster.has_metier("Soldat"):
		for ally in _get_team_including_self(caster):
			if ally != caster and hex_distance(caster.hex_coord, ally.hex_coord) == 1:
				effective_damage += 1
				break

	# Berzerk : Enragé (+niveau dégâts sous 66% PV) et Coûte que coûte
	# (+2×niveau dégâts sous 3% PV) — indépendants, se cumulent sous
	# 3% PV (les deux seuils sont alors franchis à la fois).
	if caster.has_metier("Berzerk") and caster.max_hp > 0:
		var hp_ratio = float(caster.current_hp) / caster.max_hp
		if hp_ratio < 0.66:
			effective_damage += caster.level
		if hp_ratio < 0.03:
			effective_damage += 2 * caster.level

	# Raaah (Berzerk) : bonus permanent acquis une fois pour toutes ce combat.
	if caster.berzerk_permanent_damage_bonus > 0:
		effective_damage += caster.berzerk_permanent_damage_bonus

	# Frappe puissante (Berzerk) : +N dégâts plats, consommés sur CETTE
	# attaque précise — retiré après usage, touchée ou non.
	for effect in caster.active_effects:
		if effect.grants_next_attack_flat_bonus > 0:
			effective_damage += effect.grants_next_attack_flat_bonus
			caster.remove_status_effect(effect)
			break

	# Bonus de dégâts javelot (Demi Orque) : +1D6 par dé accordé,
	# détecté via le nom de l'arme (pas de champ "catégorie" sur Weapon).
	if caster.equipped_weapon != null and caster.equipped_weapon.weapon_name.begins_with("Javelot") \
			and caster.equipped_race != null and caster.equipped_race.javelin_damage_bonus_dice > 0:
		for i in range(caster.equipped_race.javelin_damage_bonus_dice):
			effective_damage += randi_range(1, 6)

	# Dague empoisonnée (Empoisonneur) : +1D4 sur la toute PREMIÈRE
	# attaque d'arme du combat (une seule fois, peu importe l'arme
	# réellement équipée — la donnée d'origine ne restreint pas
	# explicitement aux dagues malgré le nom de la capacité).
	if not caster.empoisonneur_first_attack_used and caster.equipped_metier != null and caster.equipped_metier.grants_empoisonneur_dague:
		caster.empoisonneur_first_attack_used = true
		var poison_bonus = randi_range(1, 4)
		effective_damage += poison_bonus
		spawn_floating_text(target.position, "+%d (Dague empoisonnée)" % poison_bonus, Color(0.5, 0.75, 0.3))

	# Concentration (Samurai) : dégâts doublés et armure ignorée sur
	# cette attaque précise (voir capture en tête de fonction).
	if concentration_double:
		effective_damage *= 2

	# Coup décisif (Chasseurs de primes/monstres), bascule ON : 1 chance sur 2
	# de dégâts doublés, sinon aucun dégât.
	if caster.coup_decisif_on and caster.can_coup_decisif():
		if randf() < 0.5:
			effective_damage *= 2
			spawn_floating_text(caster.position, "Coup décisif !", Color(0.95, 0.75, 0.2))
		else:
			effective_damage = 0
			spawn_floating_text(caster.position, "Coup décisif raté", Color(0.65, 0.65, 0.65))

	# Critique : dégâts ×crit_multiplier (×2 normal, ×4 avec Frappe
	# d'énergie — voir plus haut) — se cumule avec Concentration si les
	# deux sont actifs en même temps, pas de raison de les exclure l'un
	# l'autre.
	if is_critical:
		effective_damage *= crit_multiplier

	# Frappe des ombres (Ninja) : dégâts ×2 en frappant une cible qui
	# ne lui fait pas face, peu importe l'arme.
	if caster.equipped_metier != null and caster.equipped_metier.grants_ninja_frappe_des_ombres \
			and target.is_attacked_from_behind(caster.position):
		effective_damage *= 2
		spawn_floating_text(target.position, "Frappe des ombres !", Color(0.4, 0.3, 0.6))

	# L'armure du défenseur réduit les dégâts subis (jamais sous 0) —
	# sauf Concentration (la traverse complètement) et Précision
	# mortelle (Assassin), qui fait de même mais seulement à la dague.
	var precision_mortelle = caster.equipped_weapon != null and caster.equipped_weapon.weapon_name.begins_with("Dague") \
		and caster.equipped_metier != null and caster.equipped_metier.grants_assassin_precision_mortelle
	# Arme céleste fait consulter l'armure MAGIQUE de la cible plutôt que physique.
	if not concentration_ignores_armor and not precision_mortelle:
		var relevant_armor = target.magic_armor_value if use_magic_armor else target.armor_value
		effective_damage = max(0, effective_damage - relevant_armor)

	# Maîtrise des runes (Conservateur) : +2 dégâts MAGIQUES en plus,
	# réduits par l'armure magique de la cible séparément (pas la
	# physique, même si l'attaque elle-même en est une) — s'ajoute
	# après la réduction d'armure normale, jamais sous 0 lui non plus.
	if caster.has_metier("Conservateur"):
		var runes_bonus = max(0, 2 - target.magic_armor_value)
		effective_damage += runes_bonus

	target.take_damage(effective_damage, is_critical)
	spawn_floating_text(target.position, "-%d" % effective_damage, Color(0.95, 0.3, 0.3))

	# Enchaînement (Ninja) : +1 PI par attaque qui inflige des dégâts, remis à
	# 0 sinon.
	if caster.has_metier("Ninja"):
		if effective_damage > 0:
			caster.chain_pi += 1
		else:
			caster.chain_pi = 0

	print("%s touche %s avec %s (%d dégâts)." % [caster.unit_name, target.unit_name, spell.spell_name, effective_damage])

	# Vol de vie (Gantelets du Berserk) : soigne le lanceur du montant
	# exact des dégâts infligés.
	if effective_damage > 0:
		for effect in caster.active_effects:
			if effect.grants_lifesteal:
				var healed = min(effective_damage, caster.max_hp - caster.current_hp)
				if healed > 0:
					caster.current_hp += healed
					spawn_floating_text(caster.position, "+%d (vol de vie)" % healed, Color(0.35, 0.9, 0.5))
				break

	# Contre-attaque passive (Aura de feu) : quiconque frappe la cible
	# au CORPS À CORPS subit en retour les dégâts du sort d'origine.
	if spell.is_melee_range():
		_apply_melee_reflect(target, caster)

# Additionne les bonus de dégâts d'arme temporaires (voir
# StatusEffect.bonus_weapon_dice_*) actifs sur `unit`, en respectant
# la restriction "à distance seulement" quand elle est précisée.
func _roll_weapon_bonus_dice(unit: CombatUnit, is_melee: bool) -> int:
	var total = 0
	for effect in unit.active_effects:
		if effect.bonus_weapon_dice_count <= 0:
			continue
		if effect.bonus_weapon_dice_ranged_only and is_melee:
			continue
		total += effect.bonus_weapon_dice_modifier
		for i in range(effect.bonus_weapon_dice_count):
			total += randi_range(1, 6)
	return total

# Vérifie si `target` a un effet de contre-attaque actif (voir Aura de
# feu / StatusEffect.reflect_dice_terms) et, si oui, inflige ce dégât
# à `attacker` (toujours "brut", pas de réduction d'armure — c'est une
# brûlure au contact, pas une attaque physique classique).
func _apply_melee_reflect(target: CombatUnit, attacker: CombatUnit) -> void:
	for effect in target.active_effects:
		if effect.reflect_dice_terms.is_empty():
			continue
		var total = 0
		for term in effect.reflect_dice_terms:
			total += term.get("modifier", 0)
			for i in range(term.get("count", 0)):
				total += randi_range(1, term.get("sides", 6))
		if total > 0:
			attacker.take_damage(total)
			spawn_floating_text(attacker.position, "-%d (%s)" % [total, effect.effect_name], Color(0.9, 0.4, 0.1))

# Les sorts/enchantements doivent réussir un jet de lancer basé sur la
# moyenne de deux stats (Intelligence + Adresse pour un sort physique,
# Intelligence + Charisme pour un sort psychique). S'ils touchent, ils
# peuvent être esquivés comme une attaque d'arme — SAUF un sort de
# soin, qui ne peut jamais être esquivé.
# Les sorts/enchantements doivent réussir un jet de lancer basé sur la
# moyenne de deux stats (Intelligence + Adresse pour un sort physique,
# Intelligence + Charisme pour un sort psychique) — UNE SEULE FOIS,
# peu importe le nombre de cibles. S'il réussit, l'effet est appliqué
# à chaque cible indépendamment (voir _apply_spell_effect_to_target) :
# une attaque de zone peut par exemple toucher 3 ennemis qui esquivent
# ou parent chacun de leur côté.
# Un sort ou une compétence qui coûte de l'EA et ÉCHOUE au jet du lanceur
# rend la moitié du coût (arrondie à l'inférieur). Jamais appelée quand la
# cible esquive : seul un jet raté du lanceur rembourse.
func _refund_failed_cast(caster: CombatUnit, ea_cost: int) -> void:
	var refund: int = mini(floori(ea_cost / 2.0), caster.max_ea - caster.current_ea)
	if refund <= 0:
		return
	caster.current_ea += refund
	spawn_floating_text(caster.position, "+%d EA (raté)" % refund, Color(0.65, 0.45, 0.95))
	print("%s récupère %d EA (sort raté, moitié du coût rendue)." % [caster.unit_name, refund])

# Sort à coût « initial (i) » raté : la moitié (arrondie à l'inférieur) de
# l'EA MAXIMUM perdue est rendue — au maximum, et à l'EA actuelle d'autant.
func _refund_failed_initial_cost(caster: CombatUnit) -> void:
	var paid: int = int(caster.get_meta("last_initial_cost_paid", 0))
	var refund: int = floori(paid / 2.0)
	if refund <= 0:
		return
	caster.base_max_ea += refund
	caster._recalculate_stats()
	caster.current_ea = mini(caster.current_ea + refund, caster.max_ea)
	spawn_floating_text(caster.position, "+%d EA max (raté)" % refund, Color(0.75, 0.25, 0.55))
	print("%s récupère %d EA maximum (sort à coût initial raté)." % [caster.unit_name, refund])

func _resolve_spell_effect(caster: CombatUnit, spell: Spell, targets: Array) -> void:
	if targets.is_empty():
		return

	caster.face_direction(targets[0].position)
	caster.play_animation("cast")  # Ignoré silencieusement si non définie pour cette classe.

	var avg_stat: float
	if spell.spell_type == Spell.SpellType.CHANCE:
		avg_stat = caster.chance_stat  # Pas de moyenne : la Chance seule.
	elif spell.spell_type == Spell.SpellType.COURAGE:
		avg_stat = caster.courage  # Pas de moyenne : le Courage seul.
	elif spell.spell_type == Spell.SpellType.INTELLIGENCE:
		avg_stat = caster.intelligence_stat  # Pas de moyenne : l'Intelligence seule.
	elif spell.spell_type == Spell.SpellType.COURAGE_CHARISME:
		avg_stat = (caster.courage + caster.charisme_stat) / 2.0
	elif spell.spell_type == Spell.SpellType.PSYCHIC:
		avg_stat = (caster.intelligence_stat + caster.charisme_stat) / 2.0
	else:
		avg_stat = (caster.intelligence_stat + caster.adresse_stat) / 2.0

	# Malus de trajectoire calculé vers la première cible seulement (un
	# sort de zone n'a qu'un point d'impact, pas une ligne de mire par
	# cible touchée dans le souffle).
	var malus = count_units_in_line(caster.hex_coord, targets[0].hex_coord)
	avg_stat -= malus

	var cast_roll = randi_range(1, 20)
	if cast_roll >= avg_stat:
		print("%s rate son sort %s (jet %d >= moyenne %.1f, malus -%d)." % [caster.unit_name, spell.spell_name, cast_roll, avg_stat, malus])
		spawn_floating_text(targets[0].position, "Raté", Color(0.65, 0.65, 0.65))
		if spell.is_initial_cost:
			_refund_failed_initial_cost(caster)
		elif spell.gloire_cost <= 0:
			_refund_failed_cast(caster, spell.get_effective_ea_cost(caster))
		return

	# Critique (jet = 1) : double les DÉGÂTS/SOINS du sort uniquement
	# (voir _apply_spell_effect_to_target) — n'affecte PAS les effets à
	# durée/buffs/debuffs/invocations qu'il pourrait aussi poser.
	var is_critical = cast_roll == 1
	if is_critical:
		spawn_floating_text(targets[0].position, "Critique !", Color(1.0, 0.85, 0.2))
		print("%s réalise un coup critique avec %s !" % [caster.unit_name, spell.spell_name])

	for target in targets:
		_apply_spell_effect_to_target(caster, spell, target, is_critical)

# Applique l'effet d'un sort DÉJÀ LANCÉ AVEC SUCCÈS à une cible précise
# (dégâts/soin, esquive, armure, effet à durée...) — séparé de
# _resolve_spell_effect pour être appelable une fois par cible d'un
# sort de zone/groupe. `is_critical` (jet = 1) double les dégâts/soins
# SEULEMENT — jamais les effets à durée/buffs/invocations.
func _apply_spell_effect_to_target(caster: CombatUnit, spell: Spell, target: CombatUnit, is_critical: bool = false) -> void:
	# Purge : retire tous les effets à durée actifs de la cible (buffs
	# ET debuffs — le catalogue ne distingue pas). Une action à part,
	# elle ne se combine pas avec un dégât/soin dans le même sort.
	if spell.cleanses_effects:
		target.active_effects.clear()
		target._recalculate_stats()
		spawn_floating_text(target.position, "Purifié", Color(0.6, 0.9, 1.0))
		return

	# Infection (Prêtre, Ordre du cycle éternel) : pose une charge
	# cumulable, pas de dégât classique — voir Nécrose pour leur
	# déclenchement.
	if spell.applies_infection:
		if not spell.unavoidable and _try_dodge(target, caster, is_critical):
			return
		target.infection_stacks += 1
		spawn_floating_text(target.position, "Infection (%d)" % target.infection_stacks, Color(0.5, 0.7, 0.3))
		print("%s infecte %s (%d charge(s))." % [caster.unit_name, target.unit_name, target.infection_stacks])
		return

	# Nécrose (Prêtre) : déclenche TOUTES les charges d'Infection de la
	# cible d'un coup (4 dégâts bruts chacune), les remet à 0.
	if spell.triggers_infections:
		var stacks = target.infection_stacks
		if stacks <= 0:
			spawn_floating_text(target.position, "Aucune infection", Color(0.65, 0.65, 0.65))
			return
		target.infection_stacks = 0
		var necrose_damage = stacks * 4
		target.take_damage(necrose_damage)
		spawn_floating_text(target.position, "-%d (Nécrose)" % necrose_damage, Color(0.45, 0.65, 0.25))
		print("%s déclenche %d charge(s) d'Infection sur %s (%d dégâts bruts)." % [caster.unit_name, stacks, target.unit_name, necrose_damage])
		return

	# A-t-il un vrai dégât/soin, ou est-ce un buff/debuff pur (ex: juste
	# +2 Adresse, sans aucun dégât) ? Un sort sans dice_terms ET sans
	# `damage` fixe ET qui n'est pas marqué soin n'a rien à infliger.
	var has_damage_component = spell.is_heal or not spell.dice_terms.is_empty() or spell.damage != 0

	# Esquivable seulement si c'est hostile (cible d'un autre camp,
	# effet non-soin) — un soin ou un buff sur un allié ne s'esquive
	# jamais, que ce soit un dégât ou un simple debuff de stat.
	var is_offensive = target.team != caster.team and not spell.is_heal

	if has_damage_component:
		if is_offensive and not spell.unavoidable and _try_dodge(target, caster, is_critical):
			return  # Esquivé : ni dégâts ni effet à durée éventuel ne s'appliquent.

		_spawn_spell_effect(spell, target.position)

		var rolled: int
		if spell.damage_percent_of_target_hp > 0.0:
			# Molto (Barde) : dégâts = un ratio des PV ACTUELS de la
			# cible, pas une formule de dés — ignore dice_terms.
			rolled = int(round(target.current_hp * spell.damage_percent_of_target_hp))
		elif spell.dice_count_equals_level and not spell.dice_terms.is_empty():
			# Scalpel : "1D par niveau" — le nombre de dés lancés est le
			# niveau du lanceur, pas une valeur fixe de dice_terms.
			rolled = 0
			var sides = spell.dice_terms[0].get("sides", 6)
			for i in range(caster.level):
				rolled += randi_range(1, sides)
		else:
			rolled = spell.roll_value()

		if spell.level_multiplier > 0:
			rolled = caster.level * spell.level_multiplier
		elif spell.includes_caster_level:
			rolled += caster.level

		# "+1 dégât par CHA > 12" (Barde) — voir
		# Spell.includes_charisme_bonus_above_12.
		if spell.includes_charisme_bonus_above_12:
			rolled += max(0, caster.charisme_stat - 12)

		# Critique (jet = 1) : double le résultat du dé — dégâts, soin,
		# ou restauration d'EA (voir is_critical, transmis depuis
		# _resolve_spell_effect). N'affecte RIEN d'autre (effets à
		# durée/buffs appliqués plus bas restent inchangés). Réalité
		# distordue (Prestidigitateur) bloque le critique UNIQUEMENT
		# pour des dégâts (un soin critique reste bénéfique, pas "subi").
		var target_immune_to_crits = target.equipped_metier != null and target.equipped_metier.grants_prestidigitateur_realite_distordue
		var effective_crit = is_critical and not (target_immune_to_crits and not spell.is_heal)
		if effective_crit:
			rolled *= 2

		# "Rend X PA" (voir lexique Mage) : restaure de l'EA, pas des PV —
		# traitement à part, ça ne passe jamais par take_damage().
		if spell.is_heal and spell.restores_mana:
			target.current_ea = min(target.current_ea + rolled, target.max_ea)
			spawn_floating_text(target.position, "+%d EA" % rolled, Color(0.55, 0.75, 0.95))
			print("%s restaure %d EA à %s avec %s." % [caster.unit_name, rolled, target.unit_name, spell.spell_name])
			return

		var effective_damage = -rolled if spell.is_heal else rolled
		var spell_bonus = caster.get_spell_damage_bonus()
		if spell.is_heal:
			effective_damage -= spell_bonus  # Renforce le soin (plus négatif).
		else:
			effective_damage += spell_bonus

			# Dégâts "brut" (voir lexique Mage) : ignorent TOUTE armure.
			# Sinon, un sort PH est réduit par l'armure physique, un sort PS
			# par l'armure MAGIQUE (distincte) — jamais sous 0.
			if not spell.ignores_armor:
				var relevant_armor = target.magic_armor_value if spell.spell_type == Spell.SpellType.PSYCHIC else target.armor_value
				effective_damage = max(0, effective_damage - relevant_armor)

			# Déjà vu (Artificier) : dégâts de FEU entrants réduits de
			# moitié — après la réduction d'armure normale.
			if spell.elements.has("Feu") and target.has_metier("Artificier"):
				effective_damage = int(effective_damage / 2.0)

		target.take_damage(effective_damage, effective_crit)

		if effective_damage >= 0:
			spawn_floating_text(target.position, "-%d" % effective_damage, Color(0.95, 0.3, 0.3))
		else:
			spawn_floating_text(target.position, "+%d" % abs(effective_damage), Color(0.35, 0.9, 0.5))

		print("%s touche %s avec %s (%d dégâts)." % [caster.unit_name, target.unit_name, spell.spell_name, effective_damage])

		# Croissant de lune (Prêtre) : les PV retirés sont transférés en
		# soin au lanceur (simplification : la donnée d'origine laisse
		# le choix "à un allié ou à soi-même", on transfère toujours au
		# lanceur pour éviter d'ajouter un second ciblage).
		if spell.transfers_damage_to_ally and effective_damage > 0:
			var healed = min(effective_damage, caster.max_hp - caster.current_hp)
			caster.current_hp += healed
			spawn_floating_text(caster.position, "+%d" % healed, Color(0.35, 0.9, 0.5))
			print("%s transfère %d PV depuis %s." % [caster.unit_name, healed, target.unit_name])

		# Lancer un sort à distance 1 (corps à corps) est risqué pour le
		# lanceur : il subit 1/3 des dégâts infligés, en retour.
		if is_offensive and hex_distance(caster.hex_coord, target.hex_coord) == 1 and effective_damage > 0:
			var backlash = int(effective_damage / 3.0)
			if backlash > 0:
				caster.take_damage(backlash)
				spawn_floating_text(caster.position, "-%d (recul)" % backlash, Color(0.85, 0.5, 0.2))
				print("%s subit %d dégâts de recul (sort lancé au corps à corps)." % [caster.unit_name, backlash])
	elif is_offensive and not spell.unavoidable and _try_dodge(target, caster, is_critical):
		return  # Debuff pur (sans dégâts) sur un ennemi : esquivable aussi.

	# Effet à durée (buff/debuff/DoT — voir status_effect.gd) : un
	# exemplaire propre par cible, pour que les durées/ticks se
	# décomptent indépendamment les uns des autres. Sauté si ce sort
	# demande l'absence de Nyctalopie (Erèbe) et que la cible l'a.
	if spell.effect_to_apply != null:
		var applies = not (spell.requires_missing_nyctalopie and target.has_nyctalopie)
		if applies:
			var effect_instance: StatusEffect = spell.effect_to_apply.duplicate()
			target.add_status_effect(effect_instance)
			spawn_floating_text(target.position, effect_instance.effect_name, Color(0.7, 0.6, 0.95))
		else:
			spawn_floating_text(target.position, "Résiste (Nyctalopie)", Color(0.6, 0.6, 0.6))

	# Détection de zone : retire l'invisibilité de la cible.
	if spell.reveals_invisible:
		target.active_effects = target.active_effects.filter(func(e): return not e.grants_untargetable)
		target._recalculate_stats()

	# Étourdissement (Mistral, Marchand de sable) : la cible passe
	# purement et simplement ses N prochains tours (voir
	# TurnManager._start_current_turn).
	if spell.stun_turns > 0:
		target.stunned_turns_remaining += spell.stun_turns
		spawn_floating_text(target.position, "Étourdi (%d)" % spell.stun_turns, Color(0.9, 0.9, 0.3))

	# Provocation ciblée (Doigt d'honneur) : pendant N de ses tours, la cible
	# ne peut attaquer que le lanceur (appliqué par EnemyAI).
	if spell.forces_attack_on_caster_turns > 0:
		target.taunt_source = caster
		target.taunt_turns_remaining = spell.forces_attack_on_caster_turns
		spawn_floating_text(target.position, "Provoqué (%d)" % spell.forces_attack_on_caster_turns, Color(0.95, 0.55, 0.25))

	# Arme conjurée (Vajra) : remplace l'arme de mêlée de la cible —
	# PAS de retour automatique à l'ancienne arme (limitation assumée).
	if spell.conjures_weapon:
		var old_weapon = target.equipped_weapon

		var conjured := Weapon.new()
		conjured.weapon_name = spell.conjured_weapon_name
		conjured.dice_count = spell.conjured_weapon_dice_count
		conjured.dice_modifier = spell.conjured_weapon_dice_modifier
		conjured.bonus_attaque = spell.conjured_weapon_bonus_attaque
		conjured.bonus_parade = spell.conjured_weapon_bonus_parade
		conjured.min_range = 1
		conjured.max_range = 1
		target.equipped_weapon = conjured
		target._recalculate_stats()

		# Le bouton d'attaque existant référence encore l'ancienne arme
		# (source_weapon) — on le remplace pour qu'il tire vraiment les
		# dégâts de l'arme conjurée à partir de maintenant.
		for i in range(target.spells.size()):
			if target.spells[i].is_weapon_attack and target.spells[i].source_weapon == old_weapon:
				target.spells[i] = conjured.create_attack_spell()
				break

		spawn_floating_text(target.position, spell.conjured_weapon_name, Color(0.85, 0.75, 0.2))

# Tente une esquive pour le défenseur s'il est en posture Esquive et
# que sa disponibilité d'esquive n'est pas déjà consommée ce tour-ci
# (règle "1 attaque sur 2"). Renvoie true si l'attaque est esquivée.
# `attacker` : l'unité dont l'attaque/le sort vient d'être esquivé —
# sert à savoir qui contre-attaquer (voir Race.dodge_counter_chance,
# Elfe Noir). Centralisé ici : tous les appelants passent par cette
# fonction, donc la contre-attaque couvre uniformément attaque d'arme,
# sort ET riposte, sans rien dupliquer.
func _try_dodge(target: CombatUnit, attacker: CombatUnit, attack_is_critical: bool = false) -> bool:
	if target.samurai_combo_disabled_defense:
		return false  # Défense désactivée (Combo raté ou Concentration, Samurai) — jusqu'à son prochain tour.

	if target.defensive_stance != CombatUnit.DefensiveStance.DODGE:
		return false

	# Voleur (malus d'Adresse alterné en contrepartie, voir
	# CombatUnit.voleur_ad_malus_active) OU Ninja (sans malus, voir
	# Metier.grants_ninja_esquive_totale) : pas de restriction "1 tour
	# sur 2" — pas besoin d'EN PLUS consommer dodge_available.
	var has_esquive_totale = target.equipped_metier != null \
		and (target.equipped_metier.grants_voleur_esquive_totale or target.equipped_metier.grants_ninja_esquive_totale)

	if not has_esquive_totale:
		if not target.dodge_available:
			return false  # Esquive déjà "consommée" par l'attaque précédente.
		target.dodge_available = false  # Consommée qu'elle réussisse ou non.

	var dodge_roll = randi_range(1, 20)
	# Face à un coup critique (jet d'attaque = 1), seul un 1 à l'esquive
	# aussi permet de l'éviter — le seuil normal (< Adresse) ne compte plus.
	var dodge_success = dodge_roll == 1 if attack_is_critical else dodge_roll < target.adresse_stat
	if dodge_success:
		spawn_floating_text(target.position, "Esquivé !", Color(0.4, 0.8, 1.0))

		# Contre-attaque après esquive (Elfe Noir : sans restriction ;
		# Homme des sables : seulement au corps à corps, voir
		# Race.dodge_counter_melee_only) : chance indépendante à chaque
		# esquive réussie. dodge_available étant déjà consommé des deux
		# côtés au moment où c'est pertinent, aucune boucle infinie
		# possible même si les deux unités ont cette capacité.
		if attacker != null and target.equipped_race != null and target.equipped_race.dodge_counter_chance > 0.0:
			var melee_ok = not target.equipped_race.dodge_counter_melee_only \
				or hex_distance(target.hex_coord, attacker.hex_coord) == 1
			if melee_ok and randf() < target.equipped_race.dodge_counter_chance:
				_deal_counter_attack(target, attacker)

		# Même mécanique, mais portée par un effet TEMPORAIRE (voir
		# Subito, Barde) plutôt que fixée par la race — vérifiée
		# séparément, chance indépendante elle aussi.
		if attacker != null:
			for effect in target.active_effects:
				if effect.dodge_counter_chance > 0.0:
					var melee_ok_effect = not effect.dodge_counter_melee_only \
						or hex_distance(target.hex_coord, attacker.hex_coord) == 1
					if melee_ok_effect and randf() < effect.dodge_counter_chance:
						_deal_counter_attack(target, attacker)
						break

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

	# Critique : normalement jet = 1 (dégâts ×2) — Frappe d'énergie
	# (Moine, à mains nues) étend la fenêtre à 1-5 et porte le
	# multiplicateur à ×4, même règle qu'à l'attaque normale.
	var counter_is_unarmed = defender.equipped_weapon != null and defender.equipped_weapon.weapon_name == "Poings"
	var counter_has_frappe_energie = counter_is_unarmed and defender.equipped_metier != null and defender.equipped_metier.grants_moine_frappe_energie
	var counter_crit_threshold = 5 if counter_has_frappe_energie else 1
	var counter_crit_multiplier = 4 if counter_has_frappe_energie else 2
	# Réalité distordue (Prestidigitateur) : même règle, la cible de la
	# riposte c'est l'attaquant original.
	var attacker_immune_to_crits = attacker.equipped_metier != null and attacker.equipped_metier.grants_prestidigitateur_realite_distordue
	var is_counter_critical = counter_roll <= counter_crit_threshold and not attacker_immune_to_crits
	if is_counter_critical:
		spawn_floating_text(attacker.position, "Critique !", Color(1.0, 0.85, 0.2))

	if _try_dodge(attacker, defender, is_counter_critical):
		return

	var base_damage = defender.equipped_weapon.roll_damage() if defender.equipped_weapon != null else 5
	var counter_damage = base_damage + defender.get_melee_damage_bonus()

	# Bourre pif (BP) : +1 dégât si la riposte se fait à mains nues.
	if defender.equipped_weapon != null and defender.equipped_weapon.weapon_name == "Poings" and defender.has_skill("BP"):
		counter_damage += 1

	# Bonus de dégâts javelot (Demi Orque) : même bonus qu'à l'attaque.
	if defender.equipped_weapon != null and defender.equipped_weapon.weapon_name.begins_with("Javelot") \
			and defender.equipped_race != null and defender.equipped_race.javelin_damage_bonus_dice > 0:
		for i in range(defender.equipped_race.javelin_damage_bonus_dice):
			counter_damage += randi_range(1, 6)

	# Arme céleste (Walkyrie) : même traitement qu'à l'attaque normale
	# (armure magique de la cible plutôt que physique), consommée par
	# CETTE riposte.
	var counter_relevant_armor = attacker.armor_value
	if defender.magic_weapon_attacks_remaining > 0:
		defender.magic_weapon_attacks_remaining -= 1
		counter_relevant_armor = attacker.magic_armor_value

	if is_counter_critical:
		counter_damage *= counter_crit_multiplier

	counter_damage = max(0, counter_damage - counter_relevant_armor)

	# Maîtrise des runes (Conservateur) : même bonus qu'à l'attaque
	# normale, même en ripostant.
	if defender.has_metier("Conservateur"):
		var counter_runes_bonus = max(0, 2 - attacker.magic_armor_value)
		counter_damage += counter_runes_bonus

	attacker.take_damage(counter_damage, is_counter_critical)
	spawn_floating_text(attacker.position, "-%d (riposte)" % counter_damage, Color(0.95, 0.55, 0.2))

	# Vol de vie (Gantelets du Berserk) : même traitement qu'à l'attaque normale.
	if counter_damage > 0:
		for effect in defender.active_effects:
			if effect.grants_lifesteal:
				var healed = min(counter_damage, defender.max_hp - defender.current_hp)
				if healed > 0:
					defender.current_hp += healed
					spawn_floating_text(defender.position, "+%d (vol de vie)" % healed, Color(0.35, 0.9, 0.5))
				break

# ---------- Gestion de la mort d'une unité ----------

# Appelé automatiquement via le signal "died" émis par CombatUnit.
# Libère sa case et la retire de la file de tours pour éviter tout
# crash (référence à une unité détruite).
# Unités mortes pouvant être ressuscitées (Grâce du ciel, L'équilibre du cycle).
var _graveyard: Array = []
var _pending_resurrection = null

func get_graveyard_for_team(team: int) -> Array:
	return _graveyard.filter(func(u): return is_instance_valid(u) and u.team == team)

func _on_unit_died(unit: CombatUnit) -> void:
	if _cells.has(unit.hex_coord) and _cells[unit.hex_coord]["occupant"] == unit:
		_cells[unit.hex_coord]["occupant"] = null

	_all_units.erase(unit)

	# Cimetière : les personnages (pas les invocations) restent en mémoire
	# pour pouvoir être ressuscités (voir _resolve_resurrection).
	if not unit.is_summoned and not _graveyard.has(unit):
		unit.keep_corpse = true
		_graveyard.append(unit)

	_refresh_tanker_auras()

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
		unit.base_max_hp = stats.get("max_hp", unit.base_max_hp)
		unit.base_max_pm = stats.get("max_pm", unit.base_max_pm)
		unit.base_max_ea = stats.get("max_ea", unit.base_max_ea)
		unit.base_courage = stats.get("courage", unit.base_courage)
		unit.has_ambidextrie = stats.get("ambidextrie", false)
		unit.base_attack_stat = stats.get("attack", unit.base_attack_stat)
		unit.base_parade_stat = stats.get("parade", unit.base_parade_stat)
		unit.base_adresse_stat = stats.get("adresse", unit.base_adresse_stat)
		unit.base_force_stat = stats.get("force", unit.base_force_stat)
		unit.base_intelligence_stat = stats.get("intelligence", unit.base_intelligence_stat)
		unit.base_charisme_stat = stats.get("charisme", unit.base_charisme_stat)
		unit.base_chance_stat = stats.get("chance", unit.base_chance_stat)
		unit.spells = UnitDatabase.build_spells(template_name, unit.level)
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
		unit.base_courage = courage_override

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

	var placed_unit = _pending_placement_unit

	if not place_unit_at(placed_unit, coord):
		return

	# Si ce combat vient d'une rencontre, on synchronise les PV/EA de
	# l'unité du joueur avec ceux d'avant le combat (potions bues, etc.)
	# — doit se faire APRÈS place_unit_at() : c'est add_child() qui
	# déclenche _ready(), lequel initialise current_hp/current_ea au
	# maximum, donc on ne peut les corriger qu'une fois cette étape passée.
	if WorldManager.combat_from_encounter and placed_unit.team == CombatUnit.Team.PLAYER:
		placed_unit.current_hp = min(WorldManager.party_current_hp, placed_unit.max_hp)
		placed_unit.current_ea = min(WorldManager.party_current_ea, placed_unit.max_ea)
	elif TowerManager.run_active and placed_unit.team == CombatUnit.Team.PLAYER:
		TowerManager.apply_carried_state(placed_unit)

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

	# Quitter un corps à corps sans « Appel des renforts » (ADR) : chaque
	# ennemi au contact dont on s'éloigne tente automatiquement une attaque
	# imparable (ni parade ni esquive) sur nous.
	if not unit.has_skill("ADR"):
		_resolve_opportunity_attacks(unit, target_coord)
		if not is_instance_valid(unit) or unit.current_hp <= 0:
			return false

	_cells[unit.hex_coord]["occupant"] = null
	unit.hex_coord = target_coord
	unit.move_to_pixel(axial_to_pixel(target_coord))
	_cells[target_coord]["occupant"] = unit

	_refresh_tanker_auras()

	return true

# Attaques d'opportunité (voir move_unit) : chaque ennemi adjacent à la case
# de départ mais plus à la case d'arrivée, capable d'agir et armé au corps à
# corps, attaque une fois (jet de toucher normal, imparable).
func _resolve_opportunity_attacks(mover: CombatUnit, destination: Vector2i) -> void:
	for enemy in _all_units.duplicate():
		if not is_instance_valid(enemy) or enemy.team == mover.team or enemy.current_hp <= 0:
			continue
		if mover.current_hp <= 0:
			return
		if hex_distance(enemy.hex_coord, mover.hex_coord) != 1 or hex_distance(enemy.hex_coord, destination) <= 1:
			continue
		if enemy.stunned_turns_remaining > 0 or enemy.is_frozen or not can_interact(enemy, mover):
			continue
		if mover.is_untargetable:
			continue  # L'ennemi ne voit pas un invisible partir.
		var weapon = enemy.equipped_weapon
		if weapon == null or weapon.max_range > 1:
			continue
		spawn_floating_text(enemy.position, "Attaque d'opportunité !", Color(0.9, 0.5, 0.3))
		_resolve_weapon_attack(enemy, weapon.create_attack_spell(), mover, true)

# Aura du Méca Tanker : +1 Armure aux N alliés les plus proches (N selon le
# palier), tant que le Tanker est en vie. Recalculée à chaque déplacement,
# invocation ou mort — on retire toutes les auras puis on les repose.
func _refresh_tanker_auras() -> void:
	for u in _all_units:
		for e in u.active_effects.duplicate():
			if e.source_ref != null and e.effect_name.begins_with("Aura du Tanker"):
				u.remove_status_effect(e)
	for tanker in _all_units:
		if tanker.tanker_aura_count <= 0 or tanker.current_hp <= 0:
			continue
		var allies: Array = _get_team_including_self(tanker).filter(func(u): return u != tanker)
		allies.sort_custom(func(a, b): return hex_distance(tanker.hex_coord, a.hex_coord) < hex_distance(tanker.hex_coord, b.hex_coord))
		for i in range(min(tanker.tanker_aura_count, allies.size())):
			var aura := StatusEffect.new()
			aura.effect_name = "Aura du Tanker (+1 Armure)"
			aura.duration_remaining = -1
			aura.bonus_armure = 1
			aura.source_ref = tanker
			allies[i].add_status_effect(aura)

# ---------- Tour de l'infini : construction des unités de combat ----------

# Les aventuriers qui combattent à cet étage (les vivants), construits
# depuis TowerManager.team, dans l'ordre de l'équipe.
func _build_tower_units() -> Array:
	var units: Array = []
	for index in TowerManager.get_fighting_indices():
		units.append(_build_tower_unit(int(index)))
	return units

# Transforme un aventurier de la Tour en unité de combat. Seule la SPRITE
# (et ses animations) vient du Barbare, comme pour le combat de test ;
# tout le reste vient de l'aventurier : ses 6 caractéristiques, sa race,
# sa filière de métiers EXACTE (voir CombatUnit.forced_metier_chain), son
# niveau, et son équipement — arme, les 5 pièces d'armure + bouclier, et
# accessoires. Les sorts viennent ensuite de CombatUnit._ready(), d'après
# sa race et ses métiers, plus l'attaque de son arme.
func _build_tower_unit(index: int) -> CombatUnit:
	var character = TowerManager.team[index]
	var unit = build_unit(CombatUnit.Team.PLAYER, "Barbare")
	unit.unit_name = character.character_name

	# Ce que build_unit() venait de poser d'après le Barbare : on le remplace.
	unit.base_max_hp = TowerManager.ADVENTURER_BASE_HP
	unit.base_max_ea = TowerManager.ADVENTURER_BASE_EA
	unit.base_max_pm = TowerManager.ADVENTURER_BASE_PM
	unit.base_attack_stat = TowerManager.ADVENTURER_BASE_ATTACK
	unit.base_parade_stat = TowerManager.ADVENTURER_BASE_PARADE
	unit.has_ambidextrie = false
	unit.spells = []
	unit.off_hand_weapon = null
	unit.inventory_arrows = []
	unit.inventory_potions = []
	unit.inventory_weapons = []

	unit.base_courage = TowerManager.get_stat_value(index, "courage")
	unit.base_intelligence_stat = TowerManager.get_stat_value(index, "intelligence")
	unit.base_charisme_stat = TowerManager.get_stat_value(index, "charisme")
	unit.base_adresse_stat = TowerManager.get_stat_value(index, "adresse")
	unit.base_force_stat = TowerManager.get_stat_value(index, "force")
	unit.base_chance_stat = TowerManager.get_stat_value(index, "chance")

	# Équipement : copies (duplicate), pour que ce qui arrive à l'objet pendant
	# un combat ne déborde jamais sur l'équipement de l'aventurier.
	unit.equipped_weapon = character.equipped_weapon.duplicate() if character.equipped_weapon != null else null  # null : mains nues (voir CombatUnit._ready)
	# Seconde arme et Ambidextrie : celle de la filière complète (Célébrité
	# l'hérite du Prestidigitateur), que CombatUnit.has_skill ne remonte pas ;
	# le Pirate, lui, l'obtient dans CombatUnit._recalculate_stats.
	unit.off_hand_weapon = character.equipped_off_hand.duplicate() if character.equipped_off_hand != null else null
	unit.has_ambidextrie = TowerManager.has_ambidextrie(index)
	unit.equipped_armor = null
	unit.equipped_armor_pieces = []
	for piece in character.equipped_armor.values():
		unit.equipped_armor_pieces.append(piece.duplicate())
	unit.equipped_accessories = []
	for accessory in character.equipped_accessories:
		unit.equipped_accessories.append(accessory.duplicate())

	unit.equipped_race = RaceDatabase.build(character.race_name)
	unit.queue_redraw()
	var chain: Array = TowerManager.get_metier_chain_codes(index)  # niveau 1 -> le plus avancé
	if not chain.is_empty():
		unit.equipped_metier = MetierDatabase.build(str(chain.back()))
		var chain_top_first: Array = chain.duplicate()
		chain_top_first.reverse()
		unit.forced_metier_chain = chain_top_first
	unit.level = character.level
	unit.pretre_order = character.pretre_order

	unit.set_meta("tower_index", index)  # Pour retrouver l'aventurier à la fin de l'étage.
	return unit

# Construit un ennemi de la Tour d'après son gabarit (UnitDatabase, ou
# TowerData.ENEMIES). Au-delà du dernier étage défini, ses PV et ses dégâts
# augmentent (voir TowerFloors.get_stat_multiplier).
func _build_tower_enemy(template_name: String, floor_number: int) -> CombatUnit:
	var unit = build_unit(CombatUnit.Team.ENEMY, template_name)
	var template: Dictionary = UnitDatabase.get_base_stats(template_name)

	# Arme du catalogue (ex: "Dague d'artisan renommé") et ensembles de sorts
	# nommés (voir TowerPoc.build_spell_set).
	var catalog_weapon_name: String = str(template.get("catalog_weapon", ""))
	if catalog_weapon_name != "":
		var catalog_weapon: Weapon = _find_catalog_weapon(catalog_weapon_name)
		if catalog_weapon != null:
			unit.equipped_weapon = catalog_weapon
		else:
			push_warning("Tour : arme de catalogue introuvable '%s' (%s)." % [catalog_weapon_name, template_name])
	for set_id in template.get("spell_sets", []):
		for set_spell in TowerPoc.build_spell_set(str(set_id)):
			unit.spells.append(set_spell)
	unit.set_meta("tower_xp", int(template.get("xp", 0)))

	# Armure naturelle : un ennemi n'a pas d'armure à acheter, juste un total de PR.
	var natural_armor: int = int(template.get("armor", 0))
	if natural_armor > 0:
		var skin := Armor.new()
		skin.armor_name = "Armure naturelle"
		skin.bonus_armure = natural_armor
		unit.equipped_armor_pieces.append(skin)

	var multiplier: float = TowerFloors.get_stat_multiplier(floor_number)
	if multiplier > 1.0:
		unit.base_max_hp = int(round(unit.base_max_hp * multiplier))
		if unit.equipped_weapon != null:
			unit.equipped_weapon.damage = int(round(unit.equipped_weapon.damage * multiplier))
			if unit.equipped_weapon.dice_count > 0:
				var average: float = unit.equipped_weapon.dice_count * 3.5 + unit.equipped_weapon.dice_modifier
				unit.equipped_weapon.dice_modifier += int(round(average * (multiplier - 1.0)))
		for spell in unit.spells:
			spell.damage = int(round(spell.damage * multiplier))
	return unit

# Arme du catalogue d'armes par son nom (insensible à la casse).
func _find_catalog_weapon(weapon_name: String) -> Weapon:
	var wanted: String = weapon_name.strip_edges().to_lower()
	for data in WeaponCatalog.get_all():
		if str(data.get("name", "")).strip_edges().to_lower() == wanted:
			return ShopGenerator.build_weapon_from_data(data)
	return null

# Vrai si le métier `code` est accessible à une race dont `forbidden`
# liste les métiers interdits (voir Race.profession_restriction_codes) :
# ni lui, ni TOUS les ancêtres d'au moins une de ses filières
# (parent_codes) ne doivent être interdits — comme dans la Tour
# (TowerManager), où un métier ne s'obtient qu'en passant par toute sa
# filière (ex: Templier = Prêtre puis Paladin puis Templier).
func _metier_reachable(code: String, forbidden: Array, depth: int = 0) -> bool:
	if depth > 10 or forbidden.has(code):
		return false
	var m = MetierDatabase.build(code)
	if m == null:
		return false
	if m.parent_codes.is_empty():
		return true
	for parent_code in m.parent_codes:
		if _metier_reachable(parent_code, forbidden, depth + 1):
			return true
	return false

# Construit une unité de test : seule la SPRITE (et l'arme de base)
# reste celle du Barbare. Stats neutres (10 partout) ; race tirée au
# sort parmi TOUTES les races, puis métier tiré au sort parmi ceux que
# cette race n'a pas le droit d'ignorer (voir Race.
# profession_restriction_codes + _metier_reachable) — jamais une
# combinaison interdite par les données.
func _build_random_race_metier_unit(team: int, courage_override: int = -1) -> CombatUnit:
	var unit = build_unit(team, "Barbare", courage_override)  # Sprite/arme : le Barbare — PAS ses stats ni ses sorts (voir plus bas).

	# Stats NEUTRES (10 partout, la valeur par défaut d'un CombatUnit
	# sans aucun gabarit) plutôt que celles du Barbare, très marquées
	# (Force 16, Intelligence 6...) — écrase ce que build_unit() venait
	# de poser à partir du gabarit.
	unit.base_courage = 10
	unit.base_adresse_stat = 10
	unit.base_force_stat = 10
	unit.base_intelligence_stat = 10
	unit.base_charisme_stat = 10
	unit.base_chance_stat = 10
	if courage_override >= 0:
		unit.base_courage = courage_override

	# Vide les sorts du Barbare ("Bond") : pour des unités VRAIMENT
	# distinctes, chacune ne doit avoir que son sort d'attaque d'arme
	# (réinséré automatiquement par _ready(), voir plus bas) et les
	# sorts propres à SA race/SON métier — pas ceux d'un gabarit
	# partagé par les 6.
	unit.spells = []

	# Race : TOUTES possibles, aucun filtre.
	var race_names = RaceDatabase.list_all_race_names()
	var race = RaceDatabase.build(race_names[randi() % race_names.size()])
	unit.equipped_race = race
	unit.queue_redraw()

	# Métier : parmi ceux accessibles à CETTE race (lignée entière non
	# interdite). Reste sans métier si aucun ne convient (improbable).
	var forbidden: Array = race.profession_restriction_codes if race != null else []
	var metier_codes = MetierDatabase.list_all_metier_short_codes()
	metier_codes.shuffle()
	for code in metier_codes:
		if _metier_reachable(code, forbidden):
			unit.equipped_metier = MetierDatabase.build(code)
			break

	return unit

# Combat de test : 3 unités par camp, chacune avec une race ET un
# métier tirés au sort (vérifiés — voir _build_random_race_metier_unit),
# donc 6 unités VRAIMENT distinctes (stats neutres + sorts propres à
# chaque race/métier) — seule la sprite reste celle du Barbare pour
# toutes. Remplace l'ancien tirage depuis player_units/enemy_units
# (noms de template fixes).
func setup_starting_units() -> void:
	var player_cells = get_player_zone_cells()
	var enemy_cells = get_enemy_zone_cells()

	for i in range(min(3, player_cells.size())):
		var courage_override = player_courage[i] if i < player_courage.size() else -1
		var unit = _build_random_race_metier_unit(CombatUnit.Team.PLAYER, courage_override)
		place_unit_at(unit, player_cells[i])

	for i in range(min(3, enemy_cells.size())):
		var courage_override = enemy_courage[i] if i < enemy_courage.size() else -1
		var unit = _build_random_race_metier_unit(CombatUnit.Team.ENEMY, courage_override)
		place_unit_at(unit, enemy_cells[i])

# ---------- Rendu ----------

func _draw() -> void:
	# Précalculé une seule fois par frame (pas par case) : les cases que
	# toucherait un sort de Zone si on cliquait maintenant sur la case
	# survolée — voir plus bas dans la boucle.
	var zone_preview_cells: Array = []
	var zone_preview_anchor = null
	if _casting_spell != null and _casting_spell.target_mode == Spell.TargetMode.ZONE \
			and _hovered_coord != null and _spell_range_cells.has(_hovered_coord):
		zone_preview_anchor = _hovered_coord
		zone_preview_cells = _get_zone_cells(active_unit.hex_coord, _hovered_coord, _casting_spell)

	for coord in _cells.keys():
		var center = axial_to_pixel(coord)
		var fill = fill_color

		if not _cells[coord]["is_walkable"]:
			match _cells[coord].get("obstacle_type", ObstacleType.BASIC):
				ObstacleType.EAU:
					fill = water_obstacle_color
				ObstacleType.VIDE:
					fill = void_obstacle_color
				_:
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
				if _terrain_selection_cells.has(coord):
					fill = terrain_selection_color
				elif coord == zone_preview_anchor:
					# Ancre de la zone (la case foncée), posée sous le curseur.
					fill = zone_anchor_color
				elif zone_preview_cells.has(coord):
					# Aperçu de la forme et de l'orientation courantes du
					# sort autour de l'ancre — avant même de cliquer.
					fill = zone_preview_color
				elif _spell_range_cells.has(coord):
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
