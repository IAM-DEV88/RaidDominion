--[[
    RD_Utils_Recognition.lua
    Módulo para la gestión de Reconocimientos (Boilerplate)
--]]

local addonName, private = ...
local RD = _G.RaidDominion or {}
_G.RaidDominion = RD

local string_gsub, string_upper, string_lower, string_sub, string_find, string_format, string_match = string.gsub, string.upper, string.lower, string.sub, string.find, string.format, string.match

-- Utilidades de UI
local UI = {}

function UI.CreateLabel(parent, text, template)
    local label = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlight")
    label:SetText(text)
    return label
end

function UI.CreateEditBox(name, parent, width, height, numeric)
    local eb = CreateFrame("EditBox", name, parent, "InputBoxTemplate")
    eb:SetSize(width or 200, height or 25)
    eb:SetFontObject("ChatFontNormal")
    if numeric then eb:SetNumeric(true) end
    return eb
end

-- Inicializar tablas necesarias
RD.utils = RD.utils or {}
RD.utils.recognition = RD.utils.recognition or {}
local recognitionUtils = RD.utils.recognition

-- Pool de frames para el scroll (Boilerplate similar a CoreBands)
local recognitionLinePool = {}
local memberCardPool = {}
local openRecognitionLists = {}
local selectedRecognitionIndex = nil
local selectedRecognitionLine = nil

-- Función para obtener el nivel de permisos (Reutilizada de CoreBands si está disponible)
local function GetPerms()
    local messageManager = RD.modules and RD.modules.messageManager
    if messageManager and messageManager.GetPermissionLevel then
        return messageManager:GetPermissionLevel()
    end
    
    -- Fallback simple si no está definida globalmente
    if IsGuildLeader() then return 3 end
    local _, _, rankIndex = GetGuildInfo("player")
    if rankIndex and rankIndex <= 2 then return 2 end -- Oficiales o similar
    return 1
end

-- Función para asegurar que existan los datos de reconocimiento
local function EnsureRecognitionData()
    if not RaidDominionDB then RaidDominionDB = {} end
    if not RaidDominionDB.recognition then
        RaidDominionDB.recognition = {}
    end
    return RaidDominionDB.recognition
end

-- Declarar RefreshRecognitionList antes para que addPlayerToRecognition la vea
local RefreshRecognitionList

-- Función para limpiar nombres (remover servidor)
local function CleanName(name)
    if not name then return "" end
    local clean = string.gsub(name, "%-.*", "")
    return string.lower(clean)
end

-- Helper para obtener datos del jugador (clase) desde hermandad o lista de Core
local function GetPlayerClassData(playerName)
    if not playerName then return nil end
    local cleanName = CleanName(playerName)
    
    -- 1. Intentar obtener de la unidad si existe (jugador actual, target, o en grupo)
    if UnitExists(playerName) and UnitIsPlayer(playerName) then
        local _, classFileName = UnitClass(playerName)
        if classFileName then return classFileName end
    end

    -- 2. Intentar obtener del roster de hermandad
    if IsInGuild() then
        for i = 1, GetNumGuildMembers(true) do
            local name, _, _, _, _, _, _, _, _, _, classFileName = GetGuildRosterInfo(i)
            if name and CleanName(name) == cleanName then
                return classFileName
            end
        end
    end

    -- 2. Intentar obtener de la lista de Core (Banda/Posada)
    if RaidDominionDB and RaidDominionDB.Core then
        for _, band in ipairs(RaidDominionDB.Core) do
            if band.members then
                for _, member in ipairs(band.members) do
                    if member.name and CleanName(member.name) == cleanName then
                        if member.class and member.class ~= "" then
                            return member.class
                        end
                    end
                end
            end
        end
    end
    
    return nil
end

-- Función para capitalizar nombres
local function CapitalizeName(name)
    if not name or name == "" then return "" end
    return (string_upper(string_sub(name, 1, 1)) .. string_lower(string_sub(name, 2)))
end

-- Función para agregar un jugador al reconocimiento seleccionado
local function addPlayerToRecognition(index, playerData)
    local data = EnsureRecognitionData()
    local recognition = data[index]
    if not recognition then return end
    
    if not recognition.members then recognition.members = {} end
    
    -- Verificar si ya está
    local cleanNew = CleanName(playerData.name)
    local memberEntry = nil
    for _, m in ipairs(recognition.members) do
        if CleanName(m.name) == cleanNew then
            memberEntry = m
            break
        end
    end
    
    local timestamp = time()
    if memberEntry then
        -- Acumular: agregar timestamp y aumentar contador
        memberEntry.count = (memberEntry.count or 1) + 1
        memberEntry.timestamps = memberEntry.timestamps or {}
        table.insert(memberEntry.timestamps, timestamp)
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[RaidDominion]|r Reconocimiento acumulado para " .. memberEntry.name .. " (Total: " .. memberEntry.count .. ")")
    else
        -- Nuevo registro
        table.insert(recognition.members, {
            name = CapitalizeName(playerData.name),
            class = playerData.class or "",
            count = 1,
            timestamps = { timestamp }
        })
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[RaidDominion]|r Jugador " .. playerData.name .. " agregado al reconocimiento.")
    end
    
    if RefreshRecognitionList then RefreshRecognitionList() end
    return true
end

-- Función para abrir el popup de invitación
local function getOrCreateInvitePopup()
    local invitePopup = _G["RaidDominionRecognitionInvitePopup"]
    if not invitePopup then
        invitePopup = CreateFrame("Frame", "RaidDominionRecognitionInvitePopup", UIParent)
        invitePopup:SetFrameStrata("DIALOG")
        invitePopup:SetToplevel(true)
        invitePopup:SetSize(270, 150)
        invitePopup:SetPoint("CENTER")
        invitePopup:SetBackdrop({
            bgFile = "Interface/Tooltips/UI-Tooltip-Background",
            edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 }
        })
        invitePopup:SetBackdropColor(0, 0, 0, 0.9)
        invitePopup:SetBackdropBorderColor(1, 1, 1, 0.5)
        invitePopup:EnableMouse(true)
        invitePopup:SetMovable(true)
        invitePopup:RegisterForDrag("LeftButton")
        invitePopup:SetScript("OnDragStart", invitePopup.StartMoving)
        invitePopup:SetScript("OnDragStop", invitePopup.StopMovingOrSizing)
        
        tinsert(UISpecialFrames, invitePopup:GetName())
        
        invitePopup.title = UI.CreateLabel(invitePopup, "Añadir Jugador", "GameFontNormal")
        invitePopup.title:SetPoint("TOP", 0, -15)
        
        invitePopup.closeBtn = CreateFrame("Button", nil, invitePopup, "UIPanelCloseButton")
        invitePopup.closeBtn:SetPoint("TOPRIGHT", -5, -5)
        invitePopup.closeBtn:SetScript("OnClick", function() invitePopup:Hide() end)
        
        invitePopup.nameLabel = UI.CreateLabel(invitePopup, "Nombre del jugador:")
        invitePopup.nameLabel:SetPoint("TOPLEFT", 20, -50)
        
        invitePopup.nameEdit = UI.CreateEditBox(nil, invitePopup, 240, 25)
        invitePopup.nameEdit:SetPoint("TOPLEFT", 20, -70)
        invitePopup.nameEdit:SetAutoFocus(true)
        
        -- Autocompletado robusto usando OnChar
        invitePopup.nameEdit:SetScript("OnChar", function(self, char)
            local text = self:GetText()
            local textLen = text:len()
            local cursor = self:GetCursorPosition()
            
            -- Solo autocompletar si el cursor está al final
            if cursor == textLen then
                local players = {}
                local seen = {}
                
                -- 1. Hermandad
                if IsInGuild() then
                    for i = 1, GetNumGuildMembers(true) do
                        local name = GetGuildRosterInfo(i)
                        if name then
                            name = name:match("([^%-]+)")
                            if name and not seen[name:lower()] then
                                table.insert(players, name)
                                seen[name:lower()] = true
                            end
                        end
                    end
                end
                
                -- 2. Core/Posada
                if RaidDominionDB and RaidDominionDB.Core then
                    for _, band in ipairs(RaidDominionDB.Core) do
                        if band.members then
                            for _, member in ipairs(band.members) do
                                if member.name then
                                    local name = member.name:match("([^%-]+)")
                                    if name and not seen[name:lower()] then
                                        table.insert(players, name)
                                        seen[name:lower()] = true
                                    end
                                end
                            end
                        end
                    end
                end
                
                -- Buscar coincidencia
                local searchText = text:lower()
                for _, name in ipairs(players) do
                    if name:lower():find("^" .. searchText) and name:len() > textLen then
                        local extension = name:sub(textLen + 1)
                        self:Insert(extension)
                        self:HighlightText(textLen, name:len())
                        self:SetCursorPosition(textLen)
                        break
                    end
                end
            end
        end)

        invitePopup.nameEdit:SetScript("OnEnterPressed", function() invitePopup.acceptBtn:Click() end)
        invitePopup.nameEdit:SetScript("OnEscapePressed", function() invitePopup:Hide() end)
        
        invitePopup.acceptBtn = CreateFrame("Button", nil, invitePopup, "UIPanelButtonTemplate")
        invitePopup.acceptBtn:SetSize(100, 25)
        invitePopup.acceptBtn:SetPoint("BOTTOMLEFT", 30, 15)
        invitePopup.acceptBtn:SetText("Aceptar")
        invitePopup.acceptBtn:SetScript("OnClick", function()
            local permLevel = GetPerms()
            if permLevel < 2 then
                DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[RaidDominion]|r Error: No tienes permisos para añadir jugadores.")
                return
            end

            local name = invitePopup.nameEdit:GetText()
            if name and name ~= "" and selectedRecognitionIndex then
                addPlayerToRecognition(selectedRecognitionIndex, { name = name })
                invitePopup:Hide()
            end
        end)
    end
    return invitePopup
end

function recognitionUtils.ShowPlayerSearchPopup()
    local p = _G["RaidDominionPlayerSearchPopup"]
    if not p then
        p = CreateFrame("Frame", "RaidDominionPlayerSearchPopup", UIParent)
        p:SetFrameStrata("DIALOG")
        p:SetToplevel(true)
        p:SetSize(270, 150)
        p:SetPoint("CENTER")
        p:SetBackdrop({
            bgFile = "Interface/Tooltips/UI-Tooltip-Background",
            edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 }
        })
        p:SetBackdropColor(0, 0, 0, 0.9)
        p:SetBackdropBorderColor(1, 1, 1, 0.5)
        p:EnableMouse(true)
        p:SetMovable(true)
        p:RegisterForDrag("LeftButton")
        p:SetScript("OnDragStart", p.StartMoving)
        p:SetScript("OnDragStop", p.StopMovingOrSizing)
        
        tinsert(UISpecialFrames, p:GetName())
        
        p.title = UI.CreateLabel(p, "Buscar Jugador", "GameFontNormal")
        p.title:SetPoint("TOP", 0, -15)
        
        p.closeBtn = CreateFrame("Button", nil, p, "UIPanelCloseButton")
        p.closeBtn:SetPoint("TOPRIGHT", -5, -5)
        p.closeBtn:SetScript("OnClick", function() p:Hide() end)
        
        p.nameLabel = UI.CreateLabel(p, "Nombre del jugador:")
        p.nameLabel:SetPoint("TOPLEFT", 20, -50)
        
        p.nameEdit = UI.CreateEditBox(nil, p, 240, 25)
        p.nameEdit:SetPoint("TOPLEFT", 20, -70)
        p.nameEdit:SetAutoFocus(true)
        
        -- Autocompletado robusto usando OnChar
        p.nameEdit:SetScript("OnChar", function(self, char)
            local text = self:GetText()
            local textLen = text:len()
            local cursor = self:GetCursorPosition()
            
            if cursor == textLen then
                local players = {}
                local seen = {}
                
                if IsInGuild() then
                    for i = 1, GetNumGuildMembers(true) do
                        local name = GetGuildRosterInfo(i)
                        if name then
                            name = name:match("([^%-]+)")
                            if name and not seen[name:lower()] then
                                table.insert(players, name)
                                seen[name:lower()] = true
                            end
                        end
                    end
                end
                
                if RaidDominionDB and RaidDominionDB.Core then
                    for _, band in ipairs(RaidDominionDB.Core) do
                        if band.members then
                            for _, member in ipairs(band.members) do
                                if member.name then
                                    local name = member.name:match("([^%-]+)")
                                    if name and not seen[name:lower()] then
                                        table.insert(players, name)
                                        seen[name:lower()] = true
                                    end
                                end
                            end
                        end
                    end
                end
                
                local searchText = text:lower()
                for _, name in ipairs(players) do
                    if name:lower():find("^" .. searchText) and name:len() > textLen then
                        local extension = name:sub(textLen + 1)
                        self:Insert(extension)
                        self:HighlightText(textLen, name:len())
                        self:SetCursorPosition(textLen)
                        break
                    end
                end
            end
        end)

        p.nameEdit:SetScript("OnEnterPressed", function() p.acceptBtn:Click() end)
        p.nameEdit:SetScript("OnEscapePressed", function() p:Hide() end)
        
        p.acceptBtn = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
        p.acceptBtn:SetSize(100, 25)
        p.acceptBtn:SetPoint("BOTTOMLEFT", 30, 15)
        p.acceptBtn:SetText("Editar")
        p.acceptBtn:SetScript("OnClick", function()
                    local permLevel = GetPerms()
                    if permLevel < 1 then
                        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[RaidDominion]|r Error: No tienes permisos para buscar y editar jugadores.")
                        return
                    end
                    
                    local name = p.nameEdit:GetText()
                    if name and name ~= "" then
                        if RD.utils and RD.utils.coreBands and RD.utils.coreBands.OpenPlayerEditFrame then
                            -- Abrir el editor en modo búsqueda (isSearchMode = true)
                            RD.utils.coreBands.OpenPlayerEditFrame(name, true)
                            p:Hide()
                        else
                            DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[RaidDominion]|r Error: El módulo CoreBands no está disponible.")
                        end
                    end
                end)
    end
    p:Show()
    p.nameEdit:SetText("")
    p.nameEdit:SetFocus()
end

local function AcquireFrame(pool, frameType, parent)
    local frame = table.remove(pool)
    if not frame then
        frame = CreateFrame(frameType, nil, parent)
    else
        frame:SetParent(parent)
        frame:Show()
    end
    return frame
end

local function ReleaseFrame(pool, frame)
    frame:Hide()
    frame:SetParent(nil)
    table.insert(pool, frame)
end

-- Función para renderizar miembros como tarjetas
local function renderRecognitionMembers(recognition, parentFrame)
    if not recognition.members then recognition.members = {} end
    
    -- ORDENAR: Del más reciente al más antiguo basado en el último timestamp
    table.sort(recognition.members, function(a, b)
        local tsA = (a.timestamps and #a.timestamps > 0) and a.timestamps[#a.timestamps] or 0
        local tsB = (b.timestamps and #b.timestamps > 0) and b.timestamps[#b.timestamps] or 0
        return tsA > tsB
    end)

    local xOffset = 0
    local yOffset = 0
    local cardWidth = 178 -- Ajustado para 4 columnas en 730px
    local cardHeight = 20  -- Coincidir con CoreBands
    local spacing = 4
    
    -- Limpiar tarjetas anteriores
    if parentFrame.cards then
        for _, card in ipairs(parentFrame.cards) do
            ReleaseFrame(memberCardPool, card)
        end
    end
    parentFrame.cards = {}
    
    for i, member in ipairs(recognition.members) do
        local card = AcquireFrame(memberCardPool, "Button", parentFrame)
        card:SetSize(cardWidth, cardHeight)
        card:SetPoint("TOPLEFT", 2 + xOffset, -yOffset) -- Pequeño margen izquierdo
        
        card:SetBackdrop({
            bgFile = "Interface/Buttons/WHITE8X8",
            edgeFile = "Interface/Buttons/WHITE8X8",
            tile = true, tileSize = 8, edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 }
        })
        card:SetBackdropColor(0.15, 0.15, 0.2, 1)
        card:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
        
        -- Nombre
        if not card.text then
            card.text = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            card.text:SetPoint("LEFT", 5, 0)
        end
        
        -- Color por clase
        local color = {r=1, g=1, b=1}
        local class = member.class
        
        -- Si no tiene clase o para asegurar que esté actualizada
        local updatedClass = GetPlayerClassData(member.name)
        if updatedClass then
            class = updatedClass
            member.class = updatedClass -- Actualizar en los datos persistentes
        end

        if class and RAID_CLASS_COLORS[class] then
            color = RAID_CLASS_COLORS[class]
        end
        card.text:SetText(member.name)
        card.text:SetTextColor(color.r, color.g, color.b)
        
        -- Tooltip con timestamps
        card:SetScript("OnEnter", function(self)
            if member.timestamps and #member.timestamps > 0 then
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:AddLine("Menciones de " .. member.name, 1, 1, 1)
                for _, ts in ipairs(member.timestamps) do
                    GameTooltip:AddLine(date("%d/%m/%Y %H:%M", ts), 0.7, 0.7, 0.7)
                end
                GameTooltip:Show()
            end
        end)
        card:SetScript("OnLeave", function() GameTooltip:Hide() end)

        -- Clic para abrir edición de jugador (Core) en modo consulta (ocultando controles de banda)
        card:SetScript("OnClick", function()
            if RD.utils.coreBands and RD.utils.coreBands.OpenPlayerEditFrame then
                RD.utils.coreBands.OpenPlayerEditFrame(member.name, true)
            end
        end)
        
        -- Contador
        if not card.countText then
            card.countText = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            card.countText:SetPoint("RIGHT", -40, 0)
        end
        card.countText:SetText("x" .. (member.count or 1))

        -- Botón de Adición (+)
        if not card.addBtn then
            card.addBtn = CreateFrame("Button", nil, card)
            card.addBtn:SetSize(14, 14)
            card.addBtn:SetPoint("RIGHT", -22, 0)
            card.addBtn:SetNormalTexture("Interface/Buttons/UI-PlusButton-Up")
            card.addBtn:SetPushedTexture("Interface/Buttons/UI-PlusButton-Down")
            card.addBtn:SetHighlightTexture("Interface/Buttons/UI-PlusButton-Hilight")
        end
        card.addBtn:SetScript("OnClick", function()
            local permLevel = GetPerms()
            if permLevel < 2 then
                DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[RaidDominion]|r Error: No tienes permisos para añadir menciones.")
                return
            end

            StaticPopupDialogs["RD_CONFIRM_ADD_COUNT"] = {
                text = "¿Deseas aumentar el contador de menciones para " .. member.name .. "?",
                button1 = "Aumentar",
                button2 = "Cancelar",
                OnAccept = function()
                    member.count = (member.count or 1) + 1
                    member.timestamps = member.timestamps or {}
                    table.insert(member.timestamps, time())
                    renderRecognitionMembers(recognition, parentFrame)
                    RefreshRecognitionList()
                end,
                timeout = 0,
                whileDead = true,
                hideOnEscape = true,
            }
            StaticPopup_Show("RD_CONFIRM_ADD_COUNT")
        end)

        -- Botón de Eliminación (-)
        if not card.remBtn then
            card.remBtn = CreateFrame("Button", nil, card)
            card.remBtn:SetSize(14, 14)
            card.remBtn:SetPoint("RIGHT", -5, 0)
            card.remBtn:SetNormalTexture("Interface/Buttons/UI-MinusButton-Up")
            card.remBtn:SetPushedTexture("Interface/Buttons/UI-MinusButton-Down")
            card.remBtn:SetHighlightTexture("Interface/Buttons/UI-MinusButton-Hilight")
        end
        card.remBtn:SetScript("OnClick", function()
            local permLevel = GetPerms()
            if permLevel < 2 then
                DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[RaidDominion]|r Error: No tienes permisos para quitar menciones.")
                return
            end
            
            local function performRemoval()
                member.count = (member.count or 1) - 1
                if member.timestamps and #member.timestamps > 0 then
                    table.remove(member.timestamps)
                end
                
                if member.count <= 0 then
                    for k, v in ipairs(recognition.members) do
                        if v == member then
                            table.remove(recognition.members, k)
                            break
                        end
                    end
                end
                renderRecognitionMembers(recognition, parentFrame)
                RefreshRecognitionList()
            end

            if member.count > 1 then
                StaticPopupDialogs["RD_CONFIRM_SUB_COUNT"] = {
                    text = "¿Deseas disminuir el contador de menciones para " .. member.name .. "?",
                    button1 = "Disminuir",
                    button2 = "Cancelar",
                    OnAccept = performRemoval,
                    timeout = 0,
                    whileDead = true,
                    hideOnEscape = true,
                }
                StaticPopup_Show("RD_CONFIRM_SUB_COUNT")
            else
                StaticPopupDialogs["RD_CONFIRM_REMOVE_MEMBER"] = {
                    text = "¿Deseas eliminar a " .. member.name .. " del reconocimiento?",
                    button1 = "Eliminar",
                    button2 = "Cancelar",
                    OnAccept = performRemoval,
                    timeout = 0,
                    whileDead = true,
                    hideOnEscape = true,
                }
                StaticPopup_Show("RD_CONFIRM_REMOVE_MEMBER")
            end
        end)
        
        table.insert(parentFrame.cards, card)
        
        -- Calcular posición para la siguiente tarjeta (4 columnas)
        if i % 4 == 0 then
            xOffset = 0
            yOffset = yOffset + cardHeight + spacing
        else
            xOffset = xOffset + cardWidth + spacing
        end
    end
    
    local rows = math.ceil(#recognition.members / 4)
    local totalHeight = rows * (cardHeight + spacing)
    return totalHeight > 0 and totalHeight or 0
end

-- Función para refrescar la lista de reconocimientos
RefreshRecognitionList = function()
    local f = _G["RaidDominionRecognitionFrame"]
    if not f or not f:IsVisible() then return end
    
    local data = EnsureRecognitionData()
    
    -- Limpiar frames actuales
    if f.content.lines then
        for _, line in ipairs(f.content.lines) do
            ReleaseFrame(recognitionLinePool, line)
        end
    end
    f.content.lines = {}
    
    local yOffset = 0
    local itemHeight = 45 -- Un poco más alto para los dos botones compuestos
    
    for i, item in ipairs(data) do
        local line = AcquireFrame(recognitionLinePool, "Frame", f.content)
        line:SetSize(730, itemHeight)
        line:SetPoint("TOPLEFT", 0, -yOffset)
        line:EnableMouse(true)
        
        -- Guardar índice
        line.index = i
        
        -- Fondo de la línea
        if not line.bg then
            line.bg = line:CreateTexture(nil, "BACKGROUND")
            line.bg:SetAllPoints()
        end
        
        if selectedRecognitionIndex == i then
            line.bg:SetTexture(0.2, 0.2, 0.4, 0.4)
        else
            line.bg:SetTexture(0, 0, 0, 0.3)
        end

        -- 1. BOTÓN COMPUESTO: NOMBRE (DESPLIEGA)
        if not line.expandBtn then
            line.expandBtn = CreateFrame("Button", nil, line)
            line.expandBtn:SetSize(680, 22)
            line.expandBtn:SetPoint("TOPLEFT", 5, -2)
            
            line.expandBtn.nameText = line.expandBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            line.expandBtn.nameText:SetPoint("LEFT", 5, 0)
            
            local highlight = line.expandBtn:CreateTexture(nil, "HIGHLIGHT")
            highlight:SetAllPoints()
            highlight:SetTexture("Interface/QuestFrame/UI-QuestTitleHighlight")
            highlight:SetBlendMode("ADD")
        end
        
        local memberCount = item.members and #item.members or 0
        line.expandBtn.nameText:SetText(string_format("%s (%d)", item.name, memberCount))
        
        line.expandBtn:SetScript("OnClick", function()
            -- Al desplegar, también seleccionamos
            selectedRecognitionIndex = i
            selectedRecognitionLine = line
            openRecognitionLists[i] = not openRecognitionLists[i]
            RefreshRecognitionList()
        end)

        -- 2. BOTÓN COMPUESTO: DESCRIPCIÓN (EDITA)
        if not line.descBtn then
            line.descBtn = CreateFrame("Button", nil, line)
            line.descBtn:SetSize(680, 18)
            line.descBtn:SetPoint("TOPLEFT", line.expandBtn, "BOTTOMLEFT", 0, 0)
            
            line.descBtn.text = line.descBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            line.descBtn.text:SetPoint("LEFT", 5, 0)
            line.descBtn.text:SetWidth(660)
            line.descBtn.text:SetJustifyH("LEFT")
            
            local highlight = line.descBtn:CreateTexture(nil, "HIGHLIGHT")
            highlight:SetAllPoints()
            highlight:SetTexture("Interface/QuestFrame/UI-QuestTitleHighlight")
            highlight:SetBlendMode("ADD")
            highlight:SetAlpha(0.3)
        end
        
        local desc = item.description or "Sin descripción"
        if #desc > 100 then desc = string_sub(desc, 1, 97) .. "..." end
        line.descBtn.text:SetText(desc)
        
        line.descBtn:SetScript("OnClick", function()
            local permLevel = GetPerms()
            if permLevel < 2 then
                DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[RaidDominion]|r Error: No tienes permisos para editar reconocimientos.")
                return
            end
            
            local editFrame = recognitionUtils.getOrCreateRecognitionFrame()
            editFrame.isEditing = true
            editFrame.editIndex = i
            editFrame.title:SetText("Editar Reconocimiento")
            editFrame.nameEdit:SetText(item.name or "")
            editFrame.descEdit:SetText(item.description or "")
            editFrame:Show()
        end)

        -- 3. CHECKBOX DE SELECCIÓN (DERECHA)
        if not line.check then
            line.check = CreateFrame("CheckButton", nil, line, "UICheckButtonTemplate")
            line.check:SetSize(24, 24)
            line.check:SetPoint("RIGHT", -10, 0)
        end
        
        line.check:SetScript("OnClick", function(self)
            if self:GetChecked() then
                selectedRecognitionIndex = i
                selectedRecognitionLine = line
                -- Desmarcar otros
                for _, otherLine in ipairs(f.content.lines) do
                    if otherLine.index ~= i then
                        otherLine.check:SetChecked(false)
                        otherLine.bg:SetTexture(0, 0, 0, 0.3)
                    end
                end
                line.bg:SetTexture(0.2, 0.2, 0.4, 0.4)
            else
                selectedRecognitionIndex = nil
                selectedRecognitionLine = nil
                line.bg:SetTexture(0, 0, 0, 0.3)
            end
        end)
        
        line.check:SetChecked(selectedRecognitionIndex == i)

        table.insert(f.content.lines, line)
        yOffset = yOffset + itemHeight + 2
        
        -- Si está expandido, mostrar miembros
        if openRecognitionLists[i] then
            if not line.detailsFrame then
                line.detailsFrame = CreateFrame("Frame", nil, line)
                line.detailsFrame:SetWidth(730)
                line.detailsFrame:SetBackdrop({
                    bgFile = "Interface/Buttons/WHITE8X8",
                    tile = true, tileSize = 8,
                })
                line.detailsFrame:SetBackdropColor(0, 0, 0, 0.7)
            end
            line.detailsFrame:SetParent(line)
            line.detailsFrame:SetPoint("TOPLEFT", line, "BOTTOMLEFT", 0, 0)
            line.detailsFrame:Show()
            
            if not line.detailsFrame.membersContainer then
                line.detailsFrame.membersContainer = CreateFrame("Frame", nil, line.detailsFrame)
                line.detailsFrame.membersContainer:SetPoint("TOPLEFT", 5, -5)
                line.detailsFrame.membersContainer:SetWidth(720)
            end
            
            local membersHeight = renderRecognitionMembers(item, line.detailsFrame.membersContainer)
            line.detailsFrame.membersContainer:SetHeight(membersHeight)
            
            local detailsHeight = membersHeight + 10
            line.detailsFrame:SetHeight(detailsHeight)
            yOffset = yOffset + detailsHeight + 2
        elseif line.detailsFrame then
            line.detailsFrame:Hide()
        end
    end
    
    f.content:SetHeight(yOffset)
    
    -- Actualizar Barra de Estado con Top 3
    local counts = {}
    for _, item in ipairs(data) do
        if item.members then
            for _, m in ipairs(item.members) do
                counts[m.name] = (counts[m.name] or 0) + (m.count or 1)
            end
        end
    end
    
    local sorted = {}
    for name, count in pairs(counts) do
        -- Intentar obtener la clase para el color
        local class = GetPlayerClassData(name)
        table.insert(sorted, { name = name, count = count, class = class })
    end
    table.sort(sorted, function(a, b) return a.count > b.count end)
    
    local topText = "|cff00ff00Top Reconocimientos:|r "
    if #sorted > 0 then
        for i = 1, math.min(3, #sorted) do
            local player = sorted[i]
            local colorStr = "ffffff"
            if i == 1 then colorStr = "ffff00" -- Oro
            elseif i == 2 then colorStr = "c0c0c0" -- Plata
            elseif i == 3 then colorStr = "cd7f32" -- Bronce
            end
            
            local classColor = "ffffff"
            if player.class and RAID_CLASS_COLORS[player.class] then
                local c = RAID_CLASS_COLORS[player.class]
                classColor = string_format("%02x%02x%02x", c.r*255, c.g*255, c.b*255)
            end

            topText = topText .. string_format("|cff%s%d.|r |cff%s%s|r |cffffffff(%d)|r  ", colorStr, i, classColor, player.name, player.count)
        end
    else
        topText = topText .. "Sin datos"
    end
    f.statusText:SetText(topText)
end

-- Función para obtener o crear el frame del formulario
function recognitionUtils.getOrCreateRecognitionFrame()
    local f = _G["RaidDominionRecognitionCreateFrame"]
    if not f then
        f = CreateFrame("Frame", "RaidDominionRecognitionCreateFrame", UIParent)
        f:SetSize(300, 250)
        f:SetPoint("CENTER")
        f:SetFrameStrata("DIALOG")
        f:SetToplevel(true)
        f:SetBackdrop({
            bgFile = "Interface/Tooltips/UI-Tooltip-Background",
            edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 }
        })
        f:SetBackdropColor(0, 0, 0, 0.9)
        f:SetBackdropBorderColor(1, 1, 1, 0.5)
        f:EnableMouse(true)
        f:SetMovable(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)

        tinsert(UISpecialFrames, "RaidDominionRecognitionCreateFrame")

        f.title = UI.CreateLabel(f, "Nuevo Reconocimiento", "GameFontNormal")
        f.title:SetPoint("TOP", 0, -15)

        -- Campo Nombre
        f.nameLabel = UI.CreateLabel(f, "Nombre:")
        f.nameLabel:SetPoint("TOPLEFT", 20, -50)
        f.nameEdit = UI.CreateEditBox(nil, f, 260, 25)
        f.nameEdit:SetPoint("TOPLEFT", 20, -70)

        -- Campo Descripción
        f.descLabel = UI.CreateLabel(f, "Descripción:")
        f.descLabel:SetPoint("TOPLEFT", 20, -110)
        f.descEdit = UI.CreateEditBox(nil, f, 260, 60)
        f.descEdit:SetPoint("TOPLEFT", 20, -130)
        f.descEdit:SetMultiLine(true)

        -- Botón Guardar
        f.saveBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        f.saveBtn:SetSize(100, 25)
        f.saveBtn:SetPoint("BOTTOMLEFT", 40, 20)
        f.saveBtn:SetText("Guardar")
        f.saveBtn:SetScript("OnClick", function()
            local permLevel = GetPerms()
            if permLevel < 2 then
                DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[RaidDominion]|r Error: No tienes permisos para guardar reconocimientos.")
                return
            end
            
            local name = f.nameEdit:GetText()
            local desc = f.descEdit:GetText()
            if name == "" then
                DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[RaidDominion]|r Error: El nombre es obligatorio.")
                return
            end
            
            local data = EnsureRecognitionData()
            if f.isEditing and f.editIndex then
                data[f.editIndex].name = name
                data[f.editIndex].description = desc
            else
                table.insert(data, {
                    name = name,
                    description = desc,
                    members = {}
                })
            end
            f:Hide()
            RefreshRecognitionList()
        end)

        -- Botón Cancelar
        f.cancelBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        f.cancelBtn:SetSize(100, 25)
        f.cancelBtn:SetPoint("BOTTOMRIGHT", -40, 20)
        f.cancelBtn:SetText("Cancelar")
        f.cancelBtn:SetScript("OnClick", function() f:Hide() end)
    end
    return f
end

-- Función para crear botones estilizados (Boilerplate)
local function CreateStyledButton(name, parent, width, height, text, iconPath, tooltipText)
    local button = CreateFrame("Button", name, parent)
    button:SetSize(width, height)
    
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexture(iconPath)
    button.icon = icon
    
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetTexture("Interface/Buttons/ButtonHilight-Square")
    highlight:SetBlendMode("ADD")
    
    if text then
        local label = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("BOTTOM", 0, -12)
        label:SetText(text)
    end
    
    if tooltipText then
        button:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(tooltipText, 1, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    
    return button
end

-- Función para mostrar la ventana de Reconocimiento
function recognitionUtils.ShowRecognitionWindow()
    local f = _G["RaidDominionRecognitionFrame"]
    if not f then
        f = CreateFrame("Frame", "RaidDominionRecognitionFrame", UIParent)
        f:SetFrameStrata("MEDIUM")
        f:SetToplevel(true)
        f:SetSize(790, 440)
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
        
        tinsert(UISpecialFrames, "RaidDominionRecognitionFrame")
        
        -- Título
        local guildName = GetGuildInfo("player") or ""
        f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        f.title:SetPoint("TOP", 0, -15)
        f.title:SetText("RaidDominion - Reconocimiento " .. guildName)
        
        -- Botón Cerrar
        f.closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        f.closeBtn:SetPoint("TOPRIGHT", -5, -5)
        f.closeBtn:SetScript("OnClick", function() f:Hide() end)
        
        -- Botón Izquierda: Crear, Compartir
        f.createBtn = CreateStyledButton("RDRecognitionCreateBtn", f, 30, 30, nil, "Interface/Icons/Spell_ChargePositive", "Crear Nuevo")
        f.createBtn:SetPoint("TOPLEFT", 20, -35)
        f.createBtn:SetScript("OnClick", function()
            local permLevel = GetPerms()
            if permLevel < 2 then
                DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[RaidDominion]|r Error: No tienes permisos para crear reconocimientos.")
                return
            end
            local createFrame = recognitionUtils.getOrCreateRecognitionFrame()
            createFrame.isEditing = false
            createFrame.editIndex = nil
            createFrame.title:SetText("Nuevo Reconocimiento")
            createFrame.nameEdit:SetText("")
            createFrame.descEdit:SetText("")
            createFrame:Show()
        end)
        
        f.shareBtn = CreateStyledButton("RDRecognitionShareBtn", f, 30, 30, nil, "Interface/Icons/Spell_Arcane_StudentOfMagic", "Compartir")
        f.shareBtn:SetPoint("LEFT", f.createBtn, "RIGHT", 10, 0)
        f.shareBtn:SetScript("OnClick", function()
            local permLevel = GetPerms()
            if permLevel < 2 then
                DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[RaidDominion]|r Error: No tienes permisos para compartir reconocimientos.")
                return
            end
            -- Lógica de compartir (pendiente)
            DEFAULT_CHAT_FRAME:AddMessage("|cffffff00[RaidDominion]|r Lógica de compartir no implementada aún.")
        end)

        -- Botones Derecha: Añadir, Subir, Bajar, Duplicar, Eliminar (Orden estilo Core)
        f.headerButtonsFrame = CreateFrame("Frame", nil, f)
        f.headerButtonsFrame:SetSize(250, 35)
        f.headerButtonsFrame:SetPoint("TOPRIGHT", -40, -35)

        -- Botón Añadir (Antes "Invitar")
        f.addPlayerBtn = CreateStyledButton("RDRecognitionAddPlayerBtn", f.headerButtonsFrame, 30, 30, nil, "Interface/Icons/INV_Misc_GroupLooking", "Añadir Jugador")
        f.addPlayerBtn:SetPoint("RIGHT", 0, 0)
        f.addPlayerBtn:SetScript("OnClick", function()
            local permLevel = GetPerms()
            if permLevel < 2 then
                DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[RaidDominion]|r Error: No tienes permisos para añadir jugadores.")
                return
            end
            
            if not selectedRecognitionIndex then
                DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[RaidDominion]|r Error: Debes seleccionar un reconocimiento primero.")
                return
            end

            local targetName = UnitName("target")
            if targetName and UnitIsPlayer("target") then
                local _, targetClass = UnitClass("target")
                addPlayerToRecognition(selectedRecognitionIndex, {
                    name = targetName,
                    class = targetClass
                })
            else
                local invitePopup = getOrCreateInvitePopup()
                invitePopup:Show()
            end
        end)

        f.upBtn = CreateStyledButton("RDRecognitionUpBtn", f.headerButtonsFrame, 30, 30, nil, "Interface/Icons/Spell_ChargePositive", "Subir")
        f.upBtn:SetPoint("RIGHT", f.addPlayerBtn, "LEFT", -10, 0)
        f.upBtn:SetScript("OnClick", function()
            local permLevel = GetPerms()
            if permLevel < 2 then
                DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[RaidDominion]|r Error: No tienes permisos para reordenar reconocimientos.")
                return
            end

            local data = EnsureRecognitionData()
            for i = 2, #data do
                local line = f.content.lines[i]
                if line and line.check:GetChecked() then
                    local temp = data[i]
                    data[i] = data[i-1]
                    data[i-1] = temp
                end
            end
            RefreshRecognitionList()
        end)

        f.downBtn = CreateStyledButton("RDRecognitionDownBtn", f.headerButtonsFrame, 30, 30, nil, "Interface/Icons/Spell_ChargeNegative", "Bajar")
        f.downBtn:SetPoint("RIGHT", f.upBtn, "LEFT", -10, 0)
        f.downBtn:SetScript("OnClick", function()
            local permLevel = GetPerms()
            if permLevel < 2 then
                DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[RaidDominion]|r Error: No tienes permisos para reordenar reconocimientos.")
                return
            end

            local data = EnsureRecognitionData()
            for i = #data - 1, 1, -1 do
                local line = f.content.lines[i]
                if line and line.check:GetChecked() then
                    local temp = data[i]
                    data[i] = data[i+1]
                    data[i+1] = temp
                end
            end
            RefreshRecognitionList()
        end)

        f.duplicateBtn = CreateStyledButton("RDRecognitionDuplicateBtn", f.headerButtonsFrame, 30, 30, nil, "Interface/Icons/Spell_Holy_PrayerOfHealing02", "Duplicar")
        f.duplicateBtn:SetPoint("RIGHT", f.downBtn, "LEFT", -10, 0)
        f.duplicateBtn:SetScript("OnClick", function()
            local permLevel = GetPerms()
            if permLevel < 2 then
                DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[RaidDominion]|r Error: No tienes permisos para duplicar reconocimientos.")
                return
            end

            local data = EnsureRecognitionData()
            local itemsToDuplicate = {}
            for i, item in ipairs(data) do
                local line = f.content.lines[i]
                if line and line.check:GetChecked() then
                    table.insert(itemsToDuplicate, item)
                end
            end

            if #itemsToDuplicate == 0 then
                DEFAULT_CHAT_FRAME:AddMessage("|cffffff00[RaidDominion]|r Debes seleccionar al menos un elemento para duplicar.")
                return
            end

            StaticPopupDialogs["RD_CONFIRM_DUPLICATE_RECOGNITION"] = {
                text = "¿Deseas duplicar los reconocimientos seleccionados?",
                button1 = "Duplicar",
                button2 = "Cancelar",
                OnAccept = function()
                    for _, item in ipairs(itemsToDuplicate) do
                        table.insert(data, {
                            name = item.name .. " (Copia)",
                            description = item.description,
                            members = item.members and {unpack(item.members)} or {}
                        })
                    end
                    RefreshRecognitionList()
                end,
                timeout = 0,
                whileDead = true,
                hideOnEscape = true,
            }
            StaticPopup_Show("RD_CONFIRM_DUPLICATE_RECOGNITION")
        end)

        f.deleteBtn = CreateStyledButton("RDRecognitionDeleteBtn", f.headerButtonsFrame, 30, 30, nil, "Interface/Icons/Spell_Shadow_SacrificialShield", "Eliminar")
        f.deleteBtn:SetPoint("RIGHT", f.duplicateBtn, "LEFT", -10, 0)
        f.deleteBtn:SetScript("OnClick", function()
            local permLevel = GetPerms()
            if permLevel < 2 then
                DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[RaidDominion]|r Error: No tienes permisos para eliminar reconocimientos.")
                return
            end

            -- Buscar seleccionados
            local data = EnsureRecognitionData()
            local selectedIndices = {}
            for i = #data, 1, -1 do
                local line = f.content.lines[i]
                if line and line.check:GetChecked() then
                    table.insert(selectedIndices, i)
                end
            end

            if #selectedIndices == 0 then
                DEFAULT_CHAT_FRAME:AddMessage("|cffffff00[RaidDominion]|r Debes seleccionar al menos un elemento para eliminar.")
                return
            end

            StaticPopupDialogs["RD_CONFIRM_DELETE_RECOGNITION"] = {
                text = "¿Deseas eliminar los reconocimientos seleccionados?",
                button1 = "Eliminar",
                button2 = "Cancelar",
                OnAccept = function()
                    for _, index in ipairs(selectedIndices) do
                        table.remove(data, index)
                    end
                    selectedRecognitionIndex = nil
                    selectedRecognitionLine = nil
                    RefreshRecognitionList()
                end,
                timeout = 0,
                whileDead = true,
                hideOnEscape = true,
            }
            StaticPopup_Show("RD_CONFIRM_DELETE_RECOGNITION")
        end)
        
        -- Área de Scroll
        f.scroll = CreateFrame("ScrollFrame", "RDRecognitionScroll", f, "UIPanelScrollFrameTemplate")
        f.scroll:SetPoint("TOPLEFT", 20, -75)
        f.scroll:SetPoint("BOTTOMRIGHT", -35, 35)
        
        f.content = CreateFrame("Frame", nil, f.scroll)
        f.content:SetSize(730, 1)
        f.scroll:SetScrollChild(f.content)
        f.content.lines = {}
        
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
        f.statusText:SetText("Listo")
    end
    
    RefreshRecognitionList()
    f:Show()
end
