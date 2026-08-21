--[[
    RD_UI_BandsStatus.lua
    PROPÓSITO: Estado de conexión de los jugadores de una banda vía el roster de
              la hermandad. Distingue "En línea" de "Desconectado" sin polling:
              la caché se reconstruye solo con GUILD_ROSTER_UPDATE (evento).
              Registra RD.ui.bandsStatus.
    API PÚBLICA:
        - RD.ui.bandsStatus:GetStatus(cleanName) -> true | false | nil
        - RD.ui.bandsStatus:EnsureLoaded()
        - RD.ui.bandsStatus:Invalidate()
    EVENTOS: Ninguno directo (lo dispara el gestor en GUILD_ROSTER_UPDATE).
]]

local addonName, private = ...
local RD = _G.RaidDominion or {}
_G.RaidDominion = RD

local BandsStatus = {}

local rosterCache = nil      -- cleanName -> true (online) / false (offline)
local rosterDirty = true
local rosterReady = false    -- true cuando el roster de la hermandad ya se descargó

local function CleanName(name)
    if RD.UIUtils and RD.UIUtils.CleanName then
        return RD.UIUtils.CleanName(name)
    end
    return string.lower(tostring(name or ""))
end

-- Reconstruye la caché a partir del roster de la hermandad (una sola pasada).
local function RebuildRosterCache()
    rosterCache = {}
    if IsInGuild() and rosterReady then
        for i = 1, GetNumGuildMembers(true) do
            local name = GetGuildRosterInfo(i)
            if name and name ~= "" then
                local connected = select(9, GetGuildRosterInfo(i))
                rosterCache[CleanName(name)] = (tonumber(connected) == 1)
            end
        end
    end
    rosterDirty = false
end

-- Estado de un jugador: true=online, false=offline, nil=no afiliado a la hermandad
function BandsStatus:GetStatus(cleanName)
    if rosterDirty then RebuildRosterCache() end
    return rosterCache[cleanName]
end

-- GUILD_ROSTER_UPDATE: el roster ya está disponible; invalida la caché.
function BandsStatus:Invalidate()
    rosterReady = true
    rosterDirty = true
end

-- Solicita el roster una sola vez si aún no se recibió. Si ya hay datos
-- (GetNumGuildMembers > 0), los usa directamente sin re-descargar.
function BandsStatus:EnsureLoaded()
    if not IsInGuild() or rosterReady then return end
    if GetNumGuildMembers(true) > 0 then
        rosterReady = true
        rosterDirty = true
        return
    end
    pcall(GuildRoster)
end

RD.ui = RD.ui or {}
RD.ui.bandsStatus = BandsStatus
return BandsStatus
