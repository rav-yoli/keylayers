local addonName, addon = ...
local tr = addon.Translate
local defaultMinimapAngle = math.rad(245)
local labels = {
    base = tr("Base", "Base"), ctrl = tr("Ctrl", "Ctrl"), maj = tr("Maj", "Shift"), alt = "Alt",
    always = tr("Toujours", "Always"), never = tr("Aucun", "None"),
}
function addon.LayerLabel(layer)
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
    root:CreateRadio(caption, function() return current() == value end,
        function() select(value) end)
end

local function confirm(message, accept)
    StaticPopupDialogs.BARTENDERGLOW_CONFIRM = {
        text = message, button1 = ACCEPT, button2 = CANCEL, timeout = 0,
        whileDead = true, hideOnEscape = true,
        OnAccept = function(_, action) action() end,
    }
    StaticPopup_Show("BARTENDERGLOW_CONFIRM", nil, nil, accept)
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
    header:SetScript("OnDragStart", function() window:StartMoving() end)
    header:SetScript("OnDragStop", function() window:StopMovingOrSizing() end)
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
    table.insert(UISpecialFrames, window:GetName())

    local config = CreateFrame("Frame", nil, window)
    config:SetPoint("TOPLEFT", 0, -70)
    config:SetPoint("BOTTOMRIGHT")
    local profiles = CreateFrame("Frame", nil, window)
    profiles:SetAllPoints(config)
    profiles:Hide()
    local status = label(window, "", 18, -725, "GameFontHighlightSmall")
    status:SetPoint("RIGHT", window, "RIGHT", -18, 0)
    status:SetJustifyH("LEFT")
    local function notify(message) status:SetText(message or "") end

    local selected, draft, profile
    local refresh, pick, setEditing, closeHints, openActivation, closeActivation, cancelNeutralCapture
    local editing, inactive = false, false
    local styleKeys = {}
    for _, key in ipairs(addon.styleKeys) do styleKeys[key] = true end
    local function fieldTarget(key, panel)
        panel = panel or draft
        return inactive and styleKeys[key] and panel.inactiveStyle or panel
    end
    local function layout() return BartenderGlowLayout end
    local function refreshPreview()
        local panel = window:IsShown() and config:IsShown() and draft or nil
        addon.SetDraftPreview(selected, panel, inactive)
    end
    local showConfigTab, showProfilesTab
    local function selectTab(page)
        closeHints()
        closeActivation()
        if page ~= config and editing then setEditing(false) end
        config:SetShown(page == config)
        profiles:SetShown(page == profiles)
        showConfigTab(page == config, true)
        showProfilesTab(page == profiles, true)
        notify()
        refreshPreview()
    end
    local tabDivider = window:CreateTexture(nil, "BACKGROUND")
    tabDivider:SetPoint("TOPLEFT", 10, -68)
    tabDivider:SetPoint("TOPRIGHT", -10, -68)
    tabDivider:SetHeight(1)
    tabDivider:SetColorTexture(0.29, 0.42, 0.54, 0.8)
    showConfigTab = tab(window, tr("Configuration", "Settings"), 18, -39, 130, function() selectTab(config) end)
    showProfilesTab = tab(window, tr("Profils", "Profiles"), 152, -39, 110, function() selectTab(profiles) end)
    showConfigTab(true, true)
    showProfilesTab(false, true)

    local editToggle = button(window, tr("Mode Édition", "Edit mode"), 510, -39, 152, function()
        setEditing(not editing)
    end)

    button(config, tr("Déclencheurs", "Triggers"), 18, -4, 173, function()
        openActivation()
    end)
    label(config, tr("Alt + F4 à éviter (ferme le jeu)", "Avoid Alt + F4 (closes the game)"),
        448, -11, "GameFontHighlightSmall")
    section(config, tr("Cadre en cours d’édition", "Frame being edited"), -31, 50)
    local panels = menu(config, 18, -55, 256, function(root)
        for index, panel in ipairs(layout().panels) do
            radio(root, panel.name, index, function() return selected end, pick)
        end
    end)
    button(config, tr("Nouveau cadre", "New frame"), 284, -53, 130, function()
        if not editing then setEditing(true) end
        local panel = addon.NewPanel(tr("Nouveau cadre", "New frame"))
        if editing then
            local space = UIParent:GetWidth() - window:GetWidth() * window:GetScale()
            panel.x = math.floor((space - UIParent:GetWidth()) / 2)
        end
        pick(nil, panel)
        refreshPreview()
    end)
    local frameScope = label(config, tr("Les réglages ci-dessous s’appliquent à ce cadre.", "The settings below apply to this frame."),
        429, -49, "GameFontHighlightSmall")
    frameScope:SetWidth(229)
    frameScope:SetWordWrap(true)
    frameScope:SetJustifyH("LEFT")
    local editor = CreateFrame("Frame", nil, config)
    editor:SetPoint("TOPLEFT", 0, -86)
    editor:SetPoint("BOTTOMRIGHT")
    section(editor, tr("Cadre", "Frame"), -1, 68)
    section(editor, tr("Apprentissage", "Learning"), -78, 57)
    section(editor, tr("Disposition", "Layout"), -144, 79)
    section(editor, tr("Habillage", "Appearance"), -232, 221)
    section(editor, tr("Transition et niveau", "Transition and level"), -462, 66)
    local name = field(editor, tr("Nom du cadre", "Frame name"), 18, -27, 232)
    local kinds = addon.kindLabels
    local function chatLabel(id)
        return tr("Tchat %d", "Chat %d"):format(id)
    end
    local kind = menu(editor, 272, -42, 160, function(root)
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
    local layer = button(editor, "", 446, -42, 216, function()
        openActivation()
    end)
    label(editor, tr("Type de cadre", "Frame type"), 272, -27)
    label(editor, tr("Activation", "Activation"), 446, -27)
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
    label(activationPopup, tr("Choisis le mode et la touche de chaque cadre.", "Choose the mode and shortcut for each frame."),
        16, -43, "GameFontHighlightSmall")
    label(activationPopup, tr("Maintien : surbrillance pendant l’appui, sans redirection des raccourcis.",
        "Hold: highlights while pressed, without remapping shortcuts."), 16, -60, "GameFontHighlightSmall")
    label(activationPopup, tr("Interrupteur : verrouille le cadre et redirige ses raccourcis.",
        "Toggle: locks the frame and redirects its shortcuts."), 16, -76, "GameFontHighlightSmall")
    local activationClose = CreateFrame("Button", nil, activationPopup, "UIPanelCloseButton")
    activationClose:SetPoint("TOPRIGHT", -3, -3)
    activationClose:SetScript("OnClick", closeActivation)
    label(activationPopup, tr("Cadre", "Frame"), 17, -102)
    label(activationPopup, tr("Mode", "Mode"), 256, -102)
    label(activationPopup, tr("Touche", "Key"), 407, -102)
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
    local neutralHelp = label(activationPopup, tr(
        "Assigne la touche ici ou cherche « Revenir au neutre » dans les raccourcis de KeyLayers.",
        "Assign it here or find Return to neutral in the KeyLayers key bindings."),
        16, -444, "GameFontHighlightSmall")
    neutralHelp:SetWidth(570)
    neutralHelp:SetWordWrap(true)
    label(activationPopup, tr("Pour le cadre BASE, choisis le mode Interrupteur et la touche Base (neutre).",
        "For the BASE frame, choose Toggle mode and the Base (neutral) key."),
        16, -470, "GameFontHighlightSmall")
    local capture = CreateFrame("Frame", nil, activationPopup)
    capture:SetAllPoints(activationPopup)
    local capturing = false
    local neutralControl, redrawActivation
    local advanced = CreateFrame("Frame", nil, activationPopup, "BackdropTemplate")
    advanced:SetSize(490, 173)
    advanced:SetPoint("CENTER")
    advanced:SetFrameLevel(activationPopup:GetFrameLevel() + 20)
    advanced:EnableMouse(true)
    advanced:SetBackdrop({
        bgFile = [[Interface\Buttons\WHITE8X8]],
        edgeFile = [[Interface\Buttons\WHITE8X8]], edgeSize = 1,
    })
    advanced:SetBackdropColor(0.07, 0.10, 0.14, 1)
    advanced:SetBackdropBorderColor(0.42, 0.56, 0.70, 1)
    advanced:Hide()
    local advancedTitle = tr("Options avancées", "Advanced options")
    label(advanced, advancedTitle, 16, -16, "GameFontNormalLarge")
    local advancedClose = CreateFrame("Button", nil, advanced, "UIPanelCloseButton")
    advancedClose:SetPoint("TOPRIGHT", -3, -3)
    advancedClose:SetScript("OnClick", function() advanced:Hide() end)
    local holdEnabled = check(advanced, tr("Appui bref ou prolongé", "Tap or hold"), 16, -43, function(enabled)
        layout().timedHoldEnabled = enabled
        addon.ResetTimedHold()
    end)
    local sensitivity = field(advanced, tr("Sensibilité du maintien", "Hold sensitivity"), 16, -82, 70, 4)
    sensitivity:SetNumeric(true)
    label(advanced, "ms", 101, -101, "GameFontHighlightSmall")
    local holdHelp = label(advanced, tr(
        "Ce paramètre définit la durée d’appui à partir de laquelle l’interrupteur passe en mode Maintien.",
        "This setting determines how long you need to press a toggle for it to count as a hold."),
        16, -136, "GameFontHighlightSmall")
    holdHelp:SetWidth(452)
    holdHelp:SetWordWrap(true)
    sensitivity:SetScript("OnEditFocusLost", function(self)
        local settings = layout()
        settings.timedHoldSensitivity = addon.HoldSensitivity(tonumber(self:GetText()) or settings.timedHoldSensitivity)
        self:SetText(tostring(settings.timedHoldSensitivity))
        addon.ResetTimedHold()
    end)
    button(activationPopup, advancedTitle, 395, -18, 161, function()
        cancelNeutralCapture()
        holdEnabled:SetChecked(not not layout().timedHoldEnabled)
        sensitivity:SetText(tostring(addon.HoldSensitivity(layout().timedHoldSensitivity)))
        advanced:Show()
    end)
    local function refreshNeutralKey()
        local key = addon.NeutralKey()
        neutralControl:SetText(key and (GetBindingText and GetBindingText(key, "KEY_") or key) or tr("Assigner la touche Neutre…", "Assign the neutral key…"))
    end
    cancelNeutralCapture = function()
        if not capturing then return end
        capturing = false
        capture:EnableKeyboard(false)
        refreshNeutralKey()
    end
    activationPopup:SetScript("OnHide", function()
        cancelNeutralCapture()
        advanced:Hide()
    end)
    neutralControl = button(activationPopup, "", 270, -409, 250, function()
        if InCombatLockdown() then
            popupStatus:SetText(tr("Modifie les raccourcis hors combat.", "Change shortcuts out of combat."))
            return
        end
        capturing = true
        capture:EnableKeyboard(true)
        capture:SetPropagateKeyboardInput(false)
        neutralControl:SetText(tr("Appuie sur une touche…", "Press a key…"))
        popupStatus:SetText(tr("Échap annule. Choisis une touche libre.", "Escape cancels. Choose an unused key."))
    end)
    capture:SetScript("OnKeyDown", function(_, key)
        if not capturing then return end
        if key == "ESCAPE" then
            cancelNeutralCapture()
            popupStatus:SetText("")
            return
        end
        if key:match("^[LR]CTRL$") or key:match("^[LR]SHIFT$") or key:match("^[LR]ALT$") then return end
        if IsAltKeyDown() then key = "ALT-" .. key end
        if IsShiftKeyDown() then key = "SHIFT-" .. key end
        if IsControlKeyDown() then key = "CTRL-" .. key end
        if key:match("ALT%-F4$") then
            popupStatus:SetText(tr("Alt + F4 à éviter (ferme le jeu)", "Avoid Alt + F4 (closes the game)"))
            return
        end
        local ok, reason = addon.AssignNeutralKey(key)
        if ok then
            cancelNeutralCapture()
            popupStatus:SetText(tr("Raccourci enregistré.", "Shortcut saved."))
            redrawActivation()
        elseif reason == "occupied" then
            popupStatus:SetText(tr("Cette touche est déjà utilisée. Choisis-en une autre.", "This key is already in use. Choose another."))
        else
            cancelNeutralCapture()
            popupStatus:SetText(reason == "combat"
                and tr("Modifie les raccourcis hors combat.", "Change shortcuts out of combat.")
                or tr("Cette touche ne peut pas être assignée.", "This key cannot be assigned."))
        end
    end)

    local modeLabels = {
        none = tr("Aucune", "None"),
        hold = tr("Maintien", "Hold"),
        latch = tr("Interrupteur", "Toggle"),
    }
    local rows = {}
    local function targetFor(index)
        if draft and (index == selected or index == 0) then return draft end
        return layout().panels[index]
    end
    local function keyAvailable(index, mode, key)
        if key == "base" and mode ~= "latch" then return false end
        if mode ~= "latch" then return true end
        if key == "never" or key == "always" then return false end
        for otherIndex in ipairs(layout().panels) do
            local other = targetFor(otherIndex)
            if otherIndex ~= index and addon.ActivationMode(other) == "latch" and other.layer == key then
                return false
            end
        end
        return index == 0 or selected ~= nil or not draft
            or addon.ActivationMode(draft) ~= "latch" or draft.layer ~= key
    end
    local function setActivation(index, mode, key, acknowledged)
        if InCombatLockdown() then
            popupStatus:SetText(tr("Modifie les raccourcis hors combat.", "Change shortcuts out of combat."))
            return
        end
        if not keyAvailable(index, mode, key) then
            popupStatus:SetText(tr("Cette touche est déjà utilisée par un autre interrupteur.",
                "Another switch already uses this shortcut."))
            return
        end
        if mode == "latch" and not acknowledged and not (BartenderGlowNotices and BartenderGlowNotices.switch) then
            closeActivation()
            confirm(tr(
                "Interrupteur verrouille le cadre et redirige temporairement ses touches d’action. Tes raccourcis enregistrés dans WoW et Bartender4 restent intacts.",
                "Toggle locks the frame and temporarily redirects its action keys. Your saved WoW and Bartender4 bindings stay intact."),
                function()
                    BartenderGlowNotices = BartenderGlowNotices or {}
                    BartenderGlowNotices.switch = true
                    openActivation()
                    setActivation(index, mode, key, true)
                end)
            return
        end
        local target = targetFor(index)
        target.activationMode, target.layer = mode, key
        local saved = layout().panels[index]
        if saved then
            saved.activationMode, saved.layer = mode, key
            addon.SyncSwitch(true)
        end
        popupStatus:SetText("")
        redrawActivation()
        refresh()
        refreshPreview()
    end
    local function activationKeyLabel(key)
        return key == "base" and tr("Base (neutre)", "Base (neutral)") or addon.LayerLabel(key)
    end
    local function makeActivationRow(position)
        local row = CreateFrame("Frame", nil, content)
        row:SetSize(550, 32)
        row:SetPoint("TOPLEFT", 0, -(position - 1) * 32)
        row.caption = label(row, "", 3, -8, "GameFontHighlight")
        row.caption:SetWidth(220)
        row.caption:SetJustifyH("LEFT")
        row.caption:SetWordWrap(false)
        row.mode = menu(row, 241, -2, 136, function(root)
            if not activationPopup:IsShown() then return end
            for _, mode in ipairs({"none", "hold", "latch"}) do
                radio(root, modeLabels[mode], mode, function()
                    return addon.ActivationMode(targetFor(row.index))
                end, function(value)
                    local key = targetFor(row.index).layer
                    if value == "none" then key = "never"
                    elseif key == "always" or key == "never" or not keyAvailable(row.index, value, key) then
                        key = nil
                        for _, candidate in ipairs(addon.layers) do
                            if keyAvailable(row.index, value, candidate) then key = candidate; break end
                        end
                    end
                    if key then setActivation(row.index, value, key)
                    else popupStatus:SetText(tr("Aucune touche disponible.", "No shortcut available.")) end
                end)
            end
        end)
        row.key = menu(row, 392, -2, 155, function(root)
            if not activationPopup:IsShown() then return end
            local target = targetFor(row.index)
            local mode = addon.ActivationMode(target)
            if mode == "none" then return end
            for _, key in ipairs(addon.layers) do
                if mode == "latch" or key ~= "base" then
                    local option = root:CreateRadio(activationKeyLabel(key), function() return target.layer == key end,
                        function() setActivation(row.index, mode, key) end)
                    if not keyAvailable(row.index, mode, key) then option:SetEnabled(false) end
                end
            end
        end)
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
            local mode = addon.ActivationMode(target)
            row.caption:SetText(target.name)
            row.mode:OverrideText(modeLabels[mode])
            local keyText = mode == "none" and "—" or activationKeyLabel(target.layer)
            if mode ~= "none" and target.layer == "base" then
                local key = addon.NeutralKey()
                if key then keyText = keyText .. " · " .. (GetBindingText and GetBindingText(key, "KEY_") or key) end
            end
            row.key:OverrideText(keyText)
            row.key:SetEnabled(mode ~= "none")
            row:Show()
        end
        for position = total + 1, #rows do rows[position]:Hide() end
        content:SetHeight(math.max(1, total * 32))
        if total == 0 then popupStatus:SetText(tr("Crée un cadre pour commencer.", "Create a frame to get started.")) end
    end
    openActivation = function()
        popupStatus:SetText("")
        closeHints()
        activationPopup:Show()
        refreshNeutralKey()
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
            local saved = layout().panels[selected]
            if saved then saved.hintVisible = value end
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
        globalScope = global
        heading:SetText(global and tr("Apprentissage global", "Global learning settings")
            or tr("Apprentissage du cadre", "Frame learning settings"))
        refreshHints()
        hintPopup:Show()
    end
    button(config, tr("Onglet d’apprentissage", "Learning tab"), 200, -4, 202, function() openHints(true) end)
    button(editor, tr("Réglages du cadre…", "Frame settings…"), 18, -102, 190, function() openHints(false) end)

    local barGroup = CreateFrame("Frame", nil, editor)
    barGroup:SetAllPoints(editor)
    label(barGroup, tr("Le cadre comprend les barres suivantes :", "This frame includes these bars:"), 18, -167)
    label(barGroup, tr("En édition, clique aussi sur les numéros au-dessus des barres.", "In edit mode, you can also click the numbers over the bars."),
        294, -167, "GameFontHighlightSmall")
    local barChecks, barCaptions = {}, {}
    for id = 1, 15 do
        barChecks[id], barCaptions[id] = check(barGroup, tostring(id), 18 + (id - 1) * 43, -193, function(value)
            addon.BarSelection(draft)[id] = value or nil
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

    local linkedHelp = label(editor, "", 18, -173)
    linkedHelp:SetPoint("RIGHT", editor, "RIGHT", -18, 0)
    linkedHelp:SetJustifyH("LEFT")
    local freeGroup = CreateFrame("Frame", nil, editor)
    freeGroup:SetAllPoints(editor)
    label(editor, tr("Fond", "Fill"), 18, -282)
    label(editor, tr("Bordure", "Border"), 336, -282)
    local divider = editor:CreateTexture(nil, "ARTWORK")
    divider:SetPoint("TOPLEFT", 324, -282)
    divider:SetSize(1, 156)
    divider:SetColorTexture(0.38, 0.48, 0.58, 0.6)
    local inputs, captions, positions = {}, {}, {}
    for index, spec in ipairs(fields) do
        local key = spec[1]
        local parent, column
        if index <= 4 then
            parent, column = freeGroup, index - 1
        elseif index == 5 then
            parent, column = editor, 0
        else
            parent, column = editor, (index - 6) % 4
        end
        local y = -306
        if parent == freeGroup then y = -173
        elseif key == "padding" then y = -402
        elseif key == "thickness" then y, column = -402, 2
        elseif key == "depth" or key == "linger" or key == "fade" then y = -486 end
        local x = 18 + column * 159
        inputs[key], captions[key] = field(parent, tr(spec[2], spec[3]), x, y, 126, 9)
        positions[key] = {x = x, y = y}
    end

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

    local styleControls, syncing = {}, false
    local function updateControl(key)
        if styleControls[key] then styleControls[key]() end
    end

    local function setStyle(key, value, text)
        fieldTarget(key)[key] = value
        inputs[key]:SetText(text or tostring(value))
        updateControl(key)
        refreshPreview()
    end

    for index = 1, 4 do
        local spec = fields[index]
        local key = spec[1]
        local position = positions[key]
        inputs[key]:SetWidth(98)
        local title = tr(spec[2], spec[3])
        local copy = menu(freeGroup, position.x + 108, position.y - 15, 40, function(root)
            local found = false
            for sourceIndex, source in ipairs(layout().panels) do
                if sourceIndex ~= selected then
                    local geometry = addon.GetPanelGeometry(source)
                    local value = geometry and geometry[key]
                    if value and value >= spec[4] and value <= spec[5] then
                        found = true
                        root:CreateButton(("%s  ·  %s"):format(source.name, tostring(value)), function()
                            setStyle(key, value)
                        end)
                    end
                end
            end
            if not found then
                root:CreateButton(tr("Aucun cadre source disponible", "No source frame available")):SetEnabled(false)
            end
        end)
        copy:OverrideText(" ")
        copyIcon(copy, 5, -4)
        copy:HookScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(tr("Copier la valeur de %s", "Copy the value of %s"):format(title))
            GameTooltip:Show()
        end)
        copy:HookScript("OnLeave", function() GameTooltip:Hide() end)
    end

    local function placeInput(key, offset, width)
        local input, position = inputs[key], positions[key]
        input:ClearAllPoints()
        input:SetPoint("TOPLEFT", editor, "TOPLEFT", position.x + offset, position.y - 16)
        input:SetWidth(width)
        return position.x, position.y
    end

    local function hexRGB(hex)
        return tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255,
            tonumber(hex:sub(5, 6), 16) / 255
    end

    for _, key in ipairs({"fill", "border"}) do
        local x, y = placeInput(key, 5, 89)
        local swatch = button(editor, "", x + 99, y - 16, 42, function()
            local target = fieldTarget(key)
            local original = target[key]
            local r, g, b = hexRGB(original)
            local function apply(hex)
                if draft and fieldTarget(key) == target then setStyle(key, hex) end
            end
            ColorPickerFrame:SetupColorPickerAndShow({
                r = r, g = g, b = b,
                swatchFunc = function()
                    local red, green, blue = ColorPickerFrame:GetColorRGB()
                    apply(("%02X%02X%02X"):format(math.floor(red * 255 + 0.5),
                        math.floor(green * 255 + 0.5), math.floor(blue * 255 + 0.5)))
                end,
                cancelFunc = function() apply(original) end,
            })
        end)
        local color = swatch:CreateTexture(nil, "ARTWORK")
        color:SetPoint("TOPLEFT", 5, -5)
        color:SetPoint("BOTTOMRIGHT", -5, 5)
        styleControls[key] = function()
            local style = fieldTarget(key)
            local r, g, b = hexRGB(style[key])
            color:SetColorTexture(r, g, b, 1)
            local textures = key == "fill" and addon.fillTextures or addon.borderTextures
            local solid = textures[style[key .. "Texture"]] == nil
            if not solid then
                inputs[key]:ClearFocus()
                inputs[key]:SetText(style[key])
            end
            inputs[key]:SetShown(solid)
            captions[key]:SetShown(solid)
            swatch:SetShown(solid)
        end
    end

    local function sliderControl(key, maximum, multiplier)
        local x, y = placeInput(key, 104, 38)
        local slider = CreateFrame("Slider", nil, editor)
        slider:SetOrientation("HORIZONTAL")
        slider:SetSize(89, 20)
        slider:SetPoint("TOPLEFT", editor, "TOPLEFT", x + 5, y - 17)
        slider:SetMinMaxValues(0, maximum)
        slider:SetValueStep(1)
        slider:SetObeyStepOnDrag(true)
        slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
        local track = slider:CreateTexture(nil, "BACKGROUND")
        track:SetPoint("LEFT", 3, 0)
        track:SetPoint("RIGHT", -3, 0)
        track:SetHeight(4)
        track:SetColorTexture(0.34, 0.44, 0.54, 1)
        slider:SetScript("OnValueChanged", function(_, value)
            if syncing or not draft then return end
            local step = math.floor(value + 0.5)
            setStyle(key, step / multiplier, tostring(step))
        end)
        styleControls[key] = function()
            local style = fieldTarget(key)
            if key == "thickness" then
                local solid = addon.borderTextures[style.borderTexture] == nil
                if not solid then
                    inputs[key]:ClearFocus()
                    inputs[key]:SetText(tostring(style.thickness))
                end
                inputs[key]:SetShown(solid)
                captions[key]:SetShown(solid)
                slider:SetShown(solid)
            end
            syncing = true
            slider:SetValue(style[key] * multiplier)
            syncing = false
        end
    end

    sliderControl("fillAlpha", 100, 100)
    sliderControl("borderAlpha", 100, 100)
    sliderControl("thickness", 32, 1)

    local levelX, levelY = placeInput("depth", 49, 48)
    local function stepLevel(delta)
        setStyle("depth", math.max(0, math.min(32, draft.depth + delta)))
    end
    button(editor, "−", levelX + 5, levelY - 16, 34, function() stepLevel(-1) end)
    button(editor, "+", levelX + 106, levelY - 16, 34, function() stepLevel(1) end)

    local geometryFields = {"x", "y", "width", "height"}
    for _, spec in ipairs(fields) do
        local key = spec[1]
        inputs[key]:SetScript("OnTextChanged", function(input, userInput)
            if not userInput or not draft then return end
            local value = parseField(input:GetText(), spec)
            if value == nil then return end
            fieldTarget(key)[key] = value
            updateControl(key)
            refreshPreview()
        end)
    end
    name:SetScript("OnTextChanged", function(_, userInput)
        if userInput then
            local caption = clean(name:GetText())
            panels:OverrideText(caption ~= "" and caption or draft.name)
            refreshPreview()
        end
    end)

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
    local borderOnTop = check(editor, tr("Par-dessus tout", "Draw on top"), 497, -416, function(value)
        fieldTarget("borderOnTop").borderOnTop = value
        refreshPreview()
    end)

    local function textureMenu(key, styles, x, title)
        local function current() return fieldTarget(key)[key] or "solid" end
        label(editor, title, x, -352)
        local picker = menu(editor, x, -368, 220, function(root)
            for _, style in ipairs(styles) do
                radio(root, style[2], style[1], current, function(value)
                    fieldTarget(key)[key] = value
                    refresh()
                    refreshPreview()
                end)
            end
        end)
        return function()
            for _, style in ipairs(styles) do
                if style[1] == current() then picker:OverrideText(style[2]); return end
            end
            picker:OverrideText(styles[1][2])
        end
    end
    local refreshFill = textureMenu("fillTexture", fillStyles, 18, tr("Texture de fond", "Fill texture"))
    local refreshBorder = textureMenu("borderTexture", borderStyles, 336, tr("Texture de bordure", "Border texture"))

    local function loadFields()
        for _, spec in ipairs(fields) do
            local value = fieldTarget(spec[1])[spec[1]]
            if spec[6] then value = value * spec[6] end
            inputs[spec[1]]:SetText(tostring(value))
        end
    end

    local function switchStyle(showDefault)
        if showDefault and not draft.inactiveStyle and not draft.useDefaultStyle then
            draft.inactiveStyle = {}
            addon.CopyStyle(draft, draft.inactiveStyle)
            draft.inactiveStyle.fillAlpha = 0
            draft.inactiveStyle.borderAlpha = 0
        end
        inactive = showDefault
        loadFields()
        refresh()
        refreshPreview()
    end

    local showDefaultTab = tab(editor, tr("Défaut", "Default"), 160, -243, 120, function()
        switchStyle(true)
    end)
    local showActiveTab = tab(editor, tr("Activé", "Activated"), 284, -243, 120, function()
        switchStyle(false)
    end)
    local override = check(editor, tr("Style activé distinct", "Separate activated style"), 430, -243, function(enabled)
        if enabled and not draft.inactiveStyle then
            draft.inactiveStyle = {}
            addon.CopyStyle(draft, draft.inactiveStyle)
        end
        draft.useDefaultStyle = not enabled
        switchStyle(not enabled)
    end)

    local copyStyle = menu(editor, 330, -545, 207, function(root)
        for index, source in ipairs(layout().panels) do
            if index ~= selected then
                root:CreateButton(source.name, function()
                    local copyToDefault = draft.useDefaultStyle or addon.ActivationMode(draft) == "none"
                    local sourceHasActivatedStyle = addon.ActivationMode(source) ~= "none" and not source.useDefaultStyle
                    if copyToDefault then inactive = true end
                    local sourceStyle = source
                    if not sourceHasActivatedStyle or (inactive and not copyToDefault) then
                        sourceStyle = source.inactiveStyle or source
                    end
                    addon.CopyStyle(sourceStyle, fieldTarget("fill"))
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

    local function savePanel()
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
        for index, spec in ipairs(fields) do
            local key = spec[1]
            if index > 5 or (index <= 4 and value.kind == "free") or (index == 5 and value.kind ~= "free") then
                local parsed = parseField(inputs[key]:GetText(), spec)
                if not parsed then
                    notify(tr("Valeur invalide pour ", "Invalid value for ") .. tr(spec[2], spec[3]))
                    return
                end
                fieldTarget(key, value)[key] = parsed
            end
        end
        selected = selected or #layout().panels + 1
        layout().panels[selected] = value
        addon.SyncSwitch()
        pick(selected, nil, inactive)
        addon.Refresh()
        notify(tr("Cadre enregistré.", "Frame saved."))
    end

    button(editor, tr("Enregistrer le cadre", "Save frame"), 18, -545, 158, savePanel)
    local remove = button(editor, tr("Supprimer", "Delete"), 184, -545, 105, function()
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
        local caption = draft and clean(name:GetText())
        panels:OverrideText(draft and (caption ~= "" and caption or draft.name) or tr("Sélectionner un cadre", "Select a frame"))
        frameScope:SetShown(draft ~= nil)
        editor:SetShown(draft ~= nil)
        if not draft then return end
        refreshFill()
        refreshBorder()
        borderOnTop:SetChecked(fieldTarget("borderOnTop").borderOnTop ~= false)
        showDefaultTab(inactive or draft.useDefaultStyle, true)
        showActiveTab(not inactive and not draft.useDefaultStyle, not draft.useDefaultStyle)
        override:SetChecked(not draft.useDefaultStyle)
        copyStyle:SetEnabled(#layout().panels > (selected and 1 or 0))
        for key in pairs(styleControls) do updateControl(key) end
        kind:OverrideText(draft.kind == "chat" and chatLabel(draft.chatId) or kinds[draft.kind])
        local mode = addon.ActivationMode(draft)
        layer:SetText(mode == "none" and modeLabels.none or modeLabels[mode] .. " · " .. addon.LayerLabel(draft.layer))
        local selectedBars = addon.BarSelection(draft)
        barGroup:SetShown(selectedBars ~= nil)
        freeGroup:SetShown(draft.kind == "free")
        linkedHelp:SetShown(not selectedBars and draft.kind ~= "free")
        linkedHelp:SetText(draft.kind == "chat"
            and tr("Le cadre suit la fenêtre de tchat sélectionnée.", "The frame follows the selected chat window.")
            or tr("Le cadre suit cet élément lorsqu’il est visible.", "The frame follows this element when it is visible."))
        for id, item in ipairs(barChecks) do
            item:SetShown(id <= (addon.barCounts[draft.kind] or 0))
            item:SetChecked(selectedBars and selectedBars[id])
            local caption = barCaptions[id]
            caption:SetText((addon.BarLabel(draft.kind, id)))
            item:SetHitRectInsets(0, -caption:GetStringWidth(), 0, 0)
        end
        remove:SetEnabled(panel ~= nil)
    end

    pick = function(index, initial, keepDefaultTab)
        local panel = layout().panels[index]
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

    local function applyGeometry(x, y, width, height)
        local values = {x, y, width, height}
        for index, key in ipairs(geometryFields) do
            local spec = fields[index]
            local value = math.floor(values[index] + 0.5)
            value = math.max(spec[4], math.min(spec[5], value))
            draft[key] = value
            inputs[key]:SetText(tostring(value))
        end
        refreshPreview()
    end

    setEditing = function(value)
        if value and InCombatLockdown() then
            notify(tr("Mode Édition indisponible en combat.", "Edit mode is unavailable in combat."))
            return
        end
        editing = value
        editToggle:SetText(value and tr("Quitter l’édition", "Exit edit mode") or tr("Mode Édition", "Edit mode"))
        if value then
            window:ClearAllPoints()
            window:SetPoint("RIGHT", UIParent, "RIGHT", -16, 0)
            addon.SetEditor({
                current = function() return selected, draft end,
                name = function() return clean(name:GetText()) end,
                geometry = applyGeometry,
                toggleBar = function(kind, id)
                    if not draft then pick(nil, addon.NewPanel(tr("Nouveau cadre", "New frame"))) end
                    draft.kind = kind
                    local selectedBars = addon.BarSelection(draft)
                    selectedBars[id] = not selectedBars[id] or nil
                    refresh()
                    refreshPreview()
                end,
                select = function(index)
                    if index ~= (selected or 0) then pick(index) end
                    notify(draft and draft.kind == "bars"
                        and tr("Déplace les barres dans Bartender4 pour ajuster ce cadre.",
                            "Move the bars in Bartender4 to adjust this frame.")
                        or draft and draft.kind ~= "free"
                            and tr("Le cadre suit sa cible. Déplace la cible pour ajuster le cadre.",
                                "This frame follows its target. Move the target to adjust the frame.")
                        or tr("Glisse le cadre ou sa poignée, puis enregistre.", "Drag the frame or its handle, then save."))
                    return draft
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
        cancelNeutralCapture()
        if editing then setEditing(false) end
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
            local snapshot = addon.Copy(layout())
            snapshot.minimapAngle = snapshot.minimapAngle or defaultMinimapAngle
            snapshot.neutralKey = addon.NeutralKey() or false
            BartenderGlowProfiles[value] = snapshot
            profile = value
            profileName:SetText(value)
            refreshProfiles()
            notify(tr("Profil enregistré.", "Profile saved."))
        end
        if BartenderGlowProfiles[value] then
            confirm(tr("Remplacer ce profil par la configuration actuelle ?",
                "Replace this profile with the current settings?"), save)
        else
            save()
        end
    end)
    label(profiles, tr("Profils partagés entre personnages", "Profiles shared across characters"), 18, -79)
    profileMenu = menu(profiles, 18, -98, 242, function(root)
        local names = {}
        for value in pairs(BartenderGlowProfiles) do names[#names + 1] = value end
        table.sort(names)
        for _, value in ipairs(names) do
            radio(root, value, value, function() return profile end, function(selection)
                profile = selection
                refreshProfiles()
            end)
        end
    end)
    load = button(profiles, tr("Charger", "Load"), 272, -98, 124, function()
        local snapshot = BartenderGlowProfiles[profile]
        if not snapshot then return end
        confirm(tr("Appliquer ce profil à ce personnage ?", "Apply this profile to this character?"), function()
            if InCombatLockdown() then
                notify(tr("Modifie les raccourcis hors combat.", "Change shortcuts out of combat."))
                return
            end
            local minimapAngle = layout().minimapAngle
            BartenderGlowLayout = addon.Copy(snapshot)
            BartenderGlowLayout.minimapAngle = snapshot.minimapAngle or minimapAngle
            BartenderGlowLayout.neutralKey = nil
            addon.MigrateActivation(layout())
            addon.SyncSwitch(true)
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
    window:SetScript("OnShow", refreshPreview)
    window:SetScript("OnHide", function()
        closeHints()
        closeActivation()
        if editing then setEditing(false) end
        addon.SetDraftPreview(nil, nil)
    end)
    return window
end

function addon.InstallOptions()
    local window
    local function open()
        if not window then window = buildWindow()
        else window:Show() end
    end
    local function toggle()
        if window and window:IsShown() then window:Hide()
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
    categoryPanel.name = addon.title
    label(categoryPanel, addon.title .. "  v" .. addon.version, 16, -16, "GameFontNormalLarge")
    button(categoryPanel, tr("Ouvrir KeyLayers", "Open KeyLayers"), 16, -49, 165, open)
    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        Settings.RegisterAddOnCategory(Settings.RegisterCanvasLayoutCategory(categoryPanel, addon.title))
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(categoryPanel)
    end
    if not Minimap then return end
    local icon = CreateFrame("Button", "BartenderGlowMinimapButton", Minimap)
    icon:SetSize(31, 31)
    icon:SetFrameStrata("MEDIUM")
    icon:SetFrameLevel(Minimap:GetFrameLevel() + 9)

    local emblem = icon:CreateTexture(nil, "ARTWORK")
    emblem:SetTexture([[Interface\AddOns\]] .. addonName .. [[\Media\Minimap.tga]])
    emblem:SetAllPoints(icon)

    local highlight = icon:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetTexture([[Interface\Minimap\UI-Minimap-ZoomButton-Highlight]])
    highlight:SetBlendMode("ADD")
    highlight:SetSize(31, 31)
    highlight:SetPoint("CENTER")
    local function position()
        local angle = BartenderGlowLayout.minimapAngle or defaultMinimapAngle
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
                BartenderGlowLayout.minimapAngle = math.atan2(y / scale - cy, x / scale - cx)
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
