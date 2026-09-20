extends Node2D

# ============================================================
# zone.gd
# Scène d'exploration : représente UNE zone bornée (façon Dofus), avec
# déplacement libre du joueur (WASD/flèches ou clic), changement de
# zone en touchant un bord, et un jet de rencontre unique à l'entrée
# dans chaque zone (rester/se balader n'augmente pas les chances).
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
# 6. Ajoute explorer_avatar.gd (class_name ExplorerAvatar) dans ton
#    dossier scripts/ — instancié en code, pas besoin de node manuel.
# ============================================================

const EDGE_MARGIN := 24.0          # Distance du bord qui déclenche une sortie de zone.
const MOVE_SPEED := 220.0          # Pixels par seconde.

## Dimensions de la grille générée EN CASES (pas en pixels). Rectangle
## volontairement plus large en hauteur qu'en largeur (36x80) : une
## grille isométrique forme un LOSANGE, pas un rectangle, donc une
## forme allongée couvre mieux un écran large et bas qu'une grille
## carrée. Ajuste ces deux chiffres si l'avertissement de couverture
## apparaît dans la console (voir _center_terrain_on_zone).
const MAP_COLS := 36
const MAP_ROWS := 80

## Classe utilisée pour l'apparence du personnage pendant l'exploration
## (voir UnitDatabase) — réutilise directement sa configuration de
## sprite/animations, pas besoin de la redéfinir.
const AVATAR_TEMPLATE := "Barbare"

## Distance en pixels à laquelle un PNJ devient interactible (E pour
## lui parler).
const INTERACT_RADIUS := 60.0

# Référence au node TileMapLayer enfant (voir instructions d'installation
# en haut du fichier). Reste null si absent — le fond coloré uni de
# _draw() sert alors de solution de repli, rien ne casse.
@onready var _terrain_tilemap: TileMapLayer = get_node_or_null("TerrainTileMap")

var zone_data: Dictionary
var avatar: ExplorerAvatar

# PNJ de la zone (voir _setup_npcs) et PNJ actuellement à portée
# d'interaction (null si aucun).
var _npcs: Array = []
var _nearby_npc: Npc = null

# État du dialogue en cours (voir _start_dialogue/_advance_dialogue).
var _in_dialogue: bool = false
var _dialogue_lines: Array = []
var _dialogue_index: int = 0
var _dialogue_speaker: String = ""

# Déplacement au clic : destination visée (ignorée si aucun clic en
# attente). Le clavier (WASD/flèches), s'il est utilisé, reprend
# toujours la main et annule un déplacement au clic en cours.
var _click_target: Vector2 = Vector2.ZERO
var _has_click_target: bool = false

# Vrai si l'avatar était en mouvement à la frame précédente — sert à ne
# déclencher l'animation "idle" qu'une fois, au moment où il s'arrête,
# plutôt qu'à chaque frame d'immobilité.
var _was_moving: bool = false

var _zone_label: Label
var _encounter_popup: PanelContainer
var _encounter_label: Label
var _dialogue_popup: PanelContainer
var _dialogue_name_label: Label
var _dialogue_text_label: Label
var _dialogue_hint_label: Label

# --- Barre de statut en bas de l'écran (façon Dofus) ---
var _hp_bar: ProgressBar
var _hp_label: Label
var _ea_bar: ProgressBar
var _ea_label: Label
var _inventory_button: Button
var _inventory_popup: PopupPanel
var _inventory_list_container: VBoxContainer

func _ready() -> void:
	WorldManager.ensure_party_initialized()
	zone_data = WorldMap.get_zone(WorldManager.current_zone_name)
	_setup_avatar()
	_setup_npcs()
	_build_ui()
	_generate_terrain()
	queue_redraw()
	_check_zone_entry_encounter()

# Instancie un node Npc par entrée définie dans zone_data["npcs"].
func _setup_npcs() -> void:
	_npcs.clear()

	for npc_data in zone_data.get("npcs", []):
		var npc := Npc.new()
		npc.npc_name = npc_data.get("name", "PNJ")
		npc.dialogue_lines = npc_data.get("dialogue", ["..."])
		npc.sprite_template = npc_data.get("sprite_template", "")
		npc.position = npc_data.get("position", Vector2.ZERO)
		add_child(npc)
		_npcs.append(npc)

# Crée le node ExplorerAvatar et le configure avec le sprite/les
# animations de AVATAR_TEMPLATE (voir UnitDatabase) — réutilise donc
# directement ce qui a déjà été mis en place pour le combat.
func _setup_avatar() -> void:
	avatar = ExplorerAvatar.new()
	avatar.position = WorldManager.player_spawn_position

	var stats = UnitDatabase.get_base_stats(AVATAR_TEMPLATE)
	var sprite_data = stats.get("sprite", null)
	if sprite_data != null:
		var sprite_path = sprite_data.get("path", "")
		if sprite_path != "" and ResourceLoader.exists(sprite_path):
			avatar.sprite_sheet = load(sprite_path)
			avatar.sprite_frame_size = Vector2i(
				sprite_data.get("frame_width", 32),
				sprite_data.get("frame_height", 32)
			)
			avatar.sprite_scale = sprite_data.get("scale", 2.0)
			avatar.sprite_y_offset = sprite_data.get("y_offset", 0.0)
			avatar.sprite_animations = UnitDatabase.build_sprite_animations(AVATAR_TEMPLATE)

	add_child(avatar)

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

	# Important : un node enfant se dessine normalement PAR-DESSUS le
	# contenu de _draw() de son parent (les marqueurs de sortie...). On
	# force le sol à rester en arrière-plan.
	_terrain_tilemap.z_index = -1
	_terrain_tilemap.y_sort_enabled = true

	var ground_tiles = _build_ground_layout()
	_apply_tile_layout(ground_tiles)
	_center_terrain_on_zone(ground_tiles.keys())
	_apply_obstacle_tiles()  # Après le centrage : a besoin de la position finale du TileMapLayer.

# Construit le dictionnaire "quelles tuiles où" : clé = coordonnée de
# case (Vector2i x, y dans la grille du TileMap), valeur = coordonnée
# de la tuile correspondante dans l'atlas (Vector2i colonne, ligne).
# Séparé de _apply_tile_layout() exprès : cette fonction pourra plus
# tard être remplacée par une disposition dessinée à la main (un
# dictionnaire écrit directement dans WorldMap, par exemple) sans
# toucher au code qui l'affiche.
func _build_ground_layout() -> Dictionary:
	var layout: Dictionary = {}
	var grass_variants = [Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2)]

	for x in range(MAP_COLS):
		for y in range(MAP_ROWS):
			layout[Vector2i(x, y)] = grass_variants[randi() % grass_variants.size()]

	return layout

# Applique un dictionnaire coordonnée -> tuile d'atlas (voir
# _build_ground_layout) au TileMapLayer.
func _apply_tile_layout(layout: Dictionary) -> void:
	var source_id = 0  # Suppose une seule Atlas Source dans le TileSet.
	for coord in layout.keys():
		_terrain_tilemap.set_cell(coord, source_id, layout[coord])

# Centre le TileMapLayer sur le rectangle de la zone. Plutôt que de
# deviner la formule de conversion case -> pixel (qui dépend de la
# config exacte du TileSet — forme, axe de décalage...), on demande
# directement à Godot via map_to_local() la position réelle des cases
# aux coins de la disposition fournie, puis on centre cette boîte
# englobante sur le rectangle de la zone. Fiable quelle que soit la
# config, et quelle que soit la forme du dictionnaire de cases (pas
# besoin qu'il soit un rectangle plein).
func _center_terrain_on_zone(coords: Array) -> void:
	if coords.is_empty():
		return

	var min_x = INF
	var max_x = -INF
	var min_y = INF
	var max_y = -INF

	for coord in coords:
		var p = _terrain_tilemap.map_to_local(coord)
		min_x = min(min_x, p.x)
		max_x = max(max_x, p.x)
		min_y = min(min_y, p.y)
		max_y = max(max_y, p.y)

	var zone_w = zone_data.get("width", 800)
	var zone_h = zone_data.get("height", 600)
	var layout_w = max_x - min_x
	var layout_h = max_y - min_y

	if layout_w < zone_w or layout_h < zone_h:
		push_warning("zone.gd: le sol généré (%.0fx%.0f) est plus petit que la zone (%.0fx%.0f) — augmente MAP_COLS/MAP_ROWS." % [layout_w, layout_h, zone_w, zone_h])

	_terrain_tilemap.position = Vector2(
		zone_w / 2.0 - (min_x + max_x) / 2.0,
		zone_h / 2.0 - (min_y + max_y) / 2.0
	)

# Peint de vraies tuiles de rocher (au lieu d'un simple rectangle
# placeholder) sur les cases du TileMapLayer couvertes par chaque
# obstacle défini pour la zone. Convertit le rectangle (en pixels,
# repère du déplacement du joueur) en cases via local_to_map — appelé
# APRÈS le centrage, car il faut connaître la position finale du
# TileMapLayer pour convertir correctement une position monde en case.
#
# Coordonnées d'atlas ESTIMÉES visuellement (rochers gris, ligne 6) —
# à ajuster si ça affiche autre chose une fois en jeu.
func _apply_obstacle_tiles() -> void:
	var rock_variants = [Vector2i(7, 5), Vector2i(8, 5), Vector2i(9, 5), Vector2i(10, 5)]
	var source_id = 0

	for rect in zone_data.get("obstacles", []):
		var corners = [
			rect.position,
			rect.position + Vector2(rect.size.x, 0),
			rect.position + Vector2(0, rect.size.y),
			rect.position + rect.size,
		]

		var min_cell = Vector2i(999999, 999999)
		var max_cell = Vector2i(-999999, -999999)

		for corner in corners:
			var local_pos = corner - _terrain_tilemap.position
			var cell = _terrain_tilemap.local_to_map(local_pos)
			min_cell.x = min(min_cell.x, cell.x)
			min_cell.y = min(min_cell.y, cell.y)
			max_cell.x = max(max_cell.x, cell.x)
			max_cell.y = max(max_cell.y, cell.y)

		for x in range(min_cell.x, max_cell.x + 1):
			for y in range(min_cell.y, max_cell.y + 1):
				var tile = rock_variants[randi() % rock_variants.size()]
				_terrain_tilemap.set_cell(Vector2i(x, y), source_id, tile)

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

	# Boîte de dialogue PNJ, centrée à l'écran.
	_dialogue_popup = PanelContainer.new()
	var dialogue_style = StyleBoxFlat.new()
	dialogue_style.bg_color = Color(0.08, 0.08, 0.1, 0.95)
	dialogue_style.set_corner_radius_all(10)
	dialogue_style.set_content_margin_all(20)
	_dialogue_popup.add_theme_stylebox_override("panel", dialogue_style)
	_dialogue_popup.set_anchors_preset(Control.PRESET_CENTER)
	_dialogue_popup.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_dialogue_popup.grow_vertical = Control.GROW_DIRECTION_BOTH
	_dialogue_popup.custom_minimum_size = Vector2(420, 0)
	_dialogue_popup.visible = false
	canvas.add_child(_dialogue_popup)

	var dialogue_vbox = VBoxContainer.new()
	dialogue_vbox.add_theme_constant_override("separation", 6)
	_dialogue_popup.add_child(dialogue_vbox)

	_dialogue_name_label = Label.new()
	_dialogue_name_label.add_theme_font_size_override("font_size", 18)
	_dialogue_name_label.modulate = Color(0.9, 0.8, 0.3)
	dialogue_vbox.add_child(_dialogue_name_label)

	_dialogue_text_label = Label.new()
	_dialogue_text_label.add_theme_font_size_override("font_size", 16)
	_dialogue_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	dialogue_vbox.add_child(_dialogue_text_label)

	_dialogue_hint_label = Label.new()
	_dialogue_hint_label.add_theme_font_size_override("font_size", 12)
	_dialogue_hint_label.modulate = Color(0.7, 0.7, 0.7)
	dialogue_vbox.add_child(_dialogue_hint_label)

	_build_status_bar(canvas)
	_build_inventory_popup(canvas)

# Barre de statut fixe en bas de l'écran (façon Dofus) : nom, PV, EA,
# bouton Inventaire. Reste affichée en permanence pendant l'exploration.
func _build_status_bar(canvas: CanvasLayer) -> void:
	var status_panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.1, 0.92)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(14)
	status_panel.add_theme_stylebox_override("panel", style)
	status_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	status_panel.position = Vector2(0, -16)
	status_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	status_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	canvas.add_child(status_panel)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 24)
	status_panel.add_child(hbox)

	var name_label = Label.new()
	name_label.text = WorldManager.party_name
	name_label.add_theme_font_size_override("font_size", 16)
	hbox.add_child(name_label)

	var hp_vbox = VBoxContainer.new()
	hp_vbox.custom_minimum_size = Vector2(160, 0)
	hbox.add_child(hp_vbox)

	_hp_bar = ProgressBar.new()
	_hp_bar.custom_minimum_size = Vector2(160, 16)
	_hp_bar.show_percentage = false
	hp_vbox.add_child(_hp_bar)

	_hp_label = Label.new()
	_hp_label.add_theme_font_size_override("font_size", 12)
	hp_vbox.add_child(_hp_label)

	var ea_vbox = VBoxContainer.new()
	ea_vbox.custom_minimum_size = Vector2(160, 0)
	hbox.add_child(ea_vbox)

	_ea_bar = ProgressBar.new()
	_ea_bar.custom_minimum_size = Vector2(160, 16)
	_ea_bar.show_percentage = false
	ea_vbox.add_child(_ea_bar)

	_ea_label = Label.new()
	_ea_label.add_theme_font_size_override("font_size", 12)
	ea_vbox.add_child(_ea_label)

	_inventory_button = Button.new()
	_inventory_button.text = "Inventaire"
	_inventory_button.custom_minimum_size = Vector2(110, 40)
	_inventory_button.pressed.connect(_on_inventory_button_pressed)
	hbox.add_child(_inventory_button)

	_refresh_status_bar()

func _refresh_status_bar() -> void:
	_hp_bar.max_value = WorldManager.party_max_hp
	_hp_bar.value = WorldManager.party_current_hp
	_hp_label.text = "PV : %d / %d" % [WorldManager.party_current_hp, WorldManager.party_max_hp]

	_ea_bar.max_value = WorldManager.party_max_ea
	_ea_bar.value = WorldManager.party_current_ea
	_ea_label.text = "EA : %d / %d" % [WorldManager.party_current_ea, WorldManager.party_max_ea]

func _build_inventory_popup(canvas: CanvasLayer) -> void:
	_inventory_popup = PopupPanel.new()
	_inventory_popup.min_size = Vector2(280, 0)
	canvas.add_child(_inventory_popup)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	_inventory_popup.add_child(margin)

	_inventory_list_container = VBoxContainer.new()
	_inventory_list_container.add_theme_constant_override("separation", 8)
	margin.add_child(_inventory_list_container)

func _on_inventory_button_pressed() -> void:
	for child in _inventory_list_container.get_children():
		child.queue_free()

	if WorldManager.party_potions.is_empty():
		var empty_label = Label.new()
		empty_label.text = "Inventaire vide."
		_inventory_list_container.add_child(empty_label)
	else:
		for potion in WorldManager.party_potions:
			var btn = Button.new()
			btn.text = potion.get_display_text()
			btn.pressed.connect(func(): _use_potion(potion))
			_inventory_list_container.add_child(btn)

	_inventory_popup.popup_centered()

# Boit une potion depuis la barre de statut : contrairement au combat,
# pas de notion d'action/tour ici — l'effet s'applique immédiatement.
func _use_potion(potion) -> void:
	if potion.potion_type == Potion.PotionType.HEAL:
		WorldManager.party_current_hp = min(WorldManager.party_current_hp + potion.amount, WorldManager.party_max_hp)
	else:
		WorldManager.party_current_ea = min(WorldManager.party_current_ea + potion.amount, WorldManager.party_max_ea)

	WorldManager.party_potions.erase(potion)
	_refresh_status_bar()
	_inventory_popup.hide()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		if _encounter_popup.visible:
			return
		if _in_dialogue:
			_advance_dialogue()
		elif _nearby_npc != null:
			_start_dialogue(_nearby_npc)
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _in_dialogue:
			return  # On ignore les clics de déplacement pendant un dialogue.
		var target = get_local_mouse_position()
		target.x = clamp(target.x, 0, zone_data.get("width", 800))
		target.y = clamp(target.y, 0, zone_data.get("height", 600))
		_click_target = target
		_has_click_target = true

func _process(delta: float) -> void:
	_update_nearby_npc()

	if _encounter_popup.visible or _in_dialogue:
		return  # On ne bouge pas pendant un popup de rencontre ou un dialogue.

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
		var to_target = _click_target - avatar.position
		var step = MOVE_SPEED * delta
		if to_target.length() <= step:
			movement = to_target
			_has_click_target = false
		else:
			movement = to_target.normalized() * step

	if movement == Vector2.ZERO:
		if _was_moving:
			avatar.play_animation("idle")
			_was_moving = false
		return

	avatar.face_direction(avatar.position + movement)
	avatar.play_animation("walk")
	_was_moving = true

	if not _try_move(movement):
		return  # Complètement bloqué (obstacle) : rien d'autre à faire.

	queue_redraw()

	if _check_edge_transition():
		return  # La scène va être rechargée, pas la peine de continuer.

# Tente de déplacer l'avatar de `movement`, en gérant la collision avec
# les obstacles de la zone : essaie le déplacement complet, puis à
# défaut seulement sur l'axe X, puis seulement sur l'axe Y (glissement
# le long d'un bord d'obstacle, plus agréable qu'un blocage net dès
# qu'on touche un coin). Renvoie true si l'avatar a effectivement bougé.
func _try_move(movement: Vector2) -> bool:
	var w = zone_data.get("width", 800)
	var h = zone_data.get("height", 600)

	var full_target = avatar.position + movement
	full_target.x = clamp(full_target.x, 0, w)
	full_target.y = clamp(full_target.y, 0, h)

	if not _is_blocked(full_target):
		avatar.position = full_target
		return true

	var slide_x = Vector2(clamp(avatar.position.x + movement.x, 0, w), avatar.position.y)
	if not _is_blocked(slide_x):
		avatar.position = slide_x
		return true

	var slide_y = Vector2(avatar.position.x, clamp(avatar.position.y + movement.y, 0, h))
	if not _is_blocked(slide_y):
		avatar.position = slide_y
		return true

	# Complètement bloqué : on annule aussi un déplacement au clic en
	# attente, sinon l'avatar resterait "collé" à essayer d'atteindre
	# une destination inaccessible indéfiniment.
	_has_click_target = false
	return false

# Vrai si la position donnée tombe dans un obstacle de la zone.
func _is_blocked(pos: Vector2) -> bool:
	for rect in zone_data.get("obstacles", []):
		if rect.has_point(pos):
			return true
	return false

# Renvoie true si une transition de zone a été déclenchée (la scène va
# être rechargée juste après).
func _check_edge_transition() -> bool:
	var exits = zone_data.get("exits", {})
	var w = zone_data.get("width", 800)
	var h = zone_data.get("height", 600)
	var pos = avatar.position

	if pos.x <= EDGE_MARGIN and exits.has("west"):
		_travel(exits["west"], "east")
		return true
	if pos.x >= w - EDGE_MARGIN and exits.has("east"):
		_travel(exits["east"], "west")
		return true
	if pos.y <= EDGE_MARGIN and exits.has("north"):
		_travel(exits["north"], "south")
		return true
	if pos.y >= h - EDGE_MARGIN and exits.has("south"):
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
	var pos = avatar.position

	var spawn := Vector2.ZERO
	match arrival_edge:
		"west":
			spawn = Vector2(EDGE_MARGIN + 4, pos.y)
		"east":
			spawn = Vector2(tw - EDGE_MARGIN - 4, pos.y)
		"north":
			spawn = Vector2(pos.x, EDGE_MARGIN + 4)
		"south":
			spawn = Vector2(pos.x, th - EDGE_MARGIN - 4)

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
	WorldManager.return_position = avatar.position

	print("Rencontre déclenchée ! Ennemis : %s" % str(enemies))

	# TODO : remplacer ce popup par le vrai changement de scène une fois
	# le chemin de la scène de combat connu, par exemple :
	# get_tree().change_scene_to_file("res://scenes/combat.tscn")
	_encounter_label.text = "Combat !\n%s" % ", ".join(enemies)
	_encounter_popup.visible = true

	await get_tree().create_timer(1.5).timeout
	_encounter_popup.visible = false

# Trouve le PNJ le plus proche à portée d'interaction (ou null), et
# stocke le résultat dans _nearby_npc pour l'invite affichée dans
# _draw() et la gestion de la touche E dans _unhandled_input.
func _update_nearby_npc() -> void:
	if _in_dialogue:
		return  # On garde le PNJ en cours de conversation tel quel.

	var closest: Npc = null
	var closest_dist := INTERACT_RADIUS

	for npc in _npcs:
		var dist = avatar.position.distance_to(npc.position)
		if dist <= closest_dist:
			closest = npc
			closest_dist = dist

	_nearby_npc = closest

func _start_dialogue(npc: Npc) -> void:
	_in_dialogue = true
	_dialogue_speaker = npc.npc_name
	_dialogue_lines = npc.dialogue_lines
	_dialogue_index = 0
	_dialogue_popup.visible = true
	_refresh_dialogue_display()

func _advance_dialogue() -> void:
	_dialogue_index += 1
	if _dialogue_index >= _dialogue_lines.size():
		_end_dialogue()
		return
	_refresh_dialogue_display()

func _end_dialogue() -> void:
	_in_dialogue = false
	_dialogue_popup.visible = false

func _refresh_dialogue_display() -> void:
	_dialogue_name_label.text = _dialogue_speaker
	_dialogue_text_label.text = _dialogue_lines[_dialogue_index]

	var is_last = _dialogue_index >= _dialogue_lines.size() - 1
	_dialogue_hint_label.text = "[E] Fermer" if is_last else "[E] Continuer"

func _draw() -> void:
	var w = zone_data.get("width", 800)
	var h = zone_data.get("height", 600)

	# Contour de la zone (repère visuel des limites) — plus de
	# remplissage de couleur uni, le TileMapLayer affiche le vrai décor
	# (sol ET obstacles, voir _apply_obstacle_tiles).
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

	# Invite d'interaction au-dessus du PNJ à portée (masquée pendant un
	# dialogue déjà en cours, pas la peine de la répéter).
	if _nearby_npc != null and not _in_dialogue:
		var font = ThemeDB.fallback_font
		var prompt_pos = _nearby_npc.position + Vector2(-50, -50)
		draw_string(font, prompt_pos, "[E] Parler", HORIZONTAL_ALIGNMENT_CENTER, 100, 14, Color(1, 1, 0.6))

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
