--[[
    RD_UI_Widgets_Help.lua
    PROPÓSITO: Widget de ayuda desplegable (acordeón) para la pestaña "Ayuda" de
              la configuración. Organiza las secciones de ayuda en DOS columnas
              que aprovechan el ancho disponible del panel; cada sección es una
              pill clicable que despliega/oculta su contenido. Solo UNA sección
              puede estar desplegada a la vez (al abrir una se cierran las demás).
              Sin librerías externas. El alto del contenedor se ajusta al
              contenido y, al abrir o cerrar una sección, se re-renderiza la
              ventana de configuración preservando el estado expandido.
    API PÚBLICA:
        - RD.ui.widgets:CreateHelpAccordion(parent, field)
              field.entries = { { title = "...", content = "..." }, ... }
              field._expanded = <título abierto> o nil  -- estado persistido
    EVENTOS: Al desplegar/plegar una sección llama a RD.ui.configWindow:Render().
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

local PAD = 8
local GAP = 8
local HEADER_H = 24
local COLS = 2
local BODY_COLOR = { 0.85, 0.85, 0.85 }

-- FontString de medida oculto para el alto del cuerpo (el texto readonly no se
-- puede medir con fiabilidad antes del layout en 3.3.5a; si da 0 se estima).
local measureFS

local function GetBodyHeight(content, width)
    if not measureFS then
        local holder = CreateFrame("Frame", nil, UIParent)
        holder:Hide()
        measureFS = holder:CreateFontString(nil, "ARTWORK")
        measureFS:SetFontObject(GameFontNormalSmall)
    end
    measureFS:SetWidth(math.max(120, width))
    measureFS:SetJustifyH("LEFT")
    measureFS:SetWordWrap(true)
    measureFS:SetText(content or "")
    local h = measureFS:GetStringHeight() or 0
    if h <= 0 then
        local lines = RD.UIUtils and RD.UIUtils.EstimateWrappedLines
            and RD.UIUtils.EstimateWrappedLines(content or "", width, 12) or 1
        h = lines * 14
    end
    return math.max(14, math.floor(h) + 6)
end

-- Crea un acordeón de ayuda en dos columnas dentro de `parent` (una fila del
-- render de configuración). Devuelve { container, rdHoverTargets }.
function Widgets:CreateHelpAccordion(parent, field)
    if not parent or not field then return nil end
    local entries = field.entries or {}
    if #entries == 0 then return nil end

    local availW = (parent.GetWidth and parent:GetWidth()) or 440
    if availW < 200 then availW = 440 end
    local colW = math.floor((availW - GAP * (COLS - 1)) / COLS)

    -- Estado expandido: UNA sola sección abierta a la vez. Se guarda el título
    -- de la sección abierta en field._expanded (nil = ninguna) y sobrevive al
    -- re-render.
    local openTitle = field._expanded

    local container = CreateFrame("Frame", nil, parent)
    container:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    container:SetSize(availW, 10)

    -- Asignación estática por índice: las secciones impares van a la columna 1
    -- y las pares a la 2. Así, al desplegar/plegar una sección ninguna otra
    -- cambia de columna ni de orden (a diferencia del reparto greedy por
    -- altura, que reordenaba las secciones al variar el alto de una expandida).
    local colH = { 0, 0 }
    local colX = { 0, colW + GAP }

    for i, e in ipairs(entries) do
        local title = e.title or ("Sección " .. i)
        local isOpen = (title == openTitle)
        local col = (i % 2 == 1) and 1 or 2
        local y = -colH[col]
        local bodyH = isOpen and GetBodyHeight(e.content, colW - PAD * 2) or 0

        local header = RD.UIUtils.MakeChipButton(container, nil, colW, HEADER_H)
        header:SetPoint("TOPLEFT", container, "TOPLEFT", colX[col], y)
        header:SetText(title)

        -- Indicador visual de colapso: sin glifos rotos, se usa el texto del
        -- chip (PaintTabButton para el estado abierto/cerrado es opcional; se
        -- resalta el header abierto con borde dorado completo).
        if RD.UIUtils and RD.UIUtils.PaintTabButton then
            RD.UIUtils.PaintTabButton(header, isOpen)
        end

        local body = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        body:SetPoint("TOPLEFT", container, "TOPLEFT", colX[col] + PAD, y - HEADER_H - 4)
        body:SetWidth(colW - PAD * 2)
        body:SetJustifyH("LEFT")
        body:SetWordWrap(true)
        body:SetText(e.content or "")
        body:SetTextColor(BODY_COLOR[1], BODY_COLOR[2], BODY_COLOR[3])
        if not isOpen then body:Hide() end

        colH[col] = colH[col] + HEADER_H + (isOpen and (bodyH + 6) or 0) + 6

        header:SetScript("OnClick", function()
            -- Solo una sección desplegada a la vez: al abrir una se cierran las
            -- demás; si ya estaba abierta, se cierra (colapso).
            if field._expanded == title then
                field._expanded = nil
            else
                field._expanded = title
            end
            local cw = RD.ui and RD.ui.configWindow
            if cw and cw.Render then cw:Render() end
        end)
    end

    local totalH = math.max(colH[1], colH[2])
    container:SetHeight(totalH)
    parent:SetHeight(totalH)

    return { container = container, rdHoverTargets = { container } }
end

return Widgets
