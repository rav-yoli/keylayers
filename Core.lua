local addonName, addon = ...
addon.title = "KeyLayers by Rav Yoli"
local getMetadata = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
addon.version = getMetadata and getMetadata(addonName, "Version") or "1.1.10b"
-- ProfileSync scans globals before our ADDON_LOADED handler and recognizes
-- character data by name. Keep this a plain, character-scoped saved table.
local emptyCharacterLayout = {panels = {}, mode = "hold", learning = false}
KeyLayersCharLayout = KeyLayersCharLayout or KeyLayersLayout or BartenderGlowLayout or emptyCharacterLayout
KeyLayersLayout, BartenderGlowLayout = nil, nil
local initialized = false

local root = UIParent
local layers = {
    "base", "ctrl", "maj", "alt", "ctrl+maj", "ctrl+alt", "maj+alt", "ctrl+maj+alt",
}
addon.layers = layers
-- Reserve room for both paint layers, their borders, and the learning tab.
local levelsPerPanel = 6

function addon.Copy(source)
    local copy = {}
    for key, value in pairs(source) do
        copy[key] = type(value) == "table" and addon.Copy(value) or value
    end
    return copy
end

function addon.NewPanel(name)
    return {
        name = name, kind = "free", bars = {}, blizzardBars = {}, layer = "never", activationMode = "none", hintOverride = false, useDefaultStyle = true,
        x = 0, y = 0, width = 240, height = 100, padding = 8,
        fill = "101821", fillAlpha = 0.64, border = "65CCFF", borderAlpha = 1,
        thickness = 4, depth = 0, linger = 0.25, fade = 0.25,
    }
end

local selfCastLayers = {CTRL = "ctrl", SHIFT = "maj", ALT = "alt"}

local function heldLayer()
    local keys = {}
    if IsControlKeyDown() then keys[#keys + 1] = "ctrl" end
    if IsShiftKeyDown() then keys[#keys + 1] = "maj" end
    if IsAltKeyDown() then keys[#keys + 1] = "alt" end
    local layer = #keys > 0 and table.concat(keys, "+") or "base"
    if #keys > 1 then
        local setting = GetModifiedClick and GetModifiedClick("SELFCAST")
        local selfCast = selfCastLayers[setting]
        for index, key in ipairs(keys) do
            if key == selfCast then
                table.remove(keys, index)
                return layer, selfCast, table.concat(keys, "+")
            end
        end
    end
    return layer
end

addon.fillTextures = {
    marble = [[Interface\FrameGeneral\UI-Background-Marble]],
    stone = [[Interface\FrameGeneral\UI-Background-Rock]],
    parchment = [[Interface\AchievementFrame\UI-Achievement-Parchment-Horizontal]],
    dialog = [[Interface\DialogFrame\UI-DialogBox-Background]],
    tooltip = [[Interface\Tooltips\UI-Tooltip-Background]],
}
addon.borderTextures = {
    dialog = {file = [[Interface\DialogFrame\UI-DialogBox-Border]], size = 14},
    gold = {file = [[Interface\DialogFrame\UI-DialogBox-Gold-Border]], size = 14},
    chat = {file = [[Interface\Tooltips\ChatBubble-Backdrop]], size = 16},
    wood = {file = [[Interface\AchievementFrame\UI-Achievement-WoodBorder]], size = 16},
    tooltip = {file = [[Interface\Tooltips\UI-Tooltip-Border]], size = 12},
}

local function rgb(hex)
    return tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255,
        tonumber(hex:sub(5, 6), 16) / 255
end

local function tint(texture, hex, alpha)
    local r, g, b = rgb(hex)
    texture:SetColorTexture(r, g, b, alpha)
end

function addon.CreatePaint(frame, anchor)
    anchor = anchor or frame
    frame.paint = CreateFrame("Frame", nil, anchor)
    frame.paint:SetAllPoints(anchor)
    frame.borderPaint = CreateFrame("Frame", nil, frame.paint)
    frame.borderPaint:SetAllPoints(frame.paint)
    frame.borderPaint:EnableMouse(false)
    frame.fill = frame.paint:CreateTexture(nil, "BACKGROUND")
    frame.fill:SetAllPoints(frame.paint)
    frame.edges = {}
    local function edge(first, second, horizontal)
        local texture = frame.borderPaint:CreateTexture(nil, "BORDER")
        frame.edges[#frame.edges + 1] = {texture = texture, horizontal = horizontal,
            first = first, second = second}
    end
    edge("TOPLEFT", "TOPRIGHT", true)
    edge("BOTTOMLEFT", "BOTTOMRIGHT", true)
    edge("TOPLEFT", "BOTTOMLEFT", false)
    edge("TOPRIGHT", "BOTTOMRIGHT", false)
end

function addon.PaintStyle(frame, panel)
    local fill = addon.fillTextures[panel.fillTexture]
    if fill then
        frame.fill:SetTexture(fill)
        frame.fill:SetVertexColor(1, 1, 1, panel.fillAlpha)
    else
        frame.fill:SetVertexColor(1, 1, 1, 1)
        tint(frame.fill, panel.fill, panel.fillAlpha)
    end

    local border = addon.borderTextures[panel.borderTexture]
    local native = frame.nativeBorder
    local thickness = math.min(border and border.size or panel.thickness, frame.width / 2, frame.height / 2)
    local strata = panel.borderOnTop ~= false and "HIGH" or frame.paint:GetFrameStrata()
    if frame.borderPaint:GetFrameStrata() ~= strata then frame.borderPaint:SetFrameStrata(strata) end
    if border and thickness > 0 then
        if not native then
            native = CreateFrame("Frame", nil, frame.borderPaint, "BackdropTemplate")
            native:SetAllPoints(frame.borderPaint)
            native:SetFrameLevel(frame.borderPaint:GetFrameLevel() + 1)
            frame.nativeBorder = native
        end
        if native.edgeFile ~= border.file or native.edgeSize ~= thickness then
            native:SetBackdrop({edgeFile = border.file, edgeSize = thickness})
            native.edgeFile, native.edgeSize = border.file, thickness
        end
        native:SetBackdropBorderColor(1, 1, 1, panel.borderAlpha)
        native:SetShown(true)
    elseif native then
        native:SetShown(false)
    end

    for _, edge in ipairs(frame.edges) do
        tint(edge.texture, panel.border, panel.borderAlpha)
        if edge.horizontal then
            edge.texture:SetHeight(thickness)
        else
            edge.texture:SetWidth(thickness)
        end
        if edge.inset ~= thickness then
            local inset = edge.horizontal and 0 or thickness
            edge.texture:ClearAllPoints()
            edge.texture:SetPoint(edge.first, frame.borderPaint, edge.first, 0, -inset)
            edge.texture:SetPoint(edge.second, frame.borderPaint, edge.second, 0, inset)
            edge.inset = thickness
        end
        edge.texture:SetShown(not border and thickness > 0)
    end
end

local hintAnchors = {
    top = {"BOTTOM", "TOP"},
    ["top-start"] = {"BOTTOMLEFT", "TOPLEFT"},
    ["top-end"] = {"BOTTOMRIGHT", "TOPRIGHT"},
    bottom = {"TOP", "BOTTOM"},
    ["bottom-start"] = {"TOPLEFT", "BOTTOMLEFT"},
    ["bottom-end"] = {"TOPRIGHT", "BOTTOMRIGHT"},
    left = {"RIGHT", "LEFT"},
    ["left-start"] = {"TOPRIGHT", "TOPLEFT"},
    ["left-end"] = {"BOTTOMRIGHT", "BOTTOMLEFT"},
    right = {"LEFT", "RIGHT"},
    ["right-start"] = {"TOPLEFT", "TOPRIGHT"},
    ["right-end"] = {"BOTTOMLEFT", "BOTTOMRIGHT"},
}

function addon.CreateHint(frame)
    frame.tab = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.tab.bg = frame.tab:CreateTexture(nil, "BACKGROUND")
    frame.tab.bg:SetAllPoints()
    frame.tab.text = frame.tab:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.tab.text:SetPoint("CENTER")
    frame.tab.text:SetJustifyH("CENTER")
    frame.tab.text:SetJustifyV("MIDDLE")
end

function addon.GlobalHints()
    local layout = KeyLayersCharLayout
    if not layout.hintSettings then
        layout.hintSettings = {hint = true, hintSide = "top-start", hintOrientation = "horizontal"}
    end
    return layout.hintSettings
end

function addon.HasHintOverride(panel)
    if panel.hintOverride ~= nil then return panel.hintOverride end
    return panel.hint ~= nil
end

function addon.HintSettings(panel)
    return addon.HasHintOverride(panel) and panel or addon.GlobalHints()
end

function addon.LayoutHint(frame, panel)
    local tab = frame.tab
    local hold = addon.HoldLayer(panel)
    local key = addon.PanelToggleKey(panel)
    local label = hold and addon.LayerLabel(hold) or ""
    if key then
        label = (hold and label .. " / " or "") .. (GetBindingText and GetBindingText(key) or key)
    end
    local settings = addon.HintSettings(panel)
    local side, vertical = settings.hintSide, settings.hintOrientation == "vertical"
    if tab.label == label and tab.side == side and tab.vertical == vertical then return end
    tab.label, tab.side, tab.vertical = label, side, vertical
    if tab.text.SetRotation then tab.text:SetRotation(0) end
    tab.text:SetText(label)
    local width = math.max(42, tab.text:GetStringWidth() + 16)
    tab.text:SetSize(width, 24)
    local rotate = vertical and tab.text.SetRotation
    tab:SetSize(rotate and 24 or width, rotate and width or 24)
    tab.text:ClearAllPoints()
    -- Compensate for the vertical font's optical offset in the rotated tab.
    tab.text:SetPoint("CENTER", tab, "CENTER", rotate and -3 or 0, rotate and -4 or 0)
    if rotate then tab.text:SetRotation(math.pi / 2) end
    tab:ClearAllPoints()
    local anchors = hintAnchors[side]
    if anchors then tab:SetPoint(anchors[1], frame, anchors[2])
    else tab:SetPoint("BOTTOMLEFT", frame, "TOPLEFT") end
end

function addon.HintVisibleForFrame(panel)
    if panel.hintVisible ~= nil then return panel.hintVisible end
    return addon.HintSettings(panel).hint
end

function addon.HasHint(panel)
    return addon.GlobalHints().hint and addon.HintVisibleForFrame(panel) and (addon.HoldLayer(panel) or addon.PanelToggleKey(panel))
end

function addon.TintHint(tab, panel, active)
    local border = addon.borderTextures[panel.borderTexture]
    local edge = border and border.file
    local size = border and math.min(10, border.size)
    if tab.hintEdge ~= edge or tab.hintEdgeSize ~= size then
        tab:SetBackdrop(edge and {edgeFile = edge, edgeSize = size} or nil)
        tab.hintEdge, tab.hintEdgeSize = edge, size
    end
    local r, g, b = rgb(panel.border)
    if edge then
        r, g, b = 1, 1, 1
        tab:SetBackdropBorderColor(r, g, b, panel.borderAlpha)
    end
    tab.bg:SetShown(active)
    if not active then
        tab.text:SetTextColor(r, g, b, 1)
        tab.text:SetShadowOffset(1, -1)
    elseif edge then
        local fill = addon.fillTextures[panel.fillTexture]
        if fill then
            tab.bg:SetTexture(fill)
            tab.bg:SetVertexColor(1, 1, 1, 1)
        else
            tab.bg:SetVertexColor(1, 1, 1, 1)
            tint(tab.bg, panel.fill, 1)
        end
        tab.text:SetTextColor(1, 1, 1, 1)
        tab.text:SetShadowOffset(1, -1)
    else
        tab.bg:SetVertexColor(1, 1, 1, 1)
        tint(tab.bg, panel.border, 1)
        tab.text:SetTextColor(0.035, 0.05, 0.07, 1)
        tab.text:SetShadowOffset(0, 0)
    end
end

local function newEffect()
    local frame = CreateFrame("Frame", nil, root)
    frame:EnableMouse(false)
    frame:SetFrameStrata("BACKGROUND")
    frame:Hide()
    addon.CreatePaint(frame)

    addon.CreateHint(frame)
    return frame
end

local tr = addon.Translate
local blizzardBars = {
    "MainActionBar", "MultiBarBottomLeft", "MultiBarBottomRight",
    "MultiBarRight", "MultiBarLeft", "MultiBar5", "MultiBar6", "MultiBar7",
}
addon.barCounts = {bars = 15, blizzard = #blizzardBars}
addon.linkedKinds = {
    "bars", "blizzard", "micro", "xp", "bartenderXP", "bartenderBags", "bartenderPet", "bartenderStance",
    "bartenderExtra", "bartenderVehicle", "bartenderQueue", "bartenderTotems", "questie",
}
addon.kindLabels = {
    free = tr("Cadre libre", "Free frame"),
    bars = "Bartender4",
    blizzard = tr("Barres Blizzard", "Blizzard bars"),
    micro = tr("Menu d’icônes", "Micro menu"),
    xp = tr("Barre d’XP / progression", "XP / progress bar"),
    bartenderXP = tr("Barre d’XP Bartender4", "Bartender4 XP bar"),
    bartenderBags = tr("Barre de sacs Bartender4", "Bartender4 bag bar"),
    bartenderPet = tr("Familier (Bartender4)", "Pet bar (Bartender4)"),
    bartenderStance = tr("Postures (Bartender4)", "Stance bar (Bartender4)"),
    bartenderExtra = tr("Action supplémentaire (BT4)", "Extra action bar (BT4)"),
    bartenderVehicle = tr("Véhicule (Bartender4)", "Vehicle bar (Bartender4)"),
    bartenderQueue = tr("File d’attente (Bartender4)", "Queue status (Bartender4)"),
    bartenderTotems = tr("Totems (Bartender4)", "Totem bar (Bartender4)"),
    questie = tr("Suivi Questie", "Questie tracker"),
}
local linkedFrames = {
    micro = {"MicroMenu", "MicroMenuContainer"},
    xp = {"MainStatusTrackingBarContainer", "MainMenuExpBar", "StatusTrackingBarManager"},
    bartenderXP = {"BT4BarStatus"},
    bartenderBags = {"BT4BarBagBar"},
    bartenderPet = {"BT4BarPetBar"},
    bartenderStance = {"BT4BarStanceBar"},
    bartenderExtra = {"BT4BarExtraActionBar"},
    bartenderVehicle = {"BT4BarVehicle"},
    bartenderQueue = {"BT4BarQueueStatus"},
    bartenderTotems = {"BT4BarTotemBar"},
    questie = {"Questie_BaseFrame"},
}
local buttonBars = {bartenderBags = true, bartenderPet = true, bartenderStance = true, bartenderTotems = true}

-- The numbers shown in Bartender4's modern layout differ from its internal bar IDs.
local bartenderNumbers = {[1] = 1, [6] = 2, [5] = 3, [3] = 4, [4] = 5, [13] = 6, [14] = 7, [15] = 8}
local build = GetBuildInfo and select(4, GetBuildInfo()) or 0
local modernBartender = (build >= 16001 and build < 20000)
    or (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE and build > 120000)

function addon.BarLabel(kind, id)
    if kind == "bars" and modernBartender then
        if id == 2 then return "B+", tr("Barre d’action bonus", "Bonus action bar") end
        if id >= 7 and id <= 10 then
            local number = id - 6
            return "C" .. number, tr("Barre de classe %d", "Class bar %d"):format(number)
        end
        id = bartenderNumbers[id] or id
    end
    return tostring(id), tr("Barre %d", "Bar %d"):format(id)
end

function addon.BarSelection(panel)
    if panel.kind == "bars" then return panel.bars end
    if panel.kind == "blizzard" then
        panel.blizzardBars = panel.blizzardBars or {}
        return panel.blizzardBars
    end
end

local function union(bounds, left, bottom, right, top)
    bounds.left, bounds.bottom = math.min(bounds.left, left), math.min(bounds.bottom, bottom)
    bounds.right, bounds.top = math.max(bounds.right, right), math.max(bounds.top, top)
end

local function visibleRect(frame, rootScale)
    if not frame or not frame:IsVisible() then return end
    local left, bottom, width, height = frame:GetRect()
    if not left or not bottom or not width or not height or width <= 0 or height <= 0 then return end
    local scale = frame:GetEffectiveScale() / rootScale
    return left * scale, bottom * scale, (left + width) * scale, (bottom + height) * scale
end

local function includeFrame(bounds, frame, rootScale)
    local left, bottom, right, top = visibleRect(frame, rootScale)
    if not left then return bounds end
    if not bounds then return {left = left, bottom = bottom, right = right, top = top} end
    union(bounds, left, bottom, right, top)
    return bounds
end

local function boundsForFrames(frames, rootScale)
    local bounds
    for _, frame in pairs(frames) do
        bounds = includeFrame(bounds, frame, rootScale)
    end
    return bounds
end

local function boundsForLinkedFrame(kind, frame, rootScale)
    if not frame:IsVisible() then return end
    if buttonBars[kind] and type(frame.buttons) == "table" then
        return boundsForFrames(frame.buttons, rootScale)
    end
    if kind == "bartenderXP" then
        local manager = frame.manager or BT4StatusTrackingBarManager
        if manager and type(manager.barContainers) == "table" then
            return boundsForFrames(manager.barContainers, rootScale)
        end
    elseif kind == "xp" and type(frame.bars) == "table" then
        return boundsForFrames(frame.bars, rootScale)
    elseif kind == "bartenderVehicle" or kind == "bartenderQueue" then
        frame = frame.content or frame
    elseif kind == "bartenderExtra" and frame.content and not frame.content:IsVisible() then
        return
    end
    return includeFrame(nil, frame, rootScale)
end

local function boundsForMicroMenu(frame, rootScale)
    if not frame:IsVisible() then return end
    if type(frame.buttons) == "table" then
        local bounds = boundsForFrames(frame.buttons, rootScale)
        if HelpMicroButton and HelpMicroButton:GetParent() == frame then
            bounds = includeFrame(bounds, HelpMicroButton, rootScale)
        end
        return bounds
    end
    local bounds, hasButtons
    for _, child in ipairs({frame:GetChildren()}) do
        local name = child:GetName()
        if name and name:match("MicroButton$") then
            hasButtons = true
            bounds = includeFrame(bounds, child, rootScale)
        end
    end
    if hasButtons then return bounds end
    return includeFrame(nil, frame, rootScale)
end

function addon.BarActionButton(kind, id, slot)
    if kind == "bars" then
        return _G["BT4Button" .. ((id - 1) * 12 + slot)]
    end
    local bar = blizzardBars[id]
    local prefix = id == 1 and "ActionButton" or bar .. "Button"
    return _G[prefix .. slot]
end

function addon.NativeBarBinding(kind, id, slot)
    if kind == "bars" then
        id = bartenderNumbers[id]
    end
    if not id then return end
    if id == 1 then return "ACTIONBUTTON" .. slot end
    return "MULTIACTIONBAR" .. (id - 1) .. "BUTTON" .. slot
end

local barBounds = {bars = {}, blizzard = {}}
local function boundsForBar(kind, id, rootScale)
    local cache = barBounds[kind]
    if cache[id] ~= nil then return cache[id] end
    local bounds
    for slot = 1, 12 do
        local frame = kind == "blizzard" and _G[blizzardBars[id] .. "ButtonContainer" .. slot]
            or addon.BarActionButton(kind, id, slot)
        bounds = includeFrame(bounds, frame, rootScale)
    end
    cache[id] = bounds or false
    return bounds
end

local function panelBounds(panel, rootScale)
    if panel.kind == "free" then
        local left = (root:GetWidth() - panel.width) / 2 + panel.x
        local bottom = (root:GetHeight() - panel.height) / 2 + panel.y
        return left, bottom, panel.width, panel.height
    end

    local bounds
    if panel.kind == "chat" then
        bounds = includeFrame(nil, panel.chatId and _G["ChatFrame" .. panel.chatId], rootScale)
    -- Bartender4 reparents the icon buttons and returns them to Blizzard for alternate UI states.
    elseif panel.kind == "micro" and BT4BarMicroMenu and CharacterMicroButton
        and CharacterMicroButton:GetParent() == BT4BarMicroMenu then
        bounds = boundsForMicroMenu(BT4BarMicroMenu, rootScale)
    elseif linkedFrames[panel.kind] then
        for _, name in ipairs(linkedFrames[panel.kind]) do
            local frame = _G[name]
            if frame then
                if panel.kind == "micro" then
                    bounds = boundsForMicroMenu(frame, rootScale)
                else
                    bounds = boundsForLinkedFrame(panel.kind, frame, rootScale)
                end
                break
            end
        end
    else
        for id in pairs(addon.BarSelection(panel) or {}) do
            if type(id) == "number" and id >= 1 and id <= addon.barCounts[panel.kind] and id % 1 == 0 then
                local bar = boundsForBar(panel.kind, id, rootScale)
                if bar then
                    if bounds then
                        union(bounds, bar.left, bar.bottom, bar.right, bar.top)
                    else
                        bounds = addon.Copy(bar)
                    end
                end
            end
        end
    end
    if not bounds then return end
    local margin = panel.padding
    return bounds.left - margin, bounds.bottom - margin,
        bounds.right - bounds.left + margin * 2, bounds.top - bounds.bottom + margin * 2
end

function addon.GetPanelGeometry(panel)
    if panel.kind == "free" then return panel end
    local left, bottom, width, height = panelBounds(panel, root:GetEffectiveScale())
    if not left then return end
    local function round(value)
        return math.floor(value * 100 + 0.5) / 100
    end
    return {
        x = round(left + (width - root:GetWidth()) / 2),
        y = round(bottom + (height - root:GetHeight()) / 2),
        width = round(width),
        height = round(height),
    }
end

local effects = {}
local activeLayer, heldSelfCast, heldWithoutSelfCast = "base"

local previewIndex, previewPanel, previewInactive

addon.styleKeys = {"fill", "fillAlpha", "fillTexture", "border", "borderAlpha", "borderTexture", "thickness", "borderOnTop"}
function addon.CopyStyle(source, target)
    for _, key in ipairs(addon.styleKeys) do target[key] = source[key] end
end

function addon.EditStyle(panel)
    return previewInactive and panel.inactiveStyle or panel, not previewInactive
end

function addon.SetDraftPreview(index, panel, inactive)
    previewIndex, previewPanel, previewInactive = index, panel, inactive
    addon.Refresh()
end

local function setPaintLevel(layer, level)
    layer.paint:SetFrameLevel(level)
    layer.borderPaint:SetFrameLevel(level)
    if layer.nativeBorder then layer.nativeBorder:SetFrameLevel(level + 1) end
end

local function refresh()
    local layout = KeyLayersCharLayout
    if not layout then return end
    barBounds = {bars = {}, blizzard = {}}
    local scale = root:GetEffectiveScale()
    local count = #layout.panels
    local draftIndex = previewPanel and (previewIndex or count + 1)
    if draftIndex then count = math.max(count, draftIndex) end
    for index = 1, count do
        local panel = index == draftIndex and previewPanel or layout.panels[index]
        local frame = effects[index]
        if not frame then
            frame = newEffect()
            effects[index] = frame
        end
        local left, bottom, width, height = panelBounds(panel, scale)
        local level = panel.depth * levelsPerPanel
        local defaultStyle = not panel.useDefaultStyle and panel.inactiveStyle
        if defaultStyle and not frame.defaultLayer then
            frame.defaultLayer = {}
            addon.CreatePaint(frame.defaultLayer, frame)
        end
        if left then
            if left ~= frame.left or bottom ~= frame.bottom then
                frame:ClearAllPoints()
                frame:SetPoint("BOTTOMLEFT", root, "BOTTOMLEFT", left, bottom)
                frame.left, frame.bottom = left, bottom
            end
            if width ~= frame.width or height ~= frame.height then
                frame.dirty = true
                frame:SetSize(width, height)
                frame.width, frame.height = width, height
            end
            local layered = not not defaultStyle
            if level ~= frame.level or layered ~= frame.layered then
                frame:SetFrameLevel(level)
                if frame.defaultLayer then setPaintLevel(frame.defaultLayer, level + 1) end
                setPaintLevel(frame, level + (layered and 3 or 1))
                frame.tab:SetFrameLevel(level + (layered and 5 or 2))
                frame.level, frame.layered = level, layered
            end
        end

        if frame.panel ~= panel or frame.dirty or (left and not frame.hasBounds) then
            if defaultStyle and left then
                frame.defaultLayer.width, frame.defaultLayer.height = width, height
                addon.PaintStyle(frame.defaultLayer, defaultStyle)
            end
            frame.appliedStyle = nil
            addon.LayoutHint(frame, panel)
            frame.tabBorder = nil
            frame.panel, frame.dirty = panel, nil
        end
        frame.hasBounds = left ~= nil
        frame.hasTab = not not addon.HasHint(panel)
    end
    for index = count + 1, #effects do
        effects[index]:Hide()
        effects[index].panel = nil
    end
    addon.UpdateEditOverlays(panelBounds, boundsForBar, layout, scale)
end

local hiddenCombatBackground

local function updateCombatBackground(background)
    if hiddenCombatBackground and hiddenCombatBackground ~= background then
        hiddenCombatBackground:Show()
        hiddenCombatBackground = nil
    end
    if background and background:IsShown() then
        background:Hide()
        hiddenCombatBackground = background
    end
end

local function hasVisiblePaint(style)
    return style.fillAlpha > 0
        or (style.borderAlpha > 0 and (addon.borderTextures[style.borderTexture] or style.thickness > 0))
end

local activePanels = {}
local function animate(updateHotkeys)
    local now = GetTime()
    local activeToggle = addon.ActiveToggle()
    local combatBackground
    if updateHotkeys then wipe(activePanels) end
    for _, frame in ipairs(effects) do
        local panel = frame.panel
        if panel then
            if frame.lastPanel ~= panel then
                frame.lastActive, frame.lastPanel = nil, panel
            end
            local hold = addon.HoldLayer(panel)
            local toggle = addon.PanelToggle(panel)
            local mode = (hold or toggle) and "triggered" or "none"
            local active = (mode == "none" and panel.layer == "always")
                or (hold and hold ~= "unmodified" and hold == activeLayer)
                or (toggle and addon.IsPanelToggled(panel, activeToggle) and (toggle ~= "base" or activeLayer == "base"))
                or (hold == "unmodified" and activeLayer == "base" and activeToggle == 0)
                or (hold and heldSelfCast ~= nil and (hold == heldSelfCast or hold == heldWithoutSelfCast))
            if updateHotkeys and active and mode ~= "none" then activePanels[panel] = true end
            local alpha = 0
            if active then
                frame.lastActive, alpha = now, 1
            elseif mode ~= "none" and frame.lastActive then
                local elapsed = now - frame.lastActive - panel.linger
                if elapsed <= 0 then alpha = 1
                elseif panel.fade > 0 then alpha = math.max(0, 1 - elapsed / panel.fade) end
            end
            local style = panel
            local showDefaultLayer = previewPanel ~= panel and mode ~= "none" and not panel.useDefaultStyle
                and panel.inactiveStyle ~= nil
            if frame.defaultLayer and frame.defaultLayer.paint:IsShown() ~= showDefaultLayer then
                frame.defaultLayer.paint:SetShown(showDefaultLayer)
            end
            if previewPanel == panel then
                style, alpha = addon.EditStyle(panel), 1
            elseif mode == "none" then
                style, alpha = panel.inactiveStyle or panel, 1
            elseif panel.useDefaultStyle then
                style = panel.inactiveStyle or panel
                alpha = active and 1 or 0
            end
            if frame.appliedStyle ~= style and frame.hasBounds then
                addon.PaintStyle(frame, style)
                frame.appliedStyle = style
            end
            if frame.alpha ~= alpha then
                frame.paint:SetAlpha(alpha)
                frame.alpha = alpha
            end
            if frame.tab:IsShown() ~= frame.hasTab then frame.tab:SetShown(frame.hasTab) end
            if frame.hasTab then
                local hintActive = active
                if previewPanel == panel then hintActive = not previewInactive end
                local hintStyle = showDefaultLayer and alpha == 0 and panel.inactiveStyle or style
                if frame.tabActive ~= hintActive or frame.tabBorder ~= hintStyle then
                    addon.TintHint(frame.tab, hintStyle, hintActive)
                    frame.tabActive, frame.tabBorder = hintActive, hintStyle
                end
            end
            local visible = frame.hasBounds and (alpha > 0 or showDefaultLayer or frame.hasTab)
                and not (addon.IsEditingPanel and addon.IsEditingPanel(panel))
            if frame:IsShown() ~= visible then frame:SetShown(visible) end
            if visible and panel.kind == "chat" then
                local chat = _G["ChatFrame" .. panel.chatId]
                local combatLog = COMBATLOG or _G.ChatFrame2
                if chat and chat == combatLog and ((alpha > 0 and hasVisiblePaint(style))
                    or (showDefaultLayer and hasVisiblePaint(panel.inactiveStyle))) then
                    combatBackground = _G["ChatFrame" .. panel.chatId .. "Background"] or chat.Background
                end
            end
        end
    end
    updateCombatBackground(combatBackground)
    if updateHotkeys then addon.UpdateGameplayHotkeys(activePanels) end
end

function addon.Refresh()
    for _, frame in ipairs(effects) do frame.dirty = true end
    activeLayer, heldSelfCast, heldWithoutSelfCast = heldLayer()
    refresh()
    animate(true)
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_LOGOUT")
events:RegisterEvent("MODIFIER_STATE_CHANGED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("UPDATE_BINDINGS")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function(self, event, loadedAddon)
    if event == "ADDON_LOADED" then
        if loadedAddon ~= addonName then return end
        self:UnregisterEvent("ADDON_LOADED")
        if KeyLayersCharLayout == emptyCharacterLayout then
            KeyLayersCharLayout = KeyLayersLayout or BartenderGlowLayout or emptyCharacterLayout
        end
        KeyLayersLayout, BartenderGlowLayout = nil, nil
    elseif event == "PLAYER_LOGIN" then
        KeyLayersProfiles = KeyLayersProfiles or BartenderGlowProfiles or {}
        KeyLayersNotices = KeyLayersNotices or BartenderGlowNotices or {}
        BartenderGlowProfiles, BartenderGlowNotices = nil, nil
        addon.MigrateActivation(KeyLayersCharLayout)
        addon.SyncSwitch(true)
        addon.RestoreFrameToggleKeys()
        initialized = true
        addon.InstallOptions()
        addon.Refresh()
    elseif initialized then
        if event == "PLAYER_LOGOUT" then
            addon.RememberFrameToggleKeys()
            return
        end
        if event == "UPDATE_BINDINGS" then addon.RememberFrameToggleKeys() end
        if event == "UPDATE_BINDINGS" or event == "PLAYER_ENTERING_WORLD" then addon.InvalidateGameplayHotkeys() end
        addon.SwitchEvent(event)
        addon.Refresh()
    end
end)

local elapsed = 0
events:SetScript("OnUpdate", function(_, delta)
    if not initialized then return end
    elapsed = elapsed + delta
    local updateHotkeys = elapsed >= 0.10
    if updateHotkeys then
        elapsed = 0
        refresh()
    end
    animate(updateHotkeys)
end)
