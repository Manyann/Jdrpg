extends Node2D

# ============================================================
# zone.gd
# Scène d'exploration : représente UNE zone bornée (façon Dofus), avec
# déplacement libre du joueur (WASD/flèches), changement de zone en
# touchant un bord, et un jet de rencontre unique à l'entrée dans
# chaque zone (rester/se balader n'augmente pas les chances).
#
# Cette MÊME scène est réutilisée pour toutes les zones : à chaque
# changement, WorldManager met à jour la zone/position courante puis
# on recharge la scène (get_tree().reload_current_scene()), qui relit
# alors les nouvelles données depuis WorldMap dans _ready().
#
# INSTALLATION :
# 1. Crée une NOUVELLE scène (différente de ta scène de combat) avec
#    un Node2D comme racine, nomme-la "Zone".
# 2. Attache-lui ce script.
# 3. Mets en place l'Autoload WorldManager (voir world_manager.gd).
# 4. Pour tester : Project > Project Settings > Application > Run >
#    Main Scene, mets cette scène "Zone" comme scène principale (tu
#    pourras remettre ta scène de combat en principale plus tard, une
#    fois les deux reliées).
# 5. (Optionnel, pour un vrai décor) Ajoute un node enfant TileMapLayer
#    (PAS TileMap, déprécié depuis Godot 4.3) nommé exactement
#    "TerrainTileMap", assigne-lui directement ta ressource TileSet
#    configurée en isométrique dans son champ "Tile Set" — voir
#    _generate_terrain().
# ============================================================

const EDGE_MARGIN := 24.0          # Distance du bord qui déclenche une sortie de zone.
const MOVE_SPEED := 220.0          # Pixels par seconde.

## Dimensions de la zone EN CASES du TileMap (pas en pixels) pour la
## génération procédurale du sol. Indépendant de zone_data.width/height
## (qui restent en pixels, pour les limites de déplacement de l'avatar).
## Assez grand pour que le losange isométrique généré dépasse largement
## les bords de la zone dans tous les sens (mieux vaut trop que pas
## assez : l'excédent est juste hors-champ, sans impact visuel ni
## perf notable).
const MAP_COLS := 40
const MAP_ROWS := 40

# Référence au node TileMapLayer enfant (voir instructions d'installation
# en haut du fichier). Reste null si absent — le fond coloré uni de
# _draw() sert alors de solution de repli, rien ne casse.
@onready var _terrain_tilemap: TileMapLayer = get_node_or_null("TerrainTileMap")

var zone_data: Dictionary
var avatar_pos: Vector2

# Déplacement au clic : destination visée (ignorée si aucun clic en
# attente). Le clavier (WASD/flèches), s'il est utilisé, reprend
# toujours la main et annule un déplacement au clic en cours.
var _click_target: Vector2 = Vector2.ZERO
var _has_click_target: bool = false

var _zone_label: Label
var _encounter_popup: PanelContainer
var _encounter_label: Label

func _ready() -> void:
	zone_data = WorldMap.get_zone(WorldManager.current_zone_name)
	avatar_pos = WorldManager.player_spawn_position
	_build_ui()
	_generate_terrain()
	queue_redraw()
	_check_zone_entry_encounter()

# Peuple TerrainTileMap avec un sol d'herbe généré aléatoirement parmi
# quelques variantes, à titre de premier jet. Les coordonnées d'atlas
# ci-dessous sont une ESTIMATION VISUELLE de ta feuille de tuiles
# (colonnes 0-2, ligne 2 = variantes d'herbe) — quasi certain qu'il
# faudra les ajuster une fois affiché en jeu (dis-moi ce que tu vois,
# je recalcule). Ne fait rien si TerrainTileMap n'existe pas (voir
# instructions d'installation en haut du fichier).
func _generate_terrain() -> void:
	if _terrain_tilemap == null:
		return

	var source_id = 0  # Suppose une seule Atlas Source dans le TileSet.
	var grass_variants = [Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2)]

	_terrain_tilemap.y_sort_enabled = true

	for x in range(36):
		for y in range(80):
			var tile_coord = grass_variants[randi() % grass_variants.size()]
			_terrain_tilemap.set_cell(Vector2i(x, y), source_id, tile_coord)

	#_center_terrain_on_zone()

# Centre le TileMapLayer sur le rectangle de la zone. Plutôt que de
# deviner la formule de conversion case -> pixel (qui dépend de la
# config exacte du TileSet — forme, axe de décalage...), on demande
# directement à Godot via map_to_local() la position réelle des 4
# coins de la grille générée, puis on centre cette boîte englobante
# sur le rectangle de la zone. Fiable quelle que soit la config.
func _center_terrain_on_zone() -> void:
	var corners = [
		_terrain_tilemap.map_to_local(Vector2i(0, 0)),
		_terrain_tilemap.map_to_local(Vector2i(MAP_COLS - 1, 0)),
		_terrain_tilemap.map_to_local(Vector2i(0, MAP_ROWS - 1)),
		_terrain_tilemap.map_to_local(Vector2i(MAP_COLS - 1, MAP_ROWS - 1)),
	]

	var min_x = corners[0].x
	var max_x = corners[0].x
	var min_y = corners[0].y
	var max_y = corners[0].y
	for c in corners:
		min_x = min(min_x, c.x)
		max_x = max(max_x, c.x)
		min_y = min(min_y, c.y)
		max_y = max(max_y, c.y)

	var zone_w = zone_data.get("width", 800)
	var zone_h = zone_data.get("height", 600)
	var diamond_w = max_x - min_x
	var diamond_h = max_y - min_y

	if diamond_w < zone_w or diamond_h < zone_h:
		push_warning("zone.gd: le sol généré (%.0fx%.0f) est plus petit que la zone (%.0fx%.0f) — augmente MAP_COLS/MAP_ROWS." % [diamond_w, diamond_h, zone_w, zone_h])

	_terrain_tilemap.position = Vector2(
		zone_w / 2.0 - (min_x + max_x) / 2.0,
		zone_h / 2.0 - (min_y + max_y) / 2.0
	)

func _build_ui() -> void:
	var canvas = CanvasLayer.new()
	add_child(canvas)

	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_TOP_LEFT)
	margin.position = Vector2(16, 16)
	canvas.add_child(margin)

	_zone_label = Label.new()
	_zone_label.text = "Zone : %s" % WorldManager.current_zone_name
	_zone_label.add_theme_font_size_override("font_size", 20)
	margin.add_child(_zone_label)

	# Popup provisoire affiché quand une rencontre se déclenche — à
	# remplacer par un vrai changement de scène vers le combat une fois
	# le nom/chemin de cette scène connu (voir _trigger_encounter).
	_encounter_popup = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.05, 0.05, 0.95)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(24)
	_encounter_popup.add_theme_stylebox_override("panel", style)
	_encounter_popup.set_anchors_preset(Control.PRESET_CENTER)
	_encounter_popup.visible = false
	canvas.add_child(_encounter_popup)

	_encounter_label = Label.new()
	_encounter_label.add_theme_font_size_override("font_size", 26)
	_encounter_popup.add_child(_encounter_label)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var target = get_local_mouse_position()
		target.x = clamp(target.x, 0, zone_data.get("width", 800))
		target.y = clamp(target.y, 0, zone_data.get("height", 600))
		_click_target = target
		_has_click_target = true

func _process(delta: float) -> void:
	if _encounter_popup.visible:
		return  # On ne bouge pas pendant l'affichage du popup de rencontre.

	var movement = Vector2.ZERO

	var input_dir = Vector2.ZERO
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		input_dir.x += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		input_dir.x -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		input_dir.y += 1
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		input_dir.y -= 1

	if input_dir.length_squared() > 0:
		# Le clavier prend toujours la main sur un déplacement au clic en cours.
		_has_click_target = false
		movement = input_dir.normalized() * MOVE_SPEED * delta
	elif _has_click_target:
		var to_target = _click_target - avatar_pos
		var step = MOVE_SPEED * delta
		if to_target.length() <= step:
			movement = to_target
			_has_click_target = false
		else:
			movement = to_target.normalized() * step

	if movement == Vector2.ZERO:
		return

	avatar_pos += movement
	_clamp_to_bounds()
	queue_redraw()

	if _check_edge_transition():
		return  # La scène va être rechargée, pas la peine de continuer.

func _clamp_to_bounds() -> void:
	avatar_pos.x = clamp(avatar_pos.x, 0, zone_data.get("width", 800))
	avatar_pos.y = clamp(avatar_pos.y, 0, zone_data.get("height", 600))

# Renvoie true si une transition de zone a été déclenchée (la scène va
# être rechargée juste après).
func _check_edge_transition() -> bool:
	var exits = zone_data.get("exits", {})
	var w = zone_data.get("width", 800)
	var h = zone_data.get("height", 600)

	if avatar_pos.x <= EDGE_MARGIN and exits.has("west"):
		_travel(exits["west"], "east")
		return true
	if avatar_pos.x >= w - EDGE_MARGIN and exits.has("east"):
		_travel(exits["east"], "west")
		return true
	if avatar_pos.y <= EDGE_MARGIN and exits.has("north"):
		_travel(exits["north"], "south")
		return true
	if avatar_pos.y >= h - EDGE_MARGIN and exits.has("south"):
		_travel(exits["south"], "north")
		return true

	return false

# Fait apparaître le joueur sur le bord OPPOSÉ à celui par lequel il
# vient d'arriver (ex: sorti par l'est -> apparaît collé au bord ouest
# de la nouvelle zone), à la même position sur l'axe perpendiculaire —
# donne l'impression de continuité entre les deux zones.
func _travel(target_zone: String, arrival_edge: String) -> void:
	var target_data = WorldMap.get_zone(target_zone)
	var tw = target_data.get("width", 800)
	var th = target_data.get("height", 600)

	var spawn := Vector2.ZERO
	match arrival_edge:
		"west":
			spawn = Vector2(EDGE_MARGIN + 4, avatar_pos.y)
		"east":
			spawn = Vector2(tw - EDGE_MARGIN - 4, avatar_pos.y)
		"north":
			spawn = Vector2(avatar_pos.x, EDGE_MARGIN + 4)
		"south":
			spawn = Vector2(avatar_pos.x, th - EDGE_MARGIN - 4)

	WorldManager.travel_to_zone(target_zone, spawn)
	get_tree().reload_current_scene()

# Jet de rencontre unique, effectué une seule fois à l'entrée dans la
# zone (voir _ready()). Rester ou se balader dans la zone n'augmente
# pas les chances : une seule occurrence possible par entrée de zone.
func _check_zone_entry_encounter() -> void:
	var chance = zone_data.get("encounter_chance", 0)
	if chance <= 0:
		return

	if randf() * 100.0 < chance:
		_trigger_encounter()

func _trigger_encounter() -> void:
	var table = zone_data.get("encounter_table", [])
	if table.is_empty():
		return

	var enemies = table[randi() % table.size()]

	# Préparé pour la scène de combat, pas encore lu par elle.
	WorldManager.pending_encounter_enemies = enemies
	WorldManager.return_zone_name = WorldManager.current_zone_name
	WorldManager.return_position = avatar_pos

	print("Rencontre déclenchée ! Ennemis : %s" % str(enemies))

	# TODO : remplacer ce popup par le vrai changement de scène une fois
	# le chemin de la scène de combat connu, par exemple :
	# get_tree().change_scene_to_file("res://scenes/combat.tscn")
	_encounter_label.text = "Combat !\n%s" % ", ".join(enemies)
	_encounter_popup.visible = true

	await get_tree().create_timer(1.5).timeout
	_encounter_popup.visible = false

func _draw() -> void:
	var w = zone_data.get("width", 800)
	var h = zone_data.get("height", 600)
	var bg_color = zone_data.get("background_color", Color(0.2, 0.2, 0.2))

	draw_rect(Rect2(0, 0, w, h), bg_color)
	draw_rect(Rect2(0, 0, w, h), Color.BLACK, false, 3.0)

	# Marqueurs de sortie : un hexagone, même couleur pour tous, positionné
	# au milieu de chaque bord qui a une sortie définie.
	var exits = zone_data.get("exits", {})
	var marker_color = Color(0.9, 0.8, 0.2)
	var marker_size = 18.0

	if exits.has("north"):
		_draw_hex_marker(Vector2(w / 2.0, 14), marker_size, marker_color)
	if exits.has("south"):
		_draw_hex_marker(Vector2(w / 2.0, h - 14), marker_size, marker_color)
	if exits.has("east"):
		_draw_hex_marker(Vector2(w - 14, h / 2.0), marker_size, marker_color)
	if exits.has("west"):
		_draw_hex_marker(Vector2(14, h / 2.0), marker_size, marker_color)

	# Avatar du joueur : simple disque pour l'instant (remplaçable par
	# un sprite animé plus tard, même principe que les unités de combat).
	draw_circle(avatar_pos, 14, Color(0.3, 0.6, 0.95))
	draw_arc(avatar_pos, 14, 0, TAU, 24, Color.BLACK, 2.0, true)

# Dessine un hexagone plein + contour, centré à `center`, de "rayon"
# `size` — utilisé pour les marqueurs de sortie de zone.
func _draw_hex_marker(center: Vector2, size: float, color: Color) -> void:
	var points = PackedVector2Array()
	for i in range(6):
		var angle_deg = 60.0 * i - 90.0
		var angle_rad = deg_to_rad(angle_deg)
		points.append(center + Vector2(cos(angle_rad), sin(angle_rad)) * size)

	draw_colored_polygon(points, color)

	var outline = points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, Color.BLACK, 2.0, true)
