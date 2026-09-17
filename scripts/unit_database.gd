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
		"attack": 14,
		"parade": 10,
		"adresse": 6,
		"force": 16,
		"intelligence": 6,
		"charisme": 8,
		"chance": 10,
		"ambidextrie": true,  # Peut équiper une 2e arme -> 2 attaques d'arme par tour.
		"weapon": {"name": "Hache principale", "damage": 22, "weapon_type": "melee", "min_range": 1, "max_range": 1},
		"weapon_off_hand": {"name": "Hache secondaire", "damage": 16, "weapon_type": "melee", "min_range": 1, "max_range": 1},
		"spells": [
			{"name": "Bond", "ea_cost": 2, "min_range": 1, "max_range": 3, "damage": 8, "spell_type": "physical"},
		],
		"potions": [
			{"name": "Potion de soin", "type": "heal", "amount": 25},
		],
		"inventory_weapons": [
			{"name": "Marteau de guerre", "damage": 30, "weapon_type": "melee", "min_range": 1, "max_range": 1},
		],
		# Feuille de sprites 768x256 = grille 24 colonnes x 8 lignes de
		# cases 32x32. 8 vraies orientations dessinées, une par ligne
		# (voir DIRECTION_ROWS ci-dessous) : le découpage par colonnes
		# (idle/marche/attaque/dégât/mort) est identique sur les 8
		# lignes, donc build_sprite_animations() génère automatiquement
		# les 8 variantes de chaque animation à partir de la config
		# "action_columns" ci-dessous (pas besoin de les taper à la main).
		#
		# NON VÉRIFIÉ : "ranged_attack" (colonnes 9-12) et "cast"
		# (colonnes 13-16) d'après la légende fournie — mais ces colonnes
		# ressemblent visuellement à des portraits en gros plan plutôt
		# qu'à une animation de tir/sort. Sans impact pour le Barbare
		# (pas d'arme à distance), à vérifier si réutilisé ailleurs. Pas
		# de variante directionnelle pour ces deux-là (voir "extra_animations").
		"sprite": {
			"path": "res://assets/sprites/Warrior-Red.png",
			"frame_width": 32,
			"frame_height": 32,
			"scale": 2.0,
			"y_offset": 15,
			"action_columns": {
				"idle":   {"start_col": 0,  "frame_count": 1, "fps": 6.0,  "loop": false},
				"walk":   {"start_col": 2,  "frame_count": 2, "fps": 8.0,  "loop": true},
				"attack": {"start_col": 4,  "frame_count": 4, "fps": 10.0, "loop": false},
				"hurt":   {"start_col": 19, "frame_count": 1, "fps": 6.0,  "loop": false},
				"death":  {"start_col": 22, "frame_count": 1, "fps": 4.0,  "loop": false},
			},
			"extra_animations": {
				"ranged_attack": {"row": 0, "start_col": 8,  "frame_count": 4, "fps": 10.0, "loop": false},
				"cast":          {"row": 0, "start_col": 12, "frame_count": 4, "fps": 10.0, "loop": false},
			},
		},
	},
	"Haut Elfe": {
		"max_hp": 45,
		"max_pm": 3,
		"max_ea": 6,
		"courage": 9,
		"attack": 11,
		"parade": 5,
		"adresse": 14,
		"force": 8,
		"intelligence": 15,
		"charisme": 11,
		"chance": 13,
		# Arme à distance : son "attaque d'arme" tire une flèche au lieu
		# de frapper au contact — même règles (gratuite, 1/tour) qu'une
		# arme de mêlée, juste une portée différente.
		"weapon": {"name": "Arc léger", "damage": 14, "weapon_type": "ranged", "min_range": 2, "max_range": 5},
		"spells": [
			{"name": "Flèche Magique",   "ea_cost": 3, "min_range": 2, "max_range": 6, "damage": 18, "spell_type": "physical"},
			{"name": "Flèche Enflammée", "ea_cost": 4, "min_range": 3, "max_range": 8, "damage": 22, "spell_type": "physical"},
		],
		"arrows": [
			{"name": "Flèche normale",   "damage_bonus": 0, "quantity": 20},
			{"name": "Flèche perçante",  "damage_bonus": 6, "quantity": 5},
			{"name": "Flèche barbelée",  "damage_bonus": 3, "quantity": 8},
		],
		"potions": [
			{"name": "Potion de mana", "type": "mana", "amount": 3},
		],
			"sprite": {
			"path": "res://assets/sprites/Archer-Green.png",
			"frame_width": 32,
			"frame_height": 32,
			"scale": 2.0,
			"y_offset": 15,
			"action_columns": {
				"idle":   {"start_col": 0,  "frame_count": 1, "fps": 6.0,  "loop": false},
				"walk":   {"start_col": 2,  "frame_count": 2, "fps": 8.0,  "loop": true},
				"attack": {"start_col": 4,  "frame_count": 4, "fps": 10.0, "loop": false},
				"hurt":   {"start_col": 19, "frame_count": 1, "fps": 6.0,  "loop": false},
				"death":  {"start_col": 22, "frame_count": 1, "fps": 4.0,  "loop": false},
			},
			"extra_animations": {
				"ranged_attack": {"row": 0, "start_col": 8,  "frame_count": 4, "fps": 10.0, "loop": false},
				"cast":          {"row": 0, "start_col": 12, "frame_count": 4, "fps": 10.0, "loop": false},
			},
		},
	},
	"Walkyrie": {
		"max_hp": 45,
		"max_pm": 3,
		"max_ea": 6,
		"courage": 6,
		"attack": 12,
		"parade": 9,
		"adresse": 9,
		"force": 9,
		"intelligence": 14,
		"charisme": 16,
		"chance": 12,
		"weapon": {"name": "Fléau sacré", "damage": 15, "weapon_type": "melee", "min_range": 1, "max_range": 1},
		"spells": [
			# Un "dégât" négatif soigne (voir take_damage dans unit.gd).
			{"name": "Mot Soignant", "ea_cost": 3, "min_range": 1, "max_range": 4, "damage": -20, "spell_type": "psychic"},
			{"name": "Mot Piquant",  "ea_cost": 3, "min_range": 1, "max_range": 5, "damage": 10, "spell_type": "psychic"},
		],
		"potions": [
			{"name": "Potion de soin", "type": "heal", "amount": 20},
		],	"sprite": {
			"path": "res://assets/sprites/Mage-Cyan.png",
			"frame_width": 32,
			"frame_height": 32,
			"scale": 2.0,
			"y_offset": 15,
			"action_columns": {
				"idle":   {"start_col": 0,  "frame_count": 1, "fps": 6.0,  "loop": false},
				"walk":   {"start_col": 2,  "frame_count": 2, "fps": 8.0,  "loop": true},
				"attack": {"start_col": 4,  "frame_count": 4, "fps": 10.0, "loop": false},
				"hurt":   {"start_col": 19, "frame_count": 1, "fps": 6.0,  "loop": false},
				"death":  {"start_col": 22, "frame_count": 1, "fps": 4.0,  "loop": false},
			},
			"extra_animations": {
				"ranged_attack": {"row": 0, "start_col": 8,  "frame_count": 4, "fps": 10.0, "loop": false},
				"cast":          {"row": 0, "start_col": 12, "frame_count": 4, "fps": 10.0, "loop": false},
			},
		},
	},
	"Bouftou": {
		"max_hp": 50,
		"max_pm": 3,
		"max_ea": 6,
		"courage": 8,
		"attack": 9,
		"parade": 4,
		"adresse": 6,
		"force": 11,
		"intelligence": 5,
		"charisme": 4,
		"chance": 7,
		"weapon": {"name": "Corne", "damage": 15, "weapon_type": "melee", "min_range": 1, "max_range": 1},
		"spells": [],	"sprite": {
			"path": "res://assets/sprites/Orc-Grunt.png",
			"frame_width": 32,
			"frame_height": 32,
			"scale": 2.0,
			"y_offset": 15,
			"action_columns": {
				"idle":   {"start_col": 0,  "frame_count": 1, "fps": 6.0,  "loop": false},
				"walk":   {"start_col": 2,  "frame_count": 2, "fps": 8.0,  "loop": true},
				"attack": {"start_col": 4,  "frame_count": 4, "fps": 10.0, "loop": false},
				"hurt":   {"start_col": 19, "frame_count": 1, "fps": 6.0,  "loop": false},
				"death":  {"start_col": 22, "frame_count": 1, "fps": 4.0,  "loop": false},
			},
			"extra_animations": {
				"ranged_attack": {"row": 0, "start_col": 8,  "frame_count": 4, "fps": 10.0, "loop": false},
				"cast":          {"row": 0, "start_col": 12, "frame_count": 4, "fps": 10.0, "loop": false},
			},
		},
	},
}

# Mapping direction -> ligne du spritesheet, confirmé pour ce pack :
# 8 orientations, une par ligne (0=sud, 1=sud-est, 2=est, 3=nord-est,
# 4=nord, 5=nord-ouest, 6=ouest, 7=sud-ouest). Partagé par toutes les
# classes qui utilisent ce type de feuille de sprites à 8 directions.
const DIRECTION_ROWS: Dictionary = {
	"s": 0, "se": 1, "e": 2, "ne": 3, "n": 4, "nw": 5, "w": 6, "sw": 7,
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
		s.spell_type = Spell.SpellType.PSYCHIC if spell_data.get("spell_type", "physical") == "psychic" else Spell.SpellType.PHYSICAL
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

# Génère le dictionnaire complet d'animations (8 directions x chaque
# action définie dans "action_columns") à partir de la config compacte
# de UnitDatabase — évite de taper les 40 entrées à la main pour un
# personnage à 8 directions. Les entrées de "extra_animations" (sans
# variante directionnelle, ex: "cast") sont ajoutées telles quelles.
static func build_sprite_animations(template_name: String) -> Dictionary:
	var result: Dictionary = {}

	var stats = get_base_stats(template_name)
	var sprite_data = stats.get("sprite", null)
	if sprite_data == null:
		return result

	var action_columns = sprite_data.get("action_columns", {})
	for action_name in action_columns.keys():
		var cfg = action_columns[action_name]
		for dir_code in DIRECTION_ROWS.keys():
			result["%s_%s" % [action_name, dir_code]] = {
				"row": DIRECTION_ROWS[dir_code],
				"start_col": cfg.get("start_col", 0),
				"frame_count": cfg.get("frame_count", 1),
				"fps": cfg.get("fps", 6.0),
				"loop": cfg.get("loop", false),
			}

	var extra_animations = sprite_data.get("extra_animations", {})
	for extra_name in extra_animations.keys():
		result[extra_name] = extra_animations[extra_name]

	return result
