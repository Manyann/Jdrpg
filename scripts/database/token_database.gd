# Tokens (médaillons) affichés à la place des sprites, en attendant le design
# final. Les images sont dans res://assets/tokens/<nom>.png (voir tokens.zip).
# Désactiver tout d'un coup : ENABLED = false (retour aux sprites/disques).
class_name TokenDatabase

const ENABLED := true
const FOLDERS := [
	"res://assets/tokens/",
	"res://assets/tokens/tokens/",
	"res://tokens/",
	"res://assets/token/",
]

# Noms d'unités (ennemis, invocations…) sans token propre → token existant.
const ALIASES := {
	"Elfe": "elfe_sylvain",
	"Mage": "haut_elfe",
	"Archer gobelin": "gobelin",
	"Coyote affamé": "coyote",
	"Prêtre de la nuit": "guerrier_maudit",
	"Ver des sables géant": "mille_pattes",
	"Orc": "orque",
	"Orc chef": "orque",
	"Chaman orc": "orque",
	"Méca Doc": "meca_healer",
	"Méca Tanker": "meca_tanker",
	"Méca Combat": "meca_dps_epee",
	"Méca Support": "meca_buffer",
}


static func slug(text: String) -> String:
	var s := text.to_lower()
	for pair in [["é","e"],["è","e"],["ê","e"],["ë","e"],["à","a"],["â","a"],["î","i"],["ï","i"],["ô","o"],["ù","u"],["û","u"],["ç","c"]]:
		s = s.replace(pair[0], pair[1])
	var out := ""
	for ch in s:
		out += ch if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") else "_"
	while out.contains("__"):
		out = out.replace("__", "_")
	return out.strip_edges().trim_prefix("_").trim_suffix("_")

static func _load(key: String) -> Texture2D:
	# Cache dans les métadonnées du moteur (pas de « static var » : compatible
	# avec toutes les versions de Godot 4).
	var cache: Dictionary = {}
	if Engine.has_meta("token_cache"):
		cache = Engine.get_meta("token_cache")
	else:
		Engine.set_meta("token_cache", cache)
	if cache.has(key):
		return cache[key]
	var tex: Texture2D = null
	for folder in FOLDERS:
		var path: String = folder + key + ".png"
		if ResourceLoader.exists(path):
			tex = load(path)
			break
	if tex == null:
		push_warning("TokenDatabase : token introuvable '%s.png' (dossier attendu : %s)." % [key, FOLDERS[0]])
	cache[key] = tex
	return tex

## (Équipe 0 = joueur : on évite de nommer CombatUnit ici, dépendance circulaire avec unit.gd.)
## Token d'une unité : la RACE pour un aventurier joueur, sinon son nom
## (ennemi, méca…). null si aucun token → rendu habituel.
static func texture_for(unit) -> Texture2D:
	if not ENABLED:
		return null
	if int(unit.team) == 0 and unit.equipped_race != null:
		var by_race := _load(slug(unit.equipped_race.race_name))
		if by_race != null:
			return by_race
	var uname: String = unit.unit_name
	# Les doublons sont numérotés au placement (« Gobelin 2 ») : on retire le numéro.
	var tail := uname.rfind(" ")
	if tail > 0 and uname.substr(tail + 1).is_valid_int():
		uname = uname.substr(0, tail)
	if ALIASES.has(uname):
		return _load(ALIASES[uname])
	return _load(slug(uname))
