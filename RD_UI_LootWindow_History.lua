--[[
    RD_UI_LootWindow_History.lua
    PROPÓSITO: Vista "Historial" del gestor de botín (RD_UI_LootWindow). Lleva el
              registro por día y lo muestra AGRUPADO POR ÍTEM: cada ítem agrupa
              sus dados y al ganador (la entrega), resaltando en dorado el dado
              del ganador. Navegación por días mediante un dropdown compacto y
              una lista scrollable. Separado para mantener el archivo principal
              ≤ ~700 líneas.
    API PÚBLICA:
        - RD.ui.lootWindow:BuildHistoryView(historyView)  -- construye la vista
        - RD.ui.lootWindow:SetView("loot"|"history")
        - RD.ui.lootWindow:RefreshHistory() / BuildItemHistoryRows(items)
    EVENTOS: LOOT_HISTORY_ADDED (refresca la vista si está activa).
]]

local addonName, private = ...
local RD = _G.RaidDominion or {}
_G.RaidDominion = RD

local Win = RD.ui and RD.ui.lootWindow
if not Win then
    Win = {}
    RD.ui = RD.ui or {}
    RD.ui.lootWindow = Win
end

local PAD = 12
local GOLD = (RD.constants and RD.constants.COLORS and RD.constants.COLORS.GOLD) or { 1, 0.82, 0 }
local GOLD_R, GOLD_G, GOLD_B = GOLD[1], GOLD[2], GOLD[3]

-- Construye la vista de historial dentro del contenedor historyView. El dropdown
-- de días se reconstruye en RefreshHistory (para reflejar días nuevos).
function Win:BuildHistoryView(historyView)
    if not historyView then return end
    if self._historyBuilt then return end
    self._historyBuilt = true

    local label = historyView:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetText("Historial por día:")
    label:SetTextColor(0.8, 0.8, 0.8)
    label:SetPoint("TOPLEFT", historyView, "TOPLEFT", PAD, -36)

    -- Lista de registros del día con scroll.
    local innerW = (historyView:GetWidth() or 396) - PAD * 2
    self.histScroll, self.histChild = RD.ui.widgets.CreateScrollFrame(historyView, innerW - 28, 150, PAD, -70)
    self.histEmptyText = self.histChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.histEmptyText:SetPoint("TOPLEFT", self.histChild, "TOPLEFT", 0, 0)
    self.histEmptyText:SetText("(sin registros para este día)")
    self.histEmptyText:SetTextColor(0.7, 0.7, 0.7)
    self.histRows = {}
    self.histChild:SetHeight(150)
    if self.histScroll and self.histScroll.SetVerticalScroll then
        self.histScroll:SetVerticalScroll(0)
    end

    -- Resumen inferior: total de ítems entregados y de dados del día.
    self.histSummary = historyView:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.histSummary:SetPoint("TOPLEFT", historyView, "TOPLEFT", PAD, -228)
    self.histSummary:SetTextColor(GOLD_R, GOLD_G, GOLD_B)
end

-- Cambia entre las vistas ("loot" y "history") y resalta la pestaña activa
-- ("Dados" / "Historial"). El título de la ventana se mantiene "Gestor de botín".
function Win:SetView(view)
    view = (view == "history") and "history" or "loot"
    self.view = view
    if RD.UIUtils and RD.UIUtils.PaintTabButton then
        for key, btn in pairs(self.viewTabButtons or {}) do
            RD.UIUtils.PaintTabButton(btn, key == view)
        end
    end
    if self.mainView and self.historyView then
        if view == "history" then
            self.mainView:Hide()
            self.historyView:Show()
            self:RefreshHistory()
        else
            self.historyView:Hide()
            self.mainView:Show()
            self:Refresh()
        end
    end
end

-- Refresca el historial por día: reconstruye el dropdown de días y muestra el
-- resumen + los registros del día seleccionado.
function Win:RefreshHistory()
    if not self.frame or not self.historyView then return end
    local loot = RD.modules and RD.modules.loot
    if not loot or not loot.GetDailyHistory then return end
    local groups, order = loot:GetDailyHistory()

    -- Si no hay día seleccionado o ya no existe, elige el más reciente.
    if not self.selectedDay or not groups[self.selectedDay] then
        self.selectedDay = order[1] or ""
    end

    -- Reconstruye el dropdown de días solo si cambió la lista (días nuevos o
    -- selección) para no recrear el widget en cada tick.
    local key = table.concat(order, ";") .. "|" .. tostring(self.selectedDay)
    if key ~= self._histDropdownKey then
        self._histDropdownKey = key
        if self.historyDropdown and self.historyDropdown.button then
            self.historyDropdown.button:Hide()
            self.historyDropdown.button:SetParent(nil)
            self.historyDropdown = nil
        end
        local opts = {}
        for _, day in ipairs(order) do
            opts[#opts + 1] = { key = day, label = day }
        end
        self.historyDropdown = RD.ui.widgets.CreateOptionsDropdown
            and RD.ui.widgets:CreateOptionsDropdown(self.historyView, 160, {
                emptyLabel = "Sin registros",
                current = self.selectedDay,
                options = opts,
                onSelect = function(day)
                    self.selectedDay = day or ""
                    self:RefreshHistory()
                end,
            })
        if self.historyDropdown and self.historyDropdown.button then
            self.historyDropdown.button:SetPoint("TOPLEFT", self.historyView, "TOPLEFT", PAD + 100, -32)
            self.historyDropdown.button:SetHeight(24)
            if RD.UIUtils and RD.UIUtils.StyleTitleDropdown then
                RD.UIUtils.StyleTitleDropdown(self.historyDropdown)
            end
        end
    elseif self.historyDropdown and self.historyDropdown.SetValue then
        self.historyDropdown:SetValue(self.selectedDay)
    end

    local day = self.selectedDay or order[1] or ""
    local records = groups[day] or {}
    local items = (loot.GroupByItem and loot:GroupByItem(records)) or {}
    self:BuildItemHistoryRows(items)

    -- Resumen: nº de ítems y de dados del día.
    local nRolls = 0
    for _, it in ipairs(items) do
        nRolls = nRolls + #(it.rolls or {})
    end
    if self.histSummary then
        self.histSummary:SetText(string.format("Ítems: %d  ·  Dados: %d", #items, nRolls))
    end
end

-- Construye la lista del día agrupada POR ÍTEM dentro del scroll. Cada ítem
-- se muestra como: cabecera dorada con el nombre, una fila por dado, y una fila
-- de "Ganador" (si el ítem se entregó). El dado del ganador se resalta en
-- dorado. Así el historial queda agrupado y legible por ítem.
function Win:BuildItemHistoryRows(items)
    if not self.histChild then return end
    for _, row in ipairs(self.histRows) do
        row:Hide()
        row:SetParent(nil)
    end
    self.histRows = {}

    if not items or #items == 0 then
        if self.histEmptyText then
            self.histEmptyText:SetText("(sin registros para este día)")
            self.histEmptyText:Show()
        end
        self.histChild:SetHeight(150)
        if self.histScroll and self.histScroll.SetVerticalScroll then
            self.histScroll:SetVerticalScroll(0)
        end
        return
    end
    if self.histEmptyText then self.histEmptyText:Hide() end

    local rowH, gap = 20, 2
    local childW = self.histChild:GetWidth() or 368

    -- Alto total: por cada ítem, cabecera + sus dados + el ganador (si hay).
    local totalRows = 0
    for _, it in ipairs(items) do
        totalRows = totalRows + 1 + #(it.rolls or {}) + (it.winner and 1 or 0)
    end
    self.histChild:SetHeight(totalRows * (rowH + gap) + gap)

    local y = 0
    local function AddRow()
        local row = CreateFrame("Button", nil, self.histChild)
        row:SetSize(childW, rowH)
        row:SetPoint("TOPLEFT", self.histChild, "TOPLEFT", 0, y)
        row:SetHighlightTexture("Interface\\Buttons\\UI-Listbox-Highlight", "ADD")
        y = y - (rowH + gap)
        self.histRows[#self.histRows + 1] = row
        return row
    end

    for _, it in ipairs(items) do
        local itemName = it.itemLink and it.itemLink:match("%[([^%]]+)%]") or (it.itemLink or "Ítem")

        -- Cabecera del ítem (dorada, con punto por textura)
        local header = AddRow()
        local hDot = header:CreateTexture(nil, "OVERLAY")
        hDot:SetSize(8, 8)
        hDot:SetPoint("LEFT", header, "LEFT", 3, 0)
        hDot:SetTexture(GOLD_R, GOLD_G, GOLD_B, 1)
        local hText = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        hText:SetPoint("LEFT", header, "LEFT", 16, 0)
        hText:SetPoint("RIGHT", header, "RIGHT", -4, 0)
        hText:SetJustifyH("LEFT")
        hText:SetText(itemName)
        hText:SetTextColor(GOLD_R, GOLD_G, GOLD_B)
        if RD.UIUtils and RD.UIUtils.AddButtonTooltip then
            RD.UIUtils.AddButtonTooltip(header, function()
                return "Ítem: " .. (it.itemLink or itemName)
            end)
        end

        -- Dados del ítem
        for _, r in ipairs(it.rolls or {}) do
            local row = AddRow()
            local text = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            text:SetPoint("LEFT", row, "LEFT", 20, 0)
            text:SetPoint("RIGHT", row, "RIGHT", -4, 0)
            text:SetJustifyH("LEFT")
            local isWinner = (it.winner == r.player)
            text:SetText(string.format("%s — dado %d", r.player or "?", r.roll or 0))
            text:SetTextColor(isWinner and GOLD_R or 1, isWinner and GOLD_G or 1, isWinner and GOLD_B or 1)
            if RD.UIUtils and RD.UIUtils.AddButtonTooltip then
                RD.UIUtils.AddButtonTooltip(row, function()
                    return string.format("Dado de %s: %d", r.player or "?", r.roll or 0)
                end)
            end
        end

        -- Ganador (entrega del ítem)
        if it.winner then
            local row = AddRow()
            local dot = row:CreateTexture(nil, "OVERLAY")
            dot:SetSize(8, 8)
            dot:SetPoint("LEFT", row, "LEFT", 3, 0)
            dot:SetTexture(GOLD_R, GOLD_G, GOLD_B, 1)
            local text = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            text:SetPoint("LEFT", row, "LEFT", 16, 0)
            text:SetPoint("RIGHT", row, "RIGHT", -4, 0)
            text:SetJustifyH("LEFT")
            local typeText = ({ [1] = "Main", [2] = "Dual", [3] = "Enchant" })[it.rollType] or "Main"
            text:SetText(string.format("Ganador: %s (dado %d, %s)", it.winner, it.winnerRoll or 0, typeText))
            text:SetTextColor(GOLD_R, GOLD_G, GOLD_B)
            if RD.UIUtils and RD.UIUtils.AddButtonTooltip then
                RD.UIUtils.AddButtonTooltip(row, function()
                    return string.format("Ítem entregado a %s (%s, dado %d)", it.winner, typeText, it.winnerRoll or 0)
                end)
            end
        end
    end
    if self.histScroll and self.histScroll.SetVerticalScroll then
        self.histScroll:SetVerticalScroll(0)
    end
end

return Win
