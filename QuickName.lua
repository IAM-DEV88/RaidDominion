local addonName = "QuickName"
local numRaidButtons = 40 -- Ajusta esto según el número real de botones en tu RaidGroup
local skipCheckbox
local enableAddonCheckbox

local function createHelpDialog(skipHelpDialog, enableAddon)
    local helpDialog = CreateFrame("Frame", "AboutFrame", UIParent)
    helpDialog:SetSize(450, 320)
    helpDialog:SetPoint("CENTER")
    helpDialog:EnableMouse(true)
    helpDialog:SetMovable(true)
    helpDialog:RegisterForDrag("LeftButton")
    helpDialog:SetScript("OnDragStart", helpDialog.StartMoving)
    helpDialog:SetScript("OnDragStop", helpDialog.StopMovingOrSizing)
    helpDialog:SetBackdrop({
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
    helpDialog:SetBackdropBorderColor(0.4, 0.4, 0.4)

    local helpDialogText = helpDialog:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    helpDialogText:SetPoint("CENTER", -110, 10)
    helpDialogText:SetSize(200, 280)
    helpDialogText:SetText(" ===== INSTRUCCIONES ===== \n\n" .. "Utiliza: [CLIC IZQ] +\n\n" ..
                               "[CONTROL]\nPara susurrar al objetivo\n\n" ..
                               "[SHIFT]\nAgrega el nombre del objetivo al chat activo\n\n" ..
                               "[ALT] Dentro de instancia como lider de raid\nAgrega el nombre del objetivo al chat Alerta de Raid\n\n" ..
                               "[ALT] Dentro de instancia como unidad de raid\nAgrega el nombre del objetivo al chat Raid")
    helpDialogText:SetJustifyH("LEFT")

    local donateText = helpDialog:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    donateText:SetPoint("CENTER", 110, 40)
    donateText:SetSize(200, 280)
    donateText:SetText("[ALT] Dentro de mazmorra\nAgrega el nombre del objetivo al chat Grupo\n\n" ..
    "[ALT] Fuera de instancia\nAgrega el nombre del objetivo al chat Gritar\n\n" .. 
    "Puedes ocultar este cuadro de ayuda y tambien desactivar las acciones del addon, esto devolvera al panel de banda sus funciones habituales\n\n" ..
    "QuickName v1")
    donateText:SetJustifyH("LEFT")

    skipCheckbox = CreateFrame("CheckButton", nil, helpDialog, "UICheckButtonTemplate")
    skipCheckbox:SetPoint("BOTTOMLEFT", 10, 10)
    skipCheckbox:SetSize(20, 20)
    skipCheckbox:SetChecked(skipHelpDialog)
    skipCheckbox:SetScript("OnClick", function(self)
        skipHelpDialog = (self:GetChecked() == 1) and true or false
    end)

    local skipLabel = skipCheckbox:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    skipLabel:SetPoint("LEFT", skipCheckbox, "RIGHT", 5, 0)
    skipLabel:SetText("Ocultar ayuda")

    enableAddonCheckbox = CreateFrame("CheckButton", nil, helpDialog, "UICheckButtonTemplate")
    enableAddonCheckbox:SetPoint("BOTTOMRIGHT", -10, 10)
    enableAddonCheckbox:SetSize(20, 20)
    enableAddonCheckbox:SetChecked(enableAddon)
    enableAddonCheckbox:SetScript("OnClick", function(self)
        enableAddon = (self:GetChecked() == 1) and true or false
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
            preferredIndex = 3, -- Posición preferida en la pila de ventanas emergentes
        }

        StaticPopup_Show("RELOAD_UI_CONFIRM")
    end)

    local enableAddonLabel = enableAddonCheckbox:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    enableAddonLabel:SetPoint("RIGHT", enableAddonCheckbox, "RIGHT", -24, 0)
    enableAddonLabel:SetText("Addon activo")

    local closeButton = CreateFrame("Button", nil, helpDialog, "UIPanelButtonTemplate")
    closeButton:SetPoint("BOTTOM", 0, 20)
    closeButton:SetSize(100, 25)
    closeButton:SetText("Cerrar")
    closeButton:SetScript("OnClick", function()
        helpDialog:Hide()
    end)

    local githubLink = CreateFrame("EditBox", nil, helpDialog, "InputBoxTemplate")
    githubLink:SetPoint("CENTER", helpDialog, "CENTER", 110, -70)
    githubLink:SetSize(200, 40)
    githubLink:SetAutoFocus(false)
    githubLink:SetText("https://github.com/IAM-DEV88")
    githubLink:SetFontObject("ChatFontNormal")
    githubLink:SetJustifyH("LEFT")

    local paypalLink = CreateFrame("EditBox", nil, helpDialog, "InputBoxTemplate")
    paypalLink:SetPoint("CENTER", helpDialog, "CENTER", 110, -100)
    paypalLink:SetSize(200, 40)
    paypalLink:SetAutoFocus(false)
    paypalLink:SetText("paypal.me/iamdev88")
    paypalLink:SetFontObject("ChatFontNormal")
    paypalLink:SetJustifyH("LEFT")

    return helpDialog
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

local function UpdateRaidButtons()
    for i = 1, numRaidButtons do
        local button = _G["RaidGroupButton" .. i]
        button:RegisterForClicks("LeftButtonUp")
        button:SetScript("OnClick", function()
            local playerName = UnitName("raid" .. i)
            local modifierPressed = IsAltKeyDown() and "ALT" or
                                        (IsControlKeyDown() and "CONTROL" or (IsShiftKeyDown() and "SHIFT"))
            HandleClick(playerName, modifierPressed, enableAddon)
        end)
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_LOGOUT")
frame:SetScript("OnEvent", function(self, event)
    if event == "ADDON_LOADED" then
        if enableAddon then
            UpdateRaidButtons()
            end
    elseif event == "PLAYER_LOGIN" then
        if not enableAddon and skipHelpDialog then
            print("QuickName esta desactivado, puedes usar /qname para ver las opciones")
        end
        local helpDialog = createHelpDialog(skipHelpDialog, enableAddon)
        if not skipHelpDialog then
            helpDialog:Show()
        else
            helpDialog:Hide()
        end
        SLASH_QNAME1 = "/qname"
        SlashCmdList["QNAME"] = function()
            helpDialog:Show(not helpDialog:IsShown())
        end

        if enableAddon then
            local character = CreateFrame("Frame")
            character:RegisterEvent("PLAYER_TARGET_CHANGED")
            character:SetScript("OnEvent", function(_, event, ...)
                if event == "PLAYER_TARGET_CHANGED" then
                    local targetName = UnitName("target")
                    local modifierPressed = IsAltKeyDown() and "ALT" or
                                                (IsControlKeyDown() and "CONTROL" or (IsShiftKeyDown() and "SHIFT"))
                    HandleClick(targetName, modifierPressed)
                end
            end)
    
            local groupFrame = CreateFrame("Frame")
            groupFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
            groupFrame:SetScript("OnEvent", UpdateRaidButtons)
        end
    elseif event == "PLAYER_LOGOUT" then
        skipHelpDialog = (skipCheckbox:GetChecked() == 1) and true or false
        enableAddon = (enableAddonCheckbox:GetChecked() == 1) and true or false
    end
end)
