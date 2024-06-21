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
    discordInput:SetSize(250, 20)
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