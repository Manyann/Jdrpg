extends Node2D
class_name CombatUnit

# ============================================================
# unit.gd
# Représente une unité de combat (joueur ou ennemi) placée sur
# une case de la grille hexagonale.
#
# Pour l'instant le visuel est un simple cercle coloré + le nom
# de l'unité affiché au-dessus. On remplacera ça par de vrais
# sprites plus tard sans changer la logique.
# ============================================================

enum Team { PLAYER, ENEMY }

# Posture défensive choisie par le joueur à son tour, active jusqu'à
# son tour suivant. Détermine comment cette unité réagit aux attaques
# subies pendant les tours des autres.
enum DefensiveStance { NONE, PARRY, DODGE }

@export var unit_name: String = "Unit"
@export var team: Team = Team.PLAYER
@export var radius: float = 18.0
## Rayon (px) des tokens affichés à la place des sprites (voir TokenDatabase).
const TOKEN_RADIUS := 22.0

## Couleurs par équipe.
@export var player_color: Color = Color(0.25, 0.55, 0.95)
@export var enemy_color: Color = Color(0.9, 0.25, 0.25)

## Couleur de repli personnalisée (utilisée à la place de player_color/
## enemy_color si alpha > 0) — sert aux invocations, qui n'ont pas de
## sprite dédié mais méritent une couleur propre (voir Spell.summon_color).
var custom_fallback_color: Color = Color(0, 0, 0, 0)

# ---------- Sprite (optionnel) ----------
# Si sprite_sheet est renseigné (voir UnitDatabase, clé "sprite"), un
# vrai sprite animé remplace le disque de couleur. Sinon, fallback sur
# le rendu par défaut (cercle + nom). sprite_animations définit les
# différentes poses/animations disponibles (voir plus bas).
@export var sprite_sheet: Texture2D = null
@export var sprite_frame_size: Vector2i = Vector2i(32, 32)
@export var sprite_scale: float = 2.0
## Dictionnaire des animations disponibles pour cette classe, indexé
## par nom ("idle", "walk", "attack", "hurt", "death"...). Chaque entrée :
## {row, start_col, frame_count, fps, loop}. Configuré via UnitDatabase
## (clé "animations" dans le dict "sprite") — voir _setup_sprite().
@export var sprite_animations: Dictionary = {}

## Correction fine de la position verticale du sprite, en pixels
## (positif = vers le bas, négatif = vers le haut). Le calcul par défaut
## place les pieds au centre de l'hexagone, mais selon la marge/le
## padding interne à la feuille de sprites, un ajustement manuel est
## souvent nécessaire — configurable via UnitDatabase (clé "y_offset"
## dans le dict "sprite") sans toucher au code.
@export var sprite_y_offset: float = 0.0

var _sprite: AnimatedSprite2D = null

# Suffixe de direction courant ("_s", "_se", "_e", "_ne", "_n", "_nw",
# "_w", "_sw"), déterminé par face_direction() selon la position de la
# cible/destination parmi les 8 orientations dessinées dans la feuille
# de sprites. play_animation() l'ajoute automatiquement au nom demandé
# (ex: "idle" devient "idle_se") pour choisir la bonne ligne. Retombe
# sur le nom brut si la variante directionnelle n'existe pas (permet de
# garder des animations non-directionnelles comme "cast").
var _current_facing_suffix: String = "_s"

# Coordonnée hexagonale (q, r) sur laquelle l'unité se trouve
# actuellement. Mise à jour par HexGrid lors du placement/déplacement.
var hex_coord: Vector2i

# Stats de base — valeurs BRUTES de la classe (UnitDatabase), avant
# tout bonus d'équipement. Ne changent jamais après le spawn ; les
# stats "effectives" ci-dessous (celles réellement utilisées partout
# ailleurs dans le code) sont recalculées à partir de ces bases +
# l'équipement à chaque changement d'arme/armure/accessoire — voir
# _recalculate_stats().
var base_max_hp: int = 50
var base_max_ea: int = 6
var base_courage: int = 10
var base_attack_stat: int = 12
var base_parade_stat: int = 8
var base_adresse_stat: int = 10
var base_force_stat: int = 10
var base_intelligence_stat: int = 10
var base_charisme_stat: int = 10
var base_chance_stat: int = 10

# Stats EFFECTIVES (base + bonus d'équipement) — ce sont celles-ci que
# le reste du code lit (jets de combat, PM, etc.). Ne pas les modifier
# directement : elles sont écrasées à chaque appel de
# _recalculate_stats(), déclenché automatiquement au spawn et à chaque
# changement d'équipement.
@export var max_hp: int = 50
## Points de mouvement par tour (se réinitialise chaque tour). Comme
## les autres stats, base_max_pm est la valeur brute (classe), max_pm
## la valeur EFFECTIVE recalculée (base + compétences — voir Déplacement
## silencieux/DS dans _recalculate_stats). L'équipement n'affecte pas
## le PM pour l'instant.
var base_max_pm: int = 3
@export var max_pm: int = 3
@export var max_ea: int = 6  # Réserve d'Énergie Astrale pour TOUT le combat (ne se réinitialise pas).
@export var courage: int = 10  # Détermine l'ordre de passage : plus haut = joue plus tôt.

## Stats de combat (échelle 1-20, comparées à un jet 1d20) :
## - attack_stat : une attaque d'arme ne touche que si 1d20 < attack_stat.
## - parade_stat : en posture Parade, annule une attaque d'arme en mêlée
##   et riposte si 1d20 < parade_stat.
## - adresse_stat : en posture Esquive, annule N'IMPORTE QUELLE attaque
##   (arme ou sort) si 1d20 < adresse_stat — mais une fois sur deux
##   seulement (voir dodge_available).
@export var attack_stat: int = 12
@export var parade_stat: int = 8
@export var adresse_stat: int = 10

## Stats secondaires (échelle 1-20 également) :
## - force_stat : chaque point au-dessus de 12 ajoute 1 dégât aux
##   attaques d'arme en MÊLÉE uniquement (voir get_melee_damage_bonus).
## - intelligence_stat : chaque 2 points au-dessus de 12 ajoute 1 dégât
##   (ou 1 soin) aux SORTS/enchantements (voir get_spell_damage_bonus).
##   Sert aussi au jet de lancer d'un sort (moyenne avec Adresse ou
##   Charisme selon le type du sort).
## - charisme_stat : utilisé avec Intelligence pour lancer un sort
##   psychique.
## - chance_stat : réservée pour un usage futur (critiques, etc.),
##   aucun effet implémenté pour l'instant.
@export var force_stat: int = 10
@export var intelligence_stat: int = 10
@export var charisme_stat: int = 10
@export var chance_stat: int = 10

## Réduction de dégâts subis, entièrement issue de l'équipement/des
## effets actifs (pas de base : 0 sans rien). Appliquée dans HexGrid
## lors de la résolution des dégâts. armor_value réduit les dégâts
## PHYSIQUES (PH, attaques d'arme) ; magic_armor_value réduit les
## dégâts PSYCHIQUES (PS) — voir lexique Mage. Un sort "brut" ignore
## les deux (voir Spell.ignores_armor).
var armor_value: int = 0
var magic_armor_value: int = 0

## Armure et accessoires équipés — comme equipped_weapon/off_hand_weapon,
## leurs bonus de stats sont appliqués via _recalculate_stats(). Un
## personnage peut porter PLUSIEURS accessoires à la fois (anneaux,
## collier, cape...), une seule armure.
var equipped_armor: Armor = null

## Pièces d'armure portées EN PLUS de equipped_armor : les 5 emplacements
## (casque, plastron, brassières, jambières, bottes) et le bouclier d'un
## aventurier de la Tour (voir TowerManager / EquipmentRules). Leurs bonus
## (PR compris) comptent comme ceux de equipped_armor.
var equipped_armor_pieces: Array = []

## Filière de métiers EXACTE de l'unité, du métier équipé (index 0) vers
## ses ancêtres, en codes courts — renseignée pour les aventuriers de la
## Tour, qui ont choisi chacune de leurs évolutions. Vide = on remonte
## parent_codes[0] (suffisant quand un métier n'a qu'un parent ; faux pour
## un métier à parents multiples comme l'Archange).
var forced_metier_chain: Array = []
var equipped_accessories: Array = []

## Race (voir race.gd/RaceDatabase) — choisie INDÉPENDAMMENT de la
## classe. Ses bonus (bonus_vie/bonus_mana/bonus_attaque/bonus_parade)
## sont appliqués via _recalculate_stats(), au même titre que
## l'équipement.
var equipped_race: Race = null

## Métier/classe (voir metier.gd/MetierDatabase — Guerrier, Mage,
## Voleur, Prêtre... NE PAS confondre avec Race). Mêmes bonus_*
## appliqués via _recalculate_stats(). Ses codes de compétences
## (inherited_skill_codes) comptent au même titre que ceux de la race
## dans has_skill().
var equipped_metier: Metier = null

## TOUTE la lignée de métiers du personnage (ex: Ménestrel ->
## [Menestrel, Barde]) — pas juste equipped_metier (le dernier/le plus
## spécialisé). "Un personnage a une race et PLUSIEURS classes" :
## c'est cette liste qui porte cette idée explicitement, construite
## une fois par _apply_metier_lineage() à partir de
## equipped_metier.parent_codes. Les sorts de CHAQUE métier de cette
## liste sont accordés (voir plus bas dans _ready()) — pas seulement
## ceux du dernier. Les drapeaux grants_* restent fusionnés directement
## sur equipped_metier (voir _apply_metier_lineage) pour que le reste
## du code (HexGrid compris) continue de le consulter sans changement.
var equipped_metiers: Array = []

## Effets actifs (buffs/debuffs/DoT à durée — voir status_effect.gd).
## Leurs bonus de stats sont aussi appliqués via _recalculate_stats(),
## au même titre que l'équipement.
var active_effects: Array = []

## Nombre de tours restants où cette unité ne peut PAS agir du tout
## (Mistral, Marchand de sable — voir Spell.stun_turns) : décompté et
## son tour automatiquement passé dans TurnManager._start_current_turn,
## comme une canalisation mais sans rien se déclencher à la fin.
var stunned_turns_remaining: int = 0

## Traits spéciaux d'un ennemi de la Tour (clé "traits" de son gabarit, voir
## TowerPoc) : paralysie, immunités, renvoi de magie, poison... Lus par HexGrid
## (_resolve_weapon_attack, _apply_spell_effect_to_target, traits de tour).
var traits: Dictionary = {}

## Yukionna : le prochain assaut (attaque d'arme) de cette unité est raté d'office.
var next_attack_misses: bool = false

## Ces trois-là ne sont PAS des var libres : ils sont recalculés à
## chaque appel de _recalculate_stats() à partir de active_effects
## (voir StatusEffect.grants_untargetable/grants_invulnerable/
## grants_frozen) — ne jamais les modifier directement, ajouter/retirer
## l'effet correspondant à la place.
## Provocation (Méca Tanker) : tant qu'au moins une unité provocatrice vivante
## est visible, les ennemis dirigés par l'IA ne peuvent viser qu'elles
## (voir EnemyAI._get_targets). Posé directement, jamais retiré : l'unité
## cesse de provoquer en mourant.
var is_taunting: bool = false

## Doigt d'honneur (Gladiateur) : celui qui nous a provoqués, et le nombre de
## NOS tours pendant lesquels nous ne pouvons viser que lui. forced_target_now
## est fixé par EnemyAI au début de chaque tour (null = pas de contrainte).
var taunt_source = null
var taunt_turns_remaining: int = 0
var forced_target_now = null

## Surbrillance temporaire (survol de l'ordre du tour, voir TurnManager).
var highlighted: bool = false

func set_highlight(on: bool) -> void:
	highlighted = on
	queue_redraw()

var is_untargetable: bool = false  # Invisibilité : les ENNEMIS ne peuvent plus la cibler (alliés si).
var is_invulnerable: bool = false  # Intangibilité/Cryogénisation : ignore tout dégât entrant.
var is_weakened: bool = false      # Affaibli (pièges) : sorts inutilisables.
var is_rooted: bool = false        # Entrave (pièges) : PM à 0 (dérivé des effets actifs).
var trap_charges: Dictionary = {}  # trap_id -> pièges restants à poser ce combat.
var is_frozen: bool = false        # Cryogénisation : ne peut plus se déplacer (voir Zone de mouvement dans HexGrid).

## Compétence passive de race/classe (voir Erèbe) — aucune classe ne
## l'a pour l'instant, à activer manuellement si besoin plus tard.
var has_nyctalopie: bool = false

## Sort en cours de canalisation (DI > 0 — voir Spell.cast_delay), ou
## null si aucun. Tant que non-null, l'unité ne peut pas agir
## normalement : son tour se limite à faire avancer la canalisation
## (voir TurnManager._start_current_turn). La cible/zone n'est PAS
## choisie au lancer : elle l'est au dernier tour de canalisation (voir
## HexGrid.begin_delayed_targeting) — pending_targets ne sert donc
## plus qu'aux sorts SELF/GROUP/BATTLEFIELD, recalculés à la volée
## par HexGrid.resolve_pending_spell (pas besoin de les stocker ici).
var pending_spell: Spell = null
var pending_turns_remaining: int = 0

func start_channeling(spell: Spell) -> void:
	pending_spell = spell
	pending_turns_remaining = spell.cast_delay

func clear_channeling() -> void:
	pending_spell = null
	pending_turns_remaining = 0

# Ajoute un effet actif et recalcule immédiatement les stats (pour
# qu'un buff/debuff soit effectif dès son application, pas seulement
# au tour suivant).
# Renvoie vrai si l'effet a bien été appliqué, faux s'il a été
# résisté (voir Empoisonneur, "Immunisé" — 1/2 chance d'ignorer un
# effet POISON entrant). Le bool de retour est facultatif à exploiter :
# ignoré sans erreur par tout appelant qui n'en a pas besoin.
func add_status_effect(effect: StatusEffect) -> bool:
	if effect.is_poison and bool(traits.get("immune_poison", false)):
		print("%s est immunisé contre le poison." % unit_name)
		return false
	if effect.is_poison and equipped_metier != null and equipped_metier.grants_empoisonneur_immunity and randf() < 0.5:
		print("%s est immunisé contre un effet de poison (Empoisonneur)." % unit_name)
		return false

	active_effects.append(effect)
	_recalculate_stats()

	# Ambidextrie accordée en cours de combat (voir Gantelets du
	# Berserk) : le sort d'attaque de la main secondaire n'est ajouté
	# qu'UNE FOIS à la création de l'unité (voir _ready()) — s'il
	# manque encore à ce stade, on l'ajoute maintenant.
	if has_ambidextrie and off_hand_weapon != null:
		var off_hand_spell_name = off_hand_weapon.create_attack_spell().spell_name
		var already_has_it = false
		for s in spells:
			if s.is_weapon_attack and s.spell_name == off_hand_spell_name:
				already_has_it = true
				break
		if not already_has_it:
			spells.insert(1, off_hand_weapon.create_attack_spell())

	return true

func remove_status_effect(effect: StatusEffect) -> void:
	active_effects.erase(effect)
	_recalculate_stats()

# À appeler au tout début du tour de cette unité (voir TurnManager),
# AVANT qu'elle puisse agir : applique les dégâts de DoT (Brûlure...),
# gère les effets à déclenchement probabiliste (Épée de Damocles...),
# décrémente les durées, retire les effets expirés. Les dégâts de DoT
# sont toujours "bruts" (ignorent toute armure), cohérent avec la
# définition de Brûlure.
# À appeler au tout début du tour de cette unité (voir TurnManager),
# AVANT qu'elle puisse agir : applique les dégâts de DoT (Brûlure...),
# gère les effets à déclenchement probabiliste (Épée de Damocles...),
# décrémente les durées, retire les effets expirés. Les dégâts de DoT
# sont toujours "bruts" (ignorent toute armure), cohérent avec la
# définition de Brûlure.
#
# Renvoie la liste des dégâts à AFFICHER ({amount, label}, un par tick)
# — cette fonction n'a pas accès à HexGrid.spawn_floating_text(), c'est
# donc à l'appelant (TurnManager) de les afficher.
func process_status_effects_on_turn_start() -> Array:
	var expired: Array = []
	var ticks: Array = []

	for effect in active_effects:
		if effect.mana_drain_per_tick > 0:
			var drained: int = min(effect.mana_drain_per_tick, current_ea)
			current_ea -= drained
			if effect.drains_to_source and effect.source_ref != null and is_instance_valid(effect.source_ref) and effect.source_ref.current_hp > 0:
				effect.source_ref.current_ea = min(effect.source_ref.max_ea, effect.source_ref.current_ea + drained)
			ticks.append({"amount": drained, "label": effect.effect_name})
		if effect.damage_per_tick > 0 or effect.tick_dice_count > 0:
			effect._ticks_elapsed += 1
			var should_tick = true
			if effect.tick_every_other_turn:
				should_tick = (effect._ticks_elapsed % 2 == 1)  # Tours 1, 3, 5...
			if should_tick:
				var tick_amount: int = effect.damage_per_tick
				if effect.tick_dice_count > 0:
					tick_amount = 0
					for i in range(effect.tick_dice_count):
						tick_amount += randi_range(1, 6)
				var hp_before: int = current_hp
				take_damage(tick_amount)
				ticks.append({"amount": tick_amount, "label": effect.effect_name})
				if effect.drains_to_source and effect.source_ref != null and is_instance_valid(effect.source_ref) and effect.source_ref.current_hp > 0:
					var gained: int = max(0, hp_before - current_hp)
					effect.source_ref.current_hp = min(effect.source_ref.max_hp, effect.source_ref.current_hp + gained)

		# Effet à déclenchement probabiliste (voir Épée de Damocles) :
		# à chaque tour de la cible, une chance de se déclencher ; sinon,
		# le dégât potentiel augmente pour la prochaine tentative. Une
		# fois déclenché, l'effet disparaît (quel que soit le résultat).
		if effect.trigger_chance > 0.0:
			if randf() < effect.trigger_chance:
				var total = 0
				for term in effect.trigger_dice_terms:
					total += term.get("modifier", 0)
					for i in range(term.get("count", 0)):
						total += randi_range(1, term.get("sides", 6))
				total += effect._trigger_turns_waited * effect.trigger_bonus_dice_per_turn_waited
				take_damage(total)  # Toujours "brut" par nature (voir Spell.ignores_armor pour le sort d'origine).
				ticks.append({"amount": total, "label": effect.effect_name})
				expired.append(effect)
			else:
				effect._trigger_turns_waited += 1

		if effect.duration_remaining > 0:
			effect.duration_remaining -= 1
			if effect.duration_remaining <= 0:
				expired.append(effect)

	for e in expired:
		active_effects.erase(e)

	if not expired.is_empty():
		_recalculate_stats()

	return ticks

func get_melee_damage_bonus() -> int:
	return max(0, force_stat - 12)

func get_spell_damage_bonus() -> int:
	return max(0, int((intelligence_stat - 12) / 2.0))

# Recalcule toutes les stats EFFECTIVES à partir des stats de base
# (base_*) + les bonus de TOUT l'équipement actuellement porté (armes,
# armure, accessoires) ET des effets actifs (buffs/debuffs). À appeler
# à chaque changement d'équipement ou d'effet (voir
# equip_weapon/equip_armor/equip_accessory/add_status_effect/etc.) —
# jamais besoin de modifier max_hp/attack_stat/etc. directement.
# Vrai si cette unité a la compétence `code` (voir SkillDatabase),
# héritée de sa race (equipped_race.inherited_skill_codes) — ignore un
# éventuel "*" final (présent sur certains codes dans les données
# d'origine, jamais expliqué, traité comme une simple marque).
func has_skill(code: String) -> bool:
	for raw in _all_skill_sources():
		if str(raw).rstrip("*") == code:
			return true
	return false

# Codes de compétences de la race ET de TOUTE la lignée de métiers
# (un Ninja a aussi celles du Rôdeur et du Voleur).
func _all_skill_sources() -> Array:
	var all: Array = []
	if equipped_race != null:
		all.append_array(equipped_race.inherited_skill_codes)
	var metiers: Array = equipped_metiers.duplicate()
	if equipped_metier != null and not metiers.has(equipped_metier):
		metiers.append(equipped_metier)
	for m in metiers:
		all.append_array(m.inherited_skill_codes)
	return all

# Remonte parent_codes depuis equipped_metier jusqu'à la racine,
# construit la liste de TOUS les noms de la lignée (equipped_metier.
# lineage_names) et fusionne (OR) tous les drapeaux grants_* des
# ancêtres directement SUR equipped_metier — pas besoin de garder une
# liste de ressources Metier à part : equipped_metier devient la
# "somme" de toute sa lignée, et chaque grants_X / check de nom qui le
# consulte ailleurs (HexGrid, ici) continue de fonctionner tel quel.
# Prévient les boucles infinies (parent_codes mal formé) avec une
# limite de profondeur généreuse.
# Vrai si `name` fait partie de la lignée de métiers du personnage
# (equipped_metiers — voir sa doc), pas seulement le dernier/le plus
# spécialisé. Même esprit que has_skill().
func has_metier(name: String) -> bool:
	for m in equipped_metiers:
		if m.metier_name == name:
			return true
	return false

func _apply_metier_lineage() -> void:
	if equipped_metier == null:
		return

	equipped_metier.lineage_names = [equipped_metier.metier_name]
	equipped_metiers = [equipped_metier]

	for parent in _get_metier_ancestors():
		equipped_metier.lineage_names.append(parent.metier_name)
		equipped_metiers.append(parent)

		equipped_metier.grants_moine_frappe_energie = equipped_metier.grants_moine_frappe_energie or parent.grants_moine_frappe_energie
		equipped_metier.grants_voleur_esquive_totale = equipped_metier.grants_voleur_esquive_totale or parent.grants_voleur_esquive_totale
		equipped_metier.grants_empoisonneur_immunity = equipped_metier.grants_empoisonneur_immunity or parent.grants_empoisonneur_immunity
		equipped_metier.grants_empoisonneur_dague = equipped_metier.grants_empoisonneur_dague or parent.grants_empoisonneur_dague
		equipped_metier.grants_assassin_coup_mortel = equipped_metier.grants_assassin_coup_mortel or parent.grants_assassin_coup_mortel
		equipped_metier.grants_assassin_precision_mortelle = equipped_metier.grants_assassin_precision_mortelle or parent.grants_assassin_precision_mortelle
		equipped_metier.grants_rodeur_camouflage = equipped_metier.grants_rodeur_camouflage or parent.grants_rodeur_camouflage
		equipped_metier.grants_ninja_esquive_totale = equipped_metier.grants_ninja_esquive_totale or parent.grants_ninja_esquive_totale
		equipped_metier.grants_ninja_frappe_des_ombres = equipped_metier.grants_ninja_frappe_des_ombres or parent.grants_ninja_frappe_des_ombres
		equipped_metier.grants_prestidigitateur_realite_distordue = equipped_metier.grants_prestidigitateur_realite_distordue or parent.grants_prestidigitateur_realite_distordue

# Ancêtres du métier équipé (objets Metier), du plus proche au plus
# lointain. Si forced_metier_chain est renseignée (aventurier de la Tour),
# c'est la filière réellement choisie ; sinon on remonte parent_codes[0],
# ce qui suffit tant qu'un métier n'a qu'un parent direct.
func _get_metier_ancestors() -> Array:
	var ancestors: Array = []
	if not forced_metier_chain.is_empty():
		for i in range(1, forced_metier_chain.size()):
			var chosen := MetierDatabase.build(str(forced_metier_chain[i]))
			if chosen != null:
				ancestors.append(chosen)
		return ancestors

	var current := equipped_metier
	var depth := 0
	while not current.parent_codes.is_empty() and depth < 10:
		depth += 1
		var parent_code: String = current.parent_codes[0]
		var parent := MetierDatabase.build(parent_code)
		if parent == null:
			break
		ancestors.append(parent)
		current = parent
	return ancestors

func _recalculate_stats() -> void:
	max_hp = base_max_hp
	max_ea = base_max_ea
	max_pm = base_max_pm
	if equipped_race != null:
		max_pm += equipped_race.pm_modifier
	courage = base_courage
	attack_stat = base_attack_stat
	parade_stat = base_parade_stat
	adresse_stat = base_adresse_stat
	force_stat = base_force_stat
	intelligence_stat = base_intelligence_stat
	charisme_stat = base_charisme_stat
	chance_stat = base_chance_stat
	armor_value = 0
	magic_armor_value = 0

	# Compétences (voir Race.inherited_skill_codes / SkillDatabase) avec
	# un effet de combat direct — trop peu nombreuses et trop
	# différentes les unes des autres pour un système générique de
	# bonus_*, donc appliquées à la main ici :
	if has_skill("AM"):   # Ambidextrie
		has_ambidextrie = true
	for effect in active_effects:
		if effect.grants_ambidextrie:
			has_ambidextrie = true
			break

	# Pirate : une arme à feu ("Pistolet...") en main principale ET une
	# arme de corps à corps (ni "Pistolet", ni déjà à mains nues à
	# vide) en main secondaire — pas besoin d'Ambidextrie pour ce
	# combo précis. Les DEUX sens (feu/CAC ou CAC/feu) comptent.
	if has_metier("Pirate") and equipped_weapon != null and off_hand_weapon != null:
		var main_is_firearm = equipped_weapon.weapon_name.begins_with("Pistolet")
		var off_is_firearm = off_hand_weapon.weapon_name.begins_with("Pistolet")
		if main_is_firearm != off_is_firearm:  # L'une des deux est une arme à feu, l'autre non — exactement le combo visé.
			has_ambidextrie = true

	if has_skill("DS"):   # Déplacement silencieux
		max_pm += 1
	if has_skill("ALM"):  # Attire les monstres : les monstres le visent en priorité (voir EnemyAI).
		is_taunting = true
	if has_skill("TV"):   # Tête vide
		magic_armor_value += 1
	if has_skill("TDM"):  # Truc de mauviette
		armor_value += 1

	# Voleur (esquive totale) : -3 Adresse un tour sur deux (voir
	# voleur_ad_malus_active, alterné dans reset_turn_resources).
	if voleur_ad_malus_active and equipped_metier != null and equipped_metier.grants_voleur_esquive_totale:
		adresse_stat -= 3

	# Tenir bon (Gladiateur) : +niveau Armure sous 33% PV — recalculé à
	# chaque appel de cette fonction, y compris juste après avoir
	# encaissé des dégâts (voir take_damage()), pour rester à jour.
	if has_metier("Gladiateur") and max_hp > 0 and float(current_hp) / max_hp < 0.33:
		armor_value += level

	# Équipement, race, métier ET effets actifs (buffs/debuffs)
	# partagent les mêmes noms de champs bonus_* — même boucle pour
	# tous, peu importe leur provenance.
	var sources: Array = []
	if equipped_weapon != null:
		sources.append(equipped_weapon)
	if has_ambidextrie and off_hand_weapon != null:
		sources.append(off_hand_weapon)
	if equipped_armor != null:
		sources.append(equipped_armor)
	for armor_piece in equipped_armor_pieces:
		sources.append(armor_piece)
	for accessory in equipped_accessories:
		sources.append(accessory)
	if equipped_race != null:
		sources.append(equipped_race)
	if equipped_metier != null:
		sources.append(equipped_metier)
	for effect in active_effects:
		sources.append(effect)

	for item in sources:
		courage += item.bonus_courage
		intelligence_stat += item.bonus_intelligence
		charisme_stat += item.bonus_charisme
		adresse_stat += item.bonus_adresse
		force_stat += item.bonus_force
		chance_stat += item.bonus_chance
		attack_stat += item.bonus_attaque
		parade_stat += item.bonus_parade
		armor_value += item.bonus_armure
		magic_armor_value += item.bonus_armure_magique
		if progression_managed and (item == equipped_race or item == equipped_metier):
			continue
		max_hp += item.bonus_vie
		max_ea += item.bonus_mana

	# Berzerk : pas d'Énergie Astrale (même celle que lui donneraient sa race
	# ou son équipement) — c'est la Rage qui lui sert de ressource.
	if has_metier("Berzerk"):
		max_ea = 0

	# Les PV/EA courants ne doivent jamais dépasser le nouveau maximum
	# (utile si on retire un équipement/effet qui augmentait max_hp/max_ea).
	current_hp = min(current_hp, max_hp)

	# Intouchable/invulnérable/gelé : dérivés des effets actifs, jamais
	# assignés directement ailleurs (voir la doc sur ces 3 champs plus haut).
	is_untargetable = false
	is_invulnerable = false
	is_frozen = false
	is_rooted = false
	is_weakened = false
	for effect in active_effects:
		if effect.weaken > 0:
			is_weakened = true
		if effect.grants_rooted:
			is_rooted = true
		if effect.grants_untargetable:
			is_untargetable = true
		if effect.grants_invulnerable:
			is_invulnerable = true
		if effect.grants_frozen:
			is_frozen = true
	current_ea = min(current_ea, max_ea)
	if is_weakened:
		force_stat = max(0, force_stat - 2)
		adresse_stat = max(0, adresse_stat - 2)
	if is_rooted:
		max_pm = 0
		current_pm = 0

# Posture actuelle (choisie à son tour, persiste jusqu'au tour suivant).
# Par défaut : Parade (pas de posture "Aucune").
# (Non typé strictement en DefensiveStance pour éviter tout risque de
# type mismatch runtime, comme observé avec Array[Spell] plus tôt.)
var defensive_stance: int = DefensiveStance.PARRY

# Vrai si l'unité peut encore tenter d'esquiver la PROCHAINE attaque
# qu'elle subit (règle "1 attaque sur 2"). Remis à true au début de
# son propre tour (voir reset_turn_resources).
var dodge_available: bool = true

## Ressources des capacités actives propres à une race (voir
## Race.grants_hobbit_*) — initialisées en début de combat dans
## HexGrid.build_unit(), PAS remises à zéro à chaque tour (ce sont des
## réserves pour tout le combat, contrairement à dodge_available).
var hobbit_bravoure_uses: int = 0
var coup_decisif_on: bool = false          # Chasseurs de primes/monstres : bascule ON/OFF.
var meca_support_choice: String = "attaque"  # Méca Support : "attaque" ou "parade", choisi à chaque tour.
var is_meca_support: bool = false
var tanker_aura_count: int = 0  # Méca Tanker : nombre d'alliés protégés par l'aura.
var ogre_pi_converted: int = 0   # PI déjà convertis par l'Ogre (3 maximum).
var grr_used_this_combat: bool = false
var keep_corpse: bool = false   # Mort : garder le cadavre pour une résurrection (voir HexGrid._graveyard).
var is_summoned: bool = false
var pi: int = 0         # Points d'Impact : dégâts supplémentaires sur chaque attaque d'arme.
var chain_pi: int = 0   # PI de l'Enchaînement (Ninja), remis à 0 si une attaque ne fait pas de dégâts.
var redirect_source = null      # Un pour tous : l'unité qui encaisse à ma place...
var redirect_charges: int = 0   # ... pour ce nombre de dégâts encore.
var redirect_effect = null      # Le malus d'AT du gladiateur, retiré à la fin.
var balance_next_is_damage: bool = false  # Balance de l'univers : alterne soin / dégâts.
var parallel_partner = null  # Plan parallèle : l'autre unité du plan (voir HexGrid.can_interact).
var parallel_turns_remaining: int = 0
var detect_uses: int = 0  # Charges de Détecter (DET), 3 par combat.
var hobbit_stones: int = 0

## Combo (Samurai, voir Race.grants_samurai_combo) : nombre d'attaques
## d'arme au CORPS À CORPS faites ce tour-ci ; et si la défense
## (Parade/Esquive) est actuellement désactivée suite à un échec en 2e
## attaque. Les deux sont remis à zéro par reset_turn_resources, qui
## tourne au DÉBUT du tour de cette unité — donc la désactivation de
## défense dure bien "jusqu'au prochain tour du Samurai", comme prévu :
## elle reste vraie pendant les tours adverses entre-temps.
var samurai_melee_attacks_this_turn: int = 0
var samurai_combo_disabled_defense: bool = false

## Arme céleste (Walkyrie) : nombre d'attaques d'arme restantes où les
## dégâts sont traités comme magiques (réduits par magic_armor_value
## plutôt qu'armor_value) — décrémenté à chaque attaque d'arme dans
## HexGrid._resolve_weapon_attack, peu importe qu'elle touche ou non.
var magic_weapon_attacks_remaining: int = 0

## Niveau du personnage (voir WorldManager.party_level côté joueur,
## transféré par PlacementManager avant le combat — 1 par défaut pour
## les ennemis, qui n'ont pas de progression). Utilisé par les
## formules de sorts du Prêtre qui référencent "niveau" (voir
## Spell.includes_caster_level/level_multiplier).
var level: int = 1

## Ordre choisi par un Prêtre (voir pretre_spell_catalog.gd) : "Ordre
## de l'harmonie", "Ordre du néant" ou "Ordre du cycle éternel" — un
## Prêtre n'appartient qu'à UN SEUL Ordre à la fois (spécialisation
## exclusive), qui détermine à la fois quels sorts il reçoit (voir
## PretreSpellCatalog.build_for_order) ET qui bénéficie de la nuit
## (Noirceur ne profite qu'aux Prêtres de l'Ordre du néant — voir
## HexGrid._install_night). Vide/sans effet pour tout le monde
## d'autre (pas un Prêtre, ou Prêtre sans Ordre choisi).
var pretre_order: String = ""

## Nombre de charges d'Infection actives (Ordre du cycle éternel,
## Prêtre) — posées par "Infection" (cumulable, pas de limite dans les
## données d'origine), déclenchées et consommées d'un coup par
## "Nécrose" (4 dégâts bruts par charge).
var infection_stacks: int = 0

## Nombre de Mécas invoqués ce combat (Ingénieur Automate — voir
## meca_spell_catalog.gd) — plafonné à 2, toutes branches confondues
## (Doc/Tanker/Combat/Support), selon la restriction du métier d'origine.
var mecas_summoned_this_combat: int = 0

## Bouclier de Foi (Templier) : réserve de points qui absorbe les
## dégâts entrants avant qu'ils n'atteignent les PV — voir take_damage().
## Un coup CRITIQUE détruit le bouclier d'un coup, quelle que soit sa
## réserve restante (les dégâts du critique passent alors en entier).
var shield_power: int = 0

## ============================================================
## Berzerk — voir berzerk_spell_catalog.gd.
## ============================================================

## Rage (Berzerk) : +1 par point de dégâts REÇU (voir take_damage()),
## pas de plafond précisé dans les données d'origine. Dépensée par
## Frappe puissante (5), Tourbillon (10), Raaah (X, voir plus bas).
var rage: int = 0

## Raaah : 1 fois par combat — convertit X rage en +X/10 dégâts
## PERMANENTS (voir berzerk_permanent_damage_bonus).
var raaah_used_this_combat: bool = false
var berzerk_permanent_damage_bonus: int = 0

## ============================================================
## Gladiateur — voir gladiateur_spell_catalog.gd.
## ============================================================

## Gloire : +1 par attaque réussie, +2 par parade réussie, -1 par
## parade ratée (voir HexGrid._resolve_weapon_attack) — commence à 5
## (Pour la gloire), posé dans _ready(). Dépensée par Doigt d'honneur
## (5), Coup de bouclier (7), Tortue (10).
var gloire: int = 0

## Maître d'armes : nombre d'attaques réussies, NON PARÉES et NON
## ESQUIVÉES d'affilée (+2 dégâts par cran, voir
## HexGrid._resolve_weapon_attack) — remis à 0 sur une attaque ratée,
## parée OU esquivée.
var maitre_armes_streak: int = 0

## Corsaire (Salve) : vrai une fois utilisée — 1 fois max par combat.
var corsaire_salve_used: bool = false

## Voleur (esquive totale) : vrai un tour sur deux (alterné à chaque
## DÉBUT de son propre tour, voir reset_turn_resources) — -3 Adresse
## appliqué dans _recalculate_stats() tant que vrai. Sans effet pour
## tout autre métier.
var voleur_ad_malus_active: bool = false

## Empoisonneur (Dague empoisonnée) : vrai dès que le bonus de la
## première attaque du combat a été appliqué — voir
## HexGrid._resolve_weapon_attack. Ne se remet jamais à false en
## cours de combat (une seule fois par combat, pas par tour).
var empoisonneur_first_attack_used: bool = false

## Assassin (Coup mortel) : références des cibles DÉJÀ frappées au
## moins une fois ce combat — le premier coup sur CHAQUE cible
## bénéficie de la fenêtre de critique étendue (1 à 4), pas juste le
## premier coup du combat dans l'absolu. Marquée dès la TENTATIVE
## (touchée ou non), voir HexGrid._resolve_weapon_attack.
var assassin_hit_targets: Array = []

## Ninja (Permutation) : nombre de fois déjà utilisée ce combat — 3 max.
var ninja_permutations_used: int = 0

## Peintre : usages consommés dès le LANCER, que le test réussisse ou
## non (voir la note de Spell.is_peintre_peinture_de_guerre sur cette
## interprétation). Peinture de guerre : 1 fois max. Maquillage : 3 fois max.
var peintre_peinture_de_guerre_used: bool = false
var peintre_maquillage_used: int = 0

## Si activé, l'unité peut équiper une seconde arme (off_hand_weapon)
## et bénéficie donc de 2 attaques d'arme par tour au lieu d'une seule
## (une par arme). Sans Ambidextrie : 1 seule arme, 1 seule attaque
## d'arme possible par tour.
@export var has_ambidextrie: bool = false

## Arme en main principale — détermine les dégâts ET la portée de
## l'attaque générée automatiquement dans _ready() (mêlée ou à
## distance selon l'arme). Si non définie, une arme à mains nues
## ("Poings") est utilisée par défaut.
@export var equipped_weapon: Weapon = null

## Arme en main secondaire — uniquement utilisée si has_ambidextrie
## est activé. Génère une deuxième attaque d'arme distincte.
@export var off_hand_weapon: Weapon = null

## Sorts/enchantements disponibles pour cette unité (hors attaque(s)
## d'arme, ajoutées automatiquement dans _ready() à partir des armes
## équipées).
## (Tableau volontairement non typé strictement : GDScript propage mal
## le typage Array[Spell] à travers un retour de fonction statique.)
@export var spells: Array = []

## Inventaire : armes de rechange (pour changer d'arme en combat),
## potions (soin ou mana), et flèches (munitions pour une arme à
## distance, choisies juste avant de tirer).
@export var inventory_weapons: Array = []
@export var inventory_potions: Array = []
@export var inventory_arrows: Array = []
## Munition sélectionnée pour les attaques à distance (reste d'un tour à l'autre tant qu'on ne change pas).
var selected_arrow: Arrow = null

var current_hp: int
## Vrai pour un aventurier de la Tour : ses PV/EA de base incluent déjà ceux de
## la race, des métiers et des niveaux (voir TowerManager.get_hp_ea_progression).
var progression_managed: bool = false

var current_pm: int
var current_ea: int

# Nombre d'actions (hors déplacement) déjà utilisées ce tour-ci.
# Remis à zéro à chaque tour par reset_turn_resources().
var actions_used_this_turn: int = 0

# Reste vrai tant que TOUTES les actions de ce tour sont des attaques
# d'arme (mêlée ou à distance, peu importe). Dès qu'une action d'un
# autre type est utilisée (sort, potion, changement d'arme...), passe
# à false et le bonus Ambidextrie (2e attaque d'arme) devient
# impossible pour le reste de ce tour.
var all_actions_weapon_attacks_this_turn: bool = true

# Sorts (Resource Spell) déjà utilisés ce tour-ci — empêche de lancer
# deux fois le même sort/la même arme dans le même tour (utile surtout
# pour l'Ambidextrie : chaque arme ne peut frapper qu'une fois).
var spells_used_this_turn: Array = []

# Représente "l'action utilitaire" du tour (boire une potion, changer
# d'arme, ramasser une arme...) pour l'économie d'action : ce n'est pas
# une attaque d'arme, donc son utilisation consomme l'unique action
# normale du tour (voir can_perform_action / record_action_taken).
var utility_action_slot: Spell

# Émis quand l'unité meurt (HexGrid et TurnManager s'y abonnent pour
# se nettoyer proprement : libérer la case, retirer de la file de tours).
signal died(unit: CombatUnit)

func _ready() -> void:
	# Tout en premier : un personnage a sa race et TOUTE la lignée de
	# ses métiers (pas que le dernier) — Ménestrel EST un Barde, par
	# exemple. Fusionne les noms ET les drapeaux grants_* de tous les
	# ancêtres dans equipped_metier lui-même, pour que tout le reste du
	# code (ici et dans HexGrid) continue à le consulter normalement
	# sans rien changer d'autre.
	_apply_metier_lineage()

	# Pour la gloire (Gladiateur) : commence le combat avec 5 Gloires.
	if has_metier("Gladiateur"):
		gloire = 5

	# Rage (Berzerk) : commence le combat avec 5 (puis +1 par point de
	# dégâts subi, voir take_damage).
	if has_metier("Berzerk"):
		rage = 5

	# D'abord : les stats effectives (max_hp, max_ea, etc.) dépendent de
	# l'équipement déjà assigné à ce stade (voir HexGrid.build_unit(),
	# qui assigne l'équipement AVANT add_child — donc avant que _ready()
	# ne s'exécute).
	_recalculate_stats()

	current_hp = max_hp
	current_pm = max_pm
	current_ea = max_ea
	actions_used_this_turn = 0
	all_actions_weapon_attacks_this_turn = true

	# Toute unité a au moins une attaque d'arme, générée à partir de son
	# arme équipée (mains nues par défaut si aucune arme n'est définie).
	if equipped_weapon == null:
		equipped_weapon = _create_default_weapon()
	spells.insert(0, equipped_weapon.create_attack_spell())

	# Une seconde attaque d'arme (main secondaire) uniquement si l'unité
	# a l'Ambidextrie ET qu'une arme secondaire est définie.
	if has_ambidextrie and off_hand_weapon != null:
		spells.insert(1, off_hand_weapon.create_attack_spell())

	# Capacités actives propres à une race (voir Race.grants_hobbit_*/
	# grants_samurai_*) — ajoutées ici (pas dans HexGrid.build_unit())
	# car equipped_race n'est assigné qu'après build_unit() pour l'unité
	# du joueur (voir PlacementManager), mais toujours avant _ready().
	if equipped_race != null:
		if equipped_race.grants_hobbit_bravoure:
			hobbit_bravoure_uses = 3
			# Un bouton par valeur de X (1 à 5, plage raisonnable non
			# précisée dans les données d'origine) : Test Courage-X,
			# +X Force si réussi — voir HexGrid._resolve_hobbit_bravoure.
			for x in range(1, 6):
				var bravoure := Spell.new()
				bravoure.spell_name = "Bravoure (X=%d)" % x
				bravoure.target_mode = Spell.TargetMode.SELF
				bravoure.is_hobbit_bravoure = true
				bravoure.bravoure_x = x
				bravoure.ea_cost = 0
				spells.append(bravoure)

		if equipped_race.grants_ogre_pi:
			for x in range(1, 4):
				var ogre_spell := Spell.new()
				ogre_spell.spell_name = "PI d'ogre (X=%d)" % x
				ogre_spell.target_mode = Spell.TargetMode.SELF
				ogre_spell.is_ogre_pi = true
				ogre_spell.ogre_pi_x = x
				ogre_spell.ea_cost = 0
				ogre_spell.info_text = "Retire %d AT et %d PRD pour gagner +%d PI (3 maximum par combat)." % [x, x, x]
				spells.append(ogre_spell)

		if equipped_race.grants_hobbit_precision:
			hobbit_stones = 6
			var precision := Spell.new()
			precision.spell_name = "Précision des hobbits"
			precision.target_mode = Spell.TargetMode.SINGLE_ENEMY
			precision.min_range = 1
			precision.max_range = 4  # Portée de lancer raisonnable, non précisée dans les données d'origine.
			precision.is_hobbit_precision = true
			precision.ea_cost = 0
			spells.append(precision)

		if equipped_race.grants_samurai_concentration:
			var concentration := Spell.new()
			concentration.spell_name = "Concentration"
			concentration.target_mode = Spell.TargetMode.SELF
			concentration.is_samurai_concentration = true
			concentration.ea_cost = 0
			concentration.icon_path = ClassSpellIcons.path_for("Concentration")
			spells.append(concentration)

	# Compétence Détecter (DET, voir skill_database.gd) : révèle toutes les
	# unités invisibles dans un rayon de 2 cases autour du lanceur. Gratuite
	# en EA, sans limite d'usage (non précisés dans les données d'origine).
	if has_skill("DET"):
		detect_uses = 3
		var detect := Spell.new()
		detect.is_detect_skill = true
		detect.spell_name = "Détecter"
		# Zone de 3 cases de large (case visée + voisines), portée 2 : révèle
		# unités invisibles ET pièges (voir HexGrid._cast_detect_zone).
		detect.target_mode = Spell.TargetMode.ZONE
		detect.min_range = 1
		detect.max_range = 2
		detect.reveals_invisible = true
		detect.unavoidable = true
		detect.ea_cost = 0
		detect.icon_path = "res://assets/spell_icons/mage/detection_de_zone.png"
		spells.append(detect)

	# Désamorcer (DE/DES) : retire un piège détecté ou déclenché (case adjacente).
	if has_skill("DE") or has_skill("DES"):
		var disarm := Spell.new()
		disarm.is_disarm_skill = true
		disarm.spell_name = "Désamorcer"
		disarm.icon_path = ClassSpellIcons.path_for("Désamorcer")
		disarm.target_mode = Spell.TargetMode.ZONE
		disarm.zone_offsets = [Vector2i.ZERO]
		disarm.min_range = 1
		disarm.max_range = 1
		disarm.unavoidable = true
		disarm.ea_cost = 0
		disarm.info_text = "Retire un piège détecté (ou connu de ton groupe), ou libère une victime d'un piège déclenché. Test d'Adresse. Case adjacente."
		spells.append(disarm)

	# Poser des pièges : un sort par type dont la race/les métiers donnent des charges
	# (voir TrapDatabase.CHARGES, le plus haut l'emporte).
	var trap_race: String = equipped_race.race_name if equipped_race != null else ""
	var trap_metiers: Array = []
	for m in equipped_metiers:
		trap_metiers.append(m.metier_name)
	for trap_id in TrapDatabase.all_ids():
		var charges: int = TrapDatabase.charges_for(trap_id, trap_race, trap_metiers)
		if charges <= 0:
			continue
		var def: TrapDef = TrapDatabase.build(trap_id)
		trap_charges[trap_id] = charges
		var ts := Spell.new()
		ts.is_trap_spell = true
		ts.trap_id = trap_id
		ts.spell_name = def.trap_name
		ts.target_mode = Spell.TargetMode.ZONE
		ts.zone_offsets = [Vector2i.ZERO]
		ts.min_range = def.place_min_range
		ts.max_range = def.place_max_range
		ts.unavoidable = true
		ts.ea_cost = 0
		ts.icon_path = def.get_icon_path()
		ts.info_text = def.get_summary() + "\nCharges : %d" % charges
		spells.append(ts)

	# Sorts de la branche de métier Walkyrie (voir
	# walkyrie_spell_catalog.gd) — liés au MÉTIER équipé, pas à la race
	# (malgré le nom "Walkyrie" qui existe aussi comme race, sans
	# rapport ici). Cumulatifs selon l'arborescence d'origine, gérés
	# dans build_for_metier lui-même.
	if equipped_metier != null:
		for s in WalkyrieSpellCatalog.build_for_metier(equipped_metier.metier_name):
			spells.append(s)

	# Sorts de la RACE Elfe Sylvain (voir elfe_sylvain_spell_catalog.gd)
	# — liés à la race équipée, pas au métier (à la différence des
	# sorts Walkyrie ci-dessus).
	if equipped_race != null and equipped_race.race_name == "Elfe Sylvain":
		for s in ElfeSylvainSpellCatalog.build_all():
			spells.append(s)

	# Sorts du MÉTIER Prêtre (voir pretre_spell_catalog.gd) — un Prêtre
	# n'appartient qu'à UN SEUL Ordre (pretre_order), qui détermine
	# lesquels de ses sorts il reçoit. Être nocturne / Maître de la nuit :
	# PAS appliqués ici — ce sont des passifs CONDITIONNELS à la nuit
	# (posée par Noirceur, Ordre du néant uniquement), gérés côté
	# HexGrid (voir _install_night/_end_night), pas des bonus permanents
	# à la création de l'unité.
	if has_metier("Prêtre"):
		for s in PretreSpellCatalog.build_for_order(pretre_order, level):
			spells.append(s)

	# Sorts du MÉTIER Forgeur de runes (voir
	# forgeur_de_runes_spell_catalog.gd) — accordés d'un coup.
	if has_metier("Forgeur de runes"):
		for s in ForgeurDeRunesSpellCatalog.build_all():
			spells.append(s)

	# Sorts du MÉTIER Archéologue (voir archeologue_spell_catalog.gd) —
	# accordés d'un coup.
	if has_metier("Archéologue"):
		for s in ArcheologueSpellCatalog.build_all():
			spells.append(s)

	# Sorts du MÉTIER Conservateur (voir conservateur_spell_catalog.gd)
	# — accordés d'un coup.
	if has_metier("Conservateur"):
		for s in ConservateurSpellCatalog.build_all():
			spells.append(s)

	# Sorts d'invocation de Méca du MÉTIER Ingénieur Automate (voir
	# meca_spell_catalog.gd) — accordés d'un coup (4 sorts, pas 12 : les
	# paliers Supplément 1/2 sont gérés au moment de l'invocation selon
	# le niveau, pas par des sorts séparés).
	if has_metier("Ingénieur Automate"):
		for s in MecaSpellCatalog.build_all():
			spells.append(s)

	# Sorts du MÉTIER Moine (voir moine_spell_catalog.gd) — accordés
	# d'un coup. Frappe d'énergie (passif, fenêtre de critique étendue
	# à mains nues) n'est PAS un sort : géré directement dans HexGrid
	# via Metier.grants_moine_frappe_energie.
	if has_metier("Moine"):
		for s in MoineSpellCatalog.build_all():
			spells.append(s)

	# Sorts du MÉTIER Templier (voir templier_spell_catalog.gd) —
	# accordés d'un coup.
	if has_metier("Templier"):
		for s in TemplierSpellCatalog.build_all():
			spells.append(s)

	# Camouflage Naturel (Rôdeur) : invisible dès le départ, jusqu'à sa
	# première attaque d'arme (voir HexGrid._resolve_weapon_attack, qui
	# retire cet effet précis par son nom).
	if equipped_metier != null and equipped_metier.grants_rodeur_camouflage:
		var camouflage := StatusEffect.new()
		camouflage.effect_name = "Camouflage Naturel"
		camouflage.duration_remaining = -1
		camouflage.grants_untargetable = true
		add_status_effect(camouflage)

	# Sorts du MÉTIER Ninja (voir ninja_spell_catalog.gd) — accordés
	# d'un coup. Esquive totale sans malus et Frappe des ombres
	# (passifs) ne sont PAS des sorts : gérés directement dans HexGrid
	# via Metier.grants_ninja_esquive_totale/grants_ninja_frappe_des_ombres.
	if has_metier("Ninja"):
		for s in NinjaSpellCatalog.build_all():
			spells.append(s)

	# Sorts du MÉTIER Peintre (voir peintre_spell_catalog.gd) — accordés
	# d'un coup.
	if has_metier("Peintre"):
		for s in PeintreSpellCatalog.build_all():
			spells.append(s)

	# Sorts du MÉTIER Prestidigitateur (voir
	# prestidigitateur_spell_catalog.gd) — accordés d'un coup. Réalité
	# distordue (immunité aux critiques) n'est PAS un sort : géré
	# directement dans HexGrid via
	# Metier.grants_prestidigitateur_realite_distordue.
	if has_metier("Prestidigitateur"):
		for s in PrestidigitateurSpellCatalog.build_all():
			spells.append(s)

	# Sorts du MÉTIER Barde (voir barde_spell_catalog.gd) — accordés
	# d'un coup (Sordino exclu). Le Ménestrel EST un Barde (confirmé) :
	# il les reçoit aussi, pas seulement "Barde" au sens strict.
	if has_metier("Barde"):
		for s in BardeSpellCatalog.build_all():
			spells.append(s)

	# Sorts du MÉTIER Soldat (voir soldat_spell_catalog.gd) — accordés
	# d'un coup. Formation (passif) n'est PAS un sort : géré
	# directement dans HexGrid via CombatUnit.has_metier("Soldat").
	if has_metier("Soldat"):
		for s in SoldatSpellCatalog.build_all():
			spells.append(s)

	# Sorts du MÉTIER Berzerk (voir berzerk_spell_catalog.gd) — accordés
	# d'un coup. Rage/Enragé/Coûte que coûte (passifs) ne sont PAS des
	# sorts : gérés directement dans take_damage()/HexGrid.
	if has_metier("Berzerk"):
		for s in BerzerkSpellCatalog.build_all():
			spells.append(s)

	# Sorts du MÉTIER Gladiateur (voir gladiateur_spell_catalog.gd) —
	# accordés d'un coup. Gloire/Pour la gloire/Tenir bon (passifs) ne
	# sont PAS des sorts : gérés directement dans _ready()/
	# _recalculate_stats()/take_damage()/HexGrid.
	if has_metier("Gladiateur"):
		for s in GladiateurSpellCatalog.build_all():
			spells.append(s)

	# Sorts du MÉTIER Corsaire (voir corsaire_spell_catalog.gd) —
	# accordés d'un coup.
	if has_metier("Corsaire"):
		for s in CorsaireSpellCatalog.build_all():
			spells.append(s)

	# Sorts du MÉTIER Mage (75 sorts, voir mage_spell_catalog.gd). Ils n'étaient
	# accordés que par le gabarit "Mage" (UnitDatabase.build_spells) : un
	# personnage dont le MÉTIER est Mage — comme un aventurier de la Tour —
	# n'en avait aucun. Dédoublonnés par nom : l'unité construite d'après le
	# gabarit "Mage" ET portant le métier Mage (le personnage de l'exploration)
	# a déjà ces 75 sorts, ils ne doivent pas être comptés deux fois.
	if has_metier("Mage, Sorcier"):
		var known_spell_names: Dictionary = {}
		for existing_spell in spells:
			known_spell_names[existing_spell.spell_name] = true
		for mage_spell in MageSpellCatalog.build_for_level(level):
			if not known_spell_names.has(mage_spell.spell_name):
				spells.append(mage_spell)

	utility_action_slot = Spell.new()
	utility_action_slot.spell_name = "Action utilitaire"
	utility_action_slot.is_weapon_attack = false
	utility_action_slot.ea_cost = 0

	if sprite_sheet != null:
		_setup_sprite()

	queue_redraw()

# Construit un AnimatedSprite2D à partir de la feuille de sprites, en
# découpant des régions (AtlasTexture) directement dans la texture
# source — une passe par animation définie dans sprite_animations.
func _setup_sprite() -> void:
	var frames := SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")  # Animation vide créée par défaut par Godot, inutile ici.

	for anim_name in sprite_animations.keys():
		var config = sprite_animations[anim_name]
		var row = config.get("row", 0)
		var start_col = config.get("start_col", 0)
		var frame_count = config.get("frame_count", 1)
		var fps = config.get("fps", 6.0)
		var loop = config.get("loop", true)

		frames.add_animation(anim_name)
		frames.set_animation_loop(anim_name, loop)
		frames.set_animation_speed(anim_name, fps)

		for i in range(frame_count):
			var col = start_col + i
			var atlas := AtlasTexture.new()
			atlas.atlas = sprite_sheet
			atlas.region = Rect2(
				col * sprite_frame_size.x,
				row * sprite_frame_size.y,
				sprite_frame_size.x,
				sprite_frame_size.y
			)
			frames.add_frame(anim_name, atlas)

	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = frames
	_sprite.scale = Vector2(sprite_scale, sprite_scale)

	# AnimatedSprite2D centre son image sur sa position par défaut. On le
	# décale vers le haut de la moitié de sa hauteur pour que ce soit le
	# BAS du sprite (les pieds) qui touche le centre de l'hexagone, et non
	# son centre — sinon le personnage semble "enfoncé" dans la case.
	# sprite_y_offset permet ensuite un réglage fin manuel.
	var full_height = sprite_frame_size.y * sprite_scale
	_sprite.position = Vector2(0, -full_height * 0.5 + sprite_y_offset)

	_sprite.animation_finished.connect(_on_sprite_animation_finished)

	add_child(_sprite)
	play_animation("idle")

# Joue une animation par son nom logique ("idle", "walk", "attack"...).
# Essaie d'abord la variante directionnelle courante (ex: "idle_side"),
# et retombe sur le nom brut si elle n'existe pas (utile pour les
# animations sans variante par direction, comme "cast"). Ne fait rien
# silencieusement si aucune des deux n'existe pour cette classe.
func play_animation(anim_name: String) -> void:
	if _sprite == null or _sprite.sprite_frames == null:
		return

	var directional_name = anim_name + _current_facing_suffix
	if _sprite.sprite_frames.has_animation(directional_name):
		_sprite.animation = directional_name
		_sprite.play()
	elif _sprite.sprite_frames.has_animation(anim_name):
		_sprite.animation = anim_name
		_sprite.play()

# Les animations "one-shot" (attaque, touché...) reviennent
# automatiquement à l'idle une fois terminées. "death" ne revient pas :
# l'unité est retirée juste après (voir die()).
func _on_sprite_animation_finished() -> void:
	if _sprite.animation.begins_with("death"):
		return
	play_animation("idle")

# Détermine la direction à afficher parmi les 8 orientations dessinées
# dans la feuille de sprites (S, SE, E, NE, N, NW, O, SO), vers une
# position cible en coordonnées locales à HexGrid (le même repère que
# `position`). Chaque direction a sa propre ligne dans le spritesheet
# (pas de miroir nécessaire, contrairement à la version précédente).
func face_direction(target_local_pos: Vector2) -> void:
	if _sprite == null:
		return

	var delta = target_local_pos - position
	if delta.length_squared() < 0.01:
		return  # Cible ~sur soi : on ne change pas l'orientation actuelle.

	var angle_deg = rad_to_deg(atan2(delta.y, delta.x))  # 0° = est, 90° = sud (écran Godot), -90° = nord

	# Découpe le cercle en 8 secteurs de 45°, centrés sur chaque direction.
	var index = int(round(angle_deg / 45.0))
	index = ((index % 8) + 8) % 8

	var directions = ["e", "se", "s", "sw", "w", "nw", "n", "ne"]
	_current_facing_suffix = "_" + directions[index]
	_sprite.flip_h = false

# Vrai si `attacker_position` se trouve globalement DANS LE DOS de
# cette unité — c'est-à-dire à l'opposé de l'endroit qu'elle regarde
# actuellement (voir _current_facing_suffix, mis à jour par
# face_direction() à chaque action). Tolérance de ±3 crans sur 8
# (donc jusqu'à 135° de part et d'autre de l'opposé exact), pas
# seulement pile en face — voir Frappe des ombres (Ninja).
func is_attacked_from_behind(attacker_position: Vector2) -> bool:
	var directions = ["e", "se", "s", "sw", "w", "nw", "n", "ne"]
	var my_facing_index = directions.find(_current_facing_suffix.substr(1))
	if my_facing_index == -1:
		return false

	var delta = attacker_position - position
	if delta.length_squared() < 0.01:
		return false  # Attaquant ~sur soi : indéterminé, pas "dans le dos".

	var angle_deg = rad_to_deg(atan2(delta.y, delta.x))
	var attacker_index = ((int(round(angle_deg / 45.0)) % 8) + 8) % 8

	var diff = abs(my_facing_index - attacker_index)
	diff = min(diff, 8 - diff)  # Distance circulaire la plus courte.
	return diff >= 3

# Vrai si cette unité regarde globalement vers `pos` (même repère que position) :
# écart d'au plus 1 cran sur les 8 orientations (Disque de lumière).
func is_facing(pos: Vector2) -> bool:
	var directions = ["e", "se", "s", "sw", "w", "nw", "n", "ne"]
	var my_index = directions.find(_current_facing_suffix.substr(1))
	if my_index == -1:
		return true
	var delta = pos - position
	if delta.length_squared() < 0.01:
		return true
	var angle_deg = rad_to_deg(atan2(delta.y, delta.x))
	var idx = ((int(round(angle_deg / 45.0)) % 8) + 8) % 8
	var diff = abs(my_index - idx)
	diff = min(diff, 8 - diff)
	return diff <= 1

func _create_default_weapon() -> Weapon:
	var w := Weapon.new()
	w.weapon_name = "Poings"
	w.damage = 4  # Affichage seulement : les vrais dégâts sont 1D (dice_count).
	w.dice_count = 1
	w.dice_modifier = 0
	w.weapon_type = Weapon.WeaponType.MELEE
	w.min_range = 1
	w.max_range = 1
	return w

# Réinitialise les PM et le compteur d'actions — appelé par TurnManager
# au début du tour de cette unité. L'EA, elle, N'EST PAS réinitialisée
# ici : c'est une réserve unique pour tout le combat.
func reset_turn_resources() -> void:
	current_pm = max_pm
	actions_used_this_turn = 0
	all_actions_weapon_attacks_this_turn = true
	spells_used_this_turn.clear()
	dodge_available = true
	samurai_melee_attacks_this_turn = 0
	samurai_combo_disabled_defense = false

	# Voleur (esquive totale) : alterné à CHAQUE tour (pas juste quand
	# le métier est actif, pour que le cycle reste cohérent si le
	# métier change en cours de combat — improbable, mais sans risque).
	voleur_ad_malus_active = not voleur_ad_malus_active
	_recalculate_stats()

func set_defensive_stance(stance: int) -> void:
	defensive_stance = stance

# Renvoie le sort "emplacement" à utiliser pour le suivi économie
# d'action : si `spell` est une variante temporaire (ex: tir à l'arc
# avec une flèche spéciale), on doit compter contre son origin_spell,
# pas contre la variante elle-même (sinon on pourrait la réutiliser
# indéfiniment en changeant juste de flèche).
func _resolve_action_slot(spell: Spell) -> Spell:
	return spell.origin_spell if spell.origin_spell != null else spell

# Détermine si l'unité peut encore utiliser CE sort précis ce tour-ci.
# Règle : 1 action normale par tour, OU 2 attaques d'arme si l'unité a
# l'Ambidextrie (jamais les deux à la fois) — ET un même
# sort/arme/action ne peut jamais être utilisé(e) deux fois par tour.
func can_perform_action(spell: Spell) -> bool:
	var slot = _resolve_action_slot(spell)

	if spells_used_this_turn.has(slot):
		return false  # Déjà utilisé(e) ce tour-ci.

	var would_stay_all_weapon_attacks = all_actions_weapon_attacks_this_turn and slot.is_weapon_attack
	var max_allowed = 2 if (has_ambidextrie and would_stay_all_weapon_attacks) else 1
	return actions_used_this_turn < max_allowed

# Enregistre qu'un sort/une action vient d'être utilisé(e) : incrémente
# le compteur d'actions et marque l'emplacement correspondant comme
# indisponible pour le reste du tour.
func record_action_taken(spell: Spell) -> void:
	var slot = _resolve_action_slot(spell)
	actions_used_this_turn += 1
	all_actions_weapon_attacks_this_turn = all_actions_weapon_attacks_this_turn and slot.is_weapon_attack
	spells_used_this_turn.append(slot)

# Tente de consommer l'action utilitaire du tour (boire une potion,
# changer d'arme...). Renvoie false si l'action du tour est déjà prise.
func try_use_utility_action() -> bool:
	if not can_perform_action(utility_action_slot):
		return false
	record_action_taken(utility_action_slot)
	return true

# Boit une potion de l'inventaire : consomme l'action utilitaire du
# tour, applique l'effet (soin ou mana), puis retire la potion.
# Renvoie le gain RÉEL appliqué (peut être inférieur à potion.amount
# si déjà proche du plafond), ou -1 si l'action du tour n'est plus
# disponible (rien n'a été consommé dans ce cas).
func use_potion(potion: Potion) -> int:
	if not try_use_utility_action():
		return -1

	var actual_gain := 0

	if potion.potion_type == Potion.PotionType.HEAL:
		var before = current_hp
		take_damage(-potion.amount)  # Montant négatif = soin (voir take_damage).
		actual_gain = current_hp - before
	else:
		var before = current_ea
		current_ea = min(current_ea + potion.amount, max_ea)
		actual_gain = current_ea - before

	inventory_potions.erase(potion)
	return actual_gain

# Change l'arme principale équipée : consomme l'action utilitaire du
# tour, remet l'ancienne arme dans l'inventaire, retire son attaque de
# la liste de sorts et génère celle de la nouvelle arme. Renvoie false
# si l'action du tour n'est plus disponible.
func equip_weapon(new_weapon: Weapon) -> bool:
	if not can_equip_main_hand(new_weapon):
		return false
	if not try_use_utility_action():
		return false

	# Arme à 2 mains : la seconde arme retourne dans l'inventaire.
	if new_weapon.two_handed and off_hand_weapon != null:
		spells = spells.filter(func(s): return s.source_weapon != off_hand_weapon)
		inventory_weapons.append(off_hand_weapon)
		off_hand_weapon = null

	# Retire l'attaque générée par l'ancienne arme principale.
	spells = spells.filter(func(s): return s.source_weapon != equipped_weapon)

	if equipped_weapon != null:
		inventory_weapons.append(equipped_weapon)
	inventory_weapons.erase(new_weapon)

	equipped_weapon = new_weapon
	spells.insert(0, equipped_weapon.create_attack_spell())
	_recalculate_stats()
	return true

# Vrai si `new_weapon` peut aller en SECONDE main : Ambidextrie, ou Pirate avec
# une arme à feu ET une arme de corps à corps (même règle qu'à la création).
# Raison pour laquelle `new_weapon` ne peut pas aller en main principale
# ("" = possible) : une arme à 2 mains exige la seconde main vide.
func main_hand_block_reason(new_weapon: Weapon) -> String:
	if off_hand_weapon != null and off_hand_weapon.two_handed:
		return "La seconde arme est à 2 mains"
	return ""

func can_equip_main_hand(new_weapon: Weapon) -> bool:
	return main_hand_block_reason(new_weapon) == ""

# Raison pour laquelle `new_weapon` ne peut pas aller en seconde main.
func off_hand_block_reason(new_weapon: Weapon) -> String:
	if new_weapon.two_handed:
		return "Arme à 2 mains : ne se porte pas en seconde main"
	if equipped_weapon != null and equipped_weapon.two_handed:
		return "L'arme principale est à 2 mains"
	return ""

func can_equip_off_hand(new_weapon: Weapon) -> bool:
	if off_hand_block_reason(new_weapon) != "":
		return false
	if has_ambidextrie:
		return true
	if has_metier("Pirate") and equipped_weapon != null:
		var main_firearm: bool = equipped_weapon.weapon_name.begins_with("Pistolet")
		var new_firearm: bool = new_weapon.weapon_name.begins_with("Pistolet")
		return main_firearm != new_firearm
	return false

# Équipe `new_weapon` en seconde main (consomme l'action utilitaire du tour) :
# l'ancienne arme secondaire retourne dans l'inventaire et son attaque est remplacée.
func equip_off_hand_weapon(new_weapon: Weapon) -> bool:
	if not can_equip_off_hand(new_weapon):
		return false
	if not try_use_utility_action():
		return false
	if off_hand_weapon != null:
		spells = spells.filter(func(s): return s.source_weapon != off_hand_weapon)
		inventory_weapons.append(off_hand_weapon)
	inventory_weapons.erase(new_weapon)
	off_hand_weapon = new_weapon
	_recalculate_stats()  # Pirate : peut accorder l'Ambidextrie avec ce combo.
	if has_ambidextrie:
		spells.insert(min(1, spells.size()), off_hand_weapon.create_attack_spell())
	return true

# Change l'armure équipée (une seule à la fois). Comme equip_weapon,
# consomme l'action utilitaire du tour. Renvoie false si l'action du
# tour n'est plus disponible.
func equip_armor(new_armor: Armor) -> bool:
	if not try_use_utility_action():
		return false

	equipped_armor = new_armor
	_recalculate_stats()
	return true

# Assigne la race — PAS de coût d'action utilitaire, contrairement à
# equip_weapon/equip_armor : la race se choisit hors combat (à la
# création du personnage), pas comme un changement d'équipement
# tactique en pleine bataille.
func equip_race(new_race: Race) -> void:
	equipped_race = new_race
	_recalculate_stats()

# Ajoute un accessoire équipé (plusieurs possibles simultanément — pas
# de remplacement automatique, contrairement à l'arme/l'armure).
# Consomme l'action utilitaire du tour.
func equip_accessory(accessory: Accessory) -> bool:
	if not try_use_utility_action():
		return false

	equipped_accessories.append(accessory)
	_recalculate_stats()
	return true

func unequip_accessory(accessory: Accessory) -> bool:
	if not try_use_utility_action():
		return false

	equipped_accessories.erase(accessory)
	_recalculate_stats()
	return true

func _draw() -> void:
	# Une invocation peut avoir sa propre couleur de repli (voir
	# Spell.summon_color) plutôt que la couleur d'équipe générique —
	# alpha à 0 (défaut) = pas de personnalisation, comportement normal.
	var color = custom_fallback_color if custom_fallback_color.a > 0 else (player_color if team == Team.PLAYER else enemy_color)
	var name_y_offset: float

	var token := TokenDatabase.texture_for(self)
	if _sprite != null:
		_sprite.visible = token == null
	if token != null:
		# Token (médaillon) à la place du sprite : anneau de la couleur de
		# l'équipe pour distinguer alliés et ennemis.
		draw_texture_rect(token, Rect2(-TOKEN_RADIUS, -TOKEN_RADIUS, TOKEN_RADIUS * 2, TOKEN_RADIUS * 2), false)
		draw_arc(Vector2.ZERO, TOKEN_RADIUS, 0, TAU, 48, color, 3.0, true)
		name_y_offset = -TOKEN_RADIUS - 6
		if highlighted:
			draw_circle(Vector2.ZERO, TOKEN_RADIUS + 5, Color(1, 0.9, 0.5, 0.22))
			draw_arc(Vector2.ZERO, TOKEN_RADIUS + 5, 0, TAU, 48, Color(1, 0.9, 0.5), 4.0, true)
	elif sprite_sheet != null:
		# Le vrai sprite (enfant AnimatedSprite2D) s'affiche par-dessus.
		# sprite_y_offset corrige une éventuelle marge interne/transparente
		# de la feuille de sprites pour que les pieds VISIBLES tombent au
		# centre de l'hexagone (y=0) — le socle reste donc fixe ici, il ne
		# doit PAS suivre ce réglage (sinon il se désynchronise des pieds
		# une fois la marge compensée).
		var full_height = sprite_frame_size.y * sprite_scale
		draw_arc(Vector2(0, 3), full_height * 0.12, 0, TAU, 24, color, 3.0, true)
		name_y_offset = sprite_y_offset - full_height - 8
	else:
		# Fallback : disque de couleur plein (pas encore de sprite pour
		# cette classe).
		draw_circle(Vector2.ZERO, radius, color)
		draw_arc(Vector2.ZERO, radius, 0, TAU, 32, Color.BLACK, 2.0, true)
		name_y_offset = -radius - 8

	if highlighted and token == null:
		draw_arc(Vector2.ZERO, radius + 6, 0, TAU, 32, Color(1, 0.9, 0.5), 4.0, true)

	# Nom de l'unité affiché au-dessus.
	var label_width: float = 110.0 if token != null else radius * 2
	var font = ThemeDB.fallback_font
	draw_string(
		font,
		Vector2(-label_width * 0.5, name_y_offset),
		unit_name,
		HORIZONTAL_ALIGNMENT_CENTER,
		label_width,
		14,
		Color.WHITE
	)

# Déplace l'unité vers une nouvelle position pixel (appelé par HexGrid).
# Glisse en douceur (au lieu d'un téléport instantané) et joue
# l'animation de marche pendant le trajet si elle existe pour cette
# classe ; revient à l'idle une fois arrivé.
func move_to_pixel(pixel_pos: Vector2) -> void:
	face_direction(pixel_pos)
	play_animation("walk")

	var tween = create_tween()
	tween.tween_property(self, "position", pixel_pos, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.finished.connect(func(): play_animation("idle"))

# Nom de la ressource des sorts « normaux » : PA pour le Prêtre, EA sinon
# (le Berzerk dépense de la Rage, le Gladiateur de la Gloire — voir
# get_resource_summary).
func get_resource_name() -> String:
	return "EA"

# Ressources affichées pour cette unité (fiche personnage, bandeau de tour).
func get_resource_summary(compact: bool = false) -> String:
	var parts: Array = []
	var special := false
	if has_metier("Berzerk"):
		parts.append("Rage : %d" % rage)
		special = true
	if has_metier("Gladiateur"):
		parts.append("Gloire : %d" % gloire)
		special = true
	if not special or max_ea > 0:
		if compact:
			parts.append("%s : %d" % [get_resource_name(), current_ea])
		else:
			parts.append("%s : %d / %d" % [get_resource_name(), current_ea, max_ea])
	return " | ".join(parts)

# Codes des compétences (race + métiers), sans le « * » final.
func get_skill_codes() -> Array:
	var codes: Array = []
	for raw in _all_skill_sources():
		var code: String = str(raw).rstrip("*")
		if code != "" and not codes.has(code):
			codes.append(code)
	return codes

# Coup décisif : réservé aux Chasseurs de primes et de monstres.
func can_coup_decisif() -> bool:
	return has_metier("Chasseur de primes") or has_metier("Chasseur de monstres")

# Un pour tous : la prochaine « charge » de dégâts va au gladiateur protecteur.
func _redirect_damage(amount: int, is_critical_hit: bool) -> bool:
	var src = redirect_source
	if redirect_charges <= 0 or src == null or not is_instance_valid(src) or src.current_hp <= 0:
		_clear_redirect()
		return false
	redirect_charges -= 1
	print("%s encaisse à la place de %s (Un pour tous)." % [src.unit_name, unit_name])
	if redirect_charges <= 0:
		_clear_redirect()
	src.take_damage(amount, is_critical_hit)
	return true

func _clear_redirect() -> void:
	var src = redirect_source
	var eff = redirect_effect
	redirect_source = null
	redirect_charges = 0
	redirect_effect = null
	if src != null and is_instance_valid(src) and eff != null:
		src.remove_status_effect(eff)

func take_damage(amount: int, is_critical_hit: bool = false) -> void:
	if amount > 0 and redirect_charges > 0 and _redirect_damage(amount, is_critical_hit):
		return

	# Immunité totale (Intangibilité, Cryogénisation...) : ignore TOUT
	# dégât entrant, mais les soins (amount <= 0) passent toujours —
	# rien dans les sorts concernés ne dit qu'on ne peut plus être soigné.
	if is_invulnerable and amount > 0:
		return

	# Bouclier de Foi (Templier) : absorbe les dégâts avant qu'ils
	# n'atteignent les PV. Un critique le détruit NET, peu importe sa
	# réserve restante — les dégâts du critique passent alors en entier
	# (pas d'absorption partielle sur un critique, voir la donnée d'origine).
	if amount > 0 and shield_power > 0:
		if is_critical_hit:
			shield_power = 0
		else:
			var absorbed = min(amount, shield_power)
			shield_power -= absorbed
			amount -= absorbed
			if amount <= 0:
				return  # Totalement absorbé, rien n'atteint les PV.

	# Rage (Berzerk) : +1 par point de dégâts RÉELLEMENT subi (après
	# l'absorption du bouclier ci-dessus, s'il y en avait un).
	if amount > 0 and equipped_metier != null and has_metier("Berzerk"):
		rage += amount

	var was_alive = current_hp > 0

	# Un montant négatif (ex: sort de soin) augmente les PV au lieu de
	# les diminuer — clampé pour ne jamais dépasser max_hp ni descendre
	# sous 0.
	current_hp = clamp(current_hp - amount, 0, max_hp)

	# Tenir bon (Gladiateur) : recalcule tout de suite après avoir
	# encaissé, pour que le bonus d'Armure sous 33% PV soit à jour dès
	# la prochaine attaque (pas seulement au prochain tour).
	if amount > 0 and has_metier("Gladiateur"):
		_recalculate_stats()

	if amount > 0 and was_alive:
		if current_hp == 0:
			die()
		else:
			play_animation("hurt")
	# amount <= 0 (soin) : pas d'animation de touché.

func die() -> void:
	died.emit(self)

	# Si une animation de mort existe pour cette classe, on la joue et on
	# attend qu'elle se termine avant de retirer l'unité de la scène —
	# elle est déjà retirée du combat (signal "died" traité par HexGrid),
	# seul son cadavre reste visible brièvement pour l'effet.
	if _sprite != null and _sprite.sprite_frames != null and _sprite.sprite_frames.has_animation("death"):
		play_animation("death")
		var frame_count = _sprite.sprite_frames.get_frame_count("death")
		var fps = _sprite.sprite_frames.get_animation_speed("death")
		var duration = float(frame_count) / fps if fps > 0 else 0.5
		await get_tree().create_timer(duration).timeout

	if keep_corpse:
		# Cadavre conservé pour une éventuelle résurrection (voir HexGrid).
		visible = false
		if get_parent() != null:
			get_parent().remove_child(self)
		return

	queue_free()
