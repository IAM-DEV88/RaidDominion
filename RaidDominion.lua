local addonName = "RaidDominion"

-- Function to handle events
local function OnEvent(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        -- print("ADDON_LOADED")
        getPlayersInfo()
        
    elseif event == "PLAYER_LOGIN" then
        getPlayersInfo()
        RaidDominionPanelInit()

        -- print("PLAYER_LOGIN")
        if not enabledPanel then
            print("Puedes usar /rdom para mostrar el panel de RaidDominion")
        end
        if enabledPanel then
            RaidDominionPanel:Show()
        else
            RaidDominionPanel:Hide()
        end
        SLASH_RDOM1 = "/rdom"
        SlashCmdList["RDOM"] = function()
            if RaidDominionPanel:IsShown() then
                RaidDominionPanel:Hide()
            else
                RaidDominionPanel:Show()
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

        for k, v in (addonCache) do
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
