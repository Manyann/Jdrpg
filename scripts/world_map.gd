extends RefCounted
class_name WorldMap

# ============================================================
# world_map.gd
# Base de données des zones d'exploration (façon Dofus : le monde est
# découpé en écrans bornés reliés entre eux par leurs bords). Même
# principe que UnitDatabase pour les classes : une simple constante
# GDScript, facile à étendre sans toucher au reste du code.
#
# Chaque zone :
# - width/height : dimensions de l'écran, en pixels.
# - background_color : couleur de fond provisoire (en attendant de
#   vrais décors/tilesets).
# - exits : dictionnaire bord -> nom de zone ("north"/"south"/"east"/
#   "west"). Un bord sans sortie définie est infranchissable (le joueur
#   est simplement bloqué au bord).
# - encounter_chance : probabilité de rencontre à chaque "pas" (voir
#   ENCOUNTER_STEP_DIST dans zone.gd), en POURCENTAGE (0 à 100) —
#   0 = zone sûre, jamais de rencontre.
# - encounter_table : liste de compositions d'ennemis possibles (noms
#   de classes UnitDatabase) ; une composition est tirée au hasard à
#   chaque rencontre déclenchée.
# ============================================================

const ZONES: Dictionary = {
	"Plaine": {
		"width": 1000,
		"height": 600,
		"exits": {"east": "Foret", "north": "Village"},
		"encounter_chance": 5,
		"encounter_table": [
			["Orc", "Orc"],
			["Orc", "Orc", "Orc"],
		],
	},
	"Foret": {
		"width": 1000,
		"height": 600,
		"exits": {"west": "Plaine"},
		"encounter_chance": 10,
		"encounter_table": [
			["Orc", "Orc", "Orc"],
		],
	},
	"Village": {
		"width": 1000,
		"height": 600,
		"exits": {"south": "Plaine"},
		"encounter_chance": 0,  # Zone sûre : pas de rencontres.
		"encounter_table": [],
	},
}

# Renvoie les données d'une zone (dictionnaire vide si inconnue).
static func get_zone(zone_name: String) -> Dictionary:
	if ZONES.has(zone_name):
		return ZONES[zone_name]
	push_warning("WorldMap: zone inconnue '%s'." % zone_name)
	return {}
