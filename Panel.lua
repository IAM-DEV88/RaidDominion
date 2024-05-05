function QuickNamePanelInit()
    -- Crear la ventana principal
    QuickNamePanel = CreateFrame("Frame", "QuickName_MainFrame", UIParent)
    QuickNamePanel:SetSize(440, 210)
    QuickNamePanel:SetPoint("CENTER")
    QuickNamePanel:EnableMouse(true)
    QuickNamePanel:SetMovable(true)
    QuickNamePanel:RegisterForDrag("LeftButton")
    QuickNamePanel:SetScript("OnDragStart", QuickNamePanel.StartMoving)
    QuickNamePanel:SetScript("OnDragStop", QuickNamePanel.StopMovingOrSizing)
    QuickNamePanel:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = {
            left = 11,
            right = 12,
            top = 12,
            bottom = 11
        }
    })
    QuickNamePanel:SetBackdropBorderColor(0.4, 0.4, 0.4)
    QuickNamePanel:SetFrameStrata("MEDIUM")
    QuickNamePanel:SetFrameLevel(10)

    -- Crear el título de la ventana
    local title = QuickNamePanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOP", 0, 2)
    title:SetText("QuickName")

    -- Botón de cerrar
    closeButton = CreateFrame("Button", nil, QuickNamePanel, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", QuickNamePanel, "TOPRIGHT", 10, 10)
    closeButton:SetScript("OnClick", function()
        QuickNamePanel:Hide()
    end)

    QuickNameTabContainerInit()

    rulesAndMechanicsInit()

end