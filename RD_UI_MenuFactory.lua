--[[
    RD_UI_MenuFactory.lua
    PROPÓSITO: Maneja la creación de menús siguiendo el patrón de fábrica.
    DEPENDENCIAS: RD_Constants.lua, RD_Menu.lua
    API PÚBLICA:
        - RD.UI.MenuFactory:CreateMenu(items, columns, assignable, roleType, barItems, onClick)
        - RD.UI.MenuFactory:RenderBar(buttonBar, barItems)
]]

local addonName, private = ...
local RD = _G["RaidDominion"] or {}
_G["RaidDominion"] = RD

-- Obtener constantes
local CONSTANTS = RD.constants or {}
local MENU_CONSTANTS = CONSTANTS.SIZES and CONSTANTS.SIZES.MENU or {}
local COLORS = CONSTANTS.COLORS or {}
local BACKDROP = CONSTANTS.BACKDROP or {}
local UI = CONSTANTS.UI or {}

local MenuFactory = {}

-- Constantes locales
local LABEL_WIDTH = MENU_CONSTANTS.LABEL_WIDTH or 185
local LABEL_HEIGHT = MENU_CONSTANTS.LABEL_HEIGHT or 22
local BUTTON_SIZE = MENU_CONSTANTS.BUTTON_SIZE or 20
local BUTTON_MARGIN = MENU_CONSTANTS.BUTTON_MARGIN or 1
local COLUMN_SPACING = MENU_CONSTANTS.COLUMN_SPACING or 20
local MAX_COLUMNS = MENU_CONSTANTS.MAX_COLUMNS or 2

--[[
    Crea un menú con el diseño especificado
    @param parent Marco padre del menú
    @param items Tabla con los elementos del menú
    @param yOffset Desplazamiento vertical inicial
    @param onClick Función a ejecutar al hacer clic
    @param assignable Indica si los elementos son asignables
    @param roleType Tipo de rol para elementos asignables
    @param barItems Elementos de la barra inferior (opcional)
    @return Frame del menú, ancho y alto
]]
function MenuFactory:CreateMenu(parent, items, yOffset, onClick, assignable, roleType, barItems, onRightClick, noBackdrop, centerLabels, movable)
    local menu = CreateFrame("Frame", nil, parent)
    
    -- Configuración básica del menú
    menu:SetFrameStrata("MEDIUM")
    menu:SetClampedToScreen(true)
    menu:SetMovable(movable and true or false)
    menu:EnableMouse(true)
    if movable then
        menu:RegisterForDrag("LeftButton")
        menu:SetScript("OnDragStart", menu.StartMoving)
        menu:SetScript("OnDragStop", menu.StopMovingOrSizing)
    else
        menu:SetScript("OnDragStart", nil)
        menu:SetScript("OnDragStop", nil)
    end
    
    -- Configurar el fondo
    if not noBackdrop then
        menu:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = false,
            edgeSize = 16,
            insets = { left = 5, right = 5, top = 5, bottom = 5 }
        })
    end
    
    -- Calcular columnas
    local overrideColumns = (type(yOffset) == "number" and yOffset > 0) and yOffset or nil
    
    -- Configuración de columnas
    local maxItemsPerColumn = 7  -- Máximo de elementos por columna
    local columns = 1
    
    -- Si hay más elementos que el máximo por columna, calcular columnas necesarias
    if #items > maxItemsPerColumn then
        columns = math.ceil(#items / maxItemsPerColumn)
    end
    
    -- Usar el valor de overrideColumns si está definido
    if overrideColumns then
        columns = overrideColumns
    end
    
    -- Asegurarse de no exceder el número máximo de columnas
    columns = math.min(MAX_COLUMNS, columns)
    
    -- Calcular el número real de filas necesarias
    local rows = math.ceil(#items / columns)
    
    -- Asegurarse de que no haya más de maxItemsPerColumn filas por columna
    if rows > maxItemsPerColumn then
        rows = maxItemsPerColumn
        columns = math.ceil(#items / rows)
    end
    
    local menuWidth = (LABEL_WIDTH * columns) + (COLUMN_SPACING * (columns - 1))
    local menuHeight = math.max(0, (rows * LABEL_HEIGHT))
    
    -- Ajustar para la barra de botones si existe
    if barItems and #barItems > 0 then
        menuHeight = menuHeight + BUTTON_SIZE
    end
    
    menu:SetSize(menuWidth, menuHeight)
    
    -- Crear botones del menú
    for i, item in ipairs(items) do
        local col = (i - 1) % columns
        local row = math.floor((i - 1) / columns)
        
        local button = CreateFrame("Button", nil, menu, "UIPanelButtonTemplate")
        button:SetSize(LABEL_WIDTH, LABEL_HEIGHT)
        button:SetPoint("TOPLEFT", col * (LABEL_WIDTH + COLUMN_SPACING), -row * LABEL_HEIGHT)
        
        -- Configurar texto del botón
        local fontString = button:GetFontString()
        if fontString then
            fontString:SetFontObject("GameFontHighlight")
            fontString:ClearAllPoints()
            if centerLabels then
                fontString:SetJustifyH("CENTER")
                fontString:SetPoint("CENTER", 0, 0)
            else
                fontString:SetJustifyH("LEFT")
                fontString:SetPoint("LEFT", 5, 0)
                fontString:SetPoint("RIGHT", -5, 0)
            end
            fontString:SetWordWrap(false)
        end
        
        button:SetText(item.name or item)
        
        -- Estilo de texto simple (usar texturas vacías o transparentes)
        local emptyTexture = "Interface\\Buttons\\UI-Slot-Background"
        button:SetNormalTexture(nil)
        button:SetPushedTexture(nil)
        button:SetDisabledTexture(nil)
        button:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        
        -- Si estamos en combate, forzar la eliminación de texturas de plantilla
        if InCombatLockdown() then
            local n = button:GetNormalTexture()
            if n then n:SetAlpha(0) end
            local p = button:GetPushedTexture()
            if p then p:SetAlpha(0) end
            local d = button:GetDisabledTexture()
            if d then d:SetAlpha(0) end
        end
        if button:GetFontString() then
            button:GetFontString():SetTextColor(1, 1, 1, 1)
        end
        button:SetScript("OnEnter", function(self)
            local fs = self:GetFontString()
            if fs then fs:SetTextColor(1, 0.82, 0) end
        end)
        button:SetScript("OnLeave", function(self)
            local fs = self:GetFontString()
            if fs then fs:SetTextColor(1, 1, 1, 1) end
        end)
        
        -- Configurar acciones del botón
        button:SetScript("OnClick", function(self, btn)
            if btn == "LeftButton" then
                if onClick then
                    onClick(item.name or item, self)
                end
            elseif btn == "RightButton" then
                if onRightClick then
                    onRightClick(item, self)
                else
                    if RD.ui and RD.ui.menu and RD.ui.menu.NavigateTo then
                        RD.ui.menu:NavigateTo("Main")
                    end
                end
            end
        end)
        
        -- Configurar tooltip
        if item.tooltip then
            button:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(item.name or "", 1, 1, 1, 1, true)
                GameTooltip:AddLine(item.tooltip, nil, nil, nil, true)
                GameTooltip:Show()
            end)
            
            button:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)
        end
        
        -- Botón de asignación si es necesario
        if assignable and roleType then
            local assignButton = CreateFrame("Button", nil, menu, "UIPanelButtonTemplate")
            assignButton:SetSize(BUTTON_SIZE, BUTTON_SIZE)
            assignButton:SetPoint("LEFT", button, "RIGHT", 2, 0)
            
            if item.icon then
                local texture = assignButton:CreateTexture()
                texture:SetAllPoints()
                texture:SetTexture(item.icon)
                assignButton:SetNormalTexture(texture)
            end
            
            assignButton:SetScript("OnClick", function()
                -- Implementar lógica de asignación
                if RD.MenuActions and RD.MenuActions.Execute then
                    RD.MenuActions:Execute("ResetRoleAssignment", {role = item.name, button = button})
                end
            end)
            
            -- Ajustar ancho del botón principal
            button:SetWidth(LABEL_WIDTH - BUTTON_SIZE - 5)
        end
    end
    
    -- Crear barra de botones si se especifica
    if barItems and #barItems > 0 then
        local buttonBar = CreateFrame("Frame", nil, menu)
        local totalWidth = (#barItems * BUTTON_SIZE) + ((#barItems - 1) * BUTTON_MARGIN)
        buttonBar:SetPoint("BOTTOM", 0, 0)
        buttonBar:SetSize(totalWidth, BUTTON_SIZE)
        
        for i, barItem in ipairs(barItems) do
            local button = CreateFrame("Button", nil, buttonBar, "UIPanelButtonTemplate")
            button:SetSize(BUTTON_SIZE, BUTTON_SIZE)
            button:SetPoint("LEFT", (i - 1) * (BUTTON_SIZE + BUTTON_MARGIN), 0)
            
            if barItem.icon then
                local texture = button:CreateTexture()
                texture:SetAllPoints()
                texture:SetTexture(barItem.icon)
                button:SetNormalTexture(texture)
            end
            
            button:SetScript("OnClick", function(self, btn)
                if RD.MenuActions and RD.MenuActions.Execute then
                    RD.MenuActions:Execute(barItem.action or "DefaultAction", {button = btn, item = barItem})
                end
            end)
            
            -- Tooltip para botones de la barra
            if barItem.tooltip then
                button:SetScript("OnEnter", function(self)
                    GameTooltip:SetOwner(self, "ANCHOR_TOP")
                    GameTooltip:SetText(barItem.tooltip, 1, 1, 1, 1, true)
                    GameTooltip:Show()
                end)
                
                button:SetScript("OnLeave", function()
                    GameTooltip:Hide()
                end)
            end
        end
    end
    
    return menu, menuWidth, menuHeight
end

-- Registrar el módulo
RD.UI = RD.UI or {}
RD.UI.MenuFactory = MenuFactory

return MenuFactory
