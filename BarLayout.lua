local _, A = ...
local M = {}
A.BarLayout = M
M.workspaceSelectionColor = {.18, .38, .48, .95}
M.workspacePageColor = {.09, .13, .18, .94}
M.totemDismissDefaults = {angle = 38, distance = 25, background = "0F1A26"}

local function keys(list)
    local set = {}
    for key in list:gmatch("%S+") do set[key] = true end
    return set
end

local frameResetProperties = {
    appearance = keys([[fill fillAlpha fillTexture border borderAlpha borderTexture thickness
        borderOnTop useDefaultStyle inactiveStyle]]),
    frameHint = keys([[hintVisible hintOverride hint hintSide hintOrientation font size]]),
}
local frameProperties = keys([[width height padding paddingX paddingY paddingLinked depth linger fade profileHint]])
for _, properties in pairs(frameResetProperties) do
    for key in pairs(properties) do frameProperties[key] = true end
end
local frameActivationProperties = {"layer", "activationMode", "visibility"}
local frameActivationDefaults = {layer="always", activationMode="none", visibility="always"}
local barProperties = keys([[count columns gap scale alpha empty keys macros border shape cooldown visibility
    reverse slotOffset page cooldownColor showCooldownText borderWidth borderColor borderStyle borderOpacity
    auraProgress totemProgress totemHoldMs totemOrder profileAnchor profileFont profileFontSize
    showTotemDismiss totemDismissAngle totemDismissDistance totemDismissBorderWidth totemDismissBorderColor
    totemDismissBackground]])
for _, prefix in ipairs({"aura", "totem"}) do
    for _, style in ipairs({"bar", "ring", "clock"}) do
        for _, property in ipairs({"Size", "Color", "Opacity"}) do
            barProperties[prefix .. "_" .. style .. property] = true
        end
    end
end
local builtinBar = {gap=3, scale=1, alpha=1, empty=true, keys=true, macros=true,
    border=true, shape="square", cooldown="edge", visibility="always"}
local builtinFrame
local panelMetatables, barMetatables = setmetatable({}, {__mode="k"}), setmetatable({}, {__mode="k"})

local function inheritedFrameValue(layout, panel, key)
    local typed = layout.frameTypeDefaults and layout.frameTypeDefaults[panel.kind]
    if typed and typed[key] ~= nil then return typed[key] end
    local global = layout.frameDefaults
    if global then return global[key] end
end

function M.inheritFrame(layout, panel)
    if not builtinFrame then
        builtinFrame = A.NewPanel("")
    end
    if not panelMetatables[layout] then
        panelMetatables[layout] = {__index=function(self, key)
            if not frameProperties[key] then return end
            local value = inheritedFrameValue(layout, self, key)
            if value ~= nil then return value end
            return builtinFrame[key]
        end}
    end
    return setmetatable(panel, panelMetatables[layout])
end

function M.clearFrameOverrides(panel, section)
    local properties = section == nil and frameProperties or assert(frameResetProperties[section])
    for key in pairs(properties) do rawset(panel, key, nil) end
end

function M.newFrame(layout, name)
    local panel = A.NewPanel(name)
    M.clearFrameOverrides(panel)
    panel.layer = frameActivationDefaults.layer
    return M.inheritFrame(layout, panel)
end

function M.clearBarOverrides(bar)
    for key in pairs(barProperties) do
        if key~="page" and key~="slotOffset" then rawset(bar, key, nil) end
    end
    bar.actionCount = nil
end

function M.frameDefaults(layout, kind)
    if not kind then return layout.frameDefaults or {} end
    return layout.frameTypeDefaults and layout.frameTypeDefaults[kind] or {}
end

function M.setFrameDefaults(layout, kind, defaults)
    if kind then
        layout.frameTypeDefaults = layout.frameTypeDefaults or {}
        layout.frameTypeDefaults[kind] = defaults
    else
        layout.frameDefaults = defaults
    end
end

function M.frameDefaultsFromDraft(panel)
    local defaults = {}
    for key in pairs(frameProperties) do
        local value = rawget(panel, key)
        if value ~= nil then defaults[key] = type(value) == "table" and A.Copy(value) or value end
    end
    return defaults
end

function M.frameDefaultsDraft(layout, kind)
    return M.inheritFrame({frameDefaults = kind and layout.frameDefaults or nil},
        M.frameDefaultsFromDraft(M.frameDefaults(layout, kind)))
end

function M.previewFrameDefaults(layout, kind, draft)
    local scope = {frameDefaults=layout.frameDefaults, frameTypeDefaults=A.Copy(layout.frameTypeDefaults or {})}
    M.setFrameDefaults(scope, kind, M.frameDefaultsFromDraft(draft))
    local previews = {}
    for _, panel in ipairs(layout.panels) do
        if not kind or panel.kind == kind then
            previews[panel] = M.inheritFrame(scope, A.Copy(panel))
        end
    end
    return previews
end

function M.previewFrameDimensions(layout, kind, draft)
    local previews = M.previewFrameDefaults(layout, kind, draft)
    for panel, preview in pairs(previews) do
        if panel.kind == "owned" and (preview.width ~= panel.width or preview.height ~= panel.height) then
            preview.frameSized, preview.manualFit = true, nil
        else
            previews[panel] = nil
        end
    end
    return previews
end

local function barDefault(kind, key)
    if key == "count" or key == "columns" then return kind == "totem" and 6 or kind == "stance" and 10 or 12 end
    return builtinBar[key]
end

local function readBarDefault(layout, kind, key)
    local workspace = layout.barWorkspace
    local typed = workspace.barTypeDefaults and workspace.barTypeDefaults[kind]
    local value = typed and typed[key]
    if value == nil and workspace.barDefaults then value = workspace.barDefaults[key] end
    if key == "count" and kind == "totem" and value then return math.max(4, value) end
    if value ~= nil then return value end
    return barDefault(kind, key)
end

function M.barTemplate(layout, kind)
    local state = M.init(layout)
    return setmetatable({kind=kind or "action"}, {
        __index=function(_, key)
            if barProperties[key] then return readBarDefault(layout, kind, key) end
        end,
        __newindex=function(self, key, value)
            if barProperties[key] and key~="page" and key~="slotOffset" then
                if kind then
                    state.barTypeDefaults = state.barTypeDefaults or {}
                    state.barTypeDefaults[kind] = state.barTypeDefaults[kind] or {}
                    state.barTypeDefaults[kind][key] = value
                else
                    state.barDefaults = state.barDefaults or {}
                    state.barDefaults[key] = value
                end
            else
                rawset(self, key, value)
            end
        end,
    })
end

function M.clearBarTemplate(layout, kind)
    local state = M.init(layout)
    if kind then
        if state.barTypeDefaults then state.barTypeDefaults[kind] = nil end
    else
        state.barDefaults = nil
    end
end

local function inheritBar(layout, bar)
    if not barMetatables[layout] then
        barMetatables[layout] = {__index=function(self, key)
            if not barProperties[key] then return end
            local value = readBarDefault(layout, self.kind, key)
            if value ~= nil then return value end
            if key == "page" then return self.id end
        end}
    end
    return setmetatable(bar, barMetatables[layout])
end

M.inheritBar = inheritBar

local function migrateInheritance(layout, state)
    if state.inheritanceVersion then return end
    for _, panel in ipairs(layout.panels) do
        M.inheritFrame(layout, panel)
        for key in pairs(frameProperties) do
            if rawget(panel, key) == builtinFrame[key] then rawset(panel, key, nil) end
        end
    end
    for _, bar in pairs(state.bars) do
        for key in pairs(barProperties) do
            if rawget(bar, key) == barDefault(bar.kind, key) then rawset(bar, key, nil) end
        end
        if bar.page == bar.id then bar.page = nil end
    end
    state.inheritanceVersion = 1
end

function M.available()
    local loaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
    return loaded and loaded("Bartender4")
end

local function migrateActionLock(state)
    if state.lockActions ~= nil then return end
    state.lockActions, state.actionEditModifier = false, "SHIFT"
    for id = 1, 12 do
        local bar = state.bars[id]
        if bar and bar.locked and (bar.kind == "action" or bar.kind == "totem") then
            state.lockActions = true
            local key = bar.unlockModifier
            if key == "CTRL" or key == "ALT" then state.actionEditModifier = key end
            return
        end
    end
end

local function migrateBarPaging(layout, state)
    if state.localBarPaging then return end
    for _, bar in pairs(state.bars) do
        if bar.kind == "action" then
            for _, key in ipairs({"page", "slotOffset"}) do
                if rawget(bar, key) == nil then bar[key] = readBarDefault(layout, bar.kind, key) end
            end
        end
    end
    if state.barDefaults then state.barDefaults.page, state.barDefaults.slotOffset = nil, nil end
    for _, defaults in pairs(state.barTypeDefaults or {}) do defaults.page, defaults.slotOffset = nil, nil end
    state.localBarPaging = true
end

-- Preserve the activation that was in effect before it became frame-local.
local function migrateFrameActivation(layout, state)
    if state.localFrameActivation then return end
    for _, panel in ipairs(layout.panels) do
        for _, key in ipairs(frameActivationProperties) do
            if rawget(panel, key) == nil then
                local inherited = inheritedFrameValue(layout, panel, key)
                panel[key] = inherited == nil and frameActivationDefaults[key] or inherited
            end
        end
    end
    local function clearDefaults(defaults)
        for _, key in ipairs(frameActivationProperties) do defaults[key] = nil end
    end
    if layout.frameDefaults then clearDefaults(layout.frameDefaults) end
    for _, defaults in pairs(layout.frameTypeDefaults or {}) do clearDefaults(defaults) end
    state.localFrameActivation = true
end

function M.init(layout)
    if layout.barWorkspace then
        local state = layout.barWorkspace
        if not state.attachmentTypesMigrated then
            local parents = {}
            for _, bar in pairs(state.bars) do if bar.parent then parents[bar.parent]=true end end
            for _, panel in ipairs(layout.panels) do
                if panel.kind=="free" and parents[panel.barFrameId] then panel.kind="owned" end
            end
            state.attachmentTypesMigrated = true
        end
        migrateActionLock(state)
        migrateInheritance(layout, state)
        migrateBarPaging(layout, state)
        migrateFrameActivation(layout, state)
        for _, panel in ipairs(layout.panels) do M.inheritFrame(layout, panel) end
        for _, bar in pairs(state.bars) do inheritBar(layout, bar) end
        return state
    end
    local bartender,blizzard = false,false
    for _, panel in ipairs(layout.panels) do
        if panel.kind == "bars" or (panel.kind or ""):match("^bartender") then bartender = true end
        if panel.kind == "blizzard" then blizzard = true end
    end
    if not bartender and not blizzard then bartender=M.available() end
    local state = {mode = bartender and "Bartender4" or "Blizzard", bars = {}, nextFrame = 1, attachmentTypesMigrated = true}
    layout.barWorkspace = state
    migrateActionLock(state)
    migrateInheritance(layout, state)
    migrateFrameActivation(layout, state)
    for _, panel in ipairs(layout.panels) do M.inheritFrame(layout, panel) end
    return state
end

function M.installed()
    if C_AddOns and C_AddOns.DoesAddOnExist then return C_AddOns.DoesAddOnExist("Bartender4") end
    return M.available()
end

function M.mode(state)
    if state.mode == "Bartender4" and not M.available() then return "Blizzard" end
    return state.mode
end

function M.frame(bar)
    if bar.parent then
        for index, panel in ipairs(KeyLayersCharLayout.panels) do
            if panel.barFrameId == bar.parent then return panel, index end
        end
    end
end

function M.recoverOrphanBars(layout, state)
    local frameIds = {}
    for _, panel in ipairs(layout.panels) do
        if panel.barFrameId then frameIds[panel.barFrameId] = true end
    end
    for _, bar in pairs(state.bars) do
        if bar.parent and not frameIds[bar.parent] then bar.parent = nil end
    end
end

function M.position(bar)
    local panel = M.frame(bar)
    local geo = panel and A.GetPanelGeometry(panel)
    return M.barCenter(bar, geo, M.barGrid(bar, geo))
end

function M.attach(bar, panel)
    local x, y = M.position(bar)
    local geo = panel and A.GetPanelGeometry(panel)
    if panel and not geo then return false end
    if panel and not panel.barFrameId then
        local state = M.init(KeyLayersCharLayout)
        panel.barFrameId = state.nextFrame
        state.nextFrame = state.nextFrame + 1
    end
    local oldPanel = M.frame(bar)
    if oldPanel and oldPanel ~= panel and oldPanel.manualFit then oldPanel.manualFit[bar.id] = nil end
    if oldPanel ~= panel then
        if oldPanel then oldPanel.frameSized = nil end
        if panel then panel.frameSized = nil end
    end
    if panel and panel.kind == "free" then panel.kind = "owned" end
    bar.parent = panel and panel.barFrameId
    bar.x, bar.y = x - (geo and geo.x or 0), y - (geo and geo.y or 0)
    return true
end

function M.singleFrameBar(panel)
    if not panel or panel.kind ~= "owned" or not panel.barFrameId then return end
    local state = KeyLayersCharLayout.barWorkspace
    local only
    for _, bar in pairs(state and state.bars or {}) do
        if bar.parent == panel.barFrameId then
            if only then return end
            only = bar
        end
    end
    return only
end

function M.autoFitEnabled(panel)
    local state = KeyLayersCharLayout and KeyLayersCharLayout.barWorkspace
    local global = not state or state.autoFitFrames ~= false
    if not panel then return global end
    local bar = M.singleFrameBar(panel)
    if not bar then return false end
    if panel.autoFitBars ~= nil then return panel.autoFitBars end
    if bar.fitFrame == false then return false end
    return global and (state.autoFitFrames == true or bar.fitFrame == true)
end

function M.followsFrame(bar)
    local panel = M.frame(bar)
    return panel ~= nil and M.autoFitEnabled(panel)
end

function M.changeBarLayout(change)
    local bars = M.init(KeyLayersCharLayout).bars
    local before = {}
    for id, bar in pairs(bars) do before[id] = {bar.count, bar.columns, bar.gap, bar.scale} end
    change()
    for id, old in pairs(before) do
        local bar = bars[id]
        if bar and (old[1]~=bar.count or old[2]~=bar.columns or old[3]~=bar.gap or old[4]~=bar.scale) then
            local panel = M.frame(bar)
            if panel and not M.followsFrame(bar) then panel.frameSized = nil end
        end
    end
end

M.autoFitLabel = A.Translate("Automatiser la création des barres en fonction de la taille du cadre",
    "Fit bar layouts automatically to frame dimensions")

function M.new(kind, panel, fitFirst)
    local state = M.init(KeyLayersCharLayout)
    for id = 1, 12 do
        if not state.bars[id] then
            local bar = inheritBar(KeyLayersCharLayout, {id=id, kind=kind, x=0, y=-80 + id * 8})
            bar.name = select(2, A.BarLabel("owned", id))
            local first = fitFirst and panel and kind=="action" and #M.children(panel)==0
            if first then
                bar.fitFrame = true
            end
            if panel and not M.attachInside(bar,panel) then return nil,"no-placement" end
            state.bars[id] = bar
            return bar
        end
    end
    return nil,"bar-limit"
end

function M.slotPosition(bar,slot,count)
    if bar.kind=="totem" then
        if bar.totemOrder and slot<=4 then
            for index,element in ipairs(bar.totemOrder) do
                if element==slot then return index-1 end
            end
        end
        return slot-1
    end
    if not count then count = select(4, M.barGrid(bar)) end
    local index=bar.reverse and count-slot or slot-1
    return (index+(bar.slotOffset or 0))%count
end

function M.framePadding(panel)
    local padding = panel.padding or 0
    return panel.paddingX or padding, panel.paddingY or padding
end

function M.fitGrid(bar, geometry, paddingX, paddingY)
    local width = math.max(1, geometry.width - 2 * (paddingX or 0))
    local height = math.max(1, geometry.height - 2 * (paddingY or paddingX or 0))
    local step = (36 + bar.gap) * bar.scale
    local columns = math.max(1, math.floor((width + bar.gap * bar.scale) / step))
    local availableRows = math.max(1, math.floor((height + bar.gap * bar.scale) / step))
    local minimum = bar.kind == "totem" and 4 or 1
    local count = bar.kind == "stance" and bar.count or math.max(minimum, math.min(36, columns * availableRows))
    columns = math.min(columns, count)
    local rows = math.ceil(count / columns)
    local scale = math.min(bar.scale, width / ((36 + bar.gap) * columns - bar.gap),
        height / ((36 + bar.gap) * rows - bar.gap))
    return columns, rows, scale, count
end

function M.barGrid(bar, geometry)
    local parent = M.frame(bar)
    local panel = parent and (geometry and geometry.barFrameId == parent.barFrameId and geometry or parent)
    if panel and M.autoFitEnabled(panel) then
        geometry = geometry or A.GetPanelGeometry(panel)
        local grid = geometry and geometry.manualFit and geometry.manualFit[bar.id]
        if grid then return grid.columns, grid.rows, grid.scale, grid.count end
        if geometry then
            local paddingX, paddingY = M.framePadding(panel)
            return M.fitGrid(bar, geometry, geometry.paddingX or geometry.padding or paddingX,
                geometry.paddingY or geometry.padding or paddingY)
        end
    end
    local columns = math.min(bar.count, bar.columns)
    return columns, math.ceil(bar.count / columns), bar.scale, bar.count
end

function M.barCenter(bar, geometry, columns, rows, scale)
    if not geometry then return bar.x, bar.y end
    local x, y = bar.x, bar.y
    local parent = M.frame(bar)
    local fitPanel = parent and (geometry.barFrameId == parent.barFrameId and geometry or parent)
    if fitPanel and M.autoFitEnabled(fitPanel) then
        local grid = geometry.manualFit and geometry.manualFit[bar.id]
        if grid then return geometry.x + grid.x, geometry.y + grid.y end
        local panel = M.frame(bar)
        local paddingX, paddingY = M.framePadding(panel or geometry)
        paddingX = geometry.paddingX or geometry.padding or paddingX
        paddingY = geometry.paddingY or geometry.padding or paddingY
        local width = ((36 + bar.gap) * columns - bar.gap) * scale
        local height = ((36 + bar.gap) * rows - bar.gap) * scale
        local maxX = math.max(0, (geometry.width - width) / 2 - paddingX)
        local maxY = math.max(0, (geometry.height - height) / 2 - paddingY)
        x = math.max(-maxX, math.min(maxX, x))
        y = math.max(-maxY, math.min(maxY, y))
    end
    return geometry.x + x, geometry.y + y
end

function M.setFitFrame(bar, enabled)
    local panel = M.frame(bar)
    if panel and M.singleFrameBar(panel) ~= bar then return end
    if M.followsFrame(bar) and not enabled then
        local geometry = panel and A.GetPanelGeometry(panel)
        local columns, rows, scale, count = M.barGrid(bar, geometry)
        if geometry then
            local x, y = M.barCenter(bar, geometry, columns, rows, scale)
            bar.x, bar.y = x - geometry.x, y - geometry.y
        end
        bar.columns, bar.scale, bar.count = columns, scale, count
        if bar.kind == "action" then bar.actionCount = count end
    end
    if panel then
        panel.autoFitBars = enabled
        panel.manualFit = nil
    else
        bar.fitFrame = enabled
    end
end

function M.size(bar, scale, geometry)
    local cols, rows, fittedScale = M.barGrid(bar, geometry)
    scale = scale or fittedScale
    return (36 * cols + bar.gap * (cols - 1)) * scale, (36 * rows + bar.gap * (rows - 1)) * scale
end

function M.children(panel)
    local result = {}
    local bars=M.init(KeyLayersCharLayout).bars
    for id = 1, 12 do
        local bar = bars[id]
        if bar and bar.parent == (panel and panel.barFrameId) and (not panel or bar.parent) then
            result[#result + 1] = bar
        end
    end
    return result
end

function M.totemBar(panel)
    if not panel or not panel.barFrameId then return end
    local state = M.init(KeyLayersCharLayout)
    if M.mode(state) ~= "KeyLayers" then return end
    for id = 1, 12 do
        local bar = state.bars[id]
        if bar and bar.parent == panel.barFrameId and bar.kind == "totem" then return bar end
    end
end

function M.copyBarStyle(source, target)
    for _, key in ipairs({"alpha", "shape", "border", "borderColor", "borderStyle", "borderOpacity",
        "borderWidth", "keys", "macros", "empty", "cooldown", "cooldownColor", "showCooldownText"}) do
        target[key] = source[key]
    end
    if source.kind == "totem" and target.kind == "totem" then
        target.totemDismissBorderWidth = source.totemDismissBorderWidth
        target.totemDismissBorderColor = source.totemDismissBorderColor
        target.totemDismissBackground = source.totemDismissBackground
    end
    if source.kind == target.kind and (source.kind == "totem" or source.kind == "action") then
        local style = source.kind == "totem" and "totem" or "aura"
        local progress = style .. "Progress"
        target[progress] = source[progress]
        for _, mode in ipairs({"bar", "ring", "clock"}) do
            for _, property in ipairs({"Color", "Opacity", "Size"}) do
                local key = style .. "_" .. mode .. property
                target[key] = source[key]
            end
        end
    end
end

function M.fit(panel)
    local geo, bars = A.GetPanelGeometry(panel), M.children(panel)
    if not geo or #bars == 0 then return end
    local paddingX, paddingY = M.framePadding(panel)
    local w, h = geo.width - 2 * paddingX, geo.height - 2 * paddingY
    local row = (h - 4 * (#bars - 1)) / #bars
    if w <= 0 or row <= 0 then return end
    local plan = {}
    for i, bar in ipairs(bars) do
        local bw, bh = M.size(bar, 1)
        plan[i] = {bar = bar, x = 0, y = h / 2 - row / 2 - (i - 1) * (row + 4),
            scale = math.min(w / bw, row / bh)}
    end
    return plan
end

function M.wrap(bars, padding, name)
    if #bars == 0 then return end
    local l, b, r, t = math.huge, math.huge, -math.huge, -math.huge
    for _, bar in ipairs(bars) do
        local x, y = M.position(bar)
        local w, h = M.size(bar)
        l, b = math.min(l, x - w/2), math.min(b, y - h/2)
        r, t = math.max(r, x + w/2), math.max(t, y + h/2)
    end
    local p = M.newFrame(KeyLayersCharLayout, M.uniqueName(name))
    p.x, p.y, p.width, p.height = (l+r)/2, (b+t)/2, r-l+2*padding, t-b+2*padding
    p.padding = padding
    table.insert(KeyLayersCharLayout.panels, p)
    for _, bar in ipairs(bars) do M.attach(bar, p) end
    return #KeyLayersCharLayout.panels
end

function M.driver(panel, bar)
    local parts = {}
    for form = 1, 10 do
        local pages = panel and panel.formPages and panel.formPages[form]
        if pages and pages[bar.id] then parts[#parts+1] = ("[form:%d] %d"):format(form, pages[bar.id]) end
    end
    parts[#parts+1] = tostring(bar.page)
    return table.concat(parts, "; ")
end

function A.AttachedActionIds(panel,includeTotems)
    if not panel.barFrameId then return end
    local state=M.init(KeyLayersCharLayout)
    if M.mode(state)~="KeyLayers" then return end
    local ids={}
    for id,bar in pairs(state.bars) do
        if (bar.kind=="action" or (includeTotems and bar.kind=="totem")) and bar.parent==panel.barFrameId then ids[id]=true end
    end
    return ids
end

function M.links(panel,kind)
    if kind==panel.kind then return A.BarSelection(panel) end
    return panel.linkedBars and panel.linkedBars[kind]
end

function M.hasAssignableBars(panel)
    local ids=A.AttachedActionIds(panel,true)
    local bt,blizzard=M.links(panel,"bars"),M.links(panel,"blizzard")
    return (ids and next(ids)) or (M.available() and bt and next(bt)) or (blizzard and next(blizzard))
end

function M.linkExternal(kind,id,panel)
    for _,p in ipairs(KeyLayersCharLayout.panels) do
        local links=M.links(p,kind)
        if links then links[id]=nil end
    end
    if panel then
        local links=M.links(panel,kind)
        if not links then
            panel.linkedBars=panel.linkedBars or {}
            panel.linkedBars[kind]={}
            links=panel.linkedBars[kind]
        end
        links[id]=true
    end
end

function M.dropTarget(x,y)
    local best, area
    for index, panel in ipairs(KeyLayersCharLayout.panels) do
        if panel.kind == "free" or panel.kind == "owned" then
            local g = M.envelope(panel,A.GetPanelGeometry(panel),true)
            local size = g.width*g.height
            if math.abs(x-g.x)<=g.width/2 and math.abs(y-g.y)<=g.height/2 and (not area or size<area) then
                best, area = index, size
            end
        end
    end
    return best
end

-- All coordinates are relative to the center of UIParent.
function M.placeBeside(panel, bounds, screenWidth, screenHeight)
    local halfWidth, halfHeight = screenWidth/2, screenHeight/2
    local width, height = panel.width/2, panel.height/2
    local minX, maxX = -halfWidth+width+12, halfWidth-width-12
    local minY, maxY = -halfHeight+height+12, halfHeight-height-12
    if minX>maxX or minY>maxY then return end
    local function clamp(value, low, high) return math.min(high, math.max(low,value)) end
    local x,y = clamp(panel.x,minX,maxX),clamp(panel.y,minY,maxY)
    if x-width>=bounds.right+12 or x+width<=bounds.left-12
        or y-height>=bounds.top+12 or y+height<=bounds.bottom-12 then return x,y end
    local candidates={
        {bounds.left-width-12,y}, {bounds.right+width+12,y},
        {x,bounds.top+height+12}, {x,bounds.bottom-height-12},
    }
    local closest,distance
    for _, point in ipairs(candidates) do
        if point[1]>=minX and point[1]<=maxX and point[2]>=minY and point[2]<=maxY then
            local delta=(point[1]-x)^2+(point[2]-y)^2
            if not distance or delta<distance then closest,distance=point,delta end
        end
    end
    if closest then return closest[1],closest[2] end
end

function M.remove(bar)
    local state=M.init(KeyLayersCharLayout)
    if state.bars[bar.id]~=bar then return false end
    state.bars[bar.id]=nil
    local parent = M.frame(bar)
    if parent then parent.frameSized = nil end
    for _, panel in ipairs(KeyLayersCharLayout.panels) do
        if panel.manualFit then panel.manualFit[bar.id] = nil end
        for _, pages in pairs(panel.formPages or {}) do pages[bar.id]=nil end
    end
    return true
end

function M.uniqueName(base)
    local highest
    local prefix = base .. " "
    for _, panel in ipairs(KeyLayersCharLayout.panels) do
        if panel.name == base then highest = highest or 0 end
        if panel.name:sub(1, #prefix) == prefix then
            local suffix = panel.name:sub(#prefix + 1):match("^%d+$")
            if suffix then highest = math.max(highest or 0, tonumber(suffix)) end
        end
    end
    return highest and (prefix .. (highest + 1)) or base
end

function M.resizeToPadding(panel, paddingX, paddingY)
    local grids = {}
    local halfWidth, halfHeight = 0, 0
    for _, bar in ipairs(M.children(panel)) do
        local columns, rows, scale, count = M.barGrid(bar, panel)
        local x, y = M.barCenter(bar, panel, columns, rows, scale)
        x, y = x - panel.x, y - panel.y
        if M.followsFrame(bar) then
            grids[bar.id] = {columns=columns, rows=rows, scale=scale, count=count, x=x, y=y}
        end
        local width, height = M.size(bar, nil, panel)
        halfWidth = math.max(halfWidth, math.abs(x) + width/2)
        halfHeight = math.max(halfHeight, math.abs(y) + height/2)
    end
    if not next(grids) then return false end
    panel.manualFit = grids
    if paddingX ~= nil then panel.width = 2 * (halfWidth + paddingX) end
    if paddingY ~= nil then panel.height = 2 * (halfHeight + paddingY) end
    return true
end

function M.fitMargins(panel, geometry)
    local horizontal, vertical
    local fitted
    for _, bar in ipairs(M.children(panel)) do
        fitted = fitted or M.followsFrame(bar)
        local columns, rows, scale = M.barGrid(bar, geometry)
        local x, y = M.barCenter(bar, geometry, columns, rows, scale)
        local width, height = M.size(bar, nil, geometry)
        horizontal = math.min(horizontal or math.huge, (geometry.width - width) / 2 - math.abs(x - geometry.x))
        vertical = math.min(vertical or math.huge, (geometry.height - height) / 2 - math.abs(y - geometry.y))
    end
    if fitted or geometry.frameSized and M.singleFrameBar(panel) then return horizontal, vertical end
end

function M.envelope(panel,anchor,useSavedPosition)
    local left,bottom,right,top
    local paddingX,paddingY=M.framePadding(panel)
    if M.autoFitEnabled(panel) then return anchor end
    for _,bar in ipairs(M.children(panel)) do
        local w,h=M.size(bar,nil,anchor)
        local x,y=anchor.x+bar.x,anchor.y+bar.y
        if not useSavedPosition and A.ownedBars then
            local frame=A.ownedBars[bar.id]
            if frame and frame.model==bar and bar.dragging then x,y=frame.placedX,frame.placedY end
        end
        left=math.min(left or math.huge,x-w/2)
        right=math.max(right or -math.huge,x+w/2)
        bottom=math.min(bottom or math.huge,y-h/2)
        top=math.max(top or -math.huge,y+h/2)
    end
    if not left then return anchor end
    local width, height = right-left+2*paddingX, top-bottom+2*paddingY
    if anchor.frameSized and M.singleFrameBar(panel) then
        width, height = math.max(width, anchor.width), math.max(height, anchor.height)
    end
    return {x=(right+left)/2,y=(top+bottom)/2,width=width,height=height}
end

function M.bartenderKind(kind)
    return kind=="bars" or kind:match("^bartender")~=nil
end

function M.rememberBartenderFrames(layout)
    if not M.available() then return end
    for _,panel in ipairs(layout.panels) do
        if M.bartenderKind(panel.kind) then
            local geometry=A.GetPanelGeometry(panel)
            if geometry then
                panel.x,panel.y,panel.width,panel.height=geometry.x,geometry.y,geometry.width,geometry.height
                panel.bartenderGeometry=true
            end
        end
    end
end

function M.syncProvider(layout)
    local state=M.init(layout)
    if state.mode=="KeyLayers" then
        M.rememberBartenderFrames(layout)
        for _,panel in ipairs(layout.panels) do
            if M.bartenderKind(panel.kind) then
                panel.bartenderAttachment=panel.kind
                panel.kind="owned"
            end
        end
    elseif state.mode=="Bartender4" and M.available() then
        for _,panel in ipairs(layout.panels) do
            if panel.kind=="owned" and panel.bartenderAttachment then
                panel.kind=panel.bartenderAttachment
            end
        end
    end
end

function M.attachmentPosition(bar,panel)
    local anchor=A.GetPanelGeometry(panel)
    if not anchor then return end
    local width,height=M.size(bar)
    local left,right,bottom,top
    for _,other in ipairs(M.children(panel)) do
        if other~=bar then
            local w,h=M.size(other)
            local x,y=anchor.x+other.x,anchor.y+other.y
            left=math.min(left or math.huge,x-w/2)
            right=math.max(right or -math.huge,x+w/2)
            bottom=math.min(bottom or math.huge,y-h/2)
            top=math.max(top or -math.huge,y+h/2)
        end
    end
    if not bottom then return anchor.x,anchor.y end
    local screenWidth=UIParent and UIParent:GetWidth()
    local screenHeight=UIParent and UIParent:GetHeight()
    local halfWidth,halfHeight=(screenWidth or math.huge)/2,(screenHeight or math.huge)/2
    local paddingX,paddingY=M.framePadding(panel)
    local minX,maxX=-halfWidth+width/2+paddingX,halfWidth-width/2-paddingX
    local minY,maxY=-halfHeight+height/2+paddingY,halfHeight-height/2-paddingY
    if minX>maxX or minY>maxY then return end
    local function clamp(value,minimum,maximum)
        return math.max(minimum,math.min(maximum,value))
    end
    local x,y=clamp((left+right)/2,minX,maxX),clamp((bottom+top)/2,minY,maxY)
    for _,candidate in ipairs({
        {x,bottom-height/2-4},
        {right+width/2+4,y},
        {left-width/2-4,y},
        {x,top+height/2+4},
    }) do
        local cx,cy=candidate[1],candidate[2]
        if cx>=minX and cx<=maxX and cy>=minY and cy<=maxY then return cx,cy end
    end
end

function M.attachInside(bar,panel)
    if M.frame(bar)==panel then return true end
    local x,y=M.attachmentPosition(bar,panel)
    if not x or not M.attach(bar,panel) then return false end
    local anchor=A.GetPanelGeometry(panel)
    bar.x,bar.y=x-anchor.x,y-anchor.y
    return true
end
