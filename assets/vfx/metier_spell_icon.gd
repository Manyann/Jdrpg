extends RefCounted
class_name MetierSpellIcons

# ============================================================
# metier_spell_icons.gd — Icônes des sorts de l'Archéologue, du Conservateur,
# du Peintre, de la Walkyrie et du Forgeur de runes (+ Démonologue, dont le
# catalogue n'existe pas encore : les images sont déjà dans demonologue/).
# Nom du sort -> "dossier/fichier" sous res://assets/spell_icons/.
# Sans carte dédiée : Contrat de Damoclès, Protection divine (-> icône par
# défaut) ; Rune de combat -> « renforcement », Rune d'invulnérabilité ->
# « solidité » (rapprochement par le sens, à valider).
# ============================================================

const FOLDER: String = "res://assets/spell_icons/"

const ICONS: Dictionary = {
	# Archéologue
	"Parchemin de Griffe Spectrale": "archeologue/griffe_spectrale",
	"Manuscrit de l'Esprit Berzerk": "archeologue/esprit_berzerk",
	"Traité du Stimulant de combat": "archeologue/stimulant_de_combat",
	"Essai sur la protection magique": "archeologue/protection_magique",
	"Traité sur la Revitalisation": "archeologue/revitalisation",
	"Parchemin de grande Griffe Spectrale": "archeologue/grande_griffe_spectrale",
	"Parchemin de Croc de la mort": "archeologue/croc_de_la_mort",
	"Contrat de l'Ame du Berserk": "archeologue/ame_du_berserk",
	# Conservateur
	"Traité sur la restauration des EA": "conservateur/restauration_des_ea",
	"Traité sur les Gantelets du Berserk": "conservateur/gantelets_du_berserk",
	"Essai sur la cryogénisation": "conservateur/cryogenisation",
	"Parchemin de fracture sysmique": "conservateur/fracture_sysmique",
	# Peintre
	"Peinture de guerre": "peintre/peinture_de_guerre",
	"Maquillage": "peintre/maquillage",
	# Walkyrie
	"Soin des blessures légères": "walkyrie/soin_leger",
	"Rayon de lumière": "walkyrie/rayon_de_lumiere",
	"Laser purificateur": "walkyrie/laser_purificateur",
	"Courroux du ciel": "walkyrie/courroux_du_ciel",
	"Arme céleste": "walkyrie/arme_celeste",
	"Soin des blessures majeures": "walkyrie/soin_majeur",
	"Bouclier de paix": "walkyrie/bouclier_de_paix",
	"Jugement divin": "walkyrie/jugement_divin",
	"Grâce du ciel": "walkyrie/grace_du_ciel",
	# Forgeur de runes
	"Rune de protection": "forgeur_de_runes/rune_de_protection",
	"Rune de protection magique": "forgeur_de_runes/rune_de_protection_magique",
	"Rune de combat": "forgeur_de_runes/rune_de_renforcement",
	"Rune d'invulnérabilité": "forgeur_de_runes/rune_de_solidite",
}

static func path_for(spell_name: String) -> String:
	if ICONS.has(spell_name):
		return FOLDER + str(ICONS[spell_name]) + ".png"
	return ""

static func apply(spells: Array) -> Array:
	for spell in spells:
		var path: String = path_for(spell.spell_name)
		if path != "":
			spell.icon_path = path
	return spells
