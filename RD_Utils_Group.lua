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

-- Variables locales
local playerAssignments = {}
local previousGroupMembers = {}
local currentGroupMembers = {}
local playerClasses = {} -- Table to track player classes
local groupUtils = {}
RD.utils.group = groupUtils

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

-- Variables de estado del grupo
local inRaid = false
local inParty = false
local numGroupMembers = 1
local isGroupLeader = false

-- Variables locales
local constants = RD.constants
local events = RD.events


-- Sobrescribir las funciones de grupo con versiones personalizadas
IsInRaid = function() return inRaid end
IsInGroup = function() return inParty or inRaid end
GetNumGroupMembers = function() return numGroupMembers end
UnitIsGroupLeader = function(unit) return unit == "player" and not inRaid and not inParty end
UnitIsGroupAssistant = function() return false end

-- Detectar jugadores que abandonaron el grupo
local function DetectLeftPlayers()
    local currentMembers = {}
    local numMembers = GetNumGroupMembers()
    
    -- Obtener lista actual de miembros
    if numMembers > 0 then
        for i = 1, numMembers do
            local unit = (IsInRaid() and "raid" or "party") .. i
            local name = GetUnitName(unit, true)
            if name and name ~= "" then
                currentMembers[name] = true
            end
        end
    end
    
    -- Añadir al jugador actual
    local playerName = GetUnitName("player", true)
    if playerName and playerName ~= "" then
        currentMembers[playerName] = true
    end
    
    -- Verificar jugadores que ya no están en el grupo
    local jugadoresQueAbandonaron = {}
    for nombre, _ in pairs(previousGroupMembers) do
        if not currentMembers[nombre] then
            table.insert(jugadoresQueAbandonaron, nombre)
        end
    end
    
    -- Procesar jugadores que abandonaron
    for _, nombre in ipairs(jugadoresQueAbandonaron) do
        groupUtils:ResetPlayerAssignments(nombre)
        if RD.events and RD.events.Publish then
            RD.events:Publish("PLAYER_LEFT_GROUP", {playerName = nombre})
        end
    end
    
    -- Forzar actualización de la interfaz si hay jugadores que abandonaron
    if #jugadoresQueAbandonaron > 0 then
        if RD.UI and RD.UI.DynamicMenus and RD.UI.DynamicMenus.UpdateAllMenus then
            RD.UI.DynamicMenus:UpdateAllMenus()
        end
    end
    
    -- Actualizar el registro de miembros anteriores
    previousGroupMembers = {}
    for nombre, _ in pairs(currentMembers) do
        previousGroupMembers[nombre] = true
    end
end

-- Función para obtener información del grupo de forma segura
local function GetGroupInfo()
    local inRaidStatus = false
    local inPartyStatus = false
    local numMembers = 1
    local isLeader = false
    
    -- Usar versiones seguras de las funciones
    local success, raidResult = pcall(IsInRaid)
    if success and raidResult ~= nil then
        inRaidStatus = raidResult == true
    end
    
    local success, groupResult = pcall(IsInGroup)
    if success and groupResult ~= nil then
        inPartyStatus = groupResult == true and not inRaidStatus
    end
    
    -- Obtener número de miembros del grupo
    local success, count = pcall(GetNumGroupMembers)
    if success and type(count) == "number" then
        numMembers = count > 0 and count or 1
    end
    
    -- Verificar liderazgo
    local success, leader = pcall(UnitIsGroupLeader, "player")
    if success and leader ~= nil then
        isLeader = leader == true
    else
        -- Si no podemos verificar, asumir que es líder si está solo
        isLeader = numMembers == 1
    end
    
    return inRaidStatus, inPartyStatus, numMembers, isLeader
end

-- Función para manejar eventos de grupo
local function onGroupEvent(self, event, ...)
    if event == "GROUP_ROSTER_UPDATE" or 
       event == "PARTY_MEMBERS_CHANGED" or 
       event == "RAID_ROSTER_UPDATE" or
       event == "PARTY_LEADER_CHANGED" or
       event == "GROUP_LEFT" or
       event == "GROUP_DISBANDED" or
       event == "PLAYER_ENTERING_WORLD" then
        
        DetectLeftPlayers()
        
        if self.UpdateGroupState then
            self:UpdateGroupState()
        end
        
        if RD.UI and RD.UI.DynamicMenus and RD.UI.DynamicMenus.UpdateAllMenus then
            RD.UI.DynamicMenus:UpdateAllMenus()
        end
        
        if self.updateTimer then
            self.updateTimer:Cancel()
            self.updateTimer = nil
        end
        
        -- Configurar nuevo temporizador
        self.updateTimer = 0
        self:SetScript("OnUpdate", function(frame, elapsed)
            frame.updateTimer = frame.updateTimer + elapsed
            if frame.updateTimer >= 0.5 then  -- Esperar 0.5 segundos antes de actualizar
                frame.updateTimer = nil
                frame:SetScript("OnUpdate", nil)
                
                -- Actualizar la caché del grupo
                if groupUtils and groupUtils.UpdateGroupCache then
                    groupUtils:UpdateGroupCache(true)
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
                
                -- Listar miembros actuales del grupo desde previousGroupMembers
                local hasMembers = false
                
                -- Primero verificar si previousGroupMembers es una tabla válida
                if type(previousGroupMembers) ~= "table" then
                    return
                end
                
                -- Verificar si es una tabla de miembros o una tabla de banderas
                local isFlagTable = true
                for _, v in pairs(previousGroupMembers) do
                    if type(v) == "table" then
                        isFlagTable = false
                        break
                    end
                end
                
                if isFlagTable then
                    -- Es una tabla de banderas (antiguo formato)
                    for name, _ in pairs(previousGroupMembers) do
                        hasMembers = true
                    end
                else
                    -- Es una tabla de miembros (nuevo formato)
                    for _, member in pairs(previousGroupMembers) do
                        if type(member) == "table" and member.name then
                            -- Obtener roles asignados usando roleManager
                            local roleText = "sin rol"
                            if RD.roleManager then
                                local role = RD.roleManager:GetRole(member.unit or member.name)
                                if role then
                                    roleText = role
                                end
                            end
                            
                            hasMembers = true
                        end
                    end
                end
                
            end
        end)
    end
end

-- Función para obtener información del grupo de forma segura
local function GetGroupInfo()
    local inRaidStatus = false
    local inPartyStatus = false
    local numMembers = 1
    local isLeader = false
    
    -- Usar versiones seguras de las funciones
    local success, raidResult = pcall(IsInRaid)
    if success and raidResult ~= nil then
        inRaidStatus = raidResult == true
    end
    
    local success, groupResult = pcall(IsInGroup)
    if success and groupResult ~= nil then
        inPartyStatus = groupResult == true and not inRaidStatus
    end
    
    -- Obtener número de miembros del grupo
    local success, count = pcall(GetNumGroupMembers)
    if success and type(count) == "number" then
        numMembers = count > 0 and count or 1
    end
    
    -- Verificar liderazgo
    local success, leader = pcall(UnitIsGroupLeader, "player")
    if success and leader ~= nil then
        isLeader = leader == true
    else
        -- Si no podemos verificar, asumir que es líder si está solo
        isLeader = numMembers == 1
    end
    
    return inRaidStatus, inPartyStatus, numMembers, isLeader
end

-- Función para actualizar el estado del grupo
local function UpdateGroupState(self)
    -- Obtener número de miembros en grupo y banda
    local numParty = GetNumPartyMembers()
    local numRaid = GetNumRaidMembers()
    
    -- Determinar el estado actual
    inRaid = numRaid > 0
    inParty = not inRaid and numParty > 0
    
    -- Calcular el número total de miembros
    if inRaid then
        numGroupMembers = numRaid
    elseif inParty then
        numGroupMembers = numParty + 1  -- +1 para incluir al jugador
    else
        numGroupMembers = 1  -- Solo el jugador
    end
    
    -- Verificar si somos el líder
    isGroupLeader = IsRaidLeader() or IsPartyLeader() or (numGroupMembers == 1)
    
    -- Crear una nueva tabla para los miembros del grupo
    local newGroupMembers = {}
    
    -- Obtener información del jugador
    local playerName = GetUnitName("player", true)
    local _, playerClass = UnitClass("player")
    
    -- Incluir al jugador con su clase
    if playerName and playerName ~= "" then
        newGroupMembers[playerName] = {
            name = playerName,
            class = playerClass,
            isSelf = true,
            role = "NONE",  -- Se actualizará más adelante
            unit = "player"
        }
    end
    
    -- Si estamos en grupo/banda, agregar a los demás miembros
    if numGroupMembers > 1 then
        local unitPrefix = inRaid and "raid" or "party"
        local maxMembers = inRaid and numRaid or numParty
        
        for i = 1, maxMembers do
            local unit = unitPrefix .. i
            if UnitExists(unit) then
                local name = GetUnitName(unit, true)
                local _, class = UnitClass(unit)
                if name and name ~= "" and name ~= playerName then
                    newGroupMembers[name] = {
                        name = name,
                        class = class,
                        isSelf = false,
                        role = "NONE",  -- Se actualizará más adelante
                        unit = unit
                    }
                    -- Group member information
                end
            end
        end
    end
    
    -- Actualizar la tabla de miembros del grupo
    previousGroupMembers = newGroupMembers
    
    -- Listar miembros con sus clases y roles
    for name, data in pairs(previousGroupMembers) do
        local roleText = data.role ~= "NONE" and (" (%s)"):format(data.role) or " (sin rol)"
    end
    
    -- Notificar a otros módulos sobre la actualización del grupo
    if RD.events and RD.events.Trigger then
        RD.events:Trigger("GROUP_ROSTER_UPDATE", {
            inRaid = inRaid,
            inParty = inParty,
            numMembers = numGroupMembers,
            isLeader = isGroupLeader,
            members = previousGroupMembers
        })
    end
end

-- Función para inicializar el módulo de grupo
local function InitializeGroupModule()
    -- Initialize group module
    
    -- Crear frame para eventos del grupo
    local eventFrame = CreateFrame("Frame")
    
    -- Añadir método UpdateGroupState al frame
    eventFrame.UpdateGroupState = UpdateGroupState
    
    -- Configurar el manejador de eventos
    eventFrame:SetScript("OnEvent", function(self, event, ...)
        -- Manejar errores para evitar que fallen otros addons
        local success, err = pcall(onGroupEvent, self, event, ...)
        if not success then
        end
    end)
    
    -- Lista de eventos que queremos registrar
    local eventsToRegister = {
        "GROUP_ROSTER_UPDATE",
        "PARTY_LEADER_CHANGED",
        "RAID_ROSTER_UPDATE",
        "PLAYER_ENTERING_WORLD",
        "PARTY_MEMBERS_CHANGED",
        "GROUP_LEFT",
        "GROUP_DISBANDED"
    }
    
    -- Registrar eventos
    for _, event in ipairs(eventsToRegister) do
        local success, err = pcall(function() 
            eventFrame:RegisterEvent(event)
        end)
        
        if not success then
        end
    end
    
    -- Forzar una actualización inicial del estado del grupo
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    
    return eventFrame
end

-- Inicializar el módulo de grupo
local eventFrame = InitializeGroupModule()

-- Inicializar el estado del grupo
if eventFrame and eventFrame.UpdateGroupState then
    eventFrame:UpdateGroupState(eventFrame)
else
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
    -- Dividir el nombre completo en nombre base y reino
    local baseName = string.match(fullName, "^([^%-]+)")
    return baseName or fullName
end

-- Función para depuración de eventos


-- State variables
local currentGroupMembers = {}
local lastGroupMembers = {}
local lastGroupUpdate = 0
local isProcessing = false
local isInitialized = false

-- Función para limpiar asignaciones de jugadores que ya no están en el grupo
local function CleanupLeftPlayers()
    if not isInitialized then return end
    
    -- Obtener jugadores actuales
    local currentMembers = {}
    for name in pairs(currentGroupMembers) do
        currentMembers[name] = true
    end
    
    -- Verificar jugadores que ya no están
    for name in pairs(lastGroupMembers) do
        if not currentMembers[name] then
            -- Limpiar roles y buffs del jugador que se fue
            groupUtils:ResetPlayerRoles(name)
            groupUtils:ResetPlayerBuffs(name)
        end
    end
    
    -- Actualizar la última lista conocida
    lastGroupMembers = {}
    for name in pairs(currentGroupMembers) do
        lastGroupMembers[name] = true
    end
end

-- Tipos de grupo
local GROUP_TYPES = constants.GROUP_TYPES or {
    NONE = 0,
    PARTY = 1,
    RAID = 2,
    BATTLEGROUND = 3
}

-- Función interna para obtener información del grupo
local function getGroupInfo()
    -- Si la API no está disponible, devolver valores por defecto
    if not IsGroupAPIAvailable() then
        return false, false, "SOLO", 1
    end
    
    -- Usar pcall para capturar cualquier error en las llamadas a la API
    local success, inRaid, inParty, groupType, numMembers = pcall(function()
        local inRaid = SafeIsInRaid()
        local inParty = SafeIsInGroup() and not inRaid
        local groupType = inRaid and "RAID" or (inParty and "PARTY" or "SOLO")
        local numMembers = inRaid and (SafeGetNumGroupMembers() or 0) or 
                          (inParty and (SafeGetNumGroupMembers() or 0) or 1)
        
        return inRaid, inParty, groupType, numMembers
    end)
    
    -- Si hubo un error, devolver valores por defecto
    if not success then
        return false, false, "SOLO", 1
    end
    
    return inRaid, inParty, groupType, numMembers
end

-- Función pública para obtener información del grupo
function groupUtils:GetGroupInfo()
    return getGroupInfo()
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
    local inRaid = IsInRaidCompatible()
    local inGroup = inRaid or IsInGroupCompatible()
    
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
            
            -- Send system message when player leaves
            SendSystemMessage(string.format("RaidDominion: %s (%s) ha abandonado el grupo.", baseName or playerName, playerClass))
            
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
            
            -- Send system message with reset information
            if rolesReset or buffsReset or abilitiesReset or aurasReset then
                anyChanges = true
                local resetMessages = {}
                if rolesReset then table.insert(resetMessages, "roles") end
                if buffsReset then table.insert(resetMessages, "buffs") end
                if abilitiesReset then table.insert(resetMessages, "habilidades") end
                if aurasReset then table.insert(resetMessages, "auras") end
                
                if #resetMessages > 0 then
                    SendSystemMessage(string.format("RaidDominion: Asignaciones reiniciadas para %s: %s", 
                        baseName or playerName, table.concat(resetMessages, ", ")))
                end
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
    playerName = playerName:gsub("%-", "")
    
    -- Ensure RaidDominionDB exists
    if not RaidDominionDB then 
        return 
    end
    
    -- Initialize assignments if they don't exist
    RaidDominionDB.assignments = RaidDominionDB.assignments or {}
    
    -- Function to clean assignments from a category
    local function cleanAssignments(category)
        if not RaidDominionDB.assignments[category] then 
            return 0 
        end
        
        local count = 0
        local toRemove = {}
        
        -- Find all assignments for this player
        for key, value in pairs(RaidDominionDB.assignments[category]) do
            local assignedTo = value
            if type(value) == "table" then
                assignedTo = value.target or value.name or ""
            end
            
            -- Clean the stored player name
            local cleanName = tostring(assignedTo):gsub("%-", "")
            if cleanName == playerName then
                table.insert(toRemove, key)
                count = count + 1
            end
        end
        
        -- Remove found assignments
        for _, key in ipairs(toRemove) do
            RaidDominionDB.assignments[category][key] = nil
            -- Assignment removed
        end
        
        return count
    end
    
    -- Clean assignments from all categories
    local totalRemoved = 0
    -- Cleaning role assignments
    totalRemoved = totalRemoved + cleanAssignments("roles")
    -- Cleaning buff assignments
    totalRemoved = totalRemoved + cleanAssignments("buffs")
    -- Cleaning aura assignments
    totalRemoved = totalRemoved + cleanAssignments("auras")
    -- Cleaning ability assignments
    totalRemoved = totalRemoved + cleanAssignments("abilities")
    
    -- Assignments cleanup complete
    
    -- Notify the UI to update
    if RD.events and RD.events.Publish then
        -- Publishing assignments update
        RD.events:Publish("ASSIGNMENTS_UPDATED")
        
        -- Also trigger a full UI update
        if RD.UI and RD.UI.DynamicMenus and RD.UI.DynamicMenus.UpdateAllMenus then
            RD.UI.DynamicMenus:UpdateAllMenus()
        end
    end
    
    return totalRemoved > 0
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
    local isRaid = IsInRaidCompatible()
    
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
function groupUtils:GetFullPlayerName(unit)
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
            if assignments[i] == GetBasePlayerName(playerName) then
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
            if assignments[i].target == GetBasePlayerName(playerName) then
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
            if assignments[i] == GetBasePlayerName(playerName) then
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
            if assignments[i].target == GetBasePlayerName(playerName) then
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
    
    -- Marcar como inicializado
    self.initialized = true
    
    return true
end

-- Inicialización cuando el addon se carga
local function OnAddonLoaded()
    -- Verificar la API primero
    if not IsGroupAPIAvailable() then
        -- API no disponible, modo individual
    end
    
    -- Inicializar el módulo
    local initSuccess, err = pcall(function()
        return groupUtils:Initialize()
    end)
    
    if not initSuccess then
        return
    end
    
    -- Module ready message removed
end

-- Registrar el evento de carga del addon
local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, event, addon)
    if addon == "RaidDominion2" then
        OnAddonLoaded()
        self:UnregisterEvent("ADDON_LOADED")
    end
end)

-- Registrar utilidades
RaidDominion.utils.group = groupUtils

return groupUtils






