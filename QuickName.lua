local addonName = "QuickName"

-- Function to handle events
local function OnEvent(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        -- print("ADDON_LOADED")
        getPlayersInfo()
        
        
    elseif event == "PLAYER_LOGIN" then
        getPlayersInfo()
        QuickNamePanelInit()

        -- print("PLAYER_LOGIN")
        if not enabledPanel then
            print("Puedes usar /qname para ver mostrar el panel de RaidAssist")
        end
        if enabledPanel then
            QuickNamePanel:Show()
        else
            QuickNamePanel:Hide()
        end
        SLASH_QNAME1 = "/qname"
        SlashCmdList["QNAME"] = function()
            if QuickNamePanel:IsShown() then
                QuickNamePanel:Hide()
            else
                QuickNamePanel:Show()
            end
        end
    elseif event == "PARTY_MEMBERS_CHANGED" then
        -- print("PARTY_MEMBERS_CHANGED")
        getPlayersInfo()
    elseif event == "RAID_ROSTER_UPDATE" then
        -- print("RAID_ROSTER_UPDATE")
        getPlayersInfo()
    elseif event == "PLAYER_LOGOUT" then
        -- print("PLAYER_LOGOUT")
        enabledPanel = (enabledPanelCheckbox:GetChecked() == 1) and true or false
        raidInfo = {}
        for k, v in (raidInfo) do
            raidInfo[k] = v
        end
    end
end

-- Create a frame to handle events
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_LOGOUT")
frame:RegisterEvent("PARTY_MEMBERS_CHANGED") -- Group changes
frame:RegisterEvent("RAID_ROSTER_UPDATE") -- Raid roster changes
frame:SetScript("OnEvent", OnEvent)
