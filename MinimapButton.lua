-- Función para manejar los clics en el botón del minimapa
local function MyMiniMapButton_OnMouseDown(self, button)
    if button == "LeftButton" then
        if RaidDominionFrame:IsShown() then
            -- Si el panel está mostrado, ocúltalo
            RaidDominionFrame:Hide()
        else
            -- Si el panel está oculto, muéstralo
            RaidDominionFrame:Show()
        end
    elseif button == "RightButton" then
        -- Crear el menú emergente
        local menuFrame = CreateFrame("Frame", "MyMiniMapMenuFrame", UIParent, "UIDropDownMenuTemplate")

        -- Función para manejar los clics en las opciones del menú
        local function OnMenuOptionClicked(self)
            local option = self:GetID() -- Obtener el ID de la opción seleccionada
            if option == 1 then
                ReloadUI()
            end
        end

        -- Crear las opciones del menú
        local menuList = {
            {
                text = "Recargar UI",
                func = OnMenuOptionClicked
            },
            {
                text = "Nombrar objetivo",
                func = function()
                    nameTarget()
                end
            }
        }

        -- Mostrar el menú en la posición del cursor
        EasyMenu(menuList, menuFrame, "cursor", 0, 0, "MENU", 1)
    end
end

-- Crear el botón en la barra de minimapa
local myMiniMapButton = CreateFrame("Button", "MyMiniMapButton", Minimap)
myMiniMapButton:SetSize(26, 26) -- Establecer el tamaño del botón
myMiniMapButton:SetPoint("TOPLEFT", Minimap, "TOPLEFT", 0, 0) -- Establecer la posición del botón

-- Personalizar el aspecto del botón
myMiniMapButton:SetNormalTexture("Interface\\Icons\\inv_misc_summerfest_brazierorange") -- Establecer la textura del botón

-- Asignar la función para manejar los clics en el botón
myMiniMapButton:SetScript("OnMouseDown", MyMiniMapButton_OnMouseDown)

-- Función para manejar el evento cuando el mouse entra al botón del minimapa
local function MyMiniMapButton_OnEnter(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT") -- Establecer el tooltip en relación al botón
    GameTooltip:SetText("|cfff58cbaRaidDominion|r |caad4af37v1.0.0|r")
    GameTooltip:AddLine("Clic Izq: Mostrar/ocultar panel")
    GameTooltip:AddLine("Clic Der: Menu")
    GameTooltip:Show() -- Mostrar el tooltip
end

-- Función para manejar el evento cuando el mouse sale del botón del minimapa
local function MyMiniMapButton_OnLeave(self)
    GameTooltip:Hide() -- Ocultar el tooltip cuando el mouse sale del botón
end

-- Asignar las funciones a los eventos del botón del minimapa
myMiniMapButton:SetScript("OnEnter", MyMiniMapButton_OnEnter)
myMiniMapButton:SetScript("OnLeave", MyMiniMapButton_OnLeave)
