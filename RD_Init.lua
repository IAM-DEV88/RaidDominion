--[[
    RD_Init.lua
    PROPÓSITO: Punto de entrada principal. Inicializa módulos y comandos de consola.
    API PÚBLICA: RaidDominion:Initialize()
    COMANDOS: /rd, /rdc, /rdh
]]

local addonName, private = ...
local RD = _G.RaidDominion or {}
_G.RaidDominion = RD

local isInitialized = false

-- Mensaje de sistema (fallback a print si messageManager no está cargado)
local function Log(msg)
    if RD.messageManager and RD.messageManager.SendSystemMessage then
        RD.messageManager:SendSystemMessage(msg)
    else
        print(msg)
    end
end

local function ShowHelp()
    -- Ayuda por el gestor de mensajes (no print directo, convención AGENTS §5)
    local function Out(txt)
        if RD.messageManager and RD.messageManager.SendSystemMessage then
            RD.messageManager:SendSystemMessage(txt)
        else
            print(txt)
        end
    end
    Out(" ")
    Out("|cffff8000=== RaidDominion ===|r")
    Out("|cffffff00Comandos disponibles:|r")
    Out(" ")
    Out("|cffffff00/rd|r - Muestra/oculta el menú flotante")
    Out("|cffffff00/rdc|r - Muestra/oculta la configuración")
    Out("|cffffff00/rdh|r - Muestra esta ayuda")
    Out(" ")
    Out("|cffff8000===================|r")
    Out(" ")
end

-- Abre el gestor de botín (por slash o subcomando). Loguea si no está disponible.
local function HandleOpenLoot()
    local lw = RD.ui and RD.ui.lootWindow
    if lw and lw.Open then
        lw:Open()
    else
        Log("|cffff0000[RaidDominion]|r El gestor de botín no está disponible.")
    end
end

local function SetupSlashCommands()
    SLASH_RAIDDOMINION1 = "/rd"
    SLASH_RDCONFIG1 = "/rdc"
    SLASH_RDHELP1 = "/rdh"
    SLASH_RDLOOT1 = "/rdloot"

    SlashCmdList["RAIDDOMINION"] = function(msg)
        local command = strlower(strtrim(msg or ""))
        if command == "" then
            if RD.ui and RD.ui.menuFrame and RD.ui.menuFrame.Toggle then
                RD.ui.menuFrame:Toggle()
            else
                Log("|cffff0000[RaidDominion]|r El menú flotante no está disponible.")
            end
        elseif command == "config" or command == "c" then
            if RD.ui and RD.ui.configWindow and RD.ui.configWindow.Toggle then
                RD.ui.configWindow:Toggle()
            else
                Log("|cffff0000[RaidDominion]|r La ventana de configuración no está disponible.")
            end
        elseif command == "loot" or command == "botin" then
            HandleOpenLoot()
        elseif command == "help" or command == "h" or command == "?" then
            ShowHelp()
        else
            Log("|cffff0000[RaidDominion]|r Comando desconocido. /rdh para ayuda.")
        end
    end

    SlashCmdList["RDCONFIG"] = function()
        if RD.ui and RD.ui.configWindow and RD.ui.configWindow.Toggle then
            RD.ui.configWindow:Toggle()
        end
    end

    SlashCmdList["RDHELP"] = ShowHelp

    SlashCmdList["RDLOOT"] = HandleOpenLoot
end

local function InitializeAddon()
    if isInitialized then return end

    -- Cargar configuración
    if RD.config and RD.config.Load then
        RD.config:Load()
    end

    -- Detectar/actualizar al personaje actual en la lista de personajes de la
    -- cuenta (todos comparten la misma DB account-wide).
    if RD.utils and RD.utils.characters and RD.utils.characters.RegisterCurrent then
        pcall(RD.utils.characters.RegisterCurrent, RD.utils.characters)
    end

    -- Construir UI (solo en PLAYER_LOGIN, ya garantizado por el flujo)
    if RD.ui and RD.ui.menuFrame and RD.ui.menuFrame.Create then
        RD.ui.menuFrame:Create()
    end
    if RD.ui and RD.ui.configWindow and RD.ui.configWindow.Create then
        RD.ui.configWindow:Create()
    end

    -- Ventana del spammer (modal por banda, estilo KRT) — se construye en login
    if RD.ui and RD.ui.spammerWindow and RD.ui.spammerWindow.Create then
        local ok, err = pcall(RD.ui.spammerWindow.Create, RD.ui.spammerWindow)
        if not ok and RD.messageManager and RD.messageManager.SendSystemMessage then
            RD.messageManager:SendSystemMessage("|cffff0000[RaidDominion]|r Error al crear el spammer: " .. tostring(err))
        end
    end

    -- Spammer de reglas (config → Reglas → Spamear)
    if RD.ui and RD.ui.rulesSpammerWindow and RD.ui.rulesSpammerWindow.Create then
        local ok, err = pcall(RD.ui.rulesSpammerWindow.Create, RD.ui.rulesSpammerWindow)
        if not ok and RD.messageManager and RD.messageManager.SendSystemMessage then
            RD.messageManager:SendSystemMessage("|cffff0000[RaidDominion]|r Error al crear el spammer de reglas: " .. tostring(err))
        end
    end

    -- Gestor de botín: registra eventos del juego (LOOT_OPENED, CHAT_MSG_SYSTEM)
    if RD.modules and RD.modules.loot and RD.modules.loot.Initialize then
        pcall(RD.modules.loot.Initialize, RD.modules.loot)
    end
    -- Ventana del gestor de botín (se construye en login)
    if RD.ui and RD.ui.lootWindow and RD.ui.lootWindow.Create then
        local ok, err = pcall(RD.ui.lootWindow.Create, RD.ui.lootWindow)
        if not ok then
            -- Limpia el frame parcial para permitir reintentar al abrir
            RD.ui.lootWindow.frame = nil
            if RD.messageManager and RD.messageManager.SendSystemMessage then
                RD.messageManager:SendSystemMessage("|cffff0000[RaidDominion]|r Error al crear el gestor de botín: " .. tostring(err))
            end
        end
    end

    -- Botón de minimapa (menú flotante / menú contextual / arrastre con Alt)
    if RD.ui and RD.ui.minimapButton and RD.ui.minimapButton.Initialize then
        pcall(RD.ui.minimapButton.Initialize, RD.ui.minimapButton)
    end

    -- Anuncio de buffs/debuffs con clic izquierdo en los iconos de aura de la UI
    -- base (como el addon base v2).
    if RD.modules and RD.modules.auraClick and RD.modules.auraClick.Initialize then
        pcall(RD.modules.auraClick.Initialize, RD.modules.auraClick)
    end

    -- Precargar la lista de iconos del selector (una sola pasada, en login).
    -- Protegida con pcall para que un fallo de recolección no rompa el arranque.
    if RD.ui and RD.ui.widgets and RD.ui.widgets.CollectIcons then
        pcall(RD.ui.widgets.CollectIcons)
    end

    -- Visibilidad inicial según config
    if RD.ui and RD.ui.menuFrame and RD.config and RD.config.Get then
        local showOnStart = RD.config:Get("ui.menu.showOnStart", true)
        if showOnStart then
            RD.ui.menuFrame:Show()
        else
            RD.ui.menuFrame:Hide()
        end
    end

    SetupSlashCommands()

    Log(string.format("|cff00ff00[RaidDominion]|r Addon cargado (v%s). /rdh para ayuda.", RD.constants and RD.constants.VERSION or "3.0.0"))

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
        if RD.config and RD.config.Load then
            RD.config:Load()
        end
    elseif event == "PLAYER_LOGIN" then
        InitializeAddon()
        self:UnregisterEvent("PLAYER_LOGIN")
    elseif event == "PLAYER_LOGOUT" then
        if RD.config and RD.config.Save then
            RD.config:Save()
        end
    end
end)
