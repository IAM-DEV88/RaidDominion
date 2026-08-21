--[[
    RD_Utils_Migrations.lua
    PROPÓSITO: Migraciones y saneos de la DB de RaidDominion (migraciones de
              dominio que la capa de persistencia (RD_Config) no debe conocer:
              canal legacy, siembra de listas, booleanos 1/0, dedup de reglas,
              sanciones legacy, limpieza de asignaciones huérfanas).
    API PÚBLICA:
        - RD.utils.migrations:Run(db, defaults)  -- aplica todas (idempotentes)
    EVENTOS: Ninguno (lo invoca RD.config:Load antes de publicar CONFIG_LOADED).
]]

local addonName, private = ...
local RD = _G.RaidDominion or {}
_G.RaidDominion = RD

local Migrations = {}

-- Copia profunda (helper central en RD.UIUtils.DeepCopy; RD_Config conserva el
-- suyo local porque se carga antes que RD_UI_Utils).
local DeepCopy = (RD.UIUtils and RD.UIUtils.DeepCopy) or function(orig)
    local origType = type(orig)
    if origType ~= "table" then return orig end
    local copy = {}
    for k, v in next, orig, nil do
        copy[DeepCopy(k)] = DeepCopy(v)
    end
    return setmetatable(copy, DeepCopy(getmetatable(orig)))
end

local LIST_KEYS = { "roles", "buffs", "auras", "abilities", "mechanics", "rules" }

-- Limpia asignaciones huérfanas: claves de "assignments.<lista>" que no
-- coinciden con ningún ítem de la lista actual (restos de versiones/estados
-- previos) se eliminan.
local function CleanAssignments(db)
    local assign = db and db.assignments
    if type(assign) ~= "table" then return end
    local lists = { "roles", "abilities", "buffs", "auras" }
    for _, listKey in ipairs(lists) do
        local tbl = assign[listKey]
        if type(tbl) == "table" then
            local items = db[listKey]
            local valid = {}
            if type(items) == "table" then
                for _, it in ipairs(items) do
                    local name = it.name or it.title
                    if name then valid[name] = true end
                end
            end
            local copy = {}
            for itemName, player in pairs(tbl) do
                if valid[itemName] then
                    copy[itemName] = player
                end
            end
            assign[listKey] = copy
        end
    end
end

-- Aplica todas las migraciones y saneos. Son idempotentes: las de "una sola
-- vez" usan flags en la DB; el dedup de reglas/mecánicas se ejecuta en cada
-- carga porque es barato y distintos caminos pueden re-introducir duplicados.
function Migrations:Run(db, defaults)
    if not db or type(defaults) ~= "table" then return end

    CleanAssignments(db)

    -- Migración (una sola vez): el antiguo default de canal era "SYSTEM";
    -- ahora el default es "DEFAULT" (auto-resolución por contexto, como la base).
    if db.chat and db.chat.channel == "SYSTEM" and not db._channelMigrated then
        db.chat.channel = "DEFAULT"
        db._channelMigrated = true
    end

    -- Sanitiza el canal: si no pertenece al conjunto de la base, se usa
    -- "DEFAULT" para no enviar un tipo de chat desconocido.
    local validChannels = {
        DEFAULT = true, SYSTEM = true, GUILD = true, SAY = true, YELL = true,
        PARTY = true, RAID = true, RAID_WARNING = true, BATTLEGROUND = true,
        CHANNEL = true, INN = true,
    }
    if db.chat and db.chat.channel
        and not validChannels[strtrim(strupper(tostring(db.chat.channel)))] then
        db.chat.channel = "DEFAULT"
    end

    -- Migración de listas configurables: se siembran SOLO una vez (primera
    -- carga, con flag). Así el usuario puede vaciar una lista a propósito sin
    -- que se re-siembre en el siguiente load (reglas duplicadas que reaparecen).
    if defaults.roles and not db._listsSeeded then
        for _, k in ipairs(LIST_KEYS) do
            local v = db[k]
            if type(v) ~= "table" or #v == 0 then
                db[k] = DeepCopy(defaults[k])
            end
        end
        db._listsSeeded = true
    end

    -- Migración (una sola vez): normaliza booleanos guardados como 1/0
    -- (formato legacy de la v2) a booleanos nativos, recorriendo los
    -- default actuales para saber qué hojas son booleanas.
    if not db._booleansNormalized then
        local function NormalizeBooleans(dest, src)
            for k, v in pairs(src) do
                if type(v) == "table" then
                    if type(dest[k]) == "table" then
                        NormalizeBooleans(dest[k], v)
                    end
                elseif type(v) == "boolean" and type(dest[k]) == "number" then
                    dest[k] = (dest[k] ~= 0)
                end
            end
        end
        NormalizeBooleans(db, defaults)
        db._booleansNormalized = true
    end

    -- Deduplicación de listas de contenido (reglas/mecánicas): conserva solo la
    -- primera ocurrencia de cada título; no re-añade reglas borradas.
    for _, listKey in ipairs({ "rules", "mechanics" }) do
        local list = db[listKey]
        if type(list) == "table" then
            local seen = {}
            local unique = {}
            for _, item in ipairs(list) do
                local title = item.title or item.name or ""
                if title == "" or not seen[title] then
                    if title ~= "" then seen[title] = true end
                    unique[#unique + 1] = item
                end
            end
            db[listKey] = unique
        end
    end

    -- Migración (una sola vez): el límite de dados del botín no puede superar
    -- 10 segundos (decisión de diseño del gestor de botín). Sanea configs que
    -- heredaron valores mayores de la antigua pestaña de configuración.
    if not db._lootLimitClamped then
        if type(db.loot) == "table" and db.loot.rollTimeLimit then
            db.loot.rollTimeLimit = math.min(10, math.floor(tonumber(db.loot.rollTimeLimit) or 10))
        end
        db._lootLimitClamped = true
    end

    -- Migración (una sola vez): sanciones de booleano (banned) a causal
    -- (sanction). Los jugadores legacy con banned=true pasan a "baneo".
    if not db._sanctionCausesMigrated then
        local bandsList = db.bands
        if type(bandsList) == "table" then
            for _, band in ipairs(bandsList) do
                for _, p in ipairs(band.players or {}) do
                    if p.banned and (p.sanction == nil or p.sanction == "") then
                        p.sanction = "baneo"
                    end
                end
            end
        end
        db._sanctionCausesMigrated = true
    end
end

RD.utils = RD.utils or {}
RD.utils.migrations = Migrations
return Migrations
