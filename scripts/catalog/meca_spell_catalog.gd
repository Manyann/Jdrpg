extends RefCounted
class_name MecaSpellCatalog

# ============================================================
# meca_spell_catalog.gd
# Sorts d'invocation de Méca du MÉTIER Ingénieur Automate (sous-métier
# d'Ingénieur, voir metier_database.gd) — 4 sorts (Doc/Tanker/Combat/
# Support), accordés d'un coup. "Supplément 1"/"Supplément 2" ne sont
# PAS de nouveaux Mécas (confirmé) : le MÊME Méca, amélioré selon le
# niveau du lanceur (7+ débloque Supplément 1, 10+ débloque
# Supplément 2 — toujours le palier le plus haut débloqué). Les 3
# colonnes de stats du catalogue d'origine sont condensées dans
# HexGrid._build_meca_unit (pas 12 sorts séparés).
#
# Limite "2 Mécas max par combat" (voir le métier Ingénieur Automate)
# appliquée dans HexGrid._cast_summon_spell, toutes branches confondues
# (CombatUnit.mecas_summoned_this_combat).
#
# SIMPLIFICATIONS ASSUMÉES (pas de système correspondant chez nous) :
# - Taunt (Tanker) : l'IA ennemie (EnemyAI._get_targets) ne vise que les
#   provocateurs vivants et visibles. Un ennemi piloté par un humain n'est
#   pas contraint.
# - Aura du Tanker ("+1 PR aux N alliés les plus proches tant que le
#   Méca est en vie") : appliquée UNE SEULE FOIS à l'invocation, en
#   PERMANENT — pas de mécanisme chez nous pour retirer un effet quand
#   UNE AUTRE unité meurt, ni pour le réappliquer si l'allié le plus
#   proche change en cours de combat.
# - Support ("+AT ou PRD", un choix) : toujours +AT, jamais +PRD —
#   évite d'ajouter une interface de choix pour un bonus mineur (+1/+2,
#   1 seul tour).
# - Combat, palier 2 ("Ambidextrie") : sans effet — les Mécas n'ont
#   qu'une seule arme (pas d'arme en main secondaire configurée),
#   l'Ambidextrie n'aurait donc rien à activer.
# ============================================================

static func _build_doc() -> Spell:
	var s := Spell.new()
	s.spell_name = "Invoque un Méca Doc"
	s.is_summon = true
	s.is_meca_summon = true
	s.meca_type = "doc"
	s.ea_cost = 0  # Pas de coût précisé dans les données d'origine.
	s.spell_type = Spell.SpellType.PHYSICAL
	s.min_range = 1
	s.max_range = 6
	return s

static func _build_tanker() -> Spell:
	var s := Spell.new()
	s.spell_name = "Invoque un Méca Tanker"
	s.is_summon = true
	s.is_meca_summon = true
	s.meca_type = "tanker"
	s.ea_cost = 0
	s.spell_type = Spell.SpellType.PHYSICAL
	s.min_range = 1
	s.max_range = 6
	return s

static func _build_combat() -> Spell:
	var s := Spell.new()
	s.spell_name = "Invoque un Méca Combat"
	s.is_summon = true
	s.is_meca_summon = true
	s.meca_type = "combat"
	s.ea_cost = 0
	s.spell_type = Spell.SpellType.PHYSICAL
	s.min_range = 1
	s.max_range = 6
	return s

static func _build_support() -> Spell:
	var s := Spell.new()
	s.spell_name = "Invoque un Méca Support"
	s.is_summon = true
	s.is_meca_summon = true
	s.meca_type = "support"
	s.ea_cost = 0
	s.spell_type = Spell.SpellType.PHYSICAL
	s.min_range = 1
	s.max_range = 6
	return s

static func build_all() -> Array:
	var spells: Array = [
		_build_doc(),
		_build_tanker(),
		_build_combat(),
		_build_support(),
	]
	for spell in spells:
		spell.icon_path = MecaSpellIcons.path_for(spell.spell_name)
	return spells
