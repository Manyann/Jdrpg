extends Node

# ============================================================
# world_manager.gd
# Singleton (Autoload) qui garde en mémoire l'état du monde entre les
# changements de scène : zone actuelle, position du joueur, et bientôt
# la composition de l'équipe et les infos de retour après un combat.
#
# INSTALLATION (obligatoire pour que l'état survive au rechargement
# de scène lors d'un changement de zone) :
# 1. Project > Project Settings > onglet "Autoload".
# 2. Path : sélectionne ce fichier (world_manager.gd).
# 3. Node Name : laisse "WorldManager" (doit correspondre exactement,
#    c'est le nom utilisé partout dans le code : WorldManager.xxx).
# 4. Clique "Add".
# ============================================================

# Zone actuellement affichée, et position où le joueur doit apparaître
# dans cette zone (mise à jour à chaque changement de zone, voir
# travel_to_zone).
var current_zone_name: String = "Plaine"
var player_spawn_position: Vector2 = Vector2(400, 300)

# Renseignés juste avant de déclencher un combat (rencontre) : quels
# ennemis affronter, et où revenir une fois le combat terminé. Pas
# encore lus par la scène de combat (à brancher à l'étape suivante).
var pending_encounter_enemies: Array = []
var return_zone_name: String = ""
var return_position: Vector2 = Vector2.ZERO

# Change la zone courante et la position d'arrivée du joueur. Appelé
# par zone.gd quand le joueur franchit un bord ; le script appelant
# doit ensuite recharger la scène (get_tree().reload_current_scene())
# pour que le changement prenne effet visuellement.
func travel_to_zone(zone_name: String, spawn_position: Vector2) -> void:
	current_zone_name = zone_name
	player_spawn_position = spawn_position
