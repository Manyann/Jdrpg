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

## Élément(s) du sort (voir catalogue Mage : "Feu", "Eau", "Air",
## "Terre", ou une combinaison comme ["Eau", "Feu"] pour un sort
## Double/Triple). Vide = pas de rattachement élémentaire (attaque
## d'arme, sorts des autres classes) — voir TurnManager, filtre par
## élément : un sort avec elements vide n'est JAMAIS filtré, toujours
## affiché.
@export var elements: Array = []
@export var ea_cost: int = 3

## PHYSICAL : jet contre moy(Intelligence, Adresse). PSYCHIC : moy
## (Intelligence, Charisme). CHANCE (voir Archéologue) : contre
## chance_stat SEUL, sans moyenne. COURAGE (voir Peintre) : contre
## courage SEUL, sans moyenne. INTELLIGENCE (voir Prestidigitateur,
## "Test INT") : contre intelligence_stat SEUL, sans moyenne.
## COURAGE_CHARISME (voir Soldat, "Test Cou/Cha") : moy(Courage,
## Charisme) — voir le calcul du jet dans HexGrid._resolve_spell_effect
## / _resolve_ev_cost_spell.
## NONE : aucun test, le sort réussit toujours (ex: sorts du Berzerk, du Gladiateur).
enum SpellType { PHYSICAL, PSYCHIC, CHANCE, COURAGE, INTELLIGENCE, COURAGE_CHARISME, NONE }

## Détermine comment ce sort choisit ses cibles :
## - SINGLE_ENEMY : un seul ennemi, choisi au clic (comportement par
##   défaut, celui de toutes les attaques d'arme et sorts offensifs).
## - SINGLE_ALLY : un seul allié, choisi au clic (peut se cibler
##   soi-même — utile pour les soins).
## - SELF : le lanceur lui-même, appliqué immédiatement sans clic.
## - ZONE : touche TOUTES les unités (alliées ET ennemies) autour de la
##   case ciblée au clic (rayon 1 — case cliquée + cases adjacentes).
## - GROUP : tout le groupe allié, lanceur compris, appliqué
##   immédiatement sans clic.
## - BATTLEFIELD : TOUT LE MONDE sur le champ de bataille, les deux
##   camps confondus (ex: une tempête de poussière) — appliqué
##   immédiatement sans clic, comme GROUP.
## - ALL_ENEMIES : tous les ennemis du lanceur (voir Jugement divin,
##   Walkyrie) — appliqué immédiatement sans clic, comme GROUP.
enum TargetMode { SINGLE_ENEMY, SINGLE_ALLY, SELF, ZONE, GROUP, BATTLEFIELD, ALL_ENEMIES }
@export var target_mode: TargetMode = TargetMode.SINGLE_ENEMY

## Forme d'un sort en TargetMode.ZONE (sans effet pour les autres modes) :
## liste de décalages axiaux (dq, dr) relatifs à la case d'ANCRE — la case
## foncée des schémas, toujours incluse dans la zone — pour l'orientation
## "de base", celle du schéma. La forme se pose sur la case visée (l'ancre)
## puis peut être tournée par pas de 60° (voir HexGrid._rotate_zone). Les
## formes des sorts du Mage sont définies dans zone_shapes.gd (ZoneShapes).
## Vide = l'ancre et ses 6 voisines.
@export var zone_offsets: Array = []

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

## Vrai si ce sort soigne plutôt que blesse. Pour les sorts existants
## (voir UnitDatabase.build_spells), déduit automatiquement du signe de
## `damage`. Pour les sorts à formule de dés (voir dice_terms), doit
## être précisé explicitement — un jet de dés est toujours positif, le
## signe ne peut plus servir d'indicateur.
@export var is_heal: bool = false

## Termes de dés à additionner pour calculer l'effet (voir roll_value).
## Chaque terme : {"count": N, "sides": faces, "modifier": M}. Permet de
## représenter des formules composées comme "2D+2 + 1D4" (un terme d6 ET
## un terme d4) — le catalogue Mage en a besoin, contrairement aux armes
## qui n'utilisent qu'un seul type de dé. Vide = pas de dés, utilise
## directement `damage` (comportement historique, compatibilité).
var dice_terms: Array = []

# Calcule la magnitude de l'effet (TOUJOURS positive, que ce soit un
# soin ou des dégâts — c'est is_heal qui détermine le signe final, pas
# cette fonction). Relance les dés à chaque appel : ne jamais mettre en
# cache le résultat.
func roll_value() -> int:
	if dice_terms.is_empty():
		return abs(damage)

	var total = 0
	for term in dice_terms:
		total += term.get("modifier", 0)
		for i in range(term.get("count", 0)):
			total += randi_range(1, term.get("sides", 6))
	return total

## Effet à durée (buff/debuff/DoT) appliqué à chaque cible touchée EN
## PLUS (ou à la place, si le sort n'inflige aucun dégât/soin) de
## l'effet de dégâts — voir status_effect.gd. Un exemplaire propre est
## dupliqué par cible (voir HexGrid._apply_spell_effect_to_target),
## jamais partagé, pour que leurs durées se décomptent indépendamment.
var effect_to_apply: StatusEffect = null

## Vrai pour un sort "Rend X PA" (voir lexique Mage) : la magnitude de
## roll_value() restaure de l'EA plutôt que des PV — voir
## HexGrid._apply_spell_effect_to_target. Sans effet si is_heal = false.
@export var restores_mana: bool = false

## Vrai pour un sort qui retire tous les effets à durée actifs de la
## cible (ex: Purge) — voir CombatUnit.active_effects.
@export var cleanses_effects: bool = false

## Nombre de tours que la cible passe totalement étourdie (Mistral,
## Marchand de sable) — voir CombatUnit.stunned_turns_remaining /
## TurnManager._start_current_turn. 0 = pas d'étourdissement.
@export var stun_turns: int = 0

## Doigt d'honneur (Gladiateur) : pendant N tours de la cible, l'IA ennemie
## ne peut viser que le lanceur (voir CombatUnit.taunt_source et
## EnemyAI.play_turn). 0 = sans effet.
@export var forces_attack_on_caster_turns: int = 0

## Crée jusqu'à max_terrain_cells cases infranchissables (et bloquant
## la ligne de vue) — voir Mur d'eau. Le joueur choisit lui-même
## chaque case, une par une (clic pour sélectionner/désélectionner,
## bouton "Valider" pour lancer) — voir HexGrid._handle_terrain_selection_click.
@export var creates_obstacle_line: bool = false

## Retire les obstacles du type indiqué (voir obstacle_type.gd), sur
## jusqu'à max_terrain_cells cases choisies une par une par le joueur
## (Évaporation d'eau, Gel de l'eau). -1 = ce sort ne retire aucun
## obstacle (comportement par défaut).
@export var removes_obstacle_type: int = -1

## Nombre maximum de cases que le joueur peut sélectionner pour un
## sort de terrain (creates_obstacle_line / creates_bridge_line /
## removes_obstacle_type) — le sort peut être validé avec moins, mais
## jamais plus.
@export var max_terrain_cells: int = 3

## Rend franchissables jusqu'à max_terrain_cells cases d'obstacle VIDE
## (voir obstacle_type.gd), choisies une par une par le joueur — même
## principe de sélection que creates_obstacle_line, mais RETIRE
## l'obstacle au lieu d'en créer un, et seulement sur du VIDE (voir
## Pont végétal).
@export var creates_bridge_line: bool = false

## Remplace l'arme de mêlée du lanceur par une arme conjurée (voir
## Vajra) — PAS de retour automatique à l'ancienne arme (limitation
## assumée, voir la doc de mage_spell_catalog.gd).
@export var conjures_weapon: bool = false
@export var conjured_weapon_name: String = ""
@export var conjured_weapon_dice_count: int = 0
@export var conjured_weapon_dice_modifier: int = 0
@export var conjured_weapon_bonus_attaque: int = 0
@export var conjured_weapon_bonus_parade: int = 0

## Retire l'invisibilité (StatusEffect.grants_untargetable) de toute
## cible touchée (voir Détection de zone).
@export var reveals_invisible: bool = false

## TargetMode.BATTLEFIELD uniquement : si > 0, le sort ne touche que les
## unités à cette distance (en cases) ou moins du lanceur, lanceur exclu.
@export var battlefield_radius: int = 0

## Animation visuelle jouée sur la cible au moment où ce sort touche
## (voir HexGrid._spawn_spell_effect) — vide = pas d'animation, juste
## le texte flottant habituel. effect_row est en PIXELS (pas un index
## de ligne : les feuilles de sprites n'ont pas toutes des rangées de
## même hauteur), effect_start_x aussi.
@export var effect_sprite_path: String = ""
@export var effect_frame_size: Vector2i = Vector2i(190, 256)
@export var effect_frame_count: int = 7
@export var effect_start_x: int = 0
@export var effect_row: int = 0
@export var effect_fps: float = 14.0

## Facteur d'échelle de l'animation (voir HexGrid._spawn_spell_effect) —
## 1.0 par défaut. À augmenter pour les planches à frames petites (ex:
## 32x32, comme Éclair mineur/moyen/majeur) afin qu'elles restent
## visibles à côté des planches à plus haute résolution native
## (190x256, 145x180...) qui n'ont pas besoin d'être agrandies.
@export var effect_scale: float = 1.0

## Capacités actives propres à une seule race, résolues à la main dans
## HexGrid (voir Race.grants_hobbit_*/grants_samurai_*) plutôt que par
## le système générique dice_terms/effets à durée — trop spécifiques
## chacune pour ça. Ces "pseudo-sorts" sont ajoutés à CombatUnit.spells
## par HexGrid.build_unit() UNIQUEMENT si l'unité a la race concernée.
@export var is_hobbit_bravoure: bool = false
@export var bravoure_x: int = 0  # Le X choisi pour ce bouton précis (voir HobbitBravoure : un bouton par valeur de X).
@export var is_hobbit_precision: bool = false
## Compétence Détecter (DET) : 3 charges par combat, test d'Intelligence+2
## avant de révéler (voir HexGrid._cast_spell).
@export var is_detect_skill: bool = false
## Pièges : poser un piège (trap_id, voir TrapDatabase) sur une case libre,
## ou désamorcer un piège / libérer une victime sur une case ciblée.
@export var is_trap_spell: bool = false
@export var trap_id: String = ""
@export var is_disarm_skill: bool = false
## Plan parallèle (Prêtre) : le joueur choisit DEUX unités (2 clics) ; pendant
## `parallel_plane_turns` tours de chacune, elles ne peuvent plus interagir
## qu'entre elles (voir HexGrid.can_interact).
@export var is_parallel_plane: bool = false
@export var parallel_plane_turns: int = 5
## Disque de lumière : ne touche que les ennemis tournés vers le lanceur.
@export var requires_facing_caster: bool = false
## Ogre : convertit X points d'AT et de PRD en X PI (voir CombatUnit.ogre_pi_converted).
@export var is_ogre_pi: bool = false
@export var ogre_pi_x: int = 0
## GRRRBL (Berzerk) : X Rage -> X/10 PI, 1 fois par combat, test de Courage.
@export var is_berzerk_grr: bool = false
## Coût = (2 × niveau du lanceur) - 1 PA (Scalpel).
@export var ea_cost_scales_with_level: bool = false
## Un pour tous (Gladiateur) : redirige les 3 prochains dégâts d'un allié sur le lanceur.
@export var is_un_pour_tous: bool = false
@export var is_samurai_concentration: bool = false

## Bonus/malus fixe (ex: +2) au jet de toucher du sort (Intelligence +
## Adresse ou + Charisme selon spell_type — voir SpellType) — voir
## "Magie Phy +2"/"Magie Psy +2" dans les sorts Walkyrie. 0 par défaut
## (aucun sort du Mage n'en a).
@export var to_hit_modifier: int = 0

## Sort à coût en PV plutôt qu'en EA (voir la branche Walkyrie) : le
## joueur choisit un montant X (entre ev_cost_min et ev_cost_max, ou
## current_hp - 1 si plus bas) au moment du lancer — voir
## TurnManager.show_ev_cost_picker / HexGrid.confirm_ev_cost_spell. Ce
## montant coûte X PV (PAS d'EA) et détermine l'ampleur de l'effet :
## dice_terms (s'il y en a) + floor(X / ev_x_divisor) + ev_x_flat_bonus,
## utilisé comme dégâts (is_heal=false) ou soin (is_heal=true) selon
## le sort. La cible SELF/GROUP/ALL_ENEMIES est résolue immédiatement
## après le choix de X (pas de clic en plus) ; les autres modes de
## ciblage attendent un clic comme d'habitude.
@export var is_ev_cost_spell: bool = false
@export var ev_cost_min: int = 1
@export var ev_cost_max: int = 20
@export var ev_x_divisor: int = 1
@export var ev_x_flat_bonus: int = 0

## Multiplie X APRÈS division (bonus_value = int(X/ev_x_divisor) *
## ev_x_multiplier + ev_x_flat_bonus) — voir "3X dégâts" (Frappe du
## néant) : ev_x_divisor=1, ev_x_multiplier=3. 1 par défaut (pas d'effet).
@export var ev_x_multiplier: int = 1

## Arme céleste (Walkyrie) : les X/ev_x_divisor prochaines attaques
## d'arme de la CIBLE deviennent magiques (réduites par l'armure
## magique plutôt que physique) — voir
## CombatUnit.magic_weapon_attacks_remaining, alimenté dans
## HexGrid._resolve_ev_cost_spell.
@export var grants_weapon_magic_attacks: bool = false

## Bouclier de paix (Walkyrie) : invulnérabilité totale pendant
## X/ev_x_divisor tours — réutilise StatusEffect.grants_invulnerable
## avec duration_remaining = X/ev_x_divisor.
@export var grants_shield_turns: bool = false

## Protection divine (Walkyrie) : +X/ev_x_divisor armure PERMANENT
## (pour le reste du combat) à chaque cible — réutilise
## StatusEffect.bonus_armure avec duration_remaining = -1.
@export var grants_armor_buff: bool = false

## Bouclier de Foi (Templier) : définit CombatUnit.shield_power à
## bonus_value (2×X, voir ev_x_multiplier) — une réserve de points qui
## absorbe les dégâts avant les PV, détruite net par un critique (voir
## CombatUnit.take_damage). REMPLACE toute réserve existante (pas de
## cumul si relancé).
@export var grants_shield_power: bool = false

## Grâce du ciel (Walkyrie, Archange) : résurrection d'un allié mort —
## PAS implémentée mécaniquement (voir walkyrie_spell_catalog.gd) :
## une unité morte est entièrement retirée de la scène
## (CombatUnit.die() -> queue_free()), il n'existe aucun "cadavre"
## trackable à ranimer chez nous pour l'instant. Comportement comme
## is_unimplemented : coûte l'action, affiche son texte d'origine,
## aucun effet.
@export var is_walkyrie_resurrection: bool = false

## ============================================================
## Sorts du Prêtre (Ordre de l'harmonie / Ordre du néant / Ordre du
## cycle éternel) — voir pretre_spell_catalog.gd.
## ============================================================

## Ajoute CombatUnit.level (le niveau du PERSONNAGE, pas le palier du
## sort) au résultat (dégâts/soin/durée...) — voir "niveau" dans les
## formules d'origine ("1D + niveau EV", etc.).
@export var includes_caster_level: bool = false

## Si > 0, remplace includes_caster_level par CombatUnit.level *
## level_multiplier (ex: "niveau × 3" pour Disque de lumière) — aucun
## dé, juste ce produit.
@export var level_multiplier: int = 0

## Sort à coût en PA (= EA chez nous) VARIABLE choisi par le joueur —
## même sélecteur de X que Spell.is_ev_cost_spell (voir
## TurnManager.show_ev_cost_picker), mais déduit de current_ea au lieu
## de current_hp. Réutilise ev_cost_min/max/ev_x_divisor/ev_x_flat_bonus
## pour le calcul de l'effet.
@export var is_pa_cost_spell: bool = false

## "DS : X" (Ordre du néant) : la durée de l'effet appliqué est
## exactement X (le montant de PA dépensé), pas une valeur fixe —
## écrase duration_remaining sur l'effet appliqué.
@export var duration_equals_x: bool = false

## Infection (Ordre du cycle éternel) : pose une charge cumulable sur
## la cible (CombatUnit.infection_stacks += 1) au lieu d'un dégât ou
## effet classique.
@export var applies_infection: bool = false

## Nécrose (Ordre du cycle éternel) : déclenche toutes les charges
## d'Infection de la cible (4 dégâts bruts chacune), puis les remet à 0.
@export var triggers_infections: bool = false

## Croissant de lune (Ordre du néant) : les dégâts infligés à la cible
## sont retirés ET transférés en soin à un allié (ou au lanceur lui-même).
@export var transfers_damage_to_ally: bool = false

## Scalpel (Ordre du cycle éternel) : le nombre de dés lancés est
## CombatUnit.level (remplace dice_terms[0].count au moment du jet).
@export var dice_count_equals_level: bool = false

## Équilibre parfait (Ordre de l'harmonie) : les PV de TOUT LE MONDE
## (les deux camps, vivants) sont réinitialisés à 1D100.
@export var resets_all_hp: bool = false

## Invoque la balance de l'univers (Ordre du cycle éternel) : soigne
## tous les alliés du lanceur ET inflige les mêmes dégâts à tous les
## ennemis, à chaque lancer (simplification : la donnée d'origine
## parle d'une ALTERNANCE au fil des lancers — pas de système d'état
## persistant entre plusieurs lancers chez nous, donc les deux
## s'appliquent à chaque fois plutôt que d'alterner).
@export var alternates_heal_damage: bool = false

## Le mana devient de la vie (Ordre du cycle éternel) : transforme X
## PA de la cible (choisi par le joueur, voir is_pa_cost_spell — mais
## ici X est retiré à la CIBLE, pas au lanceur) en 3×X PV.
@export var mana_to_life_ratio: int = 0

## L'équilibre du cycle (Ordre du cycle éternel) : PAS implémentée
## (résurrection — même limite que Spell.is_walkyrie_resurrection, voir
## sa documentation : aucun "cadavre" trackable chez nous).
@export var is_pretre_resurrection: bool = false

## Permutation (Ninja) : échange instantanément de place avec un
## allié — voir HexGrid._resolve_ninja_permutation.
## CombatUnit.ninja_permutations_used, 3 max par combat.
@export var is_ninja_permutation: bool = false

## Peinture de guerre (Peintre) : +niveau Courage/Force à tout le
## groupe si le test Courage réussit — résolution SUR-MESURE (voir
## HexGrid._resolve_peinture_de_guerre), pas le système générique
## GROUP + effect_to_apply, car le bonus dépend de CombatUnit.level au
## moment du lancer (un effect_to_apply est une valeur FIXE posée une
## fois pour toutes dans le catalogue, incompatible avec ça). 1 fois
## max par combat (voir CombatUnit.peintre_peinture_de_guerre_used),
## consommée que le test réussisse ou non.
@export var is_peintre_peinture_de_guerre: bool = false

## Maquillage (Peintre) : prend l'apparence de quelqu'un d'autre sur
## un test INT/CHA (SpellType.PSYCHIC) — SANS effet mécanique pour
## l'instant (consomme une charge, 3 max/combat, affiche un texte),
## mais PAS par choix définitif : son vrai intérêt (tromper un
## adversaire) n'a de sens qu'en PvP, qu'on n'a pas encore construit.
## À revoir quand le PvP existera (ex: cacher l'identité réelle du
## lanceur aux yeux de l'adversaire). Voir HexGrid._resolve_peintre_maquillage.
@export var is_peintre_maquillage: bool = false

## Substitution (Prestidigitateur) : test INT (SpellType.INTELLIGENCE
## déjà posé sur ce sort) ; si réussi, +4 à UNE stat choisie par le
## joueur et -4 à une AUTRE stat choisie ensuite, pendant 5 tours —
## choix libre via TurnManager.show_stat_picker_step1/step2, voir
## HexGrid.confirm_substitution. Remplace l'ancienne version à 6
## paires préétablies.
@export var is_prestidigitateur_substitution: bool = false

## ============================================================
## Sorts du Barde — voir barde_spell_catalog.gd.
## ============================================================

## Ajoute max(0, Charisme - 12) aux dégâts/à l'effet — voir "+1 dégât
## par CHA > 12" dans les données d'origine (table "Sort de dégâts").
@export var includes_charisme_bonus_above_12: bool = false

## "(i)" dans les données d'origine : le coût est PERMANENT — déduit
## de base_max_ea (donc de max_ea pour le reste du combat), PAS de
## current_ea temporairement comme un coût normal. Voir
## HexGrid._deduct_initial_cost.
@export var is_initial_cost: bool = false

## Si vrai, is_initial_cost utilise initial_cost_percent_value (%% de
## max_ea actuel) plutôt que ea_cost (valeur fixe) — voir "50%(i)",
## "10%(i)" dans les données d'origine.
@export var initial_cost_is_percent: bool = false
@export var initial_cost_percent_value: float = 0.0

## Molto (Barde) : dégâts = ce ratio × current_hp de LA CIBLE (ex: 0.5
## pour "-50%EV") — remplace dice_terms pour ce sort précis.
@export var damage_percent_of_target_hp: float = 0.0

## Tranquillo (Barde) : "X Ennemis", coût 2+X — SIMPLIFIÉ chez nous en
## TOUS les ennemis vivants (X = leur nombre), pas de sélecteur pour
## choisir lesquels (pas d'interface de sélection multiple chez nous).
## Coût calculé dynamiquement, voir HexGrid._resolve_barde_tranquillo.
@export var is_barde_tranquillo: bool = false

## Meno/Slancio (Barde) : coût = N × durée, durée = max(1, Charisme -
## 12) — entièrement dérivés du Charisme du LANCEUR, sans choix du
## joueur. barde_cost_multiplier = N (2 pour Meno, 7 pour Slancio).
## Voir HexGrid._resolve_barde_meno/_resolve_barde_slancio.
@export var is_barde_meno: bool = false
@export var is_barde_slancio: bool = false
@export var barde_cost_multiplier: int = 0

## Porte étendard (Soldat) : invoque un étendard sur une case ADJACENTE
## (même clic qu'une invocation, voir is_summon) — mais SANS poser de
## vraie unité : applique directement +1 à toutes les stats et +1
## AT/PRD, 3 tours, à tout allié adjacent à CETTE case AU MOMENT DU
## LANCER (voir HexGrid._resolve_porte_etendard). SIMPLIFICATION :
## effet figé à l'instant du lancer, pas une aura qui se recalcule si
## des alliés entrent/sortent de la zone ensuite — pas de système
## d'objet persistant sur la carte chez nous.
@export var is_soldat_porte_etendard: bool = false

## ============================================================
## Berzerk — voir berzerk_spell_catalog.gd.
## ============================================================

## Coût FIXE en Rage (pas en EA) — voir Frappe puissante (5),
## Tourbillon (10). Vérifié/déduit à part, CombatUnit.rage n'a aucun
## rapport avec current_ea.
@export var rage_cost: int = 0

## Frappe puissante : +2 dégâts plats sur la prochaine attaque d'arme
## (voir StatusEffect.grants_next_attack_flat_bonus).
@export var is_berzerk_frappe_puissante: bool = false

## Tourbillon : attaque de base touchant tout le monde (alliés
## compris) à 1 hexagone — voir HexGrid._resolve_berzerk_tourbillon.
@export var is_berzerk_tourbillon: bool = false

## Raaah : coût en Rage VARIABLE (X choisi par le joueur, même
## sélecteur que is_ev_cost_spell/is_pa_cost_spell mais déduit de
## CombatUnit.rage) — convertit X Rage en +X/10 dégâts PERMANENTS,
## 1 fois par combat. Voir Spell.is_rage_cost_spell.
@export var is_berzerk_raaah: bool = false

## Comme is_ev_cost_spell/is_pa_cost_spell (même sélecteur de X, voir
## TurnManager.show_ev_cost_picker), mais déduit de CombatUnit.rage.
@export var is_rage_cost_spell: bool = false

## ============================================================
## Gladiateur — voir gladiateur_spell_catalog.gd.
## ============================================================

## Coût FIXE en Gloire (pas en EA) — voir Doigt d'honneur (5), Coup de
## bouclier (7), Tortue (10). Quand > 0, remplace entièrement ea_cost :
## le sort ne coûte aucune EA, juste cette Gloire. Le reste de la
## résolution (effect_to_apply, stun_turns...) passe normalement par
## le système générique.
@export var gloire_cost: int = 0

## Salve (Corsaire) : simple marqueur pour la garde "1 fois par
## combat" (voir CombatUnit.corsaire_salve_used dans HexGrid._cast_spell)
## — la résolution (dégâts) passe par le système générique normal.
@export var is_corsaire_salve: bool = false

## ============================================================
## Mécas (Ingénieur Automate) — voir meca_spell_catalog.gd.
## ============================================================

## Vrai pour les 4 sorts d'invocation de Méca (Doc/Tanker/Combat/
## Support) — comme is_summon, mais les stats ET l'éventuelle capacité
## spéciale dépendent du NIVEAU du lanceur (voir HexGrid._build_meca_unit) :
## palier de base, "Supplément 1" (niveau 7+), "Supplément 2" (niveau
## 10+). Toujours combiné avec is_summon = true (même clic sur case
## vide pour placer le Méca).
@export var is_meca_summon: bool = false

## "doc" (soigne), "tanker" (encaisse et provoque : l'IA ennemie ne vise que lui),
## "combat" (attaque tranchante), "support" (buff AT/PRD temporaire).
@export var meca_type: String = ""

## Palier débloqué (0/1/2 — voir HexGrid._get_meca_tier), mémorisé sur
## la capacité spéciale elle-même au moment où le Méca est invoqué
## (son niveau ne change plus après coup, même si le lanceur monte en
## niveau ensuite pendant le même combat).
@export var meca_tier: int = 0

## Doc : formule de soin trop spécifique par palier (le palier 2 rend
## à la fois des PV ET de l'EA, ce que le système générique is_heal/
## restores_mana ne peut pas faire en un seul sort) — résolution
## sur-mesure, voir HexGrid._resolve_meca_doc_heal.
@export var is_meca_doc_heal: bool = false

## Support : "+AT ou PRD" (choix non modélisé, toujours AT par
## simplicité) et +FO au palier 2 — résolution sur-mesure, voir
## HexGrid._resolve_meca_support_buff.
@export var is_meca_support_buff: bool = false

## Noirceur (Ordre du néant) : pose la nuit sur TOUT le champ de
## bataille pendant X tours (voir HexGrid.is_night/_install_night) —
## X est le PA VARIABLE choisi (voir is_pa_cost_spell), sans compter
## ev_extra_flat_cost. "La nuit", voir Être nocturne/Maître de la nuit
## dans pretre_spell_catalog.gd : des bonus conditionnels appliqués/
## retirés par _install_night/_end_night, pas des sorts normaux.
@export var installs_night: bool = false

## Coût FIXE additionnel à X pour un sort is_ev_cost_spell/is_pa_cost_spell
## (ex: "X + 2 PA" pour Noirceur : ev_extra_flat_cost = 2) — s'ajoute à
## X au moment de PAYER le coût, mais n'entre PAS dans bonus_value (qui
## reste basé sur X seul, voir ev_x_divisor/flat_bonus/multiplier).
@export var ev_extra_flat_cost: int = 0

## Si vrai, effect_to_apply ne s'applique QUE si la cible n'a PAS la
## compétence passive Nyctalopie (voir Erèbe / CombatUnit.has_nyctalopie).
@export var requires_missing_nyctalopie: bool = false

## Texte affiché/consultable pour un sort — sert surtout aux sorts
## marqués is_unimplemented (voir plus bas) pour montrer ce qu'ils
## devraient faire même sans mécanique codée.
@export var info_text: String = ""

## Vrai pour un sort dont l'effet n'a PAS pu être automatisé lors de
## l'import (voir mage_spell_catalog.gd, liste en bas de fichier) : se
## lance normalement (coûte l'EA, consomme l'action) mais n'a AUCUN
## effet mécanique — seul info_text s'affiche, en attendant du code
## sur-mesure pour ce sort précis.
@export var is_unimplemented: bool = false

## Vrai pour un sort à dégâts "brut" (voir lexique Mage) : ignore
## TOUTE armure (physique ET magique), contrairement aux dégâts PH/PS
## normaux qui sont réduits par armor_value/magic_armor_value.
@export var ignores_armor: bool = false

## Vrai pour un sort dont les dégâts ne peuvent PAS être esquivés
## (voir Steropes : "dégâts inesquivables") — contourne complètement
## la posture Esquive du défenseur (voir HexGrid._try_dodge et son
## utilisation dans _resolve_weapon_attack/_apply_spell_effect_to_target).
@export var unavoidable: bool = false

## DI (durée d'incantation, voir lexique Mage) : nombre de tours de
## CHARGE avant que le sort ne se déclenche réellement. 0 = instantané
## (comportement normal). N > 0 = au lancer, le sort ne se résout pas
## tout de suite : le lanceur "canalise" pendant N tours (incapable
## d'agir normalement pendant ce temps — voir CombatUnit.start_channeling
## et TurnManager._start_current_turn), puis l'effet se déclenche
## automatiquement au début de son Nème tour suivant.
@export var cast_delay: int = 0

## Vrai si ce sort invoque une nouvelle unité plutôt que d'affecter des
## cibles existantes (voir lexique Mage, catégorie "invocation"). Les
## champs summon_* ci-dessous décrivent l'unité créée — sans effet si
## is_summon = false. Au lancer, on clique une case VIDE à portée
## (au lieu d'une unité existante) pour y faire apparaître l'invocation
## — voir HexGrid._cast_summon_spell/build_summon_unit.
@export var is_summon: bool = false
@export var summon_name: String = "Invocation"
@export var summon_max_hp: int = 15

## AT/PRD du catalogue Mage : une seule valeur utilisée à la fois comme
## Attaque ET comme Parade de l'invocation (contrairement à une unité
## normale qui a les deux stats séparément).
@export var summon_attack_parade: int = 8

## PR du catalogue : réduction de dégâts (armure physique) de l'invocation.
@export var summon_armor: int = 0

## Dégâts en dés de l'attaque de l'invocation (même système que Weapon —
## voir Weapon.roll_damage), dé à 6 faces implicite.
@export var summon_dice_count: int = 1
@export var summon_dice_modifier: int = 4

## Couleur du disque de repli (l'invocation n'a pas de sprite dédié) —
## à personnaliser par sort (ex: orangé pour un élémentaire de feu).
@export var summon_color: Color = Color(0.8, 0.6, 0.3)

## Vrai si ce sort est l'attaque générée par une arme équipée (mêlée
## OU à distance selon l'arme, ex: un arc). Toujours gratuite en EA,
## et compte dans le quota "1 action, ou 2 attaques d'armes avec
## Ambidextrie" plutôt que la limite normale d'1 action de sort.
@export var is_weapon_attack: bool = false

## Arme d'origine si c'est une attaque d'arme (permet de proposer un
## choix de munition pour les armes à distance). Assigné automatiquement
## par Weapon.create_attack_spell() — pas destiné à être édité à la main.
var source_weapon: Weapon = null

## Bonus de dégâts fixe qui s'ajoute au jet de dés de l'arme (voir
## Weapon.roll_damage), sans lui-même être aléatoire — utilisé par ex.
## pour le bonus d'une flèche spéciale (voir TurnManager._open_arrow_popup).
## Sans effet sur un sort normal (non is_weapon_attack), qui utilise
## directement `damage`.
var flat_damage_bonus: int = 0

## Si ce sort est une variante temporaire (ex: tir à l'arc avec une
## flèche spéciale choisie), pointe vers le sort "emplacement" d'origine
## dans CombatUnit.spells, pour que le suivi "déjà utilisé ce tour"
## s'applique au bon emplacement et pas à chaque variante générée.
var origin_spell: Spell = null
## Flèche consommée au lancer de cette attaque à distance (voir TurnManager._start_ranged_attack).
var arrow_used: Arrow = null

# Vrai si la portée max est de 1 case (contact direct) — sert
# uniquement à choisir le mot affiché ("mêlée" vs "distance"), plus
# à déterminer la gratuité en EA (voir is_weapon_attack pour ça).
func is_melee_range() -> bool:
	return max_range <= 1

# Coût en EA réellement appliqué : toujours 0 pour une attaque d'arme,
# peu importe la valeur renseignée dans ea_cost.
func get_effective_ea_cost(caster = null) -> int:
	if is_weapon_attack:
		return 0
	# Sort payé dans UNE AUTRE ressource (Gloire, Rage, PV, ou PA choisi par le
	# joueur) : aucun coût fixe en EA. Sans ça, la valeur par défaut d'ea_cost (3)
	# bloquait ces sorts pour toute unité sans EA (Berzerk) et leur faisait payer
	# deux fois les autres.
	if gloire_cost > 0 or rage_cost > 0 or is_rage_cost_spell or is_ev_cost_spell or is_pa_cost_spell:
		return 0
	if ea_cost_scales_with_level and caster != null:
		return max(1, 2 * int(caster.level) - 1)  # Scalpel : (2 × niveau) - 1.
	return ea_cost

## Dossier des icônes d'interface (attaque d'arme, sort générique, parade,
## esquive, inventaire, fin de tour).
const UI_ICON_FOLDER: String = "res://assets/spell_icons/ui/"

## Chemin d'une icône (PNG) pour le bouton du sort — "" = pas d'icône, on
## retombe sur le symbole texte de get_icon_text().
@export var icon_path: String = ""

# Texture de l'icône, ou null si le sort n'en a pas (ou si le fichier manque).
func get_icon_texture() -> Texture2D:
	var path: String = icon_path
	if path == "":
		# Sans icône propre : l'attaque d'arme a la sienne, et un sort offensif
		# l'icône générique « sort » (un soin garde son symbole texte).
		if is_weapon_attack:
			path = UI_ICON_FOLDER + "attaque_arme.png"
		elif not is_heal and damage >= 0:
			path = UI_ICON_FOLDER + "sort.png"
	if path == "" or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D

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
# ---------- Infobulle détaillée (coût + effet) ----------

static func _dice_text(terms: Array) -> String:
	var parts: Array = []
	var flat := 0
	for term in terms:
		var c: int = int(term.get("count", 0))
		var m: int = int(term.get("modifier", 0))
		if c > 0:
			parts.append("%dD%d" % [c, int(term.get("sides", 6))])
		flat += m
	var text := " + ".join(parts)
	if flat != 0:
		text += (" %s %d" % ["+" if flat > 0 else "−", abs(flat)]) if text != "" else str(flat)
	return text

# Nom de la ressource que ce lanceur dépense pour ses sorts « normaux ».
static func resource_label_for(caster) -> String:
	return caster.get_resource_name() if caster != null else "EA"

func _cost_text(caster) -> String:
	if is_weapon_attack:
		return "Gratuit"
	var res: String = Spell.resource_label_for(caster)
	if gloire_cost > 0:
		return "%d Gloire" % gloire_cost
	if rage_cost > 0:
		return "%d Rage" % rage_cost
	if is_rage_cost_spell:
		return "X Rage (à partir de %d, au choix)" % ev_cost_min
	if is_ev_cost_spell:
		var text := "X PV (de %d à %d, au choix)" % [ev_cost_min, ev_cost_max]
		if ev_extra_flat_cost > 0:
			text += " + %d PV" % ev_extra_flat_cost
		return text
	if is_pa_cost_spell:
		var text := "X %s (de %d à %d, au choix)" % [res, ev_cost_min, ev_cost_max]
		if ev_extra_flat_cost > 0:
			text += " + %d %s" % [ev_extra_flat_cost, res]
		return text
	if is_barde_tranquillo:
		return "2 + nombre d'ennemis vivants %s" % res
	if is_barde_meno or is_barde_slancio:
		return "%d × (CHA − 12) %s" % [barde_cost_multiplier, res]
	if is_initial_cost:
		if initial_cost_is_percent:
			return "%d%% de l'%s max (coût initial)" % [int(round(initial_cost_percent_value * 100.0)) if initial_cost_percent_value <= 1.0 else int(initial_cost_percent_value), res]
		return "%d %s (coût initial)" % [ea_cost, res]
	if ea_cost_scales_with_level:
		if caster != null:
			return "%d %s ((2 × niveau) − 1)" % [get_effective_ea_cost(caster), res]
		return "(2 × niveau) − 1 %s" % res
	if ea_cost <= 0:
		return "Gratuit"
	return "%d %s" % [ea_cost, res]

func _target_text() -> String:
	match target_mode:
		TargetMode.SELF:
			return "soi-même"
		TargetMode.GROUP:
			return "tout le groupe (lanceur compris)"
		TargetMode.ALL_ENEMIES:
			return "tous les ennemis" + (" tournés vers le lanceur" if requires_facing_caster else "")
		TargetMode.BATTLEFIELD:
			return "toutes les unités" + (" dans un rayon de %d cases" % battlefield_radius if battlefield_radius > 0 else " du champ de bataille")
		TargetMode.SINGLE_ALLY:
			return "un allié (ou soi-même)"
		TargetMode.ZONE:
			var n: int = zone_offsets.size() if not zone_offsets.is_empty() else 7
			return "une zone de %d cases" % n
	return "un ennemi"

func _test_text() -> String:
	match spell_type:
		SpellType.PHYSICAL:
			return "Intelligence + Adresse"
		SpellType.PSYCHIC:
			return "Intelligence + Charisme"
		SpellType.CHANCE:
			return "Chance"
		SpellType.COURAGE:
			return "Courage"
		SpellType.INTELLIGENCE:
			return "Intelligence"
		SpellType.COURAGE_CHARISME:
			return "Courage + Charisme"
	return ""

static func describe_effect(e: StatusEffect, duration_x: bool = false) -> String:
	var bonuses: Array = []
	var stats := {"bonus_courage": "Courage", "bonus_intelligence": "Intelligence", "bonus_charisme": "Charisme",
		"bonus_adresse": "Adresse", "bonus_force": "Force", "bonus_chance": "Chance", "bonus_attaque": "Attaque",
		"bonus_parade": "Parade", "bonus_armure": "Armure", "bonus_armure_magique": "Armure magique",
		"bonus_vie": "PV max", "bonus_mana": "EA max"}
	for key in stats:
		var v: int = int(e.get(key))
		if v != 0:
			bonuses.append("%s%d %s" % ["+" if v > 0 else "−", abs(v), stats[key]])
	if e.damage_per_tick > 0:
		bonuses.append("%d dégâts bruts par tour" % e.damage_per_tick)
	if e.grants_untargetable:
		bonuses.append("invisible")
	if e.grants_invulnerable:
		bonuses.append("insensible aux dégâts")
	if e.grants_frozen:
		bonuses.append("ne peut plus bouger")
	if e.grants_lifesteal:
		bonuses.append("vol de vie")
	if e.grants_next_attack_double_damage:
		bonuses.append("prochaine attaque ×2")
	var text: String = e.effect_name
	if not bonuses.is_empty():
		text += " (" + ", ".join(bonuses) + ")"
	if duration_x:
		text += " — X tours"
	elif e.duration_remaining < 0:
		text += " — jusqu'à la fin du combat"
	else:
		text += " — %d tour(s)" % e.duration_remaining
	return text

# Infobulle complète d'un sort : coût dans la bonne ressource (EA/PA, Rage,
# Gloire, PV), portée, cible, test et effet. `caster` (facultatif) précise
# la ressource et le coût exact.
func get_tooltip_text(caster = null) -> String:
	var lines: Array = []
	lines.append(spell_name)

	if is_weapon_attack:
		var weapon_range := "mêlée" if is_melee_range() else "distance"
		lines.append("Attaque d'arme de %s — gratuite" % weapon_range)
		if source_weapon != null and source_weapon.dice_count > 0:
			lines.append("Dégâts : %s" % Spell._dice_text([{"count": source_weapon.dice_count, "sides": 6, "modifier": source_weapon.dice_modifier}]))
		else:
			lines.append("Dégâts : %d" % damage)
		lines.append("Portée : %d à %d" % [min_range, max_range])
		return "\n".join(lines)

	lines.append("Coût : " + _cost_text(caster))
	if cast_delay > 0:
		lines.append("Incantation : %d tour(s)" % cast_delay)

	var targeting: String = "Cible : " + _target_text()
	if target_mode in [TargetMode.SINGLE_ENEMY, TargetMode.SINGLE_ALLY, TargetMode.ZONE] and max_range > 0:
		targeting += " — portée %d à %d" % [min_range, max_range]
	lines.append(targeting)

	var test := _test_text()
	if test != "" and not unavoidable and not is_unimplemented:
		lines.append("Test : " + test)
	elif unavoidable:
		lines.append("Ne peut pas être esquivé")

	if not elements.is_empty():
		lines.append("Éléments : " + ", ".join(elements))

	if info_text != "":
		lines.append("")
		lines.append(info_text)

	var effects: Array = []
	var dice := Spell._dice_text(dice_terms)
	if dice_count_equals_level:
		dice = "1D6 par niveau du lanceur" if dice_terms.is_empty() else "%dD%d par niveau du lanceur" % [int(dice_terms[0].get("count", 1)), int(dice_terms[0].get("sides", 6))]
	if level_multiplier > 0:
		dice = "niveau × %d" % level_multiplier
	if includes_caster_level and dice != "":
		dice += " + niveau"
	if is_heal and (dice != "" or damage != 0):
		effects.append("%s : %s" % ["Restaure de l'EA" if restores_mana else "Soin", dice if dice != "" else str(abs(damage))])
	elif dice != "":
		effects.append("Dégâts : %s%s" % [dice, " (bruts)" if ignores_armor else ""])
	elif damage_percent_of_target_hp > 0.0:
		effects.append("Dégâts : %d%% des PV de la cible" % int(round(damage_percent_of_target_hp * 100.0 if damage_percent_of_target_hp <= 1.0 else damage_percent_of_target_hp)))
	elif damage > 0 and info_text == "":
		effects.append("Dégâts : %d%s" % [damage, " (bruts)" if ignores_armor else ""])
	if effect_to_apply != null:
		effects.append("Effet : " + Spell.describe_effect(effect_to_apply, duration_equals_x))
	if stun_turns > 0:
		effects.append("Étourdit la cible %d tour(s)" % stun_turns)
	if forces_attack_on_caster_turns > 0:
		effects.append("La cible n'attaque que le lanceur pendant %d tour(s)" % forces_attack_on_caster_turns)
	if cleanses_effects:
		effects.append("Retire les effets négatifs")
	if reveals_invisible:
		effects.append("Révèle les unités invisibles")
	if transfers_damage_to_ally:
		effects.append("Soigne le lanceur du montant des dégâts")
	if creates_obstacle_line:
		effects.append("Crée un mur (jusqu'à %d cases)" % max_terrain_cells)
	if creates_bridge_line:
		effects.append("Crée un pont (jusqu'à %d cases)" % max_terrain_cells)
	if removes_obstacle_type >= 0:
		effects.append("Retire un obstacle (jusqu'à %d cases)" % max_terrain_cells)
	if conjures_weapon:
		effects.append("Conjure l'arme « %s »" % conjured_weapon_name)
	if is_summon:
		effects.append("Invoque %s (%d PV)" % [summon_name, summon_max_hp])
	if installs_night:
		effects.append("Plonge le champ de bataille dans la nuit (X tours)")
	if is_parallel_plane:
		effects.append("Isole 2 unités l'une avec l'autre pendant %d tours" % parallel_plane_turns)
	if is_un_pour_tous:
		effects.append("Le lanceur perd 3 AT et encaisse les 3 prochains dégâts de l'allié")
	if is_walkyrie_resurrection or is_pretre_resurrection:
		effects.append("Ressuscite un allié mort")
	if mana_to_life_ratio > 0:
		effects.append("Chaque point dépensé donne %d PV" % mana_to_life_ratio)
	if is_unimplemented:
		effects.append("(Effet pas encore implémenté)")
	if not effects.is_empty():
		lines.append("")
		lines.append_array(effects)

	return "\n".join(lines)

func get_display_text() -> String:
	if is_weapon_attack:
		var range_desc = "mêlée" if is_melee_range() else "distance"
		return "%s (Gratuit, attaque de %s, %d dégâts, portée %d-%d)" % [spell_name, range_desc, damage, min_range, max_range]
	return "%s (%d EA, %d dégâts, portée %d-%d)" % [spell_name, ea_cost, damage, min_range, max_range]
