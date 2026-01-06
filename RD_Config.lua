--[[
    RD_Config.lua
    PROPÓSITO: Maneja la configuración guardada y las preferencias del usuario.
    DEPENDENCIAS: RD_Constants.lua
    API PÚBLICA: RaidDominion.config:Load(), RaidDominion.config:Get(), RaidDominion.config:Set()
    EVENTOS: CONFIG_LOADED, CONFIG_CHANGED, CONFIG_RESET
    INTERACCIONES: Todos los módulos que necesiten acceder a la configuración
]]

local addonName, private = ...
local RD = _G.RaidDominion
local constants = RD.constants

-- Configuración por defecto
local defaultConfig = {
    general = {
        minimap = {
            hide = false,
            angle = 45,
            radius = 80
        },
        debug = false,
        scale = 1.0,
        locked = false
    },
    modules = {
        messageManager = {
            enabled = true,
            channel = "RAID",
            announceEvents = true
        },
        roleManager = {
            enabled = true,
            autoPromote = false
        }
    },
    ui = {
        showMechanicsMenu = true,
        showGuildMenu = true,
        showMainMenuOnStart = true
    }
}

-- Variables privadas
local config = {}
local db -- Referencia a la tabla global de SavedVariables

--[[
    Copia profunda de una tabla
    @param orig Tabla original
    @return Copia de la tabla
]]
local function DeepCopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[DeepCopy(orig_key)] = DeepCopy(orig_value)
        end
        setmetatable(copy, DeepCopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

--[[
    Fusiona dos tablas recursivamente (src dentro de dest)
    Preserva valores existentes en dest, añade nuevos de src
    @param dest Tabla destino
    @param src Tabla fuente
]]
local function MergeTable(dest, src)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dest[k]) ~= "table" then
                dest[k] = {}
            end
            MergeTable(dest[k], v)
        else
            if dest[k] == nil then
                dest[k] = v
            end
        end
    end
end

--[[
    Inicializa el sistema de configuración (Setup básico)
]]
function config:Initialize()
    -- Placeholder por si se necesita lógica de inicialización previa a la carga
end

--[[
    Carga la configuración guardada y fusiona con los valores por defecto
]]
function config:Load()
    -- Inicializar DB global si no existe
    if not RaidDominionDB then
        RaidDominionDB = DeepCopy(defaultConfig)
    else
        -- Fusionar nuevos valores por defecto en la DB existente
        MergeTable(RaidDominionDB, defaultConfig)
    end
    
    -- Asegurar que la estructura de asignaciones exista y tenga el formato correcto
    RaidDominionDB.assignments = RaidDominionDB.assignments or {}
    
    -- Inicializar sub-tablas necesarias si no existen
    RaidDominionDB.assignments.roles = RaidDominionDB.assignments.roles or {}
    RaidDominionDB.assignments.buffs = RaidDominionDB.assignments.buffs or {}
    RaidDominionDB.assignments.auras = RaidDominionDB.assignments.auras or {}
    RaidDominionDB.assignments.abilities = RaidDominionDB.assignments.abilities or {}

    -- Inicializar DB por personaje si no existe (para uso futuro)
    if not RaidDominionDBPC then
        RaidDominionDBPC = {}
    end

    -- Establecer referencia local
    db = RaidDominionDB

    if RD.events and RD.events.Publish then
        RD.events:Publish("CONFIG_LOADED", db)
    end
end

--[[
    Obtiene un valor de configuración
    @param key Clave de configuración (ej: "general.minimap.hide")
    @param default Valor por defecto si no existe (opcional)
    @return Valor de configuración o valor por defecto
]]
function config:Get(key, default)
    if not db then 
        return default 
    end
    if not key then 
        return db 
    end

    local path = {strsplit(".", key)}
    local current = db

    for _, node in ipairs(path) do
        if type(current) ~= "table" then 
            return default 
        end
        current = current[node]
    end

    -- If the value is nil, return the default
    if current == nil then 
        return default 
    end
    
    -- Convert number (1/0) back to boolean if needed
    if type(current) == "number" and (current == 1 or current == 0) then
        return current == 1
    end
    
    return current
end

--[[
    Establece un valor de configuración
    @param key Clave de configuración (ej: "general.minimap.hide")
    @param value Valor a establecer
]]
function config:Set(key, value)
    if not db then 
        return 
    end

    local path = {strsplit(".", key)}
    local current = db
    
    -- Navegar hasta el penúltimo nodo, creando tablas si es necesario
    for i = 1, #path - 1 do
        local node = path[i]
        if type(current[node]) ~= "table" then
            current[node] = {}
        end
        current = current[node]
    end

    local lastNode = path[#path]
    
    -- Convert boolean values to numbers (1/0) for consistency
    local valueToSet = value
    if value == nil then
        valueToSet = 0
    elseif type(value) == "boolean" then
        valueToSet = value and 1 or 0
    end
    
    -- Only update and notify if the value changes
    if current[lastNode] ~= valueToSet then
        current[lastNode] = valueToSet
        
        -- Save the changes to disk
        self:Save()
        
        if RD.events and RD.events.Publish then
            RD.events:Publish("CONFIG_CHANGED", key, valueToSet)
        end
    end
end

--[[
    Restaura la configuración por defecto
]]
function config:ResetToDefaults()
    RaidDominionDB = DeepCopy(defaultConfig)
    db = RaidDominionDB
    
    if RD.events and RD.events.Publish then
        RD.events:Publish("CONFIG_RESET")
    end
end

--[[
    Guarda la configuración (Sincronización manual si fuera necesaria)
    Nota: WoW guarda automáticamente RaidDominionDB al salir/recargar.
]]
function config:Save()
    -- Ensure all boolean values in the config are saved as numbers
    local function normalizeBooleans(tbl)
        for k, v in pairs(tbl) do
            if type(v) == "table" then
                normalizeBooleans(v)
            elseif type(v) == "boolean" then
                tbl[k] = v and 1 or 0
            end
        end
    end
    
    -- Normalize boolean values before saving
    if RaidDominionDB then
        normalizeBooleans(RaidDominionDB)
    end
end

-- Asignar al namespace global del addon
RD.config = config
