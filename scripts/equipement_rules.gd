extends RefCounted
class_name EquipmentRules

# ============================================================
# equipment_rules.gd — Restrictions d'équipement des races et des métiers.
#
# Race.equipment_restrictions et Metier.equipment_restrictions sont du
# TEXTE LIBRE (ex: "Armure limite : Cuir travaillé", "Arbalètes") que ni
# la boutique ni l'équipement du jeu ne vérifiaient. Ce fichier les
# interprète : RULES associe CHAQUE texte présent dans les données à une
# règle précise, ou à "unsupported" / "ignored" avec la raison. Un texte
# absent de RULES n'est jamais ignoré en silence : find_unmapped() le
# signale (voir TowerManager.get_unmapped_equipment_restrictions).
#
# POUR CORRIGER UNE INTERPRÉTATION : changer UNE ligne de RULES (ou une
# des listes de catégories). Rien d'autre à modifier.
#
# Conventions d'interprétation (déduites des données, à valider) :
# - Les restrictions d'un personnage = celles de sa RACE + celles de son
#   métier LE PLUS AVANCÉ seulement. Une évolution REMPLACE les
#   restrictions de son parent : l'Inquisiteur répète celles du
#   Démonologue, alors que le Barde ne reprend pas celles de l'Artiste.
# - "Armes de jet" = tout ce qui se lance ou se tire : javelots, arcs,
#   arbalètes, armes à feu. C'est la seule lecture cohérente avec « Arme
#   de jet SAUF arme à feu » et « SAUF lance-pierre ».
# - "Armure limite : X" = le matériau le plus lourd permis, dans l'ordre
#   ARMOR_TIERS (déduit des prix et des PR du catalogue). "Plaque" est
#   pris comme TOUTE la plaque (renforcée et travaillée comprises), sinon
#   ces deux armures seraient inutilisables par n'importe quel métier.
# - "N PR Max" = total de PR (toutes les pièces d'armure, le bouclier et les
#   accessoires) au plus N.
# - Un personnage a 5 emplacements d'armure (casque, plastron, brassières,
#   jambières, bottes) ; le bouclier a le sien, à part, et ne compte pas
#   parmi les « pièces ». Les robes occupent le plastron, les chapeaux le
#   casque (voir get_armor_slot).
# - "Armure complète" = les 5 pièces portées en même temps : interdite,
#   donc 4 pièces au plus. "3 pièces maximum en armure" : idem avec 3.
# - "Casque obligatoire" = un VRAI casque (pas un chapeau) ; "Bouclier
#   obligatoire" = un bouclier. Une obligation impossible à satisfaire à
#   cause d'une interdiction (race qui interdit les boucliers) est levée :
#   l'interdiction l'emporte (voir TowerManager.get_missing_equipment).
# - Robes, chapeaux et boucliers ne sont pas dans l'échelle des matériaux :
#   les limites d'armure ne les concernent pas (le bouclier a son propre
#   interdit).
# ============================================================

## Matériaux d'armure, du plus léger au plus lourd (catégories du
## catalogue ; à l'intérieur d'un matériau : de base < renforcé < travaillé,
## d'après les prix et les PR).
const ARMOR_TIERS: Array = [
	"Cuir", "Cuir Renforcé", "Cuir Travaillé",
	"Mailles", "Mailles renforcées", "Mailles Travaillées",
	"Plaque", "Plaque Renforcée", "Plaque Travaillée",
]

## Les 5 emplacements d'armure d'un personnage, et celui du bouclier (à part).
const ARMOR_SLOTS: Array = ["head", "chest", "arms", "legs", "feet"]
const SHIELD_SLOT: String = "shield"
const SLOT_LABELS: Dictionary = {
	"head": "Casque", "chest": "Plastron", "arms": "Brassières",
	"legs": "Jambières", "feet": "Bottes", "shield": "Bouclier",
}

## Début du nom d'une pièce de matériau -> son emplacement (chaque matériau
## du catalogue a exactement une pièce par emplacement).
const PIECE_PREFIXES: Array = [
	["Casque", "head"], ["Brassards", "arms"], ["Jambières", "legs"],
	["Plastron", "chest"], ["Bottes", "feet"],
]

## Types de règle :
##   ban_weapon_categories : armes de ces catégories interdites
##   ban_weapon_type       : armes de ce weapon_type interdites ("ranged")
##   weapon_only           : SEULES ces catégories d'armes sont permises
##   ban_armor_categories  : armures de ces catégories interdites
##   ban_armor_name_prefix : armures dont le nom commence ainsi interdites
##   armor_tier_max        : armures plus lourdes que ce matériau interdites
##   armor_pr_max          : PR total (armure + bouclier + accessoires) plafonné
##   armor_max_pieces      : au plus N des 5 pièces d'armure (bouclier exclu)
##   require_armor_piece   : cette pièce est OBLIGATOIRE (slot, name_prefix)
##   unsupported           : NON appliqué (voir "note")
##   ignored               : ne concerne pas l'équipement
const RULES: Dictionary = {
	# ----- Races : armes -----
	"Arbalètes": {"type": "ban_weapon_categories", "categories": ["Arbalètes"]},
	"Arcs et Arbalètes": {"type": "ban_weapon_categories", "categories": ["Arcs", "Arbalètes"]},
	"Armes à 2 mains": {"type": "ban_weapon_categories", "categories": ["Haches à 2 mains", "Marteaux à 2 mains"]},
	"Armes à 2 mains non naine": {"type": "unsupported", "note": "Aucune arme « naine » dans le catalogue, et les seules armes à 2 mains (haches, marteaux) sont justement celles des nains : sans effet."},
	"Masses": {"type": "ban_weapon_categories", "categories": ["Masses"]},
	"Pas d'armes de jet": {"type": "ban_weapon_categories", "categories": ["Javelots", "Arcs", "Arbalètes", "Armes à feu"]},
	"Armes de jet": {"type": "ban_weapon_categories", "categories": ["Javelots", "Arcs", "Arbalètes", "Armes à feu"]},
	"Armes de jet étrangère": {"type": "unsupported", "note": "Suppose de connaître l'origine de chaque arme : absente du catalogue."},
	"Arme de jet sauf arme à feu": {"type": "ban_weapon_categories", "categories": ["Javelots", "Arcs", "Arbalètes"]},
	"Arme de jet sauf lance pierre": {"type": "ban_weapon_categories", "categories": ["Javelots", "Arcs", "Arbalètes", "Armes à feu"]},
	"Armes à distance": {"type": "ban_weapon_type", "weapon_type": "ranged"},
	"Armes à feu": {"type": "ban_weapon_categories", "categories": ["Armes à feu"]},
	"Peut utiliser que les lances / javelots": {"type": "weapon_only", "categories": ["Lances", "Javelots"]},

	# ----- Races : armures -----
	"Armure complete": {"type": "armor_max_pieces", "value": 4},
	"Armure complète": {"type": "armor_max_pieces", "value": 4},
	"Bouclier": {"type": "ban_armor_categories", "categories": ["Bouclier"]},

	# ----- Métiers : armes -----
	"Epee, hache, lance, masse, javelot": {"type": "ban_weapon_categories", "categories": ["Epées 1 main", "Haches 1 main", "Haches à 2 mains", "Lances", "Masses", "Javelots"]},
	"Arcs, arbalètes, armes à feu": {"type": "ban_weapon_categories", "categories": ["Arcs", "Arbalètes", "Armes à feu"]},

	# ----- Métiers : limites d'armure -----
	"Armure limite : Cuir": {"type": "armor_tier_max", "tier": "Cuir"},
	"Armure limite : Cuir renforcé": {"type": "armor_tier_max", "tier": "Cuir Renforcé"},
	"Armure limite : Cuir travaillé": {"type": "armor_tier_max", "tier": "Cuir Travaillé"},
	"Armure limite : Maille": {"type": "armor_tier_max", "tier": "Mailles"},
	"Armure limite : Maille renforcée": {"type": "armor_tier_max", "tier": "Mailles renforcées"},
	"Armure limite : Maille travaillée": {"type": "armor_tier_max", "tier": "Mailles Travaillées"},
	"Armure limite : Plaque": {"type": "armor_tier_max", "tier": "Plaque Travaillée"},

	# ----- Métiers : plafonds de PR -----
	"2PR Max": {"type": "armor_pr_max", "value": 2},
	"3PR Max": {"type": "armor_pr_max", "value": 3},
	"4PR Max": {"type": "armor_pr_max", "value": 4},

	# ----- Métiers : pièces d'armure -----
	"Pas de casque": {"type": "ban_armor_name_prefix", "prefix": "Casque"},
	"Pas de bouclier": {"type": "ban_armor_categories", "categories": ["Bouclier"]},
	"3 pièces maximum en armure": {"type": "armor_max_pieces", "value": 3},
	"Casque obligatoire": {"type": "require_armor_piece", "slot": "head", "name_prefix": "Casque", "label": "Casque"},
	"Bouclier obligatoire": {"type": "require_armor_piece", "slot": "shield", "label": "Bouclier"},

	# ----- Autres -----
	"Le forgeur de runes ne peut apposer une rune plus d'une fois sur un joueur ou une arme/armure.": {"type": "ignored", "note": "Règle de runes, pas d'équipement."},
}

# ---------- Normalisation ----------

# Minuscules, sans accents, apostrophes droites : « Epée » et « épée »,
# « d’une » et « d'une » sont la même chose.
static func norm(text: String) -> String:
	var result := text.strip_edges().to_lower().replace("’", "'")
	for pair in [["é", "e"], ["è", "e"], ["ê", "e"], ["ë", "e"], ["à", "a"], ["â", "a"], ["ä", "a"],
			["î", "i"], ["ï", "i"], ["ô", "o"], ["ö", "o"], ["ù", "u"], ["û", "u"], ["ü", "u"],
			["ç", "c"], ["œ", "oe"]]:
		result = result.replace(pair[0], pair[1])
	return result

# ---------- Consultation ----------

# Règle associée à ce texte de restriction, ou {} s'il n'est pas dans RULES.
static func get_rule(text: String) -> Dictionary:
	if RULES.has(text):
		return RULES[text]  # Chemin rapide : le texte est exactement une clé (cas normal, appelé des milliers de fois par la boutique).
	var wanted := norm(text)
	for key in RULES:
		if norm(str(key)) == wanted:
			return RULES[key]
	return {}

# Textes de restriction qui n'ont AUCUNE règle (ni appliquée, ni marquée
# « non appliquée ») : à compléter dans RULES.
static func find_unmapped(texts: Array) -> Array:
	var result: Array = []
	for text in texts:
		if get_rule(str(text)).is_empty() and not result.has(str(text)):
			result.append(str(text))
	return result

# Emplacement où se porte cette armure : "head", "chest", "arms", "legs",
# "feet" ou "shield" ; "" si elle n'en a aucun (ne devrait pas arriver).
# Les robes vont au plastron, les chapeaux au casque.
static func get_armor_slot(data: Dictionary) -> String:
	var category := norm(str(data.get("category", "")))
	if category == "bouclier":
		return SHIELD_SLOT
	if category == "robes":
		return "chest"
	if category == "chapeau":
		return "head"
	var item_name := str(data.get("name", ""))
	for pair in PIECE_PREFIXES:
		if item_name.begins_with(str(pair[0])):
			return str(pair[1])
	return ""

# Nombre maximum de pièces d'armure (sur 5) imposé par ces restrictions
# (le plus strict), -1 s'il n'y en a pas.
static func get_max_pieces(entries: Array) -> int:
	var cap := -1
	for entry in entries:
		var rule := get_rule(str(entry["text"]))
		if str(rule.get("type", "")) == "armor_max_pieces":
			var value := int(rule["value"])
			cap = value if cap < 0 else mini(cap, value)
	return cap

# Pièces OBLIGATOIRES que `armor_data` (emplacement -> entrée de catalogue)
# ne contient pas : [{"slot", "name_prefix", "label", "source"}].
static func get_unmet_requirements(entries: Array, armor_data: Dictionary) -> Array:
	var unmet: Array = []
	for entry in entries:
		var rule := get_rule(str(entry["text"]))
		if str(rule.get("type", "")) != "require_armor_piece":
			continue
		var prefix := str(rule.get("name_prefix", ""))
		var piece: Dictionary = armor_data.get(str(rule["slot"]), {})
		var satisfied := not piece.is_empty() and (prefix == "" or str(piece.get("name", "")).begins_with(prefix))
		if not satisfied:
			unmet.append({"slot": str(rule["slot"]), "name_prefix": prefix, "label": str(rule["label"]), "source": str(entry["source"])})
	return unmet

# Plafond de PR total imposé par ces restrictions (le plus strict), -1 s'il n'y en a pas.
static func get_pr_cap(entries: Array) -> int:
	var cap := -1
	for entry in entries:
		var rule := get_rule(str(entry["text"]))
		if str(rule.get("type", "")) == "armor_pr_max":
			var value := int(rule["value"])
			cap = value if cap < 0 else mini(cap, value)
	return cap

static func _has_category(categories: Array, category: String) -> bool:
	var wanted := norm(category)
	for candidate in categories:
		if norm(str(candidate)) == wanted:
			return true
	return false

# Rang du matériau dans ARMOR_TIERS, -1 si cette catégorie n'en fait pas
# partie (robes, chapeaux, boucliers).
static func _tier_index(category: String) -> int:
	var wanted := norm(category)
	for i in range(ARMOR_TIERS.size()):
		if norm(str(ARMOR_TIERS[i])) == wanted:
			return i
	return -1

# ---------- Évaluation ----------

# Pourquoi cet objet est INTERDIT ("" = permis).
#   kind     : "weapons", "armors" ou "accessories"
#   data     : l'entrée du catalogue (name, category, weapon_type, bonus_armure...)
#   entries  : [{"text": restriction, "source": "Barbare" ou nom du métier}]
#   context  : ce que porte déjà le RESTE de l'équipement (sans l'objet
#              qu'on remplacerait) : "other_pr" (PR total) et "other_pieces"
#              (pièces d'armure sur 5), pour les plafonds
# La raison est de la forme « Barbare : Arbalètes ».
static func get_block_reason(kind: String, data: Dictionary, entries: Array, context: Dictionary = {}) -> String:
	var category := str(data.get("category", ""))
	var item_name := str(data.get("name", ""))
	var other_pr := int(context.get("other_pr", 0))
	var other_pieces := int(context.get("other_pieces", 0))
	var slot := get_armor_slot(data) if kind == "armors" else ""
	if kind == "armors" and slot == "":
		return "Emplacement d'armure inconnu"

	# Une source qui impose « seulement telles armes » : tout le reste est
	# interdit, et ses autres interdits d'armes ne s'appliquent plus aux armes
	# qu'elle autorise (la Walkyrie peut utiliser javelots malgré « armes de jet »).
	var allowed_by_source: Dictionary = {}
	if kind == "weapons":
		for entry in entries:
			var rule := get_rule(str(entry["text"]))
			if str(rule.get("type", "")) == "weapon_only":
				if _has_category(rule["categories"], category):
					allowed_by_source[str(entry["source"])] = true
				else:
					return "%s : %s" % [entry["source"], entry["text"]]

	for entry in entries:
		var rule := get_rule(str(entry["text"]))
		var reason := "%s : %s" % [entry["source"], entry["text"]]
		match str(rule.get("type", "")):
			"ban_weapon_categories":
				if kind == "weapons" and not allowed_by_source.has(str(entry["source"])) and _has_category(rule["categories"], category):
					return reason
			"ban_weapon_type":
				if kind == "weapons" and not allowed_by_source.has(str(entry["source"])) and str(data.get("weapon_type", "melee")) == str(rule["weapon_type"]):
					return reason
			"ban_armor_categories":
				if kind == "armors" and _has_category(rule["categories"], category):
					return reason
			"ban_armor_name_prefix":
				if kind == "armors" and item_name.begins_with(str(rule["prefix"])):
					return reason
			"armor_tier_max":
				if kind == "armors":
					var item_tier := _tier_index(category)
					var max_tier := _tier_index(str(rule["tier"]))
					if item_tier >= 0 and max_tier >= 0 and item_tier > max_tier:
						return reason
			"armor_pr_max":
				if kind == "armors" or kind == "accessories":
					var item_pr := int(data.get("bonus_armure", 0))
					if item_pr > 0 and item_pr + other_pr > int(rule["value"]):
						return reason
			"armor_max_pieces":
				if kind == "armors" and ARMOR_SLOTS.has(slot) and other_pieces + 1 > int(rule["value"]):
					return reason
	return ""
