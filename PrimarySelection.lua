function primarySelection()
    local primaryRoleFrame = CreateFrame("Frame", nil, QuickNamePanel)
    primaryRoleFrame:SetSize(430, 175)

    local contentScrollFrame = CreateFrame("ScrollFrame", "primaryRole_ContentScrollFrame", primaryRoleFrame, "UIPanelScrollFrameTemplate")
    contentScrollFrame:SetPoint("TOPLEFT", 10, -55)
    contentScrollFrame:SetPoint("BOTTOMRIGHT", -10, 10)

    local content = CreateFrame("Frame", nil, contentScrollFrame)
    content:SetSize(370, 175)
    contentScrollFrame:SetScrollChild(content)

    local xOffset = 15
    local yOffset = 0
    local rowHeight = 30
    local columnWidth = 190
    local numColumns = 2

    local roles = playerRoles["PRIMARY"]
    local numRoles = #roles
    local numRows = math.ceil(numRoles / numColumns)

    for i, roleName in ipairs(roles) do
        local row = math.floor((i - 1) / numColumns)
        local column = (i - 1) % numColumns

        local button = CreateFrame("Button", "primaryRol" .. i, content, "UIPanelButtonTemplate")
        button:SetPoint("TOPLEFT", xOffset + column * (columnWidth + 10), yOffset - row * (rowHeight - 3))
        button:GetFontString():SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
        button:SetSize(170, rowHeight)
        button:SetText(roleName)

        -- Comprueba si el rol está asignado a un jugador en addonCache
        local assignedPlayer = getAssignedPlayer(roleName) -- Debes implementar esta función

        if assignedPlayer then
            button:SetText(assignedPlayer .. "\n" .. roleName) -- Actualiza el texto del botón con el nombre del jugador y el rol
            button:SetAttribute("player", assignedPlayer) -- Establece la propiedad 'player' del botón con el nombre del jugador
        end

        button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        button:SetScript("OnClick", function(self, mouseButton)
            if mouseButton == "LeftButton" then
                SendRoleAlert(roleName, self)
            elseif mouseButton == "RightButton" then
                SendRoleAlert(roleName, self, true)
            end
        end)

        local resetButton = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
        resetButton:GetFontString():SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
        resetButton:SetText("X")
        resetButton:SetPoint("LEFT", button, "RIGHT", -2, 0)
        resetButton:SetSize(26, 26)
        resetButton:SetScript("OnClick", function()
            ResetRoleAssignment(roleName, button)
        end)
    end

    content:SetHeight(numRows * (rowHeight - 5))

    local scrollBar = _G[contentScrollFrame:GetName() .. "ScrollBar"]
    scrollBar:SetMinMaxValues(0, max(0, content:GetHeight() - contentScrollFrame:GetHeight()))

    return primaryRoleFrame
end

function ResetRoleAssignment(roleName, button)
    local selectedPlayer = button:GetAttribute("player")
    local _, channel = getPlayerInitialState()
    if selectedPlayer then
        if addonCache[selectedPlayer] and addonCache[selectedPlayer].rol then
            addonCache[selectedPlayer].rol[roleName] = nil
            local playerClass = addonCache[selectedPlayer].class
            playerClass = string.upper(string.sub(playerClass, 1, 1)) .. string.lower(string.sub(playerClass, 2))
            print("Se retiro al " .. playerClass .. " " .. selectedPlayer .. " del rol de [" .. roleName .. "]")
            button:SetText(roleName) -- Restaurar el texto original del button
            button:SetAttribute("player", nil)
        end
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
                button:SetText(playerClass .. " " .. targetName .. "\n" .. roleName) -- Concatenar el nombre del jugador al texto del label
            end
            SendChatMessage(playerClass .. " " .. targetName .. " [" .. roleName .. "]", channel)
        else
            SendChatMessage("No tenemos [" .. roleName .. "]", channel)
        end
    end
end

function SendRoleAlert(roleName, button, resInCombatNow)
    print(resInCombatNow)
    local _, channel = getPlayerInitialState()
    local playerName = button:GetAttribute("player")

    local message = ""
    if playerName then
        local playerClass = addonCache[playerName].class
        playerClass = string.upper(string.sub(playerClass, 1, 1)) .. string.lower(string.sub(playerClass, 2))
        message = playerClass .. " " .. playerName ..  (resInCombatNow and "" or " [" .. roleName .. "]")
        if resInCombatNow then
            message = "REVIVIR AL [" .. message .. "] ASAP!"
        else
            message = message
        end
    else
        message = "Necesitamos " .. " [" .. roleName .. "]"
    end
    SendChatMessage(message, channel)
end

function table.contains(table, element)
    for _, value in pairs(table) do
        if value == element then
            return true
        end
    end
    return false
end

function getAssignedPlayer(roleName)
    for playerName, playerData in pairs(addonCache) do
        if playerData.rol and playerData.rol[roleName] then
            return playerName
        end
    end
    return nil
end
