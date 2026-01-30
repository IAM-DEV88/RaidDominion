--[[
    RD_UI_Utils.lua
    PURPOSE: General UI utility functions for RaidDominion
    PUBLIC API:
        - RaidDominion.UIUtils:CreateFrame(name, parent, template, width, height)
        - RaidDominion.UIUtils:CreateButton(name, parent, text, width, height, onClick)
        - RaidDominion.UIUtils:CreateHelpSection(parent, title, content, yOffset)
        - RaidDominion.UIUtils:CreateCheckbox(name, parent, label, onClick)
        - RaidDominion.UIUtils:CreateScrollFrame(name, parent, width, height)
]]

local addonName, private = ...
local UIUtils = {}

-- =============================================
-- UTILIDADES DE STRINGS Y NOMBRES
-- =============================================

local cleanNameCache = {}
local cleanNameCacheSize = 0

--- Limpia un nombre eliminando el reino y normalizando a minúsculas
-- @param name string El nombre a limpiar
-- @return string El nombre limpio
function UIUtils.CleanName(name)
    if not name then return "" end
    if cleanNameCache[name] then return cleanNameCache[name] end
    
    -- Eliminar reino y cualquier espacio en blanco accidental
    local clean = string.gsub(name, "%-.*", "")
    clean = string.gsub(clean, "%s+", "")
    local result = string.lower(clean)
    
    -- Limitar tamaño de caché para evitar fuga de memoria
    if cleanNameCacheSize > 1000 then 
        wipe(cleanNameCache) 
        cleanNameCacheSize = 0
    end
    
    cleanNameCache[name] = result
    cleanNameCacheSize = cleanNameCacheSize + 1
    
    return result
end

local capitalizedNamesCache = {}

--- Capitaliza un nombre (Primera letra Mayúscula, resto minúsculas)
-- @param name string El nombre a capitalizar
-- @return string El nombre capitalizado
function UIUtils.CapitalizeName(name)
    if not name or name == "" then return "" end
    if capitalizedNamesCache[name] then return capitalizedNamesCache[name] end
    
    local cleanName = string.gsub(name, "%-.*", "")
    local result = string.upper(string.sub(cleanName, 1, 1)) .. string.lower(string.sub(cleanName, 2))
    
    capitalizedNamesCache[name] = result
    return result
end

-- =============================================
-- DETECCIÓN DE TALENTOS Y ESPECIALIZACIÓN (3.3.5)
-- =============================================

local talentCache = {}
local SPEC_ABBR = {
    ["WARRIOR"] = { [1] = "Arm", [2] = "Fur", [3] = "Pro" },
    ["PALADIN"] = { [1] = "Hol", [2] = "Pro", [3] = "Ret" },
    ["HUNTER"] = { [1] = "BM", [2] = "Pun", [3] = "Sup" },
    ["ROGUE"] = { [1] = "Ase", [2] = "Com", [3] = "Sut" },
    ["PRIEST"] = { [1] = "Dis", [2] = "Sag", [3] = "Som" },
    ["DEATHKNIGHT"] = { [1] = "San", [2] = "Esc", [3] = "Pro" },
    ["SHAMAN"] = { [1] = "Ele", [2] = "Mej", [3] = "Res" },
    ["MAGE"] = { [1] = "Arc", [2] = "Fue", [3] = "Esc" },
    ["WARLOCK"] = { [1] = "Afl", [2] = "Dem", [3] = "Des" },
    ["DRUID"] = { [1] = "Equ", [2] = "Fer", [3] = "Res" }
}

--- Obtiene la especialización de una unidad basada en talentos
-- @param unit string La unidad a inspeccionar
-- @return string, number, string Abreviatura, índice de especialización, clase
function UIUtils.GetSpecFromTalents(unit)
    if not unit or not UnitExists(unit) then return nil end
    
    local guid = UnitGUID(unit)
    local now = GetTime()
    
    if talentCache[guid] and (now - talentCache[guid].time < 30) then
        local c = talentCache[guid]
        return c.abbr, c.specIndex, c.class
    end

    local _, class = UnitClass(unit)
    local r = {}
    local isInspect = (unit ~= "player")
    
    local hasPoints = false
    for i = 1, 3 do
        local name, icon, points = GetTalentTabInfo(i, isInspect)
        r[i] = { name = name, icon = icon, points = points or 0 }
        if (points or 0) > 0 then hasPoints = true end
    end

    if not hasPoints then return nil end
    
    local specIndex = 1
    local maxPoints = r[1].points
    
    if class == "PALADIN" then
        if r[2].points >= r[1].points and r[2].points >= r[3].points then specIndex = 2
        elseif r[1].points >= r[2].points and r[1].points >= r[3].points then specIndex = 1
        else specIndex = 3 end
    elseif class == "SHAMAN" then
        local function checkName(idx, searchList)
            if not r[idx].name then return false end
            local nameLower = string.lower(r[idx].name)
            for _, search in ipairs(searchList) do
                if string.find(nameLower, string.lower(search)) then return true end
            end
            return false
        end

        if r[3].points >= r[1].points and r[3].points >= r[2].points then specIndex = 3
        elseif r[2].points >= r[1].points and r[2].points > r[3].points then specIndex = 2
        else specIndex = 1 end
        
        local diffResMej = math.abs(r[3].points - r[2].points)
        local diffResEle = math.abs(r[3].points - r[1].points)
        
        if diffResMej <= 15 or diffResEle <= 15 then
            if checkName(3, {"Rest", "Res", "Restaur"}) then specIndex = 3
            elseif checkName(2, {"Mej", "Enh", "Mejora", "Enhanc"}) then specIndex = 2
            elseif checkName(1, {"Ele", "Element"}) then specIndex = 1 end
        end
        
        for i = 1, 3 do
            if r[i].points >= 40 then specIndex = i break end
        end
    elseif class == "DRUID" then
        if r[3].points >= r[1].points and r[3].points >= r[2].points then specIndex = 3
        elseif r[2].points >= r[1].points and r[2].points > r[3].points then specIndex = 2
        else specIndex = 1 end
    else
        if r[2].points > maxPoints then maxPoints = r[2].points specIndex = 2 end
        if r[3].points > maxPoints then maxPoints = r[3].points specIndex = 3 end
    end
    
    local abbr = SPEC_ABBR[class] and SPEC_ABBR[class][specIndex] or "N/A"
    talentCache[guid] = { abbr = abbr, specIndex = specIndex, class = class, time = now }
    
    return abbr, specIndex, class
end

-- =============================================
-- GESTIÓN DE ROSTER Y GRUPO
-- =============================================

local cachedRoster = nil
local lastRosterUpdate = 0

--- Construye una caché del roster actual
-- @return table La tabla de caché del roster
function UIUtils.BuildRosterCache()
    local now = GetTime()
    if cachedRoster and (now - lastRosterUpdate < 1) then
        return cachedRoster
    end

    local rosterCache = {}
    local numRaid = GetNumRaidMembers()
    local numParty = GetNumPartyMembers()

    if numRaid > 0 then
        for i = 1, numRaid do
            local unit = "raid"..i
            local name = UnitName(unit)
            if name and name ~= "Unknown" then
                local _, fileName = UnitClass(unit)
                local clean = UIUtils.CleanName(name)
                rosterCache[clean] = { name = name, class = fileName, unit = unit }
            end
        end
    elseif numParty > 0 then
        local myName = UnitName("player")
        if myName then
            local _, fileName = UnitClass("player")
            local clean = UIUtils.CleanName(myName)
            rosterCache[clean] = { name = myName, class = fileName, unit = "player" }
        end
        for i = 1, numParty do
            local unit = "party"..i
            local name = UnitName(unit)
            if name and name ~= "Unknown" then
                local _, fileName = UnitClass(unit)
                local clean = UIUtils.CleanName(name)
                rosterCache[clean] = { name = name, class = fileName, unit = unit }
            end
        end
    else
        local myName = UnitName("player")
        if myName then
            local _, fileName = UnitClass("player")
            local clean = UIUtils.CleanName(myName)
            rosterCache[clean] = { name = myName, class = fileName, unit = "player" }
        end
    end

    cachedRoster = rosterCache
    lastRosterUpdate = now
    return rosterCache
end

-- =============================================
-- SISTEMA DE SEGUIMIENTO DE AURAS (BUFFS/DEBUFFS)
-- =============================================

-- Función para manejar clics en buffs/auras
function UIUtils.HandleBuffClick(buffName)
    if RaidDominion and RaidDominion.HandleAssignableRole then
        RaidDominion:HandleAssignableRole(buffName)
    end
end

-- Función para enviar mensajes de auras al chat
local function SendAuraMessage(name, duration, expirationTime)
    if not name then return end
    
    local message
    
    -- Check if the aura has a duration (expirationTime > 0)
    if not expirationTime or expirationTime == 0 then
        message = string.format("Aura: %s (permanente)", name)
    else
        local timeLeft = expirationTime - GetTime()
        -- Handle expired auras
        if timeLeft <= 0 then
            message = string.format("Aura: %s - Tiempo agotado", name)
        else
            -- Format time as HH:MM:SS or MM:SS
            local hours = math.floor(timeLeft / 3600)
            local minutes = math.floor((timeLeft % 3600) / 60)
            local seconds = math.floor(timeLeft % 60)
            
            if hours > 0 then
                message = string.format("Aura: %s - Tiempo restante: %d:%02d:%02d", name, hours, minutes, seconds)
            else
                message = string.format("Aura: %s - Tiempo restante: %d:%02d", name, minutes, seconds)
            end
        end
    end
    
    -- Get the default channel from MessageManager
    local msgManager = RaidDominion and RaidDominion.modules and RaidDominion.modules.messageManager
    if msgManager then
        local _, defaultChannel = msgManager:GetDefaultChannel()
        SendDelayedMessages({message}, defaultChannel)
    end
end

-- Hook a los botones de auras
local function HookAuraButtons(unit)
    local buffPrefix = (unit == "player") and "BuffButton" or "TargetFrameBuff"
    local debuffPrefix = (unit == "player") and "DebuffButton" or "TargetFrameDebuff"
    local maxAuras = 40

    for i = 1, maxAuras do
        local buff = _G[buffPrefix .. i]
        local debuff = _G[debuffPrefix .. i]

        -- Hook para buffs
        if buff and not buff.hooked then
            buff:EnableMouse(true)
            buff:SetScript("OnMouseUp", function(self, button)
                if button == "LeftButton" then
                    local idx = self:GetID()
                    local name, _, _, _, _, duration, expirationTime = UnitBuff(unit, idx)
                    if name then
                        SendAuraMessage(name, duration, expirationTime)
                    end
                end
            end)
            buff.hooked = true
        end

        -- Hook para debuffs
        if debuff and not debuff.hooked then
            debuff:EnableMouse(true)
            debuff:SetScript("OnMouseUp", function(self, button)
                if button == "LeftButton" then
                    local idx = self:GetID()
                    local name, _, _, _, _, duration, expirationTime = UnitDebuff(unit, idx)
                    if name then
                        SendAuraMessage(name, duration, expirationTime)
                    end
                end
            end)
            debuff.hooked = true
        end
    end
end

-- =============================================
-- SISTEMA DE SEGUIMIENTO DE ENCANTAMIENTOS DE ARMAS
-- =============================================

-- Constantes para las ranuras de equipo
local SLOT_MAIN = 16   -- Main Hand
local SLOT_OFF = 17    -- Off Hand
local SLOT_RANGED = 18 -- Ranged

-- Función para enviar mensajes de encantamiento de armas
local function SendWeaponMessage(slotName, slotId, ms)
    if ms == 0 then return end
    
    local itemLink = GetInventoryItemLink("player", slotId)
    local itemName = itemLink and GetItemInfo(itemLink) or "Arma"
    local minutes = math.floor(ms / 60000)
    local seconds = math.floor((ms % 60000) / 1000)
    local timeText = string.format("%d:%02d", minutes, seconds)
    
    local message = string.format("%s (%s) - Tiempo restante: %s", 
        itemName, slotName, timeText)
    
    -- Get the default channel from MessageManager
    local msgManager = RaidDominion and RaidDominion.modules and RaidDominion.modules.messageManager
    if msgManager then
        local _, defaultChannel = msgManager:GetDefaultChannel()
        SendDelayedMessages({message}, defaultChannel)
    end
end

-- Hook para los botones de encantamiento temporal
local function HookWeaponEnchantButtons()
    for i = 1, 3 do  -- TempEnchant1, TempEnchant2, TempEnchant3
        local btn = _G["TempEnchant" .. i]
        
        if btn and not btn.hooked then
            btn:EnableMouse(true)
            btn:SetScript("OnMouseUp", function(self, button)
                if button == "LeftButton" then
                    local hasMain, mainExp, _, _, _, _, hasOff, offExp, _, _, hasRanged, rangedExp = GetWeaponEnchantInfo()
                    
                    -- TempEnchant1 → puede ser OFFHAND si existe, sino MAIN
                    -- TempEnchant2 → MAIN si hay OFFHAND
                    -- TempEnchant3 → RANGED (incluye piedras de brujo)
                    if i == 1 then
                        if hasOff then
                            SendWeaponMessage("Off Hand", SLOT_OFF, offExp)
                        elseif hasMain then
                            SendWeaponMessage("Main Hand", SLOT_MAIN, mainExp)
                        end
                    elseif i == 2 and hasMain then
                        SendWeaponMessage("Main Hand", SLOT_MAIN, mainExp)
                    elseif i == 3 and hasRanged then
                        SendWeaponMessage("Ranged", SLOT_RANGED, rangedExp)
                    end
                end
            end)
            btn.hooked = true
        end
    end
end

-- =============================================
-- INICIALIZACIÓN DEL SISTEMA DE AURAS Y ENCANTAMIENTOS
-- =============================================

local auraSystemInitialized = false

function UIUtils.InitializeAuraSystem()
    if auraSystemInitialized then return end
    
    -- Frame para manejar eventos
    local eventFrame = CreateFrame("Frame", "RDAuraSystemFrame", UIParent)
    
    -- Registrar eventos
    eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    eventFrame:RegisterEvent("UNIT_AURA")
    eventFrame:RegisterEvent("UNIT_INVENTORY_CHANGED")
    eventFrame:RegisterEvent("PLAYER_LOGIN")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    
    -- Manejador de eventos
    eventFrame:SetScript("OnEvent", function(self, event, unit, ...)
        -- Actualizar hooks cuando:
        -- - Cambia el objetivo
        -- - Cambia la composición del grupo
        -- - Se actualizan las auras del jugador/objetivo
        -- - Cambia el equipo del jugador
        if event == "PLAYER_TARGET_CHANGED" 
            or event == "GROUP_ROSTER_UPDATE"
            or (event == "UNIT_AURA" and (unit == "player" or unit == "target"))
            or (event == "UNIT_INVENTORY_CHANGED" and unit == "player")
            or event == "PLAYER_LOGIN"
            or event == "PLAYER_ENTERING_WORLD"
        then
            HookAuraButtons("player")
            HookAuraButtons("target")
            HookWeaponEnchantButtons()
        end
    end)
    
    -- Ejecutar hooks iniciales
    if IsLoggedIn() then
        HookAuraButtons("player")
        HookAuraButtons("target")
        HookWeaponEnchantButtons()
    end
    
    auraSystemInitialized = true
end

-- Register the module
RaidDominion.UIUtils = UIUtils

-- Inicializar el sistema de auras cuando el addon esté listo
if IsLoggedIn() then
    UIUtils.InitializeAuraSystem()
else
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_LOGIN")
    f:SetScript("OnEvent", function() UIUtils.InitializeAuraSystem() end)
end
return UIUtils
