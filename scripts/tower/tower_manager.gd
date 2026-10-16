extends Node

# ============================================================
# tower_manager.gd — Autoload (singleton), À AJOUTER dans Project >
# Project Settings > Autoload, même principe que WorldManager (qui
# reste totalement intact : ce fichier est un système SÉPARÉ,
# spécifique au mode "Tour de l'infini").
#
# Règles de création d'équipe :
# - 16 points au total, 1 point = 1 niveau de personnage, répartis
#   librement entre 1 et 16 personnages (somme des niveaux = 16 pile
#   pour pouvoir commencer).
# - Niveau 1 : une race (toutes disponibles, choisie avec les flèches
#   de la carte) ET un métier DE BASE (sans parent_codes). Les métiers
#   proposés dépendent de la race ET des caractéristiques :
#     * Race.profession_restriction_codes = métiers INTERDITS -> absents ;
#     * métiers IMPOSSIBLES pour cette race, JUGÉS AVEC LEUR FILIÈRE (le
#       minimum dépasse le plafond de la race, ou le coût cumulé avec
#       les parents choisis dépasse la réserve de points MAXIMALE
#       possible — niveau 10, Ranger compris —, voir _is_chain_possible)
#       -> absents ;
#     * les autres sont listés, GRISÉS avec ce qui leur manque tant que
#       les caractéristiques actuelles (Metier.prereqs) ne suffisent pas.
# - Caractéristiques : 6 stats qui PARTENT de 8 (1 pour la chance) et
#   19 points PAR PERSONNAGE à répartir au-dessus. Un MINIMUM de race
#   (Race.prereqs, "min") fait partir la stat à ce minimum, bloqué, et
#   l'écart avec la valeur par défaut est décompté des 19. Un MAXIMUM de
#   race ("max") plafonne la stat. Changer de race remet les
#   caractéristiques à leur valeur de départ. L'Humain commence avec 22
#   points au lieu de 19 (Race.bonus_stat_points).
# - Le NIVEAU encadre les caractéristiques : plafond de 13 au niveau 1,
#   puis aux niveaux 2, 5 et 8 on gagne 1 point à répartir ET la limite
#   monte de 1 (14, 15, 16). Certaines races échappent à ce
#   plafond (Race.level_cap_exempt_stats) : l'Ogre en Force, l'Humain
#   sur toutes ses caractéristiques. Le Ranger donne 1
#   point de plus (Metier.bonus_stat_points). Redescendre d'un niveau, ou
#   quitter le Ranger, est REFUSÉ tant que ça laisserait des points en
#   trop ou une stat au-dessus de la nouvelle limite.
# - Niveaux 4/7/10 : évolution de métier (un métier dont parent_codes
#   contient le métier du palier précédent, non interdit à la race, et
#   dont les prérequis de caractéristiques sont remplis — voir
#   get_evolution_choices() et EVOLUTIONS_REQUIRE_STATS). Les métiers à
#   parents multiples (Archange, fils de Compagnie du crépuscule, Légion
#   céleste ET Gardienne de l'aube) reconvergent naturellement, quelle
#   que soit la branche choisie au niveau 4. Si aucune évolution n'est
#   disponible à ce palier, rien n'est exigé.
# - Un choix déjà fait n'est jamais invalidé en silence : les boutons
#   +/- des caractéristiques se grisent s'ils casseraient un métier
#   choisi (get_stat_change_blocker).
# - Restrictions d'équipement : celles de la RACE + celles du métier LE PLUS
#   AVANCÉ (une évolution remplace celles de son parent), interprétées par
#   equipment_rules.gd. Cinq emplacements d'armure (casque, plastron,
#   brassières, jambières, bottes) plus le bouclier, à part. La boutique
#   n'offre que ce qui est permis ; un changement de race, de métier ou de
#   niveau qui rend un objet porté interdit le retire et le rembourse plein
#   tarif, avec un message. Les pièces OBLIGATOIRES d'un métier (casque et
#   bouclier du Gladiateur) rendent le personnage incomplet tant qu'elles
#   manquent (voir get_incomplete_reason).
# - 8000 PO pour acheter/équiper arme, armure, accessoires (voir
#   ShopGenerator.build_weapon_from_data & co. pour convertir les
#   dictionnaires des catalogues en objets utilisables).
#
# ============================================================

const TOTAL_POINTS: int = 16
const STARTING_GOLD: int = 8000
## Caractéristiques : chaque personnage part de valeurs PAR DÉFAUT (8
## partout, 1 pour la chance) et dispose de STAT_POINTS_TOTAL points à
## répartir en plus (indépendants du niveau). Une stat qui a un MINIMUM
## de race (Race.prereqs, type "min") part à ce minimum à la place, et
## les points qu'il représente au-dessus de la valeur par défaut sont
## déjà décomptés des 19 — voir le bloc "Caractéristiques" plus bas.
const STAT_DEFAULT_VALUE: int = 8
const STAT_DEFAULT_CHANCE: int = 1
const STAT_POINTS_TOTAL: int = 19

## Niveau maximum d'un personnage.
const MAX_LEVEL: int = 10

## Les évolutions (niveaux 4, 7, 10) sont-elles soumises aux prérequis de
## CARACTÉRISTIQUES de leur métier (Metier.prereqs) ? OUI (choix retenu) :
## pour évoluer il faut avoir les stats, donc monter de niveau pour gagner
## des points (niveaux 2, 5, 8) et relever le plafond.
## ATTENTION : avec 19 à 22 points au maximum, deux métiers restent hors de
## portée de TOUTES les races même au niveau 10 — l'Archange (39 points
## requis) et le Seigneur (23) — et sont donc masqués des listes. Mettre
## `false` supprime toute exigence de stats sur les évolutions (niveau +
## race + filière seulement), ce qui les rend atteignables : rien d'autre
## à changer.
const EVOLUTIONS_REQUIRE_STATS: bool = true

## Plafond d'une caractéristique au niveau 1. Chaque niveau de
## STAT_BONUS_LEVELS (2, 5, 8) l'augmente de 1 (14, 15, puis 16) ET donne
## 1 point de plus à répartir. Le plus haut minimum de race (13) tient
## pile dans ce plafond. Une race peut y échapper sur une stat : voir
## Race.level_cap_exempt_stats (l'Ogre, en Force).
const STAT_CAP_LEVEL_1: int = 13
const STAT_BONUS_LEVELS: Array = [2, 5, 8]

const STAT_KEYS: Array = ["courage", "intelligence", "charisme", "adresse", "force", "chance"]
const STAT_LABELS: Dictionary = {
	"courage": "Courage", "intelligence": "Intelligence", "charisme": "Charisme",
	"adresse": "Adresse", "force": "Force", "chance": "Chance",
}
const STAT_SHORT: Dictionary = {
	"courage": "COU", "intelligence": "INT", "charisme": "CHA",
	"adresse": "AD", "force": "FO", "chance": "CHN",
}

class TowerCharacter:
	var character_name: String = "Aventurier"
	var level: int = 1
	## XP gagnée pendant l'ascension en cours (compteur : ne donne pas de
	## niveau pour l'instant).
	var xp: int = 0
	var race_name: String = ""

	## Points répartis PAR LE JOUEUR au-dessus de la valeur de DÉPART de
	## la stat (valeur par défaut, ou minimum imposé par la race, voir
	## TowerManager.get_stat_baseline) — valeur = départ + ceci.
	var stat_points: Dictionary = {
		"courage": 0, "intelligence": 0, "charisme": 0,
		"adresse": 0, "force": 0, "chance": 0,
	}

	## Métier à chaque palier — "" si rien choisi (ou si aucune
	## évolution n'existe à ce palier pour ce personnage). Le métier
	## EFFECTIF est le plus haut palier non vide (voir get_current_metier_code()).
	var metier_code_l1: String = ""
	var metier_code_l4: String = ""
	var metier_code_l7: String = ""
	var metier_code_l10: String = ""

	## Ordre du Prêtre (sorts de l'Ordre choisi seulement) ; sans effet si le
	## personnage n'a pas le métier Prêtre.
	var pretre_order: String = "Ordre de l'harmonie"

	var equipped_weapon: Weapon = null

	## Arme de la SECONDE main : seulement pour un personnage qui peut combattre
	## à deux armes (Ambidextrie, ou Pirate avec une arme à feu et une arme de
	## corps à corps) — voir TowerManager.can_dual_wield.
	var equipped_off_hand: Weapon = null
	## Armure PAR EMPLACEMENT : "head", "chest", "arms", "legs", "feet" (les 5
	## pièces d'armure) et "shield" (le bouclier, à part) -> objet Armor.
	var equipped_armor: Dictionary = {}
	var equipped_accessories: Array = []  # Jusqu'à 2, même convention que WorldManager.

	## Entrée de catalogue de chaque objet équipé (name, category, weapon_type,
	## bonus_armure...) : nécessaire pour revérifier les restrictions quand la
	## race ou le métier change (Weapon ne stocke pas sa catégorie, et deux
	## armes de catégories différentes portent le même nom). Même ordre que
	## equipped_accessories pour les accessoires ; pour l'armure : par
	## emplacement, comme equipped_armor.
	var equipped_weapon_data: Dictionary = {}
	var equipped_off_hand_data: Dictionary = {}
	var equipped_armor_data: Dictionary = {}
	var equipped_accessories_data: Array = []

	func get_current_metier_code() -> String:
		if metier_code_l10 != "":
			return metier_code_l10
		if metier_code_l7 != "":
			return metier_code_l7
		if metier_code_l4 != "":
			return metier_code_l4
		return metier_code_l1

	## PO déjà engagés dans l'équipement de CE personnage — sert à
	## recréditer intégralement si on le retire de l'équipe (voir
	## TowerManager.remove_character).
	func get_gear_spent() -> int:
		var total = 0
		if equipped_weapon != null:
			total += equipped_weapon.price
		if equipped_off_hand != null:
			total += equipped_off_hand.price
		for piece in equipped_armor.values():
			if piece != null:
				total += piece.price
		for acc in equipped_accessories:
			if acc != null:
				total += acc.price
		return total

var team: Array = []  # Array[TowerCharacter]
var points_remaining: int = TOTAL_POINTS
var gold: int = STARTING_GOLD

func reset() -> void:
	team.clear()
	points_remaining = TOTAL_POINTS
	gold = STARTING_GOLD
	equipment_notice = ""
	run_active = false  # Revenir à l'écran de création abandonne toute ascension en cours.

# ---------- Gestion de l'équipe ----------

func add_character() -> TowerCharacter:
	if points_remaining < 1:
		return null
	var c := TowerCharacter.new()
	c.character_name = "Aventurier %d" % (team.size() + 1)
	c.race_name = RaceDatabase.list_all_race_names()[0]  # Les flèches de la carte font défiler les autres.
	points_remaining -= 1
	team.append(c)
	return c

# Retire le personnage et recrédite TOUT ce qui lui était attribué
# (ses niveaux en points, son équipement en or) — pas de perte sèche.
func remove_character(index: int) -> void:
	if index < 0 or index >= team.size():
		return
	var c = team[index]
	points_remaining += c.level
	gold += c.get_gear_spent()
	team.remove_at(index)

func can_level_up(index: int) -> bool:
	if index < 0 or index >= team.size():
		return false
	return points_remaining > 0 and team[index].level < MAX_LEVEL

func level_up(index: int) -> void:
	if not can_level_up(index):
		return
	team[index].level += 1
	points_remaining -= 1

func can_level_down(index: int) -> bool:
	return get_level_down_block_reason(index) == ""

# Pourquoi on ne peut PAS redescendre d'un niveau ("" = on peut). Le
# niveau perdu retire des points à répartir (niveaux 2/5/8) ET abaisse
# la limite des caractéristiques : on refuse tant que ça laisserait des
# points dépensés en trop, ou une stat au-dessus de la nouvelle limite
# — jamais de correction silencieuse.
func get_level_down_block_reason(index: int) -> String:
	if index < 0 or index >= team.size():
		return "Personnage introuvable"
	var c = team[index]
	if c.level <= 1:
		return "Niveau minimum"
	var new_level: int = c.level - 1

	# Les évolutions d'un palier au-dessus du nouveau niveau seront retirées
	# (voir level_down) : elles ne comptent plus dans les points du métier.
	var pool_after: int = _base_pool(c.race_name) + get_level_bonus_points(new_level) + _bonus_points_of_codes(_chain_codes(index, new_level))
	var missing: int = get_stat_points_spent(index) - pool_after
	if missing > 0:
		return "Retire d'abord %d point(s) de caractéristiques : le niveau %d en donne." % [missing, c.level]

	var cap_after: int = get_level_stat_cap(new_level)
	for stat in STAT_KEYS:
		if _is_level_cap_exempt(c.race_name, stat):
			continue
		if get_stat_value(index, stat) > cap_after:
			return "%s dépasse la limite du niveau %d (%d)." % [STAT_LABELS[stat], new_level, cap_after]
	return ""

# En redescendant SOUS un palier d'évolution, le choix fait à ce
# palier est oublié (il faudra le refaire si on remonte, possiblement
# différemment) — jamais d'évolution "fantôme" à un niveau qui ne la
# justifie plus.
func level_down(index: int) -> void:
	if not can_level_down(index):
		return
	var c = team[index]
	if c.level == 10:
		c.metier_code_l10 = ""
	elif c.level == 7:
		c.metier_code_l7 = ""
	elif c.level == 4:
		c.metier_code_l4 = ""
	c.level -= 1
	points_remaining += 1
	enforce_equipment_rules(index)  # Le métier le plus avancé a pu changer, donc ses restrictions.

# ---------- Race / Métier / Caractéristiques ----------

# Caches : MetierDatabase.build()/RaceDatabase.build() recréent un objet à
# chaque appel, et l'écran interroge ~4 listes de métiers par carte à
# chaque rafraîchissement. Objets utilisés en LECTURE SEULE ici.
var _metier_cache: Dictionary = {}
var _race_cache: Dictionary = {}

func _get_metier(code: String):
	if not _metier_cache.has(code):
		_metier_cache[code] = MetierDatabase.build(code)
	return _metier_cache[code]

func _get_race(race_name: String):
	if race_name == "":
		return null  # Évite l'avertissement "race inconnue" de RaceDatabase.build("").
	if not _race_cache.has(race_name):
		_race_cache[race_name] = RaceDatabase.build(race_name)
	return _race_cache[race_name]

# TOUTES les races sont disponibles (aucun filtre) — c'est le choix du
# métier qui dépend de la race, pas l'inverse.
func get_available_races() -> Array:
	return RaceDatabase.list_all_race_names()

# Change la race d'un cran dans la liste (delta = -1 ou +1, avec retour
# au début/à la fin) — flèches latérales de la carte. Un changement de
# race REMET LES CARACTÉRISTIQUES À ZÉRO (nouveaux minimums/maximums) et
# retire les métiers choisis devenus interdits ou injustifiés (voir
# revalidate_metiers).
func cycle_race(index: int, delta: int) -> void:
	if index < 0 or index >= team.size():
		return
	var names = get_available_races()
	if names.is_empty():
		return
	var c = team[index]
	var i = names.find(c.race_name)
	if i < 0:
		i = 0
	c.race_name = names[(i + delta + names.size()) % names.size()]
	# Valeurs de départ, minimums et maximums changent avec la race :
	# répartir de nouveau est la seule façon prévisible de rester
	# cohérent (et les flèches ne laissent aucun résidu en parcourant
	# les races).
	for stat in STAT_KEYS:
		c.stat_points[stat] = 0
	revalidate_metiers(index)
	enforce_equipment_rules(index)  # Nouvelles restrictions de race (et de métier si un choix a sauté).

# Vrai si `metier_code` n'est PAS interdit à `race_name` (voir
# Race.profession_restriction_codes).
func _is_metier_allowed(race_name: String, metier_code: String) -> bool:
	if race_name == "":
		return true
	var race = _get_race(race_name)
	if race == null:
		return true
	return not race.profession_restriction_codes.has(metier_code)

# ----- Caractéristiques -----
#
# Modèle : chaque stat PART d'une valeur de départ (8, ou 1 pour la
# chance) ; STAT_POINTS_TOTAL (19) points sont à répartir au-dessus. Si
# la race impose un MINIMUM sur une stat (Race.prereqs, type "min"),
# elle part à ce minimum à la place, on ne peut pas descendre dessous,
# et l'écart avec la valeur par défaut est DÉJÀ décompté des 19 (une
# Walkyrie, dont les minimums valent 17 points d'écart, n'en garde que
# 2 à répartir). Un MAXIMUM de race ("max") plafonne la stat. Au total
# c'est la même économie que 60 points avec des stats partant de 0
# (8×5 + 1 = 41 de départ, 60 - 41 = 19), départ déjà payé.
# `TowerCharacter.stat_points` ne contient que ce que le joueur a ajouté
# AU-DESSUS de la valeur de départ.

# Valeur par défaut d'une stat SANS minimum de race.
func get_stat_default(stat: String) -> int:
	return STAT_DEFAULT_CHANCE if stat == "chance" else STAT_DEFAULT_VALUE

# Minimum imposé par la race sur `stat` (0 s'il n'y en a pas).
func get_race_stat_floor(race_name: String, stat: String) -> int:
	var race = _get_race(race_name)
	if race == null:
		return 0
	var result := 0
	for req in race.prereqs:
		if req.get("stat", "") == stat and req.get("type", "min") == "min":
			result = maxi(result, int(req.get("value", 0)))
	return result

# Maximum imposé par la race sur `stat`, ou -1 s'il n'y en a pas.
func get_race_stat_cap(race_name: String, stat: String) -> int:
	var race = _get_race(race_name)
	if race == null:
		return -1
	var result := -1
	for req in race.prereqs:
		if req.get("stat", "") == stat and req.get("type", "min") == "max":
			var limit := int(req.get("value", 0))
			result = limit if result < 0 else mini(result, limit)
	return result

# Valeur de DÉPART de `stat` pour cette race : son minimum s'il y en a un
# (bloqué), sinon la valeur par défaut — sans jamais dépasser un
# éventuel maximum de race.
func get_stat_baseline(race_name: String, stat: String) -> int:
	var floor_value = get_race_stat_floor(race_name, stat)
	var start: int = floor_value if floor_value > 0 else get_stat_default(stat)
	var cap = get_race_stat_cap(race_name, stat)
	if cap >= 0:
		start = mini(start, cap)
	return start

# Valeur de la stat = valeur de départ + points répartis au-dessus.
func get_stat_value(index: int, stat: String) -> int:
	if index < 0 or index >= team.size():
		return 0
	var c = team[index]
	return get_stat_baseline(c.race_name, stat) + int(c.stat_points.get(stat, 0))

func get_stats(index: int) -> Dictionary:
	var result := {}
	for stat in STAT_KEYS:
		result[stat] = get_stat_value(index, stat)
	return result

# Points DÉJÀ utilisés sur les 19 : tout ce qui dépasse la valeur par
# défaut, minimums de race compris (ils sont décomptés).
func get_stat_points_spent(index: int) -> int:
	var total := 0
	for stat in STAT_KEYS:
		total += maxi(0, get_stat_value(index, stat) - get_stat_default(stat))
	return total

# ----- Niveau et métier : limites et points en plus -----

# Points à répartir en plus que donne la RACE (Race.bonus_stat_points —
# Humain : 3, donc 22 au lieu de 19 dès le niveau 1).
func get_race_bonus_points(race_name: String) -> int:
	var race = _get_race(race_name)
	if race == null:
		return 0
	return int(race.bonus_stat_points)

# Réserve de départ de cette race, avant points de niveau et de métier.
func _base_pool(race_name: String) -> int:
	return STAT_POINTS_TOTAL + get_race_bonus_points(race_name)

# Points à répartir en plus à ce niveau (1 aux niveaux 2, 5 et 8).
func get_level_bonus_points(level: int) -> int:
	var count := 0
	for bonus_level in STAT_BONUS_LEVELS:
		if level >= int(bonus_level):
			count += 1
	return count

# Plafond des caractéristiques à ce niveau : 13, puis 14 / 15 / 16.
func get_level_stat_cap(level: int) -> int:
	return STAT_CAP_LEVEL_1 + get_level_bonus_points(level)

# Plus petit niveau dont le plafond permet d'atteindre `value` (10 si
# aucun) — sert à dire "(niv. 5)" à côté d'un métier trop exigeant.
func get_level_needed_for_stat(value: int) -> int:
	for level in range(1, MAX_LEVEL + 1):
		if get_level_stat_cap(level) >= value:
			return level
	return MAX_LEVEL

# Vrai si cette race n'est PAS limitée sur `stat` par le niveau
# (Race.level_cap_exempt_stats : l'Ogre en Force).
func _is_level_cap_exempt(race_name: String, stat: String) -> bool:
	var race = _get_race(race_name)
	if race == null:
		return false
	return race.level_cap_exempt_stats.has(stat)

# Plafond de niveau applicable à `stat` pour CE personnage, ou -1 s'il
# n'y en a pas (race exemptée sur cette stat). Distinct du maximum propre
# à la race (get_race_stat_cap), qui s'applique en plus.
func get_stat_level_cap(index: int, stat: String) -> int:
	if index < 0 or index >= team.size():
		return -1
	var c = team[index]
	if _is_level_cap_exempt(c.race_name, stat):
		return -1
	return get_level_stat_cap(c.level)

# Vrai si les prérequis de caractéristiques du métier choisi au palier
# `tier` comptent : toujours pour le métier de base, pour les évolutions
# seulement si EVOLUTIONS_REQUIRE_STATS.
func _tier_requires_stats(tier: int) -> bool:
	return tier <= 1 or EVOLUTIONS_REQUIRE_STATS

# Code du métier choisi au palier `tier` (1, 4, 7 ou 10), "" s'il n'y en a pas.
func _code_at_tier(c, tier: int) -> String:
	match tier:
		1:
			return c.metier_code_l1
		4:
			return c.metier_code_l4
		7:
			return c.metier_code_l7
		10:
			return c.metier_code_l10
	return ""

# Codes des métiers choisis aux paliers ≤ `max_level` (la filière telle
# qu'elle serait à ce niveau).
func _chain_codes(index: int, max_level: int) -> Array:
	var c = team[index]
	var result: Array = []
	for tier in [1, 4, 7, 10]:
		if int(tier) <= max_level and _code_at_tier(c, int(tier)) != "":
			result.append(_code_at_tier(c, int(tier)))
	return result

# Points en plus que donnent ces métiers (Metier.bonus_stat_points —
# Ranger : 1).
func _bonus_points_of_codes(codes: Array) -> int:
	var total := 0
	for code in codes:
		var m = _get_metier(str(code))
		if m != null:
			total += int(m.bonus_stat_points)
	return total

# Points en plus donnés par la filière de métiers actuelle du personnage.
func get_metier_bonus_points(index: int) -> int:
	if index < 0 or index >= team.size():
		return 0
	return _bonus_points_of_codes(_chain_codes(index, MAX_LEVEL))

# Réserve TOTALE de points à répartir : 19 de base, plus ceux de la race
# (Humain : +3), +1 aux niveaux 2/5/8, et ceux que donne la filière de
# métiers (Ranger).
func get_stat_pool(index: int) -> int:
	if index < 0 or index >= team.size():
		return STAT_POINTS_TOTAL
	return _base_pool(team[index].race_name) + get_level_bonus_points(team[index].level) + get_metier_bonus_points(index)

# Détail lisible de la réserve, pour une infobulle.
func get_stat_pool_breakdown(index: int) -> String:
	var parts: Array = ["%d de base" % STAT_POINTS_TOTAL]
	var from_race := get_race_bonus_points(team[index].race_name)
	if from_race > 0:
		parts.append("%d de race" % from_race)
	var from_level := get_level_bonus_points(team[index].level)
	if from_level > 0:
		parts.append("%d de niveau" % from_level)
	var from_metier := get_metier_bonus_points(index)
	if from_metier > 0:
		parts.append("%d de métier" % from_metier)
	return " + ".join(parts)

# Points encore à répartir (affichés sur la carte).
func get_stat_points_unspent(index: int) -> int:
	return get_stat_pool(index) - get_stat_points_spent(index)

# Nom du premier métier DÉJÀ CHOISI qui deviendrait invalide si `stat`
# changeait de `delta` (-1 ou +1) — "" si aucun. Sert à griser les
# boutons +/- plutôt que d'invalider un choix en silence : baisser une
# stat sous le minimum d'un métier choisi, ou monter Force au-dessus du
# maximum d'un Artiste, est refusé avec l'explication.
func get_stat_change_blocker(index: int, stat: String, delta: int) -> String:
	if index < 0 or index >= team.size():
		return ""
	var c = team[index]
	var changed = get_stats(index)
	changed[stat] = int(changed[stat]) + delta
	for tier in [1, 4, 7, 10]:
		if not _tier_requires_stats(int(tier)):
			continue  # Une évolution n'a pas de prérequis de stats à protéger.
		var code = _code_at_tier(c, int(tier))
		if code == "":
			continue
		var m = _get_metier(code)
		if m != null and not _meets_prereqs(changed, m.prereqs):
			return m.metier_name
	return ""

# Pourquoi `stat` ne peut PAS monter ("" = elle peut) : plus de points,
# maximum de la race ou limite du niveau atteint, ou limite d'un métier
# déjà choisi.
func get_stat_increase_block_reason(index: int, stat: String) -> String:
	if index < 0 or index >= team.size():
		return "Personnage introuvable"
	if get_stat_points_unspent(index) <= 0:
		return "Plus aucun point à répartir"
	var cap = get_race_stat_cap(team[index].race_name, stat)
	if cap >= 0 and get_stat_value(index, stat) >= cap:
		return "Maximum imposé par la race : %d" % cap
	var level_cap = get_stat_level_cap(index, stat)
	if level_cap >= 0 and get_stat_value(index, stat) >= level_cap:
		return "Limite du niveau %d : %d" % [team[index].level, level_cap]
	var limited_by = get_stat_change_blocker(index, stat, 1)
	if limited_by != "":
		return "Dépasserait la limite de : %s" % limited_by
	return ""

# Pourquoi `stat` ne peut PAS baisser ("" = elle peut) : déjà à sa valeur
# de départ (minimum imposé par la race, ou valeur par défaut), ou
# nécessaire à un métier déjà choisi.
func get_stat_decrease_block_reason(index: int, stat: String) -> String:
	if index < 0 or index >= team.size():
		return "Personnage introuvable"
	var c = team[index]
	if int(c.stat_points.get(stat, 0)) <= 0:
		var floor_value = get_race_stat_floor(c.race_name, stat)
		if floor_value > 0:
			return "Minimum imposé par la race : %d" % floor_value
		return "Valeur de départ : %d" % get_stat_baseline(c.race_name, stat)
	var needed_by = get_stat_change_blocker(index, stat, -1)
	if needed_by != "":
		return "Nécessaire pour : %s" % needed_by
	return ""

func can_increase_stat(index: int, stat: String) -> bool:
	return get_stat_increase_block_reason(index, stat) == ""

func increase_stat(index: int, stat: String) -> void:
	if not can_increase_stat(index, stat):
		return
	var c = team[index]
	c.stat_points[stat] = int(c.stat_points.get(stat, 0)) + 1

func can_decrease_stat(index: int, stat: String) -> bool:
	return get_stat_decrease_block_reason(index, stat) == ""

func decrease_stat(index: int, stat: String) -> void:
	if not can_decrease_stat(index, stat):
		return
	var c = team[index]
	c.stat_points[stat] = int(c.stat_points.get(stat, 0)) - 1

# Métiers DÉJÀ CHOISIS avant le palier `threshold` (objets Metier, dans
# l'ordre de la filière) — la filière dont on cherche à évoluer.
func _chosen_ancestors(index: int, threshold: int) -> Array:
	var c = team[index]
	var codes: Array = []
	if threshold > 1:
		codes.append(c.metier_code_l1)
	if threshold > 4:
		codes.append(c.metier_code_l4)
	if threshold > 7:
		codes.append(c.metier_code_l7)
	var result: Array = []
	for code in codes:
		if code != "":
			var m = _get_metier(code)
			if m != null:
				result.append(m)
	return result

# Faux si cette FILIÈRE de métiers (`metiers` : les parents déjà choisis
# + le candidat) est IMPOSSIBLE à obtenir pour cette race, quoi que fasse
# le joueur : un minimum de métier au-dessus du plafond de la race
# (ex: INT ≥ 12 pour une race plafonnée à 10), un maximum de métier en
# dessous de la valeur de départ de la stat, ou un coût total en points
# (valeurs de départ de la race, relevées au plus haut minimum de TOUTE
# la filière) qui dépasse la réserve MAXIMALE possible (niveau 10, points
# de métier compris). Ces choix sont ABSENTS des
# listes (comme les interdits), pas grisés : les griser promettrait
# l'inatteignable. Juger la filière entière, et pas le seul candidat,
# compte avec si peu de points : sans ça une évolution possible seule
# mais pas avec son parent resterait grisée à jamais.
func _is_chain_possible(race_name: String, metiers: Array) -> bool:
	var target := {}
	for stat in STAT_KEYS:
		target[stat] = get_stat_baseline(race_name, stat)

	for metier in metiers:
		for req in metier.prereqs:
			if req.get("type", "min") != "min":
				continue
			var min_stat: String = req.get("stat", "")
			var min_value := int(req.get("value", 0))
			var cap = get_race_stat_cap(race_name, min_stat)
			if cap >= 0 and cap < min_value:
				return false
			# Plafond de NIVEAU : jugé au niveau maximum (un minimum de 15
			# est atteignable au niveau 5, il n'est pas "impossible").
			if not _is_level_cap_exempt(race_name, min_stat) and min_value > get_level_stat_cap(MAX_LEVEL):
				return false
			target[min_stat] = maxi(int(target.get(min_stat, 0)), min_value)

	for metier in metiers:
		for req in metier.prereqs:
			if req.get("type", "min") == "max":
				var max_stat: String = req.get("stat", "")
				if int(target.get(max_stat, 0)) > int(req.get("value", 0)):
					return false

	# Réserve MAXIMALE que cette filière pourrait avoir : niveau maximum
	# (+1 aux niveaux 2/5/8) et points que ses métiers donnent (Ranger).
	var max_pool: int = _base_pool(race_name) + get_level_bonus_points(MAX_LEVEL)
	for metier in metiers:
		max_pool += int(metier.bonus_stat_points)

	var cost := 0
	for stat in STAT_KEYS:
		cost += maxi(0, int(target[stat]) - get_stat_default(stat))
	return cost <= max_pool

# ----- Prérequis de métier -----

# Vrai si `stats` satisfait TOUS les prereqs ({"stat","type":"min"|"max","value"}).
func _meets_prereqs(stats: Dictionary, prereqs: Array) -> bool:
	for req in prereqs:
		var value = int(stats.get(req.get("stat", ""), 0))
		var required = int(req.get("value", 0))
		if req.get("type", "min") == "min":
			if value < required:
				return false
		elif value > required:
			return false
	return true

# Prérequis NON satisfaits, en texte court ("INT ≥ 13, AD ≥ 13") — vide
# si tout est satisfait. Affiché à côté des métiers grisés. Si `index`
# est donné et qu'un minimum dépasse le plafond de NIVEAU actuel du
# personnage, le niveau qui le permettrait est ajouté : "INT ≥ 15 (niv. 5)".
func get_unmet_prereq_text(stats: Dictionary, prereqs: Array, index: int = -1) -> String:
	var parts: Array = []
	for req in prereqs:
		var stat = req.get("stat", "")
		var value = int(stats.get(stat, 0))
		var required = int(req.get("value", 0))
		var is_min: bool = req.get("type", "min") == "min"
		if (is_min and value < required) or (not is_min and value > required):
			var sign_text = "≥" if is_min else "≤"
			var piece: String = "%s %s %d" % [STAT_SHORT.get(stat, stat), sign_text, required]
			if is_min and index >= 0:
				var level_cap = get_stat_level_cap(index, stat)
				if level_cap >= 0 and required > level_cap:
					piece += " (niv. %d)" % get_level_needed_for_stat(required)
			parts.append(piece)
	return ", ".join(parts)

# ----- Choix de métier -----

# Une entrée de liste déroulante : le métier, et s'il est DISPONIBLE avec
# les stats actuelles (sinon "missing" dit ce qu'il manque).
func _make_choice(code: String, stats: Dictionary, index: int) -> Dictionary:
	var m = _get_metier(code)
	if m == null:
		return {}
	var missing = get_unmet_prereq_text(stats, m.prereqs, index)
	return {"code": code, "name": m.metier_name, "available": missing == "", "missing": missing}

# Métiers DE BASE (parent_codes vide) proposés au niveau 1 : tous ceux
# que la race n'interdit pas, chacun marqué disponible ou non selon les
# caractéristiques actuelles. Les interdits à la race sont ABSENTS.
func get_base_metier_choices(index: int) -> Array:
	if index < 0 or index >= team.size():
		return []
	var c = team[index]
	var stats = get_stats(index)
	var result: Array = []
	for code in MetierDatabase.list_all_metier_short_codes():
		var m = _get_metier(code)
		if m != null and m.parent_codes.is_empty() and _is_metier_allowed(c.race_name, code) and _is_chain_possible(c.race_name, [m]):
			result.append(_make_choice(code, stats, index))
	return result

# Métier choisi au palier PRÉCÉDENT, dont on évolue au palier `threshold`.
func get_previous_tier_metier_code(index: int, threshold: int) -> String:
	var c = team[index]
	match threshold:
		4:
			return c.metier_code_l1
		7:
			return c.metier_code_l4
		10:
			return c.metier_code_l7
	return ""

# Évolutions possibles au palier `threshold` (4, 7 ou 10) : tout métier
# dont parent_codes contient le métier du palier précédent, non interdit
# à la race, chacun marqué disponible ou non. Vide si le palier
# précédent n'a pas de métier ou n'a aucune évolution.
func get_evolution_choices(index: int, threshold: int) -> Array:
	if index < 0 or index >= team.size():
		return []
	var base_code = get_previous_tier_metier_code(index, threshold)
	if base_code == "":
		return []
	var c = team[index]
	var stats = get_stats(index)
	var ancestors = _chosen_ancestors(index, threshold)
	var result: Array = []
	for code in MetierDatabase.list_all_metier_short_codes():
		var m = _get_metier(code)
		if m != null and m.parent_codes.has(base_code) and _is_metier_allowed(c.race_name, code):
			if not EVOLUTIONS_REQUIRE_STATS:
				# Niveau + race + filière seulement : toujours disponible.
				result.append({"code": code, "name": m.metier_name, "available": true, "missing": ""})
				continue
			var chain: Array = ancestors.duplicate()
			chain.append(m)
			if _is_chain_possible(c.race_name, chain):
				result.append(_make_choice(code, stats, index))
	return result

func _available_codes(choices: Array) -> Array:
	var codes: Array = []
	for choice in choices:
		if choice.get("available", false):
			codes.append(choice["code"])
	return codes

# Codes des métiers de base DISPONIBLES (race ET caractéristiques).
func get_base_metier_options(index: int) -> Array:
	return _available_codes(get_base_metier_choices(index))

# Codes des évolutions DISPONIBLES à ce palier (race ET caractéristiques).
# Vide = rien d'exigible à ce palier pour l'instant.
func get_evolution_options(index: int, threshold: int) -> Array:
	return _available_codes(get_evolution_choices(index, threshold))

# Pourquoi on ne peut PAS choisir `code` (ou vider le palier, code = "")
# au palier `threshold` ("" = on peut). Un métier qui donne des points en
# plus (Ranger) les retire en partant : refusé tant que ça laisserait des
# points dépensés en trop — jamais de correction silencieuse.
func get_set_metier_block_reason(index: int, threshold: int, code: String) -> String:
	if index < 0 or index >= team.size():
		return ""
	var c = team[index]
	# Filière résultante : paliers avant `threshold` inchangés, le nouveau
	# code, et plus rien au-dessus (voir set_metier).
	var codes: Array = []
	for tier in [1, 4, 7, 10]:
		if int(tier) < threshold:
			if _code_at_tier(c, int(tier)) != "":
				codes.append(_code_at_tier(c, int(tier)))
		elif int(tier) == threshold and code != "":
			codes.append(code)
	var pool_after: int = _base_pool(c.race_name) + get_level_bonus_points(c.level) + _bonus_points_of_codes(codes)
	var missing: int = get_stat_points_spent(index) - pool_after
	if missing > 0:
		return "Retire d'abord %d point(s) de caractéristiques : le métier actuel en donne en plus." % missing
	return ""

# Choisit le métier du palier `threshold` (1, 4, 7 ou 10) et efface tout
# ce qui en dépend plus haut dans l'arbre (une évolution choisie sous un
# autre métier n'aurait plus de sens). Renvoie false (et ne change rien)
# si get_set_metier_block_reason() refuse.
func set_metier(index: int, threshold: int, code: String) -> bool:
	if index < 0 or index >= team.size():
		return false
	if get_set_metier_block_reason(index, threshold, code) != "":
		return false
	var c = team[index]
	match threshold:
		1:
			c.metier_code_l1 = code
			c.metier_code_l4 = ""
			c.metier_code_l7 = ""
			c.metier_code_l10 = ""
		4:
			c.metier_code_l4 = code
			c.metier_code_l7 = ""
			c.metier_code_l10 = ""
		7:
			c.metier_code_l7 = code
			c.metier_code_l10 = ""
		10:
			c.metier_code_l10 = code
	enforce_equipment_rules(index)  # Le métier le plus avancé a changé, donc ses restrictions.
	return true

# Retire les choix de métier devenus invalides (race changée → métier
# interdit, prérequis non remplis, niveau trop bas...) ET tout ce qui en
# dépend : dès qu'un palier est invalide ou vide, tous les suivants
# sont effacés. Appelé après un changement de race.
func revalidate_metiers(index: int) -> void:
	if index < 0 or index >= team.size():
		return
	var c = team[index]
	var stats = get_stats(index)
	var codes: Array = [c.metier_code_l1, c.metier_code_l4, c.metier_code_l7, c.metier_code_l10]
	var thresholds: Array = [1, 4, 7, 10]
	var parent := ""
	var broken := false

	for i in range(4):
		var code: String = codes[i]
		if not broken and code == "":
			broken = true  # Un palier vide invalide tout ce qui suit.
		elif not broken:
			var m = _get_metier(code)
			var ok: bool = m != null
			if ok:
				ok = c.level >= int(thresholds[i])
			if ok:
				ok = _is_metier_allowed(c.race_name, code)
			if ok and _tier_requires_stats(int(thresholds[i])):
				ok = _meets_prereqs(stats, m.prereqs)
			if ok:
				ok = m.parent_codes.is_empty() if i == 0 else m.parent_codes.has(parent)
			if not ok:
				broken = true
		if broken:
			codes[i] = ""
		else:
			parent = code

	c.metier_code_l1 = codes[0]
	c.metier_code_l4 = codes[1]
	c.metier_code_l7 = codes[2]
	c.metier_code_l10 = codes[3]

# ---------- Validation ----------

# Ce qu'il manque encore à ce personnage ("" = rien, il est complet) : sa
# race et son métier de base, toute évolution DISPONIBLE à un palier déjà
# atteint (si aucune n'existe à ce palier, rien n'est exigé), et les
# pièces d'équipement OBLIGATOIRES de son métier (casque, bouclier...).
func get_incomplete_reason(index: int) -> String:
	if index < 0 or index >= team.size():
		return "personnage introuvable"
	var c = team[index]
	# Le métier (et chaque évolution) est FACULTATIF : sans métier, le
	# personnage n'a que sa race, et aucune évolution n'est alors possible.
	if c.race_name == "":
		return "choisis une race"
	var missing = get_missing_equipment(index)
	if not missing.is_empty():
		return "équipement obligatoire manquant : %s" % ", ".join(missing)
	return ""

# Vrai si ce personnage a fait tous ses choix (voir get_incomplete_reason).
func is_character_complete(index: int) -> bool:
	return get_incomplete_reason(index) == ""

# Prête à entrer dans la Tour : tous les points dépensés (pile 16),
# au moins un personnage, et chacun a fait tous ses choix.
func is_team_ready() -> bool:
	if team.is_empty() or points_remaining != 0:
		return false
	for i in range(team.size()):
		if not is_character_complete(i) or get_stat_points_unspent(i) < 0:
			return false
	return true

# ---------- Équipement ----------

# Type d'objet (clé "weapons" / "armors" / "accessories") de `item`.
func _slot_of(item) -> String:
	if item is Weapon:
		return "weapons"
	if item is Armor:
		return "armors"
	if item is Accessory:
		return "accessories"
	return ""

# Ordre dans lequel on retire des pièces quand un métier en autorise moins
# (« 3 pièces maximum », « armure complète » interdite) : les bottes d'abord,
# le plastron en dernier. Arbitraire, mais fixe et annoncé dans le message.
const ARMOR_REMOVAL_ORDER: Array = ["feet", "legs", "arms", "head", "chest"]

# Or récupéré en revendant ce que le personnage porte DÉJÀ à l'endroit où
# irait un objet de ce type — ce que buy_and_equip() revend automatiquement :
# l'arme pour une arme ; pour une armure, la pièce du MÊME emplacement
# (un casque remplace un casque), d'où `data` ; pour les accessoires (2
# emplacements), le plus ancien si les deux sont déjà pris.
func get_slot_refund(index: int, kind: String, data: Dictionary = {}, hand: String = "main") -> int:
	if index < 0 or index >= team.size():
		return 0
	var c = team[index]
	match kind:
		"weapons":
			if hand == "off_hand":
				return c.equipped_off_hand.price if c.equipped_off_hand != null else 0
			return c.equipped_weapon.price if c.equipped_weapon != null else 0
		"armors":
			var piece_slot: String = EquipmentRules.get_armor_slot(data)
			if piece_slot != "" and c.equipped_armor.has(piece_slot):
				return c.equipped_armor[piece_slot].price
		"accessories":
			if c.equipped_accessories.size() >= 2 and c.equipped_accessories[0] != null:
				return c.equipped_accessories[0].price
	return 0

# Vrai si le personnage `index` peut s'offrir un objet de `price` PO de ce
# type, EN COMPTANT la revente de ce qu'il remplace (un échange de 500 PO
# contre 550 PO ne coûte que 50 PO).
func can_afford(index: int, kind: String, price: int, data: Dictionary = {}, hand: String = "main") -> bool:
	return gold + get_slot_refund(index, kind, data, hand) >= price

# Achète et équipe `item` (Weapon/Armor/Accessory, déjà construit via
# ShopGenerator.build_X_from_data) sur le personnage `index`. `data` est
# l'entrée de catalogue dont `item` est tiré (voir TowerCharacter.
# equipped_*_data) ; pour une armure, elle donne l'emplacement. Refusé si
# une restriction de race ou de métier l'interdit (get_equipment_block_reason).
# Revend AUTOMATIQUEMENT (plein tarif, pas de décote) ce qu'il portait déjà
# au même endroit avant d'acheter le nouveau — jamais besoin de passer par
# un "vendre" séparé pour changer d'avis.
func buy_and_equip(index: int, item, data: Dictionary, hand: String = "main") -> bool:
	if index < 0 or index >= team.size() or item == null:
		return false
	var kind = _slot_of(item)
	if kind == "" or not can_afford(index, kind, item.price, data, hand):
		return false
	if get_equipment_block_reason(index, kind, data) != "":
		return false
	if kind == "weapons" and hand == "off_hand" and get_off_hand_block_reason(index, data) != "":
		return false

	var c = team[index]
	gold += get_slot_refund(index, kind, data, hand)
	match kind:
		"weapons":
			if hand == "off_hand":
				c.equipped_off_hand = item
				c.equipped_off_hand_data = data
			else:
				c.equipped_weapon = item
				c.equipped_weapon_data = data
		"armors":
			var piece_slot: String = EquipmentRules.get_armor_slot(data)
			c.equipped_armor[piece_slot] = item
			c.equipped_armor_data[piece_slot] = data
		"accessories":
			if c.equipped_accessories.size() >= 2:
				c.equipped_accessories.remove_at(0)
				c.equipped_accessories_data.remove_at(0)
			c.equipped_accessories.append(item)
			c.equipped_accessories_data.append(data)

	gold -= item.price
	if kind == "weapons":
		# Changer l'arme principale peut rendre la seconde invalide (Pirate : il
		# faut une arme à feu ET une arme de corps à corps).
		enforce_equipment_rules(index)
	return true

# ---------- Seconde arme (Ambidextrie) ----------
#
# Un personnage qui a l'Ambidextrie peut porter une arme dans chaque main et
# attaquer deux fois par tour avec ses armes. L'Ambidextrie vient de sa race
# (Elfe noir, Homme des sables, Samurai), de l'un de ses métiers (Templier,
# Assassin, Ninja, Prestidigitateur, Seigneur, Berzerk, Maître d'armes), et se
# transmet DANS LA FILIÈRE : Célébrité, évolution du Prestidigitateur, l'a
# aussi. Le Pirate peut porter une arme à feu et une arme de corps à corps
# sans Ambidextrie (voir CombatUnit._recalculate_stats).

# Vrai si ce personnage a l'Ambidextrie (race ou n'importe quel métier de sa filière).
func has_ambidextrie(index: int) -> bool:
	if index < 0 or index >= team.size():
		return false
	var race = _get_race(team[index].race_name)
	if race != null:
		for raw in race.inherited_skill_codes:
			if str(raw).rstrip("*") == "AM":
				return true
	for code in _chain_codes(index, MAX_LEVEL):
		var m = _get_metier(str(code))
		if m != null:
			for raw in m.inherited_skill_codes:
				if str(raw).rstrip("*") == "AM":
					return true
	return false

func _is_pirate(index: int) -> bool:
	for code in _chain_codes(index, MAX_LEVEL):
		var m = _get_metier(str(code))
		if m != null and m.metier_name == "Pirate":
			return true
	return false

# Vrai si la boutique doit proposer une seconde main à ce personnage.
func can_dual_wield(index: int) -> bool:
	return has_ambidextrie(index) or _is_pirate(index)

# Arme à feu : même critère que CombatUnit._recalculate_stats (nom en "Pistolet...").
func _is_firearm(data: Dictionary) -> bool:
	return str(data.get("name", "")).begins_with("Pistolet")

# Pourquoi ce personnage ne peut PAS mettre `data` dans sa seconde main ("" =
# il peut). Les restrictions de race et de métier, elles, s'appliquent aux
# deux mains (voir get_equipment_block_reason).
func get_off_hand_block_reason(index: int, data: Dictionary) -> String:
	if index < 0 or index >= team.size():
		return "Personnage introuvable"
	if has_ambidextrie(index):
		return ""
	if not _is_pirate(index):
		return "Il faut l'Ambidextrie pour porter une seconde arme"
	var c = team[index]
	if c.equipped_weapon == null:
		return "Pirate : choisis d'abord l'arme de la main principale"
	if _is_firearm(c.equipped_weapon_data) == _is_firearm(data):
		return "Pirate : une arme à feu ET une arme de corps à corps"
	return ""

# Pourquoi la seconde arme ACTUELLE n'est plus tenable ("" = elle l'est) :
# Ambidextrie perdue (changement de race ou de métier), ou combinaison de
# Pirate rompue (on a changé l'arme principale).
func _off_hand_keep_reason(index: int) -> String:
	var c = team[index]
	if c.equipped_off_hand == null or has_ambidextrie(index):
		return ""
	if not _is_pirate(index):
		return "Ambidextrie perdue"
	if c.equipped_weapon == null or _is_firearm(c.equipped_weapon_data) == _is_firearm(c.equipped_off_hand_data):
		return "Pirate : une arme à feu ET une arme de corps à corps"
	return ""

func _unequip_off_hand(c, reason: String) -> String:
	var label: String = "%s (%s)" % [c.equipped_off_hand.weapon_name, reason]
	gold += c.equipped_off_hand.price
	c.equipped_off_hand = null
	c.equipped_off_hand_data = {}
	return label

# ---------- Restrictions d'équipement (races et métiers) ----------
#
# Race.equipment_restrictions / Metier.equipment_restrictions sont du texte
# libre, interprété par EquipmentRules (equipment_rules.gd). Celles d'un
# personnage = celles de sa RACE + celles de son métier LE PLUS AVANCÉ : une
# évolution REMPLACE celles de son parent.

## Ce que les règles ont retiré au dernier changement (race, métier, niveau)
## — lu puis vidé par l'écran (take_equipment_notice).
var equipment_notice: String = ""

func take_equipment_notice() -> String:
	var notice := equipment_notice
	equipment_notice = ""
	return notice

# Restrictions en vigueur pour ce personnage : [{"text", "source"}].
func get_equipment_restrictions(index: int) -> Array:
	var entries: Array = []
	if index < 0 or index >= team.size():
		return entries
	var c = team[index]
	var race = _get_race(c.race_name)
	if race != null:
		for text in race.equipment_restrictions:
			entries.append({"text": str(text), "source": c.race_name})
	var codes = _chain_codes(index, MAX_LEVEL)
	if not codes.is_empty():
		var m = _get_metier(str(codes.back()))
		if m != null:
			for text in m.equipment_restrictions:
				entries.append({"text": str(text), "source": m.metier_name})
	return entries

func _pr_of(data: Dictionary) -> int:
	return int(data.get("bonus_armure", 0))

# PR total porté : toutes les pièces d'armure, le bouclier et les accessoires.
func _total_pr(c) -> int:
	var total := 0
	for piece_data in c.equipped_armor_data.values():
		total += _pr_of(piece_data)
	for accessory_data in c.equipped_accessories_data:
		total += _pr_of(accessory_data)
	return total

# Nombre de pièces d'armure portées sur les 5 emplacements (bouclier exclu),
# sans compter `except_slot` (celui qu'on s'apprête à remplacer).
func _filled_pieces(c, except_slot: String = "") -> int:
	var count := 0
	for piece_slot in EquipmentRules.ARMOR_SLOTS:
		if piece_slot != except_slot and c.equipped_armor.has(piece_slot):
			count += 1
	return count

# Ce que porte le RESTE de l'équipement si on achetait cet objet (pour les
# plafonds « N PR Max » et « N pièces maximum ») : une pièce remplace celle
# du même emplacement, un accessoire remplace le plus ancien quand les deux
# emplacements sont pris.
func _context_for(c, kind: String, data: Dictionary) -> Dictionary:
	var context := {"other_pr": 0, "other_pieces": 0}
	if kind == "armors":
		var piece_slot: String = EquipmentRules.get_armor_slot(data)
		var replaced_pr: int = _pr_of(c.equipped_armor_data[piece_slot]) if c.equipped_armor_data.has(piece_slot) else 0
		context["other_pr"] = _total_pr(c) - replaced_pr
		context["other_pieces"] = _filled_pieces(c, piece_slot)
	elif kind == "accessories":
		var replaced_pr: int = _pr_of(c.equipped_accessories_data[0]) if c.equipped_accessories_data.size() >= 2 else 0
		context["other_pr"] = _total_pr(c) - replaced_pr
	return context

# Pourquoi ce personnage ne peut PAS équiper cet objet ("" = il peut).
# `kind` : "weapons", "armors" ou "accessories" ; `data` : entrée du catalogue.
func get_equipment_block_reason(index: int, kind: String, data: Dictionary) -> String:
	if index < 0 or index >= team.size():
		return ""
	return EquipmentRules.get_block_reason(kind, data, get_equipment_restrictions(index), _context_for(team[index], kind, data))

func _unequip_weapon(c, reason: String) -> String:
	var label: String = "%s (%s)" % [c.equipped_weapon.weapon_name, reason]
	gold += c.equipped_weapon.price
	c.equipped_weapon = null
	c.equipped_weapon_data = {}
	return label

func _unequip_armor_piece(c, piece_slot: String, reason: String) -> String:
	var label: String = "%s (%s)" % [c.equipped_armor[piece_slot].armor_name, reason]
	gold += c.equipped_armor[piece_slot].price
	c.equipped_armor.erase(piece_slot)
	c.equipped_armor_data.erase(piece_slot)
	return label

func _unequip_accessory(c, accessory_index: int, reason: String) -> String:
	var accessory = c.equipped_accessories[accessory_index]
	var label: String = "%s (%s)" % [accessory.accessory_name, reason]
	gold += accessory.price
	c.equipped_accessories.remove_at(accessory_index)
	c.equipped_accessories_data.remove_at(accessory_index)
	return label

# Retire à ce personnage tout ce que ses restrictions actuelles interdisent
# (après un changement de race, de métier ou de niveau), REMBOURSE plein
# tarif (jamais de perte sèche), et le signale dans equipment_notice. Dans
# l'ordre : les objets interdits un à un ; les pièces d'armure en trop
# (voir ARMOR_REMOVAL_ORDER) ; puis le plafond de PR total, en retirant la
# pièce qui porte le plus de PR, puis les accessoires qui en portent.
func enforce_equipment_rules(index: int) -> void:
	if index < 0 or index >= team.size():
		return
	var c = team[index]
	var entries = get_equipment_restrictions(index)
	var gold_before: int = gold
	var removed: Array = []

	if c.equipped_weapon != null:
		var weapon_reason = EquipmentRules.get_block_reason("weapons", c.equipped_weapon_data, entries)
		if weapon_reason != "":
			removed.append(_unequip_weapon(c, weapon_reason))
	if c.equipped_off_hand != null:
		var off_hand_reason: String = _off_hand_keep_reason(index)
		if off_hand_reason == "":
			off_hand_reason = EquipmentRules.get_block_reason("weapons", c.equipped_off_hand_data, entries)
		if off_hand_reason != "":
			removed.append(_unequip_off_hand(c, off_hand_reason))
	for piece_slot in c.equipped_armor.keys():
		var armor_reason = EquipmentRules.get_block_reason("armors", c.equipped_armor_data[piece_slot], entries)
		if armor_reason != "":
			removed.append(_unequip_armor_piece(c, piece_slot, armor_reason))
	var i: int = c.equipped_accessories.size() - 1
	while i >= 0:
		var accessory_reason = EquipmentRules.get_block_reason("accessories", c.equipped_accessories_data[i], entries)
		if accessory_reason != "":
			removed.append(_unequip_accessory(c, i, accessory_reason))
		i -= 1

	var max_pieces: int = EquipmentRules.get_max_pieces(entries)
	if max_pieces >= 0:
		for piece_slot in ARMOR_REMOVAL_ORDER:
			if _filled_pieces(c) <= max_pieces:
				break
			if c.equipped_armor.has(piece_slot):
				removed.append(_unequip_armor_piece(c, piece_slot, "%d pièce(s) d'armure au plus" % max_pieces))

	var pr_cap: int = EquipmentRules.get_pr_cap(entries)
	if pr_cap >= 0:
		var guard := 0
		while _total_pr(c) > pr_cap and guard < 16:
			guard += 1
			var worst_slot := ""
			var worst_pr := 0
			for piece_slot in c.equipped_armor_data.keys():
				if _pr_of(c.equipped_armor_data[piece_slot]) > worst_pr:
					worst_pr = _pr_of(c.equipped_armor_data[piece_slot])
					worst_slot = piece_slot
			if worst_slot != "":
				removed.append(_unequip_armor_piece(c, worst_slot, "PR total au-dessus de %d" % pr_cap))
				continue
			var removed_accessory := false
			for j in range(c.equipped_accessories.size()):
				if _pr_of(c.equipped_accessories_data[j]) > 0:
					removed.append(_unequip_accessory(c, j, "PR total au-dessus de %d" % pr_cap))
					removed_accessory = true
					break
			if not removed_accessory:
				break

	if removed.is_empty():
		return
	var message: String = "%s : %s retiré(s) (%d PO remboursés)." % [c.character_name, ", ".join(removed), gold - gold_before]
	equipment_notice = message if equipment_notice == "" else equipment_notice + " " + message

# Pièces d'équipement OBLIGATOIRES (« Casque obligatoire », « Bouclier
# obligatoire ») que ce personnage ne porte pas encore : libellés
# « Casque (Gladiateur) ». Une obligation IMPOSSIBLE à satisfaire — tout ce
# qui pourrait la remplir est interdit à ce personnage (un Barbare, dont la
# race interdit les boucliers, devenu Gladiateur) — est levée : l'interdiction
# l'emporte, sinon il resterait incomplet pour toujours.
func get_missing_equipment(index: int) -> Array:
	var labels: Array = []
	if index < 0 or index >= team.size():
		return labels
	var c = team[index]
	var entries = get_equipment_restrictions(index)
	for requirement in EquipmentRules.get_unmet_requirements(entries, c.equipped_armor_data):
		if not _requirement_is_satisfiable(entries, requirement):
			continue
		var label: String = "%s (%s)" % [requirement["label"], requirement["source"]]
		if not labels.has(label):
			labels.append(label)
	return labels

# Vrai s'il existe au moins une pièce du catalogue qui remplirait cette
# obligation sans être interdite par ces restrictions.
func _requirement_is_satisfiable(entries: Array, requirement: Dictionary) -> bool:
	var prefix: String = str(requirement["name_prefix"])
	for data in ArmorCatalog.get_all():
		if EquipmentRules.get_armor_slot(data) != str(requirement["slot"]):
			continue
		if prefix != "" and not str(data.get("name", "")).begins_with(prefix):
			continue
		if EquipmentRules.get_block_reason("armors", data, entries) == "":
			return true
	return false

# Vérification des données : textes de restriction (races ET métiers) qui
# n'ont AUCUNE règle dans EquipmentRules.RULES — à compléter si la liste
# n'est pas vide. Un texte absent ne serait sinon jamais appliqué.
func get_unmapped_equipment_restrictions() -> Array:
	var texts: Array = []
	for race_name in RaceDatabase.list_all_race_names():
		var race = _get_race(race_name)
		if race != null:
			texts.append_array(race.equipment_restrictions)
	for code in MetierDatabase.list_all_metier_short_codes():
		var m = _get_metier(code)
		if m != null:
			texts.append_array(m.equipment_restrictions)
	return EquipmentRules.find_unmapped(texts)

# ============================================================
# ---------- Ascension : la Tour elle-même ----------
#
# Une ascension enchaîne des combats dans la scène de combat existante, un
# par étage. Les aventuriers de `team` y sont reconstruits à chaque étage
# (voir HexGrid._build_tower_unit) ; les ennemis viennent de tower_data.gd
# (voir TowerFloors) ; ils sont pilotés par l'IA (voir EnemyAI).
# ============================================================

## Chemin de la scène de création d'équipe, où l'on revient à la fin d'une
## ascension. ⚠️ À AJUSTER si ta scène est ailleurs (même principe que
## WorldManager.combat_scene_path, qui donne la scène de combat).
var team_select_scene_path: String = "res://scenes/tower_team_select.tscn"

## Valeurs de départ d'un aventurier EN COMBAT : la création d'équipe ne fixe
## que les 6 caractéristiques, pas ces chiffres. Ce sont les valeurs par
## défaut d'une CombatUnit. À AJUSTER pour l'équilibrage (PV, EA, PM, AT, PRD
## sont ensuite augmentés par la race, le métier et l'équipement).
const ADVENTURER_BASE_HP: int = 50
const ADVENTURER_BASE_EA: int = 6
const ADVENTURER_BASE_PM: int = 3
const ADVENTURER_BASE_ATTACK: int = 12
const ADVENTURER_BASE_PARADE: int = 8

## Ordre de Prêtre donné à un aventurier Prêtre : l'écran de création ne le
## demande pas encore (à ajouter).
const DEFAULT_PRETRE_ORDER: String = "Ordre de l'harmonie"

## Récupération entre deux étages (PROVISOIRE, à valider) : tout le monde
## repart en pleine forme, y compris les aventuriers tombés. La difficulté
## vient donc des ennemis, pas de l'usure.
const SURVIVOR_HEAL_PERCENT: int = 100   # PV rendus aux survivants (en % de leur max)
const EA_RESTORE_PERCENT: int = 100      # EA rendue aux survivants (en % de leur max)
const REVIVE_DEAD: bool = true           # false : un aventurier tombé est perdu pour le reste de l'ascension
const REVIVED_HP_PERCENT: int = 100      # PV d'un aventurier ramené à la vie

## Placement des aventuriers au début de chaque étage. false : le joueur les
## pose lui-même, un par un, dans sa zone (les ennemis, eux, sont toujours
## placés automatiquement) ; true : placement automatique dans l'ordre de l'équipe.
const AUTO_PLACE_PLAYER_UNITS: bool = false

var run_active: bool = false
var current_floor: int = 1
var floors_cleared: int = 0

## Étages franchis lors de la DERNIÈRE ascension terminée (-1 : aucune).
## Conservé quand on revient à l'écran de création, pour l'afficher.
var last_run_floors_cleared: int = -1

# Par aventurier (clé = index dans `team`) : {"alive": bool, "hp": fraction
# de ses PV max, "ea": fraction de son EA max} avec laquelle il aborde
# l'étage courant.
var _run_state: Dictionary = {}

# Codes des métiers choisis par cet aventurier, du métier de base (niveau 1)
# vers le plus avancé.
func get_metier_chain_codes(index: int) -> Array:
	if index < 0 or index >= team.size():
		return []
	return _chain_codes(index, MAX_LEVEL)

# Vrai si l'aventurier a le métier Prêtre (code "PR") dans sa filière.
func has_pretre(index: int) -> bool:
	return get_metier_chain_codes(index).has("PR")

func set_pretre_order(index: int, order: String) -> void:
	if index >= 0 and index < team.size():
		team[index].pretre_order = order

# Démarre l'ascension : étage 1, tout le monde en forme, puis charge la
# scène de combat. Renvoie "" si tout va bien, sinon une explication à
# afficher au joueur (rien n'est alors démarré).
func start_run() -> String:
	if not is_team_ready():
		return "L'équipe n'est pas prête."
	if TowerFloors.defined_floor_count() == 0:
		return "Aucun étage n'est défini (tower_data.gd est vide)."
	var unknown: Array = TowerFloors.find_unknown_enemies()
	if not unknown.is_empty():
		return "Ennemis inconnus dans les étages : %s." % ", ".join(unknown)

	run_active = true
	current_floor = 1
	floors_cleared = 0
	for c in team:
		c.xp = 0
	_run_state = {}
	for i in range(team.size()):
		_run_state[i] = {"alive": true, "hp": 1.0, "ea": 1.0}
	return _enter_current_floor()

# Charge la scène de combat pour l'étage courant (HexGrid et
# PlacementManager lisent run_active/current_floor au chargement).
func _enter_current_floor() -> String:
	var path: String = WorldManager.combat_scene_path
	var error: int = get_tree().change_scene_to_file(path)
	if error != OK:
		run_active = false
		return "Impossible de charger la scène de combat « %s » (erreur %d) : vérifie WorldManager.combat_scene_path." % [path, error]
	return ""

# Ennemis de l'étage courant (voir TowerFloors).
func get_floor_enemy_ids() -> Array:
	return TowerFloors.get_floor_enemy_ids(current_floor)

# Indices des aventuriers qui combattent à cet étage (les vivants).
func get_fighting_indices() -> Array:
	var indices: Array = []
	for i in range(team.size()):
		if _run_state.get(i, {}).get("alive", true):
			indices.append(i)
	return indices

# Applique à une unité fraîchement placée les PV/EA avec lesquels son
# aventurier aborde l'étage (voir _run_state). À appeler APRÈS le placement :
# c'est add_child() qui déclenche _ready(), lequel remet PV et EA au maximum.
func apply_carried_state(unit) -> void:
	if not unit.has_meta("tower_index"):
		return
	var state: Dictionary = _run_state.get(int(unit.get_meta("tower_index")), {})
	if state.is_empty():
		return
	unit.current_hp = clampi(int(round(unit.max_hp * float(state["hp"]))), 1, unit.max_hp)
	unit.current_ea = clampi(int(round(unit.max_ea * float(state["ea"]))), 0, unit.max_ea)

# Fin d'un combat de la Tour (bouton de la bannière de fin de combat).
# `survivors` : une entrée par aventurier encore en vie à la fin —
# {"index", "hp", "max_hp", "ea", "max_ea"}. Victoire : étage suivant.
# Défaite ou match nul : fin de l'ascension.
func finish_floor(result: String, survivors: Array) -> void:
	if not run_active:
		return
	if result != "victory":
		_end_run()
		return

	floors_cleared += 1
	# XP de l'étage : à chaque aventurier qui y a combattu.
	var gained_xp: int = TowerFloors.get_floor_xp(current_floor)
	for fighter in get_fighting_indices():
		team[int(fighter)].xp += gained_xp
	_update_run_state_after_victory(survivors)
	current_floor += 1
	var error: String = _enter_current_floor()
	if error != "":
		push_warning(error)
		_end_run()

# Ce avec quoi chaque aventurier aborde l'étage suivant.
func _update_run_state_after_victory(survivors: Array) -> void:
	var alive_now: Dictionary = {}
	for survivor in survivors:
		alive_now[int(survivor["index"])] = survivor

	for i in range(team.size()):
		var state: Dictionary = _run_state.get(i, {"alive": true, "hp": 1.0, "ea": 1.0})
		if alive_now.has(i):
			var survivor: Dictionary = alive_now[i]
			var hp_fraction: float = float(survivor["hp"]) / maxf(1.0, float(survivor["max_hp"]))
			var ea_fraction: float = 1.0 if int(survivor["max_ea"]) <= 0 else float(survivor["ea"]) / float(survivor["max_ea"])
			state = {
				"alive": true,
				"hp": minf(1.0, hp_fraction + SURVIVOR_HEAL_PERCENT / 100.0),
				"ea": minf(1.0, ea_fraction + EA_RESTORE_PERCENT / 100.0),
			}
		elif state["alive"]:
			# Tombé pendant cet étage.
			if REVIVE_DEAD:
				state = {"alive": true, "hp": REVIVED_HP_PERCENT / 100.0, "ea": EA_RESTORE_PERCENT / 100.0}
			else:
				state = {"alive": false, "hp": 0.0, "ea": 0.0}
		_run_state[i] = state

# Termine l'ascension et retourne à l'écran de création d'équipe.
func _end_run() -> void:
	last_run_floors_cleared = floors_cleared
	run_active = false
	var error: int = get_tree().change_scene_to_file(team_select_scene_path)
	if error != OK:
		push_warning("TowerManager: impossible de charger '%s' (erreur %d). Vérifie/ajuste team_select_scene_path." % [team_select_scene_path, error])
