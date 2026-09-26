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
var _dialogue_npc: Npc = null  # Pour enchaîner sur la boutique si le PNJ en a une.

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
var _level_label: Label
var _xp_bar: ProgressBar
var _xp_label: Label
var _gold_label: Label
var _inventory_panel: PanelContainer
var _inventory_tab_button: Button
var _skills_tab_button: Button
var _panel_content_container: VBoxContainer
var _active_panel_tab: String = "inventory"

# --- Panneau boutique (marchand) ---
var _shop_panel: PanelContainer
var _shop_gold_label: Label
var _shop_items_container: VBoxContainer
var _shop_npc: Npc = null
var _shop_tab_buttons: Dictionary = {}
var _shop_active_kind: String = "weapon"

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
		npc.dialogue_lines = npc_data.get("dialogue", [])
		npc.sprite_template = npc_data.get("sprite_template", "")
		npc.position = npc_data.get("position", Vector2.ZERO)
		add_child(npc)
		_npcs.append(npc)

		if npc_data.get("is_merchant", false):
			_roll_merchant_stock(npc)

# Tire le stock réel d'un marchand parmi les 5 catalogues (armes,
# armures, accessoires, potions, flèches), selon le type de ville de
# la zone actuelle (voir ShopGenerator.roll_stock — le handicap réduit
# la chance de présence de chaque objet). Tiré une seule fois, au
# chargement de la zone : rester/repartir ne retire pas le stock, il
# faut recharger la zone pour un nouveau tirage.
func _roll_merchant_stock(npc: Npc) -> void:
	var settlement_type = zone_data.get("settlement_type", "bourgade")
	var stock: Array = []

	for raw in ShopGenerator.roll_stock(WeaponCatalog.get_all(), settlement_type):
		stock.append({"kind": "weapon", "resource": ShopGenerator.build_weapon_from_data(raw)})

	for raw in ShopGenerator.roll_stock(ArmorCatalog.get_all(), settlement_type):
		stock.append({"kind": "armor", "resource": ShopGenerator.build_armor_from_data(raw)})

	for raw in ShopGenerator.roll_stock(AccessoryCatalog.get_all(), settlement_type):
		stock.append({"kind": "accessory", "resource": ShopGenerator.build_accessory_from_data(raw)})

	for raw in ShopGenerator.roll_stock(PotionCatalog.get_all(), settlement_type):
		var potion = ShopGenerator.build_potion_from_data(raw)
		if potion != null:  # null = potion à buff temporaire, pas encore supportée.
			stock.append({"kind": "potion", "resource": potion})

	for raw in ShopGenerator.roll_stock(ArrowCatalog.get_all(), settlement_type):
		stock.append({"kind": "arrow", "resource": ShopGenerator.build_arrow_from_data(raw)})

	npc.shop_stock = stock

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
	# PRESET_CENTER seul n'aligne que le coin haut-gauche du panneau sur
	# le centre de l'écran (il continue de s'étendre vers la droite/le
	# bas depuis ce point) — un vrai centrage passe par un CenterContainer
	# qui enveloppe le panneau (même technique pour les 3 popups ci-dessous).
	var encounter_center = CenterContainer.new()
	encounter_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	encounter_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(encounter_center)

	_encounter_popup = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.05, 0.05, 0.95)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(24)
	_encounter_popup.add_theme_stylebox_override("panel", style)
	_encounter_popup.visible = false
	encounter_center.add_child(_encounter_popup)

	_encounter_label = Label.new()
	_encounter_label.add_theme_font_size_override("font_size", 26)
	_encounter_popup.add_child(_encounter_label)

	# Boîte de dialogue PNJ, centrée à l'écran.
	var dialogue_center = CenterContainer.new()
	dialogue_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dialogue_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(dialogue_center)

	_dialogue_popup = PanelContainer.new()
	var dialogue_style = StyleBoxFlat.new()
	dialogue_style.bg_color = Color(0.08, 0.08, 0.1, 0.95)
	dialogue_style.set_corner_radius_all(10)
	dialogue_style.set_content_margin_all(20)
	_dialogue_popup.add_theme_stylebox_override("panel", dialogue_style)
	_dialogue_popup.custom_minimum_size = Vector2(420, 0)
	_dialogue_popup.visible = false
	dialogue_center.add_child(_dialogue_popup)


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
	_build_inventory_panel(canvas)
	_build_shop_panel(canvas)

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

	var xp_vbox = VBoxContainer.new()
	xp_vbox.custom_minimum_size = Vector2(140, 0)
	hbox.add_child(xp_vbox)

	_level_label = Label.new()
	_level_label.add_theme_font_size_override("font_size", 13)
	xp_vbox.add_child(_level_label)

	_xp_bar = ProgressBar.new()
	_xp_bar.custom_minimum_size = Vector2(140, 10)
	_xp_bar.show_percentage = false
	_xp_bar.modulate = Color(0.6, 0.85, 1.0)  # Teinte bleutée pour la distinguer des PV/EA.
	xp_vbox.add_child(_xp_bar)

	_xp_label = Label.new()
	_xp_label.add_theme_font_size_override("font_size", 10)
	xp_vbox.add_child(_xp_label)

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

	_gold_label = Label.new()
	_gold_label.add_theme_font_size_override("font_size", 14)
	_gold_label.modulate = Color(0.95, 0.8, 0.3)
	hbox.add_child(_gold_label)

	_refresh_status_bar()

func _refresh_status_bar() -> void:
	_level_label.text = "Niveau %d" % WorldManager.party_level
	_xp_bar.max_value = WorldManager.party_xp_to_next_level
	_xp_bar.value = WorldManager.party_current_xp
	_xp_label.text = "%d / %d XP" % [WorldManager.party_current_xp, WorldManager.party_xp_to_next_level]

	_hp_bar.max_value = WorldManager.party_max_hp
	_hp_bar.value = WorldManager.party_current_hp
	_hp_label.text = "PV : %d / %d" % [WorldManager.party_current_hp, WorldManager.party_max_hp]

	_ea_bar.max_value = WorldManager.party_max_ea
	_ea_bar.value = WorldManager.party_current_ea
	_ea_label.text = "EA : %d / %d" % [WorldManager.party_current_ea, WorldManager.party_max_ea]

	_gold_label.text = "%d Or" % WorldManager.party_gold

func _build_inventory_panel(canvas: CanvasLayer) -> void:
	_inventory_panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.1, 0.92)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(14)
	_inventory_panel.add_theme_stylebox_override("panel", style)

	# Panneau toujours visible (pas de bouton pour l'ouvrir/fermer).
	_inventory_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_inventory_panel.position = Vector2(-16, -16)
	_inventory_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_inventory_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_inventory_panel.custom_minimum_size = Vector2(220, 0)
	canvas.add_child(_inventory_panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	_inventory_panel.add_child(vbox)

	# Deux onglets (icônes) : cliquer dessus ne rouvre PAS un nouveau
	# panneau, ça change juste le contenu affiché dans _panel_content_container.
	var tabs_row = HBoxContainer.new()
	tabs_row.add_theme_constant_override("separation", 6)
	vbox.add_child(tabs_row)

	var tab_group = ButtonGroup.new()

	_inventory_tab_button = Button.new()
	_inventory_tab_button.text = "☰"
	_inventory_tab_button.tooltip_text = "Inventaire"
	_inventory_tab_button.toggle_mode = true
	_inventory_tab_button.button_group = tab_group
	_inventory_tab_button.button_pressed = true  # Actif par défaut.
	_inventory_tab_button.custom_minimum_size = Vector2(44, 36)
	_inventory_tab_button.pressed.connect(func(): _switch_panel_tab("inventory"))
	tabs_row.add_child(_inventory_tab_button)

	_skills_tab_button = Button.new()
	_skills_tab_button.text = "★"
	_skills_tab_button.tooltip_text = "Compétences / Sorts"
	_skills_tab_button.toggle_mode = true
	_skills_tab_button.button_group = tab_group
	_skills_tab_button.custom_minimum_size = Vector2(44, 36)
	_skills_tab_button.pressed.connect(func(): _switch_panel_tab("skills"))
	tabs_row.add_child(_skills_tab_button)

	_panel_content_container = VBoxContainer.new()
	_panel_content_container.add_theme_constant_override("separation", 4)
	vbox.add_child(_panel_content_container)

	_active_panel_tab = "inventory"
	_refresh_panel_content()

# Change l'onglet actif SANS ouvrir de nouveau panneau : rafraîchit
# juste le contenu de celui déjà affiché.
func _switch_panel_tab(tab_name: String) -> void:
	_active_panel_tab = tab_name
	_refresh_panel_content()

func _refresh_panel_content() -> void:
	for child in _panel_content_container.get_children():
		child.queue_free()

	if _active_panel_tab == "inventory":
		_populate_inventory_tab()
	else:
		_populate_skills_tab()

func _populate_inventory_tab() -> void:
	var has_any = (
		not WorldManager.party_potions.is_empty()
		or not WorldManager.party_weapons.is_empty()
		or not WorldManager.party_armors.is_empty()
		or not WorldManager.party_accessories.is_empty()
	)

	if not has_any:
		var empty_label = Label.new()
		empty_label.text = "Inventaire vide."
		_panel_content_container.add_child(empty_label)
		return

	if not WorldManager.party_potions.is_empty():
		var hint = Label.new()
		hint.text = "Potions (double-clic pour utiliser) :"
		hint.add_theme_font_size_override("font_size", 12)
		hint.modulate = Color(0.75, 0.75, 0.75)
		_panel_content_container.add_child(hint)

		var potions_row = HBoxContainer.new()
		potions_row.add_theme_constant_override("separation", 4)
		_panel_content_container.add_child(potions_row)

		for potion in WorldManager.party_potions:
			var slot = Button.new()
			slot.text = potion.get_icon_text()
			slot.tooltip_text = potion.get_display_text()
			slot.custom_minimum_size = Vector2(44, 44)
			slot.add_theme_font_size_override("font_size", 20)
			# Pas de "pressed" connecté : un simple clic ne fait rien, seul
			# le double-clic (détecté via gui_input) consomme l'objet.
			slot.gui_input.connect(func(event): _on_item_slot_input(event, potion))
			potions_row.add_child(slot)

	if not WorldManager.party_weapons.is_empty():
		_add_equip_section_label("Armes (clic pour équiper) :")
		for weapon in WorldManager.party_weapons:
			var is_equipped = weapon == WorldManager.party_equipped_weapon
			_panel_content_container.add_child(_build_equip_row(
				weapon.get_display_text(), is_equipped,
				func(): _equip_from_inventory("weapon", weapon)
			))

	if not WorldManager.party_armors.is_empty():
		_add_equip_section_label("Armures (clic pour équiper) :")
		for armor in WorldManager.party_armors:
			var is_equipped = armor == WorldManager.party_equipped_armor
			_panel_content_container.add_child(_build_equip_row(
				armor.get_display_text(), is_equipped,
				func(): _equip_from_inventory("armor", armor)
			))

	if not WorldManager.party_accessories.is_empty():
		_add_equip_section_label("Accessoires (clic pour équiper/retirer) :")
		for accessory in WorldManager.party_accessories:
			var is_equipped = WorldManager.party_equipped_accessories.has(accessory)
			_panel_content_container.add_child(_build_equip_row(
				accessory.get_display_text(), is_equipped,
				func(): _equip_from_inventory("accessory", accessory)
			))

func _add_equip_section_label(text: String) -> void:
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 12)
	label.modulate = Color(0.75, 0.75, 0.75)
	_panel_content_container.add_child(label)

# Construit une ligne "nom de l'objet | bouton Équiper/Équipé". Les
# accessoires utilisent le même bouton comme bascule équiper/retirer
# (voir _equip_from_inventory) puisque plusieurs peuvent être portés
# à la fois, contrairement à l'arme/l'armure.
func _build_equip_row(text: String, is_equipped: bool, callback: Callable) -> Control:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var label = Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(150, 0)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	row.add_child(label)

	var button = Button.new()
	button.text = "Équipé" if is_equipped else "Équiper"
	button.custom_minimum_size = Vector2(70, 0)
	button.pressed.connect(callback)
	row.add_child(button)

	return row

# Équipe (ou, pour un accessoire déjà porté, retire) l'objet indiqué,
# puis recalcule les bonus PV/EA reflétés dans la barre de statut (voir
# WorldManager.recalculate_party_bonuses — les autres stats, Attaque/
# Parade/Armure/etc., sont gérées côté combat via CombatUnit, pas
# encore affichées en exploration).
func _equip_from_inventory(kind: String, item) -> void:
	match kind:
		"weapon":
			WorldManager.party_equipped_weapon = item
		"armor":
			WorldManager.party_equipped_armor = item
		"accessory":
			if WorldManager.party_equipped_accessories.has(item):
				WorldManager.party_equipped_accessories.erase(item)
			else:
				WorldManager.party_equipped_accessories.append(item)

	WorldManager.recalculate_party_bonuses()
	_refresh_status_bar()
	_refresh_panel_content()

# Affiche les sorts/attaques du personnage — pour l'instant en simple
# consultation (grisés), hors combat il n'y a pas encore d'action à
# leur associer. Réutilise directement UnitDatabase, comme pour le
# reste (sprite de l'avatar, potions de départ...).
func _populate_skills_tab() -> void:
	var spells = UnitDatabase.build_spells(WorldManager.party_name)
	var weapon = UnitDatabase.build_weapon(WorldManager.party_name, "weapon")

	if weapon != null:
		spells.push_front(weapon.create_attack_spell())

	if spells.is_empty():
		var empty_label = Label.new()
		empty_label.text = "Aucune compétence."
		_panel_content_container.add_child(empty_label)
		return

	for spell in spells:
		var slot = Button.new()
		slot.text = spell.get_icon_text()
		slot.tooltip_text = spell.get_display_text()
		slot.custom_minimum_size = Vector2(0, 36)
		slot.disabled = true  # Consultation seulement pour l'instant, hors combat.
		_panel_content_container.add_child(slot)

func _on_item_slot_input(event: InputEvent, potion) -> void:
	if event is InputEventMouseButton and event.pressed and event.double_click and event.button_index == MOUSE_BUTTON_LEFT:
		_use_potion(potion)

# Boit une potion depuis l'inventaire (double-clic) : contrairement au
# combat, pas de notion d'action/tour ici — l'effet s'applique
# immédiatement. Le panneau reste ouvert (pas de fermeture automatique)
# pour pouvoir enchaîner plusieurs objets facilement.
func _use_potion(potion) -> void:
	if potion.potion_type == Potion.PotionType.HEAL:
		WorldManager.party_current_hp = min(WorldManager.party_current_hp + potion.amount, WorldManager.party_max_hp)
	else:
		WorldManager.party_current_ea = min(WorldManager.party_current_ea + potion.amount, WorldManager.party_max_ea)

	WorldManager.party_potions.erase(potion)
	_refresh_status_bar()
	_refresh_panel_content()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		if _encounter_popup.visible:
			return
		if _in_dialogue:
			_advance_dialogue()
		elif _shop_panel.visible:
			_close_shop()
		elif _nearby_npc != null:
			if not _nearby_npc.dialogue_lines.is_empty():
				_start_dialogue(_nearby_npc)
			elif not _nearby_npc.shop_stock.is_empty():
				_open_shop(_nearby_npc)
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

	if _encounter_popup.visible or _in_dialogue or _shop_panel.visible:
		return  # On ne bouge pas pendant un popup/dialogue/boutique.

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
	_dialogue_npc = npc
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

	# Enchaîne sur la boutique si ce PNJ en a une (ex: la marchande dit
	# bonjour, puis sa boutique s'ouvre automatiquement).
	if _dialogue_npc != null and not _dialogue_npc.shop_stock.is_empty():
		_open_shop(_dialogue_npc)

	_dialogue_npc = null

func _refresh_dialogue_display() -> void:
	_dialogue_name_label.text = _dialogue_speaker
	_dialogue_text_label.text = _dialogue_lines[_dialogue_index]

	var is_last = _dialogue_index >= _dialogue_lines.size() - 1
	_dialogue_hint_label.text = "[E] Fermer" if is_last else "[E] Continuer"

# ---------- Boutique (marchand) ----------

# Ordre des onglets et leur icône/libellé. Mêmes symboles que ceux
# déjà utilisés ailleurs dans le jeu (⚔ attaque, ♥ soin, ➤ tir à
# distance) pour rester cohérent visuellement.
const SHOP_KIND_ORDER := ["weapon", "armor", "accessory", "potion", "arrow"]
const SHOP_KIND_INFO := {
	"weapon":    {"icon": "⚔", "label": "Armes"},
	"armor":     {"icon": "⛨", "label": "Armures"},
	"accessory": {"icon": "○", "label": "Accessoires"},
	"potion":    {"icon": "♥", "label": "Potions"},
	"arrow":     {"icon": "➤", "label": "Flèches"},
}

func _build_shop_panel(canvas: CanvasLayer) -> void:
	# PRESET_CENTER seul n'aligne que le coin haut-gauche du panneau sur
	# le centre de l'écran (il continue de s'étendre vers la droite/le
	# bas depuis ce point) — un vrai centrage passe par un CenterContainer
	# qui enveloppe le panneau.
	var center_container = CenterContainer.new()
	center_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	center_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(center_container)

	_shop_panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.08, 0.05, 0.96)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(18)
	_shop_panel.add_theme_stylebox_override("panel", style)
	_shop_panel.custom_minimum_size = Vector2(480, 0)
	_shop_panel.visible = false
	center_container.add_child(_shop_panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	_shop_panel.add_child(vbox)

	# En-tête : titre à gauche, or à droite, sur la même ligne (plus
	# compact que l'un sous l'autre).
	var header_row = HBoxContainer.new()
	vbox.add_child(header_row)

	var title = Label.new()
	title.text = "Boutique"
	title.add_theme_font_size_override("font_size", 18)
	header_row.add_child(title)

	var header_spacer = Control.new()
	header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(header_spacer)

	_shop_gold_label = Label.new()
	_shop_gold_label.add_theme_font_size_override("font_size", 15)
	_shop_gold_label.modulate = Color(0.95, 0.8, 0.3)
	header_row.add_child(_shop_gold_label)

	# Onglets de catégorie (façon Hôtel de Ventes) : une icône par
	# rayon, cliquer filtre la liste sans ouvrir de nouveau panneau.
	var tabs_row = HBoxContainer.new()
	tabs_row.add_theme_constant_override("separation", 6)
	vbox.add_child(tabs_row)

	var tab_group = ButtonGroup.new()
	for kind in SHOP_KIND_ORDER:
		var info = SHOP_KIND_INFO[kind]
		var tab_button = Button.new()
		tab_button.text = info["icon"]
		tab_button.tooltip_text = info["label"]
		tab_button.toggle_mode = true
		tab_button.button_group = tab_group
		tab_button.custom_minimum_size = Vector2(44, 40)
		tab_button.add_theme_font_size_override("font_size", 18)
		tab_button.button_pressed = (kind == _shop_active_kind)
		tab_button.pressed.connect(func(): _switch_shop_tab(kind))
		tabs_row.add_child(tab_button)
		_shop_tab_buttons[kind] = tab_button

	# Liste de la catégorie active — hauteur fixe avec défilement, une
	# seule catégorie affichée à la fois donc rarement besoin de scroller.
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 320)
	vbox.add_child(scroll)

	_shop_items_container = VBoxContainer.new()
	_shop_items_container.add_theme_constant_override("separation", 2)
	_shop_items_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_shop_items_container)

	var close_button = Button.new()
	close_button.text = "Fermer [E]"
	close_button.custom_minimum_size = Vector2(0, 36)
	close_button.pressed.connect(_close_shop)
	vbox.add_child(close_button)

func _open_shop(npc: Npc) -> void:
	_shop_npc = npc
	_shop_active_kind = "weapon"
	if _shop_tab_buttons.has("weapon"):
		_shop_tab_buttons["weapon"].button_pressed = true
	_shop_panel.visible = true
	_refresh_shop_panel()

func _close_shop() -> void:
	_shop_panel.visible = false
	_shop_npc = null

# Change l'onglet actif SANS ouvrir de nouveau panneau : rafraîchit
# juste la liste affichée, comme pour l'inventaire.
func _switch_shop_tab(kind: String) -> void:
	_shop_active_kind = kind
	_refresh_shop_panel()

func _refresh_shop_panel() -> void:
	for child in _shop_items_container.get_children():
		child.queue_free()

	_shop_gold_label.text = "%d Or" % WorldManager.party_gold

	if _shop_npc == null:
		return

	var entries = _shop_npc.shop_stock.filter(func(e): return e["kind"] == _shop_active_kind)

	if entries.is_empty():
		var empty_label = Label.new()
		empty_label.text = "Rien en stock dans cette catégorie aujourd'hui."
		empty_label.modulate = Color(0.7, 0.7, 0.7)
		_shop_items_container.add_child(empty_label)
		return

	for i in range(entries.size()):
		var entry = entries[i]
		var resource = entry["resource"]

		# Bande alternée (une ligne sur deux légèrement plus claire) pour
		# faciliter la lecture d'une longue liste, façon Hôtel de Ventes.
		var row_panel = PanelContainer.new()
		if i % 2 == 0:
			var row_style = StyleBoxFlat.new()
			row_style.bg_color = Color(1, 1, 1, 0.04)
			row_style.set_content_margin_all(6)
			row_panel.add_theme_stylebox_override("panel", row_style)
		else:
			var empty_style = StyleBoxFlat.new()
			empty_style.bg_color = Color(0, 0, 0, 0)
			empty_style.set_content_margin_all(6)
			row_panel.add_theme_stylebox_override("panel", empty_style)
		_shop_items_container.add_child(row_panel)

		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row_panel.add_child(row)

		var label = Label.new()
		label.text = resource.get_display_text()
		label.custom_minimum_size = Vector2(330, 0)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD
		row.add_child(label)

		var price_spacer = Control.new()
		price_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(price_spacer)

		var price = resource.price
		var buy_button = Button.new()
		buy_button.text = "%d Or" % price
		buy_button.custom_minimum_size = Vector2(80, 32)
		buy_button.disabled = WorldManager.party_gold < price
		buy_button.pressed.connect(func(): _buy_shop_entry(entry))
		row.add_child(buy_button)

func _buy_shop_entry(entry: Dictionary) -> void:
	var resource = entry["resource"]
	var price = resource.price
	if not WorldManager.spend_gold(price):
		return  # Pas assez d'or (ne devrait pas arriver, le bouton est grisé, sécurité en plus).

	match entry["kind"]:
		"weapon":
			WorldManager.party_weapons.append(resource)
		"armor":
			WorldManager.party_armors.append(resource)
		"accessory":
			WorldManager.party_accessories.append(resource)
		"potion":
			WorldManager.party_potions.append(resource)
		"arrow":
			WorldManager.party_arrows.append(resource)

	_refresh_status_bar()
	_refresh_shop_panel()
	_refresh_panel_content()  # Pour que l'onglet Inventaire se mette à jour s'il est affiché.

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
