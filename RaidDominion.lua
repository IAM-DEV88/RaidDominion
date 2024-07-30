local RaidDominion = {}
RaidDominion.frame = CreateFrame("Frame", "RaidDominionFrame", UIParent)

local function CreateMenu(parent, items, yOffset, onClick, Assignable, roleType)
    local menu = CreateFrame("Frame", nil, parent)
    local labelHeight = 22
    local buttonSize = 20
    local buttonMargin = 1

    -- Calculamos el tamaño del menú tomando en cuenta los elementos y una fila adicional para los botones
    local totalItems = #items + 1 -- +1 para la fila de botones adicionales
    menu:SetSize(180, totalItems * labelHeight)
    menu:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, yOffset)
    menu:Hide()

    -- Crear botones para el menu
    for i, item in ipairs(items) do
        local labelWidth = 185
        local assignableButton = Assignable and roleType .. "Assignable" .. i or nil
        local button = CreateFrame("Button", assignableButton, menu, "RaidDominionButtonTemplate")
        local assignedPlayer = getAssignedPlayer(item.name)
        if Assignable then
            button:SetAttribute("player", assignedPlayer)
            local resetButton = CreateFrame("Button", nil, menu, "AssignableButtonTemplate")
            resetButton:SetSize(20, 20)
            resetButton:SetPoint("LEFT", button, "RIGHT", 0, 0)
            resetButton:SetNormalTexture(item.icon)
            resetButton:SetScript("OnClick", function()
                ResetRoleAssignment(item.name, button)
            end)
            labelWidth = 167
        end
        button:SetSize(labelWidth, labelHeight)
        button:SetPoint("TOPLEFT", -4, -labelHeight * (i - 1))
        button:SetText(item.name or item)
        button:SetNormalFontObject("GameFontNormal")
        button:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        button:RegisterForClicks("AnyUp") -- Esto habilita los clics derechos y izquierdos
        button:SetScript("OnClick", function(self, button)
            if button == "LeftButton" then
                onClick(item.name or item)
            elseif button == "RightButton" then
                RaidDominion:ShowMainMenu()
            end
        end)
    end

    -- Crear botones adicionales en una sola fila
    local totalButtonWidth = (#barItems * buttonSize) + ((#barItems - 1) * (buttonMargin * 2))
    local xOffset = (menu:GetWidth() - totalButtonWidth) / 2 - 8

    for i, key in ipairs(barItems) do
        local button = CreateFrame("Button", nil, menu, "RaidDominionButtonTemplate")
        button:SetSize(buttonSize, buttonSize)
        button:SetPoint("TOPLEFT", xOffset, -labelHeight * #items -8)
        button:SetNormalTexture(key.icon) -- Asignar el icono al botón
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
        xOffset = xOffset + buttonSize + (buttonMargin * 4)
    end

    return menu
end

function RaidDominion:HandleAssignableRole(role)
    local assignedPlayer = getAssignedPlayer(role)
    if assignedPlayer then
        SendRoleAlert(role, assignedPlayer)
    else
        SendRoleAlert(role)
    end
end

function RaidDominion:ShowMainMenu()
    if self.currentMenu then
        self.currentMenu:Hide()
    end
    self.mainMenu:Show()
    self.currentMenu = self.mainMenu
    self.frame:SetHeight(self.mainMenu:GetHeight() + 23) -- Ajustar la altura del frame según el menú principal
end

function RaidDominion:HandleMainOption(option)
    if option == "Roles principales" then
        self.mainMenu:Hide()
        self.primaryMenu:Show()
        self.currentMenu = self.primaryMenu
    elseif option == "BUFFs" then
        self.mainMenu:Hide()
        self.secondaryMenu:Show()
        self.currentMenu = self.secondaryMenu
    elseif option == "Habilidades principales" then
        self.mainMenu:Hide()
        self.primarySkillsMenu:Show()
        self.currentMenu = self.primarySkillsMenu
    elseif option == "Banda" then
        self.mainMenu:Hide()
        self.raidMenu:Show()
        self.currentMenu = self.raidMenu
    elseif option == "Reglas" then
        self.addonMenu:Hide()
        self:ShowRulesMenu()
    elseif option == "Mecanicas" then
        self.addonMenu:Hide()
        self:ShowMechanicsMenu()
    elseif option == "Roles secundarios" then
        self.mainMenu:Hide()
        self.secondaryRolesMenu:Show()
        self.currentMenu = self.secondaryRolesMenu
    elseif option == "RaidDominion Tools" then
        self.mainMenu:Hide()
        self.addonMenu:Show()
        self.currentMenu = self.addonMenu
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
        isMasterLooter = not isMasterLooter -- Cambiar el estado del maestro despojador
        if isMasterLooter then
            SetLootMethod("master", UnitName("player")) -- Establecer el método de botín a "Maestro despojador"
        else
            SetLootMethod("group") -- Establecer el método de botín a "Botín de grupo"
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
        self.frame:SetHeight(self.currentMenu:GetHeight() + 24)
    end
end

function RaidDominion:ShowRulesMenu()
    local rulesList = {}
    for rule, _ in pairs(raidRules) do
        table.insert(rulesList, rule)
    end
    if not self.rulesMenu then
        self.rulesMenu = CreateMenu(self.frame, rulesList, -12, function(rule)
            SlashCmdList["DEADLYBOSSMODS"]("broadcast timer 0:10 REGLAS")
            local title = "===> " .. rule .. " <==="
            local messages = raidRules[rule]
            table.insert(messages, 1, title)
            SendDelayedMessages(messages)
        end)
    end
    self.rulesMenu:Show()
    self.currentMenu = self.rulesMenu
    self.frame:SetHeight(self.rulesMenu:GetHeight() + 23)
end

function RaidDominion:ShowMechanicsMenu()
    local mechanicsList = {}
    for mechanic, _ in pairs(raidMechanics) do
        table.insert(mechanicsList, mechanic)
    end
    if not self.mechanicsMenu then
        self.mechanicsMenu = CreateMenu(self.frame, mechanicsList, -12, function(mechanic)
            -- Enviar los detalles específicos del jefe seleccionado a SendDelayedMessages
            if raidMechanics[mechanic] then
                SlashCmdList["DEADLYBOSSMODS"]("broadcast timer 0:10 MECANICAS")
                local title = "===> " .. mechanic .. " <==="
                local messages = raidMechanics[mechanic]
                table.insert(messages, 1, title)
                SendDelayedMessages(messages)
            end
        end)
    end
    self.mechanicsMenu:Show()
    self.currentMenu = self.mechanicsMenu
    self.frame:SetHeight(self.mechanicsMenu:GetHeight() + 23)
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

    self.mainMenu = CreateMenu(self.frame, mainOptions, -12, function(option)
        RaidDominion:HandleMainOption(option)
    end, false)
    self.primaryMenu = CreateMenu(self.frame, primaryRoles, -12, function(role)
        RaidDominion:HandleAssignableRole(role)
    end, true, "PrimaryRole")
    self.primarySkillsMenu = CreateMenu(self.frame, primarySkills, -12, function(role)
        RaidDominion:HandleAssignableRole(role)
    end, true, "PrimarySkill")
    self.secondaryMenu = CreateMenu(self.frame, primaryBuffs, -12, function(role)
        RaidDominion:HandleAssignableRole(role)
    end, true, "BUFFs")
    self.secondaryRolesMenu = CreateMenu(self.frame, secondaryRoles, -12, function(role)
        RaidDominion:HandleAssignableRole(role)
    end, true, "SecondaryRole")
    self.addonMenu = CreateMenu(self.frame, addonOptions, -12, function(option)
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
        -- print("PLAYER_LOGOUT")
        enabledPanel = (enabledPanelCheckbox:GetChecked() == 1) and true or false

        for k, v in (addonCache) do
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
