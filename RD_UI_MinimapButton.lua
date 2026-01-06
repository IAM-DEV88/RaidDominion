--[[
    RD_UI_MinimapButton.lua
    PURPOSE: Manages the minimap button for RaidDominion
    DEPENDENCIES: RD_Config.lua, RD_UI_ConfigManager.lua, RD_UI_MainFrame.lua
    PUBLIC API:
        - RD.ui.minimapButton:Initialize()
        - RD.ui.minimapButton:Show()
        - RD.ui.minimapButton:Hide()
        - RD.ui.minimapButton:Toggle()
    INTERACTIONS:
        - RD_UI_MainFrame: Toggle de ventana principal
        - RD_UI_ConfigManager: Abrir configuración
]]

local addonName, private = ...
local RD = _G["RaidDominion"] or {}
_G["RaidDominion"] = RD

-- Local references
local config = RD.config
local mainFrame = RD.ui and RD.ui.mainFrame
local configManager = RD.ui and RD.ui.configManager

-- Constants
local MINIMAP_ICON = "Interface\\Icons\\inv_misc_summerfest_brazierorange"
local BUTTON_SIZE = 26
local TOOLTIP_TITLE = "|cfff58cbaRaidDominion|r |caad4af37v1.0.0|r"

local MinimapButton = {}
local isInitialized = false

--[[
    Toggle the main window visibility
]]
local function ToggleWindow()
    if configManager and configManager.Toggle then
        configManager:Toggle()
    end
end

--[[
    Toggle the floating frame visibility
]]
local function ToggleFloatingFrame()
    if mainFrame and mainFrame.Toggle then
        mainFrame:Toggle()
    end
end

--[[
    Handle minimap button dragging
]]
local function OnDragStart(self)
    -- Solo permitir arrastrar si se mantiene presionada la tecla Alt
    if not IsAltKeyDown() then
        self:StopMovingOrSizing()
        return
    end
    
    self.isMoving = true
    self:StartMoving()
    self:SetScript("OnUpdate", function()
        if not self.isMoving then return end
        
        -- Si se suelta Alt durante el arrastre, detener el movimiento
        if not IsAltKeyDown() then
            OnDragStop(self)
            return
        end
        
        -- Get mouse position relative to the minimap
        local mx, my = Minimap:GetCenter()
        local px, py = GetCursorPosition()
        local scale = Minimap:GetEffectiveScale()
        
        -- Calculate angle from center of minimap to cursor
        local angle = math.atan2(py / scale - my, px / scale - mx)
        
        -- Save the position
        if config and type(config.Set) == "function" then
            -- Convert to 0-1 range (0-2π to 0-1)
            local position = (angle % (2 * math.pi)) / (2 * math.pi)
            if position < 0 then position = position + 1 end
            config:Set("general.minimap.position", position)
        end
    end)
end

local function OnDragStop(self)
    if not self.isMoving then return end
    self.isMoving = false
    self:StopMovingOrSizing()
    self:SetScript("OnUpdate", nil)
    
    -- Update the button position
    if MinimapButton.UpdatePosition then
        MinimapButton:UpdatePosition()
    end
end

--[[
    Handle minimap button clicks
]]
local function OnMouseDown(self, button)
    if button == "LeftButton" then
        -- Start dragging if Alt key is pressed
        if IsAltKeyDown() then
            OnDragStart(self)
        else
            ToggleFloatingFrame()
        end
    elseif button == "RightButton" then
        -- Create the dropdown menu
        local menuFrame = CreateFrame("Frame", "RaidDominionMinimapMenu", UIParent, "UIDropDownMenuTemplate")
        
        -- Menu options
        local menuItems = {
            {
                text = "Configuración",
                func = function() 
                    if configManager and configManager.SelectTab then
                        configManager:SelectTab(1) -- Select General tab (first tab)
                    end
                    ToggleWindow()
                end,
            },
            {
                text = "Mover botón (Mantén Alt + Arrastra)",
                isTitle = true,
                notCheckable = true,
                notClickable = true,
            },
            {
                text = "Recargar UI",
                func = function() 
                    ReloadUI() 
                end,
            }
        }
        
        -- Show the menu
        EasyMenu(menuItems, menuFrame, "cursor", 0, 0, "MENU", 1)
    end
end

--[[
    Show tooltip on mouse enter
]]
local function OnEnter(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(TOOLTIP_TITLE)
    GameTooltip:AddLine("|cff00ff00Click|r: Abrir ventana principal")
    GameTooltip:AddLine("|cff00ff00Click Derecho|r: Menú de opciones")
    GameTooltip:AddLine("|cff00ff00Alt + Arrastrar|r: Mover botón")
    GameTooltip:Show()
end

--[[
    Hide tooltip on mouse leave
]]
local function OnLeave(self)
    GameTooltip:Hide()
end

--[[
    Initialize the minimap button
]]
function MinimapButton:Initialize()
    -- Don't initialize here - will be initialized from RD_Init.lua
    -- This prevents duplicate initialization
    -- Ensure Minimap exists and button isn't already created
    if not Minimap or self.button or isInitialized then
        return true
    end
    
    -- Create the button with error handling
    local button = CreateFrame("Button", "RaidDominionMinimapButton", Minimap)
    if not button then
        return false
    end
    
    button:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    button:SetFrameStrata("HIGH")
    button:SetFrameLevel(8)
    button:RegisterForClicks("AnyUp")
    button:SetMovable(true)
    button:SetClampedToScreen(true)
    button:SetDontSavePosition(true)
    
    -- Create the main icon texture
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexture(MINIMAP_ICON)
    
    -- Store the icon reference
    button.icon = icon
    
    -- Set up the button states
    button:SetNormalTexture(icon)
    
    -- Create highlight texture
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    highlight:SetBlendMode("ADD")
    highlight:SetAllPoints()
    button:SetHighlightTexture(highlight)
    
    -- Create pushed texture (semi-transparent version of the icon)
    local pushed = button:CreateTexture(nil, "OVERLAY")
    pushed:SetTexture(MINIMAP_ICON)
    pushed:SetAllPoints()
    pushed:SetAlpha(0.7)
    button:SetPushedTexture(pushed)
    
    -- Keep the icon visible at all times
    button:SetScript("OnShow", function(self)
        if self.icon then
            self.icon:Show()
        end
    end)
    
    -- Set scripts with error handling
    local originalOnMouseDown = OnMouseDown
    button:SetScript("OnMouseDown", function(self, button, ...)
        if button == "LeftButton" and IsAltKeyDown() then
            -- Solo iniciar arrastre si se mantiene Alt presionado
            OnDragStart(self)
        else
            -- Llamar al manejador de clic normal
            originalOnMouseDown(self, button, ...)
        end
    end)
    button:SetScript("OnEnter", OnEnter)
    button:SetScript("OnLeave", OnLeave)
    
    -- Solo registrar el arrastre cuando se presiona Alt
    button:SetScript("OnUpdate", function(self, elapsed)
        if IsAltKeyDown() then
            self:RegisterForDrag("LeftButton")
            self:SetScript("OnDragStart", OnDragStart)
            self:SetScript("OnDragStop", OnDragStop)
            self:SetScript("OnMouseUp", OnDragStop)
        else
            self:RegisterForDrag()
            self:SetScript("OnDragStart", nil)
            self:SetScript("OnDragStop", nil)
            self:SetScript("OnMouseUp", nil)
        end
    end)
    
    -- Position the button
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "TOPLEFT", 80, 0) -- Default position
    
    -- Store reference
    self.button = button
    
    -- Update position based on saved settings
    self:UpdatePosition()
    
    isInitialized = true
    return true
end

--[[
    Update the minimap button position
]]
function MinimapButton:UpdatePosition()
    if not self.button or not Minimap then return end
    
    -- Default position (top right of minimap)
    local position = 0
    if config and type(config.Get) == "function" then
        position = config:Get("general.minimap.position", 0) or 0
    end
    
    -- Convert position to radians and calculate coordinates
    local angle = position * (2 * math.pi)
    local radius = 80 -- Distance from center of minimap
    local x = math.cos(angle) * radius
    local y = math.sin(angle) * radius
    
    -- Apply position
    self.button:ClearAllPoints()
    self.button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

--[[
    Show the minimap button
]]
function MinimapButton:Show()
    if self.button then
        self.button:Show()
    end
end

--[[
    Hide the minimap button
]]
function MinimapButton:Hide()
    if self.button then
        self.button:Hide()
    end
end

--[[
    Toggle the minimap button visibility
]]
function MinimapButton:Toggle()
    if self.button then
        if self.button:IsShown() then
            self:Hide()
        else
            self:Show()
        end
    end
end

-- Register the module
RD.ui = RD.ui or {}
RD.ui.minimapButton = MinimapButton

-- Initialize when the addon is loaded
local function InitializeMinimapButton()
    if not Minimap then
        local retryFrame = CreateFrame("Frame")
        retryFrame:SetScript("OnUpdate", function(self, elapsed)
            self.elapsed = (self.elapsed or 0) + elapsed
            if self.elapsed >= 1 then
                self:SetScript("OnUpdate", nil)
                if Minimap then
                    MinimapButton:Initialize()
                end
            end
        end)
        return
    end
    
    MinimapButton:Initialize()
end

-- Event handler
local function OnEvent(self, event, ...)
    if event == "ADDON_LOADED" and ... == addonName then
        local delayFrame = CreateFrame("Frame")
        delayFrame:SetScript("OnUpdate", function(self, elapsed)
            self.elapsed = (self.elapsed or 0) + elapsed
            if self.elapsed >= 1 then
                self:SetScript("OnUpdate", nil)
                InitializeMinimapButton()
            end
        end)
    elseif event == "PLAYER_LOGIN" and not isInitialized then
        InitializeMinimapButton()
    end
end

-- Register events
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", OnEvent)

-- Slash command to show/hide the minimap button
SLASH_RDMINIMAP1 = "/rdminimap"
SlashCmdList["RDMINIMAP"] = function()
    if MinimapButton.Toggle then
        MinimapButton:Toggle()
    end
end

return MinimapButton
