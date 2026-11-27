local addonName, addon = ...
addon.title = "KeyLayers by Rav Yoli"
local getMetadata = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
addon.version = getMetadata and getMetadata(addonName, "Version") or "2.1.11b"
-- ProfileSync scans globals before our ADDON_LOADED handler and recognizes
-- character data by name. Keep this a plain, character-scoped saved table.
local emptyCharacterLayout = {panels = {}, mode = "hold", learning = false}
KeyLayersCharLayout = KeyLayersCharLayout or KeyLayersLayout or BartenderGlowLayout or emptyCharacterLayout
KeyLayersLayout, BartenderGlowLayout = nil, nil
local initialized = false
local previewIndex, previewPanel, previewInactive, previewToggleKey, previewDefaultStyle, previewDimensions

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
        thickness = 2, borderTexture = "solid", depth = 0, linger = 0.25, fade = 0.25,
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

local strataOrder = {"BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG", "FULLSCREEN", "FULLSCREEN_DIALOG", "TOOLTIP"}
local strataRank = {}
for rank, strata in ipairs(strataOrder) do strataRank[strata] = rank end

local worldMapVisible, worldMapRank, mapLeft, mapBottom, mapRight, mapTop

local function visibleWorldMap()
    local map = _G.WorldMapFrame
    return map and map:IsVisible() and map or nil
end

local function updateWorldMapLayer(map)
    worldMapVisible = map ~= nil
    worldMapRank = map and strataRank[map:GetFrameStrata()]
    mapLeft = nil
    if not worldMapRank then return end
    local left, bottom, width, height = map:GetRect()
    if not left then return end
    local scale = map:GetEffectiveScale()
    mapLeft, mapBottom = left * scale, bottom * scale
    mapRight, mapTop = (left + width) * scale, (bottom + height) * scale
end

-- OpenMap renders inside WorldMapFrame. Lower only artwork that touches the map.
function addon.SetMapAwareStrata(frame, normalStrata, bounds)
    local strata = normalStrata
    if mapLeft and strataRank[strata] >= worldMapRank then
        bounds = bounds or frame
        local left, bottom, width, height = bounds:GetRect()
        if left then
            local scale = bounds:GetEffectiveScale()
            if left * scale < mapRight and (left + width) * scale > mapLeft
                and bottom * scale < mapTop and (bottom + height) * scale > mapBottom then
                strata = strataOrder[math.max(1, worldMapRank - 1)]
            end
        end
    end
    if frame:GetFrameStrata() ~= strata then frame:SetFrameStrata(strata) end
end

local function updateBorderStrata(layer)
    local strata = layer.drawBorderOnTop and "HIGH" or layer.paint:GetFrameStrata()
    addon.SetMapAwareStrata(layer.borderPaint, strata, layer.paint)
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
    frame.drawBorderOnTop = panel.borderOnTop ~= false
    updateBorderStrata(frame)
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

addon.hintAnchors=hintAnchors

function addon.CreateLabelTab(frame)
    local tab = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    tab.bg = tab:CreateTexture(nil, "BACKGROUND")
    tab.bg:SetAllPoints()
    tab.text = tab:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    tab.text:SetJustifyH("CENTER")
    tab.text:SetJustifyV("MIDDLE")
    return tab
end

function addon.CreateHint(frame)
    frame.tab = addon.CreateLabelTab(frame)
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

local function hintToggleKey(panel)
    if panel == previewPanel and previewToggleKey ~= nil then return previewToggleKey end
    return addon.PanelToggleKey(panel)
end

function addon.LayoutHint(frame, panel)
    local tab = frame.tab
    local hold = addon.HoldLayer(panel)
    local key = hintToggleKey(panel)
    local label = hold and addon.LayerLabel(hold) or ""
    if key then
        label = (hold and label .. " / " or "") .. (GetBindingText and GetBindingText(key) or key)
    end
    local settings = addon.HintSettings(panel)
    addon.LayoutLabelTab(tab, frame, label, settings)
end

function addon.LayoutLabelTab(tab, frame, label, settings)
    local side = hintAnchors[settings.hintSide] and settings.hintSide or "top-start"
    local vertical = settings.hintOrientation == "vertical"
    local font, size = settings.font, settings.size
    if tab.label == label and tab.side == side and tab.vertical == vertical
        and tab.font == font and tab.fontSize == size then return end
    tab.label, tab.side, tab.vertical, tab.font, tab.fontSize = label, side, vertical, font, size
    if addon.ApplyHotkeyStyle and (font or size) then addon.ApplyHotkeyStyle(tab.text, settings) end
    if tab.text.SetRotation then tab.text:SetRotation(0) end
    tab.text:SetText(label)
    local width = math.max(42, tab.text:GetStringWidth() + 16)
    local height = math.max(24, (size or 12) + 8)
    tab.text:SetSize(width, height)
    local rotate = vertical and tab.text.SetRotation
    tab:SetSize((rotate and height or width) + (tab.profileArrows and 28 or 0), rotate and width or height)
    tab.text:ClearAllPoints()
    tab.text:SetPoint("CENTER", tab, "CENTER", rotate and -3 or 0, rotate and -4 or 0)
    if rotate then tab.text:SetRotation(math.pi / 2) end
    tab:ClearAllPoints()
    local anchors = hintAnchors[side]
    tab:SetPoint(anchors[1], frame, anchors[2])
end

function addon.CreateTotemProfileTab(frame)
    local tab = addon.CreateLabelTab(frame)
    tab.profileArrows = {}
    for _, direction in ipairs({-1, 1}) do
        local arrow = CreateFrame("Button", nil, tab)
        local side = direction == -1 and "LEFT" or "RIGHT"
        arrow:SetSize(14, 20)
        arrow:SetPoint(side, tab, side, -direction * 2, 0)
        arrow.icon = arrow:CreateTexture(nil, "OVERLAY")
        arrow.icon:SetPoint("CENTER")
        arrow.icon:SetSize(10, 11)
        arrow.icon:SetTexture([[Interface\AddOns\]] .. addonName .. [[\Media\TotemControls.tga]])
        arrow.icon:SetTexCoord(direction == -1 and .5 or 0, direction == -1 and 0 or .5, 0, 1)
        arrow:SetScript("OnClick", function() KeyLayersStepTotemProfile(direction) end)
        tab.profileArrows[#tab.profileArrows + 1] = arrow
    end
    return tab
end

local function tintProfileArrows(tab)
    if tab.profileArrows then
        for _, arrow in ipairs(tab.profileArrows) do arrow.icon:SetVertexColor(tab.text:GetTextColor()) end
    end
end

function addon.HintVisibleForFrame(panel)
    if panel.hintVisible ~= nil then return panel.hintVisible end
    return addon.HintSettings(panel).hint
end

function addon.HasHint(panel)
    return addon.GlobalHints().hint and addon.HintVisibleForFrame(panel) and (addon.HoldLayer(panel) or hintToggleKey(panel))
end

function addon.TintHint(tab, panel, active, custom)
    local border = addon.borderTextures[panel.borderTexture]
    local edge = border and border.file
    local size = border and math.min(10, border.size)
    if custom and not edge and panel.thickness > 0 then
        edge, size = [[Interface\Buttons\WHITE8X8]], math.min(10, panel.thickness)
    end
    if tab.hintEdge ~= edge or tab.hintEdgeSize ~= size then
        tab:SetBackdrop(edge and {edgeFile = edge, edgeSize = size} or nil)
        tab.hintEdge, tab.hintEdgeSize = edge, size
    end
    local r, g, b = rgb(panel.border)
    if edge then
        if border then r, g, b = 1, 1, 1 end
        tab:SetBackdropBorderColor(r, g, b, panel.borderAlpha)
    end
    if custom then
        local fill = addon.fillTextures[panel.fillTexture]
        tab.bg:SetShown(panel.fillAlpha > 0)
        tab.bg:SetVertexColor(1, 1, 1, 1)
        if fill then tab.bg:SetTexture(fill) else tint(tab.bg, panel.fill, 1) end
        tab.bg:SetAlpha(panel.fillAlpha)
        tab.text:SetTextColor(1, 1, 1, 1)
        tab.text:SetShadowOffset(1, -1)
        tintProfileArrows(tab)
        return
    end
    tab.bg:SetAlpha(1)
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
    tintProfileArrows(tab)
end

function addon.ProfileHintSettings(panel, bar)
    if panel.profileHint then return panel.profileHint end
    bar = bar or {}
    return {hintSide = bar.profileAnchor or "top-start", font = bar.profileFont or "game",
        size = bar.profileFontSize or 12}
end

function addon.ProfileHintAnchor(panel, preferred)
    local standard = addon.HintSettings(panel).hintSide
    standard = hintAnchors[standard] and standard or "top-start"
    preferred = hintAnchors[preferred] and preferred or "top-start"
    if not addon.HasHint(panel) or preferred ~= standard then return preferred end
    return standard:match("^bottom") and "top-start" or "bottom-start"
end

function addon.UpdateProfileHint(frame, panel, style, active)
    local bar = addon.BarLayout and addon.BarLayout.totemBar(panel)
    local settings = bar and addon.ProfileHintSettings(panel, bar)
    local tab = frame.profileTab
    if not settings or settings.hint == false then
        if tab then tab:Hide() end
        return false
    end
    if not tab then
        tab = addon.CreateTotemProfileTab(frame)
        frame.profileTab = tab
    end
    tab:SetFrameLevel(frame.tab:GetFrameLevel())
    local anchor = addon.ProfileHintAnchor(panel, settings.hintSide)
    addon.LayoutLabelTab(tab, frame, addon.TotemProfiles().active,
        {hintSide = anchor, hintOrientation = settings.hintOrientation,
            font = settings.font or "game", size = settings.size or 12})
    local activated = active and (addon.HoldLayer(panel) or addon.PanelToggle(panel))
    local customStyle
    if activated then customStyle = settings.activeStyle else customStyle = settings.defaultStyle end
    addon.TintHint(tab, customStyle or style, active, not not customStyle)
    tab:Show()
    return true
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
    "bartenderExtra", "bartenderVehicle", "bartenderQueue", "bartenderTotems", "questie", "glass",
}
addon.kindLabels = {
    free = tr("Cadre libre", "Free frame"),
    owned = tr("Barres KeyLayers", "KeyLayers bars"),
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
    glass = tr("Tchat Glass", "Glass chat"),
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
    glass = {"GlassFrame"},
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

local function microMenuFrames()
    if BT4BarMicroMenu and CharacterMicroButton and CharacterMicroButton:GetParent() == BT4BarMicroMenu then
        return BT4BarMicroMenu, BT4BarMicroMenu
    end
    local menu = MicroMenu or MicroMenuContainer
    if MicroMenuContainer and MicroMenu then
        return menu, MicroMenu:GetParent() == MicroMenuContainer and MicroMenuContainer or nil
    end
    return menu, menu
end

local movedMicroMenu
local function ownsMicroMenuAnchor(state)
    local point, relative, relativePoint, x, y = state.frame:GetPoint(1)
    return state.frame:GetNumPoints() == 1 and point == "CENTER" and relative == root
        and relativePoint == "CENTER" and x == state.x and y == state.y
end

local function updateMicroMenuPosition(position, rootScale)
    if InCombatLockdown() then return end
    local menu, frame = microMenuFrames()
    if movedMicroMenu and (not position or movedMicroMenu.frame ~= frame) then
        if ownsMicroMenuAnchor(movedMicroMenu) then
            local previous = movedMicroMenu.frame
            previous:ClearAllPoints()
            for _, point in ipairs(movedMicroMenu.points) do previous:SetPoint(unpack(point, 1, 5)) end
        end
        movedMicroMenu = nil
    end
    if not position or not frame then return end

    local bounds = boundsForMicroMenu(menu, rootScale)
    local x, y = frame:GetCenter()
    if not bounds or not x then return end
    local dx = position.x - (bounds.left + bounds.right - root:GetWidth()) / 2
    local dy = position.y - (bounds.bottom + bounds.top - root:GetHeight()) / 2
    if math.abs(dx) < .1 and math.abs(dy) < .1 then return end

    if not movedMicroMenu or not ownsMicroMenuAnchor(movedMicroMenu) then
        movedMicroMenu = {frame = frame, points = {}}
        for i = 1, frame:GetNumPoints() do movedMicroMenu.points[i] = {frame:GetPoint(i)} end
    end
    local scale = frame:GetEffectiveScale() / rootScale
    movedMicroMenu.x = x - root:GetWidth() / (2 * scale) + dx / scale
    movedMicroMenu.y = y - root:GetHeight() / (2 * scale) + dy / scale
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", root, "CENTER", movedMicroMenu.x, movedMicroMenu.y)
end

function addon.BarActionButton(kind, id, slot)
    if kind == "owned" then
        local f = addon.ownedBars[id]
        return f and f.model and slot <= (f:GetAttribute("count") or 0) and f.buttons[slot]
    end
    if kind == "bars" then
        local button = _G["BT4Button" .. ((id - 1) * 12 + slot)]
        if button then return button end
        return nil
    end
    local bar = blizzardBars[id]
    local prefix = id == 1 and "ActionButton" or bar .. "Button"
    return _G[prefix .. slot]
end

function addon.NativeBarBinding(kind, id, slot)
    if kind == "owned" then return "CLICK KeyLayersBar" .. id .. "Button" .. slot .. ":LeftButton" end
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
    if panel.kind == "free" or panel.kind == "owned" then
        local g = panel
        if panel.kind=="owned" and addon.BarLayout then
            local saved=previewIndex and KeyLayersCharLayout.panels[previewIndex]
            local moving=addon.MovingFrameGeometry and addon.MovingFrameGeometry(panel==previewPanel and saved or panel)
            local dimensions = previewDimensions and previewDimensions[panel] or panel
            g=addon.BarLayout.envelope(dimensions,moving or dimensions)
        end
        return (root:GetWidth()-g.width)/2+g.x,(root:GetHeight()-g.height)/2+g.y,g.width,g.height
    end

    local bounds
    if panel.kind == "chat" then
        bounds = includeFrame(nil, panel.chatId and _G["ChatFrame" .. panel.chatId], rootScale)
    elseif panel.kind == "micro" then
        local frame = microMenuFrames()
        if frame then bounds = boundsForMicroMenu(frame, rootScale) end
    elseif linkedFrames[panel.kind] then
        for _, name in ipairs(linkedFrames[panel.kind]) do
            local frame = _G[name]
            if frame then
                bounds = boundsForLinkedFrame(panel.kind, frame, rootScale)
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
    local paddingX, paddingY = addon.BarLayout.framePadding(panel)
    return bounds.left - paddingX, bounds.bottom - paddingY,
        bounds.right - bounds.left + paddingX * 2, bounds.top - bounds.bottom + paddingY * 2
end

function addon.GetPanelGeometry(panel)
    if panel.kind == "free" or panel.kind == "owned" then return panel end
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

local hoveredPanel
local bindingSourcePanels, bindingTargetPanels

function addon.SetBindingOutlines(sources, targets)
    bindingSourcePanels, bindingTargetPanels = sources, targets
    addon.DrawBindingOutlines(sources, targets, panelBounds, root:GetEffectiveScale())
end

local function updateDraftOutline()
    local panel = (addon.DraggedFrame and addon.DraggedFrame()) or hoveredPanel or previewPanel
    if panel then
        local moving=addon.MovingFrameGeometry and addon.MovingFrameGeometry(panel)
        if moving and panel.kind~="owned" then
            addon.UpdateDraftOutline((root:GetWidth()-moving.width)/2+moving.x,
                (root:GetHeight()-moving.height)/2+moving.y,moving.width,moving.height)
        else addon.UpdateDraftOutline(panelBounds(panel, root:GetEffectiveScale())) end
    else
        addon.UpdateDraftOutline()
    end
end

function addon.SetHoveredPanel(panel)
    if panel == hoveredPanel then return end
    hoveredPanel = panel
    updateDraftOutline()
end

local effects = {}
local activeLayer, heldSelfCast, heldWithoutSelfCast = "base"

addon.styleKeys = {"fill", "fillAlpha", "fillTexture", "border", "borderAlpha", "borderTexture", "thickness", "borderOnTop"}
function addon.CopyStyle(source, target)
    for _, key in ipairs(addon.styleKeys) do target[key] = source[key] end
end

function addon.DefaultFrameStyle(panel, write)
    if panel.inactiveStyle then
        if write and rawget(panel, "inactiveStyle") == nil then panel.inactiveStyle = addon.Copy(panel.inactiveStyle) end
        return panel.inactiveStyle
    end
    if panel.useDefaultStyle then return panel end

    -- Legacy frames can have a separate activated style with a transparent default.
    local style = {}
    addon.CopyStyle(panel, style)
    style.fillAlpha, style.borderAlpha = 0, 0
    if write then panel.inactiveStyle = style end
    return style
end
local function hasActiveStyle(panel)
    return not panel.useDefaultStyle and (addon.HoldLayer(panel) or addon.PanelToggle(panel))
end

function addon.CopyFrameStyle(source, target)
    addon.CopyStyle(addon.DefaultFrameStyle(source), addon.DefaultFrameStyle(target, true))
    if hasActiveStyle(source) and hasActiveStyle(target) then addon.CopyStyle(source, target) end
end

function addon.EditStyle(panel)
    return previewInactive and (panel.inactiveStyle or previewDefaultStyle) or panel, not previewInactive
end

function addon.SetDraftPreview(index, panel, inactive, toggleKey, defaultStyle, dimensions)
    previewIndex, previewPanel, previewInactive = index, panel, inactive
    previewToggleKey, previewDefaultStyle, previewDimensions = toggleKey, defaultStyle, dimensions
    addon.Refresh()
end

function addon.OwnedParentGeometry(panel)
    local preview = previewIndex and KeyLayersCharLayout.panels[previewIndex]==panel and previewPanel
    preview = preview or (previewDimensions and previewDimensions[panel])
    local moving = addon.MovingFrameGeometry and addon.MovingFrameGeometry(panel)
    if moving then
        moving.paddingX, moving.paddingY = addon.BarLayout.framePadding(preview or panel)
        moving.autoFitBars, moving.barFrameId, moving.kind = (preview or panel).autoFitBars, panel.barFrameId, panel.kind
        return moving
    end
    return addon.GetPanelGeometry(preview or panel)
end

local function setPaintLevel(layer, level)
    layer.paint:SetFrameLevel(level)
    layer.borderPaint:SetFrameLevel(level)
    if layer.nativeBorder then layer.nativeBorder:SetFrameLevel(level + 1) end
end

local function refresh()
    updateWorldMapLayer(visibleWorldMap())
    local layout = KeyLayersCharLayout
    if not layout then return end
    barBounds = {bars = {}, blizzard = {}}
    local scale = root:GetEffectiveScale()
    local count = #layout.panels
    local draftIndex = previewPanel and (previewIndex or count + 1)
    if draftIndex then count = math.max(count, draftIndex) end
    local dragged = addon.DraggedFrame and addon.DraggedFrame()
    local position = dragged and dragged.kind == "micro" and dragged or previewPanel
    position = position and position.kind == "micro"
        and ((addon.MovingFrameGeometry and addon.MovingFrameGeometry(position)) or position.microPosition) or nil
    if not position then
        for index, panel in ipairs(layout.panels) do
            if index ~= draftIndex and panel.kind == "micro" and panel.microPosition then
                position = panel.microPosition
                break
            end
        end
    end
    updateMicroMenuPosition(position, scale)
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
        if left then
            updateBorderStrata(frame)
            if frame.defaultLayer then updateBorderStrata(frame.defaultLayer) end
        end
        frame.hasBounds = left ~= nil
        frame.hasTab = not not addon.HasHint(panel)
    end
    for index = count + 1, #effects do
        effects[index]:Hide()
        effects[index].panel = nil
    end
    updateDraftOutline()
    if bindingSourcePanels then
        addon.DrawBindingOutlines(bindingSourcePanels, bindingTargetPanels, panelBounds, scale)
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
            local toggled = toggle and addon.IsPanelToggled(panel, activeToggle)
            local active = (mode == "none" and panel.layer == "always")
                or (hold and hold ~= "unmodified" and hold == activeLayer)
                or (toggled and (toggle ~= "base" or activeLayer == "base"))
                or (hold == "unmodified" and activeLayer == "base" and activeToggle == 0)
                or (hold and heldSelfCast ~= nil and (hold == heldSelfCast or hold == heldWithoutSelfCast))
            if updateHotkeys and active then activePanels[panel] = toggled and "toggle" or true end
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
            local labelActive = active
            if previewPanel == panel then labelActive = not previewInactive end
            local labelStyle = showDefaultLayer and alpha == 0 and panel.inactiveStyle or style
            local hasProfile = addon.UpdateProfileHint(frame, panel, labelStyle, labelActive)
            local visible = panel.visibility ~= "hidden"
                and (panel.visibility ~= "combat" or InCombatLockdown())
                and (panel.visibility ~= "hover" or frame:IsMouseOver())
                and frame.hasBounds and (alpha > 0 or showDefaultLayer or frame.hasTab or hasProfile)
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
        addon.BarLayout.syncProvider(KeyLayersCharLayout)
        addon.InstallOptions()
        addon.Refresh()
    elseif initialized then
        if event == "PLAYER_LOGOUT" then
            addon.RememberFrameToggleKeys()
            addon.BarLayout.rememberBartenderFrames(KeyLayersCharLayout)
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
    local updateHotkeys = elapsed >= 0.10 or (visibleWorldMap() ~= nil) ~= worldMapVisible
    if updateHotkeys then
        elapsed = 0
        refresh()
    end
    animate(updateHotkeys)
end)
