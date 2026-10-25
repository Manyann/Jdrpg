class_name TrapDef
extends Resource

# Définition d'un type de piège (voir TrapDatabase). Les pièges POSÉS en combat
# sont des Dictionary gérés par HexGrid (_traps) qui pointent vers une TrapDef.

enum Trigger { STEP, PROXIMITY_LINE }       # Marcher dessus / s'approcher en ligne droite.
enum ReleaseTest { NONE, FORCE, ADRESSE, INTELLIGENCE, COURAGE, CHANCE, CHARISME }
enum Affects { ENEMY, GROUP, ALL, ZONE }    # ENEMY/GROUP/ALL : qui déclenche (et subit). ZONE : déclenché par un ennemi du poseur, touche TOUS les personnages à 1 hexagone du piège.

@export var trap_id: String = ""
@export var trap_name: String = "Piège"
@export var description: String = ""

## Dégâts (bruts) : dés de 6 + modificateur. 0 dé et 0 modificateur = aucun dégât (null).
@export var damage_dice: int = 0
@export var damage_modifier: int = 0

## Effet à durée posé sur la victime (entrave, drain, buff...), null = aucun.
## Sa durée est `duration` ; l'effet s'arrête immédiatement si le piège est désamorcé.
var effect: StatusEffect = null
@export var duration: int = 0

@export var trigger: Trigger = Trigger.STEP
@export var trigger_range: int = 3          # PROXIMITY_LINE : distance max (cases) en ligne droite.

## Libération anticipée : à chaque début de tour de la victime, test sur cette stat
## (réussi si d20 < stat, comme les autres tests) ; NONE = aucune libération anticipée.
@export var release_test: ReleaseTest = ReleaseTest.NONE

@export var affects: Affects = Affects.ENEMY

## Zone persistante (ex: incendiaire) : après déclenchement, la zone reste `duration` tours
## et blesse (mêmes dés) ceux qui y commencent leur tour. Désamorçable.
@export var persistent_zone: bool = false

@export var charges: int = 2                # Nombre de pièges de ce type posables par combat.
@export var place_min_range: int = 1
@export var place_max_range: int = 3

func has_damage() -> bool:
	return damage_dice > 0 or damage_modifier != 0

func release_stat_name() -> String:
	match release_test:
		ReleaseTest.FORCE: return "Force"
		ReleaseTest.ADRESSE: return "Adresse"
		ReleaseTest.INTELLIGENCE: return "Intelligence"
		ReleaseTest.COURAGE: return "Courage"
		ReleaseTest.CHANCE: return "Chance"
		ReleaseTest.CHARISME: return "Charisme"
	return ""

func get_summary() -> String:
	var lines: Array = []
	if description != "":
		lines.append(description)
	if has_damage():
		lines.append("Dégâts bruts : %dD6%s" % [damage_dice, ("%+d" % damage_modifier) if damage_modifier != 0 else ""])
	if effect != null:
		lines.append("Effet : %s (%d tours)" % [effect.effect_name, duration])
	match trigger:
		Trigger.STEP:
			lines.append("Déclenchement : marcher dessus")
		Trigger.PROXIMITY_LINE:
			lines.append("Déclenchement : approche à %d cases en ligne droite" % trigger_range)
	if release_test != ReleaseTest.NONE:
		lines.append("Libération : test de %s à chaque tour" % release_stat_name())
	match affects:
		Affects.ENEMY: lines.append("Cible : les ennemis (invisible pour eux)")
		Affects.GROUP: lines.append("Cible : le groupe du poseur")
		Affects.ALL: lines.append("Cible : tout le monde")
		Affects.ZONE: lines.append("Cible : tous les personnages à 1 hexagone (déclenché par un ennemi)")
	if persistent_zone:
		lines.append("La zone reste %d tours" % duration)
	lines.append("Portée de pose : %d à %d — %d par combat" % [place_min_range, place_max_range, charges])
	return "\n".join(lines)

const ICON_FOLDER: String = "res://assets/spell_icons/pieges/"
const TOKEN_FOLDER: String = "res://assets/traps/"

func get_icon_path() -> String:
	return ICON_FOLDER + trap_id + ".png"

func get_token_path() -> String:
	return TOKEN_FOLDER + trap_id + ".png"
