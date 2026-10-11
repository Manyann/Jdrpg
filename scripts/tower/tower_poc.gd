extends RefCounted
class_name TowerPoc

# ============================================================
# tower_poc.gd — Les 3 premiers étages de la Tour (POC), écrits à la main.
#
# Tant que ENABLED = true, ces étages et ces ennemis REMPLACENT ceux de
# tower_data.gd (voir TowerFloors et UnitDatabase._find_template). Passer
# ENABLED à false rend la main au fichier généré.
#
# Correspondance des abréviations : AT=attack, PRD=parade, AD=adresse,
# EV=max_hp (points de vie), EA=max_ea, PR=armor (armure naturelle),
# COU=courage, INT=intelligence, CHA=charisme. « Autres stats » = force,
# chance, et celles de INT/CHA/AD/COU non citées.
#
# Champs propres à la Tour :
#   xp            : XP donnée par cet ennemi à CHAQUE aventurier (somme des
#                   ennemis de l'étage, versée à la victoire).
#   catalog_weapon: nom EXACT d'une arme du catalogue (weapon_catalog.gd).
#   weapon        : arme naturelle ; dice_count/dice_modifier = dégâts en dés
#                   (ex: 2D+3). Sans "weapon" ni "catalog_weapon" : mains nues
#                   (1D, voir CombatUnit._create_default_weapon).
#   spell_sets    : ensembles de sorts (voir build_spell_set).
# Étage : "mode" = "classic" | "ambush" ; "obstacles" (BASIC), "water"
# (EAU), "void" (VIDE) = listes de cases (q, r).
# ============================================================

const ENABLED: bool = true

# Huit piliers répartis sur la carte (symétrie centrale), hors de la zone centrale.
const PILLARS: Array = [
	Vector2i(3, -1), Vector2i(-3, 1), Vector2i(1, -3), Vector2i(-1, 3),
	Vector2i(2, 1), Vector2i(-2, -1), Vector2i(4, -2), Vector2i(-4, 2),
]

# Rivière sur toute la colonne centrale (q = 0), sauf la case (0, 0) : le pont.
const RIVER: Array = [
	Vector2i(0, -4), Vector2i(0, -3), Vector2i(0, -2), Vector2i(0, -1),
	Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3), Vector2i(0, 4),
]

const ENEMIES: Dictionary = {
	"Coyote affamé": {
		"max_hp": 8, "max_pm": 3, "max_ea": 0, "courage": 4,
		"attack": 10, "parade": 10, "adresse": 12,
		"force": 8, "intelligence": 8, "charisme": 8, "chance": 8,
		"armor": 1, "xp": 3, "spells": [], "sprite_from": "Orc",
	},
	"Guerrier maudit": {
		"max_hp": 40, "max_pm": 3, "max_ea": 12, "courage": 18,
		"attack": 12, "parade": 12, "adresse": 10,
		"force": 10, "intelligence": 10, "charisme": 10, "chance": 10,
		"armor": 6, "xp": 20, "spells": [],
		"catalog_weapon": "Epée d'artisan renommé",
		"spell_sets": ["drain_de_vie"], "sprite_from": "Orc",
	},
	# PV et EA non précisés dans la demande : 30 PV / 12 EA par défaut.
	"Prêtre de la nuit": {
		"max_hp": 30, "max_pm": 3, "max_ea": 12, "courage": 18,
		"attack": 10, "parade": 10, "adresse": 11,
		"force": 10, "intelligence": 13, "charisme": 11, "chance": 10,
		"armor": 3, "xp": 25, "spells": [],
		"catalog_weapon": "Dague d'artisan renommé",
		"spell_sets": ["pretre_neant"], "sprite_from": "Elfe",
	},
	# PR non précisée : 0.
	"Mage de feu": {
		"max_hp": 35, "max_pm": 3, "max_ea": 35, "courage": 14,
		"attack": 9, "parade": 9, "adresse": 12,
		"force": 12, "intelligence": 12, "charisme": 12, "chance": 12,
		"armor": 0, "xp": 20, "spells": [],
		"catalog_weapon": "Dague d'artisan renommé",
		"spell_sets": ["mage_feu"], "sprite_from": "Mage",
	},
	"Ver des sables géant": {
		"max_hp": 50, "max_pm": 3, "max_ea": 0, "courage": 4,
		"attack": 8, "parade": 6, "adresse": 3,
		"force": 4, "intelligence": 4, "charisme": 4, "chance": 4,
		"armor": 4, "xp": 45, "spells": [],
		"weapon": {"name": "Mandibules", "damage": 10, "dice_count": 2, "dice_modifier": 3,
			"weapon_type": "melee", "min_range": 1, "max_range": 1},
		"sprite_from": "Barbare",
	},
}

const FLOORS: Array = [
	{
		"floor": 1, "name": "Les coyotes affamés", "mode": "classic",
		"obstacles": [], "water": [], "void": [],
		"enemies": ["Coyote affamé", "Coyote affamé", "Coyote affamé",
			"Coyote affamé", "Coyote affamé", "Coyote affamé"],
	},
	{
		"floor": 2, "name": "Les piliers maudits", "mode": "ambush",
		"obstacles": PILLARS, "water": [], "void": [],
		"enemies": ["Guerrier maudit", "Guerrier maudit", "Prêtre de la nuit"],
	},
	{
		"floor": 3, "name": "Le pont des sables", "mode": "classic",
		"obstacles": [], "water": RIVER, "void": [],
		"enemies": ["Mage de feu", "Mage de feu", "Ver des sables géant"],
	},
]

# Sorts d'un ensemble nommé (clé « spell_sets » d'un ennemi).
static func build_spell_set(set_id: String) -> Array:
	match set_id:
		"drain_de_vie":
			return [_build_drain_de_vie()]
		"pretre_neant":
			return PretreSpellCatalog.build_for_order("Ordre du néant")
		"mage_feu":
			# Sorts du catalogue Mage dont le SEUL élément est le Feu.
			var fire: Array = []
			for spell in MageSpellCatalog.build_all():
				if spell.elements.size() == 1 and spell.elements.has("Feu"):
					fire.append(spell)
			return fire
	push_warning("TowerPoc: ensemble de sorts inconnu '%s'." % set_id)
	return []

# Drain de vie : 4 EA, vole 1D+3 PV à un ennemi (dégâts bruts rendus au
# lanceur, comme Croissant de lune). Portée 1 à 3 (non précisée).
static func _build_drain_de_vie() -> Spell:
	var s := Spell.new()
	s.spell_name = "Drain de vie"
	s.target_mode = Spell.TargetMode.SINGLE_ENEMY
	s.ea_cost = 4
	s.spell_type = Spell.SpellType.PHYSICAL
	s.dice_terms = [{"count": 1, "sides": 6, "modifier": 3}]
	s.ignores_armor = true
	s.transfers_damage_to_ally = true
	s.min_range = 1
	s.max_range = 3
	return s
