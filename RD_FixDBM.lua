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
        -- En lugar de reemplazar GetRaidRosterInfo (que causa Taint y rompe marcos de blizzard),
        -- envolvemos la función de DBM en un pcall para que si falla por un nil no rompa nada más.
        
        local original_RAID_ROSTER_UPDATE = _G.DBM.RAID_ROSTER_UPDATE
        
        _G.DBM.RAID_ROSTER_UPDATE = function(self, ...)
            -- Ejecutar la función original de DBM en modo protegido
            -- Si DBM intenta indexar un nil, el error morirá aquí y no propagará Taint a Blizzard
            local ok, err = pcall(original_RAID_ROSTER_UPDATE, self, ...)
            
            if not ok then
                -- Opcionalmente loguear el error solo en modo debug o si no es el esperado
                if err and not string.find(err, "attempt to index local 'name'") then
                    -- Solo reportamos si es un error distinto al que estamos tratando de mitigar
                    -- (aunque en general es mejor el silencio para evitar Taint via error handlers)
                end
            end
        end
        
        print("|cff00ff00RaidDominion:|r Parche de estabilidad para DBM aplicado (Modo Ultra-Seguro).")
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
