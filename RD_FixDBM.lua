--[[
    RD_FixDBM.lua
    Fixes "table index is nil" error in DBM-Core.lua by monkey-patching
    the RAID_ROSTER_UPDATE and PARTY_MEMBERS_CHANGED functions.
]]

local function FixDBM()
    if not _G.DBM or not _G.DBM.RAID_ROSTER_UPDATE then return end
    
    local DBM = _G.DBM
    local raid, inRaid, fireEvent, sendSync, enableIcons
    local old_RAID_ROSTER_UPDATE = DBM.RAID_ROSTER_UPDATE
    local old_PARTY_MEMBERS_CHANGED = DBM.PARTY_MEMBERS_CHANGED
    
    -- Function to update upvalues in DBM's original scope
    local function UpdateDBMUpvalue(name, value)
        local i = 1
        while true do
            local n = debug.getupvalue(old_RAID_ROSTER_UPDATE, i)
            if not n then break end
            if n == name then
                debug.setupvalue(old_RAID_ROSTER_UPDATE, i, value)
                return true
            end
            i = i + 1
        end
        return false
    end

    -- Get initial references to DBM's locals
    local i = 1
    while true do
        local name, value = debug.getupvalue(old_RAID_ROSTER_UPDATE, i)
        if not name then break end
        if name == "raid" then raid = value
        elseif name == "inRaid" then inRaid = value
        elseif name == "fireEvent" then fireEvent = value
        elseif name == "sendSync" then sendSync = value
        elseif name == "enableIcons" then enableIcons = value
        end
        i = i + 1
    end
    
    -- Fallback for raid table if not found in RAID_ROSTER_UPDATE
    if not raid and DBM.GetRaidUnitId then
        local j = 1
        while true do
            local name, value = debug.getupvalue(DBM.GetRaidUnitId, j)
            if not name then break end
            if name == "raid" then raid = value end
            j = j + 1
        end
    end

    if not raid then return end

    -- Patch RAID_ROSTER_UPDATE
    DBM.RAID_ROSTER_UPDATE = function(self)
        if GetNumRaidMembers() >= 1 then
            local playerWithHigherVersionPromoted = false
            for i = 1, GetNumRaidMembers() do
                local name, rank, subgroup, _, _, fileName = GetRaidRosterInfo(i)
                if name then
                    if (not raid[name]) and inRaid then
                        if fireEvent then fireEvent("raidJoin", name) end
                    end
                    raid[name] = raid[name] or {}
                    raid[name].name = name
                    raid[name].rank = rank
                    raid[name].subgroup = subgroup
                    raid[name].class = fileName
                    raid[name].id = "raid"..i
                    raid[name].updated = true
                    if not playerWithHigherVersionPromoted and rank >= 1 and raid[name].version and raid[name].version > tonumber(DBM.Version) then
                        playerWithHigherVersionPromoted = true
                    end
                end
            end
            
            enableIcons = not playerWithHigherVersionPromoted
            UpdateDBMUpvalue("enableIcons", enableIcons)

            if not inRaid then
                inRaid = true
                UpdateDBMUpvalue("inRaid", true)
                if sendSync then sendSync("DBMv4-Ver", "Hi!") end
                self:Schedule(2, DBM.RequestTimers, DBM)
                local playerName = UnitName("player")
                if fireEvent and playerName then fireEvent("raidJoin", playerName) end
            end
            
            for i, v in pairs(raid) do
                if not v.updated then
                    raid[i] = nil
                    if fireEvent then fireEvent("raidLeave", i) end
                else
                    v.updated = nil
                end
            end
        else
            inRaid = false
            UpdateDBMUpvalue("inRaid", false)
            enableIcons = true
            UpdateDBMUpvalue("enableIcons", true)
            local playerName = UnitName("player")
            if fireEvent and playerName then fireEvent("raidLeave", playerName) end
        end
    end

    -- Patch PARTY_MEMBERS_CHANGED
    if old_PARTY_MEMBERS_CHANGED then
        DBM.PARTY_MEMBERS_CHANGED = function(self)
            if GetNumRaidMembers() > 0 then return end
            if GetNumPartyMembers() >= 1 then
                if not inRaid then
                    inRaid = true
                    UpdateDBMUpvalue("inRaid", true)
                    if sendSync then sendSync("DBMv4-Ver", "Hi!") end
                    self:Schedule(2, DBM.RequestTimers, DBM)
                    local playerName = UnitName("player")
                    if fireEvent and playerName then fireEvent("partyJoin", playerName) end
                end
                
                for i = 0, GetNumPartyMembers() do
                    local id = (i == 0) and "player" or "party"..i
                    local name, server = UnitName(id)
                    if name then
                        local rank, _, fileName = UnitIsPartyLeader(id), UnitClass(id)
                        if server and server ~= ""  then
                            name = name.."-"..server
                        end
                        if (not raid[name]) and inRaid then
                            if fireEvent then fireEvent("partyJoin", name) end
                        end
                        raid[name] = raid[name] or {}
                        raid[name].name = name
                        raid[name].rank = rank and 2 or 0
                        raid[name].class = fileName
                        raid[name].id = id
                        raid[name].updated = true
                    end
                end
                for i, v in pairs(raid) do
                    if not v.updated then
                        raid[i] = nil
                        if fireEvent then fireEvent("partyLeave", i) end
                    else
                        v.updated = nil
                    end
                end
            else
                inRaid = false
                UpdateDBMUpvalue("inRaid", false)
                enableIcons = true
                UpdateDBMUpvalue("enableIcons", true)
            end
        end
    end
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
if _G.DBM then
    FixDBM()
end
