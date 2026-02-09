--[[
    RD_Module_Minigame.lua
    PROPÓSITO: Gestiona la lógica del minijuego de hermandad (Baúles/Pares o Nones).
    SISTEMA: El líder controla el flujo, los jugadores interactúan con baúles.
]]

local addonName, private = ...
local RD = _G.RaidDominion or {}
_G.RaidDominion = RD

local constants = RD.constants
local events = RD.events
local messageManager = RD.messageManager

-- Módulo de Minijuego
local minigame = {
    state = "IDLE", -- IDLE, SETUP, DICE, CHOICE, STEAL, FINISHED
    isPaused = false,
    players = {
        p1 = { name = nil, choice = nil, roll = nil, chest = nil },
        p2 = { name = nil, choice = nil, roll = nil, chest = nil }
    },
    chests = {
        [1] = { owner = nil, content = nil, revealed = false },
        [2] = { owner = nil, content = nil, revealed = false }
    },
    isLeader = false
}

RD.minigame = minigame

-- Prefijo de comunicación
local COMM_PREFIX = "RD_MINIGAME"

-- Estados del juego
local STATES = {
    IDLE = 0,
    SETUP = 1,     -- Eligiendo jugadores y Pares/Nones
    DICE = 2,      -- Tirando dados para ver quién empieza
    CHOICE = 3,    -- El ganador del dado elige baúl
    STEAL = 4,     -- El segundo jugador decide si roba o mantiene
    FINISHED = 5
}

-- Función auxiliar para obtener el nivel de permiso
local function GetPerms()
    local mm = RD.modules and RD.modules.messageManager
    return mm and mm.GetPermissionLevel and mm:GetPermissionLevel() or 0
end

-- Helper para logs centralizados
local function Log(...)
    if RD.messageManager and RD.messageManager.SendSystemMessage then
        RD.messageManager:SendSystemMessage(...)
    else
        local msg = select(1, ...)
        if select("#", ...) > 1 then
            msg = string.format(...)
        end
        SendSystemMessage(msg)
    end
end

-- Función auxiliar para obtener el número de miembros del grupo (Compatible con 3.3.5)
local function GetGroupSize()
    local raidMembers = GetNumRaidMembers()
    if raidMembers > 0 then
        return raidMembers
    end
    local partyMembers = GetNumPartyMembers()
    if partyMembers > 0 then
        return partyMembers + 1
    end
    return 1
end

-- Función para inicializar el juego (Solo Líder)
function minigame:StartNewGame()
    local isLeader = false
    if GetGroupSize() <= 1 then
        isLeader = true
    else
        isLeader = IsRaidLeader() or IsPartyLeader()
    end

    if not isLeader then
        Log("|cffff0000[RaidDominion]|r Solo el líder del grupo puede iniciar el minijuego.")
        return
    end

    if GetPerms() < 3 then
        Log("|cffff0000[RaidDominion]|r Error: Requiere Rango Oficial/Admin de permisos para gestionar el minijuego.")
        return
    end
    
    -- Notificar reinicio a todos antes de cambiar el estado local
    local channel = nil
    if GetNumRaidMembers() > 0 then channel = "RAID"
    elseif GetNumPartyMembers() > 0 then channel = "PARTY" end
    if channel then
        SendAddonMessage(COMM_PREFIX, "RESET_GAME", channel)
    end

    self.isLeader = true
    self:HandleLocalReset()
    self:OpenUI(true)
end

function minigame:HandleLocalReset()
    self.state = "SETUP"
    self.isPaused = false
    self.turnOwner = nil
    self.players.p1 = { name = nil, choice = "PARES", roll = nil, chest = nil }
    self.players.p2 = { name = nil, choice = "NONES", roll = nil, chest = nil }
    self.chests[1] = { owner = nil, content = nil, revealed = false, revealed_local = false }
    self.chests[2] = { owner = nil, content = nil, revealed = false, revealed_local = false }
    
    -- El líder genera contenido nuevo
    if self.isLeader or GetGroupSize() <= 1 then
        self.chests[1].content = (math.random(1, 2) == 1) and "SALVACION" or "ELIMINACION"
        self.chests[2].content = (self.chests[1].content == "SALVACION") and "ELIMINACION" or "SALVACION"
    end
    
    if self.frame then
        self:UpdateUI()
    end
end

-- Función auxiliar para anunciar con tensión
function minigame:Announce(msg, isUrgent)
    local color = isUrgent and "|cffff0000" or "|cffffff00"
    local finalMsg = "|cff00ff00[RaidDominion]|r " .. color .. msg .. "|r"
    
    if RD.messageManager and RD.messageManager.SendSystemMessage then
        RD.messageManager:SendSystemMessage(finalMsg)
    else
        SendSystemMessage(finalMsg)
    end
    
    -- RaidNotice para mensaje en medio de la pantalla
    local frame = RaidWarningFrame
    if frame then
        RaidNotice_AddMessage(frame, "|cff00ff00[RaidDominion]|r " .. msg, { r = 1, g = 1, b = 0 })
    end
    
    -- Si el líder lo anuncia, sincronizar el mensaje para que todos lo vean
    if self.isLeader and msg:sub(1, 5) ~= "SYNC:" then
        local channel = nil
        if GetNumRaidMembers() > 0 then channel = "RAID"
        elseif GetNumPartyMembers() > 0 then channel = "PARTY" end
        if channel then
            SendAddonMessage(COMM_PREFIX, "ALERT:"..msg, channel)
        end
    end
end

-- Throttling para BroadcastState (Compatible con 3.3.5)
local lastBroadcast = 0
local broadcastScheduled = false
local timerFrame = CreateFrame("Frame")

function minigame:BroadcastState(immediate)
    if not self.isLeader then return end
    
    local now = GetTime()
    if not immediate and (now - lastBroadcast < 0.2) then
        if not broadcastScheduled then
            broadcastScheduled = true
            timerFrame:SetScript("OnUpdate", function(self, elapsed)
                self.elapsed = (self.elapsed or 0) + elapsed
                if self.elapsed >= 0.2 then
                    self:SetScript("OnUpdate", nil)
                    self.elapsed = 0
                    broadcastScheduled = false
                    minigame:BroadcastState(true)
                end
            end)
        end
        return
    end
    
    lastBroadcast = now
    
    local channel = nil
    if GetNumRaidMembers() > 0 then
        channel = "RAID"
    elseif GetNumPartyMembers() > 0 then
        channel = "PARTY"
    end

    if not channel then return end
    
    local p1Name = self.players.p1.name or "nil"
    local p2Name = self.players.p2.name or "nil"
    local o1 = self.chests[1].owner or "nil"
    local o2 = self.chests[2].owner or "nil"
    local c1Revealed = tostring(self.chests[1].revealed)
    local c2Revealed = tostring(self.chests[2].revealed)
    local tOwner = self.turnOwner or "nil"
    local msg = string.format("SYNC:%s:%s:%s:%s:%s:%s:%s:%s:%s", self.state, tostring(self.isPaused), p1Name, p2Name, o1, o2, c1Revealed, c2Revealed, tOwner)
    SendAddonMessage(COMM_PREFIX, msg, channel)
end

-- Función auxiliar para enviar acciones
function minigame:SendAction(action, val)
    local channel = nil
    if GetNumRaidMembers() > 0 then
        channel = "RAID"
    elseif GetNumPartyMembers() > 0 then
        channel = "PARTY"
    end

    if channel then
        local msg = "ACTION:"..action..":"..val
        SendAddonMessage(COMM_PREFIX, msg, channel)
        -- Enviar a través de messageManager para evitar inundación
    else
        -- Si estamos solos, procesar la acción localmente de inmediato
        self:HandlePlayerAction(UnitName("player"), action, val)
    end
end

-- Recibir mensajes del líder o jugadores
local function OnCommReceived(prefix, message, channel, sender)
    if prefix ~= COMM_PREFIX then return end
    
    -- Evitar procesar nuestros propios mensajes
    if sender == UnitName("player") then return end
    
    -- Split simple por ":"
    local parts = {}
    for part in string.gmatch(message, "([^:]+)") do
        table.insert(parts, part)
    end
    
    local cmd = parts[1]
    
    if cmd == "SYNC" then
        minigame.state = parts[2]
        minigame.isPaused = (parts[3] == "true")
        minigame.players.p1.name = (parts[4] ~= "nil") and parts[4] or nil
        minigame.players.p2.name = (parts[5] ~= "nil") and parts[5] or nil
        minigame.chests[1].owner = (parts[6] ~= "nil") and parts[6] or nil
        minigame.chests[2].owner = (parts[7] ~= "nil") and parts[7] or nil
        minigame.chests[1].revealed = (parts[8] == "true")
        minigame.chests[2].revealed = (parts[9] == "true")
        minigame.turnOwner = (parts[10] ~= "nil") and parts[10] or nil
        
        -- Solo actualizar UI si el frame existe
        if minigame.frame and minigame.frame:IsShown() then
            minigame:UpdateUI()
        end
    elseif cmd == "ACTION" then
        -- Jugador realizó una acción (ej: clic en baúl)
        if minigame.isLeader then
            minigame:HandlePlayerAction(sender, parts[2], parts[3])
        end
    elseif cmd == "ALERT" then
        -- Recibir alerta del líder para mostrar en pantalla
        local msg = message:sub(7) -- Saltar "ALERT:"
        local frame = RaidWarningFrame
        if frame then
            RaidNotice_AddMessage(frame, "|cff00ff00[RaidDominion]|r " .. msg, { r = 1, g = 1, b = 0 })
        end
        Log("|cff00ff00[RaidDominion]|r |cffffff00" .. msg .. "|r")
    elseif cmd == "RESET_GAME" then
        -- Reiniciar el juego en todos los clientes
        minigame:HandleLocalReset()
    elseif cmd == "INVOKE_GAME" then
        -- El líder solicita que todos abran el minijuego
        minigame:OpenUI()
    elseif cmd == "START_COUNTDOWN" then
        -- Obsoleto
    elseif cmd == "REVEAL_ALL" then
        -- Revelación instantánea recibida del líder
        minigame:HandleRevealAll(parts[2], parts[3])
    elseif cmd == "REVEAL" then
        -- El líder revela el contenido de un baúl de forma privada a un jugador
        local chestId = tonumber(parts[2])
        local content = parts[3]
        if minigame.frame then
            local revealMsg = string.format("|cff00ff00[RaidDominion]|r ¡Has abierto tu baúl! Contiene: |cffffff00%s|r", content)
            Log(revealMsg)
            if minigame.chests[chestId] then
                minigame.chests[chestId].content = content
                minigame.chests[chestId].revealed_local = true
            end
            minigame:UpdateUI()
        end
    end
end

-- Registrar evento de comunicación
local f = CreateFrame("Frame")
f:RegisterEvent("CHAT_MSG_ADDON")
f:SetScript("OnEvent", function(self, event, prefix, message, channel, sender)
    if event == "CHAT_MSG_ADDON" then
        OnCommReceived(prefix, message, channel, sender)
    end
end)

-- Función auxiliar para gestionar tooltips explicativos
local function SetExplanatoryTooltip(btn, title, description)
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(title, 1, 1, 1)
        GameTooltip:AddLine(description, nil, nil, nil, true)
        if GetPerms() < 3 then
            GameTooltip:AddLine("\n|cffff0000Requiere Rango Oficial/Admin para usar este botón|r", 1, 0, 0)
        end
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- UI del Minijuego
function minigame:OpenUI(forceShow)
    local justCreated = false
    if not self.frame then
        self:CreateUI()
        self.frame:Hide()
        justCreated = true
    end
    
    if forceShow then
        self.frame:Show()
        self:UpdateUI()
    elseif self.frame:IsShown() and not justCreated then
        self.frame:Hide()
    else
        self.frame:Show()
        
        -- Si somos el líder o estamos solos, y el juego no ha empezado, inicializarlo
        local isActualLeader = false
        if GetGroupSize() <= 1 then isActualLeader = true
        else isActualLeader = IsRaidLeader() or IsPartyLeader() end
        
        if isActualLeader and GetPerms() >= 3 and self.state == "IDLE" then
            self:StartNewGame()
        else
            self:UpdateUI()
        end
    end
end

function minigame:CreateUI()
    local f = CreateFrame("Frame", "RaidDominionMinigameFrame", UIParent)
    f:SetSize(400, 350)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    f:SetBackdropColor(0, 0, 0, 0.9)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    
    local guildName = GetGuildInfo("player") or "Hermandad"
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.title:SetPoint("TOP", 0, -15)
    f.title:SetText("Minijuego [" .. guildName .. "]: Baúles")
    
    -- Área de Estado/Instrucciones
    f.statusArea = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.statusArea:SetPoint("TOP", f.title, "BOTTOM", 0, -5)
    f.statusArea:SetWidth(360)
    f.statusArea:SetTextColor(1, 1, 1)
    f.statusArea:SetText("Iniciando...")

    -- Botón Cerrar
    f.close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    f.close:SetPoint("TOPRIGHT", -5, -5)
    
    -- Baúles
    f.chest1 = CreateFrame("Button", "RD_Minigame_Chest1", f)
    f.chest1:SetSize(100, 80)
    f.chest1:SetPoint("CENTER", -80, -20)
    f.chest1:SetNormalTexture("Interface/Icons/INV_Box_01")
    f.chest1:SetHighlightTexture("Interface/Buttons/ButtonHilight-Square", "ADD")
    f.chest1.text = f.chest1:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.chest1.text:SetPoint("BOTTOM", 0, -20)
    f.chest1.text:SetText("Baúl 1")
    
    f.chest2 = CreateFrame("Button", "RD_Minigame_Chest2", f)
    f.chest2:SetSize(100, 80)
    f.chest2:SetPoint("CENTER", 80, -20)
    f.chest2:SetNormalTexture("Interface/Icons/INV_Box_02")
    f.chest2:SetHighlightTexture("Interface/Buttons/ButtonHilight-Square", "ADD")
    f.chest2.text = f.chest2:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.chest2.text:SetPoint("BOTTOM", 0, -20)
    f.chest2.text:SetText("Baúl 2")
    
    -- Área de dados y selección de jugadores (Solo Líder)
    f.setupArea = CreateFrame("Frame", nil, f)
    f.setupArea:SetSize(380, 100)
    f.setupArea:SetPoint("TOP", 0, -40)
    
    f.p1Btn = CreateFrame("Button", nil, f.setupArea, "UIPanelButtonTemplate")
    f.p1Btn:SetSize(120, 25)
    f.p1Btn:SetPoint("TOPLEFT", 20, -10)
    f.p1Btn:SetText("Asignar P1")
    SetExplanatoryTooltip(f.p1Btn, "Asignar Jugador 1", "Asigna a tu objetivo actual como el primer participante del minijuego.")
    f.p1Btn:SetScript("OnClick", function()
        if GetPerms() < 3 then return end
        local name = UnitName("target")
        if name then
            minigame.players.p1.name = name
            minigame:Announce("Jugador 1 asignado: " .. name)
            minigame:UpdateUI()
            minigame:BroadcastState()
        else
            local errorMsg = "|cffff0000[RaidDominion]|r Selecciona un objetivo para asignar como Jugador 1."
            Log(errorMsg)
        end
    end)
    
    f.p2Btn = CreateFrame("Button", nil, f.setupArea, "UIPanelButtonTemplate")
    f.p2Btn:SetSize(120, 25)
    f.p2Btn:SetPoint("TOPRIGHT", -20, -10)
    f.p2Btn:SetText("Asignar P2")
    SetExplanatoryTooltip(f.p2Btn, "Asignar Jugador 2", "Asigna a tu objetivo actual como el segundo participante del minijuego.")
    f.p2Btn:SetScript("OnClick", function()
        if GetPerms() < 3 then return end
        local name = UnitName("target")
        if name then
            minigame.players.p2.name = name
            minigame:Announce("Jugador 2 asignado: " .. name)
            minigame:UpdateUI()
            minigame:BroadcastState()
        else
            local errorMsg = "|cffff0000[RaidDominion]|r Selecciona un objetivo para asignar como Jugador 2."
            Log(errorMsg)
        end
    end)
    
    f.p1Text = f.setupArea:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.p1Text:SetPoint("TOP", f.p1Btn, "BOTTOM", 0, -5)
    f.p1Text:SetText("P1: Ninguno")
    
    f.p2Text = f.setupArea:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.p2Text:SetPoint("TOP", f.p2Btn, "BOTTOM", 0, -5)
    f.p2Text:SetText("P2: Ninguno")
    
    -- Selección Par/Impar para P1
    f.choiceP1 = CreateFrame("Button", nil, f.setupArea, "UIPanelButtonTemplate")
    f.choiceP1:SetSize(100, 25)
    f.choiceP1:SetPoint("TOP", f.p1Text, "BOTTOM", 0, -5)
    f.choiceP1:SetText("P1: PARES")
    SetExplanatoryTooltip(f.choiceP1, "Pares o Nones", "Cambia la elección del Jugador 1. El Jugador 2 recibirá automáticamente la opción contraria.")
    f.choiceP1:SetScript("OnClick", function()
        if GetPerms() < 3 then return end
        minigame.players.p1.choice = (minigame.players.p1.choice == "PARES") and "NONES" or "PARES"
        minigame.players.p2.choice = (minigame.players.p1.choice == "PARES") and "NONES" or "PARES"
        minigame:UpdateUI()
    end)
    minigame.players.p1.choice = "PARES"
    minigame.players.p2.choice = "NONES"
    
    f.diceBtn = CreateFrame("Button", nil, f.setupArea, "UIPanelButtonTemplate")
    f.diceBtn:SetSize(100, 25)
    f.diceBtn:SetPoint("CENTER", 0, -30)
    f.diceBtn:SetText("Tirar Dados")
    SetExplanatoryTooltip(f.diceBtn, "Lanzar Dados", "Lanza un dado de 1 a 100 para determinar quién elige el primer baúl basado en Pares/Nones.")
    f.diceBtn:SetScript("OnClick", function()
        if GetPerms() < 3 then return end
        if minigame.isPaused then return end
        if not minigame.players.p1.name or not minigame.players.p2.name then
            local errorMsg = "|cffff0000[RaidDominion]|r Debes asignar a ambos jugadores primero."
            Log(errorMsg)
            return
        end
        minigame:RollDice()
    end)

    -- Lógica de clic en baúl
    local lastClick = 0
    local function OnChestClick(id)
        local now = GetTime()
        if now - lastClick < 0.5 then return end -- Cooldown local de 0.5s
        lastClick = now
        
        if minigame.isPaused then
            Log("|cffff0000[RaidDominion]|r El juego está pausado por el líder.")
            return
        end
        
        -- Si el líder hace clic, puede ver el contenido (siempre que tenga Rango Oficial/Admin)
        if minigame.isLeader and GetPerms() >= 3 then
            local content = minigame.chests[id].content or "???"
            Log("|cff00ff00[RaidDominion]|r Baúl %d contiene: |cffffff00%s|r", id, content)
        end
        
        -- Ejecutar acción (esto enviará el mensaje al líder o lo procesará si es solo)
        minigame:SendAction("CHEST_CLICK", id)
    end
    
    f.chest1:SetScript("OnClick", function() OnChestClick(1) end)
    f.chest2:SetScript("OnClick", function() OnChestClick(2) end)
    
    -- Controles del Líder (Solo visibles para el líder)
    f.leaderControls = CreateFrame("Frame", nil, f)
    f.leaderControls:SetSize(380, 60)
    f.leaderControls:SetPoint("BOTTOM", 0, 10)
    
    f.pauseBtn = CreateFrame("Button", nil, f.leaderControls, "UIPanelButtonTemplate")
    f.pauseBtn:SetSize(85, 25)
    f.pauseBtn:SetPoint("LEFT", 5, 0)
    f.pauseBtn:SetText("Pausar")
    SetExplanatoryTooltip(f.pauseBtn, "Pausar/Reanudar", "Detiene temporalmente las interacciones de los jugadores con los baúles.")
    f.pauseBtn:SetScript("OnClick", function()
        if GetPerms() < 3 then return end
        minigame.isPaused = not minigame.isPaused
        minigame:BroadcastState()
        minigame:UpdateUI()
    end)
    
    f.invokeBtn = CreateFrame("Button", nil, f.leaderControls, "UIPanelButtonTemplate")
    f.invokeBtn:SetSize(85, 25)
    f.invokeBtn:SetPoint("LEFT", f.pauseBtn, "RIGHT", 5, 0)
    f.invokeBtn:SetText("Invocar")
    SetExplanatoryTooltip(f.invokeBtn, "Invocar Jugadores", "Envía una señal a todos los miembros de la banda para que abran automáticamente la ventana del minijuego.")
    f.invokeBtn:SetScript("OnClick", function()
        if GetPerms() < 3 then return end
        local channel = nil
        if GetNumRaidMembers() > 0 then channel = "RAID"
        elseif GetNumPartyMembers() > 0 then channel = "PARTY" end
        if channel then
            SendAddonMessage(COMM_PREFIX, "INVOKE_GAME", channel)
            minigame:Announce("Invocando minijuego para todos...")
        end
    end)
    
    f.resetBtn = CreateFrame("Button", nil, f.leaderControls, "UIPanelButtonTemplate")
    f.resetBtn:SetSize(85, 25)
    f.resetBtn:SetPoint("LEFT", f.invokeBtn, "RIGHT", 5, 0)
    f.resetBtn:SetText("Reiniciar")
    SetExplanatoryTooltip(f.resetBtn, "Reiniciar Juego", "Finaliza la ronda actual y comienza una nueva desde el principio (SETUP).")
    f.resetBtn:SetScript("OnClick", function()
        if GetPerms() < 3 then return end
        minigame:StartNewGame()
    end)
    
    f.nextBtn = CreateFrame("Button", nil, f.leaderControls, "UIPanelButtonTemplate")
    f.nextBtn:SetSize(85, 25)
    f.nextBtn:SetPoint("LEFT", f.resetBtn, "RIGHT", 5, 0)
    f.nextBtn:SetText("Siguiente")
    SetExplanatoryTooltip(f.nextBtn, "Avanzar Fase", "Salta manualmente a la siguiente fase del juego (usar con precaución).")
    f.nextBtn:SetScript("OnClick", function()
        if GetPerms() < 3 then return end
        minigame:AdvanceState()
    end)
    
    f.revealBtn = CreateFrame("Button", nil, f.leaderControls, "UIPanelButtonTemplate")
    f.revealBtn:SetSize(85, 25)
    f.revealBtn:SetPoint("LEFT", f.resetBtn, "RIGHT", 5, 0) -- Misma posición que "Siguiente" porque se intercambian
    f.revealBtn:SetText("Revelar")
    SetExplanatoryTooltip(f.revealBtn, "Revelación Final", "Inicia la cuenta atrás de 6 segundos para mostrar el contenido de ambos baúles a todos.")
    f.revealBtn:SetScript("OnClick", function()
        if GetPerms() < 3 then return end
        minigame:FinalReveal()
    end)
    f.revealBtn:Hide()
    
    self.frame = f
end

function minigame:UpdateUI()
    if not self.frame then return end
    
    local f = self.frame
    local playerName = UnitName("player")
    local isP1 = (playerName == self.players.p1.name)
    local isP2 = (playerName == self.players.p2.name)
    
    -- Determinar si somos el líder actual del grupo o estamos solos
    local isActualLeader = false
    if GetGroupSize() <= 1 then isActualLeader = true
    else isActualLeader = IsRaidLeader() or IsPartyLeader() end
    
    -- El usuario quiere ver la vista de líder (aunque sea explicativa) si es el líder del grupo
    local showAsLeader = self.isLeader or isActualLeader
    
    local role = "Espectador"
    if self.isLeader then role = "Líder"
    elseif isActualLeader then role = "Líder (Espectador)"
    elseif isP1 then role = "Jugador 1"
    elseif isP2 then role = "Jugador 2" end

    f.pauseBtn:SetText(self.isPaused and "Reanudar" or "Pausar")
    
    -- Actualizar título con nombre de hermandad
    local guildName = GetGuildInfo("player") or "Hermandad"
    f.title:SetText("Minijuego [" .. guildName .. "]: Baúles")
    
    -- Actualizar Texto de Estado según Estado y Rol
    local statusText = "|cffaaaaaa["..role.."]|r "
    if self.state == "SETUP" then
        if showAsLeader then
            statusText = statusText .. "Asigna a los jugadores y elige Pares/Nones."
        else
            statusText = statusText .. "Esperando a que el líder inicie el juego..."
        end
    elseif self.state == "DICE" then
        if showAsLeader then
            statusText = statusText .. "Lanza los dados para decidir quién elige primero."
        else
            statusText = statusText .. "El líder está lanzando los dados..."
        end
    elseif self.state == "CHOICE" then
        if playerName == self.turnOwner then
            statusText = statusText .. "|cff00ff00¡Es tu turno!|r Elige un baúl."
        else
            statusText = statusText .. "Esperando a que " .. (self.turnOwner or "alguien") .. " elija baúl."
        end
    elseif self.state == "STEAL" then
        local firstChooser = self.turnOwner
        local stealer = (self.players.p1.name == firstChooser) and self.players.p2.name or self.players.p1.name
        if playerName == stealer then
            statusText = statusText .. "|cff00ff00¡Tu turno!|r ¿Robas el baúl o te quedas el tuyo?"
        else
            statusText = statusText .. "Esperando decisión de robo de " .. (stealer or "alguien") .. "."
        end
    elseif self.state == "FINISHED" then
        statusText = statusText .. "Juego terminado. El líder revelará los contenidos."
    end
    f.statusArea:SetText(statusText)

    if showAsLeader then
        f.leaderControls:Show()
        f.setupArea:Show()
        
        -- Habilitar/Deshabilitar según nivel de permiso (Rango Oficial/Admin requerido)
        local hasPerms = (GetPerms() >= 3)
        local alpha = hasPerms and 1 or 0.5
        
        if f.p1Btn.SetEnabled then f.p1Btn:SetEnabled(hasPerms) end
        f.p1Btn:SetAlpha(alpha)
        if f.p2Btn.SetEnabled then f.p2Btn:SetEnabled(hasPerms) end
        f.p2Btn:SetAlpha(alpha)
        if f.choiceP1.SetEnabled then f.choiceP1:SetEnabled(hasPerms) end
        f.choiceP1:SetAlpha(alpha)
        if f.diceBtn.SetEnabled then f.diceBtn:SetEnabled(hasPerms) end
        f.diceBtn:SetAlpha(alpha)
        
        if f.pauseBtn.SetEnabled then f.pauseBtn:SetEnabled(hasPerms) end
        f.pauseBtn:SetAlpha(alpha)
        if f.invokeBtn.SetEnabled then f.invokeBtn:SetEnabled(hasPerms) end
        f.invokeBtn:SetAlpha(alpha)
        if f.resetBtn.SetEnabled then f.resetBtn:SetEnabled(hasPerms) end
        f.resetBtn:SetAlpha(alpha)
        if f.nextBtn.SetEnabled then f.nextBtn:SetEnabled(hasPerms) end
        f.nextBtn:SetAlpha(alpha)
        if f.revealBtn.SetEnabled then f.revealBtn:SetEnabled(hasPerms) end
        f.revealBtn:SetAlpha(alpha)
        
        if not hasPerms then
            f.statusArea:SetText(statusText .. "\n|cffff0000(Vista Explicativa: Requiere Rango Oficial/Admin)|r")
        end
    else
        f.leaderControls:Hide()
        f.setupArea:Hide()
    end
    
    -- Actualizar visual de baúles según estado
    if self.isPaused then
        f.chest1:SetAlpha(0.5)
        f.chest2:SetAlpha(0.5)
    else
        f.chest1:SetAlpha(1)
        f.chest2:SetAlpha(1)
    end
    
    -- Mostrar quién tiene qué baúl
    local c1Text = "Baúl 1"
    if self.chests[1].owner then c1Text = c1Text .. "\n("..self.chests[1].owner..")" end
    
    -- El contenido se muestra si:
    -- 1. Está revelado globalmente (FinalReveal)
    -- 2. El jugador actual es el líder
    -- 3. El jugador actual ha abierto su baúl (revealed_local)
    if self.chests[1].revealed or self.isLeader or self.chests[1].revealed_local then 
        local content = self.chests[1].content or "???"
        local color = (content == "SALVACION") and "|cff00ff00" or "|cffff0000"
        c1Text = c1Text .. "\n" .. color .. content .. "|r" 
    end
    f.chest1.text:SetText(c1Text)
    
    local c2Text = "Baúl 2"
    if self.chests[2].owner then c2Text = c2Text .. "\n("..self.chests[2].owner..")" end
    if self.chests[2].revealed or self.isLeader or self.chests[2].revealed_local then 
        local content = self.chests[2].content or "???"
        local color = (content == "SALVACION") and "|cff00ff00" or "|cffff0000"
        c2Text = c2Text .. "\n" .. color .. content .. "|r" 
    end
    f.chest2.text:SetText(c2Text)
    
    -- Actualizar textos de jugadores
    f.p1Text:SetText("P1: " .. (self.players.p1.name or "Ninguno"))
    f.p2Text:SetText("P2: " .. (self.players.p2.name or "Ninguno"))
    f.choiceP1:SetText("P1: " .. (self.players.p1.choice or "PARES"))
    
    -- Ocultar configuración si no estamos en SETUP
    if self.state == "SETUP" then
        f.p1Btn:Show()
        f.p2Btn:Show()
        f.choiceP1:Show()
        f.diceBtn:Show()
        f.nextBtn:Hide()
        f.revealBtn:Hide()
    elseif self.state == "FINISHED" then
        f.p1Btn:Hide()
        f.p2Btn:Hide()
        f.choiceP1:Hide()
        f.diceBtn:Hide()
        f.nextBtn:Hide()
        f.revealBtn:Show()
    else
        f.p1Btn:Hide()
        f.p2Btn:Hide()
        f.choiceP1:Hide()
        f.diceBtn:Hide()
        f.nextBtn:Show()
        f.revealBtn:Hide()
    end
end

-- Lógica de avance de estado (Líder)
function minigame:AdvanceState()
    local oldState = self.state
    if self.state == "SETUP" then
        self.state = "DICE"
    elseif self.state == "DICE" then
        self.state = "CHOICE"
    elseif self.state == "CHOICE" then
        self.state = "STEAL"
    elseif self.state == "STEAL" then
        self.state = "FINISHED"
    end
    
    local stageMsg = string.format("|cff00ff00[RaidDominion]|r Etapa: |cffffff00%s|r -> |cffffff00%s|r", oldState, self.state)
    Log(stageMsg)
    
    self:BroadcastState()
    self:UpdateUI()
end

-- Función para tirar dados (Líder)
function minigame:RollDice()
    if not self.isLeader then return end
    
    local p1 = self.players.p1
    local p2 = self.players.p2
    
    -- Cifra directa (1 dado de 100)
    local rollResult = math.random(1, 100)
    
    p1.roll = rollResult
    
    local result = (rollResult % 2 == 0) and "PARES" or "NONES"
    
    local winner = (p1.choice == result) and p1 or p2
    local loser = (winner == p1) and p2 or p1
    
    self.turnOwner = winner.name
    
    -- Mensajes por SYSTEM
    Log("|cff00ff00[RaidDominion]|r %s (%s) vs %s (%s)", p1.name, p1.choice, p2.name, p2.choice)
    Log("|cff00ff00[RaidDominion]|r Dado: |cffffff00%d|r (%s)", rollResult, result)
    Log("|cff00ff00[RaidDominion]|r ¡Ganador: |cffffff00%s|r! Escoge el primer baúl.", winner.name)
    
    -- Saltar directamente a CHOICE
    self.state = "CHOICE"
    self:Announce("¡Dado: " .. rollResult .. "! Ganador: " .. winner.name)
    self:BroadcastState()
    self:UpdateUI()
end

-- Manejar acciones de jugadores
function minigame:HandlePlayerAction(sender, action, val)
    if self.isPaused then return end
    
    if action == "CHEST_CLICK" then
        local chestId = tonumber(val)
        
        -- Si ya tiene dueño y no es el sender, no hacer nada (a menos que sea fase de robo)
        if self.chests[chestId].owner and self.chests[chestId].owner ~= sender and self.state ~= "STEAL" then
            return
        end

        if self.state == "CHOICE" then
            -- Solo el ganador del dado puede elegir en CHOICE
            if sender ~= self.turnOwner then 
                local errorMsg = string.format("|cffff0000[RaidDominion]|r %s intentó elegir, pero es el turno de %s.", sender, self.turnOwner or "nadie")
                Log(errorMsg)
                return 
            end
            
            self.chests[chestId].owner = sender
            local otherChest = (chestId == 1) and 2 or 1
            local otherPlayer = (self.players.p1.name == sender) and self.players.p2.name or self.players.p1.name
            self.chests[otherChest].owner = otherPlayer
            
            -- Revelar de forma privada al que eligió
            local content = self.chests[chestId].content
            if GetGroupSize() > 1 then
                SendAddonMessage(COMM_PREFIX, string.format("REVEAL:%d:%s", chestId, content), "WHISPER", sender)
            else
                -- Si estamos solos, ya lo mostramos en OnChestClick, pero marcamos localmente
                self.chests[chestId].revealed_local = true
            end
            
            local choiceMsg = string.format("|cff00ff00[RaidDominion]|r %s ha elegido el Baúl %d.", sender, chestId)
            Log(choiceMsg)
            self:Announce(sender .. " ha elegido el Baúl " .. chestId)
            self:AdvanceState()
        elseif self.state == "STEAL" then
            -- El segundo jugador (el que NO eligió primero) decide
            local firstChooser = self.turnOwner
            local stealer = (self.players.p1.name == firstChooser) and self.players.p2.name or self.players.p1.name
            
            if sender ~= stealer then return end
            
            -- Si hace clic en el baúl que NO es suyo, está robando
            if self.chests[chestId].owner ~= sender then
                local previousOwner = self.chests[chestId].owner
                local myPreviousChest = (chestId == 1) and 2 or 1
                
                self.chests[chestId].owner = sender
                self.chests[myPreviousChest].owner = previousOwner
                
                self:Announce("¡" .. sender .. " ha ROBADO el baúl " .. chestId .. "!")
            else
                self:Announce(sender .. " decide QUEDARSE con su baúl " .. chestId)
            end
            
            self.state = "FINISHED" -- Asegurar que pase a FINISHED para el botón de revelar
            self:BroadcastState()
            self:UpdateUI()
        end
        
        self:BroadcastState()
        self:UpdateUI()
    end
end

-- Función para revelar todo (Líder)
function minigame:FinalReveal()
    if not self.isLeader then return end
    
    local c1Content = self.chests[1].content or "???"
    local c2Content = self.chests[2].content or "???"
    
    local channel = nil
    if GetNumRaidMembers() > 0 then channel = "RAID"
    elseif GetNumPartyMembers() > 0 then channel = "PARTY" end
    
    -- Iniciar cuenta atrás sincronizada
    self:Announce("Iniciando revelación en 3...")
    
    -- Usar el sistema de tareas de messageManager si está disponible
    local mm = RD.modules and RD.modules.messageManager
    if mm and mm.ScheduleTask then
        mm:ScheduleTask(2, function()
            self:Announce("Revelación en 2...")
            mm:ScheduleTask(2, function()
                self:Announce("Revelación en 1...")
                mm:ScheduleTask(2, function()
                    if channel then
                        SendAddonMessage(COMM_PREFIX, string.format("REVEAL_ALL:%s:%s", c1Content, c2Content), channel)
                    end
                    self:HandleRevealAll(c1Content, c2Content)
                end)
            end)
        end)
    else
        -- Fallback simple si no hay mm (no debería ocurrir)
        if channel then
            SendAddonMessage(COMM_PREFIX, string.format("REVEAL_ALL:%s:%s", c1Content, c2Content), channel)
        end
        self:HandleRevealAll(c1Content, c2Content)
    end
end

function minigame:HandleRevealAll(c1Content, c2Content)
    self.chests[1].revealed = true
    self.chests[2].revealed = true
    self.chests[1].content = c1Content
    self.chests[2].content = c2Content
    self.state = "FINISHED"
    
    self:Announce("¡REVELACIÓN FINAL: Baúl 1: " .. c1Content .. " | Baúl 2: " .. c2Content .. "!", true)
    self:UpdateUI()
end

function minigame:StartLocalCountdown()
    -- Eliminado a petición del usuario
end
