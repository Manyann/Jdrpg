extends RefCounted
class_name GladiateurSpellCatalog

# ============================================================
# gladiateur_spell_catalog.gd
# Sorts du MÉTIER Gladiateur — accordés d'un coup.
#
# Gloire (gain sur attaque/parade), Pour la gloire (5 Gloire de
# départ) et Tenir bon (+niveau Armure sous 33% PV) NE SONT PAS des
# sorts de cette liste : passifs gérés directement dans
# CombatUnit._ready()/_recalculate_stats()/take_damage() et
# HexGrid._resolve_weapon_attack.
#
# Les 3 actifs coûtent de la GLOIRE (voir Spell.gloire_cost), pas de
# l'EA — le reste de leur résolution passe normalement par le système
# générique (effect_to_apply, stun_turns).
#
# Doigt d'honneur : pendant 3 de ses tours, la cible (si pilotée par l'IA)
# ne peut attaquer que le Gladiateur — voir Spell.forces_attack_on_caster_turns
# et EnemyAI.play_turn. Esquivable comme un sort offensif sans dégâts.
# ============================================================

static func _build_doigt_dhonneur() -> Spell:
	var s := Spell.new()
	s.spell_name = "Doigt d'honneur"
	s.target_mode = Spell.TargetMode.SINGLE_ENEMY
	s.gloire_cost = 5
	s.spell_type = Spell.SpellType.NONE
	s.damage = 0  # Aucun dégât : seulement la provocation.
	s.forces_attack_on_caster_turns = 3
	s.info_text = "Force la cible à n'attaquer que le lanceur pendant 3 de ses tours."
	s.min_range = 1
	s.max_range = 6
	return s

static func _build_coup_de_bouclier() -> Spell:
	var s := Spell.new()
	s.spell_name = "Coup de bouclier"
	s.target_mode = Spell.TargetMode.SINGLE_ENEMY
	s.gloire_cost = 7
	s.spell_type = Spell.SpellType.NONE
	s.stun_turns = 2  # "Passe ses 2 prochains tours".
	s.min_range = 1
	s.max_range = 1
	return s

static func _build_tortue() -> Spell:
	var buff := StatusEffect.new()
	buff.effect_name = "Tortue (-2 Attaque, +2 Parade)"
	buff.duration_remaining = -1  # Durée non précisée — permanent pour le reste du combat, même convention que le Mage.
	buff.bonus_attaque = -2
	buff.bonus_parade = 2

	var s := Spell.new()
	s.spell_name = "Tortue"
	s.target_mode = Spell.TargetMode.SELF
	s.gloire_cost = 10
	s.spell_type = Spell.SpellType.NONE
	s.effect_to_apply = buff
	return s

static func _build_un_pour_tous() -> Spell:
	var s := Spell.new()
	s.spell_name = "Un pour tous"
	s.target_mode = Spell.TargetMode.SINGLE_ALLY
	s.is_un_pour_tous = true
	s.ea_cost = 0
	s.gloire_cost = 0  # Aucun coût précisé dans les données d'origine.
	s.spell_type = Spell.SpellType.NONE
	s.info_text = "Le gladiateur perd 3 AT et encaisse à la place d'un allié les 3 prochains dégâts que celui-ci va subir."
	s.min_range = 1
	s.max_range = 6
	return s

static func build_all() -> Array:
	return ClassSpellIcons.apply([
		_build_doigt_dhonneur(),
		_build_coup_de_bouclier(),
		_build_tortue(),
		_build_un_pour_tous(),
	])
