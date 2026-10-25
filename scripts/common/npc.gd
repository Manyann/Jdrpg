extends Node2D
class_name Npc

# ============================================================
# npc.gd
# Personnage non-joueur statique, placé dans une zone (voir WorldMap,
# clé "npcs"). Affiche un dialogue (une ou plusieurs lignes) quand le
# joueur s'en approche et appuie sur E — voir zone.gd pour la logique
# de proximité/interaction.
# ============================================================

@export var npc_name: String = "PNJ"

## Lignes affichées une par une (E pour passer à la suivante, ou pour
## fermer sur la dernière). Tableau vide = pas de dialogue du tout —
## utile pour un marchand qui ouvre sa boutique directement.
@export var dialogue_lines: Array = []

# Stock d'une boutique : liste de {"kind": "weapon"/"armor"/
# "accessory"/"potion"/"arrow", "resource": Weapon/Armor/Accessory/
# Potion/Arrow}. Rempli au runtime par zone.gd (_roll_merchant_stock),
# PAS depuis les données statiques de WorldMap (le tirage dépend du
# type de ville + d'un jet aléatoire, voir ShopGenerator.roll_stock).
# Tableau vide = ce PNJ n'est pas un marchand. Si dialogue_lines n'est
# pas vide, la boutique s'ouvre automatiquement à la fin du dialogue.
var shop_stock: Array = []

## Optionnel : nom d'une classe de UnitDatabase (ex: "Barbare") pour
## réutiliser son sprite en pose idle statique. Laisse vide pour un
## simple marqueur en losange coloré avec le nom au-dessus.
@export var sprite_template: String = ""

@export var marker_color: Color = Color(0.8, 0.65, 0.25)

var _sprite: AnimatedSprite2D = null

func _ready() -> void:
	if sprite_template != "":
		_setup_sprite()
	queue_redraw()

# Récupère la config sprite de la classe indiquée (voir UnitDatabase)
# et n'en garde que la pose idle de face (_s), suffisante pour un PNJ
# immobile — pas besoin des 8 directions ni des autres animations.
func _setup_sprite() -> void:
	var stats = UnitDatabase.get_base_stats(sprite_template)
	var sprite_data = stats.get("sprite", null)
	if sprite_data == null:
		return

	var sprite_path = sprite_data.get("path", "")
	if sprite_path == "" or not ResourceLoader.exists(sprite_path):
		return

	var sprite_sheet = load(sprite_path)
	var frame_size = Vector2i(sprite_data.get("frame_width", 32), sprite_data.get("frame_height", 32))
	var scale_factor = sprite_data.get("scale", 2.0)
	var y_offset = sprite_data.get("y_offset", 0.0)
	var animations = UnitDatabase.build_sprite_animations(sprite_template)

	var idle_config = animations.get("idle_s", null)
	if idle_config == null:
		return

	var frames := SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")

	frames.add_animation("idle")
	frames.set_animation_loop("idle", idle_config.get("loop", true))
	frames.set_animation_speed("idle", idle_config.get("fps", 6.0))

	for i in range(idle_config.get("frame_count", 1)):
		var col = idle_config.get("start_col", 0) + i
		var atlas := AtlasTexture.new()
		atlas.atlas = sprite_sheet
		atlas.region = Rect2(
			col * frame_size.x,
			idle_config.get("row", 0) * frame_size.y,
			frame_size.x,
			frame_size.y
		)
		frames.add_frame("idle", atlas)

	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = frames
	_sprite.animation = "idle"
	_sprite.scale = Vector2(scale_factor, scale_factor)

	var full_height = frame_size.y * scale_factor
	_sprite.position = Vector2(0, -full_height * 0.5 + y_offset)

	add_child(_sprite)
	_sprite.play()

func _draw() -> void:
	if _sprite != null:
		return  # Vrai sprite déjà affiché par-dessus.

	# Marqueur de repli : petit losange coloré + nom au-dessus.
	var points = PackedVector2Array([
		Vector2(0, -18), Vector2(14, 0), Vector2(0, 18), Vector2(-14, 0),
	])
	draw_colored_polygon(points, marker_color)

	var outline = points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, Color.BLACK, 2.0, true)

	var font = ThemeDB.fallback_font
	draw_string(font, Vector2(-40, -26), npc_name, HORIZONTAL_ALIGNMENT_CENTER, 80, 14, Color.WHITE)
