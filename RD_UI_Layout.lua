--[[
    RD_UI_Layout.lua
    PROPÓSITO: Motor de layout/alineación para WoW 3.3.5a. Centraliza la geometría
              y garantiza alineación píxel-perfecta (grid base de 4px, offsets enteros).
    API PÚBLICA:
        - RD.ui.layout:Snap(value)
        - RD.ui.layout:Column(parent, x, yTop, width, spacing)
        - RD.ui.layout:Row(parent, xLeft, y, height, gap)
        - RD.ui.layout:StackChildren(parent, anchor, ...)
        - RD.ui.layout:SyncHeight(container, fontString)
        - RD.ui.layout:EnsureVisible(frame, margin)
    EVENTOS: Ninguno
]]

local addonName, private = ...
local RD = _G.RaidDominion or {}
_G.RaidDominion = RD

local Layout = {}

-- Grid base (debe coincidir con RD.constants.GRID.GUTTER)
local GUTTER = (RD.constants and RD.constants.GRID and RD.constants.GRID.GUTTER) or 4

-- Redondea un valor a múltiplo entero del grid para evitar borrosidad por fracciones de píxel
function Layout.Snap(value)
    if not value then return 0 end
    return math.floor((value + GUTTER / 2) / GUTTER) * GUTTER
end

--[[
    Cursor de columna: posiciona hijos hacia abajo desde (x, yTop).
    - cursor:Place(child, height): ancla TOPLEFT, avanza el cursor y devuelve el y usado.
    - cursor:Next(height): devuelve el y actual y reserva espacio hacia abajo.
]]
function Layout:Column(parent, x, yTop, width, spacing)
    local cursor = {
        parent = parent,
        x = Layout.Snap(x),
        y = Layout.Snap(yTop),
        width = width,
        spacing = spacing or GUTTER,
    }

    function cursor:Place(child, height)
        if not child then return cursor.y end
        local h = height
        if type(h) == "number" then
            child:SetHeight(math.floor(h))
        end
        local usedY = cursor.y
        child:ClearAllPoints()
        child:SetPoint("TOPLEFT", cursor.parent, "TOPLEFT", cursor.x, cursor.y)
        h = type(h) == "number" and h or child:GetHeight() or 0
        cursor.y = Layout.Snap(cursor.y - math.floor(h) - cursor.spacing)
        return usedY
    end

    function cursor:Next(height)
        local current = cursor.y
        local h = type(height) == "number" and height or 0
        cursor.y = Layout.Snap(cursor.y - math.floor(h) - cursor.spacing)
        return current
    end

    return cursor
end

--[[
    Cursor de fila: posiciona hijos hacia la derecha desde (xLeft, y).
    - cursor:Place(child, width): ancla TOPLEFT, avanza el cursor y devuelve el x usado.
    - cursor:Next(width): devuelve el x actual y reserva espacio hacia la derecha.
]]
function Layout:Row(parent, xLeft, y, height, gap)
    local cursor = {
        parent = parent,
        x = Layout.Snap(xLeft),
        y = Layout.Snap(y),
        height = height,
        gap = gap or GUTTER,
    }

    function cursor:Place(child, width)
        if not child then return cursor.x end
        local w = width
        if type(w) == "number" then
            child:SetWidth(math.floor(w))
        end
        local usedX = cursor.x
        child:ClearAllPoints()
        child:SetPoint("TOPLEFT", cursor.parent, "TOPLEFT", cursor.x, cursor.y)
        w = type(w) == "number" and w or child:GetWidth() or 0
        cursor.x = Layout.Snap(cursor.x + math.floor(w) + cursor.gap)
        return usedX
    end

    function cursor:Next(width)
        local current = cursor.x
        local w = type(width) == "number" and width or 0
        cursor.x = Layout.Snap(cursor.x + math.floor(w) + cursor.gap)
        return current
    end

    return cursor
end

--[[
    Apila hijos verticalmente contra un ancla del padre.
    Anclas soportadas: "TOPLEFT" (default), "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT".
    Acepta varargs de frames o una tabla de frames como único argumento.
    Para FontStrings se lee el alto natural; para frames sin alto se fuerza
    SetHeight(0) antes de leer GetHeight(). Devuelve el último y usado.
]]
function Layout:StackChildren(parent, anchor, ...)
    if not parent then return 0 end

    local children
    local anchorPoint = "TOPLEFT"

    if type(anchor) == "string" then
        anchorPoint = anchor
        children = { ... }
    elseif type(anchor) == "table" and anchor.GetObjectType then
        -- Primer argumento es un frame: ancla por defecto
        children = { anchor, ... }
    elseif type(anchor) == "table" then
        -- Único argumento: tabla de frames
        children = anchor
    end

    if not children then return 0 end

    local y = 0
    local lastY = 0

    for i = 1, #children do
        local child = children[i]
        if child then
            local h = child:GetHeight()
            if child.GetObjectType and child:GetObjectType() ~= "FontString" and (not h or h <= 0) then
                child:SetHeight(0)
                h = child:GetHeight()
            end
            h = h or 0

            child:ClearAllPoints()
            if anchorPoint == "TOPRIGHT" then
                child:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, y)
            elseif anchorPoint == "BOTTOMLEFT" then
                child:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, y)
            elseif anchorPoint == "BOTTOMRIGHT" then
                child:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, y)
            else -- "TOPLEFT" (default)
                child:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)
            end

            if anchorPoint == "BOTTOMLEFT" or anchorPoint == "BOTTOMRIGHT" then
                y = y + math.floor(h) + GUTTER
            else
                y = y - math.floor(h) - GUTTER
            end
            lastY = y
        end
    end

    return lastY
end

--[[
    Ajusta el alto del contenedor al alto real del texto del FontString.
    Alto = floor(GetStringHeight()) + 2*GUTTER, con mínimo GUTTER*4 para no colapsar.
    No modifica el ancho. Devuelve el alto final aplicado.
]]
function Layout:SyncHeight(container, fontString)
    if not container or not fontString then return end

    local minHeight = GUTTER * 4
    local height = container:GetHeight() or 0
    local text = fontString:GetText()

    if text and text ~= "" then
        local textHeight = fontString:GetStringHeight()
        if textHeight and textHeight > 0 then
            height = math.floor(textHeight) + 2 * GUTTER
        end
    end

    if height < minHeight then
        height = minHeight
    end

    container:SetHeight(height)
    return height
end

--[[
    Garantiza que un frame quede dentro de la pantalla (UIParent).
    Lee los bordes del frame y la resolución; si sale de pantalla, ajusta los
    offsets de su primer ancla (o re-ancla a TOPLEFT de UIParent si está centrado).
    Todos los offsets resultantes se redondean a múltiplos del grid.
]]
function Layout:EnsureVisible(frame, margin)
    if not frame then return end
    margin = margin or 8

    local left = frame:GetLeft()
    local right = frame:GetRight()
    local top = frame:GetTop()
    local bottom = frame:GetBottom()
    if not left or not right or not top or not bottom then return end

    local screenW = UIParent:GetWidth()
    local screenH = UIParent:GetHeight()
    if not screenW or not screenH or screenW <= 0 or screenH <= 0 then return end

    -- Desplazamiento necesario (coordenadas de pantalla: x derecha, y arriba)
    local dx = 0
    local dy = 0
    if left < margin then
        dx = margin - left
    elseif right > screenW - margin then
        dx = (screenW - margin) - right
    end
    if top > screenH - margin then
        dy = (screenH - margin) - top
    elseif bottom < margin then
        dy = margin - bottom
    end

    if dx == 0 and dy == 0 then return end

    local point, relativeTo, relativePoint, xOfs, yOfs = frame:GetPoint(1)
    if not point then return end

    if point == "CENTER" then
        -- Re-anclar por coordenadas absolutas TOPLEFT de UIParent. Ojo: el
        -- espacio de UIParent es y-positivo HACIA ABAJO (origen arriba-izquierda),
        -- así que el offset Y del borde superior es GetTop()+dy (antes se restaba
        -- screenH, lo que sacaba el frame fuera de pantalla por arriba).
        local newLeft = Layout.Snap(left + dx)
        local newTop = Layout.Snap(top + dy)
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", newLeft, newTop)
    else
        xOfs = (xOfs or 0) + dx
        yOfs = (yOfs or 0) + dy
        frame:ClearAllPoints()
        frame:SetPoint(point, relativeTo, relativePoint, Layout.Snap(xOfs), Layout.Snap(yOfs))
    end
end

RD.ui = RD.ui or {}
RD.ui.layout = Layout
return Layout
