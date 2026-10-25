extends RefCounted
class_name TowerFloors

# ============================================================
# tower_floors.gd — Logique des étages de la Tour de l'infini.
#
# Les DONNÉES (quels ennemis à quel étage) sont dans tower_data.gd, fichier
# généré par build_tower_data.py à partir des tableaux d'ennemis et d'étages.
# Ce fichier-ci ne contient que la logique : lire un étage, et prolonger la
# tour AU-DELÀ du dernier étage défini (elle est « infinie »).
#
# Prolongement (PROVISOIRE, à valider) : après le dernier étage défini,
# on reprend ses ennemis, on en ajoute un par étage supplémentaire (jusqu'à
# MAX_ENEMIES_PER_FLOOR), et on augmente leurs PV et leurs dégâts de
# BONUS_PER_EXTRA_FLOOR par étage supplémentaire.
# ============================================================

## Nombre d'ennemis au-delà duquel l'extrapolation n'en ajoute plus.
const MAX_ENEMIES_PER_FLOOR: int = 8

## Augmentation des PV et des dégâts des ennemis par étage au-delà du
## dernier étage défini (0.10 = +10 % par étage).
const BONUS_PER_EXTRA_FLOOR: float = 0.10

# Nombre d'étages définis dans tower_data.gd.
static func defined_floor_count() -> int:
	return _floors().size()

# Étages en vigueur : ceux du POC écrit à la main (TowerPoc) tant qu'il est
# activé, sinon ceux du fichier généré.
static func _floors() -> Array:
	return TowerPoc.FLOORS if TowerPoc.ENABLED else TowerData.FLOORS

# Entrée de tower_data.gd pour cet étage ({} si l'étage n'est pas défini).
static func _find_defined(floor_number: int) -> Dictionary:
	for entry in _floors():
		if int(entry["floor"]) == floor_number:
			return entry
	return {}

# Vrai si cet étage dépasse le dernier étage défini (donc prolongé).
static func is_extrapolated(floor_number: int) -> bool:
	return defined_floor_count() > 0 and floor_number > defined_floor_count()

# Étages au-delà du dernier étage défini (0 pour un étage défini).
static func extra_floors(floor_number: int) -> int:
	return maxi(0, floor_number - defined_floor_count())

# Titre de l'étage ("" s'il n'en a pas).
static func get_floor_name(floor_number: int) -> String:
	return str(_find_defined(floor_number).get("name", ""))

# Ennemis de cet étage : un nom par ennemi, répété autant de fois qu'il y
# en a. Au-delà du dernier étage défini : voir l'en-tête (prolongement).
static func get_floor_enemy_ids(floor_number: int) -> Array:
	var defined := _find_defined(floor_number)
	if not defined.is_empty():
		return Array(defined["enemies"]).duplicate()
	var count := defined_floor_count()
	if count == 0 or floor_number < 1:
		return []

	var base: Array = Array(_find_defined(count)["enemies"])
	var ids: Array = base.duplicate()
	var cap: int = maxi(MAX_ENEMIES_PER_FLOOR, base.size())
	for i in range(extra_floors(floor_number)):
		if ids.size() >= cap:
			break
		ids.append(base[i % base.size()])
	return ids

# Multiplicateur de PV et de dégâts des ennemis de cet étage : 1.0 pour un
# étage défini, puis +BONUS_PER_EXTRA_FLOOR par étage supplémentaire.
static func get_stat_multiplier(floor_number: int) -> float:
	return 1.0 + BONUS_PER_EXTRA_FLOOR * float(extra_floors(floor_number))

# Ennemis cités par un étage mais INCONNUS de UnitDatabase (ni gabarit, ni
# ennemi de tower_data.gd) : ils ne pourraient pas être construits.
static func find_unknown_enemies() -> Array:
	var unknown: Array = []
	for entry in _floors():
		for enemy_id in entry["enemies"]:
			if UnitDatabase._find_template(str(enemy_id)).is_empty() and not unknown.has(str(enemy_id)):
				unknown.append(str(enemy_id))
	return unknown

# Étage dont on lit la disposition : lui-même s'il est défini, sinon le
# dernier étage défini (la tour prolongée garde sa carte).
static func _layout_source(floor_number: int) -> Dictionary:
	var defined := _find_defined(floor_number)
	if not defined.is_empty():
		return defined
	return _find_defined(defined_floor_count())

# Cases d'obstacles de l'étage : {"obstacles", "water", "void"} (listes de Vector2i).
static func get_floor_layout(floor_number: int) -> Dictionary:
	var source := _layout_source(floor_number)
	return {
		"obstacles": Array(source.get("obstacles", [])),
		"water": Array(source.get("water", [])),
		"void": Array(source.get("void", [])),
	}

# Pièges ennemis de l'étage : ids de TrapDatabase, posés au hasard au sol.
static func get_floor_traps(floor_number: int) -> Array:
	return Array(_layout_source(floor_number).get("traps", []))

# Mode de placement de l'étage : "classic" (défaut) ou "ambush".
static func get_floor_mode(floor_number: int) -> String:
	return str(_layout_source(floor_number).get("mode", "classic"))

# XP versée à CHAQUE aventurier à la victoire : somme de l'XP des ennemis.
static func get_floor_xp(floor_number: int) -> int:
	var total := 0
	for enemy_id in get_floor_enemy_ids(floor_number):
		total += int(UnitDatabase._find_template(str(enemy_id)).get("xp", 0))
	return total
