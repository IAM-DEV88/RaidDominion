local RaidDominion = {}
RaidDominion.frame = CreateFrame("Frame", "RaidDominionFrame", UIParent)

local LABEL_WIDTH = 185
local LABEL_HEIGHT = 22
local BUTTON_SIZE = 20
local BUTTON_MARGIN = 1
local COLUMN_SPACING = 20
local MAX_COLUMNS = 2

local function CreateMenu(parent, items, yOffset, onClick, Assignable, roleType)
    local menu = CreateFrame("Frame", nil, parent)

    -- Calcular el número de columnas, asegurando al menos 2 columnas
    local columns = math.max(2, math.min(MAX_COLUMNS, math.ceil(#items / 10)))
    local rows = math.ceil(#items / columns)

    -- Establecer un ancho fijo para todos los menús basado en el máximo número de columnas
    local fixedMenuWidth = MAX_COLUMNS * (LABEL_WIDTH + COLUMN_SPACING) - COLUMN_SPACING
    local menuHeight = rows * LABEL_HEIGHT + BUTTON_SIZE + BUTTON_MARGIN * 4
    menu:SetSize(fixedMenuWidth, menuHeight)
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
    local xOffset = (fixedMenuWidth - totalButtonWidth) / 2 - 8

    for i, key in ipairs(barItems) do
        local button = CreateFrame("Button", nil, menu, "RaidDominionButtonTemplate")
        button:SetSize(BUTTON_SIZE, BUTTON_SIZE)
        button:SetPoint("TOPLEFT", xOffset, -LABEL_HEIGHT * rows - 8)
        button:SetNormalTexture(key.icon)
        button:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        button:RegisterForClicks("AnyUp")
        button:SetScript("OnClick", function(self, button)
            RaidDominion:HandleMainOption(key.name, button)
            if button == "RightButton" then
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

    return menu, fixedMenuWidth, menuHeight
end



function RaidDominion:HandleAssignableRole(role)
    local assignedPlayer = getAssignedPlayer(role)
    if assignedPlayer then
        SendRoleAlert(role, assignedPlayer)
    else
        SendRoleAlert(role)
    end
end

function RaidDominion:HandleBuffClick(buffName)
    local _, channel = getPlayerInitialState()
    local message 
    if type(SendDelayedMessages) == "function" then
        SendDelayedMessages({message})
    else
    end
    self:HandleAssignableRole(buffName)
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

function RaidDominion:HandleMainOption(option, button)
    button = button or "LeftButton" -- Default to LeftButton if not provided
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
    elseif option == "RaidDominion" then
        self:ShowMenu(self.addonMenu, self.addonMenuWidth, self.addonMenuHeight)
    elseif option == "Opciones" then
        if RaidDominionWindow then
            RaidDominionWindow:Show()
        end
    elseif option == "Nombrar objetivo" then
        if button == "LeftButton" then
            nameTarget()
        elseif button == "RightButton" then
            showTargetInfo()
        end
    elseif option == "Modo de raid" then
        StaticPopup_Show("HEROIC_MODE_POPUP")
        if GetNumPartyMembers() ~= 0 then
            ConvertToRaid()
            SendSystemMessage("El grupo ahora es un raid.")
        else
            SendSystemMessage("Debes estar en grupo para crear una raid.")
        end
    elseif option == "Iniciar Check" then
        if button == "LeftButton" then
            DoReadyCheck()
        elseif button == "RightButton" then
                SendDelayedMessages({GetOutOfRangeRaidMembers()})
        end
    elseif option == "Iniciar Pull" then
        if button == "LeftButton" then
            if not SafeDBMCommand("broadcast timer 0:10 ¿TODOS LISTOS?") then
                SendSystemMessage("|cFFFFFF00Advertencia:|r DBM no está instalado. La función de temporizador no está disponible.")
            end
            StaticPopup_Show("CONFIRM_READY_CHECK")
        elseif button == "RightButton" then
            if not UnitExists("target") or not UnitIsPlayer("target") then
                SendSystemMessage("Por favor, selecciona un jugador objetivo primero.")
                return
            end
            
            local targetName = UnitName("target")
            -- Check if already blacklisted
            local isBlacklisted = false
            if BlackListedPlayers and BlackListedPlayers[GetRealmName()] then
                for _, player in ipairs(BlackListedPlayers[GetRealmName()]) do
                    if player.name and player.name:lower() == targetName:lower() then
                        isBlacklisted = true
                        break
                    end
                end
            end
            
            -- Toggle blacklist status
            if isBlacklisted then
                local dialog = StaticPopup_Show("CONFIRM_REMOVE_BLACKLIST", targetName)
                if dialog then
                    dialog.data = targetName
                end
            else
                -- Abre el diálogo de BlackList para ingresar la razón
                local dialog = StaticPopup_Show("BL_REASON", targetName)
                if dialog then
                    dialog.data = targetName
                end
            end
        end
    elseif option == "Cambiar Botin" then
        if button == "LeftButton" then
            isMasterLooter = not isMasterLooter
            if isMasterLooter then
                SetLootMethod("master", UnitName("player"))
                SendSystemMessage("Modo de botín: Maestro despojador (Tú)")
            else
                SetLootMethod("group")
                SendSystemMessage("Modo de botín: Grupo")
            end
        elseif button == "RightButton" then
            if not UnitExists("target") or not UnitIsPlayer("target") then
                SendSystemMessage("Por favor, selecciona un jugador objetivo primero.")
                return
            end
            
            if UnitIsUnit("target", "player") then
                SetLootMethod("master", UnitName("player"))
                SendSystemMessage("Modo de botín: Maestro despojador (Tú)")
            else
                local targetName = UnitName("target")
                SetLootMethod("master", targetName)
                SendSystemMessage(string.format("Modo de botín: Maestro despojador (%s)", targetName))
            end
            isMasterLooter = true
        end
    elseif option == "Recargar" then
        ReloadUI()
    elseif option == "Marcar principales" then
            AssignIconsAndAlert(button)
    elseif option == "Susurrar asignaciones" then
        if IsRaidLeader() then
            WhisperAssignments()
        end
    elseif option == "Ocultar" then
        RaidDominionFrame:Hide()
    elseif option == "Indicar discord" then
        if button == "LeftButton" then
            ShareDC()
        elseif button == "RightButton" then
            RaidDominionWindow:Show()
            local panel = _G["RaidDominionWindow"]
            PanelTemplates_SetTab(panel, 1)
            _G["RaidDominionOptionsTab"]:Show()
            _G["RaidDominionAboutTab"]:Hide()
            local discordInput = _G["DiscordLinkInput"]
            if discordInput then
                discordInput:SetFocus()
            end
            SendSystemMessage("Menú de opciones abierto con clic derecho")
        end
    elseif option == "Revisar banda" then
        if IsRaidLeader() then
            CheckRaidMembersForPvPGear()
        end
    elseif option == "Ayuda" then
        RaidDominionWindow:Show()
        local panel = _G["RaidDominionWindow"]
        PanelTemplates_SetTab(panel, 2)
        _G["RaidDominionAboutTab"]:Show()
        _G["RaidDominionOptionsTab"]:Hide()
    elseif option == "Hermandad" then
        self:ShowMenu(self.guildMenu, self.guildMenuWidth, self.guildMenuHeight)
    end

    if self.currentMenu then
        self.frame:SetSize(self.currentMenu:GetWidth() + 20, self.currentMenu:GetHeight() + 24)
    end
end

-- Función para manejar las opciones del menú de Hermandad
function RaidDominion:HandleGuildOption(option)
    if option == "Reglas" then
        self.addonMenu:Hide()
        self:ShowGuildRulesMenu()
    elseif option == "Sorteo" then
        GuildRoulette()
    elseif option == "Lista" then
        GetGuildMemberList()
        SendSystemMessage("Lista de miembros de la hermandad actualizada.")
    elseif option == "Reconocimientos" then
        CheckGuildOfficerNotes()
    elseif option == "Bienvenida" then
        ShowWelcomeMessage(true)
    elseif option == "Jerarquia" then
        ShowGuildHierarchy()
    end
    
    if self.currentMenu then
        self.frame:SetSize(self.currentMenu:GetWidth() + 20, self.currentMenu:GetHeight() + 24)
    end
end

-- Función para mostrar el menú de reglas de la hermandad
function RaidDominion:ShowGuildRulesMenu()
    local rulesList = {}
    for rule, _ in pairs(guildRules) do
        table.insert(rulesList, rule)
    end
    
    if not self.guildRulesMenu then
        self.guildRulesMenu, self.guildRulesMenuWidth, self.guildRulesMenuHeight =
            CreateMenu(self.frame, rulesList, -12, function(rule)
                local title = "===> " .. rule .. " <==="
                local messages = {title}
                
                -- Para todas las reglas, incluir los mensajes correspondientes
                for i, msg in ipairs(guildRules[rule]) do
                    table.insert(messages, msg)
                end
                
                SendDelayedMessages(messages, "GUILD")
            end, false)
    end
    
    self:ShowMenu(self.guildRulesMenu, self.guildRulesMenuWidth, self.guildRulesMenuHeight)
end

function RaidDominion:ShowRulesMenu()
    local rulesList = {}
    for rule, _ in pairs(raidRules) do
        table.insert(rulesList, rule)
    end
    if not self.rulesMenu then
        self.rulesMenu, self.rulesMenuWidth, self.rulesMenuHeight =
            CreateMenu(self.frame, rulesList, -12, function(rule)
                if not SafeDBMCommand("broadcast timer 0:10 REGLAS") then
                    SendSystemMessage("|cFFFFFF00Advertencia:|r DBM no está instalado. La función de temporizador no está disponible.")
                end
                local title = "===> " .. rule .. " <==="
                -- Create a new table with the title and a copy of the messages
                local messages = {title}
                for i, msg in ipairs(raidRules[rule]) do
                    table.insert(messages, msg)
                end
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
                if not SafeDBMCommand("broadcast timer 0:10 MECÁNICAS") then
                    SendSystemMessage("|cFFFFFF00Advertencia:|r DBM no está instalado. La función de temporizador no está disponible.")
                end
                local title = "===> " .. mechanic .. " <==="
                -- Create a new table with the title and a copy of the messages
                local messages = {title}
                for i, msg in ipairs(raidMechanics[mechanic]) do
                    table.insert(messages, msg)
                end
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
    self.frame:SetFrameStrata("MEDIUM") -- Colocar en la strata más alta disponible
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

    -- Función para obtener las opciones del menú principal según los permisos
    local function GetMainMenuOptions()
        local options = {"Habilidades principales", "Roles principales", "BUFFs", "Roles secundarios", "RaidDominion"}
        
        -- Agregar la opción de Hermandad solo si el jugador tiene los permisos necesarios
        if self:IsPlayerTopTwoRanks() then
            table.insert(options, "Hermandad")
        end
        
        return options
    end
    
    -- Crear menú principal
    self.mainMenu, self.mainMenuWidth, self.mainMenuHeight =
        CreateMenu(self.frame, GetMainMenuOptions(), -12, function(option)
            self:HandleMainOption(option, "LeftButton")
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
            RaidDominion:HandleBuffClick(role)
        end, true, "BUFFs")
    self.secondaryRolesMenu, self.secondaryRolesMenuWidth, self.secondaryRolesMenuHeight = CreateMenu(self.frame,
        secondaryRoles, -12, function(role)
            RaidDominion:HandleAssignableRole(role)
        end, true, "SecondaryRole")
    self.addonMenu, self.addonMenuWidth, self.addonMenuHeight =
        CreateMenu(self.frame, addonOptions, -12, function(option)
            RaidDominion:HandleMainOption(option)
        end, false)
        
    -- Crear menú de Hermandad
    self.guildMenu, self.guildMenuWidth, self.guildMenuHeight =
        CreateMenu(self.frame, guildOptions, -12, function(option)
            RaidDominion:HandleGuildOption(option)
        end, false)

    self:ShowMainMenu() -- Mostrar el menú principal directamente

    self.currentMenu = self.mainMenu
end

-- Función para verificar si el jugador es uno de los dos rangos más altos de la hermandad
function RaidDominion:IsPlayerTopTwoRanks()
    -- Verificar si el jugador está en una hermandad
    if not IsInGuild() then
        return false
    end
    
    -- Obtener el rango actual del jugador (0 = rango más alto, 1 = siguiente, etc.)
    local _, _, playerRankIndex = GetGuildInfo("player")
    
    -- Obtener el número total de rangos en la hermandad
    local numRanks = GuildControlGetNumRanks()
    
    -- Verificar si el jugador está en uno de los dos rangos más altos
    -- (0 y 1 son los dos rangos más altos, donde 0 es el rango más alto)
    if playerRankIndex == 0 or playerRankIndex == 1 then
        return true
    end
    
    return false
end

-- Function to handle events
local function OnEvent(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        -- Inicializar SavedVariables si es necesario
        enabledPanel = enabledPanel or false
        raidInfo = raidInfo or {}
        toExport = toExport or {}
        
        -- Configurar el comando de consola
        SLASH_RDOM1 = "/rdom"
        SlashCmdList["RDOM"] = function()
            if RaidDominionFrame:IsShown() then
                RaidDominionFrame:Hide()
            else
                RaidDominionFrame:Show()
            end
        end
        
        -- Registrar para el evento de interfaz cargada
        local f = CreateFrame("Frame")
        f:RegisterEvent("PLAYER_ENTERING_WORLD")
        f:SetScript("OnEvent", function(self, event)
            if event == "PLAYER_ENTERING_WORLD" then
                self:UnregisterEvent("PLAYER_ENTERING_WORLD")
                -- Actualizar el estado del checkbox después de que la interfaz esté completamente cargada
                if enabledPanelCheckbox then
                    enabledPanelCheckbox:SetChecked(enabledPanel)
                end
            end
        end)
        
    elseif event == "PLAYER_LOGIN" then
        getPlayersInfo()
        RaidDominionPanelInit()
        
        -- Mostrar mensaje de ayuda si el panel está desactivado
        if not enabledPanel then
            print("Puedes usar /rdom para mostrar el panel de RaidDominion")
        end
        
        -- Configurar el estado inicial del Frame
        if enabledPanel then
            RaidDominionFrame:Show()
            RaidDominionWindow:Show()
        else
            RaidDominionFrame:Hide()
            RaidDominionWindow:Hide()
        end
        -- Asegurarse de que la ventana esté oculta al inicio
        if RaidDominionWindow then
            RaidDominionWindow:Hide()
        end
    elseif event == "PARTY_MEMBERS_CHANGED" then
        -- print("PARTY_MEMBERS_CHANGED")
        getPlayersInfo()
    elseif event == "RAID_ROSTER_UPDATE" then
        -- print("RAID_ROSTER_UPDATE")
        getPlayersInfo()
    elseif event == "PLAYER_LOGOUT" then
        -- Actualizar el estado de enabledPanel desde el checkbox si existe
        if enabledPanelCheckbox then
            enabledPanel = enabledPanelCheckbox:GetChecked() or false
        end
        
        -- Guardar datos de la caché
        if addonCache then
            for k, v in pairs(addonCache) do
                raidInfo[k] = v
            end
        end
        
        -- No es necesario este bucle ya que toExport ya es una SavedVariable
        -- y se guardará automáticamente
    end
end

-- Formato mm:ss
local function FormatTime(sec)
    if not sec or sec <= 0 then return nil end
    local m = math.floor(sec / 60)
    local s = math.floor(sec % 60)
    return string.format("%dm%02ds", m, s)
end

local function SendAuraMessage(name, duration, expirationTime)
    local line1 = "[" .. name .. "]"
    local line2 = ""

    if duration and duration > 0 and expirationTime and expirationTime > 0 then
        local remaining = math.max(0, expirationTime - GetTime())
        local t = FormatTime(remaining)
        if t then line2 = "Duración: " .. t end
    end

    SendDelayedMessages({ line1, line2 })
end

-- Hook auras (barra global del player y auras del target)
local function HookAuraButtons(unit)
    local buffPrefix   = (unit == "player") and "BuffButton"   or "TargetFrameBuff"
    local debuffPrefix = (unit == "player") and "DebuffButton" or "TargetFrameDebuff"
    local maxAuras = 40

    for i = 1, maxAuras do
        local buff   = _G[buffPrefix..i]
        local debuff = _G[debuffPrefix..i]

        if buff and not buff.hooked then
            buff:EnableMouse(true)
            buff:SetScript("OnMouseUp", function(self, button)
                if button == "LeftButton" then
                    local idx = self:GetID() or i
                    local name, _, _, _, _, duration, expirationTime = UnitBuff(unit, idx)
                    if name then
                        SendAuraMessage(name, duration, expirationTime)
                    end
                end
            end)
            buff.hooked = true
        end

        if debuff and not debuff.hooked then
            debuff:EnableMouse(true)
            debuff:SetScript("OnMouseUp", function(self, button)
                if button == "LeftButton" then
                    local idx = self:GetID() or i
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

-- Hook a estados de arma (venenos/piedras). Muestra el nombre del arma en línea 1 y duración en línea 2
local function GetItemNameFromSlot(unit, slotId)
    local link = GetInventoryItemLink(unit, slotId)
    if link then
        local name = GetItemInfo(link)
        return name or link
    end
    return nil
end

local function SendWeaponMessage(slotName, slotId, ms)
    local wName = GetItemNameFromSlot("player", slotId) or slotName
    local line1 = "[" .. wName .. "]"
    local line2 = ""

    if ms and ms > 0 then
        local t = FormatTime(ms / 1000)
        if t then line2 = "Quedan: " .. t end
    end

    SendDelayedMessages({ line1, line2 })
end

local function HookWeaponEnchantButtons()
    local SLOT_MAIN   = INVSLOT_MAINHAND or 16
    local SLOT_OFF    = INVSLOT_OFFHAND or 17
    local SLOT_RANGED = INVSLOT_RANGED or 18

    for i = 1, 3 do
        local btn = _G["TempEnchant"..i]
        if btn and not btn.hooked then
            btn:EnableMouse(true)
            local idx = i
            btn:SetScript("OnMouseUp", function(self)
                local hasMain, mainMs, mainCharges,
                      hasOff,  offMs,  offCharges,
                      hasRanged, rangedMs, rangedCharges = GetWeaponEnchantInfo()

                -- Importante: el orden de los botones es distinto al orden lógico
                -- TempEnchant1 → puede ser OFFHAND si existe, sino MAIN
                -- TempEnchant2 → MAIN si hay OFFHAND
                -- TempEnchant3 → RANGED (incluye piedras de brujo)

                if idx == 1 then
                    if hasOff then
                        SendWeaponMessage("Off Hand", SLOT_OFF, offMs)
                    elseif hasMain then
                        SendWeaponMessage("Main Hand", SLOT_MAIN, mainMs)
                    end
                elseif idx == 2 then
                    if hasMain then
                        SendWeaponMessage("Main Hand", SLOT_MAIN, mainMs)
                    end
                elseif idx == 3 and hasRanged then
                    SendWeaponMessage("Ranged", SLOT_RANGED, rangedMs)
                end
            end)
            btn.hooked = true
        end
    end
end


-- Driver de eventos: re-hook cuando cambian auras/objetivo/equipo
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("UNIT_AURA")
f:RegisterEvent("PLAYER_TARGET_CHANGED")
f:RegisterEvent("UNIT_INVENTORY_CHANGED")
f:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")

f:SetScript("OnEvent", function(self, event, arg1)
    if event == "PLAYER_ENTERING_WORLD"
       or event == "PLAYER_TARGET_CHANGED"
       or (event == "UNIT_AURA" and (arg1 == "player" or arg1 == "target"))
    then
        HookAuraButtons("player")
        HookAuraButtons("target")
    end

    if event == "PLAYER_ENTERING_WORLD"
       or event == "UNIT_INVENTORY_CHANGED"
       or event == "PLAYER_EQUIPMENT_CHANGED"
    then
        HookWeaponEnchantButtons()
    end
end)






-- Create a frame to handle events
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_LOGOUT")
frame:RegisterEvent("PARTY_MEMBERS_CHANGED") -- Group changes
frame:RegisterEvent("RAID_ROSTER_UPDATE") -- Raid roster changes
frame:SetScript("OnEvent", OnEvent)

-- -----
-- Roster Updater
-- -----
local updateTime = 0
local ROSTER_UPDATE_THROTTLE = 15
local updateFrame = CreateFrame("frame")
updateFrame:Hide()
updateFrame:SetScript("OnUpdate", function(self, elapsed)
    local value_GetTime = GetTime()
    if value_GetTime > updateTime then
        updateTime = value_GetTime + ROSTER_UPDATE_THROTTLE
        GuildRoster()
    end
end)

RaidDominion:Init()
