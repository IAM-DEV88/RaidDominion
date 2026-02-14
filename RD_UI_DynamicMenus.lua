--[[
    RD_UI_DynamicMenus.lua
    PROPÓSITO: Sistema de menús dinámicos y contextuales (Roles, Habilidades, Buffs, Auras, Opciones) integrado en el MainFrame.
    DEPENDENCIAS: RD_Constants.lua, RD_Events.lua
    API PÚBLICA:
        - RaidDominion.UI.DynamicMenus:Initialize()
        - RaidDominion.UI.DynamicMenus:Render(menuType)
        - RaidDominion.UI.DynamicMenus:GetMenu(menuType)
        - RaidDominion.UI.DynamicMenus:CreateMenu(menuType, parent)  -- alias de GetMenu
        - RaidDominion.UI.DynamicMenus:EnsureInitialized()
    ESTADO:
        - currentMenu: Tipo de menú activo (string|nil)
    INTERACCIONES:
        - RD_UI_MainFrame: Contenedor y visibilidad del marco principal
        - RD_MenuActions: Acciones que abren y actualizan menús
]]

local RD = _G["RaidDominion"] or {}
_G["RaidDominion"] = RD

RD.UI = RD.UI or {}

local MENU_TYPES = {
    ROLES = "roles",
    ABILITIES = "abilities",
    BUFFS = "buffs",
    AURAS = "auras",
    ADDON = "addonOptions",
    GUILD = "guildOptions",
    RECOGNITION = "recognition",
    MECHANICS = "mechanics",
    RULES = "raidrules",
    GUILD_MESSAGES = "guildmessages",
    MINIGAME = "minigameOptions"
}

local DynamicMenus = {
    currentMenu = nil,
    initialized = false,
    menuTypes = MENU_TYPES
}

RD.UI.DynamicMenus = DynamicMenus


-- Obtener configuración
local function GetMenuConfig(menuType)
    if not RD.constants then return nil end
    local function BuildMechanicsItems()
        local items = {}
        local rm = RD.constants.RAID_MECHANICS or {}
        for title, arr in pairs(rm) do
            table.insert(items, { name = title, messages = arr })
        end
        table.sort(items, function(a, b) return tostring(a.name) < tostring(b.name) end)
        return items
    end
    local function BuildRulesItems()
        local items = {}
        local rr = RD.constants.RAID_RULES or {}
        for title, arr in pairs(rr) do
            table.insert(items, { name = title, messages = arr })
        end
        table.sort(items, function(a, b) return tostring(a.name) < tostring(b.name) end)
        return items
    end
    local function BuildGuildMessagesItems()
        local items = {}
        local gm = RD.constants.GUILD_MESSAGES or {}
        for title, arr in pairs(gm) do
            table.insert(items, { name = title, messages = arr })
        end
        table.sort(items, function(a, b) return tostring(a.name) < tostring(b.name) end)
        return items
    end
    local configs = {
        [MENU_TYPES.ROLES] = { configKey = "roles", data = RD.constants.ROLE_DATA or {}, title = "Roles" },
        [MENU_TYPES.ABILITIES] = { configKey = "abilities", data = RD.constants.SPELL_DATA and RD.constants.SPELL_DATA.abilities or {}, title = "Habilidades" },
        [MENU_TYPES.BUFFS] = { configKey = "buffs", data = RD.constants.SPELL_DATA and RD.constants.SPELL_DATA.buffs or {}, title = "Buffs" },
        [MENU_TYPES.AURAS] = { configKey = "auras", data = RD.constants.SPELL_DATA and RD.constants.SPELL_DATA.auras or {}, title = "Auras" },
        [MENU_TYPES.ADDON] = { configKey = "addonOptions", data = RD.constants.MENU_DEFINITIONS and RD.constants.MENU_DEFINITIONS.addonOptions or {}, title = "Raid Dominion" },
        [MENU_TYPES.GUILD] = { configKey = "guildOptions", data = RD.constants.MENU_DEFINITIONS and RD.constants.MENU_DEFINITIONS.guildOptions or {}, title = "Hermandad" },
        [MENU_TYPES.RECOGNITION] = { configKey = "recognition", data = RD.constants.MENU_DEFINITIONS and RD.constants.MENU_DEFINITIONS.recognition or {}, title = "Reconocimiento" },
        [MENU_TYPES.MECHANICS] = { configKey = "mechanics", data = BuildMechanicsItems(), title = "Mecánicas" },
        [MENU_TYPES.RULES] = { configKey = "raidrules", data = BuildRulesItems(), title = "Reglas" },
        [MENU_TYPES.GUILD_MESSAGES] = { configKey = "guildmessages", data = BuildGuildMessagesItems(), title = "Mensajes de Hermandad" },
        [MENU_TYPES.MINIGAME] = { configKey = "minigameOptions", data = RD.constants.MENU_DEFINITIONS and RD.constants.MENU_DEFINITIONS.minigameOptions or {}, title = "Minijuegos" }
    }
    return menuType and configs[menuType] or configs
end

function DynamicMenus:Initialize()
    if self.initialized then return true end
    
    RD.config = RD.config or {}
    
    -- Inicializar defaults en config
    local menuConfigs = GetMenuConfig()
    if menuConfigs then
        for menuType, config in pairs(menuConfigs) do
            local configSection = config.configKey or menuType
            -- No necesitamos inicializar la tabla en RD.config porque usamos Get/Set
            
            for _, item in ipairs(config.data or {}) do
                local key = string.lower(item.id or item.name or "")
                local fullKey = configSection .. "." .. key
                
                -- Si el valor no existe, establecerlo a true por defecto
                if key ~= "" and RD.config.Get and RD.config:Get(fullKey) == nil then
                    if RD.config.Set then
                        RD.config:Set(fullKey, true)
                    end
                end
            end
        end
    end
    
    -- Suscribirse a cambios
    if RD.events and RD.events.Subscribe then
        RD.events:Subscribe("CONFIG_CHANGED", function(menuTypeOrSection)
            -- Si el menú actual es el que cambió (o cambió todo), actualizar
            if self.currentMenu then
                local currentCfg = GetMenuConfig(self.currentMenu)
                if not menuTypeOrSection or (currentCfg and currentCfg.configKey == menuTypeOrSection) then
                    self:Render(self.currentMenu)
                end
            end
        end, 10)
        
        RD.events:Subscribe("ROLE_UPDATE", function(changedMenuType)
            if self.currentMenu and changedMenuType == self.currentMenu then
                self:Render(self.currentMenu)
            end
        end, 10)

        -- Suscribirse a cambios de grupo para refrescar menús
        RD.events:Subscribe("GROUP_UPDATED", function()
            if self.currentMenu then
                self:Render(self.currentMenu)
            end
        end, 10)
    end
    
    self.initialized = true
    return true
end

-- Renderiza el menú dentro del MainFrame
function DynamicMenus:Render(menuType)
    -- Ya no bloqueamos por combate para permitir la navegación,
    -- pero usamos pcall y verificaciones para evitar errores de protección.

    if not RD.ui or not RD.ui.mainFrame or not RD.ui.mainFrame.frame then
        return
    end

    local mainFrame = RD.ui.mainFrame.frame
    
    -- Ocultar el contenedor del menú principal si existe
    local mainContainer = _G["RaidDominionMainContainer"]
    if mainContainer then
        pcall(function() mainContainer:Hide() end)
    end

    -- Crear o recuperar el contenedor de menús dinámicos
    local container = _G["RaidDominionDynamicMenuContainer"]
    if not container then
        container = CreateFrame("Frame", "RaidDominionDynamicMenuContainer", mainFrame)
    end
    
    -- Asegurar el parentesco incluso en combate
    pcall(function() 
        if container:GetParent() ~= mainFrame then
            container:SetParent(mainFrame) 
        end
    end)
    
    container:EnableMouse(true)
    container:RegisterForDrag("LeftButton")
    container:SetScript("OnDragStart", function()
        if mainFrame and mainFrame.StartMoving then mainFrame:StartMoving() end
    end)
    container:SetScript("OnDragStop", function()
        if mainFrame and mainFrame.StopMovingOrSizing then mainFrame:StopMovingOrSizing() end
    end)

    -- Configurar clic derecho en el contenedor para volver al menú principal
    container:SetScript("OnMouseDown", function(self, button)
        if button == "RightButton" then
            if RD.ui and RD.ui.mainFrame and RD.ui.mainFrame.ShowMainMenu then
                RD.ui.mainFrame:ShowMainMenu()
            end
            return true
        end
    end)
    
    -- Asegurar que el estado se limpie cuando el contenedor se oculta
    -- Esto soluciona el problema de tener que hacer doble clic para reingresar
    container:SetScript("OnHide", function()
        DynamicMenus.currentMenu = nil
    end)
    
    container:ClearAllPoints()
    container:SetPoint("TOP", mainFrame, "TOP", 0, -10)
    container:SetPoint("LEFT", mainFrame, "LEFT", 10, 0)
    container:SetPoint("RIGHT", mainFrame, "RIGHT", -10, 0)
    pcall(function() container:Show() end)

    self.currentMenu = menuType
    local menuConfig = GetMenuConfig(menuType)
    if not menuConfig then return end

    -- Ocultar/Limpiar hijos actuales del contenedor dinámico
    -- En lugar de destruir y recrear, intentaremos reutilizar o al menos ocultar bien
    local children = {container:GetChildren()}
    for _, child in ipairs(children) do
        pcall(function()
            child:Hide()
            -- No desvinculamos en combate para evitar problemas de protección
            if not InCombatLockdown() then
                child:SetParent(nil)
            end
        end)
    end

    -- Obtener items habilitados
    local configSection = menuConfig.configKey
    local data = menuConfig.data or {}
    local items = {}
    
    for _, item in ipairs(data) do
        local key = string.lower(item.id or item.name or "")
        local isEnabled = true
        
        if RD.config and RD.config.Get then
            -- Usar Get con valor por defecto true
            local val = RD.config:Get(configSection .. "." .. key)
            if val == false then isEnabled = false end
        end
        
        if key ~= "" and isEnabled then
            table.insert(items, item)
        end
    end

    -- Configuración de diseño
    local buttonWidth = 180
    local buttonHeight = 24
    local buttonSpacing = 2
    local padding = 0
    
    -- Configuración de columnas
    local maxItemsPerColumn = 7  -- Máximo de elementos por columna
    local columns = 1
    
    -- Si hay más elementos que el máximo por columna, calcular columnas necesarias
    if #items > maxItemsPerColumn then
        columns = math.ceil(#items / maxItemsPerColumn)
    end
    
    -- Asegurarse de que no haya más de maxItemsPerColumn filas por columna
    local rows = math.ceil(#items / columns)
    if rows > maxItemsPerColumn then
        rows = maxItemsPerColumn
        columns = math.ceil(#items / rows)
    end
    
    -- Asegur un mínimo de 2 columnas si hay más de un elemento
    if #items > 1 and columns < 2 then
        columns = 2
    end
    
    -- Usar un contador para reutilizar frames si fuera posible, 
    -- pero por ahora seguiremos creando nuevos si no podemos desvincular,
    -- asegurándonos de que el formato se aplique correctamente.
    
    if #items == 0 then
        -- Envolver el mensaje en un Frame
        local msgFrame = CreateFrame("Frame", nil, container)
        msgFrame:SetAllPoints()
        
        local msg = msgFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        msg:SetPoint("CENTER")
        msg:SetText("No hay elementos habilitados")
        
        local totalWidth = (buttonWidth * columns) + (buttonSpacing * (columns - 1))
        local totalHeight = 100
        
        container:SetWidth(totalWidth)
        container:SetHeight(totalHeight)
        
        local actionBarHeight = (RD.ui.mainFrame.actionBar and RD.ui.mainFrame.actionBar:GetHeight()) or 40
        local framePadding = 12
        mainFrame:SetSize(totalWidth + (framePadding * 2), totalHeight + actionBarHeight + (framePadding * 2))
    else
        for i, item in ipairs(items) do
            local col = (i - 1) % columns
            local row = math.floor((i - 1) / columns)
            
            local button = CreateFrame("Button", nil, container)
            button:SetSize(buttonWidth, buttonHeight)
            button:SetPoint("TOPLEFT", padding + (col * (buttonWidth + buttonSpacing)), -padding - (row * (buttonHeight + buttonSpacing)))
            button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            
            -- Estilo Minimalista
            local bg = button:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            bg:SetTexture(0.2, 0.2, 0.2, 0.6)
            button.bg = bg

            -- Icono (A la derecha) como botón de asignación/reset
            local iconWidth = 0
            local iconBtn
            if item.icon then
                iconWidth = buttonHeight - 2
                iconBtn = CreateFrame("Button", nil, button)
                iconBtn:SetSize(iconWidth, iconWidth)
                iconBtn:SetPoint("RIGHT", 0, -.5)
                iconBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
                local iconTex = iconBtn:CreateTexture(nil, "ARTWORK")
                iconTex:SetAllPoints()
                iconTex:SetTexture(item.icon)
                iconBtn:SetNormalTexture(iconTex)
                local iconHL = iconBtn:CreateTexture(nil, "HIGHLIGHT")
                iconHL:SetAllPoints()
                iconHL:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
                iconHL:SetBlendMode("ADD")
                iconBtn:SetHighlightTexture(iconHL)
            end

            local isAssignableMenu = (menuType == MENU_TYPES.ROLES or menuType == MENU_TYPES.ABILITIES or menuType == MENU_TYPES.BUFFS or menuType == MENU_TYPES.AURAS)
            local keyLower = string.lower(item.id or item.name or "")
            local rm = (isAssignableMenu and RD.modules and RD.modules.roleManager) or nil
            local assignedUnit = rm and rm:GetAssignment(menuType, keyLower) or nil
            if isAssignableMenu and assignedUnit then
                if button.bg then button.bg:SetTexture(0.15, 0.45, 0.15, 0.6) end
            end
            local reservedRightSpace = 0

            -- Texto
            local btnText = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            btnText:SetPoint("LEFT", 6, 0)
            btnText:SetPoint("RIGHT", -(iconWidth + 8 + reservedRightSpace), 0)
            btnText:SetJustifyH("LEFT")
            btnText:SetWordWrap(false)
            if isAssignableMenu and assignedUnit then
                btnText:SetText((assignedUnit or "") .. " [" .. (item.name or "Sin Nombre") .. "]")
            else
                btnText:SetText(item.name or "Sin Nombre")
            end
            btnText:SetTextColor(1, 1, 1)
            button:SetFontString(btnText)
            
            -- Highlight
            local highlight = button:CreateTexture(nil, "HIGHLIGHT")
            highlight:SetAllPoints()
            highlight:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
            highlight:SetBlendMode("ADD")
            button:SetHighlightTexture(highlight)
            
            -- Color de clase
            if RAID_CLASS_COLORS and RAID_CLASS_COLORS[item.id] then
                local c = RAID_CLASS_COLORS[item.id]
                btnText:SetTextColor(c.r, c.g, c.b)
            end
            
            -- Hover
            button:SetScript("OnEnter", function(self)
                if self:GetFontString() then self:GetFontString():SetTextColor(1, 0.82, 0) end
                -- Solo cambiar el fondo si no está asignado
                if self.bg and not (isAssignableMenu and assignedUnit) then
                    self.bg:SetTexture(0.3, 0.3, 0.3, 0.8)
                end

                -- Tooltip con contenido para Mecánicas, Reglas y Mensajes
                if (menuType == MENU_TYPES.MECHANICS or menuType == MENU_TYPES.RULES or menuType == MENU_TYPES.GUILD_MESSAGES) and item.messages then
                    if RD.config and RD.config.Get and not RD.config:Get("ui.showTooltips", true) then
                        return
                    end
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetText(item.name, 1, 1, 1)
                    
                    for _, msg in ipairs(item.messages) do
                        -- Limpiar posibles separadores "//" para el tooltip y mostrar como líneas
                        local parts = { strsplit("//", msg) }
                        for _, part in ipairs(parts) do
                            local cleanPart = part:match("^%s*(.-)%s*$")
                            if cleanPart and cleanPart ~= "" then
                                GameTooltip:AddLine(cleanPart, 1, 0.82, 0, true)
                            end
                        end
                    end
                    
                    GameTooltip:AddLine("\n|cff00ff00Clic:|r Anunciar en el chat", 1, 0.82, 0)
                    GameTooltip:Show()
                end
            end)
            button:SetScript("OnLeave", function(self)
                GameTooltip:Hide()
                -- Restaurar color verde si está asignado, gris oscuro si no
                if self.bg then
                    if isAssignableMenu and assignedUnit then
                        self.bg:SetTexture(0.15, 0.45, 0.15, 0.6)
                    else
                        self.bg:SetTexture(0.2, 0.2, 0.2, 0.6)
                    end
                end
                if RAID_CLASS_COLORS and RAID_CLASS_COLORS[item.id] then
                    local c = RAID_CLASS_COLORS[item.id]
                    if self:GetFontString() then self:GetFontString():SetTextColor(c.r, c.g, c.b) end
                else
                    if self:GetFontString() then self:GetFontString():SetTextColor(1, 1, 1) end
                end
            end)
            
            if iconBtn and isAssignableMenu then
                iconBtn:SetScript("OnEnter", function(self)
                    if RD.config and RD.config.Get and not RD.config:Get("ui.showTooltips", true) then
                        return
                    end
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetText("Asignación rápida", 1, 1, 1)
                    GameTooltip:AddLine("Clic Izquierdo: Asignar al objetivo / Resetear", 1, 0.82, 0, true)
                    if menuType == MENU_TYPES.AURAS or menuType == MENU_TYPES.BUFFS then
                        GameTooltip:AddLine("Clic Derecho: Anunciar QUITAR", 1, 0.82, 0, true)
                    end
                    GameTooltip:AddLine("Requiere tener objetivo seleccionado para asignar", 1, 0.82, 0, true)
                    GameTooltip:Show()
                end)
                iconBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
                iconBtn:SetScript("OnClick", function(self, buttonName)
                    if buttonName == "RightButton" and (menuType == MENU_TYPES.AURAS or menuType == MENU_TYPES.BUFFS) then
                        local mm = RaidDominion.modules and RaidDominion.modules.messageManager
                        if mm and mm.SendItemAnnouncement then
                            mm:SendItemAnnouncement(menuType, item.name, "QUITAR")
                        end
                        return
                    end

                    local currentAssigned = rm and rm:GetAssignment(menuType, keyLower)
                    if currentAssigned then
                        if rm then rm:ResetAssignment(menuType, keyLower) end
                        return
                    end
                    if UnitExists("target") then
                        local unitName = UnitName("target")
                        if rm then rm:AssignItem(menuType, keyLower, unitName) end
                    end
                end)
            end
            
            if assignedUnit then end
            
            -- Acción
            button:SetScript("OnClick", function(self, buttonName)
                if buttonName == "RightButton" then
                    if RD.ui and RD.ui.mainFrame and RD.ui.mainFrame.ShowMainMenu then
                        RD.ui.mainFrame:ShowMainMenu()
                    end
                    return
                end

                local mm = RaidDominion.modules and RaidDominion.modules.messageManager
                if isAssignableMenu and mm and mm.SendItemAnnouncement then
                    local typeKey = menuType
                    if assignedUnit then
                        mm:SendItemAnnouncement(typeKey, keyLower, assignedUnit)
                    else
                        mm:SendItemAnnouncement(typeKey, item.name, "NEED")
                    end
                    return
                end
                if menuType == MENU_TYPES.MECHANICS and mm and mm.SendRDMessage then
                    mm:SendRDMessage("mecanica", item.name)
                    return
                end
                if menuType == MENU_TYPES.RULES and mm and mm.SendRDMessage then
                    mm:SendRDMessage("regla", item.name)
                    return
                end
                if menuType == MENU_TYPES.GUILD_MESSAGES and mm and mm.SendRDMessage then
                    mm:SendRDMessage("mensaje", item.name)
                    return
                end
                if RD.MenuActions and RD.MenuActions.Execute and item.action then
                    local ok, err = pcall(function()
                        RD.MenuActions:Execute(item.action, { item = item, button = "LeftButton", source = "dynamic_menu" })
                    end)
                    return
                end
            end)
            
            button:Show()
        end
        
        -- Redimensionar
        local totalRows = math.ceil(math.max(#items, 1) / columns)
        local totalHeight = (math.min(totalRows, maxItemsPerColumn) * buttonHeight) + ((math.min(totalRows, maxItemsPerColumn) - 1) * buttonSpacing) + (padding * 2)
        local totalWidth = (buttonWidth * columns) + (buttonSpacing * (columns - 1)) + (padding * 2)
        
        pcall(function()
            container:SetWidth(totalWidth)
            container:SetHeight(totalHeight)
            
            local actionBarHeight = (RD.ui.mainFrame.actionBar and RD.ui.mainFrame.actionBar:GetHeight()) or 40
            local framePadding = 12
            local totalFrameHeight = totalHeight + actionBarHeight + (framePadding * 2)
            
            mainFrame:SetSize(totalWidth + (framePadding * 2), totalFrameHeight)
            
            -- Re-aplicar backdrop del mainFrame para asegurar el formato en combate
            if InCombatLockdown() then
                mainFrame:SetBackdrop({
                    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
                    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
                    tile = true, tileSize = 16, edgeSize = 12,
                    insets = { left = 3, right = 3, top = 3, bottom = 3 }
                })
                mainFrame:SetBackdropColor(0, 0, 0, 0.9)
                mainFrame:SetBackdropBorderColor(1, 1, 1, 0.5)
            end
        end)
    end
    
    pcall(function()
        container:Show()
        mainFrame:Show()
    end)
end

-- Interfaz compatible con RD_MenuActions
-- Devuelve un objeto "dummy" que redirige las llamadas a Render
function DynamicMenus:GetMenu(menuType)
    if not self.initialized then self:Initialize() end
    
    local menuProxy = {}
    
    function menuProxy:Show()
        DynamicMenus:Render(menuType)
    end
    
    function menuProxy:Hide()
        -- Al ocultar un submenú, volvemos al menú principal
        if RD.ui and RD.ui.mainFrame and RD.ui.mainFrame.ShowMainMenu then
            RD.ui.mainFrame:ShowMainMenu()
        end
        DynamicMenus.currentMenu = nil
    end
    
    function menuProxy:Update()
        DynamicMenus:Render(menuType)
    end
    
    function menuProxy:IsShown()
        return DynamicMenus.currentMenu == menuType
    end
    
    function menuProxy:Raise()
        if RD.ui and RD.ui.mainFrame and RD.ui.mainFrame.frame then
            RD.ui.mainFrame.frame:Raise()
        end
    end

    -- Métodos dummy para satisfacer la interfaz de RD_UI_MainFrame.lua
    function menuProxy:ClearAllPoints() end
    function menuProxy:SetPoint(...) end
    function menuProxy:SetFrameStrata(...) end
    function menuProxy:SetFrameLevel(...) end
    
    return menuProxy
end

-- CreateMenu ahora es un alias para GetMenu en este nuevo paradigma
function DynamicMenus:CreateMenu(menuType, parent)
    return self:GetMenu(menuType)
end

-- Inicialización automática
if RD.constants then
    DynamicMenus:Initialize()
end
