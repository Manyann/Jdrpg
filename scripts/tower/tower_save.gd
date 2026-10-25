extends RefCounted
class_name TowerSave

# ============================================================
# tower_save.gd — Lecture/écriture des sauvegardes de la Tour (fichiers JSON
# dans user://saves/). Aucune logique de jeu ici : le CONTENU d'une
# sauvegarde est produit et relu par TowerManager (to_save_dict /
# load_save_dict) ; ce fichier ne s'occupe que des emplacements et du disque.
#
# Emplacements : 0 = sauvegarde AUTOMATIQUE (écrite au début de chaque
# étage), 1..SLOT_COUNT = sauvegardes MANUELLES.
#
# Sécurité : l'écriture passe par un fichier temporaire, et l'ancienne
# version est gardée en « .bak » — si le fichier principal est illisible,
# on retombe sur la copie.
# ============================================================

const VERSION: int = 1
const SLOT_COUNT: int = 3
const AUTO_SLOT: int = 0
const SAVE_DIR: String = "user://saves/"

static func path_for(slot: int) -> String:
	if slot == AUTO_SLOT:
		return SAVE_DIR + "autosave.json"
	return SAVE_DIR + "slot_%d.json" % slot

static func slot_label(slot: int) -> String:
	return "Sauvegarde automatique" if slot == AUTO_SLOT else "Emplacement %d" % slot

static func exists(slot: int) -> bool:
	return FileAccess.file_exists(path_for(slot)) or FileAccess.file_exists(path_for(slot) + ".bak")

# Écrit `data` dans l'emplacement. Renvoie "" si tout va bien, sinon l'erreur.
static func write(slot: int, data: Dictionary) -> String:
	var dir_error: int = DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	if dir_error != OK:
		return "Impossible de créer le dossier de sauvegarde (erreur %d)." % dir_error
	var path: String = path_for(slot)
	var tmp_path: String = path + ".tmp"

	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		return "Impossible d'écrire la sauvegarde (erreur %d)." % FileAccess.get_open_error()
	file.store_string(JSON.stringify(data, "\t"))
	file.close()

	# L'ancienne version devient la copie de secours, puis le temporaire
	# prend sa place.
	if FileAccess.file_exists(path):
		DirAccess.copy_absolute(path, path + ".bak")
		DirAccess.remove_absolute(path)
	var rename_error: int = DirAccess.rename_absolute(tmp_path, path)
	if rename_error != OK:
		return "Impossible de finaliser la sauvegarde (erreur %d)." % rename_error
	return ""

# Lit un emplacement. Renvoie {"ok": bool, "data": Dictionary, "error": String}.
static func read(slot: int) -> Dictionary:
	var path: String = path_for(slot)
	for candidate in [path, path + ".bak"]:
		if not FileAccess.file_exists(candidate):
			continue
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(candidate))
		if parsed is Dictionary:
			var data: Dictionary = _normalize(parsed)
			if int(data.get("version", 0)) > VERSION:
				return {"ok": false, "data": {}, "error": "Sauvegarde faite avec une version plus récente du jeu."}
			return {"ok": true, "data": data, "error": ""}
	return {"ok": false, "data": {}, "error": "Sauvegarde introuvable ou illisible."}

# Résumé affichable d'un emplacement : {} s'il est vide ou illisible.
static func summary(slot: int) -> Dictionary:
	var result: Dictionary = read(slot)
	if not bool(result["ok"]):
		return {}
	return Dictionary(result["data"].get("summary", {}))

static func delete(slot: int) -> void:
	var path: String = path_for(slot)
	for candidate in [path, path + ".bak", path + ".tmp"]:
		if FileAccess.file_exists(candidate):
			DirAccess.remove_absolute(candidate)

# JSON ne connaît que les nombres décimaux : on remet en entiers ceux qui en
# sont (niveau, or, identifiants...) pour que le reste du jeu retrouve ses types.
static func _normalize(value):
	if value is Dictionary:
		var out: Dictionary = {}
		for key in value:
			out[key] = _normalize(value[key])
		return out
	if value is Array:
		var items: Array = []
		for item in value:
			items.append(_normalize(item))
		return items
	if value is float and absf(value) < 1.0e15 and is_equal_approx(value, roundf(value)):
		return int(value)
	return value
