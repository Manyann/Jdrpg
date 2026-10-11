extends RefCounted
class_name MageSpellCatalog

# ============================================================
# mage_spell_catalog.gd — GÉNÉRÉ à partir du catalogue de 75 sorts
# du Mage (branches élémentaires : Feu, Eau, Air, Terre, et leurs
# combinaisons). build_all() renvoie un Array[Spell] complet, à
# assigner à unit.spells pour la classe Mage.
#
# HYPOTHÈSES faites faute de données précises dans le catalogue
# d'origine (à ajuster si besoin) :
# - Portée : 1 à 5 cases pour tous les sorts à ciblage (le catalogue
#   ne précise aucune portée par sort).
# - Durée par défaut d'une Brûlure sans DS explicite : 4 tours.
# - "STATS -N" (Ere glaciaire) : s'applique aux 8 stats principales,
#   pas à Armure/PV/Mana.
#
# SORTS NON AUTOMATISABLES (19/75) : importés mais SANS effet
# mécanique — juste le texte d'origine affiché au lancer, en
# attendant du code sur-mesure. Listés en bas de ce fichier.
# ============================================================

func _build_boule_de_feu_mineure() -> Spell:
	var s := Spell.new()
	s.spell_name = "Boule de feu mineure"
	s.elements = ["Feu"]
	s.ea_cost = 2
	s.spell_type = Spell.SpellType.PHYSICAL
	s.target_mode = Spell.TargetMode.SINGLE_ENEMY
	s.min_range = 1
	s.max_range = 6  # Portée non précisée par le catalogue d'origine — 1 à 6 par défaut.
	s.dice_terms = [{"count": 1, "sides": 6, "modifier": 4}]
	s.effect_sprite_path = "res://assets/vfx/feu_sheet.png"
	s.effect_start_x = 205
	s.effect_row = 0
	s.effect_frame_size = Vector2i(190, 256)
	s.effect_frame_count = 7
	return s

func _build_aura_de_feu() -> Spell:
	var s := Spell.new()
	s.spell_name = "Aura de feu"
	s.elements = ["Feu"]
	s.ea_cost = 2
	s.spell_type = Spell.SpellType.PSYCHIC
	s.target_mode = Spell.TargetMode.SINGLE_ALLY
	s.min_range = 1
	s.max_range = 6  # Portée non précisée par le catalogue d'origine — 1 à 6 par défaut.
	var effect := StatusEffect.new()
	effect.effect_name = "Aura de feu"
	effect.duration_remaining = -1  # Pas de DS précisé : permanent (jusqu'à la fin du combat).
	effect.reflect_dice_terms = [{"count": 1, "sides": 4, "modifier": 0}]
	s.effect_to_apply = effect
	return s

func _build_cone_de_feu() -> Spell:
	var s := Spell.new()
	s.spell_name = "Cone de feu"
	s.elements = ["Feu"]
	s.ea_cost = 3
	s.spell_type = Spell.SpellType.PHYSICAL
	s.target_mode = Spell.TargetMode.ZONE
	s.zone_offsets = ZoneShapes.CONE_DE_FEU.duplicate()  # Forme et ancre : voir zone_shapes.gd.
	s.min_range = 1
	s.max_range = 6  # Portée non précisée par le catalogue d'origine — 1 à 6 par défaut.
	s.dice_terms = [{"count": 2, "sides": 6, "modifier": 2}]
	s.effect_sprite_path = "res://assets/vfx/feu_sheet.png"
	s.effect_start_x = 205
	s.effect_row = 768
	s.effect_frame_size = Vector2i(190, 256)
	s.effect_frame_count = 7
	return s

func _build_boule_de_feu_majeure() -> Spell:
	var s := Spell.new()
	s.spell_name = "Boule de feu majeure"
	s.elements = ["Feu"]
	s.ea_cost = 3
	s.spell_type = Spell.SpellType.PHYSICAL
	s.target_mode = Spell.TargetMode.SINGLE_ENEMY
	s.min_range = 1
	s.max_range = 6  # Portée non précisée par le catalogue d'origine — 1 à 6 par défaut.
	s.dice_terms = [{"count": 1, "sides": 6, "modifier": 6}]
	s.effect_sprite_path = "res://assets/vfx/feu_sheet.png"
	s.effect_start_x = 205
	s.effect_row = 256
	s.effect_frame_size = Vector2i(190, 256)
	s.effect_frame_count = 7
	return s

func _build_feu_follet() -> Spell:
	var s := Spell.new()
	s.spell_name = "Feu follet"
	s.elements = ["Feu"]
	s.ea_cost = 5
	s.spell_type = Spell.SpellType.PHYSICAL
	s.target_mode = Spell.TargetMode.SINGLE_ENEMY
	s.min_range = 1
	s.max_range = 6  # Portée non précisée par le catalogue d'origine — 1 à 6 par défaut.
	s.cast_delay = 1
	s.dice_terms = [{"count": 2, "sides": 6, "modifier": 2}, {"count": 1, "sides": 6, "modifier": 0}]
	s.effect_sprite_path = "res://assets/vfx/feu_sheet.png"
	s.effect_start_x = 205
	s.effect_row = 512
	s.effect_frame_size = Vector2i(190, 256)
	s.effect_frame_count = 7
	return s

func _build_phoenix() -> Spell:
	var s := Spell.new()
	s.spell_name = "Phoenix"
	s.elements = ["Feu"]
	s.ea_cost = 7
	s.spell_type = Spell.SpellType.PSYCHIC
	s.is_summon = true
	s.summon_name = "Phoenix"
	s.summon_max_hp = 15
	s.summon_attack_parade = 8
	s.summon_armor = 1
	s.summon_dice_count = 1
	s.summon_dice_modifier = 5
	s.cast_delay = 2
	s.summon_color = Color(0.9, 0.35, 0.15)
	s.min_range = 1
	s.max_range = 6  # Même règle de portée que les autres sorts (1 à 6).
	return s

func _build_prom_th_e_elementaire_de_feu() -> Spell:
	var s := Spell.new()
	s.spell_name = "Prométhée (Elementaire de feu)"
	s.elements = ["Feu"]
	s.ea_cost = 10
	s.spell_type = Spell.SpellType.PHYSICAL
	s.is_summon = true
	s.summon_name = "Prométhée (Elementaire de feu)"
	s.summon_max_hp = 25
	s.summon_attack_parade = 10
	s.summon_armor = 2
	s.summon_dice_count = 2
	s.summon_dice_modifier = 4
	s.cast_delay = 2
	s.summon_color = Color(0.9, 0.35, 0.15)
	s.min_range = 1
	s.max_range = 6  # Même règle de portée que les autres sorts (1 à 6).
	return s

func _build_soin_mineur() -> Spell:
	var s := Spell.new()
	s.spell_name = "Soin mineur"
	s.elements = ["Eau"]
	s.ea_cost = 2
	s.spell_type = Spell.SpellType.PSYCHIC
	s.target_mode = Spell.TargetMode.SINGLE_ALLY
	s.min_range = 1
	s.max_range = 6  # Portée non précisée par le catalogue d'origine — 1 à 6 par défaut.
	s.dice_terms = [{"count": 1, "sides": 6, "modifier": 1}]
	s.is_heal = true
	return s

func _build_restauration_pa() -> Spell:
	var s := Spell.new()
	s.spell_name = "Restauration PA"
	s.elements = ["Eau"]
	s.ea_cost = 2
	s.spell_type = Spell.SpellType.PSYCHIC
	s.target_mode = Spell.TargetMode.SINGLE_ALLY
	s.min_range = 1
	s.max_range = 6  # Portée non précisée par le catalogue d'origine — 1 à 6 par défaut.
	s.dice_terms = [{"count": 1, "sides": 4, "modifier": 2}]
	s.is_heal = true
	s.restores_mana = true  # "Rend X PA" : restaure EA, pas PV.
	return s

func _build_mur_d_eau() -> Spell:
	var s := Spell.new()
	s.spell_name = "Mur d eau"
	s.elements = ["Eau"]
	s.ea_cost = 2
	s.spell_type = Spell.SpellType.PHYSICAL
	s.min_range = 1
	s.max_range = 6  # Portée non précisée par le catalogue d'origine — 1 à 6 par défaut.
	s.creates_obstacle_line = true
	return s

func _build_purge() -> Spell:
	var s := Spell.new()
	s.spell_name = "Purge"
	s.elements = ["Eau"]
	s.ea_cost = 4
	s.spell_type = Spell.SpellType.PSYCHIC
	s.target_mode = Spell.TargetMode.SINGLE_ALLY
	s.min_range = 1
	s.max_range = 6  # Portée non précisée par le catalogue d'origine — 1 à 6 par défaut.
	s.cleanses_effects = true
	return s

func _build_soin_majeur() -> Spell:
	var s := Spell.new()
	s.spell_name = "Soin majeur"
	s.elements = ["Eau"]
	s.ea_cost = 4
	s.spell_type = Spell.SpellType.PSYCHIC
	s.target_mode = Spell.TargetMode.SINGLE_ALLY
	s.min_range = 1
	s.max_range = 6  # Portée non précisée par le catalogue d'origine — 1 à 6 par défaut.
	s.dice_terms = [{"count": 2, "sides": 6, "modifier": 2}, {"count": 1, "sides": 4, "modifier": 0}]
	s.is_heal = true
	return s

func _build_ras_de_mar_e() -> Spell:
	var s := Spell.new()
	s.spell_name = "Ras de marée"
	s.elements = ["Eau"]
	s.ea_cost = 10
	s.spell_type = Spell.SpellType.PHYSICAL
	s.target_mode = Spell.TargetMode.ZONE
	s.zone_offsets = ZoneShapes.RAS_DE_MAREE.duplicate()  # Forme et ancre : voir zone_shapes.gd.
	s.min_range = 1
	s.max_range = 6  # Portée non précisée par le catalogue d'origine — 1 à 6 par défaut.
	s.cast_delay = 2
	s.dice_terms = [{"count": 5, "sides": 6, "modifier": 4}]
	return s

func _build_aliz() -> Spell:
	var s := Spell.new()
	s.spell_name = "Alizé"
	s.elements = ["Air"]
	s.ea_cost = 4
	s.spell_type = Spell.SpellType.PSYCHIC
	s.target_mode = Spell.TargetMode.SINGLE_ALLY
	s.min_range = 1
	s.max_range = 6  # Portée non précisée par le catalogue d'origine — 1 à 6 par défaut.
	var effect := StatusEffect.new()
	effect.effect_name = "Alizé"
	effect.duration_remaining = -1
	effect.bonus_adresse = 2
	s.effect_to_apply = effect
	return s

func _build_mistral() -> Spell:
	var s := Spell.new()
	s.spell_name = "Mistral"
	s.elements = ["Air"]
	s.ea_cost = 4
	s.spell_type = Spell.SpellType.PHYSICAL
	s.target_mode = Spell.TargetMode.SINGLE_ENEMY
	s.min_range = 1
	s.max_range = 6  # Portée non précisée par le catalogue d'origine — 1 à 6 par défaut.
	s.cast_delay = 1
	s.stun_turns = 2
	return s

func _build_z_phir() -> Spell:
	var s := Spell.new()
	s.spell_name = "Zéphir"
	s.elements = ["Air"]
	s.ea_cost = 3
	s.spell_type = Spell.SpellType.PSYCHIC
	s.target_mode = Spell.TargetMode.SINGLE_ALLY
	s.min_range = 1
	s.max_range = 6  # Portée non précisée par le catalogue d'origine — 1 à 6 par défaut.
	var effect := StatusEffect.new()
	effect.effect_name = "Zéphir"
	effect.duration_remaining = -1  # Pas de DS précisé : permanent (jusqu'à la fin du combat).
	effect.bonus_weapon_dice_count = 1
	effect.bonus_weapon_dice_modifier = 4
	effect.bonus_weapon_dice_ranged_only = true
	s.effect_to_apply = effect
	return s

func _build_libeccio() -> Spell:
	var s := Spell.new()
	s.spell_name = "Libeccio"
	s.elements = ["Air"]
	s.ea_cost = 2
	s.spell_type = Spell.SpellType.PHYSICAL
	s.target_mode = Spell.TargetMode.SINGLE_ENEMY
	s.min_range = 1
	s.max_range = 6  # Portée non précisée par le catalogue d'origine — 1 à 6 par défaut.
	s.dice_terms = [{"count": 1, "sides": 6, "modifier": 6}]
	return s

func _build_su_tes() -> Spell:
	var s := Spell.new()
	s.spell_name = "Suêtes"
	s.elements = ["Air"]
	s.ea_cost = 4
	s.spell_type = Spell.SpellType.PHYSICAL
	s.target_mode = Spell.TargetMode.SINGLE_ENEMY
	s.min_range = 1
	s.max_range = 6  # Portée non précisée par le catalogue d'origine — 1 à 6 par défaut.
	s.dice_terms = [{"count": 2, "sides": 6, "modifier": 2}]
	return s

func _build_bise() -> Spell:
	var s := Spell.new()
	s.spell_name = "Bise"
	s.elements = ["Air"]
	s.ea_cost = 4
	s.spell_type = Spell.SpellType.PSYCHIC
	s.target_mode = Spell.TargetMode.SINGLE_ALLY
	s.min_range = 1
	s.max_range = 6  # Portée non précisée par le catalogue d'origine — 1 à 6 par défaut.
	s.cast_delay = 1
	var effect := StatusEffect.new()
	effect.effect_name = "Bise"
	effect.duration_remaining = -1
	effect.bonus_attaque = 1
	effect.bonus_parade = 1
	s.effect_to_apply = effect
	return s

func _build_eurus() -> Spell:
	var s := Spell.new()
	s.spell_name = "Eurus"
	s.elements = ["Air"]
	s.ea_cost = 7
	s.spell_type = Spell.SpellType.PSYCHIC
	s.target_mode = Spell.TargetMode.SINGLE_ENEMY
	s.min_range = 1
	s.max_range = 6  # Portée non précisée par le catalogue d'origine — 1 à 6 par défaut.
	s.cast_delay = 2
	s.dice_terms = [{"count": 2, "sides": 6, "modifier": 4}]
	return s

func _build_armure_de_terre() -> Spell:
	var s := Spell.new()
	s.spell_name = "Armure de terre"
	s.elements = ["Terre"]
	s.ea_cost = 4
	s.spell_type = Spell.SpellType.PHYSICAL
	s.target_mode = Spell.TargetMode.SINGLE_ALLY
	s.min_range = 1
	s.max_range = 6  # Portée non précisée par le catalogue d'origine — 1 à 6 par défaut.
	var effect := StatusEffect.new()
	effect.effect_name = "Armure de terre"
	effect.duration_remaining = -1
	effect.bonus_armure = 2
	s.effect_to_apply = effect
	return s

func _build_poings_de_terre() -> Spell:
	var s := Spell.new()
	s.spell_name = "Poings de terre"
	s.elements = ["Terre"]
	s.ea_cost = 2
	s.spell_type = Spell.SpellType.PHYSICAL
	s.target_mode = Spell.TargetMode.SELF
	var effect := StatusEffect.new()
	effect.effect_name = "Poings de terre"
	effect.duration_remaining = -1  # Pas de DS précisé : permanent (jusqu'à la fin du combat).
	effect.bonus_weapon_dice_count = 1
	effect.bonus_weapon_dice_modifier = 4
	# SIMPLIFICATION ASSUMÉE : censé ne s'appliquer QUE mains nues (le
	# catalogue dit "sans arme"), mais notre système de bonus ne fait
	# pas cette distinction — s'applique à toute attaque au corps à
	# corps, arme ou pas.
	s.effect_to_apply = effect
	return s

func _build_soldat_de_terre() -> Spell:
	var s := Spell.new()
	s.spell_name = "Soldat de terre"
	s.elements = ["Terre"]
	s.ea_cost = 3
	s.spell_type = Spell.SpellType.PHYSICAL
	s.is_summon = true
	s.summon_name = "Soldat de terre"
	s.summon_max_hp = 15
	s.summon_attack_parade = 8
	s.summon_armor = 1
	s.summon_dice_count = 1
	s.summon_dice_modifier = 5
	s.summon_color = Color(0.55, 0.4, 0.2)
	s.min_range = 1
	s.max_range = 6  # Même règle de portée que les autres sorts (1 à 6).
	return s

func _build_pluie_de_pierre() -> Spell:
	var s := Spell.new()
	s.spell_name = "Pluie de pierre"
	s.elements = ["Terre"]
	s.ea_cost = 4
	s.spell_type = Spell.SpellType.PHYSICAL
	s.target_mode = Spell.TargetMode.ZONE
	s.zone_offsets = ZoneShapes.PLUIE_DE_PIERRES.duplicate()  # Forme et ancre : voir zone_shapes.gd.
	s.min_range = 1
	s.max_range = 6  # Portée non précisée par le catalogue d'origine — 1 à 6 par défaut.
	s.dice_terms = [{"count": 3, "sides": 6, "modifier": 0}]
	return s

func _build_golem_de_pierre() -> Spell:
	var s := Spell.new()
	s.spell_name = "Golem de pierre"
	s.elements = ["Terre"]
	s.ea_cost = 6
	s.spell_type = Spell.SpellType.PHYSICAL
	s.is_summon = true
	s.summon_name = "Golem de pierre"
	s.summon_max_hp = 30
	s.summon_attack_parade = 6
	s.summon_armor = 6
	s.summon_dice_count = 2
	s.summon_dice_modifier = 4
	s.summon_color = Color(0.55, 0.4, 0.2)
	s.min_range = 1
	s.max_range = 6  # Même règle de portée que les autres sorts (1 à 6).
	return s

func _build_m_t_ore() -> Spell:
	var s := Spell.new()
	s.spell_name = "Météore"
	s.elements = ["Terre"]
	s.ea_cost = 10
	s.spell_type = Spell.SpellType.PHYSICAL
	s.target_mode = Spell.TargetMode.ZONE
	s.zone_offsets = ZoneShapes.METEORE.duplicate()  # Forme et ancre : voir zone_shapes.gd.
	s.min_range = 1
	s.max_range = 6  # Portée non précisée par le catalogue d'origine — 1 à 6 par défaut.
	s.dice_terms = [{"count": 5, "sides": 6, "modifier": 4}]
	return s

func _build_evaporation_d_eau() -> Spell:
	var s := Spell.new()
	s.spell_name = "Evaporation d'eau"
	s.elements = ["Eau", "Feu"]
	s.ea_cost = 2
	s.spell_type = Spell.SpellType.PSYCHIC
	s.min_range = 1
	s.max_range = 6  # Portée non précisée par le catalogue d'origine — 1 à 6 par défaut.
	s.removes_obstacle_type = ObstacleType.EAU
	s.max_terrain_cells = 4  # "Carré de 2x2" : jusqu'à 4 cases choisies une par une par le joueur.
	return s

func _build_jet_d_eau_brulante() -> Spell:
	var s := Spell.new()
	s.spell_name = "Jet d'eau brulante"
	s.elements = ["Eau", "Feu"]
	s.ea_cost = 3
	s.spell_type = Spell.SpellType.PHYSICAL
	s.target_mode = Spell.TargetMode.SINGLE_ENEMY
	s.min_range = 1
	s.max_range = 6  # Portée non précisée par le catalogue d'origine — 1 à 6 par défaut.
	s.dice_terms = [{"count": 1, "sides": 6, "modifier": 4}]
	var burn := StatusEffect.new()
	burn.effect_name = "Brûlure (Jet d'eau brulante)"
	burn.duration_remaining = -1
	burn.tick_every_other_turn = true
	burn.damage_per_tick = 2  # Moyenne de 1D4 (la brûlure n'a pas de vrai jet de dés, juste un montant fixe par tick).
	if s.effect_to_apply != null:
		s.effect_to_apply = burn  # Un seul effect_to_apply à la fois : la brûlure prend le dessus ici.
	else:
		s.effect_to_apply = burn
	return s

func _build_nuage_de_vapeur() -> Spell:
	var s := Spell.new()
	s.spell_name = "Nuage de vapeur"
	s.elements = ["Eau", "Feu"]
	s.ea_cost = 5
	s.spell_type = Spell.SpellType.PHYSICAL
	s.target_mode = Spell.TargetMode.ZONE
	s.zone_offsets = ZoneShapes.NUAGE_DE_VAPEUR.duplicate()  # Forme et ancre : voir zone_shapes.gd.
	s.min_range = 1
	s.max_range = 6  # Portée non précisée par le catalogue d'origine — 1 à 6 par défaut.
	s.dice_terms = [{"count": 2, "sides": 6, "modifier": 4}]
	var burn := StatusEffect.new()
	burn.effect_name = "Brûlure (Nuage de vapeur)"
	burn.duration_remaining = -1
	burn.tick_every_other_turn = true
	burn.damage_per_tick = 2  # Moyenne de 1D4 (la brûlure n'a pas de vrai jet de dés, juste un montant fixe par tick).
	if s.effect_to_apply != null:
		s.effect_to_apply = burn  # Un seul effect_to_apply à la fois : la brûlure prend le dessus ici.
	else:
		s.effect_to_apply = burn
	return s

func _build_evaporation_de_l_eau_d_un_corps() -> Spell:
	var s := Spell.new()
	s.spell_name = "Evaporation de l'eau d'un corps"
	s.elements = ["Eau", "Feu"]
	s.ea_cost = 6
	s.spell_type = Spell.SpellType.PSYCHIC
	s.target_mode = Spell.TargetMode.SINGLE_ENEMY
	s.min_range = 1
	s.max_range = 6  # Portée non précisée par le catalogue d'origine — 1 à 6 par défaut.
	s.cast_delay = 1
	s.dice_terms = [{"count": 3, "sides": 6, "modifier": 2}]
	return s

func _build_geyser() -> Spell:
	var s := Spell.new()
	s.spell_name = "Geyser"
	s.elements = ["Eau", "Feu"]
	s.ea_cost = 13
	s.spell_type = Spell.SpellType.PHYSICAL
	s.target_mode = Spell.TargetMode.SINGLE_ENEMY
	s.min_range = 1
	s.max_range = 6  # Portée non précisée par le catalogue d'origine — 1 à 6 par défaut.
	s.cast_delay = 2
	s.dice_terms = [{"count": 6, "sides": 6, "modifier": 6}]
	return s

func _build_bombe_volcanique() -> Spell:
	var s := Spell.new()
	s.spell_name = "Bombe volcanique"
	s.elements = ["Terre", "Feu"]
	s.ea_cost = 3
	s.spell_type = Spell.SpellType.PHYSICAL
	s.target_mode = Spell.TargetMode.SINGLE_ENEMY
	s.min_range = 1
	s.max_range = 6  # Portée non précisée par le catalogue d'origine — 1 à 6 par défaut.
	return s

func _build_er_be() -> Spell:
	var s := Spell.new()
	s.spell_name = "Erèbe"
	s.elements = ["Terre", "Feu"]
	s.ea_cost = 3
	s.spell_type = Spell.SpellType.PSYCHIC
	s.target_mode = Spell.TargetMode.BATTLEFIELD  # Toutes les unités du champ de bataille, les deux camps.
	s.min_range = 1
	s.max_range = 6  # Portée non précisée par le catalogue d'origine — 1 à 6 par défaut.
	s.requires_missing_nyctalopie = true
	var effect := StatusEffect.new()
	effect.effect_name = "Erèbe (obscurité)"
	effect.duration_remaining = -1  # Pas de DS précisé : permanent (jusqu'à la fin du combat).
	effect.bonus_adresse = -2
	effect.bonus_attaque = -2
	effect.bonus_parade = -2
	s.effect_to_apply = effect
	return s

func _build_hephaistos() -> Spell:
	var s := Spell.new()
	s.spell_name = "Hephaistos"
	s.elements = ["Terre", "Feu"]
	s.ea_cost = 4
	s.spell_type = Spell.SpellType.PHYSICAL
	s.target_mode = Spell.TargetMode.SINGLE_ENEMY
	s.min_range = 1
	s.max_range = 6  # Portée non précisée par le catalogue d'origine — 1 à 6 par défaut.
	var effect := StatusEffect.new()
	effect.effect_name = "Hephaistos"
	effect.duration_remaining = -1
	effect.bonus_armure = -3
	s.effect_to_apply = effect
	return s

func _build_nu_e_ardente() -> Spell:
	var s := Spell.new()
	s.spell_name = "Nuée ardente"
	s.elements = ["Terre", "Feu"]
	s.ea_cost = 6
	s.spell_type = Spell.SpellType.PSYCHIC
	s.target_mode = Spell.TargetMode.ZONE
	s.zone_offsets = ZoneShapes.NUEE_ARDENTE.duplicate()  # Forme et ancre : voir zone_shapes.gd.
	s.min_range = 1
	s.max_range = 6  # Portée non précisée par le catalogue d'origine — 1 à 6 par défaut.
	s.cast_delay = 1
	s.dice_terms = [{"count": 1, "sides": 6, "modifier": 5}]
	return s

func _build_pluie_pyroclastique() -> Spell:
	var s := Spell.new()
	s.spell_name = "Pluie pyroclastique"
	s.elements = ["Terre", "Feu"]
	s.ea_cost = 8
	s.spell_type = Spell.SpellType.PHYSICAL
	s.target_mode = Spell.TargetMode.ZONE
	s.zone_offsets = ZoneShapes.PLUIE_PYROCLASTIQUE.duplicate()  # Forme et ancre : voir zone_shapes.gd.
	s.min_range = 1
	s.max_range = 6  # Portée non précisée par le catalogue d'origine — 1 à 6 par défaut.
	s.dice_terms = [{"count": 2, "sides": 6, "modifier": 2}, {"count": 1, "sides": 4, "modifier": 2}]
	return s

func _build_royaume_des_enfers() -> Spell:
	var s := Spell.new()
	s.spell_name = "Royaume des enfers"
	s.elements = ["Terre", "Feu"]
	s.ea_cost = 15
	s.spell_type = Spell.SpellType.PSYCHIC
	s.target_mode = Spell.TargetMode.ZONE
	s.zone_offsets = ZoneShapes.ROYAUME_DES_ENFERS.duplicate()  # Forme et ancre : voir zone_shapes.gd.
	s.min_range = 1
	s.max_range = 6  # Portée non précisée par le catalogue d'origine — 1 à 6 par défaut.
	s.cast_delay = 3
	s.dice_terms = [{"count": 3, "sides": 6, "modifier": 0}, {"count": 2, "sides": 6, "modifier": 4}]
	return s

func _build_arges() -> Spell:
	var s := Spell.new()
	s.spell_name = "Arges"
	s.elements = ["Air", "Feu"]
	s.ea_cost = 4
	s.spell_type = Spell.SpellType.PSYCHIC
	s.target_mode = Spell.TargetMode.SINGLE_ENEMY
	s.min_range = 1
	s.max_range = 6  # Portée non précisée par le catalogue d'origine — 1 à 6 par défaut.
	s.dice_terms = [{"count": 2, "sides": 6, "modifier": 3}]
	s.effect_sprite_path = "res://assets/vfx/eclair_mineur_sheet.png"
	s.effect_start_x = 0
	s.effect_row = 0
	s.effect_frame_size = Vector2i(32, 32)
	s.effect_frame_count = 36
	s.effect_fps = 24.0  # 36 frames, sort rapide — plus véloce que le défaut (14 fps) pour ne pas traîner.
	s.effect_scale = 2.0  # Frames natives 32x32, bien plus petites que les autres planches (190x256...) — agrandi pour rester visible.
	return s

func _build_enchantement() -> Spell:
	var s := Spell.new()
	s.spell_name = "Enchantement"
	s.elements = ["Air", "Feu"]
	s.ea_cost = 5
	s.spell_type = Spell.SpellType.PSYCHIC
	s.target_mode = Spell.TargetMode.SINGLE_ALLY
	s.min_range = 1
	s.max_range = 6  # Portée non précisée par le catalogue d'origine — 1 à 6 par défaut.
	s.cast_delay = 1
	var effect := StatusEffect.new()
	effect.effect_name = "Enchantement"
	effect.duration_remaining = -1  # Pas de DS précisé : permanent (jusqu'à la fin du combat).
	effect.bonus_weapon_dice_count = 1
	effect.bonus_weapon_dice_modifier = 0
	# SIMPLIFICATION ASSUMÉE : "+1D magique" — notre système de bonus
	# d'arme ne distingue pas dégâts physiques/magiques par coup, le
	# bonus s'ajoute simplement aux dégâts d'arme normaux.
	s.effect_to_apply = effect
	return s

func _build_vajra() -> Spell:
	var s := Spell.new()
	s.spell_name = "Vajra"
	s.elements = ["Air", "Feu"]
	s.ea_cost = 7
	s.spell_type = Spell.SpellType.PSYCHIC
	s.target_mode = Spell.TargetMode.SELF
	s.cast_delay = 1
	s.conjures_weapon = true
	s.conjured_weapon_name = "Épée de foudre"
	s.conjured_weapon_dice_count = 2
	s.conjured_weapon_dice_modifier = 1
	s.conjured_weapon_bonus_attaque = 2
	s.conjured_weapon_bonus_parade = 2
	return s

func _build_flash() -> Spell:
	var s := Spell.new()
	s.spell_name = "Flash"
	s.elements = ["Air", "Feu"]
	s.ea_cost = 4
	s.spell_type = Spell.SpellType.PSYCHIC
	s.target_mode = Spell.TargetMode.SINGLE_ENEMY
	s.min_range = 1
	s.max_range = 6  # Portée non précisée par le catalogue d'origine — 1 à 6 par défaut.
	var effect := StatusEffect.new()
	effect.effect_name = "Flash"
	effect.duration_remaining = 2
	effect.bonus_attaque = -2
	effect.bonus_parade = -2
	s.effect_to_apply = effect
	return s

func _build_eclair_en_chaine() -> Spell:
	var s := Spell.new()
	s.spell_name = "Eclair en chaine"
	s.elements = ["Air", "Feu"]
	s.ea_cost = 7
	s.spell_type = Spell.SpellType.PHYSICAL
	s.target_mode = Spell.TargetMode.ZONE
	s.zone_offsets = ZoneShapes.ECLAIR_EN_CHAINE.duplicate()  # Forme et ancre : voir zone_shapes.gd.
	s.min_range = 1
	s.max_range = 6  # Portée non précisée par le catalogue d'origine — 1 à 6 par défaut.
	s.cast_delay = 1
	s.dice_terms = [{"count": 2, "sides": 6, "modifier": 3}]
	return s

func _build_brontes() -> Spell:
	var s := Spell.new()
	s.spell_name = "Brontes"
	s.elements = ["Air", "Feu"]
	s.ea_cost = 9
	s.spell_type = Spell.SpellType.PSYCHIC
	s.target_mode = Spell.TargetMode.SINGLE_ENEMY
	s.min_range = 1
	s.max_range = 6  # Portée non précisée par le catalogue d'origine — 1 à 6 par défaut.
	s.cast_delay = 1
	s.dice_terms = [{"count": 3, "sides": 6, "modifier": 4}]
	s.effect_sprite_path = "res://assets/vfx/eclair_moyen_sheet.png"
	s.effect_start_x = 0
	s.effect_row = 0
	s.effect_frame_size = Vector2i(32, 32)
	s.effect_frame_count = 36
	s.effect_fps = 24.0
	s.effect_scale = 2.0
	return s

func _build_steropes() -> Spell:
	var s := Spell.new()
	s.spell_name = "Steropes"
	s.elements = ["Air", "Feu"]
	s.ea_cost = 10
	s.spell_type = Spell.SpellType.PSYCHIC
	s.target_mode = Spell.TargetMode.SINGLE_ENEMY
	s.min_range = 1
	s.max_range = 6  # Portée non précisée par le catalogue d'origine — 1 à 6 par défaut.
	s.cast_delay = 1
	s.unavoidable = true
	s.dice_terms = [{"count": 5, "sides": 6, "modifier": 0}]
	s.effect_sprite_path = "res://assets/vfx/eclair_majeur_sheet.png"
	s.effect_start_x = 0
	s.effect_row = 0
	s.effect_frame_size = Vector2i(32, 32)
	s.effect_frame_count = 36
	s.effect_fps = 24.0
	s.effect_scale = 2.0
	return s

func _build_tapis_de_ronce() -> Spell:
	var s := Spell.new()
	s.spell_name = "Tapis de ronce"
	s.elements = ["Terre", "Eau"]
	s.ea_cost = 3
	s.spell_type = Spell.SpellType.PHYSICAL
	s.target_mode = Spell.TargetMode.SINGLE_ENEMY
	s.min_range = 1
	s.max_range = 6  # Portée non précisée par le catalogue d'origine — 1 à 6 par défaut.
	var effect := StatusEffect.new()
	effect.effect_name = "Tapis de ronce"
	effect.duration_remaining = -1
	effect.bonus_adresse = -3
	s.effect_to_apply = effect
	return s

func _build_lasso_de_lianes() -> Spell:
	var s := Spell.new()
	s.spell_name = "Lasso de lianes"
	s.elements = ["Terre", "Eau"]
	s.ea_cost = 3
	s.spell_type = Spell.SpellType.PHYSICAL
	s.target_mode = Spell.TargetMode.SINGLE_ENEMY
	s.min_range = 1
	s.max_range = 6  # Portée non précisée par le catalogue d'origine — 1 à 6 par défaut.
	s.dice_terms = [{"count": 1, "sides": 6, "modifier": 8}]
	return s

func _build_immobilisation() -> Spell:
	var s := Spell.new()
	s.spell_name = "Immobilisation"
	s.elements = ["Terre", "Eau"]
	s.ea_cost = 6
	s.spell_type = Spell.SpellType.PHYSICAL
	s.target_mode = Spell.TargetMode.SINGLE_ENEMY
	s.min_range = 1
	s.max_range = 6  # Portée non précisée par le catalogue d'origine — 1 à 6 par défaut.
	var effect := StatusEffect.new()
	effect.effect_name = "Immobilisation"
	effect.duration_remaining = -1
	effect.bonus_attaque = -3
	s.effect_to_apply = effect
	return s

func _build_revitalisation() -> Spell:
	var s := Spell.new()
	s.spell_name = "Revitalisation"
	s.elements = ["Terre", "Eau"]
	s.ea_cost = 5
	s.spell_type = Spell.SpellType.PSYCHIC
	s.target_mode = Spell.TargetMode.GROUP
	var effect := StatusEffect.new()
	effect.effect_name = "Revitalisation"
	effect.duration_remaining = -1
	effect.bonus_courage = 2
	effect.bonus_force = 2
	s.effect_to_apply = effect
	return s

func _build_membre_v_g_tal() -> Spell:
	var s := Spell.new()
	s.spell_name = "Pont végétal"  # Remplace "Membre végétal" (voir consigne).
	s.elements = ["Terre", "Eau"]
	s.ea_cost = 8
	s.spell_type = Spell.SpellType.PHYSICAL
	s.min_range = 1
	s.max_range = 6  # Portée non précisée par le catalogue d'origine — 1 à 6 par défaut.
	s.creates_bridge_line = true
	return s

func _build_jeune_ent() -> Spell:
	var s := Spell.new()
	s.spell_name = "Jeune Ent"
	s.elements = ["Terre", "Eau"]
	s.ea_cost = 12
	s.spell_type = Spell.SpellType.PHYSICAL
	s.is_summon = true
	s.summon_name = "Jeune Ent"
	s.summon_max_hp = 40
	s.summon_attack_parade = 8
	s.summon_armor = 2
	s.summon_dice_count = 3
	s.summon_dice_modifier = 0
	s.summon_color = Color(0.3, 0.6, 0.2)
	s.min_range = 1
	s.max_range = 6  # Même règle de portée que les autres sorts (1 à 6).
	return s

func _build_ent_adulte() -> Spell:
	var s := Spell.new()
	s.spell_name = "Ent adulte"
	s.elements = ["Terre", "Eau"]
	s.ea_cost = 16
	s.spell_type = Spell.SpellType.PHYSICAL
	s.is_summon = true
	s.summon_name = "Ent adulte"
	s.summon_max_hp = 50
	s.summon_attack_parade = 9
	s.summon_armor = 3
	s.summon_dice_count = 3
	s.summon_dice_modifier = 4
	s.summon_color = Color(0.3, 0.6, 0.2)
	s.min_range = 1
	s.max_range = 6  # Même règle de portée que les autres sorts (1 à 6).
	return s

func _build_jet_de_poussiere() -> Spell:
	var s := Spell.new()
	s.spell_name = "Jet de poussiere"
	s.elements = ["Terre", "Air"]
	s.ea_cost = 6
	s.spell_type = Spell.SpellType.PHYSICAL
	s.target_mode = Spell.TargetMode.SINGLE_ENEMY
	s.min_range = 1
	s.max_range = 6  # Portée non précisée par le catalogue d'origine — 1 à 6 par défaut.
	var effect := StatusEffect.new()
	effect.effect_name = "Jet de poussiere"
	effect.duration_remaining = 3
	effect.bonus_parade = -3
	s.effect_to_apply = effect
	return s

func _build_ecran_de_poussiere() -> Spell:
	var s := Spell.new()
	s.spell_name = "Ecran de poussiere"
	s.elements = ["Terre", "Air"]
	s.ea_cost = 2
	s.spell_type = Spell.SpellType.PHYSICAL
	s.target_mode = Spell.TargetMode.ZONE
	s.zone_offsets = ZoneShapes.ECRAN_DE_POUSSIERE.duplicate()  # Forme et ancre : voir zone_shapes.gd.
	s.min_range = 1
	s.max_range = 6  # Portée d'ancrage — non précisée par le catalogue d'origine, 1 à 6 par défaut.
	var effect := StatusEffect.new()
	effect.effect_name = "Écran de poussière"
	effect.duration_remaining = -1  # Pas de DS précisé : permanent (jusqu'à la fin du combat).
	effect.bonus_adresse = -2  # Réduit l'Adresse : moins de précision au tir à distance ET aux sorts physiques.
	s.effect_to_apply = effect
	return s

func _build_jet_de_poussiere_majeur() -> Spell:
	var s := Spell.new()
	s.spell_name = "Jet de poussiere majeur"
	s.elements = ["Terre", "Air"]
	s.ea_cost = 10
	s.spell_type = Spell.SpellType.PHYSICAL
	s.target_mode = Spell.TargetMode.SINGLE_ENEMY
	s.min_range = 1
	s.max_range = 6  # Portée non précisée par le catalogue d'origine — 1 à 6 par défaut.
	var effect := StatusEffect.new()
	effect.effect_name = "Jet de poussiere majeur"
	effect.duration_remaining = 3
	effect.bonus_attaque = -2
	s.effect_to_apply = effect
	return s

func _build_particule_de_poussiere() -> Spell:
	var s := Spell.new()
	s.spell_name = "Particule de poussiere"
	s.elements = ["Terre", "Air"]
	s.ea_cost = 15
	s.spell_type = Spell.SpellType.PHYSICAL
	s.target_mode = Spell.TargetMode.ZONE
	s.zone_offsets = ZoneShapes.PARTICULE_DE_POUSSIERE.duplicate()  # Forme et ancre : voir zone_shapes.gd.
	s.min_range = 1
	s.max_range = 6  # Portée non précisée par le catalogue d'origine — 1 à 6 par défaut.
	s.dice_terms = [{"count": 2, "sides": 6, "modifier": 4}, {"count": 1, "sides": 4, "modifier": 0}]
	return s

func _build_nuage_de_poussi_re() -> Spell:
	var s := Spell.new()
	s.spell_name = "Nuage de poussière"
	s.elements = ["Terre", "Air"]
	s.ea_cost = 15
	s.spell_type = Spell.SpellType.PHYSICAL
	s.target_mode = Spell.TargetMode.ZONE
	s.zone_offsets = ZoneShapes.NUAGE_DE_POUSSIERE.duplicate()  # Forme et ancre : voir zone_shapes.gd.
	s.min_range = 1
	s.max_range = 6  # Portée d'ancrage — non précisée par le catalogue d'origine, 1 à 6 par défaut.
	s.cast_delay = 2
	s.damage = 8  # Dégât fixe immédiat (pas de dés précisés pour ce montant).
	var effect := StatusEffect.new()
	effect.effect_name = "Nuage de poussière"
	effect.duration_remaining = 4
	effect.bonus_attaque = -2
	effect.bonus_parade = -2
	s.effect_to_apply = effect
	return s

func _build_pic_de_glace() -> Spell:
	var s := Spell.new()
	s.spell_name = "Pic de glace"
	s.elements = ["Eau", "Air"]
	s.ea_cost = 3
	s.spell_type = Spell.SpellType.PHYSICAL
	s.target_mode = Spell.TargetMode.SINGLE_ENEMY
	s.min_range = 1
	s.max_range = 6  # Portée non précisée par le catalogue d'origine — 1 à 6 par défaut.
	s.dice_terms = [{"count": 1, "sides": 6, "modifier": 4}]
	var burn := StatusEffect.new()
	burn.effect_name = "Brûlure (Pic de glace)"
	burn.duration_remaining = -1
	burn.tick_every_other_turn = true
	burn.damage_per_tick = 2  # Non précisé par le catalogue — valeur par défaut raisonnable.
	if s.effect_to_apply != null:
		s.effect_to_apply = burn  # Un seul effect_to_apply à la fois : la brûlure prend le dessus ici.
	else:
		s.effect_to_apply = burn
	return s

func _build_sol_de_glace() -> Spell:
	var s := Spell.new()
	s.spell_name = "Sol de glace"
	s.elements = ["Eau", "Air"]
	s.ea_cost = 3
	s.spell_type = Spell.SpellType.PHYSICAL
	s.target_mode = Spell.TargetMode.SINGLE_ENEMY
	s.min_range = 1
	s.max_range = 6  # Portée non précisée par le catalogue d'origine — 1 à 6 par défaut.
	var effect := StatusEffect.new()
	effect.effect_name = "Sol de glace"
	effect.duration_remaining = -1
	effect.bonus_adresse = -1
	effect.bonus_attaque = -1
	effect.bonus_parade = -1
	s.effect_to_apply = effect
	return s

func _build_vol_e_de_glace() -> Spell:
	var s := Spell.new()
	s.spell_name = "Volée de glace"
	s.elements = ["Eau", "Air"]
	s.ea_cost = 5
	s.spell_type = Spell.SpellType.PHYSICAL
	s.target_mode = Spell.TargetMode.ZONE
	s.zone_offsets = ZoneShapes.VOLEE_DE_GLACE.duplicate()  # Forme et ancre : voir zone_shapes.gd.
	s.min_range = 1
	s.max_range = 6  # Portée non précisée par le catalogue d'origine — 1 à 6 par défaut.
	s.dice_terms = [{"count": 2, "sides": 6, "modifier": 4}]
	var burn := StatusEffect.new()
	burn.effect_name = "Brûlure (Volée de glace)"
	burn.duration_remaining = -1
	burn.tick_every_other_turn = true
	burn.damage_per_tick = 2  # Moyenne de 1D4 (la brûlure n'a pas de vrai jet de dés, juste un montant fixe par tick).
	if s.effect_to_apply != null:
		s.effect_to_apply = burn  # Un seul effect_to_apply à la fois : la brûlure prend le dessus ici.
	else:
		s.effect_to_apply = burn
	s.effect_sprite_path = "res://assets/vfx/glace_sheet.png"
	s.effect_start_x = 55
	s.effect_row = 80
	s.effect_frame_size = Vector2i(145, 175)
	s.effect_frame_count = 10
	return s

func _build_gel_de_l_eau() -> Spell:
	var s := Spell.new()
	s.spell_name = "Gel de l'eau"
	s.elements = ["Eau", "Air"]
	s.ea_cost = 2
	s.spell_type = Spell.SpellType.PSYCHIC
	s.min_range = 1
	s.max_range = 6  # Portée non précisée par le catalogue d'origine — 1 à 6 par défaut.
	s.removes_obstacle_type = ObstacleType.EAU
	s.max_terrain_cells = 4  # "Carré de 2x2" : jusqu'à 4 cases choisies une par une par le joueur.
	return s

func _build_cryog_nisation() -> Spell:
	var s := Spell.new()
	s.spell_name = "Cryogénisation"
	s.elements = ["Eau", "Air"]
	s.ea_cost = 6
	s.spell_type = Spell.SpellType.PSYCHIC
	s.target_mode = Spell.TargetMode.SINGLE_ALLY
	s.min_range = 1
	s.max_range = 6  # Portée non précisée par le catalogue d'origine — 1 à 6 par défaut.
	var effect := StatusEffect.new()
	effect.effect_name = "Cryogénisation"
	effect.duration_remaining = -1  # Pas de DS précisé : permanent (jusqu'à la fin du combat, ou Purge).
	effect.grants_frozen = true       # Ne peut plus se déplacer ni agir (son tour est sauté).
	effect.grants_untargetable = true # Ne peut plus être attaqué/ciblé par les ennemis.
	effect.grants_invulnerable = true # Insensible à tout dégât entrant.
	s.effect_to_apply = effect
	return s

func _build_yeti() -> Spell:
	var s := Spell.new()
	s.spell_name = "Yeti"
	s.elements = ["Eau", "Air"]
	s.ea_cost = 12
	s.spell_type = Spell.SpellType.PHYSICAL
	s.is_summon = true
	s.summon_name = "Yeti"
	s.summon_max_hp = 40
	s.summon_attack_parade = 6
	s.summon_armor = 4
	s.summon_dice_count = 3
	s.summon_dice_modifier = 1
	s.summon_color = Color(0.6, 0.85, 0.95)
	s.min_range = 1
	s.max_range = 6  # Même règle de portée que les autres sorts (1 à 6).
	return s

func _build_ere_glaciaire() -> Spell:
	var s := Spell.new()
	s.spell_name = "Ere glaciaire"
	s.elements = ["Eau", "Air"]
	s.ea_cost = 15
	s.spell_type = Spell.SpellType.PSYCHIC
	s.target_mode = Spell.TargetMode.ZONE
	s.zone_offsets = ZoneShapes.ERE_GLACIAIRE.duplicate()  # Forme et ancre : voir zone_shapes.gd.
	s.min_range = 1
	s.max_range = 6  # Portée non précisée par le catalogue d'origine — 1 à 6 par défaut.
	s.cast_delay = 3
	s.dice_terms = [{"count": 2, "sides": 6, "modifier": 2}]
	var effect := StatusEffect.new()
	effect.effect_name = "Ere glaciaire"
	effect.duration_remaining = 5
	effect.bonus_courage = -2
	effect.bonus_intelligence = -2
	effect.bonus_charisme = -2
	effect.bonus_adresse = -2
	effect.bonus_force = -2
	effect.bonus_chance = -2
	effect.bonus_attaque = -2
	effect.bonus_parade = -2
	s.effect_to_apply = effect
	return s

func _build_clone_de_br_me() -> Spell:
	var s := Spell.new()
	s.spell_name = "Clone de brûme"
	s.elements = ["Eau", "Air", "Feu"]
	s.ea_cost = 6
	s.spell_type = Spell.SpellType.PSYCHIC
	s.is_summon = true
	s.summon_name = "Clone de brûme"
	s.summon_max_hp = 15
	s.summon_attack_parade = 8
	s.summon_armor = 0
	s.summon_color = Color(0.75, 0.75, 0.8)
	s.min_range = 1
	s.max_range = 6  # Même règle de portée que les autres sorts (1 à 6).
	return s

func _build_invisibilit() -> Spell:
	var s := Spell.new()
	s.spell_name = "Invisibilité"
	s.elements = ["Eau", "Air", "Feu"]
	s.ea_cost = 5
	s.spell_type = Spell.SpellType.PSYCHIC
	# "Rend invisible" est un buff défensif — pas de cible précisée dans
	# le catalogue d'origine, mais un ciblage Ennemi n'aurait aucun sens
	# ici (le classificateur automatique s'était trompé).
	s.target_mode = Spell.TargetMode.SINGLE_ALLY
	s.min_range = 1
	s.max_range = 6  # Portée non précisée par le catalogue d'origine — 1 à 6 par défaut.
	var effect := StatusEffect.new()
	effect.effect_name = "Invisibilité"
	effect.duration_remaining = -1  # Pas de DS précisé : permanent (jusqu'à la fin du combat).
	effect.grants_untargetable = true
	s.effect_to_apply = effect
	return s

func _build_intangibilit() -> Spell:
	var s := Spell.new()
	s.spell_name = "Intangibilité"
	s.elements = ["Eau", "Air", "Feu"]
	s.ea_cost = 15
	s.spell_type = Spell.SpellType.PSYCHIC
	s.target_mode = Spell.TargetMode.SELF
	s.cast_delay = 1
	var effect := StatusEffect.new()
	effect.effect_name = "Intangibilité"
	effect.duration_remaining = 3
	effect.grants_invulnerable = true
	s.effect_to_apply = effect
	return s

func _build_marchant_de_sable() -> Spell:
	var s := Spell.new()
	s.spell_name = "Marchant de sable"
	s.elements = ["Air", "Eau", "Terre"]
	s.ea_cost = 8
	s.spell_type = Spell.SpellType.PSYCHIC
	s.target_mode = Spell.TargetMode.SINGLE_ENEMY
	s.min_range = 1
	s.max_range = 6  # Portée non précisée par le catalogue d'origine — 1 à 6 par défaut.
	s.cast_delay = 1
	s.stun_turns = 4
	return s

func _build_homme_de_sable() -> Spell:
	var s := Spell.new()
	s.spell_name = "Homme de sable"
	s.elements = ["Air", "Eau", "Terre"]
	s.ea_cost = 12
	s.spell_type = Spell.SpellType.PSYCHIC
	s.is_summon = true
	s.summon_name = "Homme de sable"
	s.summon_max_hp = 30
	s.summon_attack_parade = 7
	s.summon_armor = 1
	s.summon_dice_count = 5
	s.summon_dice_modifier = 0
	s.cast_delay = 2
	s.summon_color = Color(0.85, 0.75, 0.5)
	s.min_range = 1
	s.max_range = 6  # Même règle de portée que les autres sorts (1 à 6).
	return s

func _build_sablage() -> Spell:
	var s := Spell.new()
	s.spell_name = "Sablage"
	s.elements = ["Air", "Eau", "Terre"]
	s.ea_cost = 12
	s.spell_type = Spell.SpellType.PSYCHIC
	s.target_mode = Spell.TargetMode.SINGLE_ALLY
	s.min_range = 1
	s.max_range = 6  # Portée non précisée par le catalogue d'origine — 1 à 6 par défaut.
	s.cast_delay = 1
	var effect := StatusEffect.new()
	effect.effect_name = "Sablage"
	effect.duration_remaining = -1
	effect.bonus_armure = 4
	s.effect_to_apply = effect
	return s

func _build_renforcement_d_armes() -> Spell:
	var s := Spell.new()
	s.spell_name = "Renforcement d'armes"
	s.elements = ["Feu", "Terre", "Eau"]
	s.ea_cost = 5
	s.spell_type = Spell.SpellType.PSYCHIC
	s.target_mode = Spell.TargetMode.SINGLE_ALLY
	s.min_range = 1
	s.max_range = 6  # Portée non précisée par le catalogue d'origine — 1 à 6 par défaut.
	s.info_text = "Rend une arme incassable pendant le combat."
	s.is_unimplemented = true  # Voir la liste en bas du fichier : effet non automatisable, texte affiché mais sans mécanique.
	return s

func _build_ep_e_de_damocles() -> Spell:
	var s := Spell.new()
	s.spell_name = "Epée de Damocles"
	s.elements = ["Feu", "Terre", "Eau"]
	s.ea_cost = 10
	s.spell_type = Spell.SpellType.PHYSICAL
	s.target_mode = Spell.TargetMode.SINGLE_ENEMY
	s.min_range = 1
	s.max_range = 6  # Portée non précisée par le catalogue d'origine — 1 à 6 par défaut.
	s.cast_delay = 1
	var effect := StatusEffect.new()
	effect.effect_name = "Épée de Damocles"
	effect.duration_remaining = -1  # Se retire elle-même au déclenchement (voir trigger_chance), pas de limite de tours avant ça.
	effect.trigger_chance = 1.0 / 3.0
	effect.trigger_dice_terms = [{"count": 4, "sides": 6, "modifier": 2}]
	effect.trigger_bonus_dice_per_turn_waited = 1  # "+1D par tour où il ne s'est pas déclenché".
	s.effect_to_apply = effect
	return s

func _build_armure_de_trythil() -> Spell:
	var s := Spell.new()
	s.spell_name = "Armure de trythil"
	s.elements = ["Feu", "Terre", "Eau"]
	s.ea_cost = 10
	s.spell_type = Spell.SpellType.PSYCHIC
	s.target_mode = Spell.TargetMode.SINGLE_ALLY
	s.min_range = 1
	s.max_range = 6  # Portée non précisée par le catalogue d'origine — 1 à 6 par défaut.
	s.cast_delay = 2
	var effect := StatusEffect.new()
	effect.effect_name = "Armure de trythil"
	effect.duration_remaining = -1
	effect.bonus_armure = 6
	s.effect_to_apply = effect
	return s

func _build_d_tection_de_zone() -> Spell:
	var s := Spell.new()
	s.spell_name = "Détection de zone"
	s.elements = ["Air", "Terre", "Feu"]
	s.ea_cost = 4
	s.spell_type = Spell.SpellType.PSYCHIC
	s.target_mode = Spell.TargetMode.BATTLEFIELD  # Toutes les unités du champ de bataille, les deux camps.
	s.unavoidable = true  # Une détection ne s'esquive pas.
	s.min_range = 1
	s.max_range = 6  # Portée non précisée par le catalogue d'origine — 1 à 6 par défaut.
	s.reveals_invisible = true
	# SIMPLIFICATION ASSUMÉE : "pièges, magie, cachettes" ne correspond à
	# rien dans notre système (pas de pièges) — seule la révélation
	# d'invisibilité (personnes) est fonctionnelle.
	return s

func _build_onde_de_choc() -> Spell:
	var s := Spell.new()
	s.spell_name = "Onde de choc"
	s.elements = ["Air", "Terre", "Feu"]
	s.ea_cost = 8
	s.spell_type = Spell.SpellType.PHYSICAL
	s.target_mode = Spell.TargetMode.SINGLE_ENEMY
	s.min_range = 1
	s.max_range = 6  # Portée non précisée par le catalogue d'origine — 1 à 6 par défaut.
	s.dice_terms = [{"count": 4, "sides": 6, "modifier": 0}]
	return s

func _build_fracture_sysmique() -> Spell:
	var s := Spell.new()
	s.spell_name = "Fracture sysmique"
	s.elements = ["Air", "Terre", "Feu"]
	s.ea_cost = 15
	s.spell_type = Spell.SpellType.PHYSICAL
	s.target_mode = Spell.TargetMode.ZONE
	s.zone_offsets = ZoneShapes.FRACTURE_SYSMIQUE.duplicate()  # Forme et ancre : voir zone_shapes.gd.
	s.min_range = 1
	s.max_range = 6  # Portée non précisée par le catalogue d'origine — 1 à 6 par défaut.
	s.cast_delay = 2
	s.dice_terms = [{"count": 6, "sides": 6, "modifier": 6}]
	return s

static func build_all() -> Array:
	var catalog := MageSpellCatalog.new()
	var spells: Array = []
	spells.append(catalog._build_boule_de_feu_mineure())
	spells.append(catalog._build_aura_de_feu())
	spells.append(catalog._build_cone_de_feu())
	spells.append(catalog._build_boule_de_feu_majeure())
	spells.append(catalog._build_feu_follet())
	spells.append(catalog._build_phoenix())
	spells.append(catalog._build_prom_th_e_elementaire_de_feu())
	spells.append(catalog._build_soin_mineur())
	spells.append(catalog._build_restauration_pa())
	spells.append(catalog._build_mur_d_eau())
	spells.append(catalog._build_purge())
	spells.append(catalog._build_soin_majeur())
	spells.append(catalog._build_ras_de_mar_e())
	spells.append(catalog._build_aliz())
	spells.append(catalog._build_mistral())
	spells.append(catalog._build_z_phir())
	spells.append(catalog._build_libeccio())
	spells.append(catalog._build_su_tes())
	spells.append(catalog._build_bise())
	spells.append(catalog._build_eurus())
	spells.append(catalog._build_armure_de_terre())
	spells.append(catalog._build_poings_de_terre())
	spells.append(catalog._build_soldat_de_terre())
	spells.append(catalog._build_pluie_de_pierre())
	spells.append(catalog._build_golem_de_pierre())
	spells.append(catalog._build_m_t_ore())
	spells.append(catalog._build_evaporation_d_eau())
	spells.append(catalog._build_jet_d_eau_brulante())
	spells.append(catalog._build_nuage_de_vapeur())
	spells.append(catalog._build_evaporation_de_l_eau_d_un_corps())
	spells.append(catalog._build_geyser())
	spells.append(catalog._build_bombe_volcanique())
	spells.append(catalog._build_er_be())
	spells.append(catalog._build_hephaistos())
	spells.append(catalog._build_nu_e_ardente())
	spells.append(catalog._build_pluie_pyroclastique())
	spells.append(catalog._build_royaume_des_enfers())
	spells.append(catalog._build_arges())
	spells.append(catalog._build_enchantement())
	spells.append(catalog._build_vajra())
	spells.append(catalog._build_flash())
	spells.append(catalog._build_eclair_en_chaine())
	spells.append(catalog._build_brontes())
	spells.append(catalog._build_steropes())
	spells.append(catalog._build_tapis_de_ronce())
	spells.append(catalog._build_lasso_de_lianes())
	spells.append(catalog._build_immobilisation())
	spells.append(catalog._build_revitalisation())
	spells.append(catalog._build_membre_v_g_tal())
	spells.append(catalog._build_jeune_ent())
	spells.append(catalog._build_ent_adulte())
	spells.append(catalog._build_jet_de_poussiere())
	spells.append(catalog._build_ecran_de_poussiere())
	spells.append(catalog._build_jet_de_poussiere_majeur())
	spells.append(catalog._build_particule_de_poussiere())
	spells.append(catalog._build_nuage_de_poussi_re())
	spells.append(catalog._build_pic_de_glace())
	spells.append(catalog._build_sol_de_glace())
	spells.append(catalog._build_vol_e_de_glace())
	spells.append(catalog._build_gel_de_l_eau())
	spells.append(catalog._build_cryog_nisation())
	spells.append(catalog._build_yeti())
	spells.append(catalog._build_ere_glaciaire())
	spells.append(catalog._build_clone_de_br_me())
	spells.append(catalog._build_invisibilit())
	spells.append(catalog._build_intangibilit())
	spells.append(catalog._build_marchant_de_sable())
	spells.append(catalog._build_homme_de_sable())
	spells.append(catalog._build_sablage())
	spells.append(catalog._build_renforcement_d_armes())
	spells.append(catalog._build_ep_e_de_damocles())
	spells.append(catalog._build_armure_de_trythil())
	spells.append(catalog._build_d_tection_de_zone())
	spells.append(catalog._build_onde_de_choc())
	spells.append(catalog._build_fracture_sysmique())
	for spell in spells:
		spell.icon_path = MageSpellIcons.path_for(spell.spell_name)
	return spells

# ---------- Sorts sans mécanique automatisée (is_unimplemented = true) ----------
# Aura de feu (Feu) : Inflige 1D4 dégâts aux attaquants.
# Mur d eau (Eau) : Crée un mur d’eau.
# Mistral (Air) : Fait perdre 2 assauts.
# Zéphir (Air) : Confère +1D4 dégâts à distance.
# Poings de terre (Terre) : Confère Dégâts +4 au corps-à-corps.
# Evaporation d'eau (Vapeur) : Évapore de l’eau.
# Erèbe (Lave) : Les personnes sans nyctalopie subissent -2 ADR/AT/PRD.
# Enchantement (Foudre) : Confère Armes +1D(PS).
# Vajra (Foudre) : Épée de foudre : +2 AT/PRD ; 2D +1(PS).
# Membre végétal (Bois / Végétal) : Remplace un membre coupé ; malus du membre divisé par 2.
# Ecran de poussiere (Poussière) : Réduit la visibilité. AD au tir et sorts -2
# Nuage de poussière (Poussière) : Inflige 8 dégâts sur durée et AT/PRD -2.
# Gel de l'eau (Glace) : Gèle de l’eau.
# Cryogénisation (Glace) : L’allié est considéré comme hors combat. inciblable
# Invisibilité (Brume) : Rend invisible.
# Intangibilité (Brume) : Rend insensible aux dégâts.
# Marchant de sable (Sable) : La cible rate 4 assauts.
# Renforcement d'armes (Métal) : Rend une arme incassable pendant le combat.
# Epée de Damocles (Métal) : Chaque tour de la cible => 1/3 de chance de tomber. Si tombe, Inflige 4D+2(brut) + bonus dégâts et disparait. Si non, +1D brut
# Détection de zone (Onde) : Détecte tout : personnes, pièges, magie, cachettes, etc.
#
# ---------- MISE À JOUR : les 15 sorts listés plus haut ont depuis
# été codés, ainsi que Évaporation d'eau/Gel de l'eau/Membre végétal
# (devenu "Pont végétal") grâce au système de types d'obstacles
# (BASIC/EAU/VIDE — voir obstacle_type.gd). Seul reste
# is_unimplemented :
# - Renforcement d'armes : liée au système de rupture, pas encore construit.
