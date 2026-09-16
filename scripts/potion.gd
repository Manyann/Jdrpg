extends Resource
class_name Potion

# ============================================================
# potion.gd
# Objet consommable d'inventaire : soigne des PV ou restaure de
# l'Énergie Astrale. Utilisé une fois puis retiré de l'inventaire.
# Boire une potion consomme l'action utilitaire du tour (voir
# CombatUnit.use_potion() / try_use_utility_action()).
# ============================================================

enum PotionType { HEAL, MANA }

@export var potion_name: String = "Potion de soin"
@export var potion_type: PotionType = PotionType.HEAL
@export var amount: int = 20

func get_display_text() -> String:
	if potion_type == PotionType.HEAL:
		return "%s (+%d PV)" % [potion_name, amount]
	return "%s (+%d EA)" % [potion_name, amount]
