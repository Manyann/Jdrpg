extends Resource
class_name Metier

# ============================================================
# metier.gd
# Représente un métier/classe (Guerrier, Mage, Voleur, Prêtre...) —
# NE PAS confondre avec Race (Barbare, Elfe, Nain...), un concept
# totalement séparé chez nous : une race donne des bonus et des
# compétences INNÉES, un métier donne l'orientation de combat
# (progression, sorts/capacités propres à la discipline). S'applique
# EN PLUS de la race, via les mêmes champs bonus_* que Weapon/Armor/
# Accessory/Race/StatusEffect, sommés de la même façon dans
# CombatUnit._recalculate_stats() — voir CombatUnit.equipped_metier.
#
# Les métiers forment une VRAIE arborescence (shortCodeParents) dans
# les données d'origine — ex: Templier vient de Paladin, qui vient de
# Prêtre. Conservée à titre indicatif (parent_codes) pour une future
# interface de progression, mais PAS appliquée : chez nous, un métier
# se choisit indépendamment, sans validation de chaîne de parenté.
# ============================================================

@export var metier_name: String = ""
@export var short_code: String = ""

@export var bonus_vie: int = 0
@export var bonus_mana: int = 0
@export var bonus_attaque: int = 0
@export var bonus_parade: int = 0

## Toujours à 0 pour l'instant (rien dans les données d'origine ne
## donne de bonus direct sur ces stats — seulement des PRÉREQUIS, voir
## prereqs plus bas) — présents pour rester compatible avec la boucle
## générique de CombatUnit._recalculate_stats().
@export var bonus_courage: int = 0
@export var bonus_intelligence: int = 0
@export var bonus_charisme: int = 0
@export var bonus_adresse: int = 0
@export var bonus_force: int = 0
@export var bonus_chance: int = 0
@export var bonus_armure: int = 0
@export var bonus_armure_magique: int = 0

## Frappe d'énergie (Moine) : à mains nues, la fenêtre de critique
## s'étend de 1 à 5 (au lieu de 1 seul) et le multiplicateur de
## dégâts passe à ×4 (au lieu de ×2) — voir
## HexGrid._resolve_weapon_attack/_deal_counter_attack.
@export var grants_moine_frappe_energie: bool = false

## Voleur : esquive sans la restriction "1 tour sur 2" habituelle
## (voir CombatUnit.dodge_available / HexGrid._try_dodge), compensée
## par -3 Adresse un tour sur deux (voir CombatUnit.voleur_ad_malus_active).
@export var grants_voleur_esquive_totale: bool = false

## Empoisonneur : 1/2 chance d'ignorer un effet POISON entrant (voir
## StatusEffect.is_poison / CombatUnit.add_status_effect).
@export var grants_empoisonneur_immunity: bool = false

## Empoisonneur : la PREMIÈRE attaque d'arme du combat inflige 1D4 de
## dégâts supplémentaires ("Dague empoisonnée") — voir
## CombatUnit.empoisonneur_first_attack_used / HexGrid._resolve_weapon_attack.
@export var grants_empoisonneur_dague: bool = false

## Assassin, Coup mortel : le PREMIER coup sur CHAQUE cible critique
## de 1 à 4 (au lieu de 1 seul) — voir CombatUnit.assassin_hit_targets.
@export var grants_assassin_coup_mortel: bool = false

## Assassin, Précision mortelle : une attaque à la dague ignore
## l'armure de la cible (voir HexGrid._resolve_weapon_attack).
@export var grants_assassin_precision_mortelle: bool = false

## Rôdeur, Camouflage Naturel : invisible (voir
## StatusEffect.grants_untargetable) jusqu'à sa PREMIÈRE attaque
## d'arme du combat, qui le révèle — voir CombatUnit._ready() (pose
## l'effet au départ) et HexGrid._resolve_weapon_attack (le retire).
@export var grants_rodeur_camouflage: bool = false

## Ninja : esquive sans la restriction "1 tour sur 2", SANS le malus
## d'Adresse du Voleur (contrairement à grants_voleur_esquive_totale) —
## voir HexGrid._try_dodge.
@export var grants_ninja_esquive_totale: bool = false

## Ninja, Frappe des ombres : dégâts ×2 en attaquant une cible qui ne
## lui fait pas face (voir CombatUnit.is_attacked_from_behind), peu
## importe l'arme.
@export var grants_ninja_frappe_des_ombres: bool = false

## Prestidigitateur, Réalité distordue : ne peut JAMAIS subir de coup
## critique, peu importe le jet de l'attaquant — voir
## HexGrid._resolve_weapon_attack/_deal_counter_attack.
@export var grants_prestidigitateur_realite_distordue: bool = false

## Codes shortCode des métiers parents dans l'arbre de progression
## d'origine — voir la note en tête de fichier. Informatif seulement.
@export var parent_codes: Array = []

## Noms de métier de TOUTE la lignée (ce métier + tous ses ancêtres via
## parent_codes, ex: Ménestrel -> ["Menestrel", "Barde"]) — PAS une
## donnée de catalogue, calculée une fois par CombatUnit._apply_metier_lineage()
## juste après la pose de equipped_metier. "Un personnage a une race
## et PLUSIEURS classes" (toute la lignée, pas que la dernière) : les
## champs grants_* ci-dessus sont également FUSIONNÉS (OR) depuis tous
## les ancêtres dans cette même fonction, donc equipped_metier.grants_X
## reflète déjà toute la lignée sans rien changer d'autre dans le code
## qui les consulte.
var lineage_names: Array = []

## Prérequis de stats (COU/INT/CHA/AD/FO/Chance min ou max) pour
## pouvoir choisir ce métier — PAS appliqués chez nous (pas d'écran de
## création de personnage, tout est figé). Conservés à titre indicatif :
## liste de {"stat": String, "type": "min"/"max", "value": int}.
@export var prereqs: Array = []

## Points de caractéristiques À RÉPARTIR en plus que ce métier donne à un
## personnage qui l'a dans sa filière (Ranger : 1) — voir
## TowerManager.get_metier_bonus_points.
@export var bonus_stat_points: int = 0

## Bonus/mécaniques non-automatisés (capacités uniques en texte libre :
## Rage du Berzerk, Gloire du Gladiateur, Bouclier de Foi du Templier,
## systèmes de Points d'Impact (PI), bons/mauvais points d'alignement...)
## — affichés mais sans effet mécanique pour l'instant. La grande
## majorité des métiers reposent sur des mécaniques uniques à eux
## seuls, trop nombreuses et disparates pour être automatisées d'un coup.
@export var special_traits: Array = []

## Restrictions d'équipement en texte libre (ex: "Armure limite :
## Cuir", "Armes à 2 mains") — pas encore vérifiées par la boutique.
@export var equipment_restrictions: Array = []

## Codes courts de compétences innées (voir SkillDatabase — CE SONT
## LES MÊMES CODES que pour les races, ex: "ER", "PS", "TDM") :
## appliqués via CombatUnit.has_skill(), qui vérifie la race ET le
## métier équipés.
@export var inherited_skill_codes: Array = []

## Capacités spéciales en texte libre (propres au métier, pas de code
## court) — affichées mais pas automatisées, sauf mention contraire.
@export var special_skill_texts: Array = []

func get_display_text() -> String:
	var parts = [metier_name]
	var bonus_bits = []
	if bonus_vie != 0: bonus_bits.append("%+d PV" % bonus_vie)
	if bonus_mana != 0: bonus_bits.append("%+d EA" % bonus_mana)
	if bonus_attaque != 0: bonus_bits.append("%+d Attaque" % bonus_attaque)
	if bonus_parade != 0: bonus_bits.append("%+d Parade" % bonus_parade)
	if not bonus_bits.is_empty():
		parts.append(", ".join(bonus_bits))
	return " — ".join(parts)
