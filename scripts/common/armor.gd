extends Resource
class_name Armor

# ============================================================
# armor.gd
# Représente une armure (ou un bouclier/chapeau/robe...) équipable.
# Comme Weapon, applique des bonus de stats tant qu'elle est équipée
# (voir CombatUnit._recalculate_stats) — notamment bonus_armure, qui
# réduit les dégâts subis (voir HexGrid._resolve_weapon_attack etc.).
# ============================================================

@export var armor_name: String = "Armure"
@export var category: String = ""  # "Bouclier", "Armure de cuir", etc.
@export var price: int = 0
@export var info_text: String = ""

@export var bonus_courage: int = 0
@export var bonus_intelligence: int = 0
@export var bonus_charisme: int = 0
@export var bonus_adresse: int = 0
@export var bonus_force: int = 0
@export var bonus_chance: int = 0
@export var bonus_attaque: int = 0
@export var bonus_parade: int = 0
@export var bonus_armure: int = 0
@export var bonus_armure_magique: int = 0
@export var bonus_vie: int = 0
@export var bonus_mana: int = 0

func get_display_text() -> String:
	var parts = ["%s (%d Or)" % [armor_name, price]]
	for bonus_text in _describe_bonuses():
		parts.append(bonus_text)
	return " — ".join(parts)

func _describe_bonuses() -> Array:
	var descs: Array = []
	var labels = {
		"bonus_courage": "Courage", "bonus_intelligence": "Intelligence",
		"bonus_charisme": "Charisme", "bonus_adresse": "Adresse",
		"bonus_force": "Force", "bonus_chance": "Chance",
		"bonus_attaque": "Attaque", "bonus_parade": "Parade",
		"bonus_armure": "Armure", "bonus_armure_magique": "Armure magique", "bonus_vie": "PV", "bonus_mana": "EA",
	}
	for field in labels.keys():
		var val = get(field)
		if val != 0:
			descs.append("%+d %s" % [val, labels[field]])
	return descs
