extends Node2D
class_name CombatUnit

# ============================================================
# unit.gd
# Représente une unité de combat (joueur ou ennemi) placée sur
# une case de la grille hexagonale.
#
# Pour l'instant le visuel est un simple cercle coloré + le nom
# de l'unité affiché au-dessus. On remplacera ça par de vrais
# sprites plus tard sans changer la logique.
# ============================================================

enum Team { PLAYER, ENEMY }

@export var unit_name: String = "Unit"
@export var team: Team = Team.PLAYER
@export var radius: float = 18.0

## Couleurs par équipe.
@export var player_color: Color = Color(0.25, 0.55, 0.95)
@export var enemy_color: Color = Color(0.9, 0.25, 0.25)

# Coordonnée hexagonale (q, r) sur laquelle l'unité se trouve
# actuellement. Mise à jour par HexGrid lors du placement/déplacement.
var hex_coord: Vector2i

# Stats de base.
@export var max_hp: int = 50
@export var max_pm: int = 3  # Points de mouvement par tour (se réinitialise chaque tour).
@export var max_ea: int = 6  # Réserve d'Énergie Astrale pour TOUT le combat (ne se réinitialise pas).
@export var courage: int = 10  # Détermine l'ordre de passage : plus haut = joue plus tôt.

## Si activé, l'unité peut équiper une seconde arme (off_hand_weapon)
## et bénéficie donc de 2 attaques d'arme par tour au lieu d'une seule
## (une par arme). Sans Ambidextrie : 1 seule arme, 1 seule attaque
## d'arme possible par tour.
@export var has_ambidextrie: bool = false

## Arme en main principale — détermine les dégâts ET la portée de
## l'attaque générée automatiquement dans _ready() (mêlée ou à
## distance selon l'arme). Si non définie, une arme à mains nues
## ("Poings") est utilisée par défaut.
@export var equipped_weapon: Weapon = null

## Arme en main secondaire — uniquement utilisée si has_ambidextrie
## est activé. Génère une deuxième attaque d'arme distincte.
@export var off_hand_weapon: Weapon = null

## Sorts/enchantements disponibles pour cette unité (hors attaque(s)
## d'arme, ajoutées automatiquement dans _ready() à partir des armes
## équipées).
## (Tableau volontairement non typé strictement : GDScript propage mal
## le typage Array[Spell] à travers un retour de fonction statique.)
@export var spells: Array = []

## Inventaire : armes de rechange (pour changer d'arme en combat),
## potions (soin ou mana), et flèches (munitions pour une arme à
## distance, choisies juste avant de tirer).
@export var inventory_weapons: Array = []
@export var inventory_potions: Array = []
@export var inventory_arrows: Array = []

var current_hp: int
var current_pm: int
var current_ea: int

# Nombre d'actions (hors déplacement) déjà utilisées ce tour-ci.
# Remis à zéro à chaque tour par reset_turn_resources().
var actions_used_this_turn: int = 0

# Reste vrai tant que TOUTES les actions de ce tour sont des attaques
# d'arme (mêlée ou à distance, peu importe). Dès qu'une action d'un
# autre type est utilisée (sort, potion, changement d'arme...), passe
# à false et le bonus Ambidextrie (2e attaque d'arme) devient
# impossible pour le reste de ce tour.
var all_actions_weapon_attacks_this_turn: bool = true

# Sorts (Resource Spell) déjà utilisés ce tour-ci — empêche de lancer
# deux fois le même sort/la même arme dans le même tour (utile surtout
# pour l'Ambidextrie : chaque arme ne peut frapper qu'une fois).
var spells_used_this_turn: Array = []

# Représente "l'action utilitaire" du tour (boire une potion, changer
# d'arme, ramasser une arme...) pour l'économie d'action : ce n'est pas
# une attaque d'arme, donc son utilisation consomme l'unique action
# normale du tour (voir can_perform_action / record_action_taken).
var utility_action_slot: Spell

# Émis quand l'unité meurt (HexGrid et TurnManager s'y abonnent pour
# se nettoyer proprement : libérer la case, retirer de la file de tours).
signal died(unit: CombatUnit)

func _ready() -> void:
	current_hp = max_hp
	current_pm = max_pm
	current_ea = max_ea
	actions_used_this_turn = 0
	all_actions_weapon_attacks_this_turn = true

	# Toute unité a au moins une attaque d'arme, générée à partir de son
	# arme équipée (mains nues par défaut si aucune arme n'est définie).
	if equipped_weapon == null:
		equipped_weapon = _create_default_weapon()
	spells.insert(0, equipped_weapon.create_attack_spell())

	# Une seconde attaque d'arme (main secondaire) uniquement si l'unité
	# a l'Ambidextrie ET qu'une arme secondaire est définie.
	if has_ambidextrie and off_hand_weapon != null:
		spells.insert(1, off_hand_weapon.create_attack_spell())

	utility_action_slot = Spell.new()
	utility_action_slot.spell_name = "Action utilitaire"
	utility_action_slot.is_weapon_attack = false
	utility_action_slot.ea_cost = 0

	queue_redraw()

func _create_default_weapon() -> Weapon:
	var w := Weapon.new()
	w.weapon_name = "Poings"
	w.damage = 5
	w.weapon_type = Weapon.WeaponType.MELEE
	w.min_range = 1
	w.max_range = 1
	return w

# Réinitialise les PM et le compteur d'actions — appelé par TurnManager
# au début du tour de cette unité. L'EA, elle, N'EST PAS réinitialisée
# ici : c'est une réserve unique pour tout le combat.
func reset_turn_resources() -> void:
	current_pm = max_pm
	actions_used_this_turn = 0
	all_actions_weapon_attacks_this_turn = true
	spells_used_this_turn.clear()

# Renvoie le sort "emplacement" à utiliser pour le suivi économie
# d'action : si `spell` est une variante temporaire (ex: tir à l'arc
# avec une flèche spéciale), on doit compter contre son origin_spell,
# pas contre la variante elle-même (sinon on pourrait la réutiliser
# indéfiniment en changeant juste de flèche).
func _resolve_action_slot(spell: Spell) -> Spell:
	return spell.origin_spell if spell.origin_spell != null else spell

# Détermine si l'unité peut encore utiliser CE sort précis ce tour-ci.
# Règle : 1 action normale par tour, OU 2 attaques d'arme si l'unité a
# l'Ambidextrie (jamais les deux à la fois) — ET un même
# sort/arme/action ne peut jamais être utilisé(e) deux fois par tour.
func can_perform_action(spell: Spell) -> bool:
	var slot = _resolve_action_slot(spell)

	if spells_used_this_turn.has(slot):
		return false  # Déjà utilisé(e) ce tour-ci.

	var would_stay_all_weapon_attacks = all_actions_weapon_attacks_this_turn and slot.is_weapon_attack
	var max_allowed = 2 if (has_ambidextrie and would_stay_all_weapon_attacks) else 1
	return actions_used_this_turn < max_allowed

# Enregistre qu'un sort/une action vient d'être utilisé(e) : incrémente
# le compteur d'actions et marque l'emplacement correspondant comme
# indisponible pour le reste du tour.
func record_action_taken(spell: Spell) -> void:
	var slot = _resolve_action_slot(spell)
	actions_used_this_turn += 1
	all_actions_weapon_attacks_this_turn = all_actions_weapon_attacks_this_turn and slot.is_weapon_attack
	spells_used_this_turn.append(slot)

# Tente de consommer l'action utilitaire du tour (boire une potion,
# changer d'arme...). Renvoie false si l'action du tour est déjà prise.
func try_use_utility_action() -> bool:
	if not can_perform_action(utility_action_slot):
		return false
	record_action_taken(utility_action_slot)
	return true

# Boit une potion de l'inventaire : consomme l'action utilitaire du
# tour, applique l'effet (soin ou mana), puis retire la potion.
# Renvoie le gain RÉEL appliqué (peut être inférieur à potion.amount
# si déjà proche du plafond), ou -1 si l'action du tour n'est plus
# disponible (rien n'a été consommé dans ce cas).
func use_potion(potion: Potion) -> int:
	if not try_use_utility_action():
		return -1

	var actual_gain := 0

	if potion.potion_type == Potion.PotionType.HEAL:
		var before = current_hp
		take_damage(-potion.amount)  # Montant négatif = soin (voir take_damage).
		actual_gain = current_hp - before
	else:
		var before = current_ea
		current_ea = min(current_ea + potion.amount, max_ea)
		actual_gain = current_ea - before

	inventory_potions.erase(potion)
	return actual_gain

# Change l'arme principale équipée : consomme l'action utilitaire du
# tour, remet l'ancienne arme dans l'inventaire, retire son attaque de
# la liste de sorts et génère celle de la nouvelle arme. Renvoie false
# si l'action du tour n'est plus disponible.
func equip_weapon(new_weapon: Weapon) -> bool:
	if not try_use_utility_action():
		return false

	# Retire l'attaque générée par l'ancienne arme principale.
	spells = spells.filter(func(s): return s.source_weapon != equipped_weapon)

	if equipped_weapon != null:
		inventory_weapons.append(equipped_weapon)
	inventory_weapons.erase(new_weapon)

	equipped_weapon = new_weapon
	spells.insert(0, equipped_weapon.create_attack_spell())
	return true

func _draw() -> void:
	var color = player_color if team == Team.PLAYER else enemy_color

	# Disque de couleur représentant l'unité.
	draw_circle(Vector2.ZERO, radius, color)

	# Contour noir pour la lisibilité sur le fond de la grille.
	draw_arc(Vector2.ZERO, radius, 0, TAU, 32, Color.BLACK, 2.0, true)

	# Nom de l'unité affiché au-dessus.
	var font = ThemeDB.fallback_font
	draw_string(
		font,
		Vector2(-radius, -radius - 8),
		unit_name,
		HORIZONTAL_ALIGNMENT_CENTER,
		radius * 2,
		14,
		Color.WHITE
	)

# Déplace l'unité vers une nouvelle position pixel (appelé par HexGrid).
# Séparé en fonction pour pouvoir plus tard y ajouter une animation
# de glissement plutôt qu'un téléport instantané.
func move_to_pixel(pixel_pos: Vector2) -> void:
	position = pixel_pos

func take_damage(amount: int) -> void:
	# Un montant négatif (ex: sort de soin) augmente les PV au lieu de
	# les diminuer — clampé pour ne jamais dépasser max_hp ni descendre
	# sous 0.
	current_hp = clamp(current_hp - amount, 0, max_hp)
	if current_hp == 0:
		die()

func die() -> void:
	died.emit(self)
	queue_free()
