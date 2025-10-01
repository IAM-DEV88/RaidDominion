-- Inicializar la variable si no existe
enabledPanel = enabledPanel or false

-- Variable para rastrear si ya hemos inicializado el checkbox
local checkboxInitialized = false

-- Función para actualizar el estado del checkbox y la visibilidad de la ventana
local function UpdateUIState()
    -- Actualizar el estado del checkbox si existe
    if enabledPanelCheckbox and enabledPanelCheckbox.SetChecked then
        enabledPanelCheckbox:SetChecked(enabledPanel)
    end
end

-- Registrar para eventos de carga
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("VARIABLES_LOADED")
f:RegisterEvent("ADDON_LOADED")

-- Variable para rastrear si ya hemos actualizado el estado
local uiStateUpdated = false

f:SetScript("OnEvent", function(self, event, ...)
    if event == "VARIABLES_LOADED" or event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == "RaidDominion" or not addonName then
            -- Esperar al siguiente frame para asegurar que todo esté listo
            self:SetScript("OnUpdate", function(self, elapsed)
                self:SetScript("OnUpdate", nil)
                UpdateUIState()
                uiStateUpdated = true
            end)
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        if not uiStateUpdated then
            -- Si por alguna razón aún no se ha actualizado, hacerlo ahora
            UpdateUIState()
            uiStateUpdated = true
        end
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    end
end)

function CreateRaidDominionOptionsTabContent(parent)
    local content = CreateFrame("Frame", "OptionsTabContent", parent)
    content:SetPoint("TOPLEFT", 10, -55)
    content:SetSize(340, 300)

    local instructions = {{"GameFontHighlightSmall", "DISCORD", 20}, {"GameFontNormal", "ENLACE:", 20},
                          {"GameFontHighlightSmall", "Mostrar panel al cargar", 20}}

    local currentYOffset = -5 -- Posición vertical inicial

    for _, instruction in ipairs(instructions) do
        local fontString = content:CreateFontString(nil, "ARTWORK", instruction[1])
        fontString:SetText(instruction[2])
        fontString:SetPoint("TOPLEFT", content, "TOPLEFT", instruction[3], currentYOffset)

        if instruction[4] then
            fontString:SetJustifyH("LEFT")
            fontString:SetWidth(instruction[4])
        end

        local _, fontHeight = fontString:GetFont()
        local numExtraLines = math.ceil(#instruction[2] / 70)
        currentYOffset = currentYOffset - fontHeight * (numExtraLines + 1) - 5 -- Actualiza la posición vertical para la siguiente línea
    end

    discordInput = CreateFrame("EditBox", "DiscordLinkInput", content, "InputBoxTemplate")
    discordInput:SetPoint("TOPLEFT", 90, -26) -- Ajusta la posición según sea necesario
    discordInput:SetSize(200, 20)
    discordInput:SetAutoFocus(false)
    discordInput:SetFontObject("ChatFontNormal")
    discordInput:SetText("")

    -- Crear el checkbox
    enabledPanelCheckbox = CreateFrame("CheckButton", "RaidDominionEnabledCheckbox", DiscordLinkInput, "UICheckButtonTemplate")
    enabledPanelCheckbox:SetPoint("TOPLEFT", 80, -30)
    enabledPanelCheckbox:SetSize(20, 20)
    
    -- Configurar el estado inicial
    enabledPanelCheckbox:SetChecked(enabledPanel)
    
    -- Manejar cambios en el checkbox
    enabledPanelCheckbox:SetScript("OnClick", function(self)
        enabledPanel = self:GetChecked()
        -- Actualizar la interfaz de usuario
        UpdateUIState()
    end)
    
    -- Marcar como inicializado
    checkboxInitialized = true
    
    -- Actualizar la interfaz de usuario
    UpdateUIState()
end

function CreateRaidDominionAboutTabContent(parent)
    local content = CreateFrame("Frame", "AboutTabContent", parent)
    content:SetPoint("TOPLEFT", 10, -55)
    content:SetSize(300, 300)

    local instructions = {{"GameFontHighlightSmall", "NAVEGAR POR EL MENU:", 20},
                          {"GameFontNormal", "Click derecho/izquierdo.", 20, 270}}

    local currentYOffset = -5 -- Posición vertical inicial

    for _, instruction in ipairs(instructions) do
        local fontString = content:CreateFontString(nil, "ARTWORK", instruction[1])
        fontString:SetText(instruction[2])
        fontString:SetPoint("TOPLEFT", content, "TOPLEFT", instruction[3], currentYOffset)

        if instruction[4] then
            fontString:SetJustifyH("LEFT")
            fontString:SetWidth(instruction[4])
        end

        local _, fontHeight = fontString:GetFont()
        local numExtraLines = math.ceil(#instruction[2] / 70)
        currentYOffset = currentYOffset - fontHeight * (numExtraLines + 1) - 5 -- Actualiza la posición vertical para la siguiente línea
    end

    local youtubeTitle = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    youtubeTitle:SetText("Tutorial en Youtube:")
    youtubeTitle:SetPoint("TOPLEFT", content, "TOPLEFT", 20, currentYOffset - 0)
    currentYOffset = currentYOffset - 30 -- Ajusta la posición vertical

    local youtubeLink = CreateFrame("EditBox", "youtubeLink", content, "InputBoxTemplate")
    youtubeLink:SetPoint("TOPLEFT", youtubeTitle, "BOTTOMLEFT", 0, -5)
    youtubeLink:SetSize(250, 20)
    youtubeLink:SetAutoFocus(false)
    youtubeLink:SetText("https://www.youtube.com/@IAM-GAMECODE")
    youtubeLink:SetFontObject("ChatFontNormal")
    currentYOffset = currentYOffset - 30 -- Ajusta la posición vertical

    -- Enlace de GitHub para actualizaciones
    local githubTitle = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    githubTitle:SetText("Descarga de Actualizaciones:")
    githubTitle:SetPoint("TOPLEFT", content, "TOPLEFT", 20, currentYOffset - 0)
    currentYOffset = currentYOffset - 30 -- Ajusta la posición vertical

    local githubLink = CreateFrame("EditBox", "githubLink", content, "InputBoxTemplate")
    githubLink:SetPoint("TOPLEFT", githubTitle, "BOTTOMLEFT", 0, -5)
    githubLink:SetSize(250, 20)
    githubLink:SetAutoFocus(false)
    githubLink:SetText("https://raid-dominion.netlify.app/")
    githubLink:SetFontObject("ChatFontNormal")
    currentYOffset = currentYOffset - 30 -- Ajusta la posición vertical

    -- Enlace de PayPal para donaciones
    local paypalTitle = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    paypalTitle:SetText("Donaciones:")
    paypalTitle:SetPoint("TOPLEFT", content, "TOPLEFT", 20, currentYOffset - 0)
    currentYOffset = currentYOffset - 30 -- Ajusta la posición vertical

    local paypalLink = CreateFrame("EditBox", "paypalLink", content, "InputBoxTemplate")
    paypalLink:SetPoint("TOPLEFT", paypalTitle, "BOTTOMLEFT", 0, -5)
    paypalLink:SetSize(250, 20)
    paypalLink:SetAutoFocus(false)
    paypalLink:SetText("https://paypal.me/iamdev88")
    paypalLink:SetFontObject("ChatFontNormal")
    currentYOffset = currentYOffset - 30 -- Ajusta la posición vertical
end

-- Function to initialize the RaidDominion panel
function RaidDominionPanelInit()
    -- SendSystemMessage("RaidDominionPanelInit")
    local panel = _G["RaidDominionWindow"]
    if not panel then
        return
    end

    PanelTemplates_SetNumTabs(panel, 2)
    PanelTemplates_SetTab(panel, 1)
    _G["RaidDominionOptionsTab"]:Show()
    _G["RaidDominionAboutTab"]:Hide()

    _G["RaidDominionWindowTab1"]:SetScript("OnClick", function()
        PanelTemplates_SetTab(panel, 1)
        _G["RaidDominionAboutTab"]:Hide()
        _G["RaidDominionOptionsTab"]:Show()
    end)

    _G["RaidDominionWindowTab2"]:SetScript("OnClick", function()
        PanelTemplates_SetTab(panel, 2)
        _G["RaidDominionOptionsTab"]:Hide()
        _G["RaidDominionAboutTab"]:Show()
    end)
end
