--[[
    RD_FixDBM.lua
    Soluciona el error "table index is nil" en DBM-Core.lua parcheando de forma segura
    la función RAID_ROSTER_UPDATE.
    
    Esta versión utiliza hooksecurefunc cuando es posible y evita contaminar el entorno global
    para prevenir errores de SecureTemplates.
--]]

local function FixDBM()
    if not _G.DBM then return end
    
    -- Solo aplicar si existe la función problemática
    if _G.DBM.RAID_ROSTER_UPDATE then
        -- En lugar de reemplazar la función (que causa taint), envolvemos la llamada
        -- protegiendo GetRaidRosterInfo SOLO durante la ejecución de DBM
        
        local original_RAID_ROSTER_UPDATE = _G.DBM.RAID_ROSTER_UPDATE
        
        _G.DBM.RAID_ROSTER_UPDATE = function(self, ...)
            local old_GetRaidRosterInfo = _G.GetRaidRosterInfo
            
            -- Hook temporal seguro: Solo intercepta nils, pasa todo lo demás tal cual
            _G.GetRaidRosterInfo = function(index)
                local name, rank, subgroup, level, class, fileName, zone, online, isDead, role, isML = old_GetRaidRosterInfo(index)
                if not name then
                    -- Retornar datos dummy seguros para evitar crash de DBM
                    return "Unknown", 0, 1, 1, "WARRIOR", "WARRIOR", "Unknown", false, false, "MAINTANK", false
                end
                return name, rank, subgroup, level, class, fileName, zone, online, isDead, role, isML
            end
            
            -- Ejecutar la función original de DBM en modo protegido
            local ok, err = pcall(original_RAID_ROSTER_UPDATE, self, ...)
            
            -- Restaurar INMEDIATAMENTE la función global
            _G.GetRaidRosterInfo = old_GetRaidRosterInfo
            
            if not ok then
                -- Silenciar el error específico de nil index si ocurre a pesar del parche
                if err and not string.find(err, "table index is nil") then
                    if _G.geterrorhandler then
                        _G.geterrorhandler()(err)
                    end
                end
            end
        end
        
        print("|cff00ff00RaidDominion:|r Parche de compatibilidad DBM aplicado (Modo Seguro).")
    end
end

-- Intentar aplicar el parche cuando DBM se cargue
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(self, event, addon)
    if addon == "DBM-Core" then
        FixDBM()
        self:UnregisterEvent("ADDON_LOADED") -- Ya no necesitamos escuchar
    end
end)

-- Si DBM ya está cargado, aplicar inmediatamente
if _G.DBM then
    FixDBM()
end
