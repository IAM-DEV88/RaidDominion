--[[
    RD_UI_ConfigWindow_Render.lua
    PROPÓSITO: Parte del render de la ventana de configuración (RD_UI_ConfigWindow)
              separada en archivo propio para cumplir el límite de ~700 líneas.
              Contiene el despacho de campos a widgets (CreateFieldWidget), los
              helpers de layout del render (AnchorButton, ClearContent,
              MeasureReadonlyText) y los métodos ReapplyHeight / Render sobre la
              tabla RD.ui.configWindow (definida en RD_UI_ConfigWindow.lua).
    API PÚBLICA:
        - RD.ui.configWindow:ReapplyHeight()
        - RD.ui.configWindow:Render()
    EVENTOS: Lo invoca la ventana (Create / CONFIG_RESET / CONFIG_CHANGED).
]]

local addonName, private = ...
local RD = _G.RaidDominion or {}
_G.RaidDominion = RD

local ConfigWindow = RD.ui and RD.ui.configWindow
if not ConfigWindow then
    ConfigWindow = {}
    RD.ui = RD.ui or {}
    RD.ui.configWindow = ConfigWindow
end

-- Constantes de geometría (mismos valores que RD_UI_ConfigWindow.lua)
local CONTENT_WIDTH = 440
local PANEL_PAD = 12
local SIDE_PADDING = 8
local BOTTOM_PADDING = 12
local CONTENT_TOP = -72
local ROW_HEIGHT = 24
local ROW_SPACING = 8
local SECTION_TITLE_HEIGHT = 20
local MAX_BODY_HEIGHT = 520
local GOLD_R, GOLD_G, GOLD_B = unpack((RD.constants and RD.constants.COLORS and RD.constants.COLORS.GOLD) or { 1, 0.82, 0 })

local function CreateFieldWidget(row, field)
    local widgets = RD.ui and RD.ui.widgets
    if not widgets then return nil end

    local fieldType = field.type or "text"
    if fieldType == "checkbox" then
        return widgets:CreateCheckbox(row, field, nil)
    elseif fieldType == "slider" then
        return widgets:CreateSlider(row, field, nil)
    elseif fieldType == "dropdown" then
        return widgets:CreateDropdown(row, field, nil)
    elseif fieldType == "text" or fieldType == "textbox" then
        return widgets:CreateTextbox(row, field, nil)
    elseif fieldType == "button" then
        return widgets:CreateButton(row, field, nil)
    elseif fieldType == "buttons" then
        return widgets:CreateButtons(row, field, nil)
    elseif fieldType == "list" then
        return widgets:CreateList(row, field, nil)
    elseif fieldType == "contentList" then
        return widgets:CreateContentList(row, field, nil)
    elseif fieldType == "bands" then
        return widgets:CreateBands(row, field, nil)
    elseif fieldType == "color" then
        return widgets:CreateColor(row, field, nil)
    elseif fieldType == "helpAccordion" then
        return widgets:CreateHelpAccordion(row, field)
    end

    -- Tipo de campo sin widget: reportar en lugar de improvisar.
    if RD.messageManager and RD.messageManager.SendSystemMessage then
        RD.messageManager:SendSystemMessage(
            "|cffff0000[RaidDominion]|r Campo de configuración sin widget: " .. tostring(field.key or fieldType))
    end
    return nil
end

-- CreateButton no ancla el botón: se ancla a la derecha de la fila y se
-- autodimensiona al ancho del texto (regla 6.4 de AGENTS.md).
local function AnchorButton(button, row)
    if not button or not row then return end
    local layout = RD.ui and RD.ui.layout
    local textW = 0
    local fs = button:GetFontString()
    if fs and fs.GetStringWidth then
        textW = fs:GetStringWidth() or 0
    end
    local width = math.max(140, (layout and layout.Snap(textW + 24)) or (textW + 24))
    button:SetWidth(width)
    button:SetPoint("RIGHT", row, "RIGHT", 0, 0)
end

-- Limpia el contenido previo. content.rows solo contiene FRAMES (filas y
-- cabeceras de sección); sobre FontStrings NO se puede SetParent(nil) en 3.3.5a.
local function ClearContent(content)
    if not content then return end
    if GameTooltip and GameTooltip.Hide then GameTooltip:Hide() end
    local rows = content.rows or {}
    for _, child in ipairs(rows) do
        child:Hide()
        child:SetParent(nil)
    end
    content.rows = {}
end

-- FontString de medida oculto: el alto envuelto del texto readonly se mide de
-- forma fiable (GetStringHeight del widget puede subestimar antes del layout),
-- evitando que el texto se desborde de su fila al hacer scroll. `width` es el
-- ancho real del campo (fieldW - 4), determinista. La fila queda con un margen
-- mínimo (2px) por debajo del texto para no inflar el contenido de la ayuda.
local measureTextFS = nil
local function MeasureReadonlyText(text, width)
    if not text or not text.GetText then return ROW_HEIGHT end
    if not measureTextFS then
        local holder = CreateFrame("Frame", nil, UIParent)
        holder:Hide()
        measureTextFS = holder:CreateFontString(nil, "ARTWORK")
    end
    local font, size = text:GetFont()
    if font and size then measureTextFS:SetFont(font, size) end
    measureTextFS:SetWordWrap(true)
    measureTextFS:SetJustifyH("LEFT")
    measureTextFS:SetWidth(math.max(120, width or 400))
    measureTextFS:SetText(text:GetText() or "")
    local h = measureTextFS:GetStringHeight() or 0
    -- Validación: si la medición es 0 o menor que una línea (FS no layoutado),
    -- se estima por número de líneas (helper central en RD.UIUtils).
    local lineHeight = (size or 14) * 1.2
    if h < lineHeight then
        local str = measureTextFS:GetText() or ""
        local estLines = RD.UIUtils.EstimateWrappedLines(str, width or 400, size or 14)
        h = estLines * lineHeight
    end
    return math.max(ROW_HEIGHT, math.floor(h) + 2)
end

function ConfigWindow:ReapplyHeight()
    if not self.frame or not self.content or not self.scroll then return end
    local layout = RD.ui and RD.ui.layout
    local contentWidth = math.max(CONTENT_WIDTH + 2 * PANEL_PAD, self.tabsWidth or 0)
    local colY = -PANEL_PAD
    for _, row in ipairs(self.content.rows or {}) do
        local h = (row.GetHeight and row:GetHeight()) or ROW_HEIGHT
        if h < 1 then h = ROW_HEIGHT end
        if layout and layout.Snap then
            colY = layout.Snap(colY - math.floor(h) - ROW_SPACING)
        else
            colY = colY - math.floor(h) - ROW_SPACING
        end
    end
    local innerHeight = -colY - PANEL_PAD
    local bodyH = innerHeight + 2 * PANEL_PAD
    self.content:SetSize(contentWidth, bodyH)
    local viewH = math.min(MAX_BODY_HEIGHT, bodyH)
    self.scroll:SetHeight(viewH)
    if self.scroll.UpdateScrollChildRect then
        self.scroll:UpdateScrollChildRect()
    end
    self.frame:SetSize(contentWidth + 2 * SIDE_PADDING,
        -CONTENT_TOP + viewH + BOTTOM_PADDING)
    if RD.UIUtils and RD.UIUtils.ClampModalToScreen then
        RD.UIUtils.ClampModalToScreen(self.frame, self.scroll, 16)
    end
    -- Mismo estado final que Render: si el contenido cabe, re-afirma el viewport,
    -- fuerza la barra a rango 0, resetea el scroll y oculta la barra.
    if self.scroll and bodyH <= MAX_BODY_HEIGHT then
        self.scroll:SetHeight(bodyH)
        if self.scroll.UpdateScrollChildRect then
            self.scroll:UpdateScrollChildRect()
        end
        if self.scroll.SetVerticalScroll then
            self.scroll:SetVerticalScroll(0)
        end
        if self.scroll.scrollBar then
            self.scroll.scrollBar:SetMinMaxValues(0, 0)
            self.scroll.scrollBar:SetValue(0)
            self.scroll.scrollBar:Hide()
        end
    end
end

function ConfigWindow:Render()
    if not self.frame or not self.content then return end

    local layout = RD.ui and RD.ui.layout
    if not layout then return end
    local content = self.content
    ClearContent(content)

    local schema = (RD.constants and RD.constants.CONFIG_SCHEMA) or {}
    -- El tab activo se resuelve desde self.tabs (que respeta el orden por `order`),
    -- no indexando el esquema original, para no desincronizarse si el orden cambia.
    local tab = self.tabs[self.currentTab] and self.tabs[self.currentTab].schema
    if not tab then
        self.currentTab = 1
        tab = schema[1]
    end
    if not tab or not tab.sections then
        content:SetSize(math.max(CONTENT_WIDTH + 2 * PANEL_PAD, self.tabsWidth or 0), 2 * PANEL_PAD)
        return
    end

    -- El contenido aprovecha el ancho disponible del marco. TODOS los campos
    -- (normales y editores de lista) se centran en un bloque que ocupa el 80%
    -- del ancho usable del panel (márgenes simétricos ~10% a cada lado), de
    -- modo que queden bien ubicados y sin pegarse a los bordes ni a la barra.
    local contentWidth = math.max(CONTENT_WIDTH + 2 * PANEL_PAD, self.tabsWidth or 0)
    local availW = math.max(340, contentWidth - 2 * PANEL_PAD)
    -- El contenido aprovecha el 95% del ancho usable del panel en todas las
    -- pestañas (antes 80%), centrado con márgenes simétricos.
    local fieldW = math.floor(availW * 0.95)
    local fieldX = math.max(PANEL_PAD, math.floor((contentWidth - fieldW) / 2))

    -- Tabs compactos (p.ej. Ayuda): se reduce el espaciado entre filas y el alto
    -- de las cabeceras de sección para acortar el contenido/scroll (~80px).
    local isCompact = tab.compact or tab.id == "help"
    local spacing = isCompact and 4 or ROW_SPACING
    local sectionH = isCompact and 16 or SECTION_TITLE_HEIGHT
    local col = layout:Column(content, PANEL_PAD, -PANEL_PAD, fieldW, spacing)
    local sections = (ConfigWindow.SortByOrder and ConfigWindow.SortByOrder(tab.sections)) or {}

    for _, section in ipairs(sections) do
        -- Cabecera de sección (se omite si el título está vacío; en 3.3.5a no
        -- se puede SetParent(nil) sobre un FontString, por eso se envuelve).
        if section.title and section.title ~= "" then
            local header = CreateFrame("Frame", nil, content)
            header:SetSize(fieldW, sectionH)
            local sectionTitle = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            sectionTitle:SetText(section.title or "")
            sectionTitle:SetTextColor(GOLD_R, GOLD_G, GOLD_B)
            sectionTitle:SetJustifyH("LEFT")
            sectionTitle:SetPoint("TOPLEFT", header, "TOPLEFT", 0, 0)
            RD.UIUtils.ScaleFont(sectionTitle, 1.5)
            -- Línea separadora sutil bajo el título de sección
            local titleLine = header:CreateTexture(nil, "ARTWORK")
            titleLine:SetPoint("TOPLEFT", header, "TOPLEFT", 0, -sectionH + 2)
            titleLine:SetPoint("TOPRIGHT", header, "TOPRIGHT", 0, -sectionH + 2)
            titleLine:SetHeight(1)
            titleLine:SetTexture(1, 1, 1, 0.1)
            local usedY = col:Place(header, sectionH)
            header:ClearAllPoints()
            header:SetPoint("TOPLEFT", content, "TOPLEFT", fieldX, usedY)
            table.insert(content.rows, header)
        end

        -- Campos de la sección. Cada campo se construye de forma resiliente: si
        -- un widget falla, el render continúa y el sizing final se calcula igual
        -- (evita que un fallo a mitad deje el frame/scroll con tamaños de otro tab).
        for _, field in ipairs(section.fields or {}) do
            -- La row se crea FUERA del pcall para poder limpiarla si el widget
            -- falla (evita frames huérfanos) y para reportar el error sin abortar.
            local row = CreateFrame("Frame", nil, content)
            row:SetSize(fieldW, ROW_HEIGHT)
            local okField = pcall(function()
            local isList = (field.type == "list") or (field.type == "contentList") or (field.type == "bands") or (field.type == "helpAccordion")

            local widget = CreateFieldWidget(row, field)

            -- Hover sutil + tooltip de ayuda en filas de campos normales. El
            -- hover/tooltip se propaga a los controles del widget (checkbox,
            -- slider, botón...) para cubrir todo el elemento. Los editores de
            -- lista no muestran tooltip en la fila (solo sus botones principales)
            -- y las filas de varios botones ("buttons") usan tooltips propios por
            -- botón (no se pisan con el de la fila).
            if not isList and field.type ~= "buttons" and RD.UIUtils and RD.UIUtils.AddRowHover then
                local targets = widget and widget.rdHoverTargets
                RD.UIUtils.AddRowHover(row, function() return field.help end, targets)
            end

            -- El widget de botón no ancla su control: se ancla a la derecha
            if field.type == "button" then
                AnchorButton(widget, row)
            end

            -- Texto informativo readonly: alto ajustado al contenido (medición
            -- fiable para que el texto no se desborde al hacer scroll) y clip
            -- por fila como red de seguridad.
            local rowH = ROW_HEIGHT
            if (field.type == "text" or field.type == "textbox") and field.readonly and widget then
                if row.EnableClipsChildren then
                    row:EnableClipsChildren(true)
                end
                rowH = MeasureReadonlyText(widget, fieldW - 4)
            elseif field.type == "list" or field.type == "contentList" or field.type == "bands" or field.type == "helpAccordion" then
                -- Los editores de lista y el acordeón de ayuda fijan su propio
                -- alto según el contenido (el widget hace parent:SetHeight).
                rowH = row:GetHeight() or field.height or 200
            end

            local usedY = col:Place(row, rowH)
            -- Re-anclar: todo el contenido centrado en el bloque (padding simétrico)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", content, "TOPLEFT", fieldX, usedY)
            table.insert(content.rows, row)
            end)
            if not okField then
                -- Limpia la row huérfana y reporta el fallo (sin abortar el render)
                row:Hide()
                row:SetParent(nil)
                if RD.messageManager and RD.messageManager.SendSystemMessage then
                    RD.messageManager:SendSystemMessage(
                        "|cffff8000[RaidDominion]|r No se pudo mostrar el campo '" .. tostring(field.key or field.label or field.type) .. "'.")
                end
            end
        end
    end

    -- Dimensiones finales (enteros, múltiplos del grid); el cursor empezó en
    -- -PANEL_PAD y baja, así que el alto interior es -col.y - PANEL_PAD.
    local innerHeight = -col.y - PANEL_PAD
    local bodyH = innerHeight + 2 * PANEL_PAD
    content:SetSize(contentWidth, bodyH)
    local viewH = math.min(MAX_BODY_HEIGHT, bodyH)
    if self.scroll then
        self.scroll:SetHeight(viewH)
        if self.scroll.UpdateScrollChildRect then
            self.scroll:UpdateScrollChildRect()
        end
    end
    self.frame:SetSize(contentWidth + 2 * SIDE_PADDING,
        -CONTENT_TOP + viewH + BOTTOM_PADDING)

    -- Alto máximo global: si la ventana no cabe en pantalla, se recorta el
    -- viewport (que sigue scrolleando) en lugar de salirse de la pantalla.
    if self.scroll and RD.UIUtils and RD.UIUtils.ClampModalToScreen then
        RD.UIUtils.ClampModalToScreen(self.frame, self.scroll, 16)
    elseif layout.EnsureVisible then
        layout:EnsureVisible(self.frame, 8)
    end

    -- Estado final del scroll tras reconstruir y redimensionar. Tras pasar de un
    -- tab largo (Ayuda) a uno corto (General), la barra o el rango del tab
    -- anterior podían quedar visibles/activos si OnScrollRangeChanged no se
    -- disparaba o si ClampModalToScreen (del tab largo) dejó el viewport recortado:
    -- cuando el contenido cabe (bodyH <= MAX_BODY_HEIGHT) se re-afirma el viewport,
    -- se fuerza la barra a rango 0 (la rueda no scrollea), se resetea el offset y
    -- se oculta la barra.
    if self.scroll and bodyH <= MAX_BODY_HEIGHT then
        self.scroll:SetHeight(bodyH)
        if self.scroll.UpdateScrollChildRect then
            self.scroll:UpdateScrollChildRect()
        end
        if self.scroll.SetVerticalScroll then
            self.scroll:SetVerticalScroll(0)
        end
        if self.scroll.scrollBar then
            self.scroll.scrollBar:SetMinMaxValues(0, 0)
            self.scroll.scrollBar:SetValue(0)
            self.scroll.scrollBar:Hide()
        end
    end
end

-- Registro explícito e idempotente: la tabla debe ser SIEMPRE la misma que la
-- del archivo principal (RD_UI_ConfigWindow.lua), por si este archivo se cargó
-- antes de que aquél registrara su tabla (fallback de identidad).
RD.ui = RD.ui or {}
RD.ui.configWindow = ConfigWindow

return ConfigWindow
