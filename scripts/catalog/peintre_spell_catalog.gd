extends RefCounted
class_name PeintreSpellCatalog

# ============================================================
# peintre_spell_catalog.gd
# Sorts du MÉTIER Peintre (sous-métier d'Artiste, voir
# metier_database.gd) — accordés d'un coup.
#
# Les deux sorts ont une résolution SUR-MESURE (pas le système
# générique Spell/StatusEffect) — voir HexGrid._resolve_peinture_de_guerre
# / _resolve_peintre_maquillage pour le détail et pourquoi.
#
# Maquillage : AUCUN effet mécanique pour l'instant — juste le jet, la
# consommation de charge et un texte. PAS un choix définitif : son vrai
# intérêt (tromper un adversaire) n'a de sens qu'en PvP, à revoir une
# fois que ça existera (voir la doc de Spell.is_peintre_maquillage).
# ============================================================

static func _build_peinture_de_guerre() -> Spell:
	var s := Spell.new()
	s.spell_name = "Peinture de guerre"
	s.target_mode = Spell.TargetMode.SELF
	s.is_peintre_peinture_de_guerre = true
	s.ea_cost = 0  # Pas de coût précisé dans les données d'origine.
	s.spell_type = Spell.SpellType.COURAGE
	return s

static func _build_maquillage() -> Spell:
	var s := Spell.new()
	s.spell_name = "Maquillage"
	s.target_mode = Spell.TargetMode.SELF
	s.is_peintre_maquillage = true
	s.ea_cost = 0
	s.spell_type = Spell.SpellType.PSYCHIC
	return s

static func build_all() -> Array:
	return MetierSpellIcons.apply([
		_build_peinture_de_guerre(),
		_build_maquillage(),
	])
