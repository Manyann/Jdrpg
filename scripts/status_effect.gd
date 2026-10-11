extends Resource
class_name StatusEffect

# ============================================================
# status_effect.gd
# Effet actif sur une unité pendant plusieurs tours : bonus/malus de
# stats (buff/debuff) et/ou dégâts par tick (DoT, ex: Brûlure). Voir
# CombatUnit.active_effects / add_status_effect / 
# process_status_effects_on_turn_start.
#
# Un sort qui "confère" quelque chose SANS préciser de DS (durée du
# sort) dans le catalogue Mage est considéré PERMANENT pour le reste
# du combat (duration_remaining = -1) plutôt qu'instantané et sans
# effet — un buff doit bien durer un minimum pour avoir un sens.
# ============================================================

@export var effect_name: String = "Effet"

## -1 = permanent (jusqu'à la fin du combat, ou retrait manuel).
## N > 0 = décrémenté de 1 au début de CHAQUE tour de l'unité qui le
## porte ; retiré automatiquement quand ça atteint 0.
@export var duration_remaining: int = -1

## Brûlure : dégât un tour sur deux plutôt qu'à chaque tour (voir
## process_status_effects_on_turn_start). Sans effet si damage_per_tick = 0.
@export var tick_every_other_turn: bool = false

## Dégâts infligés à chaque tick (voir tick_every_other_turn). Toujours
## "brut" (ignore armure ET armure magique) — cohérent avec la
## définition de Brûlure dans le lexique Mage.
@export var damage_per_tick: int = 0

## Bonus/malus de stats appliqués tant que l'effet est actif — mêmes
## noms de champs que Weapon/Armor/Accessory pour un traitement
## uniforme dans CombatUnit._recalculate_stats (un malus s'exprime en
## valeur négative, ex: bonus_attaque = -2 pour "-2 Attaque").
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

# --- États spéciaux (dérivés automatiquement sur CombatUnit — voir
# CombatUnit._recalculate_stats, ne jamais lire/écrire ces trois
# champs ailleurs que via l'effet lui-même) ---
@export var grants_untargetable: bool = false  # Invisibilité : plus ciblable par les ennemis.
@export var grants_invulnerable: bool = false  # Intangibilité/Cryogénisation : ignore tout dégât.
@export var grants_frozen: bool = false        # Cryogénisation : ne peut plus se déplacer.

## Concentration (Samurai) : consommés par la PROCHAINE attaque
## d'arme du porteur (touchée ou non — voir HexGrid._resolve_weapon_attack),
## quel qu'en soit le résultat. Retiré immédiatement après cette
## attaque, qu'elle ait ou non fini par toucher.
@export var grants_next_attack_double_damage: bool = false
@export var grants_next_attack_ignores_armor: bool = false

## Frappe puissante (Berzerk) : +N dégâts PLATS sur la prochaine
## attaque d'arme — même convention de retrait que
## grants_next_attack_double_damage (une seule attaque, touchée ou non).
@export var grants_next_attack_flat_bonus: int = 0

## Ambidextrie temporaire (voir Gantelets du Berserk, Conservateur) :
## OR-combiné avec CombatUnit.has_ambidextrie dans _recalculate_stats()
## — ajoute dynamiquement l'attaque de la main secondaire aux sorts
## disponibles si elle n'y était pas déjà (voir CombatUnit.add_status_effect).
@export var grants_ambidextrie: bool = false

## Vol de vie (voir Gantelets du Berserk) : soigne le porteur du
## montant exact des dégâts qu'il inflige avec une attaque d'arme —
## voir HexGrid._resolve_weapon_attack/_deal_counter_attack.
@export var grants_lifesteal: bool = false

## Vrai pour un effet de type POISON (voir Empoisonneur, "Immunisé") —
## sert uniquement à la vérification d'immunité dans
## CombatUnit.add_status_effect, aucun autre effet mécanique propre.
@export var is_poison: bool = false

## Contre-attaque après esquive (voir Subito, Barde) — même mécanique
## que Race.dodge_counter_chance/dodge_counter_melee_only, mais
## portable par un effet TEMPORAIRE plutôt que fixée par la race. Voir
## HexGrid._try_dodge, qui vérifie maintenant les deux sources.
@export var dodge_counter_chance: float = 0.0
@export var dodge_counter_melee_only: bool = false

## Bonus de dégâts en dés ajouté aux attaques d'ARME (pas aux sorts) —
## voir Zéphir/Poings de terre/Enchantement. Un seul terme (pas de
## formule composée ici, contrairement à Spell.dice_terms).
@export var bonus_weapon_dice_count: int = 0
@export var bonus_weapon_dice_modifier: int = 0
## Si vrai, le bonus ne s'applique qu'aux attaques d'arme À DISTANCE
## (Zéphir) — sinon toutes les attaques d'arme en profitent.
@export var bonus_weapon_dice_ranged_only: bool = false

## Reflet de dégâts sur quiconque attaque la cible au CORPS À CORPS
## (voir Aura de feu) — un jet de dés propre, indépendant de l'attaque
## initiale.
@export var reflect_dice_terms: Array = []

## Déclenchement probabiliste, vérifié à chaque tour de la cible (voir
## Épée de Damocles) — CombatUnit.process_status_effects_on_turn_start.
## 0 = pas de mécanique de déclenchement (comportement normal des
## autres champs ci-dessus).
@export var trigger_chance: float = 0.0
@export var trigger_dice_terms: Array = []
## Dés supplémentaires ajoutés au jet de déclenchement pour chaque tour
## où il ne s'est PAS déclenché (l'attente rend le coup plus dangereux).
@export var trigger_bonus_dice_per_turn_waited: int = 0
var _trigger_turns_waited: int = 0  # État interne, pas une donnée de configuration.

# Nombre de tours écoulés depuis l'application — sert uniquement à
# l'alternance de Brûlure (tick_every_other_turn). Pas exporté : c'est
# un état interne, pas une donnée de configuration de l'effet.
var _ticks_elapsed: int = 0
