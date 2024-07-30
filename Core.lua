
function CreateRaidDominionOptionsTabContent(parent)
    local contentScrollFrame = CreateFrame("ScrollFrame", "OptionsTab_ContentScrollFrame", parent,
        "UIPanelScrollFrameTemplate")
    contentScrollFrame:SetPoint("TOPLEFT", 10, -55)
    contentScrollFrame:SetPoint("BOTTOMRIGHT", -10, 10)

    local content = CreateFrame("Frame", nil, contentScrollFrame)
    content:SetSize(340, 600) -- Ajusta la altura según la cantidad de contenido
    contentScrollFrame:SetScrollChild(content)

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
    discordInput:SetPoint("TOPLEFT", 80, -26) -- Ajusta la posición según sea necesario
    discordInput:SetSize(200, 20)
    discordInput:SetAutoFocus(false)
    discordInput:SetFontObject("ChatFontNormal")
    discordInput:SetText("")

    enabledPanelCheckbox = CreateFrame("CheckButton", nil, DiscordLinkInput, "UICheckButtonTemplate")
    enabledPanelCheckbox:SetPoint("TOPLEFT", 60, -30)

    enabledPanelCheckbox:SetSize(20, 20)
    enabledPanelCheckbox:SetChecked(enabledPanel)
    enabledPanelCheckbox:SetScript("OnClick", function(self)
        enabledPanel = (self:GetChecked() == 1) and true or false
    end)
end


function CreateRaidDominionAboutTabContent(parent)
    local contentScrollFrame = CreateFrame("ScrollFrame", "AboutTab_ContentScrollFrame", parent,
        "UIPanelScrollFrameTemplate")
    contentScrollFrame:SetPoint("TOPLEFT", 10, -55)
    contentScrollFrame:SetPoint("BOTTOMRIGHT", -10, 10)

    local content = CreateFrame("Frame", nil, contentScrollFrame)
    content:SetSize(300, 600) -- Ajusta la altura según la cantidad de contenido
    contentScrollFrame:SetScrollChild(content)

    local instructions = {{"GameFontHighlightSmall", "NAVEGAR POR EL MENU:", 20},
                          {"GameFontNormal", "Click derecho/izquierdo.", 20, 270},
                          {"GameFontHighlightSmall", "TUTORIAL EN YOUTUBE:", 20}, {"GameFontNormal",
                                                                               "Conozca todas las herramientas de RaidDominion Tools.",
                                                                               20, 270},
                          {"GameFontHighlightSmall", "COMUNIDAD:", 20},
                          {"GameFontNormal",
                           "Apoye el desarrollo continuo del addon mediante donaciones. ¡Gracias!", 20,
                           270}}

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

    -- Enlace de GitHub para actualizaciones
    local githubTitle = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    githubTitle:SetText("Actualizaciones:")
    githubTitle:SetPoint("TOPLEFT", content, "TOPLEFT", 20, currentYOffset - 0)
    currentYOffset = currentYOffset - 30 -- Ajusta la posición vertical

    local githubLink = CreateFrame("EditBox", "githubLink", content, "InputBoxTemplate")
    githubLink:SetPoint("TOPLEFT", githubTitle, "BOTTOMLEFT", 0, -5)
    githubLink:SetSize(250, 20)
    githubLink:SetAutoFocus(false)
    githubLink:SetText("https://github.com/IAM-DEV88/RaidDominion")
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

    local youtubeTitle = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    youtubeTitle:SetText("Youtube:")
    youtubeTitle:SetPoint("TOPLEFT", content, "TOPLEFT", 20, currentYOffset - 0)
    currentYOffset = currentYOffset - 30 -- Ajusta la posición vertical

    local youtubeLink = CreateFrame("EditBox", "youtubeLink", content, "InputBoxTemplate")
    youtubeLink:SetPoint("TOPLEFT", youtubeTitle, "BOTTOMLEFT", 0, -5)
    youtubeLink:SetSize(250, 20)
    youtubeLink:SetAutoFocus(false)
    youtubeLink:SetText("https://www.youtube.com/@IAM-DEV88")
    youtubeLink:SetFontObject("ChatFontNormal")
    currentYOffset = currentYOffset - 30 -- Ajusta la posición vertical
end


-- Function to initialize the RaidDominion panel
function RaidDominionPanelInit()
    -- SendSystemMessage("RaidDominionPanelInit")
    local panel = _G["RaidDominionWindow"]
    if not panel then return end
    
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