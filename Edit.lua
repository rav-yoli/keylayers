local _, addon = ...
local root = UIParent
local overlays, badges, placed = {}, {}, {}
local editor, drag
local tr = addon.Translate

-- One mouse-transparent marker follows the editor selection, independently of activation.
local selection
local selectionGap, dashThickness = 8, 3
local dashSpeed = 27

local function paintSelection(frame)
    local width, height = frame.outlineWidth, frame.outlineHeight
    local perimeter = 2 * (width + height)
    local spacing = perimeter / math.max(1, math.min(160, math.floor(perimeter / 20)))
    local dashWidth = spacing * 0.56
    local used, traveled = 0, 0

    local function edge(length, x, y, dx, dy)
        local offset = (frame.phase - traveled) % spacing - spacing
        while offset < length do
            local first = math.max(0, offset)
            local last = math.min(length, offset + dashWidth)
            if last > first then
                used = used + 1
                local dash = frame.dashes[used]
                if not dash then
                    dash = frame:CreateTexture(nil, "OVERLAY")
                    dash:SetColorTexture(1, 0.76, 0.28, 0.98)
                    frame.dashes[used] = dash
                end
                local along = (dx < 0 or dy < 0) and last or first
                dash:ClearAllPoints()
                dash:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", x + dx * along, y + dy * along)
                dash:SetSize(dx == 0 and dashThickness or last - first, dy == 0 and dashThickness or last - first)
                dash:Show()
            end
            offset = offset + spacing
        end
        traveled = traveled + length
    end

    edge(width, 0, height, 1, 0)
    edge(height, width, height, 0, -1)
    edge(width, width, 0, -1, 0)
    edge(height, 0, 0, 0, 1)
    for index = used + 1, #frame.dashes do frame.dashes[index]:Hide() end
end

function addon.UpdateDraftOutline(left, bottom, width, height)
    if not left then
        if selection then selection:Hide() end
        return
    end
    if not selection then
        selection = CreateFrame("Frame", nil, root)
        selection:SetFrameStrata("HIGH")
        selection:SetFrameLevel(9001)
        selection:EnableMouse(false)
        selection.dashes, selection.phase, selection.elapsed = {}, 0, 0
        selection:SetScript("OnUpdate", function(self, elapsed)
            self.elapsed = self.elapsed + elapsed
            if self.elapsed < 1 / 30 then return end
            self.phase = self.phase + dashSpeed * self.elapsed
            self.elapsed = 0
            paintSelection(self)
        end)
        selection:Hide()
    end
    if left ~= selection.outlineLeft or bottom ~= selection.outlineBottom then
        selection:ClearAllPoints()
        selection:SetPoint("BOTTOMLEFT", root, "BOTTOMLEFT", left - selectionGap, bottom - selectionGap)
        selection.outlineLeft, selection.outlineBottom = left, bottom
    end
    width, height = width + 2 * selectionGap, height + 2 * selectionGap
    if width ~= selection.outlineWidth or height ~= selection.outlineHeight then
        selection.outlineWidth, selection.outlineHeight = width, height
        selection:SetSize(width, height)
        paintSelection(selection)
    end
    addon.SetMapAwareStrata(selection, "HIGH")
    selection:Show()
end

local function finishDrag()
    if not drag then return end
    drag.owner:SetScript("OnUpdate", nil)
    drag = nil
end

local function beginDrag(owner, resize, index)
    if not editor then return end
    local panel = editor.select(index)
    if not panel or panel.kind ~= "free" then return end
    finishDrag()
    local startX, startY = GetCursorPosition()
    local scale = root:GetEffectiveScale()
    local x, y, width, height = panel.x, panel.y, panel.width, panel.height
    drag = {owner = owner}
    owner:SetScript("OnUpdate", function()
        local cursorX, cursorY = GetCursorPosition()
        local dx, dy = (cursorX - startX) / scale, (cursorY - startY) / scale
        if resize then
            local newWidth = math.max(24, math.min(10000, width + dx))
            local newHeight = math.max(24, math.min(10000, height - dy))
            editor.geometry(x + (newWidth - width) / 2, y - (newHeight - height) / 2,
                newWidth, newHeight)
        else
            editor.geometry(x + dx, y + dy, width, height)
        end
    end)
end

local function makeOverlay()
    local frame = CreateFrame("Button", nil, root)
    frame:SetFrameStrata("HIGH")
    addon.CreatePaint(frame)
    addon.CreateHint(frame)
    local outline = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    outline:SetPoint("TOPLEFT", frame, "TOPLEFT", -3, 3)
    outline:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 3, -3)
    outline:SetBackdrop({edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 2})
    frame.outline = outline
    frame:EnableMouse(true)
    frame:RegisterForClicks("LeftButtonUp")
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnClick", function(self) editor.select(self.index) end)
    frame:SetScript("OnDragStart", function(self) beginDrag(self, false, self.index) end)
    frame:SetScript("OnDragStop", finishDrag)
    frame:SetScript("OnHide", function(self)
        if drag and (drag.owner == self or drag.owner == self.handle) then finishDrag() end
    end)

    frame.caption = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.caption:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 3, 4)
    frame.caption:SetShadowOffset(1, -1)

    local handle = CreateFrame("Button", nil, frame)
    handle:SetSize(20, 20)
    handle:SetPoint("BOTTOMRIGHT")
    handle:EnableMouse(true)
    handle:RegisterForDrag("LeftButton")
    handle:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    handle:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    handle:SetScript("OnDragStart", function(self) beginDrag(self, true, frame.index) end)
    handle:SetScript("OnDragStop", finishDrag)
    frame.handle = handle
    return frame
end

local function updateBarNumbers(boundsForBar, scale, draft)
    local kind = draft.kind
    local selectedBars = addon.BarSelection(draft)
    for id = 1, addon.barCounts.bars do
        local bar = id <= addon.barCounts[kind] and boundsForBar(kind, id, scale)
        local badge = badges[id]
        if bar then
            if not badge then
                badge = CreateFrame("Button", nil, root, "UIPanelButtonTemplate")
                badge:SetFrameStrata("HIGH")
                badge:SetFrameLevel(9000)
                badge:RegisterForClicks("LeftButtonUp")
                badge:SetScript("OnClick", function(self) editor.toggleBar(self.barKind, id) end)
                badge:SetSize(36, 27)
                badge:SetScript("OnEnter", function(self)
                    local _, name = addon.BarLabel(self.barKind, id)
                    GameTooltip:SetOwner(self, "ANCHOR_TOP")
                    GameTooltip:SetText(name)
                    GameTooltip:AddLine(tr("Cliquer pour ajouter ou retirer la barre", "Click to add or remove the bar"))
                    GameTooltip:Show()
                end)
                badge:SetScript("OnLeave", function() GameTooltip:Hide() end)
                badges[id] = badge
            end
            local x, y = (bar.left + bar.right) / 2, (bar.bottom + bar.top) / 2
            if x ~= badge.barX or y ~= badge.barY then
                badge:ClearAllPoints()
                badge:SetPoint("CENTER", root, "BOTTOMLEFT", x, y)
                badge.barX, badge.barY = x, y
            end
            if badge.barKind ~= kind then
                badge.barKind = kind
                badge:SetText((addon.BarLabel(kind, id)))
            end
            if selectedBars and selectedBars[id] then badge:LockHighlight()
            else badge:UnlockHighlight() end
            addon.SetMapAwareStrata(badge, "HIGH")
            badge:Show()
        elseif badge then badge:Hide() end
    end
end

function addon.UpdateEditOverlays(bounds, boundsForBar, layout, scale)
    if not editor then return end
    local selected, draft = editor.current()
    if draft and addon.barCounts[draft.kind] then
        updateBarNumbers(boundsForBar, scale, draft)
    else
        for _, badge in pairs(badges) do badge:Hide() end
    end
    wipe(placed)
    local function place(index, panel, active)
        local left, bottom, width, height = bounds(panel, scale)
        if left then
            placed[#placed + 1] = {index = index, panel = panel, active = active,
                left = left, bottom = bottom, width = width, height = height, area = width * height}
        elseif overlays[index] then
            overlays[index]:Hide()
        end
    end
    for index, panel in ipairs(layout.panels) do
        local active = index == selected
        place(index, active and draft or panel, active)
    end
    if draft and not selected then place(0, draft, true)
    elseif overlays[0] then overlays[0]:Hide() end
    -- A large background must not capture clicks meant for a smaller frame inside it.
    table.sort(placed, function(a, b)
        if a.area ~= b.area then return a.area > b.area end
        if a.active ~= b.active then return b.active end
        return a.index < b.index
    end)
    local function show(item, level)
        local index, panel, active = item.index, item.panel, item.active
        local left, bottom, width, height = item.left, item.bottom, item.width, item.height
        local frame = overlays[index]
        if not frame then
            frame = makeOverlay()
            overlays[index] = frame
        end
        if frame.left ~= left or frame.bottom ~= bottom then
            frame:ClearAllPoints()
            frame:SetPoint("BOTTOMLEFT", root, "BOTTOMLEFT", left, bottom)
            frame.left, frame.bottom = left, bottom
        end
        if frame.width ~= width or frame.height ~= height then
            frame:SetSize(width, height)
            frame.width, frame.height = width, height
        end
        frame.index = index
        if frame.drawLevel ~= level then
            frame:SetFrameLevel(level)
            frame.paint:SetFrameLevel(level + 1)
            frame.borderPaint:SetFrameLevel(level + 1)
            frame.outline:SetFrameLevel(level + 2)
            frame.handle:SetFrameLevel(level + 3)
            frame.tab:SetFrameLevel(level + 3)
            frame.drawLevel = level
        end
        if frame.active ~= active then
            frame.outline:SetShown(not active)
            if not active then frame.outline:SetBackdropBorderColor(0.65, 0.70, 0.75, 0.85) end
            frame.active = active
        end
        addon.SetMapAwareStrata(frame, "HIGH")
        if active then addon.PaintStyle(frame, addon.EditStyle(panel)) end
        frame.paint:SetShown(active)
        local showHint = active and addon.HasHint(panel)
        if showHint then
            addon.LayoutHint(frame, panel)
            local style, hintActive = addon.EditStyle(panel)
            addon.TintHint(frame.tab, style, hintActive)
        end
        frame.tab:SetShown(showHint)
        local name = active and editor.name() or panel.name
        local linked = ""
        if panel.kind == "chat" then
            linked = tr(" · Tchat %d", " · Chat %d"):format(panel.chatId)
        elseif panel.kind == "bars" then
            linked = tr(" · lié à Bartender4", " · linked to Bartender4")
        elseif panel.kind ~= "free" and addon.kindLabels[panel.kind] then
            linked = " · " .. addon.kindLabels[panel.kind]
        end
        frame.caption:SetText(name .. linked)
        frame.handle:SetShown(panel.kind == "free" and active)
        frame:Show()
    end
    for order, item in ipairs(placed) do show(item, 14 + order * 4) end
    for index, frame in pairs(overlays) do
        if index > #layout.panels then frame:Hide() end
    end
end

function addon.SetEditor(controller)
    finishDrag()
    editor = controller
    if not editor then
        for _, frame in pairs(overlays) do frame:Hide() end
        for _, badge in pairs(badges) do badge:Hide() end
    end
end

function addon.IsEditingPanel(panel)
    if not editor then return false end
    local _, draft = editor.current()
    return draft == panel
end
