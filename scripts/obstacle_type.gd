extends RefCounted
class_name ObstacleType

# ============================================================
# obstacle_type.gd
# Les 3 types d'obstacles de combat (voir HexGrid, obstacle_coords/
# water_obstacle_coords/void_obstacle_coords) :
# - BASIC : un rocher, un mur... infranchissable en permanence, ne
#   peut être ni retiré ni contourné par un sort.
# - EAU : infranchissable comme BASIC, mais peut être retiré par
#   certains sorts (Évaporation d'eau, Gel de l'eau).
# - VIDE : un gouffre/une fosse — infranchissable, mais un pont
#   végétal peut le rendre temporairement franchissable en ligne.
#
# Tous bloquent le mouvement ET la ligne de vue de la même façon (pas
# de distinction là-dessus entre les 3 types, pour rester cohérent
# avec le système is_walkable existant) — seule leur couleur et leur
# capacité à être retirés/contournés par un sort diffère.
# ============================================================

enum { BASIC, EAU, VIDE }

static func label(type: int) -> String:
	match type:
		EAU:
			return "Eau"
		VIDE:
			return "Vide"
		_:
			return "Basique"
