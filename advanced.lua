local addonName = "QuickName"
local numRaidButtons = 40 -- Ajusta esto según el número real de botones en tu RaidGroup

local skipCheckbox
local enabledAddonCheckbox
local addonCache
local characterRol = {"MAIN TANK", "HEALER 1", "OFF TANK", "HEALER 2", "HEALER 3", "HEALER 4", "HEALER 5",
                      "COLERA SAGRADA", "ENCADENAR NO MUERTO", "TIFON", "REDIRECCION", "TRAMPA DE ESCARCHA", "HEROISMO",
                      "MAESTRIA EN AURAS", -- PRIMEROS 14
"MIEDO", "RAICES ENREDADORAS", "AHUYENTAR EL MAL", "SALVAGUARDA", "PODERIO", "REYES", "SABIDURIA", "ENFOQUE",
                      "TOTEM DE MANA", "POLIMORFIA", "AURA DE DISPARO CERTERO", "DON DE LO SALVAJE",
                      "SECRETOS DEL OFICIO", -- PRIMEROS 28
"DESACTIVAR TRAMPA", "VIGILANCIA", "REZOS DE ESPIRITU, PROTECCION Y ENTEREZA", "MANO DE SACRIFICIO",
                      "MANO DE SALVACION", "IMPOSICION DE MANOS", "TOTEM DE NEXO TERRESTRE", "PIEDRA DE ALMA",
                      "FRAGMENTADOR"}

local dropdowns = {} -- Para mantener una referencia a cada dropdown creado

local function getPlayerInitialState()
    local playerChannel = "GUILD"
    local numberOfPlayers = 0
    local inRaid = GetNumRaidMembers() ~= 0 and true or false
    local playerRol = IsRaidLeader() and "RAID_WARNING" or "RAID"
    local inParty = GetNumPartyMembers() > 0 and true or false
    local inBG = UnitInBattleground("player")

    numberOfPlayers = inRaid and GetNumRaidMembers() or inBG and GetNumRaidMembers() or GetNumPartyMembers()

    playerChannel = inBG and "BATTLEGROUND" or inRaid and playerRol or inParty and "PARTY" or playerChannel

    return numberOfPlayers, playerChannel
end

local function CreateDropdown(parent, label, id, width, height, point, relativePoint, xOffset, yOffset)
    local dropdown = CreateFrame("Frame", "Dropdown" .. id, parent, "UIDropDownMenuTemplate")
    dropdown:SetPoint(point, xOffset, yOffset)
    UIDropDownMenu_SetWidth(dropdown, width)
    UIDropDownMenu_SetText(dropdown, label)

    -- Mantener una referencia al jugador seleccionado
    dropdown.selectedPlayer = nil

    -- Obtener los jugadores con rols asignados y sus rols respectivos
    local playersWithRoles = {}
    for playerName, playerData in pairs(addonCache) do
        if playerData.rol == label then
            table.insert(playersWithRoles, playerName)
        end
    end

    local playerName
    -- Función para establecer el valor del dropdown
    function dropdown:SetValue(newValue)
        UIDropDownMenu_SetText(self, newValue .. " " .. label)
        CloseDropDownMenus()
        playerName = self.selectedPlayer
        addonCache[newValue].rol = label
        for playerName, playerData in pairs(addonCache) do
            if playerData.rol == label then
                table.insert(playersWithRoles, playerName)
            end
        end
    end

    -- Si hay jugadores con rols asignados para este dropdown, establecer el texto del dropdown con el nombre del primer jugador
    if #playersWithRoles > 0 then
        UIDropDownMenu_SetText(dropdown, playersWithRoles[1] .. " " .. label)
        dropdown.selectedPlayer = playersWithRoles[1]
    end

    -- Botón para resetear la selección
    local resetButton = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    resetButton:GetFontString():SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE") -- Estableciendo la fuente y el tamaño
    resetButton:SetText("X")
    resetButton:SetPoint("LEFT", dropdown, "RIGHT", -13, 2)
    resetButton:SetSize(26, 26)
    resetButton:SetScript("OnClick", function()
        if not dropdown.selectedPlayer then
            local _, channel = getPlayerInitialState()
            SendChatMessage("Necesitamos [" .. label .. "]",channel)
        end
        UIDropDownMenu_SetText(dropdown, label) -- Restablecer el texto del dropdown al label inicial
        if playersWithRoles[1] then
            addonCache[playersWithRoles[1]].rol = nil
        end
        dropdown.selectedPlayer = nil -- Limpiar la selección del jugador
    end)

    -- Botón para alertar
    local alertButton = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    alertButton:GetFontString():SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE") -- Estableciendo la fuente y el tamaño
    alertButton:SetText("!")
    alertButton:SetPoint("LEFT", resetButton, "RIGHT", 2, 0)
    alertButton:SetSize(26, 26)
    alertButton:SetScript("OnClick", function()
        local playerName = dropdown.selectedPlayer
        local rol = label
        local _, channel = getPlayerInitialState()
        if playerName then
            local playerClass = addonCache[playerName].class
            playerClass = string.upper(string.sub(playerClass, 1, 1)) .. string.lower(string.sub(playerClass, 2)) -- Capitalizar la primera letra de playerClass
            SendChatMessage(playerClass .. " " .. playerName .. " [" .. rol .. "]", channel) -- Enviar mensaje de alerta al chat de banda
        else
            SendChatMessage("Se esta buscando [" .. rol .. "]", channel) -- Enviar mensaje si no hay ningún jugador seleccionado
        end
    end)

    return dropdown, resetButton, alertButton
end

-- Función para filtrar jugadores según la clase apta para el rol
local function filterPlayersByRol(rol)
    -- print("filterPlayersByRol: " .. rol)
    local filteredPlayers = {}
    for playerName, playerData in pairs(addonCache) do
        local playerClass = playerData.class
        if rol == "MAIN TANK" or rol == "OFF TANK" then
            if playerClass == "DRUID" or playerClass == "WARRIOR" or playerClass == "DEATHKNIGHT" or playerClass ==
                "PALADIN" then
                table.insert(filteredPlayers, playerName)
                -- print(playerName)
            end
        elseif rol:find("HEALER") then
            if playerClass == "DRUID" or playerClass == "PRIEST" or playerClass == "SHAMAN" or playerClass == "PALADIN" then
                table.insert(filteredPlayers, playerName)
                -- print(playerName)
            end
        elseif rol:find("FRAGMENTADOR") then
            if playerClass == "WARRIOR" or playerClass == "DEATHKNIGHT" or playerClass == "PALADIN" then
                table.insert(filteredPlayers, playerName)
                -- print(playerName)
            end
        elseif rol:find("SALVAGUARDA") or rol:find("PODERIO") or rol:find("REYES") or rol:find("SABIDURIA") then
            if playerClass == "PALADIN" then
                table.insert(filteredPlayers, playerName)
                -- print(playerName)
            end
        elseif rol:find("PIEDRA DE ALMA") or rol:find("MIEDO") then
            if playerClass == "WARLOCK" then
                table.insert(filteredPlayers, playerName)
                -- print(playerName)
            end
        elseif rol:find("ENFOQUE") or rol:find("POLIMORFIA") then
            if playerClass == "MAGE" then
                table.insert(filteredPlayers, playerName)
                -- print(playerName)
            end
        elseif rol:find("DON DE LO SALVAJE") or rol:find("RAICES ENREDADORAS") or rol:find("TIFON") then
            if playerClass == "DRUID" then
                table.insert(filteredPlayers, playerName)
                -- print(playerName)
            end
        elseif rol:find("HEROISMO") or rol:find("TOTEM DE MANA") or rol:find("TOTEM DE NEXO TERRESTRE") then
            if playerClass == "SHAMAN" then
                table.insert(filteredPlayers, playerName)
                -- print(playerName)
            end
        elseif rol:find("REDIRECCION") or rol:find("TRAMPA DE ESCARCHA") or rol:find("AURA DE DISPARO CERTERO") then
            if playerClass == "HUNTER" then
                table.insert(filteredPlayers, playerName)
                -- print(playerName)
            end
        elseif rol:find("SECRETOS DEL OFICIO") or rol:find("DESACTIVAR TRAMPA") then
            if playerClass == "ROGUE" then
                table.insert(filteredPlayers, playerName)
                -- print(playerName)
            end
        elseif rol:find("VIGILANCIA") then
            if playerClass == "WARRIOR" then
                table.insert(filteredPlayers, playerName)
                -- print(playerName)
            end
        elseif rol:find("MAESTRIA EN AURAS") or rol:find("AHUYENTAR EL MAL") or rol:find("MANO DE SALVACION") or
            rol:find("MANO DE SACRIFICIO") or rol:find("IMPOSICION DE MANOS") or rol:find("COLERA SAGRADA") then
            if playerClass == "PALADIN" then
                table.insert(filteredPlayers, playerName)
                -- print(playerName)
            end
        elseif rol:find("REZOS DE ESPIRITU, PROTECCION Y ENTEREZA") or rol:find("ENCADENAR NO MUERTO") then
            if playerClass == "PRIEST" then
                table.insert(filteredPlayers, playerName)
                -- print(playerName)
            end
        end
    end
    return filteredPlayers
end

local function UpdateDropdownOptions(dropdown, rol)
    local players = filterPlayersByRol(rol)
    UIDropDownMenu_Initialize(dropdown, function(self, level)
        local info = UIDropDownMenu_CreateInfo()
        for _, player in ipairs(players) do
            info.text = player
            info.func = function()
                self:SetValue(player)
                self.selectedPlayer = player
                -- addonCache[playerName].rol = rol
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
end

local function reRenderDropdown()
    -- print("reRenderDropdown")
    for i = 1, #dropdowns do
        UpdateDropdownOptions(dropdowns[i], characterRol[i])
    end
end

local function getPlayersInfo()
    -- print("getPlayersInfo")
    local numberOfPlayers, _ = getPlayerInitialState()
    -- print("numberOfPlayers: " .. numberOfPlayers)
    if numberOfPlayers == 0 then
        raidInfo = {} -- Reinicializar raidInfo
        addonCache = {} -- Reinicializar addonCache
        local _, englishClass = UnitClass("player")
        addonCache[UnitName("player")] = {
            class = englishClass,
            rol = nil
        } -- Reinicializar Cache
    else
        for i = 1, numberOfPlayers do
            local unit = GetNumRaidMembers() ~= 0 and "raid" .. i or "party" .. i
            local playerName = UnitName(unit)
            local playerClass = select(2, UnitClass(unit)) -- Cambiado para obtener solo el nombre de la clase
            if playerName then
                if addonCache[playerName] then
                    addonCache[playerName].rol = addonCache[playerName].rol or nil
                else
                    addonCache[playerName] = {
                        class = playerClass,
                        rol = nil
                    }
                end
                -- print("getPlayersInfo: " .. playerName .. " - " .. addonCache[playerName].class)
            end
        end
    end

    reRenderDropdown() -- Actualizar los dropdowns después de obtener la información del jugador
end

local function SendSplitMessage(message)
    local maxLength = 255
    local numParts = math.ceil(#message / maxLength)
    local delay = .5 -- Retraso en segundos entre cada parte
    local currentPart = 1
    local _, channel = getPlayerInitialState()

    local function SendNextPart()
        local startIdx = (currentPart - 1) * maxLength + 1
        local endIdx = currentPart * maxLength
        local part = message:sub(startIdx, endIdx)

        SendChatMessage(part, channel)

        currentPart = currentPart + 1
        if currentPart <= numParts then
            -- Programamos el siguiente envío de parte después del retraso
            local frame = CreateFrame("Frame")
            frame:SetScript("OnUpdate", function(self, elapsed)
                delay = delay - elapsed
                if delay <= 0 then
                    SendNextPart()
                    self:SetScript("OnUpdate", nil)
                end
            end)
        end
    end

    SendNextPart()
end

local function SendDelayedMessages(messages, readyCheck)
    local index = 1
    local frame = CreateFrame("Frame")
    frame.delay = 0 -- Iniciar retraso para el primer mensaje

    frame:SetScript("OnUpdate", function(self, elapsed)
        self.delay = self.delay - elapsed
        if self.delay <= 0 then
            if index <= #messages then
                SendSplitMessage(messages[index])
                index = index + 1
                self.delay = 1.8 -- Resetear retraso para el próximo mensaje
            end

            if index > #messages and readyCheck then
                self:SetScript("OnUpdate", nil) -- Detener el OnUpdate para evitar que siga ejecutándose.

                -- Usar un nuevo marco temporal para el retraso del Ready Check
                local delayFrame = CreateFrame("Frame")
                delayFrame.delay = 5 -- Establecer un retraso de 4 segundos para el Ready Check
                delayFrame:SetScript("OnUpdate", function(delaySelf, delayElapsed)
                    delaySelf.delay = delaySelf.delay - delayElapsed
                    if delaySelf.delay <= 0 then
                        DoReadyCheck()
                        delaySelf:SetScript("OnUpdate", nil) -- Detener el OnUpdate del marco de retraso
                    end
                end)
            end
        end
    end)
end

local function WpLoot()
    local raidMembers = {
        ["MAIN TANK"] = {},
        ["OFF TANK"] = {},
        ["HEALER"] = {},
        ["DPS"] = {}
    }

    -- Recoger a los miembros de la raid y sus roles de addonCache
    for playerName, playerData in pairs(addonCache) do
        local playerClass = playerData.class or ""
        local role = playerData.rol or "DPS" -- Si no se especifica el rol, se considera DPS
        playerClass = string.upper(string.sub(playerClass, 1, 1)) .. string.lower(string.sub(playerClass, 2)) -- Capitalizar la primera letra de playerClass
        if role == "MAIN TANK" or role == "OFF TANK" then
            table.insert(raidMembers[role], playerClass .. " " .. playerName)
        elseif role:find("HEALER") then
            table.insert(raidMembers["HEALER"], playerClass .. " " .. playerName)
        else
            table.insert(raidMembers["DPS"], playerClass .. " " .. playerName)
        end
    end

    -- Construir mensajes por cada grupo de roles
    local tankMessage = ""
    local healerMessage = ""
    local dpsMessage = ""
    if #raidMembers["MAIN TANK"] > 0 then
        tankMessage = "MAIN TANK: " .. table.concat(raidMembers["MAIN TANK"], ", ")
    end
    if #raidMembers["OFF TANK"] > 0 then
        if tankMessage ~= "" then
            tankMessage = tankMessage .. " - OFF TANK: " .. table.concat(raidMembers["OFF TANK"], ", ")
        else
            tankMessage = "OFF TANK: " .. table.concat(raidMembers["OFF TANK"], ", ")
        end
    end
    if #raidMembers["HEALER"] > 0 then
        if healerMessage ~= "" then
            healerMessage = healerMessage .. " - HEALER: " .. table.concat(raidMembers["HEALER"], ", ")
        else
            healerMessage = "HEALER: " .. table.concat(raidMembers["HEALER"], ", ")
        end
    end
    if #raidMembers["HEALER"] > 0 and #raidMembers["MAIN TANK"] > 0 then
        dpsMessage = "DPS: " .. table.concat(raidMembers["DPS"], ", ")
    end

    local _, channel = getPlayerInitialState()

    local guildRaid = (channel == "RAID_WARNING") and
                          {"{rt1} Atentos quienes se quedan a lotear", "{rt8} [Culto del Osario] {rt8}"} or {"Nos vemos ^^"}

    local messages = {"Gracias a todos!", tankMessage, healerMessage, dpsMessage}
    if channel == "RAID_WARNING" then
        -- Si estamos en el canal de aviso de la banda, agregamos el mensaje de la banda a los mensajes
        for _, msg in ipairs(guildRaid) do
            table.insert(messages, msg)
        end
    end

    SendDelayedMessages(messages)
end

local function RequestBuffs()
    local raidMembers = {
        ["MAIN TANK"] = {},
        ["OFF TANK"] = {},
        ["HEALER"] = {},
        ["BUFF"] = {}
    }

    -- Recoger a los miembros de la raid y sus roles de addonCache
    for playerName, playerData in pairs(addonCache) do
        local playerClass = playerData.class
        local role = playerData.rol or "DPS"
        if playerClass then
            playerClass = string.upper(string.sub(playerClass, 1, 1)) .. string.lower(string.sub(playerClass, 2)) -- Capitalizar la primera letra de playerClass
            if role == "MAIN TANK" or role == "OFF TANK" then
                table.insert(raidMembers[role], playerClass .. " " .. playerName)
            elseif role:find("HEALER") then
                table.insert(raidMembers["HEALER"], playerClass .. " " .. playerName)
            elseif not role:find("DPS") then
                table.insert(raidMembers["BUFF"], playerClass .. " " .. playerName .. " [" .. role .. "]")
            end
        end
    end

    -- Construir mensajes por cada grupo de roles
    local tankMessage = ""
    local healerMessage = ""
    local rolMessage = ""
    if #raidMembers["MAIN TANK"] > 0 then
        tankMessage = "MAIN TANK: " .. table.concat(raidMembers["MAIN TANK"], ", ")
    end
    if #raidMembers["OFF TANK"] > 0 then
        if tankMessage ~= "" then
            tankMessage = tankMessage .. " - OFF TANK: " .. table.concat(raidMembers["OFF TANK"], ", ")
        else
            tankMessage = "OFF TANK: " .. table.concat(raidMembers["OFF TANK"], ", ")
        end
    end
    if #raidMembers["HEALER"] > 0 then
        if healerMessage ~= "" then
            healerMessage = healerMessage .. " - HEALER: " .. table.concat(raidMembers["HEALER"], ", ")
        else
            healerMessage = "HEALER: " .. table.concat(raidMembers["HEALER"], ", ")
        end
    end
    if #raidMembers["BUFF"] > 0 then
        if rolMessage ~= "" then
            rolMessage = rolMessage .. " - BUFF: " .. table.concat(raidMembers["BUFF"], ", ")
        else
            rolMessage = "BUFF: " .. table.concat(raidMembers["BUFF"], ", ")
        end
    end

    local _, channel = getPlayerInitialState()

    local guildRaid = (channel == "RAID_WARNING") and
                          {"{rt1} Todos confirman check y go pull 15s"} or {""}

    local messages = {"Atentos!", tankMessage, healerMessage, rolMessage}
    if channel == "RAID_WARNING" then
        -- Si estamos en el canal de aviso de la banda, agregamos el mensaje de la banda a los mensajes
        for _, msg in ipairs(guildRaid) do
            table.insert(messages, msg)
        end
    end

    -- Enviar los mensajes
    SendDelayedMessages(messages, true)
end

local function GetDistanceBetweenUnits(unit1, unit2)
    local x1, y1 = GetPlayerMapPosition(unit1)
    local x2, y2 = GetPlayerMapPosition(unit2)

    if not x1 or not x2 then
        return nil
    end

    local dx = x2 - x1
    local dy = y2 - y1

    return math.sqrt(dx * dx + dy * dy) * 100
end

local function CheckDistance(unit)
    local distance = GetDistanceBetweenUnits("player", unit)
    return distance and distance <= 4
end

local function AlertFarPlayers()
    local playerNames = "" -- Inicializar la cadena para nombres
    local numberOfPlayers = GetNumRaidMembers() ~= 0 and GetNumRaidMembers() or GetNumPartyMembers()
    local groupType = GetNumRaidMembers() ~= 0 and "raid" or "party"
    for i = 1, numberOfPlayers do
        local unit = groupType .. i
        if not CheckDistance(unit) then
            local playerName = UnitName(unit)
            local playerClass = UnitClass(unit)
            playerClass = string.upper(string.sub(playerClass, 1, 1)) .. string.lower(string.sub(playerClass, 2)) -- Capitalizar la primera letra de playerClass
            if playerName then
                if playerNames == "" then
                    playerNames = playerClass .. " " .. playerName -- Primera asignación sin separador
                else
                    playerNames = playerNames .. " / " .. playerClass .. " " .. playerName -- Concatenar con separador
                end
            end
        end
    end

    local messages = {"Jugadores AFK/OFF o lejos del grupo", playerNames, "Presentarse pronto por favor"}

    SendDelayedMessages(messages)
end

local function GetChatPrefix()
    local instanceType = select(2, IsInInstance())
    if instanceType == "none" then
        return "/y " -- Alone
    elseif instanceType == "party" then
        return "/p " -- Party
    elseif instanceType == "raid" then
        local isLeader = IsRaidLeader()
        if isLeader then
            return "/rw " -- RaidLead
        else
            return "/raid " -- RaidMan
        end
    end
end

local function HandleClick(playerName, modifierPressed)
    if playerName and modifierPressed then
        local editBox = ChatEdit_ChooseBoxForSend()
        if editBox then
            local currentText = editBox:GetText() or ""
            local newText = currentText .. playerName
            ChatEdit_ActivateChat(editBox)
            local prefix = GetChatPrefix()
            if modifierPressed == "ALT" then
                editBox:SetText(prefix .. newText .. " ")
            elseif modifierPressed == "CONTROL" then
                editBox:SetText("/w " .. playerName .. " " .. currentText)
            elseif modifierPressed == "SHIFT" then
                editBox:SetText(newText .. " ")
            end
        end
    end
end

local raidWalker = {
    ["LA CAMARA DE ARCHAVON"] = {
        ["REGLAS"] = {"PRIORIDAD DE LOTEO PVE: Por función MAIN.", "PRIORIDAD DE LOTEO PVP: Por clase.",
                      "No loteara o podra ser expulsado quien se quede AFK/OFF, haga Pull accidental, no siga mecanincas o tenga DPS por debajo del Tanque. Heal doblado en recuento no lotea.",
                      "{rt8} [Culto del Osario] {rt8}"},
        ["BOSS"] = {
            ["TOVARON EL VIGIA DE HIELO"] = {"Los dos tanques intercambian boss cada 4 marcas",
                                             "Los DPS destruyen orbes totalmente y continuan con boss"}
        }
    },
    ["CIUDADELA DE LA CORONA DE HIELO"] = {
        ["REGLAS"] = {"PRIORIDAD DE LOTEO: Por función MAIN > DUAL > ENCHANT > CODICIA.",
        --   "MARCAS: Para lotear marca debe tener 2 t10 engemados/encantados. Caster 14k dps(3% bestias) Meles 14k dps en Libra (3% bestias). Heals top3 de Lady y Reina.",
        --   "TESTAMENTO: top5 daño inflingido en Libra cerrado con 5% en bestias, al igual que Tarro . (Testa palas sólo con agonía).",
        --   "ABACO: top3 heal en Reina, si no cae se toma el recuento de Panzachancro. Trauma igual.",
        --   "FILACTERIA: top2 cerrado daño inflingido en Libramorte con 5% en bestias.",
        --   "OBJETO: top3 cerrado daño inflingido en Libramorte con 5% en bestias.",
                      "CUIDADO",
                      "No loteara o podra ser expulsado quien se quede AFK/OFF, haga Pull accidentales, no siga mecanincas o tenga DPS debajo del Tanque. Heal doblado en recuentos no lotea.",
                      "DBM es obligatorio y Discord se comparte antes de iniciar Tuetano; la falta de alguno conllevará a la expulsión de la raid",
                      "{rt8} [Culto del Osario] {rt8}"},
        ["BOSS"] = {
            ["TUETANO"] = {"POSICIONES: Tanques a la derecha, resto del grupo debajo del boss, hunter alejado en costado opuesto a tanques",
                           "PUAS: DPS destruyen puas, si la pua esta a distancia solo caster y ranged la destruiran, heal 5 cuida empalados",
                           "FUEGO: Todos evitan trazos de fuego sin alejarse del grupo y de las posiciones iniciales",
                           "TORMENTAS INICIALES: Aplican defensivos y mitigadores",
                           "ULTIMA TORMENTA: Tanques se mueven cerca a escaleras, grupo en el centro, hunter al costado opuesto",
                           "REAGRUPE: Tanques retoman cerca a escaleras, grupo vuelve bajo el boss"},
            ["LADY"] = {"POSICIONES: Tanque MAIN a la derecha, Tanque OFF a la izquierda, resto frente al escenario, picaro con lady todo el tiempo",
                        "ADDS: DPS eliminan adds de ambos lados y continuan con lady",
                        "AREA VERDE: Retirarse de daño de area",
                        "CONTROLADO: Usar habilidades de control sin daño sobre aliado",
                        "FASEADO: Tanques llevan a lady al centro del salon evitando daños de area",
                        "FANTASMAS: Evitar tocar fantasmas morados si los siguen",
                        "PELIGRO DE AGRO: Utilizar habilidades para ceder todo el agro sobre los tanques",
                        "REAGRUPE: Tanques retoman cerca a escaleras, grupo vuelve bajo el boss"},
            ["BARCOS"] = {"POSICIONES: Tanque MAIN salta por la derecha del barco, DPS saltan por el lado izquierdo",
                          "CAÑONES: DPS bajos toman cañones y mantienen entre 85~100% el poder de ataque antes de ataque especial",
                          "MATAR Y REGRESAR: DPS destruyen mago y regresan por el mismo lado que saLtaron",
                          "PELIGRO DE RAJAR: Solo el tanque salta por el lado derecho y regresa por el mismo lado",
                          "CAÑONES: Terminan el trabajo",
                          "CUIDADO: Esperar en terraza, nadie abra el cofre de loot o perdera todo loteo "},
            ["LIBRA"] = {"TANQUES: Cada poco tiempo coloca a la persona con mayor agro una Runa de sangre, el otro tanque debe quitarle el boss inmediatamente",
                         "CASTER Y RANGO: Mantener distancia /range 12 para evitar curar al boss",
                         "BESTIAS: DPS se enfocan y las destruyen antes de continuar con boss",
                         "BESTIAS: Pueden ralentizarlas utilizando Trampas de Escarcha, Tótem de Nexo Terrestre, Veneno entorpecedor, Profanación o Cadenas de Hielo. También pueden incapacitarlas, utilizar raíces, empujarla hacia atrás, etc",
                         "MARCADOS: Aplican defensivos y mitigadores de daño y no tocan bestias, Healer 5 se enfoca a cuidarlos",
                         "HEROISMO: Castear al 35% del boss y aplicar todos los booster y multiplicadores de daño",
                         "IMPORTANTE: Tomar distancia = No marcas / Aniquilar bestias = boss no se cura"},
            ["PANZACHANCRO"] = {"TANQUES: Intercambian al boss cada 9 marcas, tanque con 9 marcas deja de pegar totalmente!",
                                "POSICIONES: Tanques mantienen al boss de espaldas en el centro de la sala",
                                "POSICIONES: DPS cuerpo a cuerpo deben permanecer siempre juntos detras del boss",
                                "POSICIONES: DPS rango toman distancia /range 8 entre ellos para no vomitarse",
                                "ESPORAS: DPS rango se juntan con la espora, otra espora se queda con los cuerpo a cuerpo",
                                "DOBLE ESPORA EN CUERPO A CUERPO: Uno de los jugadores con espora se reune con los caster para compartirles espora",
                                "ATENCION: Quien no acumula 3 esporas absorbera daño masivo en explosion de gas"},
            ["CARAPUTREA"] = {"MAIN TANK: Mantiene al boss en el centro de la sala",
                              "POSICIONES: DPS siempre detras del jefe y en zonas sin inundacion de mocos",
                              "INFECCION: Al limpiar infeccion saltara un moco pequeño",
                              "MOCO PEQUEÑO: OFF TANK lo toma de inmediato y lo tanquea en todo el circulo esterior dandole vueltas lejos del grupo",
                              "SEGUNDO MOCO: OFF TANK se encarga, mocos se unen, comienza a acumular hasta 5 mocos y explota",
                              "BOSS GIRA: DPS deben mantener sus posiciones, el boss gira y hay que evitar charcos de moco"}

        }
    }
}

local function addonInfoContent()
    local addonInfoFrame = CreateFrame("Frame", nil, mainFrame)
    addonInfoFrame:SetSize(440, 275)

    local contentScrollFrame = CreateFrame("ScrollFrame", "addonInfoFrame_ContentScrollFrame", addonInfoFrame,
        "UIPanelScrollFrameTemplate")
    contentScrollFrame:SetPoint("TOPLEFT", 10, -58)
    contentScrollFrame:SetPoint("BOTTOMRIGHT", -30, 10)

    local content = CreateFrame("Frame", nil, contentScrollFrame)
    content:SetSize(440, 400) -- Aumentar la altura para permitir desplazamiento

    contentScrollFrame:SetScrollChild(content)

    local leftSideText = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    leftSideText:SetPoint("TOP", -15, 10)
    leftSideText:SetSize(380, 270) -- Asegúrate de que el tamaño permita mostrar todo el texto
    leftSideText:SetJustifyH("LEFT") -- Alinear el texto a la izquierda
    leftSideText:SetText(
        "Utilizar [MODIFICADOR] + [CLIC IZQ]\n\n" .. "[CONTROL] + ... : Para susurrar al objetivo\n\n" ..
            "[SHIFT] + ... : Agrega el nombre del objetivo al chat activo\n\n" ..
            "[ALT] + ... : Dentro de instancia como líder de raid, agrega el nombre del objetivo al chat Raid[ALT]\n\n[ALT] + ... : Dentro de mazmorra, agrega el nombre del objetivo al chat Grupo\n\n" ..
            "[ALT] + ... : Fuera de instancia, agrega el nombre del objetivo al chat Gritar\n\n" ..
            "Puedes ocultar este cuadro de ayuda y tambien desactivar las acciones del addon, esto devolvera al los modificadores sus funciones habituales\n\n" ..
            "QuickName v1")

    -- Los enlaces pueden necesitar también estar en el área desplazable si deseas que se desplacen
    local githubLink = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
    githubLink:SetPoint("TOP", leftSideText, "BOTTOM", 0, -10)
    githubLink:SetSize(200, 20)
    githubLink:SetAutoFocus(false)
    githubLink:SetText("https://github.com/IAM-DEV88")
    githubLink:SetFontObject("ChatFontNormal")

    local paypalLink = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
    paypalLink:SetPoint("TOP", githubLink, "BOTTOM", 0, -10)
    paypalLink:SetSize(200, 20)
    paypalLink:SetAutoFocus(false)
    paypalLink:SetText("paypal.me/iamdev88")
    paypalLink:SetFontObject("ChatFontNormal")

    skipCheckbox = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    skipCheckbox:SetPoint("BOTTOMLEFT", 10, 10)

    skipCheckbox:SetSize(20, 20)
    skipCheckbox:SetChecked(skipHelpDialog)
    skipCheckbox:SetScript("OnClick", function(self)
        skipHelpDialog = (self:GetChecked() == 1) and true or false
    end)

    local skipLabel = skipCheckbox:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    skipLabel:SetPoint("LEFT", skipCheckbox, "RIGHT", 5, 0)
    skipLabel:SetText("Ocultar ayuda")

    enabledAddonCheckbox = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    enabledAddonCheckbox:SetPoint("BOTTOMRIGHT", -10, 10)
    enabledAddonCheckbox:SetSize(20, 20)
    enabledAddonCheckbox:SetChecked(enabledAddon)
    enabledAddonCheckbox:SetScript("OnClick", function(self)
        enabledAddon = (self:GetChecked() == 1) and true or false
        StaticPopupDialogs["RELOAD_UI_CONFIRM"] = {
            text = "¿Deseas recargar la interfaz de usuario para aplicar los cambios?",
            button1 = "Sí",
            button2 = "No",
            OnAccept = function()
                ReloadUI()
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3 -- Posición preferida en la pila de ventanas emergentes
        }

        StaticPopup_Show("RELOAD_UI_CONFIRM")
    end)

    local enabledAddonLabel = enabledAddonCheckbox:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    enabledAddonLabel:SetPoint("RIGHT", enabledAddonCheckbox, "RIGHT", -24, 0)
    enabledAddonLabel:SetText("Modificadores activos")

    return addonInfoFrame
end

local function addonInfoContainer()
    if not addonInfoFrame then
        addonInfoFrame = CreateFrame("Frame", nil, mainFrame)
        addonInfoFrame:SetPoint("TOPLEFT", -5, 15)
        addonInfoFrame:SetSize(280, 120)
        -- Crear el diálogo de ayuda y mostrarlo en la pestaña
        local content = addonInfoContent()
        content:SetParent(addonInfoFrame)
        content:SetPoint("TOPLEFT")
        content:Show()
    end
    addonInfoFrame:Show()
    if raidRolerFrame then
        raidRolerFrame:Hide()
    end
end

-- Función para crear el contenido de la pestaña "Roles del grupo"
local function raidRolerContent()
    local raidRolerFrame = CreateFrame("Frame", nil, mainFrame)
    raidRolerFrame:SetSize(450, 275)

    -- Crear el área desplazable para el contenido de las pestañas
    local contentScrollFrame = CreateFrame("ScrollFrame", "QuickName_ContentScrollFrame", raidRolerFrame,
        "UIPanelScrollFrameTemplate")
    contentScrollFrame:SetPoint("TOPLEFT", 10, -58)
    contentScrollFrame:SetPoint("BOTTOMRIGHT", -30, 10)

    -- Crear el contenido dentro del área desplazable
    local content = CreateFrame("Frame", nil, contentScrollFrame)
    content:SetSize(280, 270) -- Tamaño del contenido, ajusta según sea necesario

    -- Configurar el scrollChild del área desplazable
    contentScrollFrame:SetScrollChild(content)

    local maxColumns = 2
    local maxRowsPerColumn = 15
    local columnWidth = 120
    local rowHeight = 25
    local xOffset, yOffset = 0, 0 -- Ajuste de posición inicial

    for i, rol in ipairs(characterRol) do
        local row = math.floor((i - 1) / maxColumns) -- Calcular la fila actual
        local col = (i - 1) % maxColumns -- Calcular la columna actual

        local dropdown, resetButton, alertButton = CreateDropdown(content, rol, i, columnWidth, rowHeight, "TOPLEFT",
            UIParent, xOffset + col * (columnWidth + 78), yOffset - row * (rowHeight + 5))
        table.insert(dropdowns, dropdown)

        UpdateDropdownOptions(dropdown, rol)
    end

    return raidRolerFrame
end

local function raidRolerContainer()
    if not raidRolerFrame then
        raidRolerFrame = CreateFrame("Frame", nil, mainFrame)
        raidRolerFrame:SetPoint("TOP", -22, 15)
        raidRolerFrame:SetSize(425, 490)

        local content = raidRolerContent()
        content:SetParent(raidRolerFrame)
        content:SetPoint("TOPLEFT")
        content:Show()
    end
    raidRolerFrame:Show()
    if addonInfoFrame then
        addonInfoFrame:Hide()
    end
end

local function CreateMainUI()
    -- Crear la ventana principal
    mainFrame = CreateFrame("Frame", "QuickName_MainFrame", UIParent)
    mainFrame:SetSize(440, 290)
    mainFrame:SetPoint("LEFT")
    mainFrame:EnableMouse(true)
    mainFrame:SetMovable(true)
    mainFrame:RegisterForDrag("LeftButton")
    mainFrame:SetScript("OnDragStart", mainFrame.StartMoving)
    mainFrame:SetScript("OnDragStop", mainFrame.StopMovingOrSizing)
    mainFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = {
            left = 11,
            right = 12,
            top = 12,
            bottom = 11
        }
    })
    mainFrame:SetBackdropBorderColor(0.4, 0.4, 0.4)
    mainFrame:SetFrameStrata("DIALOG")
    mainFrame:SetFrameLevel(100)

    -- Crear el título de la ventana
    local title = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOP", 0, 2)
    title:SetText("QuickName")

    -- Botón de cerrar
    closeButton = CreateFrame("Button", nil, mainFrame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", 10, 10)
    closeButton:SetScript("OnClick", function()
        mainFrame:Hide()
    end)

    -- Crear las pestañas
    local tabContainer = CreateFrame("Frame", nil, mainFrame)
    tabContainer:SetPoint("TOP", 0, 0)
    tabContainer:SetSize(440, 25)

    local tab1 = CreateFrame("Button", "QuickName_Tab1", tabContainer, "UIPanelButtonTemplate")
    tab1:SetPoint("RIGHT", -127, -16)
    tab1:SetSize(60, 25)
    tab1:SetText("ROLES")
    tab1:GetFontString():SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE") -- Estableciendo la fuente y el tamaño
    tab1:SetScript("OnClick", function()
        raidRolerContainer()
    end)

    local tab2 = CreateFrame("Button", "QuickName_Tab2", tabContainer, "UIPanelButtonTemplate")
    tab2:SetPoint("RIGHT", -35, -16)
    tab2:SetSize(25, 25)
    tab2:SetText("?")
    tab2:GetFontString():SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE") -- Estableciendo la fuente y el tamaño
    tab2:SetScript("OnClick", function()
        addonInfoContainer()
    end)

    -- Inicialmente, mostrar el contenido de la pestaña "Roles del grupo"
    raidRolerContainer()

    local reloadButton = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
    reloadButton:GetFontString():SetFont("Fonts\\FRIZQT__.TTF", 6, "OUTLINE") -- Estableciendo la fuente y el tamaño
    reloadButton:SetPoint("TOPRIGHT", -8, -15)
    reloadButton:SetSize(26, 26)
    reloadButton:SetText("RELOAD")
    reloadButton:SetScript("OnClick", function()
        ReloadUI()
    end)

    local alertPlayersBtn = CreateFrame("Button", "AlertFarPlayers", mainFrame, "UIPanelButtonTemplate")
    alertPlayersBtn:GetFontString():SetFont("Fonts\\FRIZQT__.TTF", 8, "OUTLINE") -- Estableciendo la fuente y el tamaño
    alertPlayersBtn:SetPoint("TOP", -62, -16)
    alertPlayersBtn:SetSize(60, 25)
    alertPlayersBtn:SetText("AFK/OFFs")
    alertPlayersBtn:SetScript("OnClick", AlertFarPlayers)

    local reqBuffsBtn = CreateFrame("Button", "RequestBuffs", mainFrame, "UIPanelButtonTemplate")
    reqBuffsBtn:GetFontString():SetFont("Fonts\\FRIZQT__.TTF", 8, "OUTLINE") -- Estableciendo la fuente y el tamaño
    reqBuffsBtn:SetPoint("TOP", 0, -16)
    reqBuffsBtn:SetSize(60, 25)
    reqBuffsBtn:SetText("BUFF/CHECK")
    reqBuffsBtn:SetScript("OnClick", RequestBuffs)

    local wpLootBtn = CreateFrame("Button", "WpLoot", mainFrame, "UIPanelButtonTemplate")
    wpLootBtn:GetFontString():SetFont("Fonts\\FRIZQT__.TTF", 8, "OUTLINE") -- Estableciendo la fuente y el tamaño
    wpLootBtn:SetPoint("TOP", -125, -16)
    wpLootBtn:SetSize(60, 25)
    wpLootBtn:SetText("WP/LOOT")
    wpLootBtn:SetScript("OnClick", WpLoot)

    -- Dropdown para raids
    local raidDropdown = CreateFrame("Frame", "RaidDropdown", mainFrame, "UIDropDownMenuTemplate")
    raidDropdown:SetPoint("BOTTOMLEFT", mainFrame, -4, 6)
    UIDropDownMenu_SetWidth(raidDropdown, 120)
    UIDropDownMenu_SetText(raidDropdown, "REGLAS")

    -- Dropdown para bosses
    local bossDropdown = CreateFrame("Frame", "BossDropdown", mainFrame, "UIDropDownMenuTemplate")
    bossDropdown:SetPoint("BOTTOMRIGHT", mainFrame, -76, 6)
    UIDropDownMenu_SetWidth(bossDropdown, 120)
    UIDropDownMenu_SetText(bossDropdown, "MECANICAS")

    local raids = raidWalker -- Asignamos el diccionario de raids a una variable local
    local selectedRaid, selectedBoss -- Variables para almacenar las selecciones actuales

    -- Función para inicializar el dropdown de bosses
    local function InitializeBossesDropdown()
        UIDropDownMenu_ClearAll(bossDropdown)
        UIDropDownMenu_SetText(bossDropdown, "MECANICAS")
        if selectedRaid and raids[selectedRaid]["BOSS"] then
            local bosses = raids[selectedRaid]["BOSS"]
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

    -- Función para inicializar el dropdown de raids
    local function InitializeRaidsDropdown()
        local info = UIDropDownMenu_CreateInfo()
        for raidName, _ in pairs(raids) do
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
    local alertRaidRulesButton = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
    alertRaidRulesButton:SetPoint("LEFT", raidDropdown, "RIGHT", 15, 2)
    alertRaidRulesButton:SetText("!")
    alertRaidRulesButton:SetSize(26, 26)
    alertRaidRulesButton:SetScript("OnClick", function()
        if selectedRaid and raids[selectedRaid]["REGLAS"] then
            -- Crear una copia del array de reglas para no modificar el original
            local rulesArray = {unpack(raids[selectedRaid]["REGLAS"])}
            -- Insertar un nuevo elemento al inicio del array
            table.insert(rulesArray, 1, "REGLAS DE " .. selectedRaid)

            -- Enviar las reglas, ahora incluyendo el nuevo elemento al inicio
            SendDelayedMessages(rulesArray)

        end
    end)

    -- Botón de alerta para los detalles del boss seleccionado
    local alertBossDetailsButton = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
    alertBossDetailsButton:SetPoint("LEFT", bossDropdown, "RIGHT", 14, 2)
    alertBossDetailsButton:SetText("!")
    alertBossDetailsButton:SetSize(26, 26)
    alertBossDetailsButton:SetScript("OnClick", function()
        if selectedRaid and selectedBoss and raids[selectedRaid]["BOSS"][selectedBoss] then
            -- Crear una copia del array de reglas para no modificar el original
            local howToBoss = {unpack(raids[selectedRaid]["BOSS"][selectedBoss])}
            -- Insertar un nuevo elemento al inicio del array
            table.insert(howToBoss, 1, "MECANICAS DE " .. selectedBoss)

            -- Enviar las reglas, ahora incluyendo el nuevo elemento al inicio
            SendDelayedMessages(howToBoss)
        end
    end)

    -- Botón de reseteo para raids
    local resetRaidButton = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
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
    local resetBossButton = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
    resetBossButton:SetText("X")
    resetBossButton:SetPoint("RIGHT", bossDropdown, 13, 2)
    resetBossButton:SetSize(26, 26)
    resetBossButton:SetScript("OnClick", function()
        UIDropDownMenu_SetText(bossDropdown, "MECANICAS")
        selectedBoss = nil
    end)

end

-- Función para manejar eventos de addon cargado
local function OnEvent(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        -- print("ADDON_LOADED")
        addonCache = {}
        for k, v in pairs(raidInfo or {}) do
            addonCache[k] = v
        end
    elseif event == "PLAYER_LOGIN" then
        getPlayersInfo()
        -- print("PLAYER_LOGIN")
        CreateMainUI()
        if not enabledAddon and skipHelpDialog then
            -- print("QuickName esta desactivado, puedes usar /qname para ver las opciones")
        end
        if not skipHelpDialog then
            mainFrame:Show()
        else
            mainFrame:Hide()
        end
        SLASH_QNAME1 = "/qname"
        SlashCmdList["QNAME"] = function()
            mainFrame:Show(not mainFrame:IsShown())
        end
        if enabledAddon then
            local initModifiers = CreateFrame("Frame")
            initModifiers:RegisterEvent("PLAYER_TARGET_CHANGED")
            initModifiers:SetScript("OnEvent", function(_, event, ...)
                if event == "PLAYER_TARGET_CHANGED" then
                    local targetName = UnitName("target")
                    local modifierPressed = IsAltKeyDown() and "ALT" or
                                                (IsControlKeyDown() and "CONTROL" or (IsShiftKeyDown() and "SHIFT"))
                    HandleClick(targetName, modifierPressed)
                end
            end)
        end
    elseif event == "PARTY_MEMBERS_CHANGED" then
        -- print("PARTY_MEMBERS_CHANGED")
        getPlayersInfo()
    elseif event == "RAID_ROSTER_UPDATE" then
        -- print("RAID_ROSTER_UPDATE")
        getPlayersInfo()
    elseif event == "PLAYER_LOGOUT" then
        -- print("PLAYER_LOGOUT")
        skipHelpDialog = (skipCheckbox:GetChecked() == 1) and true or false
        enabledAddon = (enabledAddonCheckbox:GetChecked() == 1) and true or false
        raidInfo = {}
        for k, v in pairs(addonCache) do
            raidInfo[k] = v
        end
    end
end

-- Crear un marco para manejar eventos
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_LOGOUT")
frame:RegisterEvent("PARTY_MEMBERS_CHANGED") -- Cambios en el grupo
frame:RegisterEvent("RAID_ROSTER_UPDATE") -- Cambios en la raid
frame:SetScript("OnEvent", OnEvent)
