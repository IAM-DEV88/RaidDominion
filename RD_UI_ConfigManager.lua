--[[
    RD_UI_ConfigManager.lua
    PURPOSE: Manages the configuration interface for RaidDominion
    DEPENDENCIES: 
        - RD_Constants.lua
        - RD_Config.lua
        - RD_UI_Config_*.lua (tab implementations)
    API: 
        - RaidDominion.configManager:Toggle() - Toggle config window
        - RaidDominion.configManager:Show() - Show config window
        - RaidDominion.configManager:Hide() - Hide config window
]]

local addonName, private = ...
local RD = _G.RaidDominion
local CONSTANTS = RD.constants
local CONFIG = CONSTANTS.CONFIG
local LOCALIZATION = CONSTANTS.LOCALIZATION
local UI = CONSTANTS.UI
local config = RD.config
local UIUtils = RD.UIUtils or {}
local MenuFactory = RD.UI and RD.UI.MenuFactory or {}

-- Localize frequently used functions
local pairs, ipairs, type, tostring = pairs, ipairs, type, tostring
local strsplit, strtrim = strsplit, strtrim
local CreateFrame = CreateFrame
local UIDropDownMenu_Initialize = UIDropDownMenu_Initialize
local UIDropDownMenu_SetText = UIDropDownMenu_SetText
local UIDropDownMenu_AddButton = UIDropDownMenu_AddButton
local UIDropDownMenu_CreateInfo = UIDropDownMenu_CreateInfo
local UIDropDownMenu_SetWidth = UIDropDownMenu_SetWidth
local GameTooltip = GameTooltip

-- Module definition
local ConfigManager = {
    frame = nil,
    isShown = false,
    tabs = {},
    tabSystem = nil,
    currentTab = nil,
    initialized = false,
    
    -- Default configuration values
    defaults = {
        ui = {
            showMinimapButton = true,
            lockWindow = false,
            showRoleIcons = true,
            showTooltips = true,
            showMainMenuOnStart = true,
            showMechanicsMenu = true,
            showGuildMenu = true
        },
        chat = {
            channel = "DEFAULT"
        }
    }
}

-- Initialize tab modules with proper localization and structure
local function InitializeTabs()
    -- Tab definitions with localized names and proper structure
    local tabDefinitions = {
        {
            id = "general",
            name = LOCALIZATION.TABS.GENERAL,
            order = 1,
            create = function(container)
                -- Tab creation logic will be moved here
                local titleFrame = CreateFrame("Frame", nil, container)
                titleFrame:SetPoint("TOPLEFT", 5, -20)
                
                -- Add tab content here
                -- This will be populated with the actual UI elements
                return titleFrame
            end
        },
        {
            id = "roles",
            name = LOCALIZATION.TABS.ROLES,
            order = 2,
            create = function(container)
                -- Roles tab content
                local frame = CreateFrame("Frame", nil, container)
                return frame
            end
        },
        {
            id = "buffs",
            name = LOCALIZATION.TABS.BUFFS,
            order = 3,
            create = function(container)
                -- Buffs tab content
                local frame = CreateFrame("Frame", nil, container)
                return frame
            end
        },
        {
            id = "abilities",
            name = LOCALIZATION.TABS.ABILITIES,
            order = 4,
            create = function(container)
                -- Abilities tab content
                local frame = CreateFrame("Frame", nil, container)
                return frame
            end
        },
        {
            id = "auras",
            name = LOCALIZATION.TABS.AURAS,
            order = 5,
            create = function(container)
                -- Auras tab content
                local frame = CreateFrame("Frame", nil, container)
                return frame
            end
        },
        {
            id = "help",
            name = LOCALIZATION.TABS.HELP,
            order = 100,  -- Make it the last tab
            create = function(container)
                -- Help tab content
                local frame = CreateFrame("Frame", nil, container)
                return frame
            end
        }
    }
    
    -- Sort tabs by their order
    table.sort(tabDefinitions, function(a, b) return a.order < b.order end)
    
    return tabDefinitions
end

-- Deprecated: Select tab by name (replaced by SelectTab index and SelectTabById)

-- Show the configuration window
function ConfigManager:Show()
    if not self.frame then
        self:CreateWindow()
    end
    
    self.frame:Show()
    self.isShown = true
    
    -- Notify that the config window was shown
    if RD.events and RD.events.Publish then
        RD.events:Publish("CONFIG_WINDOW_SHOWN")
    end
end

-- Hide the configuration window
function ConfigManager:Hide()
    if self.frame then
        self.frame:Hide()
        self.isShown = false
        
        -- Notify that the config window was hidden
        if RD.events and RD.events.Publish then
            RD.events:Publish("CONFIG_WINDOW_HIDDEN")
        end
    end
end

-- Toggle the configuration window
function ConfigManager:Toggle()
    if self.isShown then
        self:Hide()
    else
        self:Show()
    end
end

-- Get a configuration value with a default fallback
function ConfigManager:Get(key, default)
    -- Split the key by dots to handle nested tables
    local keys = {strsplit(".", key)}
    local value = RD.config or {}
    
    for _, k in ipairs(keys) do
        if type(value) == "table" then
            value = value[k]
        else
            value = nil
            break
        end
    end
    
    -- Return the value or the default if not found
    if value ~= nil then
        return value
    end
    
    -- Try to get the default value from the defaults table
    local defaultPath = self.defaults
    for _, k in ipairs(keys) do
        if type(defaultPath) == "table" then
            defaultPath = defaultPath[k]
        else
            defaultPath = nil
            break
        end
    end
    
    return defaultPath or default
end

-- Set a configuration value
function ConfigManager:Set(key, value)
    if not key or value == nil then return end
    
    -- Ensure config table exists
    RD.config = RD.config or {}
    
    -- Split the key by dots to handle nested tables
    local keys = {strsplit(".", key)}
    local current = RD.config
    
    -- Navigate to the parent of the final key
    for i = 1, #keys - 1 do
        local k = keys[i]
        if current[k] == nil then
            current[k] = {}
        elseif type(current[k]) ~= "table" then
            -- Convert non-table values to tables to support nested keys
            current[k] = { [""] = current[k] }
        end
        current = current[k]
    end
    
    -- Set the value
    current[keys[#keys]] = value
    
    -- Notify listeners that a config value changed
    if RD.events and RD.events.Publish then
        RD.events:Publish("CONFIG_CHANGED", key, value)
    end
end

-- Initialize the configuration manager
function ConfigManager:Initialize()
    if self.initialized then return end
    
    -- Initialize default values if they don't exist
    for section, defaults in pairs(self.defaults) do
        if type(defaults) == "table" then
            for key, defaultValue in pairs(defaults) do
                local fullKey = section .. "." .. key
                if self:Get(fullKey) == nil then
                    self:Set(fullKey, defaultValue)
                end
            end
        end
    end
    
    -- Create slash commands
    SLASH_RAIDDOMINION1 = "/rd"
    SLASH_RAIDDOMINION2 = "/raidominion"
    
    SlashCmdList["RAIDDOMINION"] = function()
        self:Toggle()
    end
    
    -- Add configuration command
    SLASH_RDCONFIG1 = "/rdc"
    SlashCmdList["RDCONFIG"] = function()
        self:Toggle()
    end
    
    self.initialized = true
    
    -- Notify that the config manager is ready
    if RD.events and RD.events.Publish then
        RD.events:Publish("CONFIG_READY")
    end
end

-- Register the module
RaidDominion.configManager = ConfigManager

-- Initialize on load
local function OnAddonLoaded()
    ConfigManager:Initialize()
end

-- Register events
local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" and ... == addonName then
        OnAddonLoaded()
    end
end)

-- Helper function to create a scrollable list of checkboxes with icons
local function CreateCheckboxList(container, data, configKeyPrefix, topMargin)
    -- Safely get UI constants
    local RD = _G["RaidDominion"] or {}
    local UI = {}
    if RD.constants and RD.constants.UI and RD.constants.UI.TABS then
        UI = RD.constants.UI.TABS
    end
    
    -- Create a scroll frame with minimal padding
    local scrollFrame = CreateFrame("ScrollFrame", "RD_CheckboxScrollFrame"..configKeyPrefix, container, "UIPanelScrollFrameTemplate")
    local scrollBar = _G["RD_CheckboxScrollFrame"..configKeyPrefix.."ScrollBar"]
    
    -- Ensure data is a table
    data = data or {}
    
    -- Apply top margin if provided, otherwise use default 5
    local topMargin = topMargin or 5
    scrollFrame:SetPoint("TOPLEFT", 0, -topMargin) -- Shifted 5px left (1px more)
    scrollFrame:SetPoint("BOTTOMRIGHT", -29, 5) -- Shifted 4px left (no change to right)
    
    -- Create content frame with background
    local content = CreateFrame("Frame", "RD_CheckboxContent"..configKeyPrefix, scrollFrame)
    content:SetWidth(scrollFrame:GetWidth() - (scrollBar:GetWidth() + 3)) -- 2px more to the right (reduced padding)
    content:SetHeight(1)  -- Will be updated with content
    
    -- Set up scrolling
    scrollFrame:SetScrollChild(content)
    scrollFrame:SetScript("OnSizeChanged", function(self)
        content:SetWidth(self:GetWidth() - (scrollBar:GetWidth() + 5))
    end)
    
    -- Set background
    content:SetBackdrop(UI.CONTENT.BACKGROUND)
    content:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
    content:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.8)
    
    -- Function to update scroll range
    local function UpdateScrollRange()
        local maxScroll = math.max(0, content:GetHeight() - scrollFrame:GetHeight())
        scrollBar:SetMinMaxValues(0, maxScroll)
        
        -- Update scrollbar visibility
        if maxScroll > 0 then
            scrollBar:Show()
        else
            scrollBar:Hide()
        end
        
        return maxScroll
    end
    
    -- Mouse wheel support
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local current = scrollBar:GetValue()
        local minVal, maxVal = scrollBar:GetMinMaxValues()
        
        if delta < 0 and current < maxVal then
            scrollBar:SetValue(math.min(maxVal, current + 30))
        elseif delta > 0 and current > minVal then
            scrollBar:SetValue(math.max(minVal, current - 30))
        end
    end)
    
    -- Update scroll range when frame is resized
    scrollFrame:SetScript("OnSizeChanged", function()
        UpdateScrollRange()
    end)
    
    -- Update scroll range after content is created
    content:SetScript("OnSizeChanged", function()
        UpdateScrollRange()
    end)
    
    -- Update scroll range when frame is shown
    scrollFrame:SetScript("OnShow", UpdateScrollRange)
    
    -- Initial scroll range update
    UpdateScrollRange()
    
    -- Function to create a checkbox with icon
    local function CreateCheckbox(parent, item, x, y)
        local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
        check:SetPoint("TOPLEFT", x, y)
        check:SetSize(24, 24)
        
        -- Store the config key - use lowercase for consistency
        local itemKey = string.lower(item.id or item.name or "")
        local configSection = configKeyPrefix:gsub("%..*$", "")
        local configKey = configSection .. "." .. itemKey
        
        -- Set the configKey for this item if not already set
        if not item.configKey then
            item.configKey = configKey
        end
        
        -- First try to get the value from the config system
        local isChecked = config:Get(configKey)
        
        -- If not found in config, try to get it from RaidDominionDB
        if isChecked == nil and RaidDominionDB then
            -- Handle nested config keys (e.g., "ui.showMinimap")
            local keys = {strsplit(".", configKey)}
            local value = RaidDominionDB
            local valid = true
            
            for _, key in ipairs(keys) do
                if value and type(value) == "table" then
                    value = value[key]
                else
                    valid = false
                    break
                end
            end
            
            if valid and value ~= nil then
                isChecked = value
                -- Save the value to the config system for future use
                if config and config.Set then
                    config:Set(configKey, isChecked)
                end
            end
        end
        
        -- If still no value, use the default (true for checkboxes)
        if isChecked == nil then
            isChecked = true
            -- Save the default value to the config
            if config and config.Set then
                config:Set(configKey, isChecked)
            end
        end
        
        -- Set the checkbox state
        check:SetChecked(isChecked)
        
        -- Store the item key and config section for later use
        check.itemKey = itemKey
        check.configSection = configSection
        check.configKey = configSection .. "." .. itemKey
        
        -- Set up click handler with enhanced event triggering
        check:SetScript("OnClick", function(self)
            local RD = _G.RaidDominion or {}
            
            -- Ensure events system is available
            if not RD.events or not RD.events.Publish then
                return
            end
            
            local newValue = self:GetChecked() and true or false
            local configSection = self.configSection
            local itemKey = self.itemKey
            
            -- Update the configuration value
            local oldValue = config:Get(self.configKey)
            
            -- Save to persistent storage if available
            if config and config.Set then
                config:Set(self.configKey, newValue)
            end
            
            -- Configuration change handled silently
            
            -- Update the label color based on the checkbox state
            if self.label then
                if newValue then
                    self.label:SetTextColor(1, 1, 1) -- White for enabled
                else
                    self.label:SetTextColor(0.5, 0.5, 0.5) -- Gray for disabled
                end
            end
            
            -- Map the config section to the appropriate menu type
            local menuType = string.lower(configSection)
            
            -- Trigger configuration changed event for the specific menu type
            if RD.events and RD.events.Publish then
                RD.events:Publish("CONFIG_CHANGED", menuType)
            end
        end)
        
        -- Create icon
        local icon = parent:CreateTexture(nil, "ARTWORK")
        icon:SetSize(16, 16)
        icon:SetPoint("LEFT", check, "RIGHT", 5, 0)
        icon:SetTexture(item.icon)
        
        -- Create label
        local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        label:SetPoint("LEFT", icon, "RIGHT", 5, 0)
        label:SetText(item.name)
        
        -- Make the label clickable
        local labelButton = CreateFrame("Button", nil, parent)
        labelButton:SetPoint("TOPLEFT", label, "TOPLEFT")
        labelButton:SetPoint("BOTTOMRIGHT", label, "BOTTOMRIGHT")
        labelButton:SetScript("OnClick", function()
            if check and check.Click then
                check:Click()
            else
                check:SetChecked(not check:GetChecked())
                if config and config.Set then
                    config:Set(check.configKey, check:GetChecked())
                end
            end
        end)
        
        return check, label, check:GetHeight()
    end
    
    -- Calculate layout
    local totalItems = #data
    local itemsPerColumn = math.ceil((totalItems + 1) / 2)  -- +1 to balance columns better
    local buttonHeight = 24
    local buttonSpacing = 5
    local maxY = 0
    
    -- Calculate column width (account for scrollbar and margins)
    local columnWidth = (scrollFrame:GetWidth() - 35) / 2  -- Account for scrollbar and margins
    
    -- Create checkboxes in two columns
    for i, item in ipairs(data) do
        local col = (i <= itemsPerColumn) and 1 or 2
        local row = (i - 1) % itemsPerColumn
        local xOffset = (col - 1) * (columnWidth + 10)  -- Add some spacing between columns
        local yOffset = -row * (buttonHeight + buttonSpacing)
        
        -- Create the checkbox and get its height
        local check, label, height = CreateCheckbox(content, item, xOffset, yOffset)
        
        -- Make sure the label doesn't overflow
        if label and label.GetStringWidth then
            local maxWidth = columnWidth - 30  -- Leave space for checkbox and icon
            if label:GetStringWidth() > maxWidth then
                label:SetWidth(maxWidth)
                label:SetJustifyH("LEFT")
            end
        end
        
        -- Track the total height needed
        maxY = math.max(maxY, math.abs(yOffset) + height)
    end
    
    -- Set the content height with some padding
    content:SetHeight(maxY + 20)
    
    -- Update scroll range if the function exists (will be called in OnShow)
    if UpdateScrollRange then
        UpdateScrollRange()
    end
    
    return scrollFrame
end

-- Get UI Utils and Constants
local UIUtils = RaidDominion.UIUtils
local CONSTANTS = RaidDominion.constants
local UI = CONSTANTS.UI
local LOCALIZATION = CONSTANTS.LOCALIZATION

-- Define tab definitions
local tabDefinitions = {
    {
        id = "general",
        name = LOCALIZATION.TABS.GENERAL,
        order = 1,
        create = function(container)
            local UI = RaidDominion.constants.UI.TABS
    
            local titleFrame = CreateFrame("Frame", nil, container)
            titleFrame:SetPoint("TOPLEFT", 5, -20)
            titleFrame:SetPoint("RIGHT", -25, 0)
            titleFrame:SetHeight(30)
            local titleText = titleFrame:CreateFontString(nil, "OVERLAY", UI.SECTION.TITLE_FONT)
            titleText:SetPoint("CENTER")
            titleText:SetText("Configuración General")
            titleText:SetTextColor(UI.SECTION.TITLE_COLOR.r, UI.SECTION.TITLE_COLOR.g, UI.SECTION.TITLE_COLOR.b, UI.SECTION.TITLE_COLOR.a)
            
            local scrollFrame = CreateFrame("ScrollFrame", "RD_ConfigScrollFrame", container, "UIPanelScrollFrameTemplate")
            local scrollBar = _G["RD_ConfigScrollFrameScrollBar"]
            scrollFrame:SetPoint("TOPLEFT", titleFrame, "BOTTOMLEFT", -5, -5) -- Shifted 5px left (1px more)
            scrollFrame:SetPoint("BOTTOMRIGHT", -29, 5) -- Shifted 4px left (no change to right)
            
            -- Create content frame with background
            local content = CreateFrame("Frame", "RD_ConfigContent", scrollFrame)
            content:SetWidth(scrollFrame:GetWidth() - (scrollBar:GetWidth() + 3)) -- 2px more to the right (reduced padding)
            content:SetHeight(1)  -- Will be updated with content
            
            -- Set up scrolling
            scrollFrame:SetScrollChild(content)
            scrollFrame:SetScript("OnSizeChanged", function(self)
                content:SetWidth(self:GetWidth() - (scrollBar:GetWidth() + 5))
            end)
            
            -- Set background
            content:SetBackdrop(UI.CONTENT.BACKGROUND)
            content:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
            content:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.8)
            
            
            
            -- Example checkbox
            local function CreateCheckbox(parent, text, configKey, yOffset)
                local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
                check:SetPoint("TOPLEFT", 20, yOffset)
                check:SetChecked(config:Get(configKey, false))
                check:SetScript("OnClick", function(self)
                    config:Set(configKey, self:GetChecked())
                end)
                
                local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                label:SetPoint("LEFT", check, "RIGHT", 5, 0)
                label:SetText(text)
                
                return check
            end
            
            -- Create sections with reduced spacing
            local function CreateSectionHeader(parent, text, yOffset)
                local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
                header:SetPoint("TOPLEFT", 10, yOffset)
                header:SetText(text)
                return yOffset - 25  -- Reduced from -30 to -25
            end
            
            -- General Options Section with reduced top margin
            local RD = _G["RaidDominion"]
            yOffset = CreateSectionHeader(content, "Opciones de Menú", 0)  -- Reduced from -40 to -25
            
            -- Menu Checkboxes with reduced spacing and clickable text
            local function CreateMenuCheckbox(parent, text, configKey, yOffset)
                local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
                check:SetPoint("TOPLEFT", 20, yOffset)
                
                -- Function to update the checkbox state
                local function UpdateCheckboxState()
                    -- Get the value from the config system
                    local isChecked = config:Get(configKey, false)
                    
                    -- Ensure the value is a boolean
                    if type(isChecked) == "number" then
                        isChecked = (isChecked == 1)
                    end
                    
                    -- Set the checkbox state
                    check:SetChecked(isChecked)
                end
                
                -- Set up an event to update the checkbox when the config is loaded
                if RD and RD.events and RD.events.Subscribe then
                    RD.events:Subscribe("CONFIG_LOADED", UpdateCheckboxState)
                    RD.events:Subscribe("CONFIG_CHANGED", function(changedKey)
                        if changedKey == configKey then
                            UpdateCheckboxState()
                        end
                    end)
                end
                
                -- Set initial state
                UpdateCheckboxState()
                
                -- Set up click handler
                check:SetScript("OnClick", function(self)
                    local newValue = self:GetChecked()
                    -- Ensure we always pass a boolean value (not nil)
                    newValue = newValue and true or false
                    -- Save the new value (will be converted to 1/0 by config:Set)
                    config:Set(configKey, newValue)
                    
                    -- If this is the mechanics or guild menu setting, refresh the main menu
                    if (configKey == "ui.showMechanicsMenu" or configKey == "ui.showGuildMenu") and 
                       RD and RD.ui and RD.ui.mainFrame and RD.ui.mainFrame.ShowMainMenu then
                        RD.ui.mainFrame:ShowMainMenu()
                    end
                end)
                
                local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                label:SetPoint("LEFT", check, "RIGHT", 2, 0)
                label:SetText(text)
                
                -- Make the label clickable
                local labelButton = CreateFrame("Button", nil, parent)
                labelButton:SetPoint("TOPLEFT", label, "TOPLEFT")
                labelButton:SetPoint("BOTTOMRIGHT", label, "BOTTOMRIGHT")
                labelButton:SetScript("OnClick", function()
                    local newValue = not check:GetChecked()
                    check:SetChecked(newValue)
                    -- Ensure we always pass a boolean value (not nil)
                    newValue = newValue and true or false
                    config:Set(configKey, newValue)
                    
                    -- If this is the mechanics or guild menu setting, refresh the main menu
                    if (configKey == "ui.showMechanicsMenu" or configKey == "ui.showGuildMenu") and 
                       RD and RD.ui and RD.ui.mainFrame and RD.ui.mainFrame.ShowMainMenu then
                        RD.ui.mainFrame:ShowMainMenu()
                    end
                end)
                
                return yOffset - 25  -- Reduced from -30 to -25
            end
            
            yOffset = CreateMenuCheckbox(content, "Mostrar Menú Principal al iniciar", "ui.showMainMenuOnStart", yOffset)
            yOffset = CreateMenuCheckbox(content, "Mostrar Menú Mecánicas", "ui.showMechanicsMenu", yOffset)
            yOffset = CreateMenuCheckbox(content, "Mostrar Menú Hermandad", "ui.showGuildMenu", yOffset)
            yOffset = CreateMenuCheckbox(content, "Ver información de ayuda", "ui.showTooltips", yOffset)
            
            -- Chat Channel Section with reduced spacing
            yOffset = CreateSectionHeader(content, "Canal de Chat", yOffset - 10)  -- Reduced from -20 to -10
            
            -- Create dropdown for chat channels
            local function CreateDropdown(parent, options, default, configKey, yOffset)
                local dropdown = CreateFrame("Frame", "RaidDominionChatChannelDropdown", parent, "UIDropDownMenuTemplate")
                dropdown:SetPoint("TOPLEFT", 20, yOffset)
                
                -- Function to update the dropdown value
                local function UpdateDropdown()
                    -- Ensure RaidDominionDB is initialized
                    _G.RaidDominionDB = _G.RaidDominionDB or {}
                    _G.RaidDominionDB.profiles = _G.RaidDominionDB.profiles or {}
                    
                    -- Get character-specific settings
                    local realm = GetRealmName()
                    local char = UnitName("player") .. " - " .. realm
                    
                    -- Initialize character settings if they don't exist
                    _G.RaidDominionDB.profiles[char] = _G.RaidDominionDB.profiles[char] or {}
                    _G.RaidDominionDB.profiles[char].chat = _G.RaidDominionDB.profiles[char].chat or {}
                    
                    -- Try to get the value from the character's settings first
                    local currentValue = _G.RaidDominionDB.profiles[char].chat.channel
                    
                    -- If no value found, try to get it from the config
                    if not currentValue or currentValue == "" then
                        currentValue = config:Get(configKey) or default
                        
                        -- If we found a value in config, migrate it to the new format
                        if currentValue ~= default then
                            _G.RaidDominionDB.profiles[char].chat.channel = currentValue
                        end
                    end
                    
                    -- Ensure we have a valid value
                    currentValue = currentValue or default
                    
                    -- Update the displayed text
                    local text = options[currentValue] or options[default]
                    UIDropDownMenu_SetText(dropdown, text)
                    
                    return currentValue
                end
                
                -- Function to set the dropdown value
                local function SetValue(newValue)
                    -- Save to the config system
                    config:Set(configKey, newValue)
                    
                    -- Ensure RaidDominionDB is initialized
                    _G.RaidDominionDB = _G.RaidDominionDB or {}
                    
                    -- Ensure profiles table exists
                    _G.RaidDominionDB.profiles = _G.RaidDominionDB.profiles or {}
                    
                    -- Get character-specific settings
                    local realm = GetRealmName()
                    local char = UnitName("player") .. " - " .. realm
                    
                    -- Initialize character settings if they don't exist
                    _G.RaidDominionDB.profiles[char] = _G.RaidDominionDB.profiles[char] or {}
                    _G.RaidDominionDB.profiles[char].chat = _G.RaidDominionDB.profiles[char].chat or {}
                    
                    -- Save the selected channel
                    _G.RaidDominionDB.profiles[char].chat.channel = newValue
                    
                    -- Update the displayed text
                    local text = options[newValue] or options[default]
                    _G[dropdown:GetName().."Text"]:SetText(text)
                end
                
                -- Initialize the dropdown
                local function Initialize(self, level)
                    local info = UIDropDownMenu_CreateInfo()
                    for value, text in pairs(options) do
                        info.text = text
                        info.value = value
                        info.func = function() 
                            SetValue(value) 
                        end
                        info.checked = (config:Get(configKey, default) == value)
                        UIDropDownMenu_AddButton(info, level)
                    end
                end
                
                -- Set up the dropdown
                UIDropDownMenu_Initialize(dropdown, Initialize)
                
                -- Set up an event to update the dropdown when the config is loaded
                if RD.events and RD.events.Subscribe then
                    RD.events:Subscribe("CONFIG_LOADED", UpdateDropdown)
                end
                
                -- Set initial value
                UpdateDropdown()
                
                -- Set width after initialization
                UIDropDownMenu_SetWidth(dropdown, 180)
                
                return yOffset - 50
            end
            
            -- Using chat channels from constants
            local chatChannels = CONSTANTS.CONFIG.CHAT_CHANNELS
            
            yOffset = CreateDropdown(content, chatChannels, "DEFAULT", "chat.channel", yOffset)
            
            -- Interface Section with reduced spacing
            yOffset = CreateSectionHeader(content, "Interfaz", yOffset +15)  -- Reduced from -20 to -10
            
            -- Reload UI Button with adjusted positioning
            local reloadButton = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
            reloadButton:SetPoint("TOPLEFT", 20, yOffset - 5)  -- Slight vertical adjustment
            reloadButton:SetSize(150, 25)
            reloadButton:SetText("Recargar UI")
            reloadButton:SetScript("OnClick", function() 
                ReloadUI() 
            end)
            
            yOffset = yOffset - 30
            -- Update content height based on final yOffset
            content:SetHeight(math.abs(yOffset) + 20)
            
            return scrollFrame
        end
    },
    {
        id = "roles",
        name = LOCALIZATION.TABS.ROLES,
        order = 2,
        create = function(container)
            -- Get role data
            local roleData = {}
            if RD.constants and RD.constants.ROLE_DATA then
                roleData = RD.constants.ROLE_DATA
            end
            
            local scrollFrame = CreateCheckboxList(container, roleData, "roles.", 54)
            
            -- Add title
            local title = scrollFrame:GetParent():CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
            title:SetPoint("TOP", 0, -27)
            title:SetText("Configuración de Roles")
            
            return scrollFrame
        end
    },
    {
        id = "abilities",
        name = LOCALIZATION.TABS.ABILITIES,
        order = 4,
        create = function(container)
            -- Get abilities data
            local abilitiesData = {}
            if RD.constants and RD.constants.SPELL_DATA and RD.constants.SPELL_DATA.abilities then
                abilitiesData = RD.constants.SPELL_DATA.abilities
            end
            
            local scrollFrame = CreateCheckboxList(container, abilitiesData, "abilities.", 54)
            
            -- Add title
            local title = scrollFrame:GetParent():CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
            title:SetPoint("TOP", 0, -27)
            title:SetText("Configuración de Habilidades")
            
            return scrollFrame
        end
    },
    {
        id = "buffs",
        name = LOCALIZATION.TABS.BUFFS,
        order = 3,
        create = function(container)
            -- Get buffs data
            local buffsData = {}
            if RD.constants and RD.constants.SPELL_DATA and RD.constants.SPELL_DATA.buffs then
                buffsData = RD.constants.SPELL_DATA.buffs
            end
            
            local scrollFrame = CreateCheckboxList(container, buffsData, "buffs.", 54)
            
            -- Add title
            local title = scrollFrame:GetParent():CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
            title:SetPoint("TOP", 0, -27)
            title:SetText("Configuración de Buffs")
            
            return scrollFrame
        end
    },
    {
        id = "auras",
        name = LOCALIZATION.TABS.AURAS,
        order = 5,
        create = function(container)
            -- Get auras data
            local aurasData = {}
            if RD.constants and RD.constants.SPELL_DATA and RD.constants.SPELL_DATA.auras then
                aurasData = RD.constants.SPELL_DATA.auras
            end
            
            local scrollFrame = CreateCheckboxList(container, aurasData, "auras.", 54)
            
            -- Add title
            local title = scrollFrame:GetParent():CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
            title:SetPoint("TOP", 0, -27)
            title:SetText("Configuración de Auras")
            
            return scrollFrame
        end
    },
    {
        id = "help",
        name = LOCALIZATION.TABS.HELP,
        order = 100,  -- Make it the last tab
        create = function(container)
            local UI = RaidDominion.constants.UI.TABS
            
            -- Create title (outside of scroll area)
            local titleFrame = CreateFrame("Frame", nil, container)
            titleFrame:SetPoint("TOPLEFT", 5, -21)
            titleFrame:SetPoint("RIGHT", -25, 0)
            titleFrame:SetHeight(30)
            
            local title = titleFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
            title:SetPoint("CENTER")
            title:SetText("Ayuda de RaidDominion")
            
            -- Create a scroll frame below the title
            local scrollFrame = CreateFrame("ScrollFrame", "RD_HelpScrollFrame", container, "UIPanelScrollFrameTemplate")
            local scrollBar = _G["RD_HelpScrollFrameScrollBar"]
            
            scrollFrame:SetPoint("TOPLEFT", titleFrame, "BOTTOMLEFT", -5, -5) -- Shifted 5px left (1px more)
            scrollFrame:SetPoint("BOTTOMRIGHT", -29, 5) -- Shifted 4px left (no change to right)
            
            -- Create content frame with background
            local content = CreateFrame("Frame", "RD_HelpContent", scrollFrame)
            content:SetWidth(scrollFrame:GetWidth() - (scrollBar:GetWidth() + 3)) -- 2px more to the right (reduced padding)
            content:SetHeight(1)  -- Will be updated with content
            
            -- Set up scrolling
            scrollFrame:SetScrollChild(content)
            scrollFrame:SetScript("OnSizeChanged", function(self)
                content:SetWidth(self:GetWidth() - (scrollBar:GetWidth() + 3)) -- 2px more to the right (reduced padding)
            end)
            
            -- Set background
            content:SetBackdrop(UI.CONTENT.BACKGROUND)
            content:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
            content:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.8)
            
            -- Help sections
            local yOffset = -10
            
            -- Use the actual MenuFactory reference from RD.UI
            local Factory = RD.UI and RD.UI.MenuFactory
            
            -- Welcome section
            local helpText = table.concat({
                LOCALIZATION.HELP.WELCOME,
                "",
                LOCALIZATION.HELP.TIP_1,
                LOCALIZATION.HELP.TIP_2,
                LOCALIZATION.HELP.TIP_3
            }, "\n")
            
            if Factory and Factory.CreateHelpSection then
                yOffset = yOffset - Factory:CreateHelpSection(content, "Primeros Pasos", helpText, yOffset)
                
                -- Commands section
                yOffset = yOffset - Factory:CreateHelpSection(content, "Comandos", [[
Comandos disponibles:
/rd - Muestra/oculta la ventana flotante de RaidDominion
/rdc - Muestra la ventana de configuración de RaidDominion
/rdh - Muestra los comandos de ayuda de RaidDominion
                ]], yOffset)
                
                -- About section
                local aboutText = "RaidDominion v1.0"
                yOffset = yOffset - Factory:CreateHelpSection(content, "Actualizaciones", aboutText, yOffset)
            end
            
            -- Update URL section
            local updateLabel = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            updateLabel:SetPoint("TOPLEFT", 10, yOffset +20)
            
            local url = "https://colmillo.netlify.app/"
            local editbox = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
            editbox:SetPoint("TOPLEFT", updateLabel, "BOTTOMLEFT", 0, -5)
            editbox:SetPoint("RIGHT", -30, 0)
            editbox:SetHeight(20)
            editbox:SetAutoFocus(false)
            editbox:SetText(url)
            editbox:SetCursorPosition(0)
            
            -- Make the editbox selectable but not editable
            editbox:SetScript("OnEditFocusGained", function(self)
                self:HighlightText()
            end)
            
            editbox:SetScript("OnMouseUp", function(self)
                if not self:HasFocus() then
                    self:SetFocus()
                    self:HighlightText()
                end
            end)
            
            -- Update yOffset after all sections
            yOffset = yOffset - 20  -- Ajuste final del espaciado
            
            -- Set content height
            content:SetHeight(math.abs(yOffset) + 20)
            
            -- Update scroll range
            scrollFrame:UpdateScrollChildRect()
            scrollFrame:SetVerticalScroll(0)
            
            -- Function to update scroll range
            local function UpdateScrollRange()
                local maxScroll = math.max(0, content:GetHeight() - scrollFrame:GetHeight())
                scrollBar:SetMinMaxValues(0, maxScroll)
                
                -- Update scrollbar visibility
                if maxScroll > 0 then
                    scrollBar:Show()
                else
                    scrollBar:Hide()
                end
                
                return maxScroll
            end
            
            -- Initial scroll range setup
            local maxScroll = UpdateScrollRange()
            
            -- Mouse wheel support
            scrollFrame:EnableMouseWheel(true)
            scrollFrame:SetScript("OnMouseWheel", function(self, delta)
                local current = scrollBar:GetValue()
                local minVal, maxVal = scrollBar:GetMinMaxValues()
                
                if delta < 0 and current < maxVal then
                    scrollBar:SetValue(math.min(maxVal, current + 30))
                elseif delta > 0 and current > minVal then
                    scrollBar:SetValue(math.max(minVal, current - 30))
                end
            end)
            
            -- Update scroll range when frame is resized
            scrollFrame:SetScript("OnSizeChanged", function()
                UpdateScrollRange()
            end)
            
            -- Update scroll range after content is created
            content:SetScript("OnSizeChanged", function()
                UpdateScrollRange()
            end)
            
            return scrollFrame
        end
    }
}

-- Add category tabs to the tab definitions if ConfigTabs is available
if RaidDominion.ui.configTabs then
    for _, tab in ipairs(RaidDominion.ui.configTabs:Initialize()) do
        table.insert(tabDefinitions, tab)
    end
end

-- Sort tabs by order
local function SortTabs(a, b)
    return a.order < b.order
end

-- Create the main window
function ConfigManager:CreateWindow()
    if self.frame then return self.frame end
    
    local UI = RaidDominion.constants.UI.TABS
    
    -- Create the main frame
    local frame = CreateFrame("Frame", "RaidDominionConfig", UIParent)
    frame:SetFrameStrata("MEDIUM")
    frame:SetToplevel(true)
    frame:SetSize(510, 360)  -- Reducido de 450 a 360 píxeles de altura
    frame:SetClampedToScreen(true)  -- Evita que la ventana se salga de la pantalla
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function() frame:StartMoving() end)
    frame:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)
    
    -- Make the window closable with ESC key
    tinsert(UISpecialFrames, "RaidDominionConfig")
    
    -- Set the unified backdrop style
    frame:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    frame:SetBackdropColor(0, 0, 0, 0.9)
    frame:SetBackdropBorderColor(1, 1, 1, 0.5)
    
    -- Make title area draggable
    local titleDrag = CreateFrame("Button", nil, frame)
    titleDrag:SetPoint("TOPLEFT", 0, 0)
    titleDrag:SetPoint("TOPRIGHT", 0, 0)
    titleDrag:SetHeight(30)  -- Altura de la barra de título
    titleDrag:SetScript("OnMouseDown", function() frame:StartMoving() end)
    titleDrag:SetScript("OnMouseUp", function() frame:StopMovingOrSizing() end)
    titleDrag:SetScript("OnHide", function() frame:StopMovingOrSizing() end)
    titleDrag:EnableMouse(true)    
    titleDrag:SetFrameLevel(frame:GetFrameLevel() + 1)
    
    -- Create title background with the same style as the main frame
    local titleBg = CreateFrame("Frame", nil, frame)
    titleBg:SetPoint("TOP", 0, 19)
    titleBg:SetSize(200, 24)  -- Width enough for title text
    titleBg:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    titleBg:SetBackdropColor(0, 0, 0, 0.9)
    titleBg:SetBackdropBorderColor(1, 1, 1, 0.5)
    titleBg:SetFrameLevel(frame:GetFrameLevel() + 1)
    titleBg:EnableMouse(true)
    titleBg:SetScript("OnMouseDown", function() frame:StartMoving() end)
    titleBg:SetScript("OnMouseUp", function() frame:StopMovingOrSizing() end)
    -- Set frame level lower than parent so it stays behind
    titleBg:SetFrameLevel(frame:GetFrameLevel() - 1)
    
    -- Add title text on top of the background
    local title = titleBg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("CENTER")
    title:SetText("RaidDominion")
    title:SetTextColor(1, 0.82, 0)  -- Gold color
    
    -- Add close button
    local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", -5, 1) -- Moved up by 6 pixels to match other elements
    closeButton:SetFrameLevel(frame:GetFrameLevel() + 10)  -- Asegurar que esté por encima
    closeButton:SetScript("OnClick", function() self:Hide() end)
    
    -- Create content background
    local contentBg = CreateFrame("Frame", nil, frame)
    contentBg:SetPoint("TOPLEFT", 10, -24) -- Moved up by 6 pixels to match tabContainer
    contentBg:SetPoint("BOTTOMRIGHT", -10, 8)
    contentBg:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    contentBg:SetBackdropColor(0.1, 0.1, 0.1, 0.7)
    -- Use constants for tab dimensions
    local tabWidth = UI.WIDTH
    local tabHeight = UI.HEIGHT
    
    -- Create tab container
    local tabContainer = CreateFrame("Frame", nil, frame)
    tabContainer:SetHeight(tabHeight + 4)  -- Add padding
    tabContainer:SetPoint("TOPLEFT", 10, -4)
    tabContainer:SetPoint("BOTTOMRIGHT", -4, 4)
    
    -- Create tab buttons
    -- Sort tabs
    table.sort(tabDefinitions, SortTabs)
    
    for i, tabDef in ipairs(tabDefinitions) do
        local tab = CreateFrame("Button", "RaidDominionConfigTab"..i, tabContainer)
        tab:SetID(i)
        tab:SetText(tabDef.name)
        tab:SetSize(tabWidth, tabHeight)
        
        -- Style the tab text
        tab:SetNormalFontObject(UI.FONT)
        tab:SetHighlightFontObject("GameFontHighlight")
        tab:SetDisabledFontObject("GameFontDisable")
        
        -- Create tab textures for 3.3.5a compatibility
        local normalLeft = tab:CreateTexture(nil, "BORDER")
        normalLeft:SetTexture(UI.NORMAL_TEXTURE)
        normalLeft:SetSize(20, 32)
        normalLeft:SetPoint("LEFT", 0, 0)
        normalLeft:SetTexCoord(0, 0.15625, 0, 1)
        tab.left = normalLeft
        
        local normalMiddle = tab:CreateTexture(nil, "BORDER")
        normalMiddle:SetTexture(UI.NORMAL_TEXTURE)
        normalMiddle:SetPoint("LEFT", normalLeft, "RIGHT")
        normalMiddle:SetPoint("RIGHT", -20, 0)
        normalMiddle:SetTexCoord(0.15625, 0.84375, 0, 1)
        normalMiddle:SetHeight(32)
        tab.middle = normalMiddle
        
        local normalRight = tab:CreateTexture(nil, "BORDER")
        normalRight:SetTexture(UI.NORMAL_TEXTURE)
        normalRight:SetSize(20, 32)
        normalRight:SetPoint("LEFT", normalMiddle, "RIGHT")
        normalRight:SetTexCoord(0.84375, 1, 0, 1)
        tab.right = normalRight
        
        -- Create highlight state textures (active tab)
        local highlightLeft = tab:CreateTexture(nil, "ARTWORK")
        highlightLeft:SetTexture(UI.HIGHLIGHT_TEXTURE)
        highlightLeft:SetSize(20, 32)
        highlightLeft:SetPoint("LEFT", 0, 0)
        highlightLeft:SetTexCoord(0, 0.15625, 0, 1)
        highlightLeft:Hide()
        tab.highlightLeft = highlightLeft
        
        local highlightMiddle = tab:CreateTexture(nil, "ARTWORK")
        highlightMiddle:SetTexture(UI.HIGHLIGHT_TEXTURE)
        highlightMiddle:SetPoint("LEFT", highlightLeft, "RIGHT")
        highlightMiddle:SetPoint("RIGHT", -20, 0)
        highlightMiddle:SetTexCoord(0.15625, 0.84375, 0, 1)
        highlightMiddle:SetHeight(32)
        highlightMiddle:Hide()
        tab.highlightMiddle = highlightMiddle
        
        local highlightRight = tab:CreateTexture(nil, "ARTWORK")
        highlightRight:SetTexture(UI.HIGHLIGHT_TEXTURE)
        highlightRight:SetSize(20, 32)
        highlightRight:SetPoint("LEFT", highlightMiddle, "RIGHT")
        highlightRight:SetTexCoord(0.84375, 1, 0, 1)
        highlightRight:Hide()
        tab.highlightRight = highlightRight
        
        -- Set the button text
        tab:SetText(tabDef.name)
        
        -- Get or create font string
        local fontString = tab:GetFontString()
        if not fontString then
            -- Create font string if it doesn't exist
            fontString = tab:CreateFontString(nil, "OVERLAY", font)
            tab:SetFontString(fontString)
        end
        
        -- Set text color using the font string's methods
        fontString:SetTextColor(0.8, 0.8, 0.6, 1)
        
        -- Create normal state textures (inactive tab)
        local normalLeft = tab:CreateTexture(nil, "BORDER")
        normalLeft:SetTexture("Interface/PaperDollInfoFrame/UI-Character-InActiveTab")
        normalLeft:SetSize(20, 32)
        normalLeft:SetPoint("TOPLEFT", 0, 2)
        normalLeft:SetTexCoord(0, 0.15625, 0, 0.8)
        normalLeft:SetAlpha(0.8)
        
        local normalRight = tab:CreateTexture(nil, "BORDER")
        normalRight:SetTexture("Interface/PaperDollInfoFrame/UI-Character-InActiveTab")
        normalRight:SetSize(20, 32)
        normalRight:SetPoint("TOPRIGHT", 0, 2)
        normalRight:SetTexCoord(0.84375, 1, 0, 0.8)
        normalRight:SetAlpha(0.8)
        
        local normalMiddle = tab:CreateTexture(nil, "BORDER")
        normalMiddle:SetTexture("Interface/PaperDollInfoFrame/UI-Character-InActiveTab")
        normalMiddle:SetHeight(32)
        normalMiddle:SetPoint("LEFT", normalLeft, "RIGHT")
        normalMiddle:SetPoint("RIGHT", normalRight, "LEFT")
        normalMiddle:SetTexCoord(0.15625, 0.84375, 0, 0.8)
        normalMiddle:SetAlpha(0.8)
        
        -- Create highlight textures (active tab)
        local highlightLeft = tab:CreateTexture(nil, "ARTWORK")
        highlightLeft:SetTexture("Interface/PaperDollInfoFrame/UI-Character-ActiveTab")
        highlightLeft:SetSize(20, 35)
        highlightLeft:SetPoint("TOPLEFT", 0, 0)
        highlightLeft:SetTexCoord(0, 0.15625, 0, 1)
        highlightLeft:Hide()
        
        local highlightRight = tab:CreateTexture(nil, "ARTWORK")
        highlightRight:SetTexture("Interface/PaperDollInfoFrame/UI-Character-ActiveTab")
        highlightRight:SetSize(20, 35)
        highlightRight:SetPoint("TOPRIGHT", 0, 0)
        highlightRight:SetTexCoord(0.84375, 1, 0, 1)
        highlightRight:Hide()
        
        local highlightMiddle = tab:CreateTexture(nil, "ARTWORK")
        highlightMiddle:SetTexture("Interface/PaperDollInfoFrame/UI-Character-ActiveTab")
        highlightMiddle:SetHeight(35)
        highlightMiddle:SetPoint("LEFT", highlightLeft, "RIGHT")
        highlightMiddle:SetPoint("RIGHT", highlightRight, "LEFT")
        highlightMiddle:SetTexCoord(0.15625, 0.84375, 0, 1)
        highlightMiddle:Hide()
        
        -- Create highlight overlay for hover effect
        local hoverOverlay = tab:CreateTexture(nil, "HIGHLIGHT")
        hoverOverlay:SetAllPoints()
        hoverOverlay:SetTexture("Interface/Buttons/UI-Listbox-Highlight2")
        hoverOverlay:SetBlendMode("ADD")
        hoverOverlay:SetAlpha(0.3)
        hoverOverlay:Hide()
        
        -- Position and size the tab at the top
        if i == 1 then
            tab:SetPoint("TOPLEFT", tabContainer, "TOPLEFT", 0, 0)
        else
            tab:SetPoint("LEFT", _G["RaidDominionConfigTab"..(i-1)], "RIGHT", -10, 0)
        end
        tab:SetSize(tabWidth, tabHeight)
        
        -- Create a background for the tab text with a subtle border
        local bg = tab:CreateTexture(nil, "BORDER")
        bg:SetAllPoints()
        bg:SetTexture(0.1, 0.1, 0.1, 0.7)
        tab.bg = bg
        
        -- Add a highlight border for the active tab
        local highlight = tab:CreateTexture(nil, "ARTWORK")
        highlight:SetPoint("TOPLEFT", 0, 2)
        highlight:SetPoint("TOPRIGHT", 0, 2)
        highlight:SetHeight(3)
        highlight:SetTexture(1, 0.82, 0, 0)  -- Gold color
        highlight:Hide()
        tab.highlight = highlight
        
        tab:SetHighlightTexture("")
        tab:SetPushedTexture("")
        
        -- Set tab width based on text
        if fontString then
            tab:SetWidth(fontString:GetStringWidth() + 40) -- Auto-size width to text
        else
            tab:SetWidth(100) -- Default width if font string is not available
        end
        
        -- Create tab content container with improved styling (legacy system for 3.3.5a)
        local content = CreateFrame("Frame", nil, tabContainer)
        content:SetPoint("TOPLEFT", tabContainer, "TOPLEFT", 4, -tabHeight - 2)
        content:SetPoint("BOTTOMRIGHT", tabContainer, "BOTTOMRIGHT", -4, 4)
        
        -- Create background
        local bg = content:CreateTexture(nil, "BACKGROUND")
        bg:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
        bg:SetVertexColor(0.1, 0.1, 0.1, 0.8)
        bg:SetAllPoints(content)
        content.bg = bg
        
        -- No border textures - removed as requested
        
        -- Add a subtle highlight to the content background
        local highlight = content:CreateTexture(nil, "BACKGROUND")
        highlight:SetPoint("TOPLEFT", 4, -4)
        highlight:SetPoint("BOTTOMRIGHT", -4, 4)
        highlight:SetTexture("Interface\\Buttons\\UI-Listbox-Highlight2")
        highlight:SetBlendMode("ADD")
        highlight:SetAlpha(0.2)
        content:Hide()
        
        -- Store tab data
        self.tabs[i] = {
            id = tabDef.id,
            name = tabDef.name,
            button = tab,
            content = content,
            create = tabDef.create
        }
        
        -- Store texture references on the button for easier access
        tab.left = normalLeft
        tab.middle = normalMiddle
        tab.right = normalRight
        tab.highlightLeft = highlightLeft
        tab.highlightMiddle = highlightMiddle
        tab.highlightRight = highlightRight
        
        -- Set up tab click handler
        tab:SetScript("OnClick", function()
            PlaySound("igCharacterInfoTab")
            self:SelectTab(i)
        end)
        
        -- Add hover effect
        tab:SetScript("OnEnter", function(self)
            if self:IsEnabled() then
                self:GetFontString():SetTextColor(1, 0.82, 0)  -- Gold color on hover
            end
        end)
        
        tab:SetScript("OnLeave", function(self)
            if self:IsEnabled() then
                self:GetFontString():SetTextColor(0.8, 0.8, 0.6)  -- Normal color
            end
        end)
    end
    
    -- Initialize the first tab without showing the window
    self.currentTab = 1
    
    -- Hide the frame by default
    frame:Hide()
    
    self.frame = frame
    return frame
end

-- Select a tab by index
function ConfigManager:SelectTab(index)
    -- Validate index
    if index < 1 or index > #self.tabs or not self.tabs[index] then
        return
    end
    
    -- Hide all tab contents and reset their states
    for i, tabData in ipairs(self.tabs) do
        if tabData.content then
            tabData.content:Hide()
        end
        
        -- Reset tab button appearance
        if tabData.button then
            -- Hide highlight textures
            if tabData.button.highlightLeft then tabData.button.highlightLeft:Hide() end
            if tabData.button.highlightMiddle then tabData.button.highlightMiddle:Hide() end
            if tabData.button.highlightRight then tabData.button.highlightRight:Hide() end
            
            -- Show normal textures
            if tabData.button.left then 
                tabData.button.left:Show()
                tabData.button.left:SetAlpha(0.8)
            end
            if tabData.button.middle then 
                tabData.button.middle:Show()
                tabData.button.middle:SetAlpha(0.8)
            end
            if tabData.button.right then 
                tabData.button.right:Show()
                tabData.button.right:SetAlpha(0.8)
            end
            
            -- Reset text color and background
            local fs = tabData.button:GetFontString()
            if fs then
                fs:SetTextColor(0.8, 0.8, 0.6, 1)
            end
            if tabData.button.bg then
                tabData.button.bg:SetTexture(0.1, 0.1, 0.1, 0.7)
            end
            if tabData.button.highlight then
                tabData.button.highlight:Hide()
            end
        end
    end
    
    -- Show selected tab
    local tab = self.tabs[index]
    if tab and tab.button and tab.content then
        -- Update tab button appearance
        if tab.button.highlightLeft then tab.button.highlightLeft:Show() end
        if tab.button.highlightMiddle then tab.button.highlightMiddle:Show() end
        if tab.button.highlightRight then tab.button.highlightRight:Show() end
        
        -- Hide normal textures when highlighted
        if tab.button.left then tab.button.left:Hide() end
        if tab.button.middle then tab.button.middle:Hide() end
        if tab.button.right then tab.button.right:Hide() end
        
        -- Update text color for selected tab
        local fs = tab.button:GetFontString()
        if fs then
            fs:SetTextColor(1, 0.82, 0, 1) -- Gold color for selected tab
        end
        
        -- Update background and highlight for selected tab
        if tab.button.bg then
            tab.button.bg:SetTexture(0.2, 0.2, 0.2, 0.9)
        end
        if tab.button.highlight then
            tab.button.highlight:Show()
        end
        
        -- Show content with a slight delay for smoother transition
        tab.content:Show()
        
        -- Initialize tab content if not already done
        if not tab.initialized and tab.create then
            -- Use pcall to catch errors during tab creation (like the nil Factory error)
            local success, err = pcall(tab.create, tab.content)
            if not success then
                -- Fallback: show error message in the tab content
                local errorMsg = tab.content:CreateFontString(nil, "OVERLAY", "GameFontRedLarge")
                errorMsg:SetPoint("CENTER")
                errorMsg:SetText("Error al cargar la pestaña: " .. tostring(err))
                
                -- Also log to chat for debugging
                if RaidDominion.messageManager and RaidDominion.messageManager.SendSystemMessage then
                    RaidDominion.messageManager:SendSystemMessage("|cffff0000[RaidDominion]|r Error en ConfigManager (Pestaña " .. (tab.id or index) .. "): " .. tostring(err))
                else
                    SendSystemMessage("|cffff0000[RaidDominion]|r Error en ConfigManager: " .. tostring(err))
                end
            end
            tab.initialized = true
        end
        
        self.currentTab = index
        
        -- Play sound
        PlaySound("igCharacterInfoTab")
    end
end

-- Select a tab by id
function ConfigManager:SelectTabById(tabId)
    if not self.tabs or #self.tabs == 0 then
        return
    end
    local targetIndex
    for i, tab in ipairs(self.tabs) do
        if tab and tab.id == tabId then
            targetIndex = i
            break
        end
    end
    if targetIndex then
        self:SelectTab(targetIndex)
    else
        self:SelectTab(1)
    end
end

-- Toggle the config window
function ConfigManager:Toggle()
    if self.frame and self.frame:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

-- Show the config window
function ConfigManager:Show()
    if not self.frame then
        self:CreateWindow()
    end
    
    -- Select the General tab when showing the window
    if self.SelectTab then
        self:SelectTab(1) -- Select General tab (first tab)
    end
    
    -- Make sure the frame is shown and has focus
    self.frame:Show()
    self.frame:Raise()
    self.isShown = true
end

-- Hide the config window
function ConfigManager:Hide()
    if self.frame then
        self.frame:Hide()
        self.isShown = false
    end
end


-- Center the window on screen
function ConfigManager:CenterOnScreen()
    if not self.frame then return end
    
    self.frame:ClearAllPoints()
    self.frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
end

-- Initialize the config manager
function ConfigManager:Initialize()
    -- Register slash command
    SLASH_RAIDDOMINIONCONFIG1 = "/rdc"
    SlashCmdList["RAIDDOMINIONCONFIG"] = function() 
        if self.SelectTab then
            self:SelectTab(1) -- Select General tab (first tab)
        end
        self:Toggle() 
    end
    
    -- Add to UI namespace
    if not RaidDominion.ui then RaidDominion.ui = {} end
    RaidDominion.ui.configManager = self
    
    -- Create the window (but don't show it yet)
    self:CreateWindow()
    
    -- Set up drag behavior for when the window is shown
    if self.frame then
        self.frame:SetScript("OnDragStop", function()
            self.frame:StopMovingOrSizing()
        end)
    end
    
end

-- Initialize on load
ConfigManager:Initialize()

return ConfigManager
