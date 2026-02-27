--[[
    RD_Utils_GuildBank.lua
    Módulo para la gestión y escaneo del banco de hermandad.
    Propósito: Escanear depósitos de ítems y oro para reconocimientos.
--]]

local addonName, private = ...
local RD = _G.RaidDominion or {}
_G.RaidDominion = RD

-- Inicializar namespace
RD.utils = RD.utils or {}
RD.utils.guildBank = {}
local guildBankUtils = RD.utils.guildBank

-- Constantes locales
local MAX_GUILDBANK_TABS = 6
local GUILD_BANK_LOG_TIMEOUT = 3 -- Segundos de espera máxima

-- Helper para logs
local function Log(...)
    if RD.messageManager and RD.messageManager.SendSystemMessage then
        RD.messageManager:SendSystemMessage(...)
    else
        local msg = select(1, ...)
        if select("#", ...) > 1 then
            msg = string.format(...)
        end
        DEFAULT_CHAT_FRAME:AddMessage(msg)
    end
end

-- Obtener índice de rango del jugador (0-based)
local function GetMemberRankIndex(playerName)
    if not IsInGuild() then return 99 end
    local numMembers = GetNumGuildMembers(true)
    for i = 1, numMembers do
        local name, _, rankIndex = GetGuildRosterInfo(i)
        if name then
            -- Limpiar nombre (Nombre-Reino -> Nombre)
            name = string.match(name, "^([^-]+)") or name
            if string.lower(name) == string.lower(playerName) then
                return rankIndex
            end
        end
    end
    return 99 -- No encontrado (probablemente ya no está en la guild o error)
end

-- Escanear logs
-- callback(donations) donde donations es una lista de {name, itemLink, count, type, amount}
function guildBankUtils.ScanTabsForDonations(callback)
    if not IsInGuild() then 
        if callback then callback({}) end
        return 
    end

    -- Frame para eventos
    local f = CreateFrame("Frame")
    local donations = {}
    local tabsScanned = { [1]=false, [2]=false, [3]=false, ["money"]=false }
    local isComplete = false
    local timeoutTimer = 0

    -- Función de finalización
    local function Finish()
        if isComplete then return end
        isComplete = true
        f:SetScript("OnUpdate", nil)
        f:UnregisterAllEvents()
        if callback then callback(donations) end
    end

    -- Procesar logs de una pestaña
    local function ProcessTab(tab)
        local numTransactions = GetNumGuildBankTransactions(tab)
        for i = 1, numTransactions do
            local type, name, itemLink, count, tab1, tab2 = GetGuildBankTransaction(tab, i)
            -- Tipo: "deposit" para ítems
            if type == "deposit" and name then
                -- Filtrar rango: No rango 0 (GM) ni 1 (Oficial) -> rankIndex > 1
                local rankIndex = GetMemberRankIndex(name)
                if rankIndex > 1 then
                    table.insert(donations, {
                        name = name,
                        itemLink = itemLink,
                        count = count,
                        type = "item",
                        tab = tab
                    })
                end
            end
        end
    end

    -- Procesar logs de dinero
    local function ProcessMoney()
        local numTransactions = GetNumGuildBankMoneyTransactions()
        for i = 1, numTransactions do
            local type, name, amount, years, months, days, hours = GetGuildBankMoneyTransaction(i)
            -- Tipo: "deposit" para dinero
            if type == "deposit" and name and amount > 0 then
                -- Filtrar rango: No rango 0 (GM) ni 1 (Oficial) -> rankIndex > 1
                local rankIndex = GetMemberRankIndex(name)
                if rankIndex > 1 then
                    -- Solo considerar depósitos recientes (ej: últimas 24 horas) para no spamear con historial antiguo?
                    -- El usuario no especificó tiempo, pero "esc registros" implica lo que haya visible.
                    -- Los logs de Blizzard son limitados (25 últimos aprox).
                    -- Vamos a incluir todo lo visible en el log.
                    table.insert(donations, {
                        name = name,
                        amount = amount,
                        type = "money"
                    })
                end
            end
        end
    end

    -- Manejador de eventos
    f:RegisterEvent("GUILD_BANKLOG_UPDATE")
    f:SetScript("OnEvent", function(self, event)
        if event == "GUILD_BANKLOG_UPDATE" then
            -- Nota: La API de 3.3.5 no dice qué pestaña se actualizó en el evento.
            -- Asumimos que llegaron datos.
            -- Volvemos a leer todo cuando se dispara el evento (o esperamos un poco?)
            -- En realidad, QueryGuildBankLog dispara el evento cuando llega la info.
            -- Podríamos esperar un par de updates o simplemente procesar al final del timeout/espera.
            -- Para simplicidad y robustez, usaremos un pequeño delay tras el último evento o el timeout.
        end
    end)

    -- Solicitar logs
    -- Pestañas 1, 2, 3
    QueryGuildBankLog(1)
    QueryGuildBankLog(2)
    QueryGuildBankLog(3)
    -- Dinero (MAX_GUILDBANK_TABS + 1)
    QueryGuildBankLog(MAX_GUILDBANK_TABS + 1)

    -- Timer para esperar respuestas (ya que no sabemos exactamente cuándo llegan todas)
    f:SetScript("OnUpdate", function(self, elapsed)
        timeoutTimer = timeoutTimer + elapsed
        if timeoutTimer >= GUILD_BANK_LOG_TIMEOUT then
            -- Tiempo cumplido, procesar lo que tengamos
            ProcessTab(1)
            ProcessTab(2)
            ProcessTab(3)
            ProcessMoney()
            Finish()
        end
    end)
    
    Log("|cff00ff00[RaidDominion]|r Escaneando registros del banco (esperando datos)...")
end

-- Encontrar o crear reconocimiento "Contribuidor destacado"
function guildBankUtils.GetContributorRecognitionIndex()
    if not RaidDominionDB then RaidDominionDB = {} end
    if not RaidDominionDB.recognition then RaidDominionDB.recognition = {} end
    
    local targetName = "Contribuidor destacado"
    
    for i, rec in ipairs(RaidDominionDB.recognition) do
        if rec.name == targetName then
            return i
        end
    end
    
    -- Crear si no existe
    local newRec = {
        name = targetName,
        icon = "Interface\\Icons\\Inv_misc_bag_10_green",
        members = {},
        createdAt = time()
    }
    table.insert(RaidDominionDB.recognition, newRec)
    return #RaidDominionDB.recognition
end

-- Añadir jugador a reconocimiento (Wrapper)
function guildBankUtils.AddContributor(playerName)
    local index = guildBankUtils.GetContributorRecognitionIndex()
    
    -- Verificar si el módulo de reconocimiento está disponible y tiene la función AddPlayer
    if RD.utils and RD.utils.recognition and RD.utils.recognition.AddPlayer then
        RD.utils.recognition.AddPlayer(index, {name = playerName})
        return true
    else
        -- Loguear error si no se encuentra la función
        local msg = "|cffff0000[RaidDominion]|r Error: No se pudo acceder a RD.utils.recognition.AddPlayer"
        if RD.messageManager and RD.messageManager.SendSystemMessage then
            RD.messageManager:SendSystemMessage(msg)
        else
            print(msg)
        end
    end
    return false
end
