-- Function to initialize the RaidDominion panel
function RaidDominionPanelInit()
    -- SendSystemMessage("RaidDominionPanelInit")

    local panel = _G["RaidDominionPanel"]
    if not panel then return end
    
    PanelTemplates_SetNumTabs(panel, 3)
    PanelTemplates_SetTab(panel, 1)
    _G["RaidDominionRoleTab"]:Show()
    _G["RaidDominionOptionsTab"]:Hide()
    _G["RaidDominionAboutTab"]:Hide()

    _G["RaidDominionPanelTab1"]:SetScript("OnClick", function()
        PanelTemplates_SetTab(panel, 1)
        _G["RaidDominionRoleTab"]:Show()
        _G["RaidDominionAboutTab"]:Hide()
        _G["RaidDominionOptionsTab"]:Hide()
    end)

    _G["RaidDominionPanelTab2"]:SetScript("OnClick", function()
        PanelTemplates_SetTab(panel, 2)
        _G["RaidDominionRoleTab"]:Hide()
        _G["RaidDominionAboutTab"]:Hide()
        _G["RaidDominionOptionsTab"]:Show()
    end)

    _G["RaidDominionPanelTab3"]:SetScript("OnClick", function()
        PanelTemplates_SetTab(panel, 3)
        _G["RaidDominionRoleTab"]:Hide()
        _G["RaidDominionOptionsTab"]:Hide()
        _G["RaidDominionAboutTab"]:Show()
    end)
    RaidDominionTabContainerInit()
    rulesAndMechanicsInit()
end
