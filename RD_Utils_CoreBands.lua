--[[
    RD_Utils_CoreBands.lua
    Módulo para la gestión de bandas Core
--]]

local addonName, private = ...
local RD = _G.RaidDominion or {}
_G.RaidDominion = RD

-- Referencias locales para optimización
local pairs, ipairs, tonumber, string, table = pairs, ipairs, tonumber, string, table
local GetGuildRosterInfo, GetNumGuildMembers, GuildRoster = GetGuildRosterInfo, GetNumGuildMembers, GuildRoster
local GetNumRaidMembers, GetNumPartyMembers, GetRaidRosterInfo = GetNumRaidMembers, GetNumPartyMembers, GetRaidRosterInfo
local UnitExists, UnitName, UnitClass, UnitIsPlayer, UnitInParty = UnitExists, UnitName, UnitClass, UnitIsPlayer, UnitInParty
local CreateFrame, UIParent, GetTime = CreateFrame, UIParent, GetTime
local math_min, math_max, math_ceil = math.min, math.max, math.ceil
local tinsert, tremove, tsort = table.insert, table.remove, table.sort
local string_gsub, string_upper, string_lower, string_sub, string_find, string_format, string_match = string.gsub, string.upper, string.lower, string.sub, string.find, string.format, string.match

-- Función auxiliar para limpiar nombres (eliminar reino y normalizar a minúsculas para comparaciones)
-- Caché interna para CleanName para evitar procesamiento de strings repetitivo
local cleanNameCache = {}
local cleanNameCacheSize = 0
local function CleanName(name)
    if not name then return "" end
    if cleanNameCache[name] then return cleanNameCache[name] end
    
    -- Eliminar reino y cualquier espacio en blanco accidental
    local clean = string_gsub(name, "%-.*", "")
    clean = string_gsub(clean, "%s+", "")
    local result = string_lower(clean)
    
    -- Limitar tamaño de caché para evitar fuga de memoria (limpiar si crece demasiado)
    if cleanNameCacheSize > 1000 then 
        wipe(cleanNameCache) 
        cleanNameCacheSize = 0
    end
    
    cleanNameCache[name] = result
    cleanNameCacheSize = cleanNameCacheSize + 1
    
    return result
end

-- Función auxiliar para capitalizar nombres correctamente (primera letra en mayúscula, resto en minúsculas)
local capitalizedNamesCache = {}
local function CapitalizeName(name)
    if not name or name == "" then return "" end
    if capitalizedNamesCache[name] then return capitalizedNamesCache[name] end
    
    -- Eliminar reino si existe
    local cleanName = string_gsub(name, "%-.*", "")
    -- Capitalizar la primera letra y hacer el resto minúsculas
    local result = string_upper(string_sub(cleanName, 1, 1)) .. string_lower(string_sub(cleanName, 2))
    
    capitalizedNamesCache[name] = result
    return result
end

-- Inicializar tablas necesarias
RD.utils = RD.utils or {}
RD.utils.coreBands = RD.utils.coreBands or {}
local coreBandsUtils = RD.utils.coreBands

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

-- Helper para obtener el roster actual en una tabla de búsqueda (caché)
-- Caché de roster para evitar reconstrucción excesiva
local cachedRoster = nil
local lastRosterUpdate = 0

local function BuildRosterCache()
    local now = GetTime()
    if cachedRoster and (now - lastRosterUpdate < 1) then
        return cachedRoster
    end

    local rosterCache = {}
    
    local numRaid = GetNumRaidMembers()
    local numParty = GetNumPartyMembers()

    if numRaid > 0 then
        -- Estamos en Banda
        for i = 1, numRaid do
            local unit = "raid"..i
            local name = UnitName(unit)
            if name and name ~= "Unknown" then
                local _, fileName = UnitClass(unit)
                local clean = CleanName(name)
                rosterCache[clean] = { name = name, class = fileName, unit = unit }
            end
        end
    elseif numParty > 0 then
        -- Estamos en Grupo (Party)
        -- Incluir al jugador local
        local myName = UnitName("player")
        if myName then
            local _, fileName = UnitClass("player")
            local clean = CleanName(myName)
            rosterCache[clean] = { name = myName, class = fileName, unit = "player" }
        end
        -- Incluir miembros del grupo
        for i = 1, numParty do
            local unit = "party"..i
            local name = UnitName(unit)
            if name and name ~= "Unknown" then
                local _, fileName = UnitClass(unit)
                local clean = CleanName(name)
                rosterCache[clean] = { name = name, class = fileName, unit = unit }
            end
        end
    else
        -- Solo nosotros
        local myName = UnitName("player")
        if myName then
            local _, fileName = UnitClass("player")
            local clean = CleanName(myName)
            rosterCache[clean] = { name = myName, class = fileName, unit = "player" }
        end
    end
    
    cachedRoster = rosterCache
    lastRosterUpdate = now
    
    return rosterCache
end

-- Función para obtener una firma única del roster actual (para detectar cambios reales)
local function GetRosterSignature()
    local numRaid = GetNumRaidMembers()
    local numParty = GetNumPartyMembers()
    local count = numRaid > 0 and numRaid or (numParty > 0 and numParty + 1 or 1)
    
    -- Firma basada en count, líder y el primer miembro (para detectar swaps básicos)
    local leader = "none"
    local firstMember = "none"
    if numRaid > 0 then
        for i = 1, numRaid do
            local name, rank = GetRaidRosterInfo(i)
            if rank == 2 then leader = name end
            if i == 1 then firstMember = name end
            if leader ~= "none" and firstMember ~= "none" then break end
        end
    elseif numParty > 0 then
        leader = UnitName("party1") or "me"
        firstMember = UnitName("player") or "me"
    end
    
    return string_format("%d-%s-%s", count, leader, firstMember)
end

-- Mapa para convertir nombres de clase a inglés (para RAID_CLASS_COLORS)
local CLASS_ENGLISH_MAP = {
    ["GUERRERO"] = "WARRIOR", ["WARRIOR"] = "WARRIOR",
    ["PALADÍN"] = "PALADIN", ["PALADIN"] = "PALADIN",
    ["CAZADOR"] = "HUNTER", ["HUNTER"] = "HUNTER",
    ["PÍCARO"] = "ROGUE", ["PICARO"] = "ROGUE", ["ROGUE"] = "ROGUE",
    ["SACERDOTE"] = "PRIEST", ["PRIEST"] = "PRIEST",
    ["CHAMÁN"] = "SHAMAN", ["CHAMAN"] = "SHAMAN", ["SHAMAN"] = "SHAMAN",
    ["MAGO"] = "MAGE", ["MAGE"] = "MAGE",
    ["BRUJO"] = "WARLOCK", ["WARLOCK"] = "WARLOCK",
    ["MONJE"] = "MONK", ["MONK"] = "MONK",
    ["DRUIDA"] = "DRUID", ["DRUID"] = "DRUID",
    ["CABALLERO_DE_LA_MUERTE"] = "DEATHKNIGHT", ["DEATHKNIGHT"] = "DEATHKNIGHT",
    ["CAZADOR_DE_DEMONIOS"] = "DEMONHUNTER", ["DEMONHUNTER"] = "DEMONHUNTER"
}

-- Mapa estático de orden de clases para optimizar ordenación
local CLASS_ORDER = {
    ["GUERRERO"] = 1, ["WARRIOR"] = 1,
    ["PALADÍN"] = 2, ["PALADIN"] = 2,
    ["CAZADOR"] = 3, ["HUNTER"] = 3,
    ["PICARO"] = 4, ["ROGUE"] = 4,
    ["SACERDOTE"] = 5, ["PRIEST"] = 5,
    ["CHAMAN"] = 6, ["SHAMAN"] = 6,
    ["MAGO"] = 7, ["MAGE"] = 7,
    ["BRUJO"] = 8, ["WARLOCK"] = 8,
    ["MONJE"] = 9, ["MONK"] = 9,
    ["DRUIDA"] = 10, ["DRUID"] = 10,
    ["CABALLERO_DE_LA_MUERTE"] = 11, ["DEATHKNIGHT"] = 11,
    ["CAZADOR_DE_DEMONIOS"] = 12, ["DEMONHUNTER"] = 12
}

-- Helper para verificar si un jugador está en el grupo o banda actual
-- Se añade soporte para caché opcional para optimizar bucles
local function IsPlayerInGroup(playerName, rosterCache)
    if not playerName then return false end
    local cleanName = CleanName(playerName)
    
    -- Si hay caché, usarla (O(1))
    if rosterCache then
        return rosterCache[cleanName] ~= nil
    end
    
    -- Si no hay caché, búsqueda manual (O(N))
    -- Verificar en banda
    local numRaid = GetNumRaidMembers()
    if numRaid > 0 then
        for i = 1, numRaid do
            local name = GetRaidRosterInfo(i)
            if name and CleanName(name) == cleanName then
                return true
            end
        end
    else
        -- Verificar en grupo
        local numParty = GetNumPartyMembers()
        if numParty > 0 then
            -- Si hay party, verificar al jugador y a los miembros
            if CleanName(UnitName("player")) == cleanName then
                return true
            end
            for i = 1, numParty do
                local name = UnitName("party"..i)
                if name and CleanName(name) == cleanName then
                    return true
                end
            end
        end
    end
    return false
end

-- Helper para obtener nivel de permisos
local function GetPerms()
    local mm = RD.modules and RD.modules.messageManager
    return mm and mm.GetPermissionLevel and mm:GetPermissionLevel() or 0
end

-- Caché para el estado de la hermandad
local guildOnlineCache = {}
local guildFullCache = {} -- Nueva caché para datos completos (rango, notas, clase)
local lastGuildUpdate = 0
local isUpdatingGuild = false
local updateCoroutine = nil
local isInternalGuildUpdate = false

-- Función para actualizar la caché de la hermandad
local function UpdateGuildOnlineCache(force)
    local now = GetTime()
    local freq = 60 -- Frecuencia hardcoded (1 minuto)
    
    if not force and (now - lastGuildUpdate < freq) then
        return
    end
    
    -- Si ya hay una actualización en curso, no empezar otra
    if isUpdatingGuild then return end
    
    local useCoroutine = true -- Siempre usar coroutine para evitar micro-cortes
    
    local function DoUpdate()
        isUpdatingGuild = true
        isInternalGuildUpdate = true
        
        -- Usar tablas temporales para evitar parpadeo
        local tempOnlineCache = {}
        local tempFullCache = {}
        
        local numMembers = GetNumGuildMembers(true)
        local chunkCount = 0
        local chunkSize = 100 -- Procesar 100 miembros por frame (más rápido que 40)
        
        for i = 1, numMembers do
            local name, rank, rankIndex, level, class, zone, note, officerNote, online, status, classFileName = GetGuildRosterInfo(i)
            if name then
                local cleanName = CleanName(name)
                tempOnlineCache[cleanName] = online
                tempFullCache[cleanName] = {
                    index = i,
                    name = name,
                    rank = rank,
                    rankIndex = rankIndex,
                    level = level,
                    class = class,
                    classFileName = classFileName,
                    zone = zone,
                    note = note,
                    officerNote = officerNote,
                    online = online
                }
            end
            
            if useCoroutine then
                chunkCount = chunkCount + 1
                if chunkCount >= chunkSize then
                    chunkCount = 0
                    coroutine.yield()
                end
            end
        end
        
        -- Swap de caches
        guildOnlineCache = tempOnlineCache
        guildFullCache = tempFullCache
        
        lastGuildUpdate = GetTime()
        isUpdatingGuild = false
        isInternalGuildUpdate = false

        -- Refrescar la UI si es necesario
        local f3 = _G["RaidDominionCoreListFrame"]
        if f3 and f3:IsVisible() and f3.UpdateStats then
            f3.UpdateStats()
        end

        if RD.utils.coreBands and RD.utils.coreBands.RefreshAllVisibleCards then
            RD.utils.coreBands.RefreshAllVisibleCards()
        end
        local playerEditFrame = _G["RaidDominionPlayerEditFrame"]
        if playerEditFrame and playerEditFrame:IsVisible() and playerEditFrame.RefreshGuildData then
            playerEditFrame.RefreshGuildData(false)
        end
    end
    
    if useCoroutine then
        updateCoroutine = coroutine.create(DoUpdate)
        -- Iniciar el procesamiento usando un frame de OnUpdate temporal
        local tickerFrame = CreateFrame("Frame")
        tickerFrame:SetScript("OnUpdate", function(self)
            if updateCoroutine then
                local co = updateCoroutine
                local status, err = coroutine.resume(co)
                if not status or coroutine.status(co) == "dead" then
                    self:SetScript("OnUpdate", nil)
                    isUpdatingGuild = false
                    updateCoroutine = nil
                    if not status then 
                    Log("|cffff0000[RaidDominion Error]:|r " .. (err or "Unknown error in Guild Cache update"))
                    end
                end
            else
                self:SetScript("OnUpdate", nil)
                isUpdatingGuild = false
            end
        end)
    else
        DoUpdate()
    end
end

-- Frame Pooling
local bandLinePool = {}
local roleHeaderPool = {}
local memberCardPool = {}

local function AcquireFrame(pool, frameType, parent, template)
    local frame = tremove(pool)
    if not frame then
        frame = CreateFrame(frameType, nil, parent, template)
    else
        frame:SetParent(parent)
        frame:ClearAllPoints()
    end
    frame:Show()
    return frame
end

local function ReleaseFrame(pool, frame)
    frame:Hide()
    frame:SetParent(nil)
    frame:ClearAllPoints()
    tinsert(pool, frame)
end

-- Función para inicializar los datos del Core si no existen
local function EnsureCoreData()
    if not _G.RaidDominionDB then
        _G.RaidDominionDB = {}
    end
    if not _G.RaidDominionDB.Core then
        _G.RaidDominionDB.Core = {}
    end
    
    -- Asegurar que existe una lista temporal si se solicita o como salvaguarda
    local hasTemporal = false
    for _, band in ipairs(_G.RaidDominionDB.Core) do
        if band.name == "Temporal" then
            hasTemporal = true
            break
        end
    end
    
    if not hasTemporal then
        -- No la añadimos automáticamente aquí para no ensuciar la DB si no se usa,
        -- pero la lógica de asignación la creará si es necesario.
    end
    
    return _G.RaidDominionDB.Core
end

-- Función auxiliar para verificar si un jugador está en línea
local function isPlayerOnline(playerName, rosterCache)
    if not playerName then return false end
    local cleanName = CleanName(playerName)
    
    -- 1. Si está en el grupo/raid, está online por definición (O(1))
    if rosterCache and rosterCache[cleanName] then
        return true
    end
    
    -- 2. Si está en la caché de hermandad, usar ese estado (O(1))
    if guildOnlineCache[cleanName] ~= nil then
        return guildOnlineCache[cleanName]
    end
    
    -- 3. Fallback: UnitExists (Llamada al API)
    return UnitExists(playerName)
end

-- Asegurar inicialización inmediata
EnsureCoreData()

-- Configuración de Diálogos
StaticPopupDialogs["RD_RECRUIT_OFFLINE_PROMPT"] = {
    text = "¿Deseas incluir a los jugadores desconectados (offline) en el proceso de actualización?",
    button1 = "Sí",
    button2 = "No",
    OnAccept = function(self, data)
        if data and data.callback then
            data.callback(true)
        end
    end,
    OnCancel = function(self, data)
        if data and data.callback then
            data.callback(false)
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

StaticPopupDialogs["RD_CONFIRM_GUILD_KICK"] = {
    text = "¿Estás seguro de que quieres expulsar a %s de la hermandad?",
    button1 = "Sí",
    button2 = "No",
    OnAccept = function(self)
        local name = self.data.name
        GuildUninvite(name)
        GuildRoster()
        Log("|cffff0000[RaidDominion]|r Expulsando a " .. name .. " de la hermandad.")
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

StaticPopupDialogs["RAID_DOMINION_RESET_CORE_BAND"] = {
    text = "¿Estás seguro de que quieres reiniciar la banda %s? Esto eliminará a todos los miembros.",
    button1 = YES,
    button2 = NO,
    OnAccept = function(self)
        local bandIndex = self.data.bandIndex
        local coreData = EnsureCoreData()
        if coreData[bandIndex] then
            coreData[bandIndex].members = {}
            RD.utils.coreBands.ShowCoreBandsWindow()
            Log("|cff00ff00[RaidDominion]|r Banda " .. coreData[bandIndex].name .. " reiniciada.")
        end
    end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1
}

StaticPopupDialogs["RAID_DOMINION_DELETE_CORE_BAND"] = {
    text = "¿Estás seguro de que quieres eliminar la banda %s?",
    button1 = YES,
    button2 = NO,
    OnAccept = function(self)
        local bandIndex = self.data.bandIndex
        local coreData = EnsureCoreData()
        table.remove(coreData, bandIndex)
        RD.utils.coreBands.ShowCoreBandsWindow()
    end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1
}

-- Utilidades de UI
local UI = {}

function UI.CreateLabel(parent, text, template)
    local label = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlight")
    label:SetText(text)
    return label
end

function UI.CreateEditBox(name, parent, width, height, numeric)
    local eb = CreateFrame("EditBox", name, parent, "InputBoxTemplate")
    eb:SetSize(width or 200, height or 25)
    eb:SetFontObject("ChatFontNormal")
    if numeric then eb:SetNumeric(true) end
    return eb
end

-- Función para crear un botón con el estilo del marco principal
local function CreateStyledButton(name, parent, width, height, text, iconTexture, tooltipText)
    local button = CreateFrame("Button", name, parent)
    button:SetSize(width or 30, height or 30)
    
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexture(iconTexture)
    button.icon = icon
    
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetTexture("Interface/Buttons/ButtonHilight-Square")
    highlight:SetBlendMode("ADD")
    
    -- Ajustar texto si existe
    if text then
        local label = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("BOTTOM", 0, -12)
        label:SetText(text)
    end
    
    -- Tooltip
    if tooltipText then
        button:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(tooltipText, 1, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
    end
    
    return button
end
coreBandsUtils.CreateStyledButton = CreateStyledButton

-- Función para crear o obtener el frame de edición de bandas
local function getOrCreateBandFrame()
    local createFrame = _G["RaidDominionCreateBandFrame"]
    if not createFrame then
        createFrame = CreateFrame("Frame", "RaidDominionCreateBandFrame", UIParent)
        createFrame:SetFrameStrata("DIALOG") -- Asegurar que esté encima
        createFrame:SetToplevel(true)
        createFrame:SetSize(380, 250)
        createFrame:SetPoint("CENTER")
        createFrame:SetBackdrop({
            bgFile = "Interface/Tooltips/UI-Tooltip-Background",
            edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 }
        })
        createFrame:SetBackdropColor(0, 0, 0, 0.9)
        createFrame:SetBackdropBorderColor(1, 1, 1, 0.5)
        createFrame:EnableMouse(true)
        createFrame:SetMovable(true)
        createFrame:RegisterForDrag("LeftButton")
        createFrame:SetScript("OnDragStart", createFrame.StartMoving)
        createFrame:SetScript("OnDragStop", createFrame.StopMovingOrSizing)
        
        -- Hacer escapable con ESC
        tinsert(UISpecialFrames, createFrame:GetName())
        
        -- Título
        createFrame.title = UI.CreateLabel(createFrame, "Nueva Banda", "GameFontNormal")
        createFrame.title:SetPoint("TOP", 0, -15)
        
        -- Botón Cerrar
        createFrame.closeBtn = CreateFrame("Button", nil, createFrame, "UIPanelCloseButton")
        createFrame.closeBtn:SetPoint("TOPRIGHT", -5, -5)
        createFrame.closeBtn:SetScript("OnClick", function()
            createFrame:Hide()
        end)
        
        -- Campo Nombre de Banda
        createFrame.nameLabel = UI.CreateLabel(createFrame, "Banda:")
        createFrame.nameLabel:SetPoint("TOPLEFT", 20, -50)
        
        createFrame.nameEdit = UI.CreateEditBox("RaidDominionCreateBandNameEdit", createFrame, 250, 25)
        createFrame.nameEdit:SetPoint("TOPLEFT", 115, -45)
        createFrame.nameEdit:SetMaxLetters(31)
        createFrame.nameEdit:SetScript("OnTabPressed", function()
            createFrame.gsEdit:SetFocus()
        end)
        createFrame.nameEdit:SetScript("OnEscapePressed", function(self)
            createFrame:Hide()
        end)
        createFrame.nameEdit:SetScript("OnEnterPressed", function()
            createFrame.acceptBtn:Click()
        end)
        
        -- Campo GS Mínimo
        createFrame.gsLabel = UI.CreateLabel(createFrame, "GS Mínimo:")
        createFrame.gsLabel:SetPoint("TOPLEFT", 20, -85)
        
        createFrame.gsEdit = UI.CreateEditBox("RaidDominionCreateBandGSEdit", createFrame, 100, 25, true)
        createFrame.gsEdit:SetPoint("TOPLEFT", 115, -80)
        createFrame.gsEdit:SetMaxLetters(5)
        createFrame.gsEdit:SetScript("OnTabPressed", function()
            createFrame.scheduleEdit:SetFocus()
        end)
        createFrame.gsEdit:SetScript("OnEscapePressed", function(self)
            createFrame:Hide()
        end)
        createFrame.gsEdit:SetScript("OnEnterPressed", function()
            createFrame.acceptBtn:Click()
        end)
        
        -- Campo Horario
        createFrame.scheduleLabel = UI.CreateLabel(createFrame, "Horario:")
        createFrame.scheduleLabel:SetPoint("TOPLEFT", 20, -120)
        
        createFrame.scheduleEdit = UI.CreateEditBox(nil, createFrame, 250, 25)
        createFrame.scheduleEdit:SetPoint("TOPLEFT", 115, -115)
        createFrame.scheduleEdit:SetMaxLetters(50)
        createFrame.scheduleEdit:SetScript("OnTabPressed", function()
            createFrame.nameEdit:SetFocus()
        end)
        createFrame.scheduleEdit:SetScript("OnEscapePressed", function(self)
            createFrame:Hide()
        end)
        createFrame.scheduleEdit:SetScript("OnEnterPressed", function()
            createFrame.acceptBtn:Click()
        end)

        -- Campo Con Nota (Checkbox)
        createFrame.withNoteCheck = CreateFrame("CheckButton", "RaidDominionCreateBandWithNoteCheck", createFrame, "UICheckButtonTemplate")
        createFrame.withNoteCheck:SetSize(24, 24)
        createFrame.withNoteCheck:SetPoint("TOPLEFT", 115, -145)
        createFrame.withNoteCheck:SetScript("OnClick", function(self)
            local isChecked = self:GetChecked()
            -- El toggle visual es automático con UICheckButtonTemplate, 
            -- pero podemos añadir feedback si fuera necesario.
        end)
        
        createFrame.withNoteLabel = UI.CreateLabel(createFrame, "Con nota")
        createFrame.withNoteLabel:SetPoint("LEFT", createFrame.withNoteCheck, "RIGHT", 5, 0)
        createFrame.withNoteLabel:SetFontObject("GameFontHighlightSmall")
        
        -- Botón Aceptar
        createFrame.acceptBtn = CreateFrame("Button", nil, createFrame, "UIPanelButtonTemplate")
        createFrame.acceptBtn:SetSize(120, 25)
        createFrame.acceptBtn:SetPoint("BOTTOMLEFT", 30, 15)
        createFrame.acceptBtn:SetText("Aceptar")
        createFrame.acceptBtn:SetScript("OnClick", function()
            local permLevel = GetPerms()
            if permLevel < 2 then
                local mm = RD.modules and RD.modules.messageManager
                if mm and mm.PermissionError then
                    mm:PermissionError("crear o editar bandas")
                else
                    Log("|cffff0000[RaidDominion]|r Error: No tienes permisos para crear o editar bandas.")
                end
                createFrame:Hide()
                return
            end
            local name = createFrame.nameEdit:GetText()
            local minGS = tonumber(createFrame.gsEdit:GetText()) or 5000
            local schedule = createFrame.scheduleEdit:GetText()
            local withNote = createFrame.withNoteCheck:GetChecked() and 1 or 0
            
            local coreData = EnsureCoreData()
            
            if name and name ~= "" then
                if createFrame.isEditing and createFrame.bandIndex then
                    -- Actualizar banda existente
                    coreData[createFrame.bandIndex].name = name
                    coreData[createFrame.bandIndex].minGS = minGS
                    coreData[createFrame.bandIndex].schedule = schedule
                    coreData[createFrame.bandIndex].withNote = withNote
                else
                    -- Crear nueva banda
                    table.insert(coreData, {
                        name = name,
                        minGS = minGS,
                        schedule = schedule,
                        withNote = withNote,
                        members = {}
                    })
                end
                
                createFrame:Hide()
                
                -- Actualizar ventana de bandas
                RD.utils.coreBands.ShowCoreBandsWindow()
            end
        end)
        
        -- Botón Cancelar
        createFrame.cancelBtn = CreateFrame("Button", nil, createFrame, "UIPanelButtonTemplate")
        createFrame.cancelBtn:SetSize(120, 25)
        createFrame.cancelBtn:SetPoint("BOTTOMRIGHT", -30, 15)
        createFrame.cancelBtn:SetText("Cancelar")
        createFrame.cancelBtn:SetScript("OnClick", function()
            createFrame:Hide()
        end)
    end
    return createFrame
end

-- Función auxiliar para agregar un jugador a una banda
local function addPlayerToBand(bandIndex, playerData)
    -- Verificar permisos (Nivel 2+ requerido para modificar el core)
    if GetPerms() < 2 then
        return false
    end

    if not bandIndex or not playerData or not playerData.name then
        return false
    end
    
    local coreData = EnsureCoreData()
    local band = coreData[bandIndex]
    if not band then
        Log("|cffff0000[RaidDominion]|r Error: Banda no encontrada")
        return false
    end
    
    -- Asegurar que la tabla de miembros existe
    if not band.members then
        band.members = {}
    end
    
    -- Verificar si el jugador ya está en la banda (insensible a mayúsculas/minúsculas)
    local cleanNewName = CleanName(playerData.name)
    local localPlayerName = CleanName(UnitName("player"))
    
    for _, member in ipairs(band.members) do
        if CleanName(member.name) == cleanNewName then
            -- Si es el jugador local y ya está en la banda pero no tiene rol, no dar error
            -- (Ya que el renderizado lo oculta y queremos que pueda verse si lo agrega)
            if cleanNewName == localPlayerName then
                local role = (member.role or "nuevo"):lower()
                if role == "nuevo" or role == "otro" then
                    -- Ya está, pero como "nuevo/otro" (oculto). No hacemos nada y retornamos true
                    -- porque técnicamente ya existe en los datos.
                    Log("|cffffff00[RaidDominion]|r El jugador local ya está en la banda (agrupación Nuevo).")
                    return true
                end
            end
            
            -- Si ya existe, simplemente actualizamos el rol si se proporciona uno diferente de "nuevo"
            if playerData.role and playerData.role ~= "nuevo" then
                member.role = playerData.role
                Log("|cff00ff00[RaidDominion]|r Rol de " .. member.name .. " actualizado a " .. playerData.role .. " en la banda " .. band.name)
                
                -- Actualizar la interfaz solo si ya está abierta
                local f3 = _G["RaidDominionCoreListFrame"]
                if f3 and f3:IsVisible() and RD.utils.coreBands.ShowCoreBandsWindow then
                    RD.utils.coreBands.ShowCoreBandsWindow()
                end
                return true
            end

            Log("|cffff0000[RaidDominion]|r Error: El jugador ya está en la banda")
            return false
        end
    end
    
    -- Crear el nuevo miembro con datos básicos, explicitamente inicializando isLeader e isSanctioned en false
    local newMember = {
        name = CapitalizeName(playerData.name),
        role = playerData.role or "nuevo", -- Rol por defecto cambiado a "nuevo"
        class = playerData.class or "", -- Clase del jugador, vacía si no se proporciona
        isLeader = false,
        isSanctioned = false
    }
    
    -- Agregar el miembro a la banda
    table.insert(band.members, newMember)
    
    -- Actualizar la interfaz solo si ya está abierta
    local f3 = _G["RaidDominionCoreListFrame"]
    if f3 and f3:IsVisible() and RD.utils.coreBands.ShowCoreBandsWindow then
        RD.utils.coreBands.ShowCoreBandsWindow()
    end
    
    return true
end
coreBandsUtils.AddPlayerToBand = addPlayerToBand

-- Función para abrir el popup de invitación
local function getOrCreateInvitePopup(bandIndex)
    local invitePopup = _G["RaidDominionInvitePopup"]
    if not invitePopup then
        invitePopup = CreateFrame("Frame", "RaidDominionInvitePopup", UIParent)
        invitePopup:SetFrameStrata("DIALOG")
        invitePopup:SetToplevel(true)
        invitePopup:SetSize(270, 150)
        invitePopup:SetPoint("CENTER")
        invitePopup:SetBackdrop({
            bgFile = "Interface/Tooltips/UI-Tooltip-Background",
            edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 }
        })
        invitePopup:SetBackdropColor(0, 0, 0, 0.9)
        invitePopup:SetBackdropBorderColor(1, 1, 1, 0.5)
        invitePopup:EnableMouse(true)
        invitePopup:SetMovable(true)
        invitePopup:RegisterForDrag("LeftButton")
        invitePopup:SetScript("OnDragStart", invitePopup.StartMoving)
        invitePopup:SetScript("OnDragStop", invitePopup.StopMovingOrSizing)
        
        -- Hacer escapable con ESC
        tinsert(UISpecialFrames, invitePopup:GetName())
        
        -- Título
        invitePopup.title = UI.CreateLabel(invitePopup, "Invitar Jugador", "GameFontNormal")
        invitePopup.title:SetPoint("TOP", 0, -15)
        
        -- Botón Cerrar
        invitePopup.closeBtn = CreateFrame("Button", nil, invitePopup, "UIPanelCloseButton")
        invitePopup.closeBtn:SetPoint("TOPRIGHT", -5, -5)
        invitePopup.closeBtn:SetScript("OnClick", function()
            invitePopup:Hide()
        end)
        
        -- Campo Nombre
        invitePopup.nameLabel = UI.CreateLabel(invitePopup, "Nombre del jugador:")
        invitePopup.nameLabel:SetPoint("TOPLEFT", 20, -50)
        
        invitePopup.nameEdit = UI.CreateEditBox(nil, invitePopup, 240, 25)
        invitePopup.nameEdit:SetPoint("TOPLEFT", 20, -70)
        invitePopup.nameEdit:SetMaxLetters(20)
        invitePopup.nameEdit:SetAutoFocus(true)

        -- Autocompletado robusto usando OnChar
        invitePopup.nameEdit:SetScript("OnChar", function(self, char)
            local text = self:GetText()
            local textLen = text:len()
            local cursor = self:GetCursorPosition()
            
            -- Solo autocompletar si el cursor está al final
            if cursor == textLen then
                local players = {}
                local seen = {}
                
                -- 1. Hermandad
                if IsInGuild() then
                    for i = 1, GetNumGuildMembers(true) do
                        local name = GetGuildRosterInfo(i)
                        if name then
                            name = name:match("([^%-]+)")
                            if name and not seen[name:lower()] then
                                table.insert(players, name)
                                seen[name:lower()] = true
                            end
                        end
                    end
                end
                
                -- 2. Otros Cores/Posadas
                local coreData = EnsureCoreData()
                if coreData then
                    for _, band in ipairs(coreData) do
                        if band.members then
                            for _, member in ipairs(band.members) do
                                if member.name then
                                    local name = member.name:match("([^%-]+)")
                                    if name and not seen[name:lower()] then
                                        table.insert(players, name)
                                        seen[name:lower()] = true
                                    end
                                end
                            end
                        end
                    end
                end
                
                -- Buscar coincidencia
                local searchText = text:lower()
                for _, name in ipairs(players) do
                    if name:lower():find("^" .. searchText) and name:len() > textLen then
                        local extension = name:sub(textLen + 1)
                        self:Insert(extension)
                        self:HighlightText(textLen, name:len())
                        self:SetCursorPosition(textLen)
                        break
                    end
                end
            end
        end)

        invitePopup.nameEdit:SetScript("OnEscapePressed", function(self)
            invitePopup:Hide()
        end)
        invitePopup.nameEdit:SetScript("OnEnterPressed", function()
            invitePopup.acceptBtn:Click()
        end)
        
        -- Botón Aceptar
        invitePopup.acceptBtn = CreateFrame("Button", nil, invitePopup, "UIPanelButtonTemplate")
        invitePopup.acceptBtn:SetSize(100, 25)
        invitePopup.acceptBtn:SetPoint("BOTTOMLEFT", 30, 15)
        invitePopup.acceptBtn:SetText("Aceptar")
        invitePopup.acceptBtn:SetScript("OnClick", function()
            local permLevel = GetPerms()
            if permLevel < 2 then
                local mm = RD.modules and RD.modules.messageManager
                if mm and mm.PermissionError then
                    mm:PermissionError("añadir jugadores")
                else
                    Log("|cffff0000[RaidDominion]|r Error: No tienes permisos para añadir jugadores.")
                end
                invitePopup:Hide()
                return
            end
            local playerName = invitePopup.nameEdit:GetText()
            if playerName and playerName ~= "" then
                -- Agregar el jugador a la banda con rol "nuevo" por defecto
                addPlayerToBand(invitePopup.bandIndex, {
                    name = playerName,
                    role = "nuevo" -- Rol por defecto cambiado a "nuevo"
                })
                
                -- Ocultar el popup
                invitePopup:Hide()
            else
                Log("|cffff0000[RaidDominion]|r Error: Debes ingresar un nombre de jugador")
            end
        end)
        
        -- Botón Cancelar
        invitePopup.cancelBtn = CreateFrame("Button", nil, invitePopup, "UIPanelButtonTemplate")
        invitePopup.cancelBtn:SetSize(100, 25)
        invitePopup.cancelBtn:SetPoint("BOTTOMRIGHT", -30, 15)
        invitePopup.cancelBtn:SetText("Cancelar")
        invitePopup.cancelBtn:SetScript("OnClick", function()
            invitePopup:Hide()
        end)
    end
    
    -- Almacenar el índice de la banda en el popup
    invitePopup.bandIndex = bandIndex
    
    -- Limpiar el campo de texto
    invitePopup.nameEdit:SetText("")
    
    return invitePopup
end

-- Función para abrir el marco de edición de jugador
function coreBandsUtils.GetOrCreatePlayerEditFrame(playerData, isGearscoreMode)
    local playerEditFrame = _G["RaidDominionPlayerEditFrame"]
    if not playerEditFrame then
        playerEditFrame = CreateFrame("Frame", "RaidDominionPlayerEditFrame", UIParent)
        playerEditFrame:SetFrameStrata("DIALOG")
        playerEditFrame:SetToplevel(true)
        playerEditFrame:SetSize(350, 420) -- Aumentado para acomodar nota oficial y padding
        playerEditFrame:SetPoint("CENTER")
        playerEditFrame:SetBackdrop({
            bgFile = "Interface/Tooltips/UI-Tooltip-Background",
            edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 }
        })
        playerEditFrame:SetBackdropColor(0, 0, 0, 0.9)
        playerEditFrame:SetBackdropBorderColor(1, 1, 1, 0.5)
        playerEditFrame:EnableMouse(true)
        playerEditFrame:SetMovable(true)
        playerEditFrame:RegisterForDrag("LeftButton")
        playerEditFrame:SetScript("OnDragStart", playerEditFrame.StartMoving)
        playerEditFrame:SetScript("OnDragStop", playerEditFrame.StopMovingOrSizing)
        
        -- Hacer escapable con ESC
        tinsert(UISpecialFrames, playerEditFrame:GetName())
        
        -- Registrar eventos para actualización de hermandad
        -- Título
        playerEditFrame.title = UI.CreateLabel(playerEditFrame, "Editar Jugador", "GameFontNormal")
        playerEditFrame.title:SetPoint("TOP", 0, -15)
        
        -- Botón Cerrar
        playerEditFrame.closeBtn = CreateFrame("Button", nil, playerEditFrame, "UIPanelCloseButton")
        playerEditFrame.closeBtn:SetPoint("TOPRIGHT", -5, -5)
        playerEditFrame.closeBtn:SetScript("OnClick", function()
            playerEditFrame:Hide()
        end)
        
        -- Campo Nombre
        playerEditFrame.nameLabel = UI.CreateLabel(playerEditFrame, "Nombre:")
        playerEditFrame.nameLabel:SetPoint("TOPLEFT", 20, -50)
        
        playerEditFrame.nameEdit = UI.CreateEditBox("RaidDominionPlayerEditFrameNameEdit", playerEditFrame, 200, 25)
        playerEditFrame.nameEdit:SetPoint("TOPLEFT", 100, -45)
        playerEditFrame.nameEdit:SetMaxLetters(20)
        playerEditFrame.nameEdit:SetScript("OnTabPressed", function()
            playerEditFrame.noteEdit:SetFocus()
        end)
        playerEditFrame.nameEdit:SetScript("OnEscapePressed", function(self)
            playerEditFrame:Hide()
        end)
        
        -- Campo Rol (DropDown)
        playerEditFrame.roleLabel = UI.CreateLabel(playerEditFrame, "Rol:")
        playerEditFrame.roleLabel:SetPoint("TOPLEFT", 20, -85)
        
        playerEditFrame.roleDropDown = CreateFrame("Frame", "RaidDominionPlayerEditFrameRoleDropDown", playerEditFrame, "UIDropDownMenuTemplate")
        playerEditFrame.roleDropDown:SetPoint("TOPLEFT", 100, -80)
        UIDropDownMenu_SetWidth(playerEditFrame.roleDropDown, 180)
        
        -- Guardar la selección actual
        playerEditFrame.selectedRole = ""
        
        -- Campo Líder
        playerEditFrame.isLeaderCheck = CreateFrame("CheckButton", nil, playerEditFrame, "UICheckButtonTemplate")
        playerEditFrame.isLeaderCheck:SetSize(20, 20)
        playerEditFrame.isLeaderCheck:SetPoint("TOPLEFT", 100, -115)
        
        playerEditFrame.isLeaderLabel = UI.CreateLabel(playerEditFrame, "Es Líder")
        playerEditFrame.isLeaderLabel:SetPoint("LEFT", playerEditFrame.isLeaderCheck, "RIGHT", 5, 0)
        
        -- Campo Sancionado
        playerEditFrame.isSanctionedCheck = CreateFrame("CheckButton", nil, playerEditFrame, "UICheckButtonTemplate")
        playerEditFrame.isSanctionedCheck:SetSize(20, 20)
        playerEditFrame.isSanctionedCheck:SetPoint("TOPLEFT", 100, -140)
        
        playerEditFrame.isSanctionedLabel = UI.CreateLabel(playerEditFrame, "Sancionado")
        playerEditFrame.isSanctionedLabel:SetPoint("LEFT", playerEditFrame.isSanctionedCheck, "RIGHT", 5, 0)

        -- Trasladar a banda (DropDown)
        playerEditFrame.moveLabel = UI.CreateLabel(playerEditFrame, "Mover a:")
        playerEditFrame.moveLabel:SetPoint("TOPLEFT", 20, -175)
        
        playerEditFrame.moveDropDown = CreateFrame("Frame", "RaidDominionPlayerEditFrameMoveDropDown", playerEditFrame, "UIDropDownMenuTemplate")
        playerEditFrame.moveDropDown:SetPoint("TOPLEFT", 100, -170)
        UIDropDownMenu_SetWidth(playerEditFrame.moveDropDown, 180)
        
        playerEditFrame.targetBandIndex = nil
        
        -- Sección de Hermandad (Solo para jugadores del roster)
        playerEditFrame.guildSection = CreateFrame("Frame", nil, playerEditFrame)
        playerEditFrame.guildSection:SetSize(310, 100)
        playerEditFrame.guildSection:SetPoint("TOPLEFT", 20, -200)
        
        -- Rango
        playerEditFrame.rankLabel = UI.CreateLabel(playerEditFrame.guildSection, "Rango:")
        playerEditFrame.rankLabel:SetPoint("TOPLEFT", 0, 0)
        
        playerEditFrame.rankText = UI.CreateLabel(playerEditFrame.guildSection, "-", "GameFontNormal")
        playerEditFrame.rankText:SetPoint("LEFT", playerEditFrame.rankLabel, "RIGHT", 10, 0)
        
        -- Función para refrescar datos de hermandad en el cuadro de edición
        playerEditFrame.RefreshGuildData = function(force)
            local name = playerEditFrame.nameEdit:GetText()
            if not name or name == "" then return end
            
            local cleanName = CleanName(name)
            
            -- Limpiar por si no se encuentra
            playerEditFrame.rankText:SetText("")
            local isMember = false
            
            -- Si forzamos, invalidamos la caché de tiempo para obtener datos reales del servidor
            if force then
                lastGuildUpdate = 0
            end
            
            -- Búsqueda optimizada en el roster usando la caché
            UpdateGuildOnlineCache(force)
            local memberData = guildFullCache[cleanName]
            
            if memberData then
                playerEditFrame.rankText:SetText(memberData.rank or "-")
                -- Solo actualizar las notas si el usuario NO las está editando activamente
                if not playerEditFrame.noteEdit:HasFocus() then
                    playerEditFrame.noteEdit:SetText(memberData.note or "")
                end
                if not playerEditFrame.officerNoteEdit:HasFocus() then
                    playerEditFrame.officerNoteEdit:SetText(memberData.officerNote or "")
                end
                isMember = true
                playerEditFrame.guildIndex = memberData.index -- Guardar para acceso rápido
            end

            -- Controlar visibilidad de botones y textos según pertenencia
            if isMember then
                playerEditFrame.rankLabel:Show()
                playerEditFrame.rankText:Show()
                playerEditFrame.promoteBtn:Show()
                playerEditFrame.demoteBtn:Show()
                playerEditFrame.kickBtn:Show()
                playerEditFrame.inviteGuildBtn:Hide()
                playerEditFrame.noteLabel:Show()
                playerEditFrame.noteEdit:Show()
                playerEditFrame.officerNoteLabel:Show()
                playerEditFrame.officerNoteEdit:Show()
            else
                playerEditFrame.rankLabel:Hide()
                playerEditFrame.rankText:Hide()
                playerEditFrame.promoteBtn:Hide()
                playerEditFrame.demoteBtn:Hide()
                playerEditFrame.kickBtn:Hide()
                playerEditFrame.inviteGuildBtn:Show()
                -- Posicionar el botón de invitación donde estaría el rango
                playerEditFrame.inviteGuildBtn:SetPoint("LEFT", playerEditFrame.guildSection, "TOPLEFT", 0, -10)
                
                -- Ocultar notas si no es de la hermandad
                playerEditFrame.noteLabel:Hide()
                playerEditFrame.noteEdit:Hide()
                playerEditFrame.officerNoteLabel:Hide()
                playerEditFrame.officerNoteEdit:Hide()
            end
        end

        -- Botones de Rango
        playerEditFrame.promoteBtn = CreateStyledButton("RD_PlayerEditPromote", playerEditFrame.guildSection, 25, 25, nil, "Interface/Icons/Spell_ChargePositive", "Ascender en Hermandad")
        playerEditFrame.promoteBtn:SetPoint("LEFT", playerEditFrame.rankText, "RIGHT", 10, 0)
        playerEditFrame.promoteBtn:SetScript("OnClick", function()
            local permLevel = GetPerms()
            if permLevel < 2 then
                local mm = RD.modules and RD.modules.messageManager
                if mm and mm.PermissionError then
                    mm:PermissionError("gestionar rangos")
                else
                    Log("|cffff0000[RaidDominion]|r Error: No tienes permisos para gestionar rangos.")
                end
                return
            end
            local name = playerEditFrame.nameEdit:GetText()
            if name and name ~= "" then
                GuildPromote(name)
                GuildRoster() -- Solicitar actualización inmediata
                Log("|cff00ff00[RaidDominion]|r Ascendiendo a " .. name)
            end
        end)
        
        playerEditFrame.demoteBtn = CreateStyledButton("RD_PlayerEditDemote", playerEditFrame.guildSection, 25, 25, nil, "Interface/Icons/Spell_ChargeNegative", "Degradar en Hermandad")
        playerEditFrame.demoteBtn:SetPoint("LEFT", playerEditFrame.promoteBtn, "RIGHT", 5, 0)
        playerEditFrame.demoteBtn:SetScript("OnClick", function()
            local permLevel = GetPerms()
            if permLevel < 2 then
                local mm = RD.modules and RD.modules.messageManager
                if mm and mm.PermissionError then
                    mm:PermissionError("gestionar rangos")
                else
                    Log("|cffff0000[RaidDominion]|r Error: No tienes permisos para gestionar rangos.")
                end
                return
            end
            local name = playerEditFrame.nameEdit:GetText()
            if name and name ~= "" then
                GuildDemote(name)
                GuildRoster() -- Solicitar actualización inmediata
                Log("|cff00ff00[RaidDominion]|r Degradando a " .. name)
            end
        end)

        -- Botón Expulsar de Hermandad
        playerEditFrame.kickBtn = CreateStyledButton("RD_PlayerEditKick", playerEditFrame.guildSection, 25, 25, nil, "Interface/Icons/Spell_Shadow_DeathCoil", "Expulsar de Hermandad")
        playerEditFrame.kickBtn:SetPoint("LEFT", playerEditFrame.demoteBtn, "RIGHT", 5, 0)
        
        -- Sobreescribir el OnClick de kickBtn para usar GuildUninvite directamente con confirmación propia si se prefiere
        playerEditFrame.kickBtn:SetScript("OnClick", function()
            local permLevel = GetPerms()
            if permLevel < 2 then
                local mm = RD.modules and RD.modules.messageManager
                if mm and mm.PermissionError then
                    mm:PermissionError("expulsar de la hermandad")
                else
                    Log("|cffff0000[RaidDominion]|r Error: No tienes permisos para expulsar de la hermandad.")
                end
                return
            end
            local name = playerEditFrame.nameEdit:GetText()
            if name and name ~= "" then
                if IsShiftKeyDown() then
                    GuildUninvite(name)
                    GuildRoster()
                    Log("|cffff0000[RaidDominion]|r Expulsando a " .. name .. " de la hermandad.")
                else
                    StaticPopup_Show("RD_CONFIRM_GUILD_KICK", name, nil, { name = name })
                end
            end
        end)

        -- Botón Invitar a Hermandad
        playerEditFrame.inviteGuildBtn = CreateStyledButton("RD_PlayerEditGuildInvite", playerEditFrame.guildSection, 25, 25, nil, "Interface/Icons/Spell_Holy_PrayerOfSpirit", "Invitar a la Hermandad")
        playerEditFrame.inviteGuildBtn:SetPoint("LEFT", playerEditFrame.rankText, "RIGHT", 10, 0)
        playerEditFrame.inviteGuildBtn:SetScript("OnClick", function()
            local permLevel = GetPerms()
            if permLevel < 2 then
                local mm = RD.modules and RD.modules.messageManager
                if mm and mm.PermissionError then
                    mm:PermissionError("invitar a la hermandad")
                else
                    Log("|cffff0000[RaidDominion]|r Error: No tienes permisos para invitar a la hermandad.")
                end
                return
            end
            local name = playerEditFrame.nameEdit:GetText()
            if name and name ~= "" then
                GuildInvite(name)
                Log("|cff00ff00[RaidDominion]|r Invitando a " .. name .. " a la hermandad.")
            end
        end)
        playerEditFrame.inviteGuildBtn:Hide() -- Oculto por defecto
        
        -- Nota Pública
        playerEditFrame.noteLabel = UI.CreateLabel(playerEditFrame.guildSection, "Nota Pública:")
        playerEditFrame.noteLabel:SetPoint("TOPLEFT", 0, -35)
        
        playerEditFrame.noteEdit = UI.CreateEditBox("RaidDominionPlayerEditFrameNoteEdit", playerEditFrame.guildSection, 180, 25)
        playerEditFrame.noteEdit:SetPoint("TOPLEFT", 100, -30)
        playerEditFrame.noteEdit:SetMaxLetters(31)
        playerEditFrame.noteEdit:SetScript("OnTabPressed", function()
            playerEditFrame.officerNoteEdit:SetFocus()
        end)
        playerEditFrame.noteEdit:SetScript("OnEscapePressed", function(self)
            playerEditFrame:Hide()
        end)
        playerEditFrame.noteEdit:SetScript("OnEnterPressed", function(self)
            local permLevel = GetPerms()
            if permLevel < 1 then
                local mm = RD.modules and RD.modules.messageManager
                if mm and mm.PermissionError then
                    mm:PermissionError("editar notas")
                else
                    Log("|cffff0000[RaidDominion]|r Error: No tienes permisos para editar notas.")
                end
                return
            end
            local name = playerEditFrame.nameEdit:GetText()
            local note = self:GetText()
            if name and name ~= "" then
                local idx = playerEditFrame.guildIndex
                if idx then
                    GuildRosterSetPublicNote(idx, note)
                    Log("|cff00ff00[RaidDominion]|r Nota pública actualizada para " .. name)
                end
                self:ClearFocus()
            end
        end)

        -- Nota Oficial
        playerEditFrame.officerNoteLabel = UI.CreateLabel(playerEditFrame.guildSection, "Nota Oficial:")
        playerEditFrame.officerNoteLabel:SetPoint("TOPLEFT", 0, -70)
        
        playerEditFrame.officerNoteEdit = UI.CreateEditBox(nil, playerEditFrame.guildSection, 180, 25)
        playerEditFrame.officerNoteEdit:SetPoint("TOPLEFT", 100, -65)
        playerEditFrame.officerNoteEdit:SetMaxLetters(31)
        playerEditFrame.officerNoteEdit:SetScript("OnTabPressed", function()
            playerEditFrame.nameEdit:SetFocus()
        end)
        playerEditFrame.officerNoteEdit:SetScript("OnEscapePressed", function(self)
            playerEditFrame:Hide()
        end)
        playerEditFrame.officerNoteEdit:SetScript("OnEnterPressed", function(self)
            local permLevel = GetPerms()
            if permLevel < 2 then
                local mm = RD.modules and RD.modules.messageManager
                if mm and mm.PermissionError then
                    mm:PermissionError("editar notas de hermandad")
                else
                    Log("|cffff0000[RaidDominion]|r Error: Solo oficiales pueden editar notas oficiales.")
                end
                return
            end
            local name = playerEditFrame.nameEdit:GetText()
            local note = self:GetText()
            if name and name ~= "" then
                local idx = playerEditFrame.guildIndex
                if idx then
                    GuildRosterSetOfficerNote(idx, note)
                    Log("|cff00ff00[RaidDominion]|r Nota oficial actualizada para " .. name)
                end
                self:ClearFocus()
            end
        end)

        -- Botón Eliminar
        playerEditFrame.deleteBtn = CreateFrame("Button", nil, playerEditFrame, "UIPanelButtonTemplate")
        playerEditFrame.deleteBtn:SetSize(120, 25)
        playerEditFrame.deleteBtn:SetPoint("BOTTOM", 0, 60)
        playerEditFrame.deleteBtn:SetText("|cffff0000Eliminar Jugador|r")
        playerEditFrame.deleteBtn:SetScript("OnClick", function()
            local permLevel = GetPerms()
            if permLevel < 2 then
                local mm = RD.modules and RD.modules.messageManager
                if mm and mm.PermissionError then
                    mm:PermissionError("eliminar jugadores")
                else
                    Log("|cffff0000[RaidDominion]|r Error: No tienes permisos para eliminar jugadores de la banda.")
                end
                return
            end
            local context = playerEditFrame.context
            if context and context.bandIndex and context.memberIndex then
                local coreData = EnsureCoreData()
                local band = coreData[context.bandIndex]
                if band and band.members then
                    table.remove(band.members, context.memberIndex)
                    Log("|cffff0000[RaidDominion]|r Jugador eliminado: " .. playerEditFrame.nameEdit:GetText())
                    playerEditFrame:Hide()
                    RD.utils.coreBands.ShowCoreBandsWindow()
                end
            end
        end)
        
        -- Botón Aceptar
        playerEditFrame.acceptBtn = CreateFrame("Button", nil, playerEditFrame, "UIPanelButtonTemplate")
        playerEditFrame.acceptBtn:SetSize(100, 25)
        playerEditFrame.acceptBtn:SetPoint("BOTTOMLEFT", 30, 20)
        playerEditFrame.acceptBtn:SetText("Guardar")
        playerEditFrame.acceptBtn:SetScript("OnClick", function()
            local permLevel = GetPerms()
            -- Obtener los valores de los campos
            local name = playerEditFrame.nameEdit:GetText()
            local role = playerEditFrame.selectedRole
            
            -- Asegurar que el rol no esté vacío. Si lo está, asignar "Nuevo" como predeterminado
            if not role or role == "" or role == "Seleccionar Rol" then
                role = "Nuevo"
            end
            
            local isLeader = playerEditFrame.isLeaderCheck:GetChecked()
            local isSanctioned = playerEditFrame.isSanctionedCheck:GetChecked()
            local targetBandIndex = playerEditFrame.targetBandIndex
            
            -- Guardar Notas si la sección de hermandad está visible (Nivel 1+ puede editar notas)
            if playerEditFrame.guildSection:IsVisible() then
                if permLevel >= 1 then
                    local publicNote = playerEditFrame.noteEdit:GetText()
                    local officerNote = playerEditFrame.officerNoteEdit:GetText()
                    if name and name ~= "" then
                        local cleanName = CleanName(name)
                        UpdateGuildOnlineCache()
                        local memberData = guildFullCache[cleanName]
                        local guildIdx = playerEditFrame.guildIndex or (memberData and memberData.index)
                        
                        -- Verificación de seguridad: El índice debe corresponder al jugador correcto
                        if guildIdx then
                            local gName = GetGuildRosterInfo(guildIdx)
                            if not gName or CleanName(gName) ~= cleanName then
                                -- Si el índice no coincide, buscarlo de nuevo
                                guildIdx = nil
                            end
                        end

                        -- Si no tenemos índice o el que teníamos no era válido, buscamos en toda la hermandad
                        if not guildIdx then
                            for i = 1, GetNumGuildMembers(true) do
                                local nameCheck = GetGuildRosterInfo(i)
                                if nameCheck and CleanName(nameCheck) == cleanName then
                                    guildIdx = i
                                    playerEditFrame.guildIndex = i
                                    break
                                end
                            end
                        end

                        if guildIdx then
                            -- DEBUG: Loggear el intento de guardado
                            Log("|cff00ff00[RaidDominion]|r Guardando nota para " .. name .. " (Índice: " .. guildIdx .. ")")
                            
                            GuildRosterSetPublicNote(guildIdx, publicNote)
                            -- Solo Oficiales (Rango Oficial/Admin+) pueden editar notas oficiales
                            if permLevel >= 2 then
                                GuildRosterSetOfficerNote(guildIdx, officerNote)
                            end
                            
                            -- Actualizar la caché local inmediatamente para que el refresco visual sea instantáneo
                            if memberData then
                                memberData.note = publicNote
                                if permLevel >= 2 then
                                    memberData.officerNote = officerNote
                                end
                            end
                            
                            -- Forzar un ciclo de actualización de la hermandad para sincronizar con el servidor
                            -- Pero NO llamar a UpdateGuildOnlineCache(true) inmediatamente aquí, 
                            -- dejar que el evento GUILD_ROSTER_UPDATE lo haga de forma natural.
                            GuildRoster()
                            lastGuildUpdate = 0 
                        else
                            Log("|cffff0000[RaidDominion]|r Error: No se pudo encontrar al jugador en la hermandad para guardar la nota.")
                        end
                    end
                else
                    local mm = RD.modules and RD.modules.messageManager
                    if mm and mm.PermissionError then
                        mm:PermissionError("editar notas de hermandad")
                    else
                        Log("|cffff0000[RaidDominion]|r Error: No tienes permisos para editar notas de hermandad.")
                    end
                end
            end

            -- Si estamos en modo búsqueda/reconocimiento, también queremos poder guardar el estado de sancionado
            -- Buscamos al jugador en todas las bandas del Core para aplicar el cambio globalmente
            if playerEditFrame.isSearchMode and permLevel >= 2 then
                if name and name ~= "" then
                    local cleanTarget = CleanName(name)
                    local coreData = EnsureCoreData()
                    local foundInCore = false
                    for bIdx, band in ipairs(coreData) do
                        if band.members then
                            for mIdx, member in ipairs(band.members) do
                                if member.name and CleanName(member.name) == cleanTarget then
                                    member.isSanctioned = isSanctioned
                                    foundInCore = true
                                end
                            end
                        end
                    end
                    if foundInCore then
                        Log("|cff00ff00[RaidDominion]|r Estado de sanción actualizado globalmente para: " .. name)
                        -- Solo actualizar la ventana del Core si ya estaba abierta y no estamos en modo búsqueda
                        local coreListFrame = _G["RaidDominionCoreListFrame"]
                        if coreListFrame and coreListFrame:IsVisible() and not playerEditFrame.isSearchMode then
                            RD.utils.coreBands.ShowCoreBandsWindow()
                        end
                    end
                end
            end
            
            -- Verificar permisos para editar la banda (Rango Oficial/Admin+)
            if permLevel < 2 then
                -- Si solo cambió la nota, permitir que se cierre
                -- Pero no actualizamos los datos de la banda
                playerEditFrame:Hide()
                return
            end
            
            -- Obtener el contexto de edición
            local context = playerEditFrame.context
            if context and context.bandIndex and context.memberIndex then
                local coreData = EnsureCoreData()
                local sourceBand = coreData[context.bandIndex]
                if sourceBand and sourceBand.members and sourceBand.members[context.memberIndex] then
                    -- Datos del miembro preservando campos no editables (como clase original si existe)
                    local currentMember = sourceBand.members[context.memberIndex]
                    local memberData = {
                        name = name,
                        role = role,
                        class = playerEditFrame.playerClass or currentMember.class,
                        isLeader = isLeader,
                        isSanctioned = isSanctioned
                    }
                    
                    -- Si se seleccionó una banda destino diferente
                    if targetBandIndex and targetBandIndex ~= context.bandIndex then
                        local targetBand = coreData[targetBandIndex]
                        if targetBand then
                            -- Eliminar de la banda actual y añadir a la nueva
                            table.remove(sourceBand.members, context.memberIndex)
                            if not targetBand.members then targetBand.members = {} end
                            table.insert(targetBand.members, memberData)
                            Log("|cff00ff00[RaidDominion]|r Jugador trasladado a: " .. (targetBand.name or targetBandIndex))
                        end
                    else
                        -- Actualizar en la banda actual
                        sourceBand.members[context.memberIndex] = memberData
                        Log("|cff00ff00[RaidDominion]|r Jugador actualizado: " .. name)
                    end
                    
                    -- Actualizar la interfaz solo si ya estaba abierta (evita aperturas no deseadas)
                    local coreListFrame = _G["RaidDominionCoreListFrame"]
                    if coreListFrame and coreListFrame:IsVisible() then
                        RD.utils.coreBands.ShowCoreBandsWindow()
                    end
                    -- Forzar refresco de las estadísticas y caché de hermandad
                    GuildRoster()
                end
            end
            
            playerEditFrame:Hide()
        end)
        
        -- Botón Cancelar
        playerEditFrame.cancelBtn = CreateFrame("Button", nil, playerEditFrame, "UIPanelButtonTemplate")
        playerEditFrame.cancelBtn:SetSize(100, 25)
        playerEditFrame.cancelBtn:SetPoint("BOTTOMRIGHT", -30, 20)
        playerEditFrame.cancelBtn:SetText("Cancelar")
        playerEditFrame.cancelBtn:SetScript("OnClick", function()
            playerEditFrame:Hide()
        end)
    end
    
    -- Cargar datos del jugador si se proporcionan
    if playerData then
        -- Reiniciar campos de datos
        playerEditFrame.selectedRole = ""
        playerEditFrame.targetBandIndex = nil
        playerEditFrame.guildIndex = nil
        playerEditFrame.playerClass = ""
        
        -- Reinicializar menús para asegurar datos actualizados
        UIDropDownMenu_Initialize(playerEditFrame.roleDropDown, function(self, level)
            local roleOptions = { "Tank", "Healer", "Dps", "Nuevo" }
            for _, role in ipairs(roleOptions) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = role
                info.value = role
                info.func = function(self)
                    UIDropDownMenu_SetText(playerEditFrame.roleDropDown, self:GetText())
                    playerEditFrame.selectedRole = self:GetText()
                end
                UIDropDownMenu_AddButton(info, level)
            end
        end)
        
        UIDropDownMenu_Initialize(playerEditFrame.moveDropDown, function(self, level)
            local bands = EnsureCoreData()
            for i, band in ipairs(bands) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = band.name or ("Banda " .. i)
                info.value = i
                info.func = function(self)
                    UIDropDownMenu_SetText(playerEditFrame.moveDropDown, self:GetText())
                    playerEditFrame.targetBandIndex = self.value
                end
                UIDropDownMenu_AddButton(info, level)
            end
        end)

        -- Obtener datos frescos del core si hay contexto
        if playerEditFrame.context and playerEditFrame.context.bandIndex and playerEditFrame.context.memberIndex then
            local coreData = EnsureCoreData()
            local band = coreData[playerEditFrame.context.bandIndex]
            local mData = band and band.members and band.members[playerEditFrame.context.memberIndex]
            if mData then
                playerData = mData -- Usar los datos reales del DB
            end
        end

        playerEditFrame.nameEdit:SetText(playerData.name or "")
        playerEditFrame.guildIndex = playerData.index -- Guardar el índice de hermandad si viene de Gearscore
        local currentRole = playerData.role or "Nuevo"
        -- Capitalizar el rol para consistencia (ej: "tank" -> "Tank")
        if currentRole ~= "" then
            currentRole = currentRole:sub(1,1):upper() .. currentRole:sub(2):lower()
        end
        UIDropDownMenu_SetText(playerEditFrame.roleDropDown, currentRole)
        playerEditFrame.selectedRole = currentRole
        playerEditFrame.isLeaderCheck:SetChecked(playerData.isLeader or false)
        playerEditFrame.isSanctionedCheck:SetChecked(playerData.isSanctioned or false)
        playerEditFrame.playerClass = playerData.class or ""
        
        -- Cargar datos de hermandad
        playerEditFrame.guildSection:Show()
        playerEditFrame.RefreshGuildData(true)
        
        -- Controlar visibilidad según modo búsqueda o Gearscore
         if isGearscoreMode then
             playerEditFrame.roleLabel:Hide()
             playerEditFrame.roleDropDown:Hide()
             playerEditFrame.isLeaderCheck:Hide()
             playerEditFrame.isLeaderLabel:Hide()
             
             -- Mostrar sancionado y reposicionarlo
             playerEditFrame.isSanctionedCheck:Show()
             playerEditFrame.isSanctionedLabel:Show()
             playerEditFrame.isSanctionedCheck:SetPoint("TOPLEFT", 100, -80)
             
             playerEditFrame.moveLabel:Hide()
             playerEditFrame.moveDropDown:Hide()
             playerEditFrame.deleteBtn:Hide()
             
             -- Reposicionar sección de hermandad debajo de sancionado
             playerEditFrame.guildSection:SetPoint("TOPLEFT", 20, -110)
             playerEditFrame:SetSize(350, 280)
             playerEditFrame.title:SetText("Jugador: " .. (playerData.name or ""))
             playerEditFrame.acceptBtn:Show()
         elseif playerEditFrame.isSearchMode then
             playerEditFrame.roleLabel:Hide()
             playerEditFrame.roleDropDown:Hide()
             playerEditFrame.isLeaderCheck:Hide()
             playerEditFrame.isLeaderLabel:Hide()
             
             -- Mostrar sancionado pero reposicionado en el modo simplificado
             playerEditFrame.isSanctionedCheck:Show()
             playerEditFrame.isSanctionedLabel:Show()
             playerEditFrame.isSanctionedCheck:SetPoint("TOPLEFT", 100, -80)
             
             playerEditFrame.moveLabel:Hide()
             playerEditFrame.moveDropDown:Hide()
             playerEditFrame.deleteBtn:Hide()
             
             -- Reposicionar sección de hermandad más abajo para dar espacio a sancionado
             playerEditFrame.guildSection:SetPoint("TOPLEFT", 20, -110)
             playerEditFrame:SetSize(350, 280)
             playerEditFrame.title:SetText("Jugador: " .. (playerData.name or ""))
             
             -- El botón de guardar debe estar visible para permitir guardar las notas de hermandad
             playerEditFrame.acceptBtn:Show()
         else
             playerEditFrame.roleLabel:Show()
             playerEditFrame.roleDropDown:Show()
             playerEditFrame.isLeaderCheck:Show()
             playerEditFrame.isLeaderLabel:Show()
             
             -- Restaurar posición original de sancionado
             playerEditFrame.isSanctionedCheck:Show()
             playerEditFrame.isSanctionedLabel:Show()
             playerEditFrame.isSanctionedCheck:SetPoint("TOPLEFT", 100, -140)
             
             playerEditFrame.moveLabel:Show()
             playerEditFrame.moveDropDown:Show()
             playerEditFrame.deleteBtn:Show()
             playerEditFrame.acceptBtn:Show()
             
             playerEditFrame.guildSection:SetPoint("TOPLEFT", 20, -200)
             playerEditFrame:SetSize(350, 420)
             playerEditFrame.title:SetText("Editar Jugador")
         end

        -- Resetear traslado
        playerEditFrame.targetBandIndex = nil
        UIDropDownMenu_SetText(playerEditFrame.moveDropDown, "Trasladar a...")
        
        -- Solicitar actualización de hermandad
        GuildRoster()
    else
        -- Limpiar campos si no se proporcionan datos
        playerEditFrame.nameEdit:SetText("")
        UIDropDownMenu_SetText(playerEditFrame.roleDropDown, "Seleccionar Rol")
        playerEditFrame.selectedRole = ""
        playerEditFrame.isLeaderCheck:SetChecked(false)
        playerEditFrame.isSanctionedCheck:SetChecked(false)
        playerEditFrame.playerClass = "" -- Limpiar la clase
        playerEditFrame.guildSection:Hide()
    end
    
    return playerEditFrame
end

-- Función auxiliar para obtener la nota pública de un miembro de la hermandad por nombre
local function getGuildNoteByName(playerName)
    if not playerName then return "" end
    local cleanName = CleanName(playerName)
    
    if guildFullCache[cleanName] then
        return guildFullCache[cleanName].note or ""
    end
    return ""
end

-- Tabla global para almacenar las memberCards activas por nombre de jugador
local activeMemberCards = {}

-- Función pública para abrir el editor de jugador desde otros módulos
function RD.utils.coreBands.OpenPlayerEditFrame(playerName, isSearchMode, isGearscoreMode, specificBandIndex)
    if not playerName then return end
    
    local cleanName = CleanName(playerName)
    local bandIndex, memberIndex
    local playerDataForSearch = nil
    
    -- Si se proporciona una banda específica, buscar al jugador en esa banda primero
    if specificBandIndex then
        local coreData = EnsureCoreData()
        local band = coreData[specificBandIndex]
        if band and band.members then
            for mIdx, member in ipairs(band.members) do
                if member.name and CleanName(member.name) == cleanName then
                    bandIndex = specificBandIndex
                    memberIndex = mIdx
                    break
                end
            end
        end
    end

    -- Si es modo búsqueda o gearscore, intentamos encontrar al jugador para cargar su estado de sanción actual
    if isSearchMode or isGearscoreMode then
        local coreData = EnsureCoreData()
        for _, band in ipairs(coreData) do
            if band.members then
                for _, member in ipairs(band.members) do
                    if member.name and CleanName(member.name) == cleanName then
                        -- Solo nos interesa el estado de sanción para el modo búsqueda/gearscore
                        playerDataForSearch = {
                            name = member.name,
                            isSanctioned = member.isSanctioned,
                            class = member.class
                        }
                        break
                    end
                end
            end
            if playerDataForSearch then break end
        end
    elseif not bandIndex then
        -- Buscar al jugador en todas las bandas del Core para edición normal si no se encontró en la específica
        local coreData = EnsureCoreData()
        for bIdx, band in ipairs(coreData) do
            if band.members then
                for mIdx, member in ipairs(band.members) do
                    if member.name and CleanName(member.name) == cleanName then
                        bandIndex = bIdx
                        memberIndex = mIdx
                        break
                    end
                end
            end
            if bandIndex then break end
        end
    end
    
    -- Reiniciar el frame antes de configurarlo
    local editFrame = _G["RaidDominionPlayerEditFrame"]
    if editFrame then
        editFrame.context = nil
        editFrame.isSearchMode = false
    end

    editFrame = coreBandsUtils.GetOrCreatePlayerEditFrame(playerDataForSearch or {name = playerName}, isGearscoreMode)
    if editFrame then
        -- Establecer el modo búsqueda
        editFrame.isSearchMode = isSearchMode
        
        -- Si se encontró en el Core (y no estamos en modo búsqueda/gearscore), actualizar el contexto
        if not (isSearchMode or isGearscoreMode) and bandIndex and memberIndex then
            editFrame.context = { bandIndex = bandIndex, memberIndex = memberIndex }
        end
        
        -- Volver a cargar los datos con el contexto y modo ya establecidos
        -- Esto asegura que isSanctionedCheck y otros controles se actualicen correctamente
        coreBandsUtils.GetOrCreatePlayerEditFrame(playerDataForSearch or {name = playerName}, isGearscoreMode) 
        editFrame:Show()
    end
end

-- Función para actualizar todas las tarjetas visibles (Throttleada por OnUpdate)
local refreshPending = false
RD.utils.coreBands.RefreshAllVisibleCards = function()
    refreshPending = true
end

-- Frame centralizado para eventos y actualizaciones
local RD_CoreBands_UpdateFrame = CreateFrame("Frame")
RD_CoreBands_UpdateFrame:RegisterEvent("GUILD_ROSTER_UPDATE")
RD_CoreBands_UpdateFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "GUILD_ROSTER_UPDATE" then
        if isInternalGuildUpdate then return end -- Evitar recursividad
        
        local f3 = _G["RaidDominionCoreListFrame"]
        local playerEditFrame = _G["RaidDominionPlayerEditFrame"]
        local isVisible = (f3 and f3:IsVisible()) or (playerEditFrame and playerEditFrame:IsVisible())
        
        if isVisible then
            UpdateGuildOnlineCache(true)
        end
    end
end)

local elapsedSinceLastUpdate = 0
RD_CoreBands_UpdateFrame:SetScript("OnUpdate", function(self, elapsed)
    elapsedSinceLastUpdate = elapsedSinceLastUpdate + elapsed
    
    -- Refrescar tarjetas pendientes cada 0.5s
    if elapsedSinceLastUpdate > 0.5 then
        if refreshPending then
            local rosterCache = BuildRosterCache()
            local coreData = EnsureCoreData()
            for _, cards in pairs(activeMemberCards) do
                for _, card in ipairs(cards) do
                    if card:IsVisible() then
                        card:Refresh(rosterCache, coreData)
                    end
                end
            end
            refreshPending = false
        end
        elapsedSinceLastUpdate = 0
    end
end)

-- Registrar eventos para actualizaciones en vivo (Solo una vez)
if not RD.utils.coreBands.updateFrame then
    local updateFrame = CreateFrame("Frame")
    updateFrame:RegisterEvent("PARTY_MEMBERS_CHANGED")
    updateFrame:RegisterEvent("RAID_ROSTER_UPDATE")
    updateFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    
    local lastFullRebuild = 0
    local lastRosterSignature = ""
    updateFrame:SetScript("OnEvent", function(self, event)
        local f3 = _G["RaidDominionCoreListFrame"]
        if f3 and f3:IsVisible() then
            if event == "PARTY_MEMBERS_CHANGED" or event == "RAID_ROSTER_UPDATE" then
                -- Solo reconstruir si la firma del roster ha cambiado REALMENTE
                local currentSignature = GetRosterSignature()
                if currentSignature ~= lastRosterSignature then
                    -- Throttle de 1s para reconstrucción total
                    local now = GetTime()
                    if now - lastFullRebuild > 1 then
                        RD.utils.coreBands.ShowCoreBandsWindow()
                        lastFullRebuild = now
                        lastRosterSignature = currentSignature
                    end
                end
            else
                -- Para otros eventos (TARGET), solo refrescar tarjetas existentes
                if RD.utils.coreBands.RefreshAllVisibleCards then
                    RD.utils.coreBands.RefreshAllVisibleCards()
                end
            end
        end
    end)
    RD.utils.coreBands.updateFrame = updateFrame
end

-- Función para renderizar los miembros de una banda en 4 columnas
local function renderBandMembers(band, parentFrame, bandIndex, rosterCache)
    -- Usar el rosterCache pasado por parámetro o construirlo si no existe
    rosterCache = rosterCache or BuildRosterCache()

    -- Obtener miembros de la banda
    local bandMembers = band.members or {}
    
    -- Build lookup table of existing members to avoid duplicates
    local membersInBand = {}
    for _, m in ipairs(bandMembers) do
        if m.name then
            membersInBand[CleanName(m.name)] = true
        end
    end

    -- Auto-detectar jugadores del grupo/banda y añadirlos si no están en la lista
    local addedAny = false
    local coreData = EnsureCoreData()
    local currentBand = coreData[bandIndex]
    
    for clean, data in pairs(rosterCache) do
        if not membersInBand[clean] then
            if not currentBand.members then currentBand.members = {} end
            tinsert(currentBand.members, { 
                name = CapitalizeName(data.name or clean), 
                role = "nuevo",
                class = data.class
            })
            membersInBand[clean] = true
            addedAny = true
        end
    end
    
    if addedAny then
        bandMembers = currentBand.members
    end

    -- Agrupar miembros por rol
    local membersByRole = {
        en_grupo = {}, exploradores = {}, hermandad = {}, posada = {}, 
        desconectados = {}, sancionados = {}
    }
    
    -- Clasificar miembros por rol, preservando el índice original
    local localPlayerName = CleanName(UnitName("player"))
    for originalIndex, member in ipairs(bandMembers) do
        member.originalIndex = originalIndex
        local cleanName = CleanName(member.name)
        local guildData = guildFullCache[cleanName]
        local rosterData = rosterCache[cleanName]
        local isInGroup = rosterData ~= nil
        local isOnline = isPlayerOnline(member.name, rosterCache)
        local isGuildMember = guildData ~= nil
        local isSanctioned = member.isSanctioned == true or member.isSanctioned == 1
        local role = (member.role or "nuevo"):lower()
        
        -- Enriquecer datos del miembro si faltan (clase)
        if (not member.class or member.class == "") then
            if guildData and guildData.classFileName then
                member.class = guildData.classFileName
            elseif rosterData then
                member.class = rosterData.class
            end
        end

        -- Pre-calcular índice de clase para ordenación rápida
        if member.class then
            member.classOrderIndex = CLASS_ORDER[member.class:upper()] or 999
        else
            member.classOrderIndex = 999
        end

        -- 1. Sancionados (S): Prioridad absoluta
        if isSanctioned then
            tinsert(membersByRole.sancionados, member)
        -- 2. En grupo: Jugadores actualmente en el grupo/raid
        elseif isInGroup then
            tinsert(membersByRole.en_grupo, member)
        -- 3. Exploradores (G): Hermandad, no en grupo, con rol asignado
        elseif isGuildMember and isOnline and (role == "tank" or role == "healer" or role == "dps") then
            tinsert(membersByRole.exploradores, member)
        -- 4. Hermandad (G): Hermandad, en linea, sin rol asignado o no en grupo
        elseif isGuildMember and isOnline then
            tinsert(membersByRole.hermandad, member)
        -- 5. Posada (P): No hermandad, con rol asignado
        elseif not isGuildMember and (role == "tank" or role == "healer" or role == "dps") then
            tinsert(membersByRole.posada, member)
        -- 6. Desconectados: Si está OFF o no tiene rol asignado
        else
            tinsert(membersByRole.desconectados, member)
        end
    end
    
    -- Función para ordenar miembros por clase (Optimizado con classOrderIndex pre-calculado)
    local function sortMembers(members)
        tsort(members, function(a, b)
            if a.classOrderIndex ~= b.classOrderIndex then 
                return a.classOrderIndex < b.classOrderIndex 
            end
            return a.name < b.name
        end)
    end
    
    sortMembers(membersByRole.en_grupo)
    sortMembers(membersByRole.exploradores)
    sortMembers(membersByRole.hermandad)
    sortMembers(membersByRole.posada)
    sortMembers(membersByRole.desconectados)
    sortMembers(membersByRole.sancionados)
    
    -- Función interna para crear encabezados
    local function createRoleHeader(roleName, displayName, yOffset)
        local header = AcquireFrame(roleHeaderPool, "Frame", parentFrame)
        header:SetSize(738, 20) -- Aumentado para coincidir con el nuevo ancho de las member cards
        header:SetPoint("TOPLEFT", 5, -yOffset)
        header:SetBackdrop({ bgFile = "Interface/QuestFrame/UI-QuestTitleHighlight" })
        header:SetBackdropColor(0.2, 0.2, 0.3, 1)
        
        if not header.text then
            header.text = UI.CreateLabel(header, "", "GameFontNormal")
            header.text:SetPoint("LEFT", 10, 0)
        end
        header.text:SetText(string.format("%s: %d", displayName, #membersByRole[roleName]))
        
        -- Resetear visibilidad de botones
        if header.autoBtn then header.autoBtn:Hide() end
        if header.cleanBtn then header.cleanBtn:Hide() end
        if header.inviteBtn then header.inviteBtn:Hide() end

        local permLevel = GetPerms()

        -- Botón Invitar para Exploradores, Hermandad y Posada
        if (roleName == "exploradores" or roleName == "hermandad" or roleName == "posada") and #membersByRole[roleName] > 0 then
            if not header.inviteBtn then
                header.inviteBtn = CreateFrame("Button", nil, header, "UIPanelButtonTemplate")
                header.inviteBtn:SetSize(80, 16)
                header.inviteBtn:SetPoint("RIGHT", -10, 0)
                header.inviteBtn:SetText("Invitar")
                header.inviteBtn:SetNormalFontObject("GameFontNormalSmall")
                header.inviteBtn:SetHighlightFontObject("GameFontHighlightSmall")
            end
            header.inviteBtn:Show()
            if permLevel >= 2 then
                header.inviteBtn:Enable()
            else
                header.inviteBtn:Disable()
            end
            
            header.inviteBtn:SetScript("OnClick", function()
                local count = 0
                for _, member in ipairs(membersByRole[roleName]) do
                    if member.name then
                        InviteUnit(member.name)
                        count = count + 1
                    end
                end
                if count > 0 then
                    Log("|cff00ff00[RaidDominion]|r Invitando a %d jugadores de %s.", count, displayName)
                end
            end)
        -- Botón Limpiar para Desconectados
        elseif roleName == "desconectados" and #membersByRole[roleName] > 0 then
            if not header.cleanBtn then
                header.cleanBtn = CreateFrame("Button", nil, header, "UIPanelButtonTemplate")
                header.cleanBtn:SetSize(80, 16)
                header.cleanBtn:SetPoint("RIGHT", -10, 0)
                header.cleanBtn:SetText("Limpiar")
                header.cleanBtn:SetNormalFontObject("GameFontNormalSmall")
                header.cleanBtn:SetHighlightFontObject("GameFontHighlightSmall")
            end
            header.cleanBtn:Show()
            if permLevel >= 2 then
                header.cleanBtn:Enable()
            else
                header.cleanBtn:Disable()
            end
            
            header.cleanBtn:SetScript("OnClick", function()
                local coreData = EnsureCoreData()
                local currentBand = coreData[bandIndex]
                if not currentBand or not currentBand.members then return end
                
                local indicesToRemove = {}
                for _, member in ipairs(membersByRole.desconectados) do
                    local role = (member.role or "nuevo"):lower()
                    if role == "nuevo" or role == "otro" then
                        table.insert(indicesToRemove, member.originalIndex)
                    end
                end
                
                if #indicesToRemove > 0 then
                    table.sort(indicesToRemove, function(a, b) return a > b end)
                    for _, idx in ipairs(indicesToRemove) do
                        table.remove(currentBand.members, idx)
                    end
                    Log("|cff00ff00[RaidDominion]|r Se han eliminado %d jugadores sin asignación de Desconectados.", #indicesToRemove)
                    if RD.utils.coreBands and RD.utils.coreBands.ShowCoreBandsWindow then
                        RD.utils.coreBands.ShowCoreBandsWindow()
                    end
                end
            end)
        end

        return 20
    end
    
    -- Función interna para crear tarjetas
    local function createMemberCard(member, xOffset, yOffset, roleGroup, memberIndex)
        local memberCard = AcquireFrame(memberCardPool, "Button", parentFrame)
        memberCard:SetSize(182, 20) -- Aumentado de 132 a 182 (+50px)
        memberCard:SetPoint("TOPLEFT", 6 + xOffset, -yOffset)
        memberCard:EnableMouse(true)
        memberCard:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        memberCard.bandIndex = bandIndex
        memberCard.memberIndex = memberIndex
        memberCard.roleGroup = roleGroup
        memberCard.playerName = member.name

        -- Registrar la tarjeta para actualizaciones en vivo
        local cleanName = CleanName(member.name)
        if not activeMemberCards[cleanName] then
            activeMemberCards[cleanName] = {}
        end
        table.insert(activeMemberCards[cleanName], memberCard)

        memberCard:SetBackdrop({
            bgFile = "Interface/Tooltips/UI-Tooltip-Background",
            edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 }
        })
        memberCard:SetBackdropColor(0.4, 0.4, 0.4, 0.8)
        memberCard:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.7)

        -- Función de refresco interno de la tarjeta
        if not memberCard.Refresh then
            memberCard.Refresh = function(self, rosterCache, coreData)
                local name = self.playerName
                if not name then return end

                local cleanName = CleanName(name)
                local guildData = guildFullCache[cleanName]
                -- Usar el coreData pasado por parámetro o asegurar si no existe
                coreData = coreData or EnsureCoreData()
                local band = coreData[self.bandIndex]
                local memberData = band and band.members and band.members[self.memberIndex]
                
                local playerClass = memberData and memberData.class
                if playerClass == "" then playerClass = nil end
                local isGuildMember = false
                local isOnline = isPlayerOnline(name, rosterCache)
                
                if guildData then
                    isGuildMember = true
                    if guildData.classFileName then playerClass = guildData.classFileName end
                end
                
                -- Actualizar color de nombre (Clase)
                local nameColor = { r = 1, g = 1, b = 1 }
                if playerClass then
                    local englishClass = CLASS_ENGLISH_MAP[playerClass:upper()] or playerClass
                    if _G.RAID_CLASS_COLORS and _G.RAID_CLASS_COLORS[englishClass] then
                        local color = _G.RAID_CLASS_COLORS[englishClass]
                        nameColor = { r = color.r, g = color.g, b = color.b }
                    end
                end
                if self.memberText then 
                    local capitalizedName = CapitalizeName(name)
                    local displayName = capitalizedName
                    
                    -- Mostrar ubicación entre paréntesis solo para el grupo 'hermandad'
                    if self.roleGroup == "hermandad" and guildData and guildData.online and guildData.zone and guildData.zone ~= "" then
                        -- Truncar ubicación a 12 caracteres con ellipsis
                        local zone = guildData.zone
                        if #zone > 9 then
                            zone = string.sub(zone, 1, 9) .. "..."
                        end
                        
                        displayName = string.format("%s |cffaaaaaa(%s)|r", capitalizedName, zone)
                    end
                    
                    self.memberText:SetText(displayName)
                    self.memberText:SetTextColor(nameColor.r, nameColor.g, nameColor.b) 
                end

                -- Actualizar indicador de Rol (T, H, D)
                if self.roleIndicator then
                    local role = memberData and memberData.role and memberData.role:lower() or ""
                    if role == "tank" then
                        self.roleIndicator:SetText("T")
                        self.roleIndicator:SetTextColor(0.2, 0.6, 1) -- Azul claro para Tank
                        self.roleIndicator:Show()
                        if self.memberText then self.memberText:SetPoint("LEFT", 18, 0) end
                    elseif role == "healer" then
                        self.roleIndicator:SetText("H")
                        self.roleIndicator:SetTextColor(0.1, 1, 0.1) -- Verde para Healer
                        self.roleIndicator:Show()
                        if self.memberText then self.memberText:SetPoint("LEFT", 18, 0) end
                    elseif role == "dps" then
                        self.roleIndicator:SetText("D")
                        self.roleIndicator:SetTextColor(1, 0.2, 0.2) -- Rojo para DPS
                        self.roleIndicator:Show()
                        if self.memberText then self.memberText:SetPoint("LEFT", 18, 0) end
                    else
                        self.roleIndicator:Hide()
                        if self.memberText then self.memberText:SetPoint("LEFT", 5, 0) end
                    end
                end

                -- Actualizar estado Online/Offline e indicador G/P (G: Guild, P: Posada/Invitado)
                if self.guildIndicator then
                    if isGuildMember then
                        self.guildIndicator:SetText("G")
                        self.guildIndicator:SetTextColor(isOnline and 0 or 0.3, isOnline and 1 or 0.3, isOnline and 0 or 0.3)
                    else
                        self.guildIndicator:SetText("P")
                        self.guildIndicator:SetTextColor(isOnline and 0 or 0.5, isOnline and 1 or 0.5, isOnline and 0 or 0.5)
                    end
                end
                
                -- Actualizar indicador Sancionado
                if self.sanctionedIndicator then
                    if memberData and (memberData.isSanctioned == true or memberData.isSanctioned == 1) then
                        self.sanctionedIndicator:Show()
                    else
                        self.sanctionedIndicator:Hide()
                    end
                end

                -- Actualizar indicador de Líder (L)
                if self.leaderIndicator then
                    if memberData and (memberData.isLeader == true or memberData.isLeader == 1) then
                        self.leaderIndicator:Show()
                    else
                        self.leaderIndicator:Hide()
                    end
                end

                -- Alineación dinámica de indicadores a la derecha
                local rightOffset = -5
                if self.sanctionedIndicator:IsShown() then
                    self.sanctionedIndicator:SetPoint("RIGHT", rightOffset, 0)
                    rightOffset = rightOffset - 12
                end
                if self.leaderIndicator:IsShown() then
                    self.leaderIndicator:SetPoint("RIGHT", rightOffset, 0)
                    rightOffset = rightOffset - 12
                end
                if self.guildIndicator:IsShown() then
                    self.guildIndicator:SetPoint("RIGHT", rightOffset, 0)
                end
            end
        end
        
        memberCard:SetScript("OnEnter", function(self)
            self:SetBackdropColor(0.5, 0.5, 0.6, 0.9)
            self:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
            
            -- Mostrar tooltip con información de hermandad
            local cleanName = CleanName(member.name)
            local guildData = guildFullCache[cleanName]
            
            if guildData then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(CapitalizeName(member.name), 1, 1, 1)
                
                -- Ubicación (Solo si está online)
                if guildData.online and guildData.zone and guildData.zone ~= "" then
                    GameTooltip:AddLine("Ubicación: |cffffffff" .. guildData.zone .. "|r")
                end
                
                -- Nota Pública
                if guildData.note and guildData.note ~= "" then
                    GameTooltip:AddLine("Nota Pública:")
                    GameTooltip:AddLine(guildData.note, 1, 1, 1, true)
                end
                
                GameTooltip:Show()
            end
        end)
        memberCard:SetScript("OnLeave", function(self)
            self:SetBackdropColor(0.4, 0.4, 0.4, 0.8)
            self:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.7)
            GameTooltip:Hide()
        end)
        
        -- Crear textos e indicadores si no existen
        if not memberCard.roleIndicator then
            memberCard.roleIndicator = UI.CreateLabel(memberCard, "", "GameFontNormalSmall")
            memberCard.roleIndicator:SetPoint("LEFT", 5, 0)
        end

        if not memberCard.memberText then
            memberCard.memberText = UI.CreateLabel(memberCard, "", "GameFontNormalSmall")
            memberCard.memberText:SetPoint("LEFT", 5, 0) -- El punto se ajustará en Refresh() si hay rol
        end
        
        if not memberCard.sanctionedIndicator then
            memberCard.sanctionedIndicator = UI.CreateLabel(memberCard, "S", "GameFontNormalSmall")
            memberCard.sanctionedIndicator:SetTextColor(1, 0, 0)
        end

        if not memberCard.leaderIndicator then
            memberCard.leaderIndicator = UI.CreateLabel(memberCard, "L", "GameFontNormalSmall")
            memberCard.leaderIndicator:SetTextColor(1, 1, 0) -- Amarillo para el líder
        end

        if not memberCard.guildIndicator then
            memberCard.guildIndicator = UI.CreateLabel(memberCard, "-", "GameFontNormalSmall")
        end
        
        -- Ejecutar el primer refresco
        memberCard:Refresh(rosterCache)
        
        memberCard:SetScript("OnClick", function(self, button)
            if button == "RightButton" then
                InviteUnit(self.playerName)
                SendChatMessage(string.format("[RaidDominion] Invitado a %s.", band.name or "Core"), "WHISPER", nil, self.playerName)
            else
                -- Usar la función pública centralizada para evitar problemas de contexto
                -- Pasamos el bandIndex para que sepa exactamente en qué banda buscar el rol
                if RD.utils.coreBands and RD.utils.coreBands.OpenPlayerEditFrame then
                    RD.utils.coreBands.OpenPlayerEditFrame(self.playerName, false, false, self.bandIndex)
                end
            end
        end)
    end
    
    local totalHeight = 0
    local roleOrder = { "en_grupo", "exploradores", "hermandad", "posada", "desconectados", "sancionados" }
    local roleNames = {
        en_grupo = "En grupo", exploradores = "Exploradores (G)", hermandad = "Hermandad (G)",
        posada = "Posada (P)", desconectados = "Desconectados", sancionados = "Sancionados (S)"
    }
    
    for _, role in ipairs(roleOrder) do
        -- Mostrar el encabezado solo si hay miembros
        if #membersByRole[role] > 0 then
            totalHeight = totalHeight + createRoleHeader(role, roleNames[role], totalHeight)
            
            local membersPerRow = 4
            local rowHeight = 21 -- Disminuido de 25 a 21 (-4px)
            local totalMembers = #membersByRole[role]
            local rows = math.ceil(totalMembers / membersPerRow)
            
            for row = 0, rows - 1 do
                for col = 0, membersPerRow - 1 do
                    local memberIdx = row * membersPerRow + col + 1
                    local member = membersByRole[role][memberIdx]
                    if member then
                        local xOffset = col * 183 -- Disminuido de 184 a 183 (-1px de gap)
                        createMemberCard(member, xOffset, totalHeight, role, member.originalIndex)
                    end
                end
                totalHeight = totalHeight + rowHeight
            end
        end
    end
    parentFrame:SetHeight(totalHeight + 5)
    return totalHeight + 5
end

-- Obtener el módulo de bandas Core
-- coreBandsUtils ya definido al inicio del archivo

-- Variables persistentes para trackear la banda seleccionada
local selectedBandIndex = nil
local selectedBandLine = nil

-- Función para obtener el índice de la banda seleccionada
function coreBandsUtils.GetSelectedBandIndex()
    return selectedBandIndex
end

-- Función para obtener o crear la banda temporal
function coreBandsUtils.GetOrCreateTemporalBandIndex()
    -- Verificar permisos antes de cualquier acción con la lista Temporal (Nivel 2+ requerido)
    if GetPerms() < 2 then
        return nil
    end

    local coreData = EnsureCoreData()
    for i, band in ipairs(coreData) do
        if band.name == "Temporal" then
            return i
        end
    end
    
    -- Si no existe, crearla
    table.insert(coreData, {
        name = "Temporal",
        minGS = 0,
        schedule = "Temporal",
        withNote = false,
        members = {}
    })
    
    Log("|cff00ff00[RaidDominion]|r Lista 'Temporal' creada automáticamente para nuevas asignaciones.")
    return #coreData
end

local openMemberLists = {} -- Almacena los índices de bandas con listas de miembros abiertas

-- Función para capitalizar todos los nombres de jugadores en todas las bandas
local function CapitalizeAllMemberNames()
    local coreData = EnsureCoreData()
    for _, band in ipairs(coreData) do
        if band.members then
            for _, member in ipairs(band.members) do
                member.name = CapitalizeName(member.name)
            end
        end
    end
end

-- Función auxiliar para obtener miembros visibles (incluyendo jugadores en grupo si se expande la lógica)
local function GetVisibleBandMembersCount(band, rosterCache)
    local members = band.members or {}
    local localPlayerName = CleanName(UnitName("player"))
    local totalVisible = 0
    local onlineVisible = 0
    
    -- Usar el rosterCache pasado por parámetro para evitar reconstrucciones redundantes
    if not rosterCache then rosterCache = BuildRosterCache() end
    
    -- Crear un set de nombres ya en la banda para evitar duplicados al contar grupo
    local namesInBand = {}
    
    for _, member in ipairs(members) do
        local cleanName = CleanName(member.name)
        namesInBand[cleanName] = true
        local role = (member.role or "nuevo"):lower()
        
        local isVisible = true
        if cleanName == localPlayerName then
            -- Siempre visible si está en grupo (ahora que lo mostramos en "En grupo")
            if (role == "nuevo" or role == "otro") and rosterCache[cleanName] then
                isVisible = true 
            end
        end
        
        if isVisible then
            totalVisible = totalVisible + 1
            -- Búsqueda O(1) en caches
            if guildOnlineCache[cleanName] or (rosterCache[cleanName] ~= nil) then
                onlineVisible = onlineVisible + 1
            end
        end
    end

    -- Si estamos en grupo, contar también a los que se añadirían dinámicamente
    for clean, data in pairs(rosterCache) do
        if not namesInBand[clean] then
            totalVisible = totalVisible + 1
            onlineVisible = onlineVisible + 1 -- Miembros del grupo siempre están online
            namesInBand[clean] = true
        end
    end
    
    return totalVisible, onlineVisible
end

-- Función para mostrar la ventana de bandas Core
function coreBandsUtils.ShowCoreBandsWindow()
    -- Throttle de seguridad para evitar llamadas espasmódicas (ej: al abrir/cerrar rápido)
    local now = GetTime()
    if coreBandsUtils.lastShowTime and (now - coreBandsUtils.lastShowTime < 0.1) then
        return
    end
    coreBandsUtils.lastShowTime = now

    -- Construir caché de roster una sola vez para toda la ventana
    local rosterCache = BuildRosterCache()
    
    -- Limpiar activeMemberCards al inicio para permitir múltiples bandas abiertas
    wipe(activeMemberCards)
    
    -- Actualizar caché de hermandad al abrir (Usar throttle interno)
    UpdateGuildOnlineCache()
    
    -- Capitalizar nombres solo si es necesario (Evitar bucles pesados cada vez que se abre)
    -- Lo hacemos cada vez que se abre pero es O(N) y está cacheado, así aseguramos consistencia
    CapitalizeAllMemberNames()
    
    -- Obtener los datos de bandas Core
    local coreData = EnsureCoreData()
    
    -- Crear frame principal si no existe
    local f3 = _G["RaidDominionCoreListFrame"]
    if not f3 then
        f3 = CreateFrame("Frame", "RaidDominionCoreListFrame", UIParent)
        f3:SetFrameStrata("MEDIUM")
        f3:SetToplevel(true)
        f3:SetSize(790, 440) -- Aumentado de 590 a 790 (200px extra para soportar member cards de +50px en 4 columnas)
        f3:SetPoint("TOP", 0, -100)
        f3:SetBackdrop({
            bgFile = "Interface/Tooltips/UI-Tooltip-Background",
            edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 }
        })
        f3:SetBackdropColor(0, 0, 0, 1)
        f3:SetBackdropBorderColor(1, 1, 1, 0.5)
        f3:EnableMouse(true)
        f3:SetMovable(true)
        f3:RegisterForDrag("LeftButton")
        f3:SetScript("OnDragStart", f3.StartMoving)
        f3:SetScript("OnDragStop", f3.StopMovingOrSizing)
        
        -- Make the window closable with ESC key
        tinsert(UISpecialFrames, "RaidDominionCoreListFrame")
        
        -- Título
        local guildName = GetGuildInfo("player") or ""
        f3.title = UI.CreateLabel(f3, "RaidDominion - Core " .. guildName, "GameFontNormal")
        f3.title:SetPoint("TOP", 0, -15)
        
        -- Botón Cerrar
        f3.closeBtn = CreateFrame("Button", nil, f3, "UIPanelCloseButton")
        f3.closeBtn:SetPoint("TOPRIGHT", -5, -5)
        f3.closeBtn:SetScript("OnClick", function()
            f3:Hide()
        end)
        
        -- Botón Crear Nueva Banda
        f3.createBtn = CreateStyledButton("RaidDominionCoreCreateBtn", f3, 30, 30, nil, "Interface/Icons/Spell_ChargePositive", "Nueva Banda")
        f3.createBtn:SetPoint("TOPLEFT", 20, -35)
        f3.createBtn:SetScript("OnClick", function()
            local permLevel = GetPerms()
            if permLevel < 2 then
                local mm = RD.modules and RD.modules.messageManager
                if mm and mm.PermissionError then
                    mm:PermissionError("crear bandas")
                else
                    Log("|cffff0000[RaidDominion]|r Error: No tienes permisos para crear bandas.")
                end
                return
            end
            local createFrame = getOrCreateBandFrame()
            createFrame.isEditing = false
            createFrame.bandIndex = nil
            createFrame.title:SetText("Crear Nueva Banda")
            createFrame.nameEdit:SetText("")
            createFrame.gsEdit:SetText("5000")
            createFrame.scheduleEdit:SetText("Lunes y Miércoles 20:00")
            createFrame.withNoteCheck:SetChecked(false) -- Inicia desmarcado
            createFrame:Show()
        end)

        -- Botón Compartir Datos
        f3.shareBtn = CreateStyledButton("RaidDominionCoreShareBtn", f3, 30, 30, nil, "Interface/Icons/Spell_Arcane_StudentOfMagic", "Compartir Datos del Líder")
        f3.shareBtn:SetPoint("LEFT", f3.createBtn, "RIGHT", 10, 0)
        f3.shareBtn:SetScript("OnClick", function()
            local mm = RaidDominion.messageManager
            if not mm then return end
            -- Solo enviar solicitud si estamos en grupo
            if GetNumPartyMembers() == 0 and GetNumRaidMembers() == 0 then
                mm:ShowAlert("Debes estar en grupo para solicitar datos.", "WARNING")
                return
            end
            
            local channel = (GetNumRaidMembers() > 0) and "RAID" or "PARTY"
            SendAddonMessage("RD_COMM", "REQUEST_CORE_DATA", channel)
            mm:ShowAlert("Solicitando datos de bandas al grupo...", "INFO")
        end)
        
        -- Botón Actualizar Todas las Listas (Nuevo)
        f3.updateAllBtn = CreateStyledButton("RaidDominionCoreUpdateAllBtn", f3, 30, 30, nil, "Interface/Icons/Spell_Holy_Renew", "Actualizar Todas las Listas")
        f3.updateAllBtn:SetPoint("LEFT", f3.shareBtn, "RIGHT", 10, 0)
        f3.updateAllBtn:SetScript("OnClick", function()
            local permLevel = GetPerms()
            if permLevel < 2 then
                local mm = RD.modules and RD.modules.messageManager
                if mm and mm.PermissionError then
                    mm:PermissionError("actualizar bandas")
                else
                    Log("|cffff0000[RaidDominion]|r Error: No tienes permisos para actualizar bandas.")
                end
                return
            end
            local coreData = EnsureCoreData()
            if not coreData or #coreData == 0 then
                Log("|cffff0000[RaidDominion]|r Error: No hay bandas configuradas.")
                return
            end

            -- Función de ejecución de actualización
            local function executeUpdate()
                UpdateGuildOnlineCache(true)
                
                local totalAdded = 0
                local totalCleaned = 0
                local numGuildMembers = GetNumGuildMembers(true)
                
                -- Primero: Limpiar desconectados sin rol asignado de todas las bandas
                for bIdx, band in ipairs(coreData) do
                    if band.members then
                        for mIdx = #band.members, 1, -1 do
                            local member = band.members[mIdx]
                            local cleanName = CleanName(member.name)
                            local role = (member.role or "nuevo"):lower()
                            
                            -- Si el jugador está desconectado y tiene rol "nuevo" u "otro"
                            if not isPlayerOnline(member.name) and (role == "nuevo" or role == "otro") then
                                table.remove(band.members, mIdx)
                                totalCleaned = totalCleaned + 1
                            end
                        end
                    end
                end

                -- Crear un mapa de jugadores por banda para evitar duplicados internos
                local playersInBand = {}
                for bIdx, band in ipairs(coreData) do
                    playersInBand[bIdx] = {}
                    if band.members then
                        for _, member in ipairs(band.members) do
                            playersInBand[bIdx][CleanName(member.name)] = true
                        end
                    end
                end

                Log("|cff00ff00[RaidDominion]|r Iniciando actualización (limpieza y reclutamiento online)...")

                for i = 1, numGuildMembers do
                    local name, rank, rankIndex, level, class, zone, note, officernote, online, status, classFileName = GetGuildRosterInfo(i)
                    if name and online then -- Solo personal en línea
                        local cleanName = CleanName(name)
                        -- El filtrado por nota pública ahora depende de la configuración de cada banda
                        
                        -- Extraer GS de la nota
                        local playerGS = nil
                        if note and note ~= "" then
                            local gsStr, rolesPart = string.match(note, "(%d+)%.?(%d*)")
                            if gsStr then
                                playerGS = tonumber(gsStr)
                                rolesPart = rolesPart or ""
                                if playerGS and playerGS < 100 then
                                    local decimal = tonumber("0." .. (rolesPart ~= "" and rolesPart or "0")) or 0
                                    playerGS = (playerGS + decimal) * 1000
                                end
                            end
                        end
                        
                        -- Intentar agregar a las bandas donde califique
                        for bIdx, band in ipairs(coreData) do
                            -- Criterio 1: No estar ya en la banda
                            if not playersInBand[bIdx][cleanName] then
                                -- Criterio 2: Cumplir con el requisito de nota si está activo (1 = activo)
                                local passesNoteCheck = true
                                if band.withNote == 1 then
                                    if not note or note == "" then
                                        passesNoteCheck = false
                                    end
                                end
                                
                                -- Criterio 3: Cumplir con el GS mínimo
                                if passesNoteCheck then
                                    local minGS = tonumber(band.minGS) or 0
                                    -- Si tiene GS y cumple el mínimo, O si NO tiene nota/GS pero la banda permite "Sin Nota" y el mínimo es 0
                                    if (playerGS and playerGS >= minGS) or (not playerGS and minGS == 0 and band.withNote ~= 1) then
                                        addPlayerToBand(bIdx, {
                                            name = cleanName,
                                            role = "nuevo",
                                            class = classFileName or class,
                                            mainRole = "",
                                            dualRole = ""
                                        })
                                        totalAdded = totalAdded + 1
                                        playersInBand[bIdx][cleanName] = true
                                    end
                                end
                            end
                        end
                    end
                end
                
                local summary = "|cff00ff00[RaidDominion]|r Actualización finalizada."
                if totalCleaned > 0 then
                    summary = summary .. " Limpieza: " .. totalCleaned .. " desconectados."
                end
                if totalAdded > 0 then
                    summary = summary .. " Reclutamiento: " .. totalAdded .. " asignaciones."
                end
                
                if totalAdded > 0 or totalCleaned > 0 then
                    Log(summary)
                    RD.utils.coreBands.RefreshAllVisibleCards()
                    RD.utils.coreBands.ShowCoreBandsWindow()
                else
                    Log("|cffffff00[RaidDominion]|r No se encontraron cambios (limpieza o nuevos jugadores).")
                    -- Aun así refrescar las tarjetas y encabezados para asegurar consistencia
                    RD.utils.coreBands.RefreshAllVisibleCards()
                    RD.utils.coreBands.ShowCoreBandsWindow()
                end
            end

            executeUpdate()
        end)
        
        -- ScrollFrame
        f3.scroll = CreateFrame("ScrollFrame", "RaidDominionCoreListScroll", f3, "UIPanelScrollFrameTemplate")
        f3.scroll:SetPoint("TOPLEFT", 10, -75)
        f3.scroll:SetPoint("BOTTOMRIGHT", -32, 33) -- Aumentado el margen inferior para la barra de estado
        
        -- Borde superior del scroll (Línea sencilla fina)
         f3.scroll.topBorder = f3.scroll:CreateTexture(nil, "OVERLAY")
         f3.scroll.topBorder:SetTexture(1, 1, 1, 0.2) -- Color blanco con baja opacidad para efecto fino
         f3.scroll.topBorder:SetHeight(1)
         f3.scroll.topBorder:SetPoint("TOPLEFT", f3.scroll, "TOPLEFT", 0, 4)
         f3.scroll.topBorder:SetPoint("TOPRIGHT", f3.scroll, "TOPRIGHT", 0, 4)
        
        f3.content = CreateFrame("Frame", nil, f3.scroll)
        f3.content:SetSize(748, 10) -- Aumentado de 548 a 748 (+200px)
        f3.scroll:SetScrollChild(f3.content)

        -- Barra de estado inferior
        f3.statusBar = CreateFrame("Frame", nil, f3)
        f3.statusBar:SetSize(780, 25) -- Ajustado de 750 a 770 para llenar mejor el ancho de 790 de la ventana
        f3.statusBar:SetPoint("BOTTOM", 0, 5)
        f3.statusBar:SetBackdrop({
            bgFile = "Interface/Tooltips/UI-Tooltip-Background",
            edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 }
        })
        f3.statusBar:SetBackdropColor(0, 0, 0, 0.8)
        
        local function createStat(parent)
             local frame = CreateFrame("Frame", nil, parent)
             frame:SetSize(1, 20) -- Ancho dinámico
             frame:EnableMouse(true)
             
             local text = UI.CreateLabel(frame, "", "GameFontNormalSmall")
             text:SetPoint("LEFT", 0, 0)
             frame.text = text
             
             frame:SetScript("OnEnter", function(self)
                 if self.tooltipFunc then
                     GameTooltip:SetOwner(self, "ANCHOR_TOP")
                     self.tooltipFunc(GameTooltip)
                     GameTooltip:Show()
                 end
             end)
             frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
             
             return frame
         end

        f3.statOnline = createStat(f3.statusBar)
        f3.statR2 = createStat(f3.statusBar)
        f3.statR3 = createStat(f3.statusBar)
        f3.statR4 = createStat(f3.statusBar)
        f3.statR5 = createStat(f3.statusBar)

        f3.UpdateStats = function()
            if not IsInGuild() then
                f3.statOnline.text:SetText("En línea: |cff00ff000|r/|cff8888880|r")
                f3.statR2:Hide()
                f3.statR3:Hide()
                f3.statR4:Hide()
                f3.statR5:Hide()
                return
            end

            local online, offline, total = 0, 0, 0
            local rankCounts = {} -- [rankIndex] = {online = 0, total = 0}
            for i = 0, 10 do rankCounts[i] = {online = 0, total = 0} end
            
            UpdateGuildOnlineCache()
            if next(guildFullCache) == nil then
                UpdateGuildOnlineCache(true)
            end
            
            for _, data in pairs(guildFullCache) do
                total = total + 1
                local isOnline = data.online
                if isOnline then online = online + 1 else offline = offline + 1 end
                
                if data.rankIndex and rankCounts[data.rankIndex] then
                    rankCounts[data.rankIndex].total = rankCounts[data.rankIndex].total + 1
                    if isOnline then
                        rankCounts[data.rankIndex].online = rankCounts[data.rankIndex].online + 1
                    end
                end
            end
            
            -- Actualizar En línea con tooltip para r0 y r1
            f3.statOnline.text:SetText(string.format("En línea: |cff00ff00%d|r/|cff888888%d|r", online, total))
            f3.statOnline:SetWidth(f3.statOnline.text:GetStringWidth())
            f3.statOnline.tooltipFunc = function(tt)
                tt:AddLine("Desglose por Rangos (Superiores):")
                local r0Name = GuildControlGetRankName(1) or "Rango 0"
                local r1Name = GuildControlGetRankName(2) or "Rango 1"
                
                local r0Text = string.format("|cff00ff00%d|r/|cff888888%d|r", rankCounts[0].online, rankCounts[0].total)
                local r1Text = string.format("|cff00ff00%d|r/|cff888888%d|r", rankCounts[1].online, rankCounts[1].total)
                
                tt:AddDoubleLine(r0Name, r0Text)
                tt:AddDoubleLine(r1Name, r1Text)
            end

            -- Distribución mediante fórmula proporcional sobre elementos VISIBLES:
            local stats = { f3.statOnline, f3.statR2, f3.statR3, f3.statR4, f3.statR5 }
            local visibleStats = {}
            
            for i, frame in ipairs(stats) do
                if i == 1 then
                    frame:Show()
                    table.insert(visibleStats, frame)
                else
                    local rName = GuildControlGetRankName(i + 1)
                    if rName and rName ~= "" then
                        local rText = string.format("%s: |cff00ff00%d|r/|cff888888%d|r", rName, rankCounts[i].online, rankCounts[i].total)
                        frame.text:SetText(rText)
                        frame:Show()
                        table.insert(visibleStats, frame)
                    else
                        frame:Hide()
                    end
                end
            end

            local barWidth = f3.statusBar:GetWidth() - 20 -- Margen de 10px a cada lado
            local numVisible = #visibleStats
            
            for i, frame in ipairs(visibleStats) do
                -- FÓRMULA: x = margen_izq + (índice-1) * (ancho_útil / (num_elementos-1))
                local xPos = 10
                if numVisible > 1 then
                    xPos = 10 + (i - 1) * (barWidth / (numVisible - 1))
                end
                
                frame:ClearAllPoints()
                if i == 1 then
                    frame:SetPoint("LEFT", 10, 0)
                    frame.text:ClearAllPoints()
                    frame.text:SetPoint("LEFT", 0, 0)
                elseif i == numVisible then
                    frame:SetPoint("RIGHT", -10, 0)
                    frame.text:ClearAllPoints()
                    frame.text:SetPoint("RIGHT", 0, 0)
                else
                    -- Centramos los elementos intermedios en su posición calculada
                    frame:SetPoint("CENTER", f3.statusBar, "LEFT", xPos, 0)
                    frame.text:ClearAllPoints()
                    frame.text:SetPoint("CENTER", 0, 0)
                end
            end
        end

        -- Ya no registramos el evento individualmente aquí, usamos el despachador centralizado
        f3:SetScript("OnShow", function(self)
            if IsInGuild() then
                GuildRoster()
            end
            self.UpdateStats()
        end)
    end
    
    -- Guardar posición de scroll actual si existe
    local currentScroll = 0
    if f3.scroll then
        currentScroll = f3.scroll:GetVerticalScroll()
    end

    -- Limpiar contenido anterior y devolver al pool
    local children = {f3.content:GetChildren()}
    for _, child in ipairs(children) do
        if child.bandIndex then
            -- Si tiene membersFrame, liberar sus hijos también
            if child.membersFrame then
                local mChildren = {child.membersFrame:GetChildren()}
                for _, mChild in ipairs(mChildren) do
                    if mChild.playerName then
                        ReleaseFrame(memberCardPool, mChild)
                    elseif mChild.text then -- Es un header
                        ReleaseFrame(roleHeaderPool, mChild)
                    else
                        mChild:Hide()
                        mChild:SetParent(nil)
                    end
                end
                child.membersFrame:Hide()
                child.membersFrame:SetParent(nil)
                child.membersFrame = nil
            end
            ReleaseFrame(bandLinePool, child)
        else
            child:Hide()
            child:SetParent(nil)
        end
    end
    
    -- Función para cerrar todas las listas de miembros abiertas
    local function closeAllMemberFrames(skipRefresh)
        openMemberLists = {}
        if not skipRefresh then
            RD.utils.coreBands.ShowCoreBandsWindow()
        end
    end
    
    -- Verificar si ya existe el encabezado de botones, si no, crearlo
    if not f3.headerButtonsFrame then
        -- Crear frame de encabezado con botones fuera del área de scroll
        f3.headerButtonsFrame = CreateFrame("Frame", nil, f3)
        f3.headerButtonsFrame:SetSize(330, 35)
        f3.headerButtonsFrame:SetPoint("TOPRIGHT", -15, -35)
        f3.headerButtonsFrame:Show()
        f3.headerButtonsFrame:EnableMouse(true)
        
        -- Botón Reclutar
        f3.recruitBtn = CreateStyledButton("RaidDominionCoreRecruitBtn", f3.headerButtonsFrame, 30, 30, nil, "Interface/Icons/Ability_TownWatch", "Reclutar")
        f3.recruitBtn:SetPoint("TOPLEFT", 5, -2)
        
        -- Botón Invitar
        f3.inviteBtn = CreateStyledButton("RaidDominionCoreInviteBtn", f3.headerButtonsFrame, 30, 30, nil, "Interface/Icons/INV_Misc_GroupLooking", "Invitar")
        f3.inviteBtn:SetPoint("TOPLEFT", 45, -2)
        
        -- Botón Anunciar
        f3.announceBtn = CreateStyledButton("RaidDominionCoreAnnounceBtn", f3.headerButtonsFrame, 30, 30, nil, "Interface/Icons/Ability_Warrior_BattleShout", "Anunciar")
        f3.announceBtn:SetPoint("TOPLEFT", 85, -2)
        f3.announceBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        f3.announceBtn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Anunciar Banda")
            GameTooltip:AddLine("Click Izquierdo: Anuncio por canal por defecto", 1, 1, 1)
            GameTooltip:AddLine("Click Derecho: Anuncio por Hermandad", 1, 1, 1)
            GameTooltip:Show()
        end)
        f3.announceBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

        -- Botón Reiniciar (Nuevo)
        f3.resetBtn = CreateStyledButton("RaidDominionCoreResetBtn", f3.headerButtonsFrame, 30, 30, nil, "Interface/Icons/Spell_Holy_RighteousnessAura", "Reiniciar")
        f3.resetBtn:SetPoint("TOPLEFT", 125, -2)
        f3.resetBtn:SetScript("OnClick", function()
            local permLevel = GetPerms()
            if permLevel < 2 then
                local mm = RD.modules and RD.modules.messageManager
                if mm and mm.PermissionError then
                    mm:PermissionError("reiniciar bandas")
                else
                    Log("|cffff0000[RaidDominion]|r Error: No tienes permisos para reiniciar bandas.")
                end
                return
            end
            if selectedBandIndex and coreData[selectedBandIndex] then
                -- Registrar diálogo de confirmación de reinicio si no existe
                if not StaticPopupDialogs["RAID_DOMINION_RESET_CORE_BAND"] then
                    StaticPopupDialogs["RAID_DOMINION_RESET_CORE_BAND"] = {
                        text = "¿Estás seguro de que quieres reiniciar la banda %s? Esto eliminará a todos los miembros.",
                        button1 = YES,
                        button2 = NO,
                        OnAccept = function(self)
                            local bandIndex = self.data.bandIndex
                            local coreData = EnsureCoreData()
                            if coreData[bandIndex] then
                                coreData[bandIndex].members = {}
                                -- Actualizar ventana
                                RD.utils.coreBands.ShowCoreBandsWindow()
                                Log("|cff00ff00[RaidDominion]|r Banda " .. coreData[bandIndex].name .. " reiniciada.")
                            end
                        end,
                        timeout = 0,
                        whileDead = 1,
                        hideOnEscape = 1
                    }
                end
                StaticPopup_Show("RAID_DOMINION_RESET_CORE_BAND", coreData[selectedBandIndex].name, nil, { bandIndex = selectedBandIndex })
            else
                Log("|cffff0000[RaidDominion]|r Error: Debes seleccionar una banda primero")
            end
        end)
        
        -- Botón Eliminar
        f3.deleteBtn = CreateStyledButton("RaidDominionCoreDeleteBtn", f3.headerButtonsFrame, 30, 30, nil, "Interface/Icons/Spell_Shadow_SacrificialShield", "Eliminar")
        f3.deleteBtn:SetPoint("TOPLEFT", 165, -2)

        -- Botón Duplicar (Nuevo)
        f3.duplicateBtn = CreateStyledButton("RaidDominionCoreDuplicateBtn", f3.headerButtonsFrame, 30, 30, nil, "Interface/Icons/Spell_Holy_PrayerOfHealing02", "Duplicar Banda")
        f3.duplicateBtn:SetPoint("TOPLEFT", 205, -2)
        f3.duplicateBtn:SetScript("OnClick", function()
            local permLevel = GetPerms()
            if permLevel < 2 then
                local mm = RD.modules and RD.modules.messageManager
                if mm and mm.PermissionError then
                    mm:PermissionError("duplicar bandas")
                else
                    Log("|cffff0000[RaidDominion]|r Error: No tienes permisos para duplicar bandas.")
                end
                return
            end
            if selectedBandIndex and coreData[selectedBandIndex] then
                local bandToCopy = coreData[selectedBandIndex]
                
                -- Crear copia de la banda
                local newBand = {
                    name = bandToCopy.name .. " (Copia)",
                    minGS = bandToCopy.minGS,
                    schedule = bandToCopy.schedule,
                    withNote = bandToCopy.withNote,
                    members = {}
                }
                
                -- Copiar miembros si existen
                if bandToCopy.members then
                    for _, member in ipairs(bandToCopy.members) do
                        table.insert(newBand.members, {
                            name = member.name,
                            role = member.role,
                            class = member.class,
                            isSanctioned = member.isSanctioned
                        })
                    end
                end
                
                -- Insertar en coreData
                table.insert(coreData, newBand)
                
                -- Actualizar ventana
                RD.utils.coreBands.ShowCoreBandsWindow()
                Log("|cff00ff00[RaidDominion]|r Banda " .. bandToCopy.name .. " duplicada como " .. newBand.name .. ".")
             else
                 Log("|cffff0000[RaidDominion]|r Error: Debes seleccionar una banda primero")
             end
        end)

        -- Botón Subir (Nivel 1+)
        f3.moveUpBtn = CreateStyledButton("RaidDominionCoreMoveUpBtn", f3.headerButtonsFrame, 30, 30, nil, "Interface/Icons/Spell_ChargePositive", "Subir Orden")
        f3.moveUpBtn:SetPoint("TOPLEFT", 245, -2)
        f3.moveUpBtn:SetScript("OnClick", function()
            local permLevel = GetPerms()
            if permLevel < 1 then
                local mm = RD.modules and RD.modules.messageManager
                if mm and mm.PermissionError then
                    mm:PermissionError("mover bandas")
                else
                    Log("|cffff0000[RaidDominion]|r Error: No tienes permisos para mover bandas.")
                end
                return
            end
            if selectedBandIndex and selectedBandIndex > 1 then
                local band = table.remove(coreData, selectedBandIndex)
                table.insert(coreData, selectedBandIndex - 1, band)
                selectedBandIndex = selectedBandIndex - 1
                RD.utils.coreBands.ShowCoreBandsWindow()
            elseif not selectedBandIndex then
                Log("|cffff0000[RaidDominion]|r Error: Debes seleccionar una banda primero")
            end
        end)

        -- Botón Bajar (Nivel 1+)
        f3.moveDownBtn = CreateStyledButton("RaidDominionCoreMoveDownBtn", f3.headerButtonsFrame, 30, 30, nil, "Interface/Icons/Spell_ChargeNegative", "Bajar Orden")
        f3.moveDownBtn:SetPoint("TOPLEFT", 285, -2)
        f3.moveDownBtn:SetScript("OnClick", function()
            local permLevel = GetPerms()
            if permLevel < 1 then
                local mm = RD.modules and RD.modules.messageManager
                if mm and mm.PermissionError then
                    mm:PermissionError("mover bandas")
                else
                    Log("|cffff0000[RaidDominion]|r Error: No tienes permisos para mover bandas.")
                end
                return
            end
            if selectedBandIndex and selectedBandIndex < #coreData then
                local band = table.remove(coreData, selectedBandIndex)
                table.insert(coreData, selectedBandIndex + 1, band)
                selectedBandIndex = selectedBandIndex + 1
                RD.utils.coreBands.ShowCoreBandsWindow()
            elseif not selectedBandIndex then
                Log("|cffff0000[RaidDominion]|r Error: Debes seleccionar una banda primero")
            end
        end)
    end
    
    -- Asegurar que los frames de encabezado y estado estén visibles
    f3.headerButtonsFrame:Show()
    if f3.statusBar then f3.statusBar:Show() end
    if f3.UpdateStats then f3.UpdateStats() end
    
    -- Actualizar los scripts de los botones para usar la banda seleccionada actual
    f3.announceBtn:SetScript("OnClick", function(self, button)
        if selectedBandIndex and coreData[selectedBandIndex] then
            local bandData = coreData[selectedBandIndex]
            
            local targetChannel
            if button == "RightButton" then
                targetChannel = "GUILD"
            else
                -- Obtener canal por defecto del messageManager
                if RaidDominion.messageManager and RaidDominion.messageManager.GetDefaultChannel then
                    local _, defaultChannel = RaidDominion.messageManager:GetDefaultChannel()
                    targetChannel = defaultChannel
                end
            end

            if targetChannel then
                local messages = {
                    string.format("Anuncio de banda: %s", bandData.name),
                    string.format("GS Mínimo: %d", bandData.minGS),
                    string.format("Horario: %s", bandData.schedule)
                }
                
                if _G.SendDelayedMessages then
                    SendDelayedMessages(messages, targetChannel)
                    if button == "RightButton" then
                        Log("|cff00ff00[RaidDominion]|r Anunciando en Hermandad...")
                    end
                else
                    Log("|cffff0000[RaidDominion]|r Error: SendDelayedMessages no está disponible")
                end
            else
                Log("|cffff0000[RaidDominion]|r Error: No se pudo determinar el canal de anuncio.")
            end
        else
            Log("|cffff0000[RaidDominion]|r Error: Debes seleccionar una banda primero")
        end
    end)
    
    f3.inviteBtn:SetScript("OnClick", function(self)
        local permLevel = GetPerms()
        if permLevel < 2 then
            local mm = RD.modules and RD.modules.messageManager
            if mm and mm.PermissionError then
                mm:PermissionError("añadir jugadores a la banda")
            else
                Log("|cffff0000[RaidDominion]|r Error: No tienes permisos para añadir jugadores a la banda.")
            end
            return
        end
        if selectedBandIndex and coreData[selectedBandIndex] then
            -- Obtener información del objetivo actual
            local targetName = UnitName("target")
            
            if targetName then
                -- Si hay un objetivo seleccionado, obtener su clase
                local _, targetClass = UnitClass("target")
                local isPlayer = UnitIsPlayer("target")
                
                if isPlayer then
                    -- Agregar el jugador objetivo a la banda con su clase
                    addPlayerToBand(selectedBandIndex, {
                        name = targetName,
                        role = "nuevo", -- Rol por defecto cambiado a "nuevo"
                        class = targetClass -- Clase obtenida del objetivo
                    })
                else
                    Log("|cffff0000[RaidDominion]|r Error: El objetivo debe ser un jugador")
                end
            else
                -- Si no hay objetivo seleccionado, abrir el popup para ingresar el nombre
                local invitePopup = getOrCreateInvitePopup(selectedBandIndex)
                invitePopup:Show()
            end
        else
            Log("|cffff0000[RaidDominion]|r Error: Debes seleccionar una banda primero")
        end
    end)
    
    f3.recruitBtn:SetScript("OnClick", function(self)
        -- Forzar actualización de caché de hermandad para tener datos frescos
        UpdateGuildOnlineCache(true)
        
        local permLevel = GetPerms()
        if permLevel < 2 then
            local mm = RD.modules and RD.modules.messageManager
            if mm and mm.PermissionError then
                mm:PermissionError("reclutar bandas")
            else
                Log("|cffff0000[RaidDominion]|r Error: No tienes permisos para reclutar bandas.")
            end
            return
        end
        if selectedBandIndex and coreData[selectedBandIndex] then
            local bandData = coreData[selectedBandIndex]
            local members = bandData.members or {}
            
            if #members == 0 then
                Log("|cffff0000[RaidDominion]|r Error: La banda seleccionada no tiene miembros.")
                return
            end

            -- Obtener lista de jugadores para invitar (indiferente de si son de hermandad o no)
            local playersToInvite = {}
            local summonedNames = {}
            
            for _, member in ipairs(members) do
                -- Ya no filtramos por rol "nuevo" para permitir invitar a todos los de la lista
                local cleanName = CleanName(member.name)
                -- Usar el nombre de la hermandad si está disponible (por capitalización), si no, el nombre guardado
                local displayName = guildFullCache[cleanName] and guildFullCache[cleanName].name or member.name
                table.insert(playersToInvite, displayName)
                table.insert(summonedNames, displayName)
            end

            if #playersToInvite == 0 then
                Log("|cffffff00[RaidDominion]|r No hay miembros en la lista para invitar.")
                return
            end

            -- 1. Realizar invitaciones masivas
            local rosterCache = BuildRosterCache()
            Log("|cff00ff00[RaidDominion]|r Enviando invitaciones a " .. #playersToInvite .. " miembros...")
            for _, name in ipairs(playersToInvite) do
                if not IsPlayerInGroup(name, rosterCache) then
                    InviteUnit(name)
                end
            end

            -- 2. Anunciar en hermandad
            if IsInGuild() then
                local summonedList = table.concat(summonedNames, ", ")
                -- Usamos %s para minGS para preservar el formato (ej: "0.0") si el usuario lo introdujo así
                local displayMinGS = bandData.minGS or "0"
                local msgHeader = string.format("RD: Convocando a [%s] (Min GS: %s) - %s", bandData.name, displayMinGS, bandData.schedule or "")
                local msgSummoned = "Convocados: " .. summonedList
                
                -- Dividir el mensaje si es muy largo (WoW chat limit is ~255 chars)
                SendChatMessage(msgHeader, "GUILD")
                
                -- Si la lista de convocados es larga, enviarla en partes
                local currentPart = "Convocados: "
                for i, name in ipairs(summonedNames) do
                    if string.len(currentPart .. name .. ", ") > 250 then
                        SendChatMessage(currentPart, "GUILD")
                        currentPart = "Continuación: " .. name .. ", "
                    else
                        currentPart = currentPart .. name .. (i == #summonedNames and "" or ", ")
                    end
                end
                if currentPart ~= "Continuación: " and currentPart ~= "Convocados: " then
                    SendChatMessage(currentPart, "GUILD")
                end
                
                SendChatMessage("¡Por favor, acepten la invitación!", "GUILD")
            end
        else
            Log("|cffff0000[RaidDominion]|r Error: Debes seleccionar una banda primero")
        end
    end)

    
    -- Script para el botón Eliminar
    f3.deleteBtn:SetScript("OnClick", function(self)
        if selectedBandIndex and coreData[selectedBandIndex] then
            local bandData = coreData[selectedBandIndex]
            local bandName = bandData.name
            
            -- Verificar permisos: Todos pueden borrar bandas
            local permLevel = GetPerms()
            -- No hay restricción de eliminación para niveles 1+
            
            -- Registrar diálogo de confirmación de eliminación si no existe
            if not StaticPopupDialogs["RAID_DOMINION_DELETE_CORE_BAND"] then
                StaticPopupDialogs["RAID_DOMINION_DELETE_CORE_BAND"] = {
                    text = "¿Estás seguro de que quieres eliminar la banda %s?",
                    button1 = YES,
                    button2 = NO,
                    OnAccept = function(self)
                        local bandIndex = self.data.bandIndex
                        local coreData = EnsureCoreData()
                        table.remove(coreData, bandIndex)
                        
                        -- Actualizar ventana
                        RD.utils.coreBands.ShowCoreBandsWindow()
                    end,
                    timeout = 0,
                    whileDead = 1,
                    hideOnEscape = 1
                }
            end
            
            -- Mostrar diálogo de confirmación
            StaticPopup_Show("RAID_DOMINION_DELETE_CORE_BAND", bandName, nil, { bandIndex = selectedBandIndex })
        else
            Log("|cffff0000[RaidDominion]|r Error: Debes seleccionar una banda primero")
        end
    end)
    
    -- Llenar lista de bandas Core
    local yOffset = 0 -- Comenzar desde la parte superior del content frame
    
    -- Asegurar que coreData sea válido
    if not coreData then coreData = EnsureCoreData() end
    
    for i, band in ipairs(coreData) do
        
        local line = AcquireFrame(bandLinePool, "Frame", f3.content)
        line:SetSize(748, 40) -- Aumentado de 548 a 748 (+200px)
        line:SetPoint("TOPLEFT", 0, -yOffset)
        line:EnableMouse(true)
        line:SetFrameLevel(f3.content:GetFrameLevel() + 1)
        
        -- Guardar datos de la banda y el yOffset específico
        line.bandData = band
        line.bandIndex = i
        line.f3 = f3
        
        -- Resaltado al pasar el mouse y selección
        line:SetScript("OnEnter", function(self)
            -- Hover de fondo retirado por solicitud del usuario
        end)
        line:SetScript("OnLeave", function(self)
            -- Hover de fondo retirado por solicitud del usuario
        end)
        
        -- Checkbox para selección de banda
        if not line.selectCheck then
            line.selectCheck = CreateFrame("CheckButton", nil, line, "UICheckButtonTemplate")
            line.selectCheck:SetSize(24, 24)
            line.selectCheck:SetPoint("TOPRIGHT", -10, -8)
        end
        line.selectCheck:SetFrameLevel(line:GetFrameLevel() + 1)
        line.selectCheck:SetScript("OnClick", function(self)
            -- Seleccionar o deseleccionar la banda
            if self:GetChecked() then
                -- Seleccionar esta banda
                selectedBandIndex = i
                selectedBandLine = line
                
                -- Desmarcar otros checkboxes
                local children = {f3.content:GetChildren()}
                for _, child in ipairs(children) do
                    if child.bandIndex and child.bandIndex ~= i then
                        local otherCheck = child.selectCheck
                        if otherCheck then
                            otherCheck:SetChecked(false)
                        end
                    end
                end
                
                -- Actualizar todos los frames de selección
                for _, child in ipairs(children) do
                    if child.bandIndex then
                        if child.bandIndex == i then
                            child:SetBackdrop({
                                bgFile = "Interface/QuestFrame/UI-QuestTitleHighlight"
                            })
                        else
                            child:SetBackdrop(nil)
                        end
                    end
                end
            else
                -- Deseleccionar la banda
                selectedBandIndex = nil
                selectedBandLine = nil
                line:SetBackdrop(nil)
            end
        end)
        line.selectCheck:Show()
        
        -- Restaurar el estado de selección si esta es la banda seleccionada
        if selectedBandIndex == i then
            line.selectCheck:SetChecked(true)
            line:SetBackdrop({
                bgFile = "Interface/QuestFrame/UI-QuestTitleHighlight"
            })
            selectedBandLine = line -- Actualizar la referencia a la nueva línea
        else
            line.selectCheck:SetChecked(false)
            line:SetBackdrop(nil)
        end
        
        -- Nombre de la banda con número de miembros
        local totalVisible, onlineVisible = GetVisibleBandMembersCount(band, rosterCache)
        
        if not line.nameBtn then
            line.nameBtn = CreateFrame("Button", nil, line)
            line.nameBtn:SetSize(700, 20) -- Aumentado de 500 a 700
            line.nameBtn:SetPoint("TOPLEFT", 10, -2)
            
            line.nameText = UI.CreateLabel(line.nameBtn, "", "GameFontNormal")
            line.nameText:SetPoint("LEFT")
        end
        line.nameBtn:SetFrameLevel(line:GetFrameLevel() + 1)
        line.nameText:SetText(string.format("%s (Jugadores: %d, En linea: %d)", band.name, totalVisible, onlineVisible))
        line.nameText:SetTextColor(1, 1, 1)
        
        line.nameBtn:SetScript("OnEnter", function() line.nameText:SetTextColor(1, 1, 0) end)
        line.nameBtn:SetScript("OnLeave", function() line.nameText:SetTextColor(1, 1, 1) end)
        line.nameBtn:SetScript("OnClick", function()
            if totalVisible == 0 then
                Log("|cffffff00[RaidDominion]|r Esta banda no tiene miembros asignados.")
                return
            end
            local wasOpen = openMemberLists[i]
            closeAllMemberFrames(true) -- Limpiar sin refrescar inmediatamente
            if not wasOpen then
                openMemberLists[i] = true
                selectedBandIndex = i
                selectedBandLine = line
            end
            RD.utils.coreBands.ShowCoreBandsWindow()
        end)
        
        -- GS Mínimo y Horario
        if not line.infoBtn then
            line.infoBtn = CreateFrame("Button", nil, line)
            line.infoBtn:SetSize(700, 18) -- Aumentado de 500 a 700
            line.infoBtn:SetPoint("TOPLEFT", line.nameBtn, "BOTTOMLEFT", 0, 0)
            
            line.infoText = UI.CreateLabel(line.infoBtn, "", "GameFontNormalSmall")
            line.infoText:SetPoint("LEFT")
        end
        line.infoBtn:SetFrameLevel(line:GetFrameLevel() + 1)
        
        local gsMin = tonumber(band.minGS) or 5000
        local gsMinDecimal = string.format("%.1f", gsMin / 1000)
        local noteIndicator = (band.withNote == 1) and "Con Nota" or "Sin Nota"
        line.infoText:SetText(string.format("GS Min %s | %s | Horario: %s", gsMinDecimal, noteIndicator, band.schedule))
        line.infoText:SetTextColor(0.7, 0.7, 0.7)
        
        line.infoBtn:SetScript("OnEnter", function() line.infoText:SetTextColor(1, 1, 0) end)
        line.infoBtn:SetScript("OnLeave", function() line.infoText:SetTextColor(0.7, 0.7, 0.7) end)
        line.infoBtn:SetScript("OnClick", function()
            local permLevel = GetPerms()
            if permLevel < 2 then
                local mm = RD.modules and RD.modules.messageManager
                if mm and mm.PermissionError then
                    mm:PermissionError("editar bandas")
                else
                    Log("|cffff0000[RaidDominion]|r Error: No tienes permisos para editar bandas.")
                end
                return
            end
            local editFrame = getOrCreateBandFrame()
            editFrame.isEditing = true
            editFrame.bandIndex = i
            editFrame.title:SetText("Editar Banda")
            editFrame.nameEdit:SetText(band.name)
            editFrame.gsEdit:SetText(tostring(band.minGS))
            editFrame.scheduleEdit:SetText(band.schedule)
            editFrame.withNoteCheck:SetChecked(band.withNote == 1)
            editFrame:Show()
        end)
        
        yOffset = yOffset + 40
        
        if openMemberLists[i] then
            if not line.membersFrame then
                line.membersFrame = CreateFrame("Frame", nil, line)
                line.membersFrame.isMemberFrame = true
                line.membersFrame:SetWidth(748) -- Aumentado de 548 a 748 (+200px)
                line.membersFrame:SetBackdrop({
                    bgFile = "Interface/Buttons/WHITE8X8",
                    tile = true, tileSize = 8,
                })
                line.membersFrame:SetBackdropColor(0, 0, 0, 0.7)
            end
            line.membersFrame:SetParent(line)
            line.membersFrame:SetPoint("TOPLEFT", line, "BOTTOMLEFT", 0, 0)
            line.membersFrame:Show()
            
            local membersHeight = renderBandMembers(band, line.membersFrame, i, rosterCache)
            yOffset = yOffset + membersHeight
        elseif line.membersFrame then
            -- Liberar hijos del pool
            local mChildren = {line.membersFrame:GetChildren()}
            for _, mChild in ipairs(mChildren) do
                if mChild.playerName then
                    ReleaseFrame(memberCardPool, mChild)
                elseif mChild.text then
                    ReleaseFrame(roleHeaderPool, mChild)
                else
                    mChild:Hide()
                    mChild:SetParent(nil)
                end
            end
            line.membersFrame:Hide()
            line.membersFrame:SetParent(nil)
            line.membersFrame = nil
        end
    end
    
    -- Actualizar el tamaño total del content frame
    f3.content:SetHeight(yOffset + 20)
    
    -- Restaurar posición de scroll
    if f3.scroll and currentScroll > 0 then
        -- Usar un método compatible con todas las versiones en lugar de C_Timer.After
        local scrollRestoreFrame = CreateFrame("Frame")
        local startTime = GetTime()
        local delay = 0.01
        
        scrollRestoreFrame:SetScript("OnUpdate", function(self, elapsed)
            if GetTime() - startTime >= delay then
                if f3.scroll then
                    f3.scroll:SetVerticalScroll(math.min(currentScroll, f3.scroll:GetVerticalScrollRange()))
                end
                self:SetScript("OnUpdate", nil)
                self:Hide()
                self = nil
            end
        end)
    end
    
    -- Mostrar la ventana
    f3:Show()
end
