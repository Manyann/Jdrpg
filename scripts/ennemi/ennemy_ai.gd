extends RefCounted
class_name EnemyAI

# ============================================================
# enemy_ai.gd — IA des unités ennemies (Tour de l'infini).
#
# Principe : l'IA joue EXACTEMENT comme le joueur, via les mêmes fonctions
# de HexGrid — get_reachable_cells + move_unit pour se déplacer (en
# dépensant des PM), enter_targeting_mode puis _handle_spell_target_click
# pour attaquer. Portée, ligne de vue, coût en EA et nombre d'actions par
# tour sont donc vérifiés par le jeu lui-même : aucune règle n'est
# réécrite ici, l'IA ne peut pas tricher.
#
# Comportement (volontairement simple, à enrichir) :
#  1. Elle regarde, pour chaque case où elle peut aller (PM disponibles) et
#     chaque ennemi, quelle attaque serait possible depuis cette case.
#  2. Elle choisit la meilleure : un coup qui TUE d'abord, puis le plus de
#     dégâts, en se déplaçant le moins possible ; un tireur préfère rester
#     loin. Elle va à cette case, puis attaque.
#  3. Si aucune attaque n'est possible ce tour-ci, elle se rapproche de
#     l'ennemi le plus proche (par le chemin réel, obstacles compris).
#
# Elle n'utilise que des attaques simples : l'attaque de son arme et les
# sorts de dégâts à cible unique. Soins, invocations, sorts à sélecteur,
# sorts de terrain... ne sont pas joués (voir _is_simple_attack).
# ============================================================

## Pause entre deux gestes de l'IA, pour que le joueur voie ce qui se passe.
const STEP_DELAY: float = 0.45

## Garde-fou : jamais plus de ce nombre de déplacements/actions par tour.
const MAX_ITERATIONS: int = 6

## Nombre maximum d'actions jouées par tour (2 avec l'Ambidextrie).
const MAX_ACTIONS: int = 3

# Joue le tour complet de `unit`. Coroutine : à appeler avec `await`. Ne
# termine PAS le tour (c'est TurnManager qui le fait ensuite).
static func play_turn(grid, unit, tree: SceneTree) -> void:
	await tree.create_timer(STEP_DELAY).timeout

	# Provocation ciblée (Doigt d'honneur) : ce tour-ci, seul son provocateur
	# est une cible valide ; chaque tour joué en consomme un.
	unit.forced_target_now = null
	if unit.taunt_turns_remaining > 0:
		if is_instance_valid(unit.taunt_source) and unit.taunt_source.current_hp > 0:
			unit.forced_target_now = unit.taunt_source
		unit.taunt_turns_remaining -= 1

	var actions_done := 0
	for iteration in range(MAX_ITERATIONS):
		if not _can_continue(grid, unit):
			return

		# Une fois qu'elle a attaqué, l'IA ne se déplace plus "pour rien".
		var plan: Dictionary = _choose_plan(grid, unit, actions_done == 0)
		if plan.is_empty():
			return

		if plan["destination"] != unit.hex_coord:
			if not _move(grid, unit, plan["destination"], int(plan["cost"])):
				return
			await tree.create_timer(STEP_DELAY).timeout
			if not _can_continue(grid, unit):
				return

		if plan["spell"] == null:
			return  # Elle s'est seulement rapprochée.

		if not _act(grid, unit, plan["spell"], plan["target"]):
			return
		actions_done += 1
		await tree.create_timer(STEP_DELAY * 1.5).timeout
		if actions_done >= MAX_ACTIONS:
			return

# Vrai tant que l'unité peut encore jouer : elle est vivante, c'est
# toujours son tour, et le combat n'est pas terminé.
static func _can_continue(grid, unit) -> bool:
	if not is_instance_valid(grid) or not is_instance_valid(unit):
		return false
	return unit.current_hp > 0 and not grid.combat_ended and grid.active_unit == unit

# ---------- Choix du plan ----------

# Meilleure suite de gestes : {"destination", "cost", "spell", "target"}
# ("spell" vaut null pour un simple déplacement), ou {} s'il n'y a rien à
# faire. `allow_pure_move` : autoriser de se déplacer sans attaquer.
static func _choose_plan(grid, unit, allow_pure_move: bool) -> Dictionary:
	var targets: Array = _get_targets(grid, unit)
	if targets.is_empty():
		return {}

	var spells: Array = _usable_attack_spells(unit)

	# Cases atteignables ce tour-ci (coût = nombre de PM), position actuelle comprise.
	var reachable: Dictionary = grid.get_reachable_cells(unit.hex_coord, unit.current_pm)
	var cells: Dictionary = {unit.hex_coord: 0}
	for coord in reachable:
		cells[coord] = int(reachable[coord])

	var best: Dictionary = {}
	var best_score: float = -INF
	for cell in cells:
		for target in targets:
			var distance: int = grid.hex_distance(cell, target.hex_coord)
			for spell in spells:
				if distance < spell.min_range or distance > spell.max_range:
					continue
				if not grid.has_line_of_sight(cell, target.hex_coord):
					continue
				var score: float = _score_attack(spell, target, distance, int(cells[cell]))
				if score > best_score:
					best_score = score
					best = {"destination": cell, "cost": int(cells[cell]), "spell": spell, "target": target}

	if not best.is_empty():
		return best
	if not allow_pure_move:
		return {}
	return _approach_plan(grid, unit, targets, cells)

# Valeur d'une attaque : un coup qui tue passe avant tout, puis les dégâts ;
# on retranche un peu pour chaque PM dépensé et pour les PV de la cible
# (à dégâts égaux, on finit le plus faible) ; un tireur gagne à rester loin.
static func _score_attack(spell, target, distance: int, move_cost: int) -> float:
	var damage: float = _estimate_damage(spell)
	var score: float = damage - 0.4 * float(move_cost) - 0.05 * float(target.current_hp)
	if damage >= float(target.current_hp):
		score += 1000.0
	if spell.max_range > 1:
		score += 0.3 * float(distance)
	return score

# Ennemis de cette unité qu'elle peut viser (vivants, pas invisibles).
static func _get_targets(grid, unit) -> Array:
	var targets: Array = []
	for other in grid.get_all_units():
		if other.team != unit.team and other.current_hp > 0 and not other.is_untargetable:
			targets.append(other)

	# Doigt d'honneur : la cible n'a d'yeux que pour son provocateur (s'il est
	# toujours visible).
	var forced = unit.forced_target_now
	if forced != null and is_instance_valid(forced) and forced.current_hp > 0 and not forced.is_untargetable:
		return [forced]

	# Provocation (Méca Tanker) : s'il y a des provocateurs, eux seuls sont
	# visés — l'IA les attaque, ou s'en rapproche si elle ne peut pas les
	# atteindre ce tour-ci.
	var taunters: Array = targets.filter(func(t): return t.is_taunting)
	return taunters if not taunters.is_empty() else targets

# Se rapprocher de l'ennemi le plus proche quand aucune attaque n'est
# possible : on choisit, parmi les cases atteignables, celle dont le CHEMIN
# jusqu'à lui est le plus court (obstacles pris en compte, contrairement à
# la distance à vol d'oiseau, qui bloquerait derrière un mur).
static func _approach_plan(grid, unit, targets: Array, cells: Dictionary) -> Dictionary:
	var nearest = targets[0]
	for target in targets:
		if grid.hex_distance(unit.hex_coord, target.hex_coord) < grid.hex_distance(unit.hex_coord, nearest.hex_coord):
			nearest = target

	var field: Dictionary = _distance_field(grid, nearest.hex_coord)
	var best_cell: Vector2i = unit.hex_coord
	var best_distance: int = int(field.get(unit.hex_coord, 9999))
	var best_cost: int = 0
	for cell in cells:
		var d: int = int(field.get(cell, 9999))
		var cost: int = int(cells[cell])
		# Strictement plus près que sur place ; à chemin égal, le moins cher en PM.
		if d < best_distance or (d == best_distance and best_cell != unit.hex_coord and cost < best_cost):
			best_cell = cell
			best_distance = d
			best_cost = cost

	if best_cell == unit.hex_coord:
		return {}  # Déjà au plus près : rien de mieux à faire.
	return {"destination": best_cell, "cost": int(cells[best_cell]), "spell": null, "target": nearest}

# Distance de marche (en cases) de chaque case praticable jusqu'à `source`,
# par un parcours en largeur. Les unités ne comptent pas comme obstacles :
# elles bougent, un mur non.
static func _distance_field(grid, source: Vector2i) -> Dictionary:
	var distance: Dictionary = {source: 0}
	var frontier: Array = [source]
	while not frontier.is_empty():
		var next_frontier: Array = []
		for coord in frontier:
			for direction in range(6):
				var neighbor: Vector2i = grid.hex_neighbor(coord, direction)
				if distance.has(neighbor) or not grid._cells.has(neighbor):
					continue
				if not grid._cells[neighbor]["is_walkable"]:
					continue
				distance[neighbor] = int(distance[coord]) + 1
				next_frontier.append(neighbor)
		frontier = next_frontier
	return distance

# ---------- Attaques disponibles ----------

# Attaques que l'IA sait jouer ET que l'unité peut lancer maintenant :
# action disponible ce tour, EA suffisante.
static func _usable_attack_spells(unit) -> Array:
	var usable: Array = []
	for spell in unit.spells:
		if not _is_simple_attack(spell):
			continue
		if not unit.can_perform_action(spell):
			continue
		if unit.current_ea < spell.get_effective_ea_cost():
			continue
		usable.append(spell)
	return usable

# Vrai pour l'attaque d'une arme et pour un sort de dégâts à cible unique,
# sans mécanisme particulier. Tout ce qui demande un sélecteur (coût en PV,
# en PA, en Rage ; Substitution), une incantation différée, une invocation,
# un sort de terrain, un coût initial ou en Gloire est laissé de côté : l'IA
# l'ignore plutôt que de risquer de bloquer le combat.
static func _is_simple_attack(spell) -> bool:
	if spell.is_heal or spell.is_summon or spell.cast_delay > 0:
		return false
	if spell.target_mode != Spell.TargetMode.SINGLE_ENEMY:
		return false
	if spell.is_initial_cost or spell.is_ev_cost_spell or spell.is_pa_cost_spell or spell.is_rage_cost_spell:
		return false
	if spell.is_prestidigitateur_substitution or spell.gloire_cost > 0:
		return false
	if spell.creates_obstacle_line or spell.creates_bridge_line or spell.removes_obstacle_type >= 0:
		return false
	return spell.is_weapon_attack or _estimate_damage(spell) > 0.0

# Dégâts moyens d'une attaque : la valeur fixe du sort, ou la moyenne de ses dés.
static func _estimate_damage(spell) -> float:
	var total: float = float(spell.damage)
	if total > 0.0:
		return total
	var dice = spell.get("dice_terms")
	if dice != null:
		for term in dice:
			total += float(term.get("count", 0)) * (float(term.get("sides", 0)) + 1.0) / 2.0 + float(term.get("modifier", 0))
	return total

# ---------- Gestes ----------

# Déplace l'unité en dépensant ses PM, comme le clic du joueur (voir
# HexGrid._unhandled_input) : move_unit ne fait que poser l'unité.
static func _move(grid, unit, destination: Vector2i, cost: int) -> bool:
	if not grid.move_unit(unit, destination):
		return false
	unit.current_pm -= cost
	grid.spawn_floating_text(unit.position, "-%d PM" % cost, Color(0.4, 0.75, 1.0))
	return true

# Lance `spell` sur `target` par le chemin du joueur : ouverture du ciblage
# (qui vérifie EA et action disponible), puis clic sur la case de la cible
# (qui vérifie portée et ligne de vue). Renvoie vrai si une action a bien été
# dépensée — c'est le compteur d'actions de l'unité qui fait foi.
static func _act(grid, unit, spell, target) -> bool:
	var actions_before: int = unit.actions_used_this_turn
	grid.enter_targeting_mode(spell)
	if grid._casting_spell == spell and grid._spell_range_cells.has(target.hex_coord):
		grid._handle_spell_target_click(target.hex_coord)
	if grid._casting_spell != null:
		grid.cancel_targeting_mode()  # Le sort n'est pas parti : on ne laisse pas un ciblage ouvert.
	return unit.actions_used_this_turn > actions_before
