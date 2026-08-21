--[[
    RD_UI_BandsPlayerEditor.lua
    PROPÓSITO: Ventana modal para añadir/editar un jugador de una banda.
              Permite nombre, rol (T/H/R/M), gearscore, clase, sanción y notas.
              El frame se crea UNA vez y se reutiliza (sin recrear ni polling),
              por lo que consume recursos mínimos. Registra RD.ui.playerEditor.
    API PÚBLICA:
        - RD.ui.playerEditor:OpenPlayerEditor(opts)
              opts = { bandIndex, player (nil si es nuevo), onSaved }
    EVENTOS: Ninguno. Escribe vía RD.utils.bands (dispara CONFIG_CHANGED).
]]

local addonName, private = ...
local RD = _G.RaidDominion or {}
_G.RaidDominion = RD

local PlayerEditor = {}

local editor = nil

local GOLD_R, GOLD_G, GOLD_B = unpack((RD.constants and RD.constants.COLORS and RD.constants.COLORS.GOLD) or { 1, 0.82, 0 })

-- Nombre único para frames con template (los templates crean hijos con $parent).
-- Se delega en el contador ÚNICO de RD.UIUtils para evitar colisiones entre archivos.
local UniqueName = RD.UIUtils and RD.UIUtils.UniqueName

local CLASS_LIST = { "", "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DEATHKNIGHT", "DRUID" }

-- Nombre localizado de una clase (classFile)
local function ClassLabel(classFile)
    if classFile and classFile ~= "" and _G.LOCALIZED_CLASS_NAMES and _G.LOCALIZED_CLASS_NAMES[classFile] then
        return _G.LOCALIZED_CLASS_NAMES[classFile]
    end
    return classFile and classFile ~= "" and classFile or "Sin clase"
end

local function BuildEditor()
    editor = CreateFrame("Frame", "RaidDominionPlayerEditor", UIParent)
    editor:SetFrameStrata("HIGH")
    editor:SetToplevel(true)
    editor:SetClampedToScreen(true)
    editor:SetSize(400, 500)
    editor:EnableMouse(true)
    editor:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    editor:SetBackdropColor(0, 0, 0, 0.95)
    editor:SetBackdropBorderColor(1, 1, 1, 0.5)
    table.insert(UISpecialFrames, "RaidDominionPlayerEditor")

    -- Arrastrable desde cualquier zona no interactiva del editor
    editor:SetMovable(true)
    editor:RegisterForDrag("LeftButton")
    editor:SetScript("OnDragStart", function() editor:StartMoving() end)
    editor:SetScript("OnDragStop", function() editor:StopMovingOrSizing() end)
    if RD.UIUtils and RD.UIUtils.MakeClickToTop then
        RD.UIUtils.MakeClickToTop(editor)
    end

    -- Sin "clic fuera cierra": el editor NO se cierra al hacer clic fuera, para
    -- no perder lo escrito (se cierra con Guardar/Cancelar o el botón X). El
    -- Escape libera el foco de los campos (y un segundo Escape, sin campo
    -- enfocado, cierra la ventana vía UISpecialFrames).
    editor:SetScript("OnHide", function()
        editor.onSaved = nil
        editor.player = nil
    end)

    local title = editor:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOP", editor, "TOP", 0, -10)
    title:SetText("Editar jugador")
    editor.title = title
    RD.UIUtils.ScaleFont(title, 1.5)

    local closeBtn = CreateFrame("Button", UniqueName("Cl"), editor, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", editor, "TOPRIGHT", -4, -4)
    closeBtn:SetScript("OnClick", function() editor:Hide() end)

    local function MakeLabel(text, y)
        local lbl = editor:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        lbl:SetText(text)
        lbl:SetJustifyH("LEFT")
        lbl:SetPoint("TOPLEFT", editor, "TOPLEFT", 20, y)
        RD.UIUtils.ScaleFont(lbl, 1.5)
        return lbl
    end

    -- Nombre
    MakeLabel("Nombre:", -36)
    local nameBox = CreateFrame("EditBox", UniqueName("Nm"), editor, "InputBoxTemplate")
    nameBox:SetSize(160, 24)
    nameBox:SetPoint("TOPLEFT", editor, "TOPLEFT", 120, -34)
    nameBox:SetAutoFocus(false)
    RD.UIUtils.StyleInput(nameBox)
    -- Enter/Escape liberan el foco (estilo KRT) para poder usar atajos del teclado.
    nameBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    nameBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    editor.nameBox = nameBox


    local widgetHelpers = RD.ui and RD.ui.widgets

    -- Convierte tablas de datos (BAND_ROLE/BAND_LEADER/BAND_SANCTION) en opciones
    -- (helper central Widgets.DataOptions, con wrapper local defensivo)
    local function DataOptions(dataTable)
        return (widgetHelpers and widgetHelpers.DataOptions)
            and widgetHelpers.DataOptions(dataTable) or {}
    end

    -- Dropdown de campo en el modal (rol, dual, líder, sanción)
    local function MakeModalDropdown(x, y, fieldName, options, emptyLabel)
        if not widgetHelpers or not widgetHelpers.CreateOptionsDropdown then return nil end
        local dd = widgetHelpers:CreateOptionsDropdown(editor, 160, {
            options = options,
            emptyLabel = emptyLabel,
            current = editor[fieldName] or "",
            onSelect = function(key)
                editor[fieldName] = key
            end,
        })
        dd.button:SetPoint("TOPLEFT", editor, "TOPLEFT", x, y)
        return dd
    end

    -- Rol principal (lista desplegable)
    MakeLabel("Rol:", -72)
    editor.roleDD = MakeModalDropdown(110, -72, "role",
        DataOptions(RD.constants and RD.constants.BAND_ROLE_DATA), "—")

    -- Dual (segunda especialización, lista desplegable)
    MakeLabel("Dual:", -108)
    editor.dualDD = MakeModalDropdown(110, -108, "dual",
        DataOptions(RD.constants and RD.constants.BAND_ROLE_DATA), "—")

    -- Líder de raid (No / Sí / Ayudante, lista desplegable)
    MakeLabel("Líder:", -144)
    editor.leaderDD = MakeModalDropdown(110, -144, "leader",
        DataOptions(RD.constants and RD.constants.BAND_LEADER_DATA), "No")

    -- Clase (dropdown; requiere nombre único para la API de dropdowns)
    MakeLabel("Clase:", -180)
    local classDD = CreateFrame("Frame", UniqueName("Cl"), editor, "UIDropDownMenuTemplate")
    classDD:SetPoint("TOPLEFT", editor, "TOPLEFT", 110, -180)
    UIDropDownMenu_SetWidth(classDD, 150)
    UIDropDownMenu_SetAnchor(classDD, 0, 0)
    -- Escala el texto del dropdown a 15px para respetar la jerarquía (igual que
    -- los demás valores/inputs del modal).
    local classDDText = getglobal(classDD:GetName() .. "Button")
    if classDDText and classDDText.GetFontString then
        local fs = classDDText:GetFontString()
        if fs then RD.UIUtils.ScaleFont(fs, 1.5) end
    end
    UIDropDownMenu_Initialize(classDD, function()
        local info = UIDropDownMenu_CreateInfo()
        for _, cf in ipairs(CLASS_LIST) do
            info.text = ClassLabel(cf)
            info.value = cf
            info.checked = (cf == editor.class)
            info.func = function()
                editor.class = cf
                UIDropDownMenu_SetSelectedValue(classDD, cf)
                UIDropDownMenu_SetText(classDD, ClassLabel(cf))
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    editor.classDD = classDD

    -- Sanción (lista desplegable de causales)
    MakeLabel("Sanción:", -216)
    editor.sancDD = MakeModalDropdown(110, -216, "sanction",
        DataOptions(RD.constants and RD.constants.BAND_SANCTION_DATA), "Sin sanción")

    -- Asistencia (puntos; ÚNICO campo que conserva los controles - / +)
    MakeLabel("Asistencia:", -252)
    local att = widgetHelpers and widgetHelpers.CreateStepper and widgetHelpers:CreateStepper(editor, 160)
    if att then
        -- Campo y controles de asistencia desplazados 25px a la derecha en total
        att.frame:SetPoint("TOPLEFT", editor, "TOPLEFT", 135, -252)
        local function PaintAtt()
            att.label:SetText(tostring(tonumber(editor.points) or 0))
            att.label:SetTextColor(1, 1, 1)
        end
        PaintAtt()
        local function NavAtt(delta)
            editor.points = math.max(0, (tonumber(editor.points) or 0) + delta)
            PaintAtt()
        end
        att.minus:SetScript("OnClick", function() NavAtt(-1) end)
        att.plus:SetScript("OnClick", function() NavAtt(1) end)
    end
    editor.attStepper = att

    -- Notas
    MakeLabel("Notas:", -288)

    -- El EditBox multilínea de 3.3.5a no recorta su texto: crece con el contenido
    -- dentro de un ScrollFrame que lo recorta y scrollea (rueda del ratón/barra).
    local createScroll = RD.ui and RD.ui.widgets and RD.ui.widgets.CreateScrollFrame
    local notesW = (editor:GetWidth() or 400) - 40
    local notesScroll = createScroll(editor, notesW, 80, 20, -312)
    notesScroll:SetPoint("RIGHT", editor, "RIGHT", -20, 0)
    -- Las notas llenan hasta justo encima de los botones inferiores (sin hueco
    -- vertical vacío): el BOTTOM a 36px deja el borde inferior a la altura del
    -- borde superior de los botones (Guardar/Cancelar, 24px, anclados a 12px).
    notesScroll:SetPoint("BOTTOM", editor, "BOTTOM", 0, 36)

    local notesBox = CreateFrame("EditBox", nil, notesScroll)
    notesBox:SetWidth(notesW)
    notesBox:SetHeight(80)
    notesBox:SetPoint("TOPLEFT", notesScroll, "TOPLEFT", 0, 0)
    notesBox:SetMultiLine(true)
    notesBox:SetAutoFocus(false)
    notesBox:EnableMouse(true)
    notesBox:SetFontObject(GameFontNormalSmall)
    RD.UIUtils.ScaleFont(notesBox, 1.5)
    notesBox:SetTextInsets(4, 4, 4, 4)
    notesBox:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    notesBox:SetBackdropColor(0, 0, 0, 0.7)
    notesBox:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.7)
    notesScroll:SetScrollChild(notesBox)

    -- Convención de EditBox multilínea dentro de ScrollFrame (helper central
    -- UIUtils.MakeAutoResizeMultiline): mide con un FontString oculto y crece la
    -- caja al contenido; el ScrollFrame lo recorta y scrollea (3.3.5a no recorta).
    local ResizeNotesBox = RD.UIUtils.MakeAutoResizeMultiline(notesBox, notesScroll, notesW - 8)
    notesBox:SetScript("OnTextChanged", ResizeNotesBox)
    notesBox:SetScript("OnTextSet", ResizeNotesBox)
    -- Escape libera el foco del campo de notas (Enter inserta salto de línea y
    -- mantiene el foco, como es habitual en un área de texto multilínea).
    notesBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    editor:SetScript("OnShow", function()
        ResizeNotesBox()
        -- Fuerza el re-render interno del EditBox multilínea (el texto se seteó
        -- con el modal oculto).
        notesBox:SetText(notesBox:GetText() or "")
    end)
    editor.notesBox = notesBox
    editor.notesScroll = notesScroll

    -- Navegación con Tab entre los campos de texto del modal: Nombre → Notas
    if RD.UIUtils and RD.UIUtils.EnableTabNavigation then
        RD.UIUtils.EnableTabNavigation({ nameBox, notesBox })
    end

    -- Guardar / Cancelar
    local saveBtn = RD.UIUtils.MakeChipButton(editor, UniqueName("Sv"), 90, 24)
    saveBtn:SetText("Guardar")
    saveBtn:SetPoint("BOTTOMRIGHT", editor, "BOTTOMRIGHT", -16, 12)
    saveBtn:SetScript("OnClick", function()
        local name = strtrim(editor.nameBox:GetText() or "")
        if name == "" then return end
        local bands = RD.utils and RD.utils.bands
        if not bands then return end
        local data = {
            name = name,
            class = editor.class or "",
            role = editor.role or "",
            dual = editor.dual or "",
            leader = editor.leader or "",
            sanction = editor.sanction or "",
            points = tonumber(editor.points) or 0,
            notes = editor.notesBox:GetText() or "",
        }
        if editor.isNew then
            -- Comprobar el duplicado ANTES de AddPlayer (que en otros flujos
            -- fusiona el jugador existente y devuelve true): así no se pisan
            -- en silencio los datos del jugador ya registrado.
            local existing = bands.GetPlayer and bands:GetPlayer(editor.bandIndex, data.name or "")
            if existing then
                if RD.messageManager and RD.messageManager.SendSystemMessage then
                    RD.messageManager:SendSystemMessage("|cffff0000[RaidDominion]|r No se pudo añadir: ya existe un jugador con ese nombre.")
                end
                return
            end
            if not bands:AddPlayer(editor.bandIndex, data) then
                if RD.messageManager and RD.messageManager.SendSystemMessage then
                    RD.messageManager:SendSystemMessage("|cffff0000[RaidDominion]|r No se pudo añadir: nombre inválido.")
                end
                return
            end
        else
            if not bands:UpdatePlayer(editor.bandIndex, editor.player.name, data) then
                if RD.messageManager and RD.messageManager.SendSystemMessage then
                    RD.messageManager:SendSystemMessage("|cffff0000[RaidDominion]|r No se pudo guardar: ya existe un jugador con ese nombre.")
                end
                return
            end
        end
        local onSaved = editor.onSaved
        editor:Hide()
        if onSaved then onSaved() end
    end)
    editor.saveBtn = saveBtn

    local cancelBtn = RD.UIUtils.MakeChipButton(editor, UniqueName("Cx"), 90, 24)
    cancelBtn:SetText("Cancelar")
    cancelBtn:SetPoint("RIGHT", saveBtn, "LEFT", -8, 0)
    cancelBtn:SetScript("OnClick", function()
        editor:Hide()
    end)

    return editor
end

-- Crea el editor una sola vez y lo reutiliza. Si la construcción fallara, se
-- descarta el frame parcial para poder reconstruirlo limpio en el próximo uso.
local function EnsureEditor()
    if editor then return editor end
    local ok, err = pcall(BuildEditor)
    if not ok then
        editor = nil
        if RD.messageManager and RD.messageManager.SendSystemMessage then
            RD.messageManager:SendSystemMessage("|cffff0000[RaidDominion]|r Error al construir el editor de jugador: " .. tostring(err))
        end
        return nil
    end
    return editor
end

-- Abre el editor. opts.player nil => modo "nuevo jugador".
function PlayerEditor:OpenPlayerEditor(opts)
    if not opts or not opts.bandIndex then return end
    local ed = EnsureEditor()
    if not ed then return end
    ed.bandIndex = opts.bandIndex
    ed.player = opts.player
    ed.isNew = not opts.player
    ed.onSaved = opts.onSaved
    ed.role = (opts.player and opts.player.role) or ""
    ed.dual = (opts.player and opts.player.dual) or ""
    ed.leader = (opts.player and opts.player.leader) or ""
    ed.points = tonumber(opts.player and opts.player.points) or 0
    -- En modo nuevo, la clase puede venir precargada del objetivo seleccionado;
    -- solo se acepta si pertenece a CLASS_LIST (evita "UNKNOW" para no-jugadores).
    ed.class = (opts.player and opts.player.class) or ""
    if ed.class == "" and opts.prefill and opts.prefill.class then
        for _, cf in ipairs(CLASS_LIST) do
            if cf == opts.prefill.class then
                ed.class = cf
                break
            end
        end
    end

    -- Sanción: la causal guardada o, si es legacy (banned sin causal), "baneo"
    ed.sanction = (opts.player and (opts.player.sanction or (opts.player.banned and "baneo" or ""))) or ""
    if ed.isNew then
        ed.title:SetText("Nuevo jugador")
        ed.nameBox:SetText((opts.prefill and opts.prefill.name) or "")
        ed.notesBox:SetText("")
    else
        ed.title:SetText("Editar jugador")
        ed.nameBox:SetText(opts.player.name or "")
        ed.notesBox:SetText(opts.player.notes or "")
    end

    local w = RD.ui and RD.ui.widgets
    if w then
        if ed.roleDD and ed.roleDD.SetValue then ed.roleDD:SetValue(ed.role) end
        if ed.dualDD and ed.dualDD.SetValue then ed.dualDD:SetValue(ed.dual) end
        if ed.leaderDD and ed.leaderDD.SetValue then ed.leaderDD:SetValue(ed.leader) end
        if ed.sancDD and ed.sancDD.SetValue then ed.sancDD:SetValue(ed.sanction) end
        if ed.attStepper and ed.attStepper.label then
            ed.attStepper.label:SetText(tostring(ed.points))
            ed.attStepper.label:SetTextColor(1, 1, 1)
        end
    end
    UIDropDownMenu_SetSelectedValue(ed.classDD, ed.class)
    UIDropDownMenu_SetText(ed.classDD, ClassLabel(ed.class))

    -- Singleton: se resetea el scroll del área de Notas al abrir
    if ed.notesScroll and ed.notesScroll.SetVerticalScroll then
        ed.notesScroll:SetVerticalScroll(0)
    end
    if ed.notesBox.SetScrollOffset then
        ed.notesBox:SetScrollOffset(0)
    end

    ed:ClearAllPoints()
    ed:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    if RD.UIUtils and RD.UIUtils.ClampModalToScreen then
        RD.UIUtils.ClampModalToScreen(ed, ed.notesScroll, 20)
    end
    ed:Show()
    ed:Raise()

    local layout = RD.ui and RD.ui.layout
    if layout and layout.EnsureVisible then
        layout:EnsureVisible(ed, 8)
    end
end

RD.ui = RD.ui or {}
RD.ui.playerEditor = PlayerEditor
return PlayerEditor
