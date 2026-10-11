extends RefCounted
class_name BardeSpellCatalog

# ============================================================
# barde_spell_catalog.gd
# Sorts du MÉTIER Barde (sous-métier d'Artiste, voir
# metier_database.gd) — accordés d'un coup. Sordino EXCLU (demandé
# explicitement).
#
# Lexique de la planche d'origine :
# "Epreuve PH/PS" = Spell.SpellType.PHYSICAL/PSYCHIC.
# "DI" = cast_delay (délai d'incantation, système déjà existant).
# "(i)" sur le coût = Spell.is_initial_cost : déduit de base_max_ea
# PERMANENTE MENT, pas de current_ea temporairement (voir
# HexGrid._deduct_initial_cost). "%(i)" = pourcentage du max_ea actuel
# (initial_cost_is_percent/initial_cost_percent_value).
# "(b)" sur les dégâts = Spell.ignores_armor (dégâts "bruts").
# "+1 dégât par CHA > 12" (titre de la 1ère table) = appliqué à
# TOUS les sorts de cette table via includes_charisme_bonus_above_12.
#
# SIMPLIFICATIONS ASSUMÉES :
# - Maestoso : "DS : CHA-12" (une durée sur un sort de ZONE à dégâts
#   immédiats) ignorée — nos sorts de zone frappent une fois, pas de
#   zone-danger persistante chez nous. Juste les dégâts immédiats.
# - Adagio : "Ne peuvent plus attaquer ET déplacement le même tour"
#   (doivent choisir l'un OU l'autre) approximé en bloquant juste le
#   DÉPLACEMENT (grants_frozen) — l'attaque reste possible, pas de
#   système de "choix d'une seule action parmi deux" chez nous.
# - Tranquillo : "X Ennemis" (choix libre de qui) simplifié en TOUS
#   les ennemis vivants (X = leur nombre) — pas de sélecteur multi-
#   cibles chez nous.
# - Meno/Slancio : "CARA" (caractéristique) dans le commentaire
#   d'origine interprété comme Courage, par défaut faute de précision.
# - Rubato : "+2ESQ" (Esquive) mappé sur +2 Adresse, qui est la stat
#   dont dépend notre jet d'esquive — pas de stat "Esquive" séparée
#   chez nous.
# - Subito : "Permet de contre-attaquer après une esquive" sans
#   pourcentage précisé → 100% de chance (voir StatusEffect.
#   dodge_counter_chance), pas de restriction corps-à-corps.
# ============================================================

static func _build_fortissimo() -> Spell:
	var s := Spell.new()
	s.spell_name = "Fortissimo"
	s.target_mode = Spell.TargetMode.SINGLE_ENEMY
	s.ea_cost = 2
	s.spell_type = Spell.SpellType.PHYSICAL
	s.dice_terms = [{"count": 1, "sides": 6, "modifier": 3}]
	s.includes_charisme_bonus_above_12 = true
	s.min_range = 1
	s.max_range = 6
	return s

static func _build_legato() -> Spell:
	var s := Spell.new()
	s.spell_name = "Legato"
	s.target_mode = Spell.TargetMode.ZONE
	s.ea_cost = 4
	s.spell_type = Spell.SpellType.PHYSICAL
	s.dice_terms = [{"count": 1, "sides": 6, "modifier": 2}]
	s.includes_charisme_bonus_above_12 = true
	s.min_range = 1
	s.max_range = 6
	return s

static func _build_maestoso() -> Spell:
	var s := Spell.new()
	s.spell_name = "Maestoso"
	s.target_mode = Spell.TargetMode.ZONE
	s.ea_cost = 7
	s.spell_type = Spell.SpellType.PHYSICAL
	s.dice_terms = [{"count": 1, "sides": 6, "modifier": 0}]
	s.includes_charisme_bonus_above_12 = true
	s.min_range = 1
	s.max_range = 6
	return s

static func _build_molto() -> Spell:
	var s := Spell.new()
	s.spell_name = "Molto"
	s.target_mode = Spell.TargetMode.SINGLE_ENEMY
	s.is_initial_cost = true
	s.ea_cost = 6
	s.spell_type = Spell.SpellType.PHYSICAL
	s.damage_percent_of_target_hp = 0.5
	s.ignores_armor = true  # "(b)" — brut.
	s.min_range = 1
	s.max_range = 6
	return s

static func _build_adagio() -> Spell:
	var frozen := StatusEffect.new()
	frozen.effect_name = "Adagio (immobilisé)"
	frozen.duration_remaining = 3
	frozen.grants_frozen = true

	var s := Spell.new()
	s.spell_name = "Adagio"
	s.target_mode = Spell.TargetMode.ALL_ENEMIES
	s.ea_cost = 2
	s.cast_delay = 1
	s.spell_type = Spell.SpellType.PSYCHIC
	s.effect_to_apply = frozen
	return s

static func _build_tranquillo() -> Spell:
	var s := Spell.new()
	s.spell_name = "Tranquillo"
	s.target_mode = Spell.TargetMode.ALL_ENEMIES  # Approximation de "X Ennemis" — voir note en tête de fichier.
	s.is_barde_tranquillo = true
	s.spell_type = Spell.SpellType.PSYCHIC
	return s

static func _build_meno() -> Spell:
	var s := Spell.new()
	s.spell_name = "Meno"
	s.target_mode = Spell.TargetMode.ALL_ENEMIES
	s.is_barde_meno = true
	s.barde_cost_multiplier = 2
	s.spell_type = Spell.SpellType.PSYCHIC
	return s

static func _build_rubato() -> Spell:
	var buff := StatusEffect.new()
	buff.effect_name = "Rubato (+2 Adresse)"
	buff.duration_remaining = 3
	buff.bonus_adresse = 2  # "+2ESQ" — voir note en tête de fichier.

	var s := Spell.new()
	s.spell_name = "Rubato"
	s.target_mode = Spell.TargetMode.SINGLE_ALLY
	s.ea_cost = 1
	s.spell_type = Spell.SpellType.PSYCHIC
	s.effect_to_apply = buff
	s.min_range = 1
	s.max_range = 6
	return s

static func _build_vivace() -> Spell:
	var buff := StatusEffect.new()
	buff.effect_name = "Vivace (+1 Parade)"
	buff.duration_remaining = 3
	buff.bonus_parade = 1

	var s := Spell.new()
	s.spell_name = "Vivace"
	s.target_mode = Spell.TargetMode.GROUP
	s.ea_cost = 2
	s.spell_type = Spell.SpellType.PSYCHIC
	s.effect_to_apply = buff
	return s

static func _build_slancio() -> Spell:
	var s := Spell.new()
	s.spell_name = "Slancio"
	s.target_mode = Spell.TargetMode.SINGLE_ALLY
	s.is_barde_slancio = true
	s.barde_cost_multiplier = 7
	s.spell_type = Spell.SpellType.PSYCHIC
	s.min_range = 1
	s.max_range = 6
	return s

static func _build_subito() -> Spell:
	var buff := StatusEffect.new()
	buff.effect_name = "Subito (contre-attaque après esquive)"
	buff.duration_remaining = -1  # "Combat".
	buff.dodge_counter_chance = 1.0  # Pourcentage non précisé — voir note en tête de fichier.

	var s := Spell.new()
	s.spell_name = "Subito"
	s.target_mode = Spell.TargetMode.GROUP
	s.is_initial_cost = true
	s.initial_cost_is_percent = true
	s.initial_cost_percent_value = 0.10
	s.spell_type = Spell.SpellType.PSYCHIC
	s.effect_to_apply = buff
	return s

static func build_all() -> Array:
	return [
		_build_fortissimo(), _build_legato(), _build_maestoso(), _build_molto(),
		_build_adagio(), _build_tranquillo(), _build_meno(),
		_build_rubato(), _build_vivace(), _build_slancio(), _build_subito(),
	]
