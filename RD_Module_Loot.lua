--[[
    RD_Module_Loot.lua
    PROPÓSITO: Motor de gestión de botín (estilo KRT). Lleva registro de los ítems
              obtenidos en el transcurso de la banda, permite seleccionar un ítem
              (desde el botín abierto del boss o arrastrado de la bolsa), abrir
              dados por main/dual/enchant dentro de un tiempo límite, llevar el
              registro de los dados de la banda, declarar al ganador, spamear el
              botín del boss caído y limpiar el estado. Sin C_Timer: frame
              OnUpdate persistente para el countdown de los dados.
    API PÚBLICA:
        - RD.modules.loot:SetItem(itemLink, count)
        - RD.modules.loot:StartRoll(rollType) / Roll() / RecordRolls(bool)
        - RD.modules.loot:GetRolls() / HighestRoll() / GetWinner() / SetWinner(name)
        - RD.modules.loot:GetTiedPlayers() / HasTie() / StartDuel() / ResolveDuel()
        - RD.modules.loot:AnnounceWinner() / SpamLoot() / AnnounceRoll(name) / Clear()
        - RD.modules.loot:SetRollType(main|dual|enchant)
        - RD.modules.loot:IsMasterLooter()
        - RD.modules.loot:GetBossLootLinks() / MasterCandidateIndex(slot) / CollectItems()
        - RD.modules.loot:GetHistory() / GetDailyHistory() / GroupByItem(records)
        - RD.modules.loot:GetState()  -- para la UI
    EVENTOS: Publica LOOT_ITEM_ADDED, LOOT_ROLL_ADDED, LOOT_ROLL_CLEARED,
             LOOT_WINNER_SET, LOOT_STATE_CHANGED (para refrescar la UI).
]]

local addonName, private = ...
local RD = _G.RaidDominion or {}
_G.RaidDominion = RD

local Loot = {}

-- Tipos de roll (main / dual / enchant)
local ROLL_MAIN = 1
local ROLL_DUAL = 2
local ROLL_ENCHANT = 3

-- Duración por defecto de la ventana de dados (segundos)
local DEFAULT_COUNTDOWN = 10

-- Límite máximo permitido de la ventana de dados (segundos)
local MAX_COUNTDOWN = 10

-- Estado interno
local state = {
    itemName = "",
    itemLink = nil,
    itemTexture = nil,
    itemCount = 1,
    itemRarity = 0,
    rollType = ROLL_MAIN,
    rolls = {},          -- { { name = "X", roll = 87 }, ... }
    rolled = false,      -- si el jugador local ya tiró
    canRoll = true,      -- si se aceptan más dados
    recording = false,   -- si se están registrando dados
    countdown = 0,       -- tiempo restante (0 = sin countdown activo)
    countdownActive = false,
    token = 0,           -- contador anti-stale para avisos programados del conteo
    winner = nil,
    winnerRoll = nil,    -- dado final del ganador (incluye tiros de desempate)
    history = {},        -- registro persistente de ítems asignados
    announced = false,
    -- Estado del desempate por empate en el dado más alto
    duel = false,        -- si hay una ronda de desempate activa
    duelPlayers = {},    -- nombres de los jugadores que deben desempatar
    duelRolls = {},      -- tiros de la ronda de desempate { { name, roll } }
}

-- Patrón de dados localizado: convierte RANDOM_ROLL_RESULT (formato printf del
-- cliente, p.ej. "%s rolls %d (%d-%d)" o la variante esMX) a un patrón Lua.
-- Replica la conversión de LibDeformat que usa KRT pero sin librerías externas:
-- escapa los caracteres mágicos y sustituye %s → (.-) y %d → (%d+). Sin esto,
-- el parseo hardcodeado en inglés fallaba en clientes no enUS (esMX) y no se
-- registraban los dados.
local rollPattern
local function GetRollPattern()
    if rollPattern then return rollPattern end
    local fmt = _G.RANDOM_ROLL_RESULT or "%s rolls %d (%d-%d)"
    local p = fmt:gsub("([%(%)%.%+%-%[%]%?%^%$%%%*])", "%%%1")
    p = p:gsub("%%%%s", "(.-)"):gsub("%%%%d", "(%%d+)")
    rollPattern = "^" .. p .. "$"
    return rollPattern
end

-- Resuelve el nombre del jugador del mensaje de dado: quita el hipervínculo de
-- jugador (si el cliente lo incluye) y mapea el pronombre de primera persona
-- del propio jugador ("You"/"Tú" según el cliente) al nombre real, para no
-- registrar un dado bajo el pronombre.
local function ResolveRollName(player)
    if not player then return nil end
    local me = UnitName("player") or ""
    if player == me then return me end
    player = player:gsub("|Hplayer:[^|]+|h([^|]+)|h", "%1")
    if player == me then return me end
    local selfRefs = {
        ["You"] = true, ["you"] = true,
        ["Tú"] = true, ["tú"] = true, ["Tu"] = true, ["tu"] = true,
        ["Du"] = true, ["du"] = true, ["Vous"] = true, ["vous"] = true,
    }
    if selfRefs[player] then return me end
    return player
end

local Publish = function(event, ...)
    if RD.events and RD.events.Publish then
        RD.events:Publish(event, ...)
    end
end

local function System(msg)
    if RD.messageManager and RD.messageManager.SendSystemMessage then
        RD.messageManager:SendSystemMessage(msg)
    end
end

-- Anuncia por la SALIDA POR DEFECTO (chat.channel, vía MessageManager) con
-- troceado automático para mensajes largos. Los modos de dados, el ganador y
-- el spameo de botín salen por aquí, como el addon base (KRT).
local function AnnounceDefault(msg)
    local mm = RD.modules and RD.modules.messageManager
    if mm and mm.SendMessage then
        mm:SendMessage(tostring(msg or ""), mm:GetChannel())
    end
end

-- Etiqueta de tipo de dados para anuncios ("MainSpec", "DualSpec", "Enchant")
local ROLL_TYPE_LABEL = { [1] = "MainSpec", [2] = "DualSpec", [3] = "Enchant" }
local function RollTypeLabel(rollType)
    return ROLL_TYPE_LABEL[rollType] or "MainSpec"
end

-- Invalida los avisos programados del conteo en curso (cualquier reinicio de
-- dados, cierre o declaración cancela los ticks pendientes de la cuenta vieja).
local function InvalidateCountdown()
    state.token = state.token + 1
end

-- Plan de avisos del conteo de dados por la salida por defecto, con el mismo
-- ritmo que el conteo de pull/ready check: primer tick (N-1s...), "5s...
-- ¡TIREN AHORA!", luego 3s..., 2s..., 1s... Los avisos se programan con
-- mm:Schedule (sin C_Timer) y se guardan con el token de la cuenta atrás para
-- que un reinicio/cancelación los invalide.
local function ScheduleCountdownAnnouncements(limit)
    local mm = RD.modules and RD.modules.messageManager
    if not mm then return end
    local token = state.token
    local plan = {}
    local function At(second, text)
        plan[#plan + 1] = { second = second, text = text }
    end
    local hasFive = (limit - 1) >= 5
    -- Con n=6 el primer tick sería "5s..." y chocaría con el "5s... ¡TIREN
    -- AHORA!" combinado (n-5=1): se omite el suelto.
    if limit > 1 and not (hasFive and limit - 5 == 1) then
        At(1, tostring(limit - 1) .. "s...")
    end
    if hasFive then
        At(limit - 5, "5s... ¡TIREN AHORA!")
    end
    for _, s in ipairs({ 3, 2, 1 }) do
        if s < limit - 1 then
            At(limit - s, tostring(s) .. "s...")
        end
    end
    if not hasFive then
        At(limit, "¡TIREN AHORA!")
    end
    for _, p in ipairs(plan) do
        mm:Schedule(p.second, function()
            -- Solo se emite si sigue activo EL MISMO conteo (token) y la cuenta
            -- no se cerró antes (un StartRoll nuevo o ClearRolls invalidan).
            if state.token == token and state.countdownActive and state.countdown > 0 then
                AnnounceDefault(p.text)
            end
        end)
    end
end

-- Comprueba si el jugador local es el maestro despojador (para auto-capturar el
-- botín del boss). Compatible 3.3.5a: GetLootMethod() devuelve método, índice
-- de party y de raid; el jugador local es el maestro cuando partyID == 0.
function Loot:IsMasterLooter()
    local method, partyID = GetLootMethod()
    if not method or method ~= "master" then return false end
    return (partyID and partyID == 0)
end

-- ¿Hay empate en el dado más alto de la ronda principal? Si lo hay no se
-- auto-declara ganador: queda pendiente un desempate o una elección manual.
local function HasTie()
    if #state.rolls < 2 then return false end
    return state.rolls[1].roll == state.rolls[2].roll
end

local function SortRolls()
    if #state.rolls > 0 then
        table.sort(state.rolls, function(a, b)
            if a.roll == b.roll then
                return a.name < b.name
            end
            return a.roll > b.roll
        end)
        if not HasTie() then
            state.winner = state.rolls[1].name
        end
    end
end

-- ¿Hay empate en el dado más alto de la ronda principal?
function Loot:HasTie()
    return HasTie()
end

-- Nombres de los jugadores que comparten el dado más alto (los que deben
-- desempatar). Vacío si no hay empate.
function Loot:GetTiedPlayers()
    local tied = {}
    if #state.rolls < 2 then return tied end
    local top = state.rolls[1].roll
    for _, r in ipairs(state.rolls) do
        if r.roll == top then
            tied[#tied + 1] = r.name
        end
    end
    return tied
end

local function DidRoll(name)
    for _, r in ipairs(state.rolls) do
        if r.name == name then
            return true
        end
    end
    return false
end

-- Parse de un itemLink para extraer el itemID
local function GetItemID(itemLink)
    local _, _, itemID = itemLink:find("|Hitem:(%d+):")
    return tonumber(itemID)
end

-- Parse del rarity desde el color del itemLink (|cffffffff → 1, |cff0070dd → 4, ...)
local function GetItemRarity(itemLink)
    local r = itemLink:match("|cff(%x%x%x%x%x%x)")
    if not r then return 0 end
    local map = {
        ["9d9d9d"] = 0, ["ffffff"] = 1, ["1eff00"] = 2, ["0070dd"] = 3,
        ["a335ee"] = 4, ["ff8000"] = 5, ["e6cc80"] = 6,
    }
    return map[r:lower()] or 0
end

-- ==================== Gestión de ítem ====================

-- Fija el ítem actual (desde el botín del boss o arrastrado de la bolsa)
function Loot:SetItem(itemLink, count)
    if not itemLink or itemLink == "" then return false end
    local itemName = GetItemInfo(itemLink) or itemLink:match("%[([^%]]+)%]") or itemLink
    local itemTexture = select(10, GetItemInfo(itemLink)) or "Interface\\PaperDoll\\UI-Backpack-EmptySlot"
    state.itemName = itemName
    state.itemLink = itemLink
    state.itemTexture = itemTexture
    state.itemCount = tonumber(count) or 1
    state.itemRarity = GetItemRarity(itemLink)
    -- Nuevo ítem: reinicia los dados
    self:ClearRolls()
    Publish("LOOT_ITEM_ADDED", state)
    return true
end

-- Devuelve una copia del estado (para la UI)
function Loot:GetState()
    return state
end

-- Devuelve el ítem actual
function Loot:GetItem()
    if not state.itemLink then return nil end
    return state
end

-- ==================== Registro de botín de la banda ====================

-- Clave de día local (YYYY-MM-DD) para agrupar el historial por jornada.
local function TodayKey()
    return date("%Y-%m-%d")
end

-- Registra un ítem en el historial de la banda (lo obtiene un jugador)
function Loot:LogItem(playerName, itemLink, rollType, rollValue)
    table.insert(state.history, {
        day = TodayKey(),
        event = "item",
        player = playerName,
        itemLink = itemLink,
        rollType = rollType,
        rollValue = rollValue,
        time = GetTime(),
    })
    Publish("LOOT_HISTORY_ADDED", state)
end

-- Registra un dado lanzado en el historial de la banda (por día). Se llama desde
-- CHAT_MSG_SYSTEM cuando se captura un dado del jugador local o de la banda.
function Loot:LogRoll(playerName, roll)
    if not playerName or not roll then return end
    table.insert(state.history, {
        day = TodayKey(),
        event = "roll",
        player = playerName,
        roll = tonumber(roll),
        itemLink = state.itemLink,
        time = GetTime(),
    })
    Publish("LOOT_HISTORY_ADDED", state)
end

-- Devuelve el historial de botín de la banda
function Loot:GetHistory()
    return state.history
end

-- Devuelve el historial agrupado por día (tabla { [dia] = { registros } }).
-- Los días se ordenan de más reciente a más antiguo.
function Loot:GetDailyHistory()
    local groups = {}
    local order = {}
    for _, e in ipairs(state.history) do
        local day = e.day or TodayKey()
        if not groups[day] then
            groups[day] = {}
            order[#order + 1] = day
        end
        groups[day][#groups[day] + 1] = e
    end
    -- Días de más reciente a más antiguo (el formato YYYY-MM-DD ordena como string)
    table.sort(order, function(a, b) return a > b end)
    return groups, order
end

-- Agrupa una lista de registros (p.ej. los de un día) POR ÍTEM: cada ítem
-- agrupa sus dados (rolls) y al ganador (la entrega del ítem). Devuelve una
-- lista de { itemLink, rolls = { {player, roll}, ... }, winner, winnerRoll,
-- rollType }. Los registros comparten itemLink (los dados se registran con el
-- ítem actual y la entrega con el ítem ganado), lo que permite juntarlos.
function Loot:GroupByItem(records)
    local items = {}
    local order = {}
    for _, e in ipairs(records or {}) do
        local link = e.itemLink or ""
        if link ~= "" then
            if not items[link] then
                items[link] = { itemLink = link, rolls = {}, winner = nil, winnerRoll = nil, rollType = nil }
                order[#order + 1] = link
            end
            local it = items[link]
            if e.event == "roll" then
                it.rolls[#it.rolls + 1] = { player = e.player, roll = e.roll }
            elseif e.event == "item" then
                it.winner = e.player
                it.winnerRoll = e.rollValue
                it.rollType = e.rollType
            end
        end
    end
    local result = {}
    for _, link in ipairs(order) do
        result[#result + 1] = items[link]
    end
    return result
end

-- ==================== Dados (rolls) ====================

-- Inicia una ventana de dados para el ítem actual con un tipo dado. Anuncia el
-- modo por la salida por defecto (estilo KRT: "Dados MainSpec por: <ítem>") y
-- programa los avisos del conteo con el mismo ritmo que el conteo de pull.
function Loot:StartRoll(rollType)
    if not state.itemLink then return false end
    state.rollType = rollType
    self:ClearRolls()
    state.recording = true
    state.canRoll = true
    state.announced = false
    local limit = DEFAULT_COUNTDOWN
    if RD.config and RD.config.Get then
        limit = RD.config:Get("loot.rollTimeLimit", DEFAULT_COUNTDOWN)
    end
    limit = tonumber(limit) or DEFAULT_COUNTDOWN
    -- El límite no puede superar MAX_COUNTDOWN (10 s): saneo de configs
    -- heredadas que guardaron valores mayores (la pestaña de config ya no
    -- permite ese campo; el gestor de botín lo controla al escribir).
    if limit > MAX_COUNTDOWN then limit = MAX_COUNTDOWN end
    InvalidateCountdown()
    state.countdown = limit
    state.countdownActive = true
    -- Asegura que el loop del countdown corra: el frame se auto-oculta al
    -- terminar una cuenta atrás y hay que volver a mostrarlo en cada una nueva;
    -- sin esto el countdown quedaba congelado y los dados nunca se cerraban.
    self:ShowLoop()
    -- Anuncio del modo por la salida por defecto (KRT: ChatRollMS/OS/Free).
    local modeMsg = string.format("Dados %s por: %s", RollTypeLabel(rollType), state.itemLink)
    if state.itemCount and state.itemCount > 1 then
        modeMsg = modeMsg .. string.format(" x%d", state.itemCount)
    end
    AnnounceDefault(modeMsg)
    ScheduleCountdownAnnouncements(limit)
    Publish("LOOT_STATE_CHANGED", state)
    return true
end

-- Establece el tipo de roll (main/dual/enchant) sin abrir ventana
function Loot:SetRollType(rollType)
    state.rollType = rollType
end

-- El jugador local tira sus propios dados (RandomRoll 1-100)
function Loot:Roll()
    if not state.recording or state.rolled then return end
    RandomRoll(1, 100)
    state.rolled = true
    Publish("LOOT_STATE_CHANGED", state)
end

-- Activa/desactiva el registro de dados
function Loot:RecordRolls(bool)
    state.canRoll = (bool == true)
    state.recording = (bool == true)
end

-- CHAT_MSG_SYSTEM: captura los dados (RANDOM_ROLL_RESULT localizado)
function Loot:CHAT_MSG_SYSTEM(msg)
    if not msg or not state.recording then return end
    local player, roll, min, max = msg:match(GetRollPattern())
    if player and roll and tonumber(min) == 1 and tonumber(max) == 100 then
        if state.canRoll == false then
            return
        end
        player = ResolveRollName(player)
        if not player then return end
        -- Ronda de desempate: solo se aceptan tiros de los jugadores en duelo,
        -- y cada uno tira una sola vez. Al completar todos los tiros se resuelve.
        if state.duel then
            local allowed = false
            for _, name in ipairs(state.duelPlayers) do
                if name == player then allowed = true break end
            end
            if not allowed then return end
            for _, d in ipairs(state.duelRolls) do
                if d.name == player then return end
            end
            table.insert(state.duelRolls, { name = player, roll = tonumber(roll) })
            self:LogRoll(player, tonumber(roll))
            Publish("LOOT_ROLL_ADDED", state)
            self:ResolveDuel()
            return
        end
        if not DidRoll(player) then
            table.insert(state.rolls, { name = player, roll = tonumber(roll) })
            SortRolls()
            self:LogRoll(player, tonumber(roll))
            Publish("LOOT_ROLL_ADDED", state)
        end
    end
end

-- Devuelve la tabla de dados (ordenada de mayor a menor)
function Loot:GetRolls()
    return state.rolls
end

-- Devuelve el dado más alto del ganador (tiene en cuenta los tiros del
-- desempate si el ganador salió de una ronda de desempate)
function Loot:HighestRoll()
    if state.winnerRoll then return state.winnerRoll end
    if state.winner then
        for _, r in ipairs(state.rolls) do
            if r.name == state.winner then
                return r.roll
            end
        end
    end
    return 0
end

-- Devuelve el ganador actual (el de mayor dado)
function Loot:GetWinner()
    return state.winner
end

-- Declara manualmente un ganador (elección por clic en un dado). Al elegir
-- manualmente se cancela cualquier ronda de desempate en curso.
function Loot:SetWinner(name)
    state.winner = name
    state.winnerRoll = nil
    state.duel = false
    state.duelRolls = {}
    state.duelPlayers = {}
    state.announced = false
    Publish("LOOT_WINNER_SET", state)
end

-- Inicia una ronda de desempate entre los jugadores que empataron en el dado
-- más alto. Solo esos jugadores pueden tirar durante el desempate (el filtro
-- vive en CHAT_MSG_SYSTEM). Devuelve false si no hay empate que desempatar.
function Loot:StartDuel()
    if not HasTie() then return false end
    state.duelPlayers = self:GetTiedPlayers()
    state.duelRolls = {}
    state.duel = true
    state.recording = true
    state.canRoll = true
    state.rolled = false
    local limit = DEFAULT_COUNTDOWN
    if RD.config and RD.config.Get then
        limit = RD.config:Get("loot.rollTimeLimit", DEFAULT_COUNTDOWN)
    end
    limit = tonumber(limit) or DEFAULT_COUNTDOWN
    if limit > MAX_COUNTDOWN then limit = MAX_COUNTDOWN end
    InvalidateCountdown()
    state.countdown = limit
    state.countdownActive = true
    self:ShowLoop()
    AnnounceDefault("¡Desempate! Tiran solo: " .. table.concat(state.duelPlayers, ", "))
    ScheduleCountdownAnnouncements(limit)
    Publish("LOOT_STATE_CHANGED", state)
    return true
end

-- Resuelve la ronda de desempate cuando todos los jugadores en duelo han tirado.
-- Si vuelve a haber empate entre los tiros del duelo, abre otra ronda con los
-- empatados de esa ronda; si no, fija al ganador (y su dado final).
function Loot:ResolveDuel()
    if not state.duel then return end
    -- Todos los jugadores del duelo deben haber tirado una vez.
    local pending = 0
    for _, name in ipairs(state.duelPlayers) do
        local has = false
        for _, d in ipairs(state.duelRolls) do
            if d.name == name then has = true break end
        end
        if not has then pending = pending + 1 end
    end
    if pending > 0 then return end

    table.sort(state.duelRolls, function(a, b)
        if a.roll == b.roll then return a.name < b.name end
        return a.roll > b.roll
    end)
    -- Empate en el duelo: nueva ronda con los empatados de esta ronda.
    if #state.duelRolls >= 2 and state.duelRolls[1].roll == state.duelRolls[2].roll then
        state.duelPlayers = {}
        local top = state.duelRolls[1].roll
        for _, d in ipairs(state.duelRolls) do
            if d.roll == top then state.duelPlayers[#state.duelPlayers + 1] = d.name end
        end
        state.duelRolls = {}
        AnnounceDefault("Nuevo desempate entre: " .. table.concat(state.duelPlayers, ", "))
        Publish("LOOT_STATE_CHANGED", state)
        return
    end
    state.winner = state.duelRolls[1].name
    state.winnerRoll = state.duelRolls[1].roll
    state.duel = false
    state.duelRolls = {}
    state.duelPlayers = {}
    state.announced = false
    AnnounceDefault(string.format("Desempate resuelto: %s gana con %d.", state.winner, state.winnerRoll))
    Publish("LOOT_STATE_CHANGED", state)
end

-- Anuncia el dado de un jugador concreto por la salida por defecto (Ctrl-clic
-- sobre un dado en la ventana), como el ChatPlayerRolled de KRT.
function Loot:AnnounceRoll(playerName)
    if not playerName then return false end
    for _, r in ipairs(state.rolls) do
        if r.name == playerName then
            AnnounceDefault(string.format("%s obtuvo %d en dados.", playerName, r.roll))
            return true
        end
    end
    return false
end

-- Declara al ganador por la salida por defecto (anuncia el nombre y el ítem)
function Loot:AnnounceWinner()
    if not state.itemLink or not state.winner then return false end
    if state.announced then return true end
    local rollTypeText = ({ [1] = "main", [2] = "dual", [3] = "enchant" })[state.rollType] or "main"
    local rollValue = self:HighestRoll()
    AnnounceDefault(string.format("%s ganó %s (dado %d, %s)", state.winner, state.itemLink, rollValue, rollTypeText))
    -- Lleva registro del ítem ganador en el historial (esté o no haya bandas).
    self:LogItem(state.winner, state.itemLink, state.rollType, rollValue)
    state.announced = true
    state.recording = false
    state.countdownActive = false
    InvalidateCountdown()
    Publish("LOOT_STATE_CHANGED", state)
    return true
end

-- ==================== Spamear botín ====================

-- Lista los ítems del botín del boss recién caído (ventana de botín abierta),
-- sin monedas ni materiales de encantar (familia 64), igual que KRT.
function Loot:GetBossLootLinks()
    local list = {}
    local n = GetNumLootItems()
    if not n or n <= 0 then return list end
    local threshold = GetLootThreshold() or 2
    for i = 1, n do
        if LootSlotIsItem(i) then
            local itemLink = GetLootSlotLink(i)
            if itemLink and GetItemFamily(itemLink) ~= 64 then
                local _, _, rarity = GetItemInfo(itemLink)
                if (rarity or 0) >= threshold then
                    list[#list + 1] = itemLink
                end
            end
        end
    end
    return list
end

-- Spamea el botín del boss caído por la salida por defecto, como el addon base
-- (KRT): cabecera "Items obtenidos:" + un mensaje por ítem numerado. Si no hay
-- ventana de botín abierta, cae al ítem actual del gestor.
function Loot:SpamLoot()
    local list = self:GetBossLootLinks()
    if #list == 0 then
        if not state.itemLink then return false end
        AnnounceDefault("Items obtenidos:")
        if state.itemCount > 1 then
            AnnounceDefault("1. " .. state.itemLink .. " x" .. state.itemCount)
        else
            AnnounceDefault("1. " .. state.itemLink)
        end
        return true
    end
    AnnounceDefault("Items obtenidos:")
    for i, link in ipairs(list) do
        AnnounceDefault(string.format("%d. %s", i, link))
    end
    return true
end

-- Índice del candidato del maestro despojador para un slot de botín (el índice
-- de jugador que acepta GiveMasterLoot en 3.3.5a).
function Loot:MasterCandidateIndex(lootSlot)
    local myName = UnitName("player") or ""
    if myName == "" then return nil end
    for p = 1, 40 do
        local name = GetMasterLootCandidate(lootSlot, p)
        if name == myName then return p end
    end
    return nil
end

-- Recoge los ítems del botín abierto y los dirige al maestro despojador
-- (botón pensado para el maestro). Cada slot se asigna al propio maestro con
-- GiveMasterLoot, como hace KRT al asignar a un ganador.
function Loot:CollectItems()
    if not self:IsMasterLooter() then
        System("|cffff0000[RaidDominion]|r Solo el maestro despojador puede recoger los items.")
        return false
    end
    local n = GetNumLootItems()
    if not n or n <= 0 then
        System("|cffffd700[RaidDominion]|r No hay ventana de botín abierta para recoger items.")
        return false
    end
    local collected = 0
    for i = 1, n do
        if LootSlotIsItem(i) then
            local itemLink = GetLootSlotLink(i)
            if itemLink and GetItemFamily(itemLink) ~= 64 then
                local idx = self:MasterCandidateIndex(i)
                if idx then
                    GiveMasterLoot(i, idx)
                    collected = collected + 1
                end
            end
        end
    end
    if collected > 0 then
        AnnounceDefault(string.format("%s recogió %d items del botín.", UnitName("player") or "El maestro", collected))
        return true
    end
    return false
end

-- ==================== Limpiar ====================

-- Limpia los dados y el estado del roll actual (mantiene el historial)
function Loot:ClearRolls()
    InvalidateCountdown()
    state.rolls = {}
    state.rolled = false
    state.canRoll = true
    state.recording = false
    state.countdown = 0
    state.countdownActive = false
    state.winner = nil
    state.winnerRoll = nil
    state.announced = false
    state.duel = false
    state.duelPlayers = {}
    state.duelRolls = {}
    Publish("LOOT_ROLL_CLEARED", state)
end

-- Limpia todo el gestor de botín (ítem + dados + historial)
function Loot:Clear()
    state.itemName = ""
    state.itemLink = nil
    state.itemTexture = nil
    state.itemCount = 1
    state.itemRarity = 0
    state.history = {}
    self:ClearRolls()
    Publish("LOOT_STATE_CHANGED", state)
end

-- ==================== Eventos del juego ====================

-- Inicializa el registro de eventos del juego (LOOT_OPENED, CHAT_MSG_SYSTEM).
-- Se llama desde RD_Init en PLAYER_LOGIN.
function Loot:Initialize()
    if self._initialized then return end
    self._initialized = true
    local f = CreateFrame("Frame", "RDLootEvents", UIParent)
    f:RegisterEvent("LOOT_OPENED")
    f:RegisterEvent("CHAT_MSG_SYSTEM")
    f:SetScript("OnEvent", function(self, event, arg1)
        if event == "LOOT_OPENED" then
            Loot:LOOT_OPENED()
        elseif event == "CHAT_MSG_SYSTEM" then
            Loot:CHAT_MSG_SYSTEM(arg1)
        end
    end)
    self._eventFrame = f
end

-- LOOT_OPENED: si hay un botín abierto (boss caído), carga el primer ítem
-- automáticamente. Replica el comportamiento de KRT (master looter).
function Loot:LOOT_OPENED()
    if not self:IsMasterLooter() then return end
    for i = 1, GetNumLootItems() do
        if LootSlotIsItem(i) then
            local itemLink = GetLootSlotLink(i)
            if itemLink and GetItemFamily(itemLink) ~= 64 then
                -- Carga el primer ítem del botín del boss para gestionarlo.
                -- El contador es la cantidad del stack del ítem. GetLootSlotInfo
                -- devuelve los valores en orden distinto según el cliente (aquí
                -- es "textura, nombre, cantidad, ..."; en otros "nombre, cantidad,
                -- rareza, ..."), así que se localiza la cantidad por su TIPO
                -- (primer valor numérico o string numérico) en lugar de asumir
                -- una posición fija. Sin esto, el 2º valor podía ser el NOMBRE
                -- (string) y `count > 1` reventaba con "attempt to compare number
                -- with string".
                local function ToCount(v)
                    if type(v) == "number" then return v end
                    if type(v) == "string" then return tonumber(v) end
                    return nil
                end
                local a, b, c = GetLootSlotInfo(i)
                local count = ToCount(a) or ToCount(b) or ToCount(c)
                self:SetItem(itemLink, count and count > 1 and count or 1)
                Publish("LOOT_ITEM_ADDED", self:GetState())
                return
            end
        end
    end
end

-- ==================== Countdown OnUpdate ====================

local countdownFrame

function Loot:Tick(elapsed)
    if not state.countdownActive then return end
    -- Decremento por tiempo real (elapsed del OnUpdate): antes se restaba un
    -- 0.1 fijo por frame, con lo que a 60fps el countdown corría 6x.
    state.countdown = state.countdown - (elapsed or 0.1)
    if state.countdown <= 0 then
        state.countdown = 0
        state.countdownActive = false
        state.recording = false
        state.canRoll = false
        InvalidateCountdown()
        -- Fin del conteo por la salida por defecto (estilo conteo de pull) y
        -- aviso local de que los dados fuera de tiempo se ignoran.
        AnnounceDefault("¡Dados cerrados! Fuera de tiempo se ignoran.")
        System("|cffffd700[RaidDominion]|r Dados cerrados: tiempo agotado. Se ignoran dados fuera de tiempo.")
        Publish("LOOT_STATE_CHANGED", state)
    end
end

-- ==================== Loop ====================

-- Frame OnUpdate persistente: gestiona el countdown de los dados. Se crea de
-- forma perezosa en Initialize (PLAYER_LOGIN) para no depender de UIParent en
-- el load del .toc.
function Loot:EnsureLoop()
    if countdownFrame then return end
    countdownFrame = CreateFrame("Frame", "RDLootLoop", UIParent)
    countdownFrame:Hide()
    countdownFrame:SetScript("OnUpdate", function(self, elapsed)
        if not state.countdownActive then
            self:Hide()
            return
        end
        Loot:Tick(elapsed)
    end)
end

function Loot:ShowLoop()
    self:EnsureLoop()
    if state.countdownActive then
        countdownFrame:Show()
    else
        countdownFrame:Hide()
    end
end

RD.modules = RD.modules or {}
RD.modules.loot = Loot
return Loot
