--[[
    RD_Constants.lua
    PROPÓSITO: Contiene constantes globales utilizadas en todo el addon.
    DEPENDENCIAS: Ninguna
    API PÚBLICA: Constantes globales accesibles a través de RaidDominion.constants
    EVENTOS: Ninguno
    INTERACCIONES: Todos los módulos que necesiten valores constantes
]]

if not RaidDominion then return end

RaidDominion.constants = {
    -- Versión y metadatos
    VERSION = "2.0.0",
    AUTHOR = "Andres Muñoz",
    WEBSITE = "https://colmillo.netlify.app/",

    -- Tamaños y dimensiones
    SIZES = {
        -- Main Frame
        MAIN_FRAME = {
            WIDTH = 200,
            HEIGHT = 320,
            BORDER_OFFSET = 1,       -- For the border around the main frame
            TITLE_OFFSET = -12,      -- Y offset for the title
            CLOSE_BUTTON_OFFSET = -3 -- Offset for the close button from the edges
        },
    },

    -- Definiciones de menús
    MENU_DEFINITIONS = {
        MainFrameOptions = {
            {
                name = "Habilidades",
                action = "ShowSkills",
                tooltip = "Gestionar habilidades del grupo"
            },
            {
                name = "Roles",
                action = "Roles",
                tooltip = "Gestionar roles del grupo"
            },
            {
                name = "Buffs",
                action = "ShowBuffs",
                tooltip = "Gestionar buffs del grupo"
            },
            {
                name = "Auras",
                action = "ShowAuras",
                tooltip = "Gestionar auras del grupo"
            },
            {
                name = "Reglas",
                action = "ShowRaidRules",
                tooltip = "Reglas de banda"
            },
            {
                name = "Mecánicas",
                action = "ShowBossMechanics",
                tooltip = "Mecánicas de los jefes"
            },
            {
                name = "RaidDominion",
                action = "ShowRaidDominion",
                tooltip = "Opciones de Raid Dominion",
                submenu = "addonOptions"
            },
            {
                name = "Hermandad",
                action = "ShowGuild",
                tooltip = "Herramientas de hermandad",
                submenu = "guildOptions"
            }
        },
        addonOptions = {
            { name = "Ayuda",    action = "ShowHelp",      tooltip = "Mostrar ayuda del addon" },
            { name = "Recargar", action = "ReloadUI",      tooltip = "Recargar la interfaz" },
            { name = "Ocultar",  action = "HideMainFrame", tooltip = "Ocultar menu principal" }
        },
        guildOptions = {
            { name = "Mensajes",       action = "GuildMessages",      tooltip = "Mensajes de hermandad" },
            { name = "Sorteo",         action = "GuildLottery",       tooltip = "Sorteo/azar" },
            { name = "Lista",          action = "GuildRoster",        tooltip = "Guardar lista de miembros" },
            { name = "Composicion",    action = "GuildComposition",   tooltip = "Ver composición" },
            { name = "Gearscore",      action = "ShowGuildGearscore", tooltip = "Lista de jugadores con Gearscore y notas" },
            { name = "Core",           action = "ShowCoreBands",      tooltip = "Bandas Core" },
            { name = "Reconocimiento", action = "ShowRecognition",    tooltip = "Reconocimiento de hermandad" },
            { name = "Minijuego",      action = "ShowMinigame",       tooltip = "Minijuego de hermandad (Baúles)",         submenu = "minigameOptions" },
            { name = "Jugador",        action = "SearchGuildPlayer",  tooltip = "Buscar y editar jugador" }
        },
        minigameOptions = {
            { name = "Baúles", action = "StartMinigameChest", tooltip = "Juego de baúles en parejas (Pares/Nones)" },
        },
        recognition = {
            { name = "Crear Nuevo", action = "RecognitionCreate", icon = "Interface/Icons/Spell_ChargePositive" },
            { name = "Compartir",   action = "RecognitionShare",  icon = "Interface/Icons/Spell_Arcane_StudentOfMagic" },
        }
    },

    -- Datos de roles para la pestaña de configuración
    ROLE_DATA = {
        {
            name = "MAIN TANK",
            icon = "Interface\\Icons\\Ability_Warrior_DefensiveStance",
        },
        {
            name = "OFF TANK",
            icon = "Interface\\Icons\\Ability_Warrior_OffensiveStance",
        },
        {
            name = "HEALER 1",
            icon = "Interface\\Icons\\Spell_Holy_HolyBolt",
        },
        {
            name = "HEALER 2",
            icon = "Interface\\Icons\\Spell_Holy_FlashHeal",
        },
        {
            name = "HEALER 3",
            icon = "Interface\\Icons\\Spell_Holy_GreaterHeal",
        },
        {
            name = "HEALER 4",
            icon = "Interface\\Icons\\Spell_Holy_Renew",
        },
        {
            name = "HEALER 5",
            icon = "Interface\\Icons\\Spell_Holy_Heal02",
        },
        {
            name = "FRAGMENTADOR",
            icon = "Interface\\Icons\\Ability_Warrior_Riposte",
        },
        {
            name = "ABOMINACION",
            icon = "Interface\\Icons\\Spell_Shadow_AbominationExplosion",
        },
        {
            name = "SANGRES",
            icon = "Interface\\Icons\\Ability_Warrior_DefensiveStance",
        },
        {
            name = "TANQUE DUAL AUXILIAR",
            icon = "Interface\\Icons\\Ability_Warrior_DefensiveStance",
        },
        {
            name = "HEALER DUAL AUXILIAR",
            icon = "Interface\\Icons\\Spell_Holy_GuardianSpirit",
        },
    },

    -- Datos de habilidades, buffs y auras
    SPELL_DATA = {
        abilities = {
            -- SHAMAN
            { name = "HEROISMO",                icon = "Interface\\Icons\\ability_shaman_heroism" },

            -- HUNTER
            { name = "REDIRECCION",             icon = "Interface\\Icons\\Ability_Hunter_Misdirection" },
            { name = "TRAMPA DE ESCARCHA",      icon = "Interface\\Icons\\Spell_Frost_ChainsOfIce" },
            { name = "MARCA DEL CAZADOR",       icon = "Interface\\Icons\\Ability_Hunter_SniperShot" },

            -- ROGUE
            { name = "DESACTIVAR TRAMPA",       icon = "Interface\\Icons\\spell_shadow_grimward" },
            { name = "SECRETOS DEL OFICIO",     icon = "Interface\\Icons\\Ability_Rogue_TricksOftheTrade" },

            -- PRIEST
            { name = "REZO DE SANACIÓN",        icon = "Interface\\Icons\\Spell_Holy_PrayerOfHealing02" },
            { name = "PENITENCIA",              icon = "Interface\\Icons\\Spell_Holy_Penance" },
            { name = "DISPERSION",              icon = "Interface\\Icons\\spell_shadow_dispersion" },

            -- DRUID
            { name = "CICLON",                  icon = "Interface\\Icons\\Ability_Druid_Cyclone" },
            { name = "RAICES ENREDADORAS",      icon = "Interface\\Icons\\Spell_Nature_StrangleVines" },
            { name = "REJUVENECIMIENTO",        icon = "Interface\\Icons\\Spell_Nature_Rejuvenation" },
            { name = "CRECIMIENTO SALVAJE",     icon = "Interface\\Icons\\Ability_Druid_Flourish" },
            { name = "TOQUE DE SANACIÓN",       icon = "Interface\\Icons\\Spell_Nature_HealingTouch" },

            -- PALADIN
            { name = "MAESTRIA EN AURAS",       icon = "Interface\\Icons\\Spell_Holy_AuraMastery" },
            { name = "ESCUDO SAGRADO",          icon = "Interface\\Icons\\Ability_Paladin_ShieldoftheRighteous" },
            { name = "MANO DE SACRIFICIO",      icon = "Interface\\Icons\\Spell_Holy_SealOfSacrifice" },
            { name = "MARTILLO DE JUSTICIA",    icon = "Interface\\Icons\\Spell_Holy_SealOfMight" },
            { name = "COLERA SAGRADA",          icon = "Interface\\Icons\\Spell_Holy_Excorcism" },
            { name = "AHUYENTAR EL MAL",        icon = "Interface\\Icons\\Spell_Holy_TurnUndead" },
            { name = "MANO DE LIBERTAD",        icon = "Interface\\Icons\\Spell_Holy_SealOfValor" },
            { name = "IMPOSICION DE MANOS",     icon = "Interface\\Icons\\Spell_Holy_LayOnHands" },
            { name = "ESCUDO DIVINO",           icon = "Interface\\Icons\\Spell_Holy_DivineShield" },

            -- DEATHKNIGHT
            { name = "GOLPE DE LA PLAGA",       icon = "Interface\\Icons\\Spell_DeathKnight_PlagueStrike" },
            { name = "HERVOR DE SANGRE",        icon = "Interface\\Icons\\Spell_DeathKnight_BloodBoil" },
            { name = "MUERTE Y DESCOMPOSICIÓN", icon = "Interface\\Icons\\Spell_DeathKnight_DeathAndDecay" },
            { name = "CADENAS DE HIELO",        icon = "Interface\\Icons\\Spell_DeathKnight_ChainsOfIce" },
            { name = "GOLPE HELADO",            icon = "Interface\\Icons\\Spell_DeathKnight_IcyTouch" },
            { name = "ATRACCION LETAL",         icon = "Interface\\Icons\\spell_deathknight_strangulate" },

            -- MAGE
            { name = "ESCUDO DE MANÁ",          icon = "Interface\\Icons\\Spell_Shadow_DetectLesserInvisibility" },
            {
                name = "RESUCITAR CAIDOS",
                icon = "Interface\\Icons\\Spell_Shadow_AnimateDead",
            },
            {
                name = "RITUAL DE INVOCACION",
                icon = "Interface\\Icons\\Spell_Shadow_Twilight",
            },
            {
                name = "RITUAL DE REFRIGERIO",
                icon = "Interface\\Icons\\spell_arcane_massdispel",
            },
        },

        buffs = {
            -- PALADIN
            { name = "REYES",                                    icon = "Interface\\Icons\\Spell_Magic_MageArmor" },
            { name = "PODERÍO",                                  icon = "Interface\\Icons\\Spell_Holy_FistOfJustice" },
            { name = "SABIDURÍA",                                icon = "Interface\\Icons\\Spell_Holy_SealOfWisdom" },
            { name = "SALVAGUARDA",                              icon = "Interface\\Icons\\spell_holy_greaterblessingofsanctuary" },

            -- DRUID
            { name = "DON DE LO SALVAJE",                        icon = "Interface\\Icons\\Spell_Nature_Regeneration" },

            -- PRIEST
            { name = "REZOS DE ESPIRITU, PROTECCION Y ENTEREZA", icon = "Interface\\Icons\\Spell_Holy_PrayerofSpirit" },

            -- WARLOCK
            { name = "PIEDRA DE ALMA",                           icon = "Interface\\Icons\\Spell_Shadow_SoulGem" },

            -- WARRIOR
            { name = "GRITO DE BATALLA",                         icon = "Interface\\Icons\\Ability_Warrior_BattleShout" },
            { name = "VIGILANCIA",                               icon = "Interface\\Icons\\Ability_Warrior_Vigilance" },
            { name = "GRITO DE ORDEN",                           icon = "Interface\\Icons\\Ability_Warrior_RallyingCry" },
            { name = "GRITO DESMORALIZADOR",                     icon = "Interface\\Icons\\Ability_Warrior_WarCry" },

            -- MAGE
            { name = "INTELECTO ARCANO",                         icon = "Interface\\Icons\\Spell_Holy_MagicalSentry" },
            { name = "AMPLIFICAR MAGIA",                         icon = "Interface\\Icons\\Spell_Holy_FlashHeal" },
            { name = "ATENUAR MAGIA",                            icon = "Interface\\Icons\\Spell_Nature_AbolishMagic" },
            { name = "ENFOCAR",                                  icon = "Interface\\Icons\\spell_arcane_studentofmagic" },
        },

        auras = {
            -- PALADIN
            { name = "AURA DE DEVOCIÓN",                     icon = "Interface\\Icons\\Spell_Holy_DevotionAura" },
            { name = "AURA DE RETRIBUCIÓN",                  icon = "Interface\\Icons\\Spell_Holy_AuraOfLight" },
            { name = "AURA DE CONCENTRACIÓN",                icon = "Interface\\Icons\\Spell_Holy_MindSooth" },
            { name = "AURA DE CRUZADO",                      icon = "Interface\\Icons\\Spell_Holy_CrusaderAura" },

            -- DEATHKNIGHT
            { name = "PRESENCIA DE ESCARCHA",                icon = "Interface\\Icons\\Spell_Deathknight_FrostPresence" },
            { name = "PRESENCIA DE SANGRE",                  icon = "Interface\\Icons\\Spell_Deathknight_BloodPresence" },
            { name = "PRESENCIA PROFANA",                    icon = "Interface\\Icons\\Spell_Deathknight_UnholyPresence" },

            -- SHAMAN
            { name = "TÓTEM CORRIENTE DE SANACIÓN",          icon = "Interface\\Icons\\INV_Spear_04" },
            { name = "TÓTEM MAREA DE MANÁ",                  icon = "Interface\\Icons\\Spell_Frost_SummonWaterElemental" },
            { name = "TÓTEM FUERZA DE LA TIERRA",            icon = "Interface\\Icons\\Spell_Nature_EarthBindTotem" },
            { name = "TÓTEM PIEL DE PIEDRA",                 icon = "Interface\\Icons\\Spell_Nature_StoneSkinTotem" },
            { name = "TÓTEM VIENTO FURIOSO",                 icon = "Interface\\Icons\\Spell_Nature_Windfury" },
            { name = "TÓTEM CÓLERA DEL AIRE",                icon = "Interface\\Icons\\Spell_Nature_SkinofEarth" },
            { name = "TÓTEM LENGUA DE FUEGO",                icon = "Interface\\Icons\\Spell_Fire_FlameTounge" },
            { name = "TÓTEM TEMBLOR",                        icon = "Interface\\Icons\\Spell_Nature_TremorTotem" },
            { name = "TÓTEM DE RESISTENCIA A LA NATURALEZA", icon = "Interface\\Icons\\Spell_Nature_NatureResistanceTotem" },
            { name = "TÓTEM DE RESISTENCIA A LAS SOMBRAS",   icon = "Interface\\Icons\\Spell_Shadow_SealOfKings" },

            -- HUNTER
            { name = "ASPECTO DEL HALCÓN",                   icon = "Interface\\Icons\\Spell_Nature_RavenForm" },
            { name = "ASPECTO DEL GUEPARDO",                 icon = "Interface\\Icons\\Ability_Mount_JungleTiger" },
            { name = "ASPECTO DE LA MANADA",                 icon = "Interface\\Icons\\Ability_Mount_WhiteDireWolf" }
        }
    },

    -- Configuración de la barra de acciones
    ACTION_BAR = {
        HEIGHT = 30,
        BUTTON_SIZE = 27,
        BUTTON_PADDING = 2,
        ITEMS = {
            {
                name = "Modo de raid",
                icon = "Interface\\Icons\\inv_misc_coin_09",
                tooltip = "Clic Izquierdo: Cambiar modo de raid\nClic Derecho: solicitar asignaciones del lider"
            },
            {
                name = "Indicar discord",
                icon = "Interface\\Icons\\inv_letter_17",
                tooltip = "Clic Izquierdo: Enviar link de discord\nClic Derecho: Editar link de discord"
            },
            {
                name = "Nombrar objetivo",
                icon = "Interface\\Icons\\ability_hunter_beastcall",
                tooltip = "Clic Izquierdo: Nombrar objetivo\nClic Derecho: Ver info de objetivo"
            },
            {
                name = "Marcar principales",
                icon = "Interface\\Icons\\ability_hunter_markedfordeath",
                tooltip = "Clic Izquierdo: Marcar principales y alertar\nClic Derecho: Limpiar marcas de banda"
            },
            {
                name = "Susurrar asignaciones",
                icon = "Interface\\Icons\\ability_paladin_beaconoflight",
                tooltip = "Clic Izquierdo: Susurrar asignaciones a la banda"
            },
            {
                name = "Iniciar Check",
                icon = "Interface\\Icons\\ability_paladin_swiftretribution",
                tooltip = "Clic Izquierdo: Realizar Ready Check\nClic Derecho: Reportar jugadores ausentes"
            },
            {
                name = "Iniciar Pull",
                icon = "Interface\\Icons\\ability_hunter_readiness",
                tooltip = "Clic Izquierdo/Derecho: Iniciar cuenta regresiva de Pull"
            },
            {
                name = "Cambiar Botín",
                icon = "Interface\\Icons\\inv_box_02",
                tooltip = "Clic Izquierdo: Cambiar método de botín\nClic Derecho: Asignar Maestro Despojador al objetivo"
            },
            {
                name = "Configuración",
                icon = "Interface\\Icons\\INV_Gizmo_02",
                tooltip = "Clic Izquierdo: Abrir panel de configuración"
            }
        }
    },

    RAID_MECHANICS = {
        ["LA CAMARA DE ARCHAVON"] = {
            "Tanques intercambian cada 4 marcas // DPS destruyen orbes totalmente y continuan con boss",
        },
        ["TUETANO"] = {
            "Tanques derecha // Grupo detrás y debajo del boss // Hunters izquierda // HEROISMO de entrada // DESTRUIR púas de inmediato // RANGED destruyen púas lejanas al grupo // Evitar trazos de fuego",
            "Maestría y defensivos durante tormentas // Tanques retoman boss cerca de escaleras",
        },
        ["LADY DEATHWISPER"] = {
            "TODOS fondo a la derecha // Tanques juntan agro adds // DPS áreas sobre adds // Evitar áreas de daño // CADENAS y CICLÓN sobre aliado controlado // Evitar tocar fantasmas y llevarlos lejos del grupo",
        },
        ["BARCOS"] = {
            "MAIN TANK SOLO por su lado // DPS lado contrario // Evitar ser rajados // Cañones entre 87~100% del poder de ataque antes de ataque especial // DESTRUIR mago y regresar por el mismo lado // Cañones terminan el trabajo",
            "Esperar en terraza de libra, nadie abra el cofre de loot o perderá todo loteo",
        },
        ["LIBRA"] = {
            "TANQUES bajo escaleras atentos a marcas // Cuerpo a cuerpo sobre escaleras // Ranged a /range 12 evitan marcas // Trampa de Escarcha a mi señal // Marcados no atacan bestias // HEROISMO a mi señal",
            "IMPORTANTE: Tomar distancia = No marcas // Aniquilar bestias sin que los toquen = Libra no se cura",
        },
        ["PANZACHANCRO"] = {
            "MAIN TANK absorbe 9 marcas y cambia // Ranged a /range 12 para no vomitarse // Juntar desde SEGUNDA espora // DOBLE ESPORA EN CUERPO A CUERPO O DOBLE EN RANGED: Una espora se reune con el grupo que no tenga",
            "ATENCIÓN: Acumular 3 esporas o daño masivo en explosión de gas",
        },
        ["CARAPUTREA"] = {
            "MAIN TANK siempre frente al BOSS // Banda siempre detrás del boss // Unir 2xMOCOS PEQUEÑO al costado // SIN DAÑO DE ÁREA CON MOCO GRANDE CERCA // OFF mocos grandes // Deben alejarse del boss al momento de la explosión de anublo",
        },
        ["PROFESOR PUTRICIDIO"] = {
            "Fase 1: 100% a 80% // LADO DERECHO DE LA SALA // No dispel sobre ABOMINACIÓN // Si Imbuir y Rejuvenecer // ABO limpia charcos y vomita mocos // Parar DPS antes de cada moco // Marcado por moco naranja corre al caleo",
            "Fase 2: 80% a 35% // BOTELLAS sobre la pared y separan mínimo 10 metros // Esquivan maleables",
            "Fase 3: 35% a 0% // Máximo DPS // HEROISMO // TANQUES cambian boss a DOS dosis de PESTE MUTADA: una vez los tanks tengan 2 dosis, tendrán que rotar de nuevo tomando 1 dosis más en cada rotación hasta 4 dosis. Si cualquiera de los tanks adquiere 5 dosis, el daño en raid será masivo.",
        },
        ["CONCEJO DE PRINCIPES DE SANGRE"] = {
            "Main Tank gemelos // OFF Tank Keleseth y agrea Núcleos Oscuros (Mínimo 3) // DPS Cuerpo a Cuerpo se retiran al fondo en cada vórtice // Hunters y Locks mantienen cinéticas arriba",
            "Ranged toman distancia durante vórtices y se mantienen en grupo para mitigar daño // Atentos a cada cambio de príncipe",
        },
        ["REINA DE SANGRE LANA'THEL"] = {
            "MAIN TANK sobre escaleras // OFF Tank cerca para espejo // Cuerpo a cuerpo a máximo rango posible // Sombras a la pared lejos del centro // Unir PACTO rápidamente // Rotar MORDIDA rápido entre los mayores DPS",
            "TERROR: antifear sacerdote y comparte paladín // TODOS mitigan con escudos",
        },
        ["VALITHRIA DREAMWALKER"] = {
            "Minimizar daño en banda // Full Heal sobre Valithria // Tomar Portales de Pesadilla para amplificar con Nubes oníricas",
            "PRIORIDAD: // 1 Esqueleto Ardiente // 2 Supresor // 3 Archimago resucitado // 4 Zombie Virulento // 5 Abominación glotona // Tanques atentos para agrear todo y llevarlo lejos de Valithria",
            "SOLO Cazador pega y mata Zombies Virulentos lejos de la raid // Limpiar enfermedades en todo momento",
        },
        ["SINDRAGOSA"] = {
            "Main tank BOSS // OFF y DPS cuidan marcas: Máximo 6 // Re-agruparse sobre escaleras con defensivos // Tumbas de Hielo según nombres: 1 y 2 Izquierda // 3 centro // 4 y 5 Derecha // A un metro en frente del primer escalón",
            "Columnear sin pegar hasta 4to impacto // SEGUNDA FASE: marcados primero Izquierda luego centro // HEROISMO al caleo // Cambio de tanque",
        },
        ["LICK KING"] = {
            "MAIN TANK LK // OFF HORRORES // Limpiar Peste junto al tank OFF // Faseo en borde exterior // Full Redi en ESPÍRITUS // Hunter ORBES // En faseo TODOS Capa de LK // PROFANAR a los costados SIN SALTAR",
            "Stun VALKIR en cada spawn // Retri ESCUDO DIVINO al caleo para FANTASMAS // Shadow DISPERSIÓN al caleo para FANTASMAS",
        },
    },

    RAID_RULES = {
        ["LA CAMARA DE ARCHAVON"] = { "BOTIN => PVE: Por función MAIN // PVP: Por clase" },
        ["RAID DOMINION"] = { "Addon para asignación de roles en raid, administración de cores privados, eventos y gestión de hermandad. // Descarga y uso del addon // Portal: https://colmillo.netlify.app/ " },
        ["POSADA"] = { "Se esta buscando por posada // Conocidos interesados que WISP" },
        ["REVISO Y REEMPLAZO"] = {
            "AFK/OFFs sin avisar // No respetar pulls/mecanincas = No botin/Kick // DPS/Heal con bajo rendimiento = Kick // PVP = Kick",
        },
        ["BOTIN"] = {
            "No DC = No Botin // Se rollea 20 minutos antes del ligado del item o al dar Raid Off en el orden que fue obtenido.",
        },
        ["ICC 10 N"] = { "PRIORIDAD DE LOTEO: Por función MAIN > DUAL." },
        ["ICC 25 N"] = {
            "PRIORIDAD DE LOTEO: Por función MAIN > DUAL. // MARCAS: Debe linkear 1 t10 engemado/encantado. // ABACO: top3 cerrado  en Reina. // TARRO: top5 daño en Panza cerrado + 5% en bestias, rollea paladín retry, pícaro asesinato, mejora.",
            "TESTAMENTO: top5 daño en Panza cerrado + 5% en bestias. Rollean warrior fury, dk profano/escarcha, pícaro combate y druida feral, hunter punteria, mejora. Bajo rendimiento/Inactivo = NoLoot // OBJETO: top5 cerrado daño en Panza + 3% en bestias.",
            "FILACTERIA: top3 cerrado daño en Profe + 10% en mocos. // COLMILLO: prioridad tanques activos en su rol, luego el resto. // Un abalorio, Un arma, Dos marcas por raid. Un ítem por main(excepto tankes), sin limite por dual. Marcas tambien por dual.",
            "RESERVADOS: Fragmentos, Sangres, Items no ligados y Saros. // ARMAS LK: top10 daño en LK + 5% en Valkyrs y top3 conteo de sanacion en LK.",
            "Arma y sostener cuentan como ítem. Solo excentas armas de Lk. Armas 2.6 pueden ser loteadas por tanques. // Si en algun top no necesitan el ítem o no cumplen la regla para lotear, pasará al siguiente en top.",
        },
        ["ICC 10 H"] = { "PRIORIDAD DE LOTEO: Por función MAIN > DUAL. // MARCAS: Debe linkear 1 t10 engemado/encantado." },
        ["Colmillo de Acero"] = { "Recluta jugadores de todo nivel para complementar cores 5k+ de raideo diario. DC BwdpNV9sky. Horarios de raid desde las 18:00 hora server en adelante //  reglas y más en https://colmillo.netlify.app/ ¡Únete ahora! " },
    },

    GUILD_MESSAGES = {
        ["NOTA PUBLICA Y DE OFICIAL"] = {
            "» WISP función y GS al Administrador/Oficial en linea para subir de rango y actualizar su nota.",
            "» Así podrán participar en raideos, sorteos y mostrar detalles de sus personajes en la web.",
            "→ MAS INFORMACIÓN: https://colmillo.netlify.app/ ",
        },
        ["ENLACES DE LA HERMANDAD"] = {
            "» DC: https://discord.gg/BwdpNV9sky ",
            "» WEB: https://colmillo.netlify.app/ ",
            "» WHATSAPP: https://chat.whatsapp.com/BahYOaTMZfHIwYQGey3G91 ",
        },
        ["RAIDS DE HERMANDAD"] = {
            "» Consulten horarios y cores disponibles en nuestra web.",
            "» Se mide experiencia, manejo de clase y mecánicas para futuras raids.",
            "» Registren sus personajes en los core que necesiten o quieran ayudar.",
            "» Jugadores con RaidDominion pueden sincronizar las raids oficiales para mejor manejo durante las raid.",
            "→ https://colmillo.netlify.app/raids",
        },
        ["PRIMERA Y SEGUNDA PESTAÑA DEL BANCO"] = {
            "→ Se reciben donaciones de oro, equipamiento o farm lvl 74+ para sortear y ayudar a la hermandad.",
            "→ Sorteos diarios para rangos Iniciado y superiores.",
            "» WISP función y GS al Administrador/Oficial en linea para subir de rango.",
        },
        ["PESTAÑA DE EQUIPAMIENTO DEL BANCO"] = {
            "» Acceso a los elementos del baul de equipamiento mediante solicitud.",
            "→ DISCORD: kMK2ZRRCza",
            "→ WHATSAPP: https://chat.whatsapp.com/BahYOaTMZfHIwYQGey3G91 ",
        },
        ["RAID DOMINION"] = { "Addon para asignación de roles en raid, administración de cores privados, eventos y gestión de hermandad. // Descarga y uso del addon // Portal: https://colmillo.netlify.app/ " },
    },


    UI_TEXTS = {
        READY_CHECK_PROMPT = "¿Deseas iniciar un check de banda?",
        PULL_TIMER_PROMPT = "Ingresa los segundos para el pull (ej: 10):"
    },

    -- Colores (formato RGBA)
    COLORS = {
        TANK = { 0, 0.5, 1, 1 },     -- Azul
        HEALER = { 0, 1, 0, 1 },     -- Verde
        DAMAGER = { 1, 0, 0, 1 },    -- Rojo
        NORMAL = { 1, 1, 1, 1 },     -- Blanco
        WARNING = { 1, 0.8, 0, 1 },  -- Naranja
        ERROR = { 1, 0, 0, 1 },      -- Rojo
        SUCCESS = { 0, 1, 0, 1 },    -- Verde
        INFO = { 0.5, 0.5, 1, 1 },   -- Azul claro
        BACKGROUND = { 0, 0, 0, 0.8 }, -- Fondo oscuro semi-transparente
        BORDER = { 0, 0, 0, 0 }      -- Sin borde
    },

    -- Configuration settings
    CONFIG = {
        -- Chat channels
        CHAT_CHANNELS = {
            ["DEFAULT"] = "POR DEFECTO",
            ["SYSTEM"] = "SISTEMA",
            ["GUILD"] = "HERMANDAD",
            ["SAY"] = "DECIR",
            ["YELL"] = "GRITAR",
            ["PARTY"] = "GRUPO",
            ["RAID"] = "BANDA",
            ["RAID_WARNING"] = "AVISO DE BANDA",
            ["BATTLEGROUND"] = "CAMPO DE BATALLA",
            ["CHANNEL"] = "CANAL"
        },

        -- Default values
        DEFAULTS = {
            showMinimapButton = true,
            lockWindow = false,
            showRoleIcons = true,
            showTooltips = true
        },

        -- UI Constants
        UI = {
            TAB = {
                WIDTH = 100,
                HEIGHT = 24,
                PADDING = 5,
                FONT = "GameFontNormal"
            },
            CHECKBOX = {
                WIDTH = 24,
                HEIGHT = 24
            },
            DROPDOWN = {
                WIDTH = 180,
                HEIGHT = 24
            }
        }
    },

    -- Help and localization
    LOCALIZATION = {
        HELP = {
            WELCOME = "¡Bienvenido a RaidDominion! Aquí tienes algunos consejos para comenzar:",
            TIP_1 = "1. Navega y regresa por los menús usando click izquierdo y derecho.",
            TIP_2 =
            "2. Usa las pestañas Roles, Buffs, Habilidades y Auras para personalizar las asignaciones que deseas monitorear.",
            TIP_3 = "3. Configura el comportamiento del addon en la pestaña Configuración General."
        },
        TABS = {
            GENERAL = "General",
            ROLES = "Roles",
            BUFFS = "Buffs",
            ABILITIES = "Habilidades",
            AURAS = "Auras",
            HELP = "Ayuda"
        }
    },

    -- Configuración de la jerarquía de la hermandad
    GUILD_HIERARCHY = {
        MESSAGES = {
            NOT_IN_GUILD = "No eres miembro de una hermandad.",
            NO_MEMBERS = "No hay miembros en la hermandad.",
            TITLE = "=== COMPOSICION DE LA HERMANDAD ===",
            RANK_COUNT = "→ %s [%d] + %s [%d] = Organizadores de Hermandad",
            RANK_ENTRY = "→ %s [%d] = %s",
            TOTAL_MEMBERS = "Total: %d miembros (%d en línea, %d desconectados)",
            RANK_DESCRIPTIONS = {
                [3] = "Organizadores de Raid",
                [4] = "Asistencia a raid confiable",
                [5] = "Función y GS claros",
                [6] = "WISP función y GS al GM/Alter/Oficial para subir de rango."
            },
            DEFAULT_RANK_NAME = "Recluta"
        }
    },

    -- Configuración del sorteo de hermandad
    GUILD_LOTTERY = {
        -- Rangos que pueden participar en el sorteo (rankIndex + 1)
        ELIGIBLE_RANKS = { 3, 4, 5 },

        -- Configuración del diálogo
        DIALOG = {
            TITLE = "¿Deseas realizar un sorteo con %s (x%d) del banco de la hermandad?",
            RECOGNIZE_DONATION = "¿Reconocer donación de %s?\n%s",
            BUTTONS = {
                YES = "Sí",
                NO = "No",
                CHOOSE_ANOTHER = "Elegir otro"
            },
            TIMEOUT = 0, -- No se cierra automáticamente
            PREFERRED_INDEX = 3
        },

        -- Mensajes del sistema
        MESSAGES = {
            NOT_IN_GUILD = "No eres miembro de una hermandad.",
            NO_GUILD_BANK_ACCESS = "No tienes permiso para acceder al banco de la hermandad.",
            NO_ELIGIBLE_MEMBERS = "No hay miembros de la hermandad de los rangos 3, 4 y 5 conectados para el sorteo.",
            NO_ITEMS = "No hay ítems en la primera pestaña del banco de la hermandad.",
            NO_TAB_ACCESS = "No tienes permiso para ver esta pestaña del banco de la hermandad.",
            NOT_AUTHORIZED = "Solo los oficiales y el maestro de hermandad pueden iniciar un sorteo.",

            -- Mensajes de reconocimiento
            SCAN_START = "Iniciando escaneo de donaciones para reconocimiento...",
            NO_NEW_DONATIONS = "No se encontraron nuevas donaciones elegibles.",
            THANKS_MESSAGE = "¡Gracias a nuestros Contribuidores Destacados de hoy: %s! Su apoyo hace grande a nuestra hermandad. ¡Sigamos así! 💪✨",
            RECOGNITION_COMPLETE = "Reconocimiento completado. %d jugadores añadidos.",
            RECOGNITION_FINISHED_NONE = "Proceso de reconocimiento finalizado. Ningún contribuidor nuevo añadido.",
            ERROR_DIALOG = "Error: No se pudo mostrar diálogo para %s",

            -- Mensajes del sorteo
            LOTTERY_HEADER = "¡SORTEO DE LA HERMANDAD!",
            LOTTERY_ITEM = "El premio aleatorio de este sorteo es: %s",
            LOTTERY_PARTICIPANTS = "Participan hasta 5 jugadores de los rangos Iniciado y superiores en línea:",
            LOTTERY_DRAWING = "Sorteando...",
            LOTTERY_WINNER = "¡El ganador es [%s] %s! Ha ganado %s",
            LOTTERY_SCORE = "[%s] %s ha obtenido %d puntos",
            LOTTERY_WINNER_SCORE = "[%s] %s ha obtenido el mayor puntaje con %d puntos!",

            -- Mensajes privados al ganador
            WINNER_MESSAGE =
            "¡Ganaste el sorteo! Tu premio es: %s (x%d). Si es util para alguno de tus personajes reclama el premio a un GM/Alter en el Banco Alianza de Dalaran o solicita por el chat de hermandad que se envie a tu correo.",
            WINNER_FOLLOW_UP =
            "Si no deseas reclamar tu premio se guardara para un nuevo sorteo. Gracias por tu continuidad en la hermandad.",

            -- Configuración de sonido
            SOUND_WIN = "Sound\\Interface\\LevelUp.wav"
        },

        -- Configuración del sorteo
        SETTINGS = {
            MAX_PLAYERS = 5, -- Número máximo de jugadores para el sorteo
            MAX_SCORE = 200, -- Puntuación máxima aleatoria
            TAB_INDEX = 1    -- Índice de la pestaña del banco de la hermandad a usar
        }
    },

    -- Configuración de la interfaz de usuario
    UI = {

        -- Tabs
        TABS = {
            WIDTH = 100,
            HEIGHT = 20, -- Altura reducida de las pestañas
            PADDING = 5,
            FONT = "GameFontNormal",
            FONT_SIZE = 12,
            HIGHLIGHT_TEXTURE = "Interface\Buttons\UI-Listbox-Highlight2",
            NORMAL_TEXTURE = "Interface\PaperDollInfoFrame\UI-Character-ActiveTab",
            DISABLED_TEXTURE = "Interface\PaperDollInfoFrame\UI-Character-InActiveTab",

            -- Content area
            CONTENT = {

            },


            -- Sections
            SECTION = {
                PADDING = 20,
                TITLE_FONT = "GameFontNormalLarge",
                TEXT_FONT = "GameFontHighlight",
                TEXT_COLOR = { r = 0.8, g = 0.8, b = 0.8, a = 1 },
                TITLE_COLOR = { r = 1, g = 0.82, b = 0, a = 1 } -- Gold color
            },

        },
    },

    cfg_data = {
        G = "\067\111\108\109\105\108\108\111\032\100\101\032\065\099\101\114\111",
        R = {
            A = "\065\100\109\105\110\105\115\116\114\097\100\111\114",
            O = "\079\102\105\099\105\097\108"
        },
        P = {
            "\086\102\114",
            "\067\115\113",
            "\086\101\114\119\097\108\116\101\114",
            "\084\103\098",
        }
    },

    -- Mensajes de inicialización
    MESSAGES = {
        -- Mensajes de ayuda
        HELP_HEADER = "|cffffff00Comandos disponibles:|r",
        HELP_RD = "|cffffff00/rd|r - Muestra/oculta la ventana principal",
        HELP_RDC = "|cffffff00/rdc|r - Muestra/oculta la configuración",
        HELP_RDH = "|cffffff00/rdh|r - Muestra esta ayuda",
        UNKNOWN_COMMAND = "Comando desconocido. /rdh para ayuda.",

        -- Mensajes de la interfaz
        ADDON_LOADED = "RaidDominion v%s cargado. Escribe /rd para mostrar el menú.",
        MAIN_WINDOW_UNAVAILABLE = "La ventana principal no está disponible en este momento.",
        CONFIG_WINDOW_UNAVAILABLE = "La ventana de configuración no está disponible en este momento.",

        -- Títulos y cabeceras
        ADDON_TITLE = "|cffff8000=== RaidDominion ===|r",
        SEPARATOR = "|cffff8000===================|r"
    },

    -- Comandos de consola
    SLASH_COMMANDS = {
        MAIN = "/rd",
        HELP = "/rdh",
        CONFIG = "/rdc"
    },

    -- Nombres de módulos
    MODULE_NAMES = {
        MAIN = "RaidDominion2",
        EVENTS = "RD_Events",
        CONFIG = "RD_Config",
        MAIN_FRAME = "RD_UI_MainFrame",
        CONFIG_MANAGER = "RD_UI_ConfigManager"
    },

    -- Eventos personalizados
    EVENTS = {
        -- Eventos de interfaz
        UI_SHOW = "RD_UI_SHOW",
        UI_HIDE = "RD_UI_HIDE",
        UI_UPDATE = "RD_UI_UPDATE",

        -- Eventos de configuración
        CONFIG_CHANGED = "RD_CONFIG_CHANGED",

        -- Eventos de menú
        MENU_ITEMS_UPDATED = "RD_MENU_ITEMS_UPDATED",

        -- Eventos de grupo
        GROUP_ROSTER_UPDATE = "GROUP_ROSTER_UPDATE",
        GROUP_JOINED = "GROUP_JOINED",
        GROUP_LEFT = "GROUP_LEFT",

        -- Eventos de combate
        PLAYER_REGEN_DISABLED = "PLAYER_REGEN_DISABLED",
        PLAYER_REGEN_ENABLED = "PLAYER_REGEN_ENABLED",

        -- Eventos de instancia
        ZONE_CHANGED_NEW_AREA = "ZONE_CHANGED_NEW_AREA",
        ZONE_CHANGED = "ZONE_CHANGED",
        ZONE_CHANGED_INDOORS = "ZONE_CHANGED_INDOORS",

        -- Eventos de objetivo
        PLAYER_TARGET_CHANGED = "PLAYER_TARGET_CHANGED",
        UPDATE_MOUSEOVER_UNIT = "UPDATE_MOUSEOVER_UNIT",

        -- Eventos de banda
        RAID_ROSTER_UPDATE = "RAID_ROSTER_UPDATE",
        RAID_TARGET_UPDATE = "RAID_TARGET_UPDATE",

        -- Eventos de banda/instancia
        INSTANCE_GROUP_SIZE_CHANGED = "INSTANCE_GROUP_SIZE_CHANGED",

        -- Eventos de chat
        CHAT_MSG_ADDON = "CHAT_MSG_ADDON",

        -- Eventos de estado
        PLAYER_ENTERING_WORLD = "PLAYER_ENTERING_WORLD",
        PLAYER_LEAVING_WORLD = "PLAYER_LEAVING_WORLD"
    },

    -- Comandos de barra
    SLASH_COMMANDS = {
        MAIN = "/rd",
        HELP = "/rdh",
        CONFIG = "/rdc"
    },

    -- Clases de WoW
    CLASSES = {
        ["WARRIOR"] = { id = 1, color = { 0.78, 0.61, 0.43, 1 } },
        ["PALADIN"] = { id = 2, color = { 0.96, 0.55, 0.73, 1 } },
        ["HUNTER"] = { id = 3, color = { 0.67, 0.83, 0.45, 1 } },
        ["ROGUE"] = { id = 4, color = { 1, 0.96, 0.41, 1 } },
        ["PRIEST"] = { id = 5, color = { 1, 1, 1, 1 } },
        ["DEATHKNIGHT"] = { id = 6, color = { 0.77, 0.12, 0.23, 1 } },
        ["SHAMAN"] = { id = 7, color = { 0, 0.44, 0.87, 1 } },
        ["MAGE"] = { id = 8, color = { 0.25, 0.78, 0.92, 1 } },
        ["WARLOCK"] = { id = 9, color = { 0.53, 0.53, 0.93, 1 } },
        ["DRUID"] = { id = 11, color = { 1, 0.49, 0.04, 1 } }
    },

    -- Estados del jugador
    STATUS = {
        ONLINE = 1,
        OFFLINE = 2,
        AFK = 3,
        DND = 4
    },

    -- Tipos de grupo
    GROUP_TYPES = {
        NONE = 0,
        PARTY = 1,
        RAID = 2,
        BATTLEGROUND = 3
    },

    -- Mapa de clases localizadas a inglés
    CLASS_ENGLISH_MAP = {
        ["GUERRERO"] = "WARRIOR",
        ["WARRIOR"] = "WARRIOR",
        ["PALADÍN"] = "PALADIN",
        ["PALADIN"] = "PALADIN",
        ["CAZADOR"] = "HUNTER",
        ["HUNTER"] = "HUNTER",
        ["PÍCARO"] = "ROGUE",
        ["PICARO"] = "ROGUE",
        ["ROGUE"] = "ROGUE",
        ["SACERDOTE"] = "PRIEST",
        ["PRIEST"] = "PRIEST",
        ["CHAMÁN"] = "SHAMAN",
        ["CHAMAN"] = "SHAMAN",
        ["SHAMAN"] = "SHAMAN",
        ["MAGO"] = "MAGE",
        ["MAGE"] = "MAGE",
        ["BRUJO"] = "WARLOCK",
        ["WARLOCK"] = "WARLOCK",
        ["MONJE"] = "MONK",
        ["MONK"] = "MONK",
        ["DRUIDA"] = "DRUID",
        ["DRUID"] = "DRUID",
        ["CABALLERO_DE_LA_MUERTE"] = "DEATHKNIGHT",
        ["DEATHKNIGHT"] = "DEATHKNIGHT",
        ["CAZADOR_DE_DEMONIOS"] = "DEMONHUNTER",
        ["DEMONHUNTER"] = "DEMONHUNTER"
    },

    CLASS_ORDER = {
        ["GUERRERO"] = 1,
        ["WARRIOR"] = 1,
        ["PALADÍN"] = 2,
        ["PALADIN"] = 2,
        ["CAZADOR"] = 3,
        ["HUNTER"] = 3,
        ["PICARO"] = 4,
        ["ROGUE"] = 4,
        ["SACERDOTE"] = 5,
        ["PRIEST"] = 5,
        ["CHAMAN"] = 6,
        ["SHAMAN"] = 6,
        ["MAGO"] = 7,
        ["MAGE"] = 7,
        ["BRUJO"] = 8,
        ["WARLOCK"] = 8,
        ["DRUIDA"] = 9,
        ["DRUID"] = 9,
        ["CABALLERO_DE_LA_MUERTE"] = 10,
        ["DEATHKNIGHT"] = 10,
    },
}

-- Hacer las constantes accesibles globalmente
local addonName, addonTable = ...
addonTable.constants = RaidDominion.constants
