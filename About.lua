function aboutContent()
    local aboutFrame = CreateFrame("Frame", nil, RaidDominionPanel)
    aboutFrame:SetSize(440, 200)

    local contentScrollFrame = CreateFrame("ScrollFrame", "aboutFrame_ContentScrollFrame", aboutFrame,
        "UIPanelScrollFrameTemplate")
    contentScrollFrame:SetPoint("TOPLEFT", 10, -58)
    contentScrollFrame:SetPoint("BOTTOMRIGHT", -30, 10)

    local content = CreateFrame("Frame", nil, contentScrollFrame)
    content:SetSize(440, 700) -- Aumentar la altura para permitir desplazamiento

    contentScrollFrame:SetScrollChild(content)

    -- Los enlaces pueden necesitar también estar en el área desplazable si deseas que se desplacen
    local githubLink = CreateFrame("EditBox", "githubLink", content, "InputBoxTemplate")
    githubLink:SetPoint("TOP", 30, -10)
    githubLink:SetSize(250, 20)
    githubLink:SetAutoFocus(false)
    githubLink:SetText("https://github.com/IAM-DEV88/RaidDominion")
    githubLink:SetFontObject("ChatFontNormal")

    local label = githubLink:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("LEFT", githubLink, "LEFT", -90, 0)
    label:SetText("Actualizaciones")

    local paypalLink = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
    paypalLink:SetPoint("TOP", githubLink, "BOTTOM", 0, -10)
    paypalLink:SetSize(250, 20)
    paypalLink:SetAutoFocus(false)
    paypalLink:SetText("paypal.me/iamdev88")
    paypalLink:SetFontObject("ChatFontNormal")

    local label = paypalLink:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("LEFT", paypalLink, "LEFT", -90, 0)
    label:SetText("Donaciones")

    local enabledPanelCheckbox = CreateFrame("CheckButton", nil, paypalLink, "UICheckButtonTemplate")
    enabledPanelCheckbox:SetPoint("LEFT", -100, -30)

    enabledPanelCheckbox:SetSize(20, 20)
    enabledPanelCheckbox:SetChecked(enabledPanel)
    enabledPanelCheckbox:SetScript("OnClick", function(self)
        enabledPanel = (self:GetChecked() == 1) and true or false
    end)

    local enabledPanelCheckboxLabel = enabledPanelCheckbox:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    enabledPanelCheckboxLabel:SetPoint("LEFT", enabledPanelCheckbox, "RIGHT", 5, 0)
    enabledPanelCheckboxLabel:SetText("Mostrar panel al cargar")

    local enabledAddonCheckbox = CreateFrame("CheckButton", nil, paypalLink, "UICheckButtonTemplate")
    enabledAddonCheckbox:SetPoint("RIGHT", 20, -30)
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

    local leftSideText = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    leftSideText:SetPoint("BOTTOM", -15, -25)
    leftSideText:SetSize(380, 700) -- Asegúrate de que el tamaño permita mostrar todo el texto
    leftSideText:SetJustifyH("LEFT") -- Alinear el texto a la izquierda
    leftSideText:SetText(
            
    "Quickname permite transformar el grupo en raid rapidamente y asignar roles seleccionando al jugador del grupo y dando clic en [x].\n\n" ..
    "Puede alertar reglas especificas y mecanicas en los menus desplegables segun se requiera.\n\n" ..
    "ROLES: Lista por categoria, asigna y alerta los roles asignados a la banda.\n\n" ..
    "Cada boton de rol puede alertar quien ocupa cada rol o si aun no hay ningun jugador asignado en el.\n\n" ..
    "Al dar clic decrecho en los botones de roles primarios se alerta para resucitar a esa unidad.\n\n" ..
    "RAID: Permite convertir el grupo en raid o hacer checks de raid rapidos con opcion de pull de 10s.\n\n" ..
    "AFK/OFF: Alerta quien esta lejos del grupo o ha estado demasiado tiempo AFK/OFF seleccionando la unidad.\n\n" ..
    "WP/LOOT: Indica el final de la raid y el inicio del loteo.\n\n" ..
    "MODIFICADORES - CTRL / SHIFT / ALT\n\n" ..
    "Utilizar [MODIFICADOR] + [CLIC IZQ]\n\n" .. "[CONTROL] + ... : Para susurrar al objetivo\n\n" ..
            "[SHIFT] + ... : Agrega el nombre del objetivo al chat activo\n\n" ..
            "[ALT] + ... : Dentro de instancia como líder de raid, agrega el nombre del objetivo al chat Raid[ALT]\n\n[ALT] + ... : Dentro de mazmorra, agrega el nombre del objetivo al chat Grupo\n\n" ..
            "[ALT] + ... : Fuera de instancia, agrega el nombre del objetivo al chat Gritar\n\n" ..
            "Puedes ocultar este cuadro de ayuda y tambien desactivar las acciones del addon, esto devolvera al los modificadores sus funciones habituales\n\n" ..
            "RaidDominion v1")

    return aboutFrame
end
