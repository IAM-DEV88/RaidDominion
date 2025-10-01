-- Global variable to store guild member list for export
toExport = {}

-- Función auxiliar para crear una estructura de jugador
local function createPlayerStructure(playerName, className)
    return {
        class = className,
        rol = {}
    }
end

-- Función auxiliar para configurar un botón con un jugador asignado
local function setupAssignedButton(button, playerName, roleName)
    button:SetNormalFontObject("GameFontNormal")
    button:SetText(string.format("%s [%s]", playerName, roleName))
    button:SetAttribute("player", playerName)
    button:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background"
    })
    button:SetBackdropColor(0, 0, 0, 0.8)
end

-- Función auxiliar para resetear un botón a su estado por defecto
local function resetButton(button, roleName)
    button:SetText(roleName)
    button:SetAttribute("player", nil)
    button:SetNormalFontObject("GameFontHighlight")
    button:SetBackdrop({})
end

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
        addonCache[playerName] = createPlayerStructure(playerName, englishClass)
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
                    addonCache[playerName] = createPlayerStructure(playerName, playerClass)
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
            addonCache[playerName] = createPlayerStructure(playerName, englishClass)
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
    -- Asegurarse de que primaryRoles esté cargado
    if not primaryRoles then
        print("Error: primaryRoles no está cargado. Asegúrate de que Resources.lua se cargue primero.")
        return {}
    end
    
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
                setupAssignedButton(button, assignedPlayer, data.role)
            else
                resetButton(button, data.role)
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
        if not SafeDBMCommand("broadcast timer 0:10 RAIDCHECK Y PULL") then
            SendSystemMessage("|cFFFFFF00Advertencia:|r DBM no está instalado. La función de temporizador no está disponible.")
        end
        StaticPopup_Show("CONFIRM_PULL_COUNTDOWN")
    end,
    OnCancel = function()
        -- Función que se llama cuando el jugador cancela el check de banda
        -- SendChatMessage("POR FAVOR, ESPEREN", "RAID_WARNING")
        if not SafeDBMCommand("broadcast timer 0:20 ¿QUE FALTA?") then
            SendSystemMessage("|cFFFFFF00Advertencia:|r DBM no está instalado. La función de temporizador no está disponible.")
        end
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
        local dbmAvailable = SafeDBMCommand("broadcast timer 0:10 RESPETAR PULL")
        if dbmAvailable then
            SafeDBMCommand("pull 10")
        else
            SendSystemMessage("|cFFFFFF00Advertencia:|r DBM no está instalado. La función de temporizador no está disponible.")
        end
    end,
    OnCancel = function()
        -- Función que se llama cuando el jugador cancela el check de banda
        SendChatMessage("ESPEREN", "RAID_WARNING")
        if not SafeDBMCommand("broadcast timer 0:10 PULL CANCELADO") then
            SendSystemMessage("|cFFFFFF00Advertencia:|r DBM no está instalado. La función de temporizador no está disponible.")
        end
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

function ClearAllRaidIcons()
    local numRaidMembers = GetNumRaidMembers()
    for i = 1, numRaidMembers do
        local unit = "raid" .. i
        if UnitExists(unit) then
            SetRaidTarget(unit, 0)
        end
    end
    -- Also clear the player's own icon if in a group but not in raid
    if not IsInRaid() and GetNumGroupMembers() > 0 then
        for i = 1, GetNumGroupMembers() do
            local unit = "party" .. i
            if UnitExists(unit) then
                SetRaidTarget(unit, 0)
            end
        end
    end
end

function AssignIconsAndAlert(button)
    -- If right-clicked, clear all raid icons and return
    if button == "RightButton" then
        ClearAllRaidIcons()
        return
    end
    
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

    local dbmAvailable = SafeDBMCommand("broadcast timer 0:20 APLICAR BUFFS")
    if not dbmAvailable then
        SendSystemMessage("|cFFFFFF00Advertencia:|r DBM no está instalado. La función de temporizador no está disponible.")
    end
    
    for _, playerInfo in ipairs(raidMembers) do
        local playerName = playerInfo[1]
        local message = playerInfo[2]
        SendChatMessage(message .. " -- Lider de banda", "WHISPER", nil, playerName)
    end
end

-- Función auxiliar global para ejecutar comandos de DBM de manera segura
function SafeDBMCommand(command)
    if IsAddOnLoaded("DBM-Core") and SlashCmdList["DEADLYBOSSMODS"] then
        SlashCmdList["DEADLYBOSSMODS"](command)
        return true
    end
    return false
end

-- Contador para IDs únicos de tareas
local taskCounter = 0
local scheduledTasks = {}
local lastUpdate = 0


-- Función para programar una tarea con retraso
local function ScheduleTask(delay, callback)
    taskCounter = taskCounter + 1
    scheduledTasks[taskCounter] = {
        time = GetTime() + delay,
        callback = callback
    }
    return taskCounter
end

function SendDelayedMessages(messages, priorityChannel)
    if not messages or #messages == 0 then
        return
    end
    local _, channel = getPlayerInitialState()
    channel = priorityChannel or channel
    
    local maxLength = 255
    local delay = 0.1 -- Delay in seconds between each part
    local currentIndex = 1
    
    local function SendNextPart()
        if currentIndex > #messages then
            return -- All messages sent
        end
        
        local message = messages[currentIndex]
        local messageLength = #message
        
        if messageLength <= maxLength then
            -- If message is within limit, send it as is
            SendChatMessage(message, channel)
            currentIndex = currentIndex + 1
            ScheduleTask(delay, SendNextPart)
        else
            -- If message is too long, split it
            local part = message:sub(1, maxLength)
            SendChatMessage(part, channel)
            
            -- Update the message with remaining text
            messages[currentIndex] = message:sub(maxLength + 1)
            
            -- Schedule next part of the same message
            ScheduleTask(delay, SendNextPart)
        end
    end
    
    -- Start sending messages
    SendNextPart()
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
    
    -- Usar la función segura para DBM
    if not SafeDBMCommand(broadcastCommand) then
        SendSystemMessage("|cFFFFFF00Advertencia:|r DBM no está instalado. La función de temporizador no está disponible.")
    end
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

local function GetOnlineGuildMembers()
    local numTotalMembers, _, numOnlineMembers = GetNumGuildMembers(true)
    local onlineMembers = {}

    for i = 1, numTotalMembers do
        local name, _, _, _, _, _, _, _, isOnline = GetGuildRosterInfo(i)
        if isOnline then
            table.insert(onlineMembers, name)
        end
    end

    return onlineMembers
end

function GetGuildMemberList()
    local numTotalMembers, _, numOnlineMembers = GetNumGuildMembers(true)
    local onlineMembers = {}

    toExport = {}

    for i = 1, numTotalMembers do
        local name, rank, _, _, class, _, publicNote, officerNote = GetGuildRosterInfo(i)
        table.insert(toExport, {
            name = name,
            rank = rank,
            class = class,
            publicNote = publicNote or "",
            officerNote = officerNote or ""
        })
    end

    return toExport
end

-- Variable para almacenar el ítem seleccionado del banco de la hermandad
local selectedGuildBankItem = nil

-- Función para abrir el banco de la hermandad y obtener los ítems de la primera pestaña
function OpenGuildBankAndGetItems()
    if not IsInGuild() then
        SendSystemMessage("No eres miembro de una hermandad.")
        return
    end
    
    if not CanGuildBankRepair() then
        SendSystemMessage("No tienes permiso para acceder al banco de la hermandad.")
        return
    end
    
    -- Abrir el banco de la hermandad
    if not GuildBankFrame:IsShown() then
        ShowUIPanel(GuildBankFrame)
    end
    
    -- Crear un frame para manejar el temporizador
    local frame = CreateFrame("Frame")
    frame.elapsed = 0
    frame:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = self.elapsed + elapsed
        if self.elapsed >= 1 then  -- Esperar 1 segundo para que se carguen los ítems
            self:SetScript("OnUpdate", nil)
            
            local tabItems = {}
            local tab = 1  -- Primera pestaña del banco de la hermandad
            
            -- Obtener información de la pestaña
            local name, icon, isViewable, canDeposit, numWithdrawals, remainingWithdrawals = GetGuildBankTabInfo(tab)
            
            if not isViewable then
                SendSystemMessage("No tienes permiso para ver esta pestaña del banco de la hermandad.")
                return
            end
            
            -- Recorrer los espacios de la pestaña (máx. 98 por pestaña)
            for slot = 1, 98 do
                local itemLink = GetGuildBankItemLink(tab, slot)
                if itemLink then
                    local itemName, _, itemRarity, _, _, _, _, _, _, itemTexture = GetItemInfo(itemLink)
                    local _, _, count = GetGuildBankItemInfo(tab, slot)
                    
                    table.insert(tabItems, {
                        link = itemLink,
                        name = itemName,
                        texture = itemTexture,
                        count = count or 1,
                        slot = slot
                    })
                end
            end
            
            if #tabItems == 0 then
                SendSystemMessage("No hay ítems en la primera pestaña del banco de la hermandad.")
                return
            end
            
            -- Seleccionar un ítem aleatorio
            selectedGuildBankItem = tabItems[math.random(1, #tabItems)]
            
            -- Mostrar diálogo de confirmación
            StaticPopup_Show("CONFIRM_GUILD_BANK_ITEM", selectedGuildBankItem.name, selectedGuildBankItem.count)
        end
    end)
end

-- Función para realizar el sorteo una vez confirmado el ítem
function PerformGuildRoulette()
    if not selectedGuildBankItem then return end
    
    local onlineMembers = GetOnlineGuildMembers()
    if #onlineMembers == 0 then
        SendSystemMessage("No hay miembros de la hermandad conectados para el sorteo.")
        return
    end
    
    -- Siempre sortear 1 unidad
    local itemCount = 1
    local itemText = selectedGuildBankItem.link .. " (x1)"
    
    local messages = {
        "¡SORTEO DE HERMANDAD, EL GANADOR DEBE RESPONDER Y RECLAMAR O SE HACE NUEVO SORTEO!",
        "El sistema selecciona un ítem aleatorio del banco y lo sortea entre todos los jugadores de la hermandad que estén conectados.",
        "El premio de este sorteo es: " .. itemText
    }
    
    -- Añadir mensaje de "Sorteando..." con un pequeño retraso
    table.insert(messages, "Sorteando...")
    
    -- El ganador se determinará por el puntaje más alto
    
    -- Añadir encabezado de resultados
    table.insert(messages, "Resultados del sorteo:")
    
    -- Generar puntajes para todos los miembros
    local scores = {}
    local maxScore = 0
    local winnerIndex = 1
    
    for i = 1, #onlineMembers do
        scores[i] = math.random(1, 200)  -- Puntaje aleatorio entre 1 y 200
        if scores[i] > maxScore then
            maxScore = scores[i]
            winnerIndex = i
        end
    end
    
    -- Ordenar miembros por puntaje (de mayor a menor)
    local sortedIndices = {}
    for i = 1, #onlineMembers do table.insert(sortedIndices, i) end
    table.sort(sortedIndices, function(a, b) return scores[a] > scores[b] end)
    
    -- Mostrar resultados ordenados
    for _, idx in ipairs(sortedIndices) do
        local member = onlineMembers[idx]
        if idx == winnerIndex then
            table.insert(messages, member .. " ha obtenido el premio mayor: " .. itemText .. "! (Puntaje: " .. scores[idx] .. ")")
        else
            table.insert(messages, member .. " ha obtenido " .. scores[idx] .. " puntos.")
        end
    end
    
    local winner = onlineMembers[winnerIndex]
    
    -- Añadir mensaje del ganador
    table.insert(messages, "¡El ganador es " .. winner .. "! Ha ganado " .. itemText)
    table.insert(messages, "SI NO RECLAMA SE HACE NUEVO SORTEO")
    
    -- Enviar todos los mensajes con retraso
    SendDelayedMessages(messages,"GUILD")
    
    -- Enviar mensaje privado al ganador
    SendChatMessage(
        "¡Ha ganado el sorteo de hermandad! Su premio es: " .. selectedGuildBankItem.link .. 
        " (x" .. selectedGuildBankItem.count .. "). Por favor, contacte a un oficial para reclamar su premio.", 
        "WHISPER", nil, winner)
    
    PlaySoundFile("Sound\\Interface\\LevelUp.wav")
    
    -- Limpiar el ítem seleccionado
    selectedGuildBankItem = nil
end

function GuildRoulette()
    local rankIndex = select(3, GetGuildInfo("player"))
    local _, _, _, _, _, _, _, _, isGuildLeader = GetGuildRosterInfo(rankIndex)
    
    if not isGuildLeader and not CanGuildPromote() then
        SendSystemMessage("Solo los oficiales y el maestro de hermandad pueden iniciar un sorteo.")
        return
    end
    
    -- Abrir el banco de la hermandad directamente
    if not IsInGuild() then
        SendSystemMessage("No eres miembro de una hermandad.")
        return
    end
    
    if not CanGuildBankRepair() then
        SendSystemMessage("No tienes permiso para acceder al banco de la hermandad.")
        return
    end
    
    -- Abrir el banco de la hermandad
    if not GuildBankFrame:IsShown() then
        ShowUIPanel(GuildBankFrame)
    end
    
    -- Iniciar el escaneo de ítems
    OpenGuildBankAndGetItems()
end

-- Diálogo para confirmar el ítem seleccionado
StaticPopupDialogs["CONFIRM_GUILD_BANK_ITEM"] = {
    text = "¿Deseas sortear el siguiente ítem?\n\n%s (x1)",
    button1 = "Sortear",
    button2 = "Elegir otro",
    button3 = "Cancelar",
    OnAccept = function()
        -- Iniciar el sorteo
        PerformGuildRoulette()
    end,
    OnCancel = function(_, _, reason)
        if reason == "clicked" then
            -- Botón "Elegir otro"
            OpenGuildBankAndGetItems()
        else
            -- Escape presionado
            selectedGuildBankItem = nil
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
    showAlert = true,
    enterClicksFirstButton = true
}

-- Función para verificar los reconocimientos de los miembros de la hermandad
function CheckGuildOfficerNotes()
    if not IsInGuild() then
        SendSystemMessage("No eres miembro de una hermandad.")
        return
    end
    
    -- Obtener el número total de miembros, incluyendo los que no están en línea
    local numTotalMembers = GetNumGuildMembers(true)  -- true para incluir offline
    if numTotalMembers == 0 then 
        SendSystemMessage("No hay miembros en la hermandad.")
        return 
    end
    
    -- Palabras clave de reconocimientos
    local reconocimientos = {
        "ESPIRITU",
        "SABIO",
        "CAZADOR",
        "DOMINION",
        "GUARDIAN"
    }
    
    -- Inicializar tabla para agrupar reconocimientos por jugador
    local jugadores = {}
    local encontrados = false
    
    -- Recolectar las notas de oficial, rangos y clases de todos los miembros
    local miembros = {}
    -- Primero obtener los nombres de los rangos
    local rankNames = {}
    for i = 1, GuildControlGetNumRanks() do
        rankNames[i] = GuildControlGetRankName(i)
    end
    
    -- Luego procesar los miembros
    for i = 1, numTotalMembers do
        local name, _, rankIndex, _, _, _, _, officerNote, _, _, classFileName = GetGuildRosterInfo(i)
        if officerNote and officerNote ~= "" then
            local rankName = rankNames[rankIndex + 1] or "Recluta"  -- rankIndex es 0-based
            local className = classFileName and LOCALIZED_CLASS_NAMES_MALE[classFileName] or ""
            miembros[name] = {
                note = officerNote:upper(),
                rank = rankName,
                class = className
            }
        end
    end
    
    -- Procesar las notas de todos los miembros
    for name, data in pairs(miembros) do
        local reconocimientosJugador = {}
        
        -- Verificar cada palabra clave en la nota de oficial
        for _, clave in ipairs(reconocimientos) do
            if string.find(data.note, clave, 1, true) then  -- búsqueda literal
                table.insert(reconocimientosJugador, clave)
                encontrados = true
            end
        end
        
        if #reconocimientosJugador > 0 then
            table.sort(reconocimientosJugador)
            jugadores[name] = {
                reconocimientos = reconocimientosJugador,
                rank = data.rank,
                class = data.class
            }
        end
    end
    
    -- Construir el mensaje de salida
    local mensajes = {}
    
    if not encontrados then
        table.insert(mensajes, "=== JERARQUÍA DE LA HERMANDAD ===")
        table.insert(mensajes, "No se encontraron reconocimientos en las notas de los miembros.")
        table.insert(mensajes, "Puedes agregar las palabras clave en tu nota de oficial:")
        table.insert(mensajes, "ESPÍRITU, SABIO, CAZADOR, DOMINION, GUARDIÁN")
    else
        -- Agrupar jugadores por rango
        local jugadoresPorRango = {}
        local contadorPorRango = {}
        
        -- Inicializar tablas
        for _, rankName in pairs({"Recluta", "Élite", "Comandante"}) do
            jugadoresPorRango[rankName] = {}
            contadorPorRango[rankName] = 0
        end
        
        -- Agrupar jugadores por rango
        for nombre, data in pairs(jugadores) do
            local rank = data.rank
            if not jugadoresPorRango[rank] then
                jugadoresPorRango[rank] = {}
                contadorPorRango[rank] = 0
            end
            table.insert(jugadoresPorRango[rank], {
                nombre = nombre,
                clase = data.class ~= "" and data.class or "Sin Clase",
                reconocimientos = data.reconocimientos
            })
            contadorPorRango[rank] = contadorPorRango[rank] + 1
        end
        
        -- Ordenar jugadores alfabéticamente dentro de cada rango
        for rank, jugadores in pairs(jugadoresPorRango) do
            table.sort(jugadores, function(a, b) return a.nombre < b.nombre end)
        end
        
        -- Construir el mensaje
        table.insert(mensajes, "=== JERARQUÍA DE LA HERMANDAD ===")
        table.insert(mensajes, "NIVELES: 1.Recluta 2.Élite 3.Comandante // RECONOCIMIENTOS: ESPÍRITU, SABIO, CAZADOR, DOMINION, GUARDIÁN")
        
        -- Función para formatear una línea de jugadores
        local function agregarLineaJugadores(jugadores, inicio, fin)
            local linea = {}
            for i = inicio, math.min(fin, #jugadores) do
                local j = jugadores[i]
                table.insert(linea, string.format("%s %s (%s)", j.clase, j.nombre, table.concat(j.reconocimientos, ", ")))
            end
            if #linea > 0 then
                table.insert(mensajes, table.concat(linea, " // "))
            end
        end
        
        -- Mostrar por rangos en orden descendente
        local rangosEnOrden = {
            {nombre = "COMANDANTES (Nivel 3)", clave = "Comandante"},
            {nombre = "ÉLITE (Nivel 2)", clave = "Élite"},
            {nombre = "RECLUTAS (Nivel 1)", clave = "Recluta"}
        }
        
        for _, rango in ipairs(rangosEnOrden) do
            local jugadoresRango = jugadoresPorRango[rango.clave] or {}
            local totalJugadores = #jugadoresRango
            local sufix = totalJugadores == 1 and "jugador" or "jugadores"
            
            if totalJugadores > 0 then
                table.insert(mensajes, string.format("\n=== %s [%d %s] ===", rango.nombre, totalJugadores, sufix))
                
                -- Mostrar de 4 en 4 jugadores por línea
                for i = 1, totalJugadores, 4 do
                    agregarLineaJugadores(jugadoresRango, i, i + 3)
                end
            end
        end
        
        table.insert(mensajes, "")
        table.insert(mensajes, "¡Gracias por su compromiso y dedicación con la hermandad!")
    end
    
    -- Mostrar los mensajes
    SendDelayedMessages(mensajes,"GUILD")
end     

-- Frame para manejar eventos de la interfaz de usuario
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("CHAT_MSG_SYSTEM")
eventFrame:RegisterEvent("GUILD_ROSTER_UPDATE")

-- Tabla para rastrear jugadores recién unidos
local pendingWelcomes = {}

-- Función para obtener la clase de un jugador en la hermandad
local function GetPlayerClassFromGuild(playerName, maxRetries)
    maxRetries = maxRetries or 0
    
    -- Limpiar el nombre
    playerName = playerName:gsub(" %-.*$", ""):trim()
    
    -- Asegurarse de que tenemos los datos de la hermandad
    if not IsInGuild() then 
        print("Error: El jugador no está en la hermandad")
        return nil 
    end
    
    -- Forzar actualización de la lista de la hermandad
    GuildRoster()
    
    -- Obtener el número total de miembros (incluyendo los fuera de línea)
    local totalMembers = GetNumGuildMembers()
    
    -- Buscar al jugador en la lista de la hermandad
    for i = 1, totalMembers do
        -- Obtener la información del miembro
        local name, _, _, _, class, _, _, _, _, _, classFileName = GetGuildRosterInfo(i)
        
        if name and name:lower() == playerName:lower() then
            -- Devolver la clase encontrada
            return class or classFileName or "Jugador"
        end
    end
    
    -- Si no encontramos al jugador y aún tenemos intentos
    if maxRetries > 0 then
        return nil, maxRetries - 1
    end
    
    return nil
end

-- Crear un frame para manejar los temporizadores
local timerFrame = CreateFrame("Frame")
timerFrame:SetScript("OnUpdate", function(self, elapsed)
    lastUpdate = lastUpdate + elapsed
    if lastUpdate < 0.1 then return end -- Actualizar cada 100ms
    lastUpdate = 0
    
    local currentTime = GetTime()
    local toRemove = {}
    
    -- Procesar tareas programadas
    for id, task in pairs(scheduledTasks) do
        if currentTime >= task.time then
            task.callback()
            table.insert(toRemove, id)
        end
    end
    
    -- Eliminar tareas completadas
    for _, id in ipairs(toRemove) do
        scheduledTasks[id] = nil
    end
end)

-- Función para cancelar una tarea programada
local function CancelScheduledTask(id)
    if id then
        scheduledTasks[id] = nil
    end
end

-- Función para manejar la bienvenida con reintentos
local welcomeTimers = {}

local function SendGuildRules(playerName)
    local guildRules = {
        -- ENLACES DE LA HERMANDAD
        "ENLACES DE LA HERMANDAD",
        "POSADA → https://discord.gg/BwdpNV9sky",
        "REGLAS DE RAIDS → https://discord.gg/4t43agyGpv",
        "REGLAS DEL BANCO → https://discord.gg/DUVmhumcYV",
        "WEB COLMILLO DE ACERO → https://colmillo.netlify.app/",
        "CODIGOS DE NOTA → Pronto validador en nuestra web"
    }
    -- Enviar cada línea como un susurro separado con un pequeño retraso
    for i, rule in ipairs(guildRules) do
        ScheduleTask(i * 0.3, function()
            SendChatMessage(rule, "WHISPER", nil, playerName)
        end)
    end
end

local function HandleGuildWelcome(playerName, retries)
    retries = retries or 3 -- Número de reintentos
    
    -- Cancelar temporizador anterior si existe
    if welcomeTimers[playerName] then
        CancelScheduledTask(welcomeTimers[playerName])
    end
    
    -- Programar la tarea
    welcomeTimers[playerName] = ScheduleTask(1, function()
        local class = GetPlayerClassFromGuild(playerName, retries)
        -- Obtener el total de miembros y contar cuántos están en línea
        local totalMembers, _, _ = GetNumGuildMembers(true)
    
        -- Contar miembros en línea manualmente para mayor precisión
        local actualOnline = 0
        for i = 1, totalMembers do
            local _, _, _, _, _, _, _, _, isOnline = GetGuildRosterInfo(i)
            if isOnline then
                actualOnline = actualOnline + 1
            end
        end
    
        -- Asegurarse de que tenemos valores válidos
        totalMembers = totalMembers or 0
    
        
        if class then
            -- Limpiar
            pendingWelcomes[playerName] = nil
            welcomeTimers[playerName] = nil
            
            -- Obtener el nombre de la hermandad
            local guildName = GetGuildInfo("player") or "la hermandad"
            
            -- Enviar mensaje de bienvenida
            local messages = {
                string.format("¡Bienvenido a %s %s %s!", guildName, class or "", playerName),
                string.format("¡Ya somos %d!", totalMembers)
            }
            SendDelayedMessages(messages,"GUILD")
            
            -- Enviar reglas por susurro
            SendGuildRules(playerName)
        elseif retries > 0 then
            -- Reintentar
            HandleGuildWelcome(playerName, retries - 1)
        else
            -- Agotados los reintentos
            pendingWelcomes[playerName] = nil
            welcomeTimers[playerName] = nil
            SendSystemMessage(string.format("¡%s se ha unido a la jauría! (Clase no detectada)", playerName))
        end
    end)
end

StaticPopupDialogs["CONFIRM_WELCOME_MESSAGE"] = {
    text = "¿Deseas darle la bienvenida a %s?",
    button1 = "Sí",
    button2 = "No",
    OnShow = function(self)
        -- El nombre llega como "data" al popup
        self.playerName = self.data
    end,
    OnAccept = function(self)
        local playerName = self.playerName
        if playerName then
            HandleGuildWelcome(playerName)
        end
    end,
    OnCancel = function(self)
        if self and self.playerName then
            pendingWelcomes[self.playerName] = nil
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3
}


-- Manejador de eventos
eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "CHAT_MSG_SYSTEM" then
        local msg = ...
        -- Verificar si es un mensaje de unión a la hermandad
        local playerName = msg:match("^(.-) se ha unido a la hermandad")
        if playerName and IsInGuild() then
            -- Limpiar el nombre
            playerName = playerName:gsub(" %-.*$", ""):trim()
            
            -- Agregar a la lista de pendientes si no está ya en ella
            if not pendingWelcomes[playerName] then
                print("Nuevo jugador detectado:", playerName)
                pendingWelcomes[playerName] = true
                StaticPopup_Show("CONFIRM_WELCOME_MESSAGE", playerName, nil, playerName)


                -- HandleGuildWelcome(playerName)
            end
        end
    end
end)



-- Función para mostrar la jerarquía de la hermandad agrupada por rangos
function ShowGuildHierarchy()
    if not IsInGuild() then
        SendSystemMessage("No eres miembro de una hermandad.")
        return
    end
    
    local numTotalMembers = GetNumGuildMembers(true)
    if numTotalMembers == 0 then 
        SendSystemMessage("No hay miembros en la hermandad.")
        return 
    end
    
    -- Obtener los nombres de los rangos
    local rankNames = {}
    local numRanks = GuildControlGetNumRanks()
    for i = 1, numRanks do
        rankNames[i] = GuildControlGetRankName(i)
    end
    
    -- Contadores por rango
    local rankCounts = {}
    
    -- Contar miembros por rango
    for i = 1, numTotalMembers do
        local _, _, rankIndex = GetGuildRosterInfo(i)
        local rankName = rankNames[rankIndex + 1] or "Recluta"  -- rankIndex es 0-based
        rankCounts[rankName] = (rankCounts[rankName] or 0) + 1
    end
    
    -- Construir el mensaje
    local messages = {"=== COMPOSICION DE LA HERMANDAD ==="}
    
    -- Combinar los dos primeros rangos si existen
    if #rankNames >= 2 then
        local rank1 = rankNames[1] or ""
        local rank2 = rankNames[2] or ""
        local count1 = rankCounts[rank1] or 0
        local count2 = rankCounts[rank2] or 0
        
        if count1 > 0 or count2 > 0 then
            table.insert(messages, string.format("→ %s [%d] + %s [%d] = Maestro de la hermandad", 
                rank1, count1, rank2, count2))
        end
        
        -- Empezar desde el tercer rango
        for rankIndex = 3, #rankNames do
            local rankName = rankNames[rankIndex]
            local total = rankCounts[rankName] or 0
            if total > 0 then
                local description = ""
                if rankIndex == 3 then
                    description = "Maestros del Codigo"
                elseif rankIndex == 4 then
                    description = "Conocedores del Codigo"
                elseif rankIndex == 5 then
                    description = "Deben enviar su codigo de nota al GM/Alter para ser asendidos"
                end
                table.insert(messages, string.format("→ %s [%d] = %s", rankName, total, description))
            end
        end
    else
        -- Si hay menos de 2 rangos, mostrarlos todos normalmente
        for rankIndex = 1, #rankNames do
            local rankName = rankNames[rankIndex]
            local total = rankCounts[rankName] or 0
            if total > 0 then
                table.insert(messages, string.format("%s: %d", rankName, total))
            end
        end
    end
    
    -- Calcular totales
    local totalMembers = 0
    local totalOnline = 0
    local totalOffline = 0
    
    -- Contar miembros en línea y desconectados
    for i = 1, numTotalMembers do
        local _, _, _, _, _, _, _, _, isOnline = GetGuildRosterInfo(i)
        if isOnline then
            totalOnline = totalOnline + 1
        else
            totalOffline = totalOffline + 1
        end
    end
    totalMembers = totalOnline + totalOffline
    
    -- Añadir línea de total con contadores de conexión
    table.insert(messages, string.format("Total: %d miembros (%d en línea, %d desconectados)", 
        totalMembers, totalOnline, totalOffline))
    
    -- Mostrar los mensajes
    -- for _, message in ipairs(messages) do
    --     SendSystemMessage(message)
    -- end
    SendDelayedMessages(messages,"GUILD")
end