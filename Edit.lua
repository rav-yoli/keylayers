local _, addon = ...
local root = UIParent
local overlays, badges, placed = {}, {}, {}
local editor, drag
local tr = addon.Translate

local selection
local bindingSources, bindingTargets = {}, {}
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
                    dash:SetColorTexture(unpack(frame.dashColor))
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

local function makeMarker(color)
    local marker = CreateFrame("Frame", nil, root)
    marker:SetFrameStrata("HIGH")
    marker:SetFrameLevel(9001)
    marker:EnableMouse(false)
    marker.dashColor = color
    marker.dashes, marker.phase, marker.elapsed = {}, 0, 0
    marker:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = self.elapsed + elapsed
        if self.elapsed < 1 / 30 then return end
        self.phase = self.phase + dashSpeed * self.elapsed
        self.elapsed = 0
        paintSelection(self)
    end)
    marker:Hide()
    return marker
end

local function placeMarker(marker, left, bottom, width, height)
    if left ~= marker.outlineLeft or bottom ~= marker.outlineBottom then
        marker:ClearAllPoints()
        marker:SetPoint("BOTTOMLEFT", root, "BOTTOMLEFT", left - selectionGap, bottom - selectionGap)
        marker.outlineLeft, marker.outlineBottom = left, bottom
    end
    width, height = width + 2 * selectionGap, height + 2 * selectionGap
    if width ~= marker.outlineWidth or height ~= marker.outlineHeight then
        marker.outlineWidth, marker.outlineHeight = width, height
        marker:SetSize(width, height)
        paintSelection(marker)
    end
    addon.SetMapAwareStrata(marker, "HIGH")
    marker:Show()
end

local gold = {1, 0.76, 0.28, 0.98}
local green = {0.29, 0.95, 0.41, 0.98}

local barMarker, outlinedBar
function addon.ClearBarOutline(frame)
    if not frame or outlinedBar == frame then
        outlinedBar = nil
        if barMarker then barMarker:Hide() end
    end
end

function addon.ShowBarOutline(frame)
    if not frame or not frame:IsVisible() then
        addon.ClearBarOutline()
        return
    end
    local x,y,w,h=frame:GetRect()
    if not x then return end
    local scale=frame:GetEffectiveScale()/root:GetEffectiveScale()
    if not barMarker then barMarker=makeMarker(gold) end
    outlinedBar = frame
    placeMarker(barMarker,x*scale,y*scale,w*scale,h*scale)
end

local dropMarker
function addon.UpdateBarDropPreview(bar,panel,creates)
    if creates and bar then
        local x,y=addon.BarLayout.position(bar)
        local w,h=addon.BarLayout.size(bar)
        if not dropMarker then dropMarker=makeMarker(green) end
        placeMarker(dropMarker,(root:GetWidth()-w)/2+x-8,(root:GetHeight()-h)/2+y-8,w+16,h+16)
        return
    end
    if not bar or not panel then if dropMarker then dropMarker:Hide() end; return end
    if not addon.GetPanelGeometry(panel) then return end
    local w,h=addon.BarLayout.size(bar)
    if not dropMarker then dropMarker=makeMarker(green) end
    local x,y=addon.BarLayout.attachmentPosition(bar,panel)
    if not x then dropMarker:Hide(); return end
    placeMarker(dropMarker,(root:GetWidth()-w)/2+x,(root:GetHeight()-h)/2+y,w,h)
    return x,y
end

function addon.UpdateDraftOutline(left, bottom, width, height)
    if not left then
        if selection then selection:Hide() end
        return
    end
    if not selection then selection = makeMarker(gold) end
    placeMarker(selection, left, bottom, width, height)
end

function addon.DrawBindingOutlines(sources, targets, bounds, scale)
    local function placeGroup(markers, panels, color)
        for index, panel in ipairs(panels) do
            local left, bottom, width, height = bounds(panel, scale)
            local marker = markers[index]
            if not marker then
                marker = makeMarker(color)
                markers[index] = marker
            end
            if left then placeMarker(marker, left, bottom, width, height)
            else marker:Hide() end
        end
        for index = #panels + 1, #markers do markers[index]:Hide() end
    end
    placeGroup(bindingSources, sources, gold)
    placeGroup(bindingTargets, targets, green)
end

local function finishDrag(owner)
    if not drag or (owner and drag.owner~=owner) then return end
    local completed = drag
    drag = nil
    completed.owner:SetScript("OnUpdate", nil)
    if completed.commit and completed.values then completed.commit(completed.index, completed.values[1], completed.values[2],
        completed.values[3], completed.values[4], completed.resize) end
end

function addon.DraggedFrame()
    return drag and KeyLayersCharLayout.panels[drag.index]
end

function addon.MovingFrameGeometry(panel)
    if not drag or not drag.values then return end
    local index, draft = editor.current()
    local source = (index or 0)==drag.index and draft or KeyLayersCharLayout.panels[drag.index]
    if panel ~= source and panel ~= KeyLayersCharLayout.panels[drag.index] then return end
    local x,y,width,height = unpack(drag.values)
    return {x=x,y=y,width=width,height=height,manualFit=not drag.resize and source and source.manualFit or nil,
        frameSized=drag.resize or source and source.frameSized}
end

function addon.CanMoveFrame(panel)
    return panel and (panel.kind == "free" or panel.kind == "owned" or panel.kind == "micro")
end

local function beginDrag(owner, resize, index, selectFrame)
    if not editor then return end
    if InCombatLockdown() then return end
    finishDrag()
    local panel
    if selectFrame then
        panel = editor.select(index)
    else
        panel = editor.dragPanel(index)
    end
    if not addon.CanMoveFrame(panel) or (panel.kind == "micro" and resize) then return end
    local geometry = addon.GetPanelGeometry(panel)
    if not geometry then return end
    local startX, startY = GetCursorPosition()
    local scale = root:GetEffectiveScale()
    local x, y, width, height = geometry.x, geometry.y, geometry.width, geometry.height
    if resize and panel.kind=="owned" and not addon.BarLayout.autoFitEnabled(panel) then
        local displayed = addon.BarLayout.envelope(panel, geometry)
        width, height = displayed.width, displayed.height
    end
    drag = {owner = owner, index = index, resize = resize, commit = editor.commitGeometry}
    owner:SetScript("OnUpdate", function()
        local cursorX, cursorY = GetCursorPosition()
        local dx, dy = (cursorX - startX) / scale, (cursorY - startY) / scale
        if resize then
            local newWidth = math.max(24, math.min(10000, width + dx))
            local newHeight = math.max(24, math.min(10000, height - dy))
            drag.values = {x + (newWidth - width) / 2, y - (newHeight - height) / 2, newWidth, newHeight}
        else
            drag.values = {x + dx, y + dy, width, height}
        end
        if drag.commit then
            if editor.previewGeometry then editor.previewGeometry(index, addon.MovingFrameGeometry(panel)) end
        else
            editor.geometry(unpack(drag.values))
        end
        if addon.UpdateOwnedFramePositions then addon.UpdateOwnedFramePositions() end
        addon.Refresh()
    end)
    return true
end

function addon.BeginAttachedBarDrag(owner,index)
    return beginDrag(owner,false,index)
end

addon.FinishAttachedBarDrag=finishDrag

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
    local highlight = CreateFrame("Frame", nil, frame)
    highlight:SetAllPoints(frame)
    highlight:EnableMouse(false)
    local tint = highlight:CreateTexture(nil, "OVERLAY")
    tint:SetAllPoints()
    tint:SetColorTexture(.74, .58, .95, 1)
    frame.moveHighlight = highlight
    frame:EnableMouse(true)
    frame:RegisterForClicks("LeftButtonUp","RightButtonUp")
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnClick", function(self,button)
        if not editor or InCombatLockdown() then return end
        if button=="RightButton" and self.index>0 and editor.bars then editor.bars(self.index)
        else editor.select(self.index) end
    end)
    frame:SetScript("OnDragStart", function(self) beginDrag(self, false, self.index, true) end)
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
    handle:SetScript("OnClick", function() if editor then editor.select(frame.index) end end)
    handle:SetScript("OnDragStart", function(self) beginDrag(self, true, frame.index, true) end)
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
    local appearance, previews, inactive
    if editor.previewAppearance then appearance, previews, inactive = editor.previewAppearance() end
    if draft and addon.barCounts[draft.kind] then
        updateBarNumbers(boundsForBar, scale, draft)
    else
        for _, badge in pairs(badges) do badge:Hide() end
    end
    wipe(placed)
    local function place(index, panel, active)
        local left, bottom, width, height = bounds(panel, scale)
        if drag and drag.index == index and drag.values and panel.kind=="free" then
            local x, y
            x, y, width, height = unpack(drag.values)
            left, bottom = (root:GetWidth() - width)/2 + x, (root:GetHeight() - height)/2 + y
        end
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
            frame.moveHighlight:SetFrameLevel(level + 2)
            frame.outline:SetFrameLevel(level + 3)
            frame.handle:SetFrameLevel(level + 4)
            frame.tab:SetFrameLevel(level + 4)
            frame.drawLevel = level
        end
        if frame.active ~= active then
            frame.outline:SetShown(not active)
            if not active then frame.outline:SetBackdropBorderColor(0.65, 0.70, 0.75, 0.85) end
            frame.active = active
        end
        addon.SetMapAwareStrata(frame, "HIGH")
        local hasTotems = addon.BarLayout and addon.BarLayout.totemBar(panel)
        local preview = previews and previews[panel]
        local paintStrata = (hasTotems or preview or active and appearance) and "LOW" or frame:GetFrameStrata()
        if frame.paint:GetFrameStrata() ~= paintStrata then frame.paint:SetFrameStrata(paintStrata) end
        local movable = addon.CanMoveFrame(panel)
        frame.moveHighlight:SetShown(movable and not appearance)
        if movable then frame.moveHighlight:SetAlpha(active and .48 or .36) end
        local style, hintActive
        if preview then
            style = inactive and addon.DefaultFrameStyle(preview) or preview
            hintActive = not inactive
        elseif active then
            style, hintActive = addon.EditStyle(panel)
        end
        local showStyle = preview ~= nil or active and (appearance or not movable)
        if showStyle then addon.PaintStyle(frame, style) end
        frame.paint:SetShown(showStyle)
        local showHint = style ~= nil and addon.HasHint(preview or panel)
        if showHint then
            addon.LayoutHint(frame, preview or panel)
            addon.TintHint(frame.tab, style, hintActive)
        end
        frame.tab:SetShown(showHint)
        if style then
            addon.UpdateProfileHint(frame, preview or panel, style, hintActive)
        elseif frame.profileTab then
            frame.profileTab:Hide()
        end
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
        frame.handle:SetShown((panel.kind == "free" or panel.kind == "owned") and active)
        frame:Show()
    end
    for order, item in ipairs(placed) do show(item, 14 + order * 5) end
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
    if draft == panel then return true end
    if editor.previewAppearance then
        local appearance, previews = editor.previewAppearance()
        return appearance and previews and previews[panel] ~= nil
    end
    return false
end
