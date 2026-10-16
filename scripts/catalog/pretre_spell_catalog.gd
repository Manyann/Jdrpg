extends RefCounted
class_name PretreSpellCatalog

# ============================================================
# pretre_spell_catalog.gd
# Sorts du MÉTIER Prêtre, répartis en 3 "Ordres" — Harmonie / Néant /
# Cycle éternel (PAS liés à l'arbre Moine/Paladin/Templier de
# metier_database.gd, un axe de spécialisation différent et
# orthogonal). Un Prêtre n'appartient qu'à UN SEUL Ordre à la fois
# (voir CombatUnit.pretre_order) et ne reçoit QUE les sorts de cet
# Ordre (voir build_for_order), débloqués par alignement selon son niveau
# (niveaux 1, 4 et 7).
#
# "PA" traité comme l'EA déjà utilisée partout (même choix que pour
# Elfe Sylvain) — SAUF les quelques sorts "X PA" à coût variable, qui
# réutilisent le système de Walkyrie (is_pa_cost_spell, déduit de
# current_ea au lieu de current_hp).
# "niveau" dans les formules = CombatUnit.level (niveau du PERSONNAGE,
# confirmé) — voir Spell.includes_caster_level/level_multiplier.
# "PH"/"PS" = Spell.SpellType.PHYSICAL/PSYCHIC.
# "DI : N" = cast_delay (délai d'incantation, système déjà existant).
# "DS : X" = la durée de l'effet appliqué égale X, le PA dépensé (voir
# Spell.duration_equals_x) — SAUF Noirceur, où "DS : X" fixe la durée
# de la NUIT elle-même (voir Spell.installs_night / HexGrid.is_night),
# pas un effet de statut classique.
#
# NUIT : vraie mécanique de champ de bataille (pas une simplification
# "permanente") — voir Noirceur ci-dessous, qui l'installe pour X tours
# (décomptés une fois par round, pas par tour individuel). Pendant ce
# temps, tout Prêtre de l'ORDRE DU NÉANT SPÉCIFIQUEMENT déjà sur le
# champ (les deux camps — mais PAS les Prêtres Harmonie/Cycle éternel)
# gagne automatiquement Être nocturne (+niveau/2 Armure) et Maître de
# la nuit (+15 PV, +2 AT/PRD) — voir HexGrid._install_night/_end_night,
# qui vérifie CombatUnit.pretre_order. Ces 2 passifs n'ont donc PAS
# leur propre entrée dans build_for_order() : ils ne sont jamais
# lancés comme un sort, juste appliqués/retirés par HexGrid.
#
# SIMPLIFICATIONS ASSUMÉES (pas de système correspondant chez nous) :
# - Disque de lumière : ne touche que les ennemis tournés vers le lanceur
#   (CombatUnit.is_facing, tolérance d'un cran sur 8 orientations). Zone de
#   jugement a été retirée du catalogue.
# - Croissant de lune : le transfert de PV va toujours au LANCEUR (la
#   donnée d'origine laisse le choix "allié ou soi-même").
# - Le mana devient de la vie : le PA dépensé est retiré au LANCEUR,
#   pas à la cible (évite un second ciblage pour désigner qui paie).
# - Invoque la balance de l'univers : un lancer sur deux soigne le camp du
#   lanceur, l'autre inflige les dégâts à l'adversaire (le 1er soigne).
# - Scalpel : coût (2 × niveau) - 1 PA et 1D6 de dégâts par niveau.
# - Invoque un faucheur : invocation classique (stats approximées) —
#   sans sa condition de victoire spéciale ("meurt après 3 coups, XP
#   perdu") ni son "inattaquable", trop spécifiques pour être automatisés.
# - Attrape lumière : le cumul "3 fois" fonctionne tout seul (chaque
#   lancer ajoute un nouvel exemplaire à active_effects, pas de fusion).
#
# NON IMPLÉMENTÉS (affichés, sans effet — voir is_unimplemented) :
# - (Plan parallèle est désormais implémenté : voir HexGrid.can_interact.)
# - L'équilibre du cycle : résurrection — même limite que Grâce du
#   ciel (Walkyrie) et Renforcement d'armes (Mage), voir
#   Spell.is_walkyrie_resurrection pour le détail.
# ============================================================

static func _build_baiser_de_chaleur() -> Spell:
	var s := Spell.new()
	s.spell_name = "Baiser de chaleur"
	s.target_mode = Spell.TargetMode.SINGLE_ALLY
	s.is_heal = true
	s.ea_cost = 2
	s.spell_type = Spell.SpellType.PSYCHIC
	s.dice_terms = [{"count": 1, "sides": 6, "modifier": 0}]
	s.includes_caster_level = true
	s.min_range = 1
	s.max_range = 6
	return s

static func _build_bronzage() -> Spell:
	var buff := StatusEffect.new()
	buff.effect_name = "Bronzage (+1 Courage, +1 Charisme, +1 Force)"
	buff.duration_remaining = -1
	buff.bonus_courage = 1
	buff.bonus_charisme = 1
	buff.bonus_force = 1

	var s := Spell.new()
	s.spell_name = "Bronzage"
	s.target_mode = Spell.TargetMode.GROUP
	s.ea_cost = 4
	s.spell_type = Spell.SpellType.PSYCHIC
	s.effect_to_apply = buff
	return s

static func _build_brulure() -> Spell:
	var s := Spell.new()
	s.spell_name = "Brûlure"
	s.target_mode = Spell.TargetMode.SINGLE_ENEMY
	s.ea_cost = 2
	s.spell_type = Spell.SpellType.PHYSICAL
	s.dice_terms = [{"count": 1, "sides": 6, "modifier": 4}]
	s.includes_caster_level = true
	s.min_range = 1
	s.max_range = 6
	return s

static func _build_lumiere_apaisante() -> Spell:
	var s := Spell.new()
	s.spell_name = "Lumière apaisante"
	s.target_mode = Spell.TargetMode.GROUP
	s.is_heal = true
	s.ea_cost = 5
	s.spell_type = Spell.SpellType.PSYCHIC
	s.dice_terms = [{"count": 1, "sides": 6, "modifier": 2}]
	s.includes_caster_level = true
	return s

static func _build_disque_de_lumiere() -> Spell:
	var s := Spell.new()
	s.spell_name = "Disque de lumière"
	s.target_mode = Spell.TargetMode.ALL_ENEMIES
	s.requires_facing_caster = true  # « Tous [les ennemis] faisant face à la source ».
	s.ea_cost = 6
	s.spell_type = Spell.SpellType.PHYSICAL
	s.level_multiplier = 3
	return s

static func _build_etre_de_lumiere() -> Spell:
	var immunity := StatusEffect.new()
	immunity.effect_name = "Être de lumière (insensible à la magie)"
	immunity.bonus_armure_magique = 99  # Approximation d'une immunité totale (pas de champ "immunité" dédié).

	var s := Spell.new()
	s.spell_name = "Être de lumière"
	s.target_mode = Spell.TargetMode.SINGLE_ALLY
	s.is_pa_cost_spell = true
	s.ev_cost_min = 2
	s.ev_cost_max = 20
	s.ev_x_divisor = 1
	s.ev_x_flat_bonus = -1  # DS : X-1.
	s.duration_equals_x = true
	s.spell_type = Spell.SpellType.PSYCHIC
	s.effect_to_apply = immunity
	s.min_range = 1
	s.max_range = 6
	return s

static func _build_equilibre_parfait() -> Spell:
	var s := Spell.new()
	s.spell_name = "Équilibre parfait"
	s.target_mode = Spell.TargetMode.BATTLEFIELD
	s.resets_all_hp = true
	s.ea_cost = 8
	s.spell_type = Spell.SpellType.PSYCHIC
	return s

static func _build_alternative() -> Spell:
	var s := Spell.new()
	s.spell_name = "Alternative"
	s.target_mode = Spell.TargetMode.SINGLE_ENEMY
	s.ea_cost = 7
	s.spell_type = Spell.SpellType.PHYSICAL
	s.dice_terms = [{"count": 3, "sides": 6, "modifier": 3}]
	s.includes_caster_level = true
	s.min_range = 1
	s.max_range = 6
	return s

static func _build_croissant_de_lune() -> Spell:
	var s := Spell.new()
	s.spell_name = "Croissant de lune"
	s.target_mode = Spell.TargetMode.SINGLE_ENEMY
	s.ea_cost = 3
	s.spell_type = Spell.SpellType.PHYSICAL
	s.dice_terms = [{"count": 0, "sides": 6, "modifier": 3}]
	s.includes_caster_level = true
	s.ignores_armor = true  # "Dégâts bruts".
	s.transfers_damage_to_ally = true
	s.min_range = 1
	s.max_range = 6
	return s

static func _build_pleine_lune() -> Spell:
	var s := Spell.new()
	s.spell_name = "Pleine lune"
	s.target_mode = Spell.TargetMode.SINGLE_ENEMY
	s.ea_cost = 2
	s.spell_type = Spell.SpellType.PHYSICAL
	s.dice_terms = [{"count": 1, "sides": 6, "modifier": 3}]
	s.includes_caster_level = true
	s.min_range = 1
	s.max_range = 6
	return s

static func _build_noirceur() -> Spell:
	var s := Spell.new()
	s.spell_name = "Noirceur"
	s.target_mode = Spell.TargetMode.SELF
	s.is_pa_cost_spell = true
	s.ev_cost_min = 1
	s.ev_cost_max = 20
	s.ev_extra_flat_cost = 2  # "X + 2 PA" : le +2 est un coût fixe, en plus du X variable.
	s.installs_night = true  # DS : X — la nuit dure X tours (voir HexGrid._install_night).
	s.spell_type = Spell.SpellType.PSYCHIC
	return s

static func _build_attrape_lumiere() -> Spell:
	var debuff := StatusEffect.new()
	debuff.effect_name = "Attrape lumière (-1 Courage, -1 Force)"
	debuff.duration_remaining = -1
	debuff.bonus_courage = -1
	debuff.bonus_force = -1

	var s := Spell.new()
	s.spell_name = "Attrape lumière"
	s.target_mode = Spell.TargetMode.SINGLE_ENEMY
	s.ea_cost = 4
	s.spell_type = Spell.SpellType.PSYCHIC
	s.dice_terms = [{"count": 2, "sides": 6, "modifier": 3}]
	s.effect_to_apply = debuff  # Cumulable : chaque lancer ajoute un nouvel exemplaire, jusqu'à 3 fois dans les données d'origine.
	s.min_range = 1
	s.max_range = 6
	return s

static func _build_frappe_du_neant() -> Spell:
	var s := Spell.new()
	s.spell_name = "Frappe du néant"
	s.target_mode = Spell.TargetMode.ALL_ENEMIES
	s.is_pa_cost_spell = true
	s.ev_cost_min = 1
	s.ev_cost_max = 20
	s.ev_x_divisor = 1
	s.ev_x_multiplier = 3  # "3X dégâts".
	s.spell_type = Spell.SpellType.PSYCHIC
	return s

static func _build_aspiration_du_neant() -> Spell:
	var buff := StatusEffect.new()
	buff.effect_name = "Aspiration du néant (+1 à toutes les caractéristiques)"
	buff.duration_remaining = -1
	buff.bonus_courage = 1
	buff.bonus_intelligence = 1
	buff.bonus_charisme = 1
	buff.bonus_adresse = 1
	buff.bonus_force = 1
	buff.bonus_chance = 1

	var s := Spell.new()
	s.spell_name = "Aspiration du néant"
	s.target_mode = Spell.TargetMode.SINGLE_ENEMY
	s.ea_cost = 6
	s.cast_delay = 1  # DI : 1.
	s.spell_type = Spell.SpellType.PSYCHIC
	s.effect_to_apply = buff
	s.min_range = 1
	s.max_range = 6
	return s

static func _build_plan_parallele() -> Spell:
	var s := Spell.new()
	s.spell_name = "Plan parallèle"
	s.target_mode = Spell.TargetMode.SINGLE_ENEMY  # Sans effet : le ciblage à 2 clics est géré par is_parallel_plane.
	s.is_parallel_plane = true
	s.parallel_plane_turns = 5
	s.spell_type = Spell.SpellType.PSYCHIC
	s.info_text = "Choisis deux unités : pendant 5 tours, elles ne se voient et n'interagissent qu'entre elles."
	s.ea_cost = 5
	s.min_range = 1
	s.max_range = 6  # Portée non précisée dans les données d'origine.
	return s

static func _build_soin() -> Spell:
	var s := Spell.new()
	s.spell_name = "Soin"
	s.target_mode = Spell.TargetMode.SINGLE_ALLY
	s.is_heal = true
	s.ea_cost = 2
	s.spell_type = Spell.SpellType.PSYCHIC
	s.dice_terms = [{"count": 0, "sides": 6, "modifier": 5}]
	s.includes_caster_level = true
	s.min_range = 1
	s.max_range = 6
	return s

static func _build_soin_de_groupe() -> Spell:
	var s := Spell.new()
	s.spell_name = "Soin de groupe"
	s.target_mode = Spell.TargetMode.GROUP
	s.is_heal = true
	s.ea_cost = 3
	s.spell_type = Spell.SpellType.PSYCHIC
	s.dice_terms = [{"count": 0, "sides": 6, "modifier": 3}]
	s.includes_caster_level = true
	return s

static func _build_scalpel() -> Spell:
	var s := Spell.new()
	s.spell_name = "Scalpel"
	s.target_mode = Spell.TargetMode.SINGLE_ENEMY
	s.ea_cost = 3  # Valeur d'affichage de base ; le vrai coût est (2 × niveau) - 1 (voir ea_cost_scales_with_level).
	s.ea_cost_scales_with_level = true
	s.spell_type = Spell.SpellType.PSYCHIC
	s.dice_terms = [{"count": 1, "sides": 6, "modifier": 0}]
	s.dice_count_equals_level = true
	s.min_range = 1
	s.max_range = 6
	return s

static func _build_infection() -> Spell:
	var s := Spell.new()
	s.spell_name = "Infection"
	s.target_mode = Spell.TargetMode.SINGLE_ENEMY
	s.ea_cost = 1
	s.spell_type = Spell.SpellType.PSYCHIC
	s.applies_infection = true
	s.unavoidable = true
	s.min_range = 1
	s.max_range = 6
	return s

static func _build_necrose() -> Spell:
	var s := Spell.new()
	s.spell_name = "Nécrose"
	s.target_mode = Spell.TargetMode.SINGLE_ENEMY
	s.ea_cost = 2
	s.spell_type = Spell.SpellType.PSYCHIC
	s.triggers_infections = true
	s.min_range = 1
	s.max_range = 6
	return s

static func _build_invoque_un_faucheur() -> Spell:
	var s := Spell.new()
	s.spell_name = "Invoque un faucheur"
	s.is_summon = true
	s.summon_name = "Faucheur"
	s.summon_max_hp = 20
	s.summon_attack_parade = 10
	s.summon_armor = 0
	s.summon_dice_count = 1
	s.summon_dice_modifier = 5
	s.summon_color = Color(0.25, 0.15, 0.3)
	s.ea_cost = 10
	s.spell_type = Spell.SpellType.PHYSICAL
	s.min_range = 1
	s.max_range = 6
	return s

static func _build_mana_devient_vie() -> Spell:
	var s := Spell.new()
	s.spell_name = "Le mana devient de la vie"
	s.target_mode = Spell.TargetMode.SINGLE_ALLY
	s.is_pa_cost_spell = true
	s.ev_cost_min = 1
	s.ev_cost_max = 20
	s.mana_to_life_ratio = 3
	s.spell_type = Spell.SpellType.PHYSICAL
	s.min_range = 1
	s.max_range = 6
	return s

static func _build_balance_univers() -> Spell:
	var s := Spell.new()
	s.spell_name = "Invoque la balance de l'univers"
	s.target_mode = Spell.TargetMode.BATTLEFIELD
	s.alternates_heal_damage = true
	s.ea_cost = 7
	s.spell_type = Spell.SpellType.PSYCHIC
	s.dice_terms = [{"count": 3, "sides": 6, "modifier": 0}]
	return s

static func _build_equilibre_du_cycle() -> Spell:
	var s := Spell.new()
	s.spell_name = "L'équilibre du cycle"
	s.target_mode = Spell.TargetMode.SINGLE_ALLY
	s.is_pretre_resurrection = true
	s.info_text = "Ressuscite un allié (au choix) et un ennemi mort au hasard, à la moitié de leurs PV max."
	s.ea_cost = 4
	return s

## Ordre de l'harmonie (soleil/lumière/harmonie) — 9 sorts.
static func _build_harmonie() -> Array:
	return [
		_build_baiser_de_chaleur(), _build_bronzage(), _build_brulure(),
		_build_lumiere_apaisante(), _build_disque_de_lumiere(), _build_etre_de_lumiere(),
		_build_equilibre_parfait(), _build_alternative(),
	]

## Ordre du néant (lune/nuit/néant) — 7 sorts (sans compter Être
## nocturne/Maître de la nuit, qui ne sont pas des sorts cette liste —
## voir HexGrid._install_night).
static func _build_neant() -> Array:
	return [
		_build_croissant_de_lune(), _build_pleine_lune(), _build_noirceur(),
		_build_attrape_lumiere(), _build_frappe_du_neant(), _build_aspiration_du_neant(),
		_build_plan_parallele(),
	]

## Ordre du cycle éternel (vie/mort/cycle) — 9 sorts.
static func _build_cycle_eternel() -> Array:
	return [
		_build_soin(), _build_soin_de_groupe(), _build_scalpel(),
		_build_infection(), _build_necrose(), _build_invoque_un_faucheur(),
		_build_mana_devient_vie(), _build_balance_univers(), _build_equilibre_du_cycle(),
	]

# Alignements d'un Ordre (3 par Ordre, dans l'ordre de déblocage) :
# - Harmonie : soleil -> lumière -> harmonie
# - Néant    : lune -> nuit -> néant
# - Cycle    : vie -> mort -> cycle
# Niveau 1-3 : sorts du 1er alignement ; à partir du niveau 4 : ceux du 2e ;
# à partir du niveau 7 : ceux du 3e (mêmes paliers que les métiers).
const TIER_UNLOCK_LEVELS: Array = [1, 4, 7]

const SPELL_TIERS: Dictionary = {
	"Baiser de chaleur": 0, "Bronzage": 0, "Brûlure": 0,
	"Lumière apaisante": 1, "Disque de lumière": 1, "Être de lumière": 1,
	"Équilibre parfait": 2, "Alternative": 2,
	"Croissant de lune": 0, "Pleine lune": 0,
	"Noirceur": 1, "Attrape lumière": 1,
	"Frappe du néant": 2, "Aspiration du néant": 2, "Plan parallèle": 2,
	"Soin": 0, "Soin de groupe": 0, "Scalpel": 0,
	"Infection": 1, "Nécrose": 1, "Invoque un faucheur": 1,
	"Le mana devient de la vie": 2, "Invoque la balance de l'univers": 2, "L'équilibre du cycle": 2,
}

# Niveau minimum pour débloquer l'alignement `tier` (0, 1 ou 2).
static func tier_unlock_level(tier: int) -> int:
	return int(TIER_UNLOCK_LEVELS[clamp(tier, 0, TIER_UNLOCK_LEVELS.size() - 1)])

# Construit la liste de sorts pour UN SEUL Ordre (voir
# CombatUnit.pretre_order) — un Prêtre n'a accès qu'aux sorts de
# l'Ordre qu'il a choisi, et seulement ceux des alignements débloqués
# par son `level` (voir TIER_UNLOCK_LEVELS). Tableau vide si `order` ne
# correspond à aucun des 3 (ex: Prêtre sans Ordre choisi).
static func build_for_order(order: String, level: int = 10) -> Array:
	var all_spells: Array = []
	match order:
		"Ordre de l'harmonie":
			all_spells = _build_harmonie()
		"Ordre du néant":
			all_spells = _build_neant()
		"Ordre du cycle éternel":
			all_spells = _build_cycle_eternel()
	var spells: Array = []
	for spell in all_spells:
		var tier: int = int(SPELL_TIERS.get(spell.spell_name, 0))
		if level < tier_unlock_level(tier):
			continue
		spell.icon_path = PretreSpellIcons.path_for(spell.spell_name)
		spells.append(spell)
	return spells
