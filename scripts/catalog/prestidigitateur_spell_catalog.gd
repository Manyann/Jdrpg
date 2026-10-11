extends RefCounted
class_name PrestidigitateurSpellCatalog

# ============================================================
# prestidigitateur_spell_catalog.gd
# Sorts du MÉTIER Prestidigitateur (sous-métier d'Artiste, voir
# metier_database.gd) — accordés d'un coup.
#
# Réalité distordue (immunité totale aux critiques — remplace la
# version d'origine "-1 critique" par la version mise à jour) N'EST
# PAS un sort de cette liste : passif géré directement dans HexGrid
# (_resolve_weapon_attack/_deal_counter_attack/
# _apply_spell_effect_to_target/_resolve_ev_cost_spell), via
# Metier.grants_prestidigitateur_realite_distordue.
#
# Substitution : choix LIBRE de 2 statistiques parmi les 6 (+4 à l'une,
# -4 à l'autre) via un sélecteur à 2 étapes — voir
# TurnManager.show_stat_picker_step1/HexGrid.confirm_substitution. Le
# sort lui-même ne porte que le drapeau de déclenchement ; tout le
# choix (stats) et la résolution (test INT, application du buff) se
# font ailleurs, pas de données figées à construire ici.
# ============================================================

static func _build_substitution() -> Spell:
	var s := Spell.new()
	s.spell_name = "Substitution"
	s.target_mode = Spell.TargetMode.SELF
	s.is_prestidigitateur_substitution = true
	s.ea_cost = 0  # Pas de coût précisé dans les données d'origine.
	s.spell_type = Spell.SpellType.INTELLIGENCE
	return s

static func build_all() -> Array:
	return ClassSpellIcons.apply([
		_build_substitution(),
	])
