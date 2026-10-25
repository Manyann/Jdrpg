extends RefCounted
class_name ArrowCatalog

# ============================================================
# arrow_catalog.gd — liste des flèches (arc) et carreaux (arbalète).
# "category" : "Fleche" ou "Carreau". "effect" : code d'effet spécial lu
# par HexGrid (voir _apply_arrow_on_hit / _arrow_extra_targets) :
#   esq_temp (ESQ -2, 2 tours) · esq_perm (ESQ -2 jusqu'à la fin du combat)
#   at_down (AT -2) · miss_assault (la cible rate son prochain assaut)
#   bleed (hémorragie) · magic (dégâts magiques) · pierce_line (ennemis en
#   ligne derrière la cible) · multi_1 / multi_2 (AD-3, + N alliés de la
#   cible les plus proches) · vs_animal (+2 contre les animaux)
#   recover (récupérée à la fin du combat)
# "base_percentage" : taux de la donnée d'origine (rareté en boutique).
# ============================================================

const ITEMS: Array = [
	{
		"name": "Fleche de base",
		"category": "Fleche",
		"damage_bonus": 0,
		"price": 1,
		"base_percentage": 95,
		"info": "Lot de 5",
		"effect": "",
	},
	{
		"name": "Fleche de guerre",
		"category": "Fleche",
		"damage_bonus": 2,
		"price": 5,
		"base_percentage": 80,
		"info": "Lot de 5",
		"effect": "",
	},
	{
		"name": "Fleche rapide",
		"category": "Fleche",
		"damage_bonus": 0,
		"price": 5,
		"base_percentage": 80,
		"info": "Lot de 5. Cible : ESQ -2",
		"effect": "esq_temp",
	},
	{
		"name": "Fleche jumelle",
		"category": "Fleche",
		"damage_bonus": 0,
		"price": 5,
		"base_percentage": 70,
		"info": "Lot de 5. AD-3. Vise 1 cible et son allié le plus proche",
		"effect": "multi_1",
	},
	{
		"name": "Flèche glacée",
		"category": "Fleche",
		"damage_bonus": 0,
		"price": 10,
		"base_percentage": 70,
		"info": "Cible : ESQ -2 permanent",
		"effect": "esq_perm",
	},
	{
		"name": "Flèche de chasse",
		"category": "Fleche",
		"damage_bonus": 2,
		"price": 10,
		"base_percentage": 60,
		"info": "Lot de 5. +2 dégâts contre les animaux",
		"effect": "vs_animal",
	},
	{
		"name": "Flèche incapacitante",
		"category": "Fleche",
		"damage_bonus": 0,
		"price": 15,
		"base_percentage": 60,
		"info": "Cible : AT -2",
		"effect": "at_down",
	},
	{
		"name": "Flèche barbelée",
		"category": "Fleche",
		"damage_bonus": 2,
		"price": 25,
		"base_percentage": 40,
		"info": "Inflige hémorragie",
		"effect": "bleed",
	},
	{
		"name": "Flèche renforcée",
		"category": "Fleche",
		"damage_bonus": 2,
		"price": 150,
		"base_percentage": 40,
		"info": "Lot de 5. Récupérée à la fin du combat",
		"effect": "recover",
	},
	{
		"name": "Fleche éthérée",
		"category": "Fleche",
		"damage_bonus": 0,
		"price": 50,
		"base_percentage": 25,
		"info": "Dégât de l'arme devient magique",
		"effect": "magic",
	},
	{
		"name": "Carreau de base",
		"category": "Carreau",
		"damage_bonus": 0,
		"price": 1,
		"base_percentage": 95,
		"info": "Lot de 5",
		"effect": "",
	},
	{
		"name": "Carreau de guerre",
		"category": "Carreau",
		"damage_bonus": 3,
		"price": 10,
		"base_percentage": 90,
		"info": "Lot de 5",
		"effect": "",
	},
	{
		"name": "Carreau rapide",
		"category": "Carreau",
		"damage_bonus": 0,
		"price": 10,
		"base_percentage": 75,
		"info": "Lot de 5. Cible : ESQ -2",
		"effect": "esq_temp",
	},
	{
		"name": "Carreau éléctrique",
		"category": "Carreau",
		"damage_bonus": 0,
		"price": 15,
		"base_percentage": 70,
		"info": "Touche la cible et tous les ennemis en ligne droite derrière elle",
		"effect": "pierce_line",
	},
	{
		"name": "Carreau de chasse",
		"category": "Carreau",
		"damage_bonus": 2,
		"price": 15,
		"base_percentage": 70,
		"info": "Lot de 5. +2 dégâts contre les animaux",
		"effect": "vs_animal",
	},
	{
		"name": "Carreau incapacitant",
		"category": "Carreau",
		"damage_bonus": 0,
		"price": 25,
		"base_percentage": 60,
		"info": "Cible rate un assaut",
		"effect": "miss_assault",
	},
	{
		"name": "Carreau triple",
		"category": "Carreau",
		"damage_bonus": 0,
		"price": 30,
		"base_percentage": 40,
		"info": "Lot de 5. AD-3. Vise 1 cible et ses 2 alliés les plus proches",
		"effect": "multi_2",
	},
	{
		"name": "Carreau barbelé",
		"category": "Carreau",
		"damage_bonus": 2,
		"price": 35,
		"base_percentage": 40,
		"info": "Inflige hémorragie",
		"effect": "bleed",
	},
	{
		"name": "Carreau éthérée",
		"category": "Carreau",
		"damage_bonus": 0,
		"price": 75,
		"base_percentage": 25,
		"info": "Dégât de l'arme devient magique",
		"effect": "magic",
	},
	{
		"name": "Carreau renforcé",
		"category": "Carreau",
		"damage_bonus": 3,
		"price": 150,
		"base_percentage": 40,
		"info": "Lot de 5. Récupéré à la fin du combat",
		"effect": "recover",
	},
]

static func get_all() -> Array:
	return ITEMS

static func find_by_name(arrow_name: String) -> Dictionary:
	for item in ITEMS:
		if item["name"] == arrow_name:
			return item
	return {}
