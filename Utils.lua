local enabledPanel = enabledPanel or {}


function getPlayerInitialState()
    -- local defaultChannel = "SAY"
    local defaultChannel = "GUILD"
    local numberOfPlayers = 0
    local inRaid = GetNumRaidMembers() ~= 0 and true or false
    local playerRol = IsRaidLeader() and "RAID_WARNING" or "RAID"
    local inParty = GetNumPartyMembers() > 0 and true or false
    local inBG = UnitInBattleground("player")

    numberOfPlayers = inRaid and GetNumRaidMembers() or inBG and GetNumRaidMembers() or GetNumPartyMembers()

    defaultChannel = inBG and "BATTLEGROUND" or inRaid and playerRol or inParty and "PARTY" or defaultChannel

    return numberOfPlayers, defaultChannel
end

local addonCache = {}
local currentPlayers = {}

function getPlayersInfo()
    -- Restablecer currentPlayers al inicio de la función
    currentPlayers = {}

    local numberOfPlayers, _ = getPlayerInitialState()
    -- Obtener numJugadores y canal
    if numberOfPlayers == 0 then
        -- Reinicializar estructuras de datos al no estar en grupo
        raidInfo = {}
        local _, englishClass = UnitClass("player")
        local playerName = UnitName("player")
        addonCache[playerName] = {
            class = englishClass,
            rol = {}
        }
        currentPlayers[playerName] = true
    else
        addonCache = raidInfo
        -- Marcar jugadores actuales como presentes
        for i = 1, numberOfPlayers do
            local unit = GetNumRaidMembers() ~= 0 and "raid" .. i or "party" .. i
            local playerName = UnitName(unit)
            if playerName then
                currentPlayers[playerName] = true
                if addonCache[playerName] then
                    addonCache[playerName].rol = addonCache[playerName].rol or {}
                else
                    local playerClass = select(2, UnitClass(unit))
                    addonCache[playerName] = {
                        class = playerClass,
                        rol = {}
                    }
                end
            end
        end

        -- Asegurarse de añadir la información del player
        local _, englishClass = UnitClass("player")
        local playerName = UnitName("player")
        currentPlayers[playerName] = true
        if addonCache[playerName] then
            addonCache[playerName].rol = addonCache[playerName].rol or {}
        else
            addonCache[playerName] = {
                class = englishClass,
                rol = {}
            }
        end

        -- Limpiar raidInfo y addonCache de jugadores que ya no están en el grupo
        for playerName, playerData in pairs(addonCache) do
            -- Revisa la recientemente asignada addonCache y la coteja con currentPlayers
            if not currentPlayers[playerName] or playerName == "Entidad desconocida" then
                SendSystemMessage(playerName .. " se fue del grupo. Roles liberados: " ..
                                      table.concat(getPlayerRoles(playerData.rol), ", "))
                -- Eliminar el elemento
                raidInfo[playerName] = nil
                addonCache[playerName] = nil
            end
        end

        -- Imprimir el contenido de addonCache para depuración
        -- for playerName, playerInfo in pairs(addonCache) do
        --     SendSystemMessage("Player: " .. playerName)
        --     for key, value in pairs(playerInfo) do
        --         if type(value) == "table" then
        --             SendSystemMessage("  " .. key .. ":")
        --             for role, assigned in pairs(value) do
        --                 SendSystemMessage("    " .. role .. " = " .. tostring(assigned))
        --             end
        --         else
        --             SendSystemMessage("  " .. key .. " = " .. tostring(value))
        --         end
        --     end
        -- end

        updateAllButtons()
    end
    return addonCache
end

function ResetRoleAssignment(roleName, button)
    local _, channel = getPlayerInitialState()
    local addonCache = getPlayersInfo()
    local selectedPlayer = button:GetAttribute("player")
    if selectedPlayer then
        if addonCache[selectedPlayer] and addonCache[selectedPlayer].rol then
            addonCache[selectedPlayer].rol[roleName] = nil
            local playerClass = addonCache[selectedPlayer].class
            playerClass = string.upper(string.sub(playerClass, 1, 1)) .. string.lower(string.sub(playerClass, 2))
            SendSystemMessage("Se retiro al " .. playerClass .. " " .. selectedPlayer .. " del rol de [" .. roleName ..
                                  "]")
            button:SetText(roleName) -- Restaurar el texto original del button
            button:SetAttribute("player", nil)
        end
    else
        local hasTarget = UnitExists("target")
        local targetName = UnitName("target")

        local addonCache = getPlayersInfo()

        local targetInRaid = addonCache[targetName] and true or false

        if hasTarget and targetInRaid then
            addonCache[targetName].rol = addonCache[targetName].rol or {}
            local playerClass = addonCache[targetName].class
            playerClass = string.upper(string.sub(playerClass, 1, 1)) .. string.lower(string.sub(playerClass, 2))
            if not addonCache[targetName].rol[roleName] then
                addonCache[targetName].rol[roleName] = true
                button:SetAttribute("player", targetName)
                button:SetText(playerClass .. " " .. targetName .. "\n" .. roleName) -- Concatenar el nombre del jugador al texto del label
            end
            SendSystemMessage(playerClass .. " " .. targetName .. " [" .. roleName .. "]")
            -- reorderRaidMembers()
        else
            local broadcastCommand = "broadcast timer 00:05 NEED " .. roleName
            SlashCmdList["DEADLYBOSSMODS"](broadcastCommand)
        end
    end
end

function SendRoleAlert(roleName, button)
    local numberOfPlayers, channel = getPlayerInitialState()
    local addonCache = getPlayersInfo()
    local playerName = button:GetAttribute("player")

    local message = ""
    if playerName then
        local unit = "raid" -- Asumir que el jugador está en raid
        if not UnitInRaid("player") then
            unit = "party" -- Si no está en raid, asumir que está en party
        end

        -- Buscar el índice de la unidad
        local unitIndex
        for i = 1, numberOfPlayers do
            local currentUnit = unit .. i
            if UnitName(currentUnit) == playerName then
                unitIndex = i
                break
            end
        end

        -- Si se encuentra la unidad, comprobar si está muerto o vivo
        local playerClass = addonCache[playerName].class
        playerClass = string.upper(string.sub(playerClass, 1, 1)) .. string.lower(string.sub(playerClass, 2))
        if unitIndex then
            local unitFull = unit .. unitIndex
            if UnitIsDeadOrGhost(unitFull) then
                message = "REVIVIR A [" .. playerName .. "] ASAP!"
            else
                message = playerClass .. " " .. playerName .. "[" .. roleName .. "]"
            end
        else
            message = "NEED " .. " [" .. roleName .. "]"
        end
    else
        message = "NEED " .. " [" .. roleName .. "]"
    end

    SendChatMessage(message, "RAID")
end

function table.contains(table, element)
    for _, value in pairs(table) do
        if value == element then
            return true
        end
    end
    return false
end

-- Función para verificar si un jugador tiene piezas de equipamiento con temple
function checkTempleGear(playerName)
    local hasTempleGear = false
    local isChecked = false

    local slots = {"HeadSlot", "NeckSlot", "ShoulderSlot", "BackSlot", "ChestSlot", "WristSlot", "HandsSlot",
                   "WaistSlot", "LegsSlot", "FeetSlot", "Finger0Slot", "Finger1Slot", "Trinket0Slot", "Trinket1Slot",
                   "MainHandSlot", "SecondaryHandSlot", "RangedSlot"}

    -- Nombres de los items que indican la presencia de temple
    local templeItemNames = {"incansable", "colérico", "furioso"}

    if raidInfo[playerName] then
        -- Lista para almacenar los nombres de los items no permitidos
        local templeItemsFound = {}

        -- Iterar sobre los slots de equipamiento
        for _, slot in pairs(slots) do
            local itemLink = GetInventoryItemLink(playerName, GetInventorySlotInfo(slot))
            if itemLink then
                local itemName, _ = GetItemInfo(itemLink)
                -- Comprobar si el nombre del item contiene palabras clave
                for _, keyword in ipairs(templeItemNames) do
                    if string.find(itemName, keyword) then
                        table.insert(templeItemsFound, itemName)
                        hasTempleGear = true
                        break -- Salir del bucle interno, continuar con el siguiente slot
                    end
                end
                isChecked = true
            elseif not itemLink and not isChecked then
                SendSystemMessage("El jugador " .. playerName .. " debe estar cerca para ser inspeccionado")
                SendChatMessage(playerName .. " por favor acercate para inpección.", "WHISPER", nil, playerName)
                break
            end
        end

        -- Si se encontraron items no permitidos, susurrar cada uno de ellos al jugador
        if hasTempleGear and isChecked then
            local counter = 0
            for _, itemName in ipairs(templeItemsFound) do
                counter = counter + 1
                SendChatMessage(itemName, "WHISPER", nil, playerName)
            end
            SendChatMessage("Tienes (" .. counter .. ") parte" .. (counter <= 1 and "" or "s") .. " PVP", "WHISPER",
                nil, playerName)

            if GetNumRaidMembers ~= 0 then
                local numberOfPlayers, _ = getPlayerInitialState()
                local subgroup7Count = 0
                local subgroupForPvp = 7 -- Por defecto asignar al grupo 7

                -- Contar el número de jugadores en el grupo 7
                for i = 1, numberOfPlayers do
                    local _, _, subgroup = GetRaidRosterInfo(i)
                    if subgroup == 7 then
                        subgroup7Count = subgroup7Count + 1
                    end
                end

                -- Si el grupo 7 está lleno (5 jugadores), asignar al grupo 8
                if subgroup7Count >= 5 then
                    subgroupForPvp = 8
                end

                -- Asignar el jugador al grupo correspondiente
                for i = 1, numberOfPlayers do
                    local unit = "raid" .. i
                    local unt = UnitName("raid" .. i)
                    if UnitName(unit) == playerName then
                        SetRaidSubgroup(i, subgroupForPvp)
                    end
                end
            end

            -- Mostrar un popup
            local confirm = StaticPopup_Show("CONFIRM_TEMPLE_GEAR", playerName)
            if confirm then
                confirm.data = playerName -- Pasar el nombre del jugador al popup
            end
        elseif isChecked and not hasTempleGear then
            SendChatMessage("Sin piezas PVP", "WHISPER", nil, playerName)
            SendChatMessage("Muchas gracias " .. playerName, "WHISPER", nil, playerName)
        end
    else
        SendSystemMessage("El jugador " .. playerName .. " no esta en la raid para ser inspeccionado")
    end
end

-- Crear el popup de confirmación
StaticPopupDialogs["CONFIRM_TEMPLE_GEAR"] = {
    text = "El jugador %s tiene piezas de equipamiento con temple. ¿Deseas expulsarlo de la raid?",
    button1 = "Sí",
    button2 = "No",
    OnAccept = function(self, playerName)
        -- Expulsar al jugador de la raid
        SendChatMessage("Te agradezco, en una próxima oportunidad te espero full PVE.", "WHISPER", nil, playerName)
        UninviteUnit(playerName)
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3
}

-- Función para obtener una lista de roles asignados de un jugador
function getPlayerRoles(playerRoles)
    local roles = {}
    for roleName, _ in pairs(playerRoles) do
        table.insert(roles, roleName)
    end
    return roles
end

function updateAllButtons()
    updateButtonsForRoleType("PRIMARIO")
    updateButtonsForRoleType("SECUNDARIO")
    updateButtonsForRoleType("BUFF")
    updateButtonsForRoleType("SKILL")
end

function getAssignedPlayer(roleName)
    for playerName, playerData in pairs(addonCache) do
        if playerData.rol and playerData.rol[roleName] then
            return playerName
        end
    end
end

function updateButtonsForRoleType(roleType)
    local roles = playerRoles[roleType]
    roleType = string.lower(roleType)
    for i, roleName in ipairs(roles) do
        local button = _G[roleType .. "Rol" .. i]
        if button then
            local assignedPlayer = getAssignedPlayer(roleName)
            if assignedPlayer then
                -- SendSystemMessage(assignedPlayer)
                local playerData = addonCache[assignedPlayer]
                if playerData then
                    local playerClass = string.upper(string.sub(playerData.class, 1, 1)) ..
                                            string.lower(string.sub(playerData.class, 2))
                    button:SetText(playerClass .. " " .. assignedPlayer .. "\n" .. roleName)
                    button:SetAttribute("player", assignedPlayer)
                end
            else
                button:SetText(roleName)
                button:SetAttribute("player", nil)
            end
        end
    end
end

function SendSplitMessage(message)
    local maxLength = 255
    local numParts = math.ceil(#message / maxLength)
    local delay = .5 -- Retraso en segundos entre cada parte
    local currentPart = 1
    local _, channel = getPlayerInitialState()

    function SendNextPart()
        local startIdx = (currentPart - 1) * maxLength + 1
        local endIdx = currentPart * maxLength
        local part = message:sub(startIdx, endIdx)

        SendChatMessage(part, channel)

        currentPart = currentPart + 1
        if currentPart <= numParts then
            -- Programamos el siguiente envío de parte después del retraso
            local frame = CreateFrame("Frame")
            frame:SetScript("OnUpdate", function(self, elapsed)
                delay = delay - elapsed
                if delay <= 0 then
                    SendNextPart()
                    self:SetScript("OnUpdate", nil)
                end
            end)
        end
    end

    SendNextPart()
end

function SendDelayedMessages(messages, wispHowTo)
    local index = 1
    local frame = CreateFrame("Frame")
    frame.delay = 0 -- Iniciar retraso para el primer mensaje

    frame:SetScript("OnUpdate", function(self, elapsed)
        self.delay = self.delay - elapsed
        if self.delay <= 0 then
            if index <= #messages then
                if wispHowTo then
                    SendSystemMessage(messages[index])
                else
                    SendSplitMessage(messages[index])
                end
                index = index + 1
                self.delay = .1 -- Resetear retraso para el próximo mensaje
            end
            if index > #messages then
                self:SetScript("OnUpdate", nil) -- Detener el OnUpdate para evitar que siga ejecutándose
            end
        end
    end)
end

-- Definir el diálogo de confirmación para el Ready Check
StaticPopupDialogs["CONFIRM_READY_CHECK"] = {
    text = "¿Deseas iniciar un check de banda?",
    button1 = "Sí",
    button2 = "No",
    OnAccept = function()
        -- Función que se llama cuando el jugador acepta el check de banda
        DoReadyCheck()
        SendChatMessage("SI CONFIRMAN TODOS MANDO PULL", "RAID_WARNING")
        SlashCmdList["DEADLYBOSSMODS"]("broadcast timer 0:10 RAIDCHECK Y PULL")
        StaticPopup_Show("CONFIRM_PULL_COUNTDOWN")
    end,
    OnCancel = function()
        -- Función que se llama cuando el jugador cancela el check de banda
        -- SendChatMessage("POR FAVOR, ESPEREN", "RAID_WARNING")
        SlashCmdList["DEADLYBOSSMODS"]("broadcast timer 0:20 ¿QUE FALTA?")
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3 -- Evita problemas de tainting
}

-- Definir el diálogo de confirmación para el pull
StaticPopupDialogs["CONFIRM_PULL_COUNTDOWN"] = {
    text = "¿Deseas iniciar la cuenta regresiva de 10 segundos para el pull?",
    button1 = "Sí",
    button2 = "No",
    OnAccept = function()
        -- Ejecutar el comando de DBM para iniciar la cuenta regresiva
        SendChatMessage("SOLO EL TANQUE PULEA", "RAID_WARNING")
        SlashCmdList["DEADLYBOSSMODS"]("broadcast timer 0:10 RESPETAR PULL")
        SlashCmdList["DEADLYBOSSMODS"]("pull 10")
    end,
    OnCancel = function()
        -- Función que se llama cuando el jugador cancela el check de banda
        SendChatMessage("ESPEREN", "RAID_WARNING")
        SlashCmdList["DEADLYBOSSMODS"]("broadcast timer 0:10 PULL CANCELADO")
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3 -- Evita problemas de tainting
}

function WpLoot()
    local _, channel = getPlayerInitialState()

    local signatureMessage = (channel == "RAID_WARNING") and
                                 {"{rt8} Interesados en probar el addon // https://github.com/IAM-DEV88/RaidDominion/archive/refs/heads/main.zip {rt8}",
                                  "{rt1} Atentos quienes se quedan a lotear"} or {"Nos vemos"}

    local thanksMessage = {"Gracias a todos!"}
    if channel == "RAID_WARNING" or channel == "PARTY" then
        for _, msg in ipairs(signatureMessage) do
            table.insert(thanksMessage, msg)
        end
    end

    SendDelayedMessages(thanksMessage)
end

function RequestBuffs()
    local raidMembers = {
        ["BUFF"] = {}
    }

    -- Recoger a los miembros de la raid y sus roles de raidInfo
    for playerName, playerData in pairs(raidInfo) do
        local playerClass = playerData.class
        local roles = playerData.rol or {"DPS"} -- Obtener los roles del jugador
        if playerClass then
            playerClass = string.upper(string.sub(playerClass, 1, 1)) .. string.lower(string.sub(playerClass, 2)) -- Capitalizar la primera letra de playerClass
            local playerRoles = {} -- Almacena los roles del jugador
            for role, _ in pairs(roles) do -- Iterar sobre los roles del jugador
                if not role:find("DPS") then
                    table.insert(playerRoles, role)
                end
            end

            -- Concatenar los roles asignados a un solo jugador
            if #playerRoles > 0 then
                local rolesString
                if #playerRoles == 1 then
                    rolesString = playerRoles[1]
                elseif #playerRoles >= 2 and playerClass == "Paladin" then
                    rolesString = table.concat(playerRoles, ", ", 1, #playerRoles - 1) .. " o " ..
                                      playerRoles[#playerRoles]
                else -- si no es paladin solo debe concatenar con comas y "y" para el ultimo
                    rolesString = table.concat(playerRoles, ", ", 1, #playerRoles - 1) .. " y " ..
                                      playerRoles[#playerRoles]
                end

                -- Convertir la tabla de roles a una cadena para usar find
                local rolesStr = table.concat(playerRoles, ",")

                -- Añadir "SEGUN SE REQUIERA" si hay más de un rol
                if #playerRoles > 1 and playerClass == "Paladin" then
                    rolesString = rolesString .. " SEGUN CLASE"
                end

                -- Seleccionar aleatoriamente el ícono
                local icon = math.random(2, 8)

                -- Asignar el ícono como marcador de objetivo para el jugador
                if rolesStr:find("MAIN TANK") or rolesStr:find("OFF TANK") or rolesStr:find("HEALER") then
                    SetRaidTarget(playerName, icon)
                end

                -- Añadir al mensaje del jugador con ícono y roles
                table.insert(raidMembers["BUFF"], {playerName,
                                                   "{rt" .. icon .. "}" .. " " .. playerClass .. " " .. playerName ..
                    " [" .. rolesString .. "]"})
            end
        end
    end

    local _, channel = getPlayerInitialState()
    SlashCmdList["DEADLYBOSSMODS"]("broadcast timer 0:20 APLICAR BUFFS")

    SendChatMessage("Susurro asignaciones de roles y buffs", "RAID_WARNING")

    -- Enviar susurros a cada jugador
    for _, playerInfo in ipairs(raidMembers["BUFF"]) do
        local playerName = playerInfo[1]
        local message = playerInfo[2]
        SendChatMessage(message .. " -- Mensaje de RaidDominion", "WHISPER", nil, playerName)
    end

    -- Mostrar el diálogo de confirmación para el Ready Check
    -- StaticPopup_Show("CONFIRM_READY_CHECK")

end

function GetDistanceBetweenUnits(unit1, unit2)
    local x1, y1 = GetPlayerMapPosition(unit1)
    local x2, y2 = GetPlayerMapPosition(unit2)

    if not x1 or not x2 then
        return nil
    end

    local dx = x2 - x1
    local dy = y2 - y1

    return math.sqrt(dx * dx + dy * dy) * 100
end

function CheckDistance(unit)
    local distance = GetDistanceBetweenUnits("player", unit)
    return distance and distance <= 27
end

StaticPopupDialogs["TIMER_INPUT_POPUP"] = {
    text = "Tiempo en segundos y etiqueta del timer:",
    button1 = "Aceptar",
    button2 = "Cancelar",
    hasEditBox = true,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
    OnShow = function(self)
        self.editBox:SetText("")
    end,
    OnAccept = function(self, data)
        local timerInput = self.editBox:GetText()
        local broadcastCommand = "broadcast timer 00:" .. timerInput
        if data and data.targetName then
            broadcastCommand = broadcastCommand .. " " .. data.targetName
        end
        SlashCmdList["DEADLYBOSSMODS"](broadcastCommand)
    end,
    EditBoxOnEnterPressed = function(self)
        local parent = self:GetParent()
        local timerInput = self:GetText()
        local broadcastCommand = "broadcast timer 00:" .. timerInput
        if parent.data and parent.data.targetName then
            broadcastCommand = broadcastCommand .. " " .. parent.data.targetName
        end
        SlashCmdList["DEADLYBOSSMODS"](broadcastCommand)
        parent:Hide()
    end
}

function nameTimer()
    local hasTarget = UnitExists("target")
    local targetName = hasTarget and UnitName("target") or nil

    -- mostrar popup para ingresar tiempo
    StaticPopup_Show("TIMER_INPUT_POPUP", nil, nil, {
        targetName = targetName
    })
end

local reason
StaticPopupDialogs["BLACKLIST_POPUP"] = {
    text = "Motivo para agregar a Blacklist:",
    button1 = "Aceptar",
    button2 = "Cancelar",
    hasEditBox = true,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
    OnShow = function(self)
        self.editBox:SetText("")
    end,
    OnAccept = function(self, data)
        local banReason = self.editBox:GetText()
        SlashCmdList["BlackList"](data.targetName .. " " .. banReason)

    end,
    EditBoxOnEnterPressed = function(self)
        local parent = self:GetParent()
        local banReason = self:GetText()
        SlashCmdList["BlackList"](data.targetName .. " " .. banReason)
        parent:Hide()
    end
}

function AlertFarPlayers(AFKTimer)
    local hasTarget = UnitExists("target")
    local _, channel = getPlayerInitialState()
    local targetName = UnitName("target")
    local targetInRaid = raidInfo[targetName] and true or false
    -- Si hay jugador seleccionado envia una alerta con su nombre
    if hasTarget and not AFKTimer then
        SendChatMessage(targetName, channel)
    elseif not AFKTimer then
        local playerNames = "" -- Inicializar la cadena para nombres
        local numberOfPlayers = GetNumRaidMembers() ~= 0 and GetNumRaidMembers() or GetNumPartyMembers()
        local groupType = GetNumRaidMembers() ~= 0 and "raid" or "party"
        local AFKPlayerNum = 0
        for i = 1, numberOfPlayers do
            local unit = groupType .. i
            if not CheckDistance(unit) then
                AFKPlayerNum = AFKPlayerNum + 1
                local playerName = UnitName(unit)
                local playerClass = UnitClass(unit)
                playerClass = string.upper(string.sub(playerClass, 1, 1)) .. string.lower(string.sub(playerClass, 2)) -- Capitalizar la primera letra de playerClass
                if playerName then
                    if playerNames == "" then
                        playerNames = playerClass .. " " .. playerName -- Primera asignación sin separador
                    else
                        playerNames = playerNames .. " / " .. playerClass .. " " .. playerName -- Concatenar con separador
                    end
                end
            end
        end

        SendSystemMessage("Jugadores AFK/OFF o demasiado lejos: " .. AFKPlayerNum)
        SendSystemMessage(playerNames)
    end
    if AFKTimer and hasTarget then
        StaticPopup_Show("BLACKLIST_POPUP", nil, nil, {
            targetName = targetName
        })
    end

end

function reorderRaidMembers()
    if GetNumRaidMembers() > 0 and IsRaidLeader() then
        local numberOfPlayers, _ = getPlayerInitialState()
        local subgroupForHeal = numberOfPlayers > 10 and 5 or 2
        local subgroupForOff = numberOfPlayers > 10 and 3 or 1
        local subgroupForTank = numberOfPlayers > 10 and 4 or 2

        for i = 1, numberOfPlayers do
            local unit = "raid" .. i
            local playerName = UnitName(unit)
            local role = raidInfo[playerName] and raidInfo[playerName].rol

            if role then
                for roleName, _ in pairs(role) do
                    if roleName:match("^HEALER %d$") then
                        SetRaidSubgroup(i, subgroupForHeal)
                        break
                    elseif roleName == "OFF TANK" then
                        SetRaidSubgroup(i, subgroupForOff)
                        break
                    elseif roleName == "MAIN TANK" then
                        SetRaidSubgroup(i, subgroupForTank)
                        break
                    end
                end
            end
        end
    end
end

local isMasterLooter = false
local isHeroicMode = false -- Variable para almacenar si es modo heroico o no
local is25Player = false -- Variable para almacenar si es de 25 jugadores o no

-- Función para configurar la raid según la dificultad
local function configureRaid()
    local difficulty
    if isHeroicMode then
        if is25Player then
            difficulty = 4 -- Raid heroica de 25 jugadores
        else
            difficulty = 3 -- Raid heroica de 10 jugadores
        end
    else
        if is25Player then
            difficulty = 2 -- Raid normal de 25 jugadores
        else
            difficulty = 1 -- Raid normal de 10 jugadores
        end
    end
    SetRaidDifficulty(difficulty)
end

-- Popup para seleccionar el modo heroico
StaticPopupDialogs["HEROIC_MODE_POPUP"] = {
    text = "¿Raid modo heroico?",
    button1 = "Sí",
    button2 = "No",
    OnAccept = function()
        isHeroicMode = true
        -- Preguntar si es de 10 o 25 jugadores
        StaticPopup_Show("PLAYER_NUMBER_POPUP")
    end,
    OnCancel = function()
        isHeroicMode = false
        -- Preguntar si es de 10 o 25 jugadores
        StaticPopup_Show("PLAYER_NUMBER_POPUP")
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3
}

-- Popup para seleccionar el número de jugadores
StaticPopupDialogs["PLAYER_NUMBER_POPUP"] = {
    text = "¿De cuantos jugadores?",
    button1 = "10",
    button2 = "25",
    OnAccept = function()
        is25Player = false
        configureRaid()
    end,
    OnCancel = function()
        is25Player = true
        configureRaid()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3
}

function CreateRaidDominionAboutTabContent(parent)
    local contentScrollFrame = CreateFrame("ScrollFrame", "AboutTab_ContentScrollFrame", parent,
        "UIPanelScrollFrameTemplate")
    contentScrollFrame:SetPoint("TOPLEFT", 10, -55)
    contentScrollFrame:SetPoint("BOTTOMRIGHT", -10, 10)

    local content = CreateFrame("Frame", nil, contentScrollFrame)
    content:SetSize(340, 600) -- Ajusta la altura según la cantidad de contenido
    contentScrollFrame:SetScrollChild(content)

    local instructions = {{"GameFontHighlightSmall", "1. RAID MODO:", 20},
                          {"GameFontNormal", "Convierte el grupo en banda y configura la dificultad.", 20, 390},
                          {"GameFontHighlightSmall", "2. TEMPORIZADOR:", 20}, {"GameFontNormal",
                                                                               "Coloca un marcador de tiempo personalizado para los miembros de la raid. Si tienes un objetivo seleccionado añade el nombre al marcador de tiempo. Ejemplo: ´120 REARMO´",
                                                                               20, 390},
                          {"GameFontHighlightSmall", "3. LEJANOS:", 20}, {"GameFontNormal",
                                                                          "Lista a todos los jugadores que estén lejos de ti. Si tienes un objetivo seleccionado alertará su nombre. Si das clic derecho con objetivo seleccionado pedirá motivo para agregar a blacklist",
                                                                          20, 390},
                          {"GameFontHighlightSmall", "4. BOTIN:", 20},
                          {"GameFontNormal",
                           "Intercambia el modo de botín entre Maestro despojador y Botín de grupo.", 20, 390},
                          {"GameFontHighlightSmall", "5. WISP ROL:", 20},
                          {"GameFontNormal", "Susurra los roles asignados a los jugadores correspondientes.", 20, 390},
                          {"GameFontHighlightSmall", "6. PULL CHECK:", 20},
                          {"GameFontNormal",
                           "Coloca indicadores de tiempo y según el caso, da inicio o cancelación de pull de 10s.",
                           20, 390}, {"GameFontHighlightSmall", "7. BOTÓN DE NOMBRE DE ROL:", 20},
                          {"GameFontNormal", "Indica el estado del rol si está asignado o no.", 20, 390},
                          {"GameFontHighlightSmall", "8. BOTÓN X DE ROL:", 20}, {"GameFontNormal",
                                                                                  "Limpia la asignación de rol. Si ya está vacío inicia un marcador de tiempo con el nombre del rol.",
                                                                                  20, 390},
                          {"GameFontHighlightSmall", "Actualizaciones:", 20}, {"GameFontNormal",
                                                                               "Mantente actualizado con las últimas versiones y soporte del addon. Visita nuestra página oficial para más información y reportes de errores.",
                                                                               20, 390},
                          {"GameFontHighlightSmall", "Donaciones:", 20},
                          {"GameFontNormal",
                           "Apoya el desarrollo continuo del addon mediante donaciones. ¡Gracias por tu apoyo!", 20,
                           390}}

    local currentYOffset = -5 -- Posición vertical inicial

    for _, instruction in ipairs(instructions) do
        local fontString = content:CreateFontString(nil, "ARTWORK", instruction[1])
        fontString:SetText(instruction[2])
        fontString:SetPoint("TOPLEFT", content, "TOPLEFT", instruction[3], currentYOffset)

        if instruction[4] then
            fontString:SetJustifyH("LEFT")
            fontString:SetWidth(instruction[4])
        end

        local _, fontHeight = fontString:GetFont()
        local numExtraLines = math.ceil(#instruction[2] / 70)
        currentYOffset = currentYOffset - fontHeight * (numExtraLines + 1) - 5 -- Actualiza la posición vertical para la siguiente línea
    end

    -- Enlace de GitHub para actualizaciones
    local githubTitle = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    githubTitle:SetText("GitHub:")
    githubTitle:SetPoint("TOPLEFT", content, "TOPLEFT", 20, currentYOffset - 0)
    currentYOffset = currentYOffset - 30 -- Ajusta la posición vertical

    local githubLink = CreateFrame("EditBox", "githubLink", content, "InputBoxTemplate")
    githubLink:SetPoint("TOPLEFT", githubTitle, "BOTTOMLEFT", 0, -5)
    githubLink:SetSize(250, 20)
    githubLink:SetAutoFocus(false)
    githubLink:SetText("https://github.com/IAM-DEV88/RaidDominion")
    githubLink:SetFontObject("ChatFontNormal")
    currentYOffset = currentYOffset - 30 -- Ajusta la posición vertical

    -- Enlace de PayPal para donaciones
    local paypalTitle = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    paypalTitle:SetText("PayPal:")
    paypalTitle:SetPoint("TOPLEFT", content, "TOPLEFT", 20, currentYOffset - 0)
    currentYOffset = currentYOffset - 30 -- Ajusta la posición vertical

    local paypalLink = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
    paypalLink:SetPoint("TOPLEFT", paypalTitle, "BOTTOMLEFT", 0, -5)
    paypalLink:SetSize(250, 20)
    paypalLink:SetAutoFocus(false)
    paypalLink:SetText("paypal.me/iamdev88")
    paypalLink:SetFontObject("ChatFontNormal")
    currentYOffset = currentYOffset - 30 -- Ajusta la posición vertical
end

function ShareDC()
    local discordInput = _G["DiscordLinkInput"]
    local discordLink = discordInput:GetText()

    if discordLink == "" then
        -- Activar la pestaña de opciones y enfocar el input de Discord
        local panel = _G["RaidDominionPanel"]
        if not panel then return end

        PanelTemplates_SetTab(panel, 2)
        _G["RaidDominionRoleTab"]:Hide()
        _G["RaidDominionAboutTab"]:Hide()
        _G["RaidDominionOptionsTab"]:Show()
        
        discordInput:SetFocus()
    else
    SendSystemMessage(discordLink)
    -- Alertar a la banda con el enlace de Discord
        local message = "Enlace de Discord: " .. discordLink
        SendChatMessage(message, "RAID_WARNING")
    end
end

function CreateRaidDominionOptionsTabContent(parent)
    local contentScrollFrame = CreateFrame("ScrollFrame", "OptionsTab_ContentScrollFrame", parent,
        "UIPanelScrollFrameTemplate")
    contentScrollFrame:SetPoint("TOPLEFT", 10, -55)
    contentScrollFrame:SetPoint("BOTTOMRIGHT", -10, 10)

    local content = CreateFrame("Frame", nil, contentScrollFrame)
    content:SetSize(340, 600) -- Ajusta la altura según la cantidad de contenido
    contentScrollFrame:SetScrollChild(content)

    local instructions = {{"GameFontHighlightSmall", "DISCORD", 20}, {"GameFontNormal", "ENLACE:", 20},
                          {"GameFontHighlightSmall", "Mostrar panel al cargar", 20}}

    local currentYOffset = -5 -- Posición vertical inicial

    for _, instruction in ipairs(instructions) do
        local fontString = content:CreateFontString(nil, "ARTWORK", instruction[1])
        fontString:SetText(instruction[2])
        fontString:SetPoint("TOPLEFT", content, "TOPLEFT", instruction[3], currentYOffset)

        if instruction[4] then
            fontString:SetJustifyH("LEFT")
            fontString:SetWidth(instruction[4])
        end

        local _, fontHeight = fontString:GetFont()
        local numExtraLines = math.ceil(#instruction[2] / 70)
        currentYOffset = currentYOffset - fontHeight * (numExtraLines + 1) - 5 -- Actualiza la posición vertical para la siguiente línea
    end

    discordInput = CreateFrame("EditBox", "DiscordLinkInput", content, "InputBoxTemplate")
    discordInput:SetPoint("TOPLEFT", 80, -26) -- Ajusta la posición según sea necesario
    discordInput:SetSize(250, 20)
    discordInput:SetAutoFocus(false)
    discordInput:SetFontObject("ChatFontNormal")
    discordInput:SetText("")

    enabledPanelCheckbox = CreateFrame("CheckButton", nil, DiscordLinkInput, "UICheckButtonTemplate")
    enabledPanelCheckbox:SetPoint("TOPLEFT", 60, -30)

    enabledPanelCheckbox:SetSize(20, 20)
    enabledPanelCheckbox:SetChecked(enabledPanel)
    enabledPanelCheckbox:SetScript("OnClick", function(self)
        enabledPanel = (self:GetChecked() == 1) and true or false
    end)
 return enabledPanel
end

