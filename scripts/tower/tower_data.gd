extends RefCounted
class_name TowerData

# ============================================================
# tower_data.gd — FICHIER GÉNÉRÉ par build_tower_data.py à partir de
# tower_enemies.csv et tower_floors.csv. NE PAS MODIFIER À LA MAIN :
# modifie les tableaux et régénère (toute édition ici serait écrasée).
#
# ENEMIES : ennemis propres à la Tour, au MÊME format que
#   UnitDatabase.TEMPLATES (voir UnitDatabase._find_template). Les ennemis
#   déjà présents dans TEMPLATES (Barbare, Elfe, Mage, Orc...) n'ont pas
#   besoin d'être redéfinis ici.
# FLOORS  : un étage par entrée — la liste des ennemis qui l'occupent,
#   un nom par ennemi (répété autant de fois qu'il y en a).
# ============================================================

const ENEMIES: Dictionary = {
	"Gobelin": {
		"max_hp": 30,
		"max_pm": 4,
		"max_ea": 0,
		"courage": 9,
		"attack": 10,
		"parade": 5,
		"adresse": 9,
		"force": 7,
		"intelligence": 6,
		"charisme": 5,
		"chance": 8,
		"weapon": {"name": "Dague rouillée", "damage": 10, "weapon_type": "melee", "min_range": 1, "max_range": 1},
		"spells": [],
		"sprite_from": "Orc",
	},
	"Archer gobelin": {
		"max_hp": 25,
		"max_pm": 3,
		"max_ea": 0,
		"courage": 8,
		"attack": 11,
		"parade": 4,
		"adresse": 10,
		"force": 6,
		"intelligence": 6,
		"charisme": 5,
		"chance": 8,
		"weapon": {"name": "Arc court", "damage": 12, "weapon_type": "ranged", "min_range": 2, "max_range": 5},
		"spells": [],
		"sprite_from": "Elfe",
	},
	"Chaman orc": {
		"max_hp": 45,
		"max_pm": 3,
		"max_ea": 12,
		"courage": 7,
		"attack": 9,
		"parade": 5,
		"adresse": 7,
		"force": 8,
		"intelligence": 11,
		"charisme": 6,
		"chance": 8,
		"weapon": {"name": "Bâton noueux", "damage": 8, "weapon_type": "melee", "min_range": 1, "max_range": 1},
		"spells": [
			{"name": "Éclair", "ea_cost": 3, "min_range": 1, "max_range": 4, "damage": 14, "spell_type": "psychic", "target_mode": "enemy"},
		],
		"sprite_from": "Mage",
	},
	"Orc chef": {
		"max_hp": 90,
		"max_pm": 3,
		"max_ea": 6,
		"courage": 10,
		"attack": 12,
		"parade": 7,
		"adresse": 6,
		"force": 13,
		"intelligence": 5,
		"charisme": 6,
		"chance": 7,
		"armor": 1,
		"weapon": {"name": "Hache de guerre", "damage": 22, "weapon_type": "melee", "min_range": 1, "max_range": 1},
		"spells": [],
		"sprite_from": "Orc",
	},
}

const FLOORS: Array = [
	{"floor": 1, "name": "Le rez-de-chaussée", "enemies": ["Gobelin", "Gobelin"]},
	{"floor": 2, "name": "", "enemies": ["Gobelin", "Gobelin", "Gobelin"]},
	{"floor": 3, "name": "", "enemies": ["Gobelin", "Gobelin", "Archer gobelin"]},
	{"floor": 4, "name": "", "enemies": ["Orc", "Orc", "Chaman orc"]},
	{"floor": 5, "name": "Le gardien", "enemies": ["Orc chef", "Orc", "Orc", "Archer gobelin"]},
]
