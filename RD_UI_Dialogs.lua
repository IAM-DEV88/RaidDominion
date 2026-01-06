--[[
    RD_UI_Dialogs.lua
    PROPÓSITO: Maneja los diálogos y ventanas emergentes del addon.
    DEPENDENCIAS: RD_Constants.lua, RD_Events.lua, RD_Config.lua
    API PÚBLICA: 
        - RaidDominion.ui.dialogs:ShowConfirmDialog(options)
        - RaidDominion.ui.dialogs:ShowInputDialog(options)
    EVENTOS: 
        - DIALOG_SHOW: Se dispara cuando se muestra un diálogo
        - DIALOG_RESPONSE: Se dispara cuando se responde un diálogo
    INTERACCIONES: 
        - RD_Module_MessageManager: Muestra mensajes de confirmación
        - RD_Config: Obtiene preferencias de la interfaz
]]

local addonName, private = ...
local constants = RaidDominion.constants
local events = RaidDominion.events
local config = RaidDominion.config

-- Módulo de diálogos
local dialogs = {}

-- Diálogos registrados
local registeredDialogs = {}

--[[
    Muestra un diálogo de confirmación
    @param self Referencia al módulo
    @param options Tabla de opciones del diálogo
        - text: Texto a mostrar
        - acceptText: Texto del botón de aceptar (opcional)
        - cancelText: Texto del botón de cancelar (opcional)
        - onAccept: Función a ejecutar al aceptar
        - onCancel: Función a ejecutar al cancelar
        - showAlert: Mostrar como alerta (rojo)
        - hideOnEscape: Cerrar al presionar ESC (true por defecto)
        - timeout: Tiempo en segundos para cierre automático (opcional)
]]
function dialogs:ShowConfirmDialog(options)
    -- Validar opciones
    if not options or not options.text then return end
    
    -- Configurar opciones por defecto
    options.acceptText = options.acceptText or YES
    options.cancelText = options.cancelText or CANCEL
    options.showAlert = options.showAlert or false
    options.hideOnEscape = (options.hideOnEscape ~= false)
    
    -- Mostrar diálogo de confirmación de Blizzard
    StaticPopupDialogs["RAID_DOMINION_CONFIRM"] = {
        text = options.text,
        button1 = options.acceptText,
        button2 = options.cancelText,
        OnAccept = options.onAccept,
        OnCancel = options.onCancel,
        timeout = options.timeout or 0,
        hideOnEscape = options.hideOnEscape,
        whileDead = true,
        preferredIndex = 3,
    }
    
    -- Mostrar el diálogo
    StaticPopup_Show("RAID_DOMINION_CONFIRM")
    
    -- Disparar evento
    events:Publish("DIALOG_SHOW", {
        type = "confirm",
        options = options
    })
end

--[[
    Registra un diálogo personalizado
    @param self Referencia al módulo
    @param name Nombre único del diálogo
    @param options Configuración del diálogo (ver StaticPopup_Show)
]]
function dialogs:RegisterDialog(name, options)
    if not name or not options then return end
    
    -- Registrar el diálogo si no existe
    if not StaticPopupDialogs[name] then
        StaticPopupDialogs[name] = options
        registeredDialogs[name] = true
        return true
    end
    
    return false
end

--[[
    Muestra un diálogo registrado
    @param self Referencia al módulo
    @param name Nombre del diálogo registrado
    @param data Datos adicionales para el diálogo
    @return boolean Éxito de la operación
]]
function dialogs:ShowRegisteredDialog(name, data)
    if not name or not registeredDialogs[name] then return false end
    
    local dialog = StaticPopup_Show(name, data)
    if dialog and data then
        dialog.data = data
    end
    
    -- Disparar evento
    events:Publish("DIALOG_SHOW", {
        type = "custom",
        name = name,
        data = data
    })
    
    return dialog ~= nil
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

-- Inicialización
function dialogs:OnInitialize()
    -- Registrar diálogos del sistema
    self:RegisterDialog("RAID_DOMINION_ALERT", {
        text = "%s",
        button1 = OKAY,
        showAlert = true,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    })
    
    local uiTexts = RaidDominion.constants and RaidDominion.constants.UI_TEXTS or {}
    self:RegisterDialog("RAIDDOM_CONFIRM_READY_CHECK", {
        text = uiTexts.READY_CHECK_PROMPT or "¿Deseas iniciar un check de banda?",
        button1 = "Sí",
        button2 = "No",
        OnAccept = function(self)
            local data = self and self.data or {}
            if data and data.onAccept then data.onAccept() end
            StaticPopup_Show("RAIDDOM_PULL_TIMER_INPUT")
            DoReadyCheck()
            SafeDBMCommand("broadcast timer 0:10 CONFIRMAN TODOS Y PULL")
        end,
        OnCancel = function(self)
            local data = self and self.data or {}
            if data and data.onCancel then data.onCancel() end
            SafeDBMCommand("broadcast timer 0:10 ¿QUE FALTA?")
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    })
    self:RegisterDialog("RAIDDOM_PULL_TIMER_INPUT", {
        text = uiTexts.PULL_TIMER_PROMPT or "Ingresa los segundos para el pull (ej: 10):",
        button1 = "Aceptar",
        button2 = "Cancelar",
        hasEditBox = true,
        maxLetters = 2,
        OnShow = function(self)
            if self.editBox and self.editBox.SetNumeric then self.editBox:SetNumeric(true) end
            if self.editBox and self.editBox.SetNumber then self.editBox:SetNumber(10) elseif self.editBox then self.editBox:SetText("10") end
            if self.editBox then self.editBox:SetFocus(); self.editBox:HighlightText() end
        end,
        OnAccept = function(self)
            local data = self and self.data or {}
            local seconds
            if self and self.editBox and self.editBox.GetNumber then
                seconds = tonumber(self.editBox:GetNumber())
            elseif self and self.editBox then
                seconds = tonumber(self.editBox:GetText())
            end
            if seconds and seconds > 0 then
                if data and data.onAccept then data.onAccept(seconds) end
            else
                if data and data.onInvalid then data.onInvalid() end
            end
            SafeDBMCommand("broadcast timer 0:10 SOLO EL TANQUE PULEA")
            SlashCmdList["DEADLYBOSSMODS"]("pull " .. seconds)
        end,
        OnCancel = function(self)
            local data = self and self.data or {}
            if data and data.onCancel then data.onCancel() end
            SafeDBMCommand("broadcast timer 0:10 PULL CANCELADO")
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        exclusive = 1,
        preferredIndex = 3,
    })
    
    -- Registrar eventos
    events:Subscribe("DIALOG_SHOW", function(dialogInfo)
    end)
end

function dialogs:ShowReadyCheckConfirm(options)
    return self:ShowRegisteredDialog("RAIDDOM_CONFIRM_READY_CHECK", options or {})
end

function dialogs:ShowPullTimerInput(options)
    return self:ShowRegisteredDialog("RAIDDOM_PULL_TIMER_INPUT", options or {})
end

--[[
    Muestra el popup para editar el enlace de Discord
]]
function dialogs:ShowDiscordEditPopup()
    local realm = GetRealmName()
    local char = UnitName("player") .. " - " .. realm
    -- Asegurar que no haya puntos en el nombre del personaje/reino que rompan la clave de configuración
    -- Aunque los nombres de WoW no suelen tener puntos, es mejor prevenir
    local safeChar = char:gsub("%.", "")
    local configKey = "profiles." .. safeChar .. ".discordLink"
    local dbmAvailable = SafeDBMCommand("broadcast timer 0:30 PREPARANDO DC")
    
    -- Registrar el diálogo si no existe (o actualizarlo)
    StaticPopupDialogs["RAIDDOM_DISCORD_EDIT"] = {
        text = "Enlace de Discord:",
        button1 = "Guardar",
        button2 = "Cancelar",
        hasEditBox = true,
        maxLetters = 255,
        OnShow = function(self)
            local current = RaidDominion.config and RaidDominion.config.Get and RaidDominion.config:Get(configKey) or ""
            self.editBox:SetText(current)
            self.editBox:SetFocus()
            self.editBox:SetScript("OnEscapePressed", function(editBox) editBox:GetParent():Hide() end)
        end,
        OnAccept = function(self)
            local text = self.editBox:GetText()
            if RaidDominion.config and RaidDominion.config.Set then
                if text and text ~= "" then
                    RaidDominion.config:Set(configKey, text)
                else
                    RaidDominion.config:Set(configKey, nil)
                end
            end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        exclusive = true,
        preferredIndex = 3,
    }
    
    StaticPopup_Show("RAIDDOM_DISCORD_EDIT")
end

-- Registrar el módulo
RaidDominion.ui.dialogs = dialogs

-- Inicialización retrasada
events:Subscribe("PLAYER_LOGIN", function()
    dialogs:OnInitialize()
end)

return dialogs
