extends RefCounted
class_name PretreSpellIcons

# ============================================================
# pretre_spell_icons.gd — Icônes des sorts du Prêtre.
# Nom du sort (tel qu'écrit dans pretre_spell_catalog.gd) -> fichier PNG de
# res://assets/spell_icons/pretre/. « Être nocturne » et « Maître de la
# nuit » (capacités de l'Ordre du néant, pas des sorts) ont leur image dans
# le dossier mais ne sont pas listées ici.
# ============================================================

const FOLDER: String = "res://assets/spell_icons/pretre/"

const ICONS: Dictionary = {
	"Baiser de chaleur": "baiser_de_chaleur",
	"Bronzage": "bronzage",
	"Brûlure": "brulure",
	"Lumière apaisante": "lumiere_apaisante",
	"Disque de lumière": "disque_de_lumiere",
	"Être de lumière": "etre_de_lumiere",
	"Équilibre parfait": "equilibre_parfait",
	"Alternative": "alternative",
	"Zone de jugement": "zone_de_jugement",
	"Croissant de lune": "croissant_de_lune",
	"Pleine lune": "pleine_lune",
	"Noirceur": "noirceur",
	"Attrape lumière": "attrape_lumiere",
	"Frappe du néant": "frappe_du_neant",
	"Aspiration du néant": "aspiration_du_neant",
	"Plan parallèle": "plan_parallele",
	"Soin": "soin",
	"Soin de groupe": "soin_de_groupe",
	"Scalpel": "scalpel",
	"Infection": "infection",
	"Nécrose": "necrose",
	"Invoque un faucheur": "invoque_un_faucheur",
	"Le mana devient de la vie": "le_mana_devient_de_la_vie",
	"Invoque la balance de l'univers": "invoque_la_balance_de_l_univers",
	"L'équilibre du cycle": "l_equilibre_du_cycle",
}

# Chemin de l'icône d'un sort ("" si le sort n'en a pas).
static func path_for(spell_name: String) -> String:
	if ICONS.has(spell_name):
		return FOLDER + str(ICONS[spell_name]) + ".png"
	return ""
