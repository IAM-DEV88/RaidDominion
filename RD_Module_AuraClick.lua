--[[
    RD_Module_AuraClick.lua
    PROPÓSITO: Anunciar buffs/debuffs de la UI base de Wow (jugador y objetivo)
              con su duración al hacer CLIC IZQUIERDO sobre el icono del aura.
              Replica el mecanismo del addon base v2: los botones de aura de
              3.3.5a NO están registrados para OnClick, así que se usa
              OnMouseUp + EnableMouse(true), el índice del aura viene de
              GetID() y los prefijos de botón del objetivo son
              TargetFrameBuff/TargetFrameDebuff. Los botones se CREAN de forma
              dinámica (aparecen/desaparecen con las auras), por eso se
              re-hookean en cada evento relevante (UNIT_AURA, cambio de
              objetivo, roster, etc.); el flag rdAuraHooked evita re-hookear.
    API PÚBLICA:
        - RD.modules.auraClick:Initialize()  -- hookea los botones de aura
    EVENTOS: PLAYER_TARGET_CHANGED, GROUP_ROSTER_UPDATE, UNIT_AURA(player/target),
             UNIT_INVENTORY_CHANGED, PLAYER_LOGIN, PLAYER_ENTERING_WORLD.
]]

local addonName, private = ...
local RD = _G.RaidDominion or {}
_G.RaidDominion = RD

local AuraClick = {}

-- Grupos de botones de aura de la UI base: prefijo global, cuántos botones,
-- la unidad y si son buffs (UnitBuff) o debuffs (UnitDebuff).
local GROUPS = {
    { prefix = "BuffButton",        count = 40, unit = "player", isBuff = true },
    { prefix = "DebuffButton",      count = 40, unit = "player", isBuff = false },
    { prefix = "TargetFrameBuff",   count = 40, unit = "target", isBuff = true },
    { prefix = "TargetFrameDebuff", count = 40, unit = "target", isBuff = false },
}

-- Listas asignables y su etiqueta para el mensaje de aviso
local ASSIGNABLE = {
    { key = "roles",     label = "Rol" },
    { key = "abilities", label = "Habilidad" },
    { key = "buffs",     label = "Buff" },
    { key = "auras",     label = "Aura" },
}

-- Normaliza un nombre (sin sufijo de reino, minúsculas) para comparar.
local function Normalize(name)
    if RD.UIUtils and RD.UIUtils.CleanName then
        return RD.UIUtils.CleanName(name)
    end
    local clean = string.gsub(tostring(name or ""), "%-.*", "")
    clean = string.gsub(clean, "%s+", "")
    return string.lower(clean)
end

-- Si el aura corresponde a un ítem asignable configurado (p.ej. un rol),
-- devuelve { label, itemName, assigned } para incluirlo en el mensaje.
local function FindAssignableContext(name)
    local key = Normalize(name)
    if key == "" then return nil end
    for _, entry in ipairs(ASSIGNABLE) do
        local items = RD.config and RD.config.Get and RD.config:Get(entry.key, {}) or {}
        if type(items) == "table" then
            for _, item in ipairs(items) do
                local itemName = item.name or item.title or ""
                if Normalize(itemName) == key then
                    local assigned = nil
                    local assign = RD.utils and RD.utils.assignments
                    if assign and assign.Get then
                        assigned = assign:Get(entry.key, itemName)
                    end
                    return { label = entry.label, itemName = itemName, assigned = assigned }
                end
            end
        end
    end
    return nil
end

-- Anuncia el aura por el canal configurado con el formato del addon base.
-- Si el aura tiene una ASIGNACIÓN (p.ej. un rol asignado a un jugador), se
-- incluye en el mensaje (" | Rol: <jugador>").
local function SendAuraMessage(name, duration, expirationTime)
    if not name then return end
    local message
    if not expirationTime or expirationTime == 0 then
        message = string.format("Aura: %s (permanente)", name)
    else
        local timeLeft = expirationTime - GetTime()
        if timeLeft <= 0 then
            message = string.format("Aura: %s - Tiempo agotado", name)
        else
            local hours = math.floor(timeLeft / 3600)
            local minutes = math.floor((timeLeft % 3600) / 60)
            local seconds = math.floor(timeLeft % 60)
            if hours > 0 then
                message = string.format("Aura: %s - Tiempo restante: %d:%02d:%02d", name, hours, minutes, seconds)
            else
                message = string.format("Aura: %s - Tiempo restante: %d:%02d", name, minutes, seconds)
            end
        end
    end
    local context = FindAssignableContext(name)
    if context and context.assigned and context.assigned ~= "" then
        message = message .. " || " .. context.label .. ": " .. context.assigned
    end
    local mm = RD.modules and RD.modules.messageManager
    if mm and mm.SendMessage then
        mm:SendMessage(message)
    end
end

-- Hookea un botón de aura con OnMouseUp (no OnClick: los botones de aura de
-- 3.3.5a no están registrados para clics). Conserva el OnMouseUp previo y
-- protege el anuncio con pcall. Idempotente por rdAuraHooked.
local function HookAuraButton(btn, unit, isBuff)
    if not btn or not btn.SetScript or btn.rdAuraHooked then return end
    btn.rdAuraHooked = true
    if btn.EnableMouse then btn:EnableMouse(true) end
    local orig = btn.GetScript and btn:GetScript("OnMouseUp") or nil
    btn:SetScript("OnMouseUp", function(self, button)
        if orig then orig(self, button) end
        if button == "LeftButton" then
            local ok, err = pcall(function()
                local idx = self:GetID() or 0
                if idx >= 1 then
                    local name, _, _, _, _, duration, expirationTime
                    if isBuff then
                        name, _, _, _, _, duration, expirationTime = UnitBuff(unit, idx)
                    else
                        name, _, _, _, _, duration, expirationTime = UnitDebuff(unit, idx)
                    end
                    SendAuraMessage(name, duration, expirationTime)
                end
            end)
            if not ok and RD.messageManager and RD.messageManager.SendSystemMessage then
                RD.messageManager:SendSystemMessage("|cffff0000[RaidDominion]|r Error al anunciar aura: " .. tostring(err))
            end
        end
    end)
end

-- Recorre todos los grupos y hookea los botones que existan ahora (los botones
-- de aura se crean/eliminan dinámicamente; los ya hookeados se omiten).
local function HookAllAuras()
    for _, group in ipairs(GROUPS) do
        for i = 1, group.count do
            local btn = _G[group.prefix .. i]
            if btn then
                HookAuraButton(btn, group.unit, group.isBuff)
            end
        end
    end
end

-- Escucha los eventos en los que la UI crea/actualiza botones de aura y
-- re-hookea (barato: solo chequea el flag rdAuraHooked).
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_TARGET_CHANGED")
f:RegisterEvent("GROUP_ROSTER_UPDATE")
f:RegisterEvent("UNIT_AURA")
f:RegisterEvent("UNIT_INVENTORY_CHANGED")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function(self, event, unit)
    if event == "UNIT_AURA" then
        if unit == "player" or unit == "target" then
            HookAllAuras()
        end
    else
        HookAllAuras()
    end
end)

-- Hook inicial (y asegura el frame de eventos).
function AuraClick:Initialize()
    if self.isInitialized then return end
    self.isInitialized = true
    HookAllAuras()
end

RD.modules = RD.modules or {}
RD.modules.auraClick = AuraClick
return AuraClick
