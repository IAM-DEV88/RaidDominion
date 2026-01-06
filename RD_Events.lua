--[[
    RD_Events.lua
    PROPÓSITO: Sistema centralizado de manejo de eventos para el addon.
    DEPENDENCIAS: Ninguna
    API PÚBLICA:
        - RaidDominion.events:Subscribe(event, handler, [priority])
        - RaidDominion.events:Unsubscribe(event, handler)
        - RaidDominion.events:Publish(event, ...)
        - RaidDominion.events:RegisterEvent(event, handler, [priority])
        - RaidDominion.events:UnregisterEvent(event, handler)
    EVENTOS: Maneja todos los eventos del juego y eventos personalizados
]]

-- Definir constantes de prioridad primero
local PRIORITY = {
    HIGHEST = 100,
    HIGH = 75,
    NORMAL = 50,
    LOW = 25,
    LOWEST = 0
}

local addonName = "RaidDominion2"
local events = {}

-- Hacer que PRIORITY esté disponible en el objeto events
events.PRIORITY = PRIORITY

-- Tablas para el manejo de eventos
local eventHandlers = {}
local eventGroups = {}
local eventFrame = CreateFrame("Frame")
local handlerCount = 0

--[[
    Crea un grupo de eventos para suscribirse a múltiples eventos con un solo manejador
    @param name Nombre del grupo
    @param eventList Tabla con los nombres de los eventos
    @return boolean True si se creó el grupo correctamente, false en caso contrario
]]
function events:CreateEventGroup(name, eventList)
    if not name or type(eventList) ~= "table" or #eventList == 0 then
        return false
    end
    
    eventGroups[name] = {}
    for _, event in ipairs(eventList) do
        if type(event) == "string" then
            table.insert(eventGroups[name], event)
        end
    end
    
    return #eventGroups[name] > 0
end

--[[
    Registra un manejador para un evento personalizado
    @param event Nombre del evento
    @param handler Función manejadora
    @param priority Prioridad (opcional, por defecto 50)
    @return ID del manejador
]]
function events:Subscribe(event, handler, priority)
    if type(event) ~= "string" then
        error("events:Subscribe() - event must be a string", 2)
    end
    
    if type(handler) ~= "function" then
        error("events:Subscribe() - handler must be a function", 2)
    end
    
    local handlerId = handlerCount + 1
    handlerCount = handlerId
    
    if not eventHandlers[event] then
        eventHandlers[event] = {}
    end
    
    table.insert(eventHandlers[event], {
        id = handlerId,
        handler = handler,
        priority = tonumber(priority) or 50
    })
    
    -- Ordenar por prioridad (mayor prioridad primero)
    table.sort(eventHandlers[event], function(a, b)
        return a.priority > b.priority
    end)
    
    return handlerId
end

--[[
    Elimina un manejador de eventos
    @param event Nombre del evento
    @param handler Función manejadora o ID del manejador
]]
function events:Unsubscribe(event, handler)
    if not eventHandlers[event] then return end
    
    for i, h in ipairs(eventHandlers[event]) do
        if h.id == handler or h.handler == handler then
            table.remove(eventHandlers[event], i)
            break
        end
    end
    
    -- Eliminar la tabla de eventos si está vacía
    if #eventHandlers[event] == 0 then
        eventHandlers[event] = nil
    end
end

--[[
    Publica un evento personalizado
    @param event Nombre del evento
    @param ... Argumentos a pasar a los manejadores
]]
function events:Publish(event, ...)
    if not eventHandlers[event] then return end
    
    -- Hacer una copia de los manejadores para evitar problemas si se modifican durante la ejecución
    local handlers = {}
    for _, h in ipairs(eventHandlers[event] or {}) do
        table.insert(handlers, h)
    end
    
    for _, h in ipairs(handlers) do
        local success, err = pcall(h.handler, ...)
        if not success then
            geterrorhandler()(format("Error in event handler for '%s': %s", event, tostring(err)))
        end
    end
end

--[[
    Registra un manejador para un evento de WoW
    @param event Nombre del evento de WoW
    @param handler Función manejadora (opcional)
    @param priority Prioridad (opcional, por defecto 50)
    @return ID del manejador (si se proporciona handler)
]]
function events:RegisterEvent(event, handler, priority)
    if not eventFrame:IsEventRegistered(event) then
        eventFrame:RegisterEvent(event)
    end
    if handler then
        return self:Subscribe(event, handler, priority)
    end
end

--[[
    Elimina el registro de un manejador de eventos de WoW
    @param event Nombre del evento de WoW
    @param handler Función manejadora o ID del manejador
]]
function events:UnregisterEvent(event, handler)
    self:Unsubscribe(event, handler)
    
    -- Desregistrar el evento de WoW si no hay más manejadores
    if not eventHandlers[event] or #eventHandlers[event] == 0 then
        eventFrame:UnregisterEvent(event)
    end
end

-- Manejador de eventos de WoW


-- Crear la tabla de eventos local primero
local EVENTS = {
    -- Eventos de inicialización
    ADDON_LOADED = "ADDON_LOADED",
    PLAYER_LOGIN = "PLAYER_LOGIN",
    PLAYER_LOGOUT = "PLAYER_LOGOUT",
    
    -- Eventos personalizados
    ASSIGNMENTS_UPDATED = "ASSIGNMENTS_UPDATED",
    
    -- Eventos de grupo/raid
    GROUP_ROSTER_UPDATE = "GROUP_ROSTER_UPDATE",
    PARTY_LEADER_CHANGED = "PARTY_LEADER_CHANGED",
    RAID_ROSTER_UPDATE = "RAID_ROSTER_UPDATE",
    READY_CHECK = "READY_CHECK",
    READY_CHECK_CONFIRM = "READY_CHECK_CONFIRM",
    READY_CHECK_FINISHED = "READY_CHECK_FINISHED",
    
    -- Eventos de combate
    PLAYER_REGEN_DISABLED = "PLAYER_REGEN_DISABLED",
    PLAYER_REGEN_ENABLED = "PLAYER_REGEN_ENABLED",
    PLAYER_DEAD = "PLAYER_DEAD",
    PLAYER_ALIVE = "PLAYER_ALIVE",
    PLAYER_UNGHOST = "PLAYER_UNGHOST",
    
    -- Eventos de hermandad
    GUILD_ROSTER_UPDATE = "GUILD_ROSTER_UPDATE",
    GUILD_MOTD = "GUILD_MOTD",
    CHAT_MSG_SYSTEM = "CHAT_MSG_SYSTEM",
    
    -- Eventos de UI
    UI_SCALE_CHANGED = "UI_SCALE_CHANGED",
    
    -- Eventos personalizados
    CONFIG_CHANGED = "CONFIG_CHANGED",
    ROLE_UPDATE = "ROLE_UPDATE",
    BUFF_UPDATE = "BUFF_UPDATE",
    MESSAGE_RECEIVED = "MESSAGE_RECEIVED",
    
    -- Eventos de depuración
    DEBUG_MESSAGE = "DEBUG_MESSAGE",
    ERROR_OCCURRED = "ERROR_OCCURRED",
    ERROR_EVENT_HANDLER = "ERROR_EVENT_HANDLER"
}

-- Función para inicializar el sistema de eventos
events.Initialize = function()
    -- Inicializar el manejador de eventos de WoW
    eventFrame:SetScript("OnEvent", function(_, event, ...)
        -- Publicar el evento a los suscriptores
        events:Publish(event, ...)
    end)
    
    -- Registrar eventos del sistema
    events:RegisterSystemEvents()
    
    return true
end

-- Función para registrar eventos del sistema
function events:RegisterSystemEvents()
    -- Evento de cambio de configuración
    self:Subscribe("CONFIG_CHANGED", function(configKey)
        local RD = _G.RaidDominion
        if RD and RD.UI and RD.UI.DynamicMenus and RD.UI.DynamicMenus.UpdateMenu and configKey then
            RD.UI.DynamicMenus:UpdateMenu(configKey)
        end
    end, PRIORITY.HIGH)
    
    -- Registrar eventos del sistema
    self:RegisterEvent("ADDON_LOADED")
    self:RegisterEvent("PLAYER_LOGIN")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    
    -- Crear grupos de eventos comunes
    self:CreateEventGroup("GROUP_EVENTS", {
        "GROUP_ROSTER_UPDATE",
        "PARTY_LEADER_CHANGED",
        "RAID_ROSTER_UPDATE"
    })
    
    self:CreateEventGroup("COMBAT_EVENTS", {
        "PLAYER_REGEN_DISABLED",
        "PLAYER_REGEN_ENABLED",
        "PLAYER_DEAD",
        "PLAYER_ALIVE",
        "PLAYER_UNGHOST"
    })
    
end

-- Suscribirse a eventos de depuración
events:Subscribe("ERROR_EVENT_HANDLER", function(event, errorMsg, stackTrace)
    local msg = string.format("|cffff0000[%s] Error en manejador de eventos: %s|r\n%s", 
        addonName, tostring(errorMsg), tostring(stackTrace))
    geterrorhandler()(msg)
end, PRIORITY.HIGHEST)

-- Inicializar la tabla global si no existe
if not RaidDominion then
    RaidDominion = {}
end

-- Asignar el módulo de eventos
RaidDominion.events = events
RaidDominion.events.EVENTS = EVENTS

-- Inicializar el sistema de eventos cuando se cargue el addon
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:SetScript("OnEvent", function(_, _, loadedAddon)
    if loadedAddon == addonName then
        events:Initialize()
        initFrame:UnregisterAllEvents()
    end
end)

-- Registrar eventos importantes por defecto
-- Registrar eventos del juego
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_LOGOUT")
events:RegisterEvent("CHAT_MSG_SYSTEM")
events:RegisterEvent("GUILD_ROSTER_UPDATE")

return events
