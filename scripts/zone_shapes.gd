extends RefCounted
class_name ZoneShapes

# ============================================================
# zone_shapes.gd
# Formes des sorts de Zone (Spell.zone_offsets), dessinées d'après les
# schémas fournis (extraits image par image). Chaque forme est une liste
# de décalages axiaux (dq, dr) relatifs à la case d'ANCRE — la case
# foncée du schéma, toujours incluse dans la zone (elle n'est donc pas
# répétée dans les listes). Ils décrivent l'orientation "de base", celle
# du schéma : HexGrid les tourne ensuite par pas de 60° (voir
# rotate_offset), automatiquement puis à la main (molette ou Q/E).
#
# Dans les schémas ci-dessous : A = ancre, o = case de la zone. Chaque
# rangée est une rangée de la grille (r), décalée d'une demi-case d'une
# rangée à l'autre comme sur la vraie grille.
#
# Écran de poussière et Particule de poussière ont reçu la MÊME image
# (fichiers identiques) : leurs deux formes sont donc identiques pour
# l'instant — elles ont chacune leur constante pour pouvoir diverger.
# ============================================================

# Mêmes directions et même ordre que HexGrid.DIRECTIONS :
# 0=Est, 1=Nord-Est, 2=Nord-Ouest, 3=Ouest, 4=Sud-Ouest, 5=Sud-Est
# (indice +1 = rotation de 60° dans le sens trigonométrique).
const DIRS := [
	Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
	Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1),
]

# Tourne un décalage de `steps` crans de 60° (sens trigonométrique si
# steps > 0, horaire si < 0) autour de l'ancre.
static func rotate_offset(offset: Vector2i, steps: int) -> Vector2i:
	var result = offset
	for i in range(posmod(steps, 6)):
		result = Vector2i(result.x + result.y, -result.x)
	return result

static func _to_xy(v: Vector2i) -> Vector2:
	return Vector2(v.x + v.y * 0.5, v.y * 0.8660254)

# Direction (indice dans DIRS) vers laquelle la forme "pointe" depuis
# son ancre, d'après le centre de gravité de ses cases. -1 pour une forme
# (quasi) symétrique autour de l'ancre, qui n'a pas d'orientation
# privilégiée. Sert à orienter automatiquement la forme à l'opposé du
# lanceur (voir HexGrid._get_zone_orientation_steps).
static func principal_direction(offsets: Array) -> int:
	if offsets.is_empty():
		return -1
	var sum = Vector2.ZERO
	for o in offsets:
		sum += _to_xy(o)
	var centroid = sum / float(offsets.size())
	if centroid.length() < 0.6:
		return -1
	var best_index = 0
	var best_dot = -INF
	for i in range(DIRS.size()):
		var d = _to_xy(DIRS[i]).normalized().dot(centroid.normalized())
		if d > best_dot + 0.0001:
			best_dot = d
			best_index = i
	return best_index


# Cone de feu — 10 cases (ancre comprise)
#     o o
#    o o
#   A o
#    o o
#     o o
const CONE_DE_FEU := [
	Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2), Vector2i(2, -2), Vector2i(2, -1), Vector2i(3, -2),
]

# Ras de marée — 18 cases (ancre comprise)
#   o o o o
#    o o o
#   A o o o
#    o o o
#   o o o o
const RAS_DE_MAREE := [
	Vector2i(-1, 2), Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, -2), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2), Vector2i(2, -2), Vector2i(2, -1), Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 2), Vector2i(3, -2), Vector2i(3, -1), Vector2i(3, 0), Vector2i(4, -2),
]

# Pluie de pierres — 9 cases (ancre comprise)
#    o   o
#   o o o o
#    o A o
const PLUIE_DE_PIERRES := [
	Vector2i(-1, -1), Vector2i(-1, 0), Vector2i(0, -2), Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(2, -2), Vector2i(2, -1),
]

# Nuage de vapeur — 8 cases (ancre comprise)
#      o o
#   A o o o
#      o o
const NUAGE_DE_VAPEUR := [
	Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, -1), Vector2i(2, 0), Vector2i(2, 1), Vector2i(3, -1), Vector2i(3, 0),
]

# Météore — 19 cases (ancre comprise)
#     o o o
#    o o o o
#   o o A o o
#    o o o o
#     o o o
const METEORE := [
	Vector2i(-2, 0), Vector2i(-2, 1), Vector2i(-2, 2), Vector2i(-1, -1), Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(-1, 2), Vector2i(0, -2), Vector2i(0, -1), Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, -2), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, -2), Vector2i(2, -1), Vector2i(2, 0),
]

# Royaume des enfers — 37 cases (ancre comprise)
#      o o o o
#     o o o o o
#    o o o o o o
#   o o o A o o o
#    o o o o o o
#     o o o o o
#      o o o o
const ROYAUME_DES_ENFERS := [
	Vector2i(-3, 0), Vector2i(-3, 1), Vector2i(-3, 2), Vector2i(-3, 3), Vector2i(-2, -1), Vector2i(-2, 0), Vector2i(-2, 1), Vector2i(-2, 2), Vector2i(-2, 3), Vector2i(-1, -2), Vector2i(-1, -1), Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(-1, 2), Vector2i(-1, 3), Vector2i(0, -3), Vector2i(0, -2), Vector2i(0, -1), Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3), Vector2i(1, -3), Vector2i(1, -2), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2), Vector2i(2, -3), Vector2i(2, -2), Vector2i(2, -1), Vector2i(2, 0), Vector2i(2, 1), Vector2i(3, -3), Vector2i(3, -2), Vector2i(3, -1), Vector2i(3, 0),
]

# Nuée ardente — 15 cases (ancre comprise)
#     o o o
#    o o o
#   A o o
#    o o o
#     o o o
const NUEE_ARDENTE := [
	Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2), Vector2i(2, -2), Vector2i(2, -1), Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 2), Vector2i(3, -2), Vector2i(3, -1), Vector2i(4, -2),
]

# Pluie pyroclastique — 5 cases (ancre comprise)
#   o     o
#      A
#   o     o
const PLUIE_PYROCLASTIQUE := [
	Vector2i(-2, 1), Vector2i(-1, -1), Vector2i(1, 1), Vector2i(2, -1),
]

# Eclair en chaine — 7 cases (ancre comprise)
#    o o   o o
#   A   o o
const ECLAIR_EN_CHAINE := [
	Vector2i(1, -1), Vector2i(2, -1), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, -1), Vector2i(5, -1),
]

# Ecran de poussiere — 10 cases (ancre comprise)
#     o o
#    o o
#   A o
#    o o
#     o o
const ECRAN_DE_POUSSIERE := [
	Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2), Vector2i(2, -2), Vector2i(2, -1), Vector2i(3, -2),
]

# Particule de poussiere — 10 cases (ancre comprise)
#     o o
#    o o
#   A o
#    o o
#     o o
const PARTICULE_DE_POUSSIERE := [
	Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2), Vector2i(2, -2), Vector2i(2, -1), Vector2i(3, -2),
]

# Nuage de poussiere — 18 cases (ancre comprise)
#   o o o o
#    o o o
#   A o o o
#    o o o
#   o o o o
const NUAGE_DE_POUSSIERE := [
	Vector2i(-1, 2), Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, -2), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2), Vector2i(2, -2), Vector2i(2, -1), Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 2), Vector2i(3, -2), Vector2i(3, -1), Vector2i(3, 0), Vector2i(4, -2),
]

# Volée de glace — 12 cases (ancre comprise)
#   o o o o
#
#   A o o o
#
#   o o o o
const VOLEE_DE_GLACE := [
	Vector2i(-1, 2), Vector2i(0, 2), Vector2i(1, -2), Vector2i(1, 0), Vector2i(1, 2), Vector2i(2, -2), Vector2i(2, 0), Vector2i(2, 2), Vector2i(3, -2), Vector2i(3, 0), Vector2i(4, -2),
]

# Ere glaciaire — 37 cases (ancre comprise)
#      o o o o
#     o o o o o
#    o o o o o o
#   o o o A o o o
#    o o o o o o
#     o o o o o
#      o o o o
const ERE_GLACIAIRE := [
	Vector2i(-3, 0), Vector2i(-3, 1), Vector2i(-3, 2), Vector2i(-3, 3), Vector2i(-2, -1), Vector2i(-2, 0), Vector2i(-2, 1), Vector2i(-2, 2), Vector2i(-2, 3), Vector2i(-1, -2), Vector2i(-1, -1), Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(-1, 2), Vector2i(-1, 3), Vector2i(0, -3), Vector2i(0, -2), Vector2i(0, -1), Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3), Vector2i(1, -3), Vector2i(1, -2), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2), Vector2i(2, -3), Vector2i(2, -2), Vector2i(2, -1), Vector2i(2, 0), Vector2i(2, 1), Vector2i(3, -3), Vector2i(3, -2), Vector2i(3, -1), Vector2i(3, 0),
]

# Fracture sysmique — 20 cases (ancre comprise)
#   o   o   o   o
#    o   o   o   o
#   A   o   o   o
#    o   o   o   o
#   o   o   o   o
const FRACTURE_SYSMIQUE := [
	Vector2i(-1, 2), Vector2i(0, 1), Vector2i(1, -2), Vector2i(1, -1), Vector2i(1, 2), Vector2i(2, 0), Vector2i(2, 1), Vector2i(3, -2), Vector2i(3, -1), Vector2i(3, 2), Vector2i(4, 0), Vector2i(4, 1), Vector2i(5, -2), Vector2i(5, -1), Vector2i(5, 2), Vector2i(6, 0), Vector2i(6, 1), Vector2i(7, -2), Vector2i(7, -1),
]
