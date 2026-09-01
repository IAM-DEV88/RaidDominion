--[[
    RD_UI_ConfigWindow.lua
    PROPÓSITO: Ventana de configuración vinculada al menú flotante. Se renderiza
              dinámicamente a partir de RD.constants.CONFIG_SCHEMA y del valor
              seteado actual en RD.config. No hay UI hardcodeada por pestaña.
              Estilo heredado y mejorado de la v2 (RD_UI_ConfigManager):
              pestañas con texturas de personaje, panel de contenido oscuro,
              barra de título arrastrable, botón de cerrar y posición persistente.
    API PÚBLICA:
        - RD.ui.configWindow:Create()
        - RD.ui.configWindow:Show() / Hide() / Toggle()
        - RD.ui.configWindow:Render()
        - RD.ui.configWindow:SelectTab(index)
        - RD.ui.configWindow:SelectTabById(id)
    EVENTOS: Publica CONFIG_WINDOW_SHOWN, CONFIG_WINDOW_HIDDEN;
             reacciona a CONFIG_RESET (re-render) y registra de forma defensiva
             las acciones "ToggleConfig" y "ResetConfig" en RD.MenuActions.
]]

local addonName, private = ...
local RD = _G.RaidDominion or {}
_G.RaidDominion = RD

local ConfigWindow = {
    frame = nil,
    content = nil,
    tabs = {},
    currentTab = 1,
    isShown = false,
    positioned = false,
}

-- Constantes de geometría (enteros, múltiplos del grid 4px)
local CONTENT_WIDTH = 440        -- ancho MÍNIMO del contenido (las filas aprovechan el ancho real)
local PANEL_PAD = 12           -- padding interior del panel de contenido
local SIDE_PADDING = 8           -- padding lateral del frame (8 + 8)
local BOTTOM_PADDING = 12        -- padding inferior del frame
local CONTENT_TOP = -72          -- offset Y del contenedor respecto al frame
local TAB_TEXT_PAD = 4           -- padding horizontal (4px a cada lado) del texto en el chip
local TAB_MIN_WIDTH = 44         -- ancho mínimo de pestaña
local TAB_HEIGHT = 32            -- alto de pestaña estilo personaje (v2)
local TAB_GAP = 1                -- gap entre pestañas (reducido para evitar desborde)
local TAB_ROW_MARGIN = 12        -- margen derecho de reserva (compensa el redondeo del grid)
local TAB_ROW_Y = -34            -- offset Y de la fila de pestañas
local MAX_BODY_HEIGHT = 520      -- alto máximo del cuerpo de la config (si lo supera, scrollea)
local GOLD_R, GOLD_G, GOLD_B = unpack((RD.constants and RD.constants.COLORS and RD.constants.COLORS.GOLD) or { 1, 0.82, 0 })

-- Nombre único para frames con template (los templates crean hijos con $parent).
-- Se delega en el contador ÚNICO de RD.UIUtils para evitar colisiones entre archivos.
local UniqueName = RD.UIUtils and RD.UIUtils.UniqueName

-- Render/ReapplyHeight viven en RD_UI_ConfigWindow_Render.lua (adjuntos a la
-- tabla RD.ui.configWindow al cargar, antes de PLAYER_LOGIN). Se invocan con
-- guarda defensiva: si ese archivo no llegó a cargarse (p.ej. .toc viejo), el
-- arranque no debe abortar por un método ausente.
local function CallRender(cw)
    if cw and cw.Render then cw:Render() end
end
local function CallReapply(cw)
    if cw and cw.ReapplyHeight then cw:ReapplyHeight() end
end

-- Orden estable por `order` (helper central en RD.UIUtils.SortByOrder)
local SortByOrder = (RD.UIUtils and RD.UIUtils.SortByOrder) or function(list)
    local sorted = {}
    for _, v in ipairs(list or {}) do table.insert(sorted, v) end
    for i = 2, #sorted do
        local key = sorted[i]
        local keyOrder = key.order or 0
        local j = i - 1
        while j >= 1 and (sorted[j].order or 0) > keyOrder do
            sorted[j + 1] = sorted[j]
            j = j - 1
        end
        sorted[j + 1] = key
    end
    return sorted
end
-- Compartido con RD_UI_ConfigWindow_Render.lua (render de secciones)
ConfigWindow.SortByOrder = SortByOrder

-- Construye una pestaña estilo chip (como las de "Dados"/"Historial" del gestor
-- de botín): fondo oscuro translúcido, borde dorado y texto dorado centrado,
-- con el highlight en hover del chip. El ancho se ajusta al texto de la pestaña
-- (mínimo TAB_MIN_WIDTH). La pestaña activa se resalta con PaintTabButton.
local function BuildTab(container, index, tab, self)
    local btn = RD.UIUtils.MakeChipButton(container, nil, TAB_MIN_WIDTH, TAB_HEIGHT)
    btn:SetText(tab.title or "")

    -- Ancho ajustado al texto (texto + padding)
    local text = btn:GetFontString()
    local textW = (text and text.GetStringWidth and (text:GetStringWidth() or 0)) or 0
    local w = math.max(TAB_MIN_WIDTH, textW + 2 * TAB_TEXT_PAD)
    btn:SetSize(w, TAB_HEIGHT)
    btn.rdTabWidth = w

    btn:SetScript("OnClick", function()
        self:SelectTab(index)
    end)

    return { button = btn, text = text }
end

-- Repinta el estado visual de las pestañas chip (activa resaltada en dorado,
-- resto tenue). El texto de la activa va dorado y el de las inactivas gris.
local function PaintTabs(self)
    for i, tab in ipairs(self.tabs) do
        local active = (i == self.currentTab)
        if tab and tab.button and RD.UIUtils and RD.UIUtils.PaintTabButton then
            RD.UIUtils.PaintTabButton(tab.button, active)
        end
        if tab and tab.text then
            if active then
                tab.text:SetTextColor(GOLD_R, GOLD_G, GOLD_B)
            else
                tab.text:SetTextColor(0.8, 0.8, 0.8)
            end
        end
    end
end

function ConfigWindow:Create()
    if self.frame then return self.frame end

    local layout = RD.ui and RD.ui.layout
    if not layout then return nil end

    -- Acciones vinculadas al menú flotante y al botón de reset del esquema.
    -- (Las acciones "ToggleConfig"/"ResetConfig" las registra RD_MenuActions,
    -- única fuente de verdad; no re-registrar aquí para evitar doble handler.)

    local frame = CreateFrame("Frame", "RaidDominionConfig", UIParent)
    frame:SetFrameStrata("HIGH")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)

    -- Arrastre de toda la ventana (como la v2): se arrastra desde cualquier
    -- zona no interactiva (barra de título, fondo, padding). Los widgets hijos
    -- (pestañas, checkboxes, sliders, botones) capturan su propio clic.
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function()
        frame:StartMoving()
    end)
    frame:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
    end)

    -- Clic sobre la ventana la sube al frente (ventanas del addon)
    if RD.UIUtils and RD.UIUtils.MakeClickToTop then
        RD.UIUtils.MakeClickToTop(frame)
    end

    -- Escala de la interfaz (general.scale) aplicada al frame raíz
    if RD.UIUtils and RD.UIUtils.TrackScale then
        RD.UIUtils.TrackScale(frame)
    else
        local scaleValue = RD.config and RD.config.Get and RD.config:Get("general.scale", 1.0) or 1.0
        if type(scaleValue) == "number" and scaleValue > 0 then
            frame:SetScale(scaleValue)
        end
    end

    -- Backdrop estilo dialog coherente con el menú flotante
    frame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    frame:SetBackdropColor(0, 0, 0, 0.9)
    frame:SetBackdropBorderColor(1, 1, 1, 0.5)

    -- Franja del título: banda oscura casi a todo lo ancho con línea dorada de
    -- acento inferior. Se reduce 2px por lado y 2px desde el borde superior
    -- para que no asomen los "picos" de las esquinas redondeadas del frame.
    local titleBg = CreateFrame("Frame", nil, frame)
    titleBg:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -2)
    titleBg:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2)
    titleBg:SetHeight(28)
    titleBg:SetFrameLevel(frame:GetFrameLevel())
    titleBg:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        tile = true, tileSize = 16,
    })
    titleBg:SetBackdropColor(0.06, 0.06, 0.06, 0.9)
    local titleLine = titleBg:CreateTexture(nil, "ARTWORK")
    titleLine:SetPoint("BOTTOMLEFT", titleBg, "BOTTOMLEFT", 0, 0)
    titleLine:SetPoint("BOTTOMRIGHT", titleBg, "BOTTOMRIGHT", 0, 0)
    titleLine:SetHeight(2)
    titleLine:SetTexture(GOLD_R, GOLD_G, GOLD_B, 0.6)

    -- Título (jerarquía: título de ventana, el más prominente)
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetText("Configuración — RaidDominion")
    title:SetTextColor(GOLD_R, GOLD_G, GOLD_B)
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -5)
    RD.UIUtils.ScaleFont(title, 1.25)

    -- Botón de cerrar (ESC también cierra vía UISpecialFrames)
    local closeButton = CreateFrame("Button", UniqueName("Cl"), frame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, 1)
    closeButton:SetFrameLevel(frame:GetFrameLevel() + 10)
    closeButton:SetScript("OnClick", function()
        self:Hide()
    end)
    table.insert(UISpecialFrames, "RaidDominionConfig")

    -- Barra de pestañas bajo el título. Se construyen todas las pills (con su
    -- padding horizontal de 4px ya incluido en el ancho), se toma como ancho
    -- mínimo el de la pill más ancha y todas quedan con ese mismo ancho.
    self.tabs = {}
    local tabRow = layout:Row(frame, 8, TAB_ROW_Y, TAB_HEIGHT, TAB_GAP)
    local schema = (RD.constants and RD.constants.CONFIG_SCHEMA) or {}
    local sortedTabs = SortByOrder(schema)
    local maxW = 0
    for i, tab in ipairs(sortedTabs) do
        local tabData = BuildTab(frame, i, tab, self)
        local w = tabData.button.rdTabWidth or TAB_MIN_WIDTH
        tabData.id = tab.id
        tabData.schema = tab
        self.tabs[i] = tabData
        if w > maxW then maxW = w end
    end
    -- Ancho mínimo uniforme = el de la pill más grande (todas igual de anchas).
    local tabsW = maxW * #self.tabs
    for _, tabData in ipairs(self.tabs) do
        tabData.button.rdTabWidth = maxW
        tabRow:Place(tabData.button, maxW)
    end
    -- Margen derecho de reserva: el Row:Place redondea a múltiplos del grid, lo
    -- que añade unos px de más; TAB_ROW_MARGIN evita que la última pestaña
    -- desborde el borde derecho del frame.
    tabsW = tabsW + math.max(0, #self.tabs - 1) * TAB_GAP + TAB_ROW_MARGIN
    self.tabsWidth = tabsW

    -- Línea separadora sutil bajo las pestañas (sobre el panel de contenido)
    local tabLine = frame:CreateTexture(nil, "ARTWORK")
    tabLine:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, TAB_ROW_Y - TAB_HEIGHT - 3)
    tabLine:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, TAB_ROW_Y - TAB_HEIGHT - 3)
    tabLine:SetHeight(1)
    tabLine:SetTexture(1, 1, 1, 0.12)

    -- Contenedor del cuerpo: ScrollFrame con panel oscuro y alto máximo.
    -- Si el contenido supera MAX_BODY_HEIGHT, el viewport scrollea (barra + rueda).
    local contentWidth = math.max(CONTENT_WIDTH + 2 * PANEL_PAD, self.tabsWidth or 0)
    local createScroll = RD.ui and RD.ui.widgets and RD.ui.widgets.CreateScrollFrame
    local scroll, content
    if createScroll then
        scroll, content = createScroll(frame, contentWidth, 200, SIDE_PADDING, CONTENT_TOP)
        content:SetWidth(contentWidth)
        -- La barra de scroll queda DENTRO del panel (borde derecho), con un
        -- pequeño inset para que no se salga del marco; se estira al alto del
        -- viewport (el padding simétrico de las filas le deja sitio).
        if scroll and scroll.scrollBar then
            local bar = scroll.scrollBar
            bar:ClearAllPoints()
            -- La barra coincide con el bloque de contenido (PANEL_PAD=12 arriba
            -- y abajo), no con todo el viewport: así no se ve más alta que él.
            bar:SetPoint("TOPRIGHT", scroll, "TOPRIGHT", -4, -12)
            bar:SetPoint("BOTTOMRIGHT", scroll, "BOTTOMRIGHT", -4, 12)
        end
        scroll:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        scroll:SetBackdropColor(0.09, 0.09, 0.09, 0.72)
        scroll:SetBackdropBorderColor(0.55, 0.55, 0.55, 0.6)
    else
        content = CreateFrame("Frame", nil, frame)
        content:SetPoint("TOPLEFT", frame, "TOPLEFT", SIDE_PADDING, CONTENT_TOP)
        content:SetSize(contentWidth, 200)
    end
    content.rows = {}
    self.content = content
    self.scroll = scroll
    self.frame = frame

    -- Frame de debounce para re-ajustar la altura cuando cambia el contenido de
    -- un editor de lista/bandas (p.ej. "Añadir banda"): el editor crece tras
    -- BuildRows, así que se re-aplica la altura un instante después (sin recrear
    -- widgets, sin perder el foco).
    local reapplyFrame = CreateFrame("Frame")
    reapplyFrame:Hide()
    reapplyFrame:SetScript("OnUpdate", function(f, elapsed)
        f.rdElapsed = (f.rdElapsed or 0) + elapsed
        if f.rdElapsed >= (f.rdDelay or 0.1) then
            f:Hide()
            f.rdElapsed = 0
            CallReapply(self)
        end
    end)
    self.reapplyFrame = reapplyFrame
    local function QueueReapply()
        if self.isShown and self.reapplyFrame then
            self.reapplyFrame.rdElapsed = 0
            self.reapplyFrame:Show()
        end
    end

    -- Re-render al restablecer la configuración por defecto; re-ajuste de altura
    -- cuando cambia una lista/bandas del tab activo.
    if RD.events and RD.events.Subscribe then
        RD.events:Subscribe("CONFIG_RESET", function()
            CallRender(self)
        end)
        RD.events:Subscribe("CONFIG_CHANGED", function(key)
            if not key then return end
            local listKeys = { roles = true, abilities = true, buffs = true,
                auras = true, mechanics = true, rules = true, bands = true }
            if not listKeys[key] then return end
            -- Solo se re-aplica si el TAB ACTIVO contiene un campo con esa clave
            -- (evita encoger p.ej. el tab Ayuda si cambia una lista estando en él).
            local tab = self.tabs and self.tabs[self.currentTab] and self.tabs[self.currentTab].schema
            if tab and tab.sections then
                for _, section in ipairs(tab.sections) do
                    for _, field in ipairs(section.fields or {}) do
                        if field.key == key then
                            QueueReapply()
                            return
                        end
                    end
                end
            end
        end)
    end

    -- Tamaño inicial y primer render del tab activo (ancho cubre las pestañas)
    frame:SetSize(contentWidth + 2 * SIDE_PADDING, -CONTENT_TOP + math.min(MAX_BODY_HEIGHT, 260) + BOTTOM_PADDING)
    PaintTabs(self)
    CallRender(self)

    return frame
end

function ConfigWindow:Show()
    if not self.frame then
        self:Create()
    end
    if not self.frame then return end

    -- Re-aplica la escala de la interfaz por si cambió mientras estaba cerrada
    if RD.UIUtils and RD.UIUtils.ApplyScale then
        RD.UIUtils.ApplyScale(self.frame)
    end

    -- Posición: "menu" ancla la ventana junto al menú flotante; "screen" centra
    -- la primera vez y luego conserva la posición (arrastrable).
    local position = "screen"
    if RD.config and RD.config.Get then
        position = RD.config:Get("ui.config.position", "screen")
    end

    local menuFrame = RD.ui and RD.ui.menuFrame
    if position == "menu" and menuFrame and menuFrame.frame and menuFrame.isShown then
        self.frame:ClearAllPoints()
        self.frame:SetPoint("TOPLEFT", menuFrame.frame, "TOPRIGHT", 8, 0)
    elseif not self.positioned then
        self.frame:ClearAllPoints()
        self.frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        self.positioned = true
    end

    local layout = RD.ui and RD.ui.layout
    if layout and layout.EnsureVisible then
        layout:EnsureVisible(self.frame, 8)
    end

    self.frame:Raise()
    self.frame:Show()
    self.isShown = true
    if RD.events and RD.events.Publish then
        RD.events:Publish("CONFIG_WINDOW_SHOWN")
    end
end

function ConfigWindow:Hide()
    if not self.frame then return end
    self.frame:Hide()
    self.isShown = false
    if RD.events and RD.events.Publish then
        RD.events:Publish("CONFIG_WINDOW_HIDDEN")
    end
end

function ConfigWindow:Toggle()
    if self.isShown then
        self:Hide()
    else
        self:Show()
    end
end

function ConfigWindow:SelectTab(index)
    if not self.tabs or not self.tabs[index] then return end
    self.currentTab = index
    CallRender(self)
    PaintTabs(self)
end

-- Busca un tab por su id en el esquema (lo usa la acción "ShowHelp" del menú)
function ConfigWindow:SelectTabById(id)
    if not id then return end
    for i, tab in ipairs(self.tabs) do
        if tab.id == id then
            self:SelectTab(i)
            return
        end
    end
end

RD.ui = RD.ui or {}
-- Simétrico ante reorden del .toc: si RD_UI_ConfigWindow_Render.lua cargó primero
-- (tabla con Render/ReapplyHeight), se fusionan sus métodos en esta tabla.
if RD.ui.configWindow then
    for k, v in pairs(RD.ui.configWindow) do
        if ConfigWindow[k] == nil then ConfigWindow[k] = v end
    end
end
RD.ui.configWindow = ConfigWindow
return ConfigWindow
