extends RefCounted
class_name MecaSpellIcons

# ============================================================
# meca_spell_icons.gd — Icônes des sorts d'invocation de Méca (Ingénieur
# Automate) : nom du sort -> PNG de res://assets/spell_icons/meca/.
# ============================================================

const FOLDER: String = "res://assets/spell_icons/meca/"

const ICONS: Dictionary = {
	"Invoque un Méca Doc": "invoque_un_meca_doc",
	"Invoque un Méca Tanker": "invoque_un_meca_tanker",
	"Invoque un Méca Combat": "invoque_un_meca_combat",
	"Invoque un Méca Support": "invoque_un_meca_support",
}

# Chemin de l'icône d'un sort ("" si le sort n'en a pas).
static func path_for(spell_name: String) -> String:
	if ICONS.has(spell_name):
		return FOLDER + str(ICONS[spell_name]) + ".png"
	return ""
