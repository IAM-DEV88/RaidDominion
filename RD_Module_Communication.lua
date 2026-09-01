--[[
    RD_Module_Communication.lua
    PROPÓSITO: Comunicación addon-a-addon (SendAddonMessage) para emular del
              addon base la obtención de datos del líder de la banda:
              asignaciones (roles/abilities/buffs/auras) y listas configurables
              (rules / mechanics / bands).
    API PÚBLICA:
        - RD.comm:RequestAssignments()
        - RD.comm:RequestList(listKey)
        - RD.comm:BroadcastAssignments(channel)
        - RD.comm:BroadcastList(listKey, channel)
    EVENTOS: CHAT_MSG_ADDON ("RD_COMM").
    PROTOCOLO:
        REQ_ASSIGN                    -> el líder responde BroadcastAssignments
        REQ_LIST:<key>                -> el líder responde BroadcastList(key)
        DATA_START / DATA_CHUNK:<cat>:<idx>:<total>:<contenido> / DATA_END
]]

local addonName, private = ...
local RD = _G.RaidDominion or {}
_G.RaidDominion = RD

local Comm = {}

local PREFIX = "RD_COMM"
local CHUNK_SIZE = 180          -- bytes por trozo (margen sobre el límite del canal)
local ASSIGNABLE_LISTS = { "roles", "abilities", "buffs", "auras" }

local incoming = {}             -- categoria -> { [idx] = trozo }

local function CleanName(name)
    if RD.UIUtils and RD.UIUtils.CleanName then
        return RD.UIUtils.CleanName(name)
    end
    return string.lower(tostring(name or ""))
end

local function IsLeader()
    return IsRaidLeader() or (GetNumRaidMembers() == 0 and IsPartyLeader())
end

local function DefaultChannel()
    return (GetNumRaidMembers() > 0) and "RAID" or "PARTY"
end

local function SafeSend(msg, channel)
    SendAddonMessage(PREFIX, msg, channel or DefaultChannel())
end

-- Divide un string conservando campos vacíos (strsplit de WoW los descarta)
local function SplitFields(str, sep)
    local out = {}
    local pos = 1
    while true do
        local s, e = string.find(str, sep, pos, true)
        if not s then
            out[#out + 1] = str:sub(pos)
            break
        end
        out[#out + 1] = str:sub(pos, s - 1)
        pos = e + 1
    end
    return out
end

-- Codifica un ítem { title, icon, content } / { name, minGS, schedule, icon }.
-- Se sanean los caracteres de control (incluidos \1/\2 del framing y \n) para no
-- corromper el formato del mensaje, igual que EncodeBand con las notas.
local function Sanitize(text)
    return string.gsub(tostring(text or ""), "[%c]", " ")
end

local function EncodeItem(it)
    return table.concat({
        Sanitize(it.title or it.name),
        Sanitize(it.icon),
        Sanitize(it.content or it.schedule),
    }, "\1")
end

-- Codifica una banda INCLUYENDO su lista de jugadores (para compartir bandas
-- completas vía "Obtener"). Separadores: \1 = campo de banda, \2 = ítem,
-- \3 = campo de jugador, \4 = jugador. Las notas se sanean de caracteres de
-- control para no corromper el formato del mensaje.
local function EncodeBand(band)
    local parts = {
        tostring(band.name or ""),
        tostring(tonumber(band.minGS) or 0),
        tostring(band.schedule or ""),
        tostring(band.icon or ""),
    }
    local players = {}
    for _, p in ipairs(band.players or {}) do
        local notes = tostring(p.notes or "")
        notes = string.gsub(notes, "[%c]", " ")
        players[#players + 1] = table.concat({
            tostring(p.name or ""),
            tostring(p.class or ""),
            tostring(p.role or ""),
            tostring(p.dual or ""),
            tostring(p.sanction or ""),
            tostring(tonumber(p.points) or 0),
            notes,
            tostring(p.leader or ""),
        }, "\3")
    end
    parts[#parts + 1] = table.concat(players, "\4")
    return table.concat(parts, "\1")
end

-- Codifica una tabla de asignaciones { itemName = player }
local function EncodeAssignments(tbl)
    local out = {}
    for k, v in pairs(tbl) do
        out[#out + 1] = tostring(k) .. "\1" .. tostring(v)
    end
    return table.concat(out, "\2")
end

-- Envía DATA_START + trozos + DATA_END para una o varias categorías
function Comm:SendChunks(chunks, channel)
    SafeSend("DATA_START", channel)
    for _, ch in ipairs(chunks) do
        local total = math.ceil(#ch.content / CHUNK_SIZE)
        for i = 1, total do
            local sub = ch.content:sub((i - 1) * CHUNK_SIZE + 1, i * CHUNK_SIZE)
            SafeSend(string.format("DATA_CHUNK:%s:%d:%d:%s", ch.category, i, total, sub), channel)
        end
    end
    SafeSend("DATA_END", channel)
end

-- El líder envía las asignaciones de roles/abilities/buffs/auras
function Comm:BroadcastAssignments(channel)
    local chunks = {}
    for _, key in ipairs(ASSIGNABLE_LISTS) do
        local assign = RD.config:Get("assignments." .. key, {})
        if type(assign) == "table" and next(assign) then
            chunks[#chunks + 1] = { category = "assign." .. key, content = EncodeAssignments(assign) }
        end
    end
    if #chunks > 0 then
        self:SendChunks(chunks, channel)
    end
end

-- El líder envía una lista configurable (rules / mechanics / bands)
function Comm:BroadcastList(listKey, channel)
    if not listKey then return end
    local list = RD.config:Get(listKey, {})
    if type(list) ~= "table" or #list == 0 then return end
    local items = {}
    if listKey == "bands" then
        for _, b in ipairs(list) do
            items[#items + 1] = EncodeBand(b)
        end
    else
        for _, it in ipairs(list) do
            items[#items + 1] = EncodeItem(it)
        end
    end
    self:SendChunks({ { category = listKey, content = table.concat(items, "\2") } }, channel)
end

-- ============ Solicitudes (seguidor) ============

local function InGroup()
    return GetNumRaidMembers() > 0 or GetNumPartyMembers() > 0
end

-- Solicita al líder las asignaciones (roles/abilities/buffs/auras)
function Comm:RequestAssignments()
    if not InGroup() then return false end
    if IsLeader() then return false end   -- el líder ya tiene sus datos
    SafeSend("REQ_ASSIGN")
    return true
end

-- Solicita al líder una lista configurable (rules / mechanics / bands)
function Comm:RequestList(listKey)
    if not listKey then return false end
    if not InGroup() then return false end
    if IsLeader() then return false end
    SafeSend("REQ_LIST:" .. listKey)
    return true
end

-- ============ Recepción ============

function Comm:HandleIncoming(message, sender)
    if not message or message == "" then return end
    if message == "REQ_ASSIGN" then
        if IsLeader() then self:BroadcastAssignments() end
    elseif message:match("^REQ_LIST:") then
        local key = message:match("^REQ_LIST:(.+)$")
        if IsLeader() then self:BroadcastList(key) end
    elseif message == "DATA_START" then
        incoming = {}
    elseif message == "DATA_END" then
        self:ProcessIncoming()
    elseif message:match("^DATA_CHUNK:") then
        local category, idx, total, content = message:match("^DATA_CHUNK:([^:]+):(%d+):(%d+):(.+)$")
        if category and idx then
            if not incoming[category] then incoming[category] = {} end
            incoming[category][tonumber(idx)] = content
        end
    end
end

-- Clave de identidad de una banda para el dedup de "Obtener". Las bandas NO son
-- únicas por nombre: dos bandas pueden llamarse igual y distinguirse por GS y
-- horario (p.ej. "Núcleo 25" 5400 Día / "Núcleo 25" 5200 Sábado). Si se deduplica
-- solo por nombre, al obtener se perderían todas menos la primera del mismo
-- nombre. La clave compone los campos escalares de la banda (los jugadores NO
-- forman parte de la identidad: mismo nombre+GS+horario+icono = misma banda).
local function BandKey(name, minGS, schedule, icon)
    return table.concat({
        CleanName(name or ""),
        tostring(tonumber(minGS) or 0),
        tostring(schedule or ""),
        tostring(icon or ""),
    }, "\1")
end

-- Aplica los datos recibidos a la configuración local. Las listas se FUSIONAN de
-- forma NO destructiva: se conservan los elementos locales y se añaden solo los
-- recibidos que no existan (sin duplicados). Nunca se borra nada local.
function Comm:ProcessIncoming()
    local applied = false
    local totalAdded = 0
    for category, chunks in pairs(incoming) do
        local maxIdx = 0
        for i in pairs(chunks) do
            if i > maxIdx then maxIdx = i end
        end
        local content = ""
        for i = 1, maxIdx do
            content = content .. (chunks[i] or "")
        end

        local assignKey = category:match("^assign%.(.+)$")
        if assignKey then
            -- Asignaciones (item -> jugador): se REEMPLAZAN por las del líder, que
            -- es la fuente de verdad (datos de raid transitorios, no configuración
            -- local del seguidor). Solo las LISTAS (roles/rules/etc.) se fusionan
            -- de forma no destructiva.
            local tbl = {}
            for _, pair in ipairs(SplitFields(content, "\2")) do
                local fields = SplitFields(pair, "\1")
                if fields[1] ~= "" then tbl[fields[1]] = fields[2] or "" end
            end
            RD.config:Set("assignments." .. assignKey, tbl)
        elseif category == "roles" or category == "abilities" or category == "buffs" or category == "auras" then
            -- Fusión NO destructiva de listas simples { name, icon }: conserva la
            -- lista local y añade solo los recibidos cuyo nombre no exista.
            local current = RD.config:Get(category, {})
            local list = {}
            local existing = {}
            if type(current) == "table" then
                for _, v in ipairs(current) do
                    local n = v.name or ""
                    if n ~= "" then
                        existing[CleanName(n)] = true
                        list[#list + 1] = v
                    end
                end
            end
            local added = 0
            for _, item in ipairs(SplitFields(content, "\2")) do
                local fields = SplitFields(item, "\1")
                local name = fields[1] or ""
                if name ~= "" and not existing[CleanName(name)] then
                    existing[CleanName(name)] = true
                    list[#list + 1] = { name = name, icon = fields[2] or "" }
                    added = added + 1
                end
            end
            RD.config:Set(category, list)
            totalAdded = totalAdded + added
        elseif category == "rules" or category == "mechanics" then
            -- Fusión NO destructiva por título (conserva los locales, sin duplicados)
            local current = RD.config:Get(category, {})
            local list = {}
            local seen = {}
            if type(current) == "table" then
                for _, v in ipairs(current) do
                    local t = v.title or v.name or ""
                    if t ~= "" then
                        seen[CleanName(t)] = true
                        list[#list + 1] = v
                    end
                end
            end
            local added = 0
            for _, item in ipairs(SplitFields(content, "\2")) do
                local fields = SplitFields(item, "\1")
                local title = fields[1] or ""
                if title ~= "" and not seen[CleanName(title)] then
                    seen[CleanName(title)] = true
                    list[#list + 1] = { title = title, icon = fields[2] or "", content = fields[3] or "" }
                    added = added + 1
                end
            end
            RD.config:Set(category, list)
            totalAdded = totalAdded + added
        elseif category == "bands" then
            local bands = RD.utils and RD.utils.bands
            if bands then
                local existing = {}
                for _, b in ipairs(bands:GetBands()) do
                    existing[BandKey(b.name, b.minGS, b.schedule, b.icon)] = true
                end
                local added = 0
                for _, item in ipairs(SplitFields(content, "\2")) do
                    local fields = SplitFields(item, "\1")
                    local bname = fields[1] or ""
                    -- Dedup por identidad completa (no solo nombre): bandas con el
                    -- mismo nombre pero distinto GS/horario son bandas distintas.
                    local key = bname ~= "" and BandKey(fields[1], fields[2], fields[3], fields[4]) or nil
                    if key and not existing[key] then
                        existing[key] = true
                        -- Lista de jugadores compartida: campo 5 (separadores \4 / \3)
                        local players = {}
                        local playersRaw = fields[5]
                        if playersRaw and playersRaw ~= "" then
                            for _, pstr in ipairs(SplitFields(playersRaw, "\4")) do
                                local pf = SplitFields(pstr, "\3")
                                if pf[1] and pf[1] ~= "" then
                                    local sanction = pf[5] or ""
                                    players[#players + 1] = {
                                        name = pf[1],
                                        class = pf[2] or "",
                                        role = pf[3] or "",
                                        dual = pf[4] or "",
                                        sanction = sanction,
                                        banned = sanction ~= "",
                                        points = tonumber(pf[6]) or 0,
                                        notes = pf[7] or "",
                                        leader = pf[8] or "",
                                    }
                                end
                            end
                        end
                        bands:CreateBand({
                            name = bname,
                            minGS = tonumber(fields[2]) or 0,
                            schedule = fields[3] or "",
                            icon = fields[4] or "Interface\\Icons\\INV_Banner_02",
                            players = players,
                        })
                        added = added + 1
                    end
                end
                totalAdded = totalAdded + added
            end
        end
        applied = true
    end
    incoming = {}

    -- Re-render en vivo de la ventana de config si está visible: sin esto, el
    -- editor del tab activo no mostraría los datos recién obtenidos (ReapplyHeight
    -- solo reajusta alturas). Render() es responsivo en combate.
    if applied then
        local cw = RD.ui and RD.ui.configWindow
        if cw and cw.Render and cw.isShown then
            cw:Render()
        end
        -- Feedback no amenazante: cuántos elementos nuevos se añadieron (nunca se
        -- borran los locales).
        if RD.messageManager and RD.messageManager.SendSystemMessage then
            if totalAdded > 0 then
                RD.messageManager:SendSystemMessage(string.format(
                    "|cff33ff99[RaidDominion]|r Obtener: se añadieron %d elemento(s) nuevo(s), sin duplicados ni pérdidas.", totalAdded))
            else
                RD.messageManager:SendSystemMessage(
                    "|cff33ff99[RaidDominion]|r Obtener: tu lista ya estaba al día (no había elementos nuevos).")
            end
        end
    end
end

-- ============ Evento CHAT_MSG_ADDON ============
-- En 3.3.5a NO existe RegisterAddonMessagePrefix (llegó en Cataclysm): el evento
-- CHAT_MSG_ADDON llega para todos los prefijos y se filtra aquí por "RD_COMM".

local commEvent = CreateFrame("Frame")
commEvent:RegisterEvent("CHAT_MSG_ADDON")
commEvent:SetScript("OnEvent", function(self, event, prefix, message, channel, sender)
    if prefix ~= PREFIX then return end
    if sender == UnitName("player") then return end
    pcall(function()
        Comm:HandleIncoming(message, sender)
    end)
end)

RD.comm = Comm
RD.modules = RD.modules or {}
RD.modules.communication = Comm

return Comm
