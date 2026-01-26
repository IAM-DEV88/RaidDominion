--[[
    RD_Utils_Gearscore.lua
    Módulo para la gestión y visualización de GearScore de la hermandad.
    Emula la interfaz del Core con estilos, estructura y orden.
--]]

local addonName, private = ...
local RD = _G.RaidDominion or {}
_G.RaidDominion = RD

-- Referencias locales para optimización
local pairs, ipairs, tonumber, string, table = pairs, ipairs, tonumber, string, table
local GetGuildRosterInfo, GetNumGuildMembers, GuildRoster = GetGuildRosterInfo, GetNumGuildMembers, GuildRoster
local CreateFrame, UIParent, GameTooltip = CreateFrame, UIParent, GameTooltip
local tinsert, tremove, tsort = table.insert, table.remove, table.sort
local RAID_CLASS_COLORS = RAID_CLASS_COLORS

-- Obtener utilidades compartidas de CoreBands
RD.utils = RD.utils or {}
RD.utils.gearscore = RD.utils.gearscore or {}
local coreBandsUtils = RD.utils.coreBands
local gearscoreUtils = RD.utils.gearscore

-- Pool para las líneas de la lista (No se usa en el nuevo diseño de member cards, pero se mantiene por si acaso)
local linePool = {}

-- Función auxiliar para limpiar nombres (eliminar reino y normalizar a minúsculas)
local function CleanName(name)
    if not name then return "" end
    local clean = string.gsub(name, "%-.*", "")
    return string.lower(clean)
end

-- Función auxiliar para capitalizar nombres
local function CapitalizeName(name)
    if not name or name == "" then return "" end
    local cleanName = string.gsub(name, "%-.*", "")
    return string.upper(string.sub(cleanName, 1, 1)) .. string.lower(string.sub(cleanName, 2))
end

-- Pool de frames para member cards (reutilizando lógica de Core)
    local memberCardPool = {}
    local activeMemberCards = {}
    local categoryPages = { [1] = 1, [2] = 1, [3] = 1, [4] = 1 }
    local ITEMS_PER_PAGE = 25

local function AcquireFrame(pool, frameType, parent, template)
    local frame = tremove(pool)
    if not frame then
        frame = CreateFrame(frameType, nil, parent, template)
    else
        frame:SetParent(parent)
        frame:ClearAllPoints()
    end
    frame:Show()
    return frame
end

local function ReleaseFrame(pool, frame)
    frame:Hide()
    frame:SetParent(nil)
    frame:ClearAllPoints()
    tinsert(pool, frame)
end

-- Función para crear tarjetas de miembros estilo Core
local function CreateGSMemberCard(parent, member, xOffset, yOffset, category)
    local card = AcquireFrame(memberCardPool, "Button", parent)
    card:SetSize(182, 20)
    card:SetPoint("TOPLEFT", 6 + xOffset, -yOffset)
    card:EnableMouse(true)
    card:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    card.playerName = member.name
    
    local cleanName = CleanName(member.name)
    activeMemberCards[cleanName] = activeMemberCards[cleanName] or {}
    tinsert(activeMemberCards[cleanName], card)

    card:SetBackdrop({
        bgFile = "Interface/Buttons/WHITE8X8",
        edgeFile = "Interface/Buttons/WHITE8X8",
        tile = true, tileSize = 8, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    card:SetBackdropColor(0.15, 0.15, 0.2, 1)
    card:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

    -- Textos de la tarjeta
    if not card.nameText then
        card.nameText = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        card.nameText:SetPoint("LEFT", 5, 0)
    end
    
    if not card.gsText then
        card.gsText = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        card.gsText:SetPoint("RIGHT", -5, 0)
    end

    -- Actualizar datos
    local color = RAID_CLASS_COLORS[member.classFileName] or {r=1, g=1, b=1}
    card.nameText:SetText(CapitalizeName(member.name))
    card.nameText:SetTextColor(color.r, color.g, color.b)

    -- Lógica de color de GS
    local gsColor = "|cffaaaaaa" -- Gris por defecto (sin nota válida)
    if category == 1 then -- Con nota
        local note = member.publicNote or ""
        -- Patrón mejorado para detectar decimales (ej: 4.5, 5.2, 6.0)
        local noteGS = string.match(note, "(%d+[.,]%d+)")
        if noteGS then
            -- Normalizar coma a punto para tonumber
            noteGS = string.gsub(noteGS, ",", ".")
            local baseGS = math.floor(tonumber(noteGS) * 1000)
            local nextBaseGS = baseGS + 100
            if member.gearScore >= nextBaseGS then gsColor = "|cffff9900" -- Naranja (Mejorado)
            elseif member.gearScore >= baseGS then gsColor = "|cff00ff00" -- Verde (OK)
            else gsColor = "|cffff0000" end -- Rojo (Desactualizado)
        end
    elseif category == 2 then -- Sin nota pero con GS
        gsColor = "|cffffffff" -- Blanco
    end
    
    card.gsText:SetText(gsColor .. (member.gearScore or "---") .. "|r")

    -- Scripts
    card:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.25, 0.25, 0.35, 1)
        self:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
        
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(CapitalizeName(member.name), color.r, color.g, color.b)
        GameTooltip:AddLine("Rango: " .. (member.rank or "Sin Rango"), 1, 1, 1)
        if member.publicNote and member.publicNote ~= "" then
            GameTooltip:AddLine("Nota: |cffffffff" .. member.publicNote .. "|r")
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("|cff00ff00Click Izquierdo:|r Abrir Editor de Jugador", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    
    card:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.15, 0.15, 0.2, 1)
        self:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
        GameTooltip:Hide()
    end)

    card:SetScript("OnClick", function(self, button)
        if button == "LeftButton" then
            -- Abrir el editor de jugador de CoreBands en modo Gearscore
            if coreBandsUtils and coreBandsUtils.GetOrCreatePlayerEditFrame then
                -- Pasar el índice de hermandad para asegurar que la nota se guarde correctamente
                local editFrame = coreBandsUtils.GetOrCreatePlayerEditFrame({
                    name = member.name,
                    index = member.index
                }, true)
                editFrame:Show()
            end
        elseif button == "RightButton" then
            -- Menú contextual opcional o invitar
        end
    end)

    return card
end

-- Pool para cabeceras de sección
local headerPool = {}
local function CreateSectionHeader(parent, text, yOffset, categoryID, totalItems)
    local header = AcquireFrame(headerPool, "Frame", parent)
    header:SetSize(740, 24)
    header:SetPoint("TOPLEFT", 0, -yOffset)
    
    if not header.bg then
        header.bg = header:CreateTexture(nil, "BACKGROUND")
        header.bg:SetAllPoints()
        header.bg:SetTexture(1, 1, 1, 0.1)
    end
    
    if not header.text then
        header.text = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        header.text:SetPoint("LEFT", 10, 0)
    end
    
    local totalPages = math.ceil(totalItems / ITEMS_PER_PAGE)
    local currentPage = categoryPages[categoryID] or 1
    
    header.text:SetText(string.format("%s (|cffffffff%d|r)", text, totalItems))
    
    -- Paginador
    if not header.pageText then
        header.pageText = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        header.pageText:SetPoint("RIGHT", -60, 0)
    end
    
    if totalPages > 1 then
        header.pageText:SetText(string.format("Pág: %d/%d", currentPage, totalPages))
        header.pageText:Show()
        
        -- Botón Anterior
        if not header.prevBtn then
            header.prevBtn = CreateFrame("Button", nil, header)
            header.prevBtn:SetSize(20, 20)
            header.prevBtn:SetPoint("RIGHT", header.pageText, "LEFT", -5, 0)
            local tex = header.prevBtn:CreateTexture(nil, "ARTWORK")
            tex:SetAllPoints()
            tex:SetTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up")
            header.prevBtn:SetNormalTexture(tex)
            header.prevBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
        end
        if currentPage > 1 then header.prevBtn:Show() else header.prevBtn:Hide() end
        header.prevBtn:SetScript("OnClick", function()
            categoryPages[categoryID] = categoryPages[categoryID] - 1
            gearscoreUtils.ToggleGearscoreWindows(true)
        end)
        
        -- Botón Siguiente
        if not header.nextBtn then
            header.nextBtn = CreateFrame("Button", nil, header)
            header.nextBtn:SetSize(20, 20)
            header.nextBtn:SetPoint("LEFT", header.pageText, "RIGHT", 5, 0)
            local tex = header.nextBtn:CreateTexture(nil, "ARTWORK")
            tex:SetAllPoints()
            tex:SetTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
            header.nextBtn:SetNormalTexture(tex)
            header.nextBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
        end
        if currentPage < totalPages then header.nextBtn:Show() else header.nextBtn:Hide() end
        header.nextBtn:SetScript("OnClick", function()
            categoryPages[categoryID] = categoryPages[categoryID] + 1
            gearscoreUtils.ToggleGearscoreWindows(true)
        end)
    else
        header.pageText:Hide()
        if header.prevBtn then header.prevBtn:Hide() end
        if header.nextBtn then header.nextBtn:Hide() end
    end
    
    return header
end

-- Función para alternar las ventanas de GearScore
function gearscoreUtils.ToggleGearscoreWindows(forceShow)
    local f = _G["RaidDominionGearscoreFrame"]
    
    -- Lógica de toggle
    if f and f:IsVisible() and not forceShow then
        f:Hide()
        return
    end

    -- Si es un refresco forzado pero la ventana no existe o no está visible, no hacer nada
    if forceShow and (not f or not f:IsVisible()) then
        return
    end

    -- Crear ventana principal si no existe
    if not f then
        f = CreateFrame("Frame", "RaidDominionGearscoreFrame", UIParent)
        f:SetSize(790, 440) -- Mismo tamaño que Core
        f:SetPoint("CENTER", 0, 0)
        f:SetBackdrop({
            bgFile = "Interface/Tooltips/UI-Tooltip-Background",
            edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 }
        })
        f:SetBackdropColor(0, 0, 0, 1)
        f:SetBackdropBorderColor(1, 1, 1, 0.5)
        f:EnableMouse(true)
        f:SetMovable(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)
        
        tinsert(UISpecialFrames, "RaidDominionGearscoreFrame")
        
        -- Título
        local guildName = GetGuildInfo("player") or ""
        f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        f.title:SetPoint("TOP", 0, -15)
        f.title:SetText("RaidDominion - Gearscore Hermandad (" .. guildName .. ")")
        
        -- Botón Cerrar
        f.closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        f.closeBtn:SetPoint("TOPRIGHT", -5, -5)
        
        -- Botones de Cabecera (Acciones)
        f.header = CreateFrame("Frame", nil, f)
        f.header:SetSize(750, 40)
        f.header:SetPoint("TOP", 0, -35)
        
        -- Botón Autoasignar
        f.autoAssignBtn = coreBandsUtils.CreateStyledButton("RD_GS_AutoAssignBtn", f.header, 30, 30, nil, "Interface/Icons/INV_Misc_Note_02", "Autoasignar 'md' a DPS sin nota")
        f.autoAssignBtn:SetPoint("LEFT", 15, 0)
        f.autoAssignBtn:SetScript("OnClick", function()
            local guildMembers = RD.utils.group.GetGuildMemberList()
            local count = 0
            local MAX_PER_CLICK = 10 -- Límite para evitar desconexión
            local dpsClasses = {
                ["HUNTER"] = true,
                ["ROGUE"] = true,
                ["MAGE"] = true,
                ["WARLOCK"] = true
            }
            
            for _, member in ipairs(guildMembers) do
                if count >= MAX_PER_CLICK then break end
                
                local hasGS = member.gearScore and member.gearScore > 0
                local hasNote = member.publicNote and member.publicNote ~= ""
                
                -- Solo a los de la categoría 4: Sin GS y sin nota
                if not hasGS and not hasNote then
                    if dpsClasses[member.classFileName] then
                        GuildRosterSetPublicNote(member.index, "md")
                        count = count + 1
                    end
                end
            end
            
            if count > 0 then
                print("|cff00ff00RaidDominion:|r Se han autoasignado notas 'md' a " .. count .. " jugadores. (Límite de seguridad aplicado)")
                GuildRoster()
                gearscoreUtils.ToggleGearscoreWindows(true)
            else
                print("|cff00ff00RaidDominion:|r No se encontraron más jugadores DPS para autoasignar.")
            end
        end)
        
        -- Filtros (Opcional, se puede añadir después)
        
        -- ScrollFrame
        f.scroll = CreateFrame("ScrollFrame", "RaidDominionGearscoreScroll", f, "UIPanelScrollFrameTemplate")
        f.scroll:SetPoint("TOPLEFT", 15, -80)
        f.scroll:SetPoint("BOTTOMRIGHT", -35, 35)
        
        -- Borde del scroll
        f.scroll.border = f.scroll:CreateTexture(nil, "BACKGROUND")
        f.scroll.border:SetTexture(1, 1, 1, 0.1)
        f.scroll.border:SetHeight(1)
        f.scroll.border:SetPoint("TOPLEFT", 0, 5)
        f.scroll.border:SetPoint("TOPRIGHT", 20, 5)
        
        f.content = CreateFrame("Frame", nil, f.scroll)
        f.content:SetSize(740, 10)
        f.scroll:SetScrollChild(f.content)
        
        -- Barra de Estado
        f.statusBar = CreateFrame("Frame", nil, f)
        f.statusBar:SetSize(770, 25)
        f.statusBar:SetPoint("BOTTOM", 0, 5)
        f.statusBar:SetBackdrop({
            bgFile = "Interface/Tooltips/UI-Tooltip-Background",
            edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 }
        })
        f.statusBar:SetBackdropColor(0, 0, 0, 0.8)
        
        f.statusText = f.statusBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        f.statusText:SetPoint("LEFT", 10, 0)
    end

    -- Obtener y procesar datos
    if not RD.utils or not RD.utils.group then return end
    local guildMembers = RD.utils.group.GetGuildMemberList()
    
    -- Categorizar jugadores
    local cat1 = {} -- Con GS y nota
    local cat2 = {} -- Con GS sin nota
    local cat3 = {} -- Sin GS con nota
    local cat4 = {} -- Sin GS sin nota
    
    for _, member in ipairs(guildMembers) do
        local note = member.publicNote or ""
        local hasGS = member.gearScore and member.gearScore > 0
        local hasNote = note ~= ""
        
        if hasGS and hasNote then
            tinsert(cat1, member)
        elseif hasGS and not hasNote then
            tinsert(cat2, member)
        elseif not hasGS and hasNote then
            tinsert(cat3, member)
        else
            tinsert(cat4, member)
        end
    end
    
    -- Ordenar por prioridad de color, clase y GS
    local function getCat1Priority(member)
        local note = member.publicNote or ""
        local noteGS = string.match(note, "(%d+[.,]%d+)")
        if not noteGS then return 1 end -- Gris (sin nota válida)
        
        -- Normalizar coma a punto para tonumber
        noteGS = string.gsub(noteGS, ",", ".")
        local baseGS = math.floor(tonumber(noteGS) * 1000)
        local nextBaseGS = baseGS + 100
        if member.gearScore >= nextBaseGS then return 1 end -- Naranja
        if member.gearScore < baseGS then return 2 end -- Rojo
        return 3 -- Verde
    end

    local function sortCat1(a, b)
        local pA = getCat1Priority(a)
        local pB = getCat1Priority(b)
        
        if pA ~= pB then
            return pA < pB
        end
        
        -- Misma prioridad de color, ordenar por clase
        if a.classFileName ~= b.classFileName then
            return (a.classFileName or "") < (b.classFileName or "")
        end
        
        -- Misma clase, ordenar por GS descendente
        return (a.gearScore or 0) > (b.gearScore or 0)
    end

    local function sortRest(a, b)
        -- Ordenar por clase
        if a.classFileName ~= b.classFileName then
            return (a.classFileName or "") < (b.classFileName or "")
        end
        -- Misma clase, ordenar por GS descendente
        return (a.gearScore or 0) > (b.gearScore or 0)
    end

    tsort(cat1, sortCat1)
    tsort(cat2, sortRest)
    tsort(cat3, sortRest)
    tsort(cat4, sortRest)
    
    -- Limpiar frames antiguos
    local function ReleaseAll(parent)
        local children = {parent:GetChildren()}
        for _, child in ipairs(children) do
            child:Hide()
            child:SetParent(nil)
            -- Devolver al pool correspondiente
            if child.playerName then -- Es una member card
                tinsert(memberCardPool, child)
            else -- Es una cabecera
                tinsert(headerPool, child)
            end
        end
    end
    
    ReleaseAll(f.content)
    activeMemberCards = {}
    
    local yOffset = 0
    local categories = {
        { data = cat1, title = "1. Jugadores con GS y nota", id = 1 },
        { data = cat2, title = "2. Jugadores con GS sin nota", id = 2 },
        { data = cat3, title = "3. Jugadores sin GS con nota", id = 3 },
        { data = cat4, title = "4. Jugadores sin GS o nota", id = 4 }
    }
    
    local membersPerRow = 4
    local cardWidth = 183
    local rowHeight = 21
    
    for _, cat in ipairs(categories) do
        if #cat.data > 0 then
            -- Crear Cabecera
            CreateSectionHeader(f.content, cat.title, yOffset, cat.id, #cat.data)
            yOffset = yOffset + 30
            
            -- Calcular rango de jugadores para la página actual
            local totalItems = #cat.data
            local currentPage = categoryPages[cat.id] or 1
            local totalPages = math.ceil(totalItems / ITEMS_PER_PAGE)
            
            -- Asegurar que la página actual sea válida
            if currentPage > totalPages then currentPage = totalPages end
            if currentPage < 1 then currentPage = 1 end
            categoryPages[cat.id] = currentPage
            
            local startIndex = (currentPage - 1) * ITEMS_PER_PAGE + 1
            local endIndex = math.min(currentPage * ITEMS_PER_PAGE, totalItems)
            
            -- Crear Member Cards
            local pageItems = endIndex - startIndex + 1
            local rows = math.ceil(pageItems / membersPerRow)
            
            for row = 0, rows - 1 do
                for col = 0, membersPerRow - 1 do
                    local relativeIdx = row * membersPerRow + col
                    local absoluteIdx = startIndex + relativeIdx
                    
                    if absoluteIdx <= endIndex then
                        local member = cat.data[absoluteIdx]
                        if member then
                            local xOffset = col * cardWidth
                            CreateGSMemberCard(f.content, member, xOffset, yOffset, cat.id)
                        end
                    end
                end
                yOffset = yOffset + rowHeight
            end
            yOffset = yOffset + 15 -- Espacio entre categorías
        end
    end
    
    f.content:SetHeight(yOffset)
    f.statusText:SetText(string.format("Total: |cffffffff%d|r  -  Con GS y Nota: |cff00ff00%d|r  -  Con GS sin Nota: |cffffff00%d|r  -  Sin GS/Nota: |cffff0000%d|r", 
        #guildMembers, #cat1, #cat2, #cat3))
    
    f:Show()
end
