extends RefCounted
class_name ClassSpellIcons

# ============================================================
# class_spell_icons.gd — Icônes des sorts des classes à un seul sort ou
# presque (Berserk, Gladiateur, Corsaire, Moine, Ninja, Prestidigitateur,
# Soldat, Templier). Nom du sort -> PNG de res://assets/spell_icons/classes/.
# « Doigt d'honneur » (Gladiateur) a l'icône de « Provocation », « Tortue »
# celle de « Levé de bouclier », « Tourbillon » celle de « Lame
# tourbillonante », « Raaah » celle de « Cri de guerre ».
# ============================================================

const FOLDER: String = "res://assets/spell_icons/classes/"

const ICONS: Dictionary = {
	"Frappe puissante": "frappe_puissante",
	"Tourbillon": "lame_tourbillonante",
	"Raaah": "cri_de_guerre",
	"Doigt d'honneur": "provocation",
	"Coup de bouclier": "coup_de_bouclier",
	"Tortue": "leve_de_bouclier",
	"Salve": "salve_de_plomb",
	"Purification": "purification",
	"Permutation": "permutation",
	"Substitution": "substitution",
	"Porte étendard": "porte_etendard",
	"Bouclier de Foi": "bouclier_de_foi",
}

# Chemin de l'icône d'un sort ("" si le sort n'en a pas).
static func path_for(spell_name: String) -> String:
	if ICONS.has(spell_name):
		return FOLDER + str(ICONS[spell_name]) + ".png"
	return ""

# Pose l'icône sur chaque sort de la liste qui en a une, et renvoie la liste.
static func apply(spells: Array) -> Array:
	for spell in spells:
		var path: String = path_for(spell.spell_name)
		if path != "":
			spell.icon_path = path
	return spells
