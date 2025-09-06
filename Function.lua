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
                button:SetNormalFontObject("GameFontNormal")
                button:SetText(assignedPlayer .. " [" .. data.role .. "]")
                button:SetAttribute("player", assignedPlayer)
                button:SetBackdrop({
                    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background"
                })
                button:SetBackdropColor(0, 0, 0, 0.8)
            else
                button:SetText(data.role)
                button:SetAttribute("player", nil)
                button:SetNormalFontObject("GameFontHighlight")
                button:SetBackdrop({})
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
        button:SetNormalFontObject("GameFontHighlight")

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
                    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background"
                })
                button:SetNormalFontObject("GameFontNormal")
                button:SetBackdropColor(0, 0, 0, 0.8)

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

-- Definir el diálogo de confirmación para eliminar de la lista negra
StaticPopupDialogs["CONFIRM_REMOVE_BLACKLIST"] = {
    text = "",
    button1 = "Sí",
    button2 = "No",
    OnShow = function(self)
        self.targetName = UnitName("target")
        local reason = GetBlacklistReason(self.targetName) or "Sin razón especificada"
        self.text:SetFormattedText("¿Estás seguro de que deseas eliminar a %s de la lista negra?\nRazón: %s", self.targetName, reason)
    end,
    OnAccept = function(self)
        SlashCmdList["RemoveBlackList"](self.targetName)
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3
}

function GetBlacklistReason(playerName)
    -- Asegurarse de que el nombre tenga la primera letra mayúscula
    playerName = string.upper(string.sub(playerName, 1, 1)) .. string.lower(string.sub(playerName, 2))
    
    -- Verificar si la tabla de jugadores existe para el reino actual
    if not BlackListedPlayers or not BlackListedPlayers[GetRealmName()] then
        return nil, "No hay jugadores en la lista negra"
    end
    
    -- Buscar al jugador en la lista negra
    for _, player in ipairs(BlackListedPlayers[GetRealmName()]) do
        if player.name == playerName then
            return player.reason or "Sin razón especificada"
        end
    end
    
    return nil, "Jugador no encontrado en la lista negra"
end

function AssignIconsAndAlert()
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
        SendChatMessage(message .. " -- Lider de banda", "WHISPER", nil, playerName)
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
                -- SendSystemMessage(messages[index])
                index = index + 1
                self.delay = .1 -- Resetear retraso para el próximo mensaje
            end
            if index > #messages then
                self:SetScript("OnUpdate", nil) -- Detener el OnUpdate para evitar que siga ejecutándose
            end
        end
    end)
end

local function FormatNumber(num)
    if num >= 1000000 then
        return string.format("%.1fM", num / 1000000)
    elseif num >= 1000 then
        return string.format("%.1fK", num / 1000)
    end
    return tostring(num)
end

function showTargetInfo()
    if not UnitExists("target") then
        SendSystemMessage("No hay ningun objetivo seleccionado.")
        return
    end

    local messages = {}
    local targetName = UnitName("target")
    local health = UnitHealth("target")
    local healthMax = UnitHealthMax("target")
    local healthPct = math.floor((health / healthMax) * 100)

    local level = UnitLevel("target")
    local classification = UnitClassification("target")
    local class = UnitClass("target")
    local levelText = (level == -1) and "??" or tostring(level)

    local classifText = ""
    if classification == "elite" or classification == "rareelite" then
        classifText = " (Elite)"
    elseif classification == "rare" then
        classifText = " (Raro)"
    end

    -- Línea 1: Nombre + nivel
    table.insert(messages, string.format("%s [Nivel %s %s%s]",
        targetName,
        levelText,
        (class ~= targetName and class ~= "") and (class) or "",
        classifText))

    -- Línea 2: Salud
    local line2 = string.format("Salud: %s/%s [%d%%]",
        FormatNumber(health),
        FormatNumber(healthMax),
        healthPct)

    -- Recursos
    local powerType = UnitPowerType("target")
    if powerType == 0 then -- MANA
        local mana = UnitPower("target", 0)
        local manaMax = UnitPowerMax("target", 0)
        if manaMax > 0 then
            local manaPct = math.floor((mana / manaMax) * 100)
            line2 = line2 .. string.format(" //  Mana: %s/%s [%d%%]", 
                FormatNumber(mana), 
                FormatNumber(manaMax), 
                manaPct)
        end
    elseif powerType == 3 then -- ENERGÍA
        local energy = UnitPower("target", 3)
        local energyMax = UnitPowerMax("target", 3)
        local energyPct = math.floor((energy / energyMax) * 100)
        line2 = line2 .. string.format(" //  Energia: %d/%d [%d%%]", 
            energy, energyMax, energyPct)
    elseif powerType == 1 then -- IRA
        local rage = UnitPower("target", 1)
        local rageMax = UnitPowerMax("target", 1)
        local ragePct = math.floor((rage / rageMax) * 100)
        line2 = line2 .. string.format(" // Ira: %d/%d [%d%%]", 
            rage, rageMax, ragePct)
    end

    table.insert(messages, line2)

    SendDelayedMessages(messages)
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
        SendDelayedMessages({message})
    end
    SlashCmdList["DEADLYBOSSMODS"](broadcastCommand)
end

function nameTarget()
    local hasTarget = UnitExists("target")
    local targetName = UnitName("target")
    if hasTarget then
        SendDelayedMessages({targetName})
    else
        SendSystemMessage("No hay ningún objetivo seleccionado.")
    end
end

function GetOutOfRangeRaidMembers()
    local flaggedMembers = {}

    -- Verificar si estamos en raid o grupo
    local isInRaid = GetNumRaidMembers() > 0
    local isInParty = GetNumPartyMembers() > 0 and not isInRaid
    
    if not isInRaid and not isInParty then
        return "" -- no estamos en grupo ni raid
    end
    
    local maxPlayers = isInRaid and GetNumRaidMembers() or GetNumPartyMembers()
    local unitPrefix = isInRaid and "raid" or "party"
    
    for i = 1, maxPlayers do
        local unit = unitPrefix .. i
        if UnitExists(unit) and not UnitIsUnit(unit, "player") then
            local name = UnitName(unit)
            local class = select(2, UnitClass(unit))
            
            if name then
                local statusTag = nil

                if not UnitIsConnected(unit) then
                    statusTag = "OFF"
                elseif UnitIsAFK(unit) then
                    statusTag = "AFK"
                else
                    local inRange = UnitInRange(unit)
                    if inRange == false or inRange == nil then
                        statusTag = "Lejos"
                    end
                end

                if statusTag then
                    table.insert(flaggedMembers, name .. (class and (" (" .. class .. ")") or "") .. " [" .. statusTag .. "]")
                end
            end
        end
    end

    if #flaggedMembers > 0 then
        return "" .. table.concat(flaggedMembers, ", ")
    else
        return "Todos los jugadores están en rango y activos."
    end
end




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
            SendSystemMessage(playerName .. " aprobado.")
        end
    else
        SendSystemMessage("El jugador " .. playerName .. " no está en la raid para ser inspeccionado")
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

StaticPopupDialogs["CONFIRM_ALERT_FAR_PLAYERS"] = {
    text = "Hay jugadores que están fuera de rango. ¿Deseas enviar un aviso para que se acerquen?",
    button1 = "Sí, avisar",
    button2 = "No, omitir",
    OnAccept = function()
        for _, playerName in ipairs(farPlayers) do
            SendChatMessage("Por favor acércate para la inspección de equipo.", "WHISPER", nil, playerName)
        end
        SendSystemMessage("Se ha enviado un aviso a los jugadores lejanos.")
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3
}

function CheckRaidMembersForPvPGear()
    local numberOfPlayers = GetNumRaidMembers()
    local approved = {}
    local disapproved = {}
    local farPlayers = {}
    local hasFarPlayers = false

    -- Primera pasada: Verificar jugadores lejanos
    for i = 1, numberOfPlayers do
        local name, _, _, _, _, _, _, _, _, _, _ = GetRaidRosterInfo(i)
        if name and not UnitInRange("raid" .. i) then
            table.insert(farPlayers, name)
            hasFarPlayers = true
        end
    end

    -- Mostrar diálogo para jugadores lejanos si los hay
    if hasFarPlayers then
        _G.farPlayers = farPlayers  -- Guardar en variable global para el diálogo
        StaticPopup_Show("CONFIRM_ALERT_FAR_PLAYERS")
    end

    -- Segunda pasada: Verificar equipo PvP
    for i = 1, numberOfPlayers do
        local name, _, _, _, _, _, _, _, _, _, _ = GetRaidRosterInfo(i)
        if name then
            local unit = "raid" .. i
            
            -- Verificar si el jugador está en rango
            if UnitInRange(unit) then
                -- Verificar equipo PvP
                local hasPvP = false
                local slots = {"HeadSlot", "NeckSlot", "ShoulderSlot", "BackSlot", "ChestSlot", 
                             "WristSlot", "HandsSlot", "WaistSlot", "LegsSlot", "FeetSlot", 
                             "Finger0Slot", "Finger1Slot", "Trinket0Slot", "Trinket1Slot", 
                             "MainHandSlot", "SecondaryHandSlot", "RangedSlot"}
                
                -- Verificar cada slot de equipo
                for _, slot in ipairs(slots) do
                    local slotId = GetInventorySlotInfo(slot)
                    if slotId then
                        local itemLink = GetInventoryItemLink(unit, slotId)
                        if itemLink then
                            local itemName = GetItemInfo(itemLink) or ""
                            if string.find(string.lower(itemName), "incansable") or 
                               string.find(string.lower(itemName), "colérico") or 
                               string.find(string.lower(itemName), "furioso") then
                                hasPvP = true
                                break
                            end
                        end
                    end
                end
                
                if hasPvP then
                    table.insert(disapproved, name)
                    -- Mostrar diálogo de confirmación para expulsar
                    local dialog = StaticPopup_Show("CONFIRM_TEMPLE_GEAR", name)
                    if dialog then
                        dialog.data = name
                    end
                else
                    table.insert(approved, name)
                end
            else
                -- Si el jugador no está en rango, se agrega a la lista de lejanos
                if not hasFarPlayers then  -- Si no se mostró el diálogo general, lo agregamos a la lista
                    table.insert(farPlayers, name)
                end
            end
        end
    end

    -- Mostrar resumen
    if #approved > 0 then
        SendSystemMessage("Jugadores aprobados (sin PvP): " .. table.concat(approved, ", "))
    end
    
    if #disapproved > 0 then
        SendSystemMessage("Jugadores con equipo PvP: " .. table.concat(disapproved, ", "))
    end
    
    if #farPlayers > 0 then
        SendSystemMessage("Jugadores fuera de rango: " .. table.concat(farPlayers, ", "))
    end
    
    if #approved == 0 and #disapproved == 0 and #farPlayers == 0 then
        SendSystemMessage("No se encontraron jugadores para inspeccionar.")
    end
end

local rewards = {{
    name = "Bolsa de tejido de Escarcha",
    cost = 60
}, {
    name = "Cinturón del noble solitario",
    cost = 60
}, {
    name = "Sello de Edward el Extraño",
    cost = 80
}, {
    name = "Aguijón supernumerario de Namlak",
    cost = 120
}, {
    name = "Leotardos de talismanes dudosos",
    cost = 150
}, {
    name = "Bufas de solidaridad de Wapach",
    cost = 150
}, {
    name = "Cinturón de nova de sangre",
    cost = 280
}, {
    name = "Sortija de hueso de presagista",
    cost = 400
}, {
    name = "Campana de Je'Tze",
    cost = 600
}, {
    name = "Hombreras de cadáver tieso",
    cost = 800
}, {
    name = "Caparazón de reyes olvidados",
    cost = 880
}, {
    name = "Anillo de tendones podridos",
    cost = 900
}, {
    name = "Saco de maravillas de Ikfirus",
    cost = 1900
}, {
    name = "Hombreras de placas de behemoth enfurecido",
    cost = 2300
}, {
    name = "Ojo gélido de Tuétano",
    cost = 4000
}, {
    name = "Empuñadura",
    cost = 7000
}, {
    name = "Gargantilla carmesí de la Reina de Sangre",
    cost = 14000
}}

local function SelectReward(rewards)
    local totalWeight = 0
    local weights = {}

    for _, reward in ipairs(rewards) do
        local probability = math.max(0.1, (1000 / reward.cost)) -- Ajustar la probabilidad
        table.insert(weights, probability)
        totalWeight = totalWeight + probability
    end

    local randomValue = math.random() * totalWeight
    local cumulativeWeight = 0

    for i, weight in ipairs(weights) do
        cumulativeWeight = cumulativeWeight + weight
        if randomValue <= cumulativeWeight then
            return rewards[i]
        end
    end
end

local function GetOnlineGuildMembers()
    local numTotalMembers, _, numOnlineMembers = GetNumGuildMembers(true)
    local onlineMembers = {}

    print(numOnlineMembers)

    for i = 1, numTotalMembers do
        local name, _, _, _, _, _, _, _, isOnline = GetGuildRosterInfo(i)
        if isOnline then
            table.insert(onlineMembers, name)
        end
    end

    toExport = {}

    for i = 1, numTotalMembers do
        local name, rank, _, _, class, _, _, _, _ = GetGuildRosterInfo(i)
        table.insert(toExport, {
            name = name,
            rank = rank,
            class = class
        })
    end

    return onlineMembers
end

local function Announce(message)
    -- Mostrar el mensaje directamente en el chat
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99[Objetivo]|r " .. message)
    end
end

function GuildRoulette()
    if (IsGuildLeader() == true) then
        local onlineMembers = GetOnlineGuildMembers()
    
        local selectedReward = SelectReward(rewards)
        Announce("¡SORTEO DE HERMANDAD, EL GANADOR DEBE RESPONDER Y RECLAMAR O SE HACE NUEVO SORTEO!")
        Announce("El sistema selecciona un premio aleatorio del banco y lo sortea entre todos los jugadores de la hermandad que esten conectados.")
        Announce("El premio de este sorteo es: " .. selectedReward.name .. " valorado en " .. selectedReward.cost .. "g!")
    
        local totalSteps = #onlineMembers
        local currentStep = 0
    
        local frame = CreateFrame("Frame")
    
        frame:SetScript("OnUpdate", function(self, elapsed)
            currentStep = currentStep + 1
    
            if currentStep > totalSteps then
                local winnerIndex = math.random(#onlineMembers)
                local winner = onlineMembers[winnerIndex]
    
                -- Listar los resultados
                Announce("Resultados del sorteo:")
                for i, member in ipairs(onlineMembers) do
                    if i ~= winnerIndex then
                        local minorPrize = math.random(1, selectedReward.cost - 1)
                        Announce(member .. " ha obtenido " .. minorPrize .. " creditos.")
                    else
                        Announce(member .. " ha obtenido el premio mayor de " .. selectedReward.cost .. " creditos!")
                    end
                end
                Announce("¡El ganador es " .. winner .. "! Ha ganado " .. selectedReward.cost ..
                             " creditos para cambiar por " .. selectedReward.name .. " o cualquier item de igual valor.")
                             Announce("SI NO RECLAMA SE HACE NUEVO SORTEO")
                
                SendChatMessage(
                    "¡Ha ganado " .. selectedReward.cost .. " creditos para cambiar por " .. selectedReward.name ..
                        " o cualquier item de igual valor. RECLAME O SIGUE JUGANDO!", "WHISPER", nil, winner)
    
                PlaySoundFile("Sound\\Interface\\LevelUp.wav")
    
                self:SetScript("OnUpdate", nil) -- Detener el OnUpdate
                return
            end
        end)
    else
        SendSystemMessage("Solo el maestro de hermandad puede inciar un sorteo.")
    end
end

