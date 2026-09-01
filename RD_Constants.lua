--[[
    RD_Constants.lua
    PROPÓSITO: Constantes, definiciones de menú, configuración por defecto y esquema de configuración.
    API PÚBLICA: RaidDominion.constants
    EVENTOS: Ninguno
]]

local addonName, private = ...
local RD = _G.RaidDominion or {}
_G.RaidDominion = RD

-- Helper para ítems de menú cuya visibilidad depende de un flag de config
-- (p.ej. ui.showMechanicsMenu): devuelve una función `enabled` compatible con
-- el filtro de MenuFactory. Semántica `~= false` = visible salvo que se desactive.
local function MenuEnabledByConfig(key, defaultValue)
    return function()
        return (RD.config and RD.config.Get and RD.config:Get(key, defaultValue)) ~= false
    end
end

RD.constants = {
    VERSION = "3.0.0",
    AUTHOR = "Andres Muñoz",
    WEBSITE = "https://colmillo.netlify.app/",

    -- Grid base para el sistema de alineación (ver sección 6 de AGENTS.md)
    GRID = {
        GUTTER = 4,          -- unidad base de espaciado
        MENU_ITEM_HEIGHT = 22,
        MENU_ITEM_GAP = 2,
        MAX_ITEMS_PER_COLUMN = 9,
        MAX_COLUMNS = 5,
        COLUMN_SPACING = 16,
        LABEL_WIDTH = 184,
        BUTTON_SIZE = 20,
    },

    -- Paleta de acento compartida (única fuente de verdad para los colores
    -- del addon: dorado, rojo de error, verde de éxito).
    COLORS = {
        GOLD = { 1, 0.82, 0 },
        RED = { 1, 0, 0 },
        GREEN = { 0, 1, 0 },
    },

    -- Lista curada de iconos para el selector (SOLO texturas válidas de 3.3.5a).
    -- El usuario elige de esta cuadrícula en vez de escribir nombres de textura.
    -- OJO: no incluir iconos de expansiones posteriores (Cata/Legion/etc.) ni
    -- paths inciertos: una textura inexistente se muestra como casilla vacía y
    -- no hay API en 3.3.5a para validar texturas en tiempo de ejecución.
    ICON_PICKER_LIST = {
        "Interface\\Icons\\Ability_Warrior_DefensiveStance",
        "Interface\\Icons\\Ability_Warrior_OffensiveStance",
        "Interface\\Icons\\Spell_Holy_HolyBolt",
        "Interface\\Icons\\Spell_Holy_FlashHeal",
        "Interface\\Icons\\Spell_Holy_GreaterHeal",
        "Interface\\Icons\\Ability_Warrior_Riposte",
        "Interface\\Icons\\Spell_Shadow_AbominationExplosion",
        "Interface\\Icons\\ability_shaman_heroism",
        "Interface\\Icons\\Ability_Hunter_Misdirection",
        "Interface\\Icons\\Spell_Frost_ChainsOfIce",
        "Interface\\Icons\\Spell_Holy_PrayerOfHealing02",
        "Interface\\Icons\\Spell_Holy_Penance",
        "Interface\\Icons\\spell_shadow_dispersion",
        "Interface\\Icons\\Ability_Druid_Cyclone",
        "Interface\\Icons\\Spell_Nature_StrangleVines",
        "Interface\\Icons\\Spell_Nature_Rejuvenation",
        "Interface\\Icons\\Spell_Holy_DivineShield",
        "Interface\\Icons\\Spell_DeathKnight_DeathAndDecay",
        "Interface\\Icons\\Spell_Shadow_SoulGem",
        "Interface\\Icons\\Ability_Warrior_BattleShout",
        "Interface\\Icons\\Spell_Magic_MageArmor",
        "Interface\\Icons\\Spell_Holy_FistOfJustice",
        "Interface\\Icons\\Spell_Holy_SealOfWisdom",
        "Interface\\Icons\\spell_holy_greaterblessingofsanctuary",
        "Interface\\Icons\\Spell_Nature_Regeneration",
        "Interface\\Icons\\Spell_Shadow_AnimateDead",
        "Interface\\Icons\\Spell_Holy_AuraMastery",
        "Interface\\Icons\\Spell_Holy_SealOfSacrifice",
        "Interface\\Icons\\Spell_Holy_SealOfValor",
        "Interface\\Icons\\Spell_Holy_LayOnHands",
        "Interface\\Icons\\Spell_Shadow_DetectLesserInvisibility",
        "Interface\\Icons\\Spell_Shadow_Twilight",
        "Interface\\Icons\\spell_arcane_massdispel",
        "Interface\\Icons\\Spell_DeathKnight_PlagueStrike",
        "Interface\\Icons\\Spell_DeathKnight_BloodBoil",
        "Interface\\Icons\\Spell_DeathKnight_IcyTouch",
        "Interface\\Icons\\spell_deathknight_strangulate",
        "Interface\\Icons\\Ability_Rogue_TricksOftheTrade",
        "Interface\\Icons\\Spell_Nature_HealingTouch",
        "Interface\\Icons\\Spell_Holy_Excorcism",
        "Interface\\Icons\\Spell_Holy_TurnUndead",
        "Interface\\Icons\\Ability_Paladin_BeaconOfLight",
        "Interface\\Icons\\Ability_Shaman_Hex",
        "Interface\\Icons\\Spell_Nature_BloodLust",
        "Interface\\Icons\\Spell_Shadow_Metamorphosis",
        "Interface\\Icons\\Spell_Fire_Fireball",
        "Interface\\Icons\\Spell_Frost_FrostBolt02",
        "Interface\\Icons\\Spell_Arcane_Blink",
        "Interface\\Icons\\Spell_Shadow_LifeDrain",
        "Interface\\Icons\\Spell_Shadow_DeathCoil",
        "Interface\\Icons\\Ability_Hunter_Quickshot",
        "Interface\\Icons\\Ability_Rogue_SinisterStrike",
        "Interface\\Icons\\INV_Misc_QuestionMark",
        "Interface\\Icons\\INV_Misc_Coin_01",
        "Interface\\Icons\\INV_Box_01",
        "Interface\\Icons\\INV_Gizmo_01",
        "Interface\\Icons\\INV_Misc_Map_01",
        "Interface\\Icons\\INV_Letter_01",
    },

    -- Datos de roles para el menú y la configuración
    ROLE_DATA = {
        { name = "MAIN TANK",      icon = "Interface\\Icons\\Ability_Warrior_DefensiveStance" },
        { name = "OFF TANK",       icon = "Interface\\Icons\\Ability_Warrior_OffensiveStance" },
        { name = "HEALER 1",       icon = "Interface\\Icons\\Spell_Holy_HolyBolt" },
        { name = "HEALER 2",       icon = "Interface\\Icons\\Spell_Holy_FlashHeal" },
        { name = "HEALER 3",       icon = "Interface\\Icons\\Spell_Holy_GreaterHeal" },
    },

    -- Roles de jugador dentro de una banda (para el gestor de jugadores).
    -- Cada rol tiene clave estable (minúscula) guardada en `player.role`.
    BAND_ROLE_DATA = {
        { key = "tank",   short = "T", label = "Tanque",  color = { 0.2, 0.6, 1 } },
        { key = "healer", short = "H", label = "Healer",  color = { 0.1, 1, 0.1 } },
        { key = "rango",  short = "R", label = "Rango",   color = { 1, 0.5, 0 } },
        { key = "melee",  short = "M", label = "Melee",   color = { 1, 0.2, 0.2 } },
    },

    -- Causales de sanción de un jugador (columna de sanciones, similar a rol/dual).
    -- "" significa sin sanción. La pestaña "Sancionados" filtra por causal no vacía.
    -- `short` se muestra en la columna; `label` (si existe) es el nombre completo
    -- que se muestra en el tooltip (p.ej. "Engemado/Encantado").
    BAND_SANCTION_DATA = {
        { key = "lag",          short = "Lag",          color = { 1, 0.8, 0 } },
        { key = "abandono",     short = "Abandono",     color = { 1, 0.5, 0 } },
        { key = "rendimiento",  short = "Rendimiento",  color = { 1, 0.3, 0 } },
        { key = "baneo",        short = "Baneo",        color = { 1, 0.1, 0.1 } },
        { key = "equipamiento", short = "Equip.",       label = "Equipamiento",        color = { 0.3, 0.6, 1 } },
        { key = "engemado",     short = "Eng/Enc",      label = "Engemado/Encantado",  color = { 0.7, 0.4, 1 } },
    },
    BAND_SANCTION_KEYS = { "", "lag", "abandono", "rendimiento", "baneo", "equipamiento", "engemado" },

    -- Estado de líder de raid de un jugador (columna "Líder", similar a rol).
    -- "" = No; "si" = Sí; "ayudante" = Ayudante.
    BAND_LEADER_DATA = {
        { key = "si",       label = "Sí",       color = { 1, 0.82, 0 } },
        { key = "ayudante", label = "Ayudante", color = { 0.3, 0.6, 1 } },
    },
    BAND_LEADER_KEYS = { "", "si", "ayudante" },

    -- Barra de botones inferior del menú flotante (estilo base v2).
    -- Las acciones se implementan en iteraciones posteriores.
    ACTION_BAR = {
        HEIGHT = 30,
        BUTTON_SIZE = 27,
        BUTTON_PADDING = 2,
        ITEMS = {
            { name = "Modo de raid",            icon = "Interface\\Icons\\inv_misc_coin_09",              tooltip = "Clic Izquierdo: Cambiar modo de raid\nClic Derecho: solicitar asignaciones del lider", action = "ActionBarRaidMode", actionRight = "ActionBarRaidModeRight" },
            { name = "Indicar discord",         icon = "Interface\\Icons\\inv_letter_17",                 tooltip = "Clic Izquierdo: Enviar link de discord\nClic Derecho: Editar link de discord", action = "ActionBarDiscord", actionRight = "ActionBarDiscordEdit" },
            { name = "Nombrar objetivo",        icon = "Interface\\Icons\\ability_hunter_beastcall",       tooltip = "Clic Izquierdo: Nombrar objetivo\nClic Derecho: Ver info de objetivo", action = "ActionBarNameTarget", actionRight = "ActionBarTargetInfo" },
            { name = "Marcar principales",      icon = "Interface\\Icons\\ability_hunter_markedfordeath",  tooltip = "Clic Izquierdo: Marcar principales y alertar\nClic Derecho: Limpiar marcas de banda", action = "ActionBarMarkMains", actionRight = "ActionBarClearMarks" },
            { name = "Susurrar asignaciones",   icon = "Interface\\Icons\\ability_paladin_beaconoflight",  tooltip = "Clic Izquierdo: Susurrar asignaciones a la banda", action = "ActionBarWhisperAssignments" },
            { name = "Iniciar Check",           icon = "Interface\\Icons\\ability_paladin_swiftretribution", tooltip = "Clic Izquierdo: Realizar Ready Check\nClic Derecho: Reportar jugadores ausentes", action = "ActionBarReadyCheck", actionRight = "ActionBarReportAbsent" },
            { name = "Iniciar Pull",            icon = "Interface\\Icons\\ability_hunter_readiness",       tooltip = "Clic Izquierdo/Derecho: Iniciar cuenta regresiva de Pull", action = "ActionBarPull", actionRight = "ActionBarPull" },
            { name = "Cambiar Botín",           icon = "Interface\\Icons\\inv_box_02",                     tooltip = "Clic Izquierdo: Cambiar método de botín\nClic Derecho: Asignar Maestro Despojador al objetivo", action = "ActionBarLootMode", actionRight = "ActionBarMasterLooter" },
            { name = "Configuración",           icon = "Interface\\Icons\\INV_Gizmo_02",                   tooltip = "Clic Izquierdo: Abrir panel de configuración", action = "ActionBarConfig" },
        },
    },

    -- Datos por defecto de las categorías configurables (se editan desde la
    -- ventana de configuración; cada ítem es { name = ..., icon = ... })
    DEFAULT_LISTS = {
        -- Listas configuradas por el usuario. Se arrancan VACÍAS (decisión de
        -- "versión limpia": el contenido por defecto de la v2 se desactivó).
        -- "Reiniciar" en cada pestaña las restaura a este estado (vacío).
        roles = {}, abilities = {}, buffs = {}, auras = {}, mechanics = {}, rules = {},
    },

    -- Configuración por defecto del spammer de reclutamiento (estilo KRT). Vive
    -- dentro de cada banda (bands[i].spammer); estos defaults se aplican "lazy"
    -- al primer acceso (RD.utils.bands:GetSpammer) sin ensuciar la DB con bandas
    -- que nunca spamean. channels es un mapa canal -> bool (solo los true envían).
    SPAMMER_DEFAULTS = {
        name = "",
        prefix = "",
        suffix = "",
        -- Último band.name / tamaño desde el que se sincronizó el campo nombre
        -- (al renombrar la banda, AutoComposition propaga al abrir el spammer).
        syncedBandName = "",
        syncedSize = 0,
        duration = 60,
        tank = 0, tankClass = "",
        healer = 0, healerClass = "",
        melee = 0, meleeClass = "",
        ranged = 0, rangedClass = "",
        message = "",
        separator = "//",
        channels = { RAID = true },
    },

    -- Opciones del separador de partes del mensaje del spammer de banda. El
    -- valor se guarda en band.spammer.separator; "" significa "sin separador".
    -- ", " respeta el formato de coma simple. El separador reemplaza las comas
    -- del campo Mensaje al componer.
    SPAMMER_SEPARATORS = {
        { key = "//",    label = "//  (diagonal)" },
        { key = "|",     label = "|  (pipe)" },
        { key = ";",     label = ";  (punto y coma)" },
        { key = ", ",    label = ",  (coma simple)" },
        { key = "",      label = "Sin separador" },
    },

    -- Texto inicial del campo Mensaje al restablecer el spammer de banda. La
    -- cola (X/Y) se añade sola al final del mensaje (BuildMessageFrom), por eso
    -- no lleva {players}.
    SPAMMER_INITIAL_MESSAGE = "De0,ConDC,CupoFrag,GS {gs}+,Wisp Func+GS",

    -- Defaults del spammer de reglas (ui.rulesSpammer; también en DEFAULT_CONFIG).
    RULES_SPAMMER_DEFAULTS = {
        duration = 45,
        channels = { RAID = true },
        selectedTitle = "",
    },

    -- Definiciones de menú (escalables: agregar datos, no código).
    -- Los ítems con `dynamic` renderizan un submenú con los elementos de la
    -- lista de configuración correspondiente (clave de RD.config).
    MENU_DEFINITIONS = {
        MainFrameOptions = {
            { name = "Habilidades", action = "ShowSkills", dynamic = "abilities", icon = "Interface\\Icons\\ability_shaman_heroism", tooltip = "Gestionar habilidades del grupo", enabled = MenuEnabledByConfig("ui.showAbilitiesMenu", true) },
            { name = "Roles",       action = "ShowRoles",  dynamic = "roles",      icon = "Interface\\Icons\\Ability_Warrior_DefensiveStance", tooltip = "Gestionar roles del grupo", enabled = MenuEnabledByConfig("ui.showRolesMenu", true) },
            { name = "Buffs",       action = "ShowBuffs",  dynamic = "buffs",      icon = "Interface\\Icons\\Spell_Magic_MageArmor", tooltip = "Gestionar buffs del grupo", enabled = MenuEnabledByConfig("ui.showBuffsMenu", true) },
            { name = "Auras",       action = "ShowAuras",  dynamic = "auras",      icon = "Interface\\Icons\\Spell_Holy_AuraMastery", tooltip = "Gestionar auras del grupo", enabled = MenuEnabledByConfig("ui.showAurasMenu", true) },
            { name = "Mecánicas",   action = "ShowMechanics", dynamic = "mechanics", icon = "Interface\\Icons\\Spell_Shadow_Metamorphosis", tooltip = "Mecánicas de los jefes", enabled = MenuEnabledByConfig("ui.showMechanicsMenu", true) },
            { name = "Reglas",       action = "ShowRaidRules", dynamic = "rules",     icon = "Interface\\Icons\\INV_Scroll_03", tooltip = "Reglas de la banda", enabled = MenuEnabledByConfig("ui.showRulesMenu", true) },
            { name = "Banda",       dynamic = "bands",    tooltip = "Abrir una de tus bandas", icon = "Interface\\Icons\\INV_Banner_02", enabled = MenuEnabledByConfig("ui.showBandsMenu", true) },
            { name = "RaidDominion", tooltip = "Configuración del addon", submenu = "addonOptions" },
        },
        addonOptions = {
            { name = "Registrar", action = "RegisterPlayer", icon = "Interface\\Icons\\INV_Misc_Book_09", tooltip = "Guardar un registro detallado del jugador en las variables guardadas: clase, equipamiento, asignaciones, bandas, spammers y hermandad (roster completo solo si eres GM)" },
            { name = "Configuración", action = "ToggleConfig", tooltip = "Abrir la ventana de configuración" },
            { name = "Ayuda",         action = "ShowHelp",     tooltip = "Mostrar ayuda del addon" },
            { name = "Recargar",      action = "ReloadUI",     tooltip = "Recargar la interfaz" },
            { name = "Ocultar",       action = "HideMainFrame", tooltip = "Ocultar el menú principal" },
        },
    },

    -- Configuración por defecto (merge profundo con la DB al cargar)
    DEFAULT_CONFIG = {
        general = {
            debug = false,
            scale = 1.0,
        },
        ui = {
            menu = {
                showOnStart = true,
                lockPosition = false,
                itemsPerColumn = 9,   -- elementos por columna (las columnas se derivan: clamp(ceil(ítems/esto), 2, MAX_COLUMNS))
                position = { point = "CENTER", relativeTo = "UIParent", relativePoint = "CENTER", x = 0, y = 0 },
            },
            config = {
                position = "screen",   -- "screen" | "menu" (anclada junto al menú flotante)
            },
            minimap = {
                position = 0.75,       -- ángulo normalizado (0..1) del botón de minimapa
            },
            spammer = {
                -- Posición de la ventana del spammer (como ui.menu.position)
                position = { point = "CENTER", relativeTo = "UIParent", relativePoint = "CENTER", x = 0, y = 0 },
            },
            rulesSpammer = {
                duration = 45,
                channels = { RAID = true },
                selectedTitle = "",
                position = { point = "CENTER", relativeTo = "UIParent", relativePoint = "CENTER", x = 0, y = 0 },
            },
            showTooltips = true,
            -- Visibilidad en vivo de cada submenú de lista en el menú flotante.
            showAbilitiesMenu = true,
            showRolesMenu = true,
            showBuffsMenu = true,
            showAurasMenu = true,
            showMechanicsMenu = true,
            showRulesMenu = true,
            showBandsMenu = true,
        },
        chat = {
            channel = "DEFAULT",
            discordLink = "",
        },
        loot = {
            rollTimeLimit = 10,   -- segundos de cuenta atrás para los dados de un ítem (máx. 10)
        },
        roles = {},
        buffs = {},
        auras = {},
        abilities = {},
        mechanics = {},
        rules = {},
        assignments = {
            roles = {},
            abilities = {},
            buffs = {},
            auras = {},
        },
        -- Bandas registradas: nombre, icono, horario, gearscore mínimo y jugadores.
        bands = {},
        -- Registro detallado POR PERSONAJE generado por "Registrar": contenedor
        -- con clave "Nombre-Reino" por personaje; lo demás queda compartido.
        registry = {},
        -- Personajes detectados de esta cuenta (comparten esta misma DB por ser
        -- una SavedVariables account-wide): clave "Nombre-Reino".
        characters = {},
    },

    -- Esquema de configuración: la ventana se renderiza a partir de esto
    -- y según el valor seteado actual en RD.config.
    CONFIG_SCHEMA = {
        { id = "general", title = "General", order = 1, sections = {
            { id = "menu", title = "Menú", help = "Opciones de apariencia y comportamiento del menú flotante.", fields = {
                { key = "ui.menu.showOnStart",   type = "checkbox", label = "Mostrar menú al iniciar", help = "Muestra u oculta el menú flotante al iniciar sesión." },
                { key = "ui.showTooltips",       type = "checkbox", label = "Mostrar información de ayuda", help = "Activa o desactiva las ventanas de ayuda al pasar el cursor sobre los elementos de la configuración y del menú flotante." },
                { key = "ui.menu.itemsPerColumn", type = "slider",  label = "Elementos por columna", min = 2, max = 9, step = 1, help = "Máximo de elementos por columna. Las columnas se calculan solas: cuantos más elementos por columna, menos columnas (y más alto el menú)." },
                { key = "general.scale",         type = "slider",   label = "Escala de la interfaz", min = 0.7, max = 1.5, step = 0.05, help = "Escala global de la interfaz de RaidDominion." },
            }},
            { id = "chat", title = "Chat", help = "Canal usado para anunciar mensajes, reglas y mecánicas.", fields = {
                { key = "chat.channel", type = "dropdown", label = "Salida por defecto", help = "Canal por defecto para los mensajes de la raid. 'Por defecto' elige automáticamente según el contexto (banda, grupo, etc.).", options = {
                    ["DEFAULT"]      = "POR DEFECTO",
                    ["SYSTEM"]       = "SISTEMA",
                    ["GUILD"]        = "HERMANDAD",
                    ["SAY"]          = "DECIR",
                    ["YELL"]         = "GRITAR",
                    ["PARTY"]        = "GRUPO",
                    ["RAID"]         = "BANDA",
                    ["RAID_WARNING"] = "AVISO DE BANDA",
                    ["BATTLEGROUND"] = "CAMPO DE BATALLA",
                }},
            }},
            { id = "reset", title = "", fields = {
                { key = "actions", type = "buttons", buttons = {
                    { key = "reload", label = "Recargar UI", action = "ReloadUI", help = "Recarga la interfaz para aplicar cambios que requieren reinicio." },
                    { key = "reset", label = "Restablecer valores por defecto", action = "ResetConfig", help = "Devuelve toda la configuración de RaidDominion a sus valores por defecto.", confirmText = "¿Restablecer TODA la configuración de RaidDominion a sus valores por defecto? Se perderán tus opciones, listas y bandas personalizadas.", confirmAccept = "Restablecer" },
                }},
            }},
        }},
        { id = "bands", title = "Bandas", order = 2, sections = {
            { id = "main", title = "Bandas registradas", help = "Gestiona las bandas: nombre, gearscore mínimo y horario.", fields = {
                { key = "ui.showBandsMenu", type = "checkbox", label = "Mostrar en el menú flotante", help = "Muestra u oculta el submenú de bandas del menú flotante (en vivo)." },
                { key = "bands", type = "bands", label = "Bandas", height = 300, help = "Crea, edita o elimina bandas. Cada banda agrupa jugadores con rol, gearscore, sanción y asistencia." },
            }},
        }},
        { id = "roles", title = "Roles", order = 3, sections = {
            { id = "main", title = "Roles del grupo", help = "Ítems de rol asignables desde el menú flotante.", fields = {
                { key = "ui.showRolesMenu", type = "checkbox", label = "Mostrar en el menú flotante", help = "Muestra u oculta el submenú de roles del menú flotante (en vivo)." },
                { key = "roles", type = "list", label = "Roles", height = 220, help = "Edita el nombre en línea y elige el icono con el botón de la derecha (abre el selector)." },
            }},
        }},
        { id = "abilities", title = "Habilidades", order = 4, sections = {
            { id = "main", title = "Habilidades del grupo", help = "Habilidades asignables desde el menú flotante.", fields = {
                { key = "ui.showAbilitiesMenu", type = "checkbox", label = "Mostrar en el menú flotante", help = "Muestra u oculta el submenú de habilidades del menú flotante (en vivo)." },
                { key = "abilities", type = "list", label = "Habilidades", height = 220, help = "Edita el nombre en línea y elige el icono con el botón de la derecha (abre el selector)." },
            }},
        }},
        { id = "buffs", title = "Buffs", order = 5, sections = {
            { id = "main", title = "Buffs del grupo", help = "Buffs asignables desde el menú flotante.", fields = {
                { key = "ui.showBuffsMenu", type = "checkbox", label = "Mostrar en el menú flotante", help = "Muestra u oculta el submenú de buffs del menú flotante (en vivo)." },
                { key = "buffs", type = "list", label = "Buffs", height = 220, help = "Edita el nombre en línea y elige el icono con el botón de la derecha (abre el selector)." },
            }},
        }},
        { id = "auras", title = "Auras", order = 6, sections = {
            { id = "main", title = "Auras del grupo", help = "Auras asignables desde el menú flotante.", fields = {
                { key = "ui.showAurasMenu", type = "checkbox", label = "Mostrar en el menú flotante", help = "Muestra u oculta el submenú de auras del menú flotante (en vivo)." },
                { key = "auras", type = "list", label = "Auras", height = 220, help = "Edita el nombre en línea y elige el icono con el botón de la derecha (abre el selector)." },
            }},
        }},
        { id = "mechanics", title = "Mecánicas", order = 7, sections = {
            { id = "main", title = "Mecánicas de jefes", help = "Mecánicas de los jefes de la banda.", fields = {
                { key = "ui.showMechanicsMenu", type = "checkbox", label = "Mostrar en el menú flotante", help = "Muestra u oculta el submenú de mecánicas del menú flotante (en vivo)." },
                { key = "mechanics", type = "contentList", label = "Mecánicas", height = 220, help = "Título, icono y contenido. El clic en el título o la fila abre el editor." },
            }},
        }},
        { id = "rules", title = "Reglas", order = 8, sections = {
            { id = "main", title = "Reglas de la banda", help = "Reglas de comportamiento de la banda.", fields = {
                { key = "ui.showRulesMenu", type = "checkbox", label = "Mostrar en el menú flotante", help = "Muestra u oculta el submenú de reglas del menú flotante (en vivo)." },
                { key = "rules", type = "contentList", label = "Reglas", height = 220, help = "Título, icono y contenido. El clic en el título o la fila abre el editor." },
            }},
        }},
        { id = "help", title = "Ayuda", order = 100, compact = true, sections = {
            { id = "general", title = "Guía de RaidDominion", fields = {
                { key = "helpAccordion", type = "helpAccordion", entries = {
                    { title = "Acerca de", content = "RaidDominion v3.0.0 es un gestor de banda para World of Warcraft 3.3.5a (WotLK, esMX).\nOrganiza roles, habilidades, buffs, auras, mecánicas y reglas de tu raid, y gestiona bandas, jugadores y asistencia. Incluye un menú flotante, gestor de botín, spammers de reclutamiento y una barra de acciones de raid." },
                    { title = "Primeros pasos", content = "Al entrar verás el menú flotante (si 'Mostrar menú al iniciar' está activo).\nClic izquierdo en un ítem navega o ejecuta su acción; clic derecho vuelve al menú anterior.\nArrastra el menú para moverlo (la posición se recuerda). Usa /rd para mostrarlo u ocultarlo." },
                    { title = "Menú flotante", content = "El menú agrupa: Roles, Habilidades, Buffs, Auras, Mecánicas, Reglas y Bandas.\nLos ítems asignables (roles/habilidades/buffs/auras): selecciona un objetivo y pulsa el icono del ítem para asignárselo (o desasignarlo); el clic en el texto lo anuncia por el canal configurado.\nLa barra inferior reúne las acciones de raid (ver 'Barra de acciones')." },
                    { title = "Configuración", content = "Ábrela con /rdc o desde el menú flotante / la barra de acciones.\nSe organiza en pestañas: General, Bandas, Roles, Habilidades, Buffs, Auras, Mecánicas, Reglas y Ayuda.\nEl botón 'Restablecer valores por defecto' (tab General) restaura toda la configuración." },
                    { title = "Roles, habilidades, buffs y auras", content = "Son listas configurables y asignables. Se editan en la pestaña de Configuración correspondiente: añade o quita ítems con nombre e icono.\n'Obtener' pide la lista al líder; 'Reiniciar' la restaura al estado por defecto. La visibilidad de cada ítem en el menú se controla con el botón-ojo." },
                    { title = "Mecánicas y reglas", content = "Son listas de contenido (título, icono y texto).\nAl pulsar una mecánica o regla en el menú se envía su contenido al canal configurado (se trocea solo si es largo).\nSe editan en Configuración > Mecánicas / Reglas; el botón 'Obtener' pide la lista al líder." },
                    { title = "Bandas y jugadores", content = "Crea, edita o elimina bandas en Configuración > Bandas (nombre, gearscore mínimo y horario).\nDesde el menú > Banda, el clic en el texto anuncia la banda y el clic en el icono abre su gestor de jugadores: rol (T/H/R/M), dual, clase, gearscore, líder (No/Sí/Ayudante), asistencia (+/-) y sanción.\nCada jugador tiene botones para invitarlo y susurrarle una plantilla de invitación con los datos de la banda." },
                    { title = "Gestor de botín", content = "Se abre con /rdloot, desde el menú (submenú Bandas > Gestor de botín) o la barra de acciones.\nArrastra un ítem de la bolsa o haz clic con uno en el cursor. Tira dados (Main/Dual/Enchant) con límite de tiempo, elige ganador (clic en un dado), declara ganador y desempata si hay empate en el dado más alto (solo tiran los empatados).\nEl historial queda agrupado por ítem. También puedes spamear el botín y recoger los ítems hacia el maestro despojador." },
                    { title = "Spammer de banda", content = "Compone el mensaje de reclutamiento de una banda: prefijo, nombre, sufijo, duración, composición por rol, canales y vista previa (máx. 255 caracteres).\nInicia o detiene el bucle de spam. Se abre desde el submenú Bandas > Spamear banda (requiere al menos una banda registrada)." },
                    { title = "Spammer de reglas", content = "Rota el mensaje de una regla por canal: elige la regla, la duración y los canales, con vista previa y contador de caracteres.\nSe abre desde Configuración > Reglas > Spamear." },
                    { title = "Barra de acciones", content = "Botones inferiores del menú flotante:\n- Modo de raid: izq. configurar dificultad · der. pedir asignaciones al líder\n- Indicar discord: enviar / editar el link\n- Nombrar objetivo: nombrar / ver info\n- Marcar principales: marcar iconos de raid · der. limpiar\n- Susurrar asignaciones\n- Iniciar Check: ready check · der. reportar ausentes\n- Iniciar Pull: cuenta regresiva de pull\n- Cambiar botín: método de botín · der. maestro despojador\n- Configuración" },
                    { title = "Comunicación", content = "Estando en grupo o banda puedes pedir al líder las asignaciones, reglas, mecánicas o bandas (botón 'Obtener' o clic derecho en 'Modo de raid').\nEl líder puede compartir las asignaciones y listas con el resto de jugadores que usen el addon." },
                    { title = "Minimapa", content = "El botón del minimapa: clic izquierdo abre/cierra el menú flotante; clic derecho abre un menú contextual (Configuración, Gestor de botín, Recoger items, Spamear reglas/banda, Mover, Recargar UI).\nMantén Alt y arrastra para moverlo alrededor del minimapa. Se muestra/oculta con /rdminimap." },
                    { title = "Comandos", content = "/rd - muestra/oculta el menú flotante\n/rdc - abre la configuración\n/rdh - muestra esta ayuda en el chat\n/rdloot - abre el gestor de botín\n/rdminimap - muestra/oculta el botón del minimapa\nSubcomandos de /rd: /rd c (config), /rd loot (o botin), /rd help (o h)" },
                }},
            }},
        }},
    },
}

-- Semilla de las listas configurables: se rellenan tras construir el literal
-- porque dentro de la tabla RD.constants aún no existe la referencia.
local listSeeds = RD.constants.DEFAULT_LISTS
RD.constants.DEFAULT_CONFIG.roles = listSeeds.roles
RD.constants.DEFAULT_CONFIG.buffs = listSeeds.buffs
RD.constants.DEFAULT_CONFIG.auras = listSeeds.auras
RD.constants.DEFAULT_CONFIG.abilities = listSeeds.abilities
RD.constants.DEFAULT_CONFIG.mechanics = listSeeds.mechanics
RD.constants.DEFAULT_CONFIG.rules = listSeeds.rules

return RD.constants
