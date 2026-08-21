--[[
    RD_Module_ActionBar.lua
    PROPÓSITO: Funciones de la barra de botones inferior del menú flotante
              (clic izquierdo y derecho de cada botón), integradas del addon
              base v2 con las mejoras de v3 (canal configurado, asignaciones).
    API PÚBLICA: Registra handlers en RD.MenuActions (prefijo "ActionBar").
    EVENTOS: Ninguno directo.
]]

local addonName, private = ...
local RD = _G.RaidDominion or {}
_G.RaidDominion = RD

-- Mensaje de sistema (helper central en RD.UIUtils.Log)
local Log = (RD.UIUtils and RD.UIUtils.Log) or function(msg) print(msg) end

local function InRaid() return GetNumRaidMembers() ~= 0 end
local function InParty() return GetNumPartyMembers() > 0 end

local function CleanName(name)
    if RD.UIUtils and RD.UIUtils.CleanName then
        return RD.UIUtils.CleanName(name)
    end
    return string.lower(tostring(name or ""))
end

-- Limpia TODOS los iconos de marcado de la banda. En 3.3.5a NO existe
-- ClearAllRaidIcons (llegó en Cataclysm) ni se garantiza ClearRaidTargetIcon;
-- la forma fiable de retirar un marcador es SetRaidTarget(unit, 0) (índice 0 =
-- sin icono), el mismo API con el que se colocan.
local function ClearAllRaidIcons()
    for i = 1, GetNumRaidMembers() do
        if SetRaidTarget then
            SetRaidTarget("raid" .. i, 0)
        end
    end
end

-- ============ Modo de raid ============
-- Aplica la dificultad elegida. Nombrada "Apply" para no sombrear la global
-- SetRaidDifficulty/SetRaidDifficultyID (en 3.3.5a no existen; se deja listo).
local function ApplyRaidDifficulty(size, heroic)
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
    Log(string.format("|cff00ff00[RaidDominion]|r Dificultad establecida: %s %s", modeText, hText))
end

local function HandleRaidMode()
    local inParty = GetNumPartyMembers() > 0
    local inRaid = GetNumRaidMembers() ~= 0
    if not inParty and not inRaid then
        Log("|cffff0000[RaidDominion]|r Debes estar en grupo para crear una banda.")
        return
    end
    if not inRaid then
        if not IsPartyLeader() then
            Log("|cffff0000[RaidDominion]|r Solo el líder del grupo puede convertir a banda.")
            return
        end
        ConvertToRaid()
        Log("|cff00ff00[RaidDominion]|r El grupo ahora es una banda.")
    end
    local dialogs = RD.ui and RD.ui.dialogs
    if not dialogs then return end
    local mm = RD.modules and RD.modules.messageManager

    -- Diferir la siguiente pregunta: StaticPopup no se re-muestra si el popup
    -- anterior todavía está cerrándose (como resolvía el addon base).
    local function Defer(fn)
        if mm and mm.Schedule then
            mm:Schedule(0.1, fn)
        else
            fn()
        end
    end

    -- Paso a paso (como la base): ¿heroico? -> ¿tamaño? -> fijar dificultad
    local function AskSize(heroic)
        Defer(function()
            dialogs:ShowConfirmDialog({
                text = "¿De cuántos jugadores?",
                acceptText = "10",
                cancelText = "25",
                onAccept = function() ApplyRaidDifficulty(10, heroic) end,
                onCancel = function() ApplyRaidDifficulty(25, heroic) end,
            })
        end)
    end
    dialogs:ShowConfirmDialog({
        text = "¿Deseas activar el modo heroico?",
        acceptText = "Sí",
        cancelText = "No",
        onAccept = function() AskSize(true) end,
        onCancel = function() AskSize(false) end,
    })
end

-- Clic derecho en "Modo de Raid": solicita al líder las asignaciones
-- (roles/abilities/buffs/auras) vía el protocolo addon-a-addon.
local function HandleRaidModeRight()
    if not InParty() and not InRaid() then
        Log("|cffff0000[RaidDominion]|r Debes estar en grupo para solicitar asignaciones.")
        return
    end
    if IsRaidLeader() or (not InRaid() and IsPartyLeader()) then
        Log("|cff00ff00[RaidDominion]|r Eres el líder. Los miembros del grupo pueden solicitar asignaciones con clic derecho.")
        return
    end
    local comm = RD.comm
    if not comm or not comm.RequestAssignments then
        Log("|cffff0000[RaidDominion]|r La comunicación entre addons no está disponible.")
        return
    end
    if comm:RequestAssignments() then
        Log("|cff00ff00[RaidDominion]|r Solicitando asignaciones al líder...")
    end
end

-- ============ Discord ============
local function GetDiscordLink()
    return (RD.config and RD.config.Get and RD.config:Get("chat.discordLink", "")) or ""
end

local function HandleDiscordEdit()
    -- Aviso de preparación por la salida por defecto antes de abrir el editor
    if RD.messageManager and RD.messageManager.SendMessage then
        RD.messageManager:SendMessage("=== PREPARANDO DISCORD ===")
    end
    local dialogs = RD.ui and RD.ui.dialogs
    if dialogs and dialogs.ShowDiscordEditPopup then
        dialogs:ShowDiscordEditPopup()
    else
        Log("|cffff8000[RaidDominion]|r Configura el enlace de Discord con /rd discord <enlace>.")
    end
end

local function HandleDiscord()
    local link = GetDiscordLink()
    if link ~= "" then
        -- Anuncio de banda en DOS renglones: título y enlace por separado
        -- (=== DISCORD === / <enlace>), por la salida por defecto.
        if RD.messageManager and RD.messageManager.SendMessage then
            RD.messageManager:SendMessage("=== DISCORD ===")
            RD.messageManager:SendMessage(link)
        end
    else
        HandleDiscordEdit()
    end
end

-- ============ Nombrar objetivo ============
local function HandleNameTarget()
    if not UnitExists("target") then
        Log("|cffff0000[RaidDominion]|r No hay ningún objetivo seleccionado.")
        return
    end
    if RD.messageManager then RD.messageManager:SendMessage(UnitName("target")) end
end

-- Entrega toda la información del objetivo formateada como el addon base
local function HandleTargetInfo()
    if not UnitExists("target") then
        Log("|cffff0000[RaidDominion]|r No hay ningún objetivo seleccionado.")
        return
    end
    local info = {}
    info.name = UnitName("target")
    info.health = UnitHealth("target")
    info.healthMax = UnitHealthMax("target")
    info.healthPct = info.healthMax > 0 and math.floor((info.health / info.healthMax) * 100) or 0
    info.level = UnitLevel("target")
    info.classification = UnitClassification("target")
    info.classLocalized = select(1, UnitClass("target")) or ""
    local powerType = select(1, UnitPowerType("target"))
    info.power = UnitPower("target", powerType)
    info.powerMax = UnitPowerMax("target", powerType)
    info.powerPct = (info.powerMax or 0) > 0 and math.floor((info.power / info.powerMax) * 100) or 0

    local classifText = ""
    if info.classification == "elite" or info.classification == "rareelite" then
        classifText = " (Elite)"
    elseif info.classification == "rare" then
        classifText = " (Raro)"
    elseif info.classification == "worldboss" then
        classifText = " (Jefe Mundial)"
    end
    local levelText = (info.level == -1) and "??" or tostring(info.level)

    local messages = {}
    table.insert(messages, string.format("%s [Nivel %s %s%s]", info.name or "", levelText,
        (info.classLocalized ~= "" and info.classLocalized ~= info.name) and info.classLocalized or "", classifText))
    local line2 = string.format("Salud: %d/%d [%d%%]", info.health or 0, info.healthMax or 0, info.healthPct)
    if powerType == 0 then -- Mana
        if (info.powerMax or 0) > 0 then
            line2 = line2 .. string.format(" //  Mana: %d/%d [%d%%]", info.power or 0, info.powerMax or 0, info.powerPct)
        end
    elseif powerType == 3 then -- Energía
        if (info.powerMax or 0) > 0 then
            line2 = line2 .. string.format(" //  Energia: %d/%d [%d%%]", info.power or 0, info.powerMax or 0, info.powerPct)
        end
    elseif powerType == 1 then -- Ira
        if (info.powerMax or 0) > 0 then
            line2 = line2 .. string.format(" // Ira: %d/%d [%d%%]", info.power or 0, info.powerMax or 0, info.powerPct)
        end
    end
    table.insert(messages, line2)

    local mm = RD.modules and RD.modules.messageManager
    if mm then
        mm:SendSequence(messages, 0.1)
    end
end

-- ============ Marcar principales ============
local function HandleMarkMains()
    if not InRaid() then
        Log("|cffff0000[RaidDominion]|r Debes estar en banda para marcar principales.")
        return
    end
    local assign = RD.utils and RD.utils.assignments
    if not assign then return end
    local roleAssign = assign:Get("roles")
    if not roleAssign or next(roleAssign) == nil then
        Log("|cffff8000[RaidDominion]|r No hay roles asignados. Asigna objetivos en el menú Roles.")
        return
    end

    -- Mapa nombre limpio -> unit de raid. Como el addon base, se marca con
    -- SetRaidTarget(unit, icon) usando la unidad "raidN", no el índice del roster.
    local unitByName = {}
    for i = 1, GetNumRaidMembers() do
        local unit = "raid" .. i
        local name = UnitName(unit)
        if name then unitByName[CleanName(name)] = unit end
    end

    -- Recoger jugadores con rol de tanque o sanador presente en la raid
    local players = {}
    for itemName, player in pairs(roleAssign) do
        local unit = unitByName[CleanName(player)]
        if unit then
            local up = tostring(itemName):upper()
            local isTank = up:find("TANK", 1, true) ~= nil
            local isHealer = up:find("HEAL", 1, true) ~= nil
            if isTank or isHealer then
                players[#players + 1] = { name = player, unit = unit, role = up, isTank = isTank, isHealer = isHealer }
            end
        end
    end

    -- Orden estable: tanques primero, luego sanadores (como el addon base)
    table.sort(players, function(a, b)
        if a.isTank and not b.isTank then return true end
        if not a.isTank and b.isTank then return false end
        return a.name < b.name
    end)

    -- Iconos de marcado de raid (3.3.5a): 1 estrella, 2 círculo, 3 luna,
    -- 4 triángulo, 5 rombo, 6 cuadrado, 7 verde, 8 calavera. Reserva del base.
    local availableIcons = { 2, 3, 4, 5, 6, 7, 8 }
    local iconIndex = 1
    local tanks, healers = {}, {}
    ClearAllRaidIcons()
    for _, p in ipairs(players) do
        local icon = availableIcons[iconIndex]
        if icon and UnitExists(p.unit) and not UnitIsDeadOrGhost(p.unit) then
            iconIndex = iconIndex + 1
            SetRaidTarget(p.unit, icon)
            if p.role:find("MAIN TANK", 1, true) then
                tanks[1] = "{rt" .. icon .. "} MAIN TANK"
            elseif p.role:find("OFF TANK", 1, true) then
                tanks[2] = "{rt" .. icon .. "} OFF TANK"
            elseif p.isHealer then
                healers[#healers + 1] = "{rt" .. icon .. "}"
            end
        end
    end

    -- Mensaje apropiado (formato del addon base, con marcadores de icono {rtN})
    local messages = {}
    local tanksStr = {}
    if tanks[1] then tanksStr[#tanksStr + 1] = tanks[1] end
    if tanks[2] then tanksStr[#tanksStr + 1] = tanks[2] end
    if #tanksStr > 0 then messages[#messages + 1] = table.concat(tanksStr, " // ") end
    if #healers > 0 then messages[#messages + 1] = "HEALERS: " .. table.concat(healers, " ") end
    if #messages > 0 then
        -- Canal por defecto (GetChannel): con config DEFAULT y siendo líder de
        -- banda resuelve a RAID_WARNING (aviso de banda), no hardcodear "RAID".
        if RD.messageManager and RD.messageManager.SendSequence then
            RD.messageManager:SendSequence(messages, 0.5)
        else
            for _, m in ipairs(messages) do
                if RD.messageManager then RD.messageManager:SendMessage(m) end
            end
        end
    else
        Log("|cffff8000[RaidDominion]|r No se encontraron tanques/curas asignados en la banda.")
    end
end

local function HandleClearMarks()
    ClearAllRaidIcons()
    Log("|cff00ff00[RaidDominion]|r Marcas de banda limpiadas.")
end

-- ============ Susurrar asignaciones ============
local function HandleWhisperAssignments()
    local assign = RD.utils and RD.utils.assignments
    if not assign then return end

    -- Solo susurrar a miembros del grupo/banda actual (como el addon base)
    local members = {}
    if InRaid() then
        for i = 1, GetNumRaidMembers() do
            local name = GetRaidRosterInfo(i)
            if name then members[name] = true end
        end
    elseif InParty() then
        for i = 1, GetNumPartyMembers() do
            local name = UnitName("party" .. i)
            if name then members[name] = true end
        end
    end
    members[UnitName("player")] = true

    local lists = { "roles", "abilities", "buffs", "auras" }
    local perPlayer = {}
    for _, listKey in ipairs(lists) do
        local tbl = assign:Get(listKey)
        if type(tbl) == "table" then
            for itemName, player in pairs(tbl) do
                if player and members[player] then
                    perPlayer[player] = perPlayer[player] or {}
                    table.insert(perPlayer[player], itemName)
                end
            end
        end
    end
    local count = 0
    for player, items in pairs(perPlayer) do
        SendChatMessage("Tus asignaciones: " .. table.concat(items, ", "), "WHISPER", nil, player)
        count = count + 1
    end
    if count == 0 then
        Log("|cffff8000[RaidDominion]|r No hay asignaciones para susurrar.")
    else
        Log(string.format("|cff00ff00[RaidDominion]|r Asignaciones susurradas a %d jugadores.", count))
    end
end

-- ============ Iniciar Check ============
-- Al invocar alerta "¡ATENTOS!", pregunta los segundos (como el pull) y delega
-- en RD.modules.readyCheck, que lanza el DoReadyCheck, emite el conteo por CHAT
-- (ticks 9s..., 5s... ¡RESPONDAN AHORA!...) y anuncia al final quién respondió
-- / rechazó / no respondió / AFK / desconectado.
local function HandleReadyCheck()
    local dialogs = RD.ui and RD.ui.dialogs
    local rc = RD.modules and RD.modules.readyCheck
    if not dialogs or not rc then return end
    local mm = RD.modules and RD.modules.messageManager

    -- Al invocar el check se alerta de inmediato "¡ATENTOS!" por el canal
    -- configurado; luego el diálogo pide los segundos y arranca el conteo.
    if mm then
        mm:SendMessage("=== ¡ATENTOS! ===")
    end

    -- Diferir la siguiente pregunta para que el StaticPopup termine de cerrarse
    local function Defer(fn)
        if mm and mm.Schedule then
            mm:Schedule(0.1, fn)
        else
            fn()
        end
    end

    Defer(function()
        dialogs:ShowInputDialog({
            text = "Ingresa los segundos para el ready check (ej: 30):",
            acceptText = "Iniciar",
            cancelText = "Cancelar",
            maxLetters = 2,
            onShow = function(self)
                if self.editBox and self.editBox.SetNumeric then self.editBox:SetNumeric(true) end
                self.editBox:SetText("30")
                self.editBox:SetFocus()
            end,
            onAccept = function(value)
                local seconds = tonumber(value or "") or 0
                if seconds > 0 then
                    rc:Start(seconds)
                else
                    Log("|cffff0000[RaidDominion]|r Check cancelado: tiempo inválido.")
                end
            end,
            onCancel = function()
                Log("|cff00ff00[RaidDominion]|r Check cancelado.")
            end,
        })
    end)
end

local function HandleReportAbsent()
    if not InRaid() then
        Log("|cffff0000[RaidDominion]|r Debes estar en banda para reportar ausentes.")
        return
    end
    local ok, result = pcall(function()
        local notReady = {}
        for i = 1, GetNumRaidMembers() do
            local name = GetRaidRosterInfo(i)
            if name and GetReadyCheckStatus then
                local status = GetReadyCheckStatus("raid" .. i)
                if status and status ~= "ready" then
                    table.insert(notReady, name)
                end
            end
        end
        return notReady
    end)
    local notReady = ok and result or {}
    if not ok then
        if RD.messageManager then
            RD.messageManager:SendMessage("=== CHECK === ¿Quién falta? Reporta a los ausentes.")
        end
        return
    end
    if #notReady > 0 then
        if RD.messageManager then
            RD.messageManager:SendMessage("=== CHECK === Ausentes: " .. table.concat(notReady, ", "))
        end
    else
        Log("|cff00ff00[RaidDominion]|r Todos listos.")
    end
end

-- ============ Iniciar Pull ============
local function StartPullCountdown(seconds)
    local mm = RD.modules and RD.modules.messageManager
    if not mm then return end
    local n = tonumber(seconds) or 10
    if n < 1 then n = 1 end
    if n > 30 then n = 30 end
    -- Canal por defecto (GetChannel): config DEFAULT + líder de banda => RAID_WARNING.
    local ch = mm:GetChannel()
    -- Primer mensaje: "=== PULL DE Ns INICIADO POR <JUGADOR> ===" (nombre en
    -- mayúsculas). Cada mensaje se programa a su SEGUNDO EXACTO respecto al
    -- inicio del pull (contador interno): el anuncio en t=0, el primer tick en
    -- t=1, y los puntos clave 5/3/2/1 cuando faltan 5/3/2/1 segundos (t=N-s);
    -- cierra con "¡PULL AHORA!" en t=N. Así no se llena el warning con alertas.
    local pName = UnitName("player") or ""
    local playerName = (pName ~= "" and strupper(pName)) or "?"
    local plan = {}
    local function At(second, text)
        plan[#plan + 1] = { second = second, text = text }
    end
    At(0, string.format("=== PULL DE %ds INICIADO POR %s ===", n, playerName))
    if n > 1 then
        At(1, tostring(n - 1) .. "...")
    end
    for _, s in ipairs({ 5, 3, 2, 1 }) do
        if s < n - 1 then
            At(n - s, tostring(s) .. "...")
        end
    end
    At(n, "¡PULL AHORA!")

    for _, p in ipairs(plan) do
        mm:Schedule(p.second, function()
            mm:SendMessage(p.text, ch)
        end)
    end
end

local function HandlePull()
    local dialogs = RD.ui and RD.ui.dialogs
    if not dialogs then return end
    local mm = RD.modules and RD.modules.messageManager

    -- Al invocar el pull se alerta de inmediato "¡PREPARENSE!" por el canal
    -- configurado; el diálogo decide si se continúa con el conteo (Sí) o no (No).
    if mm then
        mm:SendMessage("=== ¡PREPARENSE! ===")
    end

    -- Diferir la siguiente pregunta para que el StaticPopup termine de cerrarse
    local function Defer(fn)
        if mm and mm.Schedule then
            mm:Schedule(0.1, fn)
        else
            fn()
        end
    end

    -- Cancelar en cualquier paso del flujo: alerta "¡QUE FALTA!" (no se lanza el pull)
    local function AlertQueFalta()
        if mm then
            mm:SendMessage("=== ¡QUE FALTA! ===")
        end
    end

    -- Paso a paso (como la base): ¿confirmar pull? -> ¿tiempo? -> cuenta regresiva
    local function AskPullTime()
        Defer(function()
            dialogs:ShowInputDialog({
                text = "Ingresa los segundos para el pull (ej: 10):",
                acceptText = "Iniciar",
                cancelText = "Cancelar",
                maxLetters = 2,
                onShow = function(self)
                    if self.editBox and self.editBox.SetNumeric then self.editBox:SetNumeric(true) end
                    self.editBox:SetText("10")
                    self.editBox:SetFocus()
                end,
                onAccept = function(value)
                    local seconds = tonumber(value or "") or 0
                    if seconds > 0 then
                        StartPullCountdown(seconds)
                    else
                        Log("|cffff0000[RaidDominion]|r Pull cancelado: tiempo inválido.")
                    end
                end,
                onCancel = function()
                    AlertQueFalta()
                    Log("|cff00ff00[RaidDominion]|r Pull cancelado.")
                end,
            })
        end)
    end

    dialogs:ShowConfirmDialog({
        text = "¿Deseas iniciar el pull?",
        acceptText = "Sí",
        cancelText = "No",
        onAccept = function() AskPullTime() end,
        onCancel = function()
            AlertQueFalta()
            Log("|cff00ff00[RaidDominion]|r Pull cancelado.")
        end,
    })
end

-- ============ Cambiar Botín ============
-- En 3.3.5a GetLootMethod/SetLootMethod usan MINÚSCULAS ("free"/"group"/"master"/
-- "needbeforegreed"). Alterna SOLO entre Maestro despojador y Botín de grupo
-- (como ToggleLootMethod de la v2). Importante: SetLootMethod("master", nombre)
-- necesita el nombre del maestro como 2º argumento; sin él el cambio a master
-- no se aplica (el clic izquierdo "no se daba").
local LOOT_LABELS = {
    group = "Grupo",
    master = "Maestro despojador",
}

local function HandleLootMode()
    if not (IsRaidLeader() or IsPartyLeader()) then
        Log("|cffff0000[RaidDominion]|r Solo el líder puede cambiar el botín.")
        return
    end
    local current = GetLootMethod()
    local next
    if current == "master" then
        SetLootMethod("group")
        next = "group"
    else
        SetLootMethod("master", UnitName("player"))
        next = "master"
    end
    if RD.messageManager then
        RD.messageManager:SendMessage("=== BOTÍN === Método: " .. (LOOT_LABELS[next] or next))
    end
end

local function HandleMasterLooter()
    if not (IsRaidLeader() or IsPartyLeader()) then
        Log("|cffff0000[RaidDominion]|r Solo el líder puede asignar maestro despojador.")
        return
    end
    if not UnitExists("target") then
        Log("|cffff0000[RaidDominion]|r Selecciona al jugador objetivo.")
        return
    end
    local name = UnitName("target")
    SetLootMethod("master")
    if RD.messageManager then
        RD.messageManager:SendMessage("=== BOTÍN === Maestro despojador: " .. name)
    end
end

-- ============ Configuración ============
-- Botón "Configuración" de la barra: abre (o cambia a) la pestaña que
-- corresponde al contexto actual del menú flotante. Permite un "vistazo rápido":
-- si la ventana ya está abierta EN ESA misma pestaña, un segundo clic la oculta;
-- si está abierta en otra pestaña, solo cambia de pestaña. Fuera de un submenú
-- de lista abre "general".
local function HandleConfig()
    local cw = RD.ui and RD.ui.configWindow
    if not cw or not cw.Show then return end
    local tabId = "general"
    local src = RD.ui and RD.ui.menuFrame and RD.ui.menuFrame.currentSource
    if src and src.type == "list" then
        tabId = src.key
    end

    -- Vistazo rápido: ya visible en la pestaña del contexto -> ocultar
    local currentId = (cw.tabs and cw.currentTab and cw.tabs[cw.currentTab] and cw.tabs[cw.currentTab].id) or nil
    if cw.isShown and currentId == tabId then
        cw:Hide()
        return
    end

    cw:Show()
    if cw.SelectTabById then
        cw:SelectTabById(tabId)
    end
end

-- ============ Registro de acciones ============
local Handlers = {
    ActionBarRaidMode          = HandleRaidMode,
    ActionBarRaidModeRight     = HandleRaidModeRight,
    ActionBarDiscord           = HandleDiscord,
    ActionBarDiscordEdit       = HandleDiscordEdit,
    ActionBarNameTarget        = HandleNameTarget,
    ActionBarTargetInfo        = HandleTargetInfo,
    ActionBarMarkMains         = HandleMarkMains,
    ActionBarClearMarks        = HandleClearMarks,
    ActionBarWhisperAssignments = HandleWhisperAssignments,
    ActionBarReadyCheck        = HandleReadyCheck,
    ActionBarReportAbsent      = HandleReportAbsent,
    ActionBarPull              = HandlePull,
    ActionBarLootMode          = HandleLootMode,
    ActionBarMasterLooter      = HandleMasterLooter,
    ActionBarConfig            = HandleConfig,
}
for actionId, handler in pairs(Handlers) do
    if RD.MenuActions and RD.MenuActions.Register then
        RD.MenuActions:Register(actionId, handler)
    end
end

RD.modules = RD.modules or {}
RD.modules.actionBar = {}
return RD.modules.actionBar
