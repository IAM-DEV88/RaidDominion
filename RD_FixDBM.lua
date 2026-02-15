--[[
    RD_FixDBM.lua
    Fixes "table index is nil" error in DBM-Core.lua by monkey-patching
    the RAID_ROSTER_UPDATE and PARTY_MEMBERS_CHANGED functions.
    
    This version uses a "temporary hooking" approach to avoid using the 'debug' 
    library, which may be disabled in some environments.
]]

local function FixDBM()
    if not _G.DBM or not _G.DBM.RAID_ROSTER_UPDATE then return end
    
    local DBM = _G.DBM
    
    -- Fix RAID_ROSTER_UPDATE
    local old_RAID_ROSTER_UPDATE = DBM.RAID_ROSTER_UPDATE
    DBM.RAID_ROSTER_UPDATE = function(self, ...)
        local old_GetRaidRosterInfo = _G.GetRaidRosterInfo
        
        -- Temporary hook to ensure 'name' is never nil when DBM processes it
        _G.GetRaidRosterInfo = function(index)
            local name, rank, subgroup, level, class, fileName, zone, online, isDead, role, isML = old_GetRaidRosterInfo(index)
            if not name then
                -- Return a dummy name to prevent DBM from crashing on raid[name]
                -- This entry will be automatically cleaned up by DBM's own logic 
                -- at the end of the update loop if it's not "updated" again.
                return "DBM_NIL_FIX", 0, 1, 1, "UNKNOWN", "UNKNOWN"
            end
            return name, rank, subgroup, level, class, fileName, zone, online, isDead, role, isML
        end
        
        local ok, err = pcall(old_RAID_ROSTER_UPDATE, self, ...)
        
        -- Restore original function immediately
        _G.GetRaidRosterInfo = old_GetRaidRosterInfo
        
        if not ok then
            -- Log error but don't crash the hook
            if _G.geterrorhandler then
                _G.geterrorhandler()(err)
            else
                print("|cffff0000DBM Patch Error:|r", err)
            end
        end
    end

    -- Fix PARTY_MEMBERS_CHANGED
    local old_PARTY_MEMBERS_CHANGED = DBM.PARTY_MEMBERS_CHANGED
    if old_PARTY_MEMBERS_CHANGED then
        DBM.PARTY_MEMBERS_CHANGED = function(self, ...)
            local old_UnitName = _G.UnitName
            
            -- Temporary hook for UnitName
            _G.UnitName = function(unit)
                local name, server = old_UnitName(unit)
                if not name and unit and (unit:find("party") or unit == "player") then
                    return "DBM_NIL_FIX", server
                end
                return name, server
            end
            
            local ok, err = pcall(old_PARTY_MEMBERS_CHANGED, self, ...)
            
            -- Restore original function immediately
            _G.UnitName = old_UnitName
            
            if not ok then
                if _G.geterrorhandler then
                    _G.geterrorhandler()(err)
                else
                    print("|cffff0000DBM Patch Error (Party):|r", err)
                end
            end
        end
    end
    
    -- Success message in chat (optional, but helpful for verification)
    print("|cff00ff00RaidDominion:|r DBM-Core compatibility patch applied.")
end

-- Create a frame to wait for DBM to load
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(self, event, addon)
    if addon == "DBM-Core" then
        FixDBM()
    end
end)

-- Also try fixing it immediately in case DBM is already loaded
if _G.DBM and _G.DBM.RAID_ROSTER_UPDATE then
    FixDBM()
end
