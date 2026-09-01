--[[
    RD_UI_Widgets_List.lua
    PROPÓSITO: Editor de listas configurables (CreateList) + selector de iconos
              en cuadrícula estilo WoW con recogida de iconos del juego.
              Vive en un archivo aparte para mantener RD_UI_Widgets.lua
              dentro del límite de ~700 líneas. Registra RD.ui.widgets:CreateList.
    API PÚBLICA:
        - RD.ui.widgets:CreateList(parent, field, onChange)
    EVENTOS: Ninguno. Escribe vía RD.config:Set (dispara CONFIG_CHANGED).
]]

local addonName, private = ...
local RD = _G.RaidDominion or {}
_G.RaidDominion = RD

RD.ui = RD.ui or {}
local Widgets = RD.ui.widgets
if not Widgets then
    Widgets = {}
    RD.ui.widgets = Widgets
end

local UniqueName = Widgets.UniqueName
local GetValue = Widgets.GetValue
local SetValue = Widgets.SetValue
local EnableTabNavigation = RD.UIUtils and RD.UIUtils.EnableTabNavigation

local DEFAULT_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"

-- =============================================
-- SCROLL FRAME CON BARRA PERSONALIZADA
-- La barra se ancla a la DERECHA del scroll, junto al contenido (no en el
-- borde de un área vacía), con margen controlado y rueda del ratón.
-- =============================================

local function CreateScrollFrame(parent, width, height, x, y)
    local scroll = CreateFrame("ScrollFrame", UniqueName("Scr"), parent)
    scroll:SetSize(width, height)
    scroll:SetPoint("TOPLEFT", parent, "TOPLEFT", x or 0, y or 0)
    scroll:EnableMouseWheel(true)

    local child = CreateFrame("Frame", nil, scroll)
    child:SetWidth(width)
    scroll:SetScrollChild(child)

    local bar = CreateFrame("Slider", UniqueName("Bar"), parent, "UIPanelScrollBarTemplate")
    bar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 4, -8)
    bar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 4, 8)

    -- `syncing` evita retroalimentación y errores durante la inicialización:
    -- Slider:SetValue dispara OnValueChanged aunque se llame al crear la barra.
    local syncing = true
    bar:SetScript("OnValueChanged", function(self, value)
        if not syncing and scroll and scroll.SetVerticalScroll then
            scroll:SetVerticalScroll(value)
        end
    end)
    scroll:SetScript("OnVerticalScroll", function(self, offset)
        syncing = true
        self.scrollBar:SetValue(offset)
        syncing = false
    end)
    scroll:SetScript("OnScrollRangeChanged", function(self, xrange, yrange)
        local b = self.scrollBar
        if yrange <= 0 then
            b:Hide()
        else
            b:Show()
            b:SetMinMaxValues(0, yrange)
            b:SetValueStep(math.max(1, yrange / 16))
        end
    end)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local b = self.scrollBar
        local _, max = b:GetMinMaxValues()
        local val = self:GetVerticalScroll() - delta * 16
        if val < 0 then val = 0 end
        if val > max then val = max end
        if self.SetVerticalScroll then
            self:SetVerticalScroll(val)
        end
    end)

    scroll.scrollBar = bar
    bar:SetMinMaxValues(0, 0)
    bar:SetValueStep(1)
    bar:SetValue(0)
    bar:Hide()
    syncing = false

    return scroll, child
end

-- =============================================
-- SELECTOR DE ICONOS (cuadrícula estilo WoW)
-- Recoge los iconos del juego (GetSpellInfo sobre los IDs de hechizo) y los
-- muestra junto a la lista curada, sin que el usuario necesite conocer nombres
-- de texturas.
-- =============================================

local pickerFrame = nil

local ICON_LIST = nil          -- lista completa una vez recogida
local ICON_SEEN = {}           -- dedupe de texturas

-- Paginación del selector: solo se construyen los botones de la página pedida
-- (lazy load a petición). Con ~2000 iconos, crear todos en cada apertura era un
-- golpe de rendimiento; por página se crean ~PAGE_SIZE botones.
local PAGE_SIZE = 100          -- iconos por página
local pickerPage = 1           -- página activa
local totalPages = 1           -- total de páginas

local function CuratedIcons()
    local list = {}
    local curated = (RD.constants and RD.constants.ICON_PICKER_LIST) or {}
    for _, icon in ipairs(curated) do
        if not ICON_SEEN[icon] then
            ICON_SEEN[icon] = true
            list[#list + 1] = icon
        end
    end
    return list
end

-- Recoge los iconos de los hechizos del juego en una sola pasada (sin C_Timer).
-- Se ejecuta una única vez en PLAYER_LOGIN (vía Widgets.CollectIcons) para no
-- congelar la apertura del selector. Usa GetSpellInfo (API 3.3.5a) cuyo tercer
-- valor de retorno es la textura del icono. Se acota el número de iconos únicos
-- para mantener la carga razonable. El icono por defecto (elementos sin imagen)
-- SIEMPRE está primero, para poder re-seleccionar el estado "sin icono".
local function BuildFullIconList()
    if ICON_LIST then return ICON_LIST end
    local list = {}
    if not ICON_SEEN[DEFAULT_ICON] then
        ICON_SEEN[DEFAULT_ICON] = true
        list[#list + 1] = DEFAULT_ICON
    end
    for _, icon in ipairs(CuratedIcons()) do
        list[#list + 1] = icon
    end
    local MAX_ID = 70000
    local MAX_UNIQUE = 2000
    -- Heurística anti-hitche: si ya hay suficientes iconos y se barren muchos IDs
    -- consecutivos sin encontrar uno nuevo (rangos dispersos hacia 70k), se corta.
    local MAX_GAP = 20000
    local MIN_ICONS = 200
    local sinceNew = 0
    for i = 1, MAX_ID do
        local icon = select(3, GetSpellInfo(i))
        if icon and icon ~= "" and not ICON_SEEN[icon] then
            ICON_SEEN[icon] = true
            list[#list + 1] = icon
            sinceNew = 0
            if #list >= MAX_UNIQUE then break end
        else
            sinceNew = sinceNew + 1
            if sinceNew >= MAX_GAP and #list >= MIN_ICONS then break end
        end
    end
    ICON_LIST = list
    return list
end

-- Construye la cuadrícula de botones de la PÁGINA ACTIVA (lazy load por página).
-- Solo se crean los botones de la página actual; al cambiar de página se
-- reconstruye esa página. La lista completa ya está en caché.
local function BuildPickerGrid()
    for _, btn in ipairs(pickerFrame.buttons) do
        btn:Hide()
        btn:SetParent(nil)
    end
    pickerFrame.buttons = {}

    local list = BuildFullIconList()
    totalPages = math.max(1, math.ceil(#list / PAGE_SIZE))
    if pickerPage < 1 then pickerPage = 1 end
    if pickerPage > totalPages then pickerPage = totalPages end

    local cell = 36
    local cols = math.max(4, math.floor((pickerFrame.child:GetWidth() or 412) / cell))
    local currentIcon = pickerFrame.current

    local first = (pickerPage - 1) * PAGE_SIZE + 1
    local last = math.min(#list, first + PAGE_SIZE - 1)
    local n = 0
    for i = first, last do
        local icon = list[i]
        n = n + 1
        local col = (n - 1) % cols
        local row = math.floor((n - 1) / cols)
        local btn = CreateFrame("Button", nil, pickerFrame.child)
        btn:SetSize(32, 32)
        btn:SetPoint("TOPLEFT", pickerFrame.child, "TOPLEFT", col * cell, -row * cell)

        local tex = btn:CreateTexture(nil, "ARTWORK")
        tex:SetAllPoints()
        tex:SetTexture(icon)

        local hl = btn:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
        hl:SetBlendMode("ADD")

        if icon == currentIcon then
            local ring = btn:CreateTexture(nil, "OVERLAY")
            ring:SetAllPoints()
            ring:SetTexture("Interface\\Buttons\\UI-EmptySlot")
            ring:SetVertexColor(1, 0.82, 0, 1)
        end

        btn:SetScript("OnClick", function()
            local cb = pickerFrame and pickerFrame.callback
            pickerFrame:Hide()
            if cb then cb(icon) end
        end)

        pickerFrame.buttons[#pickerFrame.buttons + 1] = btn
    end
    pickerFrame.child:SetHeight(math.ceil(n / cols) * cell)

    -- Navegación de páginas (SetEnabled no existe en 3.3.5a: se usa
    -- SetButtonState, visual; los OnClick ya guardan los límites de página)
    if pickerFrame.pageLabel then
        pickerFrame.pageLabel:SetText(string.format("Página %d / %d", pickerPage, totalPages))
        if pickerFrame.prevBtn.SetButtonState then
            pickerFrame.prevBtn:SetButtonState(pickerPage > 1 and "NORMAL" or "DISABLED")
        end
        if pickerFrame.nextBtn.SetButtonState then
            pickerFrame.nextBtn:SetButtonState(pickerPage < totalPages and "NORMAL" or "DISABLED")
        end
    end
end

-- Abre el selector de iconos junto al frame ancla. callback(iconPath) recibe
-- el path de textura elegido.
local function OpenIconPicker(anchor, callback, current)
    if not anchor or type(callback) ~= "function" then return end

    if not pickerFrame then
        pickerFrame = CreateFrame("Frame", "RDIconPicker", UIParent)
        pickerFrame:SetFrameStrata("HIGH")
        pickerFrame:SetToplevel(true)
        pickerFrame:SetClampedToScreen(true)
        pickerFrame:SetSize(460, 420)
        pickerFrame:EnableMouse(true)

        -- Arrastrable desde cualquier zona no interactiva (título/fondo/espacio
        -- vacío); los botones de la cuadrícula capturan su propio clic.
        pickerFrame:SetMovable(true)
        pickerFrame:RegisterForDrag("LeftButton")
        pickerFrame:SetScript("OnDragStart", function()
            pickerFrame:StartMoving()
        end)
        pickerFrame:SetScript("OnDragStop", function()
            pickerFrame:StopMovingOrSizing()
        end)

        pickerFrame:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 12,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        pickerFrame:SetBackdropColor(0, 0, 0, 0.95)
        pickerFrame:SetBackdropBorderColor(1, 1, 1, 0.5)
        pickerFrame.buttons = {}
        if RD.UIUtils and RD.UIUtils.TrackScale then RD.UIUtils.TrackScale(pickerFrame) end

        -- Fondo modal: clic fuera cierra el selector
        local catcher = CreateFrame("Frame", nil, UIParent)
        catcher:SetFrameStrata("HIGH")
        catcher:SetAllPoints(UIParent)
        catcher:EnableMouse(true)
        catcher:SetScript("OnMouseUp", function()
            if pickerFrame then pickerFrame:Hide() end
        end)
        pickerFrame.catcher = catcher
        pickerFrame:SetScript("OnHide", function()
            if pickerFrame and pickerFrame.catcher then pickerFrame.catcher:Hide() end
            if pickerFrame then pickerFrame.callback = nil end
        end)

        local title = pickerFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        title:SetPoint("TOP", pickerFrame, "TOP", 0, -8)
        title:SetText("Selecciona un icono")

        local closeBtn = CreateFrame("Button", UniqueName("Cl"), pickerFrame, "UIPanelCloseButton")
        closeBtn:SetPoint("TOPRIGHT", pickerFrame, "TOPRIGHT", -4, -4)
        closeBtn:SetScript("OnClick", function()
            pickerFrame:Hide()
        end)

        -- Scroll con barra personalizada a la derecha del contenido (más espacio);
        -- se deja sitio abajo para la navegación de páginas.
        local scroll, child = CreateScrollFrame(pickerFrame, 412, 320, 8, -30)
        pickerFrame.scroll = scroll
        pickerFrame.child = child

        -- Navegación de páginas (lazy load por página). Etiquetas de texto:
        -- los glifos ◀/▶ no existen en la fuente de 3.3.5a (renderizan "?").
        local prevBtn = RD.UIUtils.MakeChipButton(pickerFrame, UniqueName("Np"), 84, 24)
        prevBtn:SetText("Anterior")
        prevBtn:SetPoint("BOTTOMLEFT", pickerFrame, "BOTTOMLEFT", 12, 12)
        prevBtn:SetScript("OnClick", function()
            if pickerPage > 1 then
                pickerPage = pickerPage - 1
                BuildPickerGrid()
            end
        end)
        pickerFrame.prevBtn = prevBtn

        local pageLabel = pickerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        pageLabel:SetText("Página 1 / 1")
        pageLabel:SetPoint("BOTTOM", pickerFrame, "BOTTOM", 0, 16)
        RD.UIUtils.ScaleFont(pageLabel, 1.25)
        pickerFrame.pageLabel = pageLabel

        local nextBtn = RD.UIUtils.MakeChipButton(pickerFrame, UniqueName("Nx"), 84, 24)
        nextBtn:SetText("Siguiente")
        nextBtn:SetPoint("BOTTOMRIGHT", pickerFrame, "BOTTOMRIGHT", -12, 12)
        nextBtn:SetScript("OnClick", function()
            if pickerPage < totalPages then
                pickerPage = pickerPage + 1
                BuildPickerGrid()
            end
        end)
        pickerFrame.nextBtn = nextBtn
    end

    pickerFrame.callback = callback
    pickerFrame.current = current

    -- Un elemento sin imagen (icono vacío) se muestra con el icono por defecto;
    -- así el estado "sin icono" queda representado y re-seleccionable.
    if pickerFrame.current == "" or pickerFrame.current == nil then
        pickerFrame.current = DEFAULT_ICON
    end

    -- Salta a la página donde está el icono actual (si existe); si no, página 1
    local list = BuildFullIconList()
    local idx = nil
    for i, icon in ipairs(list) do
        if icon == pickerFrame.current then idx = i break end
    end
    if idx then
        pickerPage = math.max(1, math.ceil(idx / PAGE_SIZE))
    else
        pickerPage = 1
    end

    -- La lista ya está precargada en PLAYER_LOGIN (Widgets.CollectIcons);
    -- BuildPickerGrid usa BuildFullIconList (caché) directamente.
    BuildPickerGrid()

    pickerFrame:ClearAllPoints()
    pickerFrame:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", 0, 8)
    if RD.UIUtils and RD.UIUtils.ClampModalToScreen then
        RD.UIUtils.ClampModalToScreen(pickerFrame, pickerFrame.scroll, 20)
    end
    pickerFrame.catcher:Show()
    pickerFrame:Show()
    pickerFrame:Raise()

    local layout = RD.ui and RD.ui.layout
    if layout and layout.EnsureVisible then
        layout:EnsureVisible(pickerFrame, 8)
    end
end

-- =============================================
-- LIST EDITOR (lista de { name, icon } configurable)
-- =============================================

function Widgets:CreateList(parent, field, onChange)
    if not parent or not field then return nil end

    local key = field.key
    local value = GetValue(field)
    local list = {}
    if type(value) == "table" then
        for _, v in ipairs(value) do
            list[#list + 1] = { name = v.name or "", icon = v.icon or "", visible = v.visible }
        end
    end

    -- El editor aprovecha el ancho disponible del frame fila padre, dejando
    -- margen derecho para que la barra de scroll quede contenida en la fila.
    local width = field.width or (parent.GetWidth and (parent:GetWidth() or 0) or 0)
    if width <= 0 then width = 452 end
    local height = field.height or 200
    -- Espacio a la derecha para la barra de scroll (junto al contenido)
    local scrollW = width - 26
    local childW = scrollW
    local rowH = 24
    local gap = 2

    -- Scroll con barra personalizada (la barra queda a la derecha del contenido)
    local scroll, child = CreateScrollFrame(parent, scrollW, height)
    child:SetWidth(childW)

    local itemRows = {}
    local BuildRows

    -- Guarda una copia nueva (para que RD.config:Set detecte el cambio y dispare
    -- CONFIG_CHANGED) pero SIN reasignar `list`: así los closures de los ítems
    -- (nombre/icono) siguen referenciando la misma lista viva y cada edición
    -- posterior se propaga correctamente.
    local function SaveList()
        local copy = {}
        for _, v in ipairs(list) do
            copy[#copy + 1] = { name = v.name, icon = v.icon, visible = v.visible }
        end
        if RD.config and RD.config.Set then
            RD.config:Set(key, copy)
        end
        if onChange then onChange(field, copy) end
    end

    local function ClearRows()
        for _, r in ipairs(itemRows) do
            r:Hide()
            r:SetParent(nil)
        end
        itemRows = {}
    end

    -- Fila superior: añadir elemento (nombre + selector de icono + botón)
    local pendingIcon = DEFAULT_ICON

    local addName = CreateFrame("EditBox", UniqueName("ANm"), child, "InputBoxTemplate")
    addName:SetSize(math.max(90, childW - 24 - 64 - 72 - 76 - 24), 22)
    addName:SetPoint("TOPLEFT", child, "TOPLEFT", 6, 0)
    addName:SetAutoFocus(false)
    RD.UIUtils.StyleInput(addName)

    local addIconBtn = CreateFrame("Button", UniqueName("AIB"), child)
    addIconBtn:SetSize(24, 24)
    addIconBtn:SetPoint("LEFT", addName, "RIGHT", 4, 0)
    local addIconTex = addIconBtn:CreateTexture(nil, "ARTWORK")
    addIconTex:SetAllPoints()
    addIconTex:SetTexture(pendingIcon)
    addIconBtn:SetScript("OnClick", function()
        OpenIconPicker(addIconBtn, function(icon)
            pendingIcon = icon
            addIconTex:SetTexture(icon)
        end, pendingIcon)
    end)
    addIconBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Clic para elegir el icono", 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    addIconBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    local addBtn = RD.UIUtils.MakeChipButton(child, UniqueName("AAd"), 64, 22)
    addBtn:SetText("Añadir")
    RD.UIUtils.AddButtonTooltip(addBtn, function() return "Añade el elemento escrito a la lista." end)
    addBtn:SetPoint("LEFT", addIconBtn, "RIGHT", 4, 0)

    -- Obtener del líder + Reiniciar (confirmaciones) vía helper compartido
    local actions = RD.ui and RD.ui.widgets and RD.ui.widgets.CreateListActionButtons
        and RD.ui.widgets:CreateListActionButtons(child, addBtn, {
            listKey = key,
            label = field.label or key,
            obtainWidth = 72,
            resetWidth = 76,
            onReset = function()
                local defaults = (RD.constants and RD.constants.DEFAULT_LISTS and RD.constants.DEFAULT_LISTS[key]) or {}
                for i = #list, 1, -1 do table.remove(list, i) end
                for _, item in ipairs(defaults) do
                    local copy = {}
                    for k, v in pairs(item) do copy[k] = v end
                    list[#list + 1] = copy
                end
                SaveList()
                BuildRows()
            end,
        })

    addBtn:SetScript("OnClick", function()
        local name = strtrim(addName:GetText() or "")
        if name == "" then
            addName:ClearFocus()
            return
        end
        table.insert(list, { name = name, icon = pendingIcon })
        addName:SetText("")
        addIconTex:SetTexture(DEFAULT_ICON)
        pendingIcon = DEFAULT_ICON
        SaveList()
        BuildRows()
    end)
    -- Enter añade y libera el foco; Escape solo lo libera (para usar atajos).
    addName:SetScript("OnEnterPressed", function(self)
        addBtn:Click()
        self:ClearFocus()
    end)
    addName:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    BuildRows = function()
        ClearRows()

        -- Los ítems se distribuyen en el máximo de columnas que caben según el
        -- ancho disponible (cada celda necesita un ancho mínimo), aprovechando
        -- todo el espacio del panel.
        local MIN_CELL = 190
        local colGap = 8
        local cols = math.max(1, math.floor((childW + colGap) / (MIN_CELL + colGap)))
        local cellW = math.max(120, math.floor((childW - (cols - 1) * colGap) / cols))
        local gridRows = math.ceil(#list / cols)
        local totalH = rowH + gap + gridRows * (rowH + gap)

        for i, item in ipairs(list) do
            local col = (i - 1) % cols
            local r = math.floor((i - 1) / cols)
            local row = CreateFrame("Frame", nil, child)
            row:SetSize(cellW, rowH)
            row:SetPoint("TOPLEFT", child, "TOPLEFT", col * (cellW + colGap), -(rowH + gap) - r * (rowH + gap))
            RD.UIUtils.AddRowHover(row)

            -- Nombre editable (EditBox en línea). No hay icono a la izquierda:
            -- el único icono de la fila es el botón-toggle del selector (derecha).
            local nameBox = CreateFrame("EditBox", UniqueName("INm"), row, "InputBoxTemplate")
            nameBox:SetHeight(22)
            nameBox:SetPoint("LEFT", row, "LEFT", 6, 0)
            nameBox:SetPoint("RIGHT", row, "RIGHT", -120, 0)
            nameBox:SetAutoFocus(false)
            nameBox:SetText(item.name)
            RD.UIUtils.StyleInput(nameBox)
            local function SaveName(self)
                item.name = strtrim(self:GetText() or "")
                SaveList()
                self:ClearFocus()
            end
            -- En vivo mientras se escribe + confirmación con Enter/Esc (Enter/Esc
            -- también liberan el foco para poder usar los atajos del teclado).
            nameBox:SetScript("OnTextChanged", SaveName)
            nameBox:SetScript("OnEnterPressed", SaveName)
            nameBox:SetScript("OnEscapePressed", SaveName)
            row.nameBox = nameBox

            -- Botón de icono editable (abre el selector de iconos)
            local iconBtn = CreateFrame("Button", UniqueName("IIB"), row)
            iconBtn:SetSize(24, 24)
            local itemIconTex = iconBtn:CreateTexture(nil, "ARTWORK")
            itemIconTex:SetAllPoints()
            itemIconTex:SetTexture(item.icon ~= "" and item.icon or DEFAULT_ICON)
            iconBtn:SetScript("OnClick", function()
                OpenIconPicker(iconBtn, function(icon)
                    item.icon = icon
                    itemIconTex:SetTexture(icon)
                    SaveList()
                end, item.icon)
            end)
            iconBtn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText("Clic para cambiar el icono", 1, 1, 1, 1, true)
                GameTooltip:Show()
            end)
            iconBtn:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)

            -- Botón subir (reordenar: mueve el elemento una posición arriba)
            local upBtn = CreateFrame("Button", UniqueName("IUp"), row)
            upBtn:SetSize(20, 20)
            local upTex = upBtn:CreateTexture(nil, "ARTWORK")
            upTex:SetAllPoints()
            upTex:SetTexture("Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Up")
            upBtn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
            upBtn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText("Subir en la lista", 1, 0.82, 0, 1, true)
                GameTooltip:Show()
            end)
            upBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
            upBtn:SetScript("OnClick", function()
                if i > 1 then
                    list[i], list[i - 1] = list[i - 1], list[i]
                    SaveList()
                    BuildRows()
                end
            end)

            -- Botón bajar (reordenar: mueve el elemento una posición abajo)
            local downBtn = CreateFrame("Button", UniqueName("IDn"), row)
            downBtn:SetSize(20, 20)
            local dnTex = downBtn:CreateTexture(nil, "ARTWORK")
            dnTex:SetAllPoints()
            dnTex:SetTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up")
            downBtn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
            downBtn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText("Bajar en la lista", 1, 0.82, 0, 1, true)
                GameTooltip:Show()
            end)
            downBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
            downBtn:SetScript("OnClick", function()
                if i < #list then
                    list[i], list[i + 1] = list[i + 1], list[i]
                    SaveList()
                    BuildRows()
                end
            end)

            -- Botón visibilidad en el menú flotante (ojo), antes del eliminar
            local visBtn = RD.ui.widgets:CreateVisibilityToggle(row, item, SaveList, function() BuildRows() end)

            -- Botón quitar
            local removeBtn = CreateFrame("Button", UniqueName("IRm"), row)
            removeBtn:SetSize(20, 20)
            local rmTex = removeBtn:CreateTexture(nil, "ARTWORK")
            rmTex:SetAllPoints()
            rmTex:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
            removeBtn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")

            -- Posiciona el bloque de acciones a la derecha: [icono][bajar][subir][ojo][quitar]
            removeBtn:SetPoint("RIGHT", row, "RIGHT", 0, 0)
            visBtn:SetPoint("RIGHT", removeBtn, "LEFT", -2, 0)
            upBtn:SetPoint("RIGHT", visBtn, "LEFT", -2, 0)
            downBtn:SetPoint("RIGHT", upBtn, "LEFT", -2, 0)
            iconBtn:SetPoint("RIGHT", downBtn, "LEFT", -2, 0)
            removeBtn:SetScript("OnClick", function()
                local dialogs = RD.ui and RD.ui.dialogs
                local function DoRemove()
                    table.remove(list, i)
                    SaveList()
                    BuildRows()
                end
                if dialogs and dialogs.ShowConfirmDialog then
                    dialogs:ShowConfirmDialog({
                        text = string.format("¿Eliminar '%s' de la lista?", tostring(item.name or "")),
                        acceptText = "Eliminar",
                        onAccept = DoRemove,
                    })
                else
                    DoRemove()
                end
            end)

            itemRows[#itemRows + 1] = row
        end

        -- Lista vacía: indicación para empezar a crear elementos
        if #list == 0 then
            local empty = RD.UIUtils and RD.UIUtils.CreateEmptyList
                and RD.UIUtils.CreateEmptyList(child, childW, "Lista vacía: pulsa 'Añadir' para crear el primer elemento.", -(rowH + gap))
            if empty then itemRows[#itemRows + 1] = empty end
            totalH = rowH + gap + 20
        end

        -- Navegación con Tab entre los campos de la lista: la caja de añadir y el
        -- nombre de cada fila, en orden (con salto circular).
        if EnableTabNavigation then
            local boxes = { addName }
            for _, r in ipairs(itemRows) do
                if r.nameBox then boxes[#boxes + 1] = r.nameBox end
            end
            EnableTabNavigation(boxes)
        end

        child:SetHeight(totalH)

        if scroll.SetVerticalScroll then scroll:SetVerticalScroll(0) end
        -- Viewport dinámico: se ajusta al contenido real (compacto si la lista
        -- está vacía), con tope en field.height. Así todas las pestañas de lista
        -- siguen la misma regla que Bandas.
        local viewH = math.max(1, math.min(height, math.max(1, totalH)))
        scroll:SetHeight(viewH)
        if parent.SetHeight then parent:SetHeight(viewH) end
    end

    BuildRows()

    return scroll
end

-- Helpers compartidos con otros archivos de listas (CreateContentList)
Widgets.CreateScrollFrame = CreateScrollFrame
Widgets.OpenIconPicker = OpenIconPicker

-- Hook público para precargar la lista de iconos en PLAYER_LOGIN (sin C_Timer)
Widgets.CollectIcons = function()
    return BuildFullIconList()
end

return Widgets
