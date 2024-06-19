function primarySelection()
    local primaryRoleFrame = CreateFrame("Frame", nil, RaidDominionPanel)
    primaryRoleFrame:SetSize(430, 175)

    local contentScrollFrame = CreateFrame("ScrollFrame", "primaryRole_ContentScrollFrame", primaryRoleFrame,
        "UIPanelScrollFrameTemplate")
    contentScrollFrame:SetPoint("TOPLEFT", 10, -55)
    contentScrollFrame:SetPoint("BOTTOMRIGHT", -10, 10)

    local content = CreateFrame("Frame", nil, contentScrollFrame)
    content:SetSize(370, 175)
    contentScrollFrame:SetScrollChild(content)

    local xOffset = 29
    local yOffset = 0
    local rowHeight = 27
    local columnWidth = 190
    local numColumns = 2

    local roles = playerRoles["PRIMARIO"]
    local numRoles = #roles
    local numRows = math.ceil(numRoles / numColumns)

    for i, roleName in ipairs(roles) do
        local row = math.floor((i - 1) / numColumns)
        local column = (i - 1) % numColumns

        local button = CreateFrame("Button", "primaryRol" .. i, content, "RaidAssistButtonTemplate")
        button:SetPoint("TOPLEFT", xOffset + column * (columnWidth + 3), yOffset - row * (rowHeight + 1))
        button:GetFontString():SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
        button:SetSize(163, rowHeight)
        button:SetText(roleName)

        -- Comprueba si el rol está asignado a un jugador en addonCache
        local assignedPlayer = getAssignedPlayer(roleName)

        if assignedPlayer then
            button:SetText(assignedPlayer .. "\n" .. roleName) -- Actualiza el texto del botón con el nombre del jugador y el rol
            button:SetAttribute("player", assignedPlayer) -- Establece la propiedad 'player' del botón con el nombre del jugador
        end

        button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        button:SetScript("OnClick", function(self, mouseButton)
                SendRoleAlert(roleName, self)
        end)

        local resetButton = CreateFrame("Button", nil, content, "RaidAssistButtonTemplate")
        resetButton:GetFontString():SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
        resetButton:SetText("X")
        resetButton:SetPoint("LEFT", button, "RIGHT", 2, 0)
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
