extends Resource
class_name Skill

# ============================================================
# skill.gd
# Compétence innée (héritée d'une race — voir Race.inherited_skill_codes)
# ou spéciale. La plupart sont "Hors combat" (aucun système de test
# d'exploration chez nous pour l'instant) ou dépendent de mécaniques
# qu'on n'a pas encore (loot, pièges, rations, ciblage IA) — stockées
# ici à titre indicatif, sans effet mécanique. Les quelques
# compétences avec un effet de combat direct sont appliquées à la
# main dans CombatUnit._recalculate_stats() (voir la liste en tête de
# skill_database.gd), pas génériquement comme les bonus_* de
# Weapon/Armor/Race/StatusEffect — trop peu nombreuses et trop
# différentes les unes des autres pour un système générique.
# ============================================================

@export var code: String = ""
@export var skill_name: String = ""
@export var description: String = ""

## "actif" ou "passif" — un actif nécessiterait normalement un
## déclenchement du joueur (bouton, comme un sort) ; pour l'instant,
## aucune compétence active n'a de mécanique de combat automatisée
## (voir Détecter/DET), donc cette distinction n'a pas encore d'effet
## dans le code — gardée pour cohérence avec les données d'origine et
## un futur système d'activation si besoin.
@export var skill_type: String = "passif"

# Infobulle : nom, type, description d'origine et effet réel en combat.
func get_tooltip_text() -> String:
	var lines: Array = ["%s (%s)" % [skill_name, skill_type], description]
	var effect: String = SkillDatabase.combat_effect(code)
	lines.append("")
	lines.append("En combat : " + effect)
	return "\n".join(lines)

func get_display_text() -> String:
	return "%s (%s) : %s" % [skill_name, skill_type, description]
