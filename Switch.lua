local _, addon = ...
local tr = addon.Translate
local neutralButtonName = "BartenderGlowNeutralButton"
local neutralBinding = "CLICK " .. neutralButtonName .. ":LeftButton"
BINDING_HEADER_BARTENDERGLOW = "KeyLayers"
_G["BINDING_NAME_" .. neutralBinding] = tr("Revenir au neutre", "Return to neutral")

local function bindingContext(binding)
    if C_KeyBindings and C_KeyBindings.GetBindingContextForAction then
        return C_KeyBindings.GetBindingContextForAction(binding)
    end
end

function addon.NeutralKey()
    return GetBindingKey(neutralBinding, nil, bindingContext(neutralBinding))
end

function addon.ShortcutActionLabel(binding)
    return _G["BINDING_NAME_" .. binding] or binding
end

local function assignKey(binding, key, replace)
    if InCombatLockdown() then return false, "combat" end
    local context = bindingContext(binding)
    local previous = {GetBindingKey(binding, nil, context)}
    local owner, ownerContext
    if key then
        owner = GetBindingAction(key, false) or ""
        local effective = GetBindingAction(key, true) or ""
        if owner == "" and effective ~= "" and effective ~= binding then
            return false, "temporary", effective
        end
        if owner ~= "" and owner ~= binding then
            if owner ~= replace then return false, "occupied", owner end
            ownerContext = bindingContext(owner)
        end
        if owner == binding and #previous == 1 and previous[1] == key then return true end
    elseif #previous == 0 then
        return true
    end

    local replacing = key and owner ~= "" and owner ~= binding
    if replacing and not SetBinding(key, nil, ownerContext) then return false, "invalid" end
    if key and not SetBinding(key, binding, context) then
        if replacing then SetBinding(key, owner, ownerContext) end
        return false, "invalid"
    end

    local removed = {}
    for _, old in ipairs(previous) do
        if old ~= key then
            if not SetBinding(old, nil, context) then
                for _, restored in ipairs(removed) do SetBinding(restored, binding, context) end
                if key then
                    if replacing and ownerContext ~= context then SetBinding(key, nil, context) end
                    SetBinding(key, owner ~= "" and owner or nil, ownerContext or context)
                end
                return false, "invalid"
            end
            removed[#removed + 1] = old
        end
    end
    SaveBindings(GetCurrentBindingSet())
    return true
end

function addon.AssignNeutralKey(key, replace)
    return assignKey(neutralBinding, key, replace)
end

local driver, currentConfig, updatePending, synchronizing
local ensureToggleButton
local enabledToggles = {}
local modifierCondition = "[mod:ctrl,mod:shift,mod:alt] 7; [mod:ctrl,mod:shift] 3; "
    .. "[mod:ctrl,mod:alt] 5; [mod:shift,mod:alt] 6; [mod:ctrl] 1; [mod:shift] 2; [mod:alt] 4; 0"
local layerByMask = {[0] = "base", "ctrl", "maj", "ctrl+maj", "alt", "ctrl+alt", "maj+alt", "ctrl+maj+alt"}
local prefixMask = {CTRL = 1, SHIFT = 2, ALT = 4}
local toggleBindings, layerMasks = {}, {base = 0}
for mask = 1, 7 do
    local layer = layerByMask[mask]
    local name = "CLICK KeyLayersToggle" .. mask .. ":LeftButton"
    toggleBindings[layer], layerMasks[layer] = name, mask
    local modifiers = {}
    local captions = {ctrl = tr("Ctrl", "Ctrl"), maj = tr("Maj", "Shift"), alt = "Alt"}
    for modifier in layer:gmatch("[^+]+") do modifiers[#modifiers + 1] = captions[modifier] end
    _G["BINDING_NAME_" .. name] = tr("Verrouiller %s", "Toggle %s"):format(table.concat(modifiers, " + "))
end

function addon.ToggleKey(layer)
    local binding = toggleBindings[layer]
    if binding then return GetBindingKey(binding, nil, bindingContext(binding)) end
end

function addon.AssignToggleKey(layer, key, replace)
    local binding = toggleBindings[layer]
    if not binding then return false, "invalid" end
    return assignKey(binding, key, replace)
end

local function physicalMask()
    return (IsControlKeyDown() and 1 or 0) + (IsShiftKeyDown() and 2 or 0) + (IsAltKeyDown() and 4 or 0)
end

function addon.ActivationMode(panel)
    return panel.activationMode or ((panel.layer == "never" or panel.layer == "always") and "none" or "hold")
end

function addon.HoldLayer(panel)
    if addon.ActivationMode(panel) == "hold" then return panel.layer end
end

function addon.PanelToggle(panel)
    return panel.toggleId or panel.toggleLayer or (addon.ActivationMode(panel) == "latch" and panel.layer) or nil
end

function addon.PanelKeyLayer(panel)
    local toggle = addon.PanelToggle(panel)
    return addon.HoldLayer(panel) or (type(toggle) == "string" and toggle) or (toggle and "base" or nil)
end

local function frameToggleBinding(id)
    return "CLICK KeyLayersFrameToggle" .. id .. ":LeftButton"
end

function addon.PanelToggleKey(panel)
    local toggle = addon.PanelToggle(panel)
    if not toggle then return end
    if toggle == "base" then return addon.NeutralKey() end
    if type(toggle) == "string" then return addon.ToggleKey(toggle) end
    local binding = frameToggleBinding(toggle)
    return GetBindingKey(binding, nil, bindingContext(binding))
end

function addon.NewPanelToggleId()
    local id = KeyLayersNotices.nextToggleId or 8
    KeyLayersNotices.nextToggleId = id + 1
    return id
end

function addon.AssignPanelToggleKey(panel, toggle, key, replace)
    if InCombatLockdown() then return false, "combat" end
    if toggle == "base" then return addon.AssignNeutralKey(key, replace) end
    if type(toggle) == "string" then return addon.AssignToggleKey(toggle, key, replace) end
    local binding = frameToggleBinding(toggle)
    _G["BINDING_NAME_" .. binding] = tr("Verrouiller %s", "Toggle %s"):format(panel.name)
    ensureToggleButton(toggle)
    return assignKey(binding, key, replace)
end

function addon.MigrateActivation(layout)
    local used = {}
    for _, panel in ipairs(layout.panels) do
        if panel.activationMode == "latch" then used[panel.layer] = true end
    end
    for _, panel in ipairs(layout.panels) do
        if panel.layer == "base" and addon.ActivationMode(panel) == "hold" and not used.base then
            panel.activationMode, used.base = "latch", true
        elseif not panel.activationMode then
            local mode = addon.ActivationMode(panel)
            if mode == "hold" and panel.layer ~= "base" and not used[panel.layer] then
                local allLatch = true
                for key in panel.layer:gmatch("[^+]+") do
                    local override = layout.modifierModes and layout.modifierModes[key]
                    if (override or layout.mode) ~= "latch" then allLatch = false; break end
                end
                if allLatch then mode, used[panel.layer] = "latch", true end
            end
            panel.activationMode = mode
        end
    end
end

local function splitKey(binding)
    local mask, remaining = 0, binding
    while remaining do
        local prefix, rest = remaining:match("^([^-]+)%-(.+)$")
        if not prefixMask[prefix] then break end
        mask, remaining = mask + prefixMask[prefix], rest
    end
    return mask, remaining
end
addon.SplitBinding = splitKey

local function isActionBinding(command)
    return command:match("^CLICK BT4Button%d+:")
        or command:match("^CLICK ActionButton%d+:")
        or command:match("^CLICK MultiBar%a+Button%d+:")
        or command:match("^ACTIONBUTTON%d+$")
        or command:match("^MULTIACTIONBAR%d+BUTTON%d+$")
        or command:match("^BONUSACTIONBUTTON%d+$")
end

local modifierPrefix = {"CTRL-", "SHIFT-", "CTRL-SHIFT-", "ALT-",
    "ALT-CTRL-", "ALT-SHIFT-", "ALT-CTRL-SHIFT-"}

local selfCastButtons = {}

local function selfCastAction(command)
    local targetName = command:match("^CLICK (BT4Button%d+):")
    if not targetName then return command end
    local target = _G[targetName]
    if not target then return command end
    local proxy = selfCastButtons[targetName]
    if not proxy then
        proxy = CreateFrame("Button", "ShiftKitSelfCast" .. targetName, UIParent,
            "SecureActionButtonTemplate, SecureHandlerBaseTemplate")
        proxy:SetSize(1, 1)
        proxy:EnableMouse(false)
        proxy:RegisterForClicks("AnyDown", "AnyUp")
        proxy:SetFrameRef("actionButton", target)
        proxy:SetAttribute("clickbutton", target)
        proxy:SetAttribute("unit", "player")
        proxy:WrapScript(proxy, "OnClick", [[
            local target = self:GetFrameRef("actionButton")
            local slot = target:GetAttribute("action")
            if target:GetAttribute("type") == "action" and type(slot) == "number" and slot > 0 then
                self:SetAttribute("type", "action")
                self:SetAttribute("action", slot)
            else
                self:SetAttribute("type", "click")
                self:SetAttribute("action", nil)
            end
        ]])
        selfCastButtons[targetName] = proxy
    end
    return "CLICK " .. proxy:GetName() .. ":LeftButton"
end

local function collectBindings(switches)
    local keys = {}
    local function remember(key)
        if key then keys[key] = true end
    end

    -- In particular, temporary Bartender4 overrides may be visible to
    -- GetBindingAction but absent from GetBindingKey's reverse lookup.
    local commonKeys = [[
        0 1 2 3 4 5 6 7 8 9 A B C D E F G H I J K L M N O P Q R S T U V W X Y Z
        F1 F2 F3 F4 F5 F6 F7 F8 F9 F10 F11 F12 F13 F14 F15 F16 F17 F18 F19 F20 F21 F22 F23 F24
        NUMPAD0 NUMPAD1 NUMPAD2 NUMPAD3 NUMPAD4 NUMPAD5 NUMPAD6 NUMPAD7 NUMPAD8 NUMPAD9
        NUMPADDECIMAL NUMPADPLUS NUMPADMINUS NUMPADMULTIPLY NUMPADDIVIDE NUMPADENTER
        SPACE TAB ENTER BACKSPACE INSERT DELETE HOME END PAGEUP PAGEDOWN UP DOWN LEFT RIGHT
        MOUSEWHEELUP MOUSEWHEELDOWN - = [ ] ; ' , . / \ ` ! §
    ]]
    for key in commonKeys:gmatch("%S+") do remember(key) end
    for id = 3, 31 do remember("BUTTON" .. id) end

    local function rememberBindings(...)
        for index = 1, select("#", ...) do
            local binding = select(index, ...)
            if binding then
                local _, key = splitKey(binding)
                remember(key)
            end
        end
    end
    for id = 1, 180 do
        local name = "BT4Button" .. id
        if _G[name] then
            rememberBindings(GetBindingKey("CLICK " .. name .. ":Keybind"))
            rememberBindings(GetBindingKey("CLICK " .. name .. ":LeftButton"))
        end
    end
    if GetNumBindings and GetBinding then
        for index = 1, GetNumBindings() do
            local command = GetBinding(index)
            if command and isActionBinding(command) then rememberBindings(GetBindingKey(command)) end
        end
    end

    local entries, counts = {}, {}
    local selfCastMask = GetModifiedClick and prefixMask[GetModifiedClick("SELFCAST")] or nil
    local function hasBit(mask, bit) return mask % (bit * 2) >= bit end
    local function disjoint(first, second)
        for _, bit in ipairs({1, 2, 4}) do
            if hasBit(first, bit) and hasBit(second, bit) then return false end
        end
        return true
    end
    local function protectsShortcut(key, mask)
        if key == "F4" and hasBit(mask, 4) then return true end
        local command = GetBindingAction(key, false) or ""
        return command ~= "" and not isActionBinding(command)
    end
    for mask, prefix in ipairs(modifierPrefix) do
        local layer = layerByMask[mask]
        if switches[layer] then
            counts[layer] = 0
            for key in pairs(keys) do
                if not protectsShortcut(key, 0) and not (key == "F4" and hasBit(mask, 4)) then
                    local target = GetBindingAction(prefix .. key, true) or ""
                    if isActionBinding(target) then
                        entries[#entries + 1] = ("bindings[%d][0][%q] = %q"):format(mask, key, target)
                        counts[layer] = counts[layer] + 1
                    end
                    local physical = selfCastMask
                    if physical and disjoint(mask, physical)
                        and not (key == "F4" and hasBit(mask + physical, 4)) then
                        local pressed = modifierPrefix[physical] .. key
                        local assigned = GetBindingAction(pressed, false) or ""
                        if (assigned == "" or isActionBinding(assigned)) and not protectsShortcut(key, physical) then
                            local combined = GetBindingAction(modifierPrefix[mask + physical] .. key, true) or ""
                            local action = isActionBinding(combined) and combined or (combined == "" and target or "")
                            if isActionBinding(action) then
                                entries[#entries + 1] = ("bindings[%d][%d][%q] = %q")
                                    :format(mask, physical, pressed, selfCastAction(action))
                            end
                        end
                    end
                end
            end
        end
    end
    table.sort(entries)
    return table.concat(entries, "\n"), counts
end

local redirectsByLayer = {}
function addon.PrintSwitchDiagnostics()
    local layer = addon.SwitchLayer() or "base"
    local counts = {}
    for _, name in ipairs(addon.layers) do
        if redirectsByLayer[name] ~= nil then
            counts[#counts + 1] = addon.LayerLabel(name) .. "=" .. redirectsByLayer[name]
        end
    end
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage(("KeyLayers | %s: %s | %s: %s"):format(
            tr("Couche", "Layer"), addon.LayerLabel(layer),
            tr("Redirections détectées", "Detected redirects"), #counts > 0 and table.concat(counts, ", ") or "—"))
    end
end

local updateBindings = [[
    local physical = self:GetAttribute("shiftkit-physical") or 0
    local latched = self:GetAttribute("shiftkit-latched") or 0
    local mappedLayer = latched * 8 + physical
    if self:GetAttribute("shiftkit-mapped") ~= mappedLayer then
        self:ClearBindings()
        if latched ~= 0 then
            for key, command in pairs(bindings[latched][physical]) do
                self:SetBinding(true, key, command)
            end
        end
        self:SetAttribute("shiftkit-mapped", mappedLayer)
    end
    self:SetAttribute("shiftkit-display", physical ~= 0 and physical or latched)
]]

local modifierChanged = [[
    self:SetAttribute("shiftkit-physical", tonumber(newstate) or 0)
    self:RunAttribute("shiftkit-update")
]]

local toggleClick = [[
    if down then return end
    local controller = self:GetFrameRef("shiftkit")
    local id = self:GetAttribute("shiftkit-toggle-mask")
    local route = controller:GetAttribute("shiftkit-route-" .. id)
    if id ~= 0 and not route then return end
    local active = controller:GetAttribute("shiftkit-active-toggle") or 0
    if id == active then id = 0 end
    controller:SetAttribute("shiftkit-active-toggle", id)
    controller:SetAttribute("shiftkit-latched", id == 0 and 0 or route)
    controller:RunAttribute("shiftkit-update")
]]

ensureToggleButton = function(id)
    local name = id == 0 and neutralButtonName
        or (id < 8 and "KeyLayersToggle" or "KeyLayersFrameToggle") .. id
    if _G[name] then return end
    local button = CreateFrame("Button", name, UIParent, "SecureHandlerClickTemplate")
    button:SetSize(1, 1)
    button:EnableMouse(false)
    button:SetFrameRef("shiftkit", driver)
    button:RegisterForClicks("AnyDown", "AnyUp")
    button:SetAttribute("shiftkit-toggle-mask", id)
    button:SetAttribute("_onclick", toggleClick)
end

local function installDriver()
    driver = CreateFrame("Frame", nil, UIParent, "SecureHandlerStateTemplate")
    driver:SetAttribute("_onstate-shiftkitmods", modifierChanged)
    driver:SetAttribute("shiftkit-update", updateBindings)
    for id = 0, 7 do ensureToggleButton(id) end
end

function addon.SyncSwitch(reset)
    if synchronizing then return end
    if InCombatLockdown() then
        updatePending = true
        return
    end
    if not driver then installDriver() end
    updatePending = false
    local configuration = {"bindings = newtable()"}
    local switches, routes, ids = {}, {}, {}
    for _, panel in ipairs(KeyLayersLayout.panels) do
        local toggle = addon.PanelToggle(panel)
        local id = type(toggle) == "number" and toggle or layerMasks[toggle]
        if id and id > 0 and routes[id] == nil then
            local layer = type(toggle) == "string" and toggle or addon.HoldLayer(panel)
            local route = layerMasks[layer] or 0
            routes[id] = route
            ids[#ids + 1] = id
            if route > 0 then switches[layer] = true end
            if id >= 8 then
                KeyLayersNotices.nextToggleId = math.max(KeyLayersNotices.nextToggleId or 8, id + 1)
                _G["BINDING_NAME_" .. frameToggleBinding(id)] = tr("Verrouiller %s", "Toggle %s"):format(panel.name)
                ensureToggleButton(id)
            end
        end
    end
    table.sort(ids)
    for _, id in ipairs(ids) do
        configuration[#configuration + 1] = ("self:SetAttribute(%q, %d)"):format("shiftkit-route-" .. id, routes[id])
    end
    for physical = 0, 7 do
        configuration[#configuration + 1] = ("bindings[%d] = newtable()"):format(physical)
        for held = 0, 7 do
            configuration[#configuration + 1] = ("bindings[%d][%d] = newtable()"):format(physical, held)
        end
    end
    redirectsByLayer = {}
    if next(switches) then
        local entries
        entries, redirectsByLayer = collectBindings(switches)
        configuration[#configuration + 1] = entries
    end
    local source = table.concat(configuration, "\n")
    if reset or source ~= currentConfig then
        synchronizing = true
        if currentConfig then UnregisterStateDriver(driver, "shiftkitmods") end
        ClearOverrideBindings(driver)
        local physical = physicalMask()
        for id in pairs(enabledToggles) do driver:SetAttribute("shiftkit-route-" .. id, nil) end
        enabledToggles = routes
        driver:SetAttribute("shiftkit-active-toggle", 0)
        driver:SetAttribute("shiftkit-latched", 0)
        driver:SetAttribute("shiftkit-mapped", 0)
        driver:SetAttribute("shiftkit-physical", physical)
        driver:SetAttribute("shiftkit-display", physical)
        driver:Execute(source)
        driver:SetAttribute("state-shiftkitmods", nil)
        currentConfig = source
        RegisterStateDriver(driver, "shiftkitmods", modifierCondition)
        synchronizing = false
    end
end

function addon.ActiveToggle()
    return currentConfig and driver:GetAttribute("shiftkit-active-toggle") or 0
end

function addon.IsPanelToggled(panel, activeToggle)
    local toggle = addon.PanelToggle(panel)
    local id = type(toggle) == "number" and toggle or layerMasks[toggle]
    return id ~= nil and id == activeToggle
end

function addon.LatchedLayer()
    if not currentConfig then return end
    return layerByMask[driver:GetAttribute("shiftkit-latched")]
end

function addon.SwitchLayer()
    if currentConfig then return layerByMask[driver:GetAttribute("shiftkit-display")] end
end

function addon.SwitchEvent(event)
    if event == "PLAYER_REGEN_ENABLED" and updatePending then
        addon.SyncSwitch()
    elseif event == "UPDATE_BINDINGS" or event == "PLAYER_ENTERING_WORLD" then
        addon.SyncSwitch()
    end
end
