extends Node2D
class_name ExplorerAvatar

# ============================================================
# explorer_avatar.gd
# Représente le personnage du joueur pendant l'exploration (scène
# Zone). Même principe d'animation directionnelle à 8 sens que
# CombatUnit (voir unit.gd) — sprite_animations, suffixe _s/_se/_e/...
# choisi selon la direction visée, retour automatique à "idle" une
# fois une animation ponctuelle terminée.
#
# Volontairement séparé de CombatUnit : celui-ci est chargé de
# concepts propres au combat (PV, sorts, armes...) qui n'ont pas leur
# place ici. Seule la logique de sprite/direction est dupliquée,
# sciemment, pour ne pas risquer de casser le système de combat déjà
# testé en le faisant dépendre de l'exploration (ou l'inverse).
# ============================================================

@export var sprite_sheet: Texture2D = null
@export var sprite_frame_size: Vector2i = Vector2i(32, 32)
@export var sprite_scale: float = 2.0
@export var sprite_y_offset: float = 0.0

## Dictionnaire d'animations (voir UnitDatabase.build_sprite_animations)
## — typiquement rempli avec celles d'une classe existante (Barbare par
## défaut) pour ne pas dupliquer la configuration.
@export var sprite_animations: Dictionary = {}

## Couleur de repli si aucun sprite n'est configuré (sprite_sheet null).
@export var fallback_color: Color = Color(0.3, 0.6, 0.95)

var _sprite: AnimatedSprite2D = null
var _current_facing_suffix: String = "_s"

func _ready() -> void:
	if sprite_sheet != null:
		_setup_sprite()
	queue_redraw()

func _setup_sprite() -> void:
	var frames := SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")

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

	# Même correction "pieds au centre" que pour les unités de combat.
	var full_height = sprite_frame_size.y * sprite_scale
	_sprite.position = Vector2(0, -full_height * 0.5 + sprite_y_offset)

	_sprite.animation_finished.connect(_on_sprite_animation_finished)
	add_child(_sprite)

	play_animation("idle")

# Joue une animation par son nom logique ("idle", "walk"...), en
# essayant d'abord la variante directionnelle courante puis en
# retombant sur le nom brut si elle n'existe pas.
func play_animation(anim_name: String) -> void:
	if _sprite == null or _sprite.sprite_frames == null:
		return

	var directional_name = anim_name + _current_facing_suffix
	if _sprite.sprite_frames.has_animation(directional_name):
		if _sprite.animation != directional_name:
			_sprite.animation = directional_name
			_sprite.play()
	elif _sprite.sprite_frames.has_animation(anim_name):
		if _sprite.animation != anim_name:
			_sprite.animation = anim_name
			_sprite.play()

func _on_sprite_animation_finished() -> void:
	play_animation("idle")

# Détermine la direction à afficher parmi les 8 orientations (voir
# unit.gd pour la version combat, identique ici), vers une position
# cible en coordonnées locales au parent (Zone).
func face_direction(target_local_pos: Vector2) -> void:
	if _sprite == null:
		return

	var delta = target_local_pos - position
	if delta.length_squared() < 0.01:
		return

	var angle_deg = rad_to_deg(atan2(delta.y, delta.x))
	var index = int(round(angle_deg / 45.0))
	index = ((index % 8) + 8) % 8

	var directions = ["e", "se", "s", "sw", "w", "nw", "n", "ne"]
	_current_facing_suffix = "_" + directions[index]

func _draw() -> void:
	if sprite_sheet != null:
		return  # Le vrai sprite (enfant AnimatedSprite2D) suffit.

	# Solution de repli si aucun sprite n'est configuré : le disque
	# coloré d'origine.
	draw_circle(Vector2.ZERO, 14, fallback_color)
	draw_arc(Vector2.ZERO, 14, 0, TAU, 24, Color.BLACK, 2.0, true)
