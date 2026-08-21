--[[
    RD_UI_Widgets.lua
    PROPÓSITO: Widgets reutilizables (Checkbox, Slider, Dropdown, Textbox, Button, Color).
              La ventana de configuración los usa para renderizar por esquema.
              Cada widget lee su valor con RD.config:Get(field.key, field.default)
              y escribe con RD.config:Set (que dispara CONFIG_CHANGED).
    API PÚBLICA:
        - RD.ui.widgets:CreateCheckbox(parent, field, onChange)
        - RD.ui.widgets:CreateSlider(parent, field, onChange)
        - RD.ui.widgets:CreateDropdown(parent, field, onChange)
        - RD.ui.widgets:CreateTextbox(parent, field, onChange)
        - RD.ui.widgets:CreateButton(parent, field, onClick)
        - RD.ui.widgets:CreateList(parent, field, onChange)
        - RD.ui.widgets:CreateColor(parent, field, onChange)
    EVENTOS: Ninguno (indirectamente dispara CONFIG_CHANGED vía RD.config:Set)
]]

local addonName, private = ...
local RD = _G.RaidDominion or {}
_G.RaidDominion = RD

-- La tabla de widgets se reutiliza si ya existe: así ningún widget de otro
-- archivo (RD_UI_Widgets_*) se pierde aunque el orden de carga varíe.
RD.ui = RD.ui or {}
local Widgets = RD.ui.widgets
if not Widgets then
    Widgets = {}
    RD.ui.widgets = Widgets
end

-- Grid base (misma fuente que RD.constants.GRID)
local GUTTER = (RD.constants and RD.constants.GRID and RD.constants.GRID.GUTTER) or 4
local LABEL_WIDTH = (RD.constants and RD.constants.GRID and RD.constants.GRID.LABEL_WIDTH) or 184

-- Nombre único para frames con templates (los templates crean hijos con $parent).
-- Se delega en el contador ÚNICO de RD.UIUtils para evitar colisiones entre archivos.
local UniqueName = RD.UIUtils and RD.UIUtils.UniqueName

-- Lee un valor de config con guarda
local function GetValue(field)
    if RD.config and RD.config.Get then
        return RD.config:Get(field.key, field.default)
    end
    return field.default
end

-- Escribe un valor de config y dispara el callback con guarda
local function SetValue(field, value, onChange)
    if RD.config and RD.config.Set then
        RD.config:Set(field.key, value)
    end
    if onChange then
        onChange(field, value)
    end
end

-- Redondea un número al paso del campo (con limpieza de artefactos de coma flotante)
local function RoundToStep(value, step)
    if not step or step <= 0 then return value end
    local rounded = math.floor((value / step) + 0.5) * step
    if step < 1 then
        rounded = math.floor(rounded * 100 + 0.5) / 100
    end
    return rounded
end

-- Formatea el valor según el paso (enteros si step >= 1, dos decimales si no)
local function FormatValue(value, step)
    if step and step >= 1 then
        return string.format("%d", math.floor(value + 0.5))
    end
    return string.format("%.2f", value)
end

-- =============================================
-- CHECKBOX
-- =============================================

function Widgets:CreateCheckbox(parent, field, onChange)
    if not parent or not field then return nil end

    -- CheckButton con template y nombre único (el template crea "$parentText").
    -- Estilo WoW: checkbox a la izquierda y label a su derecha (compacto).
    local check = CreateFrame("CheckButton", UniqueName("Ck"), parent, "UICheckButtonTemplate")
    check:SetSize(20, 20)
    check:SetPoint("LEFT", parent, "LEFT", 0, 0)

    -- Vaciar el texto del template (el label propio va a la derecha del check)
    local templateText = getglobal(check:GetName() .. "Text")
    if templateText then
        templateText:SetText("")
    end

    -- Label a la derecha del checkbox
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetText(field.label or "")
    RD.UIUtils.ScaleFont(label, 1.25)
    label:SetJustifyH("LEFT")
    label:SetPoint("LEFT", check, "RIGHT", 6, 0)

    -- Botón transparente sobre el label para hacer toggle (los FontStrings no tienen OnClick)
    local labelButton = CreateFrame("Button", nil, parent)
    labelButton:SetPoint("LEFT", check, "RIGHT", 6, 0)
    labelButton:SetPoint("RIGHT", parent, "RIGHT", 0, 0)
    labelButton:SetHeight(24)
    labelButton:SetScript("OnClick", function()
        check:SetChecked(not check:GetChecked())
        -- 3.3.5a: GetChecked devuelve 1/nil (WoW Flag Boolean), se normaliza a nativo
        local checked = check:GetChecked()
        local value = (checked == true) or (checked == 1)
        SetValue(field, value, onChange)
    end)

    -- Valor inicial
    check:SetChecked(GetValue(field))

    check:SetScript("OnClick", function(self)
        -- 3.3.5a: GetChecked devuelve 1/nil, se normaliza a booleano nativo para
        -- que Config:Set guarde true/false (no borre la clave con nil).
        local checked = self:GetChecked()
        local value = (checked == true) or (checked == 1)
        SetValue(field, value, onChange)
    end)

    -- Controles interactivos para hover/tooltip de fila (cubren todo el elemento)
    check.rdHoverTargets = { check, labelButton }
    return check
end

-- =============================================
-- SLIDER
-- =============================================

function Widgets:CreateSlider(parent, field, onChange)
    if not parent or not field then return nil end

    local min = field.min or 0
    local max = field.max or 1
    local step = field.step or 0.05

    local slider = CreateFrame("Slider", UniqueName("Sld"), parent, "OptionsSliderTemplate")
    slider:SetSize(100, 32)
    slider:SetMinMaxValues(min, max)
    slider:SetValueStep(step)

    -- Vaciar el texto del template (mostramos el valor con FontString propio)
    -- y retirar las etiquetas "Bajo"/"Alto" (Low/High) del template.
    local sliderName = slider:GetName()
    for _, suffix in ipairs({ "Text", "Low", "High" }) do
        local lbl = getglobal(sliderName .. suffix)
        if lbl then
            lbl:SetText("")
        end
    end

    -- Label a la izquierda con ancho fijo para alinear todos los sliders
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetText(field.label or "")
    RD.UIUtils.ScaleFont(label, 1.25)
    label:SetJustifyH("LEFT")
    label:SetPoint("LEFT", parent, "LEFT", 0, 0)
    label:SetWidth(LABEL_WIDTH)

    -- Valor (solo lectura): FontString a la derecha, siempre visible y NO
    -- editable. El valor solo cambia arrastrando la barra.
    local valueText = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    valueText:SetJustifyH("RIGHT")
    valueText:SetPoint("RIGHT", parent, "RIGHT", 0, 0)

    -- El slider se estira entre el label y el valor
    slider:SetPoint("LEFT", label, "RIGHT", 8, 0)
    slider:SetPoint("RIGHT", valueText, "LEFT", -8, 0)

    -- Estado interno y flag de carga (protege contra OnValueChanged durante init)
    local currentValue = min
    local loading = true

    local function UpdateDisplays(value)
        currentValue = value
        valueText:SetText(FormatValue(value, step))
    end

    -- En 3.3.5a OnValueChanged recibe (self, value) sin flag userChanged
    -- (ese tercer argumento llegó en Cataclysm). El flag `loading` protege
    -- contra SetValue programáticos durante init/edición manual.
    slider:SetScript("OnValueChanged", function(self, value)
        if loading then return end
        local rounded = RoundToStep(value, step)
        UpdateDisplays(rounded)
        SetValue(field, rounded, onChange)
    end)
    slider.rdHoverTargets = { slider }

    -- Carga del valor inicial
    local initial = GetValue(field)
    if type(initial) ~= "number" then
        initial = min
    end
    loading = true
    slider:SetValue(initial)
    loading = false
    UpdateDisplays(initial)

    return slider
end

-- =============================================
-- DROPDOWN
-- =============================================

function Widgets:CreateDropdown(parent, field, onChange)
    if not parent or not field then return nil end

    local options = field.options or {}
    local dropDown = CreateFrame("Frame", UniqueName("DD"), parent, "UIDropDownMenuTemplate")
    dropDown:SetPoint("RIGHT", parent, "RIGHT", 0, 0)

    -- Label a la izquierda
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetText(field.label or "")
    RD.UIUtils.ScaleFont(label, 1.25)
    label:SetJustifyH("LEFT")
    label:SetPoint("LEFT", parent, "LEFT", 0, 0)

    UIDropDownMenu_SetWidth(dropDown, 160)
    UIDropDownMenu_SetAnchor(dropDown, 0, 0)

    -- Valor actual; si no existe en options, usar el primer valor como fallback
    local actual = GetValue(field)
    if not options[actual] then
        for k in pairs(options) do
            actual = k
            break
        end
    end

    local function InitFunc()
        local info = UIDropDownMenu_CreateInfo()
        for value, text in pairs(options) do
            info.text = text
            info.value = value
            info.checked = (value == actual)
            info.func = function()
                UIDropDownMenu_SetSelectedValue(dropDown, value)
                UIDropDownMenu_SetText(dropDown, text)
                actual = value
                SetValue(field, value, onChange)
            end
            UIDropDownMenu_AddButton(info)
        end
    end

    UIDropDownMenu_Initialize(dropDown, InitFunc)
    UIDropDownMenu_SetSelectedValue(dropDown, actual)
    UIDropDownMenu_SetText(dropDown, options[actual] or "")

    dropDown.rdHoverTargets = { dropDown, getglobal(dropDown:GetName() .. "Button") }
    return dropDown
end

-- =============================================
-- TEXTBOX
-- =============================================

function Widgets:CreateTextbox(parent, field, onChange)
    if not parent or not field then return nil end

    -- Modo readonly: FontString multilinea (se usa para el tab de ayuda)
    if field.readonly then
        local text = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        text:SetText(field.label or field.default or "")
        RD.UIUtils.ScaleFont(text, 1.25)
        text:SetWordWrap(true)
        text:SetJustifyH("LEFT")
        text:SetJustifyV("TOP")
        text:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
        -- Aprovecha el ancho disponible del frame fila
        local avail = parent.GetWidth and parent:GetWidth() or 0
        text:SetWidth((avail and avail > 0) and (avail - 4) or (LABEL_WIDTH + 80))
        return text
    end

    -- Label a la izquierda
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetText(field.label or "")
    RD.UIUtils.ScaleFont(label, 1.25)
    label:SetJustifyH("LEFT")
    label:SetPoint("LEFT", parent, "LEFT", 0, 0)

    -- EditBox a la derecha
    local editBox = CreateFrame("EditBox", UniqueName("Ed"), parent, "InputBoxTemplate")
    editBox:SetSize(200, 24)
    editBox:SetAutoFocus(false)
    RD.UIUtils.StyleInput(editBox)
    editBox:SetPoint("RIGHT", parent, "RIGHT", 0, 0)

    local initial = GetValue(field)
    if initial == nil then initial = "" end
    editBox:SetText(tostring(initial))

    local function SaveValue(self)
        local value = self:GetText()
        SetValue(field, value, onChange)
        self:ClearFocus()
    end

    editBox:SetScript("OnEnterPressed", SaveValue)
    editBox:SetScript("OnEscapePressed", SaveValue)
    editBox.rdHoverTargets = { editBox }

    return editBox
end

-- =============================================
-- BUTTON
-- =============================================

function Widgets:CreateButton(parent, field, onClick)
    if not parent or not field then return nil end

    local button = RD.UIUtils.MakeChipButton(parent, UniqueName("Btn"), 140, 24)
    button:SetText(field.label or "")

    button:SetScript("OnClick", function(self)
        if onClick then
            onClick(field, self)
        end
        if field.action then
            -- La acción puede no estar registrada aún al construir la UI
            pcall(function()
                if RD.MenuActions and RD.MenuActions.Execute then
                    RD.MenuActions:Execute(field.action, { button = self, field = field })
                end
            end)
        end
    end)

    button.rdHoverTargets = { button }
    return button
end

-- Fila de botones (varios botones en una misma línea, alineados a la derecha).
-- Cada botón lleva su propio tooltip (field.buttons[i].help) y puede pedir
-- confirmación antes de ejecutar su acción (field.buttons[i].confirmText), lo
-- que cubre los procesos destructivos (p.ej. "Restablecer valores por defecto").
function Widgets:CreateButtons(parent, field, onClick)
    if not parent or not field then return nil end
    local defs = field.buttons or {}
    if #defs == 0 then return nil end

    local buttons = {}
    local gap = 8
    local x = 0
    for _, bd in ipairs(defs) do
        local btn = RD.UIUtils.MakeChipButton(parent, UniqueName("BtR"), 140, 24)
        btn:SetText(bd.label or "")
        local fs = btn:GetFontString()
        local textW = (fs and fs.GetStringWidth and (fs:GetStringWidth() or 0)) or 0
        local layout = RD.ui and RD.ui.layout
        local width = math.max(140, textW + 24)
        btn:SetWidth(layout and layout.Snap(width) or width)
        btn:SetPoint("RIGHT", parent, "RIGHT", -x, 0)
        x = x + btn:GetWidth() + gap

        local tip = bd.help or field.help
        if tip then
            RD.UIUtils.AddButtonTooltip(btn, function() return tip end)
        end

        local function Run()
            if onClick then onClick(bd, btn) end
            if bd.action and RD.MenuActions and RD.MenuActions.Execute then
                pcall(function()
                    RD.MenuActions:Execute(bd.action, { button = btn, field = field })
                end)
            end
        end

        btn:SetScript("OnClick", function()
            if bd.confirmText then
                local dialogs = RD.ui and RD.ui.dialogs
                if dialogs and dialogs.ShowConfirmDialog then
                    dialogs:ShowConfirmDialog({
                        text = bd.confirmText,
                        acceptText = bd.confirmAccept or "Aceptar",
                        onAccept = Run,
                    })
                    return
                end
            end
            Run()
        end)

        buttons[#buttons + 1] = btn
    end

    return { buttons = buttons, rdHoverTargets = buttons }
end

-- Botones de acciones de LISTA: "Obtener" (pedir al líder) y "Reiniciar"
-- (restaurar estado por defecto), ambos con confirmación. Centraliza el patrón
-- que antes se triplicaba en CreateList / CreateContentList / CreateBands.
-- opts: { listKey, label, showObtain, showReset, obtainWidth, resetWidth,
--         obtainConfirm, obtainAccept, resetConfirm, resetAccept, resetTooltip,
--         onReset (callback del reset específico del editor) }
-- Devuelve { obtBtn, resetBtn, lastBtn } para que el editor posicione lo que siga.
function Widgets:CreateListActionButtons(parent, anchorBtn, opts)
    if not parent then return nil end
    opts = opts or {}
    local gap = 6
    local anchor = anchorBtn
    local result = {}

    local function MakeButton(name, text, w)
        local b = RD.UIUtils.MakeChipButton(parent, UniqueName(name), w or 80, 22)
        b:SetText(text)
        if anchor then
            b:SetPoint("LEFT", anchor, "RIGHT", gap, 0)
        else
            b:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
        end
        anchor = b
        return b
    end

    local function RequestList()
        local comm = RD.comm
        if comm and comm.RequestList then
            local ok = comm:RequestList(opts.listKey)
            if not ok and RD.messageManager and RD.messageManager.SendSystemMessage then
                RD.messageManager:SendSystemMessage("|cffff8000[RaidDominion]|r Debes estar en grupo y no ser el líder para obtener esta lista.")
            end
        end
    end

    if opts.showObtain ~= false then
        local b = MakeButton("LgOb", "Obtener", opts.obtainWidth)
        RD.UIUtils.AddButtonTooltip(b, function() return "Pide esta lista al líder si estás en grupo (añade solo los elementos nuevos, sin duplicados ni pérdidas)." end)
        b:SetScript("OnClick", function()
            local dialogs = RD.ui and RD.ui.dialogs
            if dialogs and dialogs.ShowConfirmDialog then
                dialogs:ShowConfirmDialog({
                    text = opts.obtainConfirm or string.format("¿Pedir la lista de %s al líder? Se añadirán solo los elementos que no tengas (sin duplicados ni pérdidas).", opts.label or opts.listKey),
                    acceptText = opts.obtainAccept or "Obtener",
                    onAccept = RequestList,
                })
            else
                RequestList()
            end
        end)
        result.obtBtn = b
    end

    if opts.showReset ~= false and opts.onReset then
        local b = MakeButton("LgRs", "Reiniciar", opts.resetWidth)
        RD.UIUtils.AddButtonTooltip(b, function()
            return opts.resetTooltip or "Restaura esta lista a su estado por defecto (elimina los elementos actuales)."
        end)
        b:SetScript("OnClick", function()
            local dialogs = RD.ui and RD.ui.dialogs
            if not (dialogs and dialogs.ShowConfirmDialog) then return end
            dialogs:ShowConfirmDialog({
                text = opts.resetConfirm or string.format("¿Reiniciar la lista de %s? Se eliminarán todos los elementos y se restaurará el estado por defecto.", opts.label or opts.listKey),
                acceptText = opts.resetAccept or "Reiniciar",
                onAccept = opts.onReset,
            })
        end)
        result.resetBtn = b
    end

    result.lastBtn = anchor
    return result
end

-- =============================================
-- DROPDOWN DE OPCIONES (rol, dual, líder, sanción)
-- =============================================

-- Convierte tablas de datos (BAND_ROLE/BAND_LEADER/BAND_SANCTION) en opciones
-- para CreateOptionsDropdown. Centraliza el patrón de BandsList/PlayerEditor.
function Widgets.DataOptions(dataTable)
    local opts = {}
    for _, d in ipairs(dataTable or {}) do
        opts[#opts + 1] = { key = d.key, label = d.label or d.short or d.key, color = d.color }
    end
    return opts
end

-- Botón pequeño que muestra el valor actual y abre un menú UIDropDownMenu con
-- las opciones. Evita el botón alto del template dentro de filas de 20px.
-- opts: { options = { {key,label,color}, ... }, current, onSelect(key), emptyLabel }
-- Devuelve { button, menu, text, GetValue(), SetValue(v) }.
function Widgets:CreateOptionsDropdown(parent, width, opts)
    if not parent or not opts then return nil end
    local options = opts.options or {}
    local emptyLabel = opts.emptyLabel or "—"
    local current = opts.current or ""
    -- Color del texto del valor mostrado (por defecto gris claro). Permite un
    -- acento más vivo (p.ej. dorado) para los dropdown de título de ventana.
    local textColor = opts.textColor or { 0.6, 0.6, 0.6 }

    local function LabelFor(key)
        if key == nil or key == "" then return emptyLabel end
        for _, o in ipairs(options) do
            if o.key == key then return o.label end
        end
        return emptyLabel
    end
    local function ColorFor(key)
        for _, o in ipairs(options) do
            if o.key == key then return o.color or textColor end
        end
        return textColor
    end

    local btn = CreateFrame("Button", UniqueName("ODb"), parent)
    btn:SetSize(width or 140, 20)
    btn:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    local text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    btn:SetFontString(text)
    text:SetJustifyH("CENTER")
    text:SetPoint("LEFT", btn, "LEFT", 2, 0)
    text:SetPoint("RIGHT", btn, "RIGHT", -2, 0)

    local menu = CreateFrame("Frame", UniqueName("ODm"), parent, "UIDropDownMenuTemplate")
    menu:Hide()

    local function Paint()
        text:SetText(LabelFor(current))
        local c = ColorFor(current)
        text:SetTextColor(c[1], c[2], c[3])
    end
    Paint()

    local function InitFunc()
        -- Opción vacía ("—") opcional: se omite cuando hideEmpty=true (p.ej. en
        -- el título de una ventana que siempre tiene un valor válido).
        if not opts.hideEmpty then
            local info = UIDropDownMenu_CreateInfo()
            info.text = emptyLabel
            info.value = ""
            info.checked = (current == "" or current == nil)
            info.func = function()
                current = ""
                Paint()
                if opts.onSelect then opts.onSelect("") end
            end
            UIDropDownMenu_AddButton(info)
        end
        for _, o in ipairs(options) do
            local info2 = UIDropDownMenu_CreateInfo()
            info2.text = o.label
            info2.value = o.key
            info2.checked = (current == o.key)
            if o.color then
                info2.colorR, info2.colorG, info2.colorB = o.color[1], o.color[2], o.color[3]
            end
            info2.func = function()
                current = o.key
                Paint()
                if opts.onSelect then opts.onSelect(o.key) end
            end
            UIDropDownMenu_AddButton(info2)
        end
    end

    btn:SetScript("OnClick", function()
        UIDropDownMenu_Initialize(menu, InitFunc)
        UIDropDownMenu_SetAnchor(menu, 0, 0)
        -- En 3.3.5a NO existe ToggleDropdown: se usa ToggleDropDownMenu con el
        -- nombre del frame ancla (el botón trigger).
        ToggleDropDownMenu(1, nil, menu, btn:GetName(), 0, 0)
    end)

    return {
        button = btn,
        menu = menu,
        text = text,
        GetValue = function() return current end,
        SetValue = function(self, v)
            -- Soportar llamada con `:` (dd:SetValue(x)) y con `.` (dd.SetValue(x)):
            -- con `:`, self es la tabla y v el valor; con `.`, self es el valor.
            if type(self) ~= "table" then
                v = self
            end
            current = v or ""
            Paint()
        end,
    }
end

-- =============================================
-- VISIBILIDAD EN EL MENÚ (mostrar/ocultar un elemento del submenú flotante)
-- =============================================

-- Botón-ojo: togglea item.visible (default true). Cuando false, el elemento no
-- aparece en el submenú correspondiente del menú flotante. Guarda (saveFn) y
-- reconstruye (rebuildFn). Colocado ANTES del botón eliminar en los editores.
function Widgets:CreateVisibilityToggle(parent, item, saveFn, rebuildFn)
    if not parent or not item then return nil end
    local btn = CreateFrame("Button", UniqueName("Vy"), parent)
    btn:SetSize(20, 20)
    local tex = btn:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints()
    tex:SetTexture("Interface\\Icons\\INV_Misc_Eye_01")
    btn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    local function Paint()
        tex:SetVertexColor(item.visible == false and 0.35 or 1, item.visible == false and 0.35 or 1, item.visible == false and 0.35 or 1)
    end
    Paint()
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(item.visible == false and "Mostrar en el menú" or "Ocultar del menú flotante", 1, 0.82, 0, 1, true)
        GameTooltip:AddLine("El elemento seguirá aquí; solo se oculta/muestra en su submenú del menú flotante.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    btn:SetScript("OnClick", function()
        if item.visible == false then
            item.visible = true
        else
            item.visible = false
        end
        Paint()
        if saveFn then saveFn() end
        if rebuildFn then rebuildFn() end
    end)
    return btn
end

-- =============================================
-- STEPPERS Y HELPERS DE ROL / SANCIÓN (compartidos por la lista de jugadores y
-- el editor de jugador)
-- =============================================

-- Stepper [-] [label] [+] reutilizable (rol, dual, sanción). Devuelve
-- { frame, minus, plus, label }.
function Widgets:CreateStepper(parent, width)
    if not parent then return nil end
    -- Flechas de página (3.3.5a): izquierda = anterior, derecha = siguiente,
    -- congruentes con el ciclo de opciones de los steppers (rol/dual/sanción).
    local PREV_ICON = "Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up"
    local NEXT_ICON = "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up"
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(width, 20)
    local minus = CreateFrame("Button", nil, frame)
    minus:SetSize(16, 20)
    minus:SetPoint("LEFT", frame, "LEFT", 0, 0)
    local minusTex = minus:CreateTexture(nil, "ARTWORK")
    minusTex:SetAllPoints()
    minusTex:SetTexture(PREV_ICON)
    minus:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    local plus = CreateFrame("Button", nil, frame)
    plus:SetSize(16, 20)
    plus:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
    local plusTex = plus:CreateTexture(nil, "ARTWORK")
    plusTex:SetAllPoints()
    plusTex:SetTexture(NEXT_ICON)
    plus:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetJustifyH("CENTER")
    label:SetPoint("LEFT", minus, "RIGHT", 4, 0)
    label:SetPoint("RIGHT", plus, "LEFT", -4, 0)
    return { frame = frame, minus = minus, plus = plus, label = label }
end

-- Pinta el label de sanción con el short de la causal (o "—" si no hay)
function Widgets:PaintSanctionLabel(label, cause)
    if not label then return end
    local data = (RD.constants and RD.constants.BAND_SANCTION_DATA) or {}
    local meta = nil
    for _, s in ipairs(data) do
        if s.key == cause then meta = s break end
    end
    if meta then
        label:SetText(meta.short)
        label:SetTextColor(meta.color[1], meta.color[2], meta.color[3])
    else
        label:SetText("—")
        label:SetTextColor(0.6, 0.6, 0.6)
    end
end

-- Helpers compartidos con otros archivos de widgets (p.ej. RD_UI_Widgets_Color)
Widgets.UniqueName = UniqueName
Widgets.GetValue = GetValue
Widgets.SetValue = SetValue

return Widgets
