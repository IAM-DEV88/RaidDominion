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

-- Create a basic frame
function UIUtils:CreateFrame(name, parent, template, width, height)
    local frame = CreateFrame("Frame", name, parent, template)
    frame:SetSize(width or 100, height or 100)
    return frame
end

-- Create a button
function UIUtils:CreateButton(name, parent, text, width, height, onClick)
    local button = CreateFrame("Button", name, parent, "UIPanelButtonTemplate")
    button:SetSize(width or 100, height or 24)
    button:SetText(text or "Button")
    if onClick then
        button:SetScript("OnClick", onClick)
    end
    return button
end

-- Create a help section with title and content
function UIUtils:CreateHelpSection(parent, title, content, yOffset)
    local section = CreateFrame("Frame", nil, parent)
    section:SetPoint("TOPLEFT", 10, yOffset)
    section:SetPoint("RIGHT", -10, 0)
    section:SetHeight(1)
    
    -- Title
    local titleText = section:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleText:SetPoint("TOPLEFT")
    titleText:SetText(title)
    titleText:SetTextColor(1, 0.82, 0)  -- Gold color
    
    -- Content frame to contain the text
    local contentFrame = CreateFrame("Frame", nil, section)
    contentFrame:SetPoint("TOPLEFT", titleText, "BOTTOMLEFT", 0, -5)
    contentFrame:SetPoint("RIGHT", section, "RIGHT", -10, 0)
    
    -- Content text with proper wrapping
    local contentText = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    contentText:SetPoint("TOPLEFT")
    contentText:SetPoint("RIGHT")
    contentText:SetJustifyH("LEFT")
    contentText:SetJustifyV("TOP")
    contentText:SetWordWrap(true)
    contentText:SetNonSpaceWrap(false)
    contentText:SetText(content)
    
    -- Calculate and set heights
    local function UpdateSizes()
        -- Force update of text dimensions
        contentText:SetHeight(0)
        local textWidth = contentFrame:GetWidth()
        contentText:SetWidth(textWidth)
        
        local contentHeight = contentText:GetStringHeight()
        contentFrame:SetHeight(contentHeight)
        
        local _, titleHeight = titleText:GetFont()
        section:SetHeight(titleHeight + contentHeight + 15)
        
        return section:GetHeight()
    end
    
    -- Update sizes when frame is shown or resized
    contentFrame:SetScript("OnSizeChanged", UpdateSizes)
    UpdateSizes()
    
    -- Ensure content is fully visible
    contentText:SetHeight(contentText:GetStringHeight())
    
    return section:GetHeight() + 10, section  -- Add some extra spacing between sections
end

-- Create a checkbox
function UIUtils:CreateCheckbox(name, parent, label, onClick)
    local check = CreateFrame("CheckButton", name, parent, "UICheckButtonTemplate")
    _G[check:GetName().."Text"]:SetText(label or "")
    if onClick then
        check:SetScript("OnClick", function(self) onClick(self:GetChecked()) end)
    end
    return check
end

-- Create a scroll frame
function UIUtils:CreateScrollFrame(name, parent, width, height)
    local scrollFrame = CreateFrame("ScrollFrame", name, parent, "UIPanelScrollFrameTemplate")
    scrollFrame:SetSize(width or 200, height or 200)
    
    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollFrame:SetScrollChild(scrollChild)
    scrollChild:SetWidth(width or 200)
    scrollChild:SetHeight(1)  -- Will be adjusted by content
    
    -- Add a scroll bar
    local scrollBar = _G[name.."ScrollBar"]
    scrollBar:SetValue(0)
    
    return scrollFrame, scrollChild
end

-- =============================================
-- SISTEMA DE SEGUIMIENTO DE AURAS (BUFFS/DEBUFFS)
-- =============================================

-- Función para manejar clics en buffs/auras
function UIUtils:HandleBuffClick(buffName)
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

function UIUtils:InitializeAuraSystem()
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
    UIUtils:InitializeAuraSystem()
else
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_LOGIN")
    f:SetScript("OnEvent", function() UIUtils:InitializeAuraSystem() end)
end
return UIUtils
