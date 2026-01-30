--[[
    RD_Init.lua
    PROPÓSITO: Punto de entrada principal del addon. Maneja la inicialización y comandos de consola.
    DEPENDENCIAS: RD_Events.lua, RD_Constants.lua
    API PÚBLICA: RaidDominion:Initialize()
    COMANDOS: /rd, /rdc, /rdd, /rdh
    INTERACCIONES: Todos los módulos principales
]]

-- Obtener referencias a las constantes
local addonName = RaidDominion and RaidDominion.constants and RaidDominion.constants.MODULE_NAMES and RaidDominion.constants.MODULE_NAMES.MAIN or "RaidDominion2"
local RD = _G.RaidDominion or {}
_G.RaidDominion = RD

-- Cargar constantes
RD.constants = RaidDominion and RaidDominion.constants or {}
local CONST = RD.constants
local MSG = CONST.MESSAGES or {}
local SLASH = CONST.SLASH_COMMANDS or {}

-- Asegurar tablas principales
RD.modules = RD.modules or {}
RD.utils = RD.utils or {}
RD.utils.coreBands = RD.utils.coreBands or {}
RD.utils.recognition = RD.utils.recognition or {}
RD.utils.gearscore = RD.utils.gearscore or {}
RD.data = RD.data or {}
RD.ui = RD.ui or {}
RD.UI = RD.UI or {}
RD.config = RD.config or {}
RD.events = RD.events or {}
RD.MenuData = RD.MenuData or {}

-- Variables locales
local isInitialized = false

local function ShowHelp()
    -- Print help messages to chat
    print(" ")
    print(MSG.ADDON_TITLE or "|cffff8000=== RaidDominion ===|r")
    print(MSG.HELP_HEADER or "|cffffff00Comandos disponibles:|")
    print(" ")
    print(MSG.HELP_RD or "|cffffff00/rd|r - Muestra/oculta la ventana principal")
    print(MSG.HELP_RDC or "|cffffff00/rdc|r - Muestra/oculta la configuración")
    print(MSG.HELP_RDH or "|cffffff00/rdh|r - Muestra esta ayuda")
    print(" ")
    print(MSG.SEPARATOR or "|cffff8000===================|")
    print(" ")
end

local function SetupSlashCommands()
    -- Configurar comandos de consola
    SLASH_RAIDDOMINION1 = SLASH.MAIN or "/rd"
    SLASH_RDHELP1 = SLASH.HELP or "/rdh"
    SLASH_RDCONFIG1 = SLASH.CONFIG or "/rdc"
    
    -- Manejador principal de comandos
    SlashCmdList["RAIDDOMINION"] = function(msg)
        local command = strlower(strtrim(msg or ""))
        
        if command == "" then
            -- Comando sin argumentos: alternar ventana principal
            if RD.ui.mainFrame and RD.ui.mainFrame.Toggle then
                RD.ui.mainFrame:Toggle()
            else
                print(MSG.MAIN_WINDOW_UNAVAILABLE or "La ventana principal no está disponible.")
            end
        elseif command == "config" or command == "c" then
            -- Comando de configuración
            if RD.ui.configManager and RD.ui.configManager.Toggle then
                RD.ui.configManager:Toggle()
            else
                print(MSG.CONFIG_WINDOW_UNAVAILABLE or "La ventana de configuración no está disponible.")
            end
        elseif command == "help" or command == "h" or command == "?" then
            -- Mostrar ayuda
            ShowHelp()
        elseif command == "minijuego" or command == "mj" or command == "game" then
            -- Comando para el minijuego
            if RD.minigame and RD.minigame.OpenUI then
                RD.minigame:OpenUI()
            else
                print("|cffff0000[RaidDominion]|r El módulo de minijuego no está cargado.")
            end
        elseif command == "testcore" then
            -- Comando de prueba para bandas Core
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[RaidDominion]|r Probando bandas Core...")
            if RD.utils and RD.utils.coreBands and RD.utils.coreBands.ShowCoreBandsWindow then
                RD.utils.coreBands.ShowCoreBandsWindow()
            else
                DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[RaidDominion]|r Error: RD.utils.coreBands no está disponible")
                if not RD.utils then
                    DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[RaidDominion]|r RD.utils no está disponible")
                elseif not RD.utils.coreBands then
                    DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[RaidDominion]|r RD.utils.coreBands no está disponible")
                else
                    DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[RaidDominion]|r RD.utils.coreBands.ShowCoreBandsWindow no está disponible")
                end
            end
        else
            -- Comando desconocido
            print(MSG.UNKNOWN_COMMAND or "Comando desconocido. /rdh para ayuda.")
        end
    end
    
    -- Comando directo para configuración
    SlashCmdList["RDCONFIG"] = function()
        if RD.ui.configManager and RD.ui.configManager.Toggle then
            RD.ui.configManager:Toggle()
        else
            print(MSG.CONFIG_WINDOW_UNAVAILABLE or "La ventana de configuración no está disponible.")
        end
    end
    
    -- Comando directo para ayuda
    SlashCmdList["RDHELP"] = ShowHelp
end

local function InitializeAddon()
    if isInitialized then return end
    
    -- Inicializar MenuData desde constantes
    if RD.constants and RD.constants.MENU_DEFINITIONS then
        RD.MenuData = RD.constants.MENU_DEFINITIONS
        
        -- Registrar acciones de menú si existen
        if RD.MenuActions and RD.MenuActions.RegisterDefaultActions then
            RD.MenuActions:RegisterDefaultActions()
        end
    end
    
    -- Inicializar DynamicMenus
    if RD.UI and RD.UI.DynamicMenus and type(RD.UI.DynamicMenus.Initialize) == "function" then
        if not RD.UI.DynamicMenus.initialized then
            RD.UI.DynamicMenus:Initialize()
            RD.UI.DynamicMenus.initialized = true
        end
    end
    
    -- Inicializar roleManager si existe
    if RD.roleManager and type(RD.roleManager.Initialize) == "function" then
        RD.roleManager:Initialize()
    end
    
    -- Inicializar botón del minimapa
    if RD.ui and RD.ui.minimapButton and RD.ui.minimapButton.Initialize then
        RD.ui.minimapButton:Initialize()
    end
    
    -- Inicializar messageManager si existe
    if RD.messageManager and type(RD.messageManager.Initialize) == "function" then
        RD.messageManager:Initialize()
        
        -- Registrar eventos después de la inicialización
        if RD.messageManager.OnInitialize then
            RD.messageManager:OnInitialize()
        end
    end
    
    -- Asegurarse de que la configuración esté cargada
    if RD.config and RD.config.Load then
        RD.config:Load()
    end
    
    -- Crear marco principal
    if RD.ui and RD.ui.mainFrame and RD.ui.mainFrame.Create then
        -- Crear el marco pero no mostrarlo aún
        RD.ui.mainFrame:Create()
        
        -- Configurar el marco
        RD.ui.mainFrame.frame:SetFrameStrata("MEDIUM")
        RD.ui.mainFrame.frame:SetFrameLevel(10)
        
        -- Obtener la configuración de visibilidad
        local showOnStart = true  -- Valor por defecto
        if RD.config and RD.config.Get then
            showOnStart = RD.config:Get("ui.showMainMenuOnStart") or false
        end
        
        -- Forzar la visibilidad según la configuración
        if showOnStart then
            RD.ui.mainFrame:Show()
        else
            -- Asegurarse de que el marco esté oculto
            if RD.ui.mainFrame.frame then
                RD.ui.mainFrame.frame:Hide()
            end
            if RD.ui.mainFrame.Hide then
                RD.ui.mainFrame:Hide()
            end
        end
    end
    
    SetupSlashCommands()
    
    local version = RD.version or "2.0.0"
    print(string.format("[%s] Addon cargado (v%s). /rdh para ayuda.", addonName, version))
    
    if RD.events and RD.events.Publish then
        RD.events:Publish("ADDON_INITIALIZED")
    end
    
    isInitialized = true
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_LOGOUT")

f:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        -- Cargar configuración cuando las variables guardadas estén disponibles
        if RD.config and RD.config.Load then
            RD.config:Load()
        end
        
        -- Cargar constantes si es necesario
        if not RD.constants and IsAddOnLoaded("RD_Constants") then
            -- RD_Constants debería haberse cargado
        end
        
    elseif event == "PLAYER_LOGIN" then
        -- Asegurar inicialización de eventos
        if RD.events and RD.events.Initialize then
            RD.events:Initialize()
        end
        
        -- Inicializar configuración (si no se ha hecho ya, aunque Load debería ser suficiente)
        if RD.config and RD.config.Initialize then
            RD.config:Initialize()
        end
        
        InitializeAddon()
        
        self:UnregisterEvent("PLAYER_LOGIN")
        
    elseif event == "PLAYER_LOGOUT" then
        if RD.config and RD.config.Save then
            RD.config:Save()
        end
    end
end)
