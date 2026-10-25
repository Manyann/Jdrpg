extends RefCounted
class_name TowerPoc

# ============================================================
# tower_poc.gd — Les 25 étages de la Tour (POC), écrits à partir des tables
# de rencontres par biome (Nouveau monde 1-3, Forêt 4-7, Jungle 8-10,
# Montagne 11-14, Mer 15-17, Grotte 18-21, Désert 22-25).
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

# Arbres de la forêt / de la jungle et rochers de la montagne (symétrie centrale).
const TREES: Array = [
	Vector2i(2, -2), Vector2i(-2, 2), Vector2i(1, 1), Vector2i(-1, -1),
	Vector2i(3, -1), Vector2i(-3, 1), Vector2i(0, 2), Vector2i(0, -2),
]
const ROCKS: Array = [
	Vector2i(1, -2), Vector2i(-1, 2), Vector2i(2, 0), Vector2i(-2, 0),
	Vector2i(3, -3), Vector2i(-3, 3),
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
		"spell_sets": ["pretre_neant"], "traits": {"night_pi": 1},
		"sprite_from": "Elfe",
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

	# ----- Ennemis des tables de rencontres par biome (tokens existants) -----
	"Chien sauvage": {
		"max_hp": 15, "max_pm": 3, "max_ea": 0, "courage": 5,
		"attack": 6, "parade": 6, "adresse": 8,
		"force": 8, "intelligence": 8, "charisme": 8, "chance": 8,
		"armor": 0, "xp": 5, "spells": [],
		"weapon": {"name": "Attaque naturelle", "damage": 10, "dice_count": 1, "dice_modifier": 2,
			"weapon_type": "melee", "min_range": 1, "max_range": 1},
		"sprite_from": "Orc",
	},
	"Kallikantzaroi": {
		"max_hp": 15, "max_pm": 3, "max_ea": 0, "courage": 7,
		"attack": 7, "parade": 7, "adresse": 8,
		"force": 8, "intelligence": 8, "charisme": 8, "chance": 8,
		"armor": 1, "xp": 8, "spells": [],
		"weapon": {"name": "Attaque naturelle", "damage": 10, "dice_count": 1, "dice_modifier": 2,
			"weapon_type": "melee", "min_range": 1, "max_range": 1},
		"sprite_from": "Orc",
	},
	"Ogre à peau bleue": {
		"max_hp": 35, "max_pm": 3, "max_ea": 0, "courage": 20,
		"attack": 6, "parade": 6, "adresse": 8,
		"force": 8, "intelligence": 8, "charisme": 8, "chance": 8,
		"armor": 4, "xp": 25, "spells": [],
		"weapon": {"name": "Attaque naturelle", "damage": 10, "dice_count": 2, "dice_modifier": 4,
			"weapon_type": "melee", "min_range": 1, "max_range": 1},
		"sprite_from": "Barbare",
	},
	"Olsklül": {
		"max_hp": 30, "max_pm": 3, "max_ea": 0, "courage": 13,
		"attack": 12, "parade": 12, "adresse": 8,
		"force": 8, "intelligence": 8, "charisme": 8, "chance": 8,
		"armor": 2, "xp": 30, "spells": [],
		"weapon": {"name": "Attaque naturelle", "damage": 10, "dice_count": 1, "dice_modifier": 6,
			"weapon_type": "melee", "min_range": 1, "max_range": 1},
		"sprite_from": "Barbare",
	},
	"Amarok": {
		"max_hp": 38, "max_pm": 3, "max_ea": 0, "courage": 14,
		"attack": 11, "parade": 11, "adresse": 8,
		"force": 8, "intelligence": 8, "charisme": 8, "chance": 8,
		"armor": 3, "xp": 30, "spells": [],
		"weapon": {"name": "Attaque naturelle", "damage": 10, "dice_count": 1, "dice_modifier": 5,
			"weapon_type": "melee", "min_range": 1, "max_range": 1},
		"sprite_from": "Orc",
	},
	"Yéti": {
		"max_hp": 45, "max_pm": 3, "max_ea": 0, "courage": 20,
		"attack": 8, "parade": 8, "adresse": 8,
		"force": 8, "intelligence": 8, "charisme": 8, "chance": 8,
		"armor": 4, "xp": 40, "spells": [],
		"weapon": {"name": "Attaque naturelle", "damage": 10, "dice_count": 3, "dice_modifier": 3,
			"weapon_type": "melee", "min_range": 1, "max_range": 1},
		"sprite_from": "Barbare",
	},
	"Yukionna": {
		"max_hp": 25, "max_pm": 3, "max_ea": 0, "courage": 20,
		"attack": 14, "parade": 14, "adresse": 8,
		"force": 8, "intelligence": 8, "charisme": 8, "chance": 8,
		"armor": 4, "xp": 50, "spells": [],
		"weapon": {"name": "Attaque naturelle", "damage": 10, "dice_count": 1, "dice_modifier": 7,
			"weapon_type": "melee", "min_range": 1, "max_range": 1},
		"traits": {"miss_next_attack": 0.5},
		"sprite_from": "Elfe",
	},
	"Brigand costaud": {
		"max_hp": 22, "max_pm": 3, "max_ea": 0, "courage": 11,
		"attack": 10, "parade": 9, "adresse": 8,
		"force": 8, "intelligence": 8, "charisme": 8, "chance": 8,
		"armor": 1, "xp": 15, "spells": [],
		"weapon": {"name": "Attaque naturelle", "damage": 10, "dice_count": 1, "dice_modifier": 3,
			"weapon_type": "melee", "min_range": 1, "max_range": 1},
		"sprite_from": "Orc",
	},
	"Loup": {
		"max_hp": 20, "max_pm": 3, "max_ea": 0, "courage": 10,
		"attack": 10, "parade": 8, "adresse": 8,
		"force": 8, "intelligence": 8, "charisme": 8, "chance": 8,
		"armor": 2, "xp": 10, "spells": [],
		"weapon": {"name": "Attaque naturelle", "damage": 10, "dice_count": 1, "dice_modifier": 4,
			"weapon_type": "melee", "min_range": 1, "max_range": 1},
		"sprite_from": "Orc",
	},
	"Orque offensif": {
		"max_hp": 18, "max_pm": 3, "max_ea": 0, "courage": 10,
		"attack": 10, "parade": 7, "adresse": 8,
		"force": 8, "intelligence": 8, "charisme": 8, "chance": 8,
		"armor": 3, "xp": 10, "spells": [],
		"weapon": {"name": "Attaque naturelle", "damage": 10, "dice_count": 1, "dice_modifier": 4,
			"weapon_type": "melee", "min_range": 1, "max_range": 1},
		"sprite_from": "Orc",
	},
	"Mercenaire errant": {
		"max_hp": 25, "max_pm": 3, "max_ea": 0, "courage": 12,
		"attack": 12, "parade": 10, "adresse": 8,
		"force": 8, "intelligence": 8, "charisme": 8, "chance": 8,
		"armor": 3, "xp": 30, "spells": [],
		"weapon": {"name": "Attaque naturelle", "damage": 10, "dice_count": 1, "dice_modifier": 5,
			"weapon_type": "melee", "min_range": 1, "max_range": 1},
		"sprite_from": "Orc",
	},
	"Elfe sylvain": {
		"max_hp": 20, "max_pm": 3, "max_ea": 0, "courage": 8,
		"attack": 4, "parade": 8, "adresse": 8,
		"force": 8, "intelligence": 8, "charisme": 8, "chance": 8,
		"armor": 0, "xp": 5, "spells": [],
		"weapon": {"name": "Attaque naturelle", "damage": 10, "dice_count": 1, "dice_modifier": 3,
			"weapon_type": "melee", "min_range": 1, "max_range": 1},
		"sprite_from": "Elfe",
	},
	"Orque d'élite": {
		"max_hp": 40, "max_pm": 3, "max_ea": 0, "courage": 14,
		"attack": 12, "parade": 12, "adresse": 8,
		"force": 8, "intelligence": 8, "charisme": 8, "chance": 8,
		"armor": 3, "xp": 35, "spells": [],
		"weapon": {"name": "Attaque naturelle", "damage": 10, "dice_count": 1, "dice_modifier": 5,
			"weapon_type": "melee", "min_range": 1, "max_range": 1},
		"sprite_from": "Orc",
	},
	"Millepattes monstrueux": {
		"max_hp": 40, "max_pm": 3, "max_ea": 0, "courage": 20,
		"attack": 12, "parade": 8, "adresse": 8,
		"force": 8, "intelligence": 8, "charisme": 8, "chance": 8,
		"armor": 5, "xp": 50, "spells": [],
		"weapon": {"name": "Attaque naturelle", "damage": 10, "dice_count": 1, "dice_modifier": 6,
			"weapon_type": "melee", "min_range": 1, "max_range": 1},
		"sprite_from": "Barbare",
	},
	"Ogre mutant aguerri": {
		"max_hp": 65, "max_pm": 3, "max_ea": 0, "courage": 20,
		"attack": 11, "parade": 8, "adresse": 8,
		"force": 15, "intelligence": 8, "charisme": 8, "chance": 8,
		"armor": 3, "xp": 60, "spells": [],
		"weapon": {"name": "Attaque naturelle", "damage": 10, "dice_count": 3, "dice_modifier": 2,
			"weapon_type": "melee", "min_range": 1, "max_range": 1},
		"sprite_from": "Barbare",
	},
	"Troll berserk vétéran": {
		"max_hp": 65, "max_pm": 3, "max_ea": 0, "courage": 20,
		"attack": 11, "parade": 8, "adresse": 8,
		"force": 18, "intelligence": 8, "charisme": 8, "chance": 8,
		"armor": 4, "xp": 65, "spells": [],
		"weapon": {"name": "Attaque naturelle", "damage": 10, "dice_count": 3, "dice_modifier": 6,
			"weapon_type": "melee", "min_range": 1, "max_range": 1},
		"sprite_from": "Barbare",
	},
	"Ent": {
		"max_hp": 60, "max_pm": 3, "max_ea": 0, "courage": 1000,
		"attack": 12, "parade": 10, "adresse": 8,
		"force": 8, "intelligence": 8, "charisme": 8, "chance": 8,
		"armor": 4, "xp": 50, "spells": [],
		"weapon": {"name": "Attaque naturelle", "damage": 10, "dice_count": 1, "dice_modifier": 6,
			"weapon_type": "melee", "min_range": 1, "max_range": 1},
		"sprite_from": "Barbare",
	},
	"Ent d'yggdrasil": {
		"max_hp": 120, "max_pm": 3, "max_ea": 0, "courage": 1000,
		"attack": 13, "parade": 11, "adresse": 8,
		"force": 8, "intelligence": 8, "charisme": 8, "chance": 8,
		"armor": 5, "xp": 80, "spells": [],
		"weapon": {"name": "Attaque naturelle", "damage": 10, "dice_count": 2, "dice_modifier": 3,
			"weapon_type": "melee", "min_range": 1, "max_range": 1},
		"traits": {"turn_aoe": {"dice": 1, "mod": 8, "radius": 3, "name": "Liane"}},
		"sprite_from": "Barbare",
	},
	"Dragonne des cimes": {
		"max_hp": 50, "max_pm": 3, "max_ea": 0, "courage": 20,
		"attack": 14, "parade": 10, "adresse": 8,
		"force": 8, "intelligence": 8, "charisme": 8, "chance": 8,
		"armor": 6, "xp": 60, "spells": [],
		"weapon": {"name": "Attaque naturelle", "damage": 10, "dice_count": 2, "dice_modifier": 3,
			"weapon_type": "melee", "min_range": 1, "max_range": 1},
		"traits": {"immune_magic": true},
		"sprite_from": "Barbare",
	},
	"Elfe gardien": {
		"max_hp": 35, "max_pm": 3, "max_ea": 0, "courage": 1000,
		"attack": 14, "parade": 14, "adresse": 8,
		"force": 8, "intelligence": 8, "charisme": 8, "chance": 8,
		"armor": 3, "xp": 70, "spells": [],
		"weapon": {"name": "Attaque naturelle", "damage": 10, "dice_count": 1, "dice_modifier": 8,
			"weapon_type": "melee", "min_range": 1, "max_range": 1},
		"sprite_from": "Elfe",
	},
	"Troll berserk débile": {
		"max_hp": 40, "max_pm": 3, "max_ea": 0, "courage": 20,
		"attack": 8, "parade": 6, "adresse": 8,
		"force": 16, "intelligence": 8, "charisme": 8, "chance": 8,
		"armor": 3, "xp": 25, "spells": [],
		"weapon": {"name": "Attaque naturelle", "damage": 10, "dice_count": 2, "dice_modifier": 4,
			"weapon_type": "melee", "min_range": 1, "max_range": 1},
		"sprite_from": "Barbare",
	},
	"Petit singe": {
		"max_hp": 18, "max_pm": 3, "max_ea": 0, "courage": 7,
		"attack": 8, "parade": 8, "adresse": 8,
		"force": 8, "intelligence": 8, "charisme": 8, "chance": 8,
		"armor": 0, "xp": 8, "spells": [],
		"weapon": {"name": "Attaque naturelle", "damage": 10, "dice_count": 1, "dice_modifier": 2,
			"weapon_type": "melee", "min_range": 1, "max_range": 1},
		"sprite_from": "Orc",
	},
	"Indigène agressif": {
		"max_hp": 25, "max_pm": 3, "max_ea": 0, "courage": 15,
		"attack": 8, "parade": 8, "adresse": 8,
		"force": 8, "intelligence": 8, "charisme": 8, "chance": 8,
		"armor": 2, "xp": 12, "spells": [],
		"weapon": {"name": "Attaque naturelle", "damage": 10, "dice_count": 1, "dice_modifier": 4,
			"weapon_type": "melee", "min_range": 1, "max_range": 1},
		"sprite_from": "Orc",
	},
	"Grand singe": {
		"max_hp": 30, "max_pm": 3, "max_ea": 0, "courage": 10,
		"attack": 10, "parade": 10, "adresse": 8,
		"force": 8, "intelligence": 8, "charisme": 8, "chance": 8,
		"armor": 1, "xp": 18, "spells": [],
		"weapon": {"name": "Attaque naturelle", "damage": 10, "dice_count": 1, "dice_modifier": 4,
			"weapon_type": "melee", "min_range": 1, "max_range": 1},
		"sprite_from": "Barbare",
	},
	"Jaguar": {
		"max_hp": 25, "max_pm": 3, "max_ea": 0, "courage": 12,
		"attack": 11, "parade": 11, "adresse": 8,
		"force": 8, "intelligence": 8, "charisme": 8, "chance": 8,
		"armor": 1, "xp": 25, "spells": [],
		"weapon": {"name": "Attaque naturelle", "damage": 10, "dice_count": 1, "dice_modifier": 5,
			"weapon_type": "melee", "min_range": 1, "max_range": 1},
		"sprite_from": "Orc",
	},
	"Mapinguari": {
		"max_hp": 50, "max_pm": 3, "max_ea": 0, "courage": 13,
		"attack": 5, "parade": 5, "adresse": 8,
		"force": 8, "intelligence": 8, "charisme": 8, "chance": 8,
		"armor": 3, "xp": 30, "spells": [],
		"weapon": {"name": "Attaque naturelle", "damage": 10, "dice_count": 3, "dice_modifier": 3,
			"weapon_type": "melee", "min_range": 1, "max_range": 1},
		"sprite_from": "Barbare",
	},
	"Chupacabra": {
		"max_hp": 30, "max_pm": 3, "max_ea": 0, "courage": 8,
		"attack": 14, "parade": 14, "adresse": 8,
		"force": 8, "intelligence": 8, "charisme": 8, "chance": 8,
		"armor": 2, "xp": 35, "spells": [],
		"weapon": {"name": "Attaque naturelle", "damage": 10, "dice_count": 2, "dice_modifier": 2,
			"weapon_type": "melee", "min_range": 1, "max_range": 1},
		"sprite_from": "Orc",
	},
	"Singe géant": {
		"max_hp": 50, "max_pm": 3, "max_ea": 0, "courage": 1000,
		"attack": 6, "parade": 7, "adresse": 8,
		"force": 8, "intelligence": 8, "charisme": 8, "chance": 8,
		"armor": 5, "xp": 50, "spells": [],
		"weapon": {"name": "Attaque naturelle", "damage": 10, "dice_count": 1, "dice_modifier": 0,
			"weapon_type": "melee", "min_range": 1, "max_range": 1},
		"traits": {"poison": {"dice": 1, "duration": 3, "name": "Poison", "chance": 1.0}},
		"sprite_from": "Barbare",
	},
	"Chaman indigène": {
		"max_hp": 25, "max_pm": 3, "max_ea": 0, "courage": 12,
		"attack": 6, "parade": 6, "adresse": 8,
		"force": 8, "intelligence": 8, "charisme": 8, "chance": 8,
		"armor": 1, "xp": 15, "spells": [],
		"weapon": {"name": "Attaque naturelle", "damage": 0, "dice_count": 0, "dice_modifier": 0,
			"weapon_type": "melee", "min_range": 1, "max_range": 1},
		"traits": {"summon": {"template": "Jaguar", "chance": 0.25, "max": 2}},
		"sprite_from": "Elfe",
	},
	"Chef de tribu indigène": {
		"max_hp": 75, "max_pm": 3, "max_ea": 0, "courage": 1000,
		"attack": 13, "parade": 5, "adresse": 8,
		"force": 8, "intelligence": 8, "charisme": 8, "chance": 8,
		"armor": 3, "xp": 80, "spells": [],
		"weapon": {"name": "Attaque naturelle", "damage": 10, "dice_count": 4, "dice_modifier": 4,
			"weapon_type": "melee", "min_range": 1, "max_range": 1},
		"sprite_from": "Barbare",
	},
	"Bouc en colère": {
		"max_hp": 10, "max_pm": 3, "max_ea": 0, "courage": 15,
		"attack": 12, "parade": 2, "adresse": 8,
		"force": 8, "intelligence": 8, "charisme": 8, "chance": 8,
		"armor": 1, "xp": 3, "spells": [],
		"weapon": {"name": "Attaque naturelle", "damage": 10, "dice_count": 1, "dice_modifier": 0,
			"weapon_type": "melee", "min_range": 1, "max_range": 1},
		"traits": {"unparryable": true},
		"sprite_from": "Orc",
	},
	"Gobelin boiteux": {
		"max_hp": 11, "max_pm": 3, "max_ea": 0, "courage": 4,
		"attack": 8, "parade": 8, "adresse": 8,
		"force": 8, "intelligence": 8, "charisme": 8, "chance": 8,
		"armor": 2, "xp": 4, "spells": [],
		"weapon": {"name": "Attaque naturelle", "damage": 10, "dice_count": 1, "dice_modifier": 2,
			"weapon_type": "melee", "min_range": 1, "max_range": 1},
		"sprite_from": "Orc",
	},
	"Prospecteur nain": {
		"max_hp": 20, "max_pm": 3, "max_ea": 0, "courage": 12,
		"attack": 9, "parade": 7, "adresse": 8,
		"force": 8, "intelligence": 8, "charisme": 8, "chance": 8,
		"armor": 2, "xp": 12, "spells": [],
		"weapon": {"name": "Attaque naturelle", "damage": 10, "dice_count": 1, "dice_modifier": 4,
			"weapon_type": "melee", "min_range": 1, "max_range": 1},
		"sprite_from": "Orc",
	},
	"Ogre débile": {
		"max_hp": 40, "max_pm": 3, "max_ea": 0, "courage": 20,
		"attack": 8, "parade": 5, "adresse": 8,
		"force": 16, "intelligence": 8, "charisme": 8, "chance": 8,
		"armor": 3, "xp": 20, "spells": [],
		"weapon": {"name": "Attaque naturelle", "damage": 10, "dice_count": 2, "dice_modifier": 3,
			"weapon_type": "melee", "min_range": 1, "max_range": 1},
		"sprite_from": "Barbare",
	},
	"Troll des montagnes": {
		"max_hp": 40, "max_pm": 3, "max_ea": 0, "courage": 20,
		"attack": 5, "parade": 5, "adresse": 8,
		"force": 8, "intelligence": 8, "charisme": 8, "chance": 8,
		"armor": 4, "xp": 25, "spells": [],
		"weapon": {"name": "Attaque naturelle", "damage": 10, "dice_count": 2, "dice_modifier": 4,
			"weapon_type": "melee", "min_range": 1, "max_range": 1},
		"sprite_from": "Barbare",
	},
	"Ours": {
		"max_hp": 50, "max_pm": 3, "max_ea": 0, "courage": 20,
		"attack": 12, "parade": 5, "adresse": 8,
		"force": 17, "intelligence": 8, "charisme": 8, "chance": 8,
		"armor": 4, "xp": 30, "spells": [],
		"weapon": {"name": "Attaque naturelle", "damage": 10, "dice_count": 2, "dice_modifier": 3,
			"weapon_type": "melee", "min_range": 1, "max_range": 1},
		"sprite_from": "Barbare",
	},
	"Maman ours": {
		"max_hp": 55, "max_pm": 3, "max_ea": 0, "courage": 20,
		"attack": 14, "parade": 5, "adresse": 8,
		"force": 18, "intelligence": 8, "charisme": 8, "chance": 8,
		"armor": 5, "xp": 45, "spells": [],
		"weapon": {"name": "Attaque naturelle", "damage": 10, "dice_count": 2, "dice_modifier": 5,
			"weapon_type": "melee", "min_range": 1, "max_range": 1},
		"sprite_from": "Barbare",
	},
	"Élémentaire de pierre": {
		"max_hp": 30, "max_pm": 3, "max_ea": 0, "courage": 20,
		"attack": 10, "parade": 10, "adresse": 8,
		"force": 8, "intelligence": 8, "charisme": 8, "chance": 8,
		"armor": 3, "xp": 55, "spells": [],
		"weapon": {"name": "Attaque naturelle", "damage": 10, "dice_count": 2, "dice_modifier": 1,
			"weapon_type": "melee", "min_range": 1, "max_range": 1},
		"traits": {"immune_sharp": true},
		"sprite_from": "Barbare",
	},
	"Dragon des cimes": {
		"max_hp": 35, "max_pm": 3, "max_ea": 0, "courage": 18,
		"attack": 12, "parade": 9, "adresse": 8,
		"force": 8, "intelligence": 8, "charisme": 8, "chance": 8,
		"armor": 5, "xp": 55, "spells": [],
		"weapon": {"name": "Attaque naturelle", "damage": 10, "dice_count": 1, "dice_modifier": 6,
			"weapon_type": "melee", "min_range": 1, "max_range": 1},
		"sprite_from": "Barbare",
	},
	"Golem de pierre puissant": {
		"max_hp": 60, "max_pm": 3, "max_ea": 0, "courage": 20,
		"attack": 12, "parade": 14, "adresse": 8,
		"force": 8, "intelligence": 8, "charisme": 8, "chance": 8,
		"armor": 8, "xp": 80, "spells": [],
		"weapon": {"name": "Attaque naturelle", "damage": 10, "dice_count": 2, "dice_modifier": 5,
			"weapon_type": "melee", "min_range": 1, "max_range": 1},
		"traits": {"immune_sharp": true},
		"sprite_from": "Barbare",
	},
	"Vouivre": {
		"max_hp": 50, "max_pm": 3, "max_ea": 0, "courage": 20,
		"attack": 10, "parade": 10, "adresse": 8,
		"force": 8, "intelligence": 8, "charisme": 8, "chance": 8,
		"armor": 4, "xp": 100, "spells": [],
		"weapon": {"name": "Attaque naturelle", "damage": 10, "dice_count": 4, "dice_modifier": 2,
			"weapon_type": "melee", "min_range": 1, "max_range": 1},
		"sprite_from": "Barbare",
	},
	"Vouivre protectrice": {
		"max_hp": 100, "max_pm": 3, "max_ea": 0, "courage": 20,
		"attack": 12, "parade": 6, "adresse": 8,
		"force": 8, "intelligence": 8, "charisme": 8, "chance": 8,
		"armor": 6, "xp": 150, "spells": [],
		"weapon": {"name": "Attaque naturelle", "damage": 10, "dice_count": 2, "dice_modifier": 4,
			"weapon_type": "melee", "min_range": 1, "max_range": 1},
		"sprite_from": "Barbare",
	},
	"Ogre mutant débile": {
		"max_hp": 45, "max_pm": 3, "max_ea": 0, "courage": 20,
		"attack": 7, "parade": 4, "adresse": 8,
		"force": 15, "intelligence": 8, "charisme": 8, "chance": 8,
		"armor": 4, "xp": 28, "spells": [],
		"weapon": {"name": "Attaque naturelle", "damage": 10, "dice_count": 3, "dice_modifier": 5,
			"weapon_type": "melee", "min_range": 1, "max_range": 1},
		"sprite_from": "Barbare",
	},
	"Troll géant maladroit": {
		"max_hp": 50, "max_pm": 3, "max_ea": 0, "courage": 20,
		"attack": 7, "parade": 5, "adresse": 8,
		"force": 17, "intelligence": 8, "charisme": 8, "chance": 8,
		"armor": 3, "xp": 35, "spells": [],
		"weapon": {"name": "Attaque naturelle", "damage": 10, "dice_count": 3, "dice_modifier": 2,
			"weapon_type": "melee", "min_range": 1, "max_range": 1},
		"sprite_from": "Barbare",
	},
	"Guerrier maudit perdu": {
		"max_hp": 40, "max_pm": 3, "max_ea": 0, "courage": 18,
		"attack": 12, "parade": 12, "adresse": 8,
		"force": 8, "intelligence": 8, "charisme": 8, "chance": 8,
		"armor": 6, "xp": 40, "spells": [],
		"weapon": {"name": "Attaque naturelle", "damage": 10, "dice_count": 1, "dice_modifier": 6,
			"weapon_type": "melee", "min_range": 1, "max_range": 1},
		"sprite_from": "Orc",
	},
	"Hippogriffe": {
		"max_hp": 70, "max_pm": 3, "max_ea": 0, "courage": 20,
		"attack": 8, "parade": 4, "adresse": 8,
		"force": 8, "intelligence": 8, "charisme": 8, "chance": 8,
		"armor": 5, "xp": 40, "spells": [],
		"weapon": {"name": "Attaque naturelle", "damage": 10, "dice_count": 2, "dice_modifier": 5,
			"weapon_type": "melee", "min_range": 1, "max_range": 1},
		"sprite_from": "Barbare",
	},
	"Nécrophage frénétique": {
		"max_hp": 40, "max_pm": 3, "max_ea": 0, "courage": 1000,
		"attack": 12, "parade": 6, "adresse": 8,
		"force": 8, "intelligence": 8, "charisme": 8, "chance": 8,
		"armor": 2, "xp": 35, "spells": [],
		"weapon": {"name": "Attaque naturelle", "damage": 10, "dice_count": 1, "dice_modifier": 6,
			"weapon_type": "melee", "min_range": 1, "max_range": 1},
		"sprite_from": "Orc",
	},
	"Brûleur": {
		"max_hp": 60, "max_pm": 3, "max_ea": 0, "courage": 20,
		"attack": 14, "parade": 4, "adresse": 8,
		"force": 8, "intelligence": 8, "charisme": 8, "chance": 8,
		"armor": 4, "xp": 75, "spells": [],
		"weapon": {"name": "Attaque naturelle", "damage": 10, "dice_count": 2, "dice_modifier": 2,
			"weapon_type": "melee", "min_range": 1, "max_range": 1},
		"traits": {"thunder_contact": {"chance": 0.34, "damage": 6}},
		"sprite_from": "Barbare",
	},
	"Dragon de banlieue adulte": {
		"max_hp": 65, "max_pm": 3, "max_ea": 0, "courage": 20,
		"attack": 13, "parade": 8, "adresse": 8,
		"force": 8, "intelligence": 8, "charisme": 8, "chance": 8,
		"armor": 6, "xp": 80, "spells": [],
		"weapon": {"name": "Attaque naturelle", "damage": 10, "dice_count": 2, "dice_modifier": 8,
			"weapon_type": "melee", "min_range": 1, "max_range": 1},
		"sprite_from": "Barbare",
	},
	"Dragon de banlieue affamé": {
		"max_hp": 80, "max_pm": 3, "max_ea": 0, "courage": 20,
		"attack": 14, "parade": 9, "adresse": 8,
		"force": 8, "intelligence": 8, "charisme": 8, "chance": 8,
		"armor": 7, "xp": 110, "spells": [],
		"weapon": {"name": "Attaque naturelle", "damage": 10, "dice_count": 3, "dice_modifier": 5,
			"weapon_type": "melee", "min_range": 1, "max_range": 1},
		"sprite_from": "Barbare",
	},
	"Rat": {
		"max_hp": 6, "max_pm": 3, "max_ea": 0, "courage": 4,
		"attack": 8, "parade": 3, "adresse": 8,
		"force": 8, "intelligence": 8, "charisme": 8, "chance": 8,
		"armor": 0, "xp": 3, "spells": [],
		"weapon": {"name": "Attaque naturelle", "damage": 10, "dice_count": 1, "dice_modifier": 0,
			"weapon_type": "melee", "min_range": 1, "max_range": 1},
		"sprite_from": "Orc",
	},
	"Gobelin des Tréfonds": {
		"max_hp": 12, "max_pm": 3, "max_ea": 0, "courage": 6,
		"attack": 8, "parade": 5, "adresse": 8,
		"force": 8, "intelligence": 8, "charisme": 8, "chance": 8,
		"armor": 1, "xp": 6, "spells": [],
		"weapon": {"name": "Attaque naturelle", "damage": 10, "dice_count": 1, "dice_modifier": 1,
			"weapon_type": "melee", "min_range": 1, "max_range": 1},
		"sprite_from": "Orc",
	},
	"Kobold mineur": {
		"max_hp": 12, "max_pm": 3, "max_ea": 0, "courage": 8,
		"attack": 8, "parade": 5, "adresse": 8,
		"force": 8, "intelligence": 8, "charisme": 8, "chance": 8,
		"armor": 1, "xp": 7, "spells": [],
		"weapon": {"name": "Attaque naturelle", "damage": 10, "dice_count": 1, "dice_modifier": 2,
			"weapon_type": "melee", "min_range": 1, "max_range": 1},
		"sprite_from": "Orc",
	},
	"Golem d'argile mineur": {
		"max_hp": 20, "max_pm": 3, "max_ea": 0, "courage": 10,
		"attack": 6, "parade": 2, "adresse": 8,
		"force": 8, "intelligence": 8, "charisme": 8, "chance": 8,
		"armor": 2, "xp": 9, "spells": [],
		"weapon": {"name": "Attaque naturelle", "damage": 10, "dice_count": 1, "dice_modifier": 2,
			"weapon_type": "melee", "min_range": 1, "max_range": 1},
		"sprite_from": "Barbare",
	},
	"Golem d'argile majeur": {
		"max_hp": 30, "max_pm": 3, "max_ea": 0, "courage": 12,
		"attack": 8, "parade": 5, "adresse": 8,
		"force": 8, "intelligence": 8, "charisme": 8, "chance": 8,
		"armor": 2, "xp": 15, "spells": [],
		"weapon": {"name": "Attaque naturelle", "damage": 10, "dice_count": 1, "dice_modifier": 4,
			"weapon_type": "melee", "min_range": 1, "max_range": 1},
		"sprite_from": "Barbare",
	},
	"Squelette d'aventurier": {
		"max_hp": 35, "max_pm": 3, "max_ea": 0, "courage": 11,
		"attack": 8, "parade": 10, "adresse": 8,
		"force": 8, "intelligence": 8, "charisme": 8, "chance": 8,
		"armor": 2, "xp": 16, "spells": [],
		"weapon": {"name": "Attaque naturelle", "damage": 10, "dice_count": 1, "dice_modifier": 4,
			"weapon_type": "melee", "min_range": 1, "max_range": 1},
		"sprite_from": "Orc",
	},
	"Goule": {
		"max_hp": 22, "max_pm": 3, "max_ea": 0, "courage": 14,
		"attack": 10, "parade": 8, "adresse": 8,
		"force": 8, "intelligence": 8, "charisme": 8, "chance": 8,
		"armor": 2, "xp": 18, "spells": [],
		"weapon": {"name": "Attaque naturelle", "damage": 10, "dice_count": 1, "dice_modifier": 4,
			"weapon_type": "melee", "min_range": 1, "max_range": 1},
		"traits": {"paralyze": {"turns": 1, "chance": 1.0}},
		"sprite_from": "Orc",
	},
	"Goule ancienne": {
		"max_hp": 28, "max_pm": 3, "max_ea": 0, "courage": 18,
		"attack": 11, "parade": 9, "adresse": 8,
		"force": 8, "intelligence": 8, "charisme": 8, "chance": 8,
		"armor": 3, "xp": 25, "spells": [],
		"weapon": {"name": "Attaque naturelle", "damage": 10, "dice_count": 1, "dice_modifier": 6,
			"weapon_type": "melee", "min_range": 1, "max_range": 1},
		"traits": {"paralyze": {"turns": 2, "chance": 1.0}},
		"sprite_from": "Orc",
	},
	"Duergar": {
		"max_hp": 20, "max_pm": 3, "max_ea": 0, "courage": 12,
		"attack": 10, "parade": 9, "adresse": 8,
		"force": 8, "intelligence": 8, "charisme": 8, "chance": 8,
		"armor": 2, "xp": 20, "spells": [],
		"weapon": {"name": "Attaque naturelle", "damage": 10, "dice_count": 1, "dice_modifier": 5,
			"weapon_type": "melee", "min_range": 1, "max_range": 1},
		"sprite_from": "Orc",
	},
	"Guerrier maudit affaibli": {
		"max_hp": 35, "max_pm": 3, "max_ea": 0, "courage": 20,
		"attack": 11, "parade": 10, "adresse": 8,
		"force": 8, "intelligence": 8, "charisme": 8, "chance": 8,
		"armor": 4, "xp": 25, "spells": [],
		"weapon": {"name": "Attaque naturelle", "damage": 10, "dice_count": 1, "dice_modifier": 5,
			"weapon_type": "melee", "min_range": 1, "max_range": 1},
		"sprite_from": "Orc",
	},
	"Rübezahl": {
		"max_hp": 40, "max_pm": 3, "max_ea": 0, "courage": 15,
		"attack": 7, "parade": 7, "adresse": 8,
		"force": 8, "intelligence": 8, "charisme": 8, "chance": 8,
		"armor": 3, "xp": 30, "spells": [],
		"weapon": {"name": "Attaque naturelle", "damage": 10, "dice_count": 4, "dice_modifier": 0,
			"weapon_type": "melee", "min_range": 1, "max_range": 1},
		"sprite_from": "Barbare",
	},
	"Golem de cristal": {
		"max_hp": 50, "max_pm": 3, "max_ea": 0, "courage": 20,
		"attack": 11, "parade": 10, "adresse": 8,
		"force": 8, "intelligence": 8, "charisme": 8, "chance": 8,
		"armor": 5, "xp": 40, "spells": [],
		"weapon": {"name": "Attaque naturelle", "damage": 10, "dice_count": 2, "dice_modifier": 2,
			"weapon_type": "melee", "min_range": 1, "max_range": 1},
		"traits": {"reflect_magic": 0.25},
		"sprite_from": "Barbare",
	},
	"Golem de cristal primordial": {
		"max_hp": 70, "max_pm": 3, "max_ea": 0, "courage": 20,
		"attack": 12, "parade": 12, "adresse": 8,
		"force": 8, "intelligence": 8, "charisme": 8, "chance": 8,
		"armor": 7, "xp": 55, "spells": [],
		"weapon": {"name": "Attaque naturelle", "damage": 10, "dice_count": 2, "dice_modifier": 4,
			"weapon_type": "melee", "min_range": 1, "max_range": 1},
		"traits": {"reflect_magic": 0.5},
		"sprite_from": "Barbare",
	},
	"Troll des Tréfonds": {
		"max_hp": 55, "max_pm": 3, "max_ea": 0, "courage": 20,
		"attack": 10, "parade": 7, "adresse": 8,
		"force": 8, "intelligence": 8, "charisme": 8, "chance": 8,
		"armor": 4, "xp": 45, "spells": [],
		"weapon": {"name": "Attaque naturelle", "damage": 10, "dice_count": 3, "dice_modifier": 2,
			"weapon_type": "melee", "min_range": 1, "max_range": 1},
		"sprite_from": "Barbare",
	},
	"Gorgone": {
		"max_hp": 40, "max_pm": 3, "max_ea": 0, "courage": 20,
		"attack": 10, "parade": 10, "adresse": 8,
		"force": 8, "intelligence": 8, "charisme": 8, "chance": 8,
		"armor": 3, "xp": 70, "spells": [],
		"weapon": {"name": "Attaque naturelle", "damage": 10, "dice_count": 1, "dice_modifier": 8,
			"weapon_type": "melee", "min_range": 1, "max_range": 1},
		"traits": {"gaze": true, "stat_drain": {"amount": 1, "max": 3, "name": "Pétrification"}},
		"sprite_from": "Elfe",
	},
	"Ver-dragon": {
		"max_hp": 70, "max_pm": 3, "max_ea": 0, "courage": 20,
		"attack": 13, "parade": 9, "adresse": 8,
		"force": 8, "intelligence": 8, "charisme": 8, "chance": 8,
		"armor": 6, "xp": 85, "spells": [],
		"weapon": {"name": "Attaque naturelle", "damage": 10, "dice_count": 2, "dice_modifier": 8,
			"weapon_type": "melee", "min_range": 1, "max_range": 1},
		"traits": {"immune_poison": true, "acid": 1},
		"sprite_from": "Barbare",
	},
	"Balrog": {
		"max_hp": 80, "max_pm": 3, "max_ea": 0, "courage": 1000,
		"attack": 14, "parade": 10, "adresse": 8,
		"force": 8, "intelligence": 8, "charisme": 8, "chance": 8,
		"armor": 5, "xp": 100, "spells": [],
		"weapon": {"name": "Attaque naturelle", "damage": 10, "dice_count": 2, "dice_modifier": 7,
			"weapon_type": "melee", "min_range": 1, "max_range": 1},
		"sprite_from": "Barbare",
	},
	"Capitaine balrog": {
		"max_hp": 100, "max_pm": 3, "max_ea": 0, "courage": 1000,
		"attack": 15, "parade": 12, "adresse": 8,
		"force": 8, "intelligence": 8, "charisme": 8, "chance": 8,
		"armor": 5, "xp": 160, "spells": [],
		"weapon": {"name": "Attaque naturelle", "damage": 10, "dice_count": 2, "dice_modifier": 10,
			"weapon_type": "melee", "min_range": 1, "max_range": 1},
		"sprite_from": "Barbare",
	},
	"Momie": {
		"max_hp": 18, "max_pm": 3, "max_ea": 0, "courage": 1000,
		"attack": 8, "parade": 5, "adresse": 8,
		"force": 8, "intelligence": 8, "charisme": 8, "chance": 8,
		"armor": 1, "xp": 10, "spells": [],
		"weapon": {"name": "Attaque naturelle", "damage": 10, "dice_count": 1, "dice_modifier": 1,
			"weapon_type": "melee", "min_range": 1, "max_range": 1},
		"sprite_from": "Orc",
	},
	"Homme des sables": {
		"max_hp": 20, "max_pm": 3, "max_ea": 0, "courage": 10,
		"attack": 8, "parade": 8, "adresse": 8,
		"force": 8, "intelligence": 8, "charisme": 8, "chance": 8,
		"armor": 1, "xp": 12, "spells": [],
		"weapon": {"name": "Attaque naturelle", "damage": 10, "dice_count": 1, "dice_modifier": 3,
			"weapon_type": "melee", "min_range": 1, "max_range": 1},
		"sprite_from": "Orc",
	},
	"Garde de la pyramide": {
		"max_hp": 30, "max_pm": 3, "max_ea": 0, "courage": 12,
		"attack": 10, "parade": 10, "adresse": 8,
		"force": 8, "intelligence": 8, "charisme": 8, "chance": 8,
		"armor": 2, "xp": 18, "spells": [],
		"weapon": {"name": "Attaque naturelle", "damage": 10, "dice_count": 1, "dice_modifier": 5,
			"weapon_type": "melee", "min_range": 1, "max_range": 1},
		"sprite_from": "Orc",
	},
	"Esclavagiste": {
		"max_hp": 25, "max_pm": 3, "max_ea": 0, "courage": 10,
		"attack": 8, "parade": 10, "adresse": 8,
		"force": 8, "intelligence": 8, "charisme": 8, "chance": 8,
		"armor": 2, "xp": 25, "spells": [],
		"weapon": {"name": "Attaque naturelle", "damage": 10, "dice_count": 1, "dice_modifier": 5,
			"weapon_type": "melee", "min_range": 1, "max_range": 1},
		"sprite_from": "Orc",
	},
	"Sphinx": {
		"max_hp": 60, "max_pm": 3, "max_ea": 0, "courage": 20,
		"attack": 8, "parade": 5, "adresse": 8,
		"force": 8, "intelligence": 8, "charisme": 8, "chance": 8,
		"armor": 5, "xp": 60, "spells": [],
		"weapon": {"name": "Attaque naturelle", "damage": 10, "dice_count": 2, "dice_modifier": 7,
			"weapon_type": "melee", "min_range": 1, "max_range": 1},
		"traits": {"immune_magic": true},
		"sprite_from": "Barbare",
	},
	"Pharaon": {
		"max_hp": 35, "max_pm": 3, "max_ea": 0, "courage": 18,
		"attack": 12, "parade": 12, "adresse": 8,
		"force": 8, "intelligence": 8, "charisme": 8, "chance": 8,
		"armor": 2, "xp": 70, "spells": [],
		"weapon": {"name": "Attaque naturelle", "damage": 10, "dice_count": 1, "dice_modifier": 7,
			"weapon_type": "melee", "min_range": 1, "max_range": 1},
		"ambidextrie": true,
		"weapon_off_hand": {"name": "Attaque naturelle (main gauche)", "damage": 10, "dice_count": 1, "dice_modifier": 7,
			"weapon_type": "melee", "min_range": 1, "max_range": 1},
		"sprite_from": "Elfe",
	},
	"Mage de sable": {
		"max_hp": 35, "max_pm": 3, "max_ea": 30, "courage": 14,
		"attack": 9, "parade": 9, "adresse": 8,
		"force": 8, "intelligence": 8, "charisme": 8, "chance": 8,
		"armor": 1, "xp": 40, "spells": [],
		"catalog_weapon": "Dague d'artisan renommé",
		"spell_sets": ["mage_feu"],
		"sprite_from": "Mage",
	},
}

const FLOORS: Array = [
	{
		"floor": 1, "name": "Les chiens sauvages", "mode": "classic",
		"obstacles": [], "water": [], "void": [],
		"enemies": ["Chien sauvage", "Chien sauvage", "Chien sauvage", "Chien sauvage"],
	},
	{
		"floor": 2, "name": "La horde de la lande", "mode": "classic",
		"obstacles": [], "water": [], "void": [],
		"enemies": ["Chien sauvage", "Chien sauvage", "Kallikantzaroi", "Kallikantzaroi", "Kallikantzaroi"],
	},
	{
		"floor": 3, "name": "Le géant bleu", "mode": "classic",
		"obstacles": ROCKS, "water": [], "void": [],
		"enemies": ["Ogre à peau bleue", "Kallikantzaroi", "Kallikantzaroi"],
	},
	{
		"floor": 4, "name": "La lisière", "mode": "classic",
		"obstacles": TREES, "water": [], "void": [],
		"enemies": ["Brigand costaud", "Brigand costaud", "Loup", "Loup"],
		"traps": ["dalle"],  # Pièges ennemis posés au sol (invisibles tant que non détectés).
	},
	{
		"floor": 5, "name": "Le campement orque", "mode": "classic",
		"obstacles": TREES, "water": [], "void": [],
		"enemies": ["Orque d'élite", "Orque offensif", "Orque offensif", "Elfe sylvain", "Elfe sylvain", "Elfe sylvain"],
		"traps": ["loup"],  # Pièges ennemis posés au sol (invisibles tant que non détectés).
	},
	{
		"floor": 6, "name": "Les mercenaires errants", "mode": "ambush",
		"obstacles": TREES, "water": [], "void": [],
		"enemies": ["Mercenaire errant", "Troll berserk débile", "Loup", "Loup"],
		"traps": ["loup", "dalle"],  # Pièges ennemis posés au sol (invisibles tant que non détectés).
	},
	{
		"floor": 7, "name": "Le gardien de la forêt", "mode": "classic",
		"obstacles": TREES, "water": [], "void": [],
		"enemies": ["Ent", "Elfe sylvain", "Elfe sylvain", "Elfe sylvain", "Loup", "Loup"],
		"traps": ["loup", "dalle"],  # Pièges ennemis posés au sol (invisibles tant que non détectés).
	},
	{
		"floor": 8, "name": "La canopée", "mode": "classic",
		"obstacles": TREES, "water": [], "void": [],
		"enemies": ["Petit singe", "Petit singe", "Indigène agressif", "Indigène agressif", "Jaguar", "Jaguar"],
		"traps": ["dalle", "gaz"],  # Pièges ennemis posés au sol (invisibles tant que non détectés).
	},
	{
		"floor": 9, "name": "Les chasseurs de la jungle", "mode": "classic",
		"obstacles": TREES, "water": [], "void": [],
		"enemies": ["Grand singe", "Grand singe", "Jaguar", "Jaguar", "Indigène agressif", "Chaman indigène"],
		"traps": ["loup", "gaz"],  # Pièges ennemis posés au sol (invisibles tant que non détectés).
	},
	{
		"floor": 10, "name": "Le chef de tribu", "mode": "classic",
		"obstacles": TREES, "water": [], "void": [],
		"enemies": ["Chef de tribu indigène", "Chaman indigène", "Chupacabra"],
		"traps": ["dalle", "gaz", "repousse"],  # Pièges ennemis posés au sol (invisibles tant que non détectés).
	},
	{
		"floor": 11, "name": "Le sentier des chèvres", "mode": "classic",
		"obstacles": ROCKS, "water": [], "void": [],
		"enemies": ["Ours", "Ours", "Troll des montagnes", "Ogre débile", "Prospecteur nain", "Prospecteur nain", "Bouc en colère", "Bouc en colère"],
		"traps": ["dalle", "repousse"],  # Pièges ennemis posés au sol (invisibles tant que non détectés).
	},
	{
		"floor": 12, "name": "La mine abandonnée", "mode": "classic",
		"obstacles": ROCKS, "water": [], "void": [],
		"enemies": ["Maman ours", "Ours", "Prospecteur nain", "Prospecteur nain", "Troll des montagnes", "Ogre débile"],
		"traps": ["dalle", "dalle", "explosif"],  # Pièges ennemis posés au sol (invisibles tant que non détectés).
	},
	{
		"floor": 13, "name": "La tanière", "mode": "classic",
		"obstacles": ROCKS, "water": [], "void": [],
		"enemies": ["Dragon des cimes", "Élémentaire de pierre", "Ours", "Prospecteur nain"],
		"traps": ["explosif", "repousse"],  # Pièges ennemis posés au sol (invisibles tant que non détectés).
	},
	{
		"floor": 14, "name": "Le pic des vouivres", "mode": "classic",
		"obstacles": ROCKS, "water": [], "void": [],
		"enemies": ["Vouivre", "Dragon des cimes", "Prospecteur nain", "Prospecteur nain"],
		"traps": ["dalle", "explosif", "repousse"],  # Pièges ennemis posés au sol (invisibles tant que non détectés).
	},
	{
		"floor": 15, "name": "La plage", "mode": "classic",
		"obstacles": [], "water": RIVER, "void": [],
		"enemies": ["Brigand costaud", "Brigand costaud", "Brigand costaud", "Ogre mutant débile", "Troll géant maladroit", "Hippogriffe", "Nécrophage frénétique"],
		"traps": ["loup", "gaz"],  # Pièges ennemis posés au sol (invisibles tant que non détectés).
	},
	{
		"floor": 16, "name": "Le port maudit", "mode": "ambush",
		"obstacles": [], "water": RIVER, "void": [],
		"enemies": ["Guerrier maudit perdu", "Guerrier maudit perdu", "Prêtre de la nuit", "Nécrophage frénétique", "Nécrophage frénétique", "Brigand costaud"],
		"traps": ["dalle", "vievore"],  # Pièges ennemis posés au sol (invisibles tant que non détectés).
	},
	{
		"floor": 17, "name": "Le nid du dragon", "mode": "classic",
		"obstacles": [], "water": RIVER, "void": [],
		"enemies": ["Dragon de banlieue affamé", "Hippogriffe", "Nécrophage frénétique", "Brigand costaud"],
		"traps": ["explosif", "molotov"],  # Pièges ennemis posés au sol (invisibles tant que non détectés).
	},
	{
		"floor": 18, "name": "L'entrée des tréfonds", "mode": "classic",
		"obstacles": PILLARS, "water": [], "void": [],
		"enemies": ["Squelette d'aventurier", "Squelette d'aventurier", "Goule ancienne", "Goule ancienne", "Duergar", "Duergar", "Troll des Tréfonds", "Golem de cristal"],
		"traps": ["vievore", "manavore"],  # Pièges ennemis posés au sol (invisibles tant que non détectés).
	},
	{
		"floor": 19, "name": "Les galeries", "mode": "classic",
		"obstacles": PILLARS, "water": [], "void": [],
		"enemies": ["Golem de cristal", "Rübezahl", "Troll des Tréfonds", "Guerrier maudit affaibli", "Guerrier maudit affaibli", "Goule ancienne", "Duergar"],
		"traps": ["dalle", "dalle", "gaz"],  # Pièges ennemis posés au sol (invisibles tant que non détectés).
	},
	{
		"floor": 20, "name": "Le cœur de cristal", "mode": "classic",
		"obstacles": PILLARS, "water": [], "void": [],
		"enemies": ["Golem de cristal primordial", "Golem de cristal", "Golem de cristal", "Rübezahl", "Duergar", "Duergar", "Goule ancienne"],
		"traps": ["manavore", "vievore", "repousse"],  # Pièges ennemis posés au sol (invisibles tant que non détectés).
	},
	{
		"floor": 21, "name": "Le regard de pierre", "mode": "classic",
		"obstacles": PILLARS, "water": [], "void": [],
		"enemies": ["Gorgone", "Ver-dragon", "Troll des Tréfonds", "Golem de cristal"],
		"traps": ["dalle", "gaz", "explosif"],  # Pièges ennemis posés au sol (invisibles tant que non détectés).
	},
	{
		"floor": 22, "name": "Les dunes", "mode": "classic",
		"obstacles": [], "water": [], "void": [],
		"enemies": ["Garde de la pyramide", "Garde de la pyramide", "Mage de sable", "Mage de sable", "Esclavagiste", "Sphinx", "Ver des sables géant", "Mage de feu"],
		"traps": ["dalle", "dalle", "loup"],  # Pièges ennemis posés au sol (invisibles tant que non détectés).
	},
	{
		"floor": 23, "name": "L'oasis maudite", "mode": "classic",
		"obstacles": [], "water": [], "void": [],
		"enemies": ["Sphinx", "Mage de sable", "Mage de sable", "Mage de sable", "Garde de la pyramide", "Garde de la pyramide", "Esclavagiste", "Ver des sables géant"],
		"traps": ["gaz", "molotov", "vievore"],  # Pièges ennemis posés au sol (invisibles tant que non détectés).
	},
	{
		"floor": 24, "name": "Le temple du sphinx", "mode": "classic",
		"obstacles": PILLARS, "water": [], "void": [],
		"enemies": ["Sphinx", "Sphinx", "Mage de sable", "Mage de sable", "Garde de la pyramide", "Garde de la pyramide", "Ver des sables géant", "Esclavagiste"],
		"traps": ["dalle", "explosif", "repousse", "gaz"],  # Pièges ennemis posés au sol (invisibles tant que non détectés).
	},
	{
		"floor": 25, "name": "Le tombeau du pharaon", "mode": "classic",
		"obstacles": PILLARS, "water": [], "void": [],
		"enemies": ["Pharaon", "Sphinx", "Sphinx", "Mage de sable", "Mage de sable", "Ver des sables géant", "Esclavagiste"],
		"traps": ["explosif", "molotov", "dalle", "manavore", "gaz"],  # Pièges ennemis posés au sol (invisibles tant que non détectés).
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
