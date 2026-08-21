--[[
    RD_UI_Widgets_Color.lua
    PROPÓSITO: Widget de color (swatch + ColorPickerFrame de Blizzard).
              Vive en un archivo aparte para mantener RD_UI_Widgets.lua
              dentro del límite de ~700 líneas. Registra RD.ui.widgets:CreateColor.
    API PÚBLICA:
        - RD.ui.widgets:CreateColor(parent, field, onChange)
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

function Widgets:CreateColor(parent, field, onChange)
    if not parent or not field then return nil end

    -- Label a la izquierda
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetText(field.label or "")
    label:SetJustifyH("LEFT")
    label:SetPoint("LEFT", parent, "LEFT", 0, 0)

    -- Swatch 24x24 con textura de color (SetColorTexture NO existe en 3.3.5a)
    local swatch = CreateFrame("Button", UniqueName("Col"), parent)
    swatch:SetSize(24, 24)
    swatch:SetPoint("RIGHT", parent, "RIGHT", 0, 0)

    local tex = swatch:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints(swatch)
    tex:SetTexture("Interface\\Buttons\\WHITE8X8")

    swatch:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\UI-ColorSwatch",
        tile = true, tileSize = 8, edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })

    local function ApplyColor(color)
        if not color then return end
        local r = color.r or 1
        local g = color.g or 1
        local b = color.b or 1
        local a = color.a or 1
        tex:SetVertexColor(r, g, b)
        swatch:SetBackdropColor(r, g, b, a)
    end

    -- Color actual
    local current = GetValue(field)
    if type(current) ~= "table" then
        current = { r = 1, g = 1, b = 1, a = 1 }
    end
    ApplyColor(current)

    local function SaveColor(color)
        current = color
        ApplyColor(color)
        SetValue(field, color, onChange)
    end

    swatch:SetScript("OnClick", function()
        local r = current.r or 1
        local g = current.g or 1
        local b = current.b or 1
        local a = current.a or 1

        ColorPickerFrame.previousValues = { r = r, g = g, b = b }

        -- Func se invoca sin argumentos o con (r,g,b); restore=true al restaurar.
        ColorPickerFrame.func = function(...)
            local arg1 = select(1, ...)
            local newR, newG, newB
            if arg1 == true then
                newR = ColorPickerFrame.previousValues.r
                newG = ColorPickerFrame.previousValues.g
                newB = ColorPickerFrame.previousValues.b
            else
                newR, newG, newB = ColorPickerFrame:GetColorRGB()
            end
            local newA = a
            if ColorPickerFrame.hasOpacity then
                newA = ColorPickerFrame.opacity or a
            end
            SaveColor({ r = newR, g = newG, b = newB, a = newA })
        end

        ColorPickerFrame.cancelFunc = function()
            ColorPickerFrame.func(true)
        end

        ColorPickerFrame.hasOpacity = (field.hasOpacity ~= false)
        ColorPickerFrame.opacityFunc = function()
            local newA = ColorPickerFrame.opacity or a
            SaveColor({ r = r, g = g, b = b, a = newA })
        end

        ColorPickerFrame:SetColorRGB(r, g, b)
        ColorPickerFrame.opacity = a
        ColorPickerFrame:Show()
    end)

    swatch.rdHoverTargets = { swatch }

    return swatch
end

return Widgets
