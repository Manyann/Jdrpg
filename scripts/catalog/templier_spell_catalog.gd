extends RefCounted
class_name TemplierSpellCatalog

# ============================================================
# templier_spell_catalog.gd
# Sorts du MÉTIER Templier (sous-métier de Paladin, voir
# metier_database.gd) — accordés d'un coup.
#
# Bouclier de Foi : coût en PA VARIABLE (réutilise le système de
# Walkyrie/Prêtre, voir Spell.is_pa_cost_spell), X choisi par le
# joueur au sélecteur. Puissance du bouclier = 2×X (ev_x_multiplier),
# posée sur CombatUnit.shield_power via Spell.grants_shield_power —
# absorbe les dégâts entrants avant les PV, détruite net par un
# critique quelle que soit sa réserve restante (voir
# CombatUnit.take_damage). Cible non précisée dans les données
# d'origine ("Invoque un bouclier") : traité comme SELF, cohérent avec
# les autres sorts sans cible explicite de ce type (Gantelets du
# Berserk, Conservateur).
# ============================================================

static func _build_bouclier_de_foi() -> Spell:
	var s := Spell.new()
	s.spell_name = "Bouclier de Foi"
	s.target_mode = Spell.TargetMode.SELF
	s.is_pa_cost_spell = true
	s.ev_cost_min = 1
	s.ev_cost_max = 20  # Plage non précisée dans les données d'origine.
	s.ev_x_divisor = 1
	s.ev_x_multiplier = 2  # Puissance = 2×X.
	s.grants_shield_power = true
	s.spell_type = Spell.SpellType.PHYSICAL
	return s

static func build_all() -> Array:
	return ClassSpellIcons.apply([
		_build_bouclier_de_foi(),
	])
