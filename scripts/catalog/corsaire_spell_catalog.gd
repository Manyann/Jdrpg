extends RefCounted
class_name CorsaireSpellCatalog

# ============================================================
# corsaire_spell_catalog.gd
# Sorts du MÉTIER Corsaire (sous-métier de Pirate) — accordés d'un coup.
#
# Salve : "4 coups de Pistolet Durandil" est descriptif/flavor — pas
# besoin de posséder cette arme précise ni 4 pistolets, juste le jet
# de dégâts final (4D+20). 1 fois par combat (voir
# Spell.is_corsaire_salve), coût non précisé dans les données
# d'origine → 0 EA.
# ============================================================

static func _build_salve() -> Spell:
	var s := Spell.new()
	s.spell_name = "Salve"
	s.target_mode = Spell.TargetMode.SINGLE_ENEMY
	s.is_corsaire_salve = true
	s.ea_cost = 0
	s.spell_type = Spell.SpellType.PHYSICAL
	s.dice_terms = [{"count": 4, "sides": 6, "modifier": 20}]
	s.min_range = 1
	s.max_range = 6
	return s

static func build_all() -> Array:
	return ClassSpellIcons.apply([
		_build_salve(),
	])
