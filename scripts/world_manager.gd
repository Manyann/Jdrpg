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

# État du personnage hors combat (barre en bas de l'écran, façon
# Dofus). Initialisé une seule fois depuis UnitDatabase (voir
# ensure_party_initialized), puis persiste tel quel entre les zones —
# jusqu'à ce que le vrai combat soit branché et vienne le modifier.
var party_name: String = "Barbare"
var party_max_hp: int = 0
var party_current_hp: int = 0
var party_max_ea: int = 0
var party_current_ea: int = 0
var party_potions: Array = []

# Objets achetés (armes/armures/accessoires/flèches) — voir zone.gd,
# ShopGenerator. Contrairement aux potions, ces objets restent dans
# l'inventaire même une fois équipés (equipped_* n'est qu'une
# référence vers l'un d'entre eux, pas un retrait de la liste).
var party_weapons: Array = []
var party_armors: Array = []
var party_accessories: Array = []
var party_arrows: Array = []

# Équipement actuellement porté. Une seule arme et une seule armure à
# la fois, mais plusieurs accessoires possibles simultanément.
var party_equipped_weapon: Weapon = null
var party_equipped_armor: Armor = null
var party_equipped_accessories: Array = []

# Monnaie du joueur. Simple var (pas besoin de passer par
# ensure_party_initialized, elle persiste déjà naturellement tant que
# WorldManager reste en mémoire — pas de dépendance à UnitDatabase).
var party_gold: int = 50

# Niveau et expérience — pas encore alimenté par le combat (pas encore
# branché), mais la mécanique est prête : appelle add_experience()
# depuis n'importe où une fois les récompenses de combat en place.
# Niveau et expérience — pas encore alimenté par le combat (pas encore
# branché), mais la mécanique est prête : appelle add_experience()
# depuis n'importe où une fois les récompenses de combat en place.
# Passer du niveau N à N+1 demande N*100 XP.
var party_level: int = 1
var party_current_xp: int = 0
var party_xp_to_next_level: int = party_level * 100

var _party_initialized: bool = false

# À appeler avant d'afficher la barre de statut (voir zone.gd) — ne
# fait rien si déjà initialisé, pour ne jamais réinitialiser les PV/EA
# du joueur à chaque changement de zone.
func ensure_party_initialized() -> void:
	if _party_initialized:
		return

	var stats = UnitDatabase.get_base_stats(party_name)
	party_max_hp = stats.get("max_hp", 50)
	party_current_hp = party_max_hp
	party_max_ea = stats.get("max_ea", 6)
	party_current_ea = party_max_ea
	party_potions = UnitDatabase.build_potions(party_name)

	_party_initialized = true

# Ajoute de l'expérience et gère la/les montée(s) de niveau (au cas où
# un gros gain d'XP ferait passer plusieurs niveaux d'un coup). Passer
# du niveau N à N+1 demande N*100 XP (100 pour 1->2, 200 pour 2->3,
# 500 pour 5->6, etc.).
func add_experience(amount: int) -> void:
	party_current_xp += amount

	while party_current_xp >= party_xp_to_next_level:
		party_current_xp -= party_xp_to_next_level
		party_level += 1
		party_xp_to_next_level = party_level * 100

func add_gold(amount: int) -> void:
	party_gold += amount

# Dépense de l'or si possible. Renvoie false (et ne change rien) si le
# joueur n'a pas assez d'or — à toujours vérifier avant un achat.
func spend_gold(amount: int) -> bool:
	if party_gold < amount:
		return false
	party_gold -= amount
	return true

# Recalcule party_max_hp/party_max_ea à partir des stats de base de la
# classe + les bonus PV/EA de l'équipement actuellement porté. Les
# autres bonus (Attaque, Parade, Armure...) sont pleinement gérés côté
# combat (voir CombatUnit._recalculate_stats) mais n'ont pas encore
# d'affichage en exploration (aucune de ces stats n'y est montrée) —
# seuls PV/EA sont donc répercutés ici, pour un effet visible
# immédiat dans la barre de statut.
func recalculate_party_bonuses() -> void:
	var base_stats = UnitDatabase.get_base_stats(party_name)
	var bonus_hp = 0
	var bonus_ea = 0

	var equipment: Array = []
	if party_equipped_weapon != null:
		equipment.append(party_equipped_weapon)
	if party_equipped_armor != null:
		equipment.append(party_equipped_armor)
	for accessory in party_equipped_accessories:
		equipment.append(accessory)

	for item in equipment:
		bonus_hp += item.bonus_vie
		bonus_ea += item.bonus_mana

	party_max_hp = base_stats.get("max_hp", 50) + bonus_hp
	party_max_ea = base_stats.get("max_ea", 6) + bonus_ea
	party_current_hp = min(party_current_hp, party_max_hp)
	party_current_ea = min(party_current_ea, party_max_ea)

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
