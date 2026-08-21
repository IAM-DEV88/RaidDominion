--[[
    RD_UI_MenuFrame_Announce.lua
    PROPÓSITO: Anuncios y asignaciones del menú flotante (separados de
              RD_UI_MenuFrame.lua para cumplir el límite de ~700 líneas):
              ToggleAssignment, OpenBandManager, AnnounceBand y
              AnnounceListItem. Se adjuntan como métodos a la tabla
              RD.ui.menuFrame (definida en RD_UI_MenuFrame.lua).
    API PÚBLICA:
        - RD.ui.menuFrame:ToggleAssignment(item)
        - RD.ui.menuFrame:OpenBandManager(item)
        - RD.ui.menuFrame:AnnounceBand(item)
        - RD.ui.menuFrame:AnnounceListItem(listKey, item)
    EVENTOS: Ninguno directo (envía por el canal configurado vía messageManager).
]]

local addonName, private = ...
local RD = _G.RaidDominion or {}
_G.RaidDominion = RD

local MenuFrame = RD.ui and RD.ui.menuFrame
if not MenuFrame then
    MenuFrame = {}
    RD.ui = RD.ui or {}
    RD.ui.menuFrame = MenuFrame
end

-- Mapea el nombre de un ítem de roles a la clave de rol de banda (tank/healer).
-- Los roles de la lista se escriben libremente (p.ej. "MAIN TANK", "HEALER 1");
-- se detectan por palabra clave para poder registrar al jugador en el roster.
local function RoleKeyFromItemName(name)
    local n = string.lower(tostring(name or ""))
    if n:find("tank") then return "tank", "Tanque" end
    if n:find("heal") then return "healer", "Healer" end
    return nil
end

-- Asigna/desasigna un ítem con el objetivo seleccionado (botón-icono).
-- Si el ítem es un rol tank/healer, el menú flotante muestra las bandas para
-- registrar al jugador en la elegida con su rol (ver pickband/ChooseBandForPendingRole).
function MenuFrame:ToggleAssignment(item)
    local listKey = self.currentSource and self.currentSource.key
    local assign = RD.utils and RD.utils.assignments
    if not listKey or not assign or not item then return end
    local itemName = item.name or item.title or ""
    if item.assigned then
        assign:Clear(listKey, itemName)
        self.pendingRoleAssign = nil
    elseif UnitExists("target") then
        local playerName = UnitName("target")
        assign:Set(listKey, itemName, playerName)
        -- Rol tank/healer: ofrecer registrar al jugador en una banda del roster
        local roleKey, roleLabel = RoleKeyFromItemName(itemName)
        if listKey == "roles" and roleKey then
            local bands = RD.utils and RD.utils.bands
            local bandList = (bands and bands.GetBands and bands:GetBands()) or {}
            local hasBands = false
            for _, v in ipairs(bandList) do
                if v.visible ~= false then hasBands = true break end
            end
            if hasBands then
                self.pendingRoleAssign = { playerName = playerName, role = roleKey, roleLabel = roleLabel }
                table.insert(self.history, self.currentSource)
                self.currentSource = { type = "pickband" }
                self:RenderCurrentMenu()
                return
            end
        end
    end
    self:RenderCurrentMenu()
end

-- Construye las definiciones del selector de banda ("pickband") que se muestra
-- en el menú flotante tras asignar un rol tank/healer. Cada banda visible es un
-- ítem con `chooseBand`; sin bandas muestra un aviso con la opción de cancelar.
function MenuFrame:BuildPickBandDefs()
    local defs = {}
    local bands = RD.utils and RD.utils.bands
    local bandList = (bands and bands.GetBands and bands:GetBands()) or {}
    local hadVisible = false
    for i, v in ipairs(bandList) do
        if v.visible ~= false then
            hadVisible = true
            defs[#defs + 1] = {
                name = v.name or ("Banda " .. i),
                icon = v.icon or "Interface\\Icons\\INV_Banner_02",
                chooseBand = true,
                bandIndex = i,
                tooltip = string.format("Registrar a %s como %s en esta banda.",
                    tostring(self.pendingRoleAssign and self.pendingRoleAssign.playerName or "?"),
                    tostring(self.pendingRoleAssign and self.pendingRoleAssign.roleLabel or "rol")),
            }
        end
    end
    if not hadVisible then
        defs[#defs + 1] = {
            name = "No hay bandas disponibles",
            tooltip = "Crea una banda en Configuración > Bandas para registrar al jugador.",
            isHint = true,
        }
        defs[#defs + 1] = {
            name = "Clic derecho para cancelar",
            tooltip = "El clic derecho cancela el registro del jugador.",
            isHint = true,
        }
    end
    return defs
end

-- Construye las definiciones del submenú Bandas del menú flotante: cada banda
-- visible es un ítem en dos partes (texto anuncia, icono abre el gestor). La
-- banda cuyo bucle de spam está corriendo recibe el flag `spamming` para que el
-- factory le aplique el efecto visual (fondo dorado pulsante + punto dorado). Incluye los
-- accesos al gestor de botín y las acciones rápidas, siempre disponibles.
function MenuFrame:BuildBandsDefs(list)
    local defs = {}
    local hadItems = false
    -- Banda en spam: se aplica un efecto visual al ítem correspondiente
    local spamIdx = nil
    local sp = RD.modules and RD.modules.spammer
    if sp and sp.ActiveIndex then spamIdx = sp:ActiveIndex() end
    if type(list) == "table" then
        for i, v in ipairs(list) do
            hadItems = true
            -- Control de visibilidad: los elementos ocultos (visible=false)
            -- no aparecen en el submenú del menú flotante.
            if v.visible ~= false then
                local nPlayers = 0
                if type(v.players) == "table" then nPlayers = #v.players end
                -- El horario acompaña al label del botón (además del tooltip)
                local label = v.name or ("Banda " .. i)
                local schedule = (v.schedule and v.schedule ~= "") and v.schedule or nil
                if schedule then label = label .. " · " .. schedule end
                local isSpamming = (spamIdx == i)
                local tooltip = string.format("GS mínimo: %d  ·  Horario: %s  ·  Jugadores: %d",
                    tonumber(v.minGS) or 0,
                    (v.schedule and v.schedule ~= "") and v.schedule or "Sin horario",
                    nPlayers)
                if isSpamming then
                    tooltip = tooltip .. "\n|r|cff1dbf00EN SPAM: el bucle de esta banda está corriendo."
                end
                defs[#defs + 1] = {
                    name = label,
                    icon = v.icon or "Interface\\Icons\\INV_Banner_02",
                    tooltip = tooltip,
                    isBand = true,
                    assignable = true,
                    bandIndex = i,
                    spamming = isSpamming,
                }
            end
        end
    end
    if #defs == 0 then
        if hadItems then
            defs[#defs + 1] = {
                name = "Todas las bandas están ocultas",
                tooltip = "Actívalas con el botón-ojo en Configuración > Bandas.",
                isHint = true,
            }
        else
            defs[#defs + 1] = {
                name = "No hay bandas registradas",
                action = "OpenConfigBands",
                tooltip = "Crea una banda desde la configuración (Opciones > Configuración > Bandas)",
            }
        end
    end
    -- Acciones de botín y banda: SIEMPRE disponibles en el submenú Bandas,
    -- aunque no haya bandas registradas ni visibles. El gestor de botín es
    -- independiente de las bandas (se abre por /rdloot o aquí).
    defs[#defs + 1] = {
        name = "Gestor de botín",
        action = "OpenLoot",
        icon = "Interface\\Icons\\INV_Misc_Bag_10_Blue",
        tooltip = "Abre el gestor de botín: registra, tira dados y asigna el botín de la banda.",
    }
    defs[#defs + 1] = {
        name = "Spamear botín",
        action = "SpamLoot",
        icon = "Interface\\Icons\\INV_Misc_Bag_09",
        tooltip = "Anuncia los ítems del botín del boss recién caído por la salida por defecto.",
    }
    defs[#defs + 1] = {
        name = "Recoger items",
        action = "CollectLoot",
        icon = "Interface\\Icons\\INV_Misc_Coin_01",
        tooltip = "Dirige todos los ítems del botín abierto al maestro despojador.",
    }
    -- "Spamear banda" solo se muestra si hay al menos una banda registrada (el
    -- spammer siempre requiere una banda/índice; no existe el modo "Sin banda").
    if type(list) == "table" and #list > 0 then
        defs[#defs + 1] = {
            name = "Spamear banda",
            action = "OpenSpammerEmpty",
            icon = "Interface\\Icons\\INV_Banner_01",
            tooltip = "Abre el spammer de banda para componer y spamear el reclutamiento de la banda.",
        }
    end
    return defs
end

-- Registra al jugador pendiente (rol tank/healer) en la banda elegida y vuelve
-- al menú de roles. Sin pendiente o sin banda válida solo regresa.
function MenuFrame:ChooseBandForPendingRole(bandIndex)
    local pending = self.pendingRoleAssign
    self.pendingRoleAssign = nil
    if pending and bandIndex and bandIndex >= 1 then
        local bands = RD.utils and RD.utils.bands
        if bands and bands.AddPlayer then
            local ok = bands:AddPlayer(bandIndex, {
                name = pending.playerName,
                role = pending.role,
            })
            local mm = RD.modules and RD.modules.messageManager
            if mm and mm.SendSystemMessage then
                if ok then
                    local band = bands.GetBand and bands:GetBand(bandIndex)
                    mm:SendSystemMessage(string.format(
                        "|cff00ff00[RaidDominion]|r %s registrado en %s como %s.",
                        tostring(pending.playerName),
                        tostring((band and band.name) or ("Banda " .. bandIndex)),
                        tostring(pending.roleLabel or pending.role)))
                else
                    mm:SendSystemMessage("|cffff8000[RaidDominion]|r No se pudo registrar al jugador en la banda.")
                end
            end
        end
    end
    self:GoBack()
end

-- Abre el gestor de jugadores de una banda (clic en el icono del ítem).
function MenuFrame:OpenBandManager(item)
    local bw = RD.ui and RD.ui.bandsWindow
    if bw and bw.ShowBand and item.bandIndex then
        bw:ShowBand(item.bandIndex)
    else
        local mm = RD.modules and RD.modules.messageManager
        if mm and mm.SendSystemMessage then
            mm:SendSystemMessage("|cffff0000[RaidDominion]|r La ventana de bandas no está disponible.")
        end
    end
end

-- Anuncia una banda por el canal configurado (clic en el texto del ítem).
-- Formato similar a reglas/mecánicas: "=== Nombre ===" + resumen de la banda.
function MenuFrame:AnnounceBand(item)
    local mm = RD.modules and RD.modules.messageManager
    if not mm or not mm.SendMessage then return end
    local bands = RD.utils and RD.utils.bands
    local band = bands and bands:GetBand(item.bandIndex)
    if not band then return end
    mm:SendMessage("=== " .. (band.name or item.name or "Banda") .. " ===")
    -- El horario NO se anuncia: queda en el label/tooltip del ítem del menú y en
    -- la ventana de banda (bandInfo), como está actualmente.
    mm:SendMessage(string.format("GS mínimo: %d",
        tonumber(band.minGS) or 0))
end

-- Anuncia un elemento de lista dinámica por el canal configurado.
-- roles/abilities/buffs/auras (asignables): "<asignado> [<ítem>]" si ya hay
-- asignación; si no, "<objetivo> [<ítem>]" o "NEED [<ítem>]". NO crea
-- asignaciones (eso es del botón-icono, como el addon base).
-- rules/mechanics: envía el contenido (troceado si supera 250 bytes).
function MenuFrame:AnnounceListItem(listKey, item)
    local mm = RD.modules and RD.modules.messageManager
    if not mm then return end

    if listKey == "mechanics" or listKey == "rules" then
        -- Como el addon base: primero el título con formato "=== Título ==="
        -- y después el contenido (troceado si supera 250 bytes).
        local title = item.title or item.name or ""
        local content = item.content or ""
        if content == "" then
            content = item.name or ""
        end
        if title ~= "" then
            mm:SendMessage("=== " .. title .. " ===")
        end
        if content ~= "" and content ~= title then
            mm:SendMessage(content)
        end
        return
    end

    local itemName = item.name or item.title or ""
    if item.assigned then
        mm:SendMessage(item.assigned .. " [" .. itemName .. "]")
        return
    end
    local targetName = UnitExists("target") and UnitName("target") or nil
    if targetName then
        mm:SendMessage(targetName .. " [" .. itemName .. "]")
    else
        mm:SendMessage("NEED [" .. itemName .. "]")
    end
end
-- Registro explícito e idempotente: la tabla debe ser SIEMPRE la misma que la del
-- archivo principal, por si este archivo se cargó antes que aquél.
RD.ui = RD.ui or {}
RD.ui.menuFrame = MenuFrame

return MenuFrame
