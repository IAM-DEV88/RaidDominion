--[[
    RD_Events.lua
    PROPÓSITO: Bus de eventos pub/sub minimalista. Sin dependencias externas.
    API PÚBLICA:
        - RD.events:Subscribe(event, fn)
        - RD.events:Unsubscribe(event, fn)
        - RD.events:Publish(event, ...)
    EVENTOS RESERVADOS:
        CONFIG_LOADED, CONFIG_CHANGED(key, value), CONFIG_RESET,
        ADDON_INITIALIZED, UI_SHOW, UI_HIDE,
        CONFIG_WINDOW_SHOWN, CONFIG_WINDOW_HIDDEN
]]

local addonName, private = ...
local RD = _G.RaidDominion or {}
_G.RaidDominion = RD

local Events = {
    registry = {}
}

-- Suscribe una función a un evento
function Events:Subscribe(event, fn)
    if not event or type(fn) ~= "function" then return end
    if not self.registry[event] then
        self.registry[event] = {}
    end
    table.insert(self.registry[event], fn)
end

-- Elimina la suscripción de una función a un evento
function Events:Unsubscribe(event, fn)
    local list = self.registry[event]
    if not list then return end
    for i = #list, 1, -1 do
        if list[i] == fn then
            table.remove(list, i)
        end
    end
end

-- Publica un evento a todos los suscriptores
function Events:Publish(event, ...)
    local list = self.registry[event]
    if not list then return end
    -- Copiar la lista antes de iterar: permite suscribirse/desuscribirse
    -- durante la publicación sin saltarse handlers.
    local handlers = {}
    for i = 1, #list do
        handlers[i] = list[i]
    end
    for i = 1, #handlers do
        local fn = handlers[i]
        if fn then
            local ok, err = pcall(fn, ...)
            if not ok and RD.messageManager and RD.messageManager.SendSystemMessage then
                RD.messageManager:SendSystemMessage(
                    "|cffff0000[RaidDominion]|r Error en evento " .. tostring(event) .. ": " .. tostring(err))
            end
        end
    end
end

RD.events = Events
return Events
