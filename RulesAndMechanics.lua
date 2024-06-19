function rulesAndMechanicsInit()
    -- Dropdown para rulesAndMechanics
    local raidDropdown = CreateFrame("Frame", "RaidDropdown", RaidDominionRoleTab, "UIDropDownMenuTemplate")
    raidDropdown:SetPoint("TOPLEFT", RaidDominionRoleTab, -4, -55)
    UIDropDownMenu_SetWidth(raidDropdown, 117)
    UIDropDownMenu_SetText(raidDropdown, "REGLAS")

    -- Dropdown para bosses
    local bossDropdown = CreateFrame("Frame", "BossDropdown", RaidDominionRoleTab, "UIDropDownMenuTemplate")
    bossDropdown:SetPoint("TOPRIGHT", RaidDominionRoleTab, -73, -55)
    UIDropDownMenu_SetWidth(bossDropdown, 117)
    UIDropDownMenu_SetText(bossDropdown, "MECANICAS")

    local rulesAndMechanics = rulesAndMechanics -- Asignamos el diccionario de rulesAndMechanics a una variable local
    local selectedRaid, selectedBoss -- Variables para almacenar las selecciones actuales

    -- Función para inicializar el dropdown de bosses
    function InitializeBossesDropdown()
        UIDropDownMenu_ClearAll(bossDropdown)
        UIDropDownMenu_SetText(bossDropdown, "MECANICAS")
        if selectedRaid and rulesAndMechanics[selectedRaid]["MECHANICS"] then
            local bosses = rulesAndMechanics[selectedRaid]["MECHANICS"]
            local info = UIDropDownMenu_CreateInfo()
            for bossName, _ in pairs(bosses) do
                info.text = bossName
                info.func = function(self)
                    UIDropDownMenu_SetSelectedName(bossDropdown, self:GetText())
                    selectedBoss = self:GetText()
                end
                UIDropDownMenu_AddButton(info)
            end
        end
    end

    -- Función para inicializar el dropdown de rulesAndMechanics
    function InitializeRaidsDropdown()
        local info = UIDropDownMenu_CreateInfo()
        for raidName, _ in pairs(rulesAndMechanics) do
            info.text = raidName
            info.func = function(self)
                UIDropDownMenu_SetSelectedName(raidDropdown, self:GetText())
                selectedRaid = self:GetText()
                InitializeBossesDropdown() -- Actualizar el dropdown de bosses basado en la raid seleccionada
            end
            UIDropDownMenu_AddButton(info)
        end
    end

    UIDropDownMenu_Initialize(raidDropdown, InitializeRaidsDropdown)
    UIDropDownMenu_Initialize(bossDropdown, InitializeBossesDropdown)

    -- Botón de alerta para las reglas de la raid seleccionada
    local alertRaidRulesButton = CreateFrame("Button", nil, RaidDominionRoleTab, "RaidAssistButtonTemplate")
    alertRaidRulesButton:GetFontString():SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    alertRaidRulesButton:SetPoint("LEFT", RaidDropdown, "RIGHT", 15, 2)
    alertRaidRulesButton:SetText("!")
    alertRaidRulesButton:SetSize(26, 26)
    alertRaidRulesButton:SetScript("OnClick", function()
        if selectedRaid and rulesAndMechanics[selectedRaid] and rulesAndMechanics[selectedRaid]["RULES"] then
            -- Obtener el número de jugadores y las reglas compartidas
            local numberOfPlayers, _ = getPlayerInitialState()
            local sharedRules = rulesAndMechanics[selectedRaid]["RULES"]["SHARED"]

            -- Obtener las reglas específicas para la cantidad de jugadores
            local specificRules
            if numberOfPlayers <= 10 then
                specificRules = rulesAndMechanics[selectedRaid]["RULES"]["10"]
            else
                specificRules = rulesAndMechanics[selectedRaid]["RULES"]["25"]
            end

            -- Combinar las reglas compartidas y específicas en un solo mensaje
            local combinedRules = {}
            table.insert(combinedRules, selectedRaid)
            for _, rule in ipairs(sharedRules) do
                table.insert(combinedRules, rule)
            end
            if specificRules then
                for _, rule in ipairs(specificRules) do
                    table.insert(combinedRules, rule)
                end
            end

            -- Enviar todas las reglas
            SendDelayedMessages(combinedRules)
        else
            print("La raid seleccionada no tiene reglas definidas.")
        end
    end)

    -- Botón de alerta para los detalles del boss seleccionado
    local alertBossDetailsButton = CreateFrame("Button", nil, RaidDominionRoleTab, "RaidAssistButtonTemplate")
    alertBossDetailsButton:SetPoint("LEFT", bossDropdown, "RIGHT", 14, 2)
    alertBossDetailsButton:GetFontString():SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    alertBossDetailsButton:SetText("!")
    alertBossDetailsButton:SetSize(26, 26)
    alertBossDetailsButton:SetScript("OnClick", function()
        if selectedRaid and selectedBoss and rulesAndMechanics[selectedRaid]["MECHANICS"][selectedBoss] then
            -- Crear una copia del array de reglas para no modificar el original
            local howToBoss = {unpack(rulesAndMechanics[selectedRaid]["MECHANICS"][selectedBoss])}
            -- Insertar un nuevo elemento al inicio del array
            table.insert(howToBoss, 1, "MECANICAS DE " .. selectedBoss)

            -- Enviar las reglas, ahora incluyendo el nuevo elemento al inicio
            SendDelayedMessages(howToBoss,true)
        end
    end)

    -- Botón de reseteo para rulesAndMechanics
    local resetRaidButton = CreateFrame("Button", nil, RaidDominionRoleTab, "RaidAssistButtonTemplate")
    resetRaidButton:GetFontString():SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    resetRaidButton:SetText("X")
    resetRaidButton:SetPoint("RIGHT", raidDropdown, 13, 2)
    resetRaidButton:SetSize(26, 26)
    resetRaidButton:SetScript("OnClick", function()
        UIDropDownMenu_SetText(raidDropdown, "REGLAS")
        UIDropDownMenu_SetText(bossDropdown, "MECANICAS")
        selectedRaid = nil
        selectedBoss = nil
        InitializeBossesDropdown()
    end)

    -- Botón de reseteo para bosses
    local resetBossButton = CreateFrame("Button", nil, RaidDominionRoleTab, "RaidAssistButtonTemplate")
    resetBossButton:GetFontString():SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    resetBossButton:SetText("X")
    resetBossButton:SetPoint("RIGHT", bossDropdown, 13, 2)
    resetBossButton:SetSize(26, 26)
    resetBossButton:SetScript("OnClick", function()
        UIDropDownMenu_SetText(bossDropdown, "MECANICAS")
        selectedBoss = nil
    end)

end
