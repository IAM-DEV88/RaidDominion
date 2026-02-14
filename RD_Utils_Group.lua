--[[
    RD_Utils_Group.lua
    Módulo de utilidades para la gestión de grupos y bandas
--]]

local addonName, private = ...
local RD = _G.RaidDominion or {}
_G.RaidDominion = RD

-- Inicializar tablas necesarias
RD.utils = RD.utils or {}
RD.constants = RD.constants or {}
RD.events = RD.events or {}

-- Referencias locales
local constants = RD.constants
local events = RD.events

-- Función centralizada para loguear mensajes
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

-- Compatibilidad con versiones antiguas de WoW (3.3.5a)
local IsInRaid = _G.IsInRaid or function() 
    return (_G.GetNumRaidMembers and _G.GetNumRaidMembers() > 0) or false 
end
local IsInGroup = _G.IsInGroup or function() 
    return (_G.GetNumPartyMembers and _G.GetNumPartyMembers() > 0) or (_G.GetNumRaidMembers and _G.GetNumRaidMembers() > 0) or false 
end
local GetNumGroupMembers = _G.GetNumGroupMembers or function()
    local raidMembers = _G.GetNumRaidMembers and _G.GetNumRaidMembers() or 0
    if raidMembers > 0 then return raidMembers end
    local partyMembers = _G.GetNumPartyMembers and _G.GetNumPartyMembers() or 0
    if partyMembers > 0 then return partyMembers + 1 end
    return 1
end

-- Función de depuración
local function RD_Debug(msg, ...)
    if RD.DEBUG_ENABLED then
        Log("|cff00ff00[RD_Debug]|r " .. msg, ...)
    end
end

-- Variables locales
local playerAssignments = {}
local previousGroupMembers = {}
local currentGroupMembers = {} -- Unificada
local playerClasses = {} 
local groupUtils = {}
RD.utils.group = groupUtils

-- Constantes
local GROUP_UPDATE_THROTTLE = 0.5 
local GROUP_TYPES = RD.constants.GROUP_TYPES or {
    NONE = 0,
    PARTY = 1,
    RAID = 2,
    BATTLEGROUND = 3
}

--- Obtiene el nombre completo de un jugador (Nombre-Reino)
-- @param unit string El identificador de la unidad (ej: "player", "raid1", "target")
-- @return string|nil El nombre completo o nil si no se encuentra
function groupUtils:GetFullPlayerName(unit)
    if not unit then return nil end
    
    local name, realm = UnitName(unit)
    if not name then return nil end
    
    if not realm or realm == "" then
        realm = GetRealmName()
    end
    
    return name.."-"..realm
end

-- Función para obtener la lista de miembros de la hermandad
function groupUtils.GetGuildMemberList()
    if not IsInGuild() then
        return {}
    end
    
    -- Ensure RaidDominionDB exists and has Guild table
    _G.RaidDominionDB = _G.RaidDominionDB or {}
    _G.RaidDominionDB.Guild = _G.RaidDominionDB.Guild or {}
    
    local numTotalMembers = GetNumGuildMembers(true)
    local guildMembers = {}
    
    -- Acceder a las tablas de GearScore
    local gsData = _G["GS_Data"]
    local realmName = GetRealmName()
    local gsPlayers = nil
    
    if gsData and gsData[realmName] and gsData[realmName]["Players"] then
        gsPlayers = gsData[realmName]["Players"]
    end
    
    local updatesNeeded = {}
    
    for i = 1, numTotalMembers do
        local name, rankName, rankIndex, _, class, _, publicNote, officerNote, _, _, classFileName = GetGuildRosterInfo(i)
        if name then
            -- Obtener GearScore y Race de la base de datos de GearScore
            local gearScore = 0
            local race = nil
            
            -- Limpiar el nombre de reino si existe (Name-Realm -> Name)
            local cleanName = string.match(name, "^([^-]+)") or name
            
            if gsPlayers and gsPlayers[cleanName] then
                local pData = gsPlayers[cleanName]
                if type(pData) == "table" then
                    gearScore = tonumber(pData["GearScore"]) or 0
                    race = pData["Race"]
                end
            end
            
            -- Verificar si se requiere actualización de nota
            if publicNote and publicNote ~= "" and gearScore > 0 then
                -- Buscar el primer número decimal en la nota (ej: 4.0, 5.1)
                local currentVal = string.match(publicNote, "(%d+%.%d+)")
                if currentVal then
                    -- Calcular el nuevo valor basado en el GearScore (ej: 5303 -> 5.3)
                    local newGSVal = string.format("%.1f", gearScore / 1000)
                    
                    -- Si son diferentes, añadir a la lista de actualizaciones
                    if currentVal ~= newGSVal then
                        -- Crear la nueva nota reemplazando solo la primera ocurrencia
                        local newNote = string.gsub(publicNote, "%d+%.%d+", newGSVal, 1)
                        table.insert(updatesNeeded, {
                            name = name,
                            currentNote = publicNote,
                            newNote = newNote,
                            gearScore = gearScore
                        })
                    end
                end
            end

            table.insert(guildMembers, {
                index = i,
                name = name,
                rank = rankName,
                class = class,
                classFileName = classFileName,
                publicNote = publicNote or "",
                officerNote = officerNote or "",
                gearScore = gearScore,
                race = race
            })
        end
    end
    
    -- Store in RaidDominionDB.Guild (excluding index, gearScore, and classFileName)
    local savedMembers = {}
    for _, member in ipairs(guildMembers) do
        local memberCopy = {}
        for k, v in pairs(member) do
            if k ~= "index" and k ~= "gearScore" and k ~= "classFileName" then
                memberCopy[k] = v
            end
        end
        table.insert(savedMembers, memberCopy)
    end
    _G.RaidDominionDB.Guild.memberList = savedMembers
    _G.RaidDominionDB.Guild.lastUpdate = time()
    _G.RaidDominionDB.Guild.generatedBy = UnitName("player")
    _G.RaidDominionDB.Guild.update = nil
    
    return guildMembers, updatesNeeded
end

-- Referencias locales para optimización
local GetGuildRosterInfo, GetNumGuildMembers, GuildRoster = GetGuildRosterInfo, GetNumGuildMembers, GuildRoster
local GetTime = GetTime

-- Caché para el estado de la hermandad
local guildOnlineCache = {}
local guildFullCache = {} -- Caché para datos completos (rango, notas, clase)
local lastGuildUpdate = 0
local isUpdatingGuild = false
local updateCoroutine = nil
local isInternalGuildUpdate = false

-- Función para actualizar la caché de la hermandad (Optimizada con coroutine)
function groupUtils:UpdateGuildOnlineCache(force)
    local now = GetTime()
    local freq = 60 -- Frecuencia (1 minuto)
    
    if not force and (now - lastGuildUpdate < freq) then
        return
    end
    
    -- Si ya hay una actualización en curso, no empezar otra
    if isUpdatingGuild then return end
    
    local function DoUpdate()
        isUpdatingGuild = true
        isInternalGuildUpdate = true
        
        -- Usar tablas temporales para evitar parpadeo
        local tempOnlineCache = {}
        local tempFullCache = {}
        
        local numMembers = GetNumGuildMembers(true)
        local chunkCount = 0
        local chunkSize = 100 -- Procesar 100 miembros por frame
        
        for i = 1, numMembers do
            local name, rank, rankIndex, level, class, zone, note, officerNote, online, status, classFileName = GetGuildRosterInfo(i)
            if name then
                local cleanName = RD.utils:CleanName(name)
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
            
            chunkCount = chunkCount + 1
            if chunkCount >= chunkSize then
                chunkCount = 0
                coroutine.yield()
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
                    if RD.messageManager and RD.messageManager.SendSystemMessage then
                        RD.messageManager:SendSystemMessage("|cffff0000[RaidDominion Error]:|r " .. (err or "Unknown error in Guild Cache update"))
                    else
                        SendSystemMessage("|cffff0000[RaidDominion Error]:|r " .. (err or "Unknown error in Guild Cache update"))
                    end
                end
            end
        else
            self:SetScript("OnUpdate", nil)
            isUpdatingGuild = false
        end
    end)
end

--- Verifica si un jugador de la hermandad está online usando la caché
-- @param cleanName string El nombre limpio del jugador
-- @return boolean|nil true si está online, false si offline, nil si no está en la hermandad
function groupUtils:IsGuildMemberOnline(cleanName)
    return guildOnlineCache[cleanName]
end

--- Obtiene los datos completos de un miembro de la hermandad desde la caché
-- @param cleanName string El nombre limpio del jugador
-- @return table|nil Datos del miembro o nil si no existe
function groupUtils:GetGuildMemberData(cleanName)
    return guildFullCache[cleanName]
end

--- Obtiene la caché completa de la hermandad (SOLO LECTURA)
-- @return table La caché completa de la hermandad
function groupUtils:GetGuildFullCache()
    return guildFullCache
end

--- Verifica si un jugador está en el grupo o banda actual
-- @param playerName string El nombre del jugador
-- @param rosterCache table Opcional: Caché del roster para búsqueda O(1)
-- @return boolean true si está en el grupo
function groupUtils:IsPlayerInGroup(playerName, rosterCache)
    if not playerName then return false end
    local cleanName = RD.utils.CleanName and RD.utils.CleanName(playerName) or playerName:lower()
    
    -- Si hay caché, usarla (O(1))
    if rosterCache then
        return rosterCache[cleanName] ~= nil
    end
    
    -- Si no hay caché, búsqueda manual (O(N))
    local numRaid = GetNumRaidMembers()
    if numRaid > 0 then
        for i = 1, numRaid do
            local name = GetRaidRosterInfo(i)
            if name and (RD.utils.CleanName and RD.utils.CleanName(name) or name:lower()) == cleanName then
                return true
            end
        end
    else
        local numParty = GetNumPartyMembers()
        if numParty > 0 then
            if (RD.utils.CleanName and RD.utils.CleanName(UnitName("player")) or UnitName("player"):lower()) == cleanName then
                return true
            end
            for i = 1, numParty do
                local name = UnitName("party"..i)
                if name and (RD.utils.CleanName and RD.utils.CleanName(name) or name:lower()) == cleanName then
                    return true
                end
            end
        end
    end
    return false
end

--- Verifica si un jugador está online (en grupo, hermandad o vía API)
-- @param playerName string El nombre del jugador
-- @param rosterCache table Opcional: Caché del roster
-- @return boolean true si está online
function groupUtils:IsPlayerOnline(playerName, rosterCache)
    if not playerName then return false end
    local cleanName = RD.utils.CleanName and RD.utils.CleanName(playerName) or playerName:lower()
    
    -- 1. Si está en el grupo/raid, está online por definición
    if rosterCache and rosterCache[cleanName] then
        return true
    end
    
    -- 2. Si está en la caché de hermandad
    if guildOnlineCache[cleanName] ~= nil then
        return guildOnlineCache[cleanName]
    end
    
    -- 3. Fallback: UnitExists
    return UnitExists(playerName)
end

-- Variables de estado del grupo (internas)
local inRaid = false
local inParty = false
local numGroupMembers = 1
local isGroupLeader = false

-- Detectar jugadores que abandonaron el grupo
local function DetectLeftPlayers()
    local currentMembers = {}
    RD_Debug("Iniciando DetectLeftPlayers...")
    
    -- Usar la lógica de groupUtils para obtener miembros actuales
    local members = groupUtils:GetGroupMembers()
    RD_Debug("Miembros actuales encontrados: %d", #members)
    
    for _, member in ipairs(members) do
        local fullName = groupUtils:GetFullPlayerName(member.unit)
        if fullName then
            currentMembers[fullName] = true
            -- RD_Debug("Miembro actual: %s", fullName)
        end
    end
    
    -- Verificar jugadores que ya no están en el grupo
    local jugadoresQueAbandonaron = {}
    local countPrevious = 0
    for nombre, memberData in pairs(previousGroupMembers) do
        countPrevious = countPrevious + 1
        if not currentMembers[nombre] then
            RD_Debug("Jugador detectado como salido: %s", nombre)
            table.insert(jugadoresQueAbandonaron, nombre)
        end
    end
    RD_Debug("Comparando con %d miembros previos. Total salidos detectados: %d", countPrevious, #jugadoresQueAbandonaron)
    
    -- Procesar jugadores que abandonaron
    for _, nombre in ipairs(jugadoresQueAbandonaron) do
        local memberData = previousGroupMembers[nombre]
        local class = memberData and memberData.class or "Unknown"
        local roles = ""
        local resetInfo = nil
        
        RD_Debug("Procesando salida de %s (%s)", nombre, class)
        
        -- Obtener roles antes de resetear
        if RD.roleManager and RD.roleManager.GetRole then
            roles = RD.roleManager:GetRole(nombre) or ""
            RD_Debug("Roles previos de %s: %s", nombre, roles)
        end
        
        if groupUtils.ResetPlayerAssignments then
            local success, info = groupUtils:ResetPlayerAssignments(nombre)
            resetInfo = info
            RD_Debug("Reseteo de asignaciones para %s: %s (Total eliminados: %d)", 
                nombre, tostring(success), (resetInfo and resetInfo.totalRemoved or 0))
        end
        
        -- Si no se resetearon asignaciones específicas de la BD, 
        -- intentamos al menos limpiar el cache de selecciones
        if not resetInfo or resetInfo.totalRemoved == 0 then
            RD_Debug("No se encontraron asignaciones en BD para %s, limpiando cache de selecciones...", nombre)
            local r1 = groupUtils:ResetPlayerRoles(nombre)
            local r2 = groupUtils:ResetPlayerBuffs(nombre)
            local r3 = groupUtils:ResetPlayerAbilities(nombre)
            local r4 = groupUtils:ResetPlayerAuras(nombre)
            RD_Debug("Limpieza de cache para %s: Roles=%s, Buffs=%s, Abils=%s, Auras=%s", 
                nombre, tostring(r1), tostring(r2), tostring(r3), tostring(r4))
        end

        if RD.events and RD.events.Publish then
            RD_Debug("Publicando PLAYER_LEFT_GROUP para %s", nombre)
            RD.events:Publish("PLAYER_LEFT_GROUP", {
                playerName = nombre, 
                class = class, 
                roles = roles,
                resetInfo = resetInfo
            })
        end
    end
    
    -- Forzar actualización de la interfaz si hay jugadores que abandonaron
    if #jugadoresQueAbandonaron > 0 then
        if RD.UI and RD.UI.DynamicMenus and RD.UI.DynamicMenus.UpdateAllMenus then
            RD_Debug("Actualizando menús dinámicos tras salidas.")
            RD.UI.DynamicMenus:UpdateAllMenus()
        end
    end
end

-- Función para manejar eventos de grupo
local function onGroupEvent(self, event, ...)
    RD_Debug("Evento de grupo recibido: %s", tostring(event))
    
    if event == "GROUP_ROSTER_UPDATE" or 
       event == "PARTY_MEMBERS_CHANGED" or 
       event == "RAID_ROSTER_UPDATE" or
       event == "PARTY_LEADER_CHANGED" or
       event == "GROUP_LEFT" or
       event == "GROUP_DISBANDED" or
       event == "PLAYER_ENTERING_WORLD" then
        
        -- Configurar temporizador para evitar múltiples ejecuciones seguidas
        if self.updateTimer then
            self.updateTimer:Cancel()
            self.updateTimer = nil
        end
        
        -- Usar C_Timer si está disponible, o OnUpdate si no
        local throttleTime = 0.5
        
        local function ProcessUpdate()
            RD_Debug("Procesando actualización diferida para evento: %s", event)
            -- IMPORTANTE: Detectar quién se fue ANTES de actualizar el estado interno
            -- para poder comparar con la lista anterior (previousGroupMembers)
            DetectLeftPlayers()
            
            -- Ahora actualizar el estado interno para la próxima comparación
            if groupUtils and groupUtils.UpdateGroupState then
                groupUtils:UpdateGroupState()
            end
            
            if RD.UI and RD.UI.DynamicMenus and RD.UI.DynamicMenus.UpdateAllMenus then
                RD.UI.DynamicMenus:UpdateAllMenus()
            end

            -- Notificar a otros módulos
            if RD.events and RD.events.Publish then
                RD.events:Publish("GROUP_UPDATED", {
                    inRaid = inRaid,
                    inParty = inParty,
                    numMembers = numGroupMembers,
                    isLeader = isGroupLeader,
                    event = event
                })
            end
        end

        if _G.C_Timer and _G.C_Timer.After then
            self.updateTimer = {
                Cancel = function(s) s.cancelled = true end,
                cancelled = false
            }
            _G.C_Timer.After(throttleTime, function()
                if not self.updateTimer.cancelled then
                    ProcessUpdate()
                end
            end)
        else
            self.updateTimerCount = 0
            self:SetScript("OnUpdate", function(frame, elapsed)
                frame.updateTimerCount = frame.updateTimerCount + elapsed
                if frame.updateTimerCount >= throttleTime then
                    frame:SetScript("OnUpdate", nil)
                    ProcessUpdate()
                end
            end)
            -- Mock Cancel para compatibilidad
            self.updateTimer = { Cancel = function() self:SetScript("OnUpdate", nil) end }
        end
    end
end

-- Función para actualizar el estado del grupo
function groupUtils:UpdateGroupState()
    if not self.GetFullPlayerName then
        RD_Debug("|cffff0000Error:|r GetFullPlayerName no está disponible en UpdateGroupState")
        return
    end

    -- Obtener número de miembros en grupo y banda
    local numParty = GetNumPartyMembers() or 0
    local numRaid = GetNumRaidMembers() or 0
    
    -- Determinar el estado actual
    inRaid = numRaid > 0
    inParty = not inRaid and numParty > 0
    
    -- Calcular el número total de miembros
    if inRaid then
        numGroupMembers = numRaid
    elseif inParty then
        numGroupMembers = numParty + 1 -- Incluir al jugador
    else
        numGroupMembers = 1
    end
    
    -- Guardar el estado anterior antes de actualizar
    local oldMembers = {}
    if previousGroupMembers then
        for k, v in pairs(previousGroupMembers) do
            oldMembers[k] = v
        end
    end

    -- Actualizar previousGroupMembers para la próxima comparación
    previousGroupMembers = {}
    
    local members = self:GetGroupMembers()
    for _, member in ipairs(members) do
        local fullName = self:GetFullPlayerName(member.unit)
        if fullName then
            local _, class = UnitClass(member.unit)
            previousGroupMembers[fullName] = {
                unit = member.unit,
                name = member.name,
                class = class or "Unknown"
            }
        end
    end
    
    -- Verificar si somos el líder
    isGroupLeader = IsRaidLeader() or IsPartyLeader() or (numGroupMembers == 1)
    
    RD_Debug("Estado del grupo actualizado. Miembros detectados: %d", numGroupMembers)
end

-- Constants
local GROUP_UPDATE_THROTTLE = 0.5 -- seconds between updates

-- Función para verificar si la API está disponible
local function IsGroupAPIAvailable()
    -- Lista de funciones requeridas
    local requiredFunctions = {
        "IsInRaid", "IsInGroup", "GetNumGroupMembers",
        "GetNumRaidMembers", "GetNumPartyMembers", "UnitInRaid", "UnitInParty"
    }
    
    -- Verificar funciones faltantes
    for _, funcName in ipairs(requiredFunctions) do
        if type(_G[funcName]) ~= "function" then
            return false
        end
    end
    
    -- Verificar que las funciones devuelvan valores válidos
    local success, raidStatus, groupStatus, memberCount = pcall(function()
        return IsInRaid(), IsInGroup(), GetNumGroupMembers()
    end)
    
    if not success then
        return false
    end
    
    -- Verificar tipos de retorno
    return type(raidStatus) == "boolean" and 
           type(groupStatus) == "boolean" and 
           type(memberCount) == "number"
end

-- Versión segura de las funciones de grupo
local function SafeIsInRaid()
    local success, result = pcall(IsInRaid)
    if not success then
        return false
    end
    return result == true or result == 1
end

local function SafeIsInGroup()
    local success, result = pcall(IsInGroup)
    if not success then
        
        -- Intentar con métodos alternativos
        if GetNumPartyMembers and GetNumPartyMembers() > 0 then
            return true
        end
        return false
    end
    return result == true or result == 1
end

local function SafeGetNumGroupMembers()
    -- Primero intentar con GetNumGroupMembers (versiones modernas)
    local success, result = pcall(GetNumGroupMembers)
    if success and result ~= nil then
        return result
    end
    
    -- Verificar si estamos en banda
    if GetNumRaidMembers then
        local raidMembers = GetNumRaidMembers()
        if raidMembers and raidMembers > 0 then
            return raidMembers
        end
    end
    
    -- Verificar si estamos en grupo
    if GetNumPartyMembers then
        local partyMembers = GetNumPartyMembers()
        if partyMembers and partyMembers > 0 then
            return partyMembers + 1 -- +1 por el jugador
        end
    end
    
    -- Si no estamos en grupo, devolver 1 (solo el jugador)
    return 1
end

-- Función para extraer el nombre base del jugador sin reino
local function GetBasePlayerName(fullName)
    if not fullName then return nil end
    local baseName = string.match(fullName, "^([^%-]+)")
    return baseName or fullName
end

--- Compara dos nombres de jugador (incluyendo casos con y sin reino)
local function ComparePlayerNames(name1, name2)
    if not name1 or not name2 then return false end
    if name1 == name2 then return true end
    
    local base1 = GetBasePlayerName(tostring(name1))
    local base2 = GetBasePlayerName(tostring(name2))
    
    return base1 == base2
end

-- Función pública para obtener información del grupo
function groupUtils:GetGroupInfo()
    local inRaid = IsInRaid()
    local inParty = IsInGroup() and not inRaid
    local numMembers = 1
    
    if inRaid then
        numMembers = GetNumRaidMembers() or 0
    elseif inParty then
        numMembers = (GetNumPartyMembers() or 0) + 1
    end
    
    local groupType = inRaid and "RAID" or (inParty and "PARTY" or "SOLO")
    
    return inRaid, inParty, groupType, numMembers
end

--[[
    Genera un reporte de jugadores ausentes (offline, AFK, muertos)
    @return table Reporte con listas de jugadores offline, afk y muertos
]]
function groupUtils:GetAbsentPlayersReport()
    local inRaid, inParty = self:GetGroupInfo()
    
    if not inRaid and not inParty then
        return nil
    end
    
    local absent = { offline = {}, afk = {}, dead = {} }
    local unitPrefix = inRaid and "raid" or "party"
    local count = inRaid and GetNumRaidMembers() or GetNumPartyMembers()
    
    -- Si es party, incluir al jugador
    local units = {}
    if not inRaid then
        table.insert(units, "player")
    end
    
    for i = 1, count do
        table.insert(units, unitPrefix .. i)
    end
    
    for _, unit in ipairs(units) do
        if UnitExists(unit) then
            local name = UnitName(unit)
            local isOnline = UnitIsConnected(unit)
            local isAFK = UnitIsAFK(unit)
            local isDead = UnitIsDeadOrGhost(unit)
            
            if not isOnline then
                table.insert(absent.offline, name)
            elseif isAFK then
                table.insert(absent.afk, name)
            elseif isDead then
                table.insert(absent.dead, name)
            end
        end
    end
    
    return absent
end

--[[
    Establece la dificultad de la banda
    @param size Tamaño (10 o 25)
    @param heroic Booleano, true para heroico
    @return string Mensaje de resultado
]]
function groupUtils:SetRaidDifficulty(size, heroic)
    local s = tonumber(size) or 10
    local h = heroic and true or false
    local diff
    
    if s >= 25 then
        diff = h and 4 or 2
    else
        diff = h and 3 or 1
    end
    
    if SetRaidDifficulty then
        SetRaidDifficulty(diff)
    elseif SetRaidDifficultyID then
        SetRaidDifficultyID(diff)
    end
    
    local modeText = (s >= 25 and "25") or "10"
    local hText = h and "Heroico" or "Normal"
    
    return string.format("Dificultad establecida: %s %s", modeText, hText)
end

--[[
    Obtiene información detallada del objetivo
    @param unit Unidad a inspeccionar (por defecto "target")
    @return table Información del objetivo o nil si no existe
]]
function groupUtils:GetTargetInfo(unit)
    unit = unit or "target"
    if not UnitExists(unit) then
        return nil
    end
    
    local info = {}
    info.name = UnitName(unit)
    info.health = UnitHealth(unit)
    info.healthMax = UnitHealthMax(unit)
    info.healthPct = info.healthMax > 0 and math.floor((info.health / info.healthMax) * 100) or 0
    info.level = UnitLevel(unit)
    info.classification = UnitClassification(unit)
    info.classLocalized = select(1, UnitClass(unit)) or ""
    
    -- Power info
    local powerType = select(1, UnitPowerType(unit))
    info.powerType = powerType
    info.power = UnitPower(unit, powerType)
    info.powerMax = UnitPowerMax(unit, powerType)
    info.powerPct = (info.powerMax or 0) > 0 and math.floor((info.power / info.powerMax) * 100) or 0
    
    return info
end

--[[
    Alterna el método de botín entre Grupo y Maestro Despojador
    @return string Mensaje de resultado
]]
function groupUtils:ToggleLootMethod()
    local inRaid, inParty, _, isLeader = self:GetGroupInfo()
    
    if (inRaid or inParty) and not isLeader then
        return "No tienes permiso para cambiar el botín."
    end
    
    local method = GetLootMethod()
    if method == "master" then
        SetLootMethod("group")
        return "Modo de botín: Grupo"
    else
        SetLootMethod("master", UnitName("player"))
        return "Modo de botín: Maestro despojador (Tú)"
    end
end

--[[
    Establece al objetivo como Maestro Despojador
    @return string Mensaje de resultado
]]
function groupUtils:SetMasterLooterToTarget()
    local inRaid, inParty, _, isLeader = self:GetGroupInfo()
    
    if (inRaid or inParty) and not isLeader then
        return "No tienes permiso para cambiar el botín."
    end
    
    if not UnitExists("target") or not UnitIsPlayer("target") then
        return "Por favor, selecciona un jugador objetivo primero."
    end
    
    if UnitIsUnit("target", "player") then
        SetLootMethod("master", UnitName("player"))
        return "Modo de botín: Maestro despojador (Tú)"
    else
        local targetName = UnitName("target")
        SetLootMethod("master", targetName)
        return string.format("Modo de botín: Maestro despojador (%s)", targetName)
    end
end

-- Función para verificar si estamos en grupo (compatible con versiones antiguas)
local function IsInGroupCompatible()
    return (GetNumPartyMembers() or 0) > 0 or (GetNumRaidMembers() or 0) > 0
end

-- Función para verificar si estamos en banda (compatible con versiones antiguas)
local function IsInRaidCompatible()
    return (GetNumRaidMembers() or 0) > 0
end



-- Esta función ha sido movida al inicio del archivo

-- Cache de miembros del grupo
local groupCache = {
    members = {},
    lastUpdate = 0,
    groupType = GROUP_TYPES.NONE
}

--[[
    Actualiza la caché de miembros del grupo
    @param self Referencia al módulo
    @param forceUpdate Forzar la actualización aunque la caché sea reciente
]]
function groupUtils:UpdateGroupCache(forceUpdate)
    -- Inicializar el módulo si es necesario
    if not self.initialized then
        self:Initialize()
        if not self.initialized then return end
    end
    
    -- Obtener el estado actual del grupo
    local inRaid = IsInRaidCompatible()
    local inGroup = inRaid or IsInGroupCompatible()
    
    if not inGroup and not inRaid then
        self:HandleGroupDisband()
        return
    end
    
    -- Obtener miembros del grupo
    local members = self:GetGroupMembers()
    local newGroup = {}
    
    -- Actualizar la lista de miembros
    for _, member in ipairs(members) do
        if member.name then
            newGroup[member.name] = true
            if not currentGroupMembers[member.name] then
                -- New group member added
            end
        end
    end
    
    -- Verificar miembros que ya no están
    for name in pairs(currentGroupMembers) do
        if not newGroup[name] then
            self:ResetPlayerRoles(name)
            self:ResetPlayerBuffs(name)
        end
    end
    
    -- Actualizar la lista actual de miembros
    currentGroupMembers = newGroup
    
    -- Inicializar tablas si no existen
    RaidDominionSelections = RaidDominionSelections or {}
    RaidDominionSelections.roles = RaidDominionSelections.roles or {}
    RaidDominionSelections.buffs = RaidDominionSelections.buffs or {}
    RaidDominionSelections.abilities = RaidDominionSelections.abilities or {}
    RaidDominionSelections.auras = RaidDominionSelections.auras or {}
    
    -- Verificar si el módulo está listo
    if not isInitialized then
        return
    end
    
    -- Verificar si las funciones de la API están disponibles
    if not (IsInRaid and IsInGroup and GetNumGroupMembers) then
        -- API no disponible, continuar con la información disponible
    end
    
    -- Throttle updates
    local now = GetTime()
    if not forceUpdate and (now - lastGroupUpdate) < GROUP_UPDATE_THROTTLE then
        return
    end
    lastGroupUpdate = now
    
    -- Prevent recursive updates
    if isProcessing then
        return
    end
    
    isProcessing = true
    
    -- Obtener estado actual del grupo de forma segura
    local inRaid, inParty, groupType, numMembers = getGroupInfo()
    
    -- Get current group members with their classes
    local newGroup = {}
    local newPlayerClasses = {}
    
    -- Asegurarse de incluir al jugador primero
    local playerName = self:GetFullPlayerName("player")
    if playerName then
        newGroup[playerName] = true
        newPlayerClasses[playerName] = UnitClass("player") -- Store player's class
    end
    
    -- Obtener miembros del grupo si es posible
    local unitPrefix = inRaid and "raid" or (inParty and "party" or nil)
    
    if unitPrefix and UnitExists and (inRaid or inParty) then
        local maxMembers = inRaid and (GetNumRaidMembers() or 0) or (GetNumPartyMembers() or 0)
        if maxMembers and maxMembers > 0 then
            
            for i = 1, maxMembers do
                local unitId = unitPrefix .. i
                if UnitExists(unitId) then
                    local name = self:GetFullPlayerName(unitId)
                    if name and name ~= playerName then  -- Evitar duplicar al jugador
                        newGroup[name] = true
                        newPlayerClasses[name] = UnitClass(unitId) -- Store member's class
                    end
                end
            end
        end
    end
    
    -- Handle raid/party members
    if inRaid then
        local numMembers = GetNumRaidMembers() or 0
        for i = 1, numMembers do
            local unitId = "raid"..i
            local name = self:GetFullPlayerName(unitId)
            if name then 
                newGroup[name] = true
                if not newPlayerClasses[name] then
                    newPlayerClasses[name] = UnitClass(unitId) -- Ensure class is stored
                end
            end
        end
    elseif inParty then
        local numMembers = GetNumPartyMembers() or 0
        for i = 1, numMembers do
            local unitId = "party"..i
            local name = self:GetFullPlayerName(unitId)
            if name then 
                newGroup[name] = true
                if not newPlayerClasses[name] then
                    newPlayerClasses[name] = UnitClass(unitId) -- Ensure class is stored
                end
            end
        end
    end
    
    -- Check for left members or group disband
    local anyChanges = false
    
    -- First, ensure currentGroupMembers is properly initialized
    if type(currentGroupMembers) ~= "table" then
        currentGroupMembers = {}
    end
    
    -- If we're not in a group anymore, clear everything
    local inRaid = IsInRaid()
    local inGroup = inRaid or IsInGroup()
    
    if not inGroup and not inRaid then
        self:HandleGroupDisband()
        return
    end
    
    -- Check each previously known member
    for playerName, _ in pairs(currentGroupMembers) do
        if not newGroup[playerName] then
            -- Player left the group
            local baseName = GetBasePlayerName(playerName)
            local playerClass = playerClasses[playerName] or "Desconocida" -- Get player's class
            
            -- Send system message when player leaves (Removed to avoid duplication with PLAYER_LEFT_GROUP event)
            -- SendSystemMessage(string.format("RaidDominion: %s (%s) ha abandonado el grupo.", baseName or playerName, playerClass))
            
            -- Reset all assignments for the player who left
            local rolesReset = self:ResetPlayerRoles(playerName)
            local buffsReset = self:ResetPlayerBuffs(playerName)
            local abilitiesReset = self:ResetPlayerAbilities(playerName)
            local aurasReset = self:ResetPlayerAuras(playerName)
            
            -- Also try with base name in case the name was stored differently
            if baseName and baseName ~= playerName then
                rolesReset = self:ResetPlayerRoles(baseName) or rolesReset
                buffsReset = self:ResetPlayerBuffs(baseName) or buffsReset
                abilitiesReset = self:ResetPlayerAbilities(baseName) or abilitiesReset
                aurasReset = self:ResetPlayerAuras(baseName) or aurasReset
            end
            
            -- Send system message with reset information (Removed to avoid duplication)
            if rolesReset or buffsReset or abilitiesReset or aurasReset then
                anyChanges = true
                -- local resetMessages = {}
                -- if rolesReset then table.insert(resetMessages, "roles") end
                -- if buffsReset then table.insert(resetMessages, "buffs") end
                -- if abilitiesReset then table.insert(resetMessages, "habilidades") end
                -- if aurasReset then table.insert(resetMessages, "auras") end
                
                -- if #resetMessages > 0 then
                --     SendSystemMessage(string.format("RaidDominion: Asignaciones reiniciadas para %s: %s", 
                --         baseName or playerName, table.concat(resetMessages, ", ")))
                -- end
            end
            
            -- Force UI update
            events:Publish("GROUP_MEMBER_LEFT", playerName)
        end
    end
    
    -- Ensure currentGroupMembers is a table
    if type(currentGroupMembers) ~= "table" then
        currentGroupMembers = {}
    end
    
    -- Update current group
    -- Clear current group members
    for k in pairs(currentGroupMembers) do
        currentGroupMembers[k] = nil
    end
    
    -- Add new members
    for k, v in pairs(newGroup) do
        if type(k) == "string" then  -- Only add string keys (player names)
            currentGroupMembers[k] = true
        end
    end
    
    -- Update player classes
    -- Clear old classes for players who left
    for k in pairs(playerClasses) do
        if not newGroup[k] then
            playerClasses[k] = nil
        end
    end
    
    -- Add/update classes for current players
    for k, v in pairs(newPlayerClasses) do
        if type(k) == "string" then
            playerClasses[k] = v
        end
    end
    
    -- Update group type
    if inRaid then
        groupCache.groupType = GROUP_TYPES.RAID
    elseif inParty then
        groupCache.groupType = GROUP_TYPES.PARTY
    else
        groupCache.groupType = GROUP_TYPES.NONE
    end
    
    -- Update group members cache
    groupCache.members = newGroup
    groupCache.lastUpdate = now
    
    -- Notify listeners
    events:Publish("GROUP_UPDATED", newGroup)
    
    isProcessing = false
end

--[[
    Resetea todas las asignaciones de un jugador que ha abandonado el grupo
    @param self Referencia al módulo
    @param playerName Nombre del jugador que ha abandonado el grupo
]]
function groupUtils:ResetPlayerAssignments(playerName)
    if not playerName or playerName == "" then 
        return 
    end
    
    -- Resetting player assignments
    
    -- Clean realm name if it exists
    local basePlayerName = GetBasePlayerName(playerName)
    
    -- Ensure RaidDominionDB exists
    if not RaidDominionDB then 
        return 
    end
    
    -- Initialize assignments if they don't exist
    RaidDominionDB.assignments = RaidDominionDB.assignments or {}
    
    -- Función para limpiar asignaciones de una categoría
    local function cleanAssignments(category)
        if not RaidDominionDB.assignments[category] then 
            return 0, {} 
        end
        
        local count = 0
        local toRemove = {}
        local names = {}
        
        -- Find all assignments for this player
        for key, value in pairs(RaidDominionDB.assignments[category]) do
            local assignedTo = value
            if type(value) == "table" then
                assignedTo = value.target or value.name or ""
            end
            
            -- Comparar usando la nueva función ComparePlayerNames
            if ComparePlayerNames(assignedTo, playerName) then
                table.insert(toRemove, key)
                table.insert(names, key) -- key es usualmente el nombre del hechizo o rol
                count = count + 1
            end
        end
        
        -- Eliminar de RaidDominionDB
        for _, key in ipairs(toRemove) do
            RaidDominionDB.assignments[category][key] = nil
        end
        
    -- Eliminar también de RaidDominionSelections (Cache en memoria)
    if RaidDominionSelections and RaidDominionSelections[category] then
        if category == "roles" then
            -- Para roles, la estructura es Selections.roles[roleName] = {player1, player2, ...}
            for roleName, players in pairs(RaidDominionSelections.roles) do
                if type(players) == "table" then
                    for i = #players, 1, -1 do
                        if ComparePlayerNames(players[i], playerName) then
                            table.remove(players, i)
                        end
                    end
                end
            end
        elseif category == "buffs" or category == "auras" then
            -- Para buffs/auras, la estructura es Selections[category][spellId] = {{target="Name", ...}, ...}
            for spellId, targets in pairs(RaidDominionSelections[category]) do
                if type(targets) == "table" then
                    for i = #targets, 1, -1 do
                        if targets[i] and ComparePlayerNames(targets[i].target, playerName) then
                            table.remove(targets, i)
                        end
                    end
                end
            end
        elseif category == "abilities" then
            -- Para habilidades, la estructura es Selections.abilities[abilityId] = {player1, player2, ...}
            for abilityId, players in pairs(RaidDominionSelections.abilities) do
                if type(players) == "table" then
                    for i = #players, 1, -1 do
                        if ComparePlayerNames(players[i], playerName) then
                            table.remove(players, i)
                        end
                    end
                end
            end
        end
    end
        
        return count, names
    end
    
    -- Clean assignments from all categories
    local results = {
        roles = 0,
        buffs = 0,
        auras = 0,
        abilities = 0,
        totalRemoved = 0,
        names = {
            roles = {},
            buffs = {},
            auras = {},
            abilities = {}
        }
    }
    
    -- Cleaning role assignments
    results.roles, results.names.roles = cleanAssignments("roles")
    -- Cleaning buff assignments
    results.buffs, results.names.buffs = cleanAssignments("buffs")
    -- Cleaning aura assignments
    results.auras, results.names.auras = cleanAssignments("auras")
    -- Cleaning ability assignments
    results.abilities, results.names.abilities = cleanAssignments("abilities")
    
    results.totalRemoved = results.roles + results.buffs + results.auras + results.abilities
    
    -- Reset selection cache as well
    local selectionsReset = false
    if self.ResetPlayerRoles then selectionsReset = self:ResetPlayerRoles(playerName) or selectionsReset end
    if self.ResetPlayerBuffs then selectionsReset = self:ResetPlayerBuffs(playerName) or selectionsReset end
    if self.ResetPlayerAbilities then selectionsReset = self:ResetPlayerAbilities(playerName) or selectionsReset end
    if self.ResetPlayerAuras then selectionsReset = self:ResetPlayerAuras(playerName) or selectionsReset end
    
    -- Assignments cleanup complete
    
    -- Notify the UI to update
    if RD.events and RD.events.Publish then
        -- Publishing assignments update
        if results.totalRemoved > 0 or selectionsReset then
            RD.events:Publish("ASSIGNMENTS_UPDATED")
        end
        
        -- Also trigger a full UI update
        if RD.UI and RD.UI.DynamicMenus and RD.UI.DynamicMenus.UpdateAllMenus then
            RD.UI.DynamicMenus:UpdateAllMenus()
        end
    end
    
    return results.totalRemoved > 0, results
end

--[[
    Obtiene el tipo de grupo actual
    @param self Referencia al módulo
    @return number Tipo de grupo (ver GROUP_TYPES)
]]
function groupUtils:GetGroupType()
    return groupCache.groupType
end

--[[
    Obtiene una tabla con los miembros del grupo
    @param self Referencia al módulo
    @param includePets Incluir mascotas en el resultado
    @return table Tabla con información de los miembros
]]
function groupUtils:GetGroupMembers(includePets)
    local members = {}
    local numMembers = 0
    local isRaid = IsInRaid()
    
    if isRaid then
        numMembers = GetNumRaidMembers() or 0
        for i = 1, numMembers do
            local name, _, _, _, _, _, _, _, _, _, _ = GetRaidRosterInfo(i)
            if name then
                table.insert(members, {
                    name = name,
                    unit = "raid"..i,
                    isPlayer = UnitIsPlayer("raid"..i)
                })
            end
        end
    else
        -- Jugador principal
        local playerName = UnitName("player")
        if playerName then
            table.insert(members, {
                name = playerName,
                unit = "player",
                isPlayer = true
            })
            -- Processing player
        end
        
        -- Miembros del grupo
        numMembers = GetNumPartyMembers() or 0
        for i = 1, numMembers do
            local unit = "party"..i
            local name = UnitName(unit)
            if name then
                table.insert(members, {
                    name = name,
                    unit = unit,
                    isPlayer = UnitIsPlayer(unit)
                })
                -- Group member processed
            end
        end
    end
    
    return members
end

--[[
    Verifica si el jugador está en una banda
    @param self Referencia al módulo
    @return boolean Verdadero si está en una banda
]]
function groupUtils:IsInRaid()
    return IsInRaid()
end

--[[
    Verifica si el jugador está en un grupo
    @param self Referencia al módulo
    @return boolean Verdadero si está en un grupo
]]
function groupUtils:IsInParty()
    return IsInGroup()
end



--[[
    Obtiene el nombre completo del jugador (nombre-reino)
    @param unit Unidad del juego (ej: "player", "party1", "raid1")
    @return string Nombre completo o nil si no es un jugador
]]
function groupUtils:GetFullPlayerName_Old(unit)
    if not unit then return nil end
    
    local name, realm = UnitName(unit)
    if not name then return nil end
    
    if not realm or realm == "" then
        realm = GetRealmName()
    end
    
    return name.."-"..realm
end

--[[
    Reinicia los roles asignados a un jugador que ha abandonado el grupo
    @param playerName Nombre del jugador
    @return boolean True si se reiniciaron roles
]]
function groupUtils:ResetPlayerRoles(playerName)
    if not playerName then return end
    
    -- Buscar y limpiar asignaciones de roles para este jugador
    local found = false
    for role, assignments in pairs(RaidDominionSelections.roles or {}) do
        for i = #assignments, 1, -1 do
            if ComparePlayerNames(assignments[i], playerName) then
                table.remove(assignments, i)
                found = true
            end
        end
    end
    
    -- Notificar a la interfaz para que actualice los botones
    if found then
        events:Publish("ROLES_UPDATED")
    end
    
    return found
end

--[[
    Reinicia los buffs asignados a un jugador que ha abandonado el grupo
    @param playerName Nombre del jugador
]]
function groupUtils:ResetPlayerBuffs(playerName)
    if not playerName then return end
    
    -- Buscar y limpiar asignaciones de buffs para este jugador
    local found = false
    for buffId, assignments in pairs(RaidDominionSelections.buffs or {}) do
        for i = #assignments, 1, -1 do
            if assignments[i] and ComparePlayerNames(assignments[i].target, playerName) then
                table.remove(assignments, i)
                found = true
            end
        end
    end
    
    -- Notificar a la interfaz para que actualice los botones
    if found then
        events:Publish("BUFFS_UPDATED")
    end
    
    return found
end

--[[
    Reinicia las habilidades asignadas a un jugador que ha abandonado el grupo
    @param playerName Nombre del jugador
    @return boolean True si se reiniciaron habilidades
]]
function groupUtils:ResetPlayerAbilities(playerName)
    if not playerName then return end
    
    local found = false
    for abilityId, assignments in pairs(RaidDominionSelections.abilities or {}) do
        for i = #assignments, 1, -1 do
            if ComparePlayerNames(assignments[i], playerName) then
                table.remove(assignments, i)
                found = true
            end
        end
    end
    
    if found then
        events:Publish("ABILITIES_UPDATED")
    end
    
    return found
end

--[[
    Reinicia las auras asignadas a un jugador que ha abandonado el grupo
    @param playerName Nombre del jugador
    @return boolean True si se reiniciaron auras
]]
function groupUtils:ResetPlayerAuras(playerName)
    if not playerName then return end
    
    local found = false
    for auraId, assignments in pairs(RaidDominionSelections.auras or {}) do
        for i = #assignments, 1, -1 do
            if assignments[i] and ComparePlayerNames(assignments[i].target, playerName) then
                table.remove(assignments, i)
                found = true
            end
        end
    end
    
    if found then
        events:Publish("AURAS_UPDATED")
    end
    
    return found
end

--[[
    Maneja eventos de cambio de grupo
    @param self Referencia al módulo
    @param event Nombre del evento
    @param ... Argumentos del evento
]]
function groupUtils:OnGroupEvent(event, ...)
    
    -- Manejar eventos específicos
    if event == "GROUP_ROSTER_UPDATE" or 
       event == "RAID_ROSTER_UPDATE" or 
       event == "PARTY_LEADER_CHANGED" or
       event == "PARTY_MEMBERS_CHANGED" or
       event == "GROUP_LEFT" or
       event == "GROUP_DISBANDED" then
        
    end
end

--[[
    Handles group disband event by cleaning up all group member assignments
]]
function groupUtils:HandleGroupDisband()
    -- Make a copy of current members before clearing
    local membersToClean = {}
    for name, _ in pairs(currentGroupMembers) do
        table.insert(membersToClean, name)
    end
    
    -- Clear current group members
    currentGroupMembers = {}
    
    -- Reset assignments for all members
    for _, playerName in ipairs(membersToClean) do
        self:ResetPlayerRoles(playerName)
        self:ResetPlayerBuffs(playerName)
        self:ResetPlayerAbilities(playerName)
        self:ResetPlayerAuras(playerName)
    end
    
    -- Force UI update
    events:Publish("GROUP_UPDATED", {})
    
    if DEFAULT_CHAT_FRAME then
        -- Group disbanded message removed
    end
end

-- Variable para evitar inicialización múltiple
local isInitialized = false

-- Estado de inicialización
local initStarted = false
local eventFrame = nil

-- Función para inicializar el módulo
function groupUtils:Initialize()
    if self.initialized then return true end
    
    -- Inicializar tablas si no existen
    RaidDominionSelections = RaidDominionSelections or {}
    RaidDominionSelections.roles = RaidDominionSelections.roles or {}
    RaidDominionSelections.buffs = RaidDominionSelections.buffs or {}
    RaidDominionSelections.abilities = RaidDominionSelections.abilities or {}
    RaidDominionSelections.auras = RaidDominionSelections.auras or {}
    
    -- Crear el frame de eventos para el grupo si no existe
    if not eventFrame then
        eventFrame = CreateFrame("Frame")
        eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
        eventFrame:RegisterEvent("RAID_ROSTER_UPDATE")
        eventFrame:RegisterEvent("PARTY_MEMBERS_CHANGED")
        eventFrame:RegisterEvent("PARTY_LEADER_CHANGED")
        eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        
        eventFrame:SetScript("OnEvent", function(f, event, ...)
            onGroupEvent(f, event, ...)
        end)
        RD_Debug("Frame de eventos de grupo registrado.")
    end

    -- Inicializar el estado inicial del grupo DESPUÉS de registrar eventos
    -- pero forzando una actualización inmediata de previousGroupMembers
    self:UpdateGroupState()
    
    -- Marcar como inicializado
    self.initialized = true
    
    return true
end

-- Inicialización cuando el addon se carga
local function OnAddonLoaded()
    -- Inicializar el módulo
    local initSuccess, err = pcall(function()
        return groupUtils:Initialize()
    end)
    
    if not initSuccess then
        RD_Debug("|cffff0000Error al inicializar groupUtils:|r %s", tostring(err))
        return
    end
    
    RD_Debug("Módulo de grupo inicializado correctamente.")
end

-- Registrar el evento de carga del addon
local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, event, addon)
    if addon == addonName then
        OnAddonLoaded()
        self:UnregisterEvent("ADDON_LOADED")
    end
end)

-- Registrar utilidades
RaidDominion.utils.group = groupUtils

return groupUtils






