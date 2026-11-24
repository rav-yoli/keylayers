local _, addon = ...
local tr = addon.Translate

local prefixes = {
    ctrl = "CTRL-", maj = "SHIFT-", alt = "ALT-", ["ctrl+maj"] = "CTRL-SHIFT-",
    ["ctrl+alt"] = "ALT-CTRL-", ["maj+alt"] = "ALT-SHIFT-", ["ctrl+maj+alt"] = "ALT-CTRL-SHIFT-",
}
function addon.BindingPrefix(layer)
    if layer == "base" or layer == "unmodified" then return "" end
    return prefixes[layer]
end

local modifiers = {CTRL = true, SHIFT = true, ALT = true}
local function isModifier(key)
    return modifiers[key] or ((key:sub(1, 1) == "L" or key:sub(1, 1) == "R") and modifiers[key:sub(2)])
end

local function canUsePrefix(prefix, selfCast)
    return not modifiers[selfCast] or not prefix:find(selfCast .. "-", 1, true)
end

local function nativeCommands()
    local commands = {}
    for index = 1, GetNumBindings() do
        local command = GetBinding(index)
        if command then commands[command] = true end
    end
    return commands
end

local function eligibleBars(commands)
    local bases, targets, seenBase = {}, {}, {}
    local selfCast = GetModifiedClick and GetModifiedClick("SELFCAST")
    for _, panel in ipairs(KeyLayersCharLayout.panels) do
        local layer = addon.HoldLayer(panel) or addon.PanelToggle(panel)
        local base = layer == "unmodified" or layer == "base"
        local prefix = prefixes[layer]
        local bars = addon.BarSelection(panel)
        if bars and (base or prefix) then
            local group = {}
            for id = 1, addon.barCounts[panel.kind] do
                if bars[id] then
                    local number, barLabel = addon.BarLabel(panel.kind, id)
                    local entry = {
                        id = id, number = tonumber(number) or math.huge,
                        label = panel.name .. " · " .. barLabel, prefix = prefix, slots = {},
                    }
                    for slot = 1, 12 do
                        local action = addon.BarActionButton(panel.kind, id, slot)
                        local command = addon.NativeBarBinding(panel.kind, id, slot)
                        if action and action:IsShown() and commands[command] then
                            local context = C_KeyBindings and C_KeyBindings.GetBindingContextForAction
                                and C_KeyBindings.GetBindingContextForAction(command)
                            entry.slots[slot] = {command = command, button = action, context = context}
                        end
                    end
                    if not next(entry.slots) then
                        entry.blocked = tr("aucune commande native", "no native binding")
                    end
                    group[#group + 1] = entry
                end
            end
            table.sort(group, function(a, b)
                if a.number == b.number then return a.id < b.id end
                return a.number < b.number
            end)
            for index, entry in ipairs(group) do
                if base then
                    local key = panel.kind .. ":" .. entry.id
                    if not seenBase[key] then
                        seenBase[key] = true
                        bases[#bases + 1] = entry
                    end
                else
                    entry.sourceIndex = index
                    entry.label = entry.label .. " (" .. addon.LayerLabel(layer) .. ")"
                    if not canUsePrefix(prefix, selfCast) then
                        entry.blocked = tr("auto-incantation", "self-cast")
                    end
                    targets[#targets + 1] = entry
                end
            end
        end
    end
    for _, target in ipairs(targets) do
        local source = bases[target.sourceIndex]
        if not target.blocked and (not source or source.blocked) then
            target.blocked = tr("pas de barre Base correspondante", "no matching Base bar")
        end
    end
    return bases, targets
end

local function baseKey(...)
    for index = 1, select("#", ...) do
        local key = select(index, ...)
        local prefix = key and key:match("^([^-]+)%-")
        if key and key ~= "" and not modifiers[prefix] then return key end
    end
end

local function keyForAction(action)
    return baseKey(GetBindingKey(action.command, nil, action.context))
end

local function bindingName(command)
    return _G["BINDING_NAME_" .. command] or command
end

local function keyName(key)
    return GetBindingText and GetBindingText(key) or key
end

local function previewChanges(bases, targets, selected, pending, approved)
    local rows, byKey, baseRows = {}, {}, {}
    local selfCast = GetModifiedClick and GetModifiedClick("SELFCAST")
    local neutral = {}
    for _, key in ipairs({addon.NeutralKey()}) do neutral[key] = true end

    local function add(bar, slot, key, blocked)
        local action = bar.slots[slot]
        local row = {key = key, label = bar.label .. " #" .. slot, action = action, blocked = blocked}
        if blocked then return row end
        if not action then
            row.blocked = tr("aucune commande native", "no native binding")
            return row
        end
        local earlier = byKey[key]
        if earlier then
            if earlier.action.command == action.command then return end
            earlier.blocked = tr("plusieurs boutons demandent cette touche", "multiple buttons request this key")
            row.blocked = earlier.blocked
            return row
        end
        byKey[key] = row

        row.previous = GetBindingAction(key, false, action.context) or ""
        row.current = row.previous == action.command
        if not row.current and neutral[key] then
            row.blocked = tr("touche de retour à Base", "return-to-Base key")
        elseif not row.current and row.previous ~= "" then
            row.conflict = true
            local choice = approved[key]
            row.approved = choice and choice.from == row.previous and choice.to == action.command
        end
        return row
    end

    for index, source in ipairs(bases) do
        local sourceRows = {}
        baseRows[index] = sourceRows
        for slot = 1, 12 do
            local action = source.slots[slot]
            local staged = pending[source] and pending[source][slot]
            local key = action and (staged or keyForAction(action))
            if key then
                local row = add(source, slot, key)
                sourceRows[slot] = row or byKey[key]
                if staged and row then rows[#rows + 1] = row end
            end
        end
    end
    for _, target in ipairs(targets) do
        local sourceRows = baseRows[target.sourceIndex]
        if selected[target] and sourceRows then
            for slot = 1, 12 do
                local base = sourceRows[slot]
                if base then
                    local blocked
                    if not canUsePrefix(target.prefix, selfCast) then
                        blocked = tr("auto-incantation", "self-cast")
                    elseif base.key == "F4" and target.prefix:find("ALT-", 1, true) then
                        blocked = tr("Alt + F4 ferme le jeu", "Alt + F4 closes the game")
                    elseif base.blocked or (base.conflict and not base.approved) then
                        blocked = tr("raccourci Base à résoudre", "resolve the Base shortcut")
                    end
                    local row = add(target, slot, target.prefix .. base.key, blocked)
                    if row then rows[#rows + 1] = row end
                end
            end
        end
    end
    return rows
end

local function saveChanges(rows)
    if InCombatLockdown() then return false end
    local completed = {}
    for _, row in ipairs(rows) do
        if not row.blocked and not row.current and (not row.conflict or row.approved) then
            if not SetBinding(row.key, row.action.command, row.action.context) then
                for index = #completed, 1, -1 do
                    local old = completed[index]
                    SetBinding(old.key, old.previous ~= "" and old.previous or nil, old.action.context)
                end
                return false
            end
            completed[#completed + 1] = row
        end
    end
    if #completed > 0 then
        SaveBindings(GetCurrentBindingSet())
        addon.SyncSwitch()
    end
    return true, #completed
end

local function openGameBindings()
    if Settings and Settings.OpenToCategory and Settings.KEYBINDINGS_CATEGORY_ID then
        Settings.OpenToCategory(Settings.KEYBINDINGS_CATEGORY_ID)
        return true
    end
    if ShowUIPanel and KeyBindingFrame then
        ShowUIPanel(KeyBindingFrame)
        return true
    end
    if GameMenuButtonKeybindings and GameMenuButtonKeybindings:IsEnabled() then
        GameMenuButtonKeybindings:Click()
        return true
    end
end

function addon.CreateKeybindingAssistant(parent, ui, optionsWindow)
    local assistant = CreateFrame("Frame", nil, parent)
    assistant:SetAllPoints()
    assistant:Hide()

    local window = CreateFrame("Frame", nil, assistant)
    window:SetPoint("TOPLEFT", 0, -36)
    window:SetPoint("BOTTOMRIGHT")
    local stylePage = CreateFrame("Frame", nil, assistant)
    stylePage:SetAllPoints(window)
    stylePage:Hide()

    local function text(value, x, y)
        local item = ui.label(window, value, x, y, "GameFontHighlightSmall")
        item:SetWidth(680 - x - 18)
        item:SetJustifyH("LEFT")
        item:SetWordWrap(true)
        return item
    end

    text(tr("Place et enregistre d’abord tes barres. Clique sur un bouton de Base puis appuie sur une touche. Les modificateurs sont ignorés pendant la saisie.",
        "Place and save your bars first. Click a Base button and press a key. Modifiers are ignored during capture."), 18, -10)
    local warning = text(tr("Cet outil modifie les raccourcis enregistrés dans WoW, pour ton personnage ou ton compte selon le réglage du jeu.",
        "This tool changes saved WoW keybindings for your character or account, depending on your game settings."), 18, -44)
    warning:SetTextColor(1, 0.82, 0.36)

    local filter, bases, targets, selected, pending, approved
    local sourceMenu, targetMenu, apply
    local redraw, refreshSlots
    local captureBar, captureSlot
    local barRows, preview, generators = {}, {}, {}
    local status = text("", 18, -576)
    local hint = text("", 18, -103)

    local function makeHalo(parent, strata)
        local halo = CreateFrame("Frame", nil, parent, "BackdropTemplate")
        if strata then halo:SetFrameStrata(strata) end
        halo:EnableMouse(false)
        halo:SetBackdrop({edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 2})
        halo:SetBackdropBorderColor(1, 0.28, 0.22, 0.95)
        local glow = CreateFrame("Frame", nil, halo, "BackdropTemplate")
        glow:SetPoint("TOPLEFT", -2, 2)
        glow:SetPoint("BOTTOMRIGHT", 2, -2)
        glow:SetBackdrop({edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 2})
        glow:SetBackdropBorderColor(1, 0.18, 0.12, 0.36)
        halo:Hide()
        return halo
    end

    local menuHalo, barHalo = makeHalo(window), makeHalo(UIParent, "HIGH")
    barHalo:SetFrameLevel(55)
    local function placeHalo(halo, anchor, parent)
        if not anchor or not anchor:IsVisible() then
            halo:Hide()
            return
        end
        if parent then
            halo:SetParent(parent)
            halo:SetFrameLevel(parent:GetFrameLevel() + 2)
        end
        halo:ClearAllPoints()
        halo:SetPoint("TOPLEFT", anchor, "TOPLEFT", -1, 1)
        halo:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", 1, -1)
        halo:Show()
    end

    local function clearHalo()
        menuHalo:Hide()
        barHalo:Hide()
    end

    local controls, targetControls, targetOverlays = {}, {}, {}
    local function highlight(action, widget)
        if not action then return end
        local match = controls[action.button] or targetControls[action.button]
        widget = widget or (match and match.widget)
        placeHalo(menuHalo, widget, widget)
        placeHalo(barHalo, match and match.overlay:IsShown() and match.overlay or action.button)
    end

    local function redKey(key)
        return "|cffff5050" .. keyName(key) .. "|r"
    end

    local keyboard = CreateFrame("Frame", nil, window)
    local function cancelCapture()
        captureBar, captureSlot = nil, nil
        keyboard:EnableKeyboard(false)
    end

    window:SetScript("OnHide", function()
        cancelCapture()
        clearHalo()
        for _, row in ipairs(barRows) do
            for _, overlay in ipairs(row.overlays) do overlay:Hide() end
        end
        for _, overlay in ipairs(targetOverlays) do overlay:Hide() end
    end)
    keyboard:SetScript("OnKeyDown", function(_, key)
        if key == "ESCAPE" then
            cancelCapture()
            refreshSlots()
        elseif captureBar and not isModifier(key) and key ~= "UNKNOWN" and not key:match("^PAD") then
            pending[captureBar] = pending[captureBar] or {}
            pending[captureBar][captureSlot] = key
            cancelCapture()
            approved = {}
            redraw()
        end
    end)
    local function capture(bar, slot)
        if InCombatLockdown() or not bar.slots[slot] then return end
        local focus = GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()
        if focus then focus:ClearFocus() end
        captureBar, captureSlot = bar, slot
        keyboard:EnableKeyboard(true)
        keyboard:SetPropagateKeyboardInput(false)
        status:SetText("")
        refreshSlots()
    end

    local function scrollArea(top, bottom)
        local scroll = CreateFrame("ScrollFrame", nil, window, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 18, top)
        scroll:SetPoint("BOTTOMRIGHT", -32, bottom)
        local content = CreateFrame("Frame", nil, scroll)
        content:SetWidth(624)
        content:SetHeight(1)
        scroll:SetScrollChild(content)
        return scroll, content
    end

    local baseScroll, baseContent = scrollArea(-125, 373)
    local allBars = tr("Tout le groupe Base", "Entire Base group")
    sourceMenu = ui.menu(window, 18, -69, 304, function(root)
        local function getFilter() return filter end
        local function setFilter(bar)
            cancelCapture()
            filter = bar
            redraw(true)
        end
        ui.radio(root, allBars, false, getFilter, setFilter)
        for _, bar in ipairs(bases) do
            ui.radio(root, bar.label, bar, getFilter, setFilter)
        end
    end)

    local function getBarRow(index)
        if barRows[index] then return barRows[index] end
        local row = CreateFrame("Frame", nil, baseContent)
        row:SetSize(624, 56)
        row:SetPoint("TOPLEFT", 0, -(index - 1) * 56)
        row.caption = ui.label(row, "", 0, -3, "GameFontHighlightSmall")
        row.slots, row.overlays = {}, {}
        for slot = 1, 12 do
            row.slots[slot] = ui.button(row, "", (slot - 1) * 52, -21, 50, function() capture(row.bar, slot) end)
            local overlay = CreateFrame("Button", nil, UIParent, "UIPanelButtonTemplate")
            overlay:SetFrameStrata("HIGH")
            overlay:SetFrameLevel(50)
            overlay:SetScript("OnClick", function() capture(row.bar, slot) end)
            overlay:Hide()
            local function enter() highlight(row.bar and row.bar.slots[slot]) end
            row.slots[slot]:SetScript("OnEnter", enter)
            row.slots[slot]:SetScript("OnLeave", clearHalo)
            overlay:SetScript("OnEnter", enter)
            overlay:SetScript("OnLeave", clearHalo)
            row.overlays[slot] = overlay
        end
        barRows[index] = row
        return row
    end

    refreshSlots = function()
        clearHalo()
        wipe(controls)
        hint:SetText(captureSlot and (captureBar.label .. " · " ..
            tr("Appuie sur la touche du bouton %d. Échap annule.",
                "Press a key for button %d. Escape cancels."):format(captureSlot)) or "")
        local visible = 0
        for _, bar in ipairs(bases) do
            if not filter or filter == bar then
                visible = visible + 1
                local row = getBarRow(visible)
                row.bar = bar
                row.caption:SetText(bar.label .. (bar.blocked and " · " .. bar.blocked or ""))
                for slot, widget in ipairs(row.slots) do
                    local action = bar.slots[slot]
                    local key = action and ((pending[bar] and pending[bar][slot]) or keyForAction(action))
                    widget:SetText(slot .. " · " .. (key and redKey(key) or "—"))
                    widget:SetEnabled(action ~= nil)
                    local overlay = row.overlays[slot]
                    if action then controls[action.button] = {widget = widget, overlay = overlay} end
                    if action and action.button:IsVisible() then
                        overlay:ClearAllPoints()
                        overlay:SetAllPoints(action.button)
                        overlay:SetText(key and redKey(key) or tostring(slot))
                        overlay:Show()
                    else
                        overlay:Hide()
                    end
                end
                row:Show()
            end
        end
        for index = visible + 1, #barRows do
            local row = barRows[index]
            row:Hide()
            for _, overlay in ipairs(row.overlays) do overlay:Hide() end
        end
        baseContent:SetHeight(math.max(visible * 56, 1))
    end

    for index, layer in ipairs({"maj", "ctrl", "alt"}) do
        local prefix = prefixes[layer]
        generators[prefix] = ui.button(window,
            tr("Générer %s", "Generate %s"):format(addon.LayerLabel(layer)),
            18 + (index - 1) * 132, -323, 125, function()
                cancelCapture()
                for _, target in ipairs(targets) do
                    if target.prefix == prefix and not target.blocked then selected[target] = true end
                end
                status:SetText("")
                redraw()
            end)
    end

    targetMenu = ui.menu(window, 414, -321, 248, function(root)
        for _, bar in ipairs(targets) do
            local entry = root:CreateCheckbox(bar.label .. (bar.blocked and " · " .. bar.blocked or ""),
                function() return selected[bar] end, function()
                    cancelCapture()
                    selected[bar] = not selected[bar] or nil
                    approved = {}
                    status:SetText("")
                    redraw()
                end)
            if bar.blocked then entry:SetEnabled(false) end
        end
    end)
    text(tr("Conseil : garde Alt pour l’auto-incantation (lancer un sort sur toi).",
        "Tip: Keep Alt for self-cast (casting a spell on yourself)."), 18, -355)
    text(tr("Dans chaque cadre cible, la génération suit l’ordre des numéros de barres et des emplacements.",
        "Within each target frame, generation follows bar numbers and button positions."), 18, -380)
    ui.label(window, tr("Aperçu des changements", "Preview changes"), 18, -406)
    text(tr("Coche un conflit pour remplacer le raccourci existant.", "Check a conflict to replace the existing shortcut."), 18, -428)
    local scroll, content = scrollArea(-450, 93)

    local function getRow(index)
        if preview[index] then return preview[index] end
        local item = CreateFrame("Frame", nil, content)
        item:SetSize(624, 26)
        item:SetPoint("TOPLEFT", 0, -(index - 1) * 26)
        item.check = CreateFrame("CheckButton", nil, item, "UICheckButtonTemplate")
        item.check:SetPoint("LEFT")
        item.caption = ui.label(item, "", 28, -6, "GameFontHighlightSmall")
        item.caption:SetWidth(590)
        item.caption:SetJustifyH("LEFT")
        item.caption:SetMaxLines(1)
        item:EnableMouse(true)
        item:SetScript("OnEnter", function()
            highlight(item.data.action, item)
            GameTooltip:SetOwner(item, "ANCHOR_CURSOR")
            GameTooltip:SetText(item.caption:GetText(), 1, 1, 1, true)
            GameTooltip:Show()
        end)
        item:SetScript("OnLeave", function()
            clearHalo()
            GameTooltip:Hide()
        end)
        item.check:SetScript("OnClick", function(self)
            local row = item.data
            approved[row.key] = self:GetChecked() and {from = row.previous, to = row.action.command} or nil
            redraw()
        end)
        preview[index] = item
        return item
    end

    local function drawTargetOverlay(index, item, row)
        local overlay = targetOverlays[index]
        if not overlay then
            overlay = CreateFrame("Button", nil, UIParent, "UIPanelButtonTemplate")
            overlay:SetFrameStrata("HIGH")
            overlay:SetFrameLevel(50)
            overlay:SetScript("OnEnter", function(self) highlight(self.action, self.previewRow) end)
            overlay:SetScript("OnLeave", clearHalo)
            targetOverlays[index] = overlay
        end
        overlay.action, overlay.previewRow = row.action, item
        overlay:ClearAllPoints()
        overlay:SetAllPoints(row.action.button)
        overlay:SetText(redKey(row.key))
        overlay:Show()
        targetControls[row.action.button] = {widget = item, overlay = overlay}
    end

    redraw = function(resetScroll)
        refreshSlots()
        sourceMenu:OverrideText(filter and filter.label or allBars)
        local count, available = 0, {}
        for _, target in ipairs(targets) do
            if selected[target] then count = count + 1 end
            if not target.blocked then available[target.prefix] = true end
        end
        for prefix, button in pairs(generators) do button:SetEnabled(not not available[prefix]) end
        targetMenu:OverrideText(count == 0 and tr("Barres cibles", "Target bars")
            or tr("%d barre(s) sélectionnée(s)", "%d bar(s) selected"):format(count))
        local rows = previewChanges(bases, targets, selected, pending, approved)
        local actionable, overlayCount = false, 0
        wipe(targetControls)
        for index, row in ipairs(rows) do
            local item = getRow(index)
            item.data = row
            local detail = row.blocked
                or (row.conflict and tr("déjà lié à %s", "already bound to %s"):format(bindingName(row.previous)))
                or (row.current and tr("déjà assigné", "already assigned"))
            item.caption:SetText(redKey(row.key) .. " → " .. row.label .. (detail and " · " .. detail or ""))
            item.check:SetShown(row.conflict and not row.blocked or false)
            item.check:SetChecked(not not row.approved)
            item:Show()
            local action = row.action
            if not row.blocked and action and action.button and action.button:IsVisible()
                and not controls[action.button] and not targetControls[action.button] then
                overlayCount = overlayCount + 1
                drawTargetOverlay(overlayCount, item, row)
            end
            if not row.blocked and not row.current and (not row.conflict or row.approved) then actionable = true end
        end
        for index = #rows + 1, #preview do preview[index]:Hide() end
        for index = overlayCount + 1, #targetOverlays do targetOverlays[index]:Hide() end
        content:SetHeight(math.max(#rows * 26, 1))
        if resetScroll then
            scroll:SetVerticalScroll(0)
            baseScroll:SetVerticalScroll(0)
        end
        apply:SetEnabled(actionable and not InCombatLockdown())
    end

    ui.button(window, tr("Ouvrir les raccourcis de WoW", "Open WoW keybindings"), 18, -620, 230, function()
        cancelCapture()
        if openGameBindings() then
            optionsWindow:Hide()
        else
            refreshSlots()
            status:SetText(tr("Dans WoW, ouvre Échap → Options → Raccourcis.",
                "In WoW, open Escape → Options → Keybindings."))
        end
    end)
    apply = ui.button(window, tr("Appliquer", "Apply"), 502, -620, 160, function()
        cancelCapture()
        local rows = previewChanges(bases, targets, selected, pending, approved)
        local ok, changed = saveChanges(rows)
        if ok and changed > 0 then
            approved = {}
            status:SetText(tr("Raccourcis enregistrés.", "Keybindings saved."))
        elseif ok then
            status:SetText(tr("Aucun changement appliqué. Vérifie l’aperçu.",
                "No changes applied. Review the preview."))
        else
            status:SetText(tr("Impossible d’enregistrer les raccourcis.", "Could not save keybindings."))
        end
        redraw()
    end)
    local refreshStyle = addon.CreateHotkeyStylePage(stylePage, ui)
    local showAssignment, showStyle
    local function selectPage(showingStyle, resetScroll)
        window:SetShown(not showingStyle)
        stylePage:SetShown(showingStyle)
        showAssignment(not showingStyle, true)
        showStyle(showingStyle, true)
        if showingStyle then refreshStyle() else redraw(resetScroll) end
    end
    showAssignment = ui.tab(assistant, tr("Assignation", "Assignment"), 18, -3, 145, function() selectPage(false) end)
    showStyle = ui.tab(assistant, tr("Style", "Style"), 168, -3, 145, function() selectPage(true) end)

    function assistant:Open()
        bases, targets = eligibleBars(nativeCommands())
        selected, pending, approved = {}, {}, {}
        filter = false
        self:Show()
        status:SetText("")
        selectPage(false, true)
        if not bases[1] then
            status:SetText(tr("Enregistre un cadre lié à une barre avec le déclencheur Base.",
                "Save a frame linked to an action bar with the Base trigger."))
        end
    end
    return assistant
end
