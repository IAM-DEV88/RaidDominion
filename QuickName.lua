local addonName = "QuickName"
local addonCache

-- Función para manejar eventos de addon cargado
local function OnEvent(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        -- print("ADDON_LOADED")
    elseif event == "PLAYER_LOGIN" then
        getPlayersInfo()
        -- print("PLAYER_LOGIN")
        QuickNamePanelInit()
        if not enabledAddon and not enabledPanel then
            print("QuickName esta desactivado, puedes usar /qname para ver las opciones")
        end
        if enabledPanel then
            QuickNamePanel:Show()
        else
            QuickNamePanel:Hide()
        end
        SLASH_QNAME1 = "/qname"
        SlashCmdList["QNAME"] = function()
            QuickNamePanel:Show(not QuickNamePanel:IsShown())
        end
        if enabledAddon then
            local initModifiers = CreateFrame("Frame")
            initModifiers:RegisterEvent("PLAYER_TARGET_CHANGED")
            initModifiers:SetScript("OnEvent", function(_, event, ...)
                if event == "PLAYER_TARGET_CHANGED" then
                    local targetName = UnitName("target")
                    local modifierPressed = IsAltKeyDown() and "ALT" or
                                                (IsControlKeyDown() and "CONTROL" or (IsShiftKeyDown() and "SHIFT"))
                    HandleClick(targetName, modifierPressed)
                end
            end)
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
        enabledAddon = (enabledAddonCheckbox:GetChecked() == 1) and true or false
        raidInfo = {}
        for k, v in pairs(addonCache) do
            raidInfo[k] = v
        end
    end
end

-- Crear un marco para manejar eventos
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_LOGOUT")
frame:RegisterEvent("PARTY_MEMBERS_CHANGED") -- Cambios en el grupo
frame:RegisterEvent("RAID_ROSTER_UPDATE") -- Cambios en la raid
frame:SetScript("OnEvent", OnEvent)