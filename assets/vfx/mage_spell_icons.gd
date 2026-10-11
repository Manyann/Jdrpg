extends RefCounted
class_name MageSpellIcons

# ============================================================
# mage_spell_icons.gd — Icônes des sorts du Mage.
# Nom du sort (tel qu'écrit dans mage_spell_catalog.gd) -> fichier PNG de
# res://assets/spell_icons/mage/. « Pont végétal » reprend l'icône de
# « Membre végétal », et « Yeti » celle de « Cryogénisation ».
# ============================================================

const FOLDER: String = "res://assets/spell_icons/mage/"

const ICONS: Dictionary = {
	"Boule de feu mineure": "boule_de_feu_mineure",
	"Aura de feu": "aura_de_feu",
	"Cone de feu": "cone_de_feu",
	"Boule de feu majeure": "boule_de_feu_majeure",
	"Feu follet": "feu_follet",
	"Phoenix": "phoenix",
	"Prométhée (Elementaire de feu)": "promethee",
	"Soin mineur": "soin_mineur",
	"Restauration PA": "restauration_energie_astrale",
	"Mur d eau": "mur_d_eau",
	"Purge": "purge",
	"Soin majeur": "soin_majeur",
	"Ras de marée": "ras_de_maree",
	"Alizé": "alize",
	"Mistral": "mistral",
	"Zéphir": "zephir",
	"Libeccio": "libeccio",
	"Suêtes": "suetes",
	"Bise": "bise",
	"Eurus": "eurus",
	"Armure de terre": "armure_de_terre",
	"Poings de terre": "poings_de_terre",
	"Soldat de terre": "soldat_de_terre",
	"Pluie de pierre": "pluie_de_pierre",
	"Golem de pierre": "golem_de_pierre",
	"Météore": "meteore",
	"Evaporation d'eau": "evaporation_d_eau",
	"Jet d'eau brulante": "jet_d_eau_brulante",
	"Nuage de vapeur": "nuage_de_vapeur",
	"Evaporation de l'eau d'un corps": "evaporation_de_l_eau_d_un_corps",
	"Geyser": "geyser",
	"Bombe volcanique": "bombe_volcanique",
	"Erèbe": "erebe",
	"Hephaistos": "hephaistos",
	"Nuée ardente": "nuee_ardente",
	"Pluie pyroclastique": "pluie_pyroclastique",
	"Royaume des enfers": "royaume_des_enfers",
	"Arges": "arges",
	"Enchantement": "enchantement",
	"Vajra": "vajra",
	"Flash": "flash",
	"Eclair en chaine": "eclair_en_chaine",
	"Brontes": "brontes",
	"Steropes": "steropes",
	"Tapis de ronce": "tapis_de_ronce",
	"Lasso de lianes": "lasso_de_lianes",
	"Immobilisation": "immobilisation",
	"Revitalisation": "revitalisation",
	"Pont végétal": "membre_vegetal",
	"Jeune Ent": "jeune_ent",
	"Ent adulte": "ent_adulte",
	"Jet de poussiere": "jet_de_poussiere",
	"Ecran de poussiere": "ecran_de_poussiere",
	"Jet de poussiere majeur": "jet_de_poussiere_majeur",
	"Particule de poussiere": "particule_de_poussiere",
	"Nuage de poussière": "nuage_de_poussiere",
	"Pic de glace": "pic_de_glace",
	"Sol de glace": "sol_de_glace",
	"Volée de glace": "volee_de_glace",
	"Gel de l'eau": "gel_de_l_eau",
	"Cryogénisation": "cryogenisation",
	"Yeti": "cryogenisation",
	"Ere glaciaire": "ere_glaciaire",
	"Clone de brûme": "clone_de_brume",
	"Invisibilité": "invisibilite",
	"Intangibilité": "intangibilite",
	"Marchant de sable": "marchant_de_sable",
	"Homme de sable": "homme_de_sable",
	"Sablage": "sablage",
	"Renforcement d'armes": "renforcement_d_armes",
	"Epée de Damocles": "epee_de_damocles",
	"Armure de trythil": "armure_de_trythil",
	"Détection de zone": "detection_de_zone",
	"Onde de choc": "onde_de_choc",
	"Fracture sysmique": "fracture_sysmique",
}

# Chemin de l'icône d'un sort ("" si le sort n'en a pas).
static func path_for(spell_name: String) -> String:
	if ICONS.has(spell_name):
		return FOLDER + str(ICONS[spell_name]) + ".png"
	return ""
