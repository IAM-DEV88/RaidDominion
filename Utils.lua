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

function getPlayersInfo()
    local numberOfPlayers, channel = getPlayerInitialState()
    -- Lista de jugadores actualmente en el grupo
    local currentPlayers = {}

    if numberOfPlayers == 0 then
        -- Reinicializar las estructuras de datos si no hay jugadores en el grupo
        raidInfo = {}
        local _, englishClass = UnitClass("player")
        raidInfo[UnitName("player")] = {
            class = englishClass,
            rol = {}
        }
        currentPlayers[UnitName("player")] = true
        updateAllButtons()
    else
        -- Actualizar raidInfo con la información del grupo

        -- Actualizar raidInfo con los jugadores actuales
        for i = 1, numberOfPlayers do
            local unit = GetNumRaidMembers() ~= 0 and "raid" .. i or "party" .. i
            local playerName = UnitName(unit)

            if playerName then
                -- SendSystemMessage(playerName)
                currentPlayers[playerName] = true

                if raidInfo[playerName] then
                    raidInfo[playerName].rol = raidInfo[playerName].rol or {}
                else
                    local playerClass = select(2, UnitClass(unit))
                    raidInfo[playerName] = {
                        class = playerClass,
                        rol = {}
                    }
                end
            end
        end

        -- Limpiar raidInfo de jugadores que ya no están en el grupo
        for playerName, playerData in pairs(raidInfo) do
            -- Imprimir mensaje informando sobre el jugador que se fue y los roles que dejó vacantes
            -- end
            if not currentPlayers[playerName] and playerName == "Entidad desconocida" and not playerName ==
                UnitName("player") then
                SendSystemMessage(playerName .. " se fue del grupo. Roles liberados: " ..
                                      table.concat(getPlayerRoles(playerData.rol)))
                -- Eliminar el jugador de raidInfo
                raidInfo[playerName] = nil
            end
        end

        -- Asegurarse de que el jugador actual tenga roles asignados
        local _, englishClass = UnitClass("player")
        local playerName = UnitName("player")
        if raidInfo[playerName] then
            raidInfo[playerName].rol = raidInfo[playerName].rol or {}
        else
            raidInfo[playerName] = {
                class = englishClass,
                rol = {}
            }
        end
        updateAllButtons()
    end
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
    updateButtonsForRoleType("PRIMARY")
    updateButtonsForRoleType("SECONDARY")
    updateButtonsForRoleType("BUFF")
    updateButtonsForRoleType("SKILL")
end

function updateButtonsForRoleType(roleType)
    local roles = playerRoles[roleType]
    roleType = string.lower(roleType)
    for i, roleName in ipairs(roles) do
        local button = _G[roleType .. "Rol" .. i]
        if button then
            local assignedPlayer = getAssignedPlayer(roleName)
            if assignedPlayer then
                local playerData = raidInfo[assignedPlayer]
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
                                 {"{rt8} Interesados en probar el addon // https://github.com/IAM-DEV88/QuickName/archive/refs/heads/main.zip {rt8}",
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
    text = "Tiempo y label para el timer:",
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
    end,
}

function nameTimer()
    local hasTarget = UnitExists("target")
    local targetName = hasTarget and UnitName("target") or nil

    -- mostrar popup para ingresar tiempo
    StaticPopup_Show("TIMER_INPUT_POPUP", nil, nil, { targetName = targetName })
end

local reason
StaticPopupDialogs["BLACKLIST_POPUP"] = {
    text = "Motivo:",
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
    end,
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
        for i = 1, numberOfPlayers do
            local unit = groupType .. i
            if not CheckDistance(unit) then
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

        local messages = {"Jugadores AFK/OFF o lejos del grupo",playerNames,"Presentarse pronto"}

        SendDelayedMessages(messages)
    end
    if AFKTimer and hasTarget then
        StaticPopup_Show("BLACKLIST_POPUP", nil, nil, { targetName = targetName })
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
