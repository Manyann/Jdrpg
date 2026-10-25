class_name TrapDatabase
extends RefCounted

# Catalogue des pièges posables (compétence « Poser des pièges », code PIEGE).
# Charges par combat : TrapDef.charges (à ajuster ici).

static func _manavore() -> TrapDef:
	var t := TrapDef.new()
	t.trap_id = "manavore"
	t.trap_name = "Glyphe Astrale"
	t.description = "Un glyphe qui drainne de la mana."
	var e := StatusEffect.new()
	e.effect_name = "Drain de mana"
	e.mana_drain_per_tick = 3
	e.drains_to_source = true
	e.grants_rooted = true
	t.effect = e
	t.duration = 3
	t.trigger = TrapDef.Trigger.STEP
	t.release_test = TrapDef.ReleaseTest.INTELLIGENCE
	t.affects = TrapDef.Affects.ENEMY
	t.charges = 2
	return t

static func _vievore() -> TrapDef:
	var t := TrapDef.new()
	t.trap_id = "vievore"
	t.trap_name = "Glyphe de sang"
	t.description = "Un glyphe qui drainne de la vie."
	var e := StatusEffect.new()
	e.effect_name = "Drain de vie"
	e.damage_per_tick = 3
	e.drains_to_source = true
	e.grants_rooted = true
	t.effect = e
	t.duration = 3
	t.trigger = TrapDef.Trigger.STEP
	t.release_test = TrapDef.ReleaseTest.INTELLIGENCE
	t.affects = TrapDef.Affects.ENEMY
	t.charges = 2
	return t

static func _dalle() -> TrapDef:
	var t := TrapDef.new()
	t.trap_id = "dalle"
	t.trap_name = "Dalle piégée"
	t.description = "Des pics sortent du sol."
	t.damage_dice = 2
	t.damage_modifier = 0
	t.trigger = TrapDef.Trigger.STEP
	t.affects = TrapDef.Affects.ENEMY
	t.charges = 3
	return t

static func _loup() -> TrapDef:
	var t := TrapDef.new()
	t.trap_id = "loup"
	t.trap_name = "Piège à loup"
	t.description = "Des mâchoires d'acier se referment sur la victime."
	t.damage_dice = 2
	t.damage_modifier = 0
	var e := StatusEffect.new()
	e.effect_name = "Entravé (piège à loup)"
	e.grants_rooted = true
	t.effect = e
	t.duration = 3
	t.trigger = TrapDef.Trigger.STEP
	t.release_test = TrapDef.ReleaseTest.FORCE
	t.affects = TrapDef.Affects.ENEMY
	t.charges = 3
	return t

static func _explosif() -> TrapDef:
	var t := TrapDef.new()
	t.trap_id = "explosif"
	t.trap_name = "Piège explosif avec gros dégat"
	t.description = "Un piège explose et inflige des dégats en zone."
	t.damage_dice = 4
	t.damage_modifier = 0
	t.trigger = TrapDef.Trigger.STEP
	t.affects = TrapDef.Affects.ZONE
	t.charges = 1
	return t

static func _molotov() -> TrapDef:
	var t := TrapDef.new()
	t.trap_id = "molotov"
	t.trap_name = "Piège incendiaire sur la durée"
	t.description = "Un piège qui inflige des dégats et reste 3 tours."
	t.damage_dice = 2
	t.damage_modifier = 0
	t.duration = 3
	t.persistent_zone = true
	t.trigger = TrapDef.Trigger.STEP
	t.affects = TrapDef.Affects.ZONE
	t.charges = 1
	return t

static func _repousse() -> TrapDef:
	var t := TrapDef.new()
	t.trap_id = "repousse"
	t.trap_name = "Glyphe de repousse"
	t.description = "Un piège magique qui repousse l'ennemi."
	t.damage_dice = 1
	t.damage_modifier = 0
	var e := StatusEffect.new()
	e.effect_name = "Repoussé"
	e.move = 3
	t.effect = e
	t.trigger = TrapDef.Trigger.STEP
	t.affects = TrapDef.Affects.ENEMY
	t.charges = 2
	return t

static func _gaz() -> TrapDef:
	var t := TrapDef.new()
	t.trap_id = "gaz"
	t.trap_name = "Gaz affaiblissant"
	t.description = "Gaz affaiblissant qui enlève force et compétences."
	t.damage_dice = 0
	t.damage_modifier = 0
	var e := StatusEffect.new()
	e.effect_name = "Affaibli (-2 Force/Adresse, sorts bloqués)"
	e.weaken = 3
	t.effect = e
	t.trigger = TrapDef.Trigger.STEP
	t.affects = TrapDef.Affects.ZONE
	t.duration = 2
	t.charges = 2
	return t

# Charges par combat, par race OU métier (le plus haut l'emporte). Clés comparées
# sans tenir compte de la casse. Un métier compte avec toute sa lignée (un Chasseur
# de monstres est aussi Ranger).
const CHARGES: Dictionary = {
	"manavore": {"Elfe Noir": 2, "Paladin": 2, "Forgeur de runes": 2, "Démonologue": 4, "Prestidigitateur": 2, "Archéologue": 1, "Conservateur": 3},
	"vievore": {"Homme des sables": 3, "Templier": 2, "Forgeur de runes": 2, "Démonologue": 4, "Archéologue": 1, "Conservateur": 3, "Chasseur de monstres": 2},
	"dalle": {"Homme des sables": 3, "Voleur": 2, "Ingénieur": 3, "Chasseur de primes": 2, "Artisan": 1},
	"loup": {"Demi Elfe": 1, "Demi Orque": 1, "Orque": 2, "Rôdeur": 2, "Ranger": 3, "Chasseur de monstres": 5, "Artisan": 1},
	"explosif": {"Artificier": 5, "Artisan": 1},
	"molotov": {"Artificier": 4},
	"repousse": {"Elfe Sylvain": 2, "Homme des sables": 2, "Prêtre": 2, "Prestidigitateur": 2, "Ingénieur": 3, "Archéologue": 2, "Artisan": 1},
	"gaz": {"Homme des sables": 1, "Empoisonneur": 3, "Artisan": 1, "Herboriste": 2, "Chasseur de primes": 2, "Chasseur de monstres": 2, "Démonologue": 2},
}

static func charges_for(trap_id: String, race_name: String, metier_names: Array) -> int:
	var table: Dictionary = CHARGES.get(trap_id, {})
	var best: int = 0
	for key in table.keys():
		var k: String = str(key).to_lower()
		if race_name.to_lower() == k:
			best = max(best, int(table[key]))
		for m in metier_names:
			if str(m).to_lower() == k:
				best = max(best, int(table[key]))
	return best

static func build(trap_id: String) -> TrapDef:
	match trap_id:
		"manavore": return _manavore()
		"vievore": return _vievore()
		"dalle": return _dalle()
		"loup": return _loup()
		"explosif": return _explosif()
		"molotov": return _molotov()
		"repousse": return _repousse()
		"gaz": return _gaz()
	return null

static func all_ids() -> Array:
	return ["dalle", "loup", "vievore", "manavore", "repousse", "gaz", "explosif", "molotov"]
