local _, addon = ...
local managed, labels, cachedKeys = {}, {}, {}
local artwork
local suspended = false

local function restore(button, state)
    if state.native then state.native:SetAlpha(state.alpha) end
    if labels[button] then labels[button].label:Hide() end
    managed[button] = nil
end

function addon.SetGameplayHotkeysSuspended(value)
    suspended = value
    if value then
        for button, state in pairs(managed) do restore(button, state) end
    end
end

function addon.InvalidateGameplayHotkeys()
    wipe(cachedKeys)
end

local function matchingKey(mask, ...)
    for index = 1, select("#", ...) do
        local key = select(index, ...)
        if key and key ~= "" then
            local modifiers, plain = addon.SplitBinding(key)
            if modifiers == mask then return plain end
        end
    end
end

local function actionKey(button, kind, id, slot, prefix)
    local byPrefix = cachedKeys[button]
    if not byPrefix then
        byPrefix = {}
        cachedKeys[button] = byPrefix
    end
    if byPrefix[prefix] ~= nil then return byPrefix[prefix] or nil end
    local mask = addon.SplitBinding(prefix .. "1")
    local key
    if kind == "bars" then
        local name = button:GetName()
        if name then
            key = matchingKey(mask, GetBindingKey("CLICK " .. name .. ":Keybind"))
                or matchingKey(mask, GetBindingKey("CLICK " .. name .. ":LeftButton"))
        end
    end
    local command = addon.NativeBarBinding(kind, id, slot)
    if command and not key then
        local context = C_KeyBindings and C_KeyBindings.GetBindingContextForAction
            and C_KeyBindings.GetBindingContextForAction(command)
        key = matchingKey(mask, GetBindingKey(command, nil, context))
    end
    byPrefix[prefix] = key and (GetBindingText and GetBindingText(key) or key) or false
    return byPrefix[prefix] or nil
end

addon.hotkeyFonts = {
    {id = "game", object = "GameFontHighlightSmall"},
    {id = "chat", object = "ChatFontNormal"},
    {id = "numbers", object = "NumberFontNormalSmall"},
}

function addon.ApplyHotkeyStyle(label, style)
    local fontObject = GameFontHighlightSmall
    for _, option in ipairs(addon.hotkeyFonts) do
        if style and style.font == option.id then
            fontObject = _G[option.object] or fontObject
            break
        end
    end
    label:SetFontObject(fontObject)
    local file, size, flags = fontObject:GetFont()
    if file then label:SetFont(file, style and style.size or size, flags) end
    local color = style and style.color
    if color then
        label:SetTextColor(color[1], color[2], color[3], 1)
    else
        local r, g, b, a = fontObject:GetTextColor()
        label:SetTextColor(r, g, b, a)
    end
end

local function showKey(button, key, style)
    local entry = labels[button]
    local label = entry and entry.label
    if not key or not button:IsVisible() then
        if label then label:Hide() end
        return
    end
    if not label then
        if not artwork then
            artwork = CreateFrame("Frame", nil, UIParent)
            artwork:SetFrameStrata("HIGH")
            artwork:EnableMouse(false)
        end
        label = artwork:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        label:SetPoint("TOPRIGHT", button, "TOPRIGHT", -2, -2)
        label:SetShadowOffset(1, -1)
        entry = {label = label}
        labels[button] = entry
    end
    if entry.style ~= (style or false) then
        addon.ApplyHotkeyStyle(label, style)
        entry.style = style or false
    end
    if label:GetText() ~= key then label:SetText(key) end
    label:Show()
end

function addon.UpdateGameplayHotkeys(activePanels)
    local layout = KeyLayersCharLayout
    if not layout.activeHotkeysOnly or suspended then
        for button, state in pairs(managed) do restore(button, state) end
        return
    end

    for _, state in pairs(managed) do state.present, state.key = false, nil end
    for _, panel in ipairs(layout.panels) do
        local layer = addon.PanelKeyLayer(panel)
        local prefix = layer and addon.BindingPrefix(layer)
        local ids = prefix and addon.BarSelection(panel)
        for id = 1, ids and addon.barCounts[panel.kind] or 0 do
            if ids[id] then
                for slot = 1, 12 do
                    local button = addon.BarActionButton(panel.kind, id, slot)
                    if button then
                        local state = managed[button]
                        if not state then
                            local name = button:GetName()
                            local native = button.HotKey or (name and _G[name .. "HotKey"])
                            state = {native = native, alpha = native and native:GetAlpha()}
                            managed[button] = state
                        end
                        state.present = true
                        if not state.key and activePanels[panel] and button:IsVisible() then
                            state.key = actionKey(button, panel.kind, id, slot, prefix)
                        end
                    end
                end
            end
        end
    end
    for button, state in pairs(managed) do
        if state.present then
            if state.native and state.native:GetAlpha() ~= 0 then
                state.alpha = state.native:GetAlpha()
                state.native:SetAlpha(0)
            end
            showKey(button, state.key, layout.activeHotkeyStyle)
        else
            restore(button, state)
        end
    end
end

function addon.CreateHotkeyStylePage(page, ui)
    local tr = addon.Translate
    local default = tr("Par défaut", "Default")
    local fontNames = {
        game = default,
        chat = tr("Police de discussion", "Chat font"),
        numbers = tr("Police des chiffres", "Number font"),
    }
    local refresh
    local function changeStyle(key, value)
        local style = addon.Copy(KeyLayersCharLayout.activeHotkeyStyle or {})
        style[key] = value
        KeyLayersCharLayout.activeHotkeyStyle = next(style) and style or nil
        refresh()
        addon.Refresh()
    end

    ui.label(page, tr("Style des raccourcis", "Keybinding style"), 18, -14, "GameFontNormalLarge")
    local enabled = ui.check(page, tr("Afficher uniquement les raccourcis des cadres actifs",
        "Show keybindings only on active frames"), 18, -51, function(value)
        KeyLayersCharLayout.activeHotkeysOnly = value or nil
        refresh()
        addon.Refresh()
    end)
    local explanation = ui.label(page, tr("Ce style s’applique aux touches affichées sur les barres actives quand l’option est cochée.",
        "This style applies to key labels on active bars when the option is checked."), 18, -88, "GameFontHighlightSmall")
    explanation:SetWidth(644)
    explanation:SetJustifyH("LEFT")
    explanation:SetWordWrap(true)

    ui.label(page, tr("Police", "Font"), 18, -137)
    local fontMenu = ui.menu(page, 18, -157, 196, function(root)
        for _, font in ipairs(addon.hotkeyFonts) do
            ui.radio(root, fontNames[font.id], font.id, function()
                return (KeyLayersCharLayout.activeHotkeyStyle or {}).font or "game"
            end, function(value)
                changeStyle("font", value ~= "game" and value or nil)
            end)
        end
    end)

    ui.label(page, tr("Taille du texte", "Text size"), 243, -137)
    local sizeMenu = ui.menu(page, 243, -157, 132, function(root)
        local function current() return (KeyLayersCharLayout.activeHotkeyStyle or {}).size or 0 end
        local function selectSize(size) changeStyle("size", size ~= 0 and size or nil) end
        ui.radio(root, default, 0, current, selectSize)
        for size = 8, 28, 2 do ui.radio(root, tostring(size), size, current, selectSize) end
    end)

    ui.label(page, tr("Couleur du texte", "Text color"), 404, -137)
    local colorButton = ui.button(page, tr("Choisir…", "Choose…"), 404, -157, 116, function()
        local layout = KeyLayersCharLayout
        local color = (layout.activeHotkeyStyle or {}).color
        local r, g, b = GameFontHighlightSmall:GetTextColor()
        if color then r, g, b = unpack(color) end
        ColorPickerFrame:SetupColorPickerAndShow({
            r = r, g = g, b = b,
            swatchFunc = function()
                if KeyLayersCharLayout == layout then changeStyle("color", {ColorPickerFrame:GetColorRGB()}) end
            end,
            cancelFunc = function()
                if KeyLayersCharLayout == layout then changeStyle("color", color) end
            end,
        })
    end)
    local swatch = colorButton:CreateTexture(nil, "ARTWORK")
    swatch:SetSize(13, 13)
    swatch:SetPoint("RIGHT", -8, 0)
    ui.button(page, tr("Réinitialiser", "Reset"), 530, -157, 132, function()
        KeyLayersCharLayout.activeHotkeyStyle = nil
        refresh()
        addon.Refresh()
    end)

    ui.label(page, tr("Aperçu du raccourci", "Key label preview"), 18, -224)
    local sampleButton = CreateFrame("Frame", nil, page, "BackdropTemplate")
    sampleButton:SetSize(82, 54)
    sampleButton:SetPoint("TOPLEFT", 18, -249)
    sampleButton:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1})
    sampleButton:SetBackdropColor(0.09, 0.11, 0.15, 1)
    sampleButton:SetBackdropBorderColor(0.29, 0.42, 0.54, 1)
    local sample = sampleButton:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sample:SetPoint("TOPRIGHT", -4, -4)
    sample:SetShadowOffset(1, -1)
    sample:SetText(GetBindingText and GetBindingText("4") or "4")

    refresh = function()
        local style = KeyLayersCharLayout.activeHotkeyStyle
        enabled:SetChecked(not not KeyLayersCharLayout.activeHotkeysOnly)
        fontMenu:OverrideText(style and fontNames[style.font] or default)
        sizeMenu:OverrideText(style and style.size and tostring(style.size) or default)
        addon.ApplyHotkeyStyle(sample, style)
        swatch:SetColorTexture(sample:GetTextColor())
    end
    return refresh
end
