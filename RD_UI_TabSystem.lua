--[[
    RD_UI_TabSystem.lua
    PURPOSE: Tab system for configuration windows
    DEPENDENCIES: RD_UI_Utils.lua
    PUBLIC API:
        - RaidDominion.TabSystem:CreateTab(parent, id, name, width, height)
        - RaidDominion.TabSystem:SetActiveTab(tabId)
        - RaidDominion.TabSystem:GetActiveContent()
]]

local addonName, private = ...
local UIUtils = RaidDominion.UIUtils

local TabSystem = {
    tabs = {},
    activeTab = nil
}

-- Create a new tab button
function TabSystem:CreateTab(parent, id, name, width, height)
    local tab = CreateFrame("Button", "RaidDominionTab_"..id, parent, "CharacterFrameTabButtonTemplate")
    tab:SetID(#self.tabs + 1)
    tab:SetText(name)
    tab:SetWidth(width or 100)
    tab:SetHeight(height or 30)
    
    -- Store tab data
    tab.id = id
    tab.content = CreateFrame("Frame", nil, parent)
    tab.content:Hide()
    
    -- Add to tabs list
    self.tabs[#self.tabs + 1] = tab
    
    -- Position the tab
    if #self.tabs == 1 then
        tab:SetPoint("TOPLEFT", parent, "BOTTOMLEFT", 5, 0)
    else
        tab:SetPoint("LEFT", self.tabs[#self.tabs-1], "RIGHT", -5, 0)
    end
    
    -- Set up highlight texture
    local highlight = tab:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetTexture("Interface/PaperDollInfoFrame/UI-Character-ActiveTab")
    highlight:SetHeight(35)
    highlight:SetPoint("LEFT", 0, 0)
    highlight:SetPoint("RIGHT", 0, 0)
    highlight:SetTexCoord(0.15625, 0.84375, 0, 1)
    tab:SetHighlightTexture(highlight)
    
    return tab
end

-- Set the active tab
function TabSystem:SetActiveTab(tabId)
    -- Hide all tab contents
    for _, tab in ipairs(self.tabs) do
        tab.content:Hide()
    end
    
    -- Show selected tab content
    for _, tab in ipairs(self.tabs) do
        if tab.id == tabId then
            tab.content:Show()
            self.activeTab = tab
            PanelTemplates_SetTab(parent, tab:GetID())
            break
        end
    end
end

-- Get the active tab's content frame
function TabSystem:GetActiveContent()
    return self.activeTab and self.activeTab.content or nil
end

-- Register module
RaidDominion.TabSystem = TabSystem
return TabSystem
