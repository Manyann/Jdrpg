extends RefCounted
class_name ElfeSylvainSpellCatalog

# ============================================================
# elfe_sylvain_spell_catalog.gd
# Sorts de la RACE Elfe Sylvain (voir race_database.gd — le tag
# "#sylvain" laissé en attente lors de l'import initial des races).
# Accordés à toute unité ayant cette race, quel que soit son métier —
# à la différence des sorts Walkyrie, liés au métier.
#
# "PA" dans les données d'origine traité comme équivalent à l'EA
# (Énergie Astrale) déjà utilisée partout ailleurs (Spell.ea_cost) —
# rien dans ces données ne suggère un coût en PV comme la branche
# Walkyrie, et les montants (2 à 12) sont cohérents avec les coûts EA
# des sorts du Mage.
# "PH"/"PS" = Spell.SpellType.PHYSICAL/PSYCHIC, comme pour le Mage.
# Dés à 6 faces par défaut quand la taille n'est pas précisée ("1D",
# "2D"), même convention que le catalogue Mage.
# ============================================================

static func _build_soin_de_la_foret() -> Spell:
	var s := Spell.new()
	s.spell_name = "Soin de la forêt"
	s.target_mode = Spell.TargetMode.SINGLE_ALLY
	s.is_heal = true
	s.ea_cost = 2
	s.spell_type = Spell.SpellType.PSYCHIC
	s.dice_terms = [{"count": 1, "sides": 6, "modifier": 1}]
	s.min_range = 1
	s.max_range = 6
	return s

static func _build_restauration_de_la_nature() -> Spell:
	var s := Spell.new()
	s.spell_name = "Restauration de la nature"
	s.target_mode = Spell.TargetMode.SINGLE_ALLY
	s.restores_mana = true
	s.is_heal = true  # Comme les sorts de restauration de mana du Mage : is_heal ET restores_mana ensemble.
	s.ea_cost = 2
	s.spell_type = Spell.SpellType.PSYCHIC
	s.dice_terms = [{"count": 1, "sides": 4, "modifier": 2}]
	s.min_range = 1
	s.max_range = 6
	return s

static func _build_purge() -> Spell:
	var s := Spell.new()
	s.spell_name = "Purge"
	s.target_mode = Spell.TargetMode.SELF
	s.cleanses_effects = true
	s.ea_cost = 4
	s.spell_type = Spell.SpellType.PSYCHIC
	return s

static func _build_soin_sylvestre() -> Spell:
	var s := Spell.new()
	s.spell_name = "Soin sylvestre"
	s.target_mode = Spell.TargetMode.SINGLE_ALLY
	s.is_heal = true
	s.ea_cost = 4
	s.spell_type = Spell.SpellType.PSYCHIC
	s.dice_terms = [{"count": 2, "sides": 6, "modifier": 2}, {"count": 1, "sides": 4, "modifier": 0}]
	s.min_range = 1
	s.max_range = 6
	return s

static func _build_tapis_de_ronce() -> Spell:
	var s := Spell.new()
	var debuff := StatusEffect.new()
	debuff.effect_name = "Tapis de ronce (-3 Adresse)"
	debuff.duration_remaining = -1  # Non précisée dans les données d'origine — permanent pour le combat, même convention que le Mage.
	debuff.bonus_adresse = -3

	s.spell_name = "Tapis de ronce"
	s.target_mode = Spell.TargetMode.SINGLE_ENEMY
	s.ea_cost = 3
	s.spell_type = Spell.SpellType.PHYSICAL
	s.effect_to_apply = debuff
	s.min_range = 1
	s.max_range = 6
	return s

static func _build_lasso_de_lianes() -> Spell:
	var s := Spell.new()
	s.spell_name = "Lasso de lianes"
	s.target_mode = Spell.TargetMode.SINGLE_ENEMY
	s.ea_cost = 3
	s.spell_type = Spell.SpellType.PHYSICAL
	s.dice_terms = [{"count": 1, "sides": 6, "modifier": 8}]
	s.min_range = 1
	s.max_range = 6
	return s

static func _build_revitalisation() -> Spell:
	var s := Spell.new()
	var buff := StatusEffect.new()
	buff.effect_name = "Revitalisation (+2 Courage, +2 Force)"
	buff.duration_remaining = -1  # Non précisée — permanent pour le combat.
	buff.bonus_courage = 2
	buff.bonus_force = 2

	s.spell_name = "Revitalisation"
	s.target_mode = Spell.TargetMode.GROUP
	s.ea_cost = 5
	s.spell_type = Spell.SpellType.PSYCHIC
	s.effect_to_apply = buff
	return s

static func _build_ent_protecteur() -> Spell:
	var s := Spell.new()
	s.spell_name = "Ent protecteur des sylvains"
	s.is_summon = true
	s.summon_name = "Ent protecteur"
	s.summon_max_hp = 40
	s.summon_attack_parade = 8
	s.summon_armor = 2
	s.summon_dice_count = 3
	s.summon_dice_modifier = 0
	s.summon_color = Color(0.35, 0.55, 0.25)
	s.ea_cost = 12
	s.spell_type = Spell.SpellType.PHYSICAL
	s.min_range = 1
	s.max_range = 6
	return s

# Icônes : celles du Mage (res://assets/spell_icons/mage/), les sorts étant
# les mêmes ou voisins. Nom du sort -> nom de l'icône du Mage.
const ICONS: Dictionary = {
	"Soin de la forêt": "soin_mineur",
	"Restauration de la nature": "restauration_energie_astrale",
	"Purge": "purge",
	"Soin sylvestre": "soin_majeur",
	"Tapis de ronce": "tapis_de_ronce",
	"Lasso de lianes": "lasso_de_lianes",
	"Revitalisation": "revitalisation",
	"Ent protecteur des sylvains": "jeune_ent",
}

static func build_all() -> Array:
	var spells: Array = [
		_build_soin_de_la_foret(),
		_build_restauration_de_la_nature(),
		_build_purge(),
		_build_soin_sylvestre(),
		_build_tapis_de_ronce(),
		_build_lasso_de_lianes(),
		_build_revitalisation(),
		_build_ent_protecteur(),
	]
	for spell in spells:
		if ICONS.has(spell.spell_name):
			spell.icon_path = MageSpellIcons.FOLDER + str(ICONS[spell.spell_name]) + ".png"
	return spells
