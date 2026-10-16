extends RefCounted
class_name SkillDatabase

# ============================================================
# skill_database.gd — GÉNÉRÉ à partir du catalogue de 44 compétences.
#
# COMPÉTENCES AVEC UN EFFET DE COMBAT AUTOMATISÉ (9/44) — voir
# CombatUnit._recalculate_stats et WorldManager.finish_encounter_combat :
# - AM  (Ambidextrie)         : force has_ambidextrie = true.
# - BP  (Bourre pif)          : +1 dégât si mains nues (arme "Poings").
# - CDN (Chercher des noises) : priorité dans l'ordre du tour (voir TurnManager).
# - DS  (Déplacement silencieux) : +1 PM de base.
# - TV  (Tête vide)           : +1 armure magique de base.
# - TDM (Truc de mauviette)   : +1 armure physique de base.
# - PS  (Premier soins)       : +1D+1 PV au groupe en fin de combat (victoire).
# - RE  (Récupération)        : +1D+1 EA au groupe en fin de combat (victoire).
# - DET (Détecter, actif)     : bouton de combat « Détecter » (voir CombatUnit,
#   rayon 2 autour du lanceur, révèle les invisibles).
#
# Les 35 autres ("Hors combat", ou dépendant d'un système qu'on n'a pas :
# loot, pièges, rations, ciblage IA...) sont importées ici pour être
# consultables (nom/description), mais n'ont AUCUN effet mécanique.
# ============================================================

static func _build_am() -> Skill:
	var skill := Skill.new()
	skill.code = "AM"
	skill.skill_name = "Ambidextrie"
	skill.description = "Permet d'avoir 2 armes de corps à corps en combat"
	skill.skill_type = "passif"
	return skill

static func _build_ag() -> Skill:
	var skill := Skill.new()
	skill.code = "AG"
	skill.skill_name = "Agoraphobie"
	skill.description = "Hors combat"
	skill.skill_type = "passif"
	return skill

static func _build_adr() -> Skill:
	var skill := Skill.new()
	skill.code = "ADR"
	skill.skill_name = "Appel des renforts"
	skill.description = "Permet de se déplacer sans test si on est au corps à corps avec un ennemi"
	skill.skill_type = "passif"
	return skill

static func _build_adt() -> Skill:
	var skill := Skill.new()
	skill.code = "ADT"
	skill.skill_name = "Appel du tonneau"
	skill.description = "Hors combat"
	skill.skill_type = "passif"
	return skill

static func _build_adv() -> Skill:
	var skill := Skill.new()
	skill.code = "ADV"
	skill.skill_name = "Appel du ventre"
	skill.description = "Hors combat"
	skill.skill_type = "passif"
	return skill

static func _build_adb() -> Skill:
	var skill := Skill.new()
	skill.code = "ADB"
	skill.skill_name = "Armes de bourrin"
	skill.description = "Permet d'utiliser les armes à 2 mains en combat"
	skill.skill_type = "passif"
	return skill

static func _build_aec() -> Skill:
	var skill := Skill.new()
	skill.code = "AEC"
	skill.skill_name = "Arnaques et carambouilles"
	skill.description = "Hors combat"
	skill.skill_type = "passif"
	return skill

static func _build_alm() -> Skill:
	var skill := Skill.new()
	skill.code = "ALM"
	skill.skill_name = "Attire les monstres"
	skill.description = "Se fait attaquer en priorité par les monstres"
	skill.skill_type = "passif"
	return skill

static func _build_bp() -> Skill:
	var skill := Skill.new()
	skill.code = "BP"
	skill.skill_name = "Bourre pif"
	skill.description = "Ajoute 1 de dégât au combat à mains nues"
	skill.skill_type = "passif"
	return skill

static func _build_bdd() -> Skill:
	var skill := Skill.new()
	skill.code = "BDD"
	skill.skill_name = "Bricolo du dimanche"
	skill.description = "Hors combat"
	skill.skill_type = "actif"
	return skill

static func _build_cdg() -> Skill:
	var skill := Skill.new()
	skill.code = "CDG"
	skill.skill_name = "Chef de groupe"
	skill.description = "Hors combat"
	skill.skill_type = "passif"
	return skill

static func _build_cdn() -> Skill:
	var skill := Skill.new()
	skill.code = "CDN"
	skill.skill_name = "Chercher des noises"
	skill.description = "Joue en premier les combats, si plusieurs personne avec la compétence, ordre par courage"
	skill.skill_type = "passif"
	return skill

static func _build_ch() -> Skill:
	var skill := Skill.new()
	skill.code = "CH"
	skill.skill_name = "Chevaucher"
	skill.description = "Hors combat"
	skill.skill_type = "passif"
	return skill

static func _build_cho() -> Skill:
	var skill := Skill.new()
	skill.code = "CHO"
	skill.skill_name = "Chouraver"
	skill.description = "Hors combat"
	skill.skill_type = "passif"
	return skill

static func _build_cla() -> Skill:
	var skill := Skill.new()
	skill.code = "CLA"
	skill.skill_name = "Comprendre les animaux"
	skill.description = "Hors combat"
	skill.skill_type = "passif"
	return skill

static func _build_cu() -> Skill:
	var skill := Skill.new()
	skill.code = "CU"
	skill.skill_name = "Cuistot"
	skill.description = "Les rations donnent 1PV supplémentaire"
	skill.skill_type = "passif"
	return skill

static func _build_ds() -> Skill:
	var skill := Skill.new()
	skill.code = "DS"
	skill.skill_name = "Déplacement silencieux"
	skill.description = "Permet d'avoir 1PM supplémentaire de base"
	skill.skill_type = "passif"
	return skill

static func _build_de() -> Skill:
	var skill := Skill.new()
	skill.code = "DE"
	skill.skill_name = "Désamorcer"
	skill.description = "Hors combat"
	skill.skill_type = "passif"
	return skill

static func _build_det() -> Skill:
	var skill := Skill.new()
	skill.code = "DET"
	skill.skill_name = "Détecter"
	skill.description = "Permet de détecter des pièges, personnes invisibles (en combat : rayon de 2 cases)"
	skill.skill_type = "actif"
	return skill

static func _build_er() -> Skill:
	var skill := Skill.new()
	skill.code = "ER"
	skill.skill_name = "Érudition"
	skill.description = "Hors combat"
	skill.skill_type = "passif"
	return skill

static func _build_es() -> Skill:
	var skill := Skill.new()
	skill.code = "ES"
	skill.skill_name = "Escalader"
	skill.description = "Hors combat"
	skill.skill_type = "passif"
	return skill

static func _build_fa() -> Skill:
	var skill := Skill.new()
	skill.code = "FA"
	skill.skill_name = "Fariboles"
	skill.description = "Hors combat"
	skill.skill_type = "passif"
	return skill

static func _build_fdp() -> Skill:
	var skill := Skill.new()
	skill.code = "FDP"
	skill.skill_name = "Fouiller dans les poubelles"
	skill.description = "Hors combat"
	skill.skill_type = "passif"
	return skill

static func _build_ids() -> Skill:
	var skill := Skill.new()
	skill.code = "IDS"
	skill.skill_name = "Instinct de survie"
	skill.description = "Hors combat"
	skill.skill_type = "passif"
	return skill

static func _build_idt() -> Skill:
	var skill := Skill.new()
	skill.code = "IDT"
	skill.skill_name = "Instinct du trésor"
	skill.description = "Augmente les chances de loot à la fin du combat"
	skill.skill_type = "passif"
	return skill

static func _build_in() -> Skill:
	var skill := Skill.new()
	skill.code = "IN"
	skill.skill_name = "Intimider"
	skill.description = "Hors combat"
	skill.skill_type = "passif"
	return skill

static func _build_jed() -> Skill:
	var skill := Skill.new()
	skill.code = "JED"
	skill.skill_name = "Jonglage et danse"
	skill.description = "Hors combat"
	skill.skill_type = "passif"
	return skill

static func _build_ldm() -> Skill:
	var skill := Skill.new()
	skill.code = "LDM"
	skill.skill_name = "Langage des monstres"
	skill.description = "Hors combat"
	skill.skill_type = "passif"
	return skill

static func _build_me() -> Skill:
	var skill := Skill.new()
	skill.code = "ME"
	skill.skill_name = "Méfiance"
	skill.description = "Hors combat"
	skill.skill_type = "passif"
	return skill

static func _build_mep() -> Skill:
	var skill := Skill.new()
	skill.code = "MEP"
	skill.skill_name = "Mendier et pleurnicher"
	skill.description = "Hors combat"
	skill.skill_type = "passif"
	return skill

static func _build_na() -> Skill:
	var skill := Skill.new()
	skill.code = "NA"
	skill.skill_name = "Nager"
	skill.description = "Hors combat"
	skill.skill_type = "passif"
	return skill

static func _build_nt() -> Skill:
	var skill := Skill.new()
	skill.code = "NT"
	skill.skill_name = "Naïveté touchante"
	skill.description = "Hors combat"
	skill.skill_type = "passif"
	return skill

static func _build_pe() -> Skill:
	var skill := Skill.new()
	skill.code = "PE"
	skill.skill_name = "Pénible"
	skill.description = "Hors combat"
	skill.skill_type = "passif"
	return skill

static func _build_pi() -> Skill:
	var skill := Skill.new()
	skill.code = "PI"
	skill.skill_name = "Pister"
	skill.description = "Hors combat"
	skill.skill_type = "passif"
	return skill

static func _build_ps() -> Skill:
	var skill := Skill.new()
	skill.code = "PS"
	skill.skill_name = "Premier soins"
	skill.description = "À la fin du combat, rend 1D+1 de vie à chaque personne du groupe"
	skill.skill_type = "passif"
	return skill

static func _build_ra() -> Skill:
	var skill := Skill.new()
	skill.code = "RA"
	skill.skill_name = "Radin"
	skill.description = "Hors combat"
	skill.skill_type = "passif"
	return skill

static func _build_re() -> Skill:
	var skill := Skill.new()
	skill.code = "RE"
	skill.skill_name = "Récupération"
	skill.description = "À la fin du combat, rend 1D+1 de mana à chaque personne du groupe"
	skill.skill_type = "passif"
	return skill

static func _build_rar() -> Skill:
	var skill := Skill.new()
	skill.code = "RAR"
	skill.skill_name = "Ressemble à rien"
	skill.description = "Hors combat"
	skill.skill_type = "passif"
	return skill

static func _build_rb() -> Skill:
	var skill := Skill.new()
	skill.code = "RB"
	skill.skill_name = "Rûnes bizarres"
	skill.description = "Hors combat"
	skill.skill_type = "passif"
	return skill

static func _build_sdp() -> Skill:
	var skill := Skill.new()
	skill.code = "SDP"
	skill.skill_name = "Sentir des pieds"
	skill.description = "Hors combat"
	skill.skill_type = "passif"
	return skill

static func _build_se() -> Skill:
	var skill := Skill.new()
	skill.code = "SE"
	skill.skill_name = "Serrurier"
	skill.description = "Hors combat"
	skill.skill_type = "passif"
	return skill

static func _build_tv() -> Skill:
	var skill := Skill.new()
	skill.code = "TV"
	skill.skill_name = "Tête vide"
	skill.description = "Donne 1PR magique de base"
	skill.skill_type = "passif"
	return skill

static func _build_tc() -> Skill:
	var skill := Skill.new()
	skill.code = "TC"
	skill.skill_name = "Tirer correctement"
	skill.description = "Permet d'utiliser les armes à distances"
	skill.skill_type = "passif"
	return skill

static func _build_tdp() -> Skill:
	var skill := Skill.new()
	skill.code = "TDP"
	skill.skill_name = "Tomber dans les pièges"
	skill.description = "Les dégats entrant des pièges ajoute 1D de dégat"
	skill.skill_type = "passif"
	return skill

static func _build_tdm() -> Skill:
	var skill := Skill.new()
	skill.code = "TDM"
	skill.skill_name = "Truc de mauviette"
	skill.description = "Donne 1PR de base"
	skill.skill_type = "passif"
	return skill

const CODES: Array = ["AM", "AG", "ADR", "ADT", "ADV", "ADB", "AEC", "ALM", "BP", "BDD", "CDG", "CDN", "CH", "CHO", "CLA", "CU", "DS", "DE", "DET", "ER", "ES", "FA", "FDP", "IDS", "IDT", "IN", "JED", "LDM", "ME", "MEP", "NA", "NT", "PE", "PI", "PS", "RA", "RE", "RAR", "RB", "SDP", "SE", "TV", "TC", "TDP", "TDM"]

# Effet réel de la compétence en combat (« Aucun effet en combat » si elle ne
# sert qu'en exploration).
const COMBAT_EFFECTS: Dictionary = {
	"AM": "permet de porter deux armes de corps à corps (une attaque par main).",
	"ADR": "quitter le corps à corps d'un ennemi ne déclenche pas son attaque d'opportunité imparable.",
	"ADB": "permet d'utiliser les armes à deux mains.",
	"ALM": "les monstres vous attaquent en priorité.",
	"BP": "+1 dégât à mains nues.",
	"CDN": "joue en premier (à égalité, ordre par Courage).",
	"DS": "+1 PM de base.",
	"DET": "bouton « Détecter » : 3 charges, test d'Intelligence + 2 ; révèle les unités invisibles à 2 cases ou moins (pièges à venir).",
	"PS": "à la fin d'un combat gagné, rend 1D+1 PV à chaque personne du groupe.",
	"RE": "à la fin d'un combat gagné, rend 1D+1 EA à chaque personne du groupe.",
	"TC": "permet d'utiliser les armes à distance.",
	"TV": "+1 armure magique de base.",
	"TDM": "+1 armure physique de base.",
}

static func combat_effect(code: String) -> String:
	return str(COMBAT_EFFECTS.get(code, "aucun effet."))

static func build(code: String) -> Skill:
	match code:
		"AM":
			return _build_am()
		"AG":
			return _build_ag()
		"ADR":
			return _build_adr()
		"ADT":
			return _build_adt()
		"ADV":
			return _build_adv()
		"ADB":
			return _build_adb()
		"AEC":
			return _build_aec()
		"ALM":
			return _build_alm()
		"BP":
			return _build_bp()
		"BDD":
			return _build_bdd()
		"CDG":
			return _build_cdg()
		"CDN":
			return _build_cdn()
		"CH":
			return _build_ch()
		"CHO":
			return _build_cho()
		"CLA":
			return _build_cla()
		"CU":
			return _build_cu()
		"DS":
			return _build_ds()
		"DE":
			return _build_de()
		"DET":
			return _build_det()
		"ER":
			return _build_er()
		"ES":
			return _build_es()
		"FA":
			return _build_fa()
		"FDP":
			return _build_fdp()
		"IDS":
			return _build_ids()
		"IDT":
			return _build_idt()
		"IN":
			return _build_in()
		"JED":
			return _build_jed()
		"LDM":
			return _build_ldm()
		"ME":
			return _build_me()
		"MEP":
			return _build_mep()
		"NA":
			return _build_na()
		"NT":
			return _build_nt()
		"PE":
			return _build_pe()
		"PI":
			return _build_pi()
		"PS":
			return _build_ps()
		"RA":
			return _build_ra()
		"RE":
			return _build_re()
		"RAR":
			return _build_rar()
		"RB":
			return _build_rb()
		"SDP":
			return _build_sdp()
		"SE":
			return _build_se()
		"TV":
			return _build_tv()
		"TC":
			return _build_tc()
		"TDP":
			return _build_tdp()
		"TDM":
			return _build_tdm()
		_:
			return null
