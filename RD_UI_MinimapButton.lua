--[[
    RD_UI_MinimapButton.lua
    PROPÓSITO: Botón de minimapa (versión mejorada, similar al addon base v2).
              Clic izquierdo: alterna el menú flotante. Clic derecho: menú
              contextual (Configuración / Gestor de botín / Recoger items /
              Spamear reglas / Spamear banda / Mover / Recargar UI). Los ítems
              de botín y spam solo aparecen cuando están disponibles. Se
              arrastra alrededor del minimapa manteniendo Alt; la posición
              angular se guarda en config (ui.minimap.position). Sin OnUpdate
              continuo: solo se activa un OnUpdate mientras se arrastra.
    API PÚBLICA:
        - RD.ui.minimapButton:Initialize()
        - RD.ui.minimapButton:Show() / Hide() / Toggle()
    EVENTOS: Se inicializa desde RD_Init en PLAYER_LOGIN.
]]

local addonName, private = ...
local RD = _G.RaidDominion or {}
_G.RaidDominion = RD

local MINIMAP_ICON = "Interface\\Icons\\INV_Misc_SummerFest_BrazierOrange"
local BUTTON_SIZE = 26
local RADIUS = 80
local DEFAULT_POS = (RD.constants and RD.constants.DEFAULT_CONFIG
    and RD.constants.DEFAULT_CONFIG.ui and RD.constants.DEFAULT_CONFIG.ui.minimap
    and RD.constants.DEFAULT_CONFIG.ui.minimap.position) or 0.75

local MinimapButton = {
    button = nil,
    menuFrame = nil,
    isMoving = false,
    isInitialized = false,
}

local function GetPos()
    return (RD.config and RD.config.Get and RD.config:Get("ui.minimap.position", DEFAULT_POS)) or DEFAULT_POS
end

local function SetPos(pos)
    if RD.config and RD.config.Set then
        RD.config:Set("ui.minimap.position", pos)
    end
end

local function UpdatePosition()
    local btn = MinimapButton.button
    if not btn or not Minimap then return end
    local angle = GetPos() * 2 * math.pi
    -- Offsets ENTEROS (sin subpíxeles borrosos/brincando durante el arrastre).
    -- El ancla no cambia (siempre CENTER), así que SetPoint re-posiciona solo.
    btn:SetPoint("CENTER", Minimap, "CENTER",
        math.floor(math.cos(angle) * RADIUS + 0.5),
        math.floor(math.sin(angle) * RADIUS + 0.5))
end

local function ToggleFloatingMenu()
    local mf = RD.ui and RD.ui.menuFrame
    if mf and mf.Toggle then mf:Toggle() end
end

-- "Configuración" del menú contextual: abre SIEMPRE la ventana de configuración
-- en la pestaña General.
local function OpenConfigGeneral()
    local cw = RD.ui and RD.ui.configWindow
    if not cw or not cw.Show then return end
    cw:Show()
    if cw.SelectTabById then
        cw:SelectTabById("general")
    end
end

-- Arrastre: sigue el cursor alrededor del minimapa. Solo activo durante el
-- arrastre (se limpia el OnUpdate al soltar o si se suelta Alt).
local function DragUpdate(self)
    if not MinimapButton.isMoving then
        self:SetScript("OnUpdate", nil)
        return
    end
    if not IsAltKeyDown() then
        MinimapButton.isMoving = false
        self:SetScript("OnUpdate", nil)
        return
    end
    local mx, my = Minimap:GetCenter()
    local px, py = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    local angle = math.atan2(py / scale - my, px / scale - mx)
    local pos = (angle % (2 * math.pi)) / (2 * math.pi)
    SetPos(pos)
    UpdatePosition()
end

local function StartDrag(self)
    MinimapButton.isMoving = true
    self:SetScript("OnUpdate", DragUpdate)
end

local function StopDrag(self)
    MinimapButton.isMoving = false
    self:SetScript("OnUpdate", nil)
end

-- Menú contextual derecho (clic derecho). El frame se reutiliza (sin acumular
-- huérfanos) pero EasyMenu debe llamarse en CADA clic para re-mostrar el menú:
-- devolver el frame sin llamarlo era la causa de que solo apareciera una vez.
local function OpenContextMenu()
    if not MinimapButton.menuFrame then
        MinimapButton.menuFrame = CreateFrame("Frame", "RaidDominionMinimapMenu", UIParent, "UIDropDownMenuTemplate")
    end
    local items = {
        { text = "Configuración", func = function()
            OpenConfigGeneral()
        end },
    }

    -- Acciones de botín y spammers: se añaden solo cuando están disponibles
    -- (cada una guarda por la existencia de su módulo/ventana; "Spamear banda"
    -- además exige al menos una banda registrada). Así el menú nunca muestra
    -- ítems inutilizables y conserva al menos un elemento de acción.
    local lootWin = RD.ui and RD.ui.lootWindow
    if lootWin and lootWin.Open then
        items[#items + 1] = { text = "Gestor de botín", func = function()
            pcall(lootWin.Open, lootWin)
        end }
    end
    local loot = RD.modules and RD.modules.loot
    if loot and loot.CollectItems then
        items[#items + 1] = { text = "Recoger items", func = function()
            loot:CollectItems()
        end }
    end
    local rulesWin = RD.ui and RD.ui.rulesSpammerWindow
    if rulesWin and rulesWin.Open then
        items[#items + 1] = { text = "Spamear reglas", func = function()
            rulesWin:Open()
        end }
    end
    local hasBand = false
    local bands = RD.utils and RD.utils.bands
    if bands and bands.GetBands then
        for _, b in ipairs(bands:GetBands() or {}) do
            hasBand = true
            break
        end
    end
    local spammerWin = RD.ui and RD.ui.spammerWindow
    if hasBand and spammerWin and spammerWin.OpenEmpty then
        items[#items + 1] = { text = "Spamear banda", func = function()
            spammerWin:OpenEmpty()
        end }
    end

    items[#items + 1] = { text = "Mover botón (Alt + arrastrar)", isTitle = true, notCheckable = true, notClickable = true }
    items[#items + 1] = { text = "Recargar UI", func = function()
        ReloadUI()
    end }
    EasyMenu(items, MinimapButton.menuFrame, "cursor", 0, 0, "MENU", 1)
end

local function OnMouseDown(self, button)
    if button == "LeftButton" then
        if IsAltKeyDown() then
            StartDrag(self)
        else
            ToggleFloatingMenu()
        end
    elseif button == "RightButton" then
            OpenContextMenu()
    end
end

local function OnEnter(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("|cfff58cbaRaidDominion|r")
    GameTooltip:AddLine("|cff00ff00Clic:|r Abrir/cerrar el menú flotante")
    GameTooltip:AddLine("|cff00ff00Clic derecho:|r Opciones")
    GameTooltip:AddLine("|cff00ff00Alt + arrastrar:|r Mover el botón")
    GameTooltip:Show()
end

local function OnLeave()
    GameTooltip:Hide()
end

function MinimapButton:Initialize()
    if self.isInitialized or not Minimap then return end

    local button = CreateFrame("Button", "RaidDominionMinimapButton", Minimap)
    button:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    -- Sin SetClampedToScreen: en un hijo de Minimap el clamp pelea con el
    -- posicionado angular (en cada frame de arrastre) y puede dejar el botón
    -- desplazado/no clicable. El radio 80 mantiene el botón dentro de la
    -- pantalla. Sin SetFrameStrata: un hijo no puede superar la strata de su
    -- padre (Minimap), así que se hereda.
    button:SetFrameLevel(8)
    button:SetMovable(true)
    button:SetDontSavePosition(true)

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexture(MINIMAP_ICON)
    button:SetNormalTexture(icon)

    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    highlight:SetBlendMode("ADD")
    highlight:SetAllPoints()
    button:SetHighlightTexture(highlight)

    local pushed = button:CreateTexture(nil, "OVERLAY")
    pushed:SetTexture(MINIMAP_ICON)
    pushed:SetAllPoints()
    pushed:SetAlpha(0.7)
    button:SetPushedTexture(pushed)

    button:SetScript("OnMouseDown", OnMouseDown)
    button:SetScript("OnMouseUp", function(self) StopDrag(self) end)
    button:SetScript("OnEnter", OnEnter)
    button:SetScript("OnLeave", OnLeave)

    self.button = button
    UpdatePosition()
    self.isInitialized = true
end

function MinimapButton:Show()
    if self.button then self.button:Show() end
end

function MinimapButton:Hide()
    if self.button then self.button:Hide() end
end

function MinimapButton:Toggle()
    if not self.button then self:Initialize() end
    if not self.button then return end
    if self.button:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

RD.ui = RD.ui or {}
RD.ui.minimapButton = MinimapButton

-- Slash command: /rdminimap
SLASH_RDMINIMAP1 = "/rdminimap"
SlashCmdList["RDMINIMAP"] = function()
    MinimapButton:Toggle()
end

return MinimapButton
