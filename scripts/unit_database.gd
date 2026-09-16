extends RefCounted
class_name UnitDatabase

# ============================================================
# unit_database.gd
# Définit les stats de base, l'arme, les sorts et l'inventaire de
# départ de chaque "classe" d'unité (Barbare, Haut Elfe, Walkyrie,
# Bouftou...).
#
# Ce dictionnaire est la source de vérité pour spawn_unit() dans
# HexGrid. Pour ajouter une nouvelle classe, il suffit d'ajouter
# une entrée ici — aucun autre fichier à modifier.
#
# NOTE POUR PLUS TARD : cette structure est volontairement une
# simple constante GDScript pour aller vite maintenant. Le jour où
# l'expert data veut piloter l'équilibrage depuis un fichier JSON/CSV
# généré en Python, il suffira de remplacer TEMPLATES par un
# chargement de fichier — le reste du code n'aura pas à changer.
# ============================================================

const TEMPLATES: Dictionary = {
	"Barbare": {
		"max_hp": 60,
		"max_pm": 3,
		"max_ea": 6,
		"courage": 12,
		"ambidextrie": true,  # Peut équiper une 2e arme -> 2 attaques d'arme par tour.
		"weapon": {"name": "Hache principale", "damage": 22, "weapon_type": "melee", "min_range": 1, "max_range": 1},
		"weapon_off_hand": {"name": "Hache secondaire", "damage": 16, "weapon_type": "melee", "min_range": 1, "max_range": 1},
		"spells": [
			{"name": "Bond", "ea_cost": 2, "min_range": 1, "max_range": 3, "damage": 8},
		],
		"potions": [
			{"name": "Potion de soin", "type": "heal", "amount": 25},
		],
		"inventory_weapons": [
			{"name": "Marteau de guerre", "damage": 30, "weapon_type": "melee", "min_range": 1, "max_range": 1},
		],
	},
	"Haut Elfe": {
		"max_hp": 45,
		"max_pm": 3,
		"max_ea": 6,
		"courage": 9,
		# Arme à distance : son "attaque d'arme" tire une flèche au lieu
		# de frapper au contact — même règles (gratuite, 1/tour) qu'une
		# arme de mêlée, juste une portée différente.
		"weapon": {"name": "Arc léger", "damage": 14, "weapon_type": "ranged", "min_range": 2, "max_range": 5},
		"spells": [
			{"name": "Flèche Magique",   "ea_cost": 3, "min_range": 2, "max_range": 6, "damage": 18},
			{"name": "Flèche Enflammée", "ea_cost": 4, "min_range": 3, "max_range": 8, "damage": 22},
		],
		"arrows": [
			{"name": "Flèche normale",   "damage_bonus": 0, "quantity": 20},
			{"name": "Flèche perçante",  "damage_bonus": 6, "quantity": 5},
			{"name": "Flèche barbelée",  "damage_bonus": 3, "quantity": 8},
		],
		"potions": [
			{"name": "Potion de mana", "type": "mana", "amount": 3},
		],
	},
	"Walkyrie": {
		"max_hp": 45,
		"max_pm": 3,
		"max_ea": 6,
		"courage": 6,
		"weapon": {"name": "Fléau sacré", "damage": 15, "weapon_type": "melee", "min_range": 1, "max_range": 1},
		"spells": [
			# Un "dégât" négatif soigne (voir take_damage dans unit.gd).
			{"name": "Mot Soignant", "ea_cost": 3, "min_range": 1, "max_range": 4, "damage": -20},
			{"name": "Mot Piquant",  "ea_cost": 3, "min_range": 1, "max_range": 5, "damage": 10},
		],
		"potions": [
			{"name": "Potion de soin", "type": "heal", "amount": 20},
		],
	},
	"Bouftou": {
		"max_hp": 50,
		"max_pm": 3,
		"max_ea": 6,
		"courage": 8,
		"weapon": {"name": "Corne", "damage": 15, "weapon_type": "melee", "min_range": 1, "max_range": 1},
		"spells": [],
	},
}

# Renvoie les stats de base d'une classe (dictionnaire vide si inconnue).
static func get_base_stats(template_name: String) -> Dictionary:
	if TEMPLATES.has(template_name):
		return TEMPLATES[template_name]
	push_warning("UnitDatabase: classe inconnue '%s'." % template_name)
	return {}

# Construit la liste de Resources Spell correspondant aux sorts
# définis pour cette classe (hors attaque(s) d'arme, gérées séparément
# via build_weapon — voir CombatUnit._ready()).
static func build_spells(template_name: String) -> Array:
	var spells: Array = []

	if not TEMPLATES.has(template_name):
		return spells

	for spell_data in TEMPLATES[template_name]["spells"]:
		var s := Spell.new()
		s.spell_name = spell_data["name"]
		s.ea_cost = spell_data["ea_cost"]
		s.min_range = spell_data["min_range"]
		s.max_range = spell_data["max_range"]
		s.damage = spell_data["damage"]
		spells.append(s)

	return spells

# Construit la Resource Weapon de cette classe. `key` vaut "weapon"
# (main principale) ou "weapon_off_hand" (main secondaire, utilisée
# uniquement si l'unité a l'Ambidextrie). Renvoie null si la classe
# n'a pas d'entrée pour cette clé (ex: pas d'arme secondaire définie).
static func build_weapon(template_name: String, key: String = "weapon") -> Weapon:
	if not TEMPLATES.has(template_name):
		return null

	var weapon_data = TEMPLATES[template_name].get(key, null)
	if weapon_data == null:
		return null

	var w := Weapon.new()
	w.weapon_name = weapon_data.get("name", "Arme")
	w.damage = weapon_data.get("damage", 10)
	w.weapon_type = Weapon.WeaponType.RANGED if weapon_data.get("weapon_type", "melee") == "ranged" else Weapon.WeaponType.MELEE
	w.min_range = weapon_data.get("min_range", 1)
	w.max_range = weapon_data.get("max_range", 1)
	return w

# Construit la liste de Resources Arrow (munitions) de cette classe.
# Pertinent uniquement si l'arme équipée est à distance ; sans effet
# sinon (le choix de flèche n'est proposé que pour une arme RANGED).
static func build_arrows(template_name: String) -> Array:
	var arrows: Array = []

	if not TEMPLATES.has(template_name):
		return arrows

	for arrow_data in TEMPLATES[template_name].get("arrows", []):
		var a := Arrow.new()
		a.arrow_name = arrow_data["name"]
		a.damage_bonus = arrow_data.get("damage_bonus", 0)
		a.quantity = arrow_data.get("quantity", 10)
		arrows.append(a)

	return arrows

# Construit la liste de Resources Potion (soin/mana) de départ de
# cette classe.
static func build_potions(template_name: String) -> Array:
	var potions: Array = []

	if not TEMPLATES.has(template_name):
		return potions

	for potion_data in TEMPLATES[template_name].get("potions", []):
		var p := Potion.new()
		p.potion_name = potion_data["name"]
		p.potion_type = Potion.PotionType.MANA if potion_data.get("type", "heal") == "mana" else Potion.PotionType.HEAL
		p.amount = potion_data.get("amount", 20)
		potions.append(p)

	return potions

# Construit la liste d'armes de rechange (inventaire) de cette classe,
# permettant de changer d'arme équipée en combat via CombatUnit.equip_weapon().
static func build_inventory_weapons(template_name: String) -> Array:
	var weapons: Array = []

	if not TEMPLATES.has(template_name):
		return weapons

	for weapon_data in TEMPLATES[template_name].get("inventory_weapons", []):
		var w := Weapon.new()
		w.weapon_name = weapon_data.get("name", "Arme")
		w.damage = weapon_data.get("damage", 10)
		w.weapon_type = Weapon.WeaponType.RANGED if weapon_data.get("weapon_type", "melee") == "ranged" else Weapon.WeaponType.MELEE
		w.min_range = weapon_data.get("min_range", 1)
		w.max_range = weapon_data.get("max_range", 1)
		weapons.append(w)

	return weapons
