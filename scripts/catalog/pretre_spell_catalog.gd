extends RefCounted
class_name PretreSpellCatalog

# ============================================================
# pretre_spell_catalog.gd
# Sorts du MÉTIER Prêtre, répartis en 3 "Ordres" — Harmonie / Néant /
# Cycle éternel (PAS liés à l'arbre Moine/Paladin/Templier de
# metier_database.gd, un axe de spécialisation différent et
# orthogonal). Un Prêtre n'appartient qu'à UN SEUL Ordre à la fois
# (voir CombatUnit.pretre_order) et ne reçoit QUE les sorts de cet
# Ordre (voir build_for_order) — pas les 25 d'un coup.
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
# - Disque de lumière / Zone de jugement ("tous faisant face à la
#   lumière" / "X+1 Ennemis") : approximés en ALL_ENEMIES (ciblage
#   directionnel et comptage variable non supportés).
# - Croissant de lune : le transfert de PV va toujours au LANCEUR (la
#   donnée d'origine laisse le choix "allié ou soi-même").
# - Le mana devient de la vie : le PA dépensé est retiré au LANCEUR,
#   pas à la cible (évite un second ciblage pour désigner qui paie).
# - Invoque la balance de l'univers : soigne ET inflige à CHAQUE
#   lancer, plutôt que d'alterner d'un lancer à l'autre (pas d'état
#   persistant entre plusieurs lancers chez nous).
# - Scalpel : coût fixé à 3 PA (la formule "(2×niveau)-1 PA" dépend du
#   niveau, qu'on ne peut pas lire au moment de calculer le coût d'un
#   sort chez nous).
# - Invoque un faucheur : invocation classique (stats approximées) —
#   sans sa condition de victoire spéciale ("meurt après 3 coups, XP
#   perdu") ni son "inattaquable", trop spécifiques pour être automatisés.
# - Attrape lumière : le cumul "3 fois" fonctionne tout seul (chaque
#   lancer ajoute un nouvel exemplaire à active_effects, pas de fusion).
#
# NON IMPLÉMENTÉS (affichés, sans effet — voir is_unimplemented) :
# - Plan parallèle : isolation à deux cibles dans un "néant" à part —
#   aucune mécanique de ce genre chez nous.
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
	s.target_mode = Spell.TargetMode.ALL_ENEMIES  # Approximation : "tous faisant face à la source" (ciblage directionnel non supporté).
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

static func _build_zone_de_jugement() -> Spell:
	var s := Spell.new()
	s.spell_name = "Zone de jugement"
	s.target_mode = Spell.TargetMode.ALL_ENEMIES  # Approximation : "X+1 Ennemis" (comptage variable non supporté).
	s.ea_cost = 9  # Coût de base ; la part "+X" (qui règle aussi le nombre de cibles) n'est pas modélisée.
	s.spell_type = Spell.SpellType.PSYCHIC
	s.dice_terms = [{"count": 3, "sides": 6, "modifier": 3}]
	s.includes_caster_level = true
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
	s.target_mode = Spell.TargetMode.SINGLE_ENEMY
	s.is_unimplemented = true
	s.info_text = "Deux cibles se retrouvent seules dans le néant pendant 5 tours. PAS IMPLÉMENTÉ (pas de mécanique d'isolement à deux chez nous)."
	s.ea_cost = 5
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
	s.ea_cost = 3  # Coût fixe approché — la formule d'origine "(2*niveau)-1" dépend du niveau (voir note en tête de fichier).
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
	s.is_unimplemented = true
	s.info_text = "Ressuscite un allié et un ennemi aléatoire. PAS IMPLÉMENTÉ (pas de système de résurrection chez nous — voir Grâce du ciel, Walkyrie)."
	s.ea_cost = 4
	return s

## Ordre de l'harmonie (soleil/lumière/harmonie) — 9 sorts.
static func _build_harmonie() -> Array:
	return [
		_build_baiser_de_chaleur(), _build_bronzage(), _build_brulure(),
		_build_lumiere_apaisante(), _build_disque_de_lumiere(), _build_etre_de_lumiere(),
		_build_equilibre_parfait(), _build_alternative(), _build_zone_de_jugement(),
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

# Construit la liste de sorts pour UN SEUL Ordre (voir
# CombatUnit.pretre_order) — un Prêtre n'a accès qu'aux sorts de
# l'Ordre qu'il a choisi, pas aux 25 d'un coup. Tableau vide si
# `order` ne correspond à aucun des 3 (ex: Prêtre sans Ordre choisi).
static func build_for_order(order: String) -> Array:
	var spells: Array = []
	match order:
		"Ordre de l'harmonie":
			spells = _build_harmonie()
		"Ordre du néant":
			spells = _build_neant()
		"Ordre du cycle éternel":
			spells = _build_cycle_eternel()
	for spell in spells:
		spell.icon_path = PretreSpellIcons.path_for(spell.spell_name)
	return spells
