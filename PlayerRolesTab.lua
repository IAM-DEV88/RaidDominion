function PlayerRolesTabContainerInit()
    -- Crear las pestañas
    local PlayerRolesTabContainer = CreateFrame("Frame", nil, QuickNameRoleTab)
    PlayerRolesTabContainer:SetPoint("TOP", 0, 0)
    PlayerRolesTabContainer:SetSize(430, 25)

    function secondarySelectionContainer()
        if not secondarySelectionFrame then
            secondarySelectionFrame = CreateFrame("Frame", nil, PlayerRolesTabContainer)
            secondarySelectionFrame:SetPoint("TOP", -14, -3)
            secondarySelectionFrame:SetSize(430, 230)

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
        if extraSelectionFrame then
            extraSelectionFrame:Hide()
        end
    end

    function primarySelectionContainer()
        if not primarySelectionFrame then
            primarySelectionFrame = CreateFrame("Frame", nil, PlayerRolesTabContainer)
            primarySelectionFrame:SetPoint("TOP", -14, -3)
            primarySelectionFrame:SetSize(430, 230)

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
        if extraSelectionFrame then
            extraSelectionFrame:Hide()
        end
    end

    function buffSelectionContainer()
        if not buffSelectionFrame then
            buffSelectionFrame = CreateFrame("Frame", nil, PlayerRolesTabContainer)
            buffSelectionFrame:SetPoint("TOP", -14, -3)
            buffSelectionFrame:SetSize(430, 230)

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
        if extraSelectionFrame then
            extraSelectionFrame:Hide()
        end
    end

    function skillSelectionContainer()
        if not skillSelectionFrame then
            skillSelectionFrame = CreateFrame("Frame", nil, PlayerRolesTabContainer)
            skillSelectionFrame:SetPoint("TOP", -14, -3)
            skillSelectionFrame:SetSize(430, 230)

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
        if extraSelectionFrame then
            extraSelectionFrame:Hide()
        end
    end

    function extraSelectionContainer()
        if not extraSelectionFrame then
            extraSelectionFrame = CreateFrame("Frame", nil, PlayerRolesTabContainer)
            extraSelectionFrame:SetPoint("TOP", -14, -3)
            extraSelectionFrame:SetSize(430, 230)

            local content = extraSelection()
            content:SetParent(extraSelectionFrame)
            content:SetPoint("TOPLEFT")
            content:Show()
        end
        extraSelectionFrame:Show()
        if primarySelectionFrame then
            primarySelectionFrame:Hide()
        end
        if buffSelectionFrame then
            buffSelectionFrame:Hide()
        end
        if secondarySelectionFrame then
            secondarySelectionFrame:Hide()
        end
        if skillSelectionFrame then
            skillSelectionFrame:Hide()
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
        elseif tabName == "EXTRA" then
            -- Función para cambiar a la pestaña de roles de habilidades
            extraSelectionContainer()
            -- Agrega el código aquí para cambiar a la pestaña de EXTRA
        elseif tabName == "SECONDARY" then
            secondarySelectionContainer()
            -- Función para cambiar a la pestaña de roles secundarios
            -- Agrega el código aquí para cambiar a la pestaña de SECONDARY
        end
    end
    -- Crear las pestañas y configurarlas
    local buttonWidth = 25
    local buttonHeight = 25
    local buttonSpacing = 1
    local verticalMargin = 4

    local previousTabButton = nil
    local tabs = {}
    local selectedTab = nil

    local function SelectTab(tabName)
        for _, tab in pairs(tabs) do
            if tab:GetText() == tabName then
                tab:LockHighlight()
                selectedTab = tabName
            else
                tab:UnlockHighlight()
            end
        end
        SwitchTab(tabName)
    end

    for tabName, _ in pairs(playerRoles) do
        local tabButton = CreateFrame("Button", tabName .. "Tab", PlayerRolesTabContainer,
            "CharacterFrameTabButtonTemplate")
        if previousTabButton then
            tabButton:SetPoint("LEFT", previousTabButton, "RIGHT", buttonSpacing, 0)
        else
            tabButton:SetPoint("LEFT", PlayerRolesTabContainer, "LEFT", 20, 0)
        end
        tabButton:SetSize(buttonWidth, buttonHeight)
        tabButton:SetText(tabName)
        tabButton:GetFontString():SetFont("Fonts\\FRIZQT__.TTF", 9)
        tabButton:SetScript("OnClick", function()
            SelectTab(tabName)
        end)
        tabButton:SetPoint("TOP", 0, -verticalMargin)
        previousTabButton = tabButton
        tabs[#tabs + 1] = tabButton
    end

    -- Inicializar la primera pestaña como seleccionada
    if #tabs > 0 then
        SelectTab(tabs[1]:GetText())
    end

    -- skillSelectionContainer()
    primarySelectionContainer()

    return PlayerRolesTabContainer
end
