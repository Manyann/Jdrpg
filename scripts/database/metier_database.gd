extends RefCounted
class_name MetierDatabase

# ============================================================
# metier_database.gd — GÉNÉRÉ à partir des 47 métiers d'origine.
#
# Le métier s'applique EN PLUS de la race (voir metier.gd) — mêmes
# champs bonus_* que Weapon/Armor/Accessory/Race/StatusEffect, sommés
# de la même façon dans CombatUnit._recalculate_stats(). Les codes de
# compétences (inherited_skill_codes) utilisent le MÊME catalogue que
# pour les races (voir SkillDatabase) — CombatUnit.has_skill()
# vérifie la race ET le métier équipés.
#
# Prérequis : PAS appliqués (pas d'écran de création de personnage
# chez nous) — conservés dans Metier.prereqs à titre indicatif.
#
# Arborescence (parent_codes) : conservée à titre indicatif, PAS
# appliquée (un métier se choisit librement chez nous, sans suivre
# la chaîne de parenté d'origine).
#
# La GRANDE MAJORITÉ des capacités uniques (Rage du Berzerk, Gloire
# du Gladiateur, Bouclier de Foi du Templier, systèmes de Points
# d'Impact (PI, jamais défini dans les données fournies), bons/
# mauvais points d'alignement...) sont des mécaniques ENTIÈREMENT
# propres à un seul métier chacune — bien trop nombreuses et
# disparates pour être automatisées d'un coup. Conservées dans
# Metier.special_traits / special_skill_texts, affichables mais SANS
# effet mécanique pour l'instant.
# ============================================================

static func _build_pr() -> Metier:
	var metier := Metier.new()
	metier.metier_name = "Prêtre"
	metier.short_code = "PR"
	metier.bonus_mana = -4
	metier.special_traits = ["1D6 EA par niveau"]
	metier.equipment_restrictions = ["Armure limite : Cuir"]
	metier.inherited_skill_codes = ["ER", "PS", "RB"]
	metier.special_skill_texts = ["#pretre"]
	metier.prereqs = [{"stat": "intelligence", "type": "min", "value": 10}, {"stat": "charisme", "type": "min", "value": 11}]
	return metier

static func _build_mo() -> Metier:
	var metier := Metier.new()
	metier.metier_name = "Moine"
	metier.short_code = "MO"
	metier.special_traits = ["Le moine a 1/4 chance de se réincarner sans utiliser de point de destin. Il revient à la vie mais perd 1D4+1 EA initiale"]
	metier.equipment_restrictions = ["Armure limite : Cuir travaillé"]
	metier.inherited_skill_codes = ["CLA", "DS", "RE", "TV"]
	metier.grants_moine_frappe_energie = true
	metier.parent_codes = ["PR"]
	metier.prereqs = [{"stat": "intelligence", "type": "min", "value": 10}, {"stat": "charisme", "type": "min", "value": 11}, {"stat": "adresse", "type": "min", "value": 11}]
	return metier

static func _build_pl() -> Metier:
	var metier := Metier.new()
	metier.metier_name = "Paladin"
	metier.short_code = "PL"
	metier.bonus_vie = 6
	metier.bonus_mana = -2
	metier.equipment_restrictions = ["Armure limite : Plaque"]
	metier.inherited_skill_codes = ["ADB", "BP", "CH", "IN"]
	metier.parent_codes = ["PR"]
	metier.prereqs = [{"stat": "courage", "type": "min", "value": 11}, {"stat": "intelligence", "type": "min", "value": 10}, {"stat": "charisme", "type": "min", "value": 11}]
	return metier

static func _build_te() -> Metier:
	var metier := Metier.new()
	metier.metier_name = "Templier"
	metier.short_code = "TE"
	metier.bonus_vie = 5
	metier.special_traits = ["Bannissement des infidèles : les adversaires du templier avec un alignement différent du sien tombent hors combat à 10hp au lieu de 3", "Conviction inébranlable : si une épreuve demande un test de courage ou de force que le templier réussit, les autres membres ne sont pas obligés de réussir"]
	metier.inherited_skill_codes = ["AM", "CDG", "TDM"]
	metier.parent_codes = ["PL"]
	metier.prereqs = [{"stat": "courage", "type": "min", "value": 13}, {"stat": "intelligence", "type": "min", "value": 10}, {"stat": "charisme", "type": "min", "value": 12}, {"stat": "force", "type": "min", "value": 11}]
	return metier

static func _build_vo() -> Metier:
	var metier := Metier.new()
	metier.metier_name = "Voleur"
	metier.short_code = "VO"
	metier.equipment_restrictions = ["Armure limite : Cuir"]
	metier.inherited_skill_codes = ["CHO", "DS", "DE", "SE"]
	metier.grants_voleur_esquive_totale = true
	metier.prereqs = [{"stat": "adresse", "type": "min", "value": 11}, {"stat": "chance", "type": "min", "value": 10}]
	return metier

static func _build_em() -> Metier:
	var metier := Metier.new()
	metier.metier_name = "Empoisonneur"
	metier.short_code = "EM"
	metier.equipment_restrictions = ["Armure limite : Cuir travaillé"]
	metier.inherited_skill_codes = ["CU", "ER", "ME", "RB"]
	metier.grants_empoisonneur_immunity = true
	metier.grants_empoisonneur_dague = true
	metier.special_skill_texts = ["Fabrication : Onguents, potions (vie uniquement), substances (catégorie 2)"]
	metier.parent_codes = ["VO", "HE"]
	metier.prereqs = [{"stat": "intelligence", "type": "min", "value": 11}, {"stat": "adresse", "type": "min", "value": 11}]
	return metier

static func _build_as() -> Metier:
	var metier := Metier.new()
	metier.metier_name = "Assassin"
	metier.short_code = "AS"
	metier.equipment_restrictions = ["Armure limite : Cuir travaillé"]
	metier.inherited_skill_codes = ["AM", "DS", "IN", "PI", "CH"]
	metier.grants_assassin_coup_mortel = true
	metier.grants_assassin_precision_mortelle = true
	metier.special_skill_texts = ["Fabrication : Capes, capuchons, gants, flèches, substances (catégorie 3)"]
	metier.parent_codes = ["EM"]
	metier.prereqs = [{"stat": "intelligence", "type": "min", "value": 13}, {"stat": "adresse", "type": "min", "value": 13}]
	return metier

static func _build_ro() -> Metier:
	var metier := Metier.new()
	metier.metier_name = "Rôdeur"
	metier.short_code = "RO"
	metier.equipment_restrictions = ["Armure limite : Cuir travaillé"]
	metier.inherited_skill_codes = ["DE", "DS", "PI", "IDS", "TC"]
	metier.grants_rodeur_camouflage = true
	metier.special_skill_texts = ["Faucon : Le ranger peut compter sur son animal de compagnie. Impuissant en combat mais permet d'observer une zone. Grâce au faucon, les aventuriers ont moins de chance de faire des rencontres (1-3 au dé 8)", "Fabrication : Capes, capuchons, gants, flèches"]
	metier.parent_codes = ["VO"]
	metier.prereqs = [{"stat": "courage", "type": "min", "value": 11}, {"stat": "adresse", "type": "min", "value": 11}]
	return metier

static func _build_na() -> Metier:
	var metier := Metier.new()
	metier.metier_name = "Ninja"
	metier.short_code = "NA"
	metier.special_traits = ["Maître du Tai-Jutsu : Les attaques à main nue du ninja sont considérées comme tranchantes", "Maître des ombres : invisible dans les ombres"]
	metier.equipment_restrictions = ["Armure limite : Cuir travaillé"]
	metier.inherited_skill_codes = ["AM", "DE", "DS", "PI", "RAR", "SE"]
	metier.grants_ninja_esquive_totale = true
	metier.grants_ninja_frappe_des_ombres = true
	metier.parent_codes = ["RO"]
	metier.prereqs = [{"stat": "adresse", "type": "min", "value": 15}]
	return metier

static func _build_ar() -> Metier:
	var metier := Metier.new()
	metier.metier_name = "Artiste"
	metier.short_code = "AR"
	metier.bonus_vie = -3
	metier.bonus_parade = 1
	metier.special_traits = ["+2 épreuves charisme (+4 sexe opposé)", "+2 jets chance", "Repos bien mérité : Alliés +1EV/PA par heure de repos"]
	metier.equipment_restrictions = ["Armes à 2 mains", "Bouclier", "Armure limite : Cuir"]
	metier.inherited_skill_codes = ["AEC", "JED", "MEP", "MEP", "NT", "PE", "TDP"]
	metier.prereqs = [{"stat": "intelligence", "type": "min", "value": 10}, {"stat": "charisme", "type": "min", "value": 10}, {"stat": "adresse", "type": "min", "value": 10}, {"stat": "force", "type": "max", "value": 12}]
	return metier

static func _build_pe() -> Metier:
	var metier := Metier.new()
	metier.metier_name = "Peintre"
	metier.short_code = "PE"
	metier.special_traits = ["Sens du détails : +2 aux épreuves de détection"]
	metier.equipment_restrictions = ["Armure limite : Cuir"]
	metier.inherited_skill_codes = ["ADR", "BDD", "CDG", "DE", "ME"]
	metier.special_skill_texts = ["Peinture de guerre : +1Cou +1Fo *lvl aux alliés si test Cou réussit", "Maquillage : Peut se faire passer pour quelqu'un d'autre sur un test INT / CHA"]
	metier.parent_codes = ["AR"]
	metier.prereqs = [{"stat": "intelligence", "type": "min", "value": 11}, {"stat": "charisme", "type": "min", "value": 10}, {"stat": "adresse", "type": "min", "value": 10}, {"stat": "force", "type": "max", "value": 11}]
	return metier

static func _build_ps() -> Metier:
	var metier := Metier.new()
	metier.metier_name = "Prestidigitateur"
	metier.short_code = "PS"
	metier.special_traits = ["Pièce derrière l'oreille : Le magicien entourloupe toujours sa cible, il récupère 10% des PO de la transaction"]
	metier.equipment_restrictions = ["Armure limite : Cuir travaillé"]
	metier.inherited_skill_codes = ["AM", "ME", "RB", "TC", "TV"]
	metier.grants_prestidigitateur_realite_distordue = true
	metier.parent_codes = ["AR"]
	metier.prereqs = [{"stat": "intelligence", "type": "min", "value": 10}, {"stat": "charisme", "type": "min", "value": 10}, {"stat": "adresse", "type": "min", "value": 11}, {"stat": "chance", "type": "min", "value": 10}]
	return metier

static func _build_bd() -> Metier:
	var metier := Metier.new()
	metier.metier_name = "Barde"
	metier.short_code = "BD"
	metier.bonus_vie = -3
	metier.special_traits = ["15 EA", "1DEA level up", "Prise de note : +1EA si inactif pendant le tour"]
	metier.equipment_restrictions = ["Armure limite : Cuir renforcé"]
	metier.inherited_skill_codes = ["ALM", "JED", "MEP", "RAR", "TDP"]
	metier.special_skill_texts = ["#barde"]
	metier.parent_codes = ["AR"]
	metier.prereqs = [{"stat": "charisme", "type": "min", "value": 12}]
	return metier

static func _build_ml() -> Metier:
	var metier := Metier.new()
	metier.metier_name = "Menestrel"
	metier.short_code = "ML"
	metier.special_traits = []
	metier.equipment_restrictions = ["Armure limite : Cuir travaillé"]
	metier.inherited_skill_codes = ["Érudition", "Fariboles", "Pénible"]
	metier.special_skill_texts = ["#barde"]
	metier.parent_codes = ["BD"]
	metier.prereqs = [{"stat": "charisme", "type": "min", "value": 13}]
	return metier

static func _build_ce() -> Metier:
	var metier := Metier.new()
	metier.metier_name = "Célébrité"
	metier.short_code = "CE"
	metier.special_traits = ["La fame : La célébrité et son groupe ont 50% dans les auberges / tavernes / restaurants", "Merchandising : Tous les jours la célébrité jette 3 dés 20 de PO comme royalties sur ses oeuvres", "Rencontre amicale: Lors d'une rencontre si les ennemis sont des humains il y a 1/4 chance qu'ils soient fan de la célébrité et n'attaquent pas", "Julia Roberts : Lors d'une rencontre si les ennemis sont des humains il y a 1/4 chance de détester la célébrité et la focus"]
	metier.equipment_restrictions = ["Armure limite : Maille renforcée"]
	metier.inherited_skill_codes = ["AEC", "CDG", "FA"]
	metier.parent_codes = ["PS", "CM", "GL", "PE", "BD", "ML"]
	metier.prereqs = [{"stat": "charisme", "type": "min", "value": 14}, {"stat": "chance", "type": "min", "value": 12}]
	return metier

static func _build_be() -> Metier:
	var metier := Metier.new()
	metier.metier_name = "Bourgeois"
	metier.short_code = "BE"
	metier.special_traits = ["Le bourgeois commence avec 3 dés de PO", "L’avare : Le bourgeois ne peut pas donner de l’argent ou du matériel, il garde tout pour lui"]
	metier.equipment_restrictions = ["Armure limite : Maille"]
	metier.inherited_skill_codes = ["ADR", "CH", "ER", "FA", "TC"]
	metier.special_skill_texts = ["Sens des affaires : Une fois par jour le bourgeois peut jouer en bourse. Il choisit d'engager une somme en PO. Avec 1D6, de 1 à 2 il gagne de l'argent, 3 et 4 rien, de 4 à 6 il perd de l'argent. 1D20 pour savoir le pourcentage d'argent gagné ou perdu"]
	metier.parent_codes = ["*", "AT"]
	metier.prereqs = [{"stat": "charisme", "type": "min", "value": 11}, {"stat": "chance", "type": "min", "value": 10}]
	return metier

static func _build_nb() -> Metier:
	var metier := Metier.new()
	metier.metier_name = "Noble"
	metier.short_code = "NB"
	metier.special_traits = ["L’argent appelle l’argent : Le Noble gagne 20% PO supplémentaire dans sa cagnotte personnelle", "L’argent c’est du temps : Le Noble prend 10% xp supplémentaire du combat pour lui"]
	metier.equipment_restrictions = ["Armure limite : Plaque"]
	metier.inherited_skill_codes = ["CDG", "DE", "RB", "PS"]
	metier.parent_codes = ["BE"]
	metier.prereqs = [{"stat": "charisme", "type": "min", "value": 12}, {"stat": "chance", "type": "min", "value": 11}]
	return metier

static func _build_se() -> Metier:
	var metier := Metier.new()
	metier.metier_name = "Seigneur"
	metier.short_code = "SE"
	metier.special_traits = ["Maître d'arme: Le seigneur peut réarranger son AT/PRD initiale comme il le souhaite, dans la limite de -5/+5", "Taxes : Une fois par jour le seigneur reçoit l'argent des taxes de ses paysans (4D20)", "Hérité : Le seigneur hérite de l'équipement familial (non vendable). Cotte de mailles luxe avec manche et lame d'excellence de riche (lame d'excellence mais avec 1D+5)"]
	metier.equipment_restrictions = ["3PR Max"]
	metier.inherited_skill_codes = ["AM", "ADB", "CDG", "IDT", "TDM"]
	metier.parent_codes = ["NB"]
	metier.prereqs = [{"stat": "charisme", "type": "min", "value": 14}]
	return metier

static func _build_at() -> Metier:
	var metier := Metier.new()
	metier.metier_name = "Artisan"
	metier.short_code = "AT"
	metier.equipment_restrictions = ["Armure limite : Cuir travaillé"]
	metier.inherited_skill_codes = ["AEC", "BDD", "FDP"]
	metier.special_skill_texts = ["Tailleur : Peut réparer tout ce qui n'est pas en métal (test AD et 50%po)", "Fabrication : Capes, capuchons, gants, accessoires"]
	metier.prereqs = [{"stat": "intelligence", "type": "min", "value": 10}, {"stat": "adresse", "type": "min", "value": 11}, {"stat": "force", "type": "min", "value": 10}]
	return metier

static func _build_fo() -> Metier:
	var metier := Metier.new()
	metier.metier_name = "Forgeron"
	metier.short_code = "FO"
	metier.bonus_vie = 5
	metier.bonus_mana = 18
	metier.special_traits = ["1D6EV level up", "1DEA level up"]
	metier.equipment_restrictions = ["Armure limite : Maille travaillée"]
	metier.inherited_skill_codes = ["SE", "TDM"]
	metier.special_skill_texts = ["Renforcement : Peut enlever 1 de rupture sur test FO (si raté ajoute 1)"]
	metier.parent_codes = ["AT"]
	metier.prereqs = [{"stat": "force", "type": "min", "value": 12}]
	return metier

static func _build_fr() -> Metier:
	var metier := Metier.new()
	metier.metier_name = "Forgeur de runes"
	metier.short_code = "FR"
	metier.bonus_vie = 5
	metier.bonus_mana = 18
	metier.special_traits = ["1D6EV level up", "1DEA level up"]
	metier.equipment_restrictions = ["Le forgeur de runes ne peut apposer une rune plus d’une fois sur un joueur ou une arme/armure.", "Armure limite : Plaque"]
	metier.inherited_skill_codes = ["CDG", "ER", "RB", "SE"]
	metier.special_skill_texts = ["#forgeur-de-runes"]
	metier.parent_codes = ["AT", "FO"]
	metier.prereqs = [{"stat": "intelligence", "type": "min", "value": 12}, {"stat": "adresse", "type": "min", "value": 11}, {"stat": "force", "type": "min", "value": 12}]
	return metier

static func _build_co() -> Metier:
	var metier := Metier.new()
	metier.metier_name = "Commerçant"
	metier.short_code = "CO"
	metier.special_traits = ["Havresac : Le commerçant peut stocker 4 items de toute taille dans son havresac", "Pignon sur rue : Le commerçant peut vendre des items peu importe l'endroit où il est pour 40% du prix (selon état) au lieu des 50% classique en ville ( arnaque et carambouille ne s'applique pas)"]
	metier.equipment_restrictions = ["Armure limite : Cuir travaillé"]
	metier.inherited_skill_codes = ["AEC", "ER", "FA", "IDT"]
	metier.parent_codes = ["AT", "BE"]
	metier.prereqs = [{"stat": "intelligence", "type": "min", "value": 11}, {"stat": "charisme", "type": "min", "value": 10}]
	return metier

static func _build_he() -> Metier:
	var metier := Metier.new()
	metier.metier_name = "Herboriste"
	metier.short_code = "HE"
	metier.equipment_restrictions = ["3PR Max"]
	metier.inherited_skill_codes = ["CU", "IDS", "NT", "PS"]
	metier.special_skill_texts = ["Fabrication : Potions, onguents, substances (categorie 1)"]
	metier.parent_codes = ["AT"]
	metier.prereqs = [{"stat": "intelligence", "type": "min", "value": 12}, {"stat": "adresse", "type": "min", "value": 11}]
	return metier

static func _build_ra() -> Metier:
	var metier := Metier.new()
	metier.metier_name = "Ranger"
	metier.short_code = "RA"
	metier.special_traits = ["Peut échanger 1 point de cara avec un autre"]
	metier.equipment_restrictions = ["Armure limite : Cuir travaillé"]
	metier.inherited_skill_codes = ["DE", "CH", "NA", "PI"]
	metier.prereqs = [{"stat": "charisme", "type": "min", "value": 10}, {"stat": "adresse", "type": "min", "value": 10}, {"stat": "chance", "type": "min", "value": 10}]
	metier.bonus_stat_points = 1  # Un point de caractéristique supplémentaire à répartir.
	return metier

static func _build_cp() -> Metier:
	var metier := Metier.new()
	metier.metier_name = "Chasseur de primes"
	metier.short_code = "CP"
	metier.special_traits = ["Dead or alive : Si le chasseur de prime combat des humains, l'un d'eux (aléatoire) possède une prime équivalente à 4* l'xp de la cible. Le chasseur doit être celui qui achève la cible pour récupérer la prime", "L'expérience n'a pas de prix : Toutes les 5 primes récoltées, le chasseur de prime gagne 1PI contre humain"]
	metier.equipment_restrictions = ["Armure limite : Maille"]
	metier.inherited_skill_codes = ["CDN", "DS", "FL", "ME", "PI"]
	metier.special_skill_texts = ["Coup décisif : Le chasseur de prime peut décider que sa prochaine attaque sera critique de 1 à X et échec critique de 20-X à 20."]
	metier.parent_codes = ["RA", "GR"]
	metier.prereqs = [{"stat": "courage", "type": "min", "value": 12}, {"stat": "intelligence", "type": "min", "value": 10}, {"stat": "adresse", "type": "min", "value": 12}]
	return metier

static func _build_cm() -> Metier:
	var metier := Metier.new()
	metier.metier_name = "Chasseur de monstres"
	metier.short_code = "CM"
	metier.special_traits = ["Collectionneur : Si le chasseur de monstres combat des créatures (animaux aussi), et que le chasseur de monstres achève l'un d'eux. Il gagne un trophée de ce monstre", "Tableau de chasse : Tous les 5 trophées récoltés, le chasseur de monstres gagne 1PI contre les créatures"]
	metier.equipment_restrictions = ["Armure limite : Maille renforcée"]
	metier.inherited_skill_codes = ["CDN", "DS", "FL", "ME", "PI"]
	metier.special_skill_texts = ["Coup décisif : Le chasseur de monstres peut décider que sa prochaine attaque sera critique de 1 à X et échec critique de 20-X à 20."]
	metier.parent_codes = ["RA"]
	metier.prereqs = [{"stat": "courage", "type": "min", "value": 12}, {"stat": "intelligence", "type": "min", "value": 10}, {"stat": "adresse", "type": "min", "value": 12}]
	return metier

static func _build_ac() -> Metier:
	var metier := Metier.new()
	metier.metier_name = "Archéologue"
	metier.short_code = "AC"
	metier.bonus_mana = 15
	metier.special_traits = ["Une journée de plus sur le terrain : Familier des ruines, tombeau, etc, l'archéologue a +1AD dans ces environnements", "Ça m'a l'air ancien tout ça : Avant de rentrer dans une ruine, tombeau, etc, sur 1-2-3-4 au dé 20 l'archéologue est sûr de trouver un item précieux"]
	metier.equipment_restrictions = ["Armure limite : Cuir"]
	metier.inherited_skill_codes = ["DS", "ER", "ES", "PI", "SE"]
	metier.special_skill_texts = ["#archeologue"]
	metier.parent_codes = ["RA"]
	metier.prereqs = [{"stat": "courage", "type": "min", "value": 10}, {"stat": "intelligence", "type": "min", "value": 11}, {"stat": "adresse", "type": "min", "value": 10}, {"stat": "chance", "type": "min", "value": 10}]
	return metier

static func _build_ct() -> Metier:
	var metier := Metier.new()
	metier.metier_name = "Chasseur de trésor"
	metier.short_code = "CT"
	metier.special_traits = ["Commissaire-priseur : le chasseur de trésor connait la valeur des objets sans avoir besoin de les faire expertiser"]
	metier.equipment_restrictions = ["Armure limite : Maille"]
	metier.inherited_skill_codes = ["CHO", "IDT", "FA", "MEP"]
	metier.special_skill_texts = ["Pas cette fois : le chasseur de trésor peut toujours effectuer un test de chance en plus du test de base pour éviter un piège (PAS ENCORE IMPLÉMENTÉ — pas de système de pièges en exploration chez nous pour l'instant ; seul métier/race capable d'éviter un piège une fois ce système construit)", "Corde de rappel : Le chasseur de trésor peut revenir quand il le souhaite (hors combat) ( avec son groupe contre EV/2) à l'entrée de la ruine, du tombeau, donjon, etc"]
	metier.parent_codes = ["AC"]
	metier.prereqs = [{"stat": "chance", "type": "min", "value": 12}]
	return metier

static func _build_cv() -> Metier:
	var metier := Metier.new()
	metier.metier_name = "Conservateur"
	metier.short_code = "CV"
	metier.bonus_mana = 10
	metier.special_traits = ["Maitrise des runes : Les armes du conservateur ont +2PI magique", "Contre-Sort : Les connaissances du conservateur lui permettent de ne pas être la cible de mutation majeure de son choix", "Galerie d'art : Tous les 10 items différents récoltés et exposés par le conservateur il gagne +1 INT"]
	metier.equipment_restrictions = ["Armure limite : Cuir travaillé"]
	metier.inherited_skill_codes = ["AEC", "CDG", "LDM", "RB"]
	metier.special_skill_texts = ["#conservateur"]
	metier.parent_codes = ["AC"]
	metier.prereqs = [{"stat": "intelligence", "type": "min", "value": 13}]
	return metier

static func _build_in() -> Metier:
	var metier := Metier.new()
	metier.metier_name = "Ingénieur"
	metier.short_code = "IN"
	metier.special_traits = ["Amélioration : Il peut ajouter 1 cara à une arme (test INT, si rate +1 RUP)"]
	metier.equipment_restrictions = ["4PR Max"]
	metier.inherited_skill_codes = ["BDD", "DE", "ER", "FDP"]
	metier.special_skill_texts = ["Polyvalence : Ajoute 1 aux tests des alliés", "Fabrication : Flèches, carreaux"]
	metier.parent_codes = ["AT"]
	metier.prereqs = [{"stat": "intelligence", "type": "min", "value": 12}, {"stat": "adresse", "type": "min", "value": 9}]
	return metier

static func _build_af() -> Metier:
	var metier := Metier.new()
	metier.metier_name = "Artificier"
	metier.short_code = "AF"
	metier.special_traits = ["Dégâts de feu réduits de moitié", "+1PI armes à feu"]
	metier.equipment_restrictions = ["4PR Max"]
	metier.inherited_skill_codes = ["DES", "TC"]
	metier.special_skill_texts = ["Fabrication : Peut fabriquer plusieurs types de dispositif explosif, fumigène, fragmentation, incendiaire, mortier, mine, feu d'artifice"]
	metier.parent_codes = ["IN"]
	metier.prereqs = [{"stat": "intelligence", "type": "min", "value": 12}, {"stat": "adresse", "type": "min", "value": 12}, {"stat": "chance", "type": "min", "value": 10}]
	return metier

static func _build_ia() -> Metier:
	var metier := Metier.new()
	metier.metier_name = "Ingénieur Automate"
	metier.short_code = "IA"
	metier.special_traits = ["Construction de Mécas (2max par combat)", "Tous les trois niveaux l’ingénieur ne gagne pas une nouvelle compétence, ses Mécas évoluent"]
	metier.equipment_restrictions = ["3PR Max"]
	metier.inherited_skill_codes = ["SE"]
	metier.special_skill_texts = ["#ingenieur"]
	metier.parent_codes = ["IN"]
	metier.prereqs = [{"stat": "intelligence", "type": "min", "value": 13}, {"stat": "adresse", "type": "min", "value": 11}, {"stat": "force", "type": "min", "value": 10}]
	return metier

static func _build_dm() -> Metier:
	var metier := Metier.new()
	metier.metier_name = "Démonologue"
	metier.short_code = "DM"
	metier.bonus_parade = -1
	metier.special_traits = ["Consomme PV alliés pour sorts", "Collecte des âmes. Toutes les 20 âmes capturées -> +1 dégâts Magique", "Repos des Damnés : Libère 1 âme pour rendre 1 pv à un allié"]
	metier.equipment_restrictions = ["Armes à 2 mains", "Bouclier", "2PR Max"]
	metier.inherited_skill_codes = ["AG", "ADR", "AEC", "CLA", "ER", "LDM"]
	metier.special_skill_texts = ["#demonologue"]
	metier.prereqs = [{"stat": "courage", "type": "min", "value": 12}, {"stat": "intelligence", "type": "min", "value": 12}, {"stat": "charisme", "type": "min", "value": 10}]
	return metier

static func _build_iq() -> Metier:
	var metier := Metier.new()
	metier.metier_name = "Inquisiteur"
	metier.short_code = "IQ"
	metier.special_traits = ["+1 PI sur le surnaturel", "Agitateur : Sait galvaniser la foule"]
	metier.equipment_restrictions = ["Armes à 2 mains", "Bouclier", "Armure limite : Cuir travaillé"]
	metier.inherited_skill_codes = ["CDG", "ER", "LDM", "ME", "PI"]
	metier.parent_codes = ["DM", "CM"]
	metier.prereqs = [{"stat": "courage", "type": "min", "value": 12}, {"stat": "charisme", "type": "min", "value": 12}, {"stat": "adresse", "type": "min", "value": 10}, {"stat": "force", "type": "min", "value": 10}]
	return metier

static func _build_gr() -> Metier:
	var metier := Metier.new()
	metier.metier_name = "Guerrier"
	metier.short_code = "GR"
	metier.bonus_vie = 5
	metier.special_traits = ["Peut échanger 1AT et 1PRD"]
	metier.equipment_restrictions = ["Armure limite : Maille travaillée"]
	metier.inherited_skill_codes = ["ADT", "BP", "CDN", "IN"]
	metier.prereqs = [{"stat": "courage", "type": "min", "value": 11}, {"stat": "force", "type": "min", "value": 11}]
	return metier

static func _build_so() -> Metier:
	var metier := Metier.new()
	metier.metier_name = "Soldat"
	metier.short_code = "SO"
	metier.special_traits = ["Caserne : pour l'achat il est toujours considéré comme dans au moins une grande ville", "Formation : +1 point d'impact s'il ne combat pas tout seul"]
	metier.equipment_restrictions = ["Armure limite : Plaque"]
	metier.inherited_skill_codes = ["CH", "IDS", "PS", "TC"]
	metier.special_skill_texts = ["Porte étendard : +1 aux cara alliés pendant 3 tours sur test COU / CHA"]
	metier.parent_codes = ["GR"]
	metier.prereqs = [{"stat": "courage", "type": "min", "value": 12}]
	return metier

static func _build_bz() -> Metier:
	var metier := Metier.new()
	metier.metier_name = "Berzerk"
	metier.short_code = "BZ"
	metier.bonus_vie = 15
	metier.bonus_attaque = 2
	metier.bonus_parade = -2
	metier.special_traits = ["Rage : Le berzerk gagne 2 de rage par dégâts reçus (après réduction)", "Enragé : +level PI en dessous de 33% EV", "Coute que coute : +level*2 PI en dessous de 66% EV"]
	metier.equipment_restrictions = ["Armure limite : Cuir travaillé", "Pas de casque", "Pas de bouclier"]
	metier.inherited_skill_codes = ["AM", "ADB", "ALM", "IN", "TV"]
	metier.special_skill_texts = ["Frappe puissante, dégâts +2 à la cible. 5 rages", "Tourbillon, sur une attaque (-2) réussit le berzerk inflige une attaque circulaire sur toute personne à portée. 10 rages", "GRRRRRBLBLBL, Transforme 10*x rages en 1*x PI. 1 fois par combat. Test COU"]
	metier.parent_codes = ["GR"]
	metier.prereqs = [{"stat": "courage", "type": "min", "value": 12}, {"stat": "intelligence", "type": "max", "value": 10}, {"stat": "force", "type": "min", "value": 13}]
	return metier

static func _build_gl() -> Metier:
	var metier := Metier.new()
	metier.metier_name = "Gladiateur"
	metier.short_code = "GL"
	metier.bonus_vie = 5
	metier.bonus_attaque = -2
	metier.bonus_parade = 2
	metier.special_traits = ["Gloire : Le gladiateur gagne 1 de gloire par AT réussi et 2 par PRD réussie. Il en perd 1 par PRD ratée.", "Pour la gloire : Le gladiateur commence le combat avec 5 de gloires", "Tenir bon : +level PR en dessous de 33% EV"]
	metier.equipment_restrictions = ["Armure limite : Maille renforcée", "3 pièces maximum en armure", "Casque obligatoire", "Bouclier obligatoire"]
	metier.inherited_skill_codes = ["CDG", "IN", "TDM"]
	metier.special_skill_texts = ["Doigt d'honneur : Force l'ennemi à l'attaquer pendant 3 tours. COU/CHA 5 gloires", "Coup de bouclier : Étourdit la cible pendant 2 tours. FO/AD 7 gloires", "Un pour tous : Le gladiateur perd 3 AT mais peut rediriger sur lui les 3 prochains dégâts qu'un allié va subir", "Tortue : -2AT +2PRD +1PR. FO/COU 10 gloires"]
	metier.parent_codes = ["GR"]
	metier.prereqs = [{"stat": "courage", "type": "min", "value": 12}, {"stat": "adresse", "type": "min", "value": 10}, {"stat": "force", "type": "min", "value": 13}]
	return metier

static func _build_ma() -> Metier:
	var metier := Metier.new()
	metier.metier_name = "Maitre d'armes"
	metier.short_code = "MA"
	metier.special_traits = ["+1 AT / PRD", "Entraîneur : Un allié au choix peut réarranger son AT / PRD dans une limite de +3 / -3"]
	metier.inherited_skill_codes = ["AM", "ADB", "TDM"]
	metier.special_skill_texts = ["Enchaînement : +1 PI pour chaque attaque réussie. Réinitialise si pas de dégâts infligés"]
	metier.parent_codes = ["SO"]
	metier.prereqs = [{"stat": "courage", "type": "min", "value": 13}, {"stat": "charisme", "type": "min", "value": 13}, {"stat": "adresse", "type": "min", "value": 13}]
	return metier

static func _build_pi() -> Metier:
	var metier := Metier.new()
	metier.metier_name = "Pirate"
	metier.short_code = "PI"
	metier.special_traits = ["Sur la mer : +1 stats en combat naval", "Peut pistolet + épée sans ambidextrie", "Perroquet : pareil que faucon du rôdeur"]
	metier.equipment_restrictions = ["Armure limite : Cuir travaillé"]
	metier.inherited_skill_codes = ["ADT", "IDS", "IDT", "NA", "TC"]
	metier.parent_codes = ["GR"]
	metier.prereqs = [{"stat": "adresse", "type": "min", "value": 12}]
	return metier

static func _build_cr() -> Metier:
	var metier := Metier.new()
	metier.metier_name = "Corsaire"
	metier.short_code = "CR"
	metier.special_traits = ["Contrebande : Peut vendre n'importe où sans malus"]
	metier.equipment_restrictions = ["Armure limite : Maille"]
	metier.inherited_skill_codes = ["AEC", "CDG", "PI"]
	metier.special_skill_texts = ["Salves : Utilise 4 pistolets en une fois, puis à besoin de 2 tours pour tout recharger"]
	metier.parent_codes = ["PI", "SO", "CP"]
	metier.prereqs = [{"stat": "courage", "type": "min", "value": 12}, {"stat": "charisme", "type": "min", "value": 12}]
	return metier

static func _build_mg() -> Metier:
	var metier := Metier.new()
	metier.metier_name = "Mage, Sorcier"
	metier.short_code = "MG"
	metier.special_traits = ["20EV si humain, sinon -30%", "EV ou EA au level up"]
	metier.equipment_restrictions = ["Epee, hache, lance, masse, javelot", "Arcs, arbalètes, armes à feu", "Bouclier", "2PR Max"]
	metier.inherited_skill_codes = ["ER", "RE", "RB"]
	metier.special_skill_texts = ["#mage"]
	metier.prereqs = [{"stat": "intelligence", "type": "min", "value": 12}]
	return metier

static func _build_wa() -> Metier:
	var metier := Metier.new()
	metier.metier_name = "Walkyrie"
	metier.short_code = "WA"
	metier.special_skill_texts = ["#walkyrie"]
	return metier

static func _build_cc() -> Metier:
	var metier := Metier.new()
	metier.metier_name = "Compagnie du crépuscule"
	metier.short_code = "CC"
	metier.special_traits = ["Justice sombre : augmente à 5 la limite de mauvais points"]
	metier.inherited_skill_codes = ["AG", "IN"]
	metier.special_skill_texts = ["#walkyrie"]
	metier.parent_codes = ["WA"]
	metier.prereqs = [{"stat": "intelligence", "type": "min", "value": 11}, {"stat": "force", "type": "min", "value": 12}]
	return metier

static func _build_lc() -> Metier:
	var metier := Metier.new()
	metier.metier_name = "Légion céleste"
	metier.short_code = "LC"
	metier.special_traits = ["EV +5", "Justice impartiale : 4 bons points / 4 mauvais points"]
	metier.inherited_skill_codes = ["TDM"]
	metier.special_skill_texts = ["#walkyrie"]
	metier.parent_codes = ["WA"]
	metier.prereqs = [{"stat": "adresse", "type": "min", "value": 13}, {"stat": "force", "type": "min", "value": 12}]
	return metier

static func _build_ga() -> Metier:
	var metier := Metier.new()
	metier.metier_name = "Gardienne de l'aube"
	metier.short_code = "GA"
	metier.special_traits = ["Justice vertueuse : 3 bons points / 2 mauvais points"]
	metier.inherited_skill_codes = ["CLA", "PS"]
	metier.special_skill_texts = ["#walkyrie"]
	metier.parent_codes = ["WA"]
	metier.prereqs = [{"stat": "intelligence", "type": "min", "value": 11}, {"stat": "charisme", "type": "min", "value": 14}]
	return metier

static func _build_aa() -> Metier:
	var metier := Metier.new()
	metier.metier_name = "Archange"
	metier.short_code = "AA"
	metier.bonus_vie = 10
	metier.special_traits = ["Justice personnelle : 1 bon point / 1 mauvais point", "Ne peut être tué que par un critique (même 1-1)"]
	metier.inherited_skill_codes = ["CDG", "CDG", "DET", "DET", "ME", "ME", "TV"]
	metier.special_skill_texts = ["#walkyrie"]
	metier.parent_codes = ["CC", "LC", "GA"]
	metier.prereqs = [{"stat": "courage", "type": "min", "value": 14}, {"stat": "intelligence", "type": "min", "value": 13}, {"stat": "charisme", "type": "min", "value": 15}, {"stat": "adresse", "type": "min", "value": 13}, {"stat": "force", "type": "min", "value": 13}, {"stat": "chance", "type": "min", "value": 12}]
	return metier

const CODES: Array = ["PR", "MO", "PL", "TE", "VO", "EM", "AS", "RO", "NA", "AR", "PE", "PS", "BD", "ML", "CE", "BE", "NB", "SE", "AT", "FO", "FR", "CO", "HE", "RA", "CP", "CM", "AC", "CT", "CV", "IN", "AF", "IA", "DM", "IQ", "GR", "SO", "BZ", "GL", "MA", "PI", "CR", "MG", "WA", "CC", "LC", "GA", "AA"]

# Tous les codes courts de métier valides (mêmes chaînes que celles
# acceptées par build() ci-dessous) — utilisé pour un tirage au sort
# (voir HexGrid.setup_starting_units, combat de test).
static func list_all_metier_short_codes() -> Array:
	return [
		"PR", "MO", "PL", "TE", "VO", "EM", "AS", "RO", "NA", "AR", "PE", "PS",
		"BD", "ML", "CE", "BE", "NB", "SE", "AT", "FO", "FR", "CO", "HE", "RA",
		"CP", "CM", "AC", "CT", "CV", "IN", "AF", "IA", "DM", "IQ", "GR", "SO",
		"BZ", "GL", "MA", "PI", "CR", "MG", "WA", "CC", "LC", "GA", "AA",
	]

static func build(short_code: String) -> Metier:
	match short_code:
		"PR":
			return _build_pr()
		"MO":
			return _build_mo()
		"PL":
			return _build_pl()
		"TE":
			return _build_te()
		"VO":
			return _build_vo()
		"EM":
			return _build_em()
		"AS":
			return _build_as()
		"RO":
			return _build_ro()
		"NA":
			return _build_na()
		"AR":
			return _build_ar()
		"PE":
			return _build_pe()
		"PS":
			return _build_ps()
		"BD":
			return _build_bd()
		"ML":
			return _build_ml()
		"CE":
			return _build_ce()
		"BE":
			return _build_be()
		"NB":
			return _build_nb()
		"SE":
			return _build_se()
		"AT":
			return _build_at()
		"FO":
			return _build_fo()
		"FR":
			return _build_fr()
		"CO":
			return _build_co()
		"HE":
			return _build_he()
		"RA":
			return _build_ra()
		"CP":
			return _build_cp()
		"CM":
			return _build_cm()
		"AC":
			return _build_ac()
		"CT":
			return _build_ct()
		"CV":
			return _build_cv()
		"IN":
			return _build_in()
		"AF":
			return _build_af()
		"IA":
			return _build_ia()
		"DM":
			return _build_dm()
		"IQ":
			return _build_iq()
		"GR":
			return _build_gr()
		"SO":
			return _build_so()
		"BZ":
			return _build_bz()
		"GL":
			return _build_gl()
		"MA":
			return _build_ma()
		"PI":
			return _build_pi()
		"CR":
			return _build_cr()
		"MG":
			return _build_mg()
		"WA":
			return _build_wa()
		"CC":
			return _build_cc()
		"LC":
			return _build_lc()
		"GA":
			return _build_ga()
		"AA":
			return _build_aa()
		_:
			push_warning("MetierDatabase: métier inconnu '%s'." % short_code)
			return null

# Cherche un métier par son NOM complet (ex: "Guerrier") plutôt que
# son short_code (ex: "GR") — pratique pour WorldManager.party_name,
# qui utilise déjà des noms complets pour les classes de test.
static func build_by_name(name: String) -> Metier:
	for code in CODES:
		var m = build(code)
		if m != null and m.metier_name == name:
			return m
	return null
