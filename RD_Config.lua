--[[
    RD_Config.lua
    PROPÓSITO: Persistencia (SavedVariables) y acceso por path a la configuración.
    API PÚBLICA:
        - RD.config:Load(), RD.config:Save(), RD.config:ResetToDefaults()
        - RD.config:Get(key, default), RD.config:Set(key, value)
    EVENTOS: CONFIG_LOADED, CONFIG_CHANGED(key, value), CONFIG_RESET
]]

local addonName, private = ...
local RD = _G.RaidDominion or {}
_G.RaidDominion = RD

local Config = {}

local db          -- Referencia a RaidDominionDB
local DEFAULTS    -- Referencia a RD.constants.DEFAULT_CONFIG
local loaded = false  -- Load() es idempotente (una sola vez por sesión)

-- Copia profunda de una tabla
local function DeepCopy(orig)
    local origType = type(orig)
    if origType ~= "table" then return orig end
    local copy = {}
    for k, v in next, orig, nil do
        copy[DeepCopy(k)] = DeepCopy(v)
    end
    return setmetatable(copy, DeepCopy(getmetatable(orig)))
end

-- Merge profundo: src dentro de dest, preservando valores existentes en dest
local function MergeTable(dest, src)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dest[k]) ~= "table" then dest[k] = {} end
            MergeTable(dest[k], v)
        else
            if dest[k] == nil then
                dest[k] = v
            end
        end
    end
end

-- Limpia/actualiza la DB con las migraciones de dominio (viven en
-- RD_Utils_Migrations.lua para que la capa de persistencia no conozca reglas
-- de negocio): canal legacy, siembra de listas, booleanos 1/0, dedup de
-- reglas, sanciones legacy y asignaciones huérfanas.
local function RunMigrations(db, defaults)
    if RD.utils and RD.utils.migrations and RD.utils.migrations.Run then
        RD.utils.migrations:Run(db, defaults)
    end
end

-- Carga la DB y fusiona con los valores por defecto. Idempotente: las
-- migraciones solo corren una vez por sesión (RD_Init la invoca en ADDON_LOADED
-- y de nuevo en PLAYER_LOGIN; la segunda llamada es un no-op).
function Config:Load()
    if loaded then return end

    DEFAULTS = (RD.constants and RD.constants.DEFAULT_CONFIG) or {}

    if not RaidDominionDB then
        RaidDominionDB = DeepCopy(DEFAULTS)
    else
        MergeTable(RaidDominionDB, DEFAULTS)
        RunMigrations(RaidDominionDB, DEFAULTS)
    end

    db = RaidDominionDB
    loaded = true

    if RD.events and RD.events.Publish then
        RD.events:Publish("CONFIG_LOADED", db)
    end
end

-- Divide una clave por path ("ui.menu.scale") en sus nodos. Robusto y sin
-- depender de strsplit (que en 3.3.5a trata "." como patrón de Lua): el patrón
-- [^.]+ separa por puntos literales. Devuelve una lista de strings.
local function SplitPath(key)
    local parts = {}
    if not key or key == "" then return parts end
    for node in string.gmatch(key, "[^.]+") do
        parts[#parts + 1] = node
    end
    return parts
end

-- Tipo del nodo hoja en DEFAULT_CONFIG para una clave por path. Sirve para
-- normalizar el tipo del valor al leer/escribir (p.ej. booleanos 1/0 legacy).
local function DefaultNodeType(key)
    local path = SplitPath(key)
    local cur = DEFAULTS
    for _, node in ipairs(path) do
        if type(cur) ~= "table" then return nil end
        cur = cur[node]
    end
    return type(cur)
end

-- Obtiene un valor por path ("ui.menu.scale")
function Config:Get(key, default)
    if not db then return default end
    if not key then return db end

    local path = SplitPath(key)
    local current = db
    for _, node in ipairs(path) do
        if type(current) ~= "table" then return default end
        current = current[node]
    end
    if current == nil then return default end
    -- Normaliza legacy 1/0 a booleano nativo cuando el default es booleano
    if type(current) == "number" and DefaultNodeType(key) == "boolean" then
        return current ~= 0
    end
    return current
end

-- Establece un valor por path ("ui.menu.scale")
function Config:Set(key, value)
    if not db or not key then return end

    local path = SplitPath(key)
    local current = db
    for i = 1, #path - 1 do
        local node = path[i]
        if type(current[node]) ~= "table" then
            current[node] = {}
        end
        current = current[node]
    end

    local lastNode = path[#path]

    -- Normaliza el valor cuando la hoja es booleana: guarda SIEMPRE true/false
    -- (nunca 1/0 ni nil) para que el desmarque no borre la clave y MergeTable
    -- no la re-siembre con el default.
    if DefaultNodeType(key) == "boolean" then
        if value == nil then value = false end
        if type(value) == "number" then value = value ~= 0 end
        value = value and true or false
    end

    if current[lastNode] == value then return end

    current[lastNode] = value
    self:Save()

    if RD.events and RD.events.Publish then
        RD.events:Publish("CONFIG_CHANGED", key, value)
    end
end

-- Restaura los valores por defecto
function Config:ResetToDefaults()
    RaidDominionDB = DeepCopy(DEFAULTS)
    db = RaidDominionDB
    if RD.events and RD.events.Publish then
        RD.events:Publish("CONFIG_RESET")
    end
end

-- Guarda (WoW guarda las SavedVariables automáticamente al salir/recargar)
function Config:Save()
end

RD.config = Config
return Config
