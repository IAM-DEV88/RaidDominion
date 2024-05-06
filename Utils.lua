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

    if numberOfPlayers == 0 then
        -- Reinicializar las estructuras de datos si no hay jugadores en el grupo
        raidInfo = {}
        addonCache = {}
        local _, englishClass = UnitClass("player")
        addonCache[UnitName("player")] = {
            class = englishClass,
            rol = {}
        }
        updateAllButtons()
    else
        -- Actualizar addonCache con la información del grupo
        addonCache = raidInfo

        -- Lista de jugadores actualmente en el grupo
        local currentPlayers = {}

        -- Actualizar addonCache con los jugadores actuales
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

        -- Limpiar addonCache de jugadores que ya no están en el grupo
        for playerName, playerData in pairs(addonCache) do
            if not currentPlayers[playerName] then
                -- Imprimir mensaje informando sobre el jugador que se fue y los roles que dejó vacantes
                print(playerName .. " se fue del grupo. Roles liberados: " .. table.concat(getPlayerRoles(playerData.rol), ", "))

                -- Eliminar el jugador de addonCache
                addonCache[playerName] = nil
            end
        end

        -- Asegurarse de que el jugador actual tenga roles asignados
        local _, englishClass = UnitClass("player")
        local playerName = UnitName("player")
        if addonCache[playerName] then
            addonCache[playerName].rol = addonCache[playerName].rol or {}
        else
            addonCache[playerName] = {
                class = englishClass,
                rol = {}
            }
        end
        updateAllButtons()
    end
end

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
                local playerData = addonCache[assignedPlayer]
                if playerData then
                    local playerClass = string.upper(string.sub(playerData.class, 1, 1)) .. string.lower(string.sub(playerData.class, 2))
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

function SendDelayedMessages(messages, readyCheck)
    local index = 1
    local frame = CreateFrame("Frame")
    frame.delay = 0 -- Iniciar retraso para el primer mensaje

    frame:SetScript("OnUpdate", function(self, elapsed)
        self.delay = self.delay - elapsed
        if self.delay <= 0 then
            if index <= #messages then
                SendSplitMessage(messages[index])
                index = index + 1
                self.delay = 1.8 -- Resetear retraso para el próximo mensaje
            end

            if index > #messages and readyCheck then
                self:SetScript("OnUpdate", nil) -- Detener el OnUpdate para evitar que siga ejecutándose

                -- Mostrar el diálogo de confirmación para el Ready Check
                StaticPopup_Show("CONFIRM_READY_CHECK")
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
        StaticPopup_Show("CONFIRM_PULL_COUNTDOWN")
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
        SlashCmdList["DEADLYBOSSMODS"]("pull 10")
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3 -- Evita problemas de tainting
}

function WpLoot()
    local _, channel = getPlayerInitialState()

    local signatureMessage = (channel == "RAID_WARNING") and
                          {"{rt8} Invitados a la Hermandad Culto del Osario {rt8}", "{rt1} https://github.com/IAM-DEV88/QuickName/archive/refs/heads/main.zip {rt1}", "{rt1} Atentos quienes se quedan a lotear"} or
                          {"Nos vemos ^^"}

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

    -- Verificar si el jugador actual está en addonCache y agregarlo si no está presente
    local playerName = UnitName("player")
    if not addonCache[playerName] then
        local _, englishClass = UnitClass("player")
        addonCache[playerName] = {
            class = englishClass,
            rol = addonCache[playerName].rol or {}
        }
    end

    -- Recoger a los miembros de la raid y sus roles de addonCache
    for playerName, playerData in pairs(addonCache) do
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
                local rolesString = table.concat(playerRoles, ", ")
                if #playerRoles > 1 then
                    rolesString = rolesString:gsub(", ([^,]+)$", " y %1") -- Reemplazar la última coma por "y"
                end
                table.insert(raidMembers["BUFF"], "{rt8} " .. playerClass .. " " .. playerName .. " [" .. rolesString .. "]")
            end
        end
    end

    -- Construir mensaje
    local buffMessage = ""
  
    if #raidMembers["BUFF"] > 0 then
        buffMessage = table.concat(raidMembers["BUFF"], ", ")
    end

    local _, channel = getPlayerInitialState()

    local guildRaid = (channel == "RAID_WARNING") and {"{rt1} Todos confirman check y go"} or {""}

    local messages = {"Atentos!", buffMessage}
    if channel == "RAID_WARNING" then
        -- Si estamos en el canal de aviso de la banda, agregamos el mensaje de la banda a los mensajes
        for _, msg in ipairs(guildRaid) do
            table.insert(messages, msg)
        end
    end

    SendDelayedMessages(messages,true)
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

function AlertFarPlayers()
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

    local messages = {"Jugadores AFK/OFF o lejos del grupo", playerNames, "Presentarse pronto por favor"}

    SendDelayedMessages(messages, true)
end

function GetChatPrefix()
    local instanceType = select(2, IsInInstance())
    if instanceType == "none" then
        return "/y " -- Alone
    elseif instanceType == "party" then
        return "/p " -- Party
    elseif instanceType == "raid" then
        local isLeader = IsRaidLeader()
        if isLeader then
            return "/rw " -- RaidLead
        else
            return "/raid " -- RaidMan
        end
    end
end

function HandleClick(playerName, modifierPressed)
    if playerName and modifierPressed then
        local editBox = ChatEdit_ChooseBoxForSend()
        if editBox then
            local currentText = editBox:GetText() or ""
            local newText = currentText .. playerName
            ChatEdit_ActivateChat(editBox)
            local prefix = GetChatPrefix()
            if modifierPressed == "ALT" then
                editBox:SetText(prefix .. newText .. " ")
            elseif modifierPressed == "CONTROL" then
                editBox:SetText("/w " .. playerName .. " " .. currentText)
            elseif modifierPressed == "SHIFT" then
                editBox:SetText(newText .. " ")
            end
        end
    end
end