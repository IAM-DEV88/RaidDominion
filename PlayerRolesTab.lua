function PlayerRolesTabContainerInit()
    -- Crear las pestañas
    local PlayerRolesTabContainer = CreateFrame("Frame", nil, QuickNameTabContainer)
    PlayerRolesTabContainer:SetPoint("TOP", 0, -27)
    PlayerRolesTabContainer:SetSize(440, 25)

    local buttonWidth = 60
    local buttonHeight = 25
    local buttonSpacing = 0
    local xOffset = 26

    for tabName, _ in pairs(playerRoles) do
        local tabButton = CreateFrame("Button", tabName .. "Tab", PlayerRolesTabContainer, "UIPanelButtonTemplate")
        tabButton:SetPoint("LEFT", xOffset, -30)
        tabButton:SetSize(buttonWidth, buttonHeight)
        tabButton:SetText(tabName)
        tabButton:GetFontString():SetFont("Fonts\\FRIZQT__.TTF", 8, "OUTLINE")
        tabButton:SetScript("OnClick", function()
            SwitchTab(tabName)
        end)
        xOffset = xOffset + buttonWidth + buttonSpacing
    end

    function secondarySelectionContainer()
        if not secondarySelectionFrame then
            secondarySelectionFrame = CreateFrame("Frame", nil, PlayerRolesTabContainer)
            secondarySelectionFrame:SetPoint("TOP", -7, 0)
            secondarySelectionFrame:SetSize(425, 210)

            local content = secondarySelection()
            content:SetParent(secondarySelectionFrame)
            content:SetPoint("TOPLEFT")
            content:Show()
        end
        secondarySelectionFrame:Show()
        if buffSelectionFrame then
            buffSelectionFrame:Hide()
        end
        if skillSelectionFrame then
            skillSelectionFrame:Hide()
        end
        if primarySelectionFrame then
            primarySelectionFrame:Hide()
        end
    end

    function primarySelectionContainer()
        if not primarySelectionFrame then
            primarySelectionFrame = CreateFrame("Frame", nil, PlayerRolesTabContainer)
            primarySelectionFrame:SetPoint("TOP", -7, 0)
            primarySelectionFrame:SetSize(425, 210)

            local content = primarySelection()
            content:SetParent(primarySelectionFrame)
            content:SetPoint("TOPLEFT")
            content:Show()
        end
        primarySelectionFrame:Show()
        if buffSelectionFrame then
            buffSelectionFrame:Hide()
        end
        if skillSelectionFrame then
            skillSelectionFrame:Hide()
        end
        if secondarySelectionFrame then
            secondarySelectionFrame:Hide()
        end
    end

    function buffSelectionContainer()
        if not buffSelectionFrame then
            buffSelectionFrame = CreateFrame("Frame", nil, PlayerRolesTabContainer)
            buffSelectionFrame:SetPoint("TOP", -7, 0)
            buffSelectionFrame:SetSize(425, 210)

            local content = buffSelection()
            content:SetParent(buffSelectionFrame)
            content:SetPoint("TOPLEFT")
            content:Show()
        end
        buffSelectionFrame:Show()
        if primarySelectionFrame then
            primarySelectionFrame:Hide()
        end
        if skillSelectionFrame then
            skillSelectionFrame:Hide()
        end
        if secondarySelectionFrame then
            secondarySelectionFrame:Hide()
        end
    end

    function skillSelectionContainer()
        if not skillSelectionFrame then
            skillSelectionFrame = CreateFrame("Frame", nil, PlayerRolesTabContainer)
            skillSelectionFrame:SetPoint("TOP", -7, 0)
            skillSelectionFrame:SetSize(425, 210)

            local content = skillSelection()
            content:SetParent(skillSelectionFrame)
            content:SetPoint("TOPLEFT")
            content:Show()
        end
        skillSelectionFrame:Show()
        if primarySelectionFrame then
            primarySelectionFrame:Hide()
        end
        if buffSelectionFrame then
            buffSelectionFrame:Hide()
        end
        if secondarySelectionFrame then
            secondarySelectionFrame:Hide()
        end
    end

    function SwitchTab(tabName)
        if tabName == "PRIMARY" then
            -- Función para cambiar a la pestaña de roles principales
            primarySelectionContainer()
        elseif tabName == "BUFF" then
            buffSelectionContainer()
            -- Función para cambiar a la pestaña de roles de buff
            -- Agrega el código aquí para cambiar a la pestaña de BUFF
        elseif tabName == "SKILL" then
            -- Función para cambiar a la pestaña de roles de habilidades
            skillSelectionContainer()
            -- Agrega el código aquí para cambiar a la pestaña de SKILL
        elseif tabName == "SECONDARY" then
            secondarySelectionContainer()
            -- Función para cambiar a la pestaña de roles secundarios
            -- Agrega el código aquí para cambiar a la pestaña de SECONDARY
        end
    end

            -- skillSelectionContainer()
            primarySelectionContainer()

    xOffset = 205

    local alertPlayersBtn = CreateFrame("Button", "AlertFarPlayers", PlayerRolesTabContainer, "UIPanelButtonTemplate")
    alertPlayersBtn:GetFontString():SetFont("Fonts\\FRIZQT__.TTF", 8, "OUTLINE") -- Estableciendo la fuente y el tamaño
    alertPlayersBtn:SetPoint("LEFT", xOffset + buttonWidth + buttonSpacing, -30)
    alertPlayersBtn:SetSize(60, 25)
    alertPlayersBtn:SetText("AFK/OFFs")
    alertPlayersBtn:SetScript("OnClick", function()
        local hasTarget = UnitExists("target")
        local _, channel = getPlayerInitialState()
        local targetName = UnitName("target")
        local targetInRaid = addonCache[targetName] and true or false
        -- Si no hay ningún jugador seleccionado o el objetivo no está en la raid, enviar un mensaje indicando que se está buscando el rol
        if hasTarget and targetInRaid then
            SendChatMessage("El jugador " .. targetName .. " ha estado AFK/OFF por mucho tiempo", channel)
        else
            AlertFarPlayers()
        end
    end)
    xOffset = xOffset + buttonWidth + buttonSpacing

    local reqBuffsBtn = CreateFrame("Button", "RequestBuffs", PlayerRolesTabContainer, "UIPanelButtonTemplate")
    reqBuffsBtn:GetFontString():SetFont("Fonts\\FRIZQT__.TTF", 8, "OUTLINE") -- Estableciendo la fuente y el tamaño
    reqBuffsBtn:SetPoint("LEFT", xOffset + buttonWidth + buttonSpacing, -30)
    reqBuffsBtn:SetSize(60, 25)
    reqBuffsBtn:SetText("BUFF/CHECK")
    reqBuffsBtn:SetScript("OnClick", RequestBuffs)
    xOffset = xOffset + buttonWidth + buttonSpacing

    local wpLootBtn = CreateFrame("Button", "WpLoot", PlayerRolesTabContainer, "UIPanelButtonTemplate")
    wpLootBtn:GetFontString():SetFont("Fonts\\FRIZQT__.TTF", 8, "OUTLINE") -- Estableciendo la fuente y el tamaño
    wpLootBtn:SetPoint("LEFT", xOffset + buttonWidth + buttonSpacing, -30)
    wpLootBtn:SetSize(60, 25)
    wpLootBtn:SetText("WP/LOOT")
    wpLootBtn:SetScript("OnClick", WpLoot)

    return PlayerRolesTabContainer
end
