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

# Race choisie par le joueur — INDÉPENDAMMENT de la classe (party_name).
# "Humain" par défaut : la seule race sans aucun prérequis ni malus
# dans les données d'origine, un choix neutre raisonnable tant que
# rien ne demande explicitement au joueur de choisir.
var party_race_name: String = "Humain"

# Métier choisi par le joueur (voir metier.gd/MetierDatabase — Guerrier,
# Mage, Voleur, Prêtre... NE PAS confondre avec la race). S'ajoute EN
# PLUS de party_name, qui reste la classe "maison" (stats de base,
# sorts — voir UnitDatabase.TEMPLATES) : le métier n'apporte que ses
# bonus_* et ses compétences (voir CombatUnit.has_skill), sans
# remplacer le système de classe existant. "MG" (Mage, Sorcier) par
# défaut, cohérent avec party_name = "Mage".
var party_metier_short_code: String = "MG"

# Ordre choisi par le joueur SI son métier est Prêtre (voir
# CombatUnit.pretre_order / pretre_spell_catalog.gd) — sans effet pour
# tout autre métier. "Ordre de l'harmonie" par défaut : un choix
# neutre tant que rien ne demande explicitement au joueur de choisir.
var party_pretre_order: String = "Ordre de l'harmonie"

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
	party_max_ea = stats.get("max_ea", 6)
	party_potions = UnitDatabase.build_potions(party_name)

	_party_initialized = true

	recalculate_party_bonuses()  # Applique le bonus de la race par défaut (Humain) dès le départ.
	party_current_hp = party_max_hp
	party_current_ea = party_max_ea

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

	var race = RaceDatabase.build(party_race_name)
	if race != null:
		equipment.append(race)

	var metier = MetierDatabase.build(party_metier_short_code)
	if metier != null:
		equipment.append(metier)

	for item in equipment:
		bonus_hp += item.bonus_vie
		bonus_ea += item.bonus_mana

	party_max_hp = base_stats.get("max_hp", 50) + bonus_hp
	party_max_ea = base_stats.get("max_ea", 6) + bonus_ea
	party_current_hp = min(party_current_hp, party_max_hp)
	party_current_ea = min(party_current_ea, party_max_ea)

# Appelé par TurnManager à la fin d'un combat déclenché par une
# rencontre d'exploration (voir show_combat_end/_return_to_exploration
# dans turn_manager.gd). Synchronise l'état du joueur et revient à la
# zone d'exploration.
#
# `surviving_hp`/`surviving_ea` : PV/EA du personnage à la fin du
# combat (uniquement significatif en cas de victoire — en cas de
# défaite, l'unité du joueur a été détruite, on ne peut plus lire ses
# PV, donc ces deux paramètres sont ignorés et une valeur de
# réapparition par défaut est utilisée à la place).
func finish_encounter_combat(victory: bool, surviving_hp: int, surviving_ea: int, human_enemies_fought: int = 0) -> void:
	if victory:
		party_current_hp = min(surviving_hp, party_max_hp)
		party_current_ea = min(surviving_ea, party_max_ea)
		current_zone_name = return_zone_name
		player_spawn_position = return_position

		# Premiers soins (PS) / Récupération (RE) : appliqués APRÈS la
		# survie des PV/EA de fin de combat — un vrai "en plus", pas un
		# remplacement. "Chaque personne du groupe" = notre unique
		# personnage suivi pour l'instant (pas de groupe multi-membres
		# côté exploration). Vérifie la race ET le métier (mêmes codes,
		# voir SkillDatabase).
		var codes: Array = []
		var race = RaceDatabase.build(party_race_name)
		if race != null:
			for c in race.inherited_skill_codes:
				codes.append(c.rstrip("*"))
		var metier = MetierDatabase.build(party_metier_short_code)
		if metier != null:
			for c in metier.inherited_skill_codes:
				codes.append(c.rstrip("*"))
		if codes.has("PS"):
			party_current_hp = min(party_current_hp + randi_range(1, 6) + 1, party_max_hp)
		if codes.has("RE"):
			party_current_ea = min(party_current_ea + randi_range(1, 6) + 1, party_max_ea)

		# Tout l'or de "butin" de fin de combat (récompense de base +
		# Larcin) est regroupé AVANT d'être versé, pour que le bonus du
		# Chasseur de trésor (+15%, voir plus bas) s'applique sur le
		# TOTAL — pas juste sur une des deux sources séparément.
		var loot_gold = 20  # Petite récompense de victoire — à ajuster/relier plus tard à la difficulté réelle des ennemis vaincus si besoin.

		# Larcin (Voleur) : +5 PO par ennemi HUMAIN affronté ce combat
		# (voir TurnManager.start_combat / HexGrid.human_enemies_fought).
		if party_metier_short_code == "VO" and human_enemies_fought > 0:
			var larcin_gold = human_enemies_fought * 5
			loot_gold += larcin_gold
			print("Larcin : +%d PO (%d ennemi(s) humain(s))." % [larcin_gold, human_enemies_fought])

		# Récit (Barde) / Récit épique (Ménestrel, 1D20 au lieu de 1D12 —
		# Ménestrel EST un Barde avancé, donc remplace Récit plutôt que
		# de s'y ajouter) : +1D en plus, après tout le reste (PS/RE compris).
		if party_metier_short_code == "BD" or party_metier_short_code == "ML":
			var recit_sides = 20 if party_metier_short_code == "ML" else 12
			var recit_ea = randi_range(1, recit_sides)
			party_current_ea = min(party_current_ea + recit_ea, party_max_ea)
			print("%s : +%d EA." % ["Récit épique" if party_metier_short_code == "ML" else "Récit", recit_ea])

		# Chasseur de trésor : +15% sur TOUT le butin d'or de fin de
		# combat (le total ci-dessus, Larcin compris).
		if party_metier_short_code == "CT":
			var bonus = int(round(loot_gold * 0.15))
			loot_gold += bonus
			print("Chasseur de trésor : +%d PO (+15%%)." % bonus)

		add_gold(loot_gold)
		add_experience(30)
	else:
		# Défaite : réapparition au village avec la moitié des PV, EA
		# pleine. Pas d'écran "Game Over" pour l'instant.
		current_zone_name = "Village"
		player_spawn_position = Vector2(400, 400)
		party_current_hp = int(party_max_hp / 2.0)
		party_current_ea = party_max_ea

	combat_from_encounter = false
	forced_placement_mode = ""
	pending_encounter_enemies = []

	var err = get_tree().change_scene_to_file(zone_scene_path)
	if err != OK:
		push_warning("WorldManager: impossible de charger '%s' (code erreur %d). Vérifie/ajuste zone_scene_path." % [zone_scene_path, err])

# Renseignés juste avant de déclencher un combat (rencontre) : quels
# ennemis affronter, et où revenir une fois le combat terminé. Pas
# encore lus par la scène de combat (à brancher à l'étape suivante).
var pending_encounter_enemies: Array = []
var return_zone_name: String = ""
var return_position: Vector2 = Vector2.ZERO

# ⚠️ À VÉRIFIER/AJUSTER : chemins réels de tes deux scènes dans ton
# projet. Si le mauvais chemin est utilisé, un avertissement clair
# s'affiche dans la console au lieu de planter — corrige ces deux
# lignes en conséquence.
var combat_scene_path: String = "res://scenes/combat.tscn"
var zone_scene_path: String = "res://scenes/zone.tscn"

# Vrai pendant qu'un combat est en cours suite à une rencontre
# d'exploration (par opposition à un lancement direct de la scène de
# combat pour la tester toute seule) — conditionne le retour
# automatique vers l'exploration à la fin du combat (voir
# TurnManager.show_combat_end/_return_to_exploration).
var combat_from_encounter: bool = false

# "classic" ou "ambush" — mode de placement forcé pour ce combat
# (tiré au sort dans start_encounter_combat, jamais "defense" pour une
# rencontre aléatoire). Vide = pas de mode forcé (choix manuel normal).
var forced_placement_mode: String = ""

# Déclenche le passage à la scène de combat suite à une rencontre
# d'exploration. Tire le mode de placement (20% Embuscade, 80%
# Classique) et prépare tout ce dont HexGrid/PlacementManager auront
# besoin au chargement (voir HexGrid._ready(), PlacementManager.start_placement_phase).
func start_encounter_combat(enemies: Array, from_zone: String, from_position: Vector2) -> void:
	pending_encounter_enemies = enemies
	return_zone_name = from_zone
	return_position = from_position
	combat_from_encounter = true
	forced_placement_mode = "ambush" if randf() < 0.2 else "classic"

	var err = get_tree().change_scene_to_file(combat_scene_path)
	if err != OK:
		push_warning("WorldManager: impossible de charger '%s' (code erreur %d). Vérifie/ajuste combat_scene_path." % [combat_scene_path, err])
		combat_from_encounter = false  # On reste en exploration plutôt que de rester bloqué.

# Change la zone courante et la position d'arrivée du joueur. Appelé
# par zone.gd quand le joueur franchit un bord ; le script appelant
# doit ensuite recharger la scène (get_tree().reload_current_scene())
# pour que le changement prenne effet visuellement.
func travel_to_zone(zone_name: String, spawn_position: Vector2) -> void:
	current_zone_name = zone_name
	player_spawn_position = spawn_position
