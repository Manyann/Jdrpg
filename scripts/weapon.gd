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

## Portée de l'attaque générée par cette arme. Pour une arme de mêlée,
## laisser 1-1. Pour une arme à distance, définir une vraie portée
## (ex: 2 à 6 pour un arc).
@export var min_range: int = 1
@export var max_range: int = 1

# Construit le sort d'attaque correspondant à cette arme (mêlée ou à
# distance selon weapon_type). Toujours gratuit en EA — voir
# Spell.is_weapon_attack / get_effective_ea_cost().
func create_attack_spell() -> Spell:
	var s := Spell.new()
	s.spell_name = "Attaque (%s)" % weapon_name
	s.ea_cost = 0
	s.is_weapon_attack = true
	s.source_weapon = self
	s.min_range = min_range
	s.max_range = max_range
	s.damage = damage
	return s
