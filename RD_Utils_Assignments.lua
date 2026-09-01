--[[
    RD_Utils_Assignments.lua
    PROPÓSITO: Gestión de asignaciones de los ítems asignables del menú
              (roles, abilities, buffs, auras). Cada asignación guarda qué
              jugador está asignado a un ítem concreto.
              Se almacena en RD.config bajo "assignments.<lista>.<ítem>".
    API PÚBLICA:
        - RD.utils.assignments:Get(listKey, itemName)
        - RD.utils.assignments:Set(listKey, itemName, playerName)
        - RD.utils.assignments:Clear(listKey, itemName)
    EVENTOS: Dispara CONFIG_CHANGED vía RD.config:Set.
]]

local addonName, private = ...
local RD = _G.RaidDominion or {}
_G.RaidDominion = RD

local Assignments = {}

-- Devuelve la tabla de asignaciones de una lista, o el jugador asignado a un
-- ítem concreto (si itemName se indica).
function Assignments:Get(listKey, itemName)
    if not listKey then return nil end
    local tbl = {}
    if RD.config and RD.config.Get then
        tbl = RD.config:Get("assignments." .. listKey, {})
    end
    if type(tbl) ~= "table" then tbl = {} end
    if itemName then
        return tbl[itemName]
    end
    return tbl
end

-- Asigna un jugador a un ítem de una lista. Se escribe la TABLA completa de la
-- lista (no un path "a.b.c" con el nombre del ítem) para que los nombres con
-- "." no se aniden en la DB y queden inaccesibles (ver CleanAssignments).
function Assignments:Set(listKey, itemName, playerName)
    if not listKey or not itemName or not playerName then return end
    local tbl = self:Get(listKey)
    local copy = {}
    for k, v in pairs(tbl) do copy[k] = v end
    copy[itemName] = playerName
    if RD.config and RD.config.Set then
        RD.config:Set("assignments." .. listKey, copy)
    end
end

-- Desasigna un ítem (quita la asignación). Se guarda una copia nueva de la
-- tabla para que RD.config:Set detecte el cambio y publique CONFIG_CHANGED.
function Assignments:Clear(listKey, itemName)
    if not listKey or not itemName then return end
    local tbl = self:Get(listKey)
    local copy = {}
    for k, v in pairs(tbl) do
        if k ~= itemName then
            copy[k] = v
        end
    end
    if RD.config and RD.config.Set then
        RD.config:Set("assignments." .. listKey, copy)
    end
end

-- Listas con asignaciones de jugador (se limpian al salir del grupo)
local ASSIGNABLE_LISTS = { "roles", "abilities", "buffs", "auras" }

-- Normaliza un nombre para comparar asignaciones (sin sufijo de reino, en
-- minúsculas) — igual que CleanName pero sin depender de la UI (fallback local).
local function Normalize(name)
    if RD.UIUtils and RD.UIUtils.CleanName then
        return RD.UIUtils.CleanName(name)
    end
    local clean = string.gsub(tostring(name or ""), "%-.*", "")
    clean = string.gsub(clean, "%s+", "")
    return string.lower(clean)
end

-- Elimina TODAS las asignaciones de un jugador (p.ej. cuando sale del grupo),
-- recorriendo las listas asignables. Devuelve (abandonados, totalQuitado):
-- abandonados es una tabla agrupada por lista con los NOMBRES completos de los
-- ítems desasignados (roles/abilities/buffs/auras) — se reportan TODOS los
-- submenús, no solo roles.
function Assignments:ClearForPlayer(playerName)
    local key = Normalize(playerName)
    if key == "" then return {}, 0 end
    local abandoned = {}
    local removed = 0
    for _, listKey in ipairs(ASSIGNABLE_LISTS) do
        local tbl = RD.config:Get("assignments." .. listKey, {})
        if type(tbl) == "table" then
            local copy = {}
            local changed = false
            for itemName, assigned in pairs(tbl) do
                if Normalize(assigned) == key then
                    changed = true
                    removed = removed + 1
                    abandoned[listKey] = abandoned[listKey] or {}
                    abandoned[listKey][#abandoned[listKey] + 1] = itemName
                else
                    copy[itemName] = assigned
                end
            end
            if changed and RD.config and RD.config.Set then
                RD.config:Set("assignments." .. listKey, copy)
            end
        end
    end
    return abandoned, removed
end

RD.utils = RD.utils or {}
RD.utils.assignments = Assignments
return Assignments
