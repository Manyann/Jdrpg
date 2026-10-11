extends RefCounted
class_name ConservateurSpellCatalog

# ============================================================
# conservateur_spell_catalog.gd
# Sorts du MÉTIER Conservateur (sous-métier d'Archéologue, voir
# metier_database.gd) — accordés d'un coup, pas de palier.
#
# Essai sur la cryogénisation / Parchemin de fracture sysmique :
# "(même que mage)"/"(pareil que mage)" — mécaniques REPRISES À
# L'IDENTIQUE des sorts Cryogénisation / Fracture sysmique du Mage
# (voir mage_spell_catalog.gd), sauf mention contraire explicite des
# données d'origine. Fracture sysmique précise "lancement : Instantanée"
# ici, DONC PAS de délai d'incantation (cast_delay=0), contrairement à
# la version Mage qui a DI:2 — différence volontaire, respectée.
#
# Traité sur les Gantelets du Berserk : 2 mécaniques neuves pour
# l'occasion (voir status_effect.gd) — grants_ambidextrie (Ambidextrie
# temporaire, ajoute dynamiquement l'attaque de la main secondaire si
# besoin, voir CombatUnit.add_status_effect) et grants_lifesteal (vol
# de vie, voir HexGrid._resolve_weapon_attack/_deal_counter_attack).
# ============================================================

static func _build_restauration_des_ea() -> Spell:
	var s := Spell.new()
	s.spell_name = "Traité sur la restauration des EA"
	s.target_mode = Spell.TargetMode.SINGLE_ALLY
	s.is_heal = true
	s.restores_mana = true
	s.ea_cost = 3
	s.spell_type = Spell.SpellType.PHYSICAL
	s.dice_terms = [{"count": 0, "sides": 6, "modifier": 7}]
	s.min_range = 1
	s.max_range = 6
	return s

static func _build_gantelets_du_berserk() -> Spell:
	var buff := StatusEffect.new()
	buff.effect_name = "Gantelets du Berserk"
	buff.duration_remaining = -1  # "Combat".
	buff.bonus_weapon_dice_count = 1
	buff.bonus_weapon_dice_modifier = 6
	buff.grants_ambidextrie = true
	buff.grants_lifesteal = true

	var s := Spell.new()
	s.spell_name = "Traité sur les Gantelets du Berserk"
	s.target_mode = Spell.TargetMode.SELF  # Cible non précisée dans les données d'origine — effet manifestement personnel ("confère... au corps à corps").
	s.ea_cost = 5
	s.spell_type = Spell.SpellType.PHYSICAL
	s.effect_to_apply = buff
	return s

static func _build_cryogenisation() -> Spell:
	var s := Spell.new()
	s.spell_name = "Essai sur la cryogénisation"
	s.target_mode = Spell.TargetMode.SINGLE_ALLY
	s.ea_cost = 6
	s.spell_type = Spell.SpellType.CHANCE

	var effect := StatusEffect.new()
	effect.effect_name = "Cryogénisation"
	effect.duration_remaining = -1  # Pas de DS précisé : permanent (jusqu'à la fin du combat, ou Purge) — même choix que le Mage.
	effect.grants_frozen = true
	effect.grants_untargetable = true
	effect.grants_invulnerable = true
	s.effect_to_apply = effect

	s.min_range = 1
	s.max_range = 6
	return s

static func _build_fracture_sysmique() -> Spell:
	var s := Spell.new()
	s.spell_name = "Parchemin de fracture sysmique"
	s.target_mode = Spell.TargetMode.ZONE
	s.zone_offsets = ZoneShapes.FRACTURE_SYSMIQUE.duplicate()  # Même forme que la version Mage.
	s.ea_cost = 12
	s.spell_type = Spell.SpellType.PSYCHIC
	s.dice_terms = [{"count": 6, "sides": 6, "modifier": 6}]
	s.min_range = 1
	s.max_range = 6
	return s

static func build_all() -> Array:
	return MetierSpellIcons.apply([
		_build_restauration_des_ea(),
		_build_gantelets_du_berserk(),
		_build_cryogenisation(),
		_build_fracture_sysmique(),
	])
