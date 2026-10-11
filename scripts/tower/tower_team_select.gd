extends Control

# ============================================================
# tower_team_select.gd — Écran de création d'équipe pour la Tour de
# l'infini, sous forme de CARTES. À attacher à un node Control dans une
# scène dédiée — construit toute son interface par code à _ready().
#
# Une carte vide « + » en fin de rangée : un clic crée un personnage
# (1 point) et la carte se transforme en carte de personnage, de haut
# en bas :
#   - nom, bouton de retrait
#   - race : flèches ◀ ▶ autour de l'illustration (le NOM s'affiche tant
#     qu'il n'y a pas d'image, voir RACE_IMAGE_DIR)
#   - niveau, avec - / + (les niveaux 2, 5 et 8 donnent 1 point de
#     caractéristique et relèvent la limite des stats, 13 au niveau 1)
#   - caractéristiques (départ à 8, chance à 1, 19 points à répartir par
#     personnage, avec - / + ; minimums/maximums de race affichés)
#   - métier de base, puis métiers de niveau 4 / 7 / 10 (listes
#     déroulantes : seuls les métiers non interdits à la race sont
#     listés, et ceux dont les caractéristiques ne suffisent pas sont
#     grisés avec ce qui leur manque)
#   - équipement : arme, 5 emplacements d'armure (casque, plastron,
#     brassières, jambières, bottes), bouclier à part, accessoires. Ouvre la
#     boutique à filtres plus bas, qui n'offre que ce que la race et le
#     métier du personnage permettent.
# Sous les cartes : bouton « Valider », qui lance l'ascension (étage 1 dans
# la scène de combat, voir TowerManager.start_run).
#
# Dépend de TowerManager (autoload, voir tower_manager.gd) pour TOUTE la
# logique — cet écran ne fait que de l'affichage et du câblage.
# ============================================================

const CARD_WIDTH: int = 400

## Hauteur FIXE d'une carte de personnage : elle ne change plus selon le
## contenu (métiers choisis, 2e arme...). Si le contenu dépasse, la carte
## défile à l'intérieur (voir _build_character_card).
const CARD_HEIGHT: int = 700

## Illustrations de race : <slug>.png dans ce dossier, slug = nom de la
## race en minuscules, sans accents, espaces remplacés par "_" (ex:
## haut_elfe.png, homme_des_sables.png). Image absente = le nom de la
## race s'affiche à la place.
const RACE_IMAGE_DIR: String = "res://assets/races/"

var _header_label: Label
var _cards_scroll: ScrollContainer
var _cards_row: HBoxContainer
var _validate_button: Button
var _warning_label: Label

## Message à afficher UNE fois dans la zone d'avertissement au prochain
## rafraîchissement (ex: pourquoi un changement de métier a été refusé).
var _notice: String = ""

var _equip_popup: PopupPanel
var _equip_popup_index: int = -1
var _equip_popup_content: VBoxContainer
var _equip_popup_gold_label: Label

func _ready() -> void:
	# Garde-fou : si l'Autoload "TowerManager" pointe par erreur vers un
	# AUTRE script au lieu de tower_manager.gd, tout le reste planterait
	# avec des erreurs obscures — on le dit clairement.
	if not TowerManager.has_method("add_character"):
		push_error("Autoload 'TowerManager' mal configuré : son chemin doit être res://scripts/tower_manager.gd (PAS tower_team_select.gd). Voir Projet > Paramètres du projet > Autoload.")
		return
	TowerManager.reset()
	# Un texte de restriction sans règle dans equipment_rules.gd ne serait
	# JAMAIS appliqué : on le dit dès l'ouverture plutôt que de le taire.
	var unmapped: Array = TowerManager.get_unmapped_equipment_restrictions()
	if not unmapped.is_empty():
		push_warning("Restrictions d'équipement sans règle dans equipment_rules.gd (donc non appliquées) : %s" % ", ".join(unmapped))
	_build_ui()
	_fit_to_viewport()
	get_viewport().size_changed.connect(_fit_to_viewport)
	_refresh()

# Impose la taille de l'écran = celle de la fenêtre, À LA MAIN, plutôt
# que de compter sur les ancres : un Control placé sous un Node2D (ex:
# la scène de la grille hexagonale) n'a PAS de rectangle parent, donc
# ses ancres donnent une taille nulle.
func _fit_to_viewport() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2.ZERO
	size = get_viewport_rect().size

# ---------- Construction de l'interface ----------

func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	var title := Label.new()
	title.text = "Tour de l'infini — Création de l'équipe"
	title.add_theme_font_size_override("font_size", 24)
	root.add_child(title)

	_header_label = Label.new()
	_header_label.add_theme_font_size_override("font_size", 16)
	root.add_child(_header_label)

	# Rangée de cartes : défile horizontalement (jusqu'à 16 personnages)
	# ET verticalement (une carte est plus haute qu'un écran de 648 px).
	_cards_scroll = ScrollContainer.new()
	_cards_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_cards_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cards_scroll.custom_minimum_size = Vector2(0, 320)  # Filet de sécurité : ne peut pas s'écraser à 0.
	root.add_child(_cards_scroll)

	_cards_row = HBoxContainer.new()
	_cards_row.add_theme_constant_override("separation", 12)
	_cards_row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN  # Cartes de taille fixe (voir CARD_HEIGHT).
	_cards_scroll.add_child(_cards_row)

	var bottom := VBoxContainer.new()
	bottom.add_theme_constant_override("separation", 4)
	root.add_child(bottom)

	_warning_label = Label.new()
	_warning_label.add_theme_font_size_override("font_size", 12)
	_warning_label.modulate = Color(0.9, 0.6, 0.3)
	_warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom.add_child(_warning_label)

	_validate_button = Button.new()
	_validate_button.text = "Valider"
	_validate_button.tooltip_text = "Lance l'ascension avec cette équipe"
	_validate_button.custom_minimum_size = Vector2(220, 40)
	_validate_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_validate_button.pressed.connect(_on_validate_pressed)
	bottom.add_child(_validate_button)

	_build_equip_popup()

# ---------- Rafraîchissement ----------

# Reconstruit toutes les cartes. Le défilement est conservé : sans ça,
# chaque clic sur un +/- renverrait la vue au début de la rangée.
func _refresh() -> void:
	if _cards_row == null:
		return
	var keep_h: int = _cards_scroll.scroll_horizontal
	var keep_v: int = _cards_scroll.scroll_vertical

	_header_label.text = "Points restants : %d / %d    —    Or : %d PO" % [
		TowerManager.points_remaining, TowerManager.TOTAL_POINTS, TowerManager.gold
	]
	if TowerManager.last_run_floors_cleared >= 0:
		_header_label.text += "    —    Dernière ascension : %d étage(s) franchi(s)" % TowerManager.last_run_floors_cleared

	for child in _cards_row.get_children():
		_cards_row.remove_child(child)  # Retiré TOUT DE SUITE (pas seulement libéré en fin d'image) : la taille du contenu ne double pas.
		child.queue_free()
	for i in range(TowerManager.team.size()):
		_cards_row.add_child(_build_character_card(i))
	_cards_row.add_child(_build_add_card())

	# Ce que les restrictions de race/métier ont retiré à un personnage
	# (objet interdit rendu à la boutique, remboursé) : on l'affiche.
	var equipment_notice: String = TowerManager.take_equipment_notice()
	if equipment_notice != "":
		_notice = equipment_notice if _notice == "" else _notice + " " + equipment_notice

	_update_validate_state()

	if is_inside_tree():
		await get_tree().process_frame  # Le contenu doit être remesuré avant de restaurer le défilement.
		_cards_scroll.scroll_horizontal = keep_h
		_cards_scroll.scroll_vertical = keep_v

func _update_validate_state() -> void:
	var ready_to_start: bool = TowerManager.is_team_ready()
	_validate_button.disabled = not ready_to_start
	_warning_label.text = ""
	if _notice != "":
		_warning_label.text = _notice
		_notice = ""
		return
	if ready_to_start:
		return
	if TowerManager.team.is_empty():
		_warning_label.text = "Ajoute au moins un personnage avec la carte « + »."
	elif TowerManager.points_remaining > 0:
		_warning_label.text = "Il reste %d point(s) à dépenser en niveaux." % TowerManager.points_remaining
	else:
		for i in range(TowerManager.team.size()):
			var reason: String = TowerManager.get_incomplete_reason(i)
			if reason != "":
				_warning_label.text = "%s : %s." % [TowerManager.team[i].character_name, reason]
				return

# ---------- Cartes ----------

func _make_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	return l

func _card_style(border: Color, background: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(10)
	return style

# La carte vide « + » : un clic ajoute un personnage (1 point).
func _build_add_card() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	panel.add_theme_stylebox_override("panel", _card_style(Color(0.45, 0.45, 0.5), Color(0.1, 0.1, 0.12, 0.6)))

	var center := CenterContainer.new()
	panel.add_child(center)

	var btn := Button.new()
	btn.text = "+"
	btn.add_theme_font_size_override("font_size", 52)
	btn.custom_minimum_size = Vector2(120, 120)
	btn.disabled = TowerManager.points_remaining < 1
	btn.tooltip_text = "Ajouter un personnage (coûte 1 point)" if not btn.disabled else "Plus aucun point à dépenser"
	btn.pressed.connect(_on_add_character_pressed)
	center.add_child(btn)
	return panel

# Carte d'un personnage. Bordure verte = tous ses choix sont faits,
# orange = il manque encore un métier (ou une évolution).
func _build_character_card(index: int) -> Control:
	var complete: bool = TowerManager.is_character_complete(index)
	var border := Color(0.35, 0.65, 0.45) if complete else Color(0.8, 0.55, 0.25)

	# Taille FIXE (largeur ET hauteur) : ni le texte d'une liste déroulante, ni
	# une ligne en plus ne doivent agrandir ou rétrécir la carte — ni, par
	# contagion, étirer les autres (la rangée donne la même hauteur à toutes).
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	panel.clip_contents = true
	panel.add_theme_stylebox_override("panel", _card_style(border, Color(0.13, 0.14, 0.17)))

	# Un ScrollContainer dont le défilement horizontal est DÉSACTIVÉ prend la
	# largeur minimale de son contenu : un nom de race ou de métier plus long
	# élargissait donc la carte. On le range dans un Control simple (qui ne
	# transmet aucune taille minimale) et on laisse le contenu défiler au
	# lieu de pousser les bords.
	var holder := Control.new()
	holder.clip_contents = true
	panel.add_child(holder)

	var inner_scroll := ScrollContainer.new()
	inner_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	inner_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.add_child(inner_scroll)

	var card := VBoxContainer.new()
	card.add_theme_constant_override("separation", 3)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(CARD_WIDTH - 44, 0)  # Largeur utile (bordure, marges et barre de défilement déduites).
	inner_scroll.add_child(card)

	card.add_child(_build_card_header(index))
	card.add_child(_build_race_selector(index))
	card.add_child(_build_level_row(index))
	card.add_child(HSeparator.new())
	card.add_child(_build_stats_block(index))
	card.add_child(HSeparator.new())
	card.add_child(_build_metier_block(index))
	card.add_child(HSeparator.new())
	card.add_child(_build_equipment_block(index))
	_constrain_width(card)
	return panel

# Aucun texte ne doit pouvoir élargir la carte : un Label posé directement
# dans une colonne passe à la ligne s'il est trop long, les autres sont
# coupés (l'infobulle donne le texte complet).
func _constrain_width(node: Node) -> void:
	for child in node.get_children():
		if child is Label:
			var label := child as Label
			if node is VBoxContainer:
				if label.autowrap_mode == TextServer.AUTOWRAP_OFF:
					label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			elif label.size_flags_horizontal & Control.SIZE_EXPAND:
				label.clip_text = true
		_constrain_width(child)

# Nom (modifiable) et retrait du personnage.
func _build_card_header(index: int) -> Control:
	var c = TowerManager.team[index]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	var name_edit := LineEdit.new()
	name_edit.text = c.character_name
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.text_submitted.connect(func(new_text): _on_name_changed(index, new_text))
	name_edit.focus_exited.connect(func():
		if is_instance_valid(name_edit):
			_on_name_changed(index, name_edit.text)
	)
	row.add_child(name_edit)

	var remove_btn := Button.new()
	remove_btn.text = "✕"
	remove_btn.tooltip_text = "Retirer ce personnage (récupère ses points et son équipement)"
	remove_btn.pressed.connect(func():
		TowerManager.remove_character(index)
		_refresh()
	)
	row.add_child(remove_btn)
	return row

# Race : flèches latérales, illustration entre les deux (ou le nom,
# faute d'image).
func _build_race_selector(index: int) -> Control:
	var c = TowerManager.team[index]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	var left := Button.new()
	left.text = "◀"
	left.tooltip_text = "Race précédente"
	left.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	left.pressed.connect(func():
		TowerManager.cycle_race(index, -1)
		_refresh()
	)
	row.add_child(left)

	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(150, 56)
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.mouse_filter = Control.MOUSE_FILTER_PASS  # Pour que l'infobulle s'affiche.
	frame.add_theme_stylebox_override("panel", _card_style(Color(0.3, 0.3, 0.36), Color(0.08, 0.08, 0.1)))
	var race = RaceDatabase.build(c.race_name)
	frame.tooltip_text = race.get_display_text() if race != null else c.race_name

	var texture := _get_race_texture(c.race_name)
	if texture != null:
		var image := TextureRect.new()
		image.texture = texture
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.mouse_filter = Control.MOUSE_FILTER_PASS
		frame.add_child(image)
	else:
		var name_label := Label.new()
		name_label.text = c.race_name
		name_label.add_theme_font_size_override("font_size", 18)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_label.mouse_filter = Control.MOUSE_FILTER_PASS
		frame.add_child(name_label)
	row.add_child(frame)

	var right := Button.new()
	right.text = "▶"
	right.tooltip_text = "Race suivante"
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	right.pressed.connect(func():
		TowerManager.cycle_race(index, 1)
		_refresh()
	)
	row.add_child(right)
	return row

# Illustration de la race si le fichier existe (voir RACE_IMAGE_DIR), sinon null.
func _get_race_texture(race_name: String) -> Texture2D:
	var slug := _normalize_text(race_name).replace(" ", "_")
	var path := "%s%s.png" % [RACE_IMAGE_DIR, slug]
	if ResourceLoader.exists(path):
		var resource = load(path)
		if resource is Texture2D:
			return resource
	return null

# Niveau, avec - / +. Chaque niveau coûte 1 point du total (les 16 de
# l'équipe). Les niveaux 2, 5 et 8 donnent AUSSI 1 point de
# caractéristique et relèvent la limite des stats, rappelée dessous.
func _build_level_row(index: int) -> Control:
	var c = TowerManager.team[index]

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	box.add_child(row)

	var label := Label.new()
	label.text = "Niveau %d" % c.level
	label.add_theme_font_size_override("font_size", 16)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)

	var down := Button.new()
	down.text = "−"
	down.custom_minimum_size = Vector2(34, 0)
	down.disabled = not TowerManager.can_level_down(index)
	if down.disabled and c.level > 1:
		down.tooltip_text = TowerManager.get_level_down_block_reason(index)
	down.pressed.connect(func():
		TowerManager.level_down(index)
		_refresh()
	)
	row.add_child(down)

	var up := Button.new()
	up.text = "+"
	up.custom_minimum_size = Vector2(34, 0)
	up.disabled = not TowerManager.can_level_up(index)
	if not up.disabled:
		var next_level: int = c.level + 1
		var gained_points: int = TowerManager.get_level_bonus_points(next_level) - TowerManager.get_level_bonus_points(c.level)
		var tip := "Monter d'un niveau (coûte 1 point)"
		if gained_points > 0:
			tip += " : +%d point(s) de caractéristique, limite des stats %d" % [gained_points, TowerManager.get_level_stat_cap(next_level)]
		up.tooltip_text = tip
	elif c.level >= TowerManager.MAX_LEVEL:
		up.tooltip_text = "Niveau maximum"
	else:
		up.tooltip_text = "Plus aucun point disponible"
	up.pressed.connect(func():
		TowerManager.level_up(index)
		_refresh()
	)
	row.add_child(up)

	# Rappel de la limite des caractéristiques à ce niveau (et des stats
	# que la race en exempte).
	var caption := Label.new()
	var exempt_names: Array = []
	for stat in TowerManager.STAT_KEYS:
		if TowerManager.get_stat_level_cap(index, stat) < 0:
			exempt_names.append(TowerManager.STAT_LABELS[stat])
	if exempt_names.size() == TowerManager.STAT_KEYS.size():
		caption.text = "Aucune limite de niveau sur les caractéristiques"  # Humain.
	else:
		caption.text = "Limite des caractéristiques : %d" % TowerManager.get_level_stat_cap(c.level)
		if not exempt_names.is_empty():
			caption.text += " (%s : aucune)" % ", ".join(exempt_names)
	caption.add_theme_font_size_override("font_size", 11)
	caption.modulate = Color(0.75, 0.75, 0.8)
	box.add_child(caption)
	return box

# Caractéristiques : valeur actuelle, - / +, et points restant à répartir
# (sur 19 par personnage ; les stats partent de 8, la chance de 1). Un
# MINIMUM imposé par la race s'affiche "min N" (la stat part de là, sans
# pouvoir descendre dessous, l'écart déjà décompté des points), un
# MAXIMUM "max N" (la stat ne peut pas le dépasser).
func _build_stats_block(index: int) -> Control:
	var c = TowerManager.team[index]
	var unspent: int = TowerManager.get_stat_points_unspent(index)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)

	var title := Label.new()
	title.text = "Caractéristiques — %d / %d point(s) à répartir" % [unspent, TowerManager.get_stat_pool(index)]
	title.tooltip_text = TowerManager.get_stat_pool_breakdown(index)
	title.mouse_filter = Control.MOUSE_FILTER_PASS
	title.add_theme_font_size_override("font_size", 13)
	title.modulate = Color(1.0, 0.85, 0.4) if unspent > 0 else Color(0.7, 0.7, 0.75)
	box.add_child(title)

	for stat in TowerManager.STAT_KEYS:
		var allocated: int = int(c.stat_points.get(stat, 0))
		var value: int = TowerManager.get_stat_value(index, stat)
		var floor_value: int = TowerManager.get_race_stat_floor(c.race_name, stat)
		var cap_value: int = TowerManager.get_race_stat_cap(c.race_name, stat)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)

		var name_label := Label.new()
		name_label.text = TowerManager.STAT_LABELS[stat]
		name_label.custom_minimum_size = Vector2(88, 0)
		row.add_child(name_label)

		# Rappel des contraintes propres à cette stat : minimum/maximum de
		# race, et absence de limite de niveau (Ogre, en Force).
		var level_cap_value: int = TowerManager.get_stat_level_cap(index, stat)
		var hint_parts: Array = []
		var hint_tips: Array = []
		if floor_value > 0:
			hint_parts.append("min %d" % floor_value)
			hint_tips.append("Minimum imposé par la race : %d (l'écart avec la valeur par défaut est déjà décompté des points)" % floor_value)
		elif cap_value >= 0:
			hint_parts.append("max %d" % cap_value)
			hint_tips.append("Maximum imposé par la race : %d" % cap_value)
		if level_cap_value < 0:
			hint_parts.append("illimité")
			hint_tips.append("Cette race n'est pas limitée sur cette caractéristique par son niveau")

		var hint := Label.new()
		hint.text = " · ".join(hint_parts)
		hint.tooltip_text = "\n".join(hint_tips)
		hint.add_theme_font_size_override("font_size", 11)
		hint.modulate = Color(0.95, 0.7, 0.35)
		hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hint.clip_text = true  # Ne doit jamais élargir la carte ; l'infobulle donne le texte complet.
		hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		hint.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_child(hint)

		var value_label := Label.new()
		value_label.text = str(value)
		value_label.custom_minimum_size = Vector2(28, 0)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value_label.mouse_filter = Control.MOUSE_FILTER_PASS
		var start_value: int = TowerManager.get_stat_baseline(c.race_name, stat)
		if floor_value > 0:
			value_label.tooltip_text = "Départ %d (minimum de la race) + %d réparti(s)" % [start_value, allocated]
		else:
			value_label.tooltip_text = "Départ %d + %d réparti(s)" % [start_value, allocated]
		if level_cap_value >= 0:
			value_label.tooltip_text += "\nLimite du niveau : %d" % level_cap_value
		row.add_child(value_label)

		var minus := Button.new()
		minus.text = "−"
		minus.custom_minimum_size = Vector2(30, 0)
		minus.disabled = not TowerManager.can_decrease_stat(index, stat)
		if minus.disabled:
			minus.tooltip_text = TowerManager.get_stat_decrease_block_reason(index, stat)
		minus.pressed.connect(func():
			TowerManager.decrease_stat(index, stat)
			_refresh()
		)
		row.add_child(minus)

		var plus := Button.new()
		plus.text = "+"
		plus.custom_minimum_size = Vector2(30, 0)
		plus.disabled = not TowerManager.can_increase_stat(index, stat)
		if plus.disabled:
			plus.tooltip_text = TowerManager.get_stat_increase_block_reason(index, stat)
		plus.pressed.connect(func():
			TowerManager.increase_stat(index, stat)
			_refresh()
		)
		row.add_child(plus)

		box.add_child(row)
	return box

# Métier de base (niveau 1) puis les métiers de niveau 4 / 7 / 10.
func _build_metier_block(index: int) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)

	var caption := Label.new()
	caption.text = "Métier"
	caption.add_theme_font_size_override("font_size", 13)
	box.add_child(caption)
	box.add_child(_build_metier_row(index, 1))

	var caption_more := Label.new()
	caption_more.text = "Autres métiers"
	caption_more.add_theme_font_size_override("font_size", 13)
	box.add_child(caption_more)
	for threshold in [4, 7, 10]:
		box.add_child(_build_metier_row(index, threshold))
	return box

func _build_metier_row(index: int, threshold: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	var level_label := Label.new()
	level_label.text = "Niv. %d" % threshold
	level_label.custom_minimum_size = Vector2(46, 0)
	level_label.add_theme_font_size_override("font_size", 12)
	level_label.modulate = Color(0.75, 0.75, 0.8)
	row.add_child(level_label)

	row.add_child(_build_metier_option(index, threshold))
	return row

# Liste déroulante du métier d'un palier (1, 4, 7 ou 10). Les métiers
# interdits à la race n'y figurent pas ; ceux dont les caractéristiques
# ne suffisent pas y sont GRISÉS, avec ce qu'il leur manque. Désactivée
# (avec la raison en texte) tant que le palier n'est pas atteignable.
func _build_metier_option(index: int, threshold: int) -> OptionButton:
	var c = TowerManager.team[index]

	var current := ""
	var choices: Array = []
	var disabled_reason := ""
	match threshold:
		1:
			current = c.metier_code_l1
			choices = TowerManager.get_base_metier_choices(index)
		4:
			current = c.metier_code_l4
		7:
			current = c.metier_code_l7
		10:
			current = c.metier_code_l10
	if threshold > 1:
		if c.level < threshold:
			disabled_reason = "Niveau %d requis" % threshold
		elif TowerManager.get_previous_tier_metier_code(index, threshold) == "":
			disabled_reason = "Choisis d'abord le métier précédent"
		else:
			choices = TowerManager.get_evolution_choices(index, threshold)
			if choices.is_empty():
				disabled_reason = "Aucune évolution"

	var opt := OptionButton.new()
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opt.clip_text = true  # Un nom long ne doit pas élargir la carte.
	opt.fit_to_longest_item = false  # Par défaut la liste prend la largeur de son plus long choix : c'est ce qui élargissait la carte.
	opt.add_item("— Aucun —")
	opt.set_item_metadata(0, "")

	if disabled_reason != "":
		opt.set_item_text(0, disabled_reason)
		opt.disabled = true
		return opt

	var selected_idx := 0
	for choice in choices:
		var label: String = choice["name"]
		if not choice["available"]:
			label += "  (%s)" % choice["missing"]
		opt.add_item(label)
		var item_idx: int = opt.item_count - 1
		opt.set_item_metadata(item_idx, choice["code"])
		if not choice["available"]:
			opt.set_item_disabled(item_idx, true)
		if choice["code"] == current:
			selected_idx = item_idx
	opt.selected = selected_idx

	opt.item_selected.connect(func(item_idx):
		var chosen_code := str(opt.get_item_metadata(item_idx))
		var refusal: String = TowerManager.get_set_metier_block_reason(index, threshold, chosen_code)
		if refusal != "":
			_notice = refusal  # Refusé : la liste se reconstruit sur le choix actuel, et le message s'affiche.
		else:
			TowerManager.set_metier(index, threshold, chosen_code)
		_refresh()
	)
	return opt

# Résumé de l'équipement porté + accès à la boutique.
func _build_equipment_block(index: int) -> Control:
	var c = TowerManager.team[index]
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)

	var caption := Label.new()
	caption.text = "Équipement"
	caption.add_theme_font_size_override("font_size", 13)
	box.add_child(caption)

	box.add_child(_gear_line("Arme", c.equipped_weapon.weapon_name if c.equipped_weapon != null else ""))
	if TowerManager.can_dual_wield(index):
		box.add_child(_gear_line("2e arme", c.equipped_off_hand.weapon_name if c.equipped_off_hand != null else ""))
	# Un emplacement par ligne : les 5 pièces d'armure, puis le bouclier, à part.
	for piece_slot in EquipmentRules.ARMOR_SLOTS + [EquipmentRules.SHIELD_SLOT]:
		var piece = c.equipped_armor.get(piece_slot)
		box.add_child(_gear_line(EquipmentRules.SLOT_LABELS[piece_slot], piece.armor_name if piece != null else ""))
	var accessory_names: Array = []
	for acc in c.equipped_accessories:
		if acc != null:
			accessory_names.append(acc.accessory_name)
	box.add_child(_gear_line("Accessoires", ", ".join(accessory_names)))

	# Pièces obligatoires du métier qui manquent encore (Gladiateur : casque
	# et bouclier) : le personnage reste incomplet tant qu'elles manquent.
	var missing: Array = TowerManager.get_missing_equipment(index)
	if not missing.is_empty():
		var missing_label := Label.new()
		missing_label.text = "Obligatoire : %s" % ", ".join(missing)
		missing_label.add_theme_font_size_override("font_size", 12)
		missing_label.modulate = Color(0.95, 0.6, 0.35)
		missing_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(missing_label)

	var shop_btn := Button.new()
	shop_btn.text = "Acheter / équiper..."
	shop_btn.pressed.connect(func(): _open_equip_popup(index))
	box.add_child(shop_btn)
	return box

func _gear_line(title: String, value: String) -> Label:
	var line := Label.new()
	line.text = "%s : %s" % [title, value if value != "" else "—"]
	line.add_theme_font_size_override("font_size", 12)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return line

# ---------- Popup d'équipement ----------
#
# Trois onglets (Armes / Armures / Accessoires), puis des filtres :
# catégorie (propre à l'onglet), portée (armes seulement), recherche par
# nom, "abordable", et tri. Chaque ligne montre CE QU'ON ACHÈTE (dés de
# dégâts + bonus) et l'effet spécial éventuel, pas seulement un nom.

## Libellés des bonus (clés des catalogues) — l'ordre ici = l'ordre d'affichage.
const BONUS_LABELS := {
	"bonus_vie": "PV", "bonus_mana": "EA",
	"bonus_attaque": "AT", "bonus_parade": "PRD", "bonus_armure": "PR",
	"bonus_courage": "COU", "bonus_intelligence": "INT", "bonus_charisme": "CHA",
	"bonus_adresse": "AD", "bonus_force": "FO", "bonus_chance": "CHN",
}

const EQUIP_TYPES := [
	{"id": "weapons", "label": "Armes"},
	{"id": "armors", "label": "Armures"},
	{"id": "accessories", "label": "Accessoires"},
]

var _equip_type: String = "weapons"
var _equip_category: String = ""        # "" = toutes les catégories
var _equip_search: String = ""          # normalisé : minuscules, sans accents (voir _normalize_text)
var _equip_affordable_only: bool = false
var _equip_only_allowed: bool = true    # Masque ce que la race/le métier de ce personnage interdit.
var _equip_sort: int = 0                # 0 prix croissant, 1 prix décroissant, 2 nom
var _equip_range: int = 0               # 0 toutes, 1 corps à corps, 2 distance (armes)
var _equip_slot: String = ""            # "" = tous les emplacements (armures)

var _equip_type_buttons: Dictionary = {}
var _equip_category_option: OptionButton
var _equip_range_box: HBoxContainer
var _equip_range_option: OptionButton
var _equip_slot_box: HBoxContainer
var _equip_slot_option: OptionButton
var _equip_search_edit: LineEdit
var _equip_affordable_check: CheckBox
var _equip_allowed_check: CheckBox
var _equip_sort_option: OptionButton
var _equip_count_label: Label

func _build_equip_popup() -> void:
	_equip_popup = PopupPanel.new()
	add_child(_equip_popup)
	# Ferme par clic extérieur OU bouton : dans les deux cas l'écran
	# principal doit se rafraîchir (équipement affiché, or restant).
	_equip_popup.popup_hide.connect(_refresh)

	var popup_vbox := VBoxContainer.new()
	popup_vbox.add_theme_constant_override("separation", 6)
	_equip_popup.add_child(popup_vbox)

	_equip_popup_gold_label = Label.new()
	_equip_popup_gold_label.add_theme_font_size_override("font_size", 14)
	popup_vbox.add_child(_equip_popup_gold_label)

	# --- Onglets de type ---
	var type_row := HBoxContainer.new()
	type_row.add_theme_constant_override("separation", 6)
	popup_vbox.add_child(type_row)
	var type_group := ButtonGroup.new()
	for t in EQUIP_TYPES:
		var type_id: String = t["id"]
		var b := Button.new()
		b.text = t["label"]
		b.toggle_mode = true
		b.button_group = type_group
		b.button_pressed = (type_id == _equip_type)
		b.pressed.connect(func(): _on_equip_type_selected(type_id))
		type_row.add_child(b)
		_equip_type_buttons[type_id] = b

	# --- Filtres, ligne 1 : catégorie, portée ---
	var filter_row1 := HBoxContainer.new()
	filter_row1.add_theme_constant_override("separation", 8)
	popup_vbox.add_child(filter_row1)

	filter_row1.add_child(_make_label("Catégorie :"))
	_equip_category_option = OptionButton.new()
	_equip_category_option.item_selected.connect(func(i):
		_equip_category = _equip_category_option.get_item_metadata(i)
		_populate_equip_list()
	)
	filter_row1.add_child(_equip_category_option)

	_equip_range_box = HBoxContainer.new()
	_equip_range_box.add_theme_constant_override("separation", 6)
	_equip_range_box.add_child(_make_label("Portée :"))
	_equip_range_option = OptionButton.new()
	_equip_range_option.add_item("Toutes")
	_equip_range_option.add_item("Corps à corps")
	_equip_range_option.add_item("Distance")
	_equip_range_option.item_selected.connect(func(i):
		_equip_range = i
		_populate_equip_list()
	)
	_equip_range_box.add_child(_equip_range_option)
	filter_row1.add_child(_equip_range_box)

	# Armures : filtre par EMPLACEMENT (casque, plastron...). Sans lui, les 68
	# pièces de tous les matériaux se mélangent.
	_equip_slot_box = HBoxContainer.new()
	_equip_slot_box.add_theme_constant_override("separation", 6)
	_equip_slot_box.add_child(_make_label("Emplacement :"))
	_equip_slot_option = OptionButton.new()
	_equip_slot_option.add_item("Tous")
	_equip_slot_option.set_item_metadata(0, "")
	for piece_slot in EquipmentRules.ARMOR_SLOTS + [EquipmentRules.SHIELD_SLOT]:
		_equip_slot_option.add_item(EquipmentRules.SLOT_LABELS[piece_slot])
		_equip_slot_option.set_item_metadata(_equip_slot_option.item_count - 1, piece_slot)
	_equip_slot_option.item_selected.connect(func(i):
		_equip_slot = str(_equip_slot_option.get_item_metadata(i))
		_populate_equip_list()
	)
	_equip_slot_box.add_child(_equip_slot_option)
	filter_row1.add_child(_equip_slot_box)

	# --- Filtres, ligne 2 : recherche, abordable, tri ---
	var filter_row2 := HBoxContainer.new()
	filter_row2.add_theme_constant_override("separation", 8)
	popup_vbox.add_child(filter_row2)

	_equip_search_edit = LineEdit.new()
	_equip_search_edit.placeholder_text = "Rechercher un nom..."
	_equip_search_edit.custom_minimum_size = Vector2(170, 0)
	_equip_search_edit.clear_button_enabled = true
	_equip_search_edit.text_changed.connect(func(t):
		_equip_search = _normalize_text(t.strip_edges())
		_populate_equip_list()
	)
	filter_row2.add_child(_equip_search_edit)

	_equip_affordable_check = CheckBox.new()
	_equip_affordable_check.text = "Abordable"
	_equip_affordable_check.toggled.connect(func(pressed):
		_equip_affordable_only = pressed
		_populate_equip_list()
	)
	filter_row2.add_child(_equip_affordable_check)

	_equip_allowed_check = CheckBox.new()
	_equip_allowed_check.text = "Équipables"
	_equip_allowed_check.tooltip_text = "Masque ce que la race ou le métier de ce personnage interdit. Décochée : ces objets restent visibles, grisés, avec la raison."
	_equip_allowed_check.button_pressed = true
	_equip_allowed_check.toggled.connect(func(pressed):
		_equip_only_allowed = pressed
		_rebuild_category_options()  # Les effectifs par catégorie suivent ce qui est visible.
		_populate_equip_list()
	)
	filter_row2.add_child(_equip_allowed_check)

	filter_row2.add_child(_make_label("Tri :"))
	_equip_sort_option = OptionButton.new()
	_equip_sort_option.add_item("Prix croissant")
	_equip_sort_option.add_item("Prix décroissant")
	_equip_sort_option.add_item("Nom (A-Z)")
	_equip_sort_option.item_selected.connect(func(i):
		_equip_sort = i
		_populate_equip_list()
	)
	filter_row2.add_child(_equip_sort_option)

	# --- Compteur + liste ---
	_equip_count_label = Label.new()
	_equip_count_label.add_theme_font_size_override("font_size", 12)
	_equip_count_label.modulate = Color(0.75, 0.75, 0.8)
	popup_vbox.add_child(_equip_count_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(580, 260)
	popup_vbox.add_child(scroll)

	_equip_popup_content = VBoxContainer.new()
	_equip_popup_content.add_theme_constant_override("separation", 4)
	_equip_popup_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_equip_popup_content)

	var close_btn := Button.new()
	close_btn.text = "Fermer"
	close_btn.pressed.connect(func(): _equip_popup.hide())
	popup_vbox.add_child(close_btn)

func _open_equip_popup(index: int) -> void:
	_equip_popup_index = index
	_equip_type = "weapons"
	_equip_type_buttons["weapons"].set_pressed_no_signal(true)
	_reset_equip_filters()
	_populate_equip_list()
	# Taille bornée par la fenêtre : 700x640 déborderait d'un écran de 648 px.
	var vp := get_viewport_rect().size
	_equip_popup.popup_centered(Vector2i(int(min(700.0, vp.x - 40.0)), int(min(640.0, vp.y - 40.0))))

func _on_equip_type_selected(type_id: String) -> void:
	if type_id == _equip_type:
		return
	_equip_type = type_id
	_reset_equip_filters()
	_populate_equip_list()

# Remet tous les filtres à zéro et reconstruit la liste des catégories
# pour le type courant (les catégories d'armes n'ont rien à voir avec
# celles d'armures) — appelé à l'ouverture et à chaque changement d'onglet.
func _reset_equip_filters() -> void:
	_equip_category = ""
	_equip_search = ""
	_equip_affordable_only = false
	_equip_only_allowed = true
	_equip_sort = 0
	_equip_range = 0
	_equip_slot = ""
	_equip_slot_option.select(0)
	_equip_search_edit.text = ""
	_equip_affordable_check.set_pressed_no_signal(false)
	_equip_allowed_check.set_pressed_no_signal(true)
	_equip_sort_option.select(0)
	_equip_range_option.select(0)
	_equip_range_box.visible = (_equip_type == "weapons")
	_equip_slot_box.visible = (_equip_type == "armors")
	_rebuild_category_options()

# Pourquoi le personnage du popup ne peut pas équiper cet objet ("" = il peut).
func _equip_block_reason(data: Dictionary) -> String:
	return TowerManager.get_equipment_block_reason(_equip_popup_index, _equip_type, data)

# Reconstruit la liste des catégories du type courant, avec le nombre
# d'objets VISIBLES : sans ceux que la race ou le métier interdisent tant
# que « Équipables » est coché (sinon « Arbalètes (8) » promettrait 8
# objets là où il n'y en a aucun).
func _rebuild_category_options() -> void:
	_equip_category = ""
	var items: Array = []
	for data in _get_equip_items():
		if not _equip_only_allowed or _equip_block_reason(data) == "":
			items.append(data)

	var counts: Dictionary = {}
	var order: Array = []
	for data in items:
		var cat: String = str(data.get("category", ""))
		if cat == "":
			continue
		if not counts.has(cat):
			counts[cat] = 0
			order.append(cat)  # Ordre du catalogue conservé : regroupe naturellement les familles proches.
		counts[cat] += 1

	_equip_category_option.clear()
	_equip_category_option.add_item("Toutes (%d)" % items.size())
	_equip_category_option.set_item_metadata(0, "")
	for cat in order:
		_equip_category_option.add_item("%s (%d)" % [cat, counts[cat]])
		_equip_category_option.set_item_metadata(_equip_category_option.item_count - 1, cat)
	_equip_category_option.select(0)

# Minuscules SANS accents, pour que "epee" comme "épée" trouvent
# "Epée pérave" (les noms du catalogue mélangent majuscules accentuées
# ou non, ex: "Epée" sans accent sur le E).
func _normalize_text(s: String) -> String:
	var result := s.to_lower()
	for pair in [["é", "e"], ["è", "e"], ["ê", "e"], ["ë", "e"], ["à", "a"], ["â", "a"], ["ä", "a"],
			["î", "i"], ["ï", "i"], ["ô", "o"], ["ö", "o"], ["ù", "u"], ["û", "u"], ["ü", "u"],
			["ç", "c"], ["œ", "oe"]]:
		result = result.replace(pair[0], pair[1])
	return result

func _get_equip_items() -> Array:
	match _equip_type:
		"weapons":
			return WeaponCatalog.get_all()
		"armors":
			return ArmorCatalog.get_all()
	return AccessoryCatalog.get_all()

func _build_item_from_data(data: Dictionary):
	match _equip_type:
		"weapons":
			return ShopGenerator.build_weapon_from_data(data)
		"armors":
			return ShopGenerator.build_armor_from_data(data)
	return ShopGenerator.build_accessory_from_data(data)

# Objets du type courant qui passent TOUS les filtres, triés.
func _filter_equip_items() -> Array:
	var result: Array = []
	for data in _get_equip_items():
		if _equip_category != "" and str(data.get("category", "")) != _equip_category:
			continue
		if _equip_type == "weapons" and _equip_range != 0:
			var is_ranged: bool = str(data.get("weapon_type", "melee")) == "ranged"
			if (_equip_range == 1 and is_ranged) or (_equip_range == 2 and not is_ranged):
				continue
		if _equip_type == "armors" and _equip_slot != "" and EquipmentRules.get_armor_slot(data) != _equip_slot:
			continue
		if _equip_search != "" and not _normalize_text(str(data.get("name", ""))).contains(_equip_search):
			continue
		if _equip_affordable_only and not TowerManager.can_afford(_equip_popup_index, _equip_type, int(data.get("price", 0)), data):
			continue
		if _equip_only_allowed and _equip_block_reason(data) != "":
			continue
		result.append(data)

	result.sort_custom(func(a, b):
		var pa: int = int(a.get("price", 0))
		var pb: int = int(b.get("price", 0))
		var na: String = str(a.get("name", ""))
		var nb: String = str(b.get("name", ""))
		match _equip_sort:
			1:
				return pa > pb if pa != pb else na < nb
			2:
				return na < nb
		return pa < pb if pa != pb else na < nb
	)
	return result

func _populate_equip_list() -> void:
	if _equip_popup_index < 0 or _equip_popup_index >= TowerManager.team.size():
		return
	var c = TowerManager.team[_equip_popup_index]
	_equip_popup_gold_label.text = "%s — Or disponible : %d PO" % [c.character_name, TowerManager.gold]

	for child in _equip_popup_content.get_children():
		child.queue_free()

	var items := _filter_equip_items()
	_equip_count_label.text = "%d objet(s)" % items.size()
	if items.is_empty():
		var empty := Label.new()
		empty.text = "Aucun objet ne correspond à ces filtres."
		empty.modulate = Color(0.8, 0.7, 0.5)
		_equip_popup_content.add_child(empty)
		return
	for data in items:
		_equip_popup_content.add_child(_build_equip_row(data, c))

# Vrai si le personnage porte déjà un objet de ce nom dans le slot courant.
# Vrai si ces deux entrées de catalogue sont le même objet (nom ET catégorie).
func _same_catalog_item(a: Dictionary, b: Dictionary) -> bool:
	return str(a.get("name", "")) == str(b.get("name", "")) and str(a.get("category", "")) == str(b.get("category", ""))

func _is_equipped(c, item_name: String) -> bool:
	match _equip_type:
		"weapons":
			return (c.equipped_weapon != null and c.equipped_weapon.weapon_name == item_name) \
				or (c.equipped_off_hand != null and c.equipped_off_hand.weapon_name == item_name)
		"armors":
			for piece in c.equipped_armor.values():
				if piece != null and piece.armor_name == item_name:
					return true
			return false
	for acc in c.equipped_accessories:
		if acc != null and acc.accessory_name == item_name:
			return true
	return false

# Résumé compact de ce qu'apporte l'objet : dés de dégâts (armes) puis
# tous les bonus non nuls, ex: "1D+3  +1 AD  -1 PRD".
func _format_item_stats(data: Dictionary) -> String:
	var parts: Array = []
	if _equip_type == "weapons":
		var dice := int(data.get("dice_count", 0))
		var modifier := int(data.get("dice_modifier", 0))
		if dice > 0:
			parts.append(("%dD%+d" % [dice, modifier]) if modifier != 0 else ("%dD" % dice))
		else:
			parts.append(str(modifier))  # Pas de dés : valeur fixe.
	elif _equip_type == "armors":
		var piece_slot: String = EquipmentRules.get_armor_slot(data)
		if piece_slot != "":
			parts.append(EquipmentRules.SLOT_LABELS[piece_slot])
	for key in BONUS_LABELS:
		var value := int(data.get(key, 0))
		if value != 0:
			parts.append("%+d %s" % [value, BONUS_LABELS[key]])
	return "  ".join(parts)

# Une ligne d'objet : nom, bonus, prix, bouton ; puis l'effet spécial
# (champ "info" du catalogue) en petit dessous, s'il y en a un.
func _build_equip_row(data: Dictionary, c) -> Control:
	var price := int(data.get("price", 0))
	var item_name := str(data.get("name", "?"))
	var is_equipped := _is_equipped(c, item_name)
	var block_reason: String = _equip_block_reason(data)  # Restriction de race/métier.

	# Armes : on distingue les deux mains. Comparaison par nom ET catégorie,
	# car deux catégories portent des noms identiques ("Hache pérave").
	var in_main_hand := false
	var in_off_hand := false
	var dual_wield := false
	if _equip_type == "weapons":
		in_main_hand = c.equipped_weapon != null and _same_catalog_item(c.equipped_weapon_data, data)
		in_off_hand = c.equipped_off_hand != null and _same_catalog_item(c.equipped_off_hand_data, data)
		is_equipped = in_main_hand or in_off_hand
		dual_wield = TowerManager.can_dual_wield(_equip_popup_index)

	# Accessoires : on peut en porter 2, racheter le même n'est pas absurde.
	var blocked_as_duplicate: bool = in_main_hand if _equip_type == "weapons" else (is_equipped and _equip_type != "accessories")

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)

	var name_label := Label.new()
	name_label.text = ("✔ " if is_equipped else "") + item_name
	name_label.custom_minimum_size = Vector2(170, 0)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.mouse_filter = Control.MOUSE_FILTER_PASS  # Pour que l'infobulle (nom complet) s'affiche.
	name_label.tooltip_text = item_name
	if is_equipped:
		name_label.modulate = Color(0.55, 0.9, 0.55)
	elif block_reason != "":
		name_label.modulate = Color(0.6, 0.6, 0.6)
	row.add_child(name_label)

	var stats_label := Label.new()
	stats_label.text = _format_item_stats(data)
	stats_label.add_theme_font_size_override("font_size", 12)
	stats_label.modulate = Color(0.8, 0.85, 0.95)
	row.add_child(stats_label)

	var price_label := Label.new()
	price_label.text = "%d PO" % price
	price_label.custom_minimum_size = Vector2(72, 0)
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(price_label)

	var buy_btn := Button.new()
	var main_label := "Main" if dual_wield else "Acheter"
	buy_btn.text = "Équipé" if blocked_as_duplicate else ("Interdit" if block_reason != "" else main_label)
	buy_btn.custom_minimum_size = Vector2(76, 0)
	buy_btn.disabled = blocked_as_duplicate or block_reason != "" or not TowerManager.can_afford(_equip_popup_index, _equip_type, price, data, "main")
	if block_reason != "":
		buy_btn.tooltip_text = "Interdit — " + block_reason
	elif dual_wield:
		buy_btn.tooltip_text = "Équiper dans la main principale"
	buy_btn.pressed.connect(func():
		var item = _build_item_from_data(data)
		if TowerManager.buy_and_equip(_equip_popup_index, item, data, "main"):
			_populate_equip_list()
	)
	row.add_child(buy_btn)

	# Personnage à deux armes (Ambidextrie, ou Pirate) : un second bouton
	# pour la seconde main, avec la raison quand elle est refusée.
	if dual_wield:
		var off_reason: String = TowerManager.get_off_hand_block_reason(_equip_popup_index, data)
		var off_btn := Button.new()
		off_btn.text = "Équipé" if in_off_hand else ("Interdit" if block_reason != "" else "2e main")
		off_btn.custom_minimum_size = Vector2(76, 0)
		off_btn.disabled = in_off_hand or block_reason != "" or off_reason != "" or not TowerManager.can_afford(_equip_popup_index, _equip_type, price, data, "off_hand")
		if block_reason != "":
			off_btn.tooltip_text = "Interdit — " + block_reason
		elif off_reason != "":
			off_btn.tooltip_text = off_reason
		else:
			off_btn.tooltip_text = "Équiper dans la seconde main"
		off_btn.pressed.connect(func():
			var off_item = _build_item_from_data(data)
			if TowerManager.buy_and_equip(_equip_popup_index, off_item, data, "off_hand"):
				_populate_equip_list()
		)
		row.add_child(off_btn)

	if block_reason != "":
		var block_label := Label.new()
		block_label.text = "      Interdit — " + block_reason
		block_label.add_theme_font_size_override("font_size", 11)
		block_label.modulate = Color(0.95, 0.6, 0.35)
		box.add_child(block_label)

	var info := str(data.get("info", ""))
	if info != "":
		var info_label := Label.new()
		info_label.text = "      " + info
		info_label.add_theme_font_size_override("font_size", 11)
		info_label.modulate = Color(0.7, 0.7, 0.75)
		info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # Un effet long passe à la ligne au lieu d'être coupé.
		info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_child(info_label)

	return box

# ---------- Signaux divers ----------

func _on_name_changed(index: int, new_text: String) -> void:
	if index < 0 or index >= TowerManager.team.size():
		return  # Personnage retiré entre-temps (carte reconstruite).
	if new_text.strip_edges() != "":
		TowerManager.team[index].character_name = new_text.strip_edges()

func _on_add_character_pressed() -> void:
	TowerManager.add_character()
	_refresh()

func _on_validate_pressed() -> void:
	if not TowerManager.is_team_ready():
		return
	# Lance l'ascension : étage 1, dans la scène de combat (voir
	# TowerManager.start_run). En cas de problème (étages absents, scène
	# introuvable), rien n'est démarré et la raison s'affiche sous les cartes.
	var error: String = TowerManager.start_run()
	if error != "":
		_notice = error
		_refresh()
		return
	_validate_button.disabled = true  # Un second clic relancerait le changement de scène.
