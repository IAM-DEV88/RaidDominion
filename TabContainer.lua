function QuickNameTabContainerInit()
    -- Crear las pestañas
    local QuickNameTabContainer = CreateFrame("Frame", nil, QuickNamePanel)
    QuickNameTabContainer:SetPoint("TOP", 0, -27)
    QuickNameTabContainer:SetSize(440, 25)

    local roleSelectionTab = CreateFrame("Button", "roleSelectionTab", QuickNameTabContainer, "UIPanelButtonTemplate")
    roleSelectionTab:SetPoint("LEFT", 11, 16)
    roleSelectionTab:SetSize(60, 25)
    roleSelectionTab:SetText("ROLES")
    roleSelectionTab:GetFontString():SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE") -- Estableciendo la fuente y el tamaño
    roleSelectionTab:SetScript("OnClick", function()
        roleSelectionContainer()
    end)

    function roleSelectionContainer()
        if not roleSelectionFrame then
            roleSelectionFrame = CreateFrame("Frame", nil, QuickNameTabContainer)
            roleSelectionFrame:SetPoint("TOP", -22, -5)
            roleSelectionFrame:SetSize(425, 490)

            local content = PlayerRolesTabContainerInit()
            content:SetParent(roleSelectionFrame)
            content:SetPoint("TOPLEFT")
            content:Show()
        end
        roleSelectionFrame:Show()
        if aboutFrame then
            aboutFrame:Hide()
        end
    end

    function aboutContainer()
        if not aboutFrame then
            aboutFrame = CreateFrame("Frame", nil, QuickNamePanel)
            aboutFrame:SetPoint("TOPLEFT", -5, -5)
            aboutFrame:SetSize(280, 120)
            -- Crear el diálogo de ayuda y mostrarlo en la pestaña
            local content = aboutContent()
            content:SetParent(aboutFrame)
            content:SetPoint("TOPLEFT")
            content:Show()
        end
        aboutFrame:Show()
        if roleSelectionFrame then
            roleSelectionFrame:Hide()
        end
    end
    -- Inicialmente, mostrar el contenido de la pestaña "Roles del grupo"
    roleSelectionContainer()
    -- aboutContainer()

    setRaidButton = CreateFrame("Button", "setRaidButton", QuickNameTabContainer, "UIPanelButtonTemplate")
    setRaidButton:SetPoint("LEFT", 71, 16)
    setRaidButton:SetSize(60, 25)
    setRaidButton:SetText("RAID")
    setRaidButton:GetFontString():SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE") -- Estableciendo la fuente y el tamaño
    setRaidButton:SetScript("OnClick", function()
        -- Chequear si el jugador ya está en un grupo de raid
        if GetNumRaidMembers() ~=0 then
            StaticPopup_Show("CONFIRM_READY_CHECK")
        else
            if GetNumPartyMembers() ~= 0 then
                ConvertToRaid()
                print("El grupo ahora es un raid.")
            else
                print("Debes estar en grupo para crear una raid.")
            end
        end
    end)
    

    local aboutTab = CreateFrame("Button", "aboutTab", QuickNameTabContainer, "UIPanelButtonTemplate")
    aboutTab:SetPoint("RIGHT", -63, 16)
    aboutTab:SetSize(26, 26)
    aboutTab:SetText("?")
    aboutTab:GetFontString():SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE") -- Estableciendo la fuente y el tamaño
    aboutTab:SetScript("OnClick", function()
        aboutContainer()
    end)

    local reloadButton = CreateFrame("Button", nil, QuickNameTabContainer, "UIPanelButtonTemplate")
    reloadButton:GetFontString():SetFont("Fonts\\FRIZQT__.TTF", 6, "OUTLINE") -- Estableciendo la fuente y el tamaño
    reloadButton:SetPoint("TOPRIGHT", -35, 16)
    reloadButton:SetSize(26, 26)
    reloadButton:SetText("RELOAD")
    reloadButton:SetScript("OnClick", function()
        ReloadUI()
    end)
end
