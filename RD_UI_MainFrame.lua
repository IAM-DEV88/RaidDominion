--[[
    RD_UI_MainFrame.lua
    PROPÓSITO: Define el marco principal de la interfaz de usuario del addon.
    DEPENDENCIAS: RD_Constants.lua, RD_Events.lua, RD_Config.lua
    API PÚBLICA: 
        - RaidDominion.ui.mainFrame:Show()
        - RaidDominion.ui.mainFrame:Hide()
        - RaidDominion.ui.mainFrame:Toggle()
        - RaidDominion.ui.mainFrame:Update()
    EVENTOS: 
        - UI_SHOW: Se dispara cuando se muestra la interfaz
        - UI_HIDE: Se dispara cuando se oculta la interfaz
        - GROUP_ROSTER_UPDATE: Se dispara cuando cambia la composición del grupo
    INTERACCIONES: 
        - RD_Module_RoleManager: Muestra información de roles
        - RD_Module_MessageManager: Muestra notificaciones
        - RD_Config: Obtiene preferencias de la interfaz
--]]

local addonName, private = ...
local constants = RaidDominion.constants
local events = RaidDominion.events
local config = RaidDominion.config

-- Función para asegurar que el marco esté visible en pantalla
local function ensureOnScreen(frame)
    if not frame then return end
    
    -- Obtener dimensiones de la pantalla
    local screenWidth = UIParent:GetWidth()
    local screenHeight = UIParent:GetHeight()
    
    -- Obtener dimensiones del marco
    local frameWidth = frame:GetWidth() or 600
    local frameHeight = frame:GetHeight() or 400
    
    -- Obtener posición actual
    local point, relativeTo, relativePoint, xOfs, yOfs = frame:GetPoint(1)
    
    -- Si no hay punto de anclaje, centrar el marco
    if not point then
        frame:ClearAllPoints()
        frame:SetPoint("CENTER")
        return
    end
    
    -- Si está anclado a UIParent o no tiene padre, verificar límites
    local relativeToName = relativeTo and (relativeTo.GetName and relativeTo:GetName() or tostring(relativeTo)) or "UIParent"
    
    if relativeToName == "UIParent" or not relativeTo then
        -- Calcular posición absoluta
        local left = frame:GetLeft()
        local right = frame:GetRight()
        local top = frame:GetTop()
        local bottom = frame:GetBottom()
        
        -- Si alguna coordenada es nula, centrar el marco
        if not left or not right or not top or not bottom then
            frame:ClearAllPoints()
            frame:SetPoint("CENTER")
            return
        end
        
        -- Verificar si el marco está fuera de los límites
        if right < 0 or left > screenWidth or bottom > screenHeight or top < 0 then
            frame:ClearAllPoints()
            frame:SetPoint("CENTER")
        end
    end
end

-- Módulo del marco principal
local mainFrame = {
    isShown = false,
    panelsCreated = false,
    pendingCombatAction = nil
}

-- Inicialización de la tabla de instancia
function mainFrame:new()
    local instance = {}
    setmetatable(instance, { __index = self })
    return instance
end

--[[
    Crea el marco principal de la interfaz
    @param self Referencia al módulo
--]]
function mainFrame:Create()
    -- Verificar si ya existe el marco
    if self.frame then 
        return self.frame 
    end
    
    -- Obtener constantes
    local CONSTANTS = RaidDominion and RaidDominion.constants
    if not CONSTANTS then

        return nil
    end
    
    local SIZES = CONSTANTS.SIZES or {}
    local COLORS = CONSTANTS.COLORS or {}
    local ASSETS = CONSTANTS.ASSETS or {}
    
    -- Crear el marco principal con un nombre global único
    local frameName = "RaidDominionMainFrame"
    if _G[frameName] then

        self.frame = _G[frameName]
        return self.frame
    end
    
    -- Crear el marco
    self.frame = CreateFrame("Frame", "RaidDominionMainFrame", UIParent)
    self.frame:SetToplevel(true)
    
    -- Configurar el marco
    self.frame:SetSize(100, 50)  -- Tamaño inicial, se ajustará más adelante
    self.frame:SetFrameStrata("HIGH")
    self.frame:SetClampedToScreen(true)
    self.frame:SetMovable(true)
    self.frame:EnableMouse(true)
    self.frame:RegisterForDrag("LeftButton")
    self.frame:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    self.frame:SetBackdropColor(0, 0, 0, 0.9)
    self.frame:SetBackdropBorderColor(1, 1, 1, 0.5)
    self.frame:SetScript("OnDragStart", self.frame.StartMoving)
    self.frame:SetScript("OnDragStop", function()
        self.frame:StopMovingOrSizing()
        self:SavePosition()
    end)
    
    -- Método para guardar la posición actual del marco
    function self:SavePosition()
        if not self.frame or not RaidDominion or not RaidDominion.config then return end
        
        local point, relativeTo, relativePoint, xOfs, yOfs = self.frame:GetPoint(1)
        if not point then return end
        
        local relativeToName = "UIParent"
        if relativeTo and relativeTo.GetName then
            relativeToName = relativeTo:GetName()
        end
        
        local position = {
            point = point,
            relativeTo = relativeToName,
            relativePoint = relativePoint or point,
            x = xOfs or 0,
            y = yOfs or 0
        }
        
        RaidDominion.config:Set("ui.position", position)
    end
    
    -- Método para restaurar la posición guardada
    function self:RestorePosition()
        if not self.frame or not RaidDominion or not RaidDominion.config then return end
        
        local pos = RaidDominion.config:Get("ui.position")
        if not pos or not pos.point then return end
        
        local relativeTo = pos.relativeTo and _G[pos.relativeTo] or UIParent
        if not relativeTo then return end
        
        self.frame:ClearAllPoints()
        self.frame:SetPoint(
            pos.point,
            relativeTo,
            pos.relativePoint or pos.point,
            pos.x or 0,
            pos.y or 0
        )
        
        -- Asegurarse de que el marco esté dentro de los límites de la pantalla
        ensureOnScreen(self.frame)
    end
    
    -- Configurar eventos para guardar/restaurar posición
    self.frame:SetScript("OnHide", function() self:SavePosition() end)
    self.frame:SetScript("OnShow", function() self:RestorePosition() end)
    
    -- Configurar arrastre del marco
    self.frame:SetScript("OnDragStart", function()
        self.frame:StartMoving()
    end)
    
    self.frame:SetScript("OnDragStop", function()
        self.frame:StopMovingOrSizing()
        self:SavePosition()
        ensureOnScreen(self.frame)
    end)
    
    -- Intentar restaurar la posición guardada al inicio
    self:RestorePosition()
    
    -- Si no hay posición guardada, centrar el marco
    if not RaidDominion.config:Get("ui.position") then
        self.frame:SetPoint("CENTER")
    end
    
    -- Función para mostrar el menú principal
    local function ShowMainMenu()
        -- Ya no bloqueamos por combate, solo manejamos los cambios de UI con cuidado
        
        -- Asegurarse de que el marco principal exista
        if not self.frame then
            return false
        end
        
        -- Guardar la posición actual del marco
        local point, relativeTo, relativePoint, xOfs, yOfs = self.frame:GetPoint(1)
        
        -- Limpiar paneles existentes
        if self.panelsCreated then
            for i = self.frame:GetNumChildren(), 1, -1 do
                local child = select(i, self.frame:GetChildren())
                if child ~= self.tabFrame and child ~= self.actionBar then
                    -- Intentar ocultar solo si no causa bloqueo (los frames creados por nosotros no suelen ser protegidos)
                    pcall(function()
                        child:Hide()
                        if not InCombatLockdown() then
                            child:SetParent(nil)
                        end
                    end)
                end
            end
            self.panelsCreated = false
        end
        
        -- Recrear los paneles (que incluyen el menú)
        self:CreatePanels()
        
        -- Restaurar la posición del marco
        if point and relativeTo and relativePoint and relativeTo:IsShown() then
            -- Asegurarse de que el marco de referencia aún sea válido
            self.frame:ClearAllPoints()
            self.frame:SetPoint(point, relativeTo, relativePoint, xOfs, yOfs)
        else
            -- Si no hay una posición válida, intentar restaurar desde la configuración
            if RaidDominion and RaidDominion.config and RaidDominion.config.ui and RaidDominion.config.ui.position then
                local pos = RaidDominion.config.ui.position
                if pos.point and pos.relativeTo and pos.relativePoint and pos.x and pos.y then
                    local relativeTo = _G[pos.relativeTo] or UIParent
                    if relativeTo then
                        self.frame:ClearAllPoints()
                        self.frame:SetPoint(pos.point, relativeTo, pos.relativePoint, pos.x, pos.y)
                    end
                end
            end
        end
        
        -- Asegurarse de que el marco esté visible
    pcall(function() 
        self.frame:Show()
        self.frame:Raise()
    end)
    
    return true
end
    
    -- Almacenar la función para usarla desde fuera
    self.ShowMainMenu = ShowMainMenu
    
    -- Habilitar interacción con el ratón
    self.frame:EnableMouse(true)
    self.frame:SetSize(SIZES.MAIN_FRAME.WIDTH, SIZES.MAIN_FRAME.HEIGHT)
    self.frame:SetPoint("CENTER")
    self.frame:SetFrameStrata("MEDIUM")
    self.frame:SetMovable(true)
    self.frame:EnableMouse(true)
    self.frame:RegisterForDrag("LeftButton")
    self.frame:SetScript("OnDragStart", self.frame.StartMoving)
    self.frame:SetScript("OnDragStop", self.frame.StopMovingOrSizing)
    
    -- Crear fondo oscuro (eliminado para usar Backdrop)
    -- local bg = self.frame:CreateTexture(nil, "BACKGROUND")
    -- bg:SetAllPoints(true)
    -- bg:SetTexture(0, 0, 0, 0.6)  -- Fondo negro semitransparente
    -- bg:SetBlendMode("BLEND")
    
    -- Asegurarse de que el frame sea visible
    self.frame:Show()
    self.frame:Raise()
    
    -- Configurar clic derecho para mostrar el menú principal y manejar menús dinámicos
    -- Configurar clic derecho para mostrar el menú principal y manejar menús dinámicos
    self.frame:SetScript("OnMouseDown", function(self, button)
        if button == "RightButton" then
            -- Mostrar el menú principal
            ShowMainMenu()
            
            -- Ocultar todos los menús dinámicos
            if RaidDominion and RaidDominion.UI and RaidDominion.UI.DynamicMenus then
                for _, menu in pairs(RaidDominion.UI.DynamicMenus) do
                    if type(menu) == "table" and menu.Hide and menu:IsShown() then
                        menu:Hide()
                    end
                end
            end
            
            -- Asegurarse de que el menú principal esté visible
            if RaidDominion and RaidDominion.ui and RaidDominion.ui.mainFrame then
                RaidDominion.ui.mainFrame:Show()
            end
            return true
        end
    end)
    
    -- Almacenar referencia
    RaidDominion.ui.mainFrame = self
    
    -- Crear pestañas, paneles y barra de acciones
    self:CreateActionBar()
    
    if not self:CreatePanels() then
        local timer = CreateFrame("Frame")
        timer.elapsed = 0
        timer:SetScript("OnUpdate", function(t, elapsed)
            t.elapsed = t.elapsed + elapsed
            if t.elapsed >= 1.0 then
                t:SetScript("OnUpdate", nil)
                if self.frame and not self.panelsCreated then
                    self:CreatePanels()
                end
            end
        end)
    end

    self:ApplyConfig()
    
    -- Mostrar por defecto
    self.frame:Show()
    
    return self.frame
end

--[[
    Crea la barra de acciones en la parte inferior del marco
    @param self Referencia al módulo
--]]
function mainFrame:CreateActionBar()
    if not self.frame then return end
    
    local CONSTANTS = RaidDominion.constants
    local ACTION_BAR = CONSTANTS.ACTION_BAR
    
    -- Crear el contenedor de la barra de acciones
    local actionBar = CreateFrame("Frame", nil, self.frame)
    actionBar:SetHeight(ACTION_BAR.HEIGHT)
    
    -- Calcular el ancho total de la barra de acciones
    local totalWidth = (#ACTION_BAR.ITEMS * (ACTION_BAR.BUTTON_SIZE + ACTION_BAR.BUTTON_PADDING)) - ACTION_BAR.BUTTON_PADDING
    actionBar:SetWidth(totalWidth)
    
    -- Centrar la barra de acciones en la parte inferior del marco principal
    actionBar:SetPoint("BOTTOM", self.frame, "BOTTOM", 0, 0)
    
    actionBar:SetBackdrop(nil)
    
    -- Crear botones de la barra de acciones
    local buttonSize = ACTION_BAR.BUTTON_SIZE
    local padding = ACTION_BAR.BUTTON_PADDING
    local totalWidth = #ACTION_BAR.ITEMS * (buttonSize + padding) - padding
    
    -- Inicializar tabla de texturas si no existe (se mantiene para compatibilidad)
    if not RaidDominion.textures then
        RaidDominion.textures = {}
    end
    
    -- Usar el mismo método/estilo de botón que la barra superior derecha de CoreBands
    local coreBandsUtils = RaidDominion.utils and RaidDominion.utils.coreBands
    local function CreateStyledButton(name, parent, width, height, iconTexture, tooltipText)
        -- Si existe el helper global de CoreBands, úsalo para mantener estilo consistente
        if coreBandsUtils and coreBandsUtils.CreateStyledButton then
            local btn = coreBandsUtils.CreateStyledButton(name, parent, width, height, nil, iconTexture, tooltipText)
            btn:RegisterForClicks("AnyUp")
            RaidDominion.textures[name] = btn
            return btn
        end
        
        -- Fallback al estilo anterior en caso de que CoreBands no esté disponible
        local button = CreateFrame("Button", name, parent, "UIPanelButtonTemplate")
        button:SetSize(width or 60, height or 25)
        button:RegisterForClicks("AnyUp")
        
        local icon = button:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints()
        if iconTexture then
            icon:SetTexture(iconTexture)
        end
        button.icon = icon
        
        button:SetHighlightTexture("Interface/Buttons/UI-Panel-Button-Highlight", "ADD")
        button:SetPushedTexture("")
        
        if tooltipText then
            button:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:SetText(tooltipText, 1, 1, 1, 1, true)
                GameTooltip:Show()
            end)
            button:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)
        end
        
        RaidDominion.textures[name] = button
        return button
    end
    
    for i, item in ipairs(ACTION_BAR.ITEMS) do
        local texture = item.icon or "Interface/Icons/INV_Misc_QuestionMark"
        local tooltipText = item.name
        
        -- Crear botón con el mismo estilo visual que la barra superior derecha de CoreBands,
        -- reduciendo el tamaño 3px pero manteniendo el layout (posición relativa)
        local button = CreateStyledButton(
            "RaidDominionActionButton"..i,
            actionBar,
            buttonSize - 3,
            buttonSize - 3,
            texture,
            tooltipText
        )
        
        -- Posicionar el botón (sin cambios en layout)
        button:SetPoint("LEFT", actionBar, "LEFT", (i-1) * (buttonSize + padding), -1)
        
        -- Configurar acción del botón
        button:SetScript("OnClick", function(self, buttonName)
            local mm = RaidDominion.modules and RaidDominion.modules.messageManager
            local groupUtils = RaidDominion.utils and RaidDominion.utils.group
            local dialogs = RaidDominion.ui and RaidDominion.ui.dialogs
            local config = RaidDominion.config
            
            if buttonName == "LeftButton" then
                if item.name == "Modo de raid" then
                    if mm and mm.HandleRaidModeClick then
                        mm:HandleRaidModeClick()
                    end
                    return
                end
                if item.name == "Cambiar Botín" then
                    if groupUtils and groupUtils.ToggleLootMethod then
                        local msg = groupUtils:ToggleLootMethod()
                        if msg then SendSystemMessage(msg) end
                    end
                    return
                end
                if item.name == "Indicar discord" then
                    local realm = GetRealmName()
                    local char = UnitName("player") .. " - " .. realm
                    local safeChar = char:gsub("%.", "")
                    local link = config and config.Get and config:Get("profiles."..safeChar..".discordLink")
                    
                    if link and link ~= "" then
                        if mm and mm.SendRDMessage then
                            mm:SendRDMessage("discord", { link }, "DISCORD")
                        end
                    else
                        if dialogs and dialogs.ShowDiscordEditPopup then
                            dialogs:ShowDiscordEditPopup()
                        end
                    end
                    return
                end
                if item.name == "Nombrar objetivo" then
                    if mm and mm.NameTarget then
                        mm:NameTarget()
                    end
                    return
                end
                if item.name == "Susurrar asignaciones" then
                    if mm and mm.WhisperAssignments then
                        mm:WhisperAssignments()
                    end
                    return
                end
                if item.name == "Marcar principales" then
                    if mm and mm.AssignIconsAndAlert then
                        mm:AssignIconsAndAlert(buttonName)
                    end
                    return
                end
                if item.name == "Iniciar Check" then
                    if mm and mm.StartRoutineReadyCheck then
                        mm:StartRoutineReadyCheck()
                    end
                    return
                end
                if item.name == "Iniciar Pull" then
                    if mm and mm.StartPullFlow then
                        mm:StartPullFlow()
                    end
                    return
                end
                if item.name == "Configuración" then
                    -- Intentar obtener el gestor de configuración desde el espacio ui o raíz
                    local cm = (RaidDominion.ui and RaidDominion.ui.configManager) or RaidDominion.configManager
                    if not cm then return end
                    
                    -- Si la ventana ya está visible, simplemente alternar (ocultar)
                    if cm.frame and cm.frame:IsShown() and cm.Hide then
                        cm:Hide()
                        return
                    end
                    
                    -- Si está cerrada, mostrarla y seleccionar la pestaña adecuada
                    if cm.Show then
                        cm:Show()
                    elseif cm.Toggle then
                        cm:Toggle()
                    end
                    
                    -- Seleccionar pestaña según el menú actual si la API lo permite
                    local currentMenu = RaidDominion.UI and RaidDominion.UI.DynamicMenus and RaidDominion.UI.DynamicMenus.currentMenu
                    local targetId = "general"  -- Valor por defecto
                    
                    if currentMenu == "roles" then
                        targetId = "roles"
                    elseif currentMenu == "buffs" then
                        targetId = "buffs"
                    elseif currentMenu == "abilities" then
                        targetId = "abilities"
                    elseif currentMenu == "auras" then
                        targetId = "auras"
                    end
                    
                    if cm.SelectTabById then
                        cm:SelectTabById(targetId)
                    elseif cm.SelectTab then
                        cm:SelectTab(1)  -- Pestaña General por defecto
                    end
                    
                    return
                end
                if RaidDominion.MenuActions and RaidDominion.MenuActions.Execute and item.action then
                    RaidDominion.MenuActions:Execute(item.action)
                end
            elseif buttonName == "RightButton" then
                if item.name == "Modo de raid" then
                    if mm and mm.HandleRaidModeRightClick then
                        mm:HandleRaidModeRightClick()
                    end
                    return
                end
                if item.name == "Cambiar Botín" then
                    if groupUtils and groupUtils.SetMasterLooterToTarget then
                        local msg = groupUtils:SetMasterLooterToTarget()
                        if msg then SendSystemMessage(msg) end
                    end
                    return
                end
                if item.name == "Indicar discord" then
                    if dialogs and dialogs.ShowDiscordEditPopup then
                        dialogs:ShowDiscordEditPopup()
                    end
                    return
                end
                if item.name == "Nombrar objetivo" then
                    if mm and mm.ShowTargetInfo then
                        mm:ShowTargetInfo()
                    end
                    return
                end
                if item.name == "Iniciar Check" then
                    if mm and mm.ReportAbsentPlayers then
                        mm:ReportAbsentPlayers()
                    end
                    return
                end
                if item.name == "Iniciar Pull" then
                    if mm and mm.StartPullFlow then
                        mm:StartPullFlow()
                    end
                    return
                end
            end
        end)
        
        -- Almacenar referencia al botón
        actionBar["button"..i] = button
    end
    
    -- Almacenar referencia a la barra de acciones
    self.actionBar = actionBar
end

--[[
    Crea los paneles de la interfaz
    @param self Referencia al módulo
--]]
function mainFrame:CreatePanels()
    -- Verificar si ya se crearon los paneles
    if self.panelsCreated then return true end
    if not self.frame then return false end
    
    -- Guardar la posición actual del marco
    local point, relativeTo, relativePoint, xOfs, yOfs = self.frame:GetPoint(1)
    local wasShown = self.frame:IsShown()
    
    -- Marcar que los paneles ya se están creando (MOVIDO: Se asignará solo si hay éxito)
    -- self.panelsCreated = true
    
    -- Guardar la posición exacta
    self.frame.savedPosition = {
        point = point or "CENTER",
        relativeTo = relativeTo and (relativeTo.GetName and relativeTo:GetName() or tostring(relativeTo)) or "UIParent",
        relativePoint = relativePoint or "CENTER",
        x = xOfs or 0,
        y = yOfs or 0
    }
    
    -- Si está centrado, guardar la posición absoluta
    if point == "CENTER" then
        local scale = self.frame:GetEffectiveScale()
        local centerX, centerY = self.frame:GetCenter()
        local screenWidth = UIParent:GetWidth()
        local screenHeight = UIParent:GetHeight()
        
        self.frame.savedPosition = {
            point = "CENTER",
            relativeTo = "UIParent",
            relativePoint = "CENTER",
            x = (centerX - (screenWidth/2)) / scale,
            y = (centerY - (screenHeight/2)) / scale
        }
    end
    
    -- Creating interface panels
    
    -- Obtener constantes
    local SIZES = RaidDominion.constants.SIZES or {}
    local COLORS = RaidDominion.constants.COLORS or {}
    
    -- Crear contenedor principal
    local container = CreateFrame("Frame", "RaidDominionMainContainer", self.frame)
    container:SetPoint("TOP", 0, 0)  
    container:SetPoint("BOTTOM", self.actionBar, "TOP", 0, 0)
    container:SetWidth(1)
    container:EnableMouse(true)
    container:RegisterForDrag("LeftButton")
    container:SetScript("OnDragStart", function()
        if self.frame and self.frame.StartMoving then self.frame:StartMoving() end
    end)
    container:SetScript("OnDragStop", function()
        if self.frame and self.frame.StopMovingOrSizing then self.frame:StopMovingOrSizing() end
    end)
    
    -- Configurar clic derecho en el contenedor para mostrar el menú principal
    container:SetScript("OnMouseDown", function(self, button)
        if button == "RightButton" then
            if mainFrame and mainFrame.ShowMainMenu then
                mainFrame:ShowMainMenu()
            end
            return true
        end
    end)
    
    -- Sin fondo ni borde para el menú principal
    
    -- Verificar si existen los datos del menú
    if not RaidDominion.MenuData or not RaidDominion.MenuData.MainFrameOptions then
        return false
    end
    
    -- Filtrar los ítems del menú según la configuración
    local function GetFilteredMenuItems()
        local filteredItems = {}
        local config = RaidDominion.config
        
        for _, item in ipairs(RaidDominion.MenuData.MainFrameOptions) do
            local includeItem = true
            
            -- Verificar configuración para Mecánicas
            if item.name == "Mecánicas" then
                includeItem = config and config.Get and config:Get("ui.showMechanicsMenu") ~= false
            -- Verificar configuración para Hermandad
            elseif item.name == "Hermandad" then
                includeItem = config and config.Get and config:Get("ui.showGuildMenu") ~= false
            end
            
            if includeItem then
                table.insert(filteredItems, item)
            end
        end
        
        return filteredItems
    end
    
    local menuItems = GetFilteredMenuItems()
    local MenuFactory = RaidDominion.UI and RaidDominion.UI.MenuFactory
    if not MenuFactory then return false end

    self.panelsCreated = true
    local function computeActionName(item)
        local name
        if type(item.action) == "table" then
            name = item.action.action or item.action.name or tostring(item.action)
        else
            name = tostring(item.action)
        end
        name = name and name:match("^%s*(.-)%s*$")
        return name
    end
    local function onLeftClick(itemName, btn)
        local item
        for _, it in ipairs(menuItems) do
            if it.name == itemName then
                item = it
                break
            end
        end
        if not item then return end
        local actionName = computeActionName(item)
        if not actionName or actionName == "" then return end
        if not RaidDominion.MenuActions or not RaidDominion.MenuActions.actionsRegistered then
            if RaidDominion.MenuActions and RaidDominion.MenuActions.RegisterDefaultActions then
                RaidDominion.MenuActions.RegisterDefaultActions()
                RaidDominion.MenuActions.actionsRegistered = true
            end
        end
        if not RaidDominion.UI or not RaidDominion.UI.DynamicMenus then
            local ok = pcall(LoadAddOn, "RD_UI_DynamicMenus")
            if not ok then return end
        end
        if not RaidDominion.UI or not RaidDominion.UI.DynamicMenus then
            return
        end
        local menuType = string.lower(string.gsub(actionName, "^Show", ""))
        if actionName == "ShowRaidDominion" then
            menuType = "addonOptions"
        elseif actionName == "ShowGuild" then
            menuType = "guildOptions"
        elseif actionName == "ShowBossMechanics" then
            menuType = "mechanics"
        elseif actionName == "ShowRaidRules" then
            menuType = "raidrules"
        elseif actionName == "ShowMinigame" then
            menuType = "minigameOptions"
        end
        local menu
        if RaidDominion.UI and RaidDominion.UI.DynamicMenus and type(RaidDominion.UI.DynamicMenus.GetMenu) == "function" then
            menu = RaidDominion.UI.DynamicMenus:GetMenu(menuType)
        end
        if menu and menu:IsShown() then
            menu:Hide()
            return
        end
        local function ShowMenu()
            -- Ya no bloqueamos aquí para permitir la navegación fluida
            
            if not menu then
                if not RaidDominion.UI or not RaidDominion.UI.DynamicMenus then 
                    return 
                end
                if not RaidDominion.UI.DynamicMenus.initialized then
                    if not RaidDominion.UI.DynamicMenus.Initialize then
                        return
                    end
                    local initOk = select(1, pcall(function()
                        return RaidDominion.UI.DynamicMenus.Initialize(RaidDominion.UI.DynamicMenus)
                    end))
                    if not initOk then
                        return
                    end
                end
                menu = RaidDominion.UI.DynamicMenus:GetMenu(menuType)
                if not menu and type(RaidDominion.UI.DynamicMenus.CreateMenu) == "function" then
                    menu = RaidDominion.UI.DynamicMenus:CreateMenu(menuType, UIParent)
                end
                if not menu then
                    return
                end
            end
            if type(menu.Update) == "function" then
                menu:Update()
            end
            menu:ClearAllPoints()
            menu:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", 0, 0)
            menu:SetFrameStrata("MEDIUM")
            menu:SetFrameLevel(100)
            
            -- Ocultar el menú principal justo antes de mostrar el submenú
            local parent = btn:GetParent()
            if parent then
                pcall(function() parent:Hide() end)
            end
            
            pcall(function() menu:Show() end)
            if RaidDominion.MenuActions and RaidDominion.MenuActions.Execute then
                pcall(function()
                    return RaidDominion.MenuActions:Execute(actionName, { 
                        item = item, 
                        button = "LeftButton",
                        source = "main_menu",
                        forceShow = true
                    })
                end)
            end
        end
        if not menu then
            local delayFrame = CreateFrame("Frame")
            delayFrame:SetScript("OnUpdate", function(self, elapsed)
                self.timeElapsed = (self.timeElapsed or 0) + elapsed
                if self.timeElapsed >= 0.05 then
                    self:SetScript("OnUpdate", nil)
                    ShowMenu()
                    self:Hide()
                end
            end)
            delayFrame:Show()
        else
            ShowMenu()
        end
    end
    local function onRightClick(item, btn)
        local mm = RaidDominion and RaidDominion.messageManager
        local groupUtils = RaidDominion.utils and RaidDominion.utils.group
        local dialogs = RaidDominion.ui and RaidDominion.ui.dialogs
        
        if item.name == "Cambiar Botín" then
            if groupUtils and groupUtils.SetMasterLooterToTarget then
                local msg = groupUtils:SetMasterLooterToTarget()
                if msg then SendSystemMessage(msg) end
            end
            return
        end
        if item.name == "Indicar discord" then
            if dialogs and dialogs.ShowDiscordEditPopup then
                dialogs:ShowDiscordEditPopup()
            end
            return
        end
        if item.name == "Nombrar objetivo" then
            if mm and mm.ShowTargetInfo then
                mm:ShowTargetInfo()
            end
            return
        end
        if item.name == "Iniciar Check" then
            if mm and mm.ReportAbsentPlayers then
                mm:ReportAbsentPlayers()
            end
            return
        end
        if item.name == "Iniciar Pull" then
            if mm and mm.StartPullFlow then
                mm:StartPullFlow()
            end
            return
        end
    end
    local menuFrame, totalWidth, totalHeight = MenuFactory:CreateMenu(container, menuItems, 2, onLeftClick, false, nil, nil, onRightClick, true, true, false)
    if menuFrame then
        menuFrame:ClearAllPoints()
        menuFrame:SetPoint("CENTER", container, "CENTER", 0, 13)
        menuFrame:EnableMouse(true)
        menuFrame:RegisterForDrag("LeftButton")
        menuFrame:SetScript("OnDragStart", function()
            if self.frame and self.frame.StartMoving then self.frame:StartMoving() end
        end)
        menuFrame:SetScript("OnDragStop", function()
            if self.frame and self.frame.StopMovingOrSizing then self.frame:StopMovingOrSizing() end
        end)
        menuFrame:Show()
    end
    container:SetSize(totalWidth, totalHeight)
    container:SetPoint("CENTER")
    
    -- Obtener el alto de la barra de acciones
    local actionBarHeight = self.actionBar and self.actionBar:GetHeight() or 40
    
    -- Calcular el alto total necesario (contenido + barra de acciones + márgenes)
    local totalFrameHeight = totalHeight + actionBarHeight - 16
    
    -- Ajustar el tamaño del marco principal con padding
    local framePadding = 12
    self.frame:SetSize(totalWidth + (framePadding * 1.5), totalFrameHeight + (framePadding * 2))
    
    -- Restaurar la posición guardada
    self.frame:ClearAllPoints()
    if self.frame.savedPosition then
        local pos = self.frame.savedPosition
        local relativeTo = _G[pos.relativeTo] or UIParent
        
        -- Si la posición guardada es CENTER, usar las coordenadas guardadas directamente
        if pos.point == "CENTER" then
            self.frame:SetPoint("CENTER", UIParent, "CENTER", pos.x, pos.y)
        else
            -- Para otros puntos de anclaje, usar la posición relativa guardada
            self.frame:SetPoint(pos.point, relativeTo, pos.relativePoint, pos.x, pos.y)
        end
    else
        -- Si no hay posición guardada, centrar el marco
        self.frame:SetPoint("CENTER")
    end
    
    -- Posicionar el contenedor con padding
    container:ClearAllPoints()
    container:SetPoint("CENTER", 0, 0)
    self.container = container
    
    -- Asegurar que la barra de acciones esté en la parte inferior
    if self.actionBar then
        self.actionBar:ClearAllPoints()
        self.actionBar:SetPoint("BOTTOM", 0, 3)
    end
    
    return true
end

--[[
    Aplica la configuración a la interfaz
    @param self Referencia al módulo
    @param skipPosition Si es verdadero, no se aplica la posición guardada
--]]
function mainFrame:ApplyConfig(skipPosition)
    -- Verificar si el marco está inicializado
    if not self or not self.frame then 

        return false
    end
    
    -- Asegurarse de que el frame es válido
    if not self.frame.SetScale or type(self.frame.SetScale) ~= "function" then

        return false
    end
    
    -- Obtener configuración con valores por defecto seguros
    local config = RaidDominion and RaidDominion.config
    if not config or type(config.Get) ~= "function" then

        return false
    end
    
    -- Aplicar escala con valor por defecto seguro
    local scale = 1.0
    local success, result = pcall(function() return config:Get("ui.scale", 1.0) end)
    if success and type(result) == "number" and result > 0 then
        scale = result
    end
    
    -- Aplicar escala de forma segura
    pcall(function() self.frame:SetScale(scale) end)
    
    -- Aplicar opacidad con valor por defecto seguro
    local alpha = 1.0
    success, result = pcall(function() return config:Get("ui.opacity", 1.0) end)
    if success and type(result) == "number" and result >= 0 and result <= 1 then
        alpha = result
    end
    pcall(function() self.frame:SetAlpha(alpha) end)
    
    -- Solo aplicar la posición si no se indica lo contrario
    if not skipPosition then
        local x, y
        success, x = pcall(function() return config:Get("window.x") end)
        success, y = pcall(function() return config:Get("window.y") end)
        
        if x and y and type(x) == "number" and type(y) == "number" then
            -- Obtener posición actual de forma segura
            local currentX, currentY = self.frame:GetLeft(), self.frame:GetTop()
            
            -- Solo mover si la posición es significativamente diferente y el frame no está siendo arrastrado
            if (not currentX or not currentY or math.abs(currentX - x) > 1 or math.abs(currentY - y) > 1) and 
               not (self.frame:IsDragging() or self.frame.isMoving) then
                pcall(function()
                    -- Guardar la posición actual
                    local currentPoint, currentRelativeTo, currentRelativePoint, currentXOfs, currentYOfs = self.frame:GetPoint(1)
                    
                    -- Solo actualizar si es necesario
                    if not (currentPoint == "TOPLEFT" and 
                           currentRelativeTo == UIParent and 
                           currentRelativePoint == "BOTTOMLEFT" and
                           math.abs(currentXOfs - x) < 1 and 
                           math.abs(currentYOfs - y) < 1) then
                        
                        self.frame:ClearAllPoints()
                        self.frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)

                    end
                end)
            end
        end
    end
    
    -- Intentar guardar la posición actual
    pcall(function() if self.SavePosition then self:SavePosition() end end)
    
    return true
end

--[[
    Muestra u oculta el menú principal
    @param self Referencia al módulo
]]
function mainFrame:ToggleMainMenu()
    if RaidDominion.ui and RaidDominion.ui.menu then
        RaidDominion.ui.menu:Toggle()
    end
end

--[[
    Muestra el marco principal
    @param self Referencia al módulo
    @param skipPosition Si es verdadero, no se modifica la posición actual
--]]

-- Versión antigua de Show eliminada (duplicada)

function mainFrame:Show(skipPosition)
    if not self.frame then return end
    
    -- Aplicar configuración actual
    self:ApplyConfig(skipPosition)
    
    -- Solo restaurar la posición si es la primera vez que se muestra
    if not self.positionRestored and not skipPosition then
        self:RestorePosition()
        self.positionRestored = true
    end
    
    -- Asegurarse de que el marco esté visible en pantalla
    ensureOnScreen(self.frame)
    
    -- Asegurarse de que el marco principal esté visible
    pcall(function()
        self.frame:Show()
        self.isShown = true
    end)
    
    -- Lanzar evento de interfaz mostrada
    RaidDominion.events:Publish("UI_SHOW")
    
    -- Publicar evento de visibilidad cambiada
    if events and events.Publish then
        events:Publish("UI_VISIBILITY_CHANGED", true)
    end
    
    -- Asegurarse de que el menú principal esté visible
    if not self.container and self.CreatePanels then
        self:CreatePanels()
    end
    
    if self.container then
        pcall(function() self.container:Show() end)
        -- Forzar una actualización del layout
        pcall(function() self.container:GetParent():Show() end)
    end
    
    -- Lanzar evento de actualización (usando Publish si está disponible)
    if RaidDominion and RaidDominion.events then
        if RaidDominion.events.Publish then
            RaidDominion.events:Publish("MAIN_FRAME_SHOW")
        end
    end
    
    -- Actualizar la interfaz
    if self.Update then
        self:Update()
    end
    
    -- Asegurarse de que el marco esté en primer plano
    pcall(function() self.frame:Raise() end)
    
    -- Re-aplicar backdrop si estamos en combate para evitar pérdida de formato
    if InCombatLockdown() then
        pcall(function()
            self.frame:SetBackdrop({
                bgFile = "Interface/Tooltips/UI-Tooltip-Background",
                edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
                tile = true, tileSize = 16, edgeSize = 12,
                insets = { left = 3, right = 3, top = 3, bottom = 3 }
            })
            self.frame:SetBackdropColor(0, 0, 0, 0.9)
            self.frame:SetBackdropBorderColor(1, 1, 1, 0.5)
        end)
    end
    
    -- Main frame shown
    return true
end

--[[
    Oculta la interfaz
    @param self Referencia al módulo
]]
function mainFrame:Hide()
    if self.frame then
        self.frame:Hide()
        events:Publish("UI_HIDE")
    end
end

--[[
    Alterna la visibilidad del marco
    @param self Referencia al módulo
]]
function mainFrame:Toggle()
    if self.frame and self.frame:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

--[[
    Maneja los eventos de la interfaz
    @param self Referencia al módulo
    @param event Nombre del evento
    @param ... Argumentos del evento
]]
function mainFrame:OnEvent(event, ...)
    if event == "GROUP_ROSTER_UPDATE" then
        self:Update()
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Inicialización cuando el jugador entra al mundo
        self:Create()
    end
end

--[[ 
    Maneja eventos de la interfaz
    @param self Referencia al módulo
    @param event Nombre del evento
    @param ... Argumentos del evento
]]
-- Versión duplicada de OnEvent eliminada

-- Inicialización
function mainFrame:OnInitialize()
    -- Registrar eventos
    events:Subscribe("GROUP_ROSTER_UPDATE", function(...) 
        self:OnEvent("GROUP_ROSTER_UPDATE", ...) 
    end)
    
    -- Manejar salida de combate para acciones pendientes
    events:Subscribe("PLAYER_REGEN_ENABLED", function()
        if self.pendingCombatAction then
            local action = self.pendingCombatAction
            self.pendingCombatAction = nil
            action()
        end
    end)
    
    -- Crear el frame cuando la interfaz esté lista
    if not self.frame then
        self:Create()
    end
    
    -- Registrar comandos de consola
    SLASH_RAIDDOMINION1 = "/rd"
    SlashCmdList["RAIDDOMINION"] = function(msg)
        self:Toggle()
    end
    
    -- Registrar eventos de cambio de tamaño y posición
    self.frame:SetScript("OnSizeChanged", function()
        self:SavePosition()
    end)
    
    -- Asegurarse de que la posición se guarde al ocultar el marco
    self.frame:SetScript("OnHide", function()
        self:SavePosition()
    end)
    
    -- Inicializar la posición
    self:RestorePosition()
end

-- Registrar el módulo
RaidDominion.ui.mainFrame = mainFrame

-- Inicialización retrasada
events:Subscribe("PLAYER_LOGIN", function()
    mainFrame:OnInitialize()
end)

return mainFrame
