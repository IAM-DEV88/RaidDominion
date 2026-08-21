--[[
    RD_UI_Dialogs.lua
    PROPÓSITO: Diálogos emergentes (confirmación e entrada de texto) usando
              StaticPopupDialogs de Blizzard, como el addon base.
    API PÚBLICA:
        - RD.ui.dialogs:ShowConfirmDialog(options)
        - RD.ui.dialogs:ShowInputDialog(options)
        - RD.ui.dialogs:ShowDiscordEditPopup()
    EVENTOS: Ninguno.
]]

local addonName, private = ...
local RD = _G.RaidDominion or {}
_G.RaidDominion = RD

local Dialogs = {}

-- Diálogo de confirmación (estilo base v2)
function Dialogs:ShowConfirmDialog(options)
    if not options or not options.text then return end
    StaticPopupDialogs["RD_CONFIRM"] = {
        text = options.text,
        button1 = options.acceptText or YES,
        button2 = options.cancelText or CANCEL,
        OnAccept = options.onAccept,
        OnCancel = options.onCancel,
        timeout = options.timeout or 0,
        hideOnEscape = (options.hideOnEscape ~= false),
        whileDead = true,
        preferredIndex = 3,
    }
    StaticPopup_Show("RD_CONFIRM")
end

-- Diálogo de entrada de texto (con editbox), estilo base v2
function Dialogs:ShowInputDialog(options)
    if not options or not options.text then return end
    StaticPopupDialogs["RD_INPUT"] = {
        text = options.text,
        button1 = options.acceptText or "Aceptar",
        button2 = options.cancelText or "Cancelar",
        hasEditBox = true,
        maxLetters = options.maxLetters or 255,
        OnShow = function(self)
            if options.onShow then options.onShow(self) end
        end,
        OnAccept = function(self)
            local value = self.editBox and self.editBox:GetText() or ""
            if options.onAccept then options.onAccept(value) end
        end,
        OnCancel = function(self)
            if options.onCancel then options.onCancel() end
        end,
        timeout = 0,
        hideOnEscape = true,
        whileDead = true,
        exclusive = true,
        preferredIndex = 3,
    }
    StaticPopup_Show("RD_INPUT")
end

-- Popup para editar el enlace de Discord (estilo base v2)
function Dialogs:ShowDiscordEditPopup()
    self:ShowInputDialog({
        text = "Enlace de Discord:",
        acceptText = "Guardar",
        cancelText = "Cancelar",
        maxLetters = 255,
        onShow = function(self)
            local current = (RD.config and RD.config.Get and RD.config:Get("chat.discordLink", "")) or ""
            self.editBox:SetText(current)
            self.editBox:SetFocus()
        end,
        onAccept = function(value)
            if RD.config and RD.config.Set then
                RD.config:Set("chat.discordLink", tostring(value or ""))
            end
        end,
    })
end

RD.ui = RD.ui or {}
RD.ui.dialogs = Dialogs
return Dialogs
