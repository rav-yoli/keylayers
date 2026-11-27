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
    {"paddingX", "Marge horizontale", "Horizontal padding", 0, 10000},
    {"paddingY", "Marge verticale", "Vertical padding", 0, 10000},
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
    window:SetSize(900, 755)
    window:SetScale(math.min(1, (UIParent:GetWidth() - 32) / 900, (UIParent:GetHeight() - 32) / 755))
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
    config:SetPoint("TOPLEFT", 220, -70)
    config:SetPoint("BOTTOMRIGHT")
    local barsPage = CreateFrame("Frame", nil, window)
    barsPage:SetAllPoints(config)
    barsPage:Hide()
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
    local editingFrameDefaults
    local framePage = "target"
    local refresh, pick, setEditing, closeHints, openActivation, closeActivation, cancelShortcutCapture
    local updateHeading, requestPick, leaveDraft, loadFields
    local ui = {}
    local pendingToggleKey, pendingBarStyles
    local stopFrameCapture = function() end
    local editing, inactive = false, false
    local keybinds, barEditor
    local defaultStyle = addon.DefaultFrameStyle
    local function layout() return KeyLayersCharLayout end
    local function refreshPreview()
        local panel = not editingFrameDefaults and window:IsShown() and config:IsShown() and draft or nil
        ui.frameStylePreviews = nil
        local dimensions
        if editingFrameDefaults and draft and window:IsShown() and config:IsShown() then
            local kind = editingFrameDefaults ~= "global" and editingFrameDefaults or nil
            dimensions = addon.BarLayout.previewFrameDimensions(layout(), kind, draft)
            if editing and framePage=="appearance" then
                ui.frameStylePreviews = addon.BarLayout.previewFrameDefaults(layout(), kind, draft)
            end
        end
        addon.SetDraftBarStyles(panel and pendingBarStyles or nil)
        addon.SetDraftPreview(selected, panel, inactive, pendingToggleKey,
            panel and inactive and not panel.inactiveStyle and defaultStyle(panel) or nil, dimensions)
        addon.UpdateOwnedFramePositions()
        if panel and ui.updateFitMargins then ui.updateFitMargins(panel) end
        if updateHeading then updateHeading() end
        if ui.updateHint and draft then ui.updateHint() end
    end
    ui.globalPage = CreateFrame("Frame",nil,window)
    ui.globalPage:SetPoint("TOPLEFT",230,-78)
    ui.globalPage:SetPoint("BOTTOMRIGHT",-18,14)
    ui.globalPage:Hide()
    local tabStates = {}
    local assignedFrame
    local function selectTabNow(page,bindingFrame)
        if (page == assignment or page == barsPage) and InCombatLockdown() then
            notify(tr("Mode Édition indisponible en combat.", "Edit mode is unavailable in combat."))
            return
        end
        local fromBars = barsPage:IsShown()
        if page == barsPage and config:IsShown() and barEditor then barEditor.follow(selected) end
        closeHints()
        closeActivation()
        if page == assignment and not editing then
            setEditing(true)
        elseif page ~= config and page ~= barsPage and page ~= assignment and editing then
            setEditing(false)
        end
        config:SetShown(page == config)
        barsPage:SetShown(page == barsPage)
        profiles:SetShown(page == profiles)
        assignedFrame = page == assignment and (bindingFrame or assignedFrame) or nil
        assignment:SetShown(page == assignment)
        notes:SetShown(page == notes)
        ui.globalPage:SetShown(page == ui.globalPage)
        status:SetShown(page == config or page == profiles)
        local workspace=page==config or page==barsPage or page==assignment or page==ui.globalPage
        for target, showState in pairs(tabStates) do showState(target==page or (target==config and workspace),true) end
        if barEditor then barEditor.navigation(workspace,page==config and selected or assignedFrame) end
        notify()
        if page == assignment then
            if not keybinds then
                keybinds = addon.CreateKeybindingAssistant(assignment,
                    {label = label, button = button, menu = menu, radio = radio, check = check, confirm = confirm}, window)
            end
            if bindingFrame or not keybinds:IsShown() then keybinds:Open(layout().panels[bindingFrame]) end
        elseif keybinds then
            keybinds:Hide()
        end
        if page == config and fromBars and barEditor then pick(barEditor.selectedFrame() or selected) end
        refreshPreview()
    end
    local function selectTab(page)
        if page == config and config:IsShown() then return end
        if (page == assignment or page == barsPage) and InCombatLockdown() then
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
    tabStates[config] = tab(window, tr("Cadres et barres", "Frames and bars"), 18, -39, 155, function() selectTab(config) end)
    tabStates[profiles] = tab(window, tr("Profils", "Profiles"), 177, -39, 74, function() selectTab(profiles) end)
    tabStates[notes] = tab(window, tr("Versions", "Versions"), 255, -39, 89, function() selectTab(notes) end)
    for page, showState in pairs(tabStates) do showState(page == config, true) end

    local editToggle = addon.CreateWorkspaceSwitch(window, function()
        if editing then
            leaveDraft(function()
                setEditing(false)
                if assignment:IsShown() then selectTabNow(config) end
            end)
        else
            setEditing(true)
        end
    end)

    local editLabel = window:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    editLabel:SetPoint("RIGHT", window, "TOPRIGHT", -18, -53)
    editLabel:SetText(tr("Édition", "Edit mode"))
    editToggle:SetPoint("RIGHT", editLabel, "LEFT", -8, 0)
    editToggle:SetActive(editing)
    editToggle:SetHitRectInsets(0, -8 - editLabel:GetStringWidth(), 0, 0)
    editToggle:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self,"ANCHOR_TOP")
        GameTooltip:SetText(editing and tr("Quitter l’édition","Exit edit mode")
            or tr("Activer le mode édition","Enable edit mode"))
        GameTooltip:Show()
    end)
    editToggle:SetScript("OnLeave",function() GameTooltip:Hide() end)
    label(notes, tr("Notes de version", "Release notes"), 18, -17, "GameFontNormalLarge")
    label(notes, tr("Versions après %s", "Versions after %s"):format(addon.releaseHistoryBase),
        18, -43, "GameFontHighlightSmall")
    local releaseScroll = CreateFrame("ScrollFrame", nil, notes, "UIPanelScrollFrameTemplate")
    releaseScroll:SetPoint("TOPLEFT", 18, -69)
    releaseScroll:SetPoint("BOTTOMRIGHT", -34, 130)
    local releaseContent = CreateFrame("Frame", nil, releaseScroll)
    releaseContent:SetWidth(618)
    releaseContent:SetHeight(1)
    releaseScroll:SetScrollChild(releaseContent)
    local entries = {}
    for index, entry in ipairs(addon.releaseHistory) do
        local row = CreateFrame("Frame", nil, releaseContent)
        row:SetWidth(618)
        label(row, entry[1], 0, 0, "GameFontNormal")
        local description = label(row, entry[2], 0, -17, "GameFontHighlight")
        description:SetWidth(612)
        description:SetJustifyH("LEFT")
        description:SetWordWrap(true)
        entries[index] = {row = row, description = description}
    end
    releaseScroll:EnableMouseWheel(true)
    releaseScroll:SetScript("OnMouseWheel", function(self, delta)
        local offset = self:GetVerticalScroll() - delta * 42
        self:SetVerticalScroll(math.max(0, math.min(offset, self:GetVerticalScrollRange())))
    end)
    notes:SetScript("OnShow", function()
        local height = 0
        for _, entry in ipairs(entries) do
            entry.row:ClearAllPoints()
            entry.row:SetPoint("TOPLEFT", releaseContent, "TOPLEFT", 0, -height)
            local rowHeight = 27 + math.ceil(entry.description:GetStringHeight())
            entry.row:SetHeight(rowHeight)
            height = height + rowHeight
        end
        releaseContent:SetHeight(math.max(1, height))
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
    local altWarning = label(config, tr("Alt + F4 est réservé. Utilise F5.", "Alt + F4 is reserved. Use F5."),
        506, -7, "GameFontHighlightSmall")
    altWarning:SetWidth(156)
    altWarning:SetJustifyH("LEFT")
    altWarning:SetWordWrap(true)
    local frameHeading = config:CreateTexture(nil, "BACKGROUND")
    frameHeading:SetPoint("TOPLEFT", 10, -31)
    frameHeading:SetPoint("TOPRIGHT", -10, -31)
    frameHeading:SetHeight(86)
    frameHeading:SetColorTexture(unpack(addon.BarLayout.workspaceSelectionColor))
    local pageBackground = config:CreateTexture(nil, "BACKGROUND")
    pageBackground:SetPoint("TOPLEFT", 10, -126)
    pageBackground:SetPoint("BOTTOMRIGHT", -10, 69)
    pageBackground:SetColorTexture(unpack(addon.BarLayout.workspacePageColor))
    ui.categoryTitle = label(config, "", 18, -39, "GameFontHighlightSmall")
    ui.categoryTitle:SetFontObject(GameFontHighlight)
    local currentName = label(config, "", 18, -57, "GameFontNormalLarge")
    currentName:SetWidth(325)
    currentName:SetJustifyH("LEFT")
    currentName:SetWordWrap(false)
    local name = CreateFrame("EditBox", nil, config, "InputBoxTemplate")
    name:SetPoint("TOPLEFT", 23, -52)
    name:SetSize(315, 23)
    name:SetAutoFocus(false)
    name:SetMaxLetters(48)
    name:Hide()
    local rename = addon.CreateRenameButton(config, tr("Renommer le cadre", "Rename frame"))
    rename:SetScript("OnClick", function()
        if not draft or editingFrameDefaults or InCombatLockdown() then return end
        name.original = draft.name
        rename:Hide()
        currentName:Hide()
        name:Show()
        name:SetFocus()
        name:HighlightText()
    end)
    name:SetScript("OnEditFocusLost", function(self)
        self:Hide()
        self.original = nil
        currentName:Show()
        if updateHeading then updateHeading() end
    end)
    name:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    name:SetScript("OnEscapePressed", function(self)
        if draft and self.original then
            draft.name = self.original
            self:SetText(draft.name)
            refreshPreview()
            if barEditor and selected then barEditor.navigation(true, selected, draft.name) end
        end
        self:ClearFocus()
    end)
    local currentDetails = label(config, "", 18, -79, "GameFontHighlightSmall")
    currentDetails:SetWidth(265)
    currentDetails:SetJustifyH("LEFT")
    currentDetails:SetWordWrap(false)
    local draftStatus = label(config, "", 18, -98, "GameFontNormalSmall")
    local function placeNew(panel)
        local scale=window:GetEffectiveScale()/UIParent:GetEffectiveScale()
        local width,height=UIParent:GetWidth(),UIParent:GetHeight()
        local left,bottom=window:GetLeft(),window:GetBottom()
        if not left or not bottom then return end
        local bounds={left=left*scale-width/2,right=window:GetRight()*scale-width/2,
            bottom=bottom*scale-height/2,top=window:GetTop()*scale-height/2}
        local x,y=addon.BarLayout.placeBeside(panel,bounds,width,height)
        if x then
            panel.x,panel.y=x,y
        else
            -- A group may be too wide to share the screen with the full inspector.
            window:ClearAllPoints()
            local scale=window:GetScale()
            if scale>.6 then
                window:SetScale(math.max(.6,scale*.8))
            end
            window:SetPoint("TOPRIGHT",UIParent,"TOPRIGHT",-12,-12)
        end

    end
    local function newFrame()
        if InCombatLockdown() then return end
        leaveDraft(function()
            if InCombatLockdown() then return end
            selectTabNow(config)
            if not editing then setEditing(true) end
            local panel = addon.BarLayout.newFrame(layout(), addon.BarLayout.uniqueName(tr("Nouveau cadre", "New frame")))
            placeNew(panel)
            table.insert(layout().panels, panel)
            if barEditor then barEditor.showContainers() end
            pick(#layout().panels)
            barEditor.navigation(true, selected, draft.name, true)
        end)
    end
    ui.newFrame = button(config, tr("Nouveau cadre", "New frame"), 0, -52, 177, newFrame)
    ui.newFrame:ClearAllPoints()
    ui.newFrame:SetPoint("TOPRIGHT", -22, -52)

    ui.form = CreateFrame("ScrollFrame", nil, config, "UIPanelScrollFrameTemplate")
    ui.form:SetPoint("TOPLEFT", 10, -126)
    ui.form:SetPoint("BOTTOMRIGHT", -30, 69)
    local editor = CreateFrame("Frame", nil, ui.form)
    editor:SetSize(640, 1)
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
    local function group(height, parent, rows)
        rows = rows or ui.groups
        local block = CreateFrame("Frame", nil, parent or editor)
        block:SetWidth(650)
        local row = {block = block, height = height}
        rows[#rows + 1] = row
        return block, row
    end
    local function placeGroups(parent, rows, y)
        for _, row in ipairs(rows) do
            row.block:ClearAllPoints()
            row.block:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -y)
            row.block:SetHeight(row.height)
            if row.block:IsShown() then y = y + row.height + 6 end
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
    ui.templateTarget = group(112)
    ui.templateDescription = label(ui.templateTarget, "", 18, -34, "GameFontHighlight")
    ui.templateDescription:SetWidth(602)
    ui.templateDescription:SetJustifyH("LEFT")
    ui.templateDescription:SetWordWrap(true)
    ui.autoFitFrames = addon.CreateWorkspaceSwitch(config, function()
        if InCombatLockdown() then return end
        local model = addon.BarLayout
        if editingFrameDefaults == "owned" then
            model.init(layout()).autoFitFrames = not model.autoFitEnabled()
        elseif not editingFrameDefaults then
            local panel = layout().panels[selected]
            local bar = model.singleFrameBar(panel)
            if not bar or not draft then return end
            model.setFitFrame(bar, not model.autoFitEnabled(panel))
            draft.autoFitBars, draft.manualFit = panel.autoFitBars, panel.manualFit
        end
        refresh()
        refreshPreview()
        addon.RebuildBars()
    end)
    ui.autoFitFrames:SetPoint("TOPLEFT", 458, -34)
    local autoFitLabel = label(config, tr("Ajustement auto", "Auto fit"), 502, -36, "GameFontHighlight")
    ui.autoFitFrames:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(addon.BarLayout.autoFitLabel)
        GameTooltip:Show()
    end)
    ui.autoFitFrames:SetScript("OnLeave", function() GameTooltip:Hide() end)
    ui.autoFitFrames:Hide()
    autoFitLabel:Hide()
    ui.templateDescriptions = {
        owned = tr("Regroupe les styles communs des cadres liés aux barres KeyLayers.",
            "Shared styles for frames attached to KeyLayers bars."),
        blizzard = tr("Regroupe les styles communs des cadres liés aux barres d’action Blizzard.",
            "Shared styles for frames attached to Blizzard action bars."),
        free = tr("Regroupe les styles communs des cadres libres.", "Shared styles for free frames."),
        global = tr("Définit les propriétés communes à tous les types de cadres.", "Shared properties for every frame type."),
    }
    ui.target = group(166)
    ui.geometry, ui.geometryRow = group(217)
    ui.activation = group(177)
    ui.appearance, ui.appearanceRow = group(103)
    ui.styleGroups = {}
    ui.default = group(242, ui.appearance, ui.styleGroups)
    label(ui.default, tr("Style par défaut", "Default style"), 18, -7, "GameFontHighlight")
    ui.activeStyleToggle = group(30, ui.appearance, ui.styleGroups)
    ui.styles = group(238, ui.appearance, ui.styleGroups)
    ui.transition = group(77)
    ui.display = group(59)

    local kinds = addon.kindLabels
    local function chatLabel(id)
        return tr("Tchat %d", "Chat %d"):format(id)
    end
    local kind = menu(ui.target, 18, -37, 265, function(root)
        local function current()
            return draft.kind == "chat" and draft.chatId or draft.kind
        end
        local function selectKind(value)
            if InCombatLockdown() or not draft then return end
            local model = addon.BarLayout
            if value == "owned" then
                local saved = layout().panels[selected]
                local geometry = addon.GetPanelGeometry(draft) or draft
                -- Stage the attachment on a copy so a full bar list leaves the frame unchanged.
                local target = model.inheritFrame(layout(), addon.Copy(saved))
                target.kind = "owned"
                for _, key in ipairs({"x", "y", "width", "height"}) do target[key] = geometry[key] end
                local state = model.init(layout())
                if #model.children(target)==0 then
                    local created, reason = model.new("action", target, true)
                    if not created then
                        notify(reason=="bar-limit" and tr("Limite de 12 barres KeyLayers atteinte.", "The 12 KeyLayers bars are already in use.")
                            or tr("Impossible de placer la première barre.", "Could not place the first bar."))
                        return
                    end
                end
                layout().panels[selected] = target
                target.microPosition = nil
                draft.kind, draft.barFrameId = target.kind, target.barFrameId
                for _, key in ipairs({"x", "y", "width", "height"}) do draft[key] = target[key] end
                state.mode = "KeyLayers"
                addon.RebuildBars()
                if barEditor then barEditor.navigation(true, selected, draft.name) end
            elseif type(value) == "number" then
                draft.kind, draft.chatId = "chat", value
            else
                draft.kind = value
                draft.bartenderAttachment = nil
            end
            if draft.kind ~= "micro" then draft.microPosition = nil end
            loadFields()
            refresh()
            refreshPreview()
        end
        radio(root, kinds.owned, "owned", current, selectKind)
        radio(root, kinds.free, "free", current, selectKind)
        for _, key in ipairs(addon.linkedKinds) do
            if not addon.BarLayout.bartenderKind(key) or addon.BarLayout.installed() then
                radio(root, kinds[key], key, current, selectKind)
            end
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
    label(ui.target, tr("Type de rattachement", "Attachment type"), 18, -15)
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
    local frameVisibility = {
        {"always", tr("Toujours visible", "Always visible")},
        {"combat", tr("En combat", "In combat")},
        {"hover", tr("Au survol", "On hover")},
        {"hidden", tr("Masquée", "Hidden")},
    }
    label(ui.activation, tr("Visibilité", "Visibility"), 18, -134)
    ui.frameVisibility = menu(ui.activation, 223, -129, 182, function(root)
        for _, option in ipairs(frameVisibility) do
            radio(root, option[2], option[1], function() return draft.visibility or "always" end, function(value)
                draft.visibility = value
                refresh()
                refreshPreview()
            end)
        end
    end)
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
        local warning = addon.ReservedShortcutMessage(key, IsAltKeyDown())
        if warning then notify(warning); return end
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
            popupStatus:SetText((reason == "reserved" and addon.ReservedShortcutMessage(key)) or (reason == "combat"
                and tr("Modifie les raccourcis hors combat.", "Change shortcuts out of combat.")
                or tr("Cette touche ne peut pas être assignée.", "This key cannot be assigned.")))
        end
    end
    capture:SetScript("OnKeyDown", function(_, key)
        if not captureLayer or pressedKey or key == "UNKNOWN" then return end
        if key:match("^[LR]CTRL$") or key:match("^[LR]SHIFT$") or key:match("^[LR]ALT$")
            or key == "CTRL" or key == "SHIFT" or key == "ALT" then return end
        local warning = addon.ReservedShortcutMessage(key, IsAltKeyDown())
        if warning then popupStatus:SetText(warning); return end
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

    ui.hintPane = CreateFrame("Frame", nil, config)
    ui.hintPane:SetPoint("TOPLEFT", 10, -126)
    ui.hintPane:SetPoint("BOTTOMRIGHT", -10, 69)
    ui.hintPane:Hide()
    closeHints = function()
        local wasShown = ui.hintPane:IsShown()
        ui.hintPane:Hide()
        if framePage=="frameHint" or framePage=="profileHint" or framePage=="globalHint" then framePage="target" end
        ui.form:SetShown(draft ~= nil)
        if wasShown and refresh then refresh() end
    end
    local heading = label(ui.hintPane, "", 16, -15, "GameFontNormalLarge")
    local description = label(ui.hintPane, tr(
        "L’étiquette indique sur quelle touche appuyer pour activer le cadre.",
        "The label shows which key activates the frame."),
        16, -40, "GameFontHighlightSmall")
    description:SetWidth(348)
    description:SetJustifyH("LEFT")
    description:SetWordWrap(true)
    local back = button(ui.hintPane, tr("Retour aux propriétés", "Back to properties"), 0, -10, 172, function()
        closeHints()
        if barEditor then barEditor.navigation(true, selected, draft and draft.name) end
    end)
    back:ClearAllPoints()
    back:SetPoint("TOPRIGHT", -14, -10)
    local globalScope, profileScope, refreshHints
    local function settings()
        if profileScope then return addon.ProfileHintSettings(draft, addon.BarLayout.totemBar(draft)) end
        return globalScope and addon.GlobalHints() or addon.HintSettings(draft)
    end
    local function writeProfileHint()
        if rawget(draft, "profileHint") == nil then draft.profileHint = addon.Copy(settings()) end
        return draft.profileHint
    end
    local function inheritHint()
        local global = addon.GlobalHints()
        draft.hint, draft.hintSide, draft.hintOrientation = global.hint, global.hintSide, global.hintOrientation
        draft.hintOverride = true
    end
    local function setHint(key, value)
        if profileScope then
            writeProfileHint()[key] = value
        else
            if not globalScope and not addon.HasHintOverride(draft) then inheritHint() end
            settings()[key] = value
        end
        refreshHints()
        if globalScope then notify(tr("Les changements s’appliquent immédiatement.", "Changes apply immediately.")) end
        refreshPreview()
    end
    local inherited = check(ui.hintPane, tr("Remplacer les réglages globaux", "Override global settings"), 16, -77, function(value)
        if value then inheritHint() else draft.hintOverride = false end
        refreshHints()
        refreshPreview()
    end)
    local hint = check(ui.hintPane, tr("Afficher l’étiquette", "Show label"), 16, -108, function(value)
        if globalScope or profileScope then
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
    local orientation = menu(ui.hintPane, 192, -109, 170, function(root)
        if not ui.hintPane:IsShown() then return end
        for _, choice in ipairs(orientations) do
            radio(root, choice[2], choice[1], orientationValue, function(value)
                setHint("hintOrientation", value)
            end)
        end
    end)
    label(ui.hintPane, tr("Ancre de l’étiquette", "Label anchor"), 16, -143)
    local diagram = ui.hintPane:CreateTexture(nil, "ARTWORK")
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
        marker.control = button(ui.hintPane, "•", marker[2], marker[3], 20, function()
            setHint("hintSide", marker[1])
        end)
        marker.control:SetHeight(19)
    end
    refreshHints = function()
        local current = settings()
        inherited:SetShown(not globalScope and not profileScope)
        inherited:SetChecked(not globalScope and not profileScope and addon.HasHintOverride(draft))
        if profileScope then
            hint:SetChecked(current.hint ~= false)
            hint:SetEnabled(true)
        elseif globalScope then
            hint:SetChecked(current.hint)
            hint:SetEnabled(true)
        else
            hint:SetChecked(addon.GlobalHints().hint and addon.HintVisibleForFrame(draft))
            hint:SetEnabled(not not addon.GlobalHints().hint)
        end
        orientation:SetEnabled(true)
        orientation:OverrideText(orientationValue() == "vertical" and orientations[2][2] or orientations[1][2])
        local side = current.hintSide or "top-start"
        if not addon.hintAnchors[side] then side = "top-start" end
        if profileScope then side = addon.ProfileHintAnchor(draft, side) end
        for _, marker in ipairs(markers) do
            marker.control:SetText(side == marker[1] and "●" or "•")
            marker.control:SetEnabled(not profileScope or addon.ProfileHintAnchor(draft, marker[1]) == marker[1])
        end
        if ui.profileDesign then ui.profileDesign(profileScope) end
    end
    local function openHints(global, profileLabel)
        if profileLabel and not editingFrameDefaults and not addon.BarLayout.totemBar(draft) then return end
        stopFrameCapture()
        closeActivation()
        globalScope, profileScope = global, profileLabel
        framePage = global and "globalHint" or profileLabel and "profileHint" or "frameHint"
        heading:SetText(global and tr("Étiquettes de cadre globales", "Global frame labels")
            or profileScope and tr("Étiquette de profil de totems", "Totem profile label")
            or tr("Étiquette de cadre", "Frame label"))
        description:SetText(profileScope and tr("Affiche le profil de totems actif. L’ancre de l’étiquette de cadre est réservée.",
            "Shows the current totem profile. The frame label’s anchor is reserved.")
            or tr("L’étiquette indique sur quelle touche appuyer pour activer le cadre.",
                "The label shows which key activates the frame."))
        refreshHints()
        ui.form:Hide()
        ui.hintPane:Show()
        refresh()
        if barEditor then barEditor.navigation(true, selected, draft and draft.name) end
        if profileScope then
            inactive = true
            refreshPreview()
        end
    end
    local framePageTitles = function()
        return {
            target=tr("Rattachement","Attachment"),
            geometry=editingFrameDefaults and tr("Dimensions","Size") or tr("Position et dimensions","Position and size"),
            activation=tr("Activation","Activation"), appearance=tr("Apparence","Appearance"),
            frameHint=tr("Étiquette de cadre","Frame label"), profileHint=tr("Étiquette de profil","Totem profile label"),
            globalHint=tr("Étiquettes globales","Global frame labels"), transition=tr("Transition","Transition"),
            display=tr("Niveau d’affichage","Display level"),
        }
    end
    local function showFrameSection(key, reveal)
        name:ClearFocus()
        if key == "frameHint" or key == "profileHint" then
            openHints(false, key == "profileHint")
            return
        end
        closeHints()
        framePage = key or "target"
        refresh()
        refreshPreview()
        ui.form:SetVerticalScroll(0)
        if barEditor then barEditor.navigation(true, selected, draft and draft.name, reveal) end
    end
    ui.sections = menu(config, 0, -81, 177, function(root)
        if not draft then return end
        local titles = framePageTitles()
        local model = addon.BarLayout
        local hasProfile = editingFrameDefaults or model.totemBar(draft)
        for _, key in ipairs({"target","geometry","activation","appearance","frameHint","transition","display","profileHint"}) do
            if (key~="profileHint" or hasProfile) and (key~="activation" or not editingFrameDefaults) then
                root:CreateButton(titles[key], function() showFrameSection(key) end)
            end
        end
        if not editingFrameDefaults and selected and model.hasAssignableBars(draft) then
            root:CreateButton(tr("Assignation des raccourcis","Assign keybindings"), function()
                leaveDraft(function() selectTabNow(assignment,selected) end)
            end)
        end
    end)
    ui.sections:ClearAllPoints()
    ui.sections:SetPoint("TOPRIGHT", -22, -81)
    ui.sections:SetSize(177, 24)
    ui.sections:OverrideText(tr("Rubriques", "Sections"))
    button(config, tr("Étiquettes globales", "Global frame labels"), 200, -4, 202, function() openHints(true) end)
    ui.keyLabel = check(ui.appearance, tr("Afficher l’étiquette de cadre", "Show frame label"), 18, -35, function(value)
        draft.hintVisible = value
        refreshPreview()
    end)
    ui.updateHint = function() ui.keyLabel:SetChecked(not not addon.HintVisibleForFrame(draft))
        ui.keyLabel:SetEnabled(not not addon.GlobalHints().hint) end
    button(ui.appearance, tr("Étiquette de cadre…", "Frame label…"), 312, -35, 245, function() openHints(false) end)
    ui.defaultProfileLabel = button(ui.appearance, tr("Étiquette de profil…", "Totem profile label…"),
        312, -71, 245, function() openHints(false, true) end)

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
    local resetMicroPosition = button(ui.target, tr("Position d’origine", "Original position"), 222, -119, 165, function()
        if InCombatLockdown() then return end
        draft.microPosition = nil
        refreshPreview()
        loadFields()
        refresh()
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
            if draft.kind == "micro" and (key == "x" or key == "y") then
                if InCombatLockdown() then return end
                local geometry = draft.microPosition or addon.GetPanelGeometry(draft) or draft
                draft.microPosition = {x = geometry.x, y = geometry.y}
                draft.microPosition[key] = value
                resetMicroPosition:Enable()
            else
                if key=="width" or key=="height" then
                    draft.manualFit = nil
                    if not editingFrameDefaults then
                        if draft.kind=="owned" and not addon.BarLayout.autoFitEnabled(draft) and not draft.frameSized then
                            local displayed = addon.BarLayout.envelope(draft, draft)
                            draft.width, draft.height = displayed.width, displayed.height
                        end
                        draft.frameSized = true
                    end
                end
                resolveStyle(draft, true)[key] = value
            end
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
            local geometry = draft.kind == "micro"
                and (key == "x" or key == "y" or key == "width" or key == "height")
            local source = geometry and addon.GetPanelGeometry(draft) or resolveStyle(draft)
            if not editingFrameDefaults and draft.kind=="owned" and not addon.BarLayout.autoFitEnabled(draft)
                and (key=="width" or key=="height") then
                source = addon.BarLayout.envelope(draft, draft)
            end
            local value = geometry and draft.microPosition and draft.microPosition[key] or source[key]
            if spec[6] then value = value * spec[6] end
            input:SetText(tostring(value))
            if control.refresh then control.refresh() end
        end
        return control, caption, set, updatePreview
    end

    local function copyFrameValue(parent, x, y, spec, read, set)
        local copy = menu(parent, x, y, 24, function(root)
            local found = false
            for sourceIndex, source in ipairs(layout().panels) do
                if sourceIndex ~= selected then
                    local value = read(source)
                    if value and value >= spec[4] and value <= spec[5] then
                        found = true
                        root:CreateButton(("%s  ·  %g"):format(source.name, value), function() set(value) end)
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
            GameTooltip:SetText(tr("Copier la valeur de %s", "Copy the value of %s"):format(tr(spec[2], spec[3])))
            GameTooltip:Show()
        end)
        copy:HookScript("OnLeave", function() GameTooltip:Hide() end)
        return copy
    end

    local geometryInputs, geometryButtons, geometryLabels = {}, {}, {}
    for index = 1, 4 do
        local spec = fields[index]
        local key, y = spec[1], -10 - (index - 1) * 31
        local control, caption, set = bindNumberOrColor(freeGroup, key, 210, y + 16, 76)
        caption:ClearAllPoints()
        caption:SetPoint("TOPLEFT", freeGroup, "TOPLEFT", 18, y - 5)
        if index == 1 then caption:SetText(tr("Position sur l’axe X", "X position")) end
        if index == 2 then caption:SetText(tr("Position sur l’axe Y", "Y position")) end
        geometryInputs[index] = control.input
        geometryLabels[index] = caption
        local function step(delta)
            local current = parseField(control.input:GetText(), spec) or draft[key]
            set(math.max(spec[4], math.min(spec[5], current + delta)))
        end
        local minus = button(freeGroup, "−", 184, y, 24, function() step(-1) end)
        local plus = button(freeGroup, "+", 297, y, 24, function() step(1) end)
        local copy = copyFrameValue(freeGroup, 328, y, spec, function(source)
            local geometry = addon.GetPanelGeometry(source)
            return geometry and geometry[key]
        end, set)
        geometryButtons[index] = {minus, plus, copy}
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
    do
        local design = CreateFrame("Frame", nil, ui.hintPane)
        design:SetPoint("TOPLEFT", 375, -42)
        design:SetSize(270, 272)
        local activeDesign = false
        local function styleSlot() return activeDesign and "activeStyle" or "defaultStyle" end
        local function inheritedStyle()
            return activeDesign and draft or defaultStyle(draft)
        end
        local function currentStyle()
            return settings()[styleSlot()] or inheritedStyle()
        end
        local function setStyle(key, value)
            local config = writeProfileHint()
            local slot = styleSlot()
            if not config[slot] then
                config[slot] = {}
                addon.CopyStyle(inheritedStyle(), config[slot])
            end
            config[slot][key] = value
            refreshHints()
            refreshPreview()
        end
        local stateMenu = menu(design, 0, 0, 255, function(root)
            for _, entry in ipairs({{false, tr("Style par défaut", "Default style")},
                {true, tr("Style activé", "Activated style")}}) do
                if not entry[1] or addon.HoldLayer(draft) or addon.PanelToggle(draft) then
                    radio(root, entry[2], entry[1], function() return activeDesign end, function(value)
                        activeDesign = value
                        inactive = not value
                        refreshHints()
                        refresh()
                        refreshPreview()
                    end)
                end
            end
        end)
        local overrideStyle = check(design, tr("Personnaliser ce style", "Customize this style"), 0, -30, function(enabled)
            local config = writeProfileHint()
            local slot = styleSlot()
            config[slot] = nil
            if enabled then
                config[slot] = {}
                addon.CopyStyle(inheritedStyle(), config[slot])
            end
            refreshHints()
            refreshPreview()
        end)
        local function styleMenu(x, title, key, choices)
            label(design, title, x, -62)
            local picker = menu(design, x, -80, 126, function(root)
                for _, choice in ipairs(choices) do
                    radio(root, choice[2], choice[1], function() return currentStyle()[key] or "solid" end,
                        function(value) setStyle(key, value) end)
                end
            end)
            return function(value, enabled)
                local caption
                for _, choice in ipairs(choices) do
                    if choice[1] == (value or "solid") then caption = choice[2] end
                end
                picker:OverrideText(caption or choices[1][2])
                picker:SetEnabled(enabled)
            end
        end
        local fillMenu = styleMenu(0, tr("Texture du fond", "Fill texture"), "fillTexture", fillStyles)
        local edgeMenu = styleMenu(132, tr("Texture de bordure", "Border texture"), "borderTexture", borderStyles)
        local function styleField(key, title, x, y, limit, parse, display)
            local input = field(design, title, x, y, 117, limit)
            local function commit()
                local value = parse(input:GetText())
                input:ClearFocus()
                if value ~= nil then setStyle(key, value) else refreshHints() end
            end
            input:SetScript("OnEnterPressed", commit)
            return function(value, enabled)
                if not input:HasFocus() then input:SetText(display(value)) end
                if enabled then input:Enable() else input:Disable() end
            end
        end
        local function hex(raw) return #raw == 6 and raw:match("^%x+$") and raw:upper() or nil end
        local function percent(raw)
            local value = tonumber(raw)
            if value and value >= 0 and value <= 100 then return value / 100 end
        end
        local function showPercent(value) return tostring(math.floor((value or 1) * 100 + .5)) end
        local fill = styleField("fill", tr("Fond (hex) ↵", "Fill (hex) ↵"), 0, -111, 6, hex, tostring)
        local border = styleField("border", tr("Bordure (hex) ↵", "Border (hex) ↵"), 132, -111, 6, hex, tostring)
        local fillAlpha = styleField("fillAlpha", tr("Fond (%) ↵", "Fill (%) ↵"), 0, -159, 3, percent, showPercent)
        local borderAlpha = styleField("borderAlpha", tr("Bordure (%) ↵", "Border (%) ↵"), 132, -159, 3, percent, showPercent)
        local fonts = {{"game",tr("Jeu","Game")},{"chat",tr("Discussion","Chat")},{"numbers",tr("Chiffres","Numbers")}}
        label(design, tr("Police", "Font"), 0, -214)
        local fontMenu = menu(design, 0, -231, 126, function(root)
            for _, choice in ipairs(fonts) do
                radio(root, choice[2], choice[1], function() return settings().font or "game" end,
                    function(value) setHint("font", value) end)
            end
        end)
        local fontSize = field(design, tr("Taille du texte ↵", "Font size ↵"), 132, -214, 117, 2)
        fontSize:SetScript("OnEnterPressed", function(self)
            local value = tonumber(self:GetText())
            self:ClearFocus()
            if value and value >= 8 and value <= 32 then setHint("size", value) else refreshHints() end
        end)
        ui.profileDesign = function(show)
            design:SetShown(not not show)
            if not show then activeDesign = false; return end
            stateMenu:OverrideText(activeDesign and tr("Style activé", "Activated style")
                or tr("Style par défaut", "Default style"))
            local style = currentStyle()
            local enabled = settings()[styleSlot()] ~= nil
            overrideStyle:SetChecked(enabled)
            fillMenu(style.fillTexture, enabled)
            edgeMenu(style.borderTexture, enabled)
            fill(style.fill, enabled)
            border(style.border, enabled)
            fillAlpha(style.fillAlpha, enabled)
            borderAlpha(style.borderAlpha, enabled)
            for _, choice in ipairs(fonts) do
                if (settings().font or "game") == choice[1] then fontMenu:OverrideText(choice[2]) end
            end
            if not fontSize:HasFocus() then fontSize:SetText(tostring(settings().size or 12)) end
        end
    end
    local function hexRGB(hex)
        return tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255,
            tonumber(hex:sub(5, 6), 16) / 255
    end
    local function styleEditor(parent, activeStyle)
        local function column(title, x)
            local panel = CreateFrame("Frame", nil, parent)
            panel:SetSize(301, 184)
            panel:SetPoint("TOPLEFT", x, -48)
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
    local refreshActiveStyle = styleEditor(ui.styles, true)
    button(ui.default, tr("Aperçu par défaut", "Preview default"), 18, -25, 194, function()
        inactive = true
        refreshPreview()
    end)
    button(ui.styles, tr("Aperçu activé", "Preview activated"), 18, -8, 194, function()
        inactive = false
        refreshPreview()
    end)

    do
        local model = addon.BarLayout
        local marginRows = {}
        local function readMargins(panel, geometry)
            local minimumX, minimumY = model.framePadding(panel)
            local actualX, actualY
            if panel.kind=="owned" then actualX, actualY = model.fitMargins(panel, geometry or panel) end
            return actualX or minimumX, actualY or minimumY, minimumX, minimumY
        end
        local function setMargin(index, value, minimum)
            if not draft or InCombatLockdown() or (index==2 and draft.paddingLinked) then return end
            local both = draft.paddingLinked
            local x, y = (both or index==1) and value or nil, (both or index==2) and value or nil
            if not minimum and not editingFrameDefaults and draft.kind=="owned" and model.resizeToPadding(draft, x, y) then
                geometryInputs[3]:SetText(("%g"):format(draft.width))
                geometryInputs[4]:SetText(("%g"):format(draft.height))
            else
                if x then draft.paddingX = x end
                if y then draft.paddingY = y end
                draft.manualFit = nil
                if not minimum then draft.frameSized = nil end
            end
            refreshPreview()
            ui.updateFitMargins(draft)
        end
        local function marginInput(spec, x, y, width, save)
            local input = CreateFrame("EditBox", nil, ui.geometry, "InputBoxTemplate")
            input:SetSize(width, 23)
            input:SetPoint("TOPLEFT", x + 30, y)
            input:SetAutoFocus(false)
            input:SetMaxLetters(9)
            input:SetScript("OnEnterPressed", function(self)
                local value = parseField(self:GetText(), spec)
                self:ClearFocus()
                if value then save(value) end
            end)
            input:SetScript("OnEscapePressed", input.ClearFocus)
            input:SetScript("OnEditFocusLost", function() ui.updateFitMargins(draft) end)
            local function step(delta)
                local value = parseField(input:GetText(), spec)
                if value then save(math.max(spec[4], math.min(spec[5], value + delta))) end
            end
            local minus = button(ui.geometry, "−", x, y, 24, function() step(-1) end)
            local plus = button(ui.geometry, "+", x + width + 35, y, 24, function() step(1) end)
            return input, minus, plus
        end
        for index, key in ipairs({"paddingX", "paddingY"}) do
            local spec = specifications[key]
            local y = -10 - (index + 3) * 31
            local caption = label(ui.geometry, tr(spec[2], spec[3]), 18, y - 5)
            local function saveActual(value) setMargin(index, value, false) end
            local actual, actualMinus, actualPlus = marginInput(spec, 184, y, 76, saveActual)
            local copy = copyFrameValue(ui.geometry, 328, y, spec, function(source)
                return math.max(0, (select(index, readMargins(source))))
            end, saveActual)
            local minimumCaption = label(ui.geometry, tr("Minimum", "Minimum"), 362, y - 5)
            local minimum, minimumMinus, minimumPlus = marginInput(spec, 435, y, 64,
                function(value) setMargin(index, value, true) end)
            marginRows[index] = {actual=actual, minimum=minimum, caption=caption, minimumCaption=minimumCaption,
                buttons={actualMinus, actualPlus, copy, minimumMinus, minimumPlus}}
        end
        local link = button(ui.geometry, "", 568, -150, 64, function()
            if not draft or InCombatLockdown() then return end
            draft.paddingLinked = not draft.paddingLinked
            ui.updateFitMargins(draft)
            updateHeading()
        end)
        function ui.updateFitMargins(panel, geometry)
            if not panel then return end
            local x, y, minX, minY = readMargins(panel, geometry)
            local values = {x, y}
            local minimums = {minX, minY}
            for index, row in ipairs(marginRows) do
                if not row.actual:HasFocus() then row.actual:SetText(("%.1f"):format(math.max(0, values[index]))) end
                if not row.minimum:HasFocus() then row.minimum:SetText(("%g"):format(minimums[index])) end
            end
            local vertical = marginRows[2]
            local enabled = not panel.paddingLinked
            vertical.actual:SetEnabled(enabled)
            vertical.minimum:SetEnabled(enabled)
            for _, control in ipairs(vertical.buttons) do control:SetEnabled(enabled) end
            local r, g, b = 1, .82, 0
            if not enabled then r, g, b = .58, .58, .58 end
            vertical.caption:SetTextColor(r, g, b)
            vertical.minimumCaption:SetTextColor(r, g, b)
            local textShade = enabled and 1 or .65
            vertical.actual:SetTextColor(textShade, textShade, textShade)
            vertical.minimum:SetTextColor(textShade, textShade, textShade)
            link:SetText(panel.paddingLinked and tr("Délier", "Unlink") or tr("Lier", "Link"))
        end
    end
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

    loadFields = function()
        for _, control in ipairs(inputs) do control.load() end
    end

    local override = addon.CreateWorkspaceSwitch(ui.activeStyleToggle, function()
        if not draft or InCombatLockdown() then return end
        local enabled = draft.useDefaultStyle
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
    override:SetPoint("TOPLEFT", 18, -5)
    label(ui.activeStyleToggle, tr("Style activé distinct", "Separate activated style"), 61, -7, "GameFontHighlight")
    name:SetScript("OnTextChanged", function(_, userInput)
        if userInput and draft then
            draft.name = clean(name:GetText())
            refreshPreview()
            if barEditor and selected then barEditor.navigation(true,selected,draft.name) end
        end
    end)

    local copyStyle = menu(ui.default, 400, -25, 225, function(root)
        for index, source in ipairs(layout().panels) do
            if index ~= selected then
                root:CreateButton(source.name, function()
                    inactive = true
                    addon.CopyFrameStyle(source, draft)
                    pendingBarStyles = {}
                    local sources = addon.BarLayout.children(source)
                    for index, target in ipairs(addon.BarLayout.children(draft)) do
                        if sources[index] then
                            local preview = addon.BarLayout.inheritBar(layout(), addon.Copy(target))
                            addon.BarLayout.copyBarStyle(sources[index], preview)
                            pendingBarStyles[target] = preview
                        end
                    end
                    loadFields()
                    refresh()
                    refreshPreview()
                    if next(pendingBarStyles) then
                        notify(tr("Aperçu des styles copié. Enregistre le cadre pour conserver la copie.",
                            "Previewing the copied styles. Save the frame to keep the copy."))
                    end
                end)
            end
        end
    end)
    copyIcon(copyStyle, -17, -4)
    copyStyle:OverrideText(tr("Copier le style depuis…", "Copy style from…"))

    local function invalidField()
        for _, control in ipairs(inputs) do
            local spec = control.spec
            local key = spec[1]
            local geometry = key == "x" or key == "y" or key == "width" or key == "height"
            local editable = draft.kind == "free" or draft.kind == "owned"
                or draft.kind == "micro" and (key == "x" or key == "y")
            if (not geometry or editable and control.input:IsShown()) and control.show()
                and parseField(control.input:GetText(), spec) == nil then
                return spec
            end
        end
    end

    local function savePanel(proceed, approvedHold, approvedBinding)
        if editingFrameDefaults then
            if InCombatLockdown() then return end
            local invalid = invalidField()
            if invalid then
                notify(tr("Valeur invalide pour ", "Invalid value for ") .. tr(invalid[2], invalid[3]))
                return
            end
            local kind = editingFrameDefaults ~= "global" and editingFrameDefaults or nil
            local dimensions = addon.BarLayout.previewFrameDimensions(layout(), kind, draft)
            addon.BarLayout.setFrameDefaults(layout(), kind, addon.BarLayout.frameDefaultsFromDraft(draft))
            for panel in pairs(dimensions) do panel.frameSized, panel.manualFit = true, nil end
            addon.RebuildBars()
            addon.SyncSwitch()
            addon.Refresh()
            updateHeading()
            notify(tr("Propriétés globales des cadres enregistrées.", "Global frame properties saved."))
            if proceed then proceed() end
            return
        end
        local target = draft
        local value = addon.BarLayout.inheritFrame(layout(), addon.Copy(draft))
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
        if hold and hold ~= "unmodified" and rawget(value, "layer") ~= nil
            and (not previous or hold ~= addon.HoldLayer(previous)) then
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
        -- A frame can be saved before its optional toggle shortcut is assigned.
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
        if value.kind == "micro" and value.microPosition then
            for _, panel in ipairs(layout().panels) do panel.microPosition = nil end
        end
        layout().panels[selected] = value
        if pendingBarStyles then
            for _, bar in ipairs(addon.BarLayout.children(value)) do
                if pendingBarStyles[bar] then addon.BarLayout.copyBarStyle(pendingBarStyles[bar], bar) end
            end
        end
        addon.RebuildBars()
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
    ui.inheritStyle = button(config, tr("Hériter du style", "Use inherited style"), 316, -120, 143, function()
        if not draft or InCombatLockdown() then return end
        local target, section = draft, framePage
        local frameLabel = section == "frameHint"
        confirm(frameLabel and tr("Retirer les réglages locaux de cette étiquette ?", "Clear this frame label’s local overrides?")
            or tr("Retirer les réglages locaux de cette apparence ?", "Clear this frame appearance’s local overrides?"), function()
            if draft ~= target or framePage ~= section or InCombatLockdown() then return end
            addon.BarLayout.clearFrameOverrides(draft, section)
            if frameLabel then
                refreshHints()
            else
                inactive = true
                loadFields()
                refresh()
            end
            refreshPreview()
        end)
    end)
    ui.inheritStyle:Hide()
    local remove = button(ui.footer, tr("Supprimer", "Delete"), 225, -5, 115, function()
        local index = selected
        local target = layout().panels[index]
        if not target then return end
        local function deleteFrame(withBars)
            if InCombatLockdown() or layout().panels[index] ~= target then return end
            local bars = addon.BarLayout.children(target)
            if withBars then
                addon.DeleteOwnedBars(bars)
            else
                for _, bar in ipairs(bars) do addon.BarLayout.attach(bar, nil) end
            end
            table.remove(layout().panels, index)
            addon.RebuildBars()
            addon.SyncSwitch()
            pick(math.min(index, #layout().panels))
            addon.Refresh()
        end
        if #addon.BarLayout.children(target) == 0 then
            confirm(tr("Supprimer ce cadre ?", "Delete this frame?"), function() deleteFrame(false) end)
            return
        end
        StaticPopupDialogs.KEYLAYERS_DELETE_FRAME = {
            text = tr("Supprimer aussi les barres liées à « %s » ?", "Also delete the bars linked to “%s”?"),
            button1 = tr("Cadre et barres", "Frame and bars"), button2 = CANCEL,
            button3 = tr("Cadre seul", "Frame only"),
            timeout = 0, whileDead = true, hideOnEscape = true,
            OnAccept = function(dialog) dialog:Hide(); deleteFrame(true) end,
            OnAlt = function(dialog) dialog:Hide(); deleteFrame(false) end,
        }
        StaticPopup_Show("KEYLAYERS_DELETE_FRAME", target.name)
    end)

    refresh = function()
        local panel = layout().panels[selected]
        ui.form:SetShown(draft ~= nil and not ui.hintPane:IsShown())
        ui.footer:SetShown(draft ~= nil)
        ui.empty:SetShown(draft == nil)
        local visualPage = draft ~= nil and (framePage == "appearance" or framePage == "frameHint")
        ui.inheritStyle:SetShown(visualPage)
        local contentTop = visualPage and -149 or -126
        pageBackground:SetPoint("TOPLEFT", 10, contentTop)
        ui.form:SetPoint("TOPLEFT", 10, contentTop)
        ui.hintPane:SetPoint("TOPLEFT", 10, contentTop)
        local titles = framePageTitles()
        ui.categoryTitle:SetText((draft or ui.hintPane:IsShown()) and titles[framePage] or "")
        ui.sections:SetShown(draft ~= nil)
        ui.sections:SetPoint("TOPRIGHT", editingFrameDefaults and -22 or -207, -81)
        if not draft then
            ui.autoFitFrames:Hide()
            autoFitLabel:Hide()
            return
        end
        ui.target:SetShown(framePage=="target" and not editingFrameDefaults)
        ui.templateTarget:SetShown(framePage=="target" and not not editingFrameDefaults)
        ui.activation:SetShown(framePage=="activation")
        ui.appearance:SetShown(framePage=="appearance")
        ui.transition:SetShown(framePage=="transition")
        ui.display:SetShown(framePage=="display")
        if editingFrameDefaults then ui.templateDescription:SetText(ui.templateDescriptions[editingFrameDefaults]) end
        do
            local model = addon.BarLayout
            local global = editingFrameDefaults=="owned"
            local localFrame = not editingFrameDefaults and draft.kind=="owned" and #model.children(draft)>0
            local enabled = global or localFrame and model.singleFrameBar(draft) ~= nil
            ui.autoFitFrames:SetShown(global or not not localFrame)
            autoFitLabel:SetShown(global or not not localFrame)
            ui.autoFitFrames:SetEnabled(not not enabled)
            ui.autoFitFrames:SetAlpha(enabled and 1 or .55)
            autoFitLabel:SetAlpha(enabled and 1 or .55)
            ui.autoFitFrames:SetActive(global and model.autoFitEnabled() or localFrame and model.autoFitEnabled(draft))
        end
        ui.defaultProfileLabel:SetShown(not not editingFrameDefaults)
        ui.newFrame:SetShown(not editingFrameDefaults)
        if ui.linked then ui.linked:SetShown(not editingFrameDefaults) end
        refreshDefaultStyle()
        refreshActiveStyle()
        ui.styles:SetShown(not draft.useDefaultStyle)
        override:SetActive(not draft.useDefaultStyle)
        copyStyle:SetEnabled(not editingFrameDefaults and #layout().panels > (selected and 1 or 0))
        local unavailable = (draft.kind == "bars" or draft.kind:match("^bartender")) and not addon.BarLayout.available()
        kind:OverrideText(unavailable and tr("Rattachement indisponible", "Attachment unavailable")
            or draft.kind == "chat" and chatLabel(draft.chatId) or kinds[draft.kind])
        local hold, toggle = addon.HoldLayer(draft), addon.PanelToggle(draft)
        local key = pendingToggleKey
        if key == nil then key = addon.PanelToggleKey(draft) end
        ui.hold:OverrideText(hold and addon.LayerLabel(hold) or (toggle and modeLabels.none
            or tr("Toujours visible", "Always visible")))
        ui.toggle:OverrideText(toggle and addon.LayerLabel(addon.ToggleModifier(draft)) or modeLabels.none)
        ui.toggle:SetEnabled(not editingFrameDefaults)
        ui.toggleKey:SetEnabled(not editingFrameDefaults and toggle ~= nil)
        for _, option in ipairs(frameVisibility) do
            if option[1] == (draft.visibility or "always") then ui.frameVisibility:OverrideText(option[2]); break end
        end
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
        if unavailable then selectedBars = nil end
        barGroup:SetShown(selectedBars ~= nil)
        local micro = draft.kind == "micro"
        local movable = addon.CanMoveFrame(draft)
        local positioning = not editingFrameDefaults and (not barEditor or not barEditor.isInheritance())
        ui.geometryRow.block:SetShown(framePage=="geometry")
        ui.updateFitMargins(draft)
        ui.moveFrame:SetShown(movable)
        resetMicroPosition:SetShown(micro)
        resetMicroPosition:SetEnabled(micro and draft.microPosition ~= nil)
        for index = 1, 4 do
            local editable = not micro or index <= 2
            local visible = movable and (positioning or index > 2)
            geometryInputs[index]:SetEnabled(editable)
            geometryInputs[index]:SetShown(visible)
            geometryLabels[index]:SetShown(visible)
            for _, control in ipairs(geometryButtons[index]) do
                control:SetEnabled(editable); control:SetShown(visible)
            end
        end
        linkedHelp:SetShown(not selectedBars)
        linkedHelp:SetText(draft.kind=="owned" and draft.bartenderAttachment and #addon.BarLayout.children(draft)==0
            and tr("Cadre Bartender4 conservé. Ajoute des barres KeyLayers ou rattache-les depuis l’arborescence.",
                "Bartender4 frame preserved. Add KeyLayers bars or attach them from the tree.")
            or unavailable and tr("Bartender4 est désactivé. Choisis un autre rattachement.",
            "Bartender4 is disabled. Choose another attachment.") or micro
            and tr("Déplace le cadre en jeu ou règle X et Y. Les dimensions suivent le menu d’icônes.",
                "Move the frame in game or set X and Y. Its size follows the micro menu.")
            or (draft.kind == "free" or draft.kind == "owned")
            and tr("En édition, glisse le cadre pour le déplacer et sa poignée pour le redimensionner.",
                "In edit mode, drag the frame to move it and its handle to resize it.")
            or draft.kind == "chat" and tr("Le cadre suit la fenêtre de tchat sélectionnée.",
                "The frame follows the selected chat window.")
            or tr("Le cadre suit cet élément lorsqu’il est visible.", "The frame follows this element when it is visible."))
        ui.reflow()
        for id, item in ipairs(barChecks) do
            item:SetShown(not unavailable and id <= (addon.barCounts[draft.kind] or 0))
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
        remove:SetShown(not editingFrameDefaults)
        remove:SetEnabled(panel ~= nil)
    end

    pick = function(index, initial, keepDefaultTab)
        stopFrameCapture()
        name:ClearFocus()
        editingFrameDefaults = nil
        local panel = layout().panels[index]
        if selected ~= index then ui.form:SetVerticalScroll(0) end
        pendingToggleKey, pendingBarStyles = nil, nil
        framePage = "target"
        selected = panel and index or nil
        draft = initial or (panel and addon.BarLayout.inheritFrame(layout(), addon.Copy(panel)))
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
        if barEditor and config:IsShown() then barEditor.navigation(true, selected) end
    end

    local function hasPendingChanges()
        if not draft then return false end
        if editingFrameDefaults then
            local kind = editingFrameDefaults ~= "global" and editingFrameDefaults or nil
            return not sameSettings(addon.BarLayout.frameDefaultsFromDraft(draft), addon.BarLayout.frameDefaults(layout(), kind))
                or invalidField() ~= nil
        end
        if not selected or pendingToggleKey ~= nil or (pendingBarStyles and next(pendingBarStyles)) or not sameSettings(draft, layout().panels[selected]) then return true end
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
            details = editingFrameDefaults and tr("Styles hérités", "Inherited styles")
                or (draft.kind == "chat" and chatLabel(draft.chatId) or kinds[draft.kind] or "") .. "  ·  " .. mode
        end
        currentDetails:SetText(details)
        rename:ClearAllPoints()
        rename:SetPoint("TOPLEFT", 26 + math.min(325, currentName:GetStringWidth()), -54)
        rename:SetShown(draft ~= nil and not editingFrameDefaults and not name:IsShown())
        draftStatus:SetText(draft and (not saved and not editingFrameDefaults and tr("Nouveau cadre non enregistré", "Unsaved new frame")
            or hasPendingChanges() and tr("Modifications non enregistrées", "Unsaved changes")) or "")
    end

    leaveDraft = function(proceed)
        stopFrameCapture()
        if not config:IsShown() or not hasPendingChanges() then proceed(); return end
        StaticPopupDialogs.KEYLAYERS_UNSAVED_FRAME = {
            text = "%s", button1 = tr("Enregistrer", "Save"), button2 = CANCEL, button3 = tr("Ignorer", "Discard"),
            timeout = 0, whileDead = true, hideOnEscape = true,
            OnAccept = function(dialog, action) dialog:Hide(); action.save() end,
            OnAlt = function(dialog, action) dialog:Hide(); action.discard() end,
        }
        local saved = layout().panels[selected]
        local title = draft.name ~= "" and draft.name or (saved and saved.name or tr("Nouveau cadre", "New frame"))
        local target = draft
        StaticPopup_Show("KEYLAYERS_UNSAVED_FRAME",
            tr("Enregistrer les modifications de « %s » ?", "Save changes to “%s”?"):format(title), nil, {
                save = function() if draft == target then savePanel(proceed) end end,
                discard = function()
                    if draft ~= target then return end
                    if editingFrameDefaults then
                        draft = nil
                        editingFrameDefaults = nil
                    else pick(selected) end
                    proceed()
                end,
            })
    end

    requestPick = function(index)
        if InCombatLockdown() then return end
        local function isCurrent()
            return config:IsShown() and not editingFrameDefaults and index == (selected or 0) and draft
        end
        local function show()
            if not config:IsShown() then selectTabNow(config) end
            if not isCurrent() then pick(index) end
            if addon.CanMoveFrame(draft) then
                barEditor.showContainers()
                showFrameSection("geometry", true)
            end
        end
        if isCurrent() then show() else leaveDraft(show) end
        return isCurrent()
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

    local function clampGeometry(index, value)
        local spec = fields[index]
        return math.max(spec[4], math.min(spec[5], math.floor(value + .5)))
    end

    local function previewGeometry(index, geometry)
        if not geometry or InCombatLockdown() or not config:IsVisible() or framePage ~= "geometry"
            or not draft or index ~= (selected or 0) then return end
        geometry.paddingX, geometry.paddingY = addon.BarLayout.framePadding(draft)
        ui.updateFitMargins(draft, geometry)
        local values = {geometry.x, geometry.y, geometry.width, geometry.height}
        local fieldCount = draft.kind == "micro" and 2 or 4
        for i = 1, fieldCount do
            local text = tostring(clampGeometry(i, values[i]))
            if geometryInputs[i]:GetText() ~= text then geometryInputs[i]:SetText(text) end
        end
    end

    local function applyGeometry(x, y, width, height)
        if draft.kind == "micro" then
            x, y = clampGeometry(1, x), clampGeometry(2, y)
            draft.microPosition = {x = x, y = y}
            geometryInputs[1]:SetText(tostring(x))
            geometryInputs[2]:SetText(tostring(y))
            resetMicroPosition:Enable()
            refreshPreview()
            return
        end
        local values = {x, y, width, height}
        for index, input in ipairs(geometryInputs) do
            local spec = fields[index]
            local value = index > 2 and draft.manualFit and values[index] or clampGeometry(index, values[index])
            if draft[spec[1]] ~= value then draft[spec[1]] = value end
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
        if barsPage:IsShown() and barEditor then barEditor.refresh() end
        if not value and keybinds then keybinds:Hide() end
        editToggle:SetActive(value)
        if value then
            if not placedForEditing then
                window:ClearAllPoints()
                window:SetPoint("RIGHT", UIParent, "RIGHT", -16, 0)
                placedForEditing = true
            end
            addon.SetEditor({
                current = function()
                    if config:IsShown() and not editingFrameDefaults then return selected, draft end
                end,
                name = function() return clean(name:GetText()) end,
                previewAppearance = function()
                    return config:IsShown() and framePage=="appearance", ui.frameStylePreviews, inactive
                end,
                geometry = applyGeometry,
                previewGeometry = previewGeometry,
                dragPanel = function(index)
                    if config:IsShown() and index == (selected or 0) then return draft end
                    return layout().panels[index]
                end,
                commitGeometry = function(index, x, y, width, height, resize)
                    if InCombatLockdown() then return end
                    local values = {x, y, width, height}
                    local saved = layout().panels[index]
                    if saved and saved.kind == "micro" then
                        for _, panel in ipairs(layout().panels) do panel.microPosition = nil end
                        saved.microPosition = {
                            x = clampGeometry(1, x),
                            y = clampGeometry(2, y),
                        }
                    elseif saved then
                        if resize then saved.manualFit = nil; saved.frameSized = true end
                        for i = 1, 4 do
                            local spec = fields[i]
                            local value = i > 2 and saved.manualFit and values[i] or clampGeometry(i, values[i])
                            if saved[spec[1]] ~= value then saved[spec[1]] = value end
                        end
                    end
                    if config:IsShown() and draft and index == (selected or 0) then
                        if resize then draft.manualFit = nil; draft.frameSized = true end
                        applyGeometry(x, y, width, height)
                    end
                    addon.RebuildBars()
                    addon.Refresh()
                end,
                bars = function(index)
                    leaveDraft(function() selectTabNow(barsPage); barEditor.open(index,nil) end)
                end,
                toggleBar = function(kind, id)
                    if not draft or not addon.barCounts[draft.kind] then return end
                    draft.kind = kind
                    local selectedBars = addon.BarSelection(draft)
                    selectedBars[id] = not selectedBars[id] or nil
                    refresh()
                    refreshPreview()
                end,
                select = requestPick,
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
        if assignment:IsShown() or barsPage:IsShown() then selectTabNow(config) end
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
            addon.BarLayout.syncProvider(layout())
            addon.SyncSwitch(true)
            addon.RestoreFrameToggleKeys()
            local restored = snapshot.neutralKey == nil or addon.AssignNeutralKey(snapshot.neutralKey)
            if addon.PositionMinimapIcon then addon.PositionMinimapIcon() end
            addon.RebuildBars()
            barEditor.open(nil,nil)
            pick(1)
            addon.Refresh()
            notify(restored and tr("Profil chargé.", "Profile loaded.")
                or tr("Profil chargé. La touche Neutre actuelle est conservée, car celle du profil n’a pas pu être assignée.",
                    "Profile loaded. The current neutral key was kept because the profile key could not be assigned."))
        end)
    end)
    barEditor = addon.CreateBarEditor(barsPage, {label=label, button=button, menu=menu, radio=radio, check=check, field=field, confirm=confirm}, {
        editing=function() return editing end,
        startEditing=function() setEditing(true) end,
        parent=window, global=ui.globalPage, placeNew=placeNew,
        openGlobal=function(section)
            local function show()
                barEditor.openGlobalSection(section)
                if not ui.globalPage:IsShown() then selectTabNow(ui.globalPage) end
            end
            if ui.globalPage:IsShown() then show() else leaveDraft(show) end
        end,
        isGlobal=function() return ui.globalPage:IsShown() end,
        viewChanged=function()
            if config:IsShown() then refresh(); refreshPreview() end
            if barsPage:IsShown() then barEditor.refresh()
            else barEditor.navigation(true, config:IsShown() and selected or assignedFrame) end
        end,
        openFrameDefaults=function(kind, section)
            local scope = kind or "global"
            local function show()
                selectTabNow(config)
                editingFrameDefaults, selected = scope, nil
                draft = addon.BarLayout.frameDefaultsDraft(layout(), kind)
                draft.kind, draft.x, draft.y = "free", 0, 0
                local titles = {free=tr("Cadre libre", "Free frame"), owned=tr("Cadre KeyLayers", "KeyLayers frame"),
                    blizzard=tr("Cadre Blizzard", "Blizzard frame")}
                draft.name = titles[kind] or tr("Propriétés globales des conteneurs", "Global container properties")
                name:SetText(draft.name)
                inactive = true
                pendingToggleKey, pendingBarStyles = nil, nil
                ui.form:SetVerticalScroll(0)
                loadFields()
                refresh()
                refreshPreview()
                barEditor.navigation(true)
                showFrameSection(section or "target")
            end
            if config:IsShown() and editingFrameDefaults == scope then
                showFrameSection(section or "target")
            else
                leaveDraft(show)
            end
        end,
        bindingFrame=function() return assignedFrame end,
        openBindings=function(index) leaveDraft(function() selectTabNow(assignment,index) end) end,
        newFrame=newFrame,
        isFrame=function() return config:IsShown() end,
        frameTemplate=function() return config:IsShown() and editingFrameDefaults or nil, framePage end,
        frameSection=function(index) return config:IsShown() and index==selected and framePage or nil end,
        openBar=function(index,id,after)
            leaveDraft(function()
                selectTabNow(barsPage)
                if barsPage:IsShown() then barEditor.open(index,id); if after then after() end end
            end)
        end,
        openFrame=function(index,section)
            local function show()
                if not config:IsShown() then selectTabNow(config) end
                if selected ~= index or not draft then pick(index) end
                if barEditor then barEditor.navigation(true,selected,draft and draft.name) end
                showFrameSection(section)
            end
            if config:IsShown() and selected==index then show() else leaveDraft(show) end
        end,
    })
    ui.linked = button(config, tr("Gérer des barres", "Manage bars"), 0, -81, 177, function()
        local function manage()
            selectTabNow(barsPage)
            if barsPage:IsShown() then barEditor.openFrameBars(selected) end
        end
        local frame = selected and layout().panels[selected]
        if draft and (not frame or draft.kind~=frame.kind) then
            savePanel(manage)
        else leaveDraft(manage) end
    end)
    ui.linked:ClearAllPoints()
    ui.linked:SetPoint("TOPRIGHT", -22, -81)
    refreshProfiles()
    selectTabNow(ui.globalPage)
    pick(nil)
    window:SetScript("OnShow", function()
        escape:Show()
        refreshPreview()
    end)
    window:SetScript("OnHide", function()
        escape:Hide()
        stopFrameCapture()
        if assignment:IsShown() or barsPage:IsShown() then selectTabNow(config) end
        closeHints()
        closeActivation()
        if editing then setEditing(false) end
        addon.SetDraftBarStyles(nil)
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
