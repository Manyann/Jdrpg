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
# - obstacles : liste de Rect2 (en pixels, même repère que le
#   déplacement du joueur) infranchissables — rochers, etc. Rendus
#   visuellement avec les vraies tuiles du tileset (voir
#   _apply_obstacle_tiles dans zone.gd), pas juste un placeholder.
#   Le joueur glisse le long de leurs bords plutôt que de se bloquer
#   net (voir _try_move dans zone.gd).
# - encounter_chance : probabilité de rencontre à chaque "pas" (voir
#   ENCOUNTER_STEP_DIST dans zone.gd), en POURCENTAGE (0 à 100) —
#   0 = zone sûre, jamais de rencontre.
# - encounter_table : liste de compositions d'ennemis possibles (noms
#   de classes UnitDatabase) ; une composition est tirée au hasard à
#   chaque rencontre déclenchée.
# ============================================================

# - npcs : liste de personnages non-joueurs statiques (voir npc.gd) —
#   name, position (Vector2 en pixels), dialogue (Array de lignes de
#   texte affichées une par une), sprite_template optionnel (nom d'une
#   classe UnitDatabase pour réutiliser son sprite en pose idle).
const ZONES: Dictionary = {
	"Plaine": {
		"width": 800,
		"height": 600,
		"background_color": Color(0.25, 0.4, 0.22),
		"exits": {"east": "Foret", "north": "Village"},
		"obstacles": [
			Rect2(560, 380, 130, 90),  # Un amas de rochers, à titre d'exemple.
		],
		"encounter_chance": 5,
		"encounter_table": [
			["Orc", "Orc"],
			["Orc", "Orc", "Orc"],
		],
	},
	"Foret": {
		"width": 800,
		"height": 600,
		"background_color": Color(0.12, 0.25, 0.12),
		"exits": {"west": "Plaine"},
		"encounter_chance": 10,
		"encounter_table": [
			["Orc", "Orc", "Orc"],
		],
	},
	"Village": {
		"width": 800,
		"height": 600,
		"background_color": Color(0.35, 0.32, 0.22),
		"exits": {"south": "Plaine"},
		"encounter_chance": 0,  # Zone sûre : pas de rencontres.
		"encounter_table": [],
		"npcs": [
			{
				"name": "Vieil Homme",
				"position": Vector2(400, 300),
				"dialogue": [
					"Bienvenue au village, voyageur.",
					"Prends garde en Forêt : les Orcs y rôdent en nombre.",
					"Reviens me voir si tu as besoin de conseils.",
				],
			},
		],
	},
}

# Renvoie les données d'une zone (dictionnaire vide si inconnue).
static func get_zone(zone_name: String) -> Dictionary:
	if ZONES.has(zone_name):
		return ZONES[zone_name]
	push_warning("WorldMap: zone inconnue '%s'." % zone_name)
	return {}
