--[[
    RD_Module_MessageManager.lua
    PROPÓSITO: Envío de mensajes por el canal configurado (chat.channel) con
              troceado automático para mensajes largos (>250 bytes), enviando
              las partes en secuencia (stackeadas), como el addon base.
              Registra RD.messageManager y RD.modules.messageManager.
    API PÚBLICA:
        - RD.messageManager:SendMessage(text, channel)
        - RD.messageManager:SendSequence(parts, delay, channel)
        - RD.messageManager:GetChannel()
        - RD.messageManager:Schedule(delay, callback)
        - RD.messageManager:SendSystemMessage(text)
        - RD.messageManager:SendRaw(text, channel)
    EVENTOS: Ninguno.
]]

local addonName, private = ...
local RD = _G.RaidDominion or {}
_G.RaidDominion = RD

local MessageManager = {}

-- Límite de SendChatMessage en 3.3.5a: 255 caracteres. Usamos 250 caracteres
-- (margen de seguridad). La base troceaba a 255 bytes (partía acentos UTF-8 a
-- la mitad); aquí el troceo es por CARACTERES y no rompe multibyte.
local MAX_CHARS = 250

-- =============================================
-- Cola de tareas programadas (sin C_Timer): frame OnUpdate que procesa por GetTime
-- =============================================

local taskFrame = nil
local tasks = {}

local function EnsureTaskFrame()
    if taskFrame then return taskFrame end
    taskFrame = CreateFrame("Frame")
    taskFrame:SetScript("OnUpdate", function(self, elapsed)
        local now = GetTime()
        local due = {}
        local pending = {}
        -- Separar primero las tareas debidas para no modificar `tasks` mientras
        -- se itera (las tareas debidas pueden programar otras nuevas).
        for _, task in ipairs(tasks) do
            if task.time <= now then
                table.insert(due, task)
            else
                table.insert(pending, task)
            end
        end
        tasks = pending
        for _, task in ipairs(due) do
            pcall(task.callback)
        end
        if #tasks == 0 then self:Hide() end
    end)
    return taskFrame
end

local function Schedule(delay, callback)
    table.insert(tasks, { time = GetTime() + (delay or 0), callback = callback })
    EnsureTaskFrame():Show()
end

-- =============================================
-- Envío
-- =============================================

-- Resuelve el canal de envío igual que la base (GetDefaultChannel):
-- usa el canal guardado si no es "DEFAULT"; si es "DEFAULT", auto-resuelve
-- según el contexto (campo de batalla / banda / grupo / hermandad / say).
function MessageManager:GetChannel()
    local saved = (RD.config and RD.config.Get and RD.config:Get("chat.channel", "DEFAULT")) or "DEFAULT"
    saved = strtrim(tostring(saved))
    saved = strupper(saved)
    if saved ~= "DEFAULT" and saved ~= "" then
        return saved
    end
    if UnitInBattleground("player") then
        return "BATTLEGROUND"
    elseif GetNumRaidMembers() ~= 0 then
        return (IsRaidLeader() or IsRaidOfficer()) and "RAID_WARNING" or "RAID"
    elseif GetNumPartyMembers() > 0 then
        return "PARTY"
    elseif IsInGuild() then
        return "GUILD"
    end
    return "SAY"
end

-- Canales reconocidos (igual que la base)
local VALID_CHANNELS = {
    DEFAULT = true, SYSTEM = true, GUILD = true, SAY = true, YELL = true,
    PARTY = true, RAID = true, RAID_WARNING = true, BATTLEGROUND = true,
    CHANNEL = true, INN = true,
}

-- Envío directo (como SendDelayedMessages de la base): INN por número de canal,
-- SYSTEM por mensaje de sistema y el resto por SendChatMessage. Si el canal no
-- es reconocido, se re-resuelve por contexto (nunca cae a sistema salvo que el
-- contexto diga SYSTEM). Es método público para que el spammer (y cualquier
-- módulo) envíe a un canal concreto sin duplicar la lógica de canales.
function MessageManager:SendRaw(text, channel)
    local ch = channel
    -- Canales numéricos 1-9 (índice de chat personalizado / general)
    local chNum = tonumber(ch)
    if chNum and chNum >= 1 and chNum <= 9 then
        SendChatMessage(text, "CHANNEL", nil, chNum)
        return
    end
    if not VALID_CHANNELS[ch] then
        ch = MessageManager:GetChannel()
    end
    if ch == "INN" then
        -- GetChannelName devuelve (nombre, índice); SendChatMessage con "CHANNEL"
        -- espera el ÍNDICE numérico (select(2)). Si el canal de la Posada no está
        -- activo (id nil) se cae a SAY para no enviar con argumento inválido.
        local id = select(2, GetChannelName("Posada"))
        if id then
            SendChatMessage(text, "CHANNEL", nil, id)
        else
            SendChatMessage(text, "SAY")
        end
    elseif ch == "SYSTEM" then
        SendSystemMessage(text)
    else
        SendChatMessage(text, ch)
    end
end

-- Alias interno (SendSequence/SendMessage lo usan) — siempre con self correcto
local function SendRaw(text, channel)
    return MessageManager:SendRaw(text, channel)
end

-- Corta en un límite de CARACTERES sin partir una palabra ni un carácter
-- UTF-8 multibyte: si hay un espacio dentro de los `limit` primeros caracteres,
-- corta justo después del último espacio (descarta ese espacio de separación);
-- si no hay ningún espacio (una única palabra más larga que el límite), corta
-- en el límite como último recurso. Devuelve (parte, resto). Si todo el texto
-- cabe en el límite de caracteres (aunque sus bytes superen el límite por
-- multibyte), no corta y devuelve el texto completo.
local function SplitAt(text, limit)
    local chars = 0
    local byte = 1
    local lastSpace = 0   -- byte de inicio del último espacio visto (0 = ninguno)
    while byte <= #text do
        if chars == limit then break end
        local b = string.byte(text, byte)
        local len = 1
        if b >= 0xF0 then len = 4
        elseif b >= 0xE0 then len = 3
        elseif b >= 0xC0 then len = 2
        end
        if b == 32 then lastSpace = byte end
        byte = byte + len
        chars = chars + 1
    end
    -- Todo el texto cabe en el límite de caracteres (no parte)
    if byte > #text then return text, "" end
    -- Cortar en el último espacio (>=2 para no devolver una parte vacía)
    if lastSpace > 1 then
        return text:sub(1, lastSpace - 1), text:sub(lastSpace + 1)
    end
    -- Sin espacios en el bloque: partir por el límite (palabra gigante)
    return text:sub(1, byte - 1), text:sub(byte)
end

-- Envía una secuencia de mensajes por un canal (por defecto el configurado),
-- con el retraso indicado entre cada parte.
function MessageManager:SendSequence(parts, delay, channel)
    if not parts or #parts == 0 then return end
    local target = channel or self:GetChannel()
    local i = 1
    local function SendNext()
        if i > #parts then return end
        SendRaw(parts[i], target)
        i = i + 1
        if i <= #parts then
            Schedule(delay or 0.1, SendNext)
        end
    end
    SendNext()
end

-- Envía un mensaje por el canal configurado (o el indicado), troceándolo en
-- partes de MAX_CHARS caracteres si es largo y enviándolas en secuencia con un
-- pequeño retraso (como el addon base, pero sin partir caracteres UTF-8).
function MessageManager:SendMessage(text, channel)
    local msg = tostring(text or "")
    if msg == "" then return end
    local parts = {}
    while #msg > 0 do
        local part, rest = SplitAt(msg, MAX_CHARS)
        table.insert(parts, part)
        msg = rest
    end
    self:SendSequence(parts, 0.1, channel)
end

-- Programa una función para ejecutarse tras un retraso (sin C_Timer)
function MessageManager:Schedule(delay, callback)
    Schedule(delay or 0, callback)
end

-- Mensaje de sistema (usado por otros módulos como fallback)
function MessageManager:SendSystemMessage(msg)
    SendSystemMessage(tostring(msg or ""))
end

RD.messageManager = MessageManager
RD.modules = RD.modules or {}
RD.modules.messageManager = MessageManager

return MessageManager
