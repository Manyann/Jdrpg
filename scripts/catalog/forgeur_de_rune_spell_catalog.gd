extends RefCounted
class_name ForgeurDeRunesSpellCatalog

# ============================================================
# forgeur_de_runes_spell_catalog.gd
# Sorts du MÉTIER Forgeur de runes (sous-métier d'Artisan, voir
# metier_database.gd) — accordés d'un coup, pas de palier.
#
# "Allié ou soit même" = TargetMode.SINGLE_ALLY (le lanceur peut déjà
# se cibler lui-même en cliquant sur sa propre case, comme pour tout
# sort SINGLE_ALLY — rien de spécial à ajouter).
# "Magie Phy"/"Magie Psy" = Spell.SpellType.PHYSICAL/PSYCHIC, "+2" =
# to_hit_modifier (même lexique que les sorts Walkyrie).
# "Durée : Combat" = permanent pour le reste du combat (duration=-1),
# même convention que les sorts du Mage sans DS précisée.
# "Rune d'invulnérabilité" : malgré son nom, l'effet décrit est "+8
# PR" (armure), pas une vraie invulnérabilité — implémenté tel que
# décrit dans la donnée (le champ "effet" fait foi, pas le nom du sort).
# Son champ "lancement : 6 tours" est traité comme une durée (6 tours),
# la donnée d'origine semble avoir inversé lancement/durée pour ce sort.
# ============================================================

static func _build_rune_de_protection() -> Spell:
	var buff := StatusEffect.new()
	buff.effect_name = "Rune de protection (+2 Armure)"
	buff.duration_remaining = -1  # "Combat".
	buff.bonus_armure = 2

	var s := Spell.new()
	s.spell_name = "Rune de protection"
	s.target_mode = Spell.TargetMode.SINGLE_ALLY
	s.ea_cost = 4
	s.spell_type = Spell.SpellType.PHYSICAL
	s.to_hit_modifier = 2
	s.effect_to_apply = buff
	s.min_range = 1
	s.max_range = 6
	return s

static func _build_rune_de_protection_magique() -> Spell:
	var buff := StatusEffect.new()
	buff.effect_name = "Rune de protection magique (+2 Armure magique)"
	buff.duration_remaining = -1  # "Combat".
	buff.bonus_armure_magique = 2

	var s := Spell.new()
	s.spell_name = "Rune de protection magique"
	s.target_mode = Spell.TargetMode.SINGLE_ALLY
	s.ea_cost = 4
	s.spell_type = Spell.SpellType.PSYCHIC
	s.to_hit_modifier = 2
	s.effect_to_apply = buff
	s.min_range = 1
	s.max_range = 6
	return s

static func _build_rune_de_combat() -> Spell:
	var buff := StatusEffect.new()
	buff.effect_name = "Rune de combat (+2 Dégâts)"
	buff.duration_remaining = 4
	buff.bonus_weapon_dice_modifier = 2

	var s := Spell.new()
	s.spell_name = "Rune de combat"
	s.target_mode = Spell.TargetMode.GROUP
	s.ea_cost = 3
	s.spell_type = Spell.SpellType.PHYSICAL
	s.to_hit_modifier = 2
	s.effect_to_apply = buff
	return s

static func _build_rune_d_invulnerabilite() -> Spell:
	var buff := StatusEffect.new()
	buff.effect_name = "Rune d'invulnérabilité (+8 Armure)"
	buff.duration_remaining = 6  # "lancement : 6 tours" — traité comme une durée, voir note en tête de fichier.
	buff.bonus_armure = 8

	var s := Spell.new()
	s.spell_name = "Rune d'invulnérabilité"
	s.target_mode = Spell.TargetMode.SINGLE_ALLY
	s.ea_cost = 8
	s.spell_type = Spell.SpellType.PHYSICAL
	s.effect_to_apply = buff
	s.min_range = 1
	s.max_range = 6
	return s

static func build_all() -> Array:
	return MetierSpellIcons.apply([
		_build_rune_de_protection(),
		_build_rune_de_protection_magique(),
		_build_rune_de_combat(),
		_build_rune_d_invulnerabilite(),
	])
