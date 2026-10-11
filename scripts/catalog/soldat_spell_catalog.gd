extends RefCounted
class_name SoldatSpellCatalog

# ============================================================
# soldat_spell_catalog.gd
# Sorts du MÉTIER Soldat — accordés d'un coup.
#
# Formation (+1 dégât si un allié est adjacent) N'EST PAS un sort de
# cette liste : passif géré directement dans
# HexGrid._resolve_weapon_attack, via CombatUnit.has_metier("Soldat").
#
# Porte étendard : clic sur une case adjacente (même flux qu'une
# invocation, voir Spell.is_summon), mais SANS poser de vraie unité —
# juste un test Cou/Cha puis un buff direct aux alliés adjacents à
# cette case AU MOMENT DU LANCER (pas une aura qui se recalcule en
# continu si des alliés bougent ensuite — voir la note de
# Spell.is_soldat_porte_etendard).
# ============================================================

static func _build_porte_etendard() -> Spell:
	var s := Spell.new()
	s.spell_name = "Porte étendard"
	s.is_summon = true  # Réutilise le clic "case adjacente VIDE" des invocations (l'étendard doit donc être planté sur une case libre, pas sous un allié).
	s.is_soldat_porte_etendard = true
	s.ea_cost = 0  # Pas de coût précisé dans les données d'origine.
	s.spell_type = Spell.SpellType.COURAGE_CHARISME
	s.min_range = 1
	s.max_range = 1
	return s

static func build_all() -> Array:
	return ClassSpellIcons.apply([
		_build_porte_etendard(),
	])
