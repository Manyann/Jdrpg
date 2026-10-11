extends RefCounted
class_name MoineSpellCatalog

# ============================================================
# moine_spell_catalog.gd
# Sorts du MÉTIER Moine (sous-métier de Prêtre, voir
# metier_database.gd) — accordés d'un coup.
#
# Frappe d'énergie (fenêtre de critique étendue à mains nues) n'est
# PAS un sort de cette liste : c'est un passif géré directement dans
# HexGrid._resolve_weapon_attack/_deal_counter_attack, via
# Metier.grants_moine_frappe_energie (voir metier_database.gd).
# ============================================================

static func _build_purification() -> Spell:
	var s := Spell.new()
	s.spell_name = "Purification"
	s.target_mode = Spell.TargetMode.SELF
	s.ea_cost = 3
	s.spell_type = Spell.SpellType.PSYCHIC
	s.cleanses_effects = true
	return s

static func build_all() -> Array:
	return ClassSpellIcons.apply([
		_build_purification(),
	])
