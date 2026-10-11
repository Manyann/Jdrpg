extends RefCounted
class_name NinjaSpellCatalog

# ============================================================
# ninja_spell_catalog.gd
# Sorts du MÉTIER Ninja (sous-métier de Rôdeur, voir
# metier_database.gd) — accordés d'un coup.
#
# Esquive totale (sans malus, contrairement au Voleur) et Frappe des
# ombres (dégâts ×2 dans le dos) NE sont PAS des sorts de cette liste :
# passifs gérés directement dans HexGrid._try_dodge/_resolve_weapon_attack,
# via Metier.grants_ninja_esquive_totale/grants_ninja_frappe_des_ombres.
# ============================================================

static func _build_permutation() -> Spell:
	var s := Spell.new()
	s.spell_name = "Permutation"
	s.target_mode = Spell.TargetMode.SINGLE_ALLY
	s.is_ninja_permutation = true
	s.ea_cost = 0  # Pas de coût précisé dans les données d'origine.
	s.spell_type = Spell.SpellType.PHYSICAL
	s.min_range = 1
	s.max_range = 6
	return s

static func build_all() -> Array:
	return ClassSpellIcons.apply([
		_build_permutation(),
	])
