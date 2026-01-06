--[[
    RD_MenuActions.lua
    PROPÓSITO: Maneja las acciones del menú y su registro.
    DEPENDENCIAS: RD_Constants.lua
    API PÚBLICA:
        - RD.MenuActions.Register(name, action)
        - RD.MenuActions.Execute(name, ...)
        - RD.MenuActions.Exists(name)
]]

-- Asegurarse de que RaidDominion está disponible globalmente
local RD = _G["RaidDominion"] or {}
_G["RaidDominion"] = RD

-- Inicializar las tablas necesarias
RD.UI = RD.UI or {}
RD.UI.DynamicMenus = RD.UI.DynamicMenus or {}
RD.config = RD.config or {}
RD.constants = RD.constants or {}

-- Obtener el messageManager
local messageManager = RD.modules and RD.modules.messageManager

-- Módulo de acciones del menú
local MenuActions = {}
RD.MenuActions = MenuActions

-- Registro de acciones
local actions = {}


--[[
    Registra una nueva acción de menú
    @param name string Nombre de la acción
    @param action function Función a ejecutar
    @param options table Opciones adicionales (opcional)
]]
function MenuActions.Register(name, action, options)
    if type(name) ~= "string" then
        error("MenuActions.Register: name must be a string", 2)
    end
    
    if type(action) ~= "function" then
        error("MenuActions.Register: action must be a function", 2)
    end
    
    actions[name] = {
        func = action,
        options = options or {}
    }
    return true
end

--[[
    Ejecuta una acción de menú
    @param name string Nombre de la acción
    @param ... Argumentos para la acción
    @return boolean, any Éxito y resultado de la acción
]]
function MenuActions:Execute(name, ...)
    local actionName
    if type(name) == "table" then
        actionName = name.action or name.name
    else
        actionName = name
    end
    
    actionName = tostring(actionName or "")
    
    local action = actions[actionName]
    if not action then
        return false, "Acción no encontrada"
    end
    
    local success, result = pcall(action.func, ...)
    if not success then
        -- Error is already caught by pcall, just return it
    end
    
    return success, result
end

--[[
    Verifica si una acción existe
]]
function MenuActions.Exists(name)
    return actions[name] ~= nil
end

--[[
    Maneja la selección de un rol (función auxiliar)
]]
function MenuActions.HandleRoleSelection(role)
    if not role or not role.id then return end
    
    if RaidDominion.modules and RaidDominion.modules.messageManager and RaidDominion.modules.messageManager.SendItemAnnouncement then
        RaidDominion.modules.messageManager:SendItemAnnouncement("roles", role.name, "NEED")
    end
    
    if RD.config and RD.config.Set then
        RD.config:Set("lastSelectedRole", role.id)
    end
    local targetName = UnitName("target")
    -- Mantener el menú abierto
end

--[[
    Funciones auxiliares para selección en otros menús
]]
function MenuActions.HandleAbilitySelection(item)

    if RaidDominion.modules and RaidDominion.modules.messageManager and RaidDominion.modules.messageManager.SendItemAnnouncement then
        RaidDominion.modules.messageManager:SendItemAnnouncement("abilities", item.name, "NEED")
    end
    local targetName = UnitName("target")
    -- Mantener el menú abierto
end

function MenuActions.HandleBuffSelection(item)

    if RaidDominion.modules and RaidDominion.modules.messageManager and RaidDominion.modules.messageManager.SendItemAnnouncement then
        RaidDominion.modules.messageManager:SendItemAnnouncement("buffs", item.name, "NEED")
    end
    local targetName = UnitName("target")
    -- Mantener el menú abierto
end

function MenuActions.HandleAuraSelection(item)

    if RaidDominion.modules and RaidDominion.modules.messageManager and RaidDominion.modules.messageManager.SendItemAnnouncement then
        RaidDominion.modules.messageManager:SendItemAnnouncement("auras", item.name, "NEED")
    end
    local targetName = UnitName("target")
    -- Mantener el menú abierto
end

--[[
    Registra las acciones por defecto
]]
local function GetGuildMemberRank(name)
    local numTotalMembers = GetNumGuildMembers(true)
    for i = 1, numTotalMembers do
        local memberName, rank = GetGuildRosterInfo(i)
        if memberName == name then
            return rank
        end
    end
    return "Rango"
end

local function GetOnlineGuildMembers(ranks)
    local numTotalMembers, _, _ = GetNumGuildMembers(true)
    local onlineMembers = {}

    for i = 1, numTotalMembers do
        local name, _, rankIndex, _, _, _, _, _, isOnline = GetGuildRosterInfo(i)
        if isOnline and (not ranks or tContains(ranks, rankIndex + 1)) then -- rankIndex is 0-based
            table.insert(onlineMembers, name)
        end
    end

    return onlineMembers
end

local selectedGuildBankItem = nil

-- Mover la función PerformGuildRoulette antes de OpenGuildBankAndGetItems
local function PerformGuildRoulette()
    if not selectedGuildBankItem then
        return
    end

    -- Obtener constantes
    local CONST = RD.constants.GUILD_LOTTERY
    local MSG = CONST.MESSAGES
    local SETTINGS = CONST.SETTINGS

    -- Obtener miembros en línea de los rangos elegibles
    local onlineMembers = GetOnlineGuildMembers(CONST.ELIGIBLE_RANKS)

    if #onlineMembers == 0 then
        SendSystemMessage(MSG.NO_ELIGIBLE_MEMBERS)
        return
    end

    -- Seleccionar jugadores aleatorios con sus rangos
    local selectedPlayers = {}
    if #onlineMembers <= SETTINGS.MAX_PLAYERS then
        -- Si hay menos jugadores que el máximo, tomarlos a todos con sus rangos
        for i = 1, #onlineMembers do
            local name = onlineMembers[i]
            local rankName = GetGuildMemberRank(name)
            table.insert(selectedPlayers, { name = name, rank = rankName })
        end
    else
        -- Si hay más jugadores que el máximo, seleccionar al azar
        local tempTable = {}
        for i = 1, #onlineMembers do
            local name = onlineMembers[i]
            local rankName = GetGuildMemberRank(name)
            table.insert(tempTable, { name = name, rank = rankName })
        end

        for i = 1, SETTINGS.MAX_PLAYERS do
            if #tempTable == 0 then
                break
            end
            local randomIndex = math.random(1, #tempTable)
            table.insert(selectedPlayers, tempTable[randomIndex])
            table.remove(tempTable, randomIndex)
        end
    end

    -- Formatear texto del ítem
    local itemText = string.format("%s (x%d)", selectedGuildBankItem.link, selectedGuildBankItem.count)

    -- Preparar mensajes del sorteo
    local messages = {
        MSG.LOTTERY_HEADER,
        string.format(MSG.LOTTERY_ITEM, itemText),
        MSG.LOTTERY_PARTICIPANTS,
        "",
    }

    -- Añadir mensaje de "Sorteando..."
    table.insert(messages, MSG.LOTTERY_DRAWING)

    -- Generar puntajes aleatorios
    local scores = {}
    local maxScore = 0
    local winnerIndex = 1

    for i = 1, #selectedPlayers do
        scores[i] = math.random(1, SETTINGS.MAX_SCORE)
        if scores[i] > maxScore then
            maxScore = scores[i]
            winnerIndex = i
        end
    end

    -- Ordenar jugadores por puntaje (de mayor a menor)
    local sortedIndices = {}
    for i = 1, #selectedPlayers do
        table.insert(sortedIndices, i)
    end
    table.sort(sortedIndices, function(a, b)
        return scores[a] > scores[b]
    end)

    -- Mostrar resultados ordenados
    for _, idx in ipairs(sortedIndices) do
        local member = selectedPlayers[idx]
        if idx == winnerIndex then
            table.insert(messages, string.format(
                MSG.LOTTERY_WINNER_SCORE,
                member.rank,
                member.name,
                scores[idx]
            ))
        else
            table.insert(messages, string.format(
                MSG.LOTTERY_SCORE,
                member.rank,
                member.name,
                scores[idx]
            ))
        end
    end

    local winner = selectedPlayers[winnerIndex]

    -- Añadir mensaje del ganador
    table.insert(messages, string.format(
        MSG.LOTTERY_WINNER,
        winner.rank,
        winner.name,
        itemText
    ))

    -- Enviar todos los mensajes con retraso
    SendDelayedMessages(messages, "GUILD")

    -- Enviar mensaje privado al ganador
    SendChatMessage(
        string.format(MSG.WINNER_MESSAGE, selectedGuildBankItem.link, selectedGuildBankItem.count),
        "WHISPER",
        nil,
        winner.name
    )
    SendChatMessage(
        MSG.WINNER_FOLLOW_UP,
        "WHISPER",
        nil,
        winner.name
    )

    -- Reproducir sonido de victoria
    PlaySoundFile(MSG.SOUND_WIN)

    -- Limpiar el ítem seleccionado
    selectedGuildBankItem = nil
end

local function OpenGuildBankAndGetItems()
    -- Obtener constantes
    local CONST = RD.constants.GUILD_LOTTERY
    local MSG = CONST.MESSAGES
    local DIALOG = CONST.DIALOG
    local SETTINGS = CONST.SETTINGS

    -- Verificar membresía y permisos
    if not IsInGuild() then
        SendSystemMessage(MSG.NOT_IN_GUILD)
        return
    end

    if not CanGuildBankRepair() then
        SendSystemMessage(MSG.NO_GUILD_BANK_ACCESS)
        return
    end

    -- Abrir el banco de la hermandad si no está abierto
    if not GuildBankFrame:IsShown() then
        ShowUIPanel(GuildBankFrame)
    end

    -- Crear un frame para manejar el temporizador de carga
    local frame = CreateFrame("Frame")
    frame.elapsed = 0
    frame:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = self.elapsed + elapsed
        if self.elapsed >= 1 then -- Esperar 1 segundo para que se carguen los ítems
            self:SetScript("OnUpdate", nil)

            local tabItems = {}
            local tab = SETTINGS.TAB_INDEX

            -- Obtener información de la pestaña
            local name, icon, isViewable = GetGuildBankTabInfo(tab)

            if not isViewable then
                SendSystemMessage(MSG.NO_TAB_ACCESS)
                return
            end

            -- Recorrer los espacios de la pestaña (máx. 98 por pestaña)
            for slot = 1, 98 do
                local itemLink = GetGuildBankItemLink(tab, slot)
                if itemLink then
                    local itemName, _, _, _, _, _, _, _, _, itemTexture = GetItemInfo(itemLink)
                    local _, _, count = GetGuildBankItemInfo(tab, slot)

                    table.insert(tabItems, {
                        link = itemLink,
                        name = itemName,
                        texture = itemTexture,
                        count = count or 1,
                        slot = slot,
                    })
                end
            end

            if #tabItems == 0 then
                SendSystemMessage(MSG.NO_ITEMS)
                return
            end

            -- Seleccionar un ítem aleatorio
            selectedGuildBankItem = tabItems[math.random(1, #tabItems)]

            -- Mostrar diálogo de confirmación con opción de elegir otro ítem
            local dialog = StaticPopup_Show("CONFIRM_GUILD_BANK_ITEM", selectedGuildBankItem.name, selectedGuildBankItem.count)
            if dialog then
                dialog.data = {
                    OnAccept = function()
                        PerformGuildRoulette()
                    end,
                    OnCancel = function()
                        -- No hacer nada, simplemente cerrar el diálogo
                    end,
                    OnAlt = function()
                        -- Elegir otro ítem
                        OpenGuildBankAndGetItems()
                    end
                }
                -- Configurar el escape para que llame a OnAlt
                dialog:SetScript("OnKeyDown", function(self, key)
                    if key == "ESCAPE" then
                        if self.data and self.data.OnAlt then
                            self.data.OnAlt()
                        end
                        self:Hide()
                    end
                end)
            end
        end
    end)
end

-- La función PerformGuildRoulette ha sido movida más arriba en el archivo

local function GuildLottery()
    -- Obtener constantes
    local MSG = RD.constants.GUILD_LOTTERY.MESSAGES

    -- Verificar permisos de oficial o líder de hermandad
    local rankIndex = select(3, GetGuildInfo("player"))
    local _, _, _, _, _, _, _, _, isGuildLeader = GetGuildRosterInfo(rankIndex)

    if not isGuildLeader and not CanGuildPromote() then
        SendSystemMessage(MSG.NOT_AUTHORIZED)
        return
    end

    -- Verificar membresía y permisos
    if not IsInGuild() then
        SendSystemMessage(MSG.NOT_IN_GUILD)
        return
    end

    if not CanGuildBankRepair() then
        SendSystemMessage(MSG.NO_GUILD_BANK_ACCESS)
        return
    end

    -- Abrir el banco de la hermandad si no está abierto
    if not GuildBankFrame:IsShown() then
        ShowUIPanel(GuildBankFrame)
    end

    -- Iniciar el escaneo de ítems
    OpenGuildBankAndGetItems()
end

function MenuActions.RegisterDefaultActions()

    
    -- Función generadora para abrir menús
    local function OpenMenuAction(menuType)
        return function()
            -- Cargar/Inicializar DynamicMenus si es necesario
            if not RD.UI.DynamicMenus or not RD.UI.DynamicMenus.GetMenu then
                if not IsAddOnLoaded("RD_UI_DynamicMenus") then
                    LoadAddOn("RD_UI_DynamicMenus")
                end
                -- Intentar inicializar manualmente si existe la tabla pero no está lista
                if RD.UI.DynamicMenus and RD.UI.DynamicMenus.Initialize then
                    RD.UI.DynamicMenus:Initialize()
                end
            end
            
            if not RD.UI.DynamicMenus or not RD.UI.DynamicMenus.GetMenu then
                return
            end
            
            local menu = RD.UI.DynamicMenus:GetMenu(menuType)
            if menu then
                -- Ocultar menú principal
                if RD.ui and RD.ui.mainFrame and RD.ui.mainFrame.Hide then
                    RD.ui.mainFrame:Hide()
                end
                
                -- Mostrar menú dinámico
                menu:Show()
                menu:Raise()
                
                -- Forzar actualización
                if menu.Update then menu:Update() end
            else

            end
        end
    end
    
    -- Registrar acciones que coincidan con RD_Constants.lua
    MenuActions.Register("Roles", OpenMenuAction("roles"))
    MenuActions.Register("ShowSkills", OpenMenuAction("abilities"))
    MenuActions.Register("ShowBuffs", OpenMenuAction("buffs"))
    MenuActions.Register("ShowAuras", OpenMenuAction("auras"))
    
    -- Acciones adicionales
    MenuActions.Register("ShowRaidRules", function()
        if RD.UI and RD.UI.DynamicMenus and RD.UI.DynamicMenus.GetMenu then
            local m = RD.UI.DynamicMenus:GetMenu("raidrules")
            if RD.ui and RD.ui.mainFrame and RD.ui.mainFrame.Show then RD.ui.mainFrame:Show() end
            if m and m.Show then m:Show() end
            if m and m.Update then m:Update() end
            if m and m.Raise then m:Raise() end
        end
    end)
    MenuActions.Register("ShowBossMechanics", function()
        if RD.UI and RD.UI.DynamicMenus and RD.UI.DynamicMenus.GetMenu then
            local m = RD.UI.DynamicMenus:GetMenu("mechanics")
            if RD.ui and RD.ui.mainFrame and RD.ui.mainFrame.Show then RD.ui.mainFrame:Show() end
            if m and m.Show then m:Show() end
            if m and m.Update then m:Update() end
            if m and m.Raise then m:Raise() end
        end
    end)
    MenuActions.Register("ShowRaidDominion", function()
        if RD.UI and RD.UI.DynamicMenus and RD.UI.DynamicMenus.GetMenu then
            local m = RD.UI.DynamicMenus:GetMenu("addonOptions")
            if RD.ui and RD.ui.mainFrame and RD.ui.mainFrame.Show then RD.ui.mainFrame:Show() end
            if m and m.Show then m:Show() end
            if m and m.Update then m:Update() end
            if m and m.Raise then m:Raise() end
            return
        end
        if RD.ui and RD.ui.menu and RD.ui.menu.NavigateTo then
            RD.ui.menu:NavigateTo("addonOptions")
            if RD.ui.menu.Show then RD.ui.menu:Show() end
            return
        end
        if RD.ui and RD.ui.configManager then RD.ui.configManager:Toggle() end
    end)
    MenuActions.Register("ShowGuild", function()
        if RD.UI and RD.UI.DynamicMenus and RD.UI.DynamicMenus.GetMenu then
            local m = RD.UI.DynamicMenus:GetMenu("guildOptions")
            if RD.ui and RD.ui.mainFrame and RD.ui.mainFrame.Show then RD.ui.mainFrame:Show() end
            if m and m.Show then m:Show() end
            if m and m.Update then m:Update() end
            if m and m.Raise then m:Raise() end
            return
        end
        if RD.ui and RD.ui.menu and RD.ui.menu.NavigateTo then
            RD.ui.menu:NavigateTo("guildOptions")
            if RD.ui.menu.Show then RD.ui.menu:Show() end
        end
    end)
    
    -- Submenús: acciones básicas
    MenuActions.Register("ReloadUI", function() ReloadUI() end)
    MenuActions.Register("HideMainFrame", function() if RD.ui and RD.ui.mainFrame and RD.ui.mainFrame.Hide then RD.ui.mainFrame:Hide() end end)
    MenuActions.Register("ShowHelp", function()
        local cm = RD.ui and RD.ui.configManager
        if cm and cm.Show then
            cm:Show()
            if cm.SelectTabById then
                cm:SelectTabById("help")
            else
                cm:SelectTab(1)
            end
            return
        end
        if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
            DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99[RaidDominion]|r Abre la configuración con /rdc")
        end
    end)
    MenuActions.Register("CloseMenu", function()
        if RD.ui and RD.ui.menu and RD.ui.menu.Hide then RD.ui.menu:Hide() end
    end)
    MenuActions.Register("ShowOptions", function()
        if RD.ui and RD.ui.configManager then RD.ui.configManager:Toggle() end
    end)
    
    -- Acciones de Hermandad (placeholders funcionales)
    MenuActions.Register("GuildMessages", function()
        if RD.UI and RD.UI.DynamicMenus and RD.UI.DynamicMenus.GetMenu then
            local m = RD.UI.DynamicMenus:GetMenu("guildmessages")
            if RD.ui and RD.ui.mainFrame and RD.ui.mainFrame.Show then RD.ui.mainFrame:Show() end
            if m and m.Show then m:Show() end
            if m and m.Update then m:Update() end
            if m and m.Raise then m:Raise() end
        end
    end)
    MenuActions.Register("GuildLottery", function() end)
    MenuActions.Register("GuildRoster", function() 
        -- Registrar diálogo de confirmación de promoción
        if not StaticPopupDialogs["RAID_DOMINION_CONFIRM_PROMOTE"] then
            StaticPopupDialogs["RAID_DOMINION_CONFIRM_PROMOTE"] = {
                text = "¿Deseas promover a %s a Iniciado?",
                button1 = YES,
                button2 = NO,
                OnAccept = function(self)
                    GuildPromote(self.data.name)
                end,
                timeout = 0,
                whileDead = 1,
                hideOnEscape = 1,
                preferredIndex = 3,
            }
        end

        -- Registrar el diálogo de edición de nota si no existe
        if not StaticPopupDialogs["RAID_DOMINION_EDIT_GUILD_NOTE"] then
            StaticPopupDialogs["RAID_DOMINION_EDIT_GUILD_NOTE"] = {
                text = "Editar nota pública de %s",
                button1 = ACCEPT,
                button2 = CANCEL,
                hasEditBox = 1,
                maxLetters = 31,
                OnShow = function(self)
                    local currentNote = ""
                    if self.data and self.data.currentNote then
                        currentNote = self.data.currentNote
                    end
                    self.editBox:SetText(currentNote)
                    self.editBox:SetFocus()
                end,
                OnAccept = function(self)
                    local text = self.editBox:GetText()
                    local index = self.data.index
                    local name = self.data.name
                    local wasEmpty = (self.data.currentNote == nil or self.data.currentNote == "")
                    
                    GuildRosterSetPublicNote(index, text)
                    
                    -- Si no tenía nota y ahora tiene, preguntar si promover
                    if wasEmpty and text ~= "" then
                        local dialog = StaticPopup_Show("RAID_DOMINION_CONFIRM_PROMOTE", name)
                        if dialog then
                            dialog.data = { index = index, name = name }
                        end
                    end
                end,
                EditBoxOnEnterPressed = function(self)
                    local parent = self:GetParent()
                    local text = parent.editBox:GetText()
                    local index = parent.data.index
                    local name = parent.data.name
                    local wasEmpty = (parent.data.currentNote == nil or parent.data.currentNote == "")
                    
                    GuildRosterSetPublicNote(index, text)
                    parent:Hide()
                    
                    if wasEmpty and text ~= "" then
                        local dialog = StaticPopup_Show("RAID_DOMINION_CONFIRM_PROMOTE", name)
                        if dialog then
                            dialog.data = { index = index, name = name }
                        end
                    end
                end,

                timeout = 0,
                whileDead = 1,
                hideOnEscape = 1
            }
        end

        -- Obtener la lista de miembros de la hermandad
        -- Obtener la lista de miembros de la hermandad y datos de KRT
        local guildMembers, updatesNeeded, krtData = RD.utils.group.GetGuildMemberList()
        
        -- Mostrar un mensaje con el resultado
        if #guildMembers > 0 then
            local message = "Lista de miembros de la hermandad actualizada. Total: " .. #guildMembers
            if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
                DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99[RaidDominion]|r " .. message)
            end
            
            -- Filtrar jugadores que tienen GearScore y Nota Pública
            local playersWithData = {}
            -- Filtrar jugadores que tienen GearScore pero NO tienen Nota Pública
            local playersNoNote = {}
            
            for _, member in ipairs(guildMembers) do
                if member.gearScore and member.gearScore > 0 then
                    if member.publicNote and member.publicNote ~= "" then
                        table.insert(playersWithData, member)
                    else
                        table.insert(playersNoNote, member)
                    end
                end
            end
            
            -- Si hay jugadores con datos, mostrar una ventana con la lista
            if #playersWithData > 0 then
                if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
                    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99[RaidDominion]|r Se encontraron " .. #playersWithData .. " jugadores con GS y Nota.")
                end
                
                -- Crear marco para mostrar la lista
                local f = _G["RaidDominionUpdateListFrame"]
                if not f then
                    f = CreateFrame("Frame", "RaidDominionUpdateListFrame", UIParent)
                    f:SetSize(450, 400)
                    f:SetPoint("CENTER", -230, 0) -- Mover a la izquierda
                    f:SetBackdrop({
                        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
                        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
                        tile = true, tileSize = 32, edgeSize = 32,
                        insets = { left = 11, right = 12, top = 12, bottom = 11 }
                    })
                    f:SetBackdropColor(0, 0, 0, 0.9)
                    f:EnableMouse(true)
                    f:SetMovable(true)
                    f:RegisterForDrag("LeftButton")
                    f:SetScript("OnDragStart", f.StartMoving)
                    f:SetScript("OnDragStop", f.StopMovingOrSizing)
                    
                    -- Título
                    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                    f.title:SetPoint("TOP", 0, -15)
                    
                    -- Botón Cerrar
                    f.closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
                    f.closeBtn:SetPoint("TOPRIGHT", -5, -5)
                    
                    -- ScrollFrame
                    f.scroll = CreateFrame("ScrollFrame", "RaidDominionUpdateListScroll", f, "UIPanelScrollFrameTemplate")
                    f.scroll:SetPoint("TOPLEFT", 20, -40)
                    f.scroll:SetPoint("BOTTOMRIGHT", -40, 20)
                    
                    f.content = CreateFrame("Frame", nil, f.scroll)
                    f.content:SetSize(390, 10) -- Altura dinámica
                    f.scroll:SetScrollChild(f.content)
                end
                
                f.title:SetText(string.format("Jugadores con GS y Nota (%d)", #playersWithData))
                
                -- Limpiar contenido anterior
                local children = {f.content:GetChildren()}
                for _, child in ipairs(children) do
                    child:Hide()
                    child:SetParent(nil)
                end
                
                -- Llenar lista
                local yOffset = 0
                for i, member in ipairs(playersWithData) do
                    local line = CreateFrame("Frame", nil, f.content)
                    line:SetSize(390, 20)
                    line:SetPoint("TOPLEFT", 0, -yOffset)
                    
                    -- Botón para el nombre (Clic para editar)
                    local nameBtn = CreateFrame("Button", nil, line)
                    nameBtn:SetSize(120, 20)
                    nameBtn:SetPoint("LEFT", 0, 0)
                    
                    local nameText = nameBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                    nameText:SetPoint("LEFT")
                    nameBtn:SetFontString(nameText)
                    
                    local color = RAID_CLASS_COLORS[member.classFileName] or {r=1, g=1, b=1}
                    nameBtn:SetText(member.name)
                    nameText:SetTextColor(color.r, color.g, color.b)
                    
                    nameBtn:SetScript("OnClick", function()
                        local dialog = StaticPopup_Show("RAID_DOMINION_EDIT_GUILD_NOTE", member.name)
                        if dialog then
                            dialog.data = { index = member.index, currentNote = member.publicNote, name = member.name }
                            if dialog.editBox then
                                dialog.editBox:SetText(member.publicNote or "")
                                dialog.editBox:HighlightText()
                            end
                        end
                    end)
                    nameBtn:SetScript("OnEnter", function(self)
                        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                        GameTooltip:SetText("Clic para editar nota", 1, 1, 1)
                        GameTooltip:Show()
                    end)
                    nameBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

                    -- Determinar color del GS basado en la nota
                    local gsColor = "|cffaaaaaa" -- Gris por defecto
                    local noteGS = string.match(member.publicNote, "(%d+%.%d+)")
                    if noteGS then
                        local baseGS = math.floor(tonumber(noteGS) * 1000)  -- 5.2 -> 5200
                        local nextBaseGS = baseGS + 100  -- 5.2 -> 5300 (límite superior)
                        
                        if member.gearScore >= nextBaseGS then
                            gsColor = "|cffff9900" -- Naranja (GS actual > rango de la nota)
                        elseif member.gearScore >= baseGS then
                            gsColor = "|cff00ff00" -- Verde (GS actual dentro del rango de la nota)
                        else
                            gsColor = "|cffff0000" -- Rojo (GS actual < rango de la nota)
                        end
                    end

                    -- Texto de información (Sin nombre de clase, con Rango)
                    local infoText = line:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                    infoText:SetPoint("LEFT", nameBtn, "RIGHT", 5, 0)
                    infoText:SetText(string.format("%s |cff888888[%s]|r %s(GS: %d)|r", member.publicNote, member.rank, gsColor, member.gearScore))
                    
                    yOffset = yOffset + 20
                end
                
                f.content:SetHeight(yOffset)
                f:Show()
            end

            -- Si hay jugadores SIN nota pero con GS, mostrar otra ventana
            if #playersNoNote > 0 then
                if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
                    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99[RaidDominion]|r Se encontraron " .. #playersNoNote .. " jugadores con GS pero SIN Nota.")
                end
                
                -- Crear marco para mostrar la lista de SIN NOTA
                local f2 = _G["RaidDominionNoNoteListFrame"]
                if not f2 then
                    f2 = CreateFrame("Frame", "RaidDominionNoNoteListFrame", UIParent)
                    f2:SetSize(300, 400)
                    f2:SetPoint("CENTER", 230, 0) -- Mover a la derecha
                    f2:SetBackdrop({
                        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
                        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
                        tile = true, tileSize = 32, edgeSize = 32,
                        insets = { left = 11, right = 12, top = 12, bottom = 11 }
                    })
                    f2:SetBackdropColor(0, 0, 0, 0.9)
                    f2:EnableMouse(true)
                    f2:SetMovable(true)
                    f2:RegisterForDrag("LeftButton")
                    f2:SetScript("OnDragStart", f2.StartMoving)
                    f2:SetScript("OnDragStop", f2.StopMovingOrSizing)
                    
                    -- Título
                    f2.title = f2:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                    f2.title:SetPoint("TOP", 0, -15)
                    
                    -- Botón Cerrar
                    f2.closeBtn = CreateFrame("Button", nil, f2, "UIPanelCloseButton")
                    f2.closeBtn:SetPoint("TOPRIGHT", -5, -5)
                    
                    -- ScrollFrame
                    f2.scroll = CreateFrame("ScrollFrame", "RaidDominionNoNoteListScroll", f2, "UIPanelScrollFrameTemplate")
                    f2.scroll:SetPoint("TOPLEFT", 20, -40)
                    f2.scroll:SetPoint("BOTTOMRIGHT", -40, 20)
                    
                    f2.content = CreateFrame("Frame", nil, f2.scroll)
                    f2.content:SetSize(240, 10) -- Altura dinámica
                    f2.scroll:SetScrollChild(f2.content)
                end
                
                f2.title:SetText(string.format("Jugadores con GS sin Nota (%d)", #playersNoNote))
                
                -- Limpiar contenido anterior
                local children = {f2.content:GetChildren()}
                for _, child in ipairs(children) do
                    child:Hide()
                    child:SetParent(nil)
                end
                
                -- Llenar lista
                local yOffset = 0
                for i, member in ipairs(playersNoNote) do
                    local line = CreateFrame("Frame", nil, f2.content)
                    line:SetSize(240, 20)
                    line:SetPoint("TOPLEFT", 0, -yOffset)
                    
                    -- Botón para el nombre (Clic para editar)
                    local nameBtn = CreateFrame("Button", nil, line)
                    nameBtn:SetSize(100, 20)
                    nameBtn:SetPoint("LEFT", 0, 0)
                    
                    local nameText = nameBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                    nameText:SetPoint("LEFT")
                    nameBtn:SetFontString(nameText)
                    
                    local color = RAID_CLASS_COLORS[member.classFileName] or {r=1, g=1, b=1}
                    nameBtn:SetText(member.name)
                    nameText:SetTextColor(color.r, color.g, color.b)
                    
                    nameBtn:SetScript("OnClick", function()
                        local dialog = StaticPopup_Show("RAID_DOMINION_EDIT_GUILD_NOTE", member.name)
                        if dialog then
                            dialog.data = { index = member.index, currentNote = member.publicNote, name = member.name }
                            if dialog.editBox then
                                dialog.editBox:SetText(member.publicNote or "")
                                dialog.editBox:HighlightText()
                            end
                        end
                    end)
                    nameBtn:SetScript("OnEnter", function(self)
                        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                        GameTooltip:SetText("Clic para editar nota", 1, 1, 1)
                        GameTooltip:Show()
                    end)
                    nameBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

                    -- Texto de información (Sin nombre de clase, con Rango)
                    local infoText = line:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                    infoText:SetPoint("LEFT", nameBtn, "RIGHT", 5, 0)
                    infoText:SetText(string.format("|cff888888[%s]|r |cffaaaaaa(GS: %d)|r", member.rank, member.gearScore))
                    
                    yOffset = yOffset + 20
                end
                
                f2.content:SetHeight(yOffset)
                f2:Show()
            end
            
            -- Mostrar ventana de KRT si hay datos
            if krtData and krtData.raids and #krtData.raids > 0 then
                if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
                    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99[RaidDominion]|r Se encontraron " .. #krtData.raids .. " raids en el historial de KRT.")
                end
                
                local f3 = _G["RaidDominionKRTListFrame"]
                if not f3 then
                    f3 = CreateFrame("Frame", "RaidDominionKRTListFrame", UIParent)
                    f3:SetSize(400, 400)
                    f3:SetPoint("BOTTOM", 0, 50) -- Centrado abajo
                    f3:SetBackdrop({
                        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
                        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
                        tile = true, tileSize = 32, edgeSize = 32,
                        insets = { left = 11, right = 12, top = 12, bottom = 11 }
                    })
                    f3:SetBackdropColor(0, 0, 0, 0.9)
                    f3:EnableMouse(true)
                    f3:SetMovable(true)
                    f3:RegisterForDrag("LeftButton")
                    f3:SetScript("OnDragStart", f3.StartMoving)
                    f3:SetScript("OnDragStop", f3.StopMovingOrSizing)
                    
                    -- Título
                    f3.title = f3:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                    f3.title:SetPoint("TOP", 0, -15)
                    
                    -- Botón Cerrar
                    f3.closeBtn = CreateFrame("Button", nil, f3, "UIPanelCloseButton")
                    f3.closeBtn:SetPoint("TOPRIGHT", -5, -5)
                    
                    -- ScrollFrame
                    f3.scroll = CreateFrame("ScrollFrame", "RaidDominionKRTListScroll", f3, "UIPanelScrollFrameTemplate")
                    f3.scroll:SetPoint("TOPLEFT", 20, -40)
                    f3.scroll:SetPoint("BOTTOMRIGHT", -40, 20)
                    
                    f3.content = CreateFrame("Frame", nil, f3.scroll)
                    f3.content:SetSize(340, 10)
                    f3.scroll:SetScrollChild(f3.content)
                end
                
                f3.title:SetText(string.format("Historial de Raids (KRT) (%d)", #krtData.raids))
                
                -- Ordenar raids de más reciente a más antigua
                table.sort(krtData.raids, function(a, b)
                    return a.endTime > b.endTime
                end)

                -- Limpiar contenido
                local children = {f3.content:GetChildren()}
                for _, child in ipairs(children) do
                    child:Hide()
                    child:SetParent(nil)
                end
                
                -- Crear mapa de hermandad para búsqueda rápida
                local guildMap = {}
                for _, m in ipairs(guildMembers) do
                    local cleanName = string.match(m.name, "^([^-]+)") or m.name
                    guildMap[cleanName] = m
                end

                -- Llenar lista
                local yOffset = 0
                for i, raid in ipairs(krtData.raids) do
                    -- Encontrar miembros de la hermandad que asistieron
                    local attendees = {}
                    for pName, pData in pairs(raid.players) do
                        if guildMap[pName] then
                            -- Encontrar el último boss para este jugador
                            local lastBoss = "Ninguno"
                            local lastBossTime = 0
                            
                            for _, boss in ipairs(raid.bossKills) do
                                -- Si el boss murió mientras el jugador estaba (con margen de 5 min)
                                if boss.date >= (pData.join - 300) and (pData.leave == 0 or boss.date <= (pData.leave + 300)) then
                                    if boss.date >= lastBossTime then
                                        lastBoss = boss.name
                                        lastBossTime = boss.date
                                    end
                                end
                            end
                            
                            table.insert(attendees, {
                                name = pName,
                                lastBoss = lastBoss,
                                class = guildMap[pName].classFileName
                            })
                        end
                    end
                    
                    -- Ordenar asistentes por nombre
                    table.sort(attendees, function(a, b) return a.name < b.name end)

                    local raidFrame = CreateFrame("Frame", nil, f3.content)
                    raidFrame:SetSize(340, 45 + (#attendees * 15))
                    raidFrame:SetPoint("TOPLEFT", 0, -yOffset)
                    
                    local raidTitle = raidFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                    raidTitle:SetPoint("TOPLEFT", 5, 0)
                    raidTitle:SetText(string.format("|cffffff00%s|r (%d jugadores)", raid.zone, raid.size))
                    
                    local raidTime = raidFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                    raidTime:SetPoint("TOPLEFT", 5, -15)
                    local startDateStr = date("%d/%m/%y %H:%M", raid.startTime)
                    local endDateStr = date("%H:%M", raid.endTime)
                    raidTime:SetText(string.format("|cffaaaaaaInicio:|r %s |cffaaaaaaFin:|r %s", startDateStr, endDateStr))
                    
                    local bossCount = #raid.bossKills
                    local lootCount = #raid.loot
                    local raidStats = raidFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                    raidStats:SetPoint("TOPLEFT", 5, -30)
                    raidStats:SetText(string.format("|cffaaaaaaJefes:|r %d  |cffaaaaaaLoot:|r %d", bossCount, lootCount))
                    
                    -- Mostrar asistentes de la hermandad
                    local pYOffset = -45
                    if #attendees > 0 then
                        local header = raidFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                        header:SetPoint("TOPLEFT", 15, pYOffset)
                        header:SetText("|cff00ff00Miembros de Hermandad:|r")
                        pYOffset = pYOffset - 15
                        
                        for _, attendee in ipairs(attendees) do
                            local pBtn = CreateFrame("Button", nil, raidFrame)
                            pBtn:SetSize(300, 15)
                            pBtn:SetPoint("TOPLEFT", 25, pYOffset)
                            
                            local pText = pBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                            pText:SetPoint("LEFT", 0, 0)
                            
                            local classColor = RAID_CLASS_COLORS[attendee.class] or {r=1, g=1, b=1}
                            local colorStr = string.format("|cff%02x%02x%02x", classColor.r*255, classColor.g*255, classColor.b*255)
                            
                            local playerStatusText = ""
                            local pData = raid.players[attendee.name]
                            if pData and pData.leave > 0 and raid.endTime > 0 then
                                local timeDiff = raid.endTime - pData.leave
                                if timeDiff > 0 then
                                    local minutesLeft = math.floor(timeDiff / 60)
                                    playerStatusText = string.format("|cffff0000Abandonó: %d min antes|r", minutesLeft)
                                else
                                    playerStatusText = "|cff00ff00Completó|r"
                                end
                            else
                                playerStatusText = "|cff00ff00Completó|r" -- Asumir que completó si no hay datos de salida o raid no terminó
                            end

                            pText:SetText(string.format("%s%s|r -> %s", colorStr, attendee.name, playerStatusText))
                            
                            -- Acción al hacer clic: Mostrar detalles del jugador
                            pBtn:SetScript("OnClick", function()
                                local f4 = _G["RaidDominionPlayerDetailFrame"]
                                if not f4 then
                                    f4 = CreateFrame("Frame", "RaidDominionPlayerDetailFrame", UIParent)
                                    f4:SetSize(300, 350)
                                    f4:SetPoint("CENTER", 400, 0)
                                    f4:SetBackdrop({
                                        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
                                        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
                                        tile = true, tileSize = 32, edgeSize = 32,
                                        insets = { left = 11, right = 12, top = 12, bottom = 11 }
                                    })
                                    f4:SetBackdropColor(0, 0, 0, 0.95)
                                    f4:EnableMouse(true)
                                    f4:SetMovable(true)
                                    f4:RegisterForDrag("LeftButton")
                                    f4:SetScript("OnDragStart", f4.StartMoving)
                                    f4:SetScript("OnDragStop", f4.StopMovingOrSizing)
                                    
                                    f4.title = f4:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                                    f4.title:SetPoint("TOP", 0, -15)
                                    
                                    f4.closeBtn = CreateFrame("Button", nil, f4, "UIPanelCloseButton")
                                    f4.closeBtn:SetPoint("TOPRIGHT", -5, -5)
                                    
                                    f4.scroll = CreateFrame("ScrollFrame", "RaidDominionPlayerDetailScroll", f4, "UIPanelScrollFrameTemplate")
                                    f4.scroll:SetPoint("TOPLEFT", 20, -40)
                                    f4.scroll:SetPoint("BOTTOMRIGHT", -40, 20)
                                    
                                    f4.content = CreateFrame("Frame", nil, f4.scroll)
                                    f4.content:SetSize(240, 10)
                                    f4.scroll:SetScrollChild(f4.content)
                                end
                                
                                f4.title:SetText(string.format("Detalles: %s%s|r", colorStr, attendee.name))
                                
                                -- Limpiar contenido (hijos y regiones como FontStrings)
                                local children = {f4.content:GetChildren()}
                                for _, child in ipairs(children) do child:Hide() child:SetParent(nil) end
                                local regions = {f4.content:GetRegions()}
                                for _, region in ipairs(regions) do region:Hide() end
                                
                                local dy = 0

                                -- Helper function to get difficulty string
                                local function GetDifficultyString(difficulty)
                                    if difficulty == 1 then return "Normal"
                                    elseif difficulty == 2 then return "Heroico"
                                    elseif difficulty == 3 then return "Mítico"
                                    else return "Desconocido"
                                    end
                                end
                                
                                -- Rango del jugador
                                local rText = f4.content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                                rText:SetPoint("TOPLEFT", 0, -dy)
                                local pRank = guildMap[attendee.name] and guildMap[attendee.name].rank or "Desconocido"
                                rText:SetText(string.format("|cffffff00Rango:|r %s", pRank))
                                dy = dy + 15

                                -- Información de tiempo (Ingreso/Salida en ESTA raid)
                                local tHeader = f4.content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                                tHeader:SetPoint("TOPLEFT", 0, -dy)
                                tHeader:SetText("|cffffff00Tiempos en esta Raid:|r")
                                dy = dy + 15
                                
                                local pDataThisRaid = raid.players[attendee.name]
                                local joinStr = date("%H:%M:%S", pDataThisRaid.join)
                                local leaveStr = pDataThisRaid.leave > 0 and date("%H:%M:%S", pDataThisRaid.leave) or "Fin de Raid"
                                
                                local tText = f4.content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                                tText:SetPoint("TOPLEFT", 10, -dy)
                                tText:SetText(string.format("Entrada: %s\nSalida: %s", joinStr, leaveStr))
                                dy = dy + 30
                                
                                -- Botones de Rango (Ascender/Degradar)
                                local btnContainer = CreateFrame("Frame", nil, f4.content)
                                btnContainer:SetSize(240, 30)
                                btnContainer:SetPoint("TOPLEFT", 0, -dy)
                                
                                local promoteBtn = CreateFrame("Button", nil, btnContainer, "UIPanelButtonTemplate")
                                promoteBtn:SetSize(110, 22)
                                promoteBtn:SetPoint("LEFT", 0, 0)
                                promoteBtn:SetText("Ascender")
                                promoteBtn:SetScript("OnClick", function()
                                    if attendee.name then
                                        GuildPromote(attendee.name)
                                        if DEFAULT_CHAT_FRAME then
                                            DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff33ff99[RaidDominion]|r Intentando ascender a %s...", attendee.name))
                                        end
                                    end
                                end)
                                
                                local demoteBtn = CreateFrame("Button", nil, btnContainer, "UIPanelButtonTemplate")
                                demoteBtn:SetSize(110, 22)
                                demoteBtn:SetPoint("LEFT", promoteBtn, "RIGHT", 5, 0)
                                demoteBtn:SetText("Degradar")
                                demoteBtn:SetScript("OnClick", function()
                                    if attendee.name then
                                        GuildDemote(attendee.name)
                                        if DEFAULT_CHAT_FRAME then
                                            DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff33ff99[RaidDominion]|r Intentando degradar a %s...", attendee.name))
                                        end
                                    end
                                end)
                                dy = dy + 30

                                -- --- ESTADÍSTICAS GLOBALES (KRT History) ---
                                local zoneStats = {}
                                local bossStats = {}
                                local totalRaids = 0
                                
                                for _, r in ipairs(krtData.raids) do
                                    local pRaidData = r.players[attendee.name]
                                    if pRaidData then
                                        totalRaids = totalRaids + 1
                                        zoneStats[r.zone] = (zoneStats[r.zone] or 0) + 1
                                        
                                        for _, boss in ipairs(r.bossKills) do
                                            if boss.date >= (pRaidData.join - 300) and (pRaidData.leave == 0 or boss.date <= (pRaidData.leave + 300)) then
                                                local difficulty = boss.difficulty or 0 -- Assuming difficulty is available in boss object
                                                if not bossStats[boss.name] then
                                                    bossStats[boss.name] = {}
                                                end
                                                bossStats[boss.name][difficulty] = (bossStats[boss.name][difficulty] or 0) + 1
                                            end
                                        end
                                    end
                                end

                                -- Mostrar Raids por Zona
                                local zHeader = f4.content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                                zHeader:SetPoint("TOPLEFT", 0, -dy)
                                zHeader:SetText(string.format("|cffffff00Total Raids (%d):|r", totalRaids))
                                dy = dy + 15
                                
                                for zName, count in pairs(zoneStats) do
                                    local zText = f4.content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                                    zText:SetPoint("TOPLEFT", 10, -dy)
                                    zText:SetText(string.format("- %s: %d", zName, count))
                                    dy = dy + 12
                                end
                                dy = dy + 10

                                -- Mostrar Bosses (Contador por dificultad)
                                local bHeader = f4.content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                                bHeader:SetPoint("TOPLEFT", 0, -dy)
                                bHeader:SetText("|cffffff00Contador de Jefes (por dificultad):|r")
                                dy = dy + 15
                                
                                -- Ordenar bosses alfabéticamente
                                local sortedBossNames = {}
                                for bName, _ in pairs(bossStats) do table.insert(sortedBossNames, bName) end
                                table.sort(sortedBossNames)

                                for _, bName in ipairs(sortedBossNames) do
                                    local bText = f4.content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                                    bText:SetPoint("TOPLEFT", 10, -dy)
                                    bText:SetText(string.format("- %s:", bName))
                                    dy = dy + 12

                                    -- Ordenar dificultades (Normal, Heroico, Mítico)
                                    local sortedDifficulties = {}
                                    for diff, _ in pairs(bossStats[bName]) do table.insert(sortedDifficulties, diff) end
                                    table.sort(sortedDifficulties)

                                    for _, difficulty in ipairs(sortedDifficulties) do
                                        local count = bossStats[bName][difficulty]
                                        local diffStr = GetDifficultyString(difficulty)
                                        local dText = f4.content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                                        dText:SetPoint("TOPLEFT", 20, -dy)
                                        dText:SetText(string.format("  %s: |cff00ff00%d|r", diffStr, count))
                                        dy = dy + 12
                                    end
                                end
                                dy = dy + 10

                                -- Loot obtenido por este jugador (EN ESTA RAID)
                                local lHeader = f4.content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                                lHeader:SetPoint("TOPLEFT", 0, -dy)
                                lHeader:SetText("|cffffff00Botín en esta Raid:|r")
                                dy = dy + 15
                                
                                local gotLoot = false
                                for _, item in ipairs(raid.loot) do
                                    if item.looter == attendee.name or item.looter == (attendee.name .. "-" .. GetRealmName()) then
                                        local iText = f4.content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                                        iText:SetPoint("TOPLEFT", 10, -dy)
                                        iText:SetText("- " .. item.itemName)
                                        dy = dy + 12
                                        gotLoot = true
                                    end
                                end
                                if not gotLoot then
                                    local iText = f4.content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                                    iText:SetPoint("TOPLEFT", 10, -dy)
                                    iText:SetText("|cff888888Sin botín|r")
                                    dy = dy + 12
                                end
                                
                                f4.content:SetHeight(dy)
                                f4:Show()
                            end)
                            
                            pBtn:SetScript("OnEnter", function(self)
                                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                                GameTooltip:SetText("Clic para ver detalles de bosses y loot", 1, 1, 1)
                                GameTooltip:Show()
                            end)
                            pBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

                            pYOffset = pYOffset - 15
                        end
                    end
                    
                    yOffset = yOffset + (45 + (#attendees > 0 and (#attendees + 1) * 15 or 0)) + 10
                end
                f3.content:SetHeight(yOffset)
                f3:Show()
            end
            
        else
            local message = "No se pudo obtener la lista de la hermandad o no estás en una hermandad."
            if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
                DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[RaidDominion]|r " .. message)
            end
        end
    end)
    -- Función para mostrar la jerarquía de la hermandad agrupada por rangos
    local function ShowGuildHierarchy()
        -- Obtener constantes
        local CONST = RD.constants.GUILD_HIERARCHY
        local MSG = CONST.MESSAGES
        -- Verificar membresía
        if not IsInGuild() then
            SendSystemMessage(MSG.NOT_IN_GUILD)
            return
        end

        -- Obtener información de miembros
        local numTotalMembers = GetNumGuildMembers(true)
        if numTotalMembers == 0 then
            SendSystemMessage(MSG.NO_MEMBERS)
            return
        end

        -- Obtener nombres de rangos
        local rankNames = {}
        local numRanks = GuildControlGetNumRanks()
        for i = 1, numRanks do
            rankNames[i] = GuildControlGetRankName(i)
        end

        -- Contar miembros por rango
        local rankCounts = {}
        for i = 1, numTotalMembers do
            local _, _, rankIndex = GetGuildRosterInfo(i)
            local rankName = rankNames[rankIndex + 1] or MSG.DEFAULT_RANK_NAME
            rankCounts[rankName] = (rankCounts[rankName] or 0) + 1
        end

        -- Construir mensaje
        local messages = { MSG.TITLE }

        -- Procesar rangos
        if #rankNames >= 2 then
            -- Combinar los dos primeros rangos (líder y oficiales)
            local rank1 = rankNames[1] or ""
            local rank2 = rankNames[2] or ""
            local count1 = rankCounts[rank1] or 0
            local count2 = rankCounts[rank2] or 0

            if count1 > 0 or count2 > 0 then
                if rank1 == rank2 then
                    table.insert(messages, string.format(
                        MSG.RANK_ENTRY, 
                        rank1, count1,
                        "Organizadores de Hermandad"
                    ))
                else
                    table.insert(messages, string.format(
                        MSG.RANK_COUNT, 
                        rank1, count1, 
                        rank2, count2
                    ))
                end
            end

            -- Procesar rangos restantes con descripciones
            for rankIndex = 3, #rankNames do
                local rankName = rankNames[rankIndex]
                local total = rankCounts[rankName] or 0
                if total > 0 then
                    local description = MSG.RANK_DESCRIPTIONS[rankIndex] or ""
                    table.insert(messages, string.format(
                        MSG.RANK_ENTRY, 
                        rankName, 
                        total, 
                        description
                    ))
                end
            end
        else
            -- Mostrar todos los rangos sin formato especial si hay menos de 2
            for rankIndex = 1, #rankNames do
                local rankName = rankNames[rankIndex]
                local total = rankCounts[rankName] or 0
                if total > 0 then
                    table.insert(messages, string.format("%s: %d", rankName, total))
                end
            end
        end

        -- Calcular totales
        local totalOnline = 0
        local totalOffline = 0

        for i = 1, numTotalMembers do
            local _, _, _, _, _, _, _, _, isOnline = GetGuildRosterInfo(i)
            if isOnline then
                totalOnline = totalOnline + 1
            else
                totalOffline = totalOffline + 1
            end
        end
        
        local totalMembers = totalOnline + totalOffline

        -- Añadir línea de totales
        table.insert(messages, string.format(
            MSG.TOTAL_MEMBERS, 
            totalMembers, 
            totalOnline, 
            totalOffline
        ))
        
        SendDelayedMessages(messages, "GUILD")
    end

    MenuActions.Register("GuildComposition", function() 
        ShowGuildHierarchy()
    end)
    
    -- Registrar el comando de sorteo de hermandad
    MenuActions.Register("GuildLottery", GuildLottery)
end

-- Inicialización
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, addonName)
    if event == "ADDON_LOADED" and addonName == "RaidDominion2" then
        -- Registrar el diálogo de confirmación para el sorteo
        -- Configuración del diálogo de confirmación del sorteo
        local DIALOG = RD.constants.GUILD_LOTTERY.DIALOG
        StaticPopupDialogs["CONFIRM_GUILD_BANK_ITEM"] = {
            text = DIALOG.TITLE,
            button1 = DIALOG.BUTTONS.YES,
            button2 = DIALOG.BUTTONS.NO,
            button3 = DIALOG.BUTTONS.CHOOSE_ANOTHER,
            OnAccept = function(self)
                if self.data and self.data.OnAccept then
                    self.data.OnAccept()
                end
            end,
            OnCancel = function(self, _, reason)
                if reason == "clicked" then
                    -- Si se hace clic en No o en la X
                    if self.data and self.data.OnCancel then
                        self.data.OnCancel()
                    end
                end
                return false
            end,
            OnAlt = function(self)
                if self.data and self.data.OnAlt then
                    self.data.OnAlt()
                    return true  -- Evita que se cierre el diálogo
                end
                return false
            end,
            timeout = DIALOG.TIMEOUT,
            whileDead = true,
            hideOnEscape = false,  -- Deshabilitar el cierre automático con Escape
            preferredIndex = DIALOG.PREFERRED_INDEX,
            exclusive = 1,  -- Evita que se muestren múltiples instancias
        }
        
        MenuActions.RegisterDefaultActions()
        self:UnregisterEvent("ADDON_LOADED")
    end
end)

return MenuActions
