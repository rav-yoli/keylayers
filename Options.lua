local addonName, addon = ...
local tr = addon.Translate
local function minimapSettings(layout, previous)
    if not layout.minimapIcon then
        if layout.minimapAngle then
            layout.minimapIcon = {minimapPos = math.deg(layout.minimapAngle) % 360}
        else
            layout.minimapIcon = previous and addon.Copy(previous) or {minimapPos = 245}
        end
    end
    return layout.minimapIcon
end
local labels = {
    base = tr("Base", "Base"), ctrl = tr("Ctrl", "Ctrl"), maj = tr("Maj", "Shift"), alt = "Alt",
    always = tr("Toujours", "Always"), never = tr("Aucun", "None"),
}
function addon.LayerLabel(layer)
    if layer == "unmodified" then return labels.base end
    if labels[layer] then return labels[layer] end
    local keys = {}
    for key in layer:gmatch("[^+]+") do keys[#keys + 1] = labels[key] end
    return table.concat(keys, " + ")
end

local function label(parent, value, x, y, font)
    local item = parent:CreateFontString(nil, "OVERLAY", font or "GameFontNormal")
    item:SetPoint("TOPLEFT", x, y)
    item:SetText(value)
    return item
end

local function section(parent, title, top, height)
    local bg = parent:CreateTexture(nil, "BACKGROUND")
    bg:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, top)
    bg:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, top)
    bg:SetHeight(height)
    bg:SetColorTexture(0.14, 0.20, 0.27, 0.46)
    label(parent, title, 18, top - 8, "GameFontNormal")
end

local function button(parent, value, x, y, width, callback)
    local item = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    item:SetSize(width, 24)
    item:SetPoint("TOPLEFT", x, y)
    item:SetText(value)
    item:SetScript("OnClick", callback)
    return item
end

local function tab(parent, value, x, y, width, callback)
    local item = CreateFrame("Button", nil, parent)
    item:SetSize(width, 29)
    item:SetPoint("TOPLEFT", x, y)
    item:SetNormalFontObject("GameFontHighlight")
    item:SetHighlightFontObject("GameFontHighlight")
    item:SetDisabledFontObject("GameFontDisable")
    local caption = item:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    caption:SetPoint("CENTER", 0, 1)
    item:SetFontString(caption)
    item:SetText(value)
    item:SetScript("OnClick", callback)

    local background = item:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    local marker = item:CreateTexture(nil, "ARTWORK")
    marker:SetPoint("BOTTOMLEFT")
    marker:SetPoint("BOTTOMRIGHT")
    marker:SetHeight(3)
    marker:SetColorTexture(0.17, 0.84, 0.91, 1)
    local hover = item:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints()
    hover:SetColorTexture(0.60, 0.80, 0.92, 0.14)

    local function showState(active, enabled)
        item:SetEnabled(enabled)
        marker:SetShown(active and enabled)
        if active and enabled then
            background:SetColorTexture(0.16, 0.33, 0.42, 1)
        elseif enabled then
            background:SetColorTexture(0.10, 0.15, 0.21, 1)
        else
            background:SetColorTexture(0.07, 0.10, 0.14, 1)
        end
    end
    return showState
end

local function field(parent, title, x, y, width, limit)
    local caption = label(parent, title, x, y)
    local item = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    item:SetSize(width, 23)
    item:SetPoint("TOPLEFT", x + 5, y - 16)
    item:SetAutoFocus(false)
    item:SetMaxLetters(limit or 48)
    item:SetScript("OnEnterPressed", item.ClearFocus)
    item:SetScript("OnEscapePressed", item.ClearFocus)
    return item, caption
end

local function check(parent, title, x, y, callback)
    local item = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    item:SetSize(24, 24)
    item:SetPoint("TOPLEFT", x, y)
    local caption = label(item, title, 25, -6, "GameFontHighlightSmall")
    item:SetHitRectInsets(0, -caption:GetStringWidth(), 0, 0)
    item:SetScript("OnClick", function(self) callback(not not self:GetChecked()) end)
    return item, caption
end

local function menu(parent, x, y, width, build)
    local item = CreateFrame("DropdownButton", nil, parent, "WowStyle2DropdownTemplate")
    item:SetPoint("TOPLEFT", x, y)
    item:SetWidth(width)
    item:SetupMenu(function(_, root) build(root) end)
    return item
end

local function copyIcon(control, x, y)
    for index, shade in ipairs({0.45, 0.75}) do
        local offset = (index - 1) * 4
        local page = control:CreateTexture(nil, "OVERLAY")
        page:SetPoint("TOPLEFT", control, "TOPLEFT", x + offset, y - offset)
        page:SetSize(10, 12)
        page:SetColorTexture(shade, shade + 0.07, shade + 0.13, 1)
    end
end

local function radio(root, caption, value, current, select)
    return root:CreateRadio(caption, function() return current() == value end,
        function() select(value) end)
end

local function confirm(message, accept, cancel)
    StaticPopupDialogs.BARTENDERGLOW_CONFIRM = {
        text = "%s", button1 = ACCEPT, button2 = CANCEL, timeout = 0,
        whileDead = true, hideOnEscape = true,
        OnAccept = function(dialog, action) action.accept(dialog) end,
        OnCancel = function(_, action) if action.cancel then action.cancel() end end,
    }
    StaticPopup_Show("BARTENDERGLOW_CONFIRM", message, nil, {accept = accept, cancel = cancel})
end

local function sameSettings(left, right)
    if left == right then return true end
    if type(left) ~= "table" or type(right) ~= "table" then return false end
    for key, value in pairs(left) do
        if not sameSettings(value, right[key]) then return false end
    end
    for key in pairs(right) do
        if left[key] == nil then return false end
    end
    return true
end

local fields = {
    {"x", "X", "X", -10000, 10000}, {"y", "Y", "Y", -10000, 10000},
    {"width", "Largeur", "Width", 1, 10000}, {"height", "Hauteur", "Height", 1, 10000},
    {"padding", "Marge", "Padding", 0, 200},
    {"fill", "Fond (hex)", "Fill (hex)"},
    {"fillAlpha", "Opacité fond", "Fill opacity", 0, 100, 100},
    {"border", "Bordure (hex)", "Border (hex)"},
    {"borderAlpha", "Opacité bordure", "Border opacity", 0, 100, 100},
    {"thickness", "Épaisseur", "Thickness", 0, 32},
    {"depth", "Niveau", "Level", 0, 32},
    {"linger", "Rémanence (s)", "Hold (s)", 0, 30},
    {"fade", "Fondu (s)", "Fade (s)", 0, 30},
}

local function clean(value)
    return (value:gsub("|", ""):match("^%s*(.-)%s*$"))
end

local function defaultProfileName()
    local full = GetUnitName and GetUnitName("player")
    if full and full:find(" ", 1, true) then return full end
    local name, surname = UnitFullName("player")
    if name and surname and surname ~= "" and not name:find(" ", 1, true) then
        return name .. " " .. surname
    end
    return full or name or UnitName("player")
end

local function buildWindow()
    local window = CreateFrame("Frame", "BartenderGlowWindow", UIParent, "BackdropTemplate")
    window:SetSize(680, 755)
    window:SetScale(math.min(1, (UIParent:GetWidth() - 32) / 680, (UIParent:GetHeight() - 32) / 755))
    window:SetPoint("CENTER")
    window:SetFrameStrata("DIALOG")
    window:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1})
    window:SetBackdropColor(0.055, 0.075, 0.10, 0.98)
    window:SetBackdropBorderColor(0.29, 0.42, 0.54, 1)
    window:SetMovable(true)
    window:SetClampedToScreen(true)
    window:EnableMouse(true)
    local header = CreateFrame("Frame", nil, window)
    header:SetPoint("TOPLEFT")
    header:SetPoint("TOPRIGHT", -36, 0)
    header:SetHeight(34)
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    local placedForEditing, moving
    local function stopMoving()
        if not moving then return end
        moving = false
        window:StopMovingOrSizing()
    end
    header:SetScript("OnDragStart", function()
        moving, placedForEditing = true, true
        window:StartMoving()
    end)
    header:SetScript("OnDragStop", stopMoving)
    header:SetScript("OnHide", stopMoving)
    local strip = window:CreateTexture(nil, "BACKGROUND", nil, 1)
    strip:SetPoint("TOPLEFT", 1, -1)
    strip:SetPoint("TOPRIGHT", -1, -1)
    strip:SetHeight(34)
    strip:SetColorTexture(0.15, 0.21, 0.28, 0.95)
    label(header, "KeyLayers", 18, -10, "GameFontNormalLarge")
    local credit = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    credit:SetPoint("RIGHT", -9, 0)
    credit:SetText("by Rav Yoli  ·  v" .. addon.version)
    local close = CreateFrame("Button", nil, window, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)


    local config = CreateFrame("Frame", nil, window)
    config:SetPoint("TOPLEFT", 0, -70)
    config:SetPoint("BOTTOMRIGHT")
    local profiles = CreateFrame("Frame", nil, window)
    profiles:SetAllPoints(config)
    profiles:Hide()
    local assignment = CreateFrame("Frame", nil, window)
    assignment:SetAllPoints(config)
    assignment:Hide()
    local notes = CreateFrame("Frame", nil, window)
    notes:SetAllPoints(config)
    notes:Hide()
    local status = label(window, "", 18, -725, "GameFontHighlightSmall")
    status:SetPoint("RIGHT", window, "RIGHT", -18, 0)
    status:SetJustifyH("LEFT")
    local function notify(message) status:SetText(message or "") end

    local selected, draft, profile
    local refresh, pick, setEditing, closeHints, openActivation, closeActivation, cancelShortcutCapture
    local updateHeading, requestPick, leaveDraft
    local ui = {}
    local pendingToggleKey
    local stopFrameCapture = function() end
    local editing, inactive = false, false
    local keybinds
    local function defaultStyle(panel, write)
        if panel.inactiveStyle then return panel.inactiveStyle end
        if panel.useDefaultStyle then return panel end

        -- Legacy frames can have a separate activated style with a transparent default.
        local style = {}
        addon.CopyStyle(panel, style)
        style.fillAlpha, style.borderAlpha = 0, 0
        if write then panel.inactiveStyle = style end
        return style
    end
    local function layout() return KeyLayersCharLayout end
    local function refreshPreview()
        local panel = window:IsShown() and config:IsShown() and draft or nil
        addon.SetDraftPreview(selected, panel, inactive, pendingToggleKey,
            panel and inactive and not panel.inactiveStyle and defaultStyle(panel) or nil)
        if updateHeading then updateHeading() end
        if ui.updateHint and draft then ui.updateHint() end
    end
    local tabStates = {}
    local function selectTabNow(page)
        if page == assignment and InCombatLockdown() then
            notify(tr("Mode Édition indisponible en combat.", "Edit mode is unavailable in combat."))
            return
        end
        closeHints()
        closeActivation()
        if page == assignment and not editing then
            setEditing(true)
        elseif page ~= config and page ~= assignment and editing then
            setEditing(false)
        end
        config:SetShown(page == config)
        profiles:SetShown(page == profiles)
        assignment:SetShown(page == assignment)
        notes:SetShown(page == notes)
        status:SetShown(page == config or page == profiles)
        for target, showState in pairs(tabStates) do showState(target == page, true) end
        notify()
        if page == assignment then
            if not keybinds then
                keybinds = addon.CreateKeybindingAssistant(assignment,
                    {label = label, button = button, menu = menu, radio = radio, tab = tab, check = check}, window)
            end
            if not keybinds:IsShown() then keybinds:Open() end
        elseif keybinds then
            keybinds:Hide()
        end
        refreshPreview()
    end
    local function selectTab(page)
        if page == config and config:IsShown() then return end
        if page == assignment and InCombatLockdown() then
            notify(tr("Mode Édition indisponible en combat.", "Edit mode is unavailable in combat."))
            return
        end
        leaveDraft(function() selectTabNow(page) end)
    end
    local tabDivider = window:CreateTexture(nil, "BACKGROUND")
    tabDivider:SetPoint("TOPLEFT", 10, -68)
    tabDivider:SetPoint("TOPRIGHT", -10, -68)
    tabDivider:SetHeight(1)
    tabDivider:SetColorTexture(0.29, 0.42, 0.54, 0.8)
    tabStates[config] = tab(window, tr("Configuration", "Settings"), 18, -39, 111, function() selectTab(config) end)
    tabStates[profiles] = tab(window, tr("Profils", "Profiles"), 133, -39, 75, function() selectTab(profiles) end)
    tabStates[assignment] = tab(window, tr("Assigner les raccourcis", "Assign keybindings"), 212, -39, 151,
        function() selectTab(assignment) end)
    tabStates[notes] = tab(window, tr("Notes de version", "Release notes"), 367, -39, 135, function() selectTab(notes) end)
    for page, showState in pairs(tabStates) do showState(page == config, true) end

    local editToggle = button(window, tr("Mode Édition", "Edit mode"), 510, -39, 152, function()
        if editing then
            leaveDraft(function()
                setEditing(false)
                if assignment:IsShown() then selectTabNow(config) end
            end)
        else
            setEditing(true)
        end
    end)

    label(notes, tr("Notes de version", "Release notes"), 18, -17, "GameFontNormalLarge")
    local releaseScroll = CreateFrame("ScrollFrame", nil, notes, "UIPanelScrollFrameTemplate")
    releaseScroll:SetPoint("TOPLEFT", 18, -54)
    releaseScroll:SetPoint("BOTTOMRIGHT", -34, 130)
    local releaseContent = CreateFrame("Frame", nil, releaseScroll)
    releaseContent:SetWidth(618)
    releaseContent:SetHeight(1)
    releaseScroll:SetScrollChild(releaseContent)
    local entries = {}
    for index, entry in ipairs(addon.releaseHistory) do
        entries[index] = ("|cffffd100%s|r\n%s"):format(entry[1], entry[2])
    end
    local releaseText = label(releaseContent, table.concat(entries, "\n\n"), 0, 0, "GameFontHighlight")
    releaseText:SetWidth(618)
    releaseText:SetJustifyH("LEFT")
    releaseText:SetWordWrap(true)
    notes:SetScript("OnShow", function()
        releaseContent:SetHeight(math.max(1, math.ceil(releaseText:GetStringHeight()) + 8))
        releaseScroll:UpdateScrollChildRect()
        releaseScroll:SetVerticalScroll(0)
        if releaseScroll.ScrollBar then
            releaseScroll.ScrollBar:SetShown(releaseScroll:GetVerticalScrollRange() > 0)
        end
    end)
    local issueURL = "https://legacy.curseforge.com/wow/addons/keylayers-by-rav-yoli/issues"
    local issueField, issueLabel = field(notes,
        tr("Copie ce lien avec Ctrl+C, puis ouvre-le dans ton navigateur.",
            "Copy this link with Ctrl+C and open it in your browser."), 18, -607, 628, #issueURL)
    issueField:SetScript("OnTextChanged", function(self)
        if self:GetText() ~= issueURL then self:SetText(issueURL) end
    end)
    issueField:SetText(issueURL)
    issueField:Hide()
    issueLabel:Hide()
    notes:SetScript("OnHide", function() issueField:ClearFocus() end)
    button(notes, tr("Signaler un problème", "Report an issue"), 18, -568, 220, function()
        issueLabel:Show()
        issueField:Show()
        issueField:SetFocus()
        issueField:HighlightText()
    end)

    button(config, tr("Déclencheurs globaux", "Global triggers"), 18, -4, 173, function()
        leaveDraft(function() openActivation() end)
    end)
    local altWarning = label(config, tr("Alt + F4 à éviter (ferme le jeu)", "Avoid Alt + F4 (closes the game)"),
        506, -7, "GameFontHighlightSmall")
    altWarning:SetWidth(156)
    altWarning:SetJustifyH("LEFT")
    altWarning:SetWordWrap(true)
    section(config, tr("Cadre en cours d’édition", "Frame being edited"), -31, 86)
    local currentName = label(config, "", 18, -57, "GameFontNormalLarge")
    currentName:SetWidth(325)
    currentName:SetJustifyH("LEFT")
    currentName:SetWordWrap(false)
    local currentDetails = label(config, "", 18, -79, "GameFontHighlightSmall")
    currentDetails:SetWidth(325)
    currentDetails:SetJustifyH("LEFT")
    currentDetails:SetWordWrap(false)
    local draftStatus = label(config, "", 18, -98, "GameFontNormalSmall")
    local hoveredIndex
    local function clearFrameHover()
        hoveredIndex = nil
        addon.SetHoveredPanel(nil)
    end
    local panels = menu(config, 348, -54, 156, function(root)
        for index, panel in ipairs(layout().panels) do
            local entry = radio(root, panel.name, index, function() return selected end, function(value)
                clearFrameHover()
                requestPick(value)
            end)
            entry:SetOnEnter(function()
                hoveredIndex = index
                addon.SetHoveredPanel(index == selected and draft or panel)
            end)
            entry:SetOnLeave(function()
                if hoveredIndex == index then clearFrameHover() end
            end)
        end
    end)
    panels:RegisterCallback("OnMenuClose", clearFrameHover)
    panels:HookScript("OnHide", clearFrameHover)
    local function makeDraft(actionBars)
        if not editing then setEditing(true) end
        local panel = addon.NewPanel(tr("Nouveau cadre", "New frame"))
        panel.layer = "always"
        if actionBars then
            local loaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
            panel.kind = loaded and loaded("Bartender4") and "bars" or "blizzard"
        end
        if editing then
            local space = UIParent:GetWidth() - window:GetWidth() * window:GetScale()
            panel.x = math.floor((space - UIParent:GetWidth()) / 2)
        end
        return panel
    end
    ui.newFrame = menu(config, 512, -54, 147, function(root)
        root:CreateButton(tr("Mettre en évidence des barres d’action", "Highlight action bars"), function()
            leaveDraft(function() pick(nil, makeDraft(true)) end)
        end)
        root:CreateButton(tr("Décorer un élément de l’interface", "Decorate a UI element"), function()
            leaveDraft(function() pick(nil, makeDraft(false)) end)
        end)
    end)
    ui.newFrame:OverrideText(tr("Nouveau cadre", "New frame"))

    ui.form = CreateFrame("ScrollFrame", nil, config, "UIPanelScrollFrameTemplate")
    ui.form:SetPoint("TOPLEFT", 0, -126)
    ui.form:SetPoint("BOTTOMRIGHT", -30, 69)
    local editor = CreateFrame("Frame", nil, ui.form)
    editor:SetSize(650, 1)
    ui.form:SetScrollChild(editor)
    ui.form:EnableMouseWheel(true)
    ui.form:SetScript("OnMouseWheel", function(self, delta)
        local target = self:GetVerticalScroll() - delta * 32
        self:SetVerticalScroll(math.max(0, math.min(self:GetVerticalScrollRange(), target)))
    end)
    ui.empty = label(config, tr("Crée un cadre pour commencer.", "Create a frame to get started."),
        18, -141, "GameFontHighlight")
    ui.footer = CreateFrame("Frame", nil, config)
    ui.footer:SetPoint("BOTTOMLEFT", 0, 32)
    ui.footer:SetPoint("BOTTOMRIGHT", 0, 32)
    ui.footer:SetHeight(36)
    local footerDivider = ui.footer:CreateTexture(nil, "ARTWORK")
    footerDivider:SetPoint("TOPLEFT", 10, 0)
    footerDivider:SetPoint("TOPRIGHT", -10, 0)
    footerDivider:SetHeight(1)
    footerDivider:SetColorTexture(0.29, 0.42, 0.54, 0.8)
    ui.groups = {}
    local function group(title, height, collapsed, parent, rows)
        rows = rows or ui.groups
        local block = CreateFrame("Frame", nil, parent or editor)
        block:SetWidth(650)
        local row = {block = block, height = height, closed = collapsed}
        rows[#rows + 1] = row
        if collapsed ~= nil then
            local border = CreateFrame("Frame", nil, block, "BackdropTemplate")
            local inset = parent and 12 or 8
            border:SetPoint("TOPLEFT", inset, 0)
            border:SetPoint("BOTTOMRIGHT", -inset, 0)
            border:SetBackdrop({edgeFile = [[Interface\Buttons\WHITE8X8]], edgeSize = 1})
            border:EnableMouse(false)
            -- The nested style panels draw above the section body.
            border:SetFrameLevel(block:GetFrameLevel() + 8)
            row.body = CreateFrame("Frame", nil, block)
            row.body:SetPoint("TOPLEFT", 0, -32)
            row.body:SetPoint("BOTTOMRIGHT")
            local disclosure = CreateFrame("Button", nil, block)
            disclosure:SetPoint("TOPLEFT", parent and 22 or 10, 0)
            disclosure:SetPoint("TOPRIGHT", parent and -16 or -10, 0)
            disclosure:SetHeight(30)
            local background = disclosure:CreateTexture(nil, "BACKGROUND")
            background:SetAllPoints()
            local hover = disclosure:CreateTexture(nil, "HIGHLIGHT")
            hover:SetAllPoints()
            hover:SetColorTexture(0.48, 0.72, 0.88, 0.13)
            local caption = label(disclosure, title, 32, -8, "GameFontHighlight")
            caption:SetPoint("RIGHT", -12, 0)
            caption:SetJustifyH("LEFT")
            local upper, lower = disclosure:CreateLine(nil, "ARTWORK"), disclosure:CreateLine(nil, "ARTWORK")
            for _, line in ipairs({upper, lower}) do
                line:SetThickness(2)
                line:SetColorTexture(0.54, 0.83, 0.96, 1)
            end
            local function updateDisclosure()
                border:SetBackdropBorderColor(0.40, 0.57, 0.68, row.closed and 0.22 or 0.68)
                if row.closed then
                    upper:SetStartPoint("LEFT", disclosure, 13, 5)
                    upper:SetEndPoint("LEFT", disclosure, 18, 0)
                    lower:SetStartPoint("LEFT", disclosure, 18, 0)
                    lower:SetEndPoint("LEFT", disclosure, 13, -5)
                    background:SetColorTexture(0.13, 0.20, 0.28, 1)
                else
                    upper:SetStartPoint("LEFT", disclosure, 11, 3)
                    upper:SetEndPoint("LEFT", disclosure, 16, -2)
                    lower:SetStartPoint("LEFT", disclosure, 16, -2)
                    lower:SetEndPoint("LEFT", disclosure, 21, 3)
                    background:SetColorTexture(0.16, 0.32, 0.40, 1)
                end
            end
            updateDisclosure()
            disclosure:SetScript("OnClick", function()
                row.closed = not row.closed
                updateDisclosure()
                ui.reflow()
            end)
        else
            row.body = block
            section(block, title, 0, height)
        end
        return row.body, row
    end
    local function placeGroups(parent, rows, y)
        for _, row in ipairs(rows) do
            row.block:ClearAllPoints()
            row.block:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -y)
            row.block:SetHeight(row.closed and 30 or row.height)
            if row.body ~= row.block then row.body:SetShown(not row.closed) end
            if row.block:IsShown() then y = y + row.block:GetHeight() + 6 end
        end
        return y
    end
    ui.reflow = function()
        ui.appearanceRow.height = placeGroups(ui.appearance, ui.styleGroups, 111) + 4
        editor:SetHeight(math.max(1, placeGroups(editor, ui.groups, 0)))
        ui.form:UpdateScrollChildRect()
        local range = ui.form:GetVerticalScrollRange()
        ui.form:SetVerticalScroll(math.min(ui.form:GetVerticalScroll(), range))
    end
    ui.target = group(tr("Quoi encadrer ?", "What should the frame surround?"), 166)
    ui.geometry, ui.geometryRow = group(tr("Position et dimensions", "Position and size"), 86, true)
    ui.activation = group(tr("Quand l’afficher ?", "When should it appear?"), 146)
    ui.appearance, ui.appearanceRow = group(tr("Apparence", "Appearance"), 103)
    local appearanceBackground = ui.appearance:CreateTexture(nil, "BACKGROUND", nil, -1)
    appearanceBackground:SetPoint("TOPLEFT", 7, 0)
    appearanceBackground:SetPoint("BOTTOMRIGHT", -7, 0)
    appearanceBackground:SetColorTexture(0.10, 0.15, 0.21, 0.9)
    local appearanceRail = ui.appearance:CreateTexture(nil, "ARTWORK")
    appearanceRail:SetPoint("TOPLEFT", 7, 0)
    appearanceRail:SetPoint("BOTTOMLEFT", 7, 0)
    appearanceRail:SetWidth(2)
    appearanceRail:SetColorTexture(0.29, 0.58, 0.71, 1)
    ui.styleGroups = {}
    ui.default = group(tr("Style par défaut", "Default style"), 278, false, ui.appearance, ui.styleGroups)
    ui.styles, ui.stylesRow = group(tr("Style activé", "Activated style"), 278, true, ui.appearance, ui.styleGroups)
    ui.transition = group(tr("Transition", "Transition"), 109, true)
    ui.display = group(tr("Niveau d’affichage", "Display level"), 91, true)

    local name = field(ui.target, tr("Renommer", "Rename"), 18, -31, 290)
    local kinds = addon.kindLabels
    local function chatLabel(id)
        return tr("Tchat %d", "Chat %d"):format(id)
    end
    local kind = menu(ui.target, 340, -46, 265, function(root)
        local function current()
            return draft.kind == "chat" and draft.chatId or draft.kind
        end
        local function selectKind(value)
            if type(value) == "number" then
                draft.kind, draft.chatId = "chat", value
            else
                draft.kind = value
            end
            refresh()
            refreshPreview()
        end
        radio(root, kinds.free, "free", current, selectKind)
        for _, key in ipairs(addon.linkedKinds) do
            radio(root, kinds[key], key, current, selectKind)
        end
        for id = 1, math.max(NUM_CHAT_WINDOWS or 10, draft.chatId or 0) do
            local name = id <= (NUM_CHAT_WINDOWS or 10) and GetChatWindowInfo and GetChatWindowInfo(id)
            local chat = _G["ChatFrame" .. id]
            if (draft.kind == "chat" and draft.chatId == id)
                or (chat and (id == 1 or (name and name ~= "") or chat:IsVisible())) then
                local title = chatLabel(id)
                if name and name ~= "" then title = title .. " · " .. clean(name) end
                radio(root, title, id, current, selectKind)
            end
        end
    end)
    label(ui.target, tr("Type de cadre", "Frame type"), 340, -31)
    label(ui.activation, tr("Touche maintenue", "Hold key"), 18, -32)
    label(ui.activation, tr("Couche à activer", "Layer to activate"), 223, -32)
    label(ui.activation, tr("Raccourci de bascule", "Toggle shortcut"), 421, -32)
    local function setFrameHold(key)
        if addon.ActivationMode(draft) == "latch" then draft.toggleLayer = draft.layer end
        draft.activationMode = key and "hold" or "none"
        draft.layer = key or "always"
        refresh()
        refreshPreview()
    end
    local function setToggleLayer(key)
        local old = addon.PanelToggle(draft)
        if old and key == addon.ToggleModifier(draft) then return end
        local oldKey = addon.PanelToggleKey(draft)
        if addon.ActivationMode(draft) == "latch" then draft.activationMode, draft.layer = "none", "always" end
        if not key then
            draft.toggleId, draft.toggleLayer, draft.toggleModifier = nil, nil, nil
            pendingToggleKey = nil
        else
            if type(old) ~= "number" then
                pendingToggleKey = oldKey
                draft.toggleId = addon.NewPanelToggleId()
            end
            draft.toggleLayer, draft.toggleModifier = nil, key
        end
        refresh()
        refreshPreview()
    end
    ui.hold = menu(ui.activation, 18, -48, 190, function(root)
        local function current() return addon.HoldLayer(draft) or false end
        radio(root, addon.PanelToggle(draft) and tr("Aucune", "None")
            or tr("Toujours visible", "Always visible"), false, current, function() setFrameHold(nil) end)
        for _, key in ipairs(addon.layers) do
            local holdKey = key == "base" and "unmodified" or key
            radio(root, addon.LayerLabel(holdKey), holdKey, current, setFrameHold)
        end
    end)
    ui.toggle = menu(ui.activation, 223, -48, 182, function(root)
        local function current() return addon.PanelToggle(draft) and addon.ToggleModifier(draft) or false end
        radio(root, tr("Aucune", "None"), false, current, function() setToggleLayer(nil) end)
        for _, key in ipairs(addon.layers) do radio(root, addon.LayerLabel(key), key, current, setToggleLayer) end
    end)
    ui.activationHelp = label(ui.activation, "", 18, -84, "GameFontHighlightSmall")
    ui.activationHelp:SetWidth(602)
    ui.activationHelp:SetJustifyH("LEFT")
    ui.activationHelp:SetWordWrap(true)
    ui.activationHelp:SetHeight(40)
    ui.capture = CreateFrame("Frame", nil, window)
    ui.capture:SetAllPoints(window)
    local function cancelFrameCapture()
        if not ui.capturing then return end
        ui.capturing = false
        ui.capture:EnableKeyboard(false)
        if draft then refresh() end
    end
    stopFrameCapture = cancelFrameCapture
    ui.toggleKey = button(ui.activation, "", 421, -48, 194, function(self, mouseButton)
        if ui.capturing then cancelFrameCapture(); notify(); return end
        if mouseButton == "RightButton" then
            pendingToggleKey = false
            refresh()
            refreshPreview()
            return
        end
        if InCombatLockdown() then
            notify(tr("Modifie les raccourcis hors combat.", "Change shortcuts out of combat."))
            return
        end
        local focus = GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()
        if focus then focus:ClearFocus() end
        ui.capturing = true
        ui.capture:EnableKeyboard(true)
        ui.capture:SetPropagateKeyboardInput(false)
        self:SetText(tr("Appuie sur une touche…", "Press a key…"))
        notify(tr("Appuie sur une touche ou sur Échap pour annuler.", "Press a key or Escape to cancel."))
    end)
    ui.toggleKey:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    ui.capture:SetScript("OnKeyDown", function(_, key)
        if not ui.capturing then return end
        if key == "ESCAPE" then cancelFrameCapture(); notify(); return end
        if key == "UNKNOWN" or key:match("^[LR]?CTRL$") or key:match("^[LR]?SHIFT$") or key:match("^[LR]?ALT$") then return end
        if key == "F4" and IsAltKeyDown() then return end
        if IsShiftKeyDown() then key = "SHIFT-" .. key end
        if IsControlKeyDown() then key = "CTRL-" .. key end
        if IsAltKeyDown() then key = "ALT-" .. key end
        pendingToggleKey = key
        cancelFrameCapture()
        refreshPreview()
        notify()
    end)
    local activationPopup = CreateFrame("Frame", nil, window, "BackdropTemplate")
    activationPopup:SetSize(605, 518)
    activationPopup:SetPoint("CENTER")
    activationPopup:SetFrameStrata("FULLSCREEN_DIALOG")
    activationPopup:EnableMouse(true)
    activationPopup:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1,
    })
    activationPopup:SetBackdropColor(0.07, 0.10, 0.14, 1)
    activationPopup:SetBackdropBorderColor(0.42, 0.56, 0.70, 1)
    activationPopup:Hide()
    closeActivation = function() activationPopup:Hide() end
    label(activationPopup, tr("Déclencheurs", "Triggers"), 16, -16, "GameFontNormalLarge")
    label(activationPopup, tr("Les changements s’appliquent immédiatement.", "Changes apply immediately."),
        16, -43, "GameFontHighlightSmall")
    label(activationPopup, tr("Maintien : surbrillance pendant l’appui, sans redirection des raccourcis.",
        "Hold: highlights while pressed, without remapping shortcuts."), 16, -60, "GameFontHighlightSmall")
    label(activationPopup, tr("Interrupteur : assigne un raccourci dédié pour verrouiller le cadre.",
        "Toggle: assign a dedicated shortcut to lock the frame."), 16, -76, "GameFontHighlightSmall")
    local activationClose = CreateFrame("Button", nil, activationPopup, "UIPanelCloseButton")
    activationClose:SetPoint("TOPRIGHT", -3, -3)
    activationClose:SetScript("OnClick", closeActivation)
    label(activationPopup, tr("Cadre", "Frame"), 17, -102)
    label(activationPopup, tr("Maintien", "Hold"), 180, -102)
    label(activationPopup, tr("Interrupteur", "Toggle"), 332, -102)
    local popupStatus = label(activationPopup, "", 16, -493, "GameFontHighlightSmall")
    popupStatus:SetWidth(570)
    popupStatus:SetJustifyH("LEFT")

    local scroll = CreateFrame("ScrollFrame", nil, activationPopup, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 14, -123)
    scroll:SetPoint("BOTTOMRIGHT", -32, 125)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetWidth(550)
    scroll:SetScrollChild(content)

    label(activationPopup, tr("Touche Neutre (Base)", "Neutral key (Base)"), 16, -416)
    local neutralHelp = label(activationPopup, "", 16, -441, "GameFontHighlightSmall")
    neutralHelp:SetWidth(570)
    neutralHelp:SetJustifyH("LEFT")
    neutralHelp:SetWordWrap(true)
    label(activationPopup, tr("Clic droit sur un raccourci pour le retirer.", "Right-click a shortcut to clear it."),
        16, -478, "GameFontHighlightSmall")
    local capture = CreateFrame("Frame", nil, activationPopup)
    capture:SetAllPoints(activationPopup)
    local captureLayer, captureControl, pressedKey, pressedShortcut, captureSave
    local neutralControl, redrawActivation, cancelCaptureButton, targetFor
    local function neutralText()
        local key = addon.NeutralKey()
        return key and (GetBindingText and GetBindingText(key) or key) or tr("Assigner…", "Assign…")
    end
    local function needsNeutralKey()
        if addon.NeutralKey() then return false end
        for index in ipairs(layout().panels) do
            if addon.PanelToggle(targetFor(index)) then return true end
        end
        return draft and not selected and addon.PanelToggle(draft)
    end
    local function refreshNeutralKey()
        neutralControl:SetText(neutralText())
        local missing = needsNeutralKey()
        neutralHelp:SetText(missing and tr(
            "Assigne une touche Neutre. En attendant, rappuie sur l’interrupteur actif pour revenir à Base.",
            "Assign a Neutral key. Until then, press the active Toggle shortcut again to return to Base.")
            or tr("La touche Neutre ramène à Base depuis n’importe quelle couche verrouillée.",
                "The Neutral key returns to Base from any locked layer."))
        if missing then neutralHelp:SetTextColor(1, 0.82, 0.36)
        else neutralHelp:SetTextColor(1, 1, 1) end
    end
    cancelShortcutCapture = function()
        if not captureLayer then return end
        captureControl:SetText(captureControl == neutralControl and neutralText() or captureControl.previousText)
        captureLayer, captureControl, pressedKey, pressedShortcut, captureSave = nil, nil, nil, nil, nil
        capture:EnableKeyboard(false)
        cancelCaptureButton:Hide()
        popupStatus:SetWidth(570)
    end
    activationPopup:SetScript("OnHide", cancelShortcutCapture)
    cancelCaptureButton = button(activationPopup, CANCEL, 453, -484, 117, function()
        cancelShortcutCapture()
        popupStatus:SetText("")
    end)
    cancelCaptureButton:Hide()

    local function shortcutClick(control, mouseButton, layer, save)
        cancelShortcutCapture()
        if InCombatLockdown() then
            popupStatus:SetText(tr("Modifie les raccourcis hors combat.", "Change shortcuts out of combat."))
            return
        end
        if mouseButton == "RightButton" then
            if addon.AssignNeutralKey(nil) then
                popupStatus:SetText(tr("Raccourci retiré.", "Shortcut cleared."))
                redrawActivation()
            end
            return
        end
        local focus = GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()
        if focus then focus:ClearFocus() end
        control.previousText = control:GetText()
        captureLayer, captureControl, captureSave = layer, control, save
        capture:EnableKeyboard(true)
        capture:SetPropagateKeyboardInput(false)
        control:SetText(tr("Appuie sur une touche…", "Press a key…"))
        popupStatus:SetWidth(423)
        popupStatus:SetText(tr("Appuie sur une touche ou clique sur Annuler.", "Press a key or click Cancel."))
        cancelCaptureButton:Show()
    end
    neutralControl = button(activationPopup, "", 270, -409, 250, function(self, mouseButton)
        shortcutClick(self, mouseButton, "base")
    end)
    neutralControl:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    local function confirmActivation(message, accept)
        closeActivation()
        local function reopen()
            if window:IsVisible() and config:IsShown() and not InCombatLockdown() then
                openActivation()
                return true
            end
        end
        confirm(message, function()
            if reopen() then accept() end
        end, reopen)
    end
    local function saveShortcut(layer, key, replace, apply, done, caption)
        local ok, reason, owner
        if apply then ok, reason, owner = apply(layer, key, replace)
        else ok, reason, owner = addon.AssignNeutralKey(key, replace) end
        cancelShortcutCapture()
        if ok then
            popupStatus:SetText(tr("Raccourci enregistré.", "Shortcut saved."))
            if done then done() else redrawActivation() end
            if layer ~= "base" and needsNeutralKey() then
                shortcutClick(neutralControl, "LeftButton", "base")
                popupStatus:SetText(tr("Saisis la touche Neutre, ou clique sur Annuler.",
                    "Press the Neutral key, or click Cancel."))
            end
        elseif reason == "occupied" then
            confirmActivation(tr(
                "%s est affecté à « %s ». Réattribuer cette touche à « %s » ?",
                "%s is assigned to “%s”. Reassign this key to “%s”?")
                :format(GetBindingText and GetBindingText(key) or key, addon.ShortcutActionLabel(owner),
                    caption or tr("Revenir au neutre", "Return to neutral")),
                function()
                    saveShortcut(layer, key, owner, apply, done, caption)
                end)
        elseif reason == "temporary" then
            popupStatus:SetText(tr("Touche temporairement utilisée par %s.", "Key temporarily used by %s.")
                :format(addon.ShortcutActionLabel(owner)))
        else
            popupStatus:SetText(reason == "combat"
                and tr("Modifie les raccourcis hors combat.", "Change shortcuts out of combat.")
                or tr("Cette touche ne peut pas être assignée.", "This key cannot be assigned."))
        end
    end
    capture:SetScript("OnKeyDown", function(_, key)
        if not captureLayer or pressedKey or key == "UNKNOWN" then return end
        if key:match("^[LR]CTRL$") or key:match("^[LR]SHIFT$") or key:match("^[LR]ALT$")
            or key == "CTRL" or key == "SHIFT" or key == "ALT" then return end
        if key == "F4" and IsAltKeyDown() then
            popupStatus:SetText(tr("Alt + F4 à éviter (ferme le jeu)", "Avoid Alt + F4 (closes the game)"))
            return
        end
        pressedKey = key
        if IsShiftKeyDown() then key = "SHIFT-" .. key end
        if IsControlKeyDown() then key = "CTRL-" .. key end
        if IsAltKeyDown() then key = "ALT-" .. key end
        pressedShortcut = key
    end)
    capture:SetScript("OnKeyUp", function(_, key)
        if captureLayer and key == pressedKey then
            local save = captureSave or saveShortcut
            save(captureLayer, pressedShortcut)
        end
    end)

    local modeLabels = {
        none = tr("Aucune", "None"),
        hold = tr("Maintien", "Hold"),
        latch = tr("Interrupteur", "Toggle"),
    }
    local rows = {}
    targetFor = function(index)
        if draft and (index == selected or index == 0) then return draft end
        return layout().panels[index]
    end
    local function setHold(index, key, approved)
        cancelShortcutCapture()
        if InCombatLockdown() then
            popupStatus:SetText(tr("Modifie les raccourcis hors combat.", "Change shortcuts out of combat."))
            return
        end
        local target = targetFor(index)
        if not target then return end
        local matches, names = {}, {}
        local function find(otherIndex)
            local other = targetFor(otherIndex)
            if otherIndex ~= index and other and addon.HoldLayer(other) == key then
                matches[otherIndex] = other
                names[#names + 1] = other.name
            end
        end
        if key and key ~= "unmodified" then
            for otherIndex in ipairs(layout().panels) do find(otherIndex) end
            if not selected then find(0) end
        end
        for otherIndex, other in pairs(matches) do
            if not approved or approved[otherIndex] ~= other then
                confirmActivation(tr(
                    "%s (%s) est utilisé par « %s ». Réserver ce déclencheur à « %s » ?",
                    "%s (%s) is used by “%s”. Assign this trigger only to “%s”?")
                    :format(addon.LayerLabel(key), modeLabels.hold, table.concat(names, ", "), target.name),
                    function()
                        if targetFor(index) == target then setHold(index, key, matches) end
                    end)
                return
            end
        end
        local function set(panel, layer)
            if addon.ActivationMode(panel) == "latch" then panel.toggleLayer = panel.layer end
            panel.activationMode, panel.layer = layer and "hold" or "none", layer or "never"
        end
        local function update(otherIndex, layer)
            local other, saved = targetFor(otherIndex), layout().panels[otherIndex]
            set(other, layer)
            if saved and saved ~= other then set(saved, layer) end
        end
        for otherIndex in pairs(matches) do update(otherIndex, nil) end
        update(index, key)
        addon.SyncSwitch(true)
        popupStatus:SetText("")
        redrawActivation()
        refresh()
        refreshPreview()
    end

    local function updateToggle(index, toggle)
        local function set(panel)
            if addon.ActivationMode(panel) == "latch" then
                panel.activationMode, panel.layer = "none", "never"
            end
            panel.toggleId = type(toggle) == "number" and toggle or nil
            panel.toggleLayer = type(toggle) == "string" and toggle or nil
            if not toggle then panel.toggleModifier = nil end
        end
        local target, saved = targetFor(index), layout().panels[index]
        set(target)
        if saved and saved ~= target then set(saved) end
        addon.SyncSwitch(true)
        addon.RememberFrameToggleKeys()
        redrawActivation()
        refresh()
        refreshPreview()
    end

    local function captureToggle(row)
        local index, target = row.index, targetFor(row.index)
        shortcutClick(row.shortcut, "LeftButton", true, function(_, key)
            cancelShortcutCapture()
            if targetFor(index) ~= target then return end
            local toggle = addon.PanelToggle(target)
            -- Base's reset shortcut is shared; a frame toggle is its own action.
            if not toggle or toggle == "base" then toggle = addon.NewPanelToggleId() end
            saveShortcut(toggle, key, nil, function(id, shortcut, replace)
                local current = targetFor(index)
                if current ~= target then return false, "invalid" end
                return addon.AssignPanelToggleKey(target, id, shortcut, replace)
            end, function() updateToggle(index, toggle) end,
                tr("Verrouiller %s", "Toggle %s"):format(target.name))
        end)
    end
    local function buildHoldMenu(root, row)
        if not activationPopup:IsShown() then return end
        local function current() return addon.HoldLayer(targetFor(row.index)) or "never" end
        radio(root, modeLabels.none, "never", current, function() setHold(row.index, nil) end)
        for _, layer in ipairs(addon.layers) do
            local key = layer == "base" and "unmodified" or layer
            radio(root, addon.LayerLabel(key), key, current, function() setHold(row.index, key) end)
        end
    end

    local function makeActivationRow(position)
        local row = CreateFrame("Frame", nil, content)
        row:SetSize(550, 32)
        row:SetPoint("TOPLEFT", 0, -(position - 1) * 32)
        row.caption = label(row, "", 3, -8, "GameFontHighlight")
        row.caption:SetWidth(150)
        row.caption:SetJustifyH("LEFT")
        row.caption:SetWordWrap(false)
        row.hold = menu(row, 165, -2, 139, function(root) buildHoldMenu(root, row) end)
        row.shortcut = button(row, "", 317, -3, 229, function(_, mouseButton)
            if mouseButton ~= "RightButton" then
                captureToggle(row)
                return
            end
            cancelShortcutCapture()
            if InCombatLockdown() then
                popupStatus:SetText(tr("Modifie les raccourcis hors combat.", "Change shortcuts out of combat."))
                return
            end
            local target = targetFor(row.index)
            local toggle = addon.PanelToggle(target)
            if not toggle then return end
            if toggle == "base" or addon.AssignPanelToggleKey(target, toggle, nil) then
                updateToggle(row.index, nil)
                popupStatus:SetText(tr("Raccourci retiré.", "Shortcut cleared."))
            end
        end)
        row.shortcut:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        return row
    end
    redrawActivation = function()
        local count = #layout().panels
        local showDraft = draft and not selected
        local total = count + (showDraft and 1 or 0)
        for position = 1, total do
            local row = rows[position]
            if not row then row = makeActivationRow(position); rows[position] = row end
            row.index = position > count and 0 or position
            local target = targetFor(row.index)
            local hold, key = addon.HoldLayer(target), addon.PanelToggleKey(target)
            row.caption:SetText(target.name)
            row.hold:OverrideText(hold and addon.LayerLabel(hold) or "—")
            row.shortcut:SetText(key and (GetBindingText and GetBindingText(key) or key)
                or tr("Assigner…", "Assign…"))
            row:Show()
        end
        for position = total + 1, #rows do rows[position]:Hide() end
        content:SetHeight(math.max(1, total * 32))
        refreshNeutralKey()
        if total == 0 then popupStatus:SetText(tr("Crée un cadre pour commencer.", "Create a frame to get started.")) end
    end
    openActivation = function()
        stopFrameCapture()
        popupStatus:SetText("")
        closeHints()
        activationPopup:Show()
        redrawActivation()
    end

    local hintPopup = CreateFrame("Frame", nil, window, "BackdropTemplate")
    hintPopup:SetSize(380, 302)
    hintPopup:SetPoint("CENTER")
    hintPopup:SetFrameStrata("FULLSCREEN_DIALOG")
    hintPopup:EnableMouse(true)
    hintPopup:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1,
    })
    hintPopup:SetBackdropColor(0.07, 0.10, 0.14, 1)
    hintPopup:SetBackdropBorderColor(0.42, 0.56, 0.70, 1)
    hintPopup:Hide()
    closeHints = function() hintPopup:Hide() end
    local heading = label(hintPopup, "", 16, -15, "GameFontNormalLarge")
    local description = label(hintPopup, tr(
        "L’onglet indique sur quelle touche appuyer pour activer le cadre.",
        "The tab shows which key to press to activate the frame."),
        16, -40, "GameFontHighlightSmall")
    description:SetWidth(348)
    description:SetJustifyH("LEFT")
    description:SetWordWrap(true)
    local close = CreateFrame("Button", nil, hintPopup, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -3, -3)
    close:SetScript("OnClick", closeHints)
    local globalScope, refreshHints
    local function settings()
        return globalScope and addon.GlobalHints() or addon.HintSettings(draft)
    end
    local function canEditHints()
        return globalScope or addon.HasHintOverride(draft)
    end
    local function setHint(key, value)
        if not canEditHints() then return end
        settings()[key] = value
        refreshHints()
        if globalScope then notify(tr("Les changements s’appliquent immédiatement.", "Changes apply immediately.")) end
        refreshPreview()
    end
    local inherited = check(hintPopup, tr("Remplacer les réglages globaux", "Override global settings"), 16, -77, function(value)
        if value then
            local global = addon.GlobalHints()
            draft.hint, draft.hintSide, draft.hintOrientation = global.hint, global.hintSide, global.hintOrientation
        end
        draft.hintOverride = value
        refreshHints()
        refreshPreview()
    end)
    local hint = check(hintPopup, tr("Afficher l’onglet", "Show tab"), 16, -108, function(value)
        if globalScope then
            setHint("hint", value)
        else
            draft.hintVisible = value
            refreshHints()
            refreshPreview()
        end
    end)
    local orientations = {
        {"horizontal", tr("Horizontal", "Horizontal")}, {"vertical", tr("Vertical", "Vertical")},
    }
    local function orientationValue() return settings().hintOrientation or "horizontal" end
    local orientation = menu(hintPopup, 192, -109, 170, function(root)
        if not hintPopup:IsShown() then return end
        for _, choice in ipairs(orientations) do
            radio(root, choice[2], choice[1], orientationValue, function(value)
                setHint("hintOrientation", value)
            end)
        end
    end)
    label(hintPopup, tr("Placer l’onglet", "Place tab"), 16, -143)
    local diagram = hintPopup:CreateTexture(nil, "ARTWORK")
    diagram:SetPoint("TOPLEFT", 126, -190)
    diagram:SetSize(120, 59)
    diagram:SetColorTexture(0.23, 0.31, 0.40, 1)
    local markers = {
        {"top-start", 126, -166}, {"top", 176, -166}, {"top-end", 226, -166},
        {"left-start", 99, -180}, {"left", 99, -210}, {"left-end", 99, -239},
        {"right-start", 253, -180}, {"right", 253, -210}, {"right-end", 253, -239},
        {"bottom-start", 126, -258}, {"bottom", 176, -258}, {"bottom-end", 226, -258},
    }
    for _, marker in ipairs(markers) do
        marker.control = button(hintPopup, "•", marker[2], marker[3], 20, function()
            setHint("hintSide", marker[1])
        end)
        marker.control:SetHeight(19)
    end
    refreshHints = function()
        local current, editable = settings(), canEditHints()
        inherited:SetShown(not globalScope)
        inherited:SetChecked(not globalScope and editable)
        if globalScope then
            hint:SetChecked(current.hint)
            hint:SetEnabled(true)
        else
            hint:SetChecked(addon.GlobalHints().hint and addon.HintVisibleForFrame(draft))
            hint:SetEnabled(not not addon.GlobalHints().hint)
        end
        orientation:SetEnabled(editable)
        orientation:OverrideText(orientationValue() == "vertical" and orientations[2][2] or orientations[1][2])
        local side = current.hintSide or "top-start"
        if side == "legacy" then side = "top-start" end
        for _, marker in ipairs(markers) do
            marker.control:SetText(side == marker[1] and "●" or "•")
            marker.control:SetEnabled(editable)
        end
    end
    local function openHints(global)
        stopFrameCapture()
        globalScope = global
        heading:SetText(global and tr("Apprentissage global", "Global learning settings")
            or tr("Apprentissage du cadre", "Frame learning settings"))
        refreshHints()
        hintPopup:Show()
    end
    button(config, tr("Étiquettes globales", "Global key labels"), 200, -4, 202, function() openHints(true) end)
    ui.keyLabel = check(ui.appearance, tr("Afficher l’étiquette de touche", "Show key label"), 18, -35, function(value)
        draft.hintVisible = value
        refreshPreview()
    end)
    ui.updateHint = function() ui.keyLabel:SetChecked(not not addon.HintVisibleForFrame(draft))
        ui.keyLabel:SetEnabled(not not addon.GlobalHints().hint) end
    button(ui.appearance, tr("Réglages de l’étiquette…", "Key label settings…"), 312, -35, 245, function() openHints(false) end)

    local barGroup = CreateFrame("Frame", nil, ui.target)
    barGroup:SetAllPoints(ui.target)
    ui.barSummary = label(barGroup, "", 18, -84, "GameFontHighlight")
    ui.barSummary:SetWidth(575)
    ui.barSummary:SetJustifyH("LEFT")
    ui.barSummary:SetWordWrap(false)
    button(barGroup, tr("Sélectionner en jeu", "Select in game"), 414, -125, 200, function()
        if not editing then setEditing(true) end
    end)
    label(barGroup, tr("En édition, clique aussi sur les numéros au-dessus des barres.", "In edit mode, you can also click the numbers over the bars."),
        18, -134, "GameFontHighlightSmall")
    local barChecks, barCaptions = {}, {}
    for id = 1, 15 do
        barChecks[id], barCaptions[id] = check(barGroup, tostring(id), 18 + (id - 1) * 40, -102, function(value)
            addon.BarSelection(draft)[id] = value or nil
            refresh()
            refreshPreview()
        end)
        barChecks[id]:SetScript("OnEnter", function(self)
            local _, name = addon.BarLabel(draft.kind, id)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(name)
            GameTooltip:Show()
        end)
        barChecks[id]:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end

    local linkedHelp = label(ui.target, "", 18, -90)
    linkedHelp:SetWidth(600)
    linkedHelp:SetJustifyH("LEFT")
    linkedHelp:SetWordWrap(true)
    ui.moveFrame = button(ui.target, tr("Déplacer en jeu", "Move in game"), 18, -119, 195, function()
        if not editing then setEditing(true) end
    end)
    local freeGroup = ui.geometry
    local inputs, specifications = {}, {}
    for _, spec in ipairs(fields) do specifications[spec[1]] = spec end

    local function parseField(raw, spec)
        raw = clean(raw)
        if spec[4] then
            local number = tonumber((raw:gsub(",", ".")))
            if number and number >= spec[4] and number <= spec[5] then
                local value = number / (spec[6] or 1)
                return spec[1] == "depth" and math.floor(value) or value
            end
        else
            raw = raw:gsub("^#", "")
            if #raw == 6 and raw:match("^%x+$") then return raw:upper() end
        end
    end

    local function bindNumberOrColor(parent, key, x, y, width, activeStyle, isStyle)
        local spec = specifications[key]
        local input, caption = field(parent, tr(spec[2], spec[3]), x, y, width, 9)
        local function resolveStyle(panel, write)
            if not isStyle or activeStyle then return panel end
            return defaultStyle(panel, write)
        end
        local control = {input = input, spec = spec, show = function()
            return not activeStyle or not draft.useDefaultStyle
        end, activeStyle = activeStyle}
        inputs[#inputs + 1] = control

        local function updatePreview(value)
            resolveStyle(draft, true)[key] = value
            if isStyle then inactive = not activeStyle end
            if control.refresh then control.refresh() end
            refreshPreview()
        end
        local function set(value)
            input:SetText(tostring(value * (spec[6] or 1)))
            updatePreview(value)
        end
        input:SetScript("OnTextChanged", function(_, userInput)
            if not userInput or not draft then return end
            local value = parseField(input:GetText(), spec)
            if value == nil then updateHeading(); return end
            updatePreview(value)
        end)
        function control.load()
            local value = resolveStyle(draft)[key]
            if spec[6] then value = value * spec[6] end
            input:SetText(tostring(value))
            if control.refresh then control.refresh() end
        end
        return control, caption, set, updatePreview
    end

    local geometryInputs = {}
    for index = 1, 4 do
        local spec = fields[index]
        local key, x = spec[1], 18 + (index - 1) * 159
        local control, _, set = bindNumberOrColor(freeGroup, key, x + 22, -9, 58)
        geometryInputs[index] = control.input
        local function step(delta)
            set(math.max(spec[4], math.min(spec[5], draft[key] + delta)))
        end
        button(freeGroup, "−", x, -24, 24, function() step(-1) end)
        button(freeGroup, "+", x + 88, -24, 24, function() step(1) end)
        local title = tr(spec[2], spec[3])
        local copy = menu(freeGroup, x + 118, -24, 24, function(root)
            local found = false
            for sourceIndex, source in ipairs(layout().panels) do
                if sourceIndex ~= selected then
                    local geometry = addon.GetPanelGeometry(source)
                    local value = geometry and geometry[key]
                    if value and value >= spec[4] and value <= spec[5] then
                        found = true
                        root:CreateButton(("%s  ·  %s"):format(source.name, tostring(value)), function() set(value) end)
                    end
                end
            end
            if not found then
                root:CreateButton(tr("Aucun cadre source disponible", "No source frame available")):SetEnabled(false)
            end
        end)
        copy:SetSize(24, 24)
        copy:OverrideText(" ")
        copyIcon(copy, 5, -5)
        copy:HookScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(tr("Copier la valeur de %s", "Copy the value of %s"):format(title))
            GameTooltip:Show()
        end)
        copy:HookScript("OnLeave", function() GameTooltip:Hide() end)
    end

    local fillStyles = {
        {"solid", tr("Uni", "Solid")}, {"marble", tr("Marbre", "Marble")},
        {"stone", tr("Pierre", "Stone")}, {"parchment", tr("Parchemin", "Parchment")},
        {"dialog", tr("Dialogue", "Dialog")}, {"tooltip", tr("Infobulle", "Tooltip")},
    }
    local borderStyles = {
        {"solid", tr("Unie", "Solid")}, {"dialog", tr("Dialogue", "Dialog")},
        {"gold", tr("Dialogue doré", "Gold dialog")}, {"chat", tr("Bulle de discussion", "Chat bubble")},
        {"wood", tr("Bois", "Wood")}, {"tooltip", tr("Infobulle", "Tooltip")},
    }
    local function hexRGB(hex)
        return tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255,
            tonumber(hex:sub(5, 6), 16) / 255
    end
    local function styleEditor(parent, activeStyle)
        local function column(title, x)
            local panel = CreateFrame("Frame", nil, parent)
            panel:SetSize(301, 184)
            panel:SetPoint("TOPLEFT", x, -48)
            local background = panel:CreateTexture(nil, "BACKGROUND")
            background:SetAllPoints()
            background:SetColorTexture(0.12, 0.18, 0.24, 0.8)
            label(panel, title, 10, -9, "GameFontNormal")
            return panel
        end
        local fill = column(tr("Fond", "Fill"), 16)
        local border = column(tr("Bordure", "Border"), 333)
        local colorY, textureY = -79, -33
        local pickers = {}
        local function target(write)
            if activeStyle then return draft end
            return defaultStyle(draft, write)
        end
        local function isSolid(key)
            local available = key == "fill" and addon.fillTextures or addon.borderTextures
            return not available[target()[key .. "Texture"]]
        end
        local function colorControl(container, key, x)
            local control, caption, _, apply = bindNumberOrColor(container, key, x, colorY, 89, activeStyle, true)
            local swatch = button(container, "", x + 99, colorY - 16, 42, function()
                local owner, original = draft, target()[key]
                local red, green, blue = hexRGB(original)
                local function setHex(hex)
                    if draft ~= owner or (activeStyle and draft.useDefaultStyle) then return end
                    control.input:SetText(hex)
                    apply(hex)
                end
                ColorPickerFrame:SetupColorPickerAndShow({
                    r = red, g = green, b = blue,
                    swatchFunc = function()
                        local r, g, b = ColorPickerFrame:GetColorRGB()
                        setHex(("%02X%02X%02X"):format(math.floor(r * 255 + 0.5),
                            math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5)))
                    end,
                    cancelFunc = function() setHex(original) end,
                })
            end)
            local color = swatch:CreateTexture(nil, "ARTWORK")
            color:SetPoint("TOPLEFT", 5, -5)
            color:SetPoint("BOTTOMRIGHT", -5, 5)
            control.refresh = function()
                local r, g, b = hexRGB(target()[key])
                color:SetColorTexture(r, g, b, 1)
                local solid = isSolid(key)
                control.input:SetShown(solid)
                caption:SetShown(solid)
                swatch:SetShown(solid)
                if not solid then control.input:SetText(target()[key]) end
            end
            return control.refresh
        end
        local function sliderControl(key, parent, x, y, maximum)
            local control, caption, set = bindNumberOrColor(parent, key, x + 99, y, 38, activeStyle, true)
            caption:ClearAllPoints()
            caption:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
            local slider = CreateFrame("Slider", nil, parent)
            slider:SetOrientation("HORIZONTAL")
            slider:SetSize(89, 20)
            slider:SetPoint("TOPLEFT", parent, "TOPLEFT", x + 5, y - 17)
            slider:SetMinMaxValues(0, maximum)
            slider:SetValueStep(1)
            slider:SetObeyStepOnDrag(true)
            slider:SetThumbTexture([[Interface\Buttons\UI-SliderBar-Button-Horizontal]])
            local track = slider:CreateTexture(nil, "BACKGROUND")
            track:SetPoint("LEFT", 3, 0)
            track:SetPoint("RIGHT", -3, 0)
            track:SetHeight(4)
            track:SetColorTexture(0.34, 0.44, 0.54, 1)
            local syncing
            slider:SetScript("OnValueChanged", function(_, value)
                if not syncing and draft then set(math.floor(value + 0.5) / (control.spec[6] or 1)) end
            end)
            control.refresh = function()
                local visible = key ~= "thickness" or isSolid("border")
                control.input:SetShown(visible)
                caption:SetShown(visible)
                slider:SetShown(visible)
                if not visible then control.input:SetText(tostring(target()[key])) end
                syncing = true
                slider:SetValue(target()[key] * (control.spec[6] or 1))
                syncing = false
            end
            return control.refresh
        end
        local refreshFill = colorControl(fill, "fill", 10)
        local refreshBorder = colorControl(border, "border", 10)
        sliderControl("fillAlpha", fill, 155, colorY, 100)
        sliderControl("borderAlpha", border, 155, colorY, 100)
        local refreshThickness = sliderControl("thickness", border, 10, -123, 32)
        local function textureMenu(container, key, styles, title, refreshColor, refreshSize)
            local function current() return target()[key] or "solid" end
            label(container, title, 10, textureY)
            local picker = menu(container, 10, textureY - 16, 285, function(root)
                for _, style in ipairs(styles) do
                    radio(root, style[2], style[1], current, function(value)
                        target(true)[key] = value
                        inactive = not activeStyle
                        refreshColor()
                        if refreshSize then refreshSize() end
                        refresh()
                        refreshPreview()
                    end)
                end
            end)
            pickers[#pickers + 1] = function()
                for _, style in ipairs(styles) do
                    if style[1] == current() then picker:OverrideText(style[2]); return end
                end
                picker:OverrideText(styles[1][2])
            end
        end
        textureMenu(fill, "fillTexture", fillStyles, tr("Texture de fond", "Fill texture"), refreshFill)
        textureMenu(border, "borderTexture", borderStyles, tr("Texture de bordure", "Border texture"), refreshBorder, refreshThickness)
        local onTop = check(border, tr("Par-dessus tout", "Draw on top"), 157, -136, function(value)
            target(true).borderOnTop = value
            inactive = not activeStyle
            refreshPreview()
        end)
        return function()
            for _, updatePicker in ipairs(pickers) do updatePicker() end
            onTop:SetChecked(target().borderOnTop ~= false)
        end
    end

    local refreshDefaultStyle = styleEditor(ui.default, false)
    local activeControls = CreateFrame("Frame", nil, ui.styles)
    activeControls:SetAllPoints(ui.styles)
    local refreshActiveStyle = styleEditor(activeControls, true)
    button(ui.default, tr("Aperçu par défaut", "Preview default"), 18, -8, 194, function()
        inactive = true
        refreshPreview()
    end)
    button(activeControls, tr("Aperçu activé", "Preview activated"), 18, -8, 194, function()
        inactive = false
        refreshPreview()
    end)

    bindNumberOrColor(ui.appearance, "padding", 18, -60, 126)
    local _, _, setLevel = bindNumberOrColor(ui.display, "depth", 62, -6, 48)
    local function stepLevel(delta)
        setLevel(math.max(0, math.min(32, draft.depth + delta)))
    end
    button(ui.display, "−", 23, -22, 34, function() stepLevel(-1) end)
    button(ui.display, "+", 124, -22, 34, function() stepLevel(1) end)
    bindNumberOrColor(ui.transition, "linger", 18, -6, 126)
    bindNumberOrColor(ui.transition, "fade", 177, -6, 126)

    local displayHelp = label(ui.display, tr(
        "+ fait passer le cadre devant, − le fait reculer quand deux cadres se chevauchent. Le niveau s’applique aux cadres d’une même couche d’affichage.",
        "+ moves the frame forward, − moves it back when frames overlap. This applies to frames on the same display layer."),
        181, -9, "GameFontHighlightSmall")
    displayHelp:SetWidth(441)
    displayHelp:SetJustifyH("LEFT")
    displayHelp:SetWordWrap(true)

    local transitionHelp = label(ui.transition, tr(
        "Après désactivation, la rémanence prolonge le style activé. Le fondu détermine ensuite le temps qu’il met à disparaître.\nPour un cadre avec un style activé distinct.",
        "After deactivation, hold keeps the active style visible. Fade is how long it then takes to disappear.\nFor frames with a separate activated style."),
        325, -8, "GameFontHighlightSmall")
    transitionHelp:SetWidth(300)
    transitionHelp:SetJustifyH("LEFT")
    transitionHelp:SetWordWrap(true)

    local function loadFields()
        for _, control in ipairs(inputs) do control.load() end
    end

    local override = check(ui.styles, tr("Style activé distinct", "Separate activated style"), 300, -8, function(enabled)
        if enabled and not draft.inactiveStyle then
            draft.inactiveStyle = {}
            addon.CopyStyle(draft, draft.inactiveStyle)
        end
        draft.useDefaultStyle = not enabled
        if enabled then
            for _, control in ipairs(inputs) do
                if control.activeStyle then control.load() end
            end
        end
        inactive = not enabled
        refresh()
        refreshPreview()
    end)
    name:SetScript("OnTextChanged", function(_, userInput)
        if userInput and draft then
            draft.name = clean(name:GetText())
            refreshPreview()
        end
    end)

    local copyStyle = menu(ui.default, 400, -8, 225, function(root)
        for index, source in ipairs(layout().panels) do
            if index ~= selected then
                root:CreateButton(source.name, function()
                    inactive = true
                    addon.CopyStyle(defaultStyle(source), defaultStyle(draft, true))
                    draft.padding = source.padding or 8
                    draft.hintVisible = source.hintVisible
                    draft.hintOverride = source.hintOverride
                    draft.hint = source.hint
                    draft.hintOrientation = source.hintOrientation
                    draft.hintSide = source.hintSide
                    loadFields()
                    refresh()
                    refreshPreview()
                end)
            end
        end
    end)
    copyIcon(copyStyle, -17, -4)
    copyStyle:OverrideText(tr("Copier le style de…", "Copy style from…"))

    local function invalidField()
        for _, control in ipairs(inputs) do
            local spec = control.spec
            local key = spec[1]
            local geometry = key == "x" or key == "y" or key == "width" or key == "height"
            if (not geometry or draft.kind == "free") and control.show()
                and parseField(control.input:GetText(), spec) == nil then
                return spec
            end
        end
    end

    local function savePanel(proceed, approvedHold, approvedBinding)
        local target = draft
        local value = addon.Copy(draft)
        value.name = clean(name:GetText())
        if value.name == "" then
            notify(tr("Saisis un nom de cadre.", "Enter a frame name."))
            return
        end
        local selectedBars = addon.BarSelection(value)
        if selectedBars and not next(selectedBars) then
            notify(tr("Sélectionne au moins une barre.", "Select at least one bar."))
            return
        end
        local invalid = invalidField()
        if invalid then
            notify(tr("Valeur invalide pour ", "Invalid value for ") .. tr(invalid[2], invalid[3]))
            return
        end
        local previous = layout().panels[selected]
        local hold = addon.HoldLayer(value)
        local conflicts, names = {}, {}
        if hold and hold ~= "unmodified" and (not previous or hold ~= addon.HoldLayer(previous)) then
            for index, panel in ipairs(layout().panels) do
                if index ~= selected and addon.HoldLayer(panel) == hold then
                    conflicts[#conflicts + 1] = panel
                    names[#names + 1] = panel.name
                end
            end
        end
        if #conflicts > 0 and not sameSettings(conflicts, approvedHold) then
            confirm(tr("%s (%s) est utilisé par « %s ». Réserver ce déclencheur à « %s » ?",
                "%s (%s) is used by “%s”. Assign this trigger only to “%s”?")
                :format(addon.LayerLabel(hold), modeLabels.hold, table.concat(names, ", "), value.name),
                function(dialog)
                    if dialog then dialog:Hide() end
                    if draft == target then savePanel(proceed, conflicts, approvedBinding) end
                end)
            return
        end
        local oldToggle, toggle = previous and addon.PanelToggle(previous), addon.PanelToggle(value)
        local key = pendingToggleKey
        if toggle and oldToggle ~= toggle and not key then
            notify(tr("Assigne un raccourci à la bascule.", "Assign a shortcut to the toggle."))
            return
        end
        if toggle and key ~= nil then
            local ok, reason, owner = addon.AssignPanelToggleKey(value, toggle, key or nil, approvedBinding)
            if not ok then
                if reason == "occupied" then
                    confirm(tr("%s est affecté à « %s ». Réattribuer cette touche à « %s » ?",
                        "%s is assigned to “%s”. Reassign this key to “%s”?")
                        :format(GetBindingText and GetBindingText(key) or key, addon.ShortcutActionLabel(owner), value.name),
                        function()
                            if draft == target then savePanel(proceed, approvedHold, owner) end
                        end)
                elseif reason == "temporary" then
                    notify(tr("Touche temporairement utilisée par %s.", "Key temporarily used by %s.")
                        :format(addon.ShortcutActionLabel(owner)))
                else
                    notify(reason == "combat"
                        and tr("Modifie les raccourcis hors combat.", "Change shortcuts out of combat.")
                        or tr("Cette touche ne peut pas être assignée.", "This key cannot be assigned."))
                end
                return
            end
        elseif not toggle and type(oldToggle) == "number" then
            if not addon.AssignPanelToggleKey(previous, oldToggle, nil) then
                notify(tr("Modifie les raccourcis hors combat.", "Change shortcuts out of combat."))
                return
            end
        end
        for _, panel in ipairs(conflicts) do
            panel.activationMode, panel.layer = "none", "never"
            if panel.toggleId and not panel.toggleModifier then panel.toggleModifier = hold end
        end
        selected = selected or #layout().panels + 1
        layout().panels[selected] = value
        addon.SyncSwitch()
        addon.RememberFrameToggleKeys()
        pick(selected, nil, inactive)
        addon.Refresh()
        notify(tr("Cadre enregistré.", "Frame saved."))
        if proceed then proceed() end
    end

    button(ui.footer, tr("Enregistrer le cadre", "Save frame"), 18, -5, 195, function()
        stopFrameCapture()
        savePanel()
    end)
    local remove = button(ui.footer, tr("Supprimer", "Delete"), 225, -5, 115, function()
        local index = selected
        confirm(tr("Supprimer ce cadre ?", "Delete this frame?"), function()
            table.remove(layout().panels, index)
            addon.SyncSwitch()
            pick(math.min(index, #layout().panels))
            addon.Refresh()
        end)
    end)

    refresh = function()
        local panel = layout().panels[selected]
        panels:OverrideText(tr("Changer de cadre", "Change frame"))
        panels:SetEnabled(#layout().panels > 0)
        ui.form:SetShown(draft ~= nil)
        ui.footer:SetShown(draft ~= nil)
        ui.empty:SetShown(draft == nil)
        if not draft then return end
        refreshDefaultStyle()
        refreshActiveStyle()
        activeControls:SetShown(not draft.useDefaultStyle)
        ui.stylesRow.height = draft.useDefaultStyle and 70 or 278
        override:SetChecked(not draft.useDefaultStyle)
        copyStyle:SetEnabled(#layout().panels > (selected and 1 or 0))
        kind:OverrideText(draft.kind == "chat" and chatLabel(draft.chatId) or kinds[draft.kind])
        local hold, toggle = addon.HoldLayer(draft), addon.PanelToggle(draft)
        local key = pendingToggleKey
        if key == nil then key = addon.PanelToggleKey(draft) end
        ui.hold:OverrideText(hold and addon.LayerLabel(hold) or (toggle and modeLabels.none
            or tr("Toujours visible", "Always visible")))
        ui.toggle:OverrideText(toggle and addon.LayerLabel(addon.ToggleModifier(draft)) or modeLabels.none)
        ui.toggleKey:SetEnabled(toggle ~= nil)
        if not ui.capturing then
            ui.toggleKey:SetText(key and (GetBindingText and GetBindingText(key) or key)
                or (toggle and tr("Assigner…", "Assign…") or "—"))
        end
        ui.activationHelp:SetText(toggle and tr(
            "Bascule : la couche reste active après l’appui. Les raccourcis sont appliqués dans WoW à l’enregistrement.",
            "Toggle: the layer stays active after pressing the shortcut. WoW keybindings are applied when you save.")
            or hold and tr("Touche maintenue : le cadre s’allume pendant l’appui.",
                "Hold key: the frame highlights while the key is held.")
            or tr("Toujours visible : le cadre s’affiche sans déclencheur.",
                "Always visible: the frame is shown without a trigger."))
        local selectedBars = addon.BarSelection(draft)
        barGroup:SetShown(selectedBars ~= nil)
        ui.geometryRow.block:SetShown(draft.kind == "free")
        ui.moveFrame:SetShown(draft.kind == "free")
        linkedHelp:SetShown(not selectedBars)
        linkedHelp:SetText(draft.kind == "free"
            and tr("En édition, glisse le cadre pour le déplacer et sa poignée pour le redimensionner.",
                "In edit mode, drag the frame to move it and its handle to resize it.")
            or draft.kind == "chat" and tr("Le cadre suit la fenêtre de tchat sélectionnée.",
                "The frame follows the selected chat window.")
            or tr("Le cadre suit cet élément lorsqu’il est visible.", "The frame follows this element when it is visible."))
        ui.reflow()
        for id, item in ipairs(barChecks) do
            item:SetShown(id <= (addon.barCounts[draft.kind] or 0))
            item:SetChecked(selectedBars and selectedBars[id])
            local caption = barCaptions[id]
            caption:SetText((addon.BarLabel(draft.kind, id)))
            item:SetHitRectInsets(0, -caption:GetStringWidth(), 0, 0)
        end
        if selectedBars then
            local names = {}
            for id = 1, addon.barCounts[draft.kind] do
                if selectedBars[id] then names[#names + 1] = (addon.BarLabel(draft.kind, id)) end
            end
            ui.barSummary:SetText(#names > 0 and tr("Barres sélectionnées : %s", "Selected bars: %s")
                :format(table.concat(names, ", ")) or tr("Sélectionne au moins une barre.", "Select at least one bar."))
        end
        remove:SetEnabled(panel ~= nil)
    end

    pick = function(index, initial, keepDefaultTab)
        stopFrameCapture()
        local panel = layout().panels[index]
        if selected ~= index then ui.form:SetVerticalScroll(0) end
        pendingToggleKey = nil
        selected = panel and index or nil
        draft = initial or (panel and addon.Copy(panel))
        if keepDefaultTab ~= nil then
            inactive = keepDefaultTab
        else
            inactive = draft and (draft.inactiveStyle ~= nil or draft.useDefaultStyle == true) or false
        end
        closeHints()
        closeActivation()
        if draft then
            name:SetText(draft.name)
            loadFields()
        end
        refresh()
        notify()
        refreshPreview()
    end

    local function hasPendingChanges()
        if not draft then return false end
        if not selected or pendingToggleKey ~= nil or not sameSettings(draft, layout().panels[selected]) then return true end
        return invalidField() ~= nil
    end

    updateHeading = function()
        local saved = layout().panels[selected]
        currentName:SetText(draft and (draft.name ~= "" and draft.name or tr("Cadre sans nom", "Unnamed frame"))
            or tr("Aucun cadre", "No frame"))
        local details = ""
        if draft then
            local hold, toggle = addon.HoldLayer(draft), addon.PanelToggle(draft)
            local mode = hold and tr("Touche maintenue", "Hold key") or tr("Toujours visible", "Always visible")
            if toggle then
                local toggleText = tr("Bascule", "Toggle")
                mode = hold and (mode .. " + " .. toggleText) or toggleText
            end
            details = (draft.kind == "chat" and chatLabel(draft.chatId) or kinds[draft.kind] or "") .. "  ·  " .. mode
        end
        currentDetails:SetText(details)
        draftStatus:SetText(draft and (not saved and tr("Nouveau cadre non enregistré", "Unsaved new frame")
            or hasPendingChanges() and tr("Modifications non enregistrées", "Unsaved changes")) or "")
    end

    leaveDraft = function(proceed)
        stopFrameCapture()
        if not hasPendingChanges() then proceed(); return end
        StaticPopupDialogs.KEYLAYERS_UNSAVED_FRAME = {
            text = "%s", button1 = tr("Enregistrer", "Save"), button2 = CANCEL, button3 = tr("Ignorer", "Discard"),
            timeout = 0, whileDead = true, hideOnEscape = true,
            OnAccept = function(_, action) action.save() end,
            OnAlt = function(_, action) action.discard() end,
        }
        local saved = layout().panels[selected]
        local title = saved and saved.name or (draft.name ~= "" and draft.name or tr("Nouveau cadre", "New frame"))
        local target = draft
        StaticPopup_Show("KEYLAYERS_UNSAVED_FRAME",
            tr("Enregistrer les modifications de « %s » ?", "Save changes to “%s”?"):format(title), nil, {
                save = function() if draft == target then savePanel(proceed) end end,
                discard = function()
                    if draft ~= target then return end
                    pick(selected)
                    proceed()
                end,
            })
    end

    requestPick = function(index)
        if index == (selected or 0) then return draft end
        leaveDraft(function() pick(index) end)
        if selected == index then return draft end
    end
    local function requestClose()
        leaveDraft(function() window:Hide() end)
    end
    close:SetScript("OnClick", requestClose)
    local escape = CreateFrame("Frame", "KeyLayersEditorEscape", window)
    escape:SetScript("OnHide", function(self)
        if window:IsShown() then
            requestClose()
            if window:IsShown() then self:Show() end
        end
    end)
    table.insert(UISpecialFrames, escape:GetName())

    local function applyGeometry(x, y, width, height)
        local values = {x, y, width, height}
        for index, input in ipairs(geometryInputs) do
            local spec = fields[index]
            local value = math.floor(values[index] + 0.5)
            value = math.max(spec[4], math.min(spec[5], value))
            draft[spec[1]] = value
            input:SetText(tostring(value))
        end
        refreshPreview()
    end

    setEditing = function(value)
        if value and InCombatLockdown() then
            notify(tr("Mode Édition indisponible en combat.", "Edit mode is unavailable in combat."))
            return
        end
        editing = value
        addon.SetGameplayHotkeysSuspended(value)
        if not value and keybinds then keybinds:Hide() end
        editToggle:SetText(value and tr("Quitter l’édition", "Exit edit mode") or tr("Mode Édition", "Edit mode"))
        if value then
            if not placedForEditing then
                window:ClearAllPoints()
                window:SetPoint("RIGHT", UIParent, "RIGHT", -16, 0)
                placedForEditing = true
            end
            addon.SetEditor({
                current = function() return selected, draft end,
                name = function() return clean(name:GetText()) end,
                geometry = applyGeometry,
                toggleBar = function(kind, id)
                    if not draft or not addon.barCounts[draft.kind] then return end
                    draft.kind = kind
                    local selectedBars = addon.BarSelection(draft)
                    selectedBars[id] = not selectedBars[id] or nil
                    refresh()
                    refreshPreview()
                end,
                select = function(index)
                    return requestPick(index)
                end,
            })
            notify(tr("Clique sur un cadre pour afficher ses réglages.", "Click a frame to show its settings."))
        else
            addon.SetEditor(nil)
            notify()
        end
        refreshPreview()
    end

    window:RegisterEvent("PLAYER_REGEN_DISABLED")
    window:SetScript("OnEvent", function()
        stopFrameCapture()
        cancelShortcutCapture()
        if editing then setEditing(false) end
        if assignment:IsShown() then selectTabNow(config) end
    end)

    local profileName = field(profiles, tr("Nom du profil", "Profile name"), 18, -13, 242)
    profileName:SetText(defaultProfileName() or "")
    local profileMenu, load
    local function refreshProfiles()
        profileMenu:OverrideText(profile or tr("Sélectionner un profil", "Select a profile"))
        load:SetEnabled(profile ~= nil)
    end
    button(profiles, tr("Enregistrer", "Save"), 272, -29, 124, function()
        local value = clean(profileName:GetText())
        if value == "" then value = defaultProfileName() end
        if not value then return end
        local function save()
            addon.RememberFrameToggleKeys()
            local snapshot = addon.Copy(layout())
            minimapSettings(snapshot)
            snapshot.neutralKey = addon.NeutralKey() or false
            KeyLayersProfiles[value] = snapshot
            profile = value
            profileName:SetText(value)
            refreshProfiles()
            notify(tr("Profil enregistré.", "Profile saved."))
        end
        if KeyLayersProfiles[value] then
            confirm(tr("Remplacer ce profil par la configuration actuelle ?",
                "Replace this profile with the current settings?"), save)
        else
            save()
        end
    end)
    label(profiles, tr("Profils partagés entre personnages", "Profiles shared across characters"), 18, -79)
    profileMenu = menu(profiles, 18, -98, 242, function(root)
        local names = {}
        for value in pairs(KeyLayersProfiles) do names[#names + 1] = value end
        table.sort(names)
        for _, value in ipairs(names) do
            radio(root, value, value, function() return profile end, function(selection)
                profile = selection
                refreshProfiles()
            end)
        end
    end)
    load = button(profiles, tr("Charger", "Load"), 272, -98, 124, function()
        local snapshot = KeyLayersProfiles[profile]
        if not snapshot then return end
        confirm(tr("Appliquer ce profil à ce personnage ?", "Apply this profile to this character?"), function()
            if InCombatLockdown() then
                notify(tr("Modifie les raccourcis hors combat.", "Change shortcuts out of combat."))
                return
            end
            local previousMinimap = minimapSettings(layout())
            KeyLayersCharLayout = addon.Copy(snapshot)
            minimapSettings(KeyLayersCharLayout, previousMinimap)
            KeyLayersCharLayout.neutralKey = nil
            addon.MigrateActivation(layout())
            addon.SyncSwitch(true)
            addon.RestoreFrameToggleKeys()
            local restored = snapshot.neutralKey == nil or addon.AssignNeutralKey(snapshot.neutralKey)
            if addon.PositionMinimapIcon then addon.PositionMinimapIcon() end
            pick(1)
            addon.Refresh()
            notify(restored and tr("Profil chargé.", "Profile loaded.")
                or tr("Profil chargé. La touche Neutre actuelle est conservée, car celle du profil n’a pas pu être assignée.",
                    "Profile loaded. The current neutral key was kept because the profile key could not be assigned."))
        end)
    end)
    refreshProfiles()
    pick(1)
    window:SetScript("OnShow", function()
        escape:Show()
        refreshPreview()
    end)
    window:SetScript("OnHide", function()
        escape:Hide()
        stopFrameCapture()
        if assignment:IsShown() then selectTabNow(config) end
        closeHints()
        closeActivation()
        if editing then setEditing(false) end
        addon.SetDraftPreview(nil, nil)
    end)
    return window, requestClose
end

function addon.InstallOptions()
    local window, requestClose
    local function open()
        if not window then window, requestClose = buildWindow()
        else window:Show() end
    end
    local function toggle()
        if window and window:IsShown() then requestClose()
        else open() end
    end
    SLASH_BARTENDERGLOW1 = "/keylayers"
    SLASH_BARTENDERGLOW2 = "/btglow"
    SLASH_BARTENDERGLOW3 = "/shiftkit"
    SlashCmdList.BARTENDERGLOW = function(text)
        if (text or ""):match("^%s*(.-)%s*$"):lower() == "diagnostic" then
            addon.PrintSwitchDiagnostics()
        else
            toggle()
        end
    end
    local categoryPanel = CreateFrame("Frame")
    categoryPanel.name = "KeyLayers"
    label(categoryPanel, addon.title .. "  v" .. addon.version, 16, -16, "GameFontNormalLarge")
    button(categoryPanel, tr("Ouvrir l’éditeur de cadres", "Open frame editor"), 16, -49, 234, function()
        open()
        if SettingsPanel and SettingsPanel:IsShown() then
            if HideUIPanel then HideUIPanel(SettingsPanel) else SettingsPanel:Hide() end
        elseif InterfaceOptionsFrame and InterfaceOptionsFrame:IsShown() then
            InterfaceOptionsFrame:Hide()
        end
    end)
    local minimapToggle = check(categoryPanel, tr("Afficher l’icône de minimap", "Show minimap icon"),
        16, -88, function(value)
            minimapSettings(KeyLayersCharLayout).hide = not value or nil
            if addon.PositionMinimapIcon then addon.PositionMinimapIcon() end
        end)
    categoryPanel:SetScript("OnShow", function()
        minimapToggle:SetChecked(not minimapSettings(KeyLayersCharLayout).hide)
    end)
    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        Settings.RegisterAddOnCategory(Settings.RegisterCanvasLayoutCategory(categoryPanel, "KeyLayers"))
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(categoryPanel)
    end
    if not Minimap then return end
    local texture = [[Interface\AddOns\]] .. addonName .. [[\Media\Minimap.tga]]
    local broker = LibStub and LibStub:GetLibrary("LibDataBroker-1.1", true)
    local icons = LibStub and LibStub:GetLibrary("LibDBIcon-1.0", true)
    if broker and icons then
        local state = minimapSettings(KeyLayersCharLayout)
        local launcher = broker:NewDataObject("KeyLayers", {
            type = "launcher",
            label = "KeyLayers",
            icon = [[Interface\AddOns\]] .. addonName .. [[\Media\MinimapBroker.tga]],
            iconCoords = {0, 1, 0, 1},
            OnClick = toggle,
            OnTooltipShow = function(tooltip)
                tooltip:AddLine(addon.title .. "  v" .. addon.version)
            end,
        })
        icons:Register("KeyLayers", launcher, state)
        local icon = icons:GetMinimapButton("KeyLayers")
        addon.PositionMinimapIcon = function()
            local newState = minimapSettings(KeyLayersCharLayout)
            if newState ~= state then
                wipe(state)
                for key, value in pairs(newState) do state[key] = value end
                KeyLayersCharLayout.minimapIcon = state
            end
            if state.hide then
                icons:Hide("KeyLayers")
            else
                local isLoaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
                if isLoaded and isLoaded("SexyMap") then
                    -- SexyMap restores the button's position from its own profile.
                    icon:Show()
                else
                    icons:Show("KeyLayers")
                end
            end
        end
        return
    end

    local icon = CreateFrame("Button", "BartenderGlowMinimapButton", Minimap)
    icon:SetSize(31, 31)
    icon:SetFrameStrata("MEDIUM")
    icon:SetFrameLevel(Minimap:GetFrameLevel() + 9)

    local emblem = icon:CreateTexture(nil, "ARTWORK")
    emblem:SetTexture(texture)
    emblem:SetAllPoints(icon)

    local highlight = icon:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetTexture([[Interface\Minimap\UI-Minimap-ZoomButton-Highlight]])
    highlight:SetBlendMode("ADD")
    highlight:SetSize(31, 31)
    highlight:SetPoint("CENTER")
    local function position()
        local state = minimapSettings(KeyLayersCharLayout)
        local angle = math.rad(state.minimapPos or 245)
        icon:SetShown(not state.hide)
        icon:ClearAllPoints()
        icon:SetPoint("CENTER", Minimap, "CENTER",
            math.cos(angle) * (Minimap:GetWidth() / 2 + 5),
            math.sin(angle) * (Minimap:GetHeight() / 2 + 5))
    end
    icon:RegisterForDrag("LeftButton")
    icon:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local x, y = GetCursorPosition()
            local cx, cy = Minimap:GetCenter()
            if cx then
                local scale = Minimap:GetEffectiveScale()
                minimapSettings(KeyLayersCharLayout).minimapPos =
                    math.deg(math.atan2(y / scale - cy, x / scale - cx)) % 360
                position()
            end
        end)
    end)
    icon:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    icon:SetScript("OnClick", toggle)
    icon:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(addon.title .. "  v" .. addon.version)
        GameTooltip:Show()
    end)
    icon:SetScript("OnLeave", function() GameTooltip:Hide() end)
    addon.PositionMinimapIcon = position
    Minimap:HookScript("OnSizeChanged", position)
    position()
end
