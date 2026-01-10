--[[
    RD_Module_MessageManager.lua
    PROPÓSITO: Gestiona el sistema de mensajería del addon, incluyendo mensajes de chat, alertas y notificaciones.
    DEPENDENCIAS: RD_Events.lua, RD_Constants.lua
    API PÚBLICA: 
        - RaidDominion.messageManager:ShowAlert(message, alertType)
        - RaidDominion.messageManager:ScheduleMessage(delay, channel, message, target)
    EVENTOS: 
        - MESSAGE_SENT: Se dispara cuando se envía un mensaje
        - ALERT_SHOWN: Se dispara cuando se muestra una alerta
    INTERACCIONES: 
        - RD_UI_MainFrame: Muestra notificaciones en la interfaz
        - RD_Config: Obtiene preferencias de mensajería
]]

local addonName, private = ...
local RD = _G.RaidDominion or {}
_G.RaidDominion = RD -- Asegurar que la referencia global esté establecida

-- Inicializar tablas si no existen
RD.constants = RD.constants or {}
RD.events = RD.events or {}
RD.modules = RD.modules or {}

-- Referencias locales
local constants = RD.constants
local events = RD.events

-- Módulo de gestión de mensajes
local messageManager = {}

-- Prefijo para comunicación entre addons
local COMM_PREFIX = "RD_COMM"

-- Registrar el módulo
RD.messageManager = messageManager
RD.modules.messageManager = messageManager

-- Cola de mensajes programados
local messageQueue = {}

-- Mensaje de carga eliminado para reducir ruido en la consola

--[[
    Asigna iconos de banda a tanques y sanadores y muestra una alerta
    @param button El botón que activó la función (para manejar clic derecho)
--]]
--[[
    Asigna iconos de banda a tanques y sanadores y muestra una alerta
    @param button El botón que activó la función (para manejar clic derecho)
--]]
function messageManager:AssignIconsAndAlert(button)
    -- Clear raid icons on right click
    if button == "RightButton" then
        ClearAllRaidIcons()
        return
    end

    local roleManager = RD.roleManager
    if not roleManager or not roleManager.AssignRaidIcons then
        return
    end
    
    -- Delegar la lógica de asignación al RoleManager
    local report = roleManager:AssignRaidIcons()
    
    -- Formatear y enviar el mensaje
    if report then
        local alertMessages = {}
        local tanksStr = {}
        
        if report.tanks[1] then table.insert(tanksStr, report.tanks[1]) end
        if report.tanks[2] then table.insert(tanksStr, report.tanks[2]) end
        
        if #tanksStr > 0 then
            table.insert(alertMessages, table.concat(tanksStr, " // "))
        end

        if #report.healers > 0 then
            table.insert(alertMessages, "HEALERS: " .. table.concat(report.healers, " "))
        end
        
        if #alertMessages > 0 then
            local _, defaultChannel = self:GetDefaultChannel()
            if defaultChannel then
                SendDelayedMessages(alertMessages, defaultChannel)
            end
        else
            SendSystemMessage("No tanks or healers with assigned roles found.")
        end
    end
end

--[[
    Muestra una alerta en pantalla
    @param self Referencia al módulo
    @param message Texto de la alerta
    @param alertType Tipo de alerta ("INFO", "WARNING", "ERROR", "SUCCESS")
    @param duration Duración en segundos (opcional)
]]
function messageManager:ShowAlert(message, alertType, duration)
    local text = tostring(message or "")
    local d = tonumber(duration) or 0
    
    local colors = {
        INFO = {r = 0.4, g = 0.8, b = 1},     -- Light Blue
        WARNING = {r = 1, g = 0.8, b = 0},    -- Gold
        ERROR = {r = 1, g = 0.2, b = 0.2},    -- Red
        SUCCESS = {r = 0.2, g = 1, b = 0.2}   -- Green
    }
    
    local color = colors[alertType] or ChatTypeInfo[alertType] or ChatTypeInfo["RAID_WARNING"]
    
    if RaidBossEmoteFrame then
        RaidNotice_AddMessage(RaidBossEmoteFrame, text, color, d)
    else
        -- Fallback if RaidBossEmoteFrame is not available
        UIErrorsFrame:AddMessage(text, color.r, color.g, color.b, 1.0, d > 0 and d or 2.0)
    end
end

-- Contador y sistema de tareas programadas (debe declararse antes de su uso)
local taskCounter = 0
local scheduledTasks = {}
local lastUpdate = 0
local updateFrame = CreateFrame("Frame")

updateFrame:SetScript("OnUpdate", function(self, elapsed)
	lastUpdate = lastUpdate + elapsed
	if lastUpdate < 0.1 then -- Revisar tareas cada 100ms
		return
	end
	lastUpdate = 0

	local currentTime = GetTime()
	local toRemove = {}

	-- Identificar tareas a ejecutar (para evitar modificar la tabla mientras se itera)
	local tasksToRun = {}
	for id, task in pairs(scheduledTasks) do
		if currentTime >= task.time then
			tasksToRun[id] = task
		end
	end

	-- Ejecutar tareas y eliminarlas
	for id, task in pairs(tasksToRun) do
		-- Verificar si la tarea aún existe (podría haber sido cancelada por otra tarea en este mismo ciclo)
		if scheduledTasks[id] then
			scheduledTasks[id] = nil -- Eliminar de la cola principal
			pcall(task.callback)
		end
	end
end)

-- Función para programar una tarea con retraso
local function ScheduleTask(delay, callback)
	taskCounter = taskCounter + 1
	scheduledTasks[taskCounter] = {
		time = GetTime() + (tonumber(delay) or 0),
		callback = callback,
	}
	return taskCounter
end

function SendDelayedMessages(messages, channel)
	if not messages or #messages == 0 then
		return
	end
	channel = channel or ""
	local maxLength = 255
	local delay = 0.1 -- Delay in seconds between each part
	local currentIndex = 1

	local function SendNextPart()
		if currentIndex > #messages then
			return -- All messages sent
		end

		local message = messages[currentIndex]
		local messageLength = #message

		if messageLength <= maxLength then
			-- If message is within limit, send it as is
			if channel == "INN" then
				local id = select(1, GetChannelName("Posada"))
				SendChatMessage(message, "CHANNEL", nil, id)
			elseif channel == "SYSTEM" then
				SendSystemMessage(message)
			else
				SendChatMessage(message, channel)
			end
			currentIndex = currentIndex + 1
			ScheduleTask(delay, SendNextPart)
		else
			-- If message is too long, split it
			local part = message:sub(1, maxLength)
			if channel == "SYSTEM" then
				SendSystemMessage(part)
			elseif channel == "INN" then
				local id = select(1, GetChannelName("Posada"))
				SendChatMessage(message, "CHANNEL", nil, id)
			else
				SendChatMessage(part, channel)
			end

			-- Update the message with remaining text
			messages[currentIndex] = message:sub(maxLength + 1)

			-- Schedule next part of the same message
			ScheduleTask(delay, SendNextPart)
		end
	end

	-- Start sending messages
	SendNextPart()
end

local function SafeDBMCommand(command)
	if not DBM then
		return false
	end
	local ok, res = pcall(function()
		if command:match("^broadcast timer") then
			local timeStr, message = command:match("broadcast timer (%d+:%d+) (.+)")
			if timeStr and message then
				local minutes, seconds = timeStr:match("(%d+):(%d+)")
				local totalSeconds = (tonumber(minutes) or 0) * 60 + (tonumber(seconds) or 0)
				if DBT and DBT.StartBar then
					DBT:StartBar(totalSeconds, message, "Interface\\Icons\\Spell_Nature_WispSplode")
					return true
				elseif DBM.Bars and DBM.Bars.CreateBar then
					DBM.Bars:CreateBar(totalSeconds, message, "Interface\\Icons\\Spell_Nature_WispSplode")
					return true
				elseif DBM.CreatePizzaTimer then
					DBM:CreatePizzaTimer(totalSeconds, message, true)
					return true
				end
			end
		elseif command:match("^pull") then
			local seconds = command:match("pull (%d+)")
			if seconds then
				local secNum = tonumber(seconds)
				if DBM.StartPull then
					DBM:StartPull(secNum)
					return true
				elseif DBM.Pull then
					DBM:Pull(secNum)
					return true
				elseif SlashCmdList and SlashCmdList["DBMPULL"] then
					SlashCmdList["DBMPULL"](seconds)
					return true
				end
			end
		end
		return false
	end)
	return ok and res
end

function messageManager:SendRDMessage(arg1, arg2, arg3)
	local msgType, key
	if type(arg1) == "table" then
		msgType = arg2
		key = arg3
	else
		msgType = arg1
		key = arg2
	end
	local _, defaultChannel = self:GetDefaultChannel()
	local arrayToSend
	local title = tostring(key or "")
	if msgType == "regla" then
		arrayToSend = RaidDominion.constants and RaidDominion.constants.RAID_RULES and RaidDominion.constants.RAID_RULES[key]
	elseif msgType == "mecanica" then
		arrayToSend = RaidDominion.constants and RaidDominion.constants.RAID_MECHANICS and RaidDominion.constants.RAID_MECHANICS[key]
	elseif msgType == "mensaje" then
		arrayToSend = RaidDominion.constants and RaidDominion.constants.GUILD_MESSAGES and RaidDominion.constants.GUILD_MESSAGES[key]
        defaultChannel = "GUILD"
	elseif msgType == "discord" then
		arrayToSend = { arg2 }
        local dbmAvailable = SafeDBMCommand("broadcast timer 0:30 CONECTAR DC")
	end
	if type(key) == "table" then
		arrayToSend = key
		title = tostring(arg3 or "MENSAJE")
	end
	if not arrayToSend then
		if DEFAULT_CHAT_FRAME then
			DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[RaidDominion]|r Error: No data found for " .. tostring(msgType) .. " key: " .. tostring(key))
		end
		return
	end
	local messages = { "=== " .. tostring(title or "") .. " ===" }
	for _, line in ipairs(arrayToSend) do
		table.insert(messages, line)
	end
	SendDelayedMessages(messages, defaultChannel)
	if msgType == "regla" or msgType == "mecanica" or msgType == "mensaje" then
		if not SafeDBMCommand(string.format("broadcast timer %s %s", "0:10", string.upper(tostring(msgType or "")))) then
			SendSystemMessage("|cFFFFFF00Advertencia:|r DBM no está instalado. La función de temporizador no está disponible.")
		end
	end
	return true
end

--[[
    Maneja eventos de mensajes entrantes
    @param self Referencia al módulo
    @param prefix Prefijo del mensaje
    @param message Texto del mensaje
    @param channel Canal del mensaje
    @param sender Remitente del mensaje
]]
function messageManager:HandleIncomingMessage(prefix, message, channel, sender)
    if prefix ~= COMM_PREFIX then return end
    if sender == UnitName("player") then return end
    
    if message == "REQUEST_DATA" then
         -- Check if I am leader
         if IsRaidLeader() or (GetNumRaidMembers() == 0 and IsPartyLeader()) then
             self:BroadcastRaidData(channel)
             self:ShowAlert("Datos enviados a " .. sender, "SUCCESS")
         end
    elseif message == "DATA_START" then
        self.incomingData = {}
        self:ShowAlert("Recibiendo datos del líder...", "INFO")
    elseif message == "DATA_END" then
        -- Process complete
        self:ProcessIncomingData()
        self:ShowAlert("Datos actualizados correctamente.", "SUCCESS")
    elseif message:match("^DATA_CHUNK:") then
        local type, key, idx, total, content = message:match("^DATA_CHUNK:([^:]+):([^:]+):(%d+):(%d+):(.+)$")
        if type and key then
            if not self.incomingData then self.incomingData = {} end
            if not self.incomingData[type] then self.incomingData[type] = {} end
            if not self.incomingData[type][key] then self.incomingData[type][key] = {} end
            self.incomingData[type][key][tonumber(idx)] = content
        end
    end
end

function messageManager:HandleRaidModeRightClick()
    -- Solo enviar solicitud si estamos en grupo
    if GetNumPartyMembers() == 0 and GetNumRaidMembers() == 0 then
        self:ShowAlert("Debes estar en grupo para solicitar datos.", "WARNING")
        return
    end

    -- Si soy el líder, no solicito nada
    if IsRaidLeader() or (GetNumRaidMembers() == 0 and IsPartyLeader()) then
         self:ShowAlert("Eres el líder. Los ayudantes pueden solicitar datos haciendo clic derecho aquí.", "INFO")
         return
    end
    
    local channel = (GetNumRaidMembers() > 0) and "RAID" or "PARTY"
    SendAddonMessage(COMM_PREFIX, "REQUEST_DATA", channel)
    self:ShowAlert("Solicitando datos al líder...", "INFO")
end

function messageManager:BroadcastRaidData(channel)
    if not RaidDominion.constants then return end
    
    local function SafeSend(msg)
        SendAddonMessage(COMM_PREFIX, msg, channel)
    end
    
    SafeSend("DATA_START")
    
    -- Sync RAID_RULES
    if RaidDominion.constants.RAID_RULES then
        for k, v in pairs(RaidDominion.constants.RAID_RULES) do
            local content = table.concat(v, "~|~")
            -- Chunking
            local maxLen = 200
            local totalLen = #content
            local numChunks = math.ceil(totalLen / maxLen)
            
            for i = 1, numChunks do
                local sub = string.sub(content, (i-1)*maxLen + 1, i*maxLen)
                SafeSend(string.format("DATA_CHUNK:RULES:%s:%d:%d:%s", k, i, numChunks, sub))
            end
        end
    end
    
    -- Sync RAID_MECHANICS
    if RaidDominion.constants.RAID_MECHANICS then
        for k, v in pairs(RaidDominion.constants.RAID_MECHANICS) do
            local content = table.concat(v, "~|~")
            local maxLen = 200
            local totalLen = #content
            local numChunks = math.ceil(totalLen / maxLen)
            
            for i = 1, numChunks do
                local sub = string.sub(content, (i-1)*maxLen + 1, i*maxLen)
                SafeSend(string.format("DATA_CHUNK:MECH:%s:%d:%d:%s", k, i, numChunks, sub))
            end
        end
    end
    
    -- Sync GUILD_MESSAGES
    if RaidDominion.constants.GUILD_MESSAGES then
        for k, v in pairs(RaidDominion.constants.GUILD_MESSAGES) do
            local content = table.concat(v, "~|~")
            local maxLen = 200
            local totalLen = #content
            local numChunks = math.ceil(totalLen / maxLen)
            
            for i = 1, numChunks do
                local sub = string.sub(content, (i-1)*maxLen + 1, i*maxLen)
                SafeSend(string.format("DATA_CHUNK:MSG:%s:%d:%d:%s", k, i, numChunks, sub))
            end
        end
    end
    
    -- Sync Assignments
    local assignments = RD.config and RD.config:Get("assignments")
    if assignments then
        for typeName, data in pairs(assignments) do
            if type(data) == "table" then
                local lines = {}
                for key, val in pairs(data) do
                    if type(val) ~= "table" then
                        table.insert(lines, tostring(key) .. "=" .. tostring(val))
                    end
                end
                
                if #lines > 0 then
                    local content = table.concat(lines, "~|~")
                    local maxLen = 200
                    local totalLen = #content
                    local numChunks = math.ceil(totalLen / maxLen)
                    
                    for i = 1, numChunks do
                        local sub = string.sub(content, (i-1)*maxLen + 1, i*maxLen)
                        SafeSend(string.format("DATA_CHUNK:ASSIGN:%s:%d:%d:%s", typeName, i, numChunks, sub))
                    end
                end
            end
        end
    end
    
    SafeSend("DATA_END")
end

function messageManager:ProcessIncomingData()
    if not self.incomingData then return end
    
    local function Reconstruct(typeTable, targetTable)
        if not typeTable then return end
        for key, chunks in pairs(typeTable) do
            local content = ""
            -- Find max index
            local maxIdx = 0
            for k, _ in pairs(chunks) do if k > maxIdx then maxIdx = k end end
            
            for i = 1, maxIdx do
                content = content .. (chunks[i] or "")
            end
            
            -- Split content back to table
            local lines = {}
            -- Custom split for ~|~
            local start = 1
            local sepStart, sepEnd = string.find(content, "~|~", start, true)
            while sepStart do
                table.insert(lines, string.sub(content, start, sepStart - 1))
                start = sepEnd + 1
                sepStart, sepEnd = string.find(content, "~|~", start, true)
            end
            table.insert(lines, string.sub(content, start))
            
            targetTable[key] = lines
        end
    end
    
    if not RaidDominion.constants then RaidDominion.constants = {} end
    
    if self.incomingData["RULES"] then
        if not RaidDominion.constants.RAID_RULES then RaidDominion.constants.RAID_RULES = {} end
        Reconstruct(self.incomingData["RULES"], RaidDominion.constants.RAID_RULES)
    end
    
    if self.incomingData["MECH"] then
        if not RaidDominion.constants.RAID_MECHANICS then RaidDominion.constants.RAID_MECHANICS = {} end
        Reconstruct(self.incomingData["MECH"], RaidDominion.constants.RAID_MECHANICS)
    end
    
    if self.incomingData["MSG"] then
        if not RaidDominion.constants.GUILD_MESSAGES then RaidDominion.constants.GUILD_MESSAGES = {} end
        Reconstruct(self.incomingData["MSG"], RaidDominion.constants.GUILD_MESSAGES)
    end
    
    if self.incomingData["ASSIGN"] then
        for typeName, chunks in pairs(self.incomingData["ASSIGN"]) do
            local content = ""
            local maxIdx = 0
            for k, _ in pairs(chunks) do if k > maxIdx then maxIdx = k end end
            for i = 1, maxIdx do content = content .. (chunks[i] or "") end
            
            local function ProcessLine(line)
                local key, val = line:match("([^=]+)=(.+)")
                if key and val and RD.config and RD.config.Set then
                     RD.config:Set("assignments." .. typeName .. "." .. key, val)
                end
            end
            
            local start = 1
            local sepStart, sepEnd = string.find(content, "~|~", start, true)
            while sepStart do
                ProcessLine(string.sub(content, start, sepStart - 1))
                start = sepEnd + 1
                sepStart, sepEnd = string.find(content, "~|~", start, true)
            end
            ProcessLine(string.sub(content, start))
        end
    end
    
    self.incomingData = {}

    -- Refresh UI if open
    if RaidDominion.UI and RaidDominion.UI.DynamicMenus and RaidDominion.UI.DynamicMenus.currentMenu then
        RaidDominion.UI.DynamicMenus:Render(RaidDominion.UI.DynamicMenus.currentMenu)
    end
end

function messageManager:GetDefaultChannel()
    -- Get default channel for message sending
    local realm = GetRealmName()
    local char = UnitName("player") .. " - " .. realm
    
    -- Ensure charSettings has a chat table with default values
    if not RaidDominionDB then RaidDominionDB = {} end
    if not RaidDominionDB.profiles then RaidDominionDB.profiles = {} end
    if not RaidDominionDB.profiles[char] then RaidDominionDB.profiles[char] = {} end
    if not RaidDominionDB.profiles[char].chat then 
        RaidDominionDB.profiles[char].chat = { channel = "DEFAULT" }
    end
    
    local charSettings = RaidDominionDB.profiles[char]
    local isInGuild = IsInGuild()
    local inParty = GetNumPartyMembers() > 0
    local inRaid = GetNumRaidMembers() ~= 0
    local inBG = UnitInBattleground("player")
    
    -- Get the saved channel from config
    local savedChannel = charSettings.chat and charSettings.chat.channel or "DEFAULT"
    
    -- Initialize default channel based on group status and saved settings
    local defaultChannel
    
    -- If we have a saved channel and it's not DEFAULT, use it
    if savedChannel and savedChannel ~= "DEFAULT" then
        defaultChannel = savedChannel
    else
        -- Use default channel based on group status
        if inBG then
            defaultChannel = "BATTLEGROUND"
        elseif inRaid then
            -- If in raid and using DEFAULT, use RAID_WARNING for leaders/officers, RAID for others
            defaultChannel = (IsRaidLeader() or IsRaidOfficer()) and "RAID_WARNING" or "RAID"
        elseif inParty then
            defaultChannel = "PARTY"
        elseif isInGuild then
            defaultChannel = "GUILD"
        else
            defaultChannel = "SAY"
        end
    end
    
    -- Settings check

    local numberOfPlayers = inRaid and GetNumRaidMembers() or inBG and GetNumRaidMembers() or GetNumPartyMembers()
    return numberOfPlayers, defaultChannel
end

local function resolveItemName(menuType, key)
    local k = string.lower(tostring(key or ""))
    local c = RaidDominion.constants
    if not c then return k end
    if menuType == "roles" and c.ROLE_DATA then
        for _, it in ipairs(c.ROLE_DATA) do
            local name = string.lower(it.name or "")
            if name == k then return it.name end
        end
        return key
    end
    local sd = c.SPELL_DATA
    if not sd then return key end
    local section = menuType == "abilities" and sd.abilities
        or menuType == "buffs" and sd.buffs
        or menuType == "auras" and sd.auras
        or nil
    if section then
        for _, it in ipairs(section) do
            if string.lower(it.name or "") == k then
                return it.name
            end
        end
    end
    return key
end

function messageManager:SendItemAnnouncement(menuType, itemKeyOrName, playerOrNeed)
    local _, defaultChannel = self:GetDefaultChannel()
    local itemName = resolveItemName(menuType, itemKeyOrName)
    local who = tostring(playerOrNeed or "")
    local msg
    if who ~= "" and string.upper(who) == "NEED" then
        msg = string.format("%s [%s]", who, tostring(itemName or ""))
    else
        msg = string.format("%s [%s]", who, tostring(itemName or ""))
    end
    SendDelayedMessages({ msg }, defaultChannel)
end

-- Discord functions moved to Config/Dialogs
-- Keeping wrappers for compatibility if needed, or removing if UI is updated.
-- UI will be updated to use Config/Dialogs directly.

function messageManager:NameTarget()
    if not UnitExists("target") then
        SendSystemMessage("No hay ningún objetivo seleccionado.")
        return
    end
    local name = UnitName("target")
    local _, defaultChannel = self:GetDefaultChannel()
    SendDelayedMessages({ tostring(name or "") }, defaultChannel)
end

function messageManager:ShowTargetInfo()
    if RD.utils and RD.utils.group and RD.utils.group.GetTargetInfo then
        local info = RD.utils.group:GetTargetInfo("target")
        if not info then
            SendSystemMessage("No hay ningun objetivo seleccionado.")
            return
        end
        
        local messages = {}
        local classifText = ""
        if info.classification == "elite" or info.classification == "rareelite" then
            classifText = " (Elite)"
        elseif info.classification == "rare" then
            classifText = " (Raro)"
        elseif info.classification == "worldboss" then
            classifText = " (Jefe Mundial)"
        end
        
        local levelText = (info.level == -1) and "??" or tostring(info.level)
        
        table.insert(messages, string.format("%s [Nivel %s %s%s]", tostring(info.name or ""), levelText, (info.classLocalized ~= info.name and info.classLocalized ~= "") and info.classLocalized or "", classifText))
        
        local line2 = string.format("Salud: %d/%d [%d%%]", tonumber(info.health) or 0, tonumber(info.healthMax) or 0, info.healthPct)
        
        if info.powerType == 0 then -- Mana
            if (info.powerMax or 0) > 0 then
                line2 = line2 .. string.format(" //  Mana: %d/%d [%d%%]", tonumber(info.power) or 0, tonumber(info.powerMax) or 0, info.powerPct)
            end
        elseif info.powerType == 3 then -- Energy
            if (info.powerMax or 0) > 0 then
                line2 = line2 .. string.format(" //  Energia: %d/%d [%d%%]", tonumber(info.power) or 0, tonumber(info.powerMax) or 0, info.powerPct)
            end
        elseif info.powerType == 1 then -- Rage
            if (info.powerMax or 0) > 0 then
                line2 = line2 .. string.format(" // Ira: %d/%d [%d%%]", tonumber(info.power) or 0, tonumber(info.powerMax) or 0, info.powerPct)
            end
        end
        
        table.insert(messages, line2)
        local _, defaultChannel = self:GetDefaultChannel()
        SendDelayedMessages(messages, defaultChannel)
    end
end

function messageManager:ReportAbsentPlayers()
    if RD.utils and RD.utils.group and RD.utils.group.GetAbsentPlayersReport then
        local absent = RD.utils.group:GetAbsentPlayersReport()
        if not absent then
            SendSystemMessage("No estás en grupo o banda.")
            return
        end
        
        local _, defaultChannel = self:GetDefaultChannel()
        local messages = {}
        local hasAbsent = false
        
        if #absent.offline > 0 then
            hasAbsent = true
            table.insert(messages, "=== DESCONECTADOS ===")
            table.insert(messages, table.concat(absent.offline, ", "))
        end
        if #absent.afk > 0 then
            hasAbsent = true
            table.insert(messages, "=== AFK (AUSENTES) ===")
            table.insert(messages, table.concat(absent.afk, ", "))
        end
        if #absent.dead > 0 then
            hasAbsent = true
            table.insert(messages, "=== MUERTOS ===")
            table.insert(messages, table.concat(absent.dead, ", "))
        end
        
        if hasAbsent then
            SendDelayedMessages(messages, defaultChannel)
            if DEFAULT_CHAT_FRAME then
                DEFAULT_CHAT_FRAME:AddMessage(string.format("|cFF33FF99[RaidDominion]|r Reporte de ausentes enviado (%d offline, %d AFK, %d muertos)", #absent.offline, #absent.afk, #absent.dead))
            end
        else
            SendSystemMessage("Todos los miembros del grupo/banda están presentes y listos.")
        end
    end
end

function messageManager:HandleRaidModeClick()
    local inParty = GetNumPartyMembers() > 0
    local inRaid = GetNumRaidMembers() ~= 0
    local defaultChannel = "SYSTEM"
    if not inParty and not inRaid then
        SendDelayedMessages({"◄ ERROR ►", "Debes estar en grupo para crear una banda."}, defaultChannel)
        return
    end
    if not inRaid then
        if not IsPartyLeader() then
            SendDelayedMessages({"◄ ERROR ►", "Solo el líder del grupo puede convertir a banda."}, defaultChannel)
            return
        end
        ConvertToRaid()
        SendDelayedMessages({"◄ BANDA ►", "El grupo ahora es una banda."}, defaultChannel)
    end
    local dialogs = RaidDominion.ui and RaidDominion.ui.dialogs
    if not dialogs or not dialogs.ShowConfirmDialog then
        return
    end
    dialogs:ShowConfirmDialog({
        text = "¿Deseas activar el modo heroico?",
        acceptText = "Sí",
        cancelText = "No",
        onAccept = function()
            ScheduleTask(0.05, function() self:_ShowRaidSizePopup(true) end)
        end,
        onCancel = function()
            ScheduleTask(0.05, function() self:_ShowRaidSizePopup(false) end)
        end
    })
end

function messageManager:_ShowRaidSizePopup(heroic)
    local dialogs = RaidDominion.ui and RaidDominion.ui.dialogs
    if not dialogs or not dialogs.ShowConfirmDialog then
        return
    end
    dialogs:ShowConfirmDialog({
        text = "¿De cuántos jugadores?",
        acceptText = "10",
        cancelText = "25",
        onAccept = function()
            self:SetRaidDifficulty(10, heroic)
        end,
        onCancel = function()
            self:SetRaidDifficulty(25, heroic)
        end
    })
end

function messageManager:SetRaidDifficulty(size, heroic)
    if RD.utils and RD.utils.group and RD.utils.group.SetRaidDifficulty then
        local msg = RD.utils.group:SetRaidDifficulty(size, heroic)
        local defaultChannel = "SYSTEM"
        SendDelayedMessages({"◄ DIFICULTAD ►", msg}, defaultChannel)
    end
end

function messageManager:CancelScheduledTask(taskId)
    if scheduledTasks[taskId] then
        scheduledTasks[taskId] = nil
        return true
    end
    return false
end

function messageManager:Initialize()
    -- Inicializar tablas necesarias
    self.pendingWelcomes = {}
    self.welcomeTimers = {}
    
    -- Inicializar el sistema de eventos
    self:InitializeEventHandlers()
    
    return true
end

-- Función para inicializar los manejadores de eventos
function messageManager:InitializeEventHandlers()
    -- Verificar que el sistema de eventos esté disponible
    if not self.events then
        self.events = {}
    end
    
    -- Registrar eventos del sistema
    self:RegisterSystemEvents()
end

-- Función para registrar eventos del sistema
function messageManager:RegisterSystemEvents()
    -- Verificar si ya estamos registrados para evitar duplicados
    if self.eventsRegistered then 
        return 
    end
    
    -- Crear un frame para manejar los eventos
    if not self.eventFrame then
        self.eventFrame = CreateFrame("Frame")
        self.eventFrame:RegisterEvent("CHAT_MSG_SYSTEM")
        self.eventFrame:RegisterEvent("CHAT_MSG_ADDON")
        
        if RegisterAddonMessagePrefix then
            RegisterAddonMessagePrefix("RD_COMM")
        end
        
        -- Configurar el manejador de eventos
        self.eventFrame:SetScript("OnEvent", function(_, event, ...)
            if event == "CHAT_MSG_SYSTEM" then
                local msg = ...
                self:HandleSystemMessage(msg)
            elseif event == "CHAT_MSG_ADDON" then
                local prefix, msg, channel, sender = ...
                self:HandleIncomingMessage(prefix, msg, channel, sender)
            end
        end)
    end
    
    -- Registrar también en el sistema de eventos personalizado si está disponible
    if self.events and type(self.events.RegisterEvent) == "function" then
        self.events:RegisterEvent("CHAT_MSG_SYSTEM", function(msg, ...)
            self:HandleSystemMessage(msg, ...)
        end)
    end
    
    -- Marcar como registrado
    self.eventsRegistered = true
end

-- Maneja los mensajes del sistema
function messageManager:HandleSystemMessage(msg, ...)
    if not msg then 
        return 
    end
    
    -- Limpiar el mensaje de códigos de color y espacios adicionales
    local cleanMsg = msg:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("^%s*(.-)%s*$", "%1")
    
    -- Patrones para detectar cuando un jugador se une a la hermandad (en diferentes idiomas)
    local patterns = {
        "^(.-) se ha unido a la hermandad",  -- Español
        "^(.-) has joined the guild"          -- Inglés
    }
    
    -- Verificar si el mensaje coincide con algún patrón de unión a la hermandad
        for _, pattern in ipairs(patterns) do
            local playerName = cleanMsg:match(pattern)
            if playerName and self:IsTopThreeRanks() then
                -- Limpiar el nombre del jugador
                playerName = playerName:gsub("-", ""):gsub(" ", "")
                
                -- Verificar si ya estamos procesando a este jugador
                if not self.pendingWelcomes[playerName] then
                    self.pendingWelcomes[playerName] = true
                    self:HandleGuildWelcome(playerName)
                end
                return
            end
        end
    
    -- Aquí puedes agregar más manejadores para otros tipos de mensajes del sistema
    -- por ejemplo, mensajes de banda, mazmorra, etc.
end

local function trim(str)
    return tostring(str or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

function messageManager:IsTopThreeRanks()
    -- Verificar si estamos en una hermandad
    if not IsInGuild() then 
        return false 
    end
    
    -- Obtener información del jugador en la hermandad
    local _, _, rankIndex = GetGuildInfo("player")
    
    -- Si no se pudo obtener la información, forzar una actualización
    if not rankIndex then
        GuildRoster()
        return false
    end
    
    -- Comprobar si el rango está entre los tres más altos (0, 1 y 2)
    return rankIndex == 0 or rankIndex == 1 or rankIndex == 2
end

function messageManager:CountGuildOnline()
    local total = GetNumGuildMembers(true) or 0
    local online = 0
    for i = 1, total do
        local name, _, _, _, _, _, _, _, isOnline = GetGuildRosterInfo(i)
        if isOnline then
            online = online + 1
        end
    end
    return total, online
end

function messageManager:GetPlayerClassFromGuild(playerName)
    if not IsInGuild() then return nil end
    GuildRoster()
    local total = GetNumGuildMembers(true) or 0
    local target = string.lower(trim(playerName or ""))
    for i = 1, total do
        local name, _, _, _, class, _, _, _, _, _, classFileName = GetGuildRosterInfo(i)
        local cleanName = tostring(name or ""):gsub("%-.*$", "")
        if string.lower(cleanName) == target then
            return class or classFileName
        end
    end
    return nil
end

function messageManager:ShowWelcomeConfirmation(playerName, class, totalMembers, onlineMembers)
    local dialogs = RaidDominion.ui and RaidDominion.ui.dialogs
    if not dialogs or not dialogs.ShowConfirmDialog then return end
    local p = tostring(playerName or "Nuevo miembro")
    local c = tostring(class or "")
    local t = tonumber(totalMembers) or 0
    local o = tonumber(onlineMembers) or 0
    dialogs:ShowConfirmDialog({
        text = "¿Deseas darle la bienvenida a " .. p .. "?",
        acceptText = "Sí",
        cancelText = "No",
        onAccept = function()
            local guildName = GetGuildInfo("player") or "la hermandad"
            local messages = {
                string.format("¡Bienvenido a %s %s %s!", guildName, c, p),
                string.format("¡Ya somos %d!", t),
            }
            SendDelayedMessages(messages, "GUILD")
        end
    })
end

function messageManager:HandleGuildWelcome(playerName, retries)
    local r = tonumber(retries) or 3
    local key = tostring(playerName or "")
    
    if self.welcomeTimers[key] then
        self:CancelScheduledTask(self.welcomeTimers[key])
    end
    
    self.welcomeTimers[key] = ScheduleTask(.2, function()
        local class = self:GetPlayerClassFromGuild(key)
        local total, online = self:CountGuildOnline()
        
        if class then
            self.pendingWelcomes[key] = nil
            self.welcomeTimers[key] = nil
            self:ShowWelcomeConfirmation(key, class, total, online)
        elseif r > 0 then
            self:HandleGuildWelcome(key, r - 1)
        else
            self.pendingWelcomes[key] = nil
            self.welcomeTimers[key] = nil
            self:ShowWelcomeConfirmation(key, nil, total, online)
        end
    end)
end

function messageManager:StartRoutineReadyCheck()
    DoReadyCheck()
    local dbmAvailable = SafeDBMCommand("broadcast timer 0:30 AFK = REEMPLAZO/KICK")
    
end

function messageManager:WhisperAssignments()
    local raidMembers = {}
    
    -- Obtener instancia de groupUtils
    local groupUtils = RaidDominion.utils and RaidDominion.utils.group
    if not groupUtils then
        return
    end
    
    -- Obtener instancia de roleManager
    local roleManager = RaidDominion.roleManager
    if not roleManager then
        return
    end
    
    -- Inicializar el caché de asignaciones
    local addonCache = {}
    
    -- Obtener todos los miembros del grupo/banda
    local groupMembers = groupUtils:GetGroupMembers()
    if not groupMembers or #groupMembers == 0 then
        return
    end
    
    -- Obtener todas las asignaciones del roleManager
    local roleAssignments = {}
    local buffAssignments = {}
    local auraAssignments = {}
    local abilityAssignments = {}
    
    -- Obtener asignaciones de configuración
    if RaidDominionDB and RaidDominionDB.assignments then
        roleAssignments = RaidDominionDB.assignments.roles or {}
        buffAssignments = RaidDominionDB.assignments.buffs or {}
        auraAssignments = RaidDominionDB.assignments.auras or {}
        abilityAssignments = RaidDominionDB.assignments.abilities or {}
    end
    
    -- Procesar cada miembro del grupo
    for _, member in ipairs(groupMembers) do
        if member.name and member.unit and member.isPlayer then
            local fullName = member.name
            local _, class = UnitClass(member.unit)
            local roles = {}
            local buffs = {}
            local auras = {}
            local abilities = {}
            
            -- Obtener rol asignado
            local assignedRole = UnitGroupRolesAssigned(member.unit)
            if assignedRole == "TANK" then
                table.insert(roles, "TANQUE")
            elseif assignedRole == "HEALER" then
                table.insert(roles, "SANADOR")
            else
                table.insert(roles, "DPS")
            end
            
            -- Buscar asignaciones de roles específicos
            for roleName, assignedTo in pairs(roleAssignments) do
                if type(assignedTo) == "table" then
                    if assignedTo.target == fullName then
                        table.insert(roles, roleName)
                    end
                elseif assignedTo == fullName then
                    table.insert(roles, roleName)
                end
            end
            
            -- Buscar asignaciones de buffs
            for buffName, assignedTo in pairs(buffAssignments) do
                if type(assignedTo) == "table" then
                    if assignedTo.target == fullName then
                        table.insert(buffs, buffName)
                    end
                elseif assignedTo == fullName then
                    table.insert(buffs, buffName)
                end
            end
            
            -- Buscar asignaciones de auras
            for auraName, assignedTo in pairs(auraAssignments) do
                if type(assignedTo) == "table" then
                    if assignedTo.target == fullName then
                        table.insert(auras, auraName)
                    end
                elseif assignedTo == fullName then
                    table.insert(auras, auraName)
                end
            end
            
            -- Buscar asignaciones de habilidades
            for abilityName, assignedTo in pairs(abilityAssignments) do
                if type(assignedTo) == "table" then
                    if assignedTo.target == fullName then
                        table.insert(abilities, abilityName)
                    end
                elseif assignedTo == fullName then
                    table.insert(abilities, abilityName)
                end
            end
            
            -- Agregar al caché con todas las asignaciones
            addonCache[fullName] = {
                rol = roles,
                buffs = buffs,
                auras = auras,
                abilities = abilities,
                class = class,
                unit = member.unit
            }
            
        end
    end
    
    -- Verificar si hay jugadores en el grupo
    local playerCount = 0
    for _ in pairs(addonCache) do playerCount = playerCount + 1 end
    
    if playerCount == 0 then
        SendSystemMessage("No se encontraron jugadores en el grupo/banda.")
        return
    end
    
    -- Procesar asignaciones
    local assignedCount = 0
    for playerName, playerData in pairs(addonCache) do
        local roles = playerData.rol or { "DPS" }
        local playerRoles = {}
        
        -- Filtrar roles que no sean DPS
        for _, role in ipairs(roles) do
            if role ~= "DPS" then
                table.insert(playerRoles, role)
            end
        end
        
        -- Obtener todas las asignaciones
        local abilities = playerData.abilities or {}
        local buffs = playerData.buffs or {}
        local auras = playerData.auras or {}
        local messageParts = {}
        
        -- Función para formatear texto (primera letra mayúscula, resto minúsculas)
        local function formatText(text)
            if not text or text == "" then return text end
            return text:sub(1,1):upper() .. text:sub(2):lower()
        end
        
        -- Agregar roles (excluyendo DPS)
        for _, role in ipairs(playerRoles) do
            if role ~= "DPS" then
                table.insert(messageParts, formatText(role))
            end
        end
        
        -- Agregar buffs
        for _, buff in ipairs(buffs) do
            table.insert(messageParts, formatText(buff))
        end
        
        -- Agregar habilidades
        for _, ability in ipairs(abilities) do
            table.insert(messageParts, formatText(ability))
        end
        
        -- Agregar auras
        for _, aura in ipairs(auras) do
            table.insert(messageParts, formatText(aura))
        end
        
        -- Si hay algo para enviar, crear el mensaje
        if #messageParts > 0 then
            local message = playerName .. " [" .. table.concat(messageParts, ", ") .. "]"
            table.insert(raidMembers, { playerName, message })
            assignedCount = assignedCount + 1
        end
    end
    
    -- Configurar temporizador DBM si está disponible
    local dbmAvailable = SafeDBMCommand("broadcast timer 0:20 APLICAR BUFFS")
    
    -- Enviar mensajes privados a cada jugador
    for i, playerInfo in ipairs(raidMembers) do
        local playerName = playerInfo[1]
        local message = playerInfo[2]
        
        -- Enviar el mensaje
        local success, err = pcall(function()
            SendChatMessage(message .. " -- Lider de banda", "WHISPER", nil, playerName)
        end)
        
        -- Mostrar error si falla el envío
        if not success then
            SendSystemMessage(string.format("Error al enviar a %s: %s", tostring(playerName), tostring(err)))
        end
    end
end

function messageManager:StartPullFlow()
    -- Asegurarse de que los diálogos estén inicializados
    if not StaticPopupDialogs["RAIDDOM_CONFIRM_READY_CHECK"] or not StaticPopupDialogs["RAIDDOM_PULL_TIMER_INPUT"] then
        if RaidDominion.ui and RaidDominion.ui.dialogs and RaidDominion.ui.dialogs.OnInitialize then
            RaidDominion.ui.dialogs:OnInitialize()
        end
    end
    
    -- Obtener la instancia de diálogos
    local dialogs = RaidDominion.ui and RaidDominion.ui.dialogs
    if not dialogs then 
        self:SendSystemMessage("Error: No se pudo acceder al sistema de diálogos")
        return 
    end
    
    -- Mostrar diálogo de confirmación de ready check
    local dialog = StaticPopup_Show("RAIDDOM_CONFIRM_READY_CHECK")
    SafeDBMCommand("broadcast timer 0:10 ¿TODOS LISTOS?")

    if not dialog then
        -- Si falla, intentar registrar los diálogos de nuevo
        if dialogs.OnInitialize then
            dialogs:OnInitialize()
            dialog = StaticPopup_Show("RAIDDOM_CONFIRM_READY_CHECK")
        end
        if not dialog then
            self:SendSystemMessage("Error: No se pudo mostrar el diálogo de confirmación")
            return
        end
    end
end

-- Loot methods moved to RD_Utils_Group.lua
-- UI should call RD.utils.group:ToggleLootMethod() and RD.utils.group:SetMasterLooterToTarget() directly.

local function SendRoleMessage(self, roleName, player)
    -- Normalize calling conventions:
    -- Support both:
    --   FunctionModule:SendRoleMessage(roleName, player)  -- colon (self is module)
    --   SendRoleMessage(roleName, player)                 -- function call (self is roleName)
    if type(self) == "table" and roleName ~= nil then
        -- called as module:SendRoleMessage(roleName, player) -> keep roleName/player as provided
    else
        -- called as SendRoleMessage(roleName, player) -> shift parameters
        player = roleName
        roleName = self
        self = nil
    end

    -- Get the current state and default channel
    local _, defaultChannel = messageManager:GetDefaultChannel()

	-- Format the message based on whether it's a NEED or an assignment
	local message
	if player and player:upper() == "NEED" then
		message = string.format("%s [%s]", player, tostring(roleName or ""))
	else
		message = string.format("%s [%s]", tostring(player or ""), tostring(roleName or ""))
	end

	-- Send the message using the existing delayed message system
	SendDelayedMessages({ message }, defaultChannel)
end


-- Inicialización
function messageManager:OnInitialize()
    self:Initialize()
end

-- Registrar el módulo
RaidDominion.modules.messageManager = messageManager

-- Inicialización retrasada
if events and events.Subscribe then
    events:Subscribe("PLAYER_LOGIN", function()
        messageManager:OnInitialize()
    end)
end

return messageManager
