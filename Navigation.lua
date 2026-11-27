local _, addon = ...
local tr = addon.Translate

function addon.CreateRenameButton(parent, tooltip)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(19, 19)
    button:SetBackdrop({bgFile=[[Interface\Buttons\WHITE8X8]], edgeFile=[[Interface\Buttons\WHITE8X8]], edgeSize=1})
    button:SetBackdropColor(.12, .25, .34, 1)
    button:SetBackdropBorderColor(.54, .77, .90, 1)
    button:SetHighlightTexture([[Interface\Buttons\UI-Listbox-Highlight2]], "ADD")
    local pencil = button:CreateLine(nil, "ARTWORK")
    pencil:SetThickness(3)
    pencil:SetColorTexture(.9, .96, 1)
    pencil:SetStartPoint("CENTER", button, -3, -3)
    pencil:SetEndPoint("CENTER", button, 3, 3)
    local tip = button:CreateTexture(nil, "ARTWORK")
    tip:SetSize(2, 2)
    tip:SetPoint("CENTER", -5, -5)
    tip:SetColorTexture(.9, .96, 1)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(tooltip)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return button
end

function addon.CreateWorkspaceSwitch(parent, onClick)
    local switch = CreateFrame("Button", nil, parent, "BackdropTemplate")
    switch:SetSize(34, 16)
    switch:SetBackdrop({bgFile=[[Interface\Buttons\WHITE8X8]], edgeFile=[[Interface\Buttons\WHITE8X8]], edgeSize=1})
    switch:SetBackdropBorderColor(.54, .77, .90, 1)
    local thumb = switch:CreateTexture(nil, "ARTWORK")
    thumb:SetTexture([[Interface\CharacterFrame\TempPortraitAlphaMask]])
    thumb:SetSize(12, 12)
    function switch:SetActive(active)
        self:SetBackdropColor(active and .20 or .11, active and .39 or .18, active and .51 or .23, 1)
        thumb:ClearAllPoints()
        thumb:SetPoint(active and "RIGHT" or "LEFT", active and -2 or 2, 0)
        thumb:SetVertexColor(active and .96 or .62, active and .79 or .72, active and .38 or .80)
    end
    switch:SetScript("OnClick", onClick)
    return switch
end

function addon.CreateWorkspaceTree(parent, choose, drop, hoverFrame, toggleView)
    local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    frame:SetPoint("TOPLEFT", 10, -78)
    frame:SetPoint("BOTTOMLEFT", 10, 14)
    frame:SetWidth(198)
    frame:SetBackdrop({bgFile = [[Interface\Buttons\WHITE8X8]]})
    frame:SetBackdropColor(.09, .13, .18, 1)

    local heading=CreateFrame("Frame",nil,frame)
    heading:SetPoint("TOPLEFT",4,-2)
    heading:SetPoint("TOPRIGHT",-4,-2)
    heading:SetHeight(25)
    local caption=heading:CreateFontString(nil,"OVERLAY","GameFontNormal")
    caption:SetPoint("LEFT",6,0)
    local viewCaption = caption
    local switch = addon.CreateWorkspaceSwitch(heading, toggleView)
    switch:SetPoint("RIGHT", -4, 0)
    switch:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(tr("Basculer entre Conteneurs et Styles hérités", "Switch between Containers and Inherited styles"))
        GameTooltip:Show()
    end)
    switch:SetScript("OnLeave", function() GameTooltip:Hide() end)
    local scroll = CreateFrame("Frame", nil, frame, "WowScrollBoxList")
    local scrollbar = CreateFrame("EventFrame", nil, frame, "MinimalScrollBar")
    scroll:SetPoint("TOPLEFT", 4, -29)
    scroll:SetPoint("BOTTOMRIGHT", -15, 6)
    scrollbar:SetPoint("TOPRIGHT", -4, -29)
    scrollbar:SetPoint("BOTTOMRIGHT", -4, 6)
    local view = CreateScrollBoxListTreeListView(13, 0, 0, 0, 0, 2)
    view:SetElementExtent(24)

    local collapsed, previousPath = {}, {}
    local dragged, hovered
    local badge=CreateFrame("Frame",nil,UIParent,"BackdropTemplate")
    badge:SetFrameStrata("TOOLTIP")
    badge:SetSize(220,24)
    badge:SetBackdrop({bgFile=[[Interface\Buttons\WHITE8X8]]})
    badge:SetBackdropColor(.08,.12,.16,.96)
    local caption=badge:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    caption:SetPoint("CENTER")
    badge:Hide()
    badge:SetScript("OnUpdate",function(self)
        local x,y=GetCursorPosition()
        local scale=UIParent:GetEffectiveScale()
        self:SetPoint("BOTTOMLEFT",UIParent,"BOTTOMLEFT",x/scale+14,y/scale+12)
        hovered=nil
        scroll:ForEachFrame(function(row)
            if row:IsMouseOver() then hovered=row end
        end)
        local target=hovered and hovered.item.drop
        if target and not addon.BarLayout.attachmentPosition(dragged,target) then target=nil end
        local creates=hovered and hovered.item.framesRoot
        addon.UpdateBarDropPreview(dragged,target,creates)
        caption:SetText(((target or creates) and "+ " or "X ")..dragged.name)
        caption:SetTextColor((target or creates) and .45 or 1,(target or creates) and 1 or .4,.45)
    end)
    local function paint(row)
        local item = row.item
        local isDropTarget = dragged and hovered == row
        if isDropTarget or (item.active and not item.activeDescendant) then
            row.active:SetColorTexture(unpack(addon.BarLayout.workspaceSelectionColor))
        else
            row.active:SetColorTexture(.18, .38, .48, .50)
        end
        row.active:SetShown(item.active or item.activeDescendant or isDropTarget)
    end
    local function initializer(row, node)
        if not row.caption then
            row.caption = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.caption:SetPoint("LEFT", 21, 0)
            row.caption:SetPoint("RIGHT", -3, 0)
            row.caption:SetJustifyH("LEFT")
            row.caption:SetWordWrap(false)
            row.active = row:CreateTexture(nil, "BACKGROUND")
            row.active:SetAllPoints()
            row.active:SetColorTexture(unpack(addon.BarLayout.workspaceSelectionColor))
            local hover = row:CreateTexture(nil, "HIGHLIGHT")
            hover:SetAllPoints()
            hover:SetColorTexture(.4, .68, .8, .18)
            row:SetHighlightTexture(hover)
            local toggle = CreateFrame("Button", nil, row)
            toggle:SetSize(20, 24)
            toggle:SetPoint("LEFT")
            toggle:SetNormalFontObject("GameFontHighlightSmall")
            toggle:SetScript("OnClick", function()
                local data = row.item
                collapsed[data.key] = not row.node:IsCollapsed()
                row.node:SetCollapsed(collapsed[data.key])
                toggle:SetText(collapsed[data.key] and "+" or "-")
            end)
            row.toggle = toggle
            row:RegisterForDrag("LeftButton")
            row:SetScript("OnClick", function()
                if row.item.heading
                    and not (row.item.framesRoot or row.item.frameDefaults or row.item.barDefaults or row.item.globalSettings)
                    and row.toggle:IsShown() then row.toggle:Click()
                else choose(row.item) end
            end)
            row:SetScript("OnEnter", function()
                hovered=row
                if hoverFrame and not dragged then hoverFrame(row.item) end
                paint(row)
            end)
            row:SetScript("OnLeave", function()
                if hovered==row then hovered=nil end
                if hoverFrame and not dragged then hoverFrame() end
                paint(row)
            end)
            row:SetScript("OnHide",function()
                if hovered==row then
                    hovered=nil
                    if hoverFrame and not dragged then hoverFrame() end
                end
            end)
            row:SetScript("OnDragStart", function()
                if row.item.bar and not row.item.barSection and not InCombatLockdown() then
                    dragged = row.item.bar
                    badge:Show()
                end
            end)
            row:SetScript("OnDragStop", function()
                local item = dragged
                dragged = nil
                badge:Hide()
                addon.UpdateBarDropPreview()
                if not item then return end
                local target
                scroll:ForEachFrame(function(candidate)
                    if candidate:IsMouseOver() then
                        if candidate.item.framesRoot then target=0
                        elseif candidate.item.drop then target=candidate.item.index end
                    end
                    paint(candidate)
                end)
                if target then drop(item, target) end
            end)
        end
        row.item, row.node = node:GetData(), node
        row.caption:SetText(row.item.frame and ("["..row.item.text.."]") or row.item.text)
        if row.item.bar and not row.item.barSection then row.caption:SetTextColor(.42,1,.55)
        elseif row.item.heading then row.caption:SetTextColor(.95,.78,.36)
        elseif row.item.section or row.item.barSection or row.item.bindings or row.item.hoverBindings or row.item.globalSection then row.caption:SetTextColor(.74,.79,1)
        else row.caption:SetTextColor(1,1,1) end
        row.toggle:SetShown(node:GetFirstNode() ~= nil)
        row.toggle:SetText(node:IsCollapsed() and "+" or "-")
        paint(row)
    end
    view:SetElementInitializer("Button", initializer)
    ScrollUtil.InitScrollBoxListWithScrollBar(scroll, scrollbar, view)

    frame:SetScript("OnHide", function() badge:Hide(); addon.UpdateBarDropPreview(); dragged, hovered = nil, nil end)
    function frame:Update(items,selection,barID,inherited,reveal)
        viewCaption:SetText(inherited and tr("Styles hérités", "Inherited styles") or tr("Conteneurs", "Containers"))
        if self.inherited ~= inherited then
            self.inherited = inherited
            switch:SetActive(inherited)
        end
        if barID and barID~=self.barID then
            collapsed["bar:"..barID]=false
        end
        self.barID=barID
        if selection and selection~=self.selection then
            collapsed.frames=false
            collapsed["frame:"..selection]=false
        end
        self.selection=selection
        local provider = CreateTreeDataProvider()
        local path = {}
        local revealNode
        local function add(parentNode, list)
            local containsSelection = false
            for _, item in ipairs(list) do
                local node = parentNode:Insert(item)
                if item.children then
                    item.activeDescendant = add(node, item.children)
                    if item.activeDescendant then
                        path[item.key] = true
                        if reveal or not previousPath[item.key] then collapsed[item.key] = false end
                    end
                    local isCollapsed=collapsed[item.key]
                    if isCollapsed==nil then isCollapsed=item.defaultCollapsed end
                    node:SetCollapsed(isCollapsed==true)
                elseif reveal and item.active then
                    revealNode = node
                end
                containsSelection = containsSelection or item.active or item.activeDescendant or false
            end
            return containsSelection
        end
        add(provider, items)
        previousPath = path
        scroll:SetDataProvider(provider, ScrollBoxConstants.RetainScrollPosition)
        if revealNode and scroll.ScrollToElementData then scroll:ScrollToElementData(revealNode) end
    end
    return frame
end
