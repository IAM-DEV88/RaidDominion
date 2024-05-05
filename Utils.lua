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
        raidInfo = {} -- Reinicializar raidInfo
        addonCache = {} -- Reinicializar addonCache
        local _, englishClass = UnitClass("player")
        addonCache[UnitName("player")] = {
            class = englishClass,
            rol = {}
        } -- Reinicializar Cache
    else
        addonCache = raidInfo

        for i = 1, numberOfPlayers do
            local unit = GetNumRaidMembers() ~= 0 and "raid" .. i or "party" .. i
            local playerName = UnitName(unit)
            local playerClass = select(2, UnitClass(unit)) -- Cambiado para obtener solo el nombre de la clase
            if playerName then
                if addonCache[playerName] then
                    addonCache[playerName].rol = addonCache[playerName].rol or {}
                else
                    addonCache[playerName] = {
                        class = playerClass,
                        rol = {}
                    }
                end
            end
        end

        -- Ahora asegurémonos de que el jugador actual tenga roles asignados
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
    local raidMembers = {
        ["MAIN TANK"] = {},
        ["OFF TANK"] = {},
        ["HEALER"] = {},
        ["DPS"] = {}
    }
    local nonDpsMembers = {}

    -- Recoger a los miembros de la raid y sus roles
    for playerName, playerData in pairs(raidInfo) do
        local playerClass = playerData.class or ""
        local roles = playerData.rol or {"DPS"} -- Assume DPS if not specified
        playerClass = string.upper(string.sub(playerClass, 1, 1)) .. string.lower(string.sub(playerClass, 2))
        local isDps = true
        for role, _ in pairs(roles) do
            local formattedName = playerClass .. " " .. playerName
            if role == "MAIN TANK" or role == "OFF TANK" then
                raidMembers[role][formattedName] = true
                nonDpsMembers[formattedName] = true
                isDps = false
            elseif role:find("^HEALER ") then
                raidMembers["HEALER"][formattedName] = true
                nonDpsMembers[formattedName] = true
                isDps = false
            end
        end
        if isDps and not nonDpsMembers[playerName] then
            raidMembers["DPS"][playerClass .. " " .. playerName] = true
        end
    end

    function keysToArray(inputTable)
        local array = {}
        for key, _ in pairs(inputTable) do
            table.insert(array, key)
        end
        return array
    end

    -- Construir mensajes por cada grupo de roles
    local tankMessage = ""
    local healerMessage = ""
    local dpsMessage = ""
    if next(raidMembers["MAIN TANK"]) then
        tankMessage = "MAIN TANK: " .. table.concat(keysToArray(raidMembers["MAIN TANK"]), ", ")
    end
    if next(raidMembers["OFF TANK"]) then
        local offTankMsg = "OFF TANK: " .. table.concat(keysToArray(raidMembers["OFF TANK"]), ", ")
        tankMessage = (tankMessage ~= "" and tankMessage .. " - " or "") .. offTankMsg
    end
    if next(raidMembers["HEALER"]) then
        healerMessage = "HEALER: " .. table.concat(keysToArray(raidMembers["HEALER"]), ", ")
    end
    if next(raidMembers["DPS"]) then
        dpsMessage = "DPS: " .. table.concat(keysToArray(raidMembers["DPS"]), ", ")
    end

    local _, channel = getPlayerInitialState()

    local guildRaid = (channel == "RAID_WARNING") and
                          {"{rt1} Atentos quienes se quedan a lotear", "{rt8} [https://github.com/IAM-DEV88/QuickName] {rt8}"} or
                          {"Nos vemos ^^"}

    local messages = {"Gracias a todos!", tankMessage, healerMessage, dpsMessage}
    if channel == "RAID_WARNING" then
        for _, msg in ipairs(guildRaid) do
            table.insert(messages, msg)
        end
    end

    SendDelayedMessages(messages)
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
                table.insert(raidMembers["BUFF"], playerClass .. " " .. playerName .. " [" .. rolesString .. "]")
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
