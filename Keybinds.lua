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

local function bindingContext(command)
    return C_KeyBindings and C_KeyBindings.GetBindingContextForAction
        and C_KeyBindings.GetBindingContextForAction(command)
end

local function nativeCommands()
    local commands = {}
    for index = 1, GetNumBindings() do
        local command = GetBinding(index)
        if command then commands[command] = true end
    end
    return commands
end

local function eligibleBars(commands, frame)
    local bases, targets, seenBase = {}, {}, {}
    local selfCast = GetModifiedClick and GetModifiedClick("SELFCAST")
    local function addLayer(panel, layer, kind, bars, count, offset)
        local base = layer == "unmodified" or layer == "base"
        local prefix = prefixes[layer]
        if bars and (base or prefix) then
            local group = {}
            for id = 1, count do
                if bars[id] then
                    local number, barLabel = addon.BarLabel(kind, id)
                    local entry = {
                        id = id, number = tonumber(number) or math.huge,
                        label = panel.name .. " · " .. barLabel, panel = panel, prefix = prefix, layer = layer, slots = {},
                        slotCount = kind=="owned" and 0 or 12,
                    }
                    for slot = 1, kind=="owned" and 36 or 12 do
                        local action = addon.BarActionButton(kind, id, slot)
                        local command = addon.NativeBarBinding(kind, id, slot)
                        if action and action:IsShown() and (kind=="owned" or commands[command]) then
                            entry.slotCount=math.max(entry.slotCount,slot)
                            local context = bindingContext(command)
                            entry.slots[slot] = {command=command,button=action,context=context,
                                totemElement=kind=="owned" and action.model and action.model.kind=="totem" and slot<=4}
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
                    local key = kind .. ":" .. entry.id
                    if not seenBase[key] then
                        seenBase[key] = true
                        bases[#bases + 1] = entry
                    end
                else
                    entry.sourceIndex = index + offset
                    entry.label = entry.label .. " (" .. addon.LayerLabel(layer) .. ")"
                    if not canUsePrefix(prefix, selfCast) then
                        entry.blocked = tr("auto-incantation", "self-cast")
                    end
                    targets[#targets + 1] = entry
                end
            end
            return #group
        end
        return 0
    end
    local directTotems={}
    for _, panel in ipairs(KeyLayersCharLayout.panels) do
        local hold, toggle = addon.HoldLayer(panel), addon.PanelToggle(panel)
        local toggleLayer = type(toggle) == "string" and toggle or (toggle and panel.toggleModifier)
        local holdOffset,toggleOffset=0,0
        local function include(kind, ids, count)
            if hold then holdOffset=holdOffset+addLayer(panel,hold,kind,ids,count,holdOffset) end
            if toggleLayer and toggleLayer ~= hold then
                toggleOffset=toggleOffset+addLayer(panel,toggleLayer,kind,ids,count,toggleOffset)
            end
        end
        for _,kind in ipairs({"bars","blizzard"}) do
            include(kind, addon.BarLayout.links(panel,kind), addon.barCounts[kind])
        end
        local owned = addon.AttachedActionIds(panel,true)
        if owned then
            local totems={}
            for id in pairs(owned) do
                local model=addon.BarLayout.init(KeyLayersCharLayout).bars[id]
                if model.kind=="totem" then
                    totems[id]=true
                    if panel==frame then directTotems[id]=true end
                    owned[id]=nil
                end
            end
            include("owned",owned,12)
            if prefixes[hold] then holdOffset=holdOffset+addLayer(panel,hold,"owned",totems,12,holdOffset) end
            if prefixes[toggleLayer] and toggleLayer~=hold then
                addLayer(panel,toggleLayer,"owned",totems,12,toggleOffset)
            end
        end
    end
    if next(directTotems) then
        local first=#bases+1
        addLayer(frame,"unmodified","owned",directTotems,12)
        for index=first,#bases do
            for _,action in pairs(bases[index].slots) do action.direct=true end
            bases[index].direct=true
        end
    end
    for _, target in ipairs(targets) do
        local source = bases[target.sourceIndex]
        if not target.blocked and (not source or source.blocked or source.direct) then
            target.blocked = tr("pas de barre Base correspondante", "no matching Base bar")
        end
    end
    return bases, targets
end

local generationLayers = {"ctrl", "maj", "ctrl+maj", "alt", "ctrl+alt", "maj+alt", "ctrl+maj+alt"}

local function groupTargets(targets)
    local byLayer = {}
    for _, bar in ipairs(targets) do
        local layer = byLayer[bar.layer]
        if not layer then
            layer = {groups = {}, panels = {}}
            byLayer[bar.layer] = layer
        end
        local group = layer.panels[bar.panel]
        if not group then
            group = {panel = bar.panel, bars = {}, usable = false}
            layer.panels[bar.panel] = group
            layer.groups[#layer.groups + 1] = group
        end
        group.bars[#group.bars + 1] = bar
        group.usable = group.usable or not bar.blocked
    end
    return byLayer
end

local function uniquePanels(bars)
    local panels, seen = {}, {}
    for _, bar in ipairs(bars) do
        if not seen[bar.panel] then
            seen[bar.panel] = true
            panels[#panels + 1] = bar.panel
        end
    end
    return panels
end

local function baseKey(...)
    for index = 1, select("#", ...) do
        local key = select(index, ...)
        local prefix = key and key:match("^([^-]+)%-")
        if key and key ~= "" and not modifiers[prefix] then return key end
    end
end

local function keyForAction(action)
    if action.direct then return GetBindingKey(action.command,nil,action.context) end
    return baseKey(GetBindingKey(action.command, nil, action.context)) or baseKey(action.button and action.button.nativeKey)
end

local function visualSlotFor(action, slot)
    if action and action.totemElement and action.button and action.button.model then
        return addon.BarLayout.slotPosition(action.button.model, slot) + 1
    end
    return slot
end

local function sourceSlotFor(action, slot, offset)
    return visualSlotFor(action, slot) + offset
end

local function compareSlots(bases, group, pending, offset)
    local sourceCount, targetCount, matched, keyed = 0, 0, 0, 0
    for _, base in ipairs(bases) do
        for _ in pairs(base.slots) do sourceCount = sourceCount + 1 end
    end
    for _, bar in ipairs(group.bars) do
        local base = bases[bar.sourceIndex]
        for slot, targetAction in pairs(bar.slots) do
            targetCount = targetCount + 1
            local sourceSlot = sourceSlotFor(targetAction, slot, offset or 0)
            local action = base and base.slots[sourceSlot]
            if action then
                matched = matched + 1
                if (pending[base] and pending[base][sourceSlot]) or keyForAction(action) then keyed = keyed + 1 end
            end
        end
    end
    return sourceCount, targetCount, matched, keyed
end

local function bindingName(command)
    return _G["BINDING_NAME_" .. command] or command
end

local function keyName(key)
    return GetBindingText and GetBindingText(key) or key
end

local function selectionKey(action, key)
    return action.command .. "\0" .. key
end

local function matchesPrefix(key, prefix)
    return key:sub(1, #prefix) == prefix and baseKey(key:sub(#prefix + 1))
end

local function previewChanges(bases, targets, selected, pending, approved, offset, excluded, remapTotems)
    offset=offset or 0
    local rows, byKey, baseRows = {}, {}, {}
    local directCommands, directKeys = {}, {}
    local selfCast = GetModifiedClick and GetModifiedClick("SELFCAST")
    local neutral = {}
    for _, key in ipairs({addon.NeutralKey()}) do neutral[key] = true end

    local function add(bar, slot, key, blocked, movable)
        local action = bar.slots[slot]
        blocked = addon.ReservedShortcutMessage(key) or blocked
        local row = {key = key, label = bar.label .. " #" .. visualSlotFor(action, slot), action = action, blocked = blocked,
            bar = bar, slot = slot}
        if action and excluded and excluded[selectionKey(action, key)] then return end
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
        elseif not row.current and row.previous ~= "" and not (movable and movable[row.previous]) then
            row.conflict = true
            local choice = approved[key]
            row.approved = choice and choice.from == row.previous and choice.to == action.command
        end
        return row
    end

    for index, source in ipairs(bases) do
        local sourceRows = {}
        baseRows[index] = sourceRows
        for slot = 1, source.slotCount or 12 do
            local action = source.slots[slot]
            local staged = pending[source] and pending[source][slot]
            local key = action and (staged or keyForAction(action))
            if key then
                if staged then
                    local row=add(source,slot,key)
                    sourceRows[slot]=row or byKey[key]
                    if row then
                        rows[#rows+1]=row
                        if action.direct then
                            directCommands[action.command] = true
                            directKeys[key] = true
                        end
                    end
                else
                    sourceRows[slot]={key=key,action=action}
                end
            end
        end
    end
    local unused={}
    local function releaseKey(key, action)
        unused[key] = {key=key, label=tr("Libérer la touche","Release key"),
            action=action, previous=action.command, clear=true}
    end
    for _,target in ipairs(targets) do
        local source=bases[target.sourceIndex]
        local sourceRows=baseRows[target.sourceIndex]
        if selected[target] and sourceRows and not target.blocked then
            local ownedCommands, used, protected = {}, {}, {}
            local totemBar
            for _, action in pairs(target.slots) do
                if action.totemElement then totemBar = true; break end
            end
            local remapping = totemBar and remapTotems
            for _, action in pairs(target.slots) do
                if directCommands[action.command] or (totemBar and not remapping
                    and GetBindingKey(action.command, nil, action.context)) then
                    protected[action.command] = true
                else
                    ownedCommands[action.command] = action
                end
            end
            for slot=1,target.slotCount or 12 do
                local action=target.slots[slot]
                if action then
                    local sourceSlot = sourceSlotFor(action, slot, offset)
                    local base = sourceRows[sourceSlot]
                    local boundElement = protected[action.command]
                    if boundElement and not directCommands[action.command] then
                        for _, key in ipairs({GetBindingKey(action.command, nil, action.context)}) do
                            if matchesPrefix(key, target.prefix)
                                and GetBindingAction(key, false, action.context) == action.command then
                                rows[#rows+1] = {key = key, label = target.label .. " #" .. visualSlotFor(action, slot),
                                    action = action, current = true}
                            end
                        end
                    end
                    if base and not boundElement then
                        used[sourceSlot]=true
                        local blocked
                        if base.action and base.action.direct then
                            blocked=tr("Ce raccourci est assigné directement.","This shortcut is assigned directly.")
                        elseif not canUsePrefix(target.prefix,selfCast) then
                            blocked=tr("auto-incantation","self-cast")
                        elseif base.blocked or (base.conflict and not base.approved) then
                            blocked=tr("raccourci Base à résoudre","resolve the Base shortcut")
                        end
                        local key = target.prefix .. base.key
                        local owner = GetBindingAction(key, false, action.context)
                        if not blocked and protected[owner] then
                            blocked = tr("touche conservée par un totem", "key kept by a totem")
                        end
                        if not directKeys[key] then
                            local row = add(target, slot, key, blocked, remapping and ownedCommands)
                            if row then
                                rows[#rows+1] = row
                                if remapping and not row.blocked and (not row.conflict or row.approved) then
                                    for _, saved in ipairs({GetBindingKey(action.command, nil, action.context)}) do
                                        if saved ~= key and matchesPrefix(saved, target.prefix)
                                            and not directKeys[saved]
                                            and GetBindingAction(saved, false, action.context) == action.command then
                                            releaseKey(saved, action)
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
            for slot=1,source.slotCount or 12 do
                local base=sourceRows[slot]
                if base and not used[slot] and not base.blocked and (not base.conflict or base.approved) then
                    local key=target.prefix..base.key
                    for command,action in pairs(ownedCommands) do
                        if GetBindingAction(key,false,action.context)==command then
                            releaseKey(key, action)
                            break
                        end
                    end
                end
            end
        end
    end
    local release={}
    for key in pairs(unused) do if not byKey[key] then release[#release+1]=key end end
    table.sort(release)
    for _,key in ipairs(release) do rows[#rows+1]=unused[key] end
    return rows
end

local function saveChanges(rows)
    if InCombatLockdown() then return false end
    local completed = {}
    for _, row in ipairs(rows) do
        if not row.blocked and not row.current and (not row.conflict or row.approved) then
            local command
            if not row.clear then command=row.action.command end
            if (command and addon.ReservedShortcutMessage(row.key))
                or not SetBinding(row.key,command,row.action.context) then
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

local function frameShortcuts(panel)
    local rows, seen = {}, {}
    local function collect(kind, barIds, models)
        for id in pairs(barIds or {}) do
            for slot = 1, models and models[id].count or 12 do
                local command = addon.NativeBarBinding(kind, id, slot)
                if command and not seen[command] then
                    seen[command] = true
                    local context = bindingContext(command)
                    local action = {command = command, context = context}
                    for _, key in ipairs({GetBindingKey(command, nil, context)}) do
                        if GetBindingAction(key, false, context) == command then
                            rows[#rows+1] = {key = key, action = action, previous = command, clear = true}
                        end
                    end
                end
            end
        end
    end
    local layout = addon.BarLayout
    if layout.available() then collect("bars", layout.links(panel, "bars")) end
    collect("blizzard", layout.links(panel, "blizzard"))
    collect("owned", addon.AttachedActionIds(panel, true), layout.init(KeyLayersCharLayout).bars)
    return rows
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
    window:SetAllPoints(assistant)

    local function text(value, x, y)
        local item = ui.label(window, value, x, y, "GameFontHighlightSmall")
        item:SetWidth(680 - x - 18)
        item:SetJustifyH("LEFT")
        item:SetWordWrap(true)
        return item
    end

    text(tr("Clique sur un bouton, puis appuie sur une touche. Les lignes de totems acceptent les modificateurs. Les lignes de Base utilisent une touche seule.",
        "Click a button, then press a key. Totem rows accept modifiers. Base rows use an unmodified key."), 18, -10)
    local warning = text(tr("Cet outil modifie les raccourcis enregistrés dans WoW, pour ton personnage ou ton compte selon le réglage du jeu.",
        "This tool changes saved WoW keybindings for your character or account, depending on your game settings."), 18, -44)
    warning:SetTextColor(1, 0.82, 0.36)

    local filter, bases, targets, selected, pending, approved
    local sourceMenu, apply, clearFrameButton
    local openedFrame, excluded
    local targetGroups, sourcePanels
    local sourceOffset, remapTotems = 0, false
    local generators, hoveredGenerator = {}, nil
    local refreshGeneratorHover
    local redraw, refreshSlots
    local captureBar, captureSlot
    local barRows, preview = {}, {}
    local status = text("", 18, -581)

    local function makeHalo(parent, strata, color)
        local halo = CreateFrame("Frame", nil, parent, "BackdropTemplate")
        if strata then halo:SetFrameStrata(strata) end
        halo:EnableMouse(false)
        halo:SetBackdrop({edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 2})
        color = color or {1, 0.28, 0.22}
        halo:SetBackdropBorderColor(color[1], color[2], color[3], 0.95)
        local glow = CreateFrame("Frame", nil, halo, "BackdropTemplate")
        glow:SetPoint("TOPLEFT", -2, 2)
        glow:SetPoint("BOTTOMRIGHT", 2, -2)
        glow:SetBackdrop({edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 2})
        glow:SetBackdropBorderColor(color[1], color[2], color[3], 0.36)
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
    local capturePrompt = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    capturePrompt:SetSize(396, 116)
    capturePrompt:SetFrameStrata("FULLSCREEN_DIALOG")
    capturePrompt:SetClampedToScreen(true)
    capturePrompt:EnableMouse(true)
    capturePrompt:SetBackdrop({
        bgFile = [[Interface\Buttons\WHITE8X8]],
        edgeFile = [[Interface\Buttons\WHITE8X8]], edgeSize = 1,
    })
    capturePrompt:SetBackdropColor(0.08, 0.12, 0.17, 0.98)
    capturePrompt:SetBackdropBorderColor(0.38, 0.70, 0.86, 1)
    ui.label(capturePrompt, tr("Attribution d’un raccourci", "Assigning a shortcut"),
        16, -10, "GameFontNormalLarge")
    local promptTarget = ui.label(capturePrompt, "", 16, -34, "GameFontHighlightSmall")
    promptTarget:SetWidth(364)
    promptTarget:SetMaxLines(1)
    promptTarget:SetJustifyH("LEFT")
    local promptInstructions = ui.label(capturePrompt, tr(
        "Appuie sur la touche de ton choix, seule, sans Maj, Ctrl ni Alt. Échap annule.",
        "Press the key you want on its own, without Shift, Ctrl, or Alt. Escape cancels."),
        16, -54, "GameFontHighlight")
    promptInstructions:SetWidth(364)
    promptInstructions:SetJustifyH("LEFT")
    promptInstructions:SetWordWrap(true)
    capturePrompt:Hide()

    local function cancelCapture()
        captureBar, captureSlot = nil, nil
        keyboard:EnableKeyboard(false)
        capturePrompt:Hide()
    end

    ui.button(capturePrompt, CANCEL or tr("Annuler", "Cancel"), 252, -86, 128, function()
        cancelCapture()
        redraw()
    end)

    window:SetScript("OnHide", function()
        addon.SetBindingOutlines({}, {})
        if hoveredGenerator then
            hoveredGenerator.halo:Hide()
            GameTooltip:Hide()
            hoveredGenerator = nil
        end
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
            redraw()
        elseif captureBar and not isModifier(key) and key ~= "UNKNOWN" and not key:match("^PAD") then
            local alt = IsAltKeyDown()
            local warning = addon.ReservedShortcutMessage(key, alt)
            if warning then promptInstructions:SetText(warning); return end
            if captureBar.direct then
                local ctrl, shift = IsControlKeyDown(), IsShiftKeyDown()
                key=(alt and "ALT-" or "")..(ctrl and "CTRL-" or "")..(shift and "SHIFT-" or "")..key
            end
            pending[captureBar] = pending[captureBar] or {}
            pending[captureBar][captureSlot] = key
            excluded[selectionKey(captureBar.slots[captureSlot], key)] = nil
            cancelCapture()
            approved = {}
            redraw()
        end
    end)
    local function placeCapturePrompt(anchor)
        local scale = UIParent:GetEffectiveScale()
        local mouseX, mouseY = GetCursorPosition()
        mouseX, mouseY = mouseX / scale, mouseY / scale
        local left, bottom, width, height = anchor:GetRect()
        local right, top = mouseX, mouseY
        if left then
            local factor = anchor:GetEffectiveScale() / scale
            right, top = (left + width) * factor, (bottom + height) * factor
            left, bottom = left * factor, bottom * factor
        else
            left, bottom = mouseX, mouseY
        end

        local gap, margin = 12, 8
        local promptWidth, promptHeight = capturePrompt:GetSize()
        local screenWidth, screenHeight = UIParent:GetSize()
        local x, y = math.max(mouseX, right) + gap, mouseY - 32
        if x + promptWidth > screenWidth - margin then
            x = math.min(mouseX, left) - gap - promptWidth
            if x < margin then
                x = mouseX - promptWidth / 2
                y = top + gap
                if y + promptHeight > screenHeight - margin then
                    y = bottom - gap - promptHeight
                end
            end
        end

        x = math.max(margin, math.min(x, screenWidth - promptWidth - margin))
        y = math.max(margin, math.min(y, screenHeight - promptHeight - margin))
        capturePrompt:ClearAllPoints()
        capturePrompt:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, y)
    end

    local function capture(bar, slot, anchor)
        if InCombatLockdown() or not bar.slots[slot] then return end
        local focus = GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()
        if focus then focus:ClearFocus() end
        captureBar, captureSlot = bar, slot
        keyboard:EnableKeyboard(true)
        keyboard:SetPropagateKeyboardInput(false)
        promptInstructions:SetText(bar.direct
            and tr("Appuie sur une touche avec ou sans modificateur. Échap annule.","Press a key with or without modifiers. Escape cancels.")
            or tr("Appuie sur la touche de ton choix, seule, sans Maj, Ctrl ni Alt. Échap annule.",
                "Press the key you want on its own, without Shift, Ctrl, or Alt. Escape cancels."))
        promptTarget:SetText(bar.label .. " · " .. tr("Bouton %d", "Button %d"):format(slot))
        placeCapturePrompt(anchor or bar.slots[slot].button)
        capturePrompt:Show()
        status:SetText("")
    end

    local function removeShortcut(action, key, bar, slot)
        if not action or not key or InCombatLockdown() then return end
        cancelCapture()
        local saved = GetBindingAction(key, false, action.context) == action.command
        if saved and not saveChanges({{key=key, action=action, previous=action.command, clear=true}}) then
            status:SetText(tr("Impossible de désassigner le raccourci.", "Could not clear the shortcut."))
            return
        end
        if bar and pending[bar] and pending[bar][slot] == key then pending[bar][slot] = nil end
        excluded[selectionKey(action,key)] = true
        approved[key] = nil
        status:SetText(saved and tr("Raccourci désassigné.", "Shortcut cleared.")
            or tr("Proposition retirée.", "Suggestion removed."))
        redraw()
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

    local baseScroll, baseContent = scrollArea(-105, 416)
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
        for slot = 1, 36 do
            row.slots[slot] = ui.button(row, "", ((slot - 1)%12) * 52, -21-24*math.floor((slot-1)/12), 50)
            local overlay = CreateFrame("Button", nil, UIParent, "UIPanelButtonTemplate")
            overlay:SetFrameStrata("HIGH")
            overlay:SetFrameLevel(50)
            local function click(self, mouseButton)
                local action = row.bar.slots[slot]
                if mouseButton == "RightButton" then
                    local shown = self.bindingPreview
                    local key = shown and shown.key or (pending[row.bar] and pending[row.bar][slot])
                        or (action and keyForAction(action))
                    removeShortcut(action, key, row.bar, slot)
                else
                    capture(row.bar, slot, self)
                end
            end
            row.slots[slot]:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            row.slots[slot]:SetScript("OnClick", click)
            overlay:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            overlay:SetScript("OnClick", click)
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
        local visible,height = 0,0
        for _, bar in ipairs(bases) do
            if not filter or filter == bar then
                visible = visible + 1
                local row = getBarRow(visible)
                row.bar = bar
                local count=bar.slotCount or 12
                local rowHeight=56+24*math.max(0,math.ceil(count/12)-1)
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT",0,-height)
                row:SetHeight(rowHeight)
                height=height+rowHeight
                row.caption:SetText(bar.label .. (bar.blocked and " · " .. bar.blocked or ""))
                for slot, widget in ipairs(row.slots) do
                    local action = bar.slots[slot]
                    local key = action and ((pending[bar] and pending[bar][slot]) or keyForAction(action))
                    local position = visualSlotFor(action, slot)
                    widget:ClearAllPoints()
                    widget:SetPoint("TOPLEFT", ((position-1)%12)*52, -21-24*math.floor((position-1)/12))
                    widget:SetText(position .. " · " .. (key and redKey(key) or "—"))
                    widget:SetEnabled(action ~= nil)
                    widget:SetShown(slot<=count)
                    local overlay = row.overlays[slot]
                    overlay.bindingPreview = nil
                    if action then controls[action.button] = {widget = widget, overlay = overlay} end
                    if action and action.button:IsVisible() then
                        overlay:ClearAllPoints()
                        overlay:SetAllPoints(action.button)
                        overlay:SetText(key and redKey(key) or tostring(position))
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
        baseContent:SetHeight(math.max(height,1))
    end

    local function groupsFor(layer)
        return targetGroups[layer] and targetGroups[layer].groups or {}
    end

    local function missingTarget(layer)
        return tr(
            "Dans Configuration, crée un cadre %s, lie-le à une ou plusieurs barres d’action Blizzard ou Bartender4, puis enregistre-le.",
            "In Settings, create a %s frame, link it to one or more Blizzard or Bartender4 action bars, then save it.")
            :format(addon.LayerLabel(layer))
    end

    local function reserved(layer)
        return not canUsePrefix(prefixes[layer], GetModifiedClick and GetModifiedClick("SELFCAST"))
    end

    local function clearGeneratorHover()
        if not hoveredGenerator then return end
        hoveredGenerator.halo:Hide()
        hoveredGenerator = nil
        GameTooltip:Hide()
        if window:IsVisible() then addon.SetBindingOutlines(sourcePanels, {}) end
    end

    refreshGeneratorHover = function()
        local generator = hoveredGenerator
        if not generator or not window:IsVisible() then return end
        local groups = groupsFor(generator.layer)
        local panels = {}
        local tooltip = GameTooltip
        tooltip:SetOwner(generator.button, "ANCHOR_RIGHT")
        tooltip:SetText(generator.button:GetText())
        if reserved(generator.layer) then
            tooltip:AddLine(tr("Cette combinaison utilise ton modificateur d’auto-incantation.",
                "This combination uses your self-cast modifier."), 1, 0.82, 0.36, true)
        elseif #groups == 0 then
            tooltip:AddLine(missingTarget(generator.layer), 1, 0.82, 0.36, true)
        else
            for _, group in ipairs(groups) do
                panels[#panels + 1] = group.panel
                local source, target, matched, keyed = compareSlots(bases, group, pending, sourceOffset)
                tooltip:AddLine(tr("%s · %d boutons Base, %d en cible, %d positions communes.",
                    "%s · %d Base buttons, %d target buttons, %d matching positions.")
                    :format(group.panel.name, source, target, matched), 1, 1, 1, true)
                local reason = not group.usable and group.bars[1].blocked
                if reason then tooltip:AddLine(reason, 1, 0.82, 0.36, true) end
                if target ~= keyed then
                    tooltip:AddLine(tr("%d boutons cibles sans raccourci Base correspondant.",
                        "%d target buttons have no matching Base shortcut."):format(target - keyed),
                        1, 0.82, 0.36, true)
                end
                if matched < source then
                    tooltip:AddLine(tr("%d positions Base sans bouton cible.",
                        "%d Base positions have no target button."):format(source - matched),
                        1, 0.82, 0.36, true)
                end
            end
        end
        addon.SetBindingOutlines(sourcePanels, panels)
        if #panels > 0 then placeHalo(generator.halo, generator.button, generator.button)
        else generator.halo:Hide() end
        tooltip:Show()
    end

    ui.label(window, tr("Générer par combinaison", "Generate by combination"), 18, -239)
    local offsetLabel=ui.label(window,"",307,-239,"GameFontHighlightSmall")
    local offsetSlider=CreateFrame("Slider",nil,window,"OptionsSliderTemplate")
    offsetSlider.Low:Hide()
    offsetSlider.High:Hide()
    offsetSlider:SetPoint("TOPLEFT",465,-235)
    offsetSlider:SetSize(178,15)
    offsetSlider:SetMinMaxValues(0,35)
    offsetSlider:SetValueStep(1)
    offsetSlider:SetObeyStepOnDrag(true)
    offsetSlider:SetValue(0)
    local function offsetCaption()
        offsetLabel:SetText(tr("Décalage source : %d","Source offset: %d"):format(sourceOffset))
    end
    offsetCaption()
    offsetSlider:SetScript("OnValueChanged",function(_,value)
        local newOffset = math.floor(value + .5)
        if newOffset == sourceOffset then return end
        sourceOffset, remapTotems = newOffset, true
        offsetCaption()
        if next(selected) then
            for target in pairs(selected) do selected[target] = true end
        else
            local onlyLayer
            for _,target in ipairs(targets) do
                if not target.blocked then
                    if onlyLayer and onlyLayer~=target.layer then onlyLayer=false; break end
                    onlyLayer=target.layer
                end
            end
            if onlyLayer then
                for _,target in ipairs(targets) do
                    if target.layer==onlyLayer and not target.blocked then selected[target]=true end
                end
            end
        end
        if redraw then approved={}; redraw() end
    end)
    for index, layer in ipairs(generationLayers) do
        local generator = {layer = layer}
        generators[index] = generator
        local button = ui.button(window, tr("Générer les raccourcis du cadre %s",
            "Generate shortcuts for the %s frame"):format(addon.LayerLabel(layer)), 18, -256, 644, function()
            local groups = groupsFor(layer)
            if reserved(layer) then
                status:SetText(tr("Cette combinaison utilise ton modificateur d’auto-incantation.",
                    "This combination uses your self-cast modifier."))
                return
            end
            if #groups == 0 then status:SetText(missingTarget(layer)); return end

            cancelCapture()
            selected, approved = {}, {}
            remapTotems = true
            for _, group in ipairs(groups) do
                for _, bar in ipairs(group.bars) do
                    if not bar.blocked then selected[bar] = true end
                end
            end
            status:SetText(next(selected) and "" or (groups[1].bars[1].blocked or ""))
            redraw()
        end)
        button:SetHeight(22)
        generator.button = button
        button:SetMotionScriptsWhileDisabled(true)
        generator.halo = makeHalo(button, nil, {0.29, 0.95, 0.41})
        button:HookScript("OnEnter", function()
            if not window:IsVisible() then return end
            clearGeneratorHover()
            hoveredGenerator = generator
            refreshGeneratorHover()
        end)
        button:HookScript("OnLeave", function()
            if hoveredGenerator == generator then clearGeneratorHover() end
        end)
    end
    local missingHelp = text(tr(
        "Pour activer un bouton grisé, crée un cadre associé à la combinaison et lie-le à des barres d’action.",
        "To enable a greyed-out button, create a frame for the combination and link it to action bars."), 18, 0)
    missingHelp:SetTextColor(0.72, 0.76, 0.81)

    local function layoutGenerators()
        local configured, missing = {}, {}
        for _, generator in ipairs(generators) do
            local exists = #groupsFor(generator.layer) > 0
            local group = exists and configured or missing
            group[#group + 1] = generator
            generator.button:SetEnabled(exists and not reserved(generator.layer))
        end
        local function placeGroup(group, top)
            for index, generator in ipairs(group) do
                generator.button:ClearAllPoints()
                generator.button:SetPoint("TOPLEFT", window, "TOPLEFT",
                    18, top - (index - 1) * 24)
            end
            return top - #group * 24
        end
        local afterConfigured = placeGroup(configured, -256)
        missingHelp:SetShown(#missing > 0)
        if #missing > 0 then
            missingHelp:ClearAllPoints()
            missingHelp:SetPoint("TOPLEFT", window, "TOPLEFT", 18, afterConfigured - 2)
            placeGroup(missing, afterConfigured - 23)
        end
    end
    text(tr("Applique chaque combinaison séparément. Survole un bouton pour vérifier ses cibles.",
        "Apply each modifier combination separately. Hover over a button to check its targets."), 18, -450)
    ui.label(window, tr("Aperçu des changements", "Preview changes"), 18, -470)
    text(tr("Coche un conflit pour le remplacer. Clic droit sur une touche pour la retirer.",
        "Check a conflict to replace it. Right-click a key to remove it."), 18, -489)
    local bulk=CreateFrame("CheckButton",nil,window,"UICheckButtonTemplate")
    bulk:SetPoint("TOPLEFT",385,-464)
    bulk:SetSize(24,24)
    local bulkLabel=ui.label(window,tr("Accepter tous les conflits","Accept all conflicts"),414,-470,"GameFontHighlightSmall")
    bulk:SetHitRectInsets(0,-bulkLabel:GetStringWidth(),0,0)
    bulk:SetScript("OnClick",function(self)
        local checked=self:GetChecked()
        local rows=previewChanges(bases,targets,selected,pending,approved,sourceOffset,excluded,remapTotems)
        for _,row in ipairs(rows) do
            if row.conflict and not row.blocked then
                approved[row.key]=checked and {from=row.previous,to=row.action.command} or nil
            end
        end
        redraw()
    end)
    local scroll, content = scrollArea(-508, 74)

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
        item:SetScript("OnMouseUp", function(_, mouseButton)
            if mouseButton == "RightButton" then
                local row = item.data
                removeShortcut(row.action, row.key, row.bar, row.slot)
            end
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
            overlay:RegisterForClicks("RightButtonUp")
            overlay:SetScript("OnClick", function(self)
                removeShortcut(self.action, self.bindingKey)
            end)
            overlay:SetScript("OnEnter", function(self) highlight(self.action, self.previewRow) end)
            overlay:SetScript("OnLeave", clearHalo)
            targetOverlays[index] = overlay
        end
        overlay.action, overlay.previewRow, overlay.bindingKey = row.action, item, row.key
        overlay:ClearAllPoints()
        overlay:SetAllPoints(row.action.button)
        overlay:SetText(redKey(row.key))
        overlay:Show()
        targetControls[row.action.button] = {widget = item, overlay = overlay}
    end

    local function frameToClear()
        local only
        for target in pairs(selected) do
            if target.panel == openedFrame then return openedFrame end
            if only and only ~= target.panel then return openedFrame end
            only = target.panel
        end
        return only or openedFrame
    end

    redraw = function(resetScroll)
        refreshSlots()
        sourceMenu:OverrideText(filter and filter.label or allBars)
        if hoveredGenerator then refreshGeneratorHover()
        else addon.SetBindingOutlines(sourcePanels, {}) end
        local rows = previewChanges(bases, targets, selected, pending, approved, sourceOffset, excluded, remapTotems)
        local actionable, overlayCount = false, 0
        local conflicts, accepted=0,0
        wipe(targetControls)
        for _, row in ipairs(rows) do
            local control = row.clear and controls[row.action.button]
            if control and remapTotems then control.overlay:SetText("—") end
        end
        for index, row in ipairs(rows) do
            local item = getRow(index)
            item.data = row
            local detail = row.blocked
                or (row.conflict and tr("déjà lié à %s", "already bound to %s"):format(bindingName(row.previous)))
                or (row.current and tr("déjà assigné", "already assigned"))
            item.caption:SetText(redKey(row.key) .. " → " .. row.label .. (detail and " · " .. detail or ""))
            item.check:SetShown(row.conflict and not row.blocked or false)
            item.check:SetChecked(not not row.approved)
            if row.conflict and not row.blocked then
                conflicts=conflicts+1
                if row.approved then accepted=accepted+1 end
            end
            item:Show()
            local action = row.action
            if not row.clear and not row.blocked and action and action.button and action.button:IsVisible() then
                local existing=controls[action.button]
                if existing then
                    existing.overlay.bindingPreview = row
                    existing.overlay:SetText(redKey(row.key))
                elseif not targetControls[action.button] then
                    overlayCount=overlayCount+1
                    drawTargetOverlay(overlayCount,item,row)
                end
            end
            if not row.blocked and not row.current and (not row.conflict or row.approved) then actionable = true end
        end
        for index = #rows + 1, #preview do preview[index]:Hide() end
        for index = overlayCount + 1, #targetOverlays do targetOverlays[index]:Hide() end
        bulk:SetEnabled(conflicts>0)
        bulk:SetChecked(conflicts>0 and conflicts==accepted)
        content:SetHeight(math.max(#rows * 26, 1))
        if resetScroll then
            scroll:SetVerticalScroll(0)
            baseScroll:SetVerticalScroll(0)
        end
        apply:SetEnabled(actionable and not InCombatLockdown())
        clearFrameButton:SetEnabled(frameToClear() ~= nil and not InCombatLockdown())
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
    clearFrameButton = ui.button(window, tr("Désassigner le cadre", "Clear frame keybindings"), 253, -620, 244, function()
        local panel = frameToClear()
        if not panel or InCombatLockdown() then return end
        cancelCapture()
        ui.confirm(tr("Désassigner tous les raccourcis du cadre « %s » ?",
            "Clear all keybindings for the “%s” frame?"):format(panel.name), function()
            local ok, changed = saveChanges(frameShortcuts(panel))
            if not ok then
                status:SetText(tr("Impossible de désassigner les raccourcis du cadre.",
                    "Could not clear the frame keybindings."))
                return
            end
            local commands = {}
            local function collectCommands(bar)
                for _, action in pairs(bar.slots) do commands[action.command] = true end
            end
            for _, bar in ipairs(bases) do
                if bar.panel == panel then
                    pending[bar] = nil
                    collectCommands(bar)
                end
            end
            for _, target in ipairs(targets) do
                if target.panel == panel then
                    collectCommands(target)
                    -- Keep the combination available for the next slider change.
                    if selected[target] then selected[target] = false end
                end
            end
            for key in pairs(excluded) do
                if commands[key:match("^[^%z]+")] then excluded[key] = nil end
            end
            approved = {}
            status:SetText(changed > 0 and tr("Raccourcis du cadre désassignés.", "Frame keybindings cleared.")
                or tr("Ce cadre n’a aucun raccourci enregistré.", "This frame has no saved keybindings."))
            redraw()
        end)
    end)
    apply = ui.button(window, tr("Appliquer", "Apply"), 502, -620, 160, function()
        cancelCapture()
        local rows = previewChanges(bases, targets, selected, pending, approved, sourceOffset, excluded, remapTotems)
        local ok, changed = saveChanges(rows)
        if ok then
            for _, row in ipairs(rows) do
                local staged = row.bar and pending[row.bar]
                if staged and staged[row.slot] == row.key
                    and GetBindingAction(row.key, false, row.action.context) == row.action.command then
                    staged[row.slot] = nil
                end
            end
        end
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
    function assistant:Open(frame)
        cancelCapture()
        openedFrame, excluded = frame, {}
        bases, targets = eligibleBars(nativeCommands(),frame)
        targetGroups = groupTargets(targets)
        layoutGenerators()
        sourcePanels = uniquePanels(bases)
        pending, selected, approved = {}, {}, {}
        filter = false
        local maxOffset=0
        for _,bar in ipairs(bases) do
            if not bar.direct then maxOffset=math.max(maxOffset,(bar.slotCount or 12)-1) end
        end
        sourceOffset, remapTotems = 0, false
        offsetSlider:SetValue(0)
        offsetSlider:SetMinMaxValues(0,math.max(1,maxOffset))
        offsetSlider:SetEnabled(maxOffset>0)
        offsetCaption()
        for _,bar in ipairs(bases) do
            if bar.panel==frame and (not filter or bar.direct) then filter=bar end
        end
        for _,target in ipairs(targets) do
            if target.panel==frame and not target.blocked then selected[target]=true end
        end
        self:Show()
        status:SetText("")
        redraw(true)
        if not bases[1] then
            status:SetText(tr("Pour générer des raccourcis, enregistre un cadre lié à une barre avec le déclencheur Base.",
                "To generate keybindings, save a frame linked to an action bar with the Base trigger."))
        end
    end
    return assistant
end
