--[[
    RD_UI_Widgets_Bands.lua
    PROPÓSITO: Editor CRUD de bandas para la pestaña "Bandas" de la configuración
              (CreateBands). Vive en un archivo propio, igual que los otros
              editores de lista, reutilizando la tabla RD.ui.widgets.
    API PÚBLICA:
        - RD.ui.widgets:CreateBands(parent, field, onChange)
    EVENTOS: Escribe vía RD.utils.bands / RD.config:Set (dispara CONFIG_CHANGED).
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
local CreateScrollFrame = Widgets.CreateScrollFrame
local EnableTabNavigation = RD.UIUtils and RD.UIUtils.EnableTabNavigation


-- Acceso al módulo de bandas (con guarda; puede no estar cargado al renderizar)
local function BandsModule()
    return RD.utils and RD.utils.bands
end

-- Guarda los campos editables de una banda existente (dispara CONFIG_CHANGED)
local function SaveBandField(index, data)
    local bands = BandsModule()
    if bands and bands.UpdateBand then
        bands:UpdateBand(index, data)
    end
end

function Widgets:CreateBands(parent, field, onChange)
    if not parent or not field then return nil end

    local createScroll = Widgets.CreateScrollFrame
    if not createScroll then return nil end

    local height = field.height or 200
    local width = field.width or (parent.GetWidth and (parent:GetWidth() or 0) or 0)
    if width <= 0 then width = 452 end
    local scrollW = width - 26
    local childW = scrollW

    local scroll, child = createScroll(parent, scrollW, height)
    child:SetWidth(childW)

    -- Geometría del editor (offsets enteros, grid 4px)
    local ADD_H = 22
    local ROW_H = 24
    local GAP = 6
    local HEADER_H = 14
    -- Columnas proporcionales al ancho real (sin solapes): se reserva sitio a la
    -- derecha para el bloque de acciones (ojo + bajar + subir + eliminar, 88px) y
    -- un padding izquierdo para que el primer campo no quede cortado por el clip.
    local RM_W = 88
    local LEFT_PAD = 4
    local availW = math.max(240, childW - RM_W - 4 - LEFT_PAD)
    local GS_W = 56
    local NAME_W = math.floor((availW - GS_W - 2 * GAP) / 2)
    local SCHED_W = availW - NAME_W - GS_W - 2 * GAP

    local bandRows = {}
    local headerFrames = {}

    local function ClearRows()
        for _, r in ipairs(bandRows) do
            r:Hide(); r:SetParent(nil)
        end
        bandRows = {}
        for _, h in ipairs(headerFrames) do
            h:Hide(); h:SetParent(nil)
        end
        headerFrames = {}
    end

    -- Cabecera de columna (frame, para poder limpiarla con SetParent(nil))
    local function MakeHeader(x, label, w)
        local hf = CreateFrame("Frame", nil, child)
        hf:SetSize(w, HEADER_H)
        local fs = hf:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetText(label)
        fs:SetTextColor(1, 0.82, 0)
        fs:SetJustifyH("LEFT")
        fs:SetPoint("LEFT", hf, "LEFT", 0, 0)
        fs:SetPoint("RIGHT", hf, "RIGHT", 0, 0)
        RD.UIUtils.ScaleFont(fs, 1.5)
        headerFrames[#headerFrames + 1] = hf
        return hf
    end

    local BuildRows

    -- Fila superior: botón de añadir banda
    local addBtn = RD.UIUtils.MakeChipButton(child, UniqueName("BAdd"), 130, ADD_H)
    addBtn:SetPoint("TOPLEFT", child, "TOPLEFT", 0, 0)
    addBtn:SetText("Añadir banda")
    RD.UIUtils.AddButtonTooltip(addBtn, function() return "Crea una nueva banda en la lista." end)
    addBtn:SetScript("OnClick", function()
        local bands = BandsModule()
        if bands and bands.CreateBand then
            local index = bands:CreateBand({ name = "Nueva banda", minGS = 5000, schedule = "DIA 20:00" })
            BuildRows()
            local row = bandRows[index]
            if row and row.nameBox then
                row.nameBox:SetFocus()
                row.nameBox:HighlightText()
            end
        end
    end)

    -- Obtener del líder + Reiniciar (borra TODAS las bandas) vía helper compartido
    local actions = RD.ui.widgets and RD.ui.widgets.CreateListActionButtons
        and RD.ui.widgets:CreateListActionButtons(child, addBtn, {
            listKey = "bands",
            label = "bandas",
            obtainWidth = 90,
            resetWidth = 90,
            obtainConfirm = "¿Pedir la lista de bandas al líder? Se añadirán solo las bandas que no tengas (sin duplicados ni pérdidas).",
            resetTooltip = "Borra TODAS las bandas y sus jugadores (no hay valores por defecto de bandas).",
            resetConfirm = "¿Borrar TODAS las bandas? Se perderán sus jugadores, asistencia y sanciones.",
            resetAccept = "Borrar todo",
            onReset = function()
                if RD.config and RD.config.Set then
                    RD.config:Set("bands", {})
                end
                BuildRows()
            end,
        })

    BuildRows = function()
        ClearRows()

        local bands = BandsModule()
        local list = {}
        if bands and bands.GetBands then
            list = bands:GetBands()
        end
        if type(list) ~= "table" then list = {} end

        local y = -(ADD_H + GAP)
        MakeHeader(LEFT_PAD, "Nombre", NAME_W):SetPoint("TOPLEFT", child, "TOPLEFT", LEFT_PAD, y)
        MakeHeader(LEFT_PAD + NAME_W + GAP, "GS mín", GS_W):SetPoint("TOPLEFT", child, "TOPLEFT", LEFT_PAD + NAME_W + GAP, y)
        MakeHeader(LEFT_PAD + NAME_W + GAP + GS_W + GAP, "Horario", SCHED_W):SetPoint("TOPLEFT", child, "TOPLEFT", LEFT_PAD + NAME_W + GAP + GS_W + GAP, y)
        y = y - HEADER_H - GAP

        -- Cada banda: una fila con nombre, gearscore mínimo y horario editables.
        -- Las filas capturan el índice de la banda en la lista; tras cualquier
        -- cambio estructural (añadir/eliminar) se reconstruyen los índices.
        for i, band in ipairs(list) do
            local row = CreateFrame("Frame", nil, child)
            row:SetSize(childW, ROW_H)
            row:SetPoint("TOPLEFT", child, "TOPLEFT", 0, y)
            RD.UIUtils.AddRowHover(row)

            -- Nombre (edición en vivo)
            local nameBox = CreateFrame("EditBox", UniqueName("BNm"), row, "InputBoxTemplate")
            nameBox:SetSize(NAME_W, 22)
            nameBox:SetPoint("LEFT", row, "LEFT", LEFT_PAD, 0)
            nameBox:SetAutoFocus(false)
            nameBox:SetText(band.name or "")
            RD.UIUtils.StyleInput(nameBox)
            nameBox:SetScript("OnTextChanged", function(self)
                SaveBandField(i, { name = self:GetText() })
            end)
            -- Enter/Escape liberan el foco (estilo KRT) para usar atajos del teclado.
            nameBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
            nameBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
            row.nameBox = nameBox

            -- Gearscore mínimo (numérico; se guarda al confirmar/foco perdido)
            local gsBox = CreateFrame("EditBox", UniqueName("BGS"), row, "InputBoxTemplate")
            gsBox:SetSize(GS_W, 22)
            gsBox:SetNumeric(true)
            gsBox:SetAutoFocus(false)
            gsBox:SetPoint("LEFT", nameBox, "RIGHT", GAP, 0)
            gsBox:SetText(tostring(tonumber(band.minGS) or 0))
            RD.UIUtils.StyleInput(gsBox)
            local function SaveGS(self)
                SaveBandField(i, { minGS = tonumber(self:GetText()) or 0 })
                self:ClearFocus()
            end
            gsBox:SetScript("OnEnterPressed", SaveGS)
            gsBox:SetScript("OnEscapePressed", SaveGS)
            gsBox:SetScript("OnEditFocusLost", SaveGS)
            row.gsBox = gsBox

            -- Horario (edición en vivo)
            local schedBox = CreateFrame("EditBox", UniqueName("BSc"), row, "InputBoxTemplate")
            schedBox:SetSize(SCHED_W, 22)
            schedBox:SetAutoFocus(false)
            schedBox:SetPoint("LEFT", gsBox, "RIGHT", GAP, 0)
            schedBox:SetText(band.schedule or "")
            RD.UIUtils.StyleInput(schedBox)
            schedBox:SetScript("OnTextChanged", function(self)
                SaveBandField(i, { schedule = self:GetText() })
            end)
            -- Enter/Escape liberan el foco (estilo KRT) para usar atajos del teclado.
            schedBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
            schedBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
            row.schedBox = schedBox

            -- Botón subir (reordenar: una posición arriba)
            local upBtn = CreateFrame("Button", UniqueName("BUp"), row)
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
                local bands = BandsModule()
                if not bands then return end
                local list = bands:GetBands()
                if i > 1 and list and list[i] then
                    list[i], list[i - 1] = list[i - 1], list[i]
                    local copy = {}
                    for idx, bd in ipairs(list) do copy[idx] = bd end
                    if RD.config and RD.config.Set then RD.config:Set("bands", copy) end
                    BuildRows()
                    if onChange then onChange(field, list) end
                end
            end)

            -- Botón bajar (reordenar: una posición abajo)
            local downBtn = CreateFrame("Button", UniqueName("BDn"), row)
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
                local bands = BandsModule()
                if not bands then return end
                local list = bands:GetBands()
                if i < #list and list[i] then
                    list[i], list[i + 1] = list[i + 1], list[i]
                    local copy = {}
                    for idx, bd in ipairs(list) do copy[idx] = bd end
                    if RD.config and RD.config.Set then RD.config:Set("bands", copy) end
                    BuildRows()
                    if onChange then onChange(field, list) end
                end
            end)

            -- Botón visibilidad en el menú flotante (ojo), antes del eliminar
            local visBtn = RD.ui.widgets:CreateVisibilityToggle(row, band, function()
                local bands = BandsModule()
                if bands and RD.config and RD.config.Set then
                    local list = bands:GetBands()
                    local copy = {}
                    for idx, bd in ipairs(list) do copy[idx] = bd end
                    RD.config:Set("bands", copy)
                end
                if onChange then onChange(field, bands and bands:GetBands()) end
            end, function() BuildRows() end)

            -- Botón eliminar banda
            local removeBtn = CreateFrame("Button", UniqueName("BRm"), row)
            removeBtn:SetSize(20, 20)
            local rmTex = removeBtn:CreateTexture(nil, "ARTWORK")
            rmTex:SetAllPoints()
            rmTex:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
            removeBtn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
            -- Bloque de acciones a la derecha: [bajar][subir][ojo][eliminar]
            removeBtn:SetPoint("RIGHT", row, "RIGHT", 0, 0)
            visBtn:SetPoint("RIGHT", removeBtn, "LEFT", -2, 0)
            upBtn:SetPoint("RIGHT", visBtn, "LEFT", -2, 0)
            downBtn:SetPoint("RIGHT", upBtn, "LEFT", -2, 0)
            removeBtn:SetScript("OnClick", function()
                local dialogs = RD.ui and RD.ui.dialogs
                local bands = BandsModule()
                if not bands then return end
                local bandName = (bands.GetBand and (bands:GetBand(i) or {}).name) or "la banda"
                local function DoDelete()
                    if bands.DeleteBand then
                        bands:DeleteBand(i)
                    end
                    BuildRows()
                    if onChange then onChange(field, bands:GetBands()) end
                end
                if dialogs and dialogs.ShowConfirmDialog then
                    dialogs:ShowConfirmDialog({
                        text = string.format("¿Eliminar la banda '%s'? Se borrarán sus jugadores y asistencia.", tostring(bandName)),
                        acceptText = "Eliminar",
                        cancelText = "Cancelar",
                        onAccept = DoDelete,
                    })
                else
                    DoDelete()
                end
            end)

            bandRows[i] = row
            y = y - (ROW_H + GAP)
        end

        if #list == 0 then
            local empty = RD.UIUtils and RD.UIUtils.CreateEmptyList
                and RD.UIUtils.CreateEmptyList(child, childW, "Lista vacía: pulsa 'Añadir banda' para crear la primera banda.", y)
            if empty then bandRows[1] = empty end
            y = y - 20
        end

        -- Navegación con Tab entre los campos de cada banda: nombre → GS mín →
        -- horario (fila a fila, con salto circular).
        if EnableTabNavigation then
            local boxes = {}
            for _, r in ipairs(bandRows) do
                if r.nameBox then boxes[#boxes + 1] = r.nameBox end
                if r.gsBox then boxes[#boxes + 1] = r.gsBox end
                if r.schedBox then boxes[#boxes + 1] = r.schedBox end
            end
            EnableTabNavigation(boxes)
        end

        child:SetHeight(math.max(1, -y))
        if scroll.SetVerticalScroll then scroll:SetVerticalScroll(0) end
        -- Viewport dinámico: se ajusta al contenido real (compacto si no hay
        -- bandas), con tope en field.height.
        local viewH = math.max(1, math.min(height, math.max(1, -y)))
        scroll:SetHeight(viewH)
        if parent.SetHeight then parent:SetHeight(viewH) end
    end

    BuildRows()

    return scroll
end

return Widgets
