local _, addon = ...
local root = UIParent
local overlays, badges = {}, {}
local editor, drag
local tr = addon.Translate

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
    local kind = draft and draft.kind
    if not addon.barCounts[kind] then
        kind = "blizzard"
        for id = 1, addon.barCounts.bars do
            if boundsForBar("bars", id, scale) then
                kind = "bars"
                break
            end
        end
    end
    local selectedBars = draft and draft.kind == kind and addon.BarSelection(draft)
    for id = 1, addon.barCounts.bars do
        local bar = id <= addon.barCounts[kind] and boundsForBar(kind, id, scale)
        local badge = badges[id]
        if bar then
            if not badge then
                badge = CreateFrame("Button", nil, root, "UIPanelButtonTemplate")
                badge:SetFrameStrata("HIGH")
                badge:SetFrameLevel(30)
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
            badge:Show()
        elseif badge then badge:Hide() end
    end
end

function addon.UpdateEditOverlays(bounds, boundsForBar, layout, scale)
    if not editor then return end
    local selected, draft = editor.current()
    updateBarNumbers(boundsForBar, scale, draft)
    local function show(index, panel, active)
        local left, bottom, width, height = bounds(panel, scale)
        local frame = overlays[index]
        if not left then
            if frame then frame:Hide() end
            return
        end
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
        if frame.active ~= active then
            local level = active and 22 or 18
            frame:SetFrameLevel(level)
            frame.paint:SetFrameLevel(level + 1)
            frame.borderPaint:SetFrameLevel(level + 1)
            frame.outline:SetFrameLevel(level + 2)
            frame.handle:SetFrameLevel(level + 3)
            frame.tab:SetFrameLevel(level + 3)
            if active then frame.outline:SetBackdropBorderColor(0.44, 0.84, 1, 1)
            else frame.outline:SetBackdropBorderColor(0.65, 0.70, 0.75, 0.85) end
            frame.active = active
        end
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
    for index, panel in ipairs(layout.panels) do
        show(index, index == selected and draft or panel, index == selected)
    end
    if draft and not selected then show(0, draft, true)
    elseif overlays[0] then overlays[0]:Hide() end
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
