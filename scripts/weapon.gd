extends Resource
class_name Weapon

# ============================================================
# weapon.gd
# Représente une arme (ou une "arme naturelle" pour un monstre :
# corne, griffes...) équipée par une unité. Détermine les dégâts
# ET la portée de SON attaque, générée automatiquement pour toutes
# les unités via create_attack_spell() — voir CombatUnit._ready().
#
# Une arme MELEE (épée, hache...) génère typiquement une attaque
# portée 1-1. Une arme RANGED (arc, arbalète...) génère une attaque
# à distance avec sa propre portée (ex: 2-6) — ce n'est PAS une
# "attaque mêlée" au sens géographique, mais ça reste une "attaque
# d'arme" gratuite en EA qui suit les mêmes règles d'économie
# d'action (1 par tour, ou 2 avec Ambidextrie).
# ============================================================

enum WeaponType { MELEE, RANGED }

@export var weapon_name: String = "Poings"
@export var damage: int = 5
@export var weapon_type: WeaponType = WeaponType.MELEE
@export var price: int = 0
@export var info_text: String = ""

## Dégâts en dés (façon "1D+3" = dice_count 1, dice_modifier 3, dé à 6
## faces implicite). Si dice_count = 0, l'arme fait des dégâts FIXES
## (juste dice_modifier, pas de hasard) — c'est le cas des armes
## codées à la main (Barbare, Elfe...) : `damage` ci-dessus reste leur
## valeur fixe. Les armes importées du catalogue (voir weapon_catalog.gd)
## utilisent de vrais dés. Voir roll_damage().
@export var dice_count: int = 0
@export var dice_modifier: int = 0

## Renvoie les dégâts RÉELLEMENT infligés pour un coup : lance
## dice_count dés à 6 faces + dice_modifier. Si dice_count = 0 (arme à
## dégâts fixes), renvoie simplement `damage` — pas de jet, valeur
## garantie. Appelée à chaque attaque (voir HexGrid._resolve_weapon_attack
## et _deal_counter_attack), jamais mise en cache.
func roll_damage() -> int:
	if dice_count <= 0:
		return damage

	var total = dice_modifier
	for i in range(dice_count):
		total += randi_range(1, 6)
	return total

## Bonus de stats appliqués tant que cette arme est équipée (voir
## CombatUnit._recalculate_stats). Valeur 0 = pas de bonus sur cette
## stat. Champs communs à Weapon/Armor/Accessory pour un traitement
## uniforme dans _recalculate_stats.
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

## Portée de l'attaque générée par cette arme. Pour une arme de mêlée,
## laisser 1-1. Pour une arme à distance, définir une vraie portée
## (ex: 2 à 6 pour un arc).
@export var min_range: int = 1
@export var max_range: int = 1

# Texte prêt à afficher dans une liste/boutique.
func get_display_text() -> String:
	var damage_text: String
	if dice_count > 0:
		damage_text = "%dD+%d dégâts" % [dice_count, dice_modifier] if dice_modifier >= 0 else "%dD%d dégâts" % [dice_count, dice_modifier]
	else:
		damage_text = "%d dégâts" % damage

	var parts = ["%s (%s, %d Or)" % [weapon_name, damage_text, price]]
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

# Construit le sort d'attaque correspondant à cette arme (mêlée ou à
# distance selon weapon_type). Toujours gratuit en EA — voir
# Spell.is_weapon_attack / get_effective_ea_cost(). spell.damage sert
# uniquement à l'AFFICHAGE (tooltip) : les dégâts réellement infligés
# sont recalculés à chaque attaque via roll_damage() (voir
# HexGrid._resolve_weapon_attack), pas figés ici.
func create_attack_spell() -> Spell:
	var s := Spell.new()
	s.spell_name = "Attaque (%s)" % weapon_name
	s.ea_cost = 0
	s.is_weapon_attack = true
	s.source_weapon = self
	s.min_range = min_range
	s.max_range = max_range
	s.damage = round(dice_count * 3.5 + dice_modifier) if dice_count > 0 else damage
	return s
