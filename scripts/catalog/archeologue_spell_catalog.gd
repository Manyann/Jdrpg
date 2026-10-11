extends RefCounted
class_name ArcheologueSpellCatalog

# ============================================================
# archeologue_spell_catalog.gd
# Sorts du MÉTIER Archéologue (sous-métier de Rôdeur, voir
# metier_database.gd) — accordés d'un coup, pas de palier.
#
# "Magie Phy"/"Magie Psy" = Spell.SpellType.PHYSICAL/PSYCHIC. "Chance"
# = Spell.SpellType.CHANCE (nouveau — jet contre chance_stat SEUL, pas
# de moyenne, voir sa doc dans spell.gd).
# "Dégâts bruts" = Spell.ignores_armor.
# "Durée : Combat" = permanent pour le reste du combat (duration=-1),
# même convention que le Mage.
# "Contrat de Damoclès" : "Pareil que le sort Épée de Damocles du
# mage" — on reprend EXACTEMENT sa mécanique (voir
# mage_spell_catalog.gd : 1/3 de chance par tour que la cible subisse
# 4D+2 bruts et que l'effet disparaisse, sinon +1D de dégât potentiel
# pour la tentative suivante), juste reconditionné en sort Chance
# plutôt que Physique/élémentaire.
# ============================================================

static func _build_griffe_spectrale() -> Spell:
	var s := Spell.new()
	s.spell_name = "Parchemin de Griffe Spectrale"
	s.target_mode = Spell.TargetMode.SINGLE_ENEMY
	s.ea_cost = 2
	s.spell_type = Spell.SpellType.PSYCHIC
	s.dice_terms = [{"count": 1, "sides": 6, "modifier": 2}]
	s.ignores_armor = true
	s.min_range = 1
	s.max_range = 6
	return s

static func _build_esprit_berzerk() -> Spell:
	var buff := StatusEffect.new()
	buff.effect_name = "Manuscrit de l'Esprit Berzerk (-1 Parade, +1 Attaque)"
	buff.duration_remaining = -1  # "Combat".
	buff.bonus_parade = -1
	buff.bonus_attaque = 1

	var s := Spell.new()
	s.spell_name = "Manuscrit de l'Esprit Berzerk"
	s.target_mode = Spell.TargetMode.SINGLE_ALLY
	s.ea_cost = 2
	s.spell_type = Spell.SpellType.PSYCHIC
	s.effect_to_apply = buff
	s.min_range = 1
	s.max_range = 6
	return s

static func _build_stimulant_de_combat() -> Spell:
	var buff := StatusEffect.new()
	buff.effect_name = "Stimulant de combat (+1 Attaque)"
	buff.duration_remaining = 2
	buff.bonus_attaque = 1

	var s := Spell.new()
	s.spell_name = "Traité du Stimulant de combat"
	s.target_mode = Spell.TargetMode.SINGLE_ALLY
	s.ea_cost = 2
	s.spell_type = Spell.SpellType.PHYSICAL
	s.effect_to_apply = buff
	s.min_range = 1
	s.max_range = 6
	return s

static func _build_protection_magique() -> Spell:
	var buff := StatusEffect.new()
	buff.effect_name = "Protection magique (+2 Armure magique)"
	buff.duration_remaining = -1  # "Combat".
	buff.bonus_armure_magique = 2

	var s := Spell.new()
	s.spell_name = "Essai sur la protection magique"
	s.target_mode = Spell.TargetMode.SINGLE_ALLY
	s.ea_cost = 4
	s.spell_type = Spell.SpellType.CHANCE
	s.effect_to_apply = buff
	s.min_range = 1
	s.max_range = 6
	return s

static func _build_revitalisation() -> Spell:
	var buff := StatusEffect.new()
	buff.effect_name = "Revitalisation (+2 Courage, +2 Force)"
	buff.duration_remaining = 3
	buff.bonus_courage = 2
	buff.bonus_force = 2

	var s := Spell.new()
	s.spell_name = "Traité sur la Revitalisation"
	s.target_mode = Spell.TargetMode.GROUP
	s.ea_cost = 3
	s.spell_type = Spell.SpellType.PHYSICAL
	s.effect_to_apply = buff
	return s

static func _build_grande_griffe_spectrale() -> Spell:
	var s := Spell.new()
	s.spell_name = "Parchemin de grande Griffe Spectrale"
	s.target_mode = Spell.TargetMode.SINGLE_ENEMY
	s.ea_cost = 3
	s.spell_type = Spell.SpellType.PSYCHIC
	s.dice_terms = [{"count": 1, "sides": 6, "modifier": 4}]
	s.ignores_armor = true
	s.min_range = 1
	s.max_range = 6
	return s

static func _build_croc_de_la_mort() -> Spell:
	var s := Spell.new()
	s.spell_name = "Parchemin de Croc de la mort"
	s.target_mode = Spell.TargetMode.ZONE
	s.ea_cost = 5
	s.spell_type = Spell.SpellType.PSYCHIC
	s.dice_terms = [{"count": 2, "sides": 6, "modifier": 3}]
	s.ignores_armor = true
	s.min_range = 1
	s.max_range = 6
	return s

static func _build_ame_du_berserk() -> Spell:
	var buff := StatusEffect.new()
	buff.effect_name = "Contrat de l'Âme du Berserk (-4 Parade, +6 Attaque)"
	buff.duration_remaining = -1  # "Combat".
	buff.bonus_parade = -4
	buff.bonus_attaque = 6

	var s := Spell.new()
	s.spell_name = "Contrat de l'Ame du Berserk"
	s.target_mode = Spell.TargetMode.SINGLE_ALLY
	s.ea_cost = 6
	s.spell_type = Spell.SpellType.CHANCE
	s.effect_to_apply = buff
	s.min_range = 1
	s.max_range = 6
	return s

static func _build_contrat_de_damocles() -> Spell:
	var effect := StatusEffect.new()
	effect.effect_name = "Contrat de Damoclès"
	effect.duration_remaining = -1  # Se retire elle-même au déclenchement (voir trigger_chance).
	effect.trigger_chance = 1.0 / 3.0
	effect.trigger_dice_terms = [{"count": 4, "sides": 6, "modifier": 2}]
	effect.trigger_bonus_dice_per_turn_waited = 1

	var s := Spell.new()
	s.spell_name = "Contrat de Damoclès"
	s.target_mode = Spell.TargetMode.SINGLE_ENEMY
	s.ea_cost = 10
	s.spell_type = Spell.SpellType.CHANCE
	s.cast_delay = 1  # Même mécanique qu'Épée de Damocles (Mage), qui a DI:1.
	s.effect_to_apply = effect
	s.min_range = 1
	s.max_range = 6
	return s

static func build_all() -> Array:
	return MetierSpellIcons.apply([
		_build_griffe_spectrale(),
		_build_esprit_berzerk(),
		_build_stimulant_de_combat(),
		_build_protection_magique(),
		_build_revitalisation(),
		_build_grande_griffe_spectrale(),
		_build_croc_de_la_mort(),
		_build_ame_du_berserk(),
		_build_contrat_de_damocles(),
	])
