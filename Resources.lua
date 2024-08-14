local addonName, addon = ...
local _G = _G
_G["RaidDominion"] = addon

raidRules = {
    ["LA CAMARA DE ARCHAVON"] = {"BOTIN => PVE: Por función MAIN // PVP: Por clase"},
    ["RAID DOMINION"] = {"Todos invitados a unirse a la hermandad // Portal: https://raid-dominion.netlify.app/"},
    ["RE-ARME RAPIDO"] = {"Por favor continuar // Ya se esta buscando por posada // Conocidos interesados que WISP"},
    ["REVISO Y REEMPLAZO"] = {"AFK/OFFs sin avisar // DPS debajo del Tanque // No respetar pulls o mecanincas = No botin"},
    ["BOTIN"] =  {"No DC = No Botin // Se rollea 20 minutos antes del ligado del item o al dar Raid Off en el orden que fueron obtenidos."},
    ["ICC 10 N"] = {"PRIORIDAD DE LOTEO: Por función MAIN > DUAL."},
    ["ICC 25 N"] = {"PRIORIDAD DE LOTEO: Por función MAIN > DUAL. // MARCAS: Debe linkear 1 t10 engemado/encantado. // ABACO: top3 cerrado  en Reina. // TARRO: top5 daño en Panza cerrado + 5% en bestias, rollea paladín retry, pícaro asesinato.","TESTAMENTO: top5 daño en Panza cerrado + 5% en bestias. Rollean warrior fury, dk profano/escarcha, pícaro combate y druida feral, hunter punteria. // OBJETO: top5 cerrado daño en Panza + 3% en bestias.","FILACTERIA: top3 cerrado daño en Profe + 10% en mocos. // COLMILLO: prioridad tanques activos en su rol, luego el resto. // RESERVADOS: Fragmentos, Items no ligados y Saros.","ARMAS LK: top10 daño en LK + 5% en Valkyrs y top3 conteo de sanacion en LK. // Un abalorio, Un arma, Dos marcas por raid. Un ítem por main(excepto tankes), sin limite por dual. Marcas tambien por dual.","Arma y sostener cuentan como ítem. Solo excentas armas de Lk. Armas 2.6 pueden ser loteadas por tanques. // Si en algun top no necesitan el ítem o no cumplen la regla para lotear, pasará al siguiente en top."},
    ["ICC 10 H"] = {"PRIORIDAD DE LOTEO: Por función MAIN > DUAL. // MARCAS: Debe linkear 1 t10 engemado/encantado."},
}
raidMechanics = {
    ["LA CAMARA DE ARCHAVON"] = {"Tanques intercambian cada 4 marcas // DPS destruyen orbes totalmente y continuan con boss"},
    ["TUETANO"] = {
        "Tanques derecha // Grupo detrás y debajo del boss // Hunters izquierda // HEROISMO de entrada // DESTRUIR púas de inmediato // RANGED destruyen púas lejanas al grupo // Evitar trazos de fuego",
        "Maestría y defensivos durante tormentas // Tanques retoman boss cerca de escaleras"
    },
    ["LADY DEATHWISPER"] = {
        "TODOS fondo a la derecha // Tanques juntan agro adds // DPS áreas sobre adds // Evitar áreas de daño // CADENAS y CICLÓN sobre aliado controlado // Evitar tocar fantasmas y llevarlos lejos del grupo"
    },
    ["BARCOS"] = {
        "MAIN TANK SOLO por su lado // DPS lado contrario // Evitar ser rajados // Cañones entre 87~100% del poder de ataque antes de ataque especial // DESTRUIR mago y regresar por el mismo lado // Cañones terminan el trabajo",
        "Esperar en terraza de libra, nadie abra el cofre de loot o perderá todo loteo"
    },
    ["LIBRA"] = {
        "TANQUES bajo escaleras atentos a marcas // Cuerpo a cuerpo sobre escaleras // Ranged a /range 12 evitan marcas // Trampa de Escarcha al caleo // Marcados no atacan bestias // HEROISMO al caleo",
        "IMPORTANTE: Tomar distancia = No marcas // Aniquilar bestias sin que los toquen = Libra no se cura"
    },
    ["PANZACHANCRO"] = {
        "MAIN TANK absorbe 9 marcas y cambia // Ranged a /range 12 para no vomitarse // Juntar desde SEGUNDA espora // DOBLE ESPORA EN CUERPO A CUERPO O DOBLE EN RANGED: Una espora se reune con el grupo que no tenga",
        "ATENCIÓN: Acumular 3 esporas o daño masivo en explosión de gas"
    },
    ["CARAPUTREA"] = {
        "MAIN TANK siempre frente al BOSS // Banda siempre detrás del boss // Unir 2xMOCOS PEQUEÑO al costado // SIN DAÑO DE ÁREA CON MOCO GRANDE CERCA // OFF mocos grandes // Deben alejarse del boss al momento de la explosión de anublo"
    },
    ["PROFESOR PUTRICIDIO"] = {
        "Fase 1: 100% a 80% // LADO DERECHO DE LA SALA // No dispel sobre ABOMINACIÓN // Si Imbuir y Rejuvenecer // ABO limpia charcos y vomita mocos // Parar DPS antes de cada moco // Marcado por moco naranja corre al caleo",
        "Fase 2: 80% a 35% // BOTELLAS sobre la pared y separan mínimo 10 metros // Esquivan maleables",
        "Fase 3: 35% a 0% // Máximo DPS // HEROISMO // TANQUES cambian boss a DOS dosis de PESTE MUTADA: una vez los tanks tengan 2 dosis, tendrán que rotar de nuevo tomando 1 dosis más en cada rotación hasta 4 dosis. Si cualquiera de los tanks adquiere 5 dosis, el daño en raid será masivo."
    },
    ["REINA DE SANGRE LANA'THEL"] = {
        "MAIN TANK sobre escaleras // OFF Tank cerca para espejo // Cuerpo a cuerpo a máximo rango posible // Sombras a la pared lejos del centro // Unir PACTO rápidamente // Rotar MORDIDA rápido entre los mayores DPS",
        "TERROR: antifear sacerdote y comparte paladín // TODOS mitigan con escudos"
    },
    ["VALITHRIA DREAMWALKER"] = {
        "Minimizar daño en banda // Full Heal sobre Valithria // Tomar Portales de Pesadilla para amplificar con Nubes oníricas",
        "PRIORIDAD: // 1 Esqueleto Ardiente // 2 Supresor // 3 Archimago resucitado // 4 Zombie Virulento // 5 Abominación glotona // Tanques atentos para agrear todo y llevarlo lejos de Valithria",
        "SOLO Cazador pega y mata Zombies Virulentos lejos de la raid // Limpiar enfermedades en todo momento"
    },
    ["CONCEJO DE PRINCIPES DE SANGRE"] = {
        "Main Tank gemelos // OFF Tank Keleseth y agrea Núcleos Oscuros (Mínimo 3) // DPS Cuerpo a Cuerpo se retiran al fondo en cada vórtice // Hunters y Locks mantienen cinéticas arriba",
        "Ranged toman distancia durante vórtices y se mantienen en grupo para mitigar daño // Atentos a cada cambio de príncipe"
    },
    ["SINDRAGOSA"] = {
        "Main tank BOSS // OFF y DPS cuidan marcas: Máximo 6 // Re-agruparse sobre escaleras con defensivos // Tumbas de Hielo según nombres: 1 y 2 Izquierda // 3 centro // 4 y 5 Derecha // A un metro en frente del primer escalón",
        "Columnear sin pegar hasta 4to impacto // SEGUNDA FASE: marcados primero Izquierda luego centro // HEROISMO al caleo // Cambio de tanque"
    },
    ["LICK KING"] = {
        "MAIN TANK LK // OFF HORRORES // Limpiar de inmediato cada Peste // Atacar HORROR al caleo hasta 15% // Faseo en borde exterior // Full Redi en ESPÍRITUS // Hunter ORBES // TODOS Capa de LK // PROFANAR a los costados SIN SALTAR",
        "Stun VALKIR en cada spawn // Retri ESCUDO DIVINO al caleo para FANTASMAS // Shadow DISPERSIÓN al caleo para FANTASMAS"
    }
}
primaryRoles = {{
    name = "MAIN TANK",
    icon = "Interface\\Icons\\Ability_Warrior_DefensiveStance"
}, {
    name = "OFF TANK",
    icon = "Interface\\Icons\\Ability_Warrior_OffensiveStance"
}, {
    name = "HEALER 1",
    icon = "Interface\\Icons\\Spell_Holy_HolyBolt"
}, {
    name = "HEALER 2",
    icon = "Interface\\Icons\\Spell_Holy_FlashHeal"
}, {
    name = "HEALER 3",
    icon = "Interface\\Icons\\Spell_Holy_GreaterHeal"
}, {
    name = "HEALER 4",
    icon = "Interface\\Icons\\Spell_Holy_Renew"
}, {
    name = "HEALER 5",
    icon = "Interface\\Icons\\Spell_Holy_Heal02"
}}
primaryBuffs = {{
    name = "REZOS DE ESPIRITU, PROTECCION Y ENTEREZA",
    icon = "Interface\\Icons\\Spell_Holy_PrayerofSpirit"
}, {
    name = "DON DE LO SALVAJE",
    icon = "Interface\\Icons\\Spell_Nature_Regeneration"
}, {
    name = "SALVAGUARDA",
    icon = "Interface\\Icons\\spell_holy_greaterblessingofsanctuary"
}, {
    name = "REYES",
    icon = "Interface\\Icons\\Spell_Magic_GreaterBlessingofKings"
}, {
    name = "PODERIO",
    icon = "Interface\\Icons\\spell_holy_greaterblessingofkings"
}, {
    name = "SABIDURIA",
    icon = "Interface\\Icons\\spell_holy_greaterblessingofwisdom"
}, {
    name = "VIGILANCIA",
    icon = "Interface\\Icons\\Ability_Warrior_Vigilance"
}, {
    name = "GRITO DE ORDEN",
    icon = "Interface\\Icons\\Ability_Warrior_RallyingCry"
}, {
    name = "GRITO DE BATALLA",
    icon = "Interface\\Icons\\Ability_Warrior_BattleShout"
}, {
    name = "GRITO DESMORALIZADOR",
    icon = "Interface\\Icons\\Ability_Warrior_WarCry"
}, {
    name = "ENFOCAR",
    icon = "Interface\\Icons\\spell_arcane_studentofmagic"
}, {
    name = "TOTEM DE CORRIENTE DE SANACION",
    icon = "Interface\\Icons\\inv_spear_04"
}}
primarySkills = {{
    name = "HEROISMO",
    icon = "Interface\\Icons\\ability_shaman_heroism"
}, {
    name = "DESACTIVAR TRAMPA",
    icon = "Interface\\Icons\\spell_shadow_grimward"
}, {
    name = "SECRETOS DEL OFICIO",
    icon = "Interface\\Icons\\Ability_Rogue_TricksOftheTrade"
}, {
    name = "REDIRECCION",
    icon = "Interface\\Icons\\Ability_Hunter_Misdirection"
}, {
    name = "TRAMPA DE ESCARCHA",
    icon = "Interface\\Icons\\Spell_Frost_ChainsOfIce"
}, {
    name = "COLERA SAGRADA",
    icon = "Interface\\Icons\\Spell_Holy_Excorcism"
}, {
    name = "POLIMORFIA",
    icon = "Interface\\Icons\\Spell_Nature_Polymorph"
}, {
    name = "CICLON",
    icon = "Interface\\Icons\\Ability_Druid_Cyclone"
}, {
    name = "RAICES ENREDADORAS",
    icon = "Interface\\Icons\\Spell_Nature_StrangleVines"
}, {
    name = "AHUYENTAR EL MAL",
    icon = "Interface\\Icons\\Spell_Holy_TurnUndead"
}, {
    name = "TIFON",
    icon = "Interface\\Icons\\Ability_Druid_Typhoon"
}, {
    name = "CADENAS DE HIELO",
    icon = "Interface\\Icons\\Spell_Frost_ChainsOfIce"
}, {
    name = "ENCADENAR NO MUERTO",
    icon = "Interface\\Icons\\Spell_Nature_Slow"
}, {
    name = "ATRACCION LETAL",
    icon = "Interface\\Icons\\spell_deathknight_strangulate"
}, {
    name = "MAESTRIA EN AURAS",
    icon = "Interface\\Icons\\Spell_Holy_AuraMastery"
}, {
    name = "IMPOSICION DE MANOS",
    icon = "Interface\\Icons\\Spell_Holy_LayOnHands"
}, {
    name = "MANO DE SACRIFICIO",
    icon = "Interface\\Icons\\Spell_Holy_SealOfSacrifice"
}, {
    name = "MANO DE LIBERTAD",
    icon = "Interface\\Icons\\Spell_Holy_SealOfValor"
}, {
    name = "DISPERSION",
    icon = "Interface\\Icons\\spell_shadow_dispersion"
}, {
    name = "PIEDRA DE ALMA",
    icon = "Interface\\Icons\\Spell_Shadow_SoulGem"
}, {
    name = "TOTEM DE NEXO TERRESTRE",
    icon = "Interface\\Icons\\spell_nature_strengthofearthtotem02"
}}
secondaryRoles = {{
    name = "FRAGMENTADOR",
    icon = "Interface\\Icons\\Ability_Warrior_Riposte"
}, {
    name = "ABOMINACION",
    icon = "Interface\\Icons\\Spell_Shadow_AbominationExplosion"
}, {
    name = "TANQUE DUAL AUXILIAR",
    icon = "Interface\\Icons\\Ability_Warrior_DefensiveStance"
}, {
    name = "HEALER DUAL AUXILIAR",
    icon = "Interface\\Icons\\Spell_Holy_GuardianSpirit"
}, {
    name = "RESUCITAR CAIDOS",
    icon = "Interface\\Icons\\Spell_Shadow_AnimateDead"
}, {
    name = "RITUAL DE INVOCACION",
    icon = "Interface\\Icons\\Spell_Shadow_Twilight"
}, {
    name = "RITUAL DE REFRIGERIO",
    icon = "Interface\\Icons\\spell_arcane_massdispel"
}}
mainOptions = {"Habilidades principales", "Roles principales", "BUFFs", "Roles secundarios", "RaidDominion Tools"}
addonOptions = {"Reglas", "Mecanicas","Revisar banda","Sorteo de hermandad","Ayuda", "Recargar", "Ocultar"}
barItems = {{
    name = "Modo de raid",
    icon = "Interface\\Icons\\inv_misc_coin_09"
}, {
    name = "Indicar discord",
    icon = "Interface\\Icons\\inv_letter_17"
}, {
    name = "Nombrar objetivo",
    icon = "Interface\\Icons\\ability_hunter_beastcall"
}, {
    name = "Marcar principales",
    icon = "Interface\\Icons\\ability_hunter_markedfordeath"
}, {
    name = "Susurrar asignaciones",
    icon = "Interface\\Icons\\ability_paladin_beaconoflight"
}, {
    name = "Iniciar Check",
    icon = "Interface\\Icons\\ability_paladin_swiftretribution"
}, {
    name = "Iniciar Pull",
    icon = "Interface\\Icons\\ability_hunter_readiness"
}, {
    name = "Cambiar Botin",
    icon = "Interface\\Icons\\inv_box_02"
}}

local currentPlayers = {}
addonCache = {}
local isMasterLooter = false
toExport = {}
