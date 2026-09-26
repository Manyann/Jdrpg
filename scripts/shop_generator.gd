extends RefCounted
class_name ShopGenerator

# ============================================================
# shop_generator.gd
# Tire le stock d'une boutique selon le type de ville, et construit
# les vraies Resources (Weapon/Armor/Accessory/Potion/Arrow) à partir
# des données brutes des catalogues (voir weapon_catalog.gd etc.).
#
# RÈGLE DE TIRAGE : chaque objet d'un catalogue a une chance de base
# ("base_percentage") d'être en stock. Cette chance est réduite par le
# "handicap" du type de ville (plus la ville est petite, plus le
# handicap est élevé) : chance réelle = base_percentage - handicap.
# Tiré UNE fois par appel de roll_stock() (pas re-tiré à chaque visite
# — appelle roll_stock() à nouveau si tu veux un renouvellement de stock).
# ============================================================

const SETTLEMENT_TYPES: Dictionary = {
	"capitale":   {"label": "Capitale",                          "handicap": 0},
	"ville-grande": {"label": "Grande ville",                     "handicap": 8},
	"campement":  {"label": "Campement militaire, fort",          "handicap": 8},
	"ville-moyenne": {"label": "Moyenne ville",                   "handicap": 15},
	"ville-petite": {"label": "Petite ville",                     "handicap": 22},
	"bourgade":   {"label": "Bourgades, villages, hameaux",       "handicap": 27},
}

static func get_handicap(settlement_type: String) -> int:
	return SETTLEMENT_TYPES.get(settlement_type, {}).get("handicap", 0)

# Tire quels objets d'un catalogue (Array de Dictionary bruts, voir
# weapon_catalog.gd etc.) sont effectivement en stock pour ce type de
# ville. Renvoie les dictionnaires bruts (pas encore convertis en
# Resource) — utilise build_weapon_from_data() etc. ensuite pour les
# objets réellement achetés.
static func roll_stock(catalog: Array, settlement_type: String) -> Array:
	var handicap = get_handicap(settlement_type)
	var stock: Array = []

	for item_data in catalog:
		var chance = item_data.get("base_percentage", 0) - handicap
		if randf() * 100.0 < chance:
			stock.append(item_data)

	return stock

# ---------- Construction des Resources à partir des données brutes ----------

static func build_weapon_from_data(data: Dictionary) -> Weapon:
	var w := Weapon.new()
	w.weapon_name = data.get("name", "Arme")
	w.damage = data.get("damage", 0)
	w.weapon_type = Weapon.WeaponType.RANGED if data.get("weapon_type", "melee") == "ranged" else Weapon.WeaponType.MELEE
	w.price = data.get("price", 0)
	w.info_text = data.get("info", "")
	_apply_bonus_fields(w, data)

	# Portée par défaut selon le type — le catalogue n'a pas de portée
	# précise par arme, on approxime selon mêlée/distance.
	if w.weapon_type == Weapon.WeaponType.RANGED:
		w.min_range = 2
		w.max_range = 6
	else:
		w.min_range = 1
		w.max_range = 1

	return w

static func build_armor_from_data(data: Dictionary) -> Armor:
	var a := Armor.new()
	a.armor_name = data.get("name", "Armure")
	a.category = data.get("category", "")
	a.price = data.get("price", 0)
	a.info_text = data.get("info", "")
	_apply_bonus_fields(a, data)
	return a

static func build_accessory_from_data(data: Dictionary) -> Accessory:
	var a := Accessory.new()
	a.accessory_name = data.get("name", "Accessoire")
	a.category = data.get("category", "")
	a.price = data.get("price", 0)
	a.info_text = data.get("info", "")
	_apply_bonus_fields(a, data)
	return a

# Renvoie null si la potion n'est pas "functional" (potions à buff
# temporaire, pas encore supportées — voir potion_catalog.gd).
static func build_potion_from_data(data: Dictionary) -> Potion:
	if not data.get("functional", false):
		return null

	var p := Potion.new()
	p.potion_name = data.get("name", "Potion")
	p.price = data.get("price", 0)

	if data.has("heal_amount"):
		p.potion_type = Potion.PotionType.HEAL
		p.amount = data.get("heal_amount", 0)
	elif data.has("mana_amount"):
		p.potion_type = Potion.PotionType.MANA
		p.amount = data.get("mana_amount", 0)

	return p

static func build_arrow_from_data(data: Dictionary) -> Arrow:
	var a := Arrow.new()
	a.arrow_name = data.get("name", "Flèche")
	a.damage_bonus = data.get("damage_bonus", 0)
	a.price = data.get("price", 0)
	a.quantity = 5  # Vendues par lot de 5 (voir informations du catalogue d'origine).
	return a

# Applique les champs bonus_* communs (Weapon/Armor/Accessory ont tous
# les mêmes noms de champs, donc une boucle générique suffit).
static func _apply_bonus_fields(item: Object, data: Dictionary) -> void:
	for field in [
		"bonus_courage", "bonus_intelligence", "bonus_charisme", "bonus_adresse",
		"bonus_force", "bonus_chance", "bonus_attaque", "bonus_parade",
		"bonus_armure", "bonus_vie", "bonus_mana",
	]:
		if data.has(field):
			item.set(field, data[field])
