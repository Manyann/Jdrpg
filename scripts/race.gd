extends Resource
class_name Race

# ============================================================
# race.gd
# Représente une race (Humain, Barbare, Elfe Noir...), choisie par le
# joueur INDÉPENDAMMENT de la classe (Mage, Barbare-classe, etc. — ne
# pas confondre avec "Barbare" qui existe des deux côtés dans les
# données d'origine, comme race ET comme classe). S'applique en plus
# de la classe, via les mêmes champs bonus_* que Weapon/Armor/
# Accessory/StatusEffect, sommés de la même façon dans
# CombatUnit._recalculate_stats() — voir CombatUnit.equipped_race.
# ============================================================

@export var race_name: String = "Humain"

@export var bonus_vie: int = 0
@export var bonus_mana: int = 0
@export var bonus_attaque: int = 0
@export var bonus_parade: int = 0

## Toujours à 0 pour l'instant (rien dans les données d'origine ne
## donne de bonus direct sur ces stats — seulement des PRÉREQUIS, voir
## prereqs plus bas) — présents pour rester compatible avec la boucle
## générique de CombatUnit._recalculate_stats(), au même titre que
## Weapon/Armor/Accessory/StatusEffect.
@export var bonus_courage: int = 0
@export var bonus_intelligence: int = 0
@export var bonus_charisme: int = 0
@export var bonus_adresse: int = 0
@export var bonus_force: int = 0
@export var bonus_chance: int = 0
@export var bonus_armure: int = 0
@export var bonus_armure_magique: int = 0

## Chance (0.0 à 1.0) de contre-attaquer automatiquement après une
## esquive réussie (voir Elfe Noir) — vérifié dans
## HexGrid._try_dodge(), qui déclenche alors _deal_counter_attack().
## 0.0 par défaut (aucune race n'a cette capacité).
@export var dodge_counter_chance: float = 0.0

## Restreint dodge_counter_chance aux esquives d'une attaque à portée 1
## (corps à corps) uniquement — voir Homme des sables ("au CAC"), par
## opposition à l'Elfe Noir dont la contre-attaque n'a pas cette
## restriction dans les données d'origine.
@export var dodge_counter_melee_only: bool = false

## Nombre de dés à 6 faces de dégâts supplémentaires quand l'arme
## équipée est un javelot (voir Demi Orque) — détecté via
## Weapon.weapon_name qui commence par "Javelot", faute d'un champ de
## catégorie sur Weapon. 0 par défaut.
@export var javelin_damage_bonus_dice: int = 0

## Capacités actives/passives propres à une seule race chacune — trop
## spécifiques (ressources dédiées, mécaniques sur-mesure) pour un
## système générique. Voir HexGrid pour leur résolution :
## - Hobbit : "Bravoure des hobbits" (grants_hobbit_bravoure, 3
##   utilisations par combat, choix d'un X, test Courage-X, +X Force
##   en cas de réussite) et "Précision des hobbits"
##   (grants_hobbit_precision, 6 cailloux par combat, jet Adresse-3,
##   1D + Courage/2 de dégâts).
## - Samurai : "Concentration" (grants_samurai_concentration, renonce à
##   sa défense ce tour, prochaine attaque à dégâts doublés ignorant
##   l'armure) et "Combo" (grants_samurai_combo, 2e attaque au CAC ratée
##   dans le tour => ne peut plus se défendre jusqu'à son prochain
##   tour ; le volet "pas de malus d'ambidextrie" n'a aucun effet chez
##   nous, qui n'appliquons déjà aucun malus de ce genre).
@export var grants_hobbit_bravoure: bool = false
@export var grants_hobbit_precision: bool = false
@export var grants_samurai_concentration: bool = false
@export var grants_samurai_combo: bool = false

## Prérequis de stats (COU/INT/CHA/AD/FO min ou max) pour pouvoir
## choisir cette race — PAS appliqués chez nous (pas d'écran de
## création de personnage, tout est figé). Conservés à titre indicatif
## pour un futur écran de création si besoin : liste de
## {"stat": String, "type": "min"/"max", "value": int}.
@export var prereqs: Array = []

## Bonus non-automatisés (paliers de niveau, dés au level up,
## pourcentages, passifs conditionnels...) — texte libre, affiché mais
## sans effet mécanique pour l'instant (pas de système de montée de
## niveau affectant les stats chez nous).
@export var special_traits: Array = []

## Restrictions d'équipement en texte libre (ex: "Armure complète",
## "Arbalètes") — pas encore vérifiées par la boutique/l'équipement.
@export var equipment_restrictions: Array = []

## Codes courts de compétences innées (ex: "ADB", "BP"...) — catalogue
## pas encore fourni, stockés sans effet mécanique pour l'instant.
@export var inherited_skill_codes: Array = []

## Compétences spéciales en texte libre (passifs propres à la race,
## pas de code court) — affichées mais pas automatisées.
@export var special_skill_texts: Array = []

## Codes courts de métiers/classes interdits à cette race — pas encore
## vérifiés (aucune restriction appliquée au choix de classe pour l'instant).
@export var profession_restriction_codes: Array = []

## Caractéristiques que le plafond lié au NIVEAU ne limite pas (clés
## "courage", "force"...) — voir TowerManager.get_stat_level_cap. Ogre :
## ["force"] ; Humain : les six (aucune restriction par niveau).
## Les maximums PROPRES à la race (prereqs, type "max") s'appliquent
## toujours.
@export var level_cap_exempt_stats: Array = []

## Points de caractéristiques À RÉPARTIR en plus que donne cette race, dès
## le niveau 1 (Humain : 3, soit 22 au lieu de 19) — voir
## TowerManager.get_race_bonus_points.
@export var bonus_stat_points: int = 0

func get_display_text() -> String:
	var parts = [race_name]
	var bonus_bits = []
	if bonus_vie != 0: bonus_bits.append("%+d PV" % bonus_vie)
	if bonus_mana != 0: bonus_bits.append("%+d EA" % bonus_mana)
	if bonus_attaque != 0: bonus_bits.append("%+d Attaque" % bonus_attaque)
	if bonus_parade != 0: bonus_bits.append("%+d Parade" % bonus_parade)
	if not bonus_bits.is_empty():
		parts.append(", ".join(bonus_bits))
	return " — ".join(parts)
