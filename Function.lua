function getPlayerInitialState()
    local isInGuild = IsInGuild()
    local defaultChannel = isInGuild and "GUILD" or "SAY"

    local numberOfPlayers = 0
    local inParty = GetNumPartyMembers() > 0 and true or false
    local inRaid = GetNumRaidMembers() ~= 0 and true or false

    local playerRol = IsRaidLeader() and "RAID_WARNING" or "RAID"
    local inBG = UnitInBattleground("player")

    numberOfPlayers = inRaid and GetNumRaidMembers() or inBG and GetNumRaidMembers() or GetNumPartyMembers()

    if inBG then
        defaultChannel = "BATTLEGROUND"
    elseif inRaid then
        defaultChannel = playerRol
    elseif inParty then
        defaultChannel = "PARTY"
    end

    return numberOfPlayers, defaultChannel
end

function getPlayerRoles(playerRoles)
    local roles = {}
    for roleName, _ in pairs(playerRoles) do
        table.insert(roles, roleName)
    end
    return roles
end

function getPlayersInfo()
    -- Restablecer currentPlayers al inicio de la función
    currentPlayers = {}

    local numberOfPlayers, _ = getPlayerInitialState()
    -- Obtener numJugadores y canal
    if numberOfPlayers == 0 then
        -- Reinicializar estructuras de datos al no estar en grupo
        raidInfo = {}
        addonCache = {}
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
            if not currentPlayers[playerName] then
                if playerName == "Entidad desconocida" then
                    --
                else
                    SendSystemMessage(playerData.class .. ". Roles liberados: " ..
                                          table.concat(getPlayerRoles(playerData.rol), ", "))
                end
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

    end
    updateAllButtons()
    return addonCache
end

function getAssignedPlayer(roleName)
    for playerName, playerData in pairs(addonCache) do
        if playerData.rol and playerData.rol[roleName] then
            return playerName
        end
    end
end

function updateAllButtons()
    -- Combinar todos los roles en una única tabla con sus identificadores
    local AssignableRoles = {}
    for i, role in ipairs(primaryRoles) do
        table.insert(AssignableRoles, {
            role = role.name,
            idPrefix = "PrimaryRole",
            index = i
        })
    end
    for i, role in ipairs(secondaryRoles) do
        table.insert(AssignableRoles, {
            role = role.name,
            idPrefix = "SecondaryRole",
            index = i
        })
    end
    for i, buff in ipairs(primaryBuffs) do
        table.insert(AssignableRoles, {
            role = buff.name,
            idPrefix = "BUFFs",
            index = i
        })
    end
    for i, skill in ipairs(primarySkills) do
        table.insert(AssignableRoles, {
            role = skill.name,
            idPrefix = "PrimarySkill",
            index = i
        })
    end

    -- Iterar sobre todos los roles asignables y actualizar los botones
    for _, data in ipairs(AssignableRoles) do
        local buttonName = data.idPrefix .. "Assignable" .. data.index
        local button = _G[buttonName]
        if button then
            local assignedPlayer = getAssignedPlayer(data.role)
            if assignedPlayer then
                button:SetText(assignedPlayer .. " [" .. data.role .. "]")
                button:SetAttribute("player", assignedPlayer)
            else
                button:SetText(data.role)
                button:SetAttribute("player", nil)
            end
        end
    end
end

function ResetRoleAssignment(roleName, button)
    local selectedPlayer = button:GetAttribute("player")
    if selectedPlayer then
        if addonCache[selectedPlayer] and addonCache[selectedPlayer].rol then
            addonCache[selectedPlayer].rol[roleName] = nil
        end
        button:SetText(roleName) -- Restaurar el texto original del button
        button:SetAttribute("player", nil)
        button:SetBackdrop({})
        button:SetTextColor(1, 1, 1, 1) -- Cambiar el color del texto a blanco

        SendSystemMessage("Se retiró a " .. selectedPlayer .. " del rol de [" .. roleName .. "]")
    else
        local hasTarget = UnitExists("target")
        local targetName = UnitName("target")
        local targetInRaid = addonCache[targetName] and true or false

        if hasTarget and targetInRaid then
            addonCache[targetName].rol = addonCache[targetName].rol or {}
            local playerClass = addonCache[targetName].class
            playerClass = string.upper(string.sub(playerClass, 1, 1)) .. string.lower(string.sub(playerClass, 2))
            if not addonCache[targetName].rol[roleName] then
                addonCache[targetName].rol[roleName] = true
                button:SetAttribute("player", targetName)
                button:SetText(targetName .. " [" .. roleName .. "]") -- Concatenar el nombre del jugador al texto del label
                button:SetBackdrop({
                    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
                })
                button:SetBackdropColor(0, 0, 0, 0.8)
                button:SetTextColor(1, 1, 1, 1) -- Cambiar el color del texto a blanco

                SendSystemMessage(playerClass .. " " .. targetName .. " [" .. roleName .. "]")
            end
        else
            SendSystemMessage("Para asignar un rol seleccione un jugador de la banda o grupo.")
        end
    end
end


function SendRoleAlert(roleName, player)
    local numberOfPlayers, defaultChannel = getPlayerInitialState()
    local playerName = player

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
        if unitIndex then
            local unitFull = unit .. unitIndex
            if UnitIsDeadOrGhost(unitFull) then
                message = "REVIVIR A [" .. playerName .. "] ASAP!"
            else
                message = playerName .. " [" .. roleName .. "]"
            end
        else
            message = "NEED" .. " [" .. roleName .. "]"
        end
    else
        message = "NEED" .. " [" .. roleName .. "]"
    end

    -- SendSystemMessage(message, defaultChannel)
    SendChatMessage(message, defaultChannel)
end

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

function AssignIconsAndAlert()
    if IsRaidLeader() then
        local raidMembers = {
            ["ALERT"] = {
                tanks = {},
                healers = {}
            }
        }
        local numberOfPlayers, _ = getPlayerInitialState()
        local availableIcons = {2, 3, 4, 5, 6, 7, 8}
        local iconIndex = 1
        local addonCache = getPlayersInfo()

        local function GetRaidUnitByName(name)
            for i = 1, numberOfPlayers do
                local unit = "raid" .. i
                if UnitName(unit) == name then
                    return unit
                end
            end
            return nil
        end

        local function ShouldAssignIcon(rolesStr)
            local iconRoles = {"MAIN TANK", "HEALER 1", "OFF TANK", "HEALER 2", "HEALER 3", "HEALER 4", "HEALER 5"}
            for _, role in ipairs(iconRoles) do
                if rolesStr:find(role) then
                    return true
                end
            end
            return false
        end

        for playerName, playerData in pairs(addonCache) do
            local roles = playerData.rol or {"DPS"}
            local playerRoles = {}
            for role, _ in pairs(roles) do
                if not role:find("DPS") then
                    table.insert(playerRoles, role)
                end
            end

            if #playerRoles > 0 then
                local rolesString = #playerRoles == 1 and playerRoles[1] or
                                        table.concat(playerRoles, ", ", 1, #playerRoles - 1) .. " y " ..
                                        playerRoles[#playerRoles]
                local rolesStr = table.concat(playerRoles, ",")

                local icon = nil
                if ShouldAssignIcon(rolesStr) and iconIndex <= #availableIcons then
                    icon = availableIcons[iconIndex]
                    iconIndex = iconIndex + 1
                end

                if icon then
                    local raidUnit = GetRaidUnitByName(playerName)
                    if raidUnit and UnitExists(raidUnit) and not UnitIsDeadOrGhost(raidUnit) then
                        SetRaidTarget(raidUnit, icon)
                    else
                        icon = nil
                    end
                end

                if icon then
                    if rolesStr:find("MAIN TANK") then
                        raidMembers["ALERT"].tanks[1] = "{rt" .. icon .. "} MAIN TANK"
                    elseif rolesStr:find("OFF TANK") then
                        raidMembers["ALERT"].tanks[2] = "{rt" .. icon .. "} OFF TANK"
                    elseif rolesStr:find("HEALER") then
                        table.insert(raidMembers["ALERT"].healers, "{rt" .. icon .. "}")
                    end
                end
            end
        end

        -- Verificar si hay al menos un tanque o un healer
        if #raidMembers["ALERT"].tanks > 0 or #raidMembers["ALERT"].healers > 0 then
            local alertMessages = {}

            if #raidMembers["ALERT"].tanks > 0 then
                table.insert(alertMessages, table.concat(raidMembers["ALERT"].tanks, " // "))
            end

            if #raidMembers["ALERT"].healers > 0 then
                table.insert(alertMessages, "HEALERS")
                table.insert(alertMessages, table.concat(raidMembers["ALERT"].healers, " "))
            end
            SendDelayedMessages(alertMessages)
        else
            SendSystemMessage("No hay tanques ni healers asignados.")
        end
    else
        SendSystemMessage("Debe ser lider de grupo o raid.")
    end
end

function WhisperAssignments()
    local raidMembers = {}
    local addonCache = getPlayersInfo()

    for playerName, playerData in pairs(addonCache) do
        local roles = playerData.rol or {"DPS"}
        local playerRoles = {}
        for role, _ in pairs(roles) do
            if not role:find("DPS") then
                table.insert(playerRoles, role)
            end
        end

        if #playerRoles > 0 then
            local rolesString = #playerRoles == 1 and playerRoles[1] or
                                    table.concat(playerRoles, ", ", 1, #playerRoles - 1) .. " y " ..
                                    playerRoles[#playerRoles]
            local rolesStr = table.concat(playerRoles, ",")

            if rolesStr:find("PODERIO") or rolesStr:find("SABIDURIA") then
                rolesString = "SEGÚN REQUIERA CADA CLASE " .. rolesString
            end

            local message = playerName .. " [" .. rolesString .. "]"
            table.insert(raidMembers, {playerName, message})
        end
    end

    for _, playerInfo in ipairs(raidMembers) do
        local playerName = playerInfo[1]
        local message = playerInfo[2]
            SlashCmdList["DEADLYBOSSMODS"]("broadcast timer 0:20 APLICAR BUFFS")
            SendChatMessage(message .. " -- RaidDominion Tools", "WHISPER", nil, playerName)
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

function SendDelayedMessages(messages)
    local index = 1
    local frame = CreateFrame("Frame")
    frame.delay = 0 -- Iniciar retraso para el primer mensaje

    frame:SetScript("OnUpdate", function(self, elapsed)
        self.delay = self.delay - elapsed
        if self.delay <= 0 then
            if index <= #messages then
                SendSplitMessage(messages[index])
                index = index + 1
                self.delay = .1 -- Resetear retraso para el próximo mensaje
            end
            if index > #messages then
                self:SetScript("OnUpdate", nil) -- Detener el OnUpdate para evitar que siga ejecutándose
            end
        end
    end)
end

function ShareDC()
    local discordInput = _G["DiscordLinkInput"]
    local discordLink = discordInput:GetText()
    local broadcastCommand = "broadcast timer 00:30"

    if discordLink == "" then
        -- Activar la pestaña de opciones y enfocar el input de Discord
        local panel = _G["RaidDominionWindow"]
        if not panel then
            return
        end

        RaidDominionWindow:Show()

        PanelTemplates_SetTab(panel, 1)
        _G["RaidDominionAboutTab"]:Hide()
        _G["RaidDominionOptionsTab"]:Show()
        broadcastCommand = broadcastCommand .. " PREPARANDO DC"
        discordInput:SetFocus()
    else
        -- Alertar a la banda con el enlace de Discord
        broadcastCommand = broadcastCommand .. " CONECTEN DC"
        local message = "Enlace de Discord: " .. discordLink
        SendChatMessage(message, "RAID_WARNING")
    end
    SlashCmdList["DEADLYBOSSMODS"](broadcastCommand)
end

function nameTarget()
    local hasTarget = UnitExists("target")
    local targetName = UnitName("target")
    if hasTarget then
        SendDelayedMessages({targetName})
    end
end
