extends Resource
class_name Spell

# ============================================================
# spell.gd
# Représente un sort/enchantement OU une attaque d'arme (mêlée ou
# à distance) : portée, dégâts, coût en Énergie Astrale (EA).
#
# RÈGLE IMPORTANTE : une "attaque d'arme" (is_weapon_attack = true,
# générée par Weapon.create_attack_spell()) est TOUJOURS gratuite en
# EA, quelle que soit sa portée — un arc génère une attaque à distance
# qui reste une "attaque d'arme" au même titre qu'une épée en mêlée.
# Elle suit son propre quota (1 ou 2 par tour selon Ambidextrie),
# séparé de la limite "1 action par tour" des sorts/enchantements.
#
# C'est une Resource (donnée pure, pas de node) — réutilisable
# facilement, et éditable comme fichier .tres si besoin plus tard
# (pratique pour que l'expert data génère des sorts depuis un
# fichier JSON/CSV converti en .tres, par exemple).
# ============================================================

@export var spell_name: String = "Attaque"
@export var ea_cost: int = 3

enum SpellType { PHYSICAL, PSYCHIC }

## Type du sort — détermine quelle paire de stats est moyennée pour le
## jet de lancer (voir HexGrid._resolve_spell_effect) : Intelligence +
## Adresse pour un sort physique, Intelligence + Charisme pour un sort
## psychique. Sans effet sur une attaque d'arme (is_weapon_attack),
## qui utilise directement attack_stat.
@export var spell_type: SpellType = SpellType.PHYSICAL

## Portée minimale et maximale en nombre de cases (distance à vol
## d'oiseau pour l'instant — la ligne de vue/les obstacles pour les
## sorts à distance viendront dans une itération future).
@export var min_range: int = 1
@export var max_range: int = 1

@export var damage: int = 15

## Vrai si ce sort est l'attaque générée par une arme équipée (mêlée
## OU à distance selon l'arme, ex: un arc). Toujours gratuite en EA,
## et compte dans le quota "1 action, ou 2 attaques d'armes avec
## Ambidextrie" plutôt que la limite normale d'1 action de sort.
@export var is_weapon_attack: bool = false

## Arme d'origine si c'est une attaque d'arme (permet de proposer un
## choix de munition pour les armes à distance). Assigné automatiquement
## par Weapon.create_attack_spell() — pas destiné à être édité à la main.
var source_weapon: Weapon = null

## Si ce sort est une variante temporaire (ex: tir à l'arc avec une
## flèche spéciale choisie), pointe vers le sort "emplacement" d'origine
## dans CombatUnit.spells, pour que le suivi "déjà utilisé ce tour"
## s'applique au bon emplacement et pas à chaque variante générée.
var origin_spell: Spell = null

# Vrai si la portée max est de 1 case (contact direct) — sert
# uniquement à choisir le mot affiché ("mêlée" vs "distance"), plus
# à déterminer la gratuité en EA (voir is_weapon_attack pour ça).
func is_melee_range() -> bool:
	return max_range <= 1

# Coût en EA réellement appliqué : toujours 0 pour une attaque d'arme,
# peu importe la valeur renseignée dans ea_cost.
func get_effective_ea_cost() -> int:
	return 0 if is_weapon_attack else ea_cost

# Symbole compact à afficher sur le bouton (le texte complet reste
# disponible via get_display_text(), affiché en tooltip au survol).
# Basé sur une simple heuristique : à remplacer par de vraies icônes
# (TextureButton) une fois que vous aurez des assets graphiques.
func get_icon_text() -> String:
	if is_weapon_attack:
		if source_weapon != null and source_weapon.weapon_type == Weapon.WeaponType.RANGED:
			return "➤"  # Attaque d'arme à distance (arc, arbalète...)
		return "⚔"  # Attaque d'arme en mêlée
	if damage < 0:
		return "♥"  # Soin
	return "★"  # Sort à distance / enchantement

# Texte prêt à afficher dans l'UI (bouton de sort).
func get_display_text() -> String:
	if is_weapon_attack:
		var range_desc = "mêlée" if is_melee_range() else "distance"
		return "%s (Gratuit, attaque de %s, %d dégâts, portée %d-%d)" % [spell_name, range_desc, damage, min_range, max_range]
	return "%s (%d EA, %d dégâts, portée %d-%d)" % [spell_name, ea_cost, damage, min_range, max_range]
