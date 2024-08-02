local RaidDominion = {}
RaidDominion.frame = CreateFrame("Frame", "RaidDominionFrame", UIParent)

local LABEL_WIDTH = 185
local LABEL_HEIGHT = 22
local BUTTON_SIZE = 20
local BUTTON_MARGIN = 1
local COLUMN_SPACING = 20
local MAX_COLUMNS = 3

local function CreateMenu(parent, items, yOffset, onClick, Assignable, roleType)
    local menu = CreateFrame("Frame", nil, parent)

    -- Calcular el número de columnas y filas necesarias
    local columns = math.min(MAX_COLUMNS, math.ceil(#items / 10))
    local rows = math.ceil(#items / columns)

    -- Ajustar el tamaño del menú en función del número de columnas y filas
    local menuWidth = columns * (LABEL_WIDTH + COLUMN_SPACING) - COLUMN_SPACING
    local menuHeight = rows * LABEL_HEIGHT + BUTTON_SIZE + BUTTON_MARGIN * 4
    menu:SetSize(menuWidth, menuHeight)
    menu:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, yOffset)
    menu:Hide()

    -- Crear botones para el menú
    for i, item in ipairs(items) do
        local assignableButton = Assignable and roleType .. "Assignable" .. i or nil
        local button = CreateFrame("Button", assignableButton, menu, "RaidDominionButtonTemplate")
        local assignedPlayer = getAssignedPlayer(item.name)
        if Assignable then
            button:SetAttribute("player", assignedPlayer)
            local resetButton = CreateFrame("Button", nil, menu, "RaidDominionButtonTemplate")
            resetButton:SetSize(BUTTON_SIZE, BUTTON_SIZE)
            resetButton:SetPoint("LEFT", button, "RIGHT", 0, 0)
            resetButton:SetNormalTexture(item.icon)
            resetButton:SetScript("OnClick", function()
                ResetRoleAssignment(item.name, button)
            end)
            button:SetSize(LABEL_WIDTH - 18, LABEL_HEIGHT) -- Ajustar el ancho del botón si es asignable
        else
            button:SetSize(LABEL_WIDTH, LABEL_HEIGHT)
        end
        local col = (i - 1) % columns
        local row = math.floor((i - 1) / columns)
        button:SetPoint("TOPLEFT", col * (LABEL_WIDTH + COLUMN_SPACING), -row * LABEL_HEIGHT)
        button:SetText(item.name or item)
        button:GetFontString():SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
        button:SetNormalFontObject("GameFontHighlight")
        button:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        button:RegisterForClicks("AnyUp")
        button:SetScript("OnClick", function(self, button)
            if button == "LeftButton" then
                onClick(item.name or item)
            elseif button == "RightButton" then
                RaidDominion:ShowMainMenu()
            end
        end)
    end

    -- Crear botones adicionales en una sola fila
    local totalButtonWidth = (#barItems * BUTTON_SIZE) + ((#barItems - 1) * (BUTTON_MARGIN * 2))
    local xOffset = (menuWidth - totalButtonWidth) / 2 - 8

    for i, key in ipairs(barItems) do
        local button = CreateFrame("Button", nil, menu, "RaidDominionButtonTemplate")
        button:SetSize(BUTTON_SIZE, BUTTON_SIZE)
        button:SetPoint("TOPLEFT", xOffset, -LABEL_HEIGHT * rows - 8)
        button:SetNormalTexture(key.icon)
        button:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        button:RegisterForClicks("AnyUp")
        button:SetScript("OnClick", function(self, button)
            if button == "LeftButton" then
                RaidDominion:HandleMainOption(key.name)
            elseif button == "RightButton" then
                RaidDominion:ShowMainMenu()
            end
        end)
        button:SetScript("OnEnter", function()
            GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
            GameTooltip:SetText(key.name, 1, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        xOffset = xOffset + BUTTON_SIZE + (BUTTON_MARGIN * 4)
    end

    if columns > 1 then
        menuWidth = menuWidth - (columns * 9) - (columns > 2 and 10 or 0)
    end
    return menu, menuWidth, menuHeight
end

function RaidDominion:HandleAssignableRole(role)
    local assignedPlayer = getAssignedPlayer(role)
    if assignedPlayer then
        SendRoleAlert(role, assignedPlayer)
    else
        SendRoleAlert(role)
    end
end

function RaidDominion:ShowMenu(menu, menuWidth, menuHeight)
    if self.currentMenu then
        self.currentMenu:Hide()
    end
    menu:Show()
    self.currentMenu = menu

    -- Ajustar el tamaño del frame principal según las dimensiones del menú
    self.frame:SetSize(menuWidth + 20, menuHeight + 20)
end

function RaidDominion:ShowMainMenu()
    self:ShowMenu(self.mainMenu, self.mainMenuWidth, self.mainMenuHeight)
end

function RaidDominion:HandleMainOption(option)
    if option == "Roles principales" then
        self:ShowMenu(self.primaryMenu, self.primaryMenuWidth, self.primaryMenuHeight)
    elseif option == "BUFFs" then
        self:ShowMenu(self.secondaryMenu, self.secondaryMenuWidth, self.secondaryMenuHeight)
    elseif option == "Habilidades principales" then
        self:ShowMenu(self.primarySkillsMenu, self.primarySkillsMenuWidth, self.primarySkillsMenuHeight)
    elseif option == "Banda" then
        self:ShowMenu(self.raidMenu, self.raidMenuWidth, self.raidMenuHeight)
    elseif option == "Reglas" then
        self.addonMenu:Hide()
        self:ShowRulesMenu()
    elseif option == "Mecanicas" then
        self.addonMenu:Hide()
        self:ShowMechanicsMenu()
    elseif option == "Roles secundarios" then
        self:ShowMenu(self.secondaryRolesMenu, self.secondaryRolesMenuWidth, self.secondaryRolesMenuHeight)
    elseif option == "RaidDominion Tools" then
        self:ShowMenu(self.addonMenu, self.addonMenuWidth, self.addonMenuHeight)
    elseif option == "Nombrar objetivo" then
        nameTarget()
    elseif option == "Modo de raid" then
        StaticPopup_Show("HEROIC_MODE_POPUP")
        if GetNumPartyMembers() ~= 0 then
            ConvertToRaid()
            SendSystemMessage("El grupo ahora es un raid.")
        else
            SendSystemMessage("Debes estar en grupo para crear una raid.")
        end
    elseif option == "Iniciar Check" then
        DoReadyCheck()
    elseif option == "Iniciar Pull" then
        SlashCmdList["DEADLYBOSSMODS"]("broadcast timer 0:10 ¿TODOS LISTOS?")
        StaticPopup_Show("CONFIRM_READY_CHECK")
    elseif option == "Cambiar Botin" then
        isMasterLooter = not isMasterLooter
        if isMasterLooter then
            SetLootMethod("master", UnitName("player"))
        else
            SetLootMethod("group")
        end
    elseif option == "Recargar" then
        ReloadUI()
    elseif option == "Marcar principales" then
        AssignIconsAndAlert()
    elseif option == "Susurrar asignaciones" then
        WhisperAssignments()
    elseif option == "Ocultar" then
        RaidDominionFrame:Hide()
    elseif option == "Indicar discord" then
        ShareDC()
    elseif option == "Ayuda" then
        RaidDominionWindow:Show()
        local panel = _G["RaidDominionWindow"]
        PanelTemplates_SetTab(panel, 2)
        _G["RaidDominionAboutTab"]:Show()
        _G["RaidDominionOptionsTab"]:Hide()
    end

    if self.currentMenu then
        self.frame:SetSize(self.currentMenu:GetWidth() + 20, self.currentMenu:GetHeight() + 24)
    end
end

function RaidDominion:ShowRulesMenu()
    local rulesList = {}
    for rule, _ in pairs(raidRules) do
        table.insert(rulesList, rule)
    end
    if not self.rulesMenu then
        self.rulesMenu, self.rulesMenuWidth, self.rulesMenuHeight =
            CreateMenu(self.frame, rulesList, -12, function(rule)
                SlashCmdList["DEADLYBOSSMODS"]("broadcast timer 0:10 REGLAS")
                local title = "===> " .. rule .. " <==="
                local messages = raidRules[rule]
                table.insert(messages, 1, title)
                SendDelayedMessages(messages)
            end)
    end
    if self.rulesMenuWidth > 210 then
        self.rulesMenuWidth = self.rulesMenuWidth + 18
    end
    self:ShowMenu(self.rulesMenu, self.rulesMenuWidth, self.rulesMenuHeight)
end

function RaidDominion:ShowMechanicsMenu()
    local mechanicsList = {}
    for mechanic, _ in pairs(raidMechanics) do
        table.insert(mechanicsList, mechanic)
    end
    if not self.mechanicsMenu then
        self.mechanicsMenu, self.mechanicsMenuWidth, self.mechanicsMenuHeight =
            CreateMenu(self.frame, mechanicsList, -12, function(mechanic)
                SlashCmdList["DEADLYBOSSMODS"]("broadcast timer 0:10 MECÁNICAS")
                local title = "===> " .. mechanic .. " <==="
                local messages = raidMechanics[mechanic]
                table.insert(messages, 1, title)
                SendDelayedMessages(messages)
            end)
    end
    if self.mechanicsMenuWidth > 210 then
        self.mechanicsMenuWidth = self.mechanicsMenuWidth + 18
    end
    self:ShowMenu(self.mechanicsMenu, self.mechanicsMenuWidth, self.mechanicsMenuHeight)
end

function RaidDominion:Init()
    self.frame:SetSize(200, 0) -- Altura inicial arbitraria
    self.frame:SetPoint("CENTER")
    self.frame:SetFrameStrata("HIGH")
    self.frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = false,
        edgeSize = 1
    })
    self.frame:SetMovable(true)
    self.frame:EnableMouse(true)
    self.frame:RegisterForDrag("LeftButton")
    self.frame:SetScript("OnDragStart", self.frame.StartMoving)
    self.frame:SetScript("OnDragStop", self.frame.StopMovingOrSizing)

    self.mainMenu, self.mainMenuWidth, self.mainMenuHeight =
        CreateMenu(self.frame, mainOptions, -12, function(option)
            RaidDominion:HandleMainOption(option)
        end, false)
    self.primaryMenu, self.primaryMenuWidth, self.primaryMenuHeight =
        CreateMenu(self.frame, primaryRoles, -12, function(role)
            RaidDominion:HandleAssignableRole(role)
        end, true, "PrimaryRole")
    self.primarySkillsMenu, self.primarySkillsMenuWidth, self.primarySkillsMenuHeight = CreateMenu(self.frame,
        primarySkills, -12, function(role)
            RaidDominion:HandleAssignableRole(role)
        end, true, "PrimarySkill")
    self.secondaryMenu, self.secondaryMenuWidth, self.secondaryMenuHeight =
        CreateMenu(self.frame, primaryBuffs, -12, function(role)
            RaidDominion:HandleAssignableRole(role)
        end, true, "BUFFs")
    self.secondaryRolesMenu, self.secondaryRolesMenuWidth, self.secondaryRolesMenuHeight = CreateMenu(self.frame,
        secondaryRoles, -12, function(role)
            RaidDominion:HandleAssignableRole(role)
        end, true, "SecondaryRole")
    self.addonMenu, self.addonMenuWidth, self.addonMenuHeight =
        CreateMenu(self.frame, addonOptions, -12, function(option)
            RaidDominion:HandleMainOption(option)
        end, false)

    self:ShowMainMenu() -- Mostrar el menú principal directamente

    self.currentMenu = self.mainMenu
end

-- Function to handle events
local function OnEvent(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        -- print("ADDON_LOADED")
    elseif event == "PLAYER_LOGIN" then
        -- print("PLAYER_LOGIN")
        getPlayersInfo()
        RaidDominionPanelInit()
        RaidDominionWindow:Hide()
        if not enabledPanel then
            print("Puedes usar /rdom para mostrar el panel de RaidDominion Tools")
        end
        if enabledPanel then
            RaidDominionFrame:Show()
        else
            RaidDominionFrame:Hide()
        end
        SLASH_RDOM1 = "/rdom"
        SlashCmdList["RDOM"] = function()
            if RaidDominionFrame:IsShown() then
                RaidDominionFrame:Hide()
            else
                RaidDominionFrame:Show()
            end
        end
    elseif event == "PARTY_MEMBERS_CHANGED" then
        -- print("PARTY_MEMBERS_CHANGED")
        getPlayersInfo()
    elseif event == "RAID_ROSTER_UPDATE" then
        -- print("RAID_ROSTER_UPDATE")
        getPlayersInfo()
    elseif event == "PLAYER_LOGOUT" then
        enabledPanel = (enabledPanelCheckbox:GetChecked() == 1)
        for k, v in pairs(addonCache) do
            raidInfo[k] = v
        end
    end
end

-- Create a frame to handle events
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_LOGOUT")
frame:RegisterEvent("PARTY_MEMBERS_CHANGED") -- Group changes
frame:RegisterEvent("RAID_ROSTER_UPDATE") -- Raid roster changes
frame:SetScript("OnEvent", OnEvent)

RaidDominion:Init()
