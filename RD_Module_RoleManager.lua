--[[
    RD_Module_RoleManager.lua
    PROPÓSITO: Gestiona y hace seguimiento de las asignaciones en la banda.
    DEPENDENCIAS: RD_Events.lua, RD_Constants.lua
    API PÚBLICA: 
        - RaidDominion.roleManager:AssignRole(unit, role)
        - RaidDominion.roleManager:GetRole(unit)
        - RaidDominion.roleManager:GetPlayersByRole(role)
    EVENTOS: 
        - ROLE_UPDATE: Se dispara cuando cambia la asignación de un jugador
        - GROUP_ROSTER_UPDATE: Se dispara cuando cambia la composición del grupo
    INTERACCIONES: 
        - RD_UI_MainFrame: Actualiza la interfaz cuando cambian las asignaciones
        - RD_Module_MessageManager: Envía notificaciones sobre cambios de asignación
]]

local addonName, private = ...
local RD = _G.RaidDominion or {}
_G.RaidDominion = RD

local constants = RD.constants or {}
local events = RD.events or {}

-- Tabla de roles
local roles = {}

-- Módulo de gestión de roles
local roleManager = {}

-- Hacer el módulo accesible globalmente
RD.roleManager = roleManager

--[[
    Inicializa el módulo de gestión de roles
    @param self Referencia al módulo
]]
function roleManager:Initialize()
    if self.initialized then return end
    
    -- Inicializar la tabla de roles si no existe
    if not RaidDominionDB or not RaidDominionDB.assignments then
        RaidDominionDB = RaidDominionDB or {}
        RaidDominionDB.assignments = RaidDominionDB.assignments or {}
        RaidDominionDB.assignments.roles = RaidDominionDB.assignments.roles or {}
    end
    
    -- Registrar eventos si es necesario
    if events and events.Subscribe then
        events:Subscribe("GROUP_ROSTER_UPDATE", function()
            -- Actualizar roles cuando cambia la composición del grupo
            if RD.utils and RD.utils.group and RD.utils.group.UpdateGroupCache then
                RD.utils.group:UpdateGroupCache(true)
            end
        end)
    end
    
    self.initialized = true
    -- Role module initialization complete
end

function roleManager:AssignItem(menuType, key, unitName)
    if not menuType or not key or not unitName then return false end
    menuType = string.lower(menuType)
    key = string.lower(key)
    
    local RD = _G.RaidDominion
    if RD.config and RD.config.Set then
        RD.config:Set("assignments." .. menuType .. "." .. key, unitName)
    end
    
    if events and events.Publish then
        events:Publish("ROLE_UPDATE", menuType, key, unitName)
    end
    return true
end

function roleManager:GetAssignment(menuType, key)
    if not menuType or not key then return nil end
    menuType = string.lower(menuType)
    key = string.lower(key)
    
    local RD = _G.RaidDominion
    if RD.config and RD.config.Get then
        return RD.config:Get("assignments." .. menuType .. "." .. key)
    end
    return nil
end

function roleManager:ResetAssignment(menuType, key)
    if not menuType or not key then return false end
    menuType = string.lower(menuType)
    key = string.lower(key)
    
    local RD = _G.RaidDominion
    if RD.config and RD.config.Set then
        RD.config:Set("assignments." .. menuType .. "." .. key, nil)
    end
    
    if events and events.Publish then
        events:Publish("ROLE_UPDATE", menuType, key, nil)
    end
    return true
end

--[[
    Obtiene todas las asignaciones de un jugador como una tabla
    @param self Referencia al módulo
    @param unit Unidad (ej: "player", "party1", "raid5") o nombre del jugador
    @return table Tabla con todas las asignaciones del jugador o tabla vacía si no tiene asignaciones
--]]
function roleManager:GetRoleTable(unit)
    if not unit then return {} end
    
    -- Obtener el nombre del jugador
    local name = type(unit) == "string" and (UnitName(unit) or unit) or nil
    if not name then return {} end
    
    -- Asegurar que el nombre esté en el formato correcto (sin realm)
    name = name:gsub("%-[^|]+", "")  -- Eliminar el nombre del reino si existe
    
    -- Obtener las asignaciones
    local assignments = RaidDominionDB and RaidDominionDB.assignments
    if not assignments then return {} end
    
    -- Tabla para almacenar todas las asignaciones
    local allRoles = {}
    
    -- Buscar asignaciones de roles
    if assignments.roles then
        for role, assignedTo in pairs(assignments.roles) do
            -- Manejar diferentes formatos de asignación
            local target = assignedTo
            if type(assignedTo) == "table" then
                target = assignedTo.target or assignedTo.name or ""
            end
            
            -- Limpiar el nombre del jugador guardado
            local cleanPlayerName = tostring(target):gsub("%-[^|]+", "")
            if cleanPlayerName == name then
                table.insert(allRoles, role:upper()) -- Convertir a mayúsculas para consistencia
            end
        end
    end
    
    return allRoles
end

--[[
    Obtiene todas las asignaciones de un jugador como una cadena (para compatibilidad)
    @param self Referencia al módulo
    @param unit Unidad (ej: "player", "party1", "raid5") o nombre del jugador
    @return string Cadena con todas las asignaciones del jugador o nil si no tiene asignaciones
--]]
function roleManager:GetRole(unit)
    local roles = self:GetRoleTable(unit)
    if #roles > 0 then
        return table.concat(roles, "; ")
    end
    return nil
end

--[[
    Asigna iconos de banda a tanques y sanadores basado en sus roles
    @return table Reporte de asignaciones {tanks = {}, healers = {}}
]]
function roleManager:AssignRaidIcons()
    local raidMembers = {
        tanks = {},
        healers = {},
    }
    
    local raidMembers = GetNumRaidMembers()
    local partyMembers = GetNumPartyMembers()
    local numberOfPlayers = (raidMembers > 0 and raidMembers) or (partyMembers > 0 and partyMembers + 1) or 1
    local availableIcons = { 2, 3, 4, 5, 6, 7, 8 }
    local iconIndex = 1
    local addonCache = {}
    
    -- Función auxiliar para obtener unidad de raid por nombre
    local function GetRaidUnitByName(name)
        for i = 1, numberOfPlayers do
            local unit = "raid" .. i
            if UnitName(unit) == name then
                return unit
            end
        end
        return nil
    end

    -- Función para verificar si se debe asignar icono
    local function ShouldAssignIcon(roles)
        local iconRoles = { "MAIN TANK", "HEALER 1", "OFF TANK", "HEALER 2", "HEALER 3", "HEALER 4", "HEALER 5" }
        for _, role in ipairs(roles) do
            for _, iconRole in ipairs(iconRoles) do
                if role:upper() == iconRole then
                    return true
                end
            end
        end
        return false
    end

    -- Obtener información de jugadores con roles asignados
    for i = 1, numberOfPlayers do
        local unit = "raid" .. i
        local name = GetUnitName(unit, true)
        if name then
            local roles = {}
            local isTank = false
            local isHealer = false
            
            -- Obtener roles del role manager
            local rolesTable = self:GetRoleTable(name)
            for _, role in ipairs(rolesTable) do
                role = tostring(role):upper()
                if not role:find("DPS") then
                    table.insert(roles, role)
                end
                if role:find("TANK") or role:find("TANQUE") then
                    isTank = true
                elseif role:find("HEAL") or role:find("SANADOR") or role:find("CURADOR") then
                    isHealer = true
                end
            end

            -- Solo procesar si tiene rol de tanque o sanador
            if isTank or isHealer then
                addonCache[name] = {
                    roles = roles,
                    unit = unit,
                    isTank = isTank,
                    isHealer = isHealer
                }
            end
        end
    end

    -- Ordenar jugadores para asignación consistente
    local sortedPlayers = {}
    for name, data in pairs(addonCache) do
        table.insert(sortedPlayers, {name = name, data = data})
    end
    
    -- Ordenar: Tanques primero, luego sanadores
    table.sort(sortedPlayers, function(a, b)
        if a.data.isTank and not b.data.isTank then
            return true
        elseif not a.data.isTank and b.data.isTank then
            return false
        end
        return a.name < b.name
    end)

    -- Asignar iconos
    for _, player in ipairs(sortedPlayers) do
        local playerName = player.name
        local playerData = player.data
        local roles = playerData.roles or {}
        local rolesStr = table.concat(roles, ",")

        local icon = nil
        if ShouldAssignIcon(roles) and iconIndex <= #availableIcons then
            icon = availableIcons[iconIndex]
            iconIndex = iconIndex + 1
        end

        if icon then
            local raidUnit = GetRaidUnitByName(playerName)
            if raidUnit and UnitExists(raidUnit) and not UnitIsDeadOrGhost(raidUnit) then
                SetRaidTarget(raidUnit, icon)
                
                -- Añadir al reporte
                if rolesStr:find("MAIN TANK") then
                    raidMembers.tanks[1] = "{rt" .. icon .. "} MAIN TANK"
                elseif rolesStr:find("OFF TANK") then
                    raidMembers.tanks[2] = "{rt" .. icon .. "} OFF TANK"
                elseif playerData.isHealer then
                    table.insert(raidMembers.healers, "{rt" .. icon .. "}")
                end
            end
        end
    end
    
    return raidMembers
end

-- Inicialización
function roleManager:OnInitialize()
    self:Initialize()
    
    -- Registrar eventos
    events:Subscribe("GROUP_ROSTER_UPDATE", function(...) 
        self:OnGroupEvent("GROUP_ROSTER_UPDATE", ...) 
    end)
    
    events:Subscribe("PLAYER_ROLES_ASSIGNED", function(...) 
        self:UpdateRoles() 
    end)
end

-- Registrar el módulo
if not RaidDominion.modules then
    -- If modules table doesn't exist yet, create it
    RaidDominion.modules = {}
end
RaidDominion.modules.roleManager = roleManager

-- Inicialización retrasada
local function OnInitialize()
    roleManager:OnInitialize()
end

-- Subscribe to PLAYER_LOGIN event
if events and events.Subscribe then
    events:Subscribe("PLAYER_LOGIN", OnInitialize)
else
    -- If events system isn't ready yet, use a frame to wait for it
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_LOGIN")
    f:SetScript("OnEvent", function()
        if RaidDominion.events and RaidDominion.events.Subscribe then
            RaidDominion.events:Subscribe("PLAYER_LOGIN", OnInitialize)
            f:UnregisterAllEvents()
        end
    end)
end

return roleManager
