extends Resource
class_name Arrow

# ============================================================
# arrow.gd
# Type de munition pour une arme à distance (arc, arbalète...).
# Modifie les dégâts de l'attaque d'arme générée par le Weapon.
# Choisi juste après avoir cliqué sur l'attaque d'une arme à
# distance, avant de sélectionner la cible (voir TurnManager).
# ============================================================

@export var arrow_name: String = "Flèche normale"
@export var damage_bonus: int = 0

## Nombre de flèches de ce type restant en carquois. Décrémenté à
## chaque tir (voir TurnManager._open_arrow_popup) ; à 0, le bouton
## correspondant se grise et ne peut plus être utilisé.
@export var quantity: int = 10

func get_display_text() -> String:
	var bonus_text = ""
	if damage_bonus > 0:
		bonus_text = " (+%d dégâts)" % damage_bonus
	elif damage_bonus < 0:
		bonus_text = " (%d dégâts)" % damage_bonus
	return "%s%s — x%d" % [arrow_name, bonus_text, quantity]
