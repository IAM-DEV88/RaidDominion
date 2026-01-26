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

    -- Verificar membresía y permisos
    if not IsInGuild() then
        SendSystemMessage(MSG.NOT_IN_GUILD)
        return
    end

    -- Verificar permisos según el nuevo sistema (Mínimo Nivel 2: Oficial)
    local mm = RD.modules and RD.modules.messageManager
    local permLevel = mm and mm.GetPermissionLevel and mm:GetPermissionLevel() or 0
    
    if permLevel < 2 then
        SendSystemMessage("|cffff0000[RaidDominion]|r Error: No tienes permisos de Oficial para iniciar el sorteo.")
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
        -- Registrar diálogos de StaticPopup
        if not StaticPopupDialogs["RAID_DOMINION_CONFIRM_PROMOTE"] then
            StaticPopupDialogs["RAID_DOMINION_CONFIRM_PROMOTE"] = {
                text = "¿Deseas promover a %s a Iniciado?",
                button1 = "Sí",
                button2 = "No",
                OnAccept = function(self)
                    GuildPromote(self.data.name)
                end,
                timeout = 0,
                whileDead = 1,
                hideOnEscape = 1,
                preferredIndex = 3,
            }
        end

        if not StaticPopupDialogs["RAID_DOMINION_EDIT_GUILD_NOTE"] then
            StaticPopupDialogs["RAID_DOMINION_EDIT_GUILD_NOTE"] = {
                text = "Editar nota pública de %s",
                button1 = "Aceptar",
                button2 = "Cancelar",
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
                    
                    GuildRosterSetPublicNote(index, text)
                    GuildRoster() -- Solicitar actualización
                end,
                EditBoxOnEnterPressed = function(self)
                    local parent = self:GetParent()
                    local text = parent.editBox:GetText()
                    local index = parent.data.index
                    
                    GuildRosterSetPublicNote(index, text)
                    GuildRoster() -- Solicitar actualización
                    parent:Hide()
                end,
                timeout = 0,
                whileDead = 1,
                hideOnEscape = 1
            }
        end

    
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
        -- Generar la lista de miembros de la hermandad y guardarla en RaidDominionDB.Guild.memberList
        if RD.utils and RD.utils.group then
            local guildMembers, updatesNeeded = RD.utils.group.GetGuildMemberList()
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[RaidDominion]|r Lista de hermandad generada con " .. #guildMembers .. " miembros.")
            if #updatesNeeded > 0 then
                DEFAULT_CHAT_FRAME:AddMessage("|cffffff00[RaidDominion]|r Se requieren actualizaciones de notas para " .. #updatesNeeded .. " miembros.")
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
    
    -- Crear un frame para escuchar actualizaciones de la hermandad
    local gsUpdateFrame = CreateFrame("Frame", "RaidDominionGSUpdateFrame", UIParent)
    gsUpdateFrame:RegisterEvent("GUILD_ROSTER_UPDATE")
    gsUpdateFrame:SetScript("OnEvent", function(self, event)
        if event == "GUILD_ROSTER_UPDATE" then
            -- Refrescar las ventanas de Gearscore si están abiertas
            if RD.utils and RD.utils.gearscore and RD.utils.gearscore.ToggleGearscoreWindows then
                RD.utils.gearscore.ToggleGearscoreWindows(true)
            end
        end
    end)
    
    -- Nuevas acciones para Gearscore y Core Bands
    MenuActions.Register("ShowGuildGearscore", function() 
        if RD.utils and RD.utils.gearscore and RD.utils.gearscore.ToggleGearscoreWindows then
            RD.utils.gearscore.ToggleGearscoreWindows()
        end
    end)
    
    MenuActions.Register("ShowCoreBands", function() 
        local f = _G["RaidDominionCoreListFrame"]
        if f and f:IsVisible() then
            f:Hide()
            return
        end
        if RD.utils and RD.utils.coreBands then
            RD.utils.coreBands.ShowCoreBandsWindow()
        end
    end)

    MenuActions.Register("ShowRecognition", function()
        local permLevel = messageManager and messageManager.GetPermissionLevel and messageManager:GetPermissionLevel() or 0
        if permLevel < 1 then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[RaidDominion]|r Error: No tienes permisos para ver reconocimientos.")
            return
        end

        local f = _G["RaidDominionRecognitionFrame"]
        if f and f:IsShown() then
            f:Hide()
        elseif RD.utils and RD.utils.recognition then
            RD.utils.recognition.ShowRecognitionWindow()
        end
    end)

    MenuActions.Register("SearchGuildPlayer", function()
        local permLevel = messageManager and messageManager.GetPermissionLevel and messageManager:GetPermissionLevel() or 0
        if permLevel < 1 then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[RaidDominion]|r Error: No tienes permisos para buscar jugadores.")
            return
        end

        local p = _G["RaidDominionPlayerSearchPopup"]
        if p and p:IsShown() then
            p:Hide()
        elseif RD.utils and RD.utils.recognition and RD.utils.recognition.ShowPlayerSearchPopup then
            RD.utils.recognition.ShowPlayerSearchPopup()
        end
    end)

    MenuActions.Register("RecognitionCreate", function()
        local permLevel = messageManager and messageManager.GetPermissionLevel and messageManager:GetPermissionLevel() or 0
        if permLevel < 2 then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[RaidDominion]|r Error: No tienes permisos para crear reconocimientos.")
            return
        end
        if RD.utils and RD.utils.recognition and RD.utils.recognition.getOrCreateRecognitionFrame then
            local createFrame = RD.utils.recognition.getOrCreateRecognitionFrame()
            createFrame.isEditing = false
            createFrame.editIndex = nil
            createFrame.title:SetText("Nuevo Reconocimiento")
            createFrame.nameEdit:SetText("")
            createFrame.descEdit:SetText("")
            createFrame:Show()
        end
    end)

    MenuActions.Register("RecognitionShare", function()
        local permLevel = messageManager and messageManager.GetPermissionLevel and messageManager:GetPermissionLevel() or 0
        if permLevel < 2 then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[RaidDominion]|r Error: No tienes permisos para compartir reconocimientos.")
            return
        end
        -- Lógica de compartir (pendiente)
        DEFAULT_CHAT_FRAME:AddMessage("|cffffff00[RaidDominion]|r Lógica de compartir no implementada aún.")
    end)
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


