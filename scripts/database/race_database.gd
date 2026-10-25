extends RefCounted
class_name RaceDatabase

# ============================================================
# race_database.gd — GÉNÉRÉ à partir des 15 races d'origine.
#
# La race s'applique EN PLUS de la classe (choisie indépendamment,
# voir CombatUnit.equipped_race) — mêmes champs bonus_* que
# Weapon/Armor/Accessory/StatusEffect, sommés de la même façon dans
# CombatUnit._recalculate_stats().
#
# Prérequis (COU/INT/CHA/AD/FO min ou max pour pouvoir choisir cette
# race) : PAS appliqués (pas d'écran de création de personnage chez
# nous, tout est figé) — conservés dans Race.prereqs à titre
# indicatif seulement, pour un futur écran de création si besoin.
#
# Codes de compétences (inherited_skill_codes) : catalogue pas
# encore fourni — stockés tels quels, sans effet mécanique pour
# l'instant (même traitement que les sorts Mage non automatisés).
#
# Restrictions d'équipement/de métier : stockées en texte/codes bruts,
# pas encore vérifiées par la boutique/l'équipement.
#
# Bonus non-automatisés (paliers de niveau, dés au level up, %,
# passifs conditionnels...) : conservés dans Race.special_traits en
# texte libre, pas appliqués mécaniquement — pas de système de
# montée de niveau affectant les stats chez nous pour l'instant.
# ============================================================

static func _build_humain() -> Race:
	var race := Race.new()
	race.race_name = "Humain"
	race.bonus_vie = 30
	race.bonus_mana = 30
	race.profession_restriction_codes = ["WA"]
	race.bonus_stat_points = 3  # Commence avec 22 points à répartir au lieu de 19.
	race.level_cap_exempt_stats = ["courage", "intelligence", "charisme", "adresse", "force", "chance"]  # Aucune restriction de caractéristique par niveau.
	return race

static func _build_barbare() -> Race:
	var race := Race.new()
	race.race_name = "Barbare"
	race.bonus_vie = 35
	race.bonus_attaque = 1
	race.bonus_parade = -1
	race.equipment_restrictions = ["Arbalètes", "Armure complete", "Bouclier"]
	race.inherited_skill_codes = ["ADB", "BP", "CDN", "IN", "SDP", "TV", "TDM*"]
	race.profession_restriction_codes = ["PR", "VO", "AR", "BE", "AT", "RA", "IN", "DM", "MG", "SO", "CR", "PI", "CP", "WA"]
	race.prereqs = [{"stat": "courage", "type": "min", "value": 12}, {"stat": "intelligence", "type": "max", "value": 9}, {"stat": "force", "type": "min", "value": 13}]
	return race

static func _build_nain() -> Race:
	var race := Race.new()
	race.race_name = "Nain"
	race.bonus_vie = 35
	race.bonus_mana = 22
	race.equipment_restrictions = ["Arcs et Arbalètes", "Armes à 2 mains non naine"]
	race.inherited_skill_codes = ["ADT", "AEC", "CDN", "ME", "IDT", "PE", "RA", "TC*"]
	race.profession_restriction_codes = ["MO", "VO", "AR", "HE", "RA", "DM", "MG", "PS", "PI", "CP", "CR", "WA"]
	race.prereqs = [{"stat": "courage", "type": "min", "value": 11}, {"stat": "intelligence", "type": "min", "value": 10}, {"stat": "force", "type": "min", "value": 12}]
	return race

static func _build_haut_elfe() -> Race:
	var race := Race.new()
	race.race_name = "Haut Elfe"
	race.bonus_vie = 25
	race.bonus_mana = 35
	race.special_traits = ["+1CHA niveau 2 et 3"]
	race.equipment_restrictions = ["Armes à 2 mains", "Arbalètes", "Masses"]
	race.inherited_skill_codes = ["ADR", "CDG", "CH", "ER", "RB", "TDP", "PE", "PS*"]
	race.profession_restriction_codes = ["PR", "VO", "AR", "AT", "RA", "IN", "DM", "GR", "WA", "CO"]
	race.prereqs = [{"stat": "intelligence", "type": "min", "value": 11}, {"stat": "charisme", "type": "min", "value": 12}, {"stat": "adresse", "type": "min", "value": 11}, {"stat": "force", "type": "max", "value": 10}]
	return race

static func _build_demi_elfe() -> Race:
	var race := Race.new()
	race.race_name = "Demi Elfe"
	race.bonus_vie = 28
	race.bonus_mana = 32
	race.special_traits = ["+1CHA niveau 2"]
	race.inherited_skill_codes = ["ADR", "DE", "CHO", "ME", "MEP", "IDS", "TC*"]
	race.profession_restriction_codes = ["WA"]
	race.prereqs = [{"stat": "charisme", "type": "min", "value": 10}, {"stat": "adresse", "type": "min", "value": 11}]
	return race

static func _build_elfe_sylvain() -> Race:
	var race := Race.new()
	race.race_name = "Elfe Sylvain"
	race.bonus_vie = 25
	race.bonus_mana = 30
	race.special_traits = ["+1CHA niveau 2 et 3"]
	race.equipment_restrictions = ["Armes à 2 mains", "Arbalètes"]
	race.inherited_skill_codes = ["CH", "CLA", "LDM", "NT", "PS", "TC", "TDP", "DS*"]
	race.profession_restriction_codes = ["PR", "IN", "DM", "MG", "GR", "FO", "FR", "WA"]
	race.prereqs = [{"stat": "charisme", "type": "min", "value": 11}, {"stat": "adresse", "type": "min", "value": 11}, {"stat": "force", "type": "max", "value": 12}]
	return race

static func _build_elfe_noir() -> Race:
	var race := Race.new()
	race.race_name = "Elfe Noir"
	race.bonus_vie = 25
	race.bonus_mana = 30
	race.dodge_counter_chance = 0.5
	race.special_traits = ["+1CHA niveau 2 et 3"]
	race.equipment_restrictions = ["Armes à 2 mains"]
	race.inherited_skill_codes = ["AG", "DS", "DE", "ES", "ME", "PI", "TC", "AM*"]
	race.profession_restriction_codes = ["PR", "BE", "AT", "IN", "MG", "GR", "AC", "WA"]
	race.prereqs = [{"stat": "intelligence", "type": "min", "value": 12}, {"stat": "adresse", "type": "min", "value": 13}, {"stat": "force", "type": "max", "value": 12}]
	return race

static func _build_orque() -> Race:
	var race := Race.new()
	race.race_name = "Orque"
	race.bonus_vie = 35
	race.bonus_mana = 22
	race.bonus_attaque = 1
	race.bonus_parade = -1
	race.equipment_restrictions = ["Pas d'armes de jet"]
	race.inherited_skill_codes = ["AG", "ADT", "BP", "CDN", "IDS", "SDP", "TDM", "ADB*"]
	race.profession_restriction_codes = ["MO", "AR", "BE", "DM", "WA"]
	race.prereqs = [{"stat": "courage", "type": "min", "value": 11}, {"stat": "charisme", "type": "max", "value": 11}, {"stat": "force", "type": "min", "value": 12}]
	return race

static func _build_demi_orque() -> Race:
	var race := Race.new()
	race.race_name = "Demi Orque"
	race.bonus_vie = 32
	race.bonus_mana = 25
	race.javelin_damage_bonus_dice = 1
	race.special_traits = ["Achète 3 javelots pour le prix de 1"]
	race.inherited_skill_codes = ["AG", "BP", "CDN", "IDS", "IN", "MDP", "SDP", "TDM*"]
	race.profession_restriction_codes = ["WA"]
	race.prereqs = [{"stat": "intelligence", "type": "min", "value": 10}, {"stat": "charisme", "type": "min", "value": 10}, {"stat": "force", "type": "max", "value": 12}]
	return race

static func _build_ogre() -> Race:
	var race := Race.new()
	race.race_name = "Ogre"
	race.grants_ogre_pi = true
	race.bonus_vie = 40
	race.bonus_mana = 3
	race.bonus_attaque = 1
	race.bonus_parade = -1
	race.special_traits = ["1D+3EV au level up", "Équipement 50% plus cher", "Consomme 2 rations", "Peut retirer jusqu'à 3AT/PRD pour avoir jusqu'à +3PI"]
	race.equipment_restrictions = ["Armes à distance", "Armure complète"]
	race.inherited_skill_codes = ["AG", "ADT", "ADV", "ADB", "BP", "IDS", "IN", "SDP", "TV", "TDM"]
	race.profession_restriction_codes = ["PR", "VO", "AR", "BE", "AT", "RA", "IN", "DM", "MG", "CP", "SO", "GL", "PI", "WA"]
	race.level_cap_exempt_stats = ["force"]  # Seule race non limitée en Force par son niveau.
	race.prereqs = [{"stat": "courage", "type": "min", "value": 11}, {"stat": "intelligence", "type": "max", "value": 10}, {"stat": "charisme", "type": "max", "value": 10}, {"stat": "adresse", "type": "max", "value": 11}, {"stat": "force", "type": "min", "value": 13}]
	return race

static func _build_centaure() -> Race:
	var race := Race.new()
	race.race_name = "Centaure"
	race.pm_modifier = 1  # 4 PM de base.
	race.bonus_vie = 40
	race.bonus_mana = 25
	race.bonus_attaque = 1
	race.bonus_parade = -1
	race.special_traits = ["1D6 +1D4EV au level up", "Équipement 50% plus cher", "Consomme 2 rations"]
	race.equipment_restrictions = ["Armes de jet", "Armes à feu", "Armure complète"]
	race.inherited_skill_codes = ["ADT", "ADB", "BP", "IN", "PI", "TC", "TDM", "PS*"]
	race.profession_restriction_codes = ["PR", "VO", "AR", "BE", "IN", "DM", "MG", "HE", "AC", "BZ", "PI", "CR", "IQ", "WA"]
	race.prereqs = [{"stat": "intelligence", "type": "min", "value": 11}, {"stat": "adresse", "type": "min", "value": 11}, {"stat": "force", "type": "min", "value": 13}]
	return race

static func _build_homme_des_sables() -> Race:
	var race := Race.new()
	race.race_name = "Homme des sables"
	race.bonus_vie = 25
	race.bonus_mana = 25
	race.bonus_parade = 2
	race.dodge_counter_chance = 0.25
	race.dodge_counter_melee_only = true
	race.special_traits = ["+1 ESQ", "10% réduction sur arme à feu"]
	race.equipment_restrictions = ["Armes à 2 mains", "Arme de jet sauf arme à feu"]
	race.inherited_skill_codes = ["DS", "DE", "DET", "ME", "PI", "TC", "AM*"]
	race.profession_restriction_codes = ["MG", "GR", "WA"]
	race.prereqs = [{"stat": "courage", "type": "min", "value": 11}, {"stat": "adresse", "type": "min", "value": 13}, {"stat": "force", "type": "max", "value": 11}]
	return race

static func _build_hobbit() -> Race:
	var race := Race.new()
	race.race_name = "Hobbit"
	race.pm_modifier = -1  # 2 PM de base, et pas de Déplacement silencieux.
	race.bonus_vie = 25
	race.bonus_mana = 25
	race.grants_hobbit_bravoure = true
	race.grants_hobbit_precision = true
	race.special_traits = ["+1D4EV level up", "Minimum 1 point destin", "Les Hobbits essayent de voler tous les anneaux qu'ils voient. Test INT +3 pour se retenir", "En l'honneur de Sam : Les Hobbits gagnent 1 COU tous les 2 niveaux"]
	race.equipment_restrictions = ["Armes à 2 mains", "Arme de jet sauf lance pierre"]
	race.inherited_skill_codes = ["ADT", "ADV", "CU", "ES", "IN", "MEP", "NT", "JED*"]
	race.profession_restriction_codes = ["PR", "VO", "RA", "IN", "DM", "MG", "GR", "FO", "FR", "WA"]
	race.prereqs = [{"stat": "courage", "type": "min", "value": 12}, {"stat": "intelligence", "type": "min", "value": 10}, {"stat": "force", "type": "max", "value": 10}]
	return race

static func _build_walkyrie() -> Race:
	var race := Race.new()
	race.race_name = "Walkyrie"
	race.bonus_vie = 40
	race.bonus_mana = 40
	race.bonus_attaque = 1
	race.bonus_parade = 1
	race.special_traits = ["+1D+3EV level up", "Pas de malus aux lances", "Justice céleste: 4 bons points / 3 mauvais points", "Ailes : Les walkyries peuvent voler pendant un certain temps", "Persécuté : Les walkyries sont chassées pour leurs ailes (cape conseillée)"]
	race.equipment_restrictions = ["Peut utiliser que les lances / javelots", "Armes de jet"]
	race.inherited_skill_codes = ["AG", "CDG", "ER", "RB", "PS", "DS*"]
	race.special_skill_texts = ["#walkyrie"]
	race.profession_restriction_codes = ["PR", "VO", "AR", "BE", "AT", "RA", "IN", "DM", "MG", "GR"]
	race.prereqs = [{"stat": "courage", "type": "min", "value": 13}, {"stat": "charisme", "type": "min", "value": 13}, {"stat": "adresse", "type": "min", "value": 12}, {"stat": "force", "type": "min", "value": 11}]
	return race

static func _build_samurai() -> Race:
	var race := Race.new()
	race.race_name = "Samurai"
	race.bonus_vie = 30
	race.bonus_mana = 20
	race.bonus_attaque = 1
	race.bonus_parade = -1
	race.grants_samurai_concentration = true
	race.grants_samurai_combo = true
	race.special_traits = ["Honneur : le samuraï doit avoir 6 bons points", "Sur coup critique : 18/19/20 mort de l'ennemi, le samuraï gagne 1 bon point", "Sur échec critique : 1/2 échec annulé. 20 Hara-Kiri. 3 à 19 gagne un mauvais point"]
	race.equipment_restrictions = ["Armes de jet étrangère"]
	race.inherited_skill_codes = ["AM", "ER", "ALM", "CH", "TC", "TDM*"]
	race.profession_restriction_codes = ["PR", "VO", "AR", "IN", "DM", "MG", "HE", "PI", "BZ", "GL", "WA", "CP", "AC", "IQ"]
	race.prereqs = [{"stat": "courage", "type": "min", "value": 13}, {"stat": "charisme", "type": "min", "value": 10}, {"stat": "adresse", "type": "min", "value": 11}, {"stat": "force", "type": "min", "value": 11}]
	return race

const NAMES: Array = ["Humain", "Barbare", "Nain", "Haut Elfe", "Demi Elfe", "Elfe Sylvain", "Elfe Noir", "Orque", "Demi Orque", "Ogre", "Centaure", "Homme des sables", "Hobbit", "Walkyrie", "Samurai"]

# Tous les noms de race valides (mêmes chaînes que celles acceptées
# par build() ci-dessous) — utilisé pour un tirage au sort (voir
# HexGrid.setup_starting_units, combat de test).
static func list_all_race_names() -> Array:
	return [
		"Humain", "Barbare", "Nain", "Haut Elfe", "Demi Elfe", "Elfe Sylvain",
		"Elfe Noir", "Orque", "Demi Orque", "Ogre", "Centaure",
		"Homme des sables", "Hobbit", "Walkyrie", "Samurai",
	]

static func build(race_name: String) -> Race:
	match race_name:
		"Humain":
			return _build_humain()
		"Barbare":
			return _build_barbare()
		"Nain":
			return _build_nain()
		"Haut Elfe":
			return _build_haut_elfe()
		"Demi Elfe":
			return _build_demi_elfe()
		"Elfe Sylvain":
			return _build_elfe_sylvain()
		"Elfe Noir":
			return _build_elfe_noir()
		"Orque":
			return _build_orque()
		"Demi Orque":
			return _build_demi_orque()
		"Ogre":
			return _build_ogre()
		"Centaure":
			return _build_centaure()
		"Homme des sables":
			return _build_homme_des_sables()
		"Hobbit":
			return _build_hobbit()
		"Walkyrie":
			return _build_walkyrie()
		"Samurai":
			return _build_samurai()
		_:
			push_warning("RaceDatabase: race inconnue '%s'." % race_name)
			return null
