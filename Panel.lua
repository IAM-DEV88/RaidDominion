-- Function to initialize the QuickName panel
function QuickNamePanelInit()
    -- SendSystemMessage("QuickNamePanelInit")

    local panel = _G["QuickNamePanel"]
    if not panel then return end
    
    PanelTemplates_SetNumTabs(panel, 3)
    PanelTemplates_SetTab(panel, 1)
    _G["QuickNameRoleTab"]:Show()
    _G["QuickNameOptionsTab"]:Hide()
    _G["QuickNameAboutTab"]:Hide()

    _G["QuickNamePanelTab1"]:SetScript("OnClick", function()
        PanelTemplates_SetTab(panel, 1)
        _G["QuickNameRoleTab"]:Show()
        _G["QuickNameAboutTab"]:Hide()
        _G["QuickNameOptionsTab"]:Hide()
    end)

    _G["QuickNamePanelTab2"]:SetScript("OnClick", function()
        PanelTemplates_SetTab(panel, 2)
        _G["QuickNameRoleTab"]:Hide()
        _G["QuickNameAboutTab"]:Hide()
        _G["QuickNameOptionsTab"]:Show()
    end)

    _G["QuickNamePanelTab3"]:SetScript("OnClick", function()
        PanelTemplates_SetTab(panel, 3)
        _G["QuickNameRoleTab"]:Hide()
        _G["QuickNameOptionsTab"]:Hide()
        _G["QuickNameAboutTab"]:Show()
    end)

    QuickNameTabContainerInit()
    rulesAndMechanicsInit()
end
