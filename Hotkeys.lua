local _, addon = ...
local managed, labels, cachedKeys = {}, {}, {}
local suspended, previewingStyle = false, false

local function restore(button, state)
    if state.native then state.native:SetAlpha(state.alpha) end
    if labels[button] then labels[button].label:Hide() end
    managed[button] = nil
end

function addon.SetGameplayHotkeysSuspended(value)
    suspended = value
    if value and not previewingStyle then
        for button, state in pairs(managed) do restore(button, state) end
    end
end

function addon.InvalidateGameplayHotkeys()
    wipe(cachedKeys)
end

local function displayMode(layout)
    return layout.hotkeyDisplayMode or (layout.activeHotkeysOnly and "active" or "native")
end

local function matchingKey(mask, ...)
    for index = 1, select("#", ...) do
        local key = select(index, ...)
        if key and key ~= "" then
            local modifiers = addon.SplitBinding(key)
            if mask == nil or modifiers == mask then return key end
        end
    end
end

local function actionKey(button, kind, id, slot, prefix)
    local byPrefix = cachedKeys[button]
    if not byPrefix then
        byPrefix = {}
        cachedKeys[button] = byPrefix
    end
    local cacheKey = prefix or false
    if byPrefix[cacheKey] ~= nil then return byPrefix[cacheKey] or nil end
    local mask = prefix and addon.SplitBinding(prefix .. "1")
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
    if not key and kind=="owned" and button.nativeKey then
        key=matchingKey(mask,button.nativeKey)
    end
    byPrefix[cacheKey] = key or false
    return key
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
        local artwork = CreateFrame("Frame", nil, UIParent)
        artwork:SetFrameStrata("HIGH")
        artwork:SetAllPoints(button)
        artwork:EnableMouse(false)
        label = artwork:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        label:SetPoint("TOPRIGHT", button, "TOPRIGHT", -2, -2)
        label:SetShadowOffset(1, -1)
        entry = {label = label, artwork = artwork}
        labels[button] = entry
    end
    if entry.style ~= (style or false) then
        addon.ApplyHotkeyStyle(label, style)
        entry.style = style or false
    end
    if label:GetText() ~= key then label:SetText(key) end
    label:Show()
    addon.SetMapAwareStrata(entry.artwork, "HIGH", button)
end

function addon.UpdateGameplayHotkeys(activePanels)
    local layout = KeyLayersCharLayout
    local mode = displayMode(layout)
    if mode == "native" or (suspended and not previewingStyle) then
        for button, state in pairs(managed) do restore(button, state) end
        return
    end

    for _, state in pairs(managed) do state.present, state.key = false, nil end
    for _, panel in ipairs(layout.panels) do
        local layer = addon.PanelKeyLayer(panel, activePanels[panel] == "toggle")
        local prefix = layer and addon.BindingPrefix(layer)
        local function include(kind, ids, count)
        for id = 1, ids and count or 0 do
            if ids[id] then
                for slot = 1, kind=="owned" and 36 or 12 do
                    local button = addon.BarActionButton(kind, id, slot)
                    if button and (kind~="owned" or not button.model or button.model.keys~=false) then
                        local state = managed[button]
                        if not state then
                            local name = button:GetName()
                            local native = button.HotKey or (name and _G[name .. "HotKey"])
                            state = {native = native, alpha = native and native:GetAlpha()}
                            managed[button] = state
                        end
                        state.present = true
                        if not state.key and button:IsVisible() and (mode == "all" or activePanels[panel]) then
                            local key = actionKey(button, kind, id, slot, prefix)
                            if mode == "all" then
                                key = key or actionKey(button, kind, id, slot)
                            elseif key then
                                local _, plain = addon.SplitBinding(key)
                                key = plain
                            end
                            if key then
                                local caption = GetBindingText and GetBindingText(key) or key
                                if mode == "all" then
                                    caption = caption:gsub("^CTRL%-", "C-"):gsub("%-CTRL%-", "-C-")
                                    caption = caption:gsub("^MAJ%-", "S-"):gsub("%-MAJ%-", "-S-")
                                    caption = caption:gsub("^SHIFT%-", "S-"):gsub("%-SHIFT%-", "-S-")
                                end
                                state.key = caption
                            end
                        end
                    end
                end
            end
        end
        end
        if prefix or mode == "all" or activePanels[panel] then
            for _,kind in ipairs({"bars","blizzard"}) do
                include(kind, addon.BarLayout.links(panel,kind), addon.barCounts[kind])
            end
            include("owned", addon.AttachedActionIds(panel,true), 12)
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

function addon.CreateHotkeyModeMenu(page,ui,x,y)
    local tr=addon.Translate
    local captions={native=tr("Affichage de WoW ou Bartender4","WoW or Bartender4 display"),
        all=tr("Tous les cadres liés","All linked frames"),active=tr("Cadres actifs uniquement","Active frames only")}
    local menu
    local function refresh() menu:OverrideText(captions[displayMode(KeyLayersCharLayout)]) end
    menu=ui.menu(page,x,y,300,function(root)
        for _,mode in ipairs({"native","all","active"}) do
            ui.radio(root,captions[mode],mode,function() return displayMode(KeyLayersCharLayout) end,function(value)
                KeyLayersCharLayout.hotkeyDisplayMode=value~="native" and value or nil
                KeyLayersCharLayout.activeHotkeysOnly=nil
                refresh()
                addon.Refresh()
            end)
        end
    end)
    return refresh
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
    ui.label(page, tr("Police", "Font"), 18, -50)
    local fontMenu = ui.menu(page, 18, -70, 196, function(root)
        for _, font in ipairs(addon.hotkeyFonts) do
            ui.radio(root, fontNames[font.id], font.id, function()
                return (KeyLayersCharLayout.activeHotkeyStyle or {}).font or "game"
            end, function(value)
                changeStyle("font", value ~= "game" and value or nil)
            end)
        end
    end)

    ui.label(page, tr("Taille du texte", "Text size"), 243, -50)
    local sizeMenu = ui.menu(page, 243, -70, 132, function(root)
        local function current() return (KeyLayersCharLayout.activeHotkeyStyle or {}).size or 0 end
        local function selectSize(size) changeStyle("size", size ~= 0 and size or nil) end
        ui.radio(root, default, 0, current, selectSize)
        for size = 8, 28, 2 do ui.radio(root, tostring(size), size, current, selectSize) end
    end)

    ui.label(page, tr("Couleur du texte", "Text color"), 404, -50)
    local colorButton = ui.button(page, tr("Choisir…", "Choose…"), 404, -70, 116, function()
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
    ui.button(page, tr("Réinitialiser", "Reset"), 530, -70, 102, function()
        KeyLayersCharLayout.activeHotkeyStyle = nil
        refresh()
        addon.Refresh()
    end)

    ui.label(page, tr("Aperçu du raccourci", "Key label preview"), 18, -122)
    local sampleButton = CreateFrame("Frame", nil, page, "BackdropTemplate")
    sampleButton:SetSize(82, 54)
    sampleButton:SetPoint("TOPLEFT", 18, -147)
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
        fontMenu:OverrideText(style and fontNames[style.font] or default)
        sizeMenu:OverrideText(style and style.size and tostring(style.size) or default)
        addon.ApplyHotkeyStyle(sample, style)
        swatch:SetColorTexture(sample:GetTextColor())
    end
    -- The Style page uses the real action bars as its preview. Capture mode still
    -- suspends the gameplay labels as soon as the page is hidden.
    page:HookScript("OnShow", function()
        previewingStyle = true
        addon.Refresh()
    end)
    page:HookScript("OnHide", function()
        previewingStyle = false
        addon.Refresh()
    end)
    return refresh
end
