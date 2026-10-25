extends RefCounted
class_name BerzerkSpellCatalog

# ============================================================
# berzerk_spell_catalog.gd
# Sorts du MÉTIER Berzerk — accordés d'un coup.
#
# Rage (+1 par dégât REÇU), Enragé (+niveau dégâts sous 66% PV) et
# Coûte que coûte (+2×niveau dégâts sous 3% PV) NE SONT PAS des sorts
# de cette liste : passifs gérés directement dans
# CombatUnit.take_damage() / HexGrid._resolve_weapon_attack, via
# CombatUnit.has_metier("Berzerk").
#
# Frappe puissante / Tourbillon : coût FIXE en Rage (pas en EA), voir
# Spell.rage_cost — vérifié et déduit directement dans HexGrid._cast_spell,
# pas via ea_cost.
# Raaah : coût VARIABLE en Rage (X choisi par le joueur, même
# sélecteur que les sorts à coût en PV/PA), voir Spell.is_rage_cost_spell.
# ============================================================

static func _build_frappe_puissante() -> Spell:
	var s := Spell.new()
	s.spell_name = "Frappe puissante"
	s.target_mode = Spell.TargetMode.SELF
	s.is_berzerk_frappe_puissante = true
	s.rage_cost = 5
	s.spell_type = Spell.SpellType.NONE
	return s

static func _build_tourbillon() -> Spell:
	var s := Spell.new()
	s.spell_name = "Tourbillon"
	s.target_mode = Spell.TargetMode.SELF
	s.is_berzerk_tourbillon = true
	s.rage_cost = 10
	s.spell_type = Spell.SpellType.NONE
	return s

static func _build_raaah() -> Spell:
	var s := Spell.new()
	s.spell_name = "Raaah"
	s.target_mode = Spell.TargetMode.SELF
	s.is_rage_cost_spell = true
	s.is_berzerk_raaah = true
	s.ev_cost_min = 1
	s.ev_cost_max = 999  # Pas de plafond précisé — borné par la Rage réellement disponible de toute façon.
	s.spell_type = Spell.SpellType.NONE
	return s

static func _build_grr() -> Spell:
	var s := Spell.new()
	s.spell_name = "GRRRRRBLBLBL"
	s.target_mode = Spell.TargetMode.SELF
	s.is_rage_cost_spell = true
	s.is_berzerk_grr = true
	s.ev_cost_min = 10
	s.ev_cost_max = 999
	s.spell_type = Spell.SpellType.COURAGE
	s.info_text = "Transforme 10×X Rage en X PI (dégâts supplémentaires). 1 fois par combat. Test de Courage."
	return s

static func build_all() -> Array:
	return ClassSpellIcons.apply([
		_build_frappe_puissante(),
		_build_tourbillon(),
		_build_raaah(),
		_build_grr(),
	])
