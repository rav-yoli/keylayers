local _, addon = ...
local tr = addon.Translate
local neutralButtonName = "BartenderGlowNeutralButton"
local neutralBinding = "CLICK " .. neutralButtonName .. ":LeftButton"
BINDING_HEADER_BARTENDERGLOW = "KeyLayers"
_G["BINDING_NAME_" .. neutralBinding] = tr("Revenir au neutre", "Return to neutral")

function addon.NeutralKey()
    return GetBindingKey(neutralBinding)
end

function addon.AssignNeutralKey(key)
    if InCombatLockdown() then return false, "combat" end
    if key then
        local saved = GetBindingAction(key, false) or ""
        local effective = GetBindingAction(key, true) or ""
        if (saved ~= "" and saved ~= neutralBinding) or (effective ~= "" and effective ~= neutralBinding) then
            return false, "occupied"
        end
    end
    local previous = {GetBindingKey(neutralBinding)}
    if key and #previous == 1 and previous[1] == key then return true end
    if key and not SetBinding(key, neutralBinding) then return false, "invalid" end
    for _, old in ipairs(previous) do
        if old ~= key then SetBinding(old) end
    end
    if not key and #previous == 0 then return true end
    SaveBindings(GetCurrentBindingSet())
    return true
end

local driver, currentConfig, updatePending, synchronizing
local modifierCondition = "[mod:ctrl,mod:shift,mod:alt] 7; [mod:ctrl,mod:shift] 3; "
    .. "[mod:ctrl,mod:alt] 5; [mod:shift,mod:alt] 6; [mod:ctrl] 1; [mod:shift] 2; [mod:alt] 4; 0"
local layerByMask = {[0] = "base", "ctrl", "maj", "ctrl+maj", "alt", "ctrl+alt", "maj+alt", "ctrl+maj+alt"}
local prefixMask = {CTRL = 1, SHIFT = 2, ALT = 4}
local activeSwitches, observedMask, timedPress, pendingRestore

local function physicalMask()
    return (IsControlKeyDown() and 1 or 0) + (IsShiftKeyDown() and 2 or 0) + (IsAltKeyDown() and 4 or 0)
end

function addon.HoldSensitivity(value)
    return math.max(50, math.min(1000, math.floor((tonumber(value) or 150) + 0.5)))
end

function addon.ResetTimedHold()
    observedMask, timedPress, pendingRestore = physicalMask(), nil, nil
end

local function includesMask(mask, required)
    for _, bit in ipairs({1, 2, 4}) do
        if required % (bit * 2) >= bit and mask % (bit * 2) < bit then return false end
    end
    return true
end

function addon.ApplyTimedHold()
    if not pendingRestore then return end
    if InCombatLockdown() or GetTime() - pendingRestore.releasedAt > 0.5 then
        addon.ResetTimedHold()
        return
    end
    local physical = driver:GetAttribute("shiftkit-physical") or 0
    if physical ~= observedMask or includesMask(physical, pendingRestore.mask) then return end
    if driver:GetAttribute("shiftkit-last-press") == pendingRestore.mask
        and driver:GetAttribute("shiftkit-press-sequence") == pendingRestore.sequence then
        driver:Execute([[
            self:SetAttribute("shiftkit-latched", self:GetAttribute("shiftkit-before-press") or 0)
            self:SetAttribute("shiftkit-last-press", nil)
            self:RunAttribute("shiftkit-update")
        ]])
    end
    pendingRestore = nil
end

local function observeTimedHold()
    if not currentConfig or not BartenderGlowLayout.timedHoldEnabled or InCombatLockdown() then return end
    local mask = physicalMask()
    if mask == observedMask then return end
    local now = GetTime()
    if timedPress and not includesMask(mask, timedPress.mask) then
        local threshold = addon.HoldSensitivity(BartenderGlowLayout.timedHoldSensitivity) / 1000
        if now - timedPress.startedAt >= threshold then
            pendingRestore = timedPress
            pendingRestore.releasedAt = now
        end
        timedPress = nil
    end
    if activeSwitches[layerByMask[mask]] and not includesMask(observedMask, mask) then
        local sequence = driver:GetAttribute("shiftkit-press-sequence") or 0
        local observedByDriver = driver:GetAttribute("shiftkit-physical") == mask
            and driver:GetAttribute("shiftkit-last-press") == mask
        timedPress = {mask = mask, startedAt = now, sequence = observedByDriver and sequence or sequence + 1}
        pendingRestore = nil
    end
    observedMask = mask
    addon.ApplyTimedHold()
end

function addon.ActivationMode(panel)
    return panel.activationMode or ((panel.layer == "never" or panel.layer == "always") and "none" or "hold")
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
                    for physical, heldPrefix in ipairs(modifierPrefix) do
                        if disjoint(mask, physical) and not switches[layerByMask[physical]]
                            and not (key == "F4" and hasBit(mask + physical, 4)) then
                            local pressed = heldPrefix .. key
                            local assigned = GetBindingAction(pressed, false) or ""
                            if (assigned == "" or isActionBinding(assigned)) and not protectsShortcut(key, physical) then
                                local combined = GetBindingAction(modifierPrefix[mask + physical] .. key, true) or ""
                                local action = isActionBinding(combined) and combined or (combined == "" and target or "")
                                if isActionBinding(action) then
                                    if selfCastMask and hasBit(physical, selfCastMask) then action = selfCastAction(action) end
                                    entries[#entries + 1] = ("bindings[%d][%d][%q] = %q")
                                        :format(mask, physical, pressed, action)
                                end
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
    local physical = tonumber(newstate) or 0
    local previous = self:GetAttribute("shiftkit-physical") or 0
    if physical == previous then return end

    local candidates = candidateMasks[physical]
    local priorCandidates = candidateMasks[previous]
    local added = false
    for bit = 1, 4 do
        if bit ~= 3 and candidates % (bit * 2) >= bit and previous % (bit * 2) < bit
            and physical % (bit * 2) >= bit then
            added = true
        end
    end
    if added then
        local latched = self:GetAttribute("shiftkit-latched") or 0
        if priorCandidates == 0 then self:SetAttribute("shiftkit-before-press", latched) end
        local before = self:GetAttribute("shiftkit-before-press") or 0
        self:SetAttribute("shiftkit-latched", candidates == before and 0 or candidates)
        self:SetAttribute("shiftkit-last-press", candidates)
        self:SetAttribute("shiftkit-press-sequence", (self:GetAttribute("shiftkit-press-sequence") or 0) + 1)
    end
    self:SetAttribute("shiftkit-physical", physical)
    self:RunAttribute("shiftkit-update")
]]

local function installDriver()
    driver = CreateFrame("Frame", nil, UIParent, "SecureHandlerStateTemplate")
    driver:SetAttribute("_onstate-shiftkitmods", modifierChanged)
    driver:SetAttribute("shiftkit-update", updateBindings)
    local reset = CreateFrame("Button", neutralButtonName, UIParent, "SecureHandlerClickTemplate")
    reset:SetSize(1, 1)
    reset:EnableMouse(false)
    reset:SetFrameRef("shiftkit", driver)
    reset:RegisterForClicks("AnyDown", "AnyUp")
    reset:SetAttribute("_onclick", [[
        if down then return end
        local controller = self:GetFrameRef("shiftkit")
        controller:ClearBindings()
        controller:SetAttribute("shiftkit-latched", 0)
        controller:SetAttribute("shiftkit-before-press", 0)
        controller:SetAttribute("shiftkit-last-press", nil)
        controller:SetAttribute("shiftkit-mapped", controller:GetAttribute("shiftkit-physical") or 0)
        controller:SetAttribute("shiftkit-display", controller:GetAttribute("shiftkit-physical") or 0)
    ]])
end

function addon.SyncSwitch(reset)
    if synchronizing then return end
    if InCombatLockdown() then
        updatePending = true
        return
    end
    if not driver then installDriver() end
    updatePending = false
    local configuration = {"bindings = newtable(); candidateMasks = newtable()"}
    local switches = {}
    for _, panel in ipairs(BartenderGlowLayout.panels) do
        if addon.ActivationMode(panel) == "latch" and panel.layer ~= "base" then switches[panel.layer] = true end
    end
    for physical = 0, 7 do
        local candidate = switches[layerByMask[physical]] and physical or 0
        configuration[#configuration + 1] = ("bindings[%d] = newtable(); candidateMasks[%d] = %d")
            :format(physical, physical, candidate)
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
        addon.ResetTimedHold()
        activeSwitches = switches
        driver:SetAttribute("shiftkit-latched", 0)
        driver:SetAttribute("shiftkit-mapped", 0)
        driver:SetAttribute("shiftkit-physical", physical)
        driver:SetAttribute("shiftkit-display", physical)
        driver:SetAttribute("shiftkit-before-press", 0)
        driver:SetAttribute("shiftkit-last-press", nil)
        driver:Execute(source)
        driver:SetAttribute("state-shiftkitmods", nil)
        currentConfig = source
        RegisterStateDriver(driver, "shiftkitmods", modifierCondition)
        synchronizing = false
    end
end

function addon.LatchedLayer()
    if not currentConfig then return end
    if timedPress and driver:GetAttribute("shiftkit-last-press") == timedPress.mask
        and driver:GetAttribute("shiftkit-press-sequence") == timedPress.sequence then
        return layerByMask[timedPress.mask]
    end
    return layerByMask[driver:GetAttribute("shiftkit-latched")]
end

function addon.SwitchLayer()
    if currentConfig then return layerByMask[driver:GetAttribute("shiftkit-display")] end
end

function addon.SwitchEvent(event)
    if event == "MODIFIER_STATE_CHANGED" then
        observeTimedHold()
    elseif event == "PLAYER_REGEN_DISABLED" then
        addon.ResetTimedHold()
    elseif event == "PLAYER_REGEN_ENABLED" then
        addon.ResetTimedHold()
        if updatePending then addon.SyncSwitch() end
    elseif event == "UPDATE_BINDINGS" or event == "PLAYER_ENTERING_WORLD" then
        addon.SyncSwitch()
    end
end
