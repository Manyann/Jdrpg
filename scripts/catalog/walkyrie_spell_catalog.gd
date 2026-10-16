extends RefCounted
class_name WalkyrieSpellCatalog

# ============================================================
# walkyrie_spell_catalog.gd
# Sorts de la branche de métier Walkyrie (voir metier_database.gd —
# Walkyrie -> Compagnie du crépuscule / Légion céleste / Gardienne de
# l'aube -> Archange, qui hérite des 3). Liés au MÉTIER équipé
# (CombatUnit.equipped_metier), pas à la race — malgré le nom "Walkyrie"
# qui existe aussi comme race, sans rapport ici.
#
# Particularité : ce sont des sorts à COÛT EN PV (pas en EA) — voir
# Spell.is_ev_cost_spell. Le joueur choisit un montant X au lancer
# (voir TurnManager.show_ev_cost_picker), qui coûte X PV et détermine
# l'ampleur de l'effet (dice_terms + X/ev_x_divisor + ev_x_flat_bonus).
#
# "Grâce du ciel" (résurrection) n'est PAS implémentée mécaniquement
# (voir Spell.is_walkyrie_resurrection) : une unité morte est
# entièrement retirée de la scène chez nous (CombatUnit.die() ->
# queue_free()), impossible à ranimer sans un système de "cadavre"
# trackable qu'on n'a pas. Traité comme un sort non-automatisé
# (is_unimplemented) : coûte l'action, affiche son texte d'origine,
# aucun effet.
#
# Aucune "condition" (plage de X) n'était précisée dans les données
# d'origine pour Rayon de lumière / Laser purificateur / Courroux du
# ciel / Arme céleste / Protection divine / Bouclier de paix /
# Jugement divin — plage 1-20 choisie par défaut, à ajuster si besoin.
# ============================================================

static func _build_soin_leger() -> Spell:
	var s := Spell.new()
	s.spell_name = "Soin des blessures légères"
	s.target_mode = Spell.TargetMode.SINGLE_ALLY
	s.is_heal = true
	s.is_ev_cost_spell = true
	s.ev_cost_min = 4
	s.ev_cost_max = 10
	s.ev_x_divisor = 2
	s.ev_x_flat_bonus = 2
	s.spell_type = Spell.SpellType.PSYCHIC
	s.min_range = 1
	s.max_range = 6
	return s

static func _build_rayon_de_lumiere() -> Spell:
	var s := Spell.new()
	s.spell_name = "Rayon de lumière"
	s.target_mode = Spell.TargetMode.SINGLE_ENEMY
	s.is_ev_cost_spell = true
	s.ev_cost_min = 1
	s.ev_cost_max = 20  # Plage non précisée dans les données d'origine — défaut raisonnable.
	s.ev_x_divisor = 2
	s.spell_type = Spell.SpellType.PHYSICAL
	s.to_hit_modifier = 2
	s.dice_terms = [{"count": 1, "sides": 10, "modifier": 0}]
	s.min_range = 1
	s.max_range = 6
	return s

static func _build_laser_purificateur() -> Spell:
	var s := Spell.new()
	s.spell_name = "Laser purificateur"
	s.target_mode = Spell.TargetMode.ZONE
	# Ligne droite de 3 cases dans l'axe lanceur -> ancre (même principe
	# que les formes de zone du Mage, voir zone_shapes.gd) — orientée
	# automatiquement à l'opposé du lanceur.
	s.zone_offsets = [Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)]
	s.is_ev_cost_spell = true
	s.ev_cost_min = 1
	s.ev_cost_max = 20  # Plage non précisée dans les données d'origine.
	s.ev_x_divisor = 2
	s.spell_type = Spell.SpellType.PHYSICAL
	s.to_hit_modifier = 2
	s.dice_terms = [{"count": 2, "sides": 6, "modifier": 0}]
	s.min_range = 1
	s.max_range = 6
	return s

static func _build_courroux_du_ciel() -> Spell:
	var s := Spell.new()
	s.spell_name = "Courroux du ciel"
	s.target_mode = Spell.TargetMode.SINGLE_ENEMY
	s.is_ev_cost_spell = true
	s.ev_cost_min = 1
	s.ev_cost_max = 20  # Plage non précisée dans les données d'origine.
	s.ev_x_divisor = 1  # Dégâts = X directement.
	s.spell_type = Spell.SpellType.PSYCHIC
	s.to_hit_modifier = 2
	s.min_range = 1
	s.max_range = 6
	return s

static func _build_arme_celeste() -> Spell:
	var s := Spell.new()
	s.spell_name = "Arme céleste"
	s.target_mode = Spell.TargetMode.SINGLE_ALLY
	s.is_ev_cost_spell = true
	s.ev_cost_min = 1
	s.ev_cost_max = 20  # Plage non précisée dans les données d'origine.
	s.ev_x_divisor = 5  # X/5 attaques rendues magiques.
	s.grants_weapon_magic_attacks = true
	s.spell_type = Spell.SpellType.PHYSICAL
	s.min_range = 1
	s.max_range = 6
	return s

static func _build_protection_divine() -> Spell:
	var s := Spell.new()
	s.spell_name = "Protection divine"
	s.target_mode = Spell.TargetMode.GROUP
	s.is_ev_cost_spell = true
	s.ev_cost_min = 1
	s.ev_cost_max = 20  # Plage non précisée dans les données d'origine.
	s.ev_x_divisor = 7  # +X/7 armure à chaque allié.
	s.grants_armor_buff = true
	s.spell_type = Spell.SpellType.PHYSICAL
	return s

static func _build_soin_majeur() -> Spell:
	var s := Spell.new()
	s.spell_name = "Soin des blessures majeures"
	s.target_mode = Spell.TargetMode.SINGLE_ALLY
	s.is_heal = true
	s.is_ev_cost_spell = true
	s.ev_cost_min = 4
	s.ev_cost_max = 50
	s.ev_x_divisor = 2
	s.ev_x_flat_bonus = 6
	s.spell_type = Spell.SpellType.PSYCHIC
	s.min_range = 1
	s.max_range = 6
	return s

static func _build_bouclier_de_paix() -> Spell:
	var s := Spell.new()
	s.spell_name = "Bouclier de paix"
	s.target_mode = Spell.TargetMode.SINGLE_ALLY
	s.is_ev_cost_spell = true
	s.ev_cost_min = 1
	s.ev_cost_max = 20  # Plage non précisée dans les données d'origine.
	s.ev_x_divisor = 5  # Invulnérabilité pendant X/5 tours.
	s.grants_shield_turns = true
	s.spell_type = Spell.SpellType.PSYCHIC
	s.min_range = 1
	s.max_range = 6
	return s

static func _build_jugement_divin() -> Spell:
	var s := Spell.new()
	s.spell_name = "Jugement divin"
	s.target_mode = Spell.TargetMode.ALL_ENEMIES
	s.is_ev_cost_spell = true
	s.ev_cost_min = 1
	s.ev_cost_max = 20  # Plage non précisée dans les données d'origine.
	s.ev_x_divisor = 1  # Dégâts = X directement, à CHAQUE ennemi.
	s.spell_type = Spell.SpellType.PSYCHIC
	return s

static func _build_grace_du_ciel() -> Spell:
	var s := Spell.new()
	s.spell_name = "Grâce du ciel"
	s.target_mode = Spell.TargetMode.SINGLE_ALLY
	s.is_walkyrie_resurrection = true
	s.ea_cost = 0  # Aucun coût pour la Walkyrie : le prix est payé par le ressuscité.
	s.info_text = "Ressuscite un allié mort (au choix). Il revient à 15 PV. La Walkyrie perd 15 PV MAX et 1 point d'une caractéristique aléatoire."
	return s

# Construit la liste de sorts pour un métier de cette branche —
# CUMULATIVE selon l'arborescence d'origine (voir metier_database.gd,
# Metier.parent_codes) : Compagnie du crépuscule / Légion céleste /
# Gardienne de l'aube héritent des 2 sorts de base Walkyrie ; Archange
# hérite de TOUT (ses 3 parents + ses 2 sorts propres). Renvoie un
# tableau vide si `metier_name` n'est pas dans cette branche.
static func build_for_metier(metier_name: String) -> Array:
	return MetierSpellIcons.apply(_build_for_metier_raw(metier_name))

static func _build_for_metier_raw(metier_name: String) -> Array:
	var walkyrie_base := [_build_soin_leger(), _build_rayon_de_lumiere()]

	match metier_name:
		"Walkyrie":
			return walkyrie_base
		"Compagnie du crépuscule":
			return walkyrie_base + [_build_laser_purificateur(), _build_courroux_du_ciel()]
		"Légion céleste":
			return walkyrie_base + [_build_arme_celeste(), _build_protection_divine()]
		"Gardienne de l'aube":
			return walkyrie_base + [_build_soin_majeur(), _build_bouclier_de_paix()]
		"Archange":
			return walkyrie_base + [
				_build_laser_purificateur(), _build_courroux_du_ciel(),
				_build_arme_celeste(), _build_protection_divine(),
				_build_soin_majeur(), _build_bouclier_de_paix(),
				_build_jugement_divin(), _build_grace_du_ciel(),
			]
		_:
			return []
