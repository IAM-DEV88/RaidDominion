function aboutContent()
    local aboutFrame = CreateFrame("Frame", nil, QuickNamePanel)
    aboutFrame:SetSize(440, 200)

    local contentScrollFrame = CreateFrame("ScrollFrame", "aboutFrame_ContentScrollFrame", aboutFrame,
        "UIPanelScrollFrameTemplate")
    contentScrollFrame:SetPoint("TOPLEFT", 10, -58)
    contentScrollFrame:SetPoint("BOTTOMRIGHT", -30, 10)

    local content = CreateFrame("Frame", nil, contentScrollFrame)
    content:SetSize(440, 350) -- Aumentar la altura para permitir desplazamiento

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
    local githubLink = CreateFrame("EditBox", "githubLink", content, "InputBoxTemplate")
    githubLink:SetPoint("TOP", leftSideText, "BOTTOM", 0, 0)
    githubLink:SetSize(200, 20)
    githubLink:SetAutoFocus(false)
    githubLink:SetText("https://github.com/IAM-DEV88/QuickName")
    githubLink:SetFontObject("ChatFontNormal")

    local paypalLink = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
    paypalLink:SetPoint("TOP", githubLink, "BOTTOM", 0, -10)
    paypalLink:SetSize(200, 20)
    paypalLink:SetAutoFocus(false)
    paypalLink:SetText("paypal.me/iamdev88")
    paypalLink:SetFontObject("ChatFontNormal")

    enabledPanelCheckbox = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    enabledPanelCheckbox:SetPoint("BOTTOMLEFT", 10, 10)

    enabledPanelCheckbox:SetSize(20, 20)
    enabledPanelCheckbox:SetChecked(enabledPanel)
    enabledPanelCheckbox:SetScript("OnClick", function(self)
        enabledPanel = (self:GetChecked() == 1) and true or false
    end)

    local enabledPanelCheckboxLabel = enabledPanelCheckbox:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    enabledPanelCheckboxLabel:SetPoint("LEFT", enabledPanelCheckbox, "RIGHT", 5, 0)
    enabledPanelCheckboxLabel:SetText("Mostrar panel al cargar")

    enabledAddonCheckbox = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    enabledAddonCheckbox:SetPoint("BOTTOMRIGHT", -40, 10)
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

    local enabledAddonCheckboxLabel = enabledAddonCheckbox:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    enabledAddonCheckboxLabel:SetPoint("RIGHT", enabledAddonCheckbox, "RIGHT", -25, 0)
    enabledAddonCheckboxLabel:SetText("Modificadores activos")

    return aboutFrame
end