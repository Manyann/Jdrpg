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

# Posture défensive choisie par le joueur à son tour, active jusqu'à
# son tour suivant. Détermine comment cette unité réagit aux attaques
# subies pendant les tours des autres.
enum DefensiveStance { NONE, PARRY, DODGE }

@export var unit_name: String = "Unit"
@export var team: Team = Team.PLAYER
@export var radius: float = 18.0

## Couleurs par équipe.
@export var player_color: Color = Color(0.25, 0.55, 0.95)
@export var enemy_color: Color = Color(0.9, 0.25, 0.25)

# ---------- Sprite (optionnel) ----------
# Si sprite_sheet est renseigné (voir UnitDatabase, clé "sprite"), un
# vrai sprite animé remplace le disque de couleur. Sinon, fallback sur
# le rendu par défaut (cercle + nom). sprite_animations définit les
# différentes poses/animations disponibles (voir plus bas).
@export var sprite_sheet: Texture2D = null
@export var sprite_frame_size: Vector2i = Vector2i(32, 32)
@export var sprite_scale: float = 2.0
## Dictionnaire des animations disponibles pour cette classe, indexé
## par nom ("idle", "walk", "attack", "hurt", "death"...). Chaque entrée :
## {row, start_col, frame_count, fps, loop}. Configuré via UnitDatabase
## (clé "animations" dans le dict "sprite") — voir _setup_sprite().
@export var sprite_animations: Dictionary = {}

## Correction fine de la position verticale du sprite, en pixels
## (positif = vers le bas, négatif = vers le haut). Le calcul par défaut
## place les pieds au centre de l'hexagone, mais selon la marge/le
## padding interne à la feuille de sprites, un ajustement manuel est
## souvent nécessaire — configurable via UnitDatabase (clé "y_offset"
## dans le dict "sprite") sans toucher au code.
@export var sprite_y_offset: float = 0.0

var _sprite: AnimatedSprite2D = null

# Suffixe de direction courant ("_s", "_se", "_e", "_ne", "_n", "_nw",
# "_w", "_sw"), déterminé par face_direction() selon la position de la
# cible/destination parmi les 8 orientations dessinées dans la feuille
# de sprites. play_animation() l'ajoute automatiquement au nom demandé
# (ex: "idle" devient "idle_se") pour choisir la bonne ligne. Retombe
# sur le nom brut si la variante directionnelle n'existe pas (permet de
# garder des animations non-directionnelles comme "cast").
var _current_facing_suffix: String = "_s"

# Coordonnée hexagonale (q, r) sur laquelle l'unité se trouve
# actuellement. Mise à jour par HexGrid lors du placement/déplacement.
var hex_coord: Vector2i

# Stats de base.
@export var max_hp: int = 50
@export var max_pm: int = 3  # Points de mouvement par tour (se réinitialise chaque tour).
@export var max_ea: int = 6  # Réserve d'Énergie Astrale pour TOUT le combat (ne se réinitialise pas).
@export var courage: int = 10  # Détermine l'ordre de passage : plus haut = joue plus tôt.

## Stats de combat (échelle 1-20, comparées à un jet 1d20) :
## - attack_stat : une attaque d'arme ne touche que si 1d20 < attack_stat.
## - parade_stat : en posture Parade, annule une attaque d'arme en mêlée
##   et riposte si 1d20 < parade_stat.
## - adresse_stat : en posture Esquive, annule N'IMPORTE QUELLE attaque
##   (arme ou sort) si 1d20 < adresse_stat — mais une fois sur deux
##   seulement (voir dodge_available).
@export var attack_stat: int = 12
@export var parade_stat: int = 8
@export var adresse_stat: int = 10

## Stats secondaires (échelle 1-20 également) :
## - force_stat : chaque point au-dessus de 12 ajoute 1 dégât aux
##   attaques d'arme en MÊLÉE uniquement (voir get_melee_damage_bonus).
## - intelligence_stat : chaque 2 points au-dessus de 12 ajoute 1 dégât
##   (ou 1 soin) aux SORTS/enchantements (voir get_spell_damage_bonus).
##   Sert aussi au jet de lancer d'un sort (moyenne avec Adresse ou
##   Charisme selon le type du sort).
## - charisme_stat : utilisé avec Intelligence pour lancer un sort
##   psychique.
## - chance_stat : réservée pour un usage futur (critiques, etc.),
##   aucun effet implémenté pour l'instant.
@export var force_stat: int = 10
@export var intelligence_stat: int = 10
@export var charisme_stat: int = 10
@export var chance_stat: int = 10

func get_melee_damage_bonus() -> int:
	return max(0, force_stat - 12)

func get_spell_damage_bonus() -> int:
	return max(0, int((intelligence_stat - 12) / 2.0))

# Posture actuelle (choisie à son tour, persiste jusqu'au tour suivant).
# Par défaut : Parade (pas de posture "Aucune").
# (Non typé strictement en DefensiveStance pour éviter tout risque de
# type mismatch runtime, comme observé avec Array[Spell] plus tôt.)
var defensive_stance: int = DefensiveStance.PARRY

# Vrai si l'unité peut encore tenter d'esquiver la PROCHAINE attaque
# qu'elle subit (règle "1 attaque sur 2"). Remis à true au début de
# son propre tour (voir reset_turn_resources).
var dodge_available: bool = true

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

	if sprite_sheet != null:
		_setup_sprite()

	queue_redraw()

# Construit un AnimatedSprite2D à partir de la feuille de sprites, en
# découpant des régions (AtlasTexture) directement dans la texture
# source — une passe par animation définie dans sprite_animations.
func _setup_sprite() -> void:
	var frames := SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")  # Animation vide créée par défaut par Godot, inutile ici.

	for anim_name in sprite_animations.keys():
		var config = sprite_animations[anim_name]
		var row = config.get("row", 0)
		var start_col = config.get("start_col", 0)
		var frame_count = config.get("frame_count", 1)
		var fps = config.get("fps", 6.0)
		var loop = config.get("loop", true)

		frames.add_animation(anim_name)
		frames.set_animation_loop(anim_name, loop)
		frames.set_animation_speed(anim_name, fps)

		for i in range(frame_count):
			var col = start_col + i
			var atlas := AtlasTexture.new()
			atlas.atlas = sprite_sheet
			atlas.region = Rect2(
				col * sprite_frame_size.x,
				row * sprite_frame_size.y,
				sprite_frame_size.x,
				sprite_frame_size.y
			)
			frames.add_frame(anim_name, atlas)

	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = frames
	_sprite.scale = Vector2(sprite_scale, sprite_scale)

	# AnimatedSprite2D centre son image sur sa position par défaut. On le
	# décale vers le haut de la moitié de sa hauteur pour que ce soit le
	# BAS du sprite (les pieds) qui touche le centre de l'hexagone, et non
	# son centre — sinon le personnage semble "enfoncé" dans la case.
	# sprite_y_offset permet ensuite un réglage fin manuel.
	var full_height = sprite_frame_size.y * sprite_scale
	_sprite.position = Vector2(0, -full_height * 0.5 + sprite_y_offset)

	_sprite.animation_finished.connect(_on_sprite_animation_finished)

	add_child(_sprite)
	play_animation("idle")

# Joue une animation par son nom logique ("idle", "walk", "attack"...).
# Essaie d'abord la variante directionnelle courante (ex: "idle_side"),
# et retombe sur le nom brut si elle n'existe pas (utile pour les
# animations sans variante par direction, comme "cast"). Ne fait rien
# silencieusement si aucune des deux n'existe pour cette classe.
func play_animation(anim_name: String) -> void:
	if _sprite == null or _sprite.sprite_frames == null:
		return

	var directional_name = anim_name + _current_facing_suffix
	if _sprite.sprite_frames.has_animation(directional_name):
		_sprite.animation = directional_name
		_sprite.play()
	elif _sprite.sprite_frames.has_animation(anim_name):
		_sprite.animation = anim_name
		_sprite.play()

# Les animations "one-shot" (attaque, touché...) reviennent
# automatiquement à l'idle une fois terminées. "death" ne revient pas :
# l'unité est retirée juste après (voir die()).
func _on_sprite_animation_finished() -> void:
	if _sprite.animation.begins_with("death"):
		return
	play_animation("idle")

# Détermine la direction à afficher parmi les 8 orientations dessinées
# dans la feuille de sprites (S, SE, E, NE, N, NW, O, SO), vers une
# position cible en coordonnées locales à HexGrid (le même repère que
# `position`). Chaque direction a sa propre ligne dans le spritesheet
# (pas de miroir nécessaire, contrairement à la version précédente).
func face_direction(target_local_pos: Vector2) -> void:
	if _sprite == null:
		return

	var delta = target_local_pos - position
	if delta.length_squared() < 0.01:
		return  # Cible ~sur soi : on ne change pas l'orientation actuelle.

	var angle_deg = rad_to_deg(atan2(delta.y, delta.x))  # 0° = est, 90° = sud (écran Godot), -90° = nord

	# Découpe le cercle en 8 secteurs de 45°, centrés sur chaque direction.
	var index = int(round(angle_deg / 45.0))
	index = ((index % 8) + 8) % 8

	var directions = ["e", "se", "s", "sw", "w", "nw", "n", "ne"]
	_current_facing_suffix = "_" + directions[index]
	_sprite.flip_h = false

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
	dodge_available = true

func set_defensive_stance(stance: int) -> void:
	defensive_stance = stance

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
	var name_y_offset: float

	if sprite_sheet != null:
		# Le vrai sprite (enfant AnimatedSprite2D) s'affiche par-dessus.
		# sprite_y_offset corrige une éventuelle marge interne/transparente
		# de la feuille de sprites pour que les pieds VISIBLES tombent au
		# centre de l'hexagone (y=0) — le socle reste donc fixe ici, il ne
		# doit PAS suivre ce réglage (sinon il se désynchronise des pieds
		# une fois la marge compensée).
		var full_height = sprite_frame_size.y * sprite_scale
		draw_arc(Vector2(0, 3), full_height * 0.12, 0, TAU, 24, color, 3.0, true)
		name_y_offset = sprite_y_offset - full_height - 8
	else:
		# Fallback : disque de couleur plein (pas encore de sprite pour
		# cette classe).
		draw_circle(Vector2.ZERO, radius, color)
		draw_arc(Vector2.ZERO, radius, 0, TAU, 32, Color.BLACK, 2.0, true)
		name_y_offset = -radius - 8

	# Nom de l'unité affiché au-dessus.
	var font = ThemeDB.fallback_font
	draw_string(
		font,
		Vector2(-radius, name_y_offset),
		unit_name,
		HORIZONTAL_ALIGNMENT_CENTER,
		radius * 2,
		14,
		Color.WHITE
	)

# Déplace l'unité vers une nouvelle position pixel (appelé par HexGrid).
# Glisse en douceur (au lieu d'un téléport instantané) et joue
# l'animation de marche pendant le trajet si elle existe pour cette
# classe ; revient à l'idle une fois arrivé.
func move_to_pixel(pixel_pos: Vector2) -> void:
	face_direction(pixel_pos)
	play_animation("walk")

	var tween = create_tween()
	tween.tween_property(self, "position", pixel_pos, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.finished.connect(func(): play_animation("idle"))

func take_damage(amount: int) -> void:
	var was_alive = current_hp > 0

	# Un montant négatif (ex: sort de soin) augmente les PV au lieu de
	# les diminuer — clampé pour ne jamais dépasser max_hp ni descendre
	# sous 0.
	current_hp = clamp(current_hp - amount, 0, max_hp)

	if amount > 0 and was_alive:
		if current_hp == 0:
			die()
		else:
			play_animation("hurt")
	# amount <= 0 (soin) : pas d'animation de touché.

func die() -> void:
	died.emit(self)

	# Si une animation de mort existe pour cette classe, on la joue et on
	# attend qu'elle se termine avant de retirer l'unité de la scène —
	# elle est déjà retirée du combat (signal "died" traité par HexGrid),
	# seul son cadavre reste visible brièvement pour l'effet.
	if _sprite != null and _sprite.sprite_frames != null and _sprite.sprite_frames.has_animation("death"):
		play_animation("death")
		var frame_count = _sprite.sprite_frames.get_frame_count("death")
		var fps = _sprite.sprite_frames.get_animation_speed("death")
		var duration = float(frame_count) / fps if fps > 0 else 0.5
		await get_tree().create_timer(duration).timeout

	queue_free()
