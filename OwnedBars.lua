local _, A = ...
local M = A.BarLayout
local tr = A.Translate
local runtime = {}
A.ownedBars = runtime
local step = 2 * math.pi / 48
local asset = [[Interface\AddOns\]] .. (...) .. [[\Media\RoundedButton.tga]]
local circle = [[Interface\CharacterFrame\TempPortraitAlphaMask]]
local totemControls = [[Interface\AddOns\]] .. (...) .. [[\Media\TotemControls.tga]]
local dismissDiameter = 12
local function borderPoint(index, shape, inset)
    local radius = 18 - inset
    if shape == "square" then
        index = index + 6
        local side = math.floor(index / 12) % 4
        local along = (index % 12 / 6 - 1) * radius
        if side == 0 then return along, radius end
        if side == 1 then return radius, -along end
        if side == 2 then return -along, -radius end
        return -radius, along
    end
    local angle = index * step
    return math.sin(angle) * radius, math.cos(angle) * radius
end

local function setShape(button, shape)
    if button.shape == shape then return end
    if button.shape and button.shape ~= "square" then
        button.icon:RemoveMaskTexture(button.mask)
        button.hover:RemoveMaskTexture(button.mask)
        button.pressed:RemoveMaskTexture(button.mask)
        button.base:RemoveMaskTexture(button.mask)
    end
    button.shape = shape
    if shape ~= "square" then
        button.mask:SetTexture(shape == "round" and circle or asset, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        button.icon:AddMaskTexture(button.mask)
        button.hover:AddMaskTexture(button.mask)
        button.pressed:AddMaskTexture(button.mask)
        button.base:AddMaskTexture(button.mask)
    end
    for j, band in ipairs(button.bands) do
        local dy = 18-(j-.5)*2
        local width = 36
        if shape == "round" then width = 2*math.sqrt(324-dy*dy)
        elseif shape == "rounded" and dy > 12 then width = 2*(12+math.sqrt(36-(dy-12)^2)) end
        band:SetWidth(width)
    end
    button.totemClock:SetSwipeTexture(shape=="round" and circle or shape=="rounded" and asset or [[Interface\Buttons\WHITE8X8]])
    button.totemClock:SetUseCircularEdge(shape=="round")
    button.nativeCD:SetUseCircularEdge(shape=="round")
    button.nativeCD:SetSwipeTexture(shape=="round" and circle or shape=="rounded" and asset or [[Interface\Buttons\WHITE8X8]])
end

local function info(slot)
    if GetActionCooldown then return GetActionCooldown(slot) end
    local cd = C_ActionBar and C_ActionBar.GetActionCooldown(slot)
    if cd then return cd.startTime, cd.duration, cd.isEnabled, cd.modRate end
end

local function updateSwipe(frame,start,duration,rate)
    if not start or not duration or duration<=0 then
        frame:Hide()
        frame.lastStart=nil
        return
    end
    if frame.lastStart~=start or frame.lastDuration~=duration or frame.lastRate~=rate then
        frame:SetCooldown(start,duration,rate or 1)
        frame.lastStart,frame.lastDuration,frame.lastRate=start,duration,rate
    end
    frame:Show()
end

local function color(hex)
    return tonumber(hex:sub(1,2),16)/255,tonumber(hex:sub(3,4),16)/255,tonumber(hex:sub(5,6),16)/255
end

local draftBarStyles
local function actionInfo(slot)
    local query = GetActionInfo or (C_ActionBar and C_ActionBar.GetActionInfo)
    if slot and query then return query(slot) end
end

local function itemCountText(item)
    local query = C_Item and C_Item.GetItemCount or GetItemCount
    if not item or not query or (issecretvalue and issecretvalue(item)) then return "" end
    local count = query(item, false, false)
    if count == nil or (issecretvalue and issecretvalue(count)) then return "" end
    return tostring(count)
end

local function actionDisplayCount(slot)
    local query = C_ActionBar and C_ActionBar.GetActionDisplayCount
    if slot and query then return query(slot) end
    return ""
end

local function spellCountText(spell, slot)
    if issecretvalue and issecretvalue(spell) then return actionDisplayCount(slot) end
    if not spell then return "" end
    local consumable = C_Spell and C_Spell.IsConsumableSpell or IsConsumableSpell
    local query = C_Spell and C_Spell.GetSpellCastCount or GetSpellCount
    if not consumable or not query or not consumable(spell) then return "" end
    local count = query(spell)
    if issecretvalue and issecretvalue(count) then
        -- Water Breathing consumes one Shiny Fish Scale per cast.
        if spell == 131 then
            local stock = itemCountText(17057)
            if stock ~= "" then return stock end
        end
        local display = C_Spell and C_Spell.GetSpellDisplayCount
        if display then return display(spell) end
        return actionDisplayCount(slot)
    end
    return count ~= nil and tostring(count) or ""
end

local function spellCooldownObject(spell)
    if (issecretvalue and issecretvalue(spell)) or not spell
        or not C_Spell or not C_Spell.GetSpellCooldownDuration then return end
    return C_Spell.GetSpellCooldownDuration(spell)
end

local function playerAuraDuration(spell)
    local api = C_UnitAuras
    if issecretvalue and issecretvalue(spell) then spell = nil end
    if not api or not api.GetPlayerAuraBySpellID or not spell then return end
    local aura = api.GetPlayerAuraBySpellID(spell)
    if not aura then return end
    local instance = aura.auraInstanceID
    local duration, expires = aura.duration, aura.expirationTime
    if issecretvalue and (issecretvalue(duration) or issecretvalue(expires)) then
        if api.GetAuraDuration and not issecretvalue(instance) and instance then
            local object = api.GetAuraDuration("player", instance)
            if object and object.GetRemainingDuration and object.GetTotalDuration then
                local remaining, total = object:GetRemainingDuration(), object:GetTotalDuration()
                if not (issecretvalue(remaining) or issecretvalue(total)) then
                    if remaining > 0 and total > 0 then return GetTime() + remaining - total, total end
                    return
                end
            end
            return nil, nil, object
        end
    elseif duration and duration > 0 and expires and expires > GetTime() then
        return expires - duration, duration
    end
end

local function draw(b, preview)
    local bar = draftBarStyles and draftBarStyles[b.model] or b.model
    setShape(b, bar.shape or "square")
    if b.drawStyle ~= bar then
        b.drawStyle = bar
        b.lastEdge = nil
        for _, line in ipairs(b.lines) do line.lit = nil end
    end
    local slot = b:GetAttribute("action")
    local texture, start, duration, rate, caption, totemStart, totemDuration, item, spell, totemDurationObject
    local privateActionType
    local auraSpell
    local entry = bar.extra and bar.extra[b.index]
    if bar.kind=="action" and b.index>12 then
        if entry then
            texture=entry.texture
            if entry.kind=="item" then item=entry.id end
            if entry.kind=="spell" then spell=entry.id end
            if entry.kind=="spell" and C_Spell and C_Spell.GetSpellCooldown then
                local cd=C_Spell.GetSpellCooldown(entry.id)
                if cd then start,duration,rate=cd.startTime,cd.duration,cd.modRate end
            end
            if entry.kind=="macro" and bar.macros then caption=entry.id end
        end
    elseif bar.kind == "action" then
        texture = (GetActionTexture or C_ActionBar.GetActionTexture)(slot)
        local kind, id = actionInfo(slot)
        privateActionType = issecretvalue and issecretvalue(kind)
        if not privateActionType then
            if kind == "item" then item = id elseif kind == "spell" then spell = id end
        end
        -- The client may restrict action metadata in combat. Reuse the last
        -- readable spell only while the action slot and its icon still match.
        if privateActionType or (issecretvalue and issecretvalue(spell)) then
            if InCombatLockdown() and b.auraActionSlot == slot and
                ((issecretvalue and issecretvalue(texture)) or b.auraActionTexture == texture) then
                auraSpell = b.auraActionSpell
            end
        else
            local readableTexture = not (issecretvalue and issecretvalue(texture)) and texture or nil
            b.auraActionSlot, b.auraActionSpell, b.auraActionTexture = slot, spell, readableTexture
            auraSpell = spell
        end
        local enabled
        start, duration, enabled, rate = info(slot)
        if not (issecretvalue and issecretvalue(enabled)) and (enabled == 0 or enabled == false) then duration = 0 end
        if bar.macros then caption = (GetActionText or C_ActionBar.GetActionText)(slot) end
    elseif bar.kind == "stance" then
        if b.index <= GetNumShapeshiftForms() then
            local active
            texture, active = GetShapeshiftFormInfo(b.index)
            caption = active and "●" or nil
            start, duration = GetShapeshiftFormCooldown(b.index)
        end
    else
        texture, start, duration, caption, totemStart, totemDuration, totemDurationObject = A.TotemVisual(b)
        if b.index > 4 and entry and entry.kind == "item" then item = entry.id
        else spell = b.spellId end
    end
    if not (issecretvalue and issecretvalue(item)) and item and not (bar.kind == "action" and b.index <= 12) then
        local query = C_Item and C_Item.GetItemCooldown or GetItemCooldown
        if query then start, duration = query(item) end
    end
    b.icon:SetTexture(texture)
    b.caption:SetText(caption or "")
    if privateActionType or (issecretvalue and issecretvalue(item)) then
        b.itemCount:SetText(actionDisplayCount(slot))
    elseif item then
        b.itemCount:SetText(itemCountText(item))
    else
        b.itemCount:SetText(spellCountText(spell, slot))
    end
    local command="CLICK "..b:GetName()..":LeftButton"
    local context=C_KeyBindings and C_KeyBindings.GetBindingContextForAction
        and C_KeyBindings.GetBindingContextForAction(command)
    local key=GetBindingKey(command,nil,context) or b.nativeKey
    b.HotKey:SetText(bar.keys and key and GetBindingText(key, "KEY_", true) or "")
    local cooldown=bar.cooldown or "edge"
    local red,green,blue=color(bar.cooldownColor or "FFD42E")
    local rounded=cooldown=="edge" and b.shape=="rounded"
    local secret=issecretvalue and (issecretvalue(duration) or issecretvalue(start) or issecretvalue(rate))
    local cooldownObject
    if secret then
        if bar.kind == "action" and b.index <= 12 then
            local query = C_ActionBar and C_ActionBar.GetActionCooldownDuration
            if query and slot then cooldownObject = query(slot) end
        end
        if not cooldownObject then
            if not (issecretvalue and (issecretvalue(spell) or issecretvalue(item))) and not spell and item then
                local query = C_Item and C_Item.GetItemSpell or GetItemSpell
                if query then spell = select(2, query(item)) end
            end
            cooldownObject = spellCooldownObject(spell)
        end
        duration = nil
    end
    if cooldownObject and (cooldown ~= "none" or bar.showCooldownText) then
        local swipe = b.shape == "round" and circle or b.shape == "rounded" and asset
            or [[Interface\Buttons\WHITE8X8]]
        if rounded then swipe = asset:gsub("RoundedButton", "Solid3") end
        if b.nativeCD.roundedEdge ~= rounded then
            b.nativeCD:SetFrameLevel(b:GetFrameLevel() + (rounded and 9 or 1))
            b.nativeCD.roundedEdge = rounded
        end
        b.nativeCD:SetSwipeTexture(swipe)
        b.nativeCD:SetDrawSwipe(cooldown ~= "none")
        b.nativeCD:SetHideCountdownNumbers(not bar.showCooldownText)
        b.nativeCD:SetSwipeColor(red, green, blue, rounded and 1 or .65)
        b.nativeCD:SetCooldownFromDurationObject(cooldownObject)
        b.nativeCD:Show()
    else
        b.nativeCD:Hide()
    end
    local progress = duration and duration > 0 and math.min(1, (GetTime()-start)*(rate or 1)/duration) or 1
    local demo=preview and not secret and progress>=1 and cooldown~="none"
    if demo then
        start,duration,rate=GetTime()-GetTime()%3,3,1
        progress=(GetTime()-start)/duration
    end
    b.roundedCD:SetSwipeColor(red,green,blue,1)
    local ringActive=rounded and not secret and progress<1
    updateSwipe(b.roundedCD,ringActive and start,duration,rate)
    local countdown=not secret and bar.showCooldownText and not demo and progress<1
    local seconds=countdown and math.max(1,math.ceil(duration*(1-progress)/(rate or 1)))
    if not seconds and preview and A.totemCooldownPreview==bar and bar.showCooldownText and b.index<=4 and not secret then
        seconds=8
    end
    local isTotem = bar.kind == "totem"
    local totemMode = isTotem and (bar.totemProgress or "bar") or (bar.auraProgress or "none")
    if not isTotem and bar.kind == "action" and totemMode ~= "none" then
        totemStart, totemDuration, totemDurationObject = playerAuraDuration(auraSpell or spell)
        if totemStart or totemDurationObject then
            b.nativeCD:SetHideCountdownNumbers(true)
            seconds = totemStart and (totemStart + totemDuration - GetTime())
        end
    end
    b.cooldownText:SetText(seconds and A.FormatRemaining(seconds) or "")
    local activeTotem = isTotem and b.slot and (totemStart or totemDurationObject)
    if preview and not totemStart and bar.kind=="totem" and b.index<=4 and totemMode~="none" then
        local now=GetTime()
        totemDuration=12
        totemStart=now-now%12
    end
    local remaining=totemStart and totemDuration and totemDuration>0 and
        math.max(0,math.min(1,(totemStart+totemDuration-GetTime())/totemDuration))
    local life=remaining and remaining>0
    if b.dismissTotem then
        local dismissible = not InCombatLockdown() and bar.showTotemDismiss ~= false
            and activeTotem and not not (life or totemDurationObject)
        if dismissible and GetTotemCannotDismiss then
            local cannotDismiss = GetTotemCannotDismiss(b.slot)
            dismissible = not ((issecretvalue and issecretvalue(cannotDismiss)) or cannotDismiss)
        end
        dismissible = not not dismissible
        local dismiss = b.dismissTotem
        dismiss:SetAlpha(dismissible and 1 or 0)
        dismiss.dismissible:SetShown(dismissible)
        if not InCombatLockdown() and dismiss:IsMouseEnabled() ~= dismissible then
            dismiss:EnableMouse(dismissible)
        end
        local rim = dismiss.rim
        local width = bar.totemDismissBorderWidth or math.max(1, math.min(2, bar.borderWidth or 1))
        if width ~= rim.width then
            local fillDiameter = dismissDiameter - 2 * width
            rim:SetShown(width > 0)
            dismiss.fill:SetSize(fillDiameter, fillDiameter)
            rim.width = width
        end
        local r, g, blue = color(bar.totemDismissBorderColor or bar.borderColor or "787D85")
        rim:SetVertexColor(r, g, blue, bar.borderOpacity or .9)
        dismiss.fill:SetVertexColor(color(bar.totemDismissBackground or M.totemDismissDefaults.background))
    end
    if isTotem or totemMode ~= "none" then
        local prefix=(isTotem and "totem_" or "aura_")..totemMode
        local hex=bar[prefix.."Color"] or (totemMode=="clock" and "17251C" or "59FF7D")
        local r,g,blue=color(hex)
        local opacity=bar[prefix.."Opacity"] or (totemMode=="clock" and .65 or .95)
        local size=bar[prefix.."Size"] or (totemMode=="clock" and 1 or 3)
        b.totemTrack:SetShown(not not (life and totemMode=="bar"))
        if life and totemMode=="bar" then
            b.totemTrack:SetHeight(size)
            b.totemFill:SetHeight(size)
            b.totemFill:SetWidth(math.max(.01,28*remaining))
            b.totemFill:SetColorTexture(r,g,blue,opacity)
        end
        if life and totemMode=="ring" then
            local thickness=math.max(1,math.min(8,math.floor(size+.5)))
            if b.totemRing.thickness~=thickness then
                b.totemRing:SetSwipeTexture((asset:gsub("RoundedButton","Solid"..thickness)))
                b.totemRing.thickness=thickness
            end
            b.totemRing:SetSwipeColor(r,g,blue,opacity)
        end
        if life and totemMode=="clock" then
            b.totemClock:SetSwipeColor(r,g,blue,opacity)
            local inset=(1-size)*18
            if b.totemClock.inset~=inset then
                b.totemClock:ClearAllPoints()
                b.totemClock:SetPoint("TOPLEFT",inset,-inset)
                b.totemClock:SetPoint("BOTTOMRIGHT",-inset,inset)
                b.totemClock.inset=inset
            end
        end
        updateSwipe(b.totemRing,life and totemMode=="ring" and totemStart,totemDuration)
        if totemDurationObject and totemMode ~= "none" then
            b.totemClock.lastStart = nil
            b.totemClock:SetSwipeColor(r, g, blue, opacity)
            b.totemClock:SetHideCountdownNumbers(isTotem)
            b.totemClock:SetCooldownFromDurationObject(totemDurationObject)
            b.totemClock:Show()
        else
            b.totemClock:SetHideCountdownNumbers(true)
            updateSwipe(b.totemClock,life and totemMode=="clock" and totemStart,totemDuration)
        end
    else
        b.totemTrack:Hide();b.totemRing:Hide();b.totemClock:Hide()
    end
    local visible = texture or bar.empty or preview
    b.base:SetShown(not not visible)
    local edge = cooldown == "edge" and not rounded and progress < 1
    local litCount=edge and math.max(1, math.ceil(progress*48)) or 0
    local showBorder=not not (visible and bar.border and bar.borderStyle~="none")
    local hex=bar.borderColor or "787D85"
    local r,g,blue=tonumber(hex:sub(1,2),16),tonumber(hex:sub(3,4),16),tonumber(hex:sub(5,6),16)
    local alpha=bar.borderOpacity or .9
    b.decor:SetShown(showBorder and b.shape=="rounded")
    if b.shape == "rounded" then
        local width = math.max(1, math.min(8, math.floor((bar.borderWidth or 1) + .5)))
        local texture = bar.borderStyle == "dashed" and "Dash" or "Solid"
        local borderAsset = texture .. width
        if b.borderAsset ~= borderAsset then
            b.decor:SetTexture((asset:gsub("RoundedButton", borderAsset)))
            b.borderAsset = borderAsset
        end
    end
    b.decor:SetVertexColor((r or 120)/255,(g or 125)/255,(blue or 133)/255,alpha)
    if b.lastEdge~=litCount or b.lastBorder~=showBorder or b.edgeColor~=bar.cooldownColor then
        for i, line in ipairs(b.lines) do
            local lit = i <= litCount
            if lit ~= line.lit or (lit and b.edgeColor~=bar.cooldownColor) then
                if lit then line:SetColorTexture(red,green,blue,1) else line:SetColorTexture((r or 120)/255,(g or 125)/255,(blue or 133)/255,alpha) end
                local width = lit and 2 or (bar.borderWidth or 1)
                local x, y = borderPoint(i - 1, b.shape, width / 2)
                local xx, yy = borderPoint(i, b.shape, width / 2)
                line:SetStartPoint("CENTER", b, x, y)
                line:SetEndPoint("CENTER", b, xx, yy)
                line:SetThickness(width)
                line.lit = lit
            end
            line:SetShown(lit or (showBorder and b.shape~="rounded" and (bar.borderStyle~="dashed" or i%4<2)))
        end
        b.lastEdge,b.lastBorder,b.edgeColor=litCount,showBorder,bar.cooldownColor
    end
    -- Horizontal black scanlines clip the progress veil to the circular silhouette.
    local veil = progress < 1 and cooldown == "veil"
    if bar.cooldownColor~=b.veilColor then
        b.veilColor=bar.cooldownColor
        for _,band in ipairs(b.bands) do
            if b.veilColor then band:SetColorTexture(red,green,blue,.45)
            else band:SetColorTexture(0,0,0,.68) end
        end
    end
    local bands=veil and math.ceil((1-progress)*18) or 0
    if bands~=b.lastBands then
        for i, band in ipairs(b.bands) do band:SetShown(i<=bands) end
        b.lastBands=bands
    end
end

local draggedItem

local function nativeSlot(button)
    if button.model.kind == "action" and button.index <= 12 then return button:GetAttribute("action") end
end

local function buttonEntry(button, slot)
    if slot then
        local kind, id = actionInfo(slot)
        if id and (kind == "item" or kind == "spell" or kind == "macro") then
            return {kind=kind, id=id, texture=(GetActionTexture or C_ActionBar.GetActionTexture)(slot)}
        end
    else
        local bar = button.model
        local entry = bar.extra and bar.extra[button.index]
        if entry then return entry end
        if bar.kind == "totem" and button.spellId then
            return {kind="spell", id=button.spellId, texture=C_Spell.GetSpellTexture(button.spellId)}
        end
    end
end

local function putExtra(button, entry)
    local bar = button.model
    bar.extra = bar.extra or {}
    if not entry and bar.kind == "totem" then entry = false end
    bar.extra[button.index] = entry
end

local function pickupEntry(entry)
    if entry.kind == "item" then
        local pickup = C_Item and C_Item.PickupItem or PickupItem
        if pickup then pickup("item:" .. entry.id) end
    elseif entry.kind == "spell" then
        C_Spell.PickupSpell(entry.id)
    elseif entry.kind == "macro" then
        PickupMacro(entry.id)
    end
end

local function placeDraggedItem(target, slot, drag)
    local source, sourceSlot = drag.button, drag.slot
    if source.model ~= drag.model or nativeSlot(source) ~= sourceSlot then return end
    local current = buttonEntry(source, sourceSlot)
    if not current or current.kind ~= "item" or current.id ~= drag.entry.id then return end
    if target == source or (slot and slot == sourceSlot) then ClearCursor(); return end
    local displaced = buttonEntry(target, slot)
    if sourceSlot and slot then
        ClearCursor()
        PickupAction(sourceSlot)
        if not GetCursorInfo() then return end
        PlaceAction(slot)
        if GetCursorInfo() then PlaceAction(sourceSlot) end
    elseif slot then
        local hasAction = HasAction or (C_ActionBar and C_ActionBar.HasAction)
        if not displaced and ((hasAction and hasAction(slot)) or actionInfo(slot)) then return end
        PlaceAction(slot)
        local placedKind, placedId = actionInfo(slot)
        if placedKind ~= "item" or placedId ~= drag.entry.id then return end
        putExtra(source, displaced)
    elseif sourceSlot then
        ClearCursor()
        if displaced then
            pickupEntry(displaced)
            if not GetCursorInfo() then return end
            PlaceAction(sourceSlot)
            local replacedKind, replacedId = actionInfo(sourceSlot)
            if replacedKind ~= displaced.kind or replacedId ~= displaced.id then
                ClearCursor()
                return
            end
        else
            PickupAction(sourceSlot)
            if not GetCursorInfo() then return end
        end
        putExtra(target, drag.entry)
    else
        putExtra(source, displaced)
        putExtra(target, drag.entry)
    end
    if GetCursorInfo() then ClearCursor() end
    A.RebuildBars()
end

local pendingTotemCast
local function unavailableReason(button)
    local model = button.model
    local slot = nativeSlot(button)
    local kind, id
    if slot then
        kind, id = actionInfo(slot)
    elseif model.kind == "totem" and button.spellId then
        kind, id = "spell", button.spellId
    else
        local entry = model.extra and model.extra[button.index]
        if entry then kind, id = entry.kind, entry.id end
    end
    if issecretvalue and (issecretvalue(kind) or issecretvalue(id)) then return end
    if not kind and not slot and (model.kind == "action" or model.kind == "totem") then
        return tr("Action indisponible", "Action unavailable")
    end
    local usable, noMana
    if slot then
        local query = IsUsableAction or (C_ActionBar and C_ActionBar.IsUsableAction)
        if query then usable, noMana = query(slot) end
    elseif kind == "spell" and id then
        local query = C_Spell and C_Spell.IsSpellUsable or IsUsableSpell
        if query then usable, noMana = query(id) end
    end
    if not (issecretvalue and issecretvalue(noMana)) and noMana then
        return tr("Mana insuffisant", "Not enough mana")
    end
    if not (issecretvalue and issecretvalue(usable)) and usable == false then
        return tr("Action indisponible", "Action unavailable")
    end
    if kind == "spell" and id and C_Spell and C_Spell.GetSpellCooldown then
        local cd = C_Spell.GetSpellCooldown(id)
        if not cd then return end
        local start, duration, rate = cd.startTime, cd.duration, cd.modRate
        if issecretvalue and (issecretvalue(start) or issecretvalue(duration) or issecretvalue(rate)) then return end
        if start and duration and start > 0 and duration > 0 then
            local remaining = start + duration / (rate and rate > 0 and rate or 1) - GetTime()
            if remaining > 0 then
                return tr("Recharge : %s", "Cooldown: %s"):format(A.FormatRemaining(remaining))
            end
        end
    end
end

local function makeButton(frame, id, i)
    local b = CreateFrame("Button", "KeyLayersBar"..id.."Button"..i, frame, "SecureActionButtonTemplate, SecureHandlerMouseUpDownTemplate")
    b.index = i
    b:SetSize(36,36)
    b:RegisterForClicks("AnyDown","AnyUp")
    b:RegisterForDrag("LeftButton")
    b:SetAttribute("_onmousedown", [[
        if button == "LeftButton" and self:GetAttribute("editableAction") then
            self:SetAttribute("mouseLeftClick", true)
            self:SetAttribute("editMouseLeftClick", nil)
        end
    ]])
    b:SetAttribute("_onmouseup", [[
        if button == "LeftButton" and not self:IsUnderMouse() then
            self:SetAttribute("mouseLeftClick", nil)
            self:SetAttribute("editMouseLeftClick", nil)
        end
    ]])
    frame:WrapScript(b, "OnClick", [[
        if not self:IsVisible() then return false end
        if self:GetAttribute("editableAction") then
            local modifier = control:GetAttribute("actionEditModifier")
            local editingModifier = (modifier == "SHIFT" and IsShiftKeyDown())
                or (modifier == "CTRL" and IsControlKeyDown())
                or (modifier == "ALT" and IsAltKeyDown())
            if button == "RightButton" and editingModifier then
                if not down then self:CallMethod("RemoveAction") end
                return false
            end
            if button == "LeftButton" and self:GetAttribute("mouseLeftClick") then
                local block = self:GetAttribute("editMouseLeftClick")
                    or (control:GetAttribute("lockActions") and editingModifier)
                if down then
                    self:SetAttribute("editMouseLeftClick", block)
                else
                    self:SetAttribute("mouseLeftClick", nil)
                    self:SetAttribute("editMouseLeftClick", nil)
                end
                if block then
                    self:CallMethod("FlashPressed", true)
                    return false
                end
            end
        end
        if button ~= "RightButton" and not self:GetAttribute("element") then self:CallMethod("FlashPressed") end
    ]])
    frame:WrapScript(b, "OnHide", [[
        self:SetAttribute("mouseLeftClick", nil)
        self:SetAttribute("editMouseLeftClick", nil)
    ]])
    b:SetAttribute("checkselfcast",true)
    b:SetAttribute("checkfocuscast",true)
    b.base = b:CreateTexture(nil,"BACKGROUND")
    b.base:SetAllPoints()
    b.base:SetColorTexture(0.07,0.08,0.10,0.74)
    b.icon = b:CreateTexture(nil,"ARTWORK")
    b.icon:SetAllPoints()
    b.icon:SetTexCoord(.055,.945,.055,.945)
    b.hover=b:CreateTexture(nil,"HIGHLIGHT",nil,0)
    b.hover:SetAllPoints()
    b:SetHighlightTexture(b.hover)
    b.pressed=b:CreateTexture(nil,"OVERLAY",nil,4)
    b.pressed:SetAllPoints()
    b.pressed:Hide()
    function b:FlashPressed(blocked, castAttempt)
        local reason = blocked and castAttempt and tr("Aucun totem sélectionné", "No totem selected")
            or (not blocked and self.model and unavailableReason(self))
        local rgb = (blocked or reason) and self.blockedPressColor or self.pressColor
        self.pressed:SetColorTexture(rgb[1], rgb[2], rgb[3], self.pressOpacity)
        self.pressedUntil = GetTime() + ((blocked or reason) and .28 or .16)
        self.pressed:Show()
        if castAttempt and reason and UIErrorsFrame then UIErrorsFrame:AddMessage(reason) end
        if castAttempt and not blocked then
            pendingTotemCast = {button = self, spell = self.spellId, untilTime = GetTime() + .35}
        end
    end
    b:HookScript("OnHide",function(self) self.pressed:Hide();self.pressedUntil=nil end)
    b.mask = b:CreateMaskTexture()
    b.mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    b.mask:SetAllPoints()
    local border=CreateFrame("Frame",nil,b)
    border:SetAllPoints()
    border:SetFrameLevel(b:GetFrameLevel()+8)
    b.decor=border:CreateTexture(nil,"OVERLAY",nil,0)
    b.decor:SetAllPoints()
    b.nativeCD=CreateFrame("Cooldown",nil,b,"CooldownFrameTemplate")
    b.nativeCD:SetAllPoints()
    b.nativeCD:SetDrawEdge(false)
    b.nativeCD:Hide()
    local function ring(inset,reverse)
        local widget=CreateFrame("Cooldown",nil,b,"CooldownFrameTemplate")
        widget:SetPoint("TOPLEFT",inset,-inset)
        widget:SetPoint("BOTTOMRIGHT",-inset,inset)
        widget:SetSwipeTexture((asset:gsub("RoundedButton","Solid2")))
        widget:SetDrawEdge(false)
        widget:SetDrawBling(false)
        widget:SetHideCountdownNumbers(true)
        widget:SetReverse(reverse)
        widget:Hide()
        return widget
    end
    b.roundedCD=ring(0,true)
    b.roundedCD:SetFrameLevel(b:GetFrameLevel()+9)
    b.roundedCD:SetSwipeTexture((asset:gsub("RoundedButton","Solid3")))
    b.totemRing=ring(4,false)
    b.totemClock=ring(0,false)
    b.totemRing:SetSwipeColor(.35,1,.49,.95)
    b.lines, b.bands = {}, {}
    for j = 1,48 do
        local line = border:CreateLine(nil,"OVERLAY",nil,2)
        line:SetThickness(2)
        line:SetColorTexture(.47,.49,.52,.9)
        b.lines[j] = line
    end
    for j=1,18 do
        local band=b:CreateTexture(nil,"ARTWORK",nil,1)
        band:SetPoint("TOP",0,-(j-1)*2)
        band:SetHeight(2)
        band:SetColorTexture(0,0,0,.68)
        b.bands[j]=band
    end
    local readouts=CreateFrame("Frame",nil,b)
    readouts:SetAllPoints()
    readouts:SetFrameLevel(b:GetFrameLevel()+10)
    b.HotKey = readouts:CreateFontString(nil,"OVERLAY","NumberFontNormalSmall")
    b.HotKey:SetPoint("TOPRIGHT",-1,-1)
    b.itemCount = readouts:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    b.itemCount:SetPoint("BOTTOMRIGHT", -2, 2)
    b.itemCount:SetShadowOffset(1, -1)
    b.caption=readouts:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    b.caption:SetPoint("BOTTOM",0,8)
    b.caption:SetWidth(36)
    b.cooldownText=readouts:CreateFontString(nil,"OVERLAY","NumberFontNormalSmall")
    b.cooldownText:SetPoint("CENTER",0,6)
    b.totemTrack=CreateFrame("Frame",nil,readouts)
    b.totemTrack:SetSize(28,3)
    b.totemTrack:SetPoint("BOTTOM",0,1)
    local track=b.totemTrack:CreateTexture(nil,"BACKGROUND")
    track:SetAllPoints()
    track:SetColorTexture(.02,.12,.04,.95)
    b.totemFill=b.totemTrack:CreateTexture(nil,"ARTWORK")
    b.totemFill:SetPoint("LEFT")
    b.totemFill:SetHeight(3)
    b.totemFill:SetColorTexture(.35,1,.49,.95)
    b.totemTrack:Hide()
    local function canEdit(self)
        return not InCombatLockdown() and self:GetAttribute("editableAction")
    end
    local function canMove(self)
        if not canEdit(self) then return false end
        local workspace = M.init(KeyLayersCharLayout)
        local key = workspace.actionEditModifier
        return not workspace.lockActions or (key=="SHIFT" and IsShiftKeyDown())
            or (key=="CTRL" and IsControlKeyDown()) or (key=="ALT" and IsAltKeyDown())
    end
    local function removeExtra(self)
        putExtra(self, nil)
        A.RebuildBars()
    end
    function b:RemoveAction()
        if not self.model or not canEdit(self) or GetCursorInfo() then return end
        local slot = nativeSlot(self)
        if slot then
            PickupAction(slot)
            if GetCursorInfo() then ClearCursor() end
            draw(self, A.barPreview == self.model)
        elseif buttonEntry(self) then
            removeExtra(self)
        end
    end
    b:SetScript("OnDragStart", function(self)
        if not canMove(self) or GetCursorInfo() then return end
        draggedItem = nil
        local slot = nativeSlot(self)
        local entry = buttonEntry(self, slot)
        if entry and entry.kind == "item" then
            -- Leave the source in place until a KeyLayers destination accepts the drop.
            pickupEntry(entry)
            local kind, id = GetCursorInfo()
            if kind == "item" and id == entry.id then
                draggedItem = {button=self, model=self.model, slot=slot, entry=entry}
            end
        elseif slot then
            PickupAction(slot)
        elseif entry then
            pickupEntry(entry)
            if GetCursorInfo() then removeExtra(self) end
        end
    end)
    -- A drag does not dispatch a click on release.
    frame:WrapScript(b, "OnDragStart", [[
        self:SetAttribute("mouseLeftClick", nil)
        self:SetAttribute("editMouseLeftClick", nil)
    ]])
    b:SetScript("OnReceiveDrag",function(self)
        if not canEdit(self) then return end
        local kind,id,_,spellID=GetCursorInfo()
        local bar = self.model
        local native = bar.kind == "action" and self.index <= 12
        local slot = nativeSlot(self)
        if draggedItem and kind == "item" and id == draggedItem.entry.id then
            if not canMove(self) then return end
            local drag = draggedItem
            draggedItem = nil
            placeDraggedItem(self, slot, drag)
            return
        end
        if not canMove(self) then
            if (kind ~= "item" and kind ~= "spell" and kind ~= "macro") or not (id or spellID) then return end
            if native then
                local hasAction = HasAction or (C_ActionBar and C_ActionBar.HasAction)
                if not slot or (hasAction and hasAction(slot)) or (not hasAction and actionInfo(slot)) then return end
            elseif (bar.extra and bar.extra[self.index]) or (bar.kind == "totem" and self.spellId) then
                return
            end
        end
        if native then PlaceAction(slot); return end
        local texture
        if kind=="spell" then
            id=spellID or id
            if id then texture=C_Spell.GetSpellTexture(id) end
        elseif kind=="item" and id then
            local icon = C_Item and C_Item.GetItemIconByID or GetItemIcon
            if icon then texture=icon(id) end
        elseif kind=="macro" then id,texture=GetMacroInfo(id)
        else return end
        if not id then return end
        self.model.extra=self.model.extra or {}
        self.model.extra[self.index]={kind=kind,id=id,texture=texture}
        ClearCursor()
        A.RebuildBars()
    end)
    b:SetScript("OnEnter",function(self)
        GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
        local slot = nativeSlot(self)
        local entry = buttonEntry(self)
        if slot then
            GameTooltip:SetAction(slot)
        elseif entry and entry.kind == "spell" and entry.id then
            GameTooltip:SetSpellByID(entry.id, false, true)
        elseif entry and entry.kind == "item" and entry.id then
            GameTooltip:SetHyperlink("item:" .. entry.id)
        elseif entry and entry.kind == "macro" then
            local name = entry.id and GetMacroInfo and GetMacroInfo(entry.id)
            GameTooltip:SetText(name or tr("Macro indisponible", "Unavailable macro"))
        elseif self.model.kind == "totem" then
            A.TotemTooltip(self)
        elseif entry then
            GameTooltip:SetText(tr("Action indisponible", "Unavailable action"))
        else
            GameTooltip:SetText(self.model.name)
        end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave",function() GameTooltip:Hide() end)
    return b
end

local function configureTotemDismiss(button)
    local dismiss = button.dismissTotem
    if not dismiss and button.slot then
        dismiss = CreateFrame("Button", nil, button, "SecureActionButtonTemplate, SecureHandlerStateTemplate")
        dismiss.dismissible = CreateFrame("Frame", nil, UIParent)
        dismiss.dismissible:Hide()
        dismiss:SetFrameRef("dismissible", dismiss.dismissible)
        dismiss:SetAttribute("_onstate-combat", [[
            if newstate == "on" then
                self:EnableMouse(false)
                self:SetAttribute("dismissPress", nil)
                self:SetAttribute("type1", nil)
            end
        ]])
        RegisterStateDriver(dismiss,"combat","[combat] on; off")
        dismiss:WrapScript(dismiss, "OnClick", [[
            self:SetAttribute("type1", nil)
            local combat = self:GetAttribute("state-combat") == "on"
            if SecureCmdOptionParse then combat = SecureCmdOptionParse("[combat] on; off") == "on" end
            if combat then return false end

            local active = self:GetFrameRef("dismissible"):IsShown()
            if down then
                self:SetAttribute("dismissPress", active)
                return false
            end
            local pressed = self:GetAttribute("dismissPress")
            self:SetAttribute("dismissPress", nil)
            if not pressed or not active then return false end
            self:SetAttribute("type1", "destroytotem")
        ]])
        dismiss:RegisterForClicks("LeftButtonDown","LeftButtonUp")
        dismiss:SetPassThroughButtons("RightButton", "MiddleButton")
        dismiss:SetAttribute("useOnKeyDown", false)
        dismiss:SetSize(dismissDiameter, dismissDiameter)
        dismiss:SetFrameLevel(button:GetFrameLevel() + 12)
        local rim = dismiss:CreateTexture(nil, "BACKGROUND")
        rim:SetPoint("CENTER")
        rim:SetSize(dismissDiameter, dismissDiameter)
        rim:SetTexture(totemControls)
        rim:SetTexCoord(.5, 1, 0, 1)
        dismiss.rim = rim
        local fill = dismiss:CreateTexture(nil, "ARTWORK")
        fill:SetPoint("CENTER")
        fill:SetTexture(totemControls)
        fill:SetTexCoord(.5, 1, 0, 1)
        dismiss.fill = fill
        local label = dismiss:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        label:SetPoint("CENTER")
        label:SetText("×")
        dismiss:SetScript("OnEnter", function(self)
            if self:GetAlpha() == 0 then return end
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(tr("Retirer le totem posé", "Dismiss the active totem"))
            GameTooltip:Show()
        end)
        dismiss:SetScript("OnLeave", function() GameTooltip:Hide() end)
        dismiss:EnableMouse(false)
        button.dismissTotem = dismiss
    end
    if dismiss then
        local defaults = M.totemDismissDefaults
        local angle = math.rad(button.model.totemDismissAngle or defaults.angle)
        local distance = button.model.totemDismissDistance or defaults.distance
        dismiss:ClearAllPoints()
        dismiss:SetPoint("CENTER", button, "CENTER", math.sin(angle) * distance, math.cos(angle) * distance)
        dismiss:SetAttribute("totem-slot", button.slot)
        dismiss:SetAttribute("dismissPress", nil)
        dismiss:SetShown(button.slot ~= nil and button.model.showTotemDismiss ~= false)
        dismiss:SetAlpha(0)
        dismiss.dismissible:Hide()

    end
end

local function makeBar(id)
    local f=CreateFrame("Frame","KeyLayersOwnedBar"..id,UIParent,"SecureHandlerStateTemplate")
    f.buttons={}
    f.profileBadge=A.CreateTotemProfileTab(f)
    f.profileText=f.profileBadge.text
    f:SetFrameStrata("MEDIUM")
    f:SetAttribute("_onstate-page", [[
        if not tonumber(newstate) then return end
        for i=1,math.min(12,self:GetAttribute("count")) do
            self:GetFrameRef("slot"..i):SetAttribute("action", (tonumber(newstate)-1)*12+i)
        end
    ]])
    f:SetAttribute("_onstate-input", [[
        self:ClearBindings()
        if newstate=="on" then
            for i=1,self:GetAttribute("keyCount") do
                self:SetBindingClick(false,self:GetAttribute("key"..i),self:GetAttribute("target"..i),"LeftButton")
            end
        end
    ]])
    runtime[id]=f
    return f
end

local pageCommands={[1]=1,[6]=2,[5]=3,[3]=4,[4]=5,[13]=6,[14]=7,[15]=8}
local function configure(bar, frame, claimed)
    local parent=M.frame(bar)
    local geometry = parent and A.OwnedParentGeometry(parent)
    local columns,rows,scale,count=M.barGrid(bar,geometry)
    local x,y = M.barCenter(bar,geometry,columns,rows,scale)
    frame.layoutColumns,frame.layoutRows,frame.layoutScale=columns,rows,scale
    frame:SetScale(scale)
    frame:SetSize(36*columns+bar.gap*(columns-1),36*rows+bar.gap*(rows-1))
    frame.model=bar
    A.PlaceOwnedBar(frame,x,y)
    frame.profileBadge:SetShown(bar.kind=="totem" and not parent)
    if bar.kind=="totem" then
        A.LayoutLabelTab(frame.profileBadge, frame, A.TotemProfiles().active,
            {hintSide=bar.profileAnchor, font=bar.profileFont or "game", size=bar.profileFontSize or 12})
        if not parent then A.TintHint(frame.profileBadge, A.NewPanel(""), true) end
    end
    frame:SetAttribute("count",count)
    local keyCount=0
    local workspace=M.init(KeyLayersCharLayout)
    frame:SetAttribute("actionEditModifier", workspace.actionEditModifier)
    frame:SetAttribute("lockActions", workspace.lockActions)
    local r,g,blue=color(workspace.actionHoverColor or "65CCFF")
    local pressColor = {color(workspace.actionPressColor or "FFD250")}
    local blockedPressColor = {color(workspace.actionBlockedPressColor or "FF4242")}
    for i=1,count do
        local b=frame.buttons[i]
        if not b then
            b=makeButton(frame,bar.id,i)
            frame.buttons[i]=b
            frame:SetFrameRef("slot"..i,b)
        end
        b.model=bar
        b.hover:SetColorTexture(r,g,blue,(bar.kind=="action" or bar.kind=="totem") and .32 or 0)
        b.pressColor, b.blockedPressColor = pressColor, blockedPressColor
        b.pressOpacity = workspace.actionPressOpacity or .55
        local n=M.slotPosition(bar,i,count)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT",(n%columns)*(36+bar.gap),-math.floor(n/columns)*(36+bar.gap))
        local style = draftBarStyles and draftBarStyles[bar] or bar
        setShape(b, style.shape or "square")
        b.drawStyle = nil
        b:SetAttribute("element",bar.kind=="totem" and i<=4 or nil)
        b:SetAttribute("editableAction", bar.kind=="action" or (bar.kind=="totem" and i>4))
        b:SetAttribute("totemHoldSeconds",(bar.totemHoldMs or 150)/1000)
        local entry = bar.extra and bar.extra[i]
        local release = (bar.kind == "action" and i <= 12) or (entry and entry.kind == "item")
        if release then b:SetAttribute("useOnKeyDown", false) else b:SetAttribute("useOnKeyDown", nil) end
        b:SetAttribute("type1",nil)
        b:SetAttribute("spell",nil)
        b:SetAttribute("spell1",nil)
        if b.selector then
            ClearOverrideBindings(b.selector)
            b.selector:SetAttribute("held",nil)
            b.selector:SetAttribute("cancelledRelease",nil)
            b.selector:SetAttribute("latchedCarousel",nil)
            b.selector:HideCarousel()
        end
        b.slot=nil
        b.nativeKey=nil
        if bar.kind=="action" and i<=12 then
            b:SetAttribute("type","action")
            b:SetAttribute("action",(bar.page-1)*12+i)
            local native=pageCommands[bar.page]
            if native and not GetBindingKey("CLICK "..b:GetName()..":LeftButton") then
                local keys={GetBindingKey(A.NativeBarBinding("blizzard",native,i))}
                for _,key in ipairs(keys) do
                    if not claimed[key] then
                        keyCount=keyCount+1
                        frame:SetAttribute("key"..keyCount,key)
                        frame:SetAttribute("target"..keyCount,b:GetName())
                        claimed[key]=true
                        b.nativeKey=b.nativeKey or key
                    end
                end
            end
        elseif bar.kind=="action" then
            local entry=bar.extra and bar.extra[i]
            b:SetAttribute("action",nil)
            b:SetAttribute("type",entry and entry.kind)
            if entry then
                b:SetAttribute(entry.kind,entry.kind=="item" and ("item:"..entry.id) or entry.id)
            end
        elseif bar.kind=="stance" then
            local _,_,_,spell=GetShapeshiftFormInfo(i)
            b:SetAttribute("type","spell")
            b:SetAttribute("spell",spell)
        else A.ConfigureTotem(b); if i<=4 then b:SetAttribute("useOnKeyDown",false) end end
        configureTotemDismiss(b)
        b:SetShown(bar.kind~="stance" or i<=GetNumShapeshiftForms())
    end
    for i=count+1,#frame.buttons do
        frame.buttons[i]:Hide()
        frame.buttons[i]:SetAttribute("type",nil)
    end
    UnregisterStateDriver(frame,"page")
    if bar.kind=="action" then
        frame:SetAttribute("state-page",nil)
        RegisterStateDriver(frame,"page",M.driver(parent,bar))
    end
    local vis="[vehicleui][possessbar][overridebar] hide; "
    for _,v in ipairs({parent and parent.visibility or "always", bar.visibility}) do
        if v=="hidden" then vis=vis.."hide; "
        elseif v=="combat" then vis=vis.."[nocombat] hide; " end
    end
    frame:SetAttribute("keyCount",keyCount)
    UnregisterStateDriver(frame,"input")
    frame:SetAttribute("state-input",nil)
    RegisterStateDriver(frame,"input",vis:gsub("hide","off").."on")
    RegisterStateDriver(frame,"visibility",vis.."show")
end

local stockParents = {}
local stockHolder
local stockNames = {"MainActionBar","MultiBarBottomLeft","MultiBarBottomRight",
    "MultiBarRight","MultiBarLeft","MultiBar5","MultiBar6","MultiBar7"}

local function setStockBarsHidden(hidden)
    if hidden then
        if not stockHolder then
            stockHolder = CreateFrame("Frame", nil, UIParent, "SecureHandlerStateTemplate")
            stockHolder:SetAllPoints(UIParent)
            stockHolder:Hide()
            RegisterStateDriver(stockHolder, "visibility", "[vehicleui][possessbar][overridebar] show; hide")
        end
        for _, name in ipairs(stockNames) do
            local frame = _G[name]
            if frame and not stockParents[frame] then
                stockParents[frame] = frame:GetParent()
                frame:SetParent(stockHolder)
            end
        end
    else
        for frame, parent in pairs(stockParents) do
            if frame:GetParent() == stockHolder then frame:SetParent(parent) end
            stockParents[frame] = nil
        end
    end
end

local originalAlpha={}
local hiddenParent, originalParents
local function hideStockFrame(frame, hidden)
    if not frame then return end
    originalParents = originalParents or {}
    if hidden and not originalParents[frame] then
        if not hiddenParent then
            hiddenParent = CreateFrame("Frame", nil, UIParent)
            hiddenParent:Hide()
        end
        originalParents[frame] = frame:GetParent()
        frame:SetParent(hiddenParent)
    elseif not hidden and originalParents[frame] then
        if frame:GetParent() == hiddenParent then frame:SetParent(originalParents[frame]) end
        originalParents[frame] = nil
    end
end
local function hideRegion(region,hide)
    if not region then return end
    if hide and originalAlpha[region]==nil then
        originalAlpha[region]=region:GetAlpha()
        region:SetAlpha(0)
    elseif not hide and originalAlpha[region]~=nil then
        region:SetAlpha(originalAlpha[region])
        originalAlpha[region]=nil
    end
end

local function hideOwnedBar(frame)
    local model = frame.model
    frame.model = nil
    if model and A.barPreview == model then A.barPreview = nil end
    if model and A.totemCooldownPreview == model then A.totemCooldownPreview = nil end
    if A.ClearBarOutline then A.ClearBarOutline(frame) end
    for _, driver in ipairs({"input", "visibility", "page"}) do
        UnregisterStateDriver(frame, driver)
    end
    ClearOverrideBindings(frame)
    frame:SetAttribute("keyCount", 0)
    frame:Hide()
    frame.profileBadge:Hide()
    for _, button in ipairs(frame.buttons) do
        button:Hide()
        if button.selector then
            ClearOverrideBindings(button.selector)
            button.selector:SetAttribute("held", nil)
            button.selector:HideCarousel()
        end
        button.model, button.slot, button.nativeKey = nil, nil, nil
        for _, attribute in ipairs({"type", "type1", "action", "element", "editableAction"}) do
            button:SetAttribute(attribute, nil)
        end
    end
end

local function isSpellOnOwnedBar(spellID)
    if not spellID then return false end
    for _, frame in pairs(runtime) do
        local bar = frame.model
        if bar and (bar.kind == "action" or bar.kind == "totem") then
            local first = bar.kind == "totem" and 1 or 13
            for index = first, frame:GetAttribute("count") do
                if bar.kind == "totem" and frame.buttons[index].spellId == spellID then return true end
                local entry = bar.extra and bar.extra[index]
                if entry and entry.kind == "spell" and entry.id == spellID then return true end
            end
        end
    end
    return false
end

local hookedSpellBookItems = setmetatable({}, {__mode = "k"})
local function updateSpellBookHighlight(item)
    local info = item.spellBookItemInfo
    if info and item.spellBank == Enum.SpellBookSpellBank.Player and info.itemType == Enum.SpellBookItemType.Spell
        and isSpellOnOwnedBar(info.spellID or info.actionID) then
        item.Button.ActionBarHighlight.Anim:Stop()
    end
end

function A.RefreshOwnedSpellBook()
    local book = PlayerSpellsFrame and PlayerSpellsFrame.SpellBookFrame
    if not book or not book.ForEachDisplayedSpell or not book:IsVisible() then return end
    book:ForEachDisplayedSpell(function(item)
        local button = item.Button
        local highlight = button and button.ActionBarHighlight
        if not item.UpdateActionBarAnim or not (highlight and highlight.Anim) then return end
        if not hookedSpellBookItems[item] then
            hooksecurefunc(item, "UpdateActionBarAnim", updateSpellBookHighlight)
            hookedSpellBookItems[item] = true
        end
        item:UpdateActionBarAnim()
    end)
end

if EventRegistry then
    EventRegistry:RegisterCallback("PlayerSpellsFrame.SpellBookFrame.DisplayedSpellsChanged", A.RefreshOwnedSpellBook, A)
    EventRegistry:RegisterCallback("PlayerSpellsFrame.SpellBookFrame.Show", A.RefreshOwnedSpellBook, A)
end

function A.DeleteOwnedBars(bars)
    if InCombatLockdown() then return 0 end
    local removed, changed = 0, false
    for _, bar in ipairs(bars) do
        if M.remove(bar) then
            removed = removed + 1
            local frame = runtime[bar.id]
            if frame and frame.model == bar then hideOwnedBar(frame) end
            for slot = 1, 36 do
                local command = A.NativeBarBinding("owned", bar.id, slot)
                local context = C_KeyBindings and C_KeyBindings.GetBindingContextForAction
                    and C_KeyBindings.GetBindingContextForAction(command)
                for _, key in ipairs({GetBindingKey(command, nil, context)}) do
                    if GetBindingAction(key, false, context) == command and SetBinding(key, nil, context) then
                        changed = true
                    end
                end
            end
        end
    end
    if changed then SaveBindings(GetCurrentBindingSet()) end
    if removed > 0 then A.RefreshOwnedSpellBook() end
    return removed
end

function A.RebuildBars()
    if InCombatLockdown() then return end
    local state=M.init(KeyLayersCharLayout)
    M.recoverOrphanBars(KeyLayersCharLayout, state)
    local owned=M.mode(state)=="KeyLayers"
    setStockBarsHidden(owned and state.hideBlizzard~=false and not M.available())
    local main=MainActionBar
    if main then
        hideRegion(main.BorderArt,state.hideBlizzardArt)
        hideRegion(main.EndCaps,state.hideBlizzardArt)
    end
    hideStockFrame(BagsBar, state.hideBlizzardBags)
    hideStockFrame(MultiCastActionBarFrame, state.hideBlizzardTotems)
    hideStockFrame(TotemFrame or (PlayerFrame and PlayerFrame.TotemFrame), state.hideBlizzardActiveTotems)
    local claimed={}
    for id=1,12 do
        local bar=owned and state.bars[id]
        local f=runtime[id]
        local _,class=UnitClass("player")
        if bar and (bar.kind~="totem" or class=="SHAMAN") then
            configure(bar,f or makeBar(id),claimed)
        elseif f and f.model then
            hideOwnedBar(f)
        end
    end
    A.SyncTotemProfileControls(runtime)
    A.RefreshOwnedSpellBook()
    A.InvalidateGameplayHotkeys()
end

local function bindingSignature()
    local state=KeyLayersCharLayout and KeyLayersCharLayout.barWorkspace
    if not state or M.mode(state)~="KeyLayers" then return "" end
    local keys={}
    for id=1,12 do
        local bar=state.bars[id]
        if bar and bar.kind=="action" then
            local frame = runtime[id]
            local count = frame and frame.model == bar and frame:GetAttribute("count") or bar.count
            for i=1,count do
                local own=A.NativeBarBinding("owned",id,i)
                local native=pageCommands[bar.page]
                keys[#keys+1]=table.concat({GetBindingKey(own)},":")
                if native and i<=12 then
                    keys[#keys+1]=table.concat({GetBindingKey(A.NativeBarBinding("blizzard",native,i))},":")
                end
            end
        end
    end
    return table.concat(keys,"|")
end

local events=CreateFrame("Frame")
events:RegisterEvent("PLAYER_TOTEM_UPDATE")
events:RegisterEvent("CURSOR_CHANGED")
for _, event in ipairs({"UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_FAILED_QUIET", "UNIT_SPELLCAST_SUCCEEDED"}) do
    events:RegisterUnitEvent(event, "player")
end
for _,e in ipairs({"PLAYER_ENTERING_WORLD","PLAYER_REGEN_ENABLED","UPDATE_BINDINGS","UPDATE_SHAPESHIFT_FORMS","SPELLS_CHANGED"}) do events:RegisterEvent(e) end
events:SetScript("OnEvent",function(_,event,unit,_,spellID)
    if event:match("^UNIT_SPELLCAST_") then
        local attempt = pendingTotemCast
        if attempt and GetTime() <= attempt.untilTime
            and not (issecretvalue and (issecretvalue(unit) or issecretvalue(spellID)))
            and unit == "player" and spellID == attempt.spell then
            if event ~= "UNIT_SPELLCAST_SUCCEEDED" then attempt.button:FlashPressed(true) end
            pendingTotemCast = nil
        end
        return
    end
    if event=="CURSOR_CHANGED" then
        if draggedItem then
            local kind, id = GetCursorInfo()
            if kind ~= "item" or id ~= draggedItem.entry.id then draggedItem = nil end
        end
        return
    end
    if event=="PLAYER_TOTEM_UPDATE" then
        for _,frame in pairs(runtime) do
            if frame.model and frame.model.kind=="totem" and frame:IsShown() then
                for _,b in ipairs(frame.buttons) do if b.slot then draw(b,A.barPreview==frame.model) end end
            end
        end
        return
    end
    if event=="UPDATE_BINDINGS" then
        A.SyncTotemProfileBindings()
        local signature=bindingSignature()
        if signature==events.keySignature then return end
        events.keySignature=signature
    end
    if events.pending then return end
    events.pending=true
    C_Timer.After(0,function() events.pending=nil; A.RebuildBars() end)
end)
local function drawBar(frame)
    local model = frame.model
    local parent = M.frame(model)
    local geo = parent and A.OwnedParentGeometry(parent)
    local visible = model.visibility ~= "hover" or frame:IsMouseOver()
    if visible and parent and parent.visibility == "hover" and geo then
        local x, y = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        visible = math.abs(x/scale-UIParent:GetWidth()/2-geo.x) <= geo.width/2
            and math.abs(y/scale-UIParent:GetHeight()/2-geo.y) <= geo.height/2
    end
    local style = draftBarStyles and draftBarStyles[model] or model
    local preview = A.barPreview == model
    frame:SetAlpha(preview and math.max(.65, style.alpha) or visible and style.alpha or 0)
    if frame.profileBadge:IsShown() then
        A.LayoutLabelTab(frame.profileBadge, frame, A.TotemProfiles().active,
            {hintSide=model.profileAnchor, font=model.profileFont or "game", size=model.profileFontSize or 12})
    end
    for _, button in ipairs(frame.buttons) do
        if button.pressedUntil and GetTime() >= button.pressedUntil then
            button.pressed:Hide()
            button.pressedUntil = nil
        end
        if button:IsShown() then draw(button, preview) end
    end
end

function A.SetDraftBarStyles(styles)
    if styles == draftBarStyles then return end
    local previous = draftBarStyles
    draftBarStyles = styles
    for _, frame in pairs(runtime) do
        local model = frame.model
        if model and ((previous and previous[model]) or (styles and styles[model])) and frame:IsShown() then
            drawBar(frame)
        end
    end
end

local elapsed=0
events:SetScript("OnUpdate",function(_,dt)
    elapsed=elapsed+dt
    if elapsed<.08 then return end
    elapsed=0
    A.UpdateOwnedFramePositions()
    for _, frame in pairs(runtime) do
        if frame.model and frame:IsShown() then drawBar(frame) end
    end
end)

function A.PlaceOwnedBar(frame,x,y)
    frame:ClearAllPoints()
    local scale=frame.layoutScale or frame.model.scale
    frame:SetPoint("CENTER",UIParent,"CENTER",x/scale,y/scale)
    frame.placedX,frame.placedY=x,y
end

function A.UpdateOwnedFramePositions()
    if InCombatLockdown() then return end
    for _,frame in pairs(runtime) do
        local bar=frame.model
        local parent=bar and not bar.dragging and M.frame(bar)
        local geometry=parent and A.OwnedParentGeometry(parent)
        if geometry then
            local columns,rows,scale,count=M.barGrid(bar,geometry)
            local x,y=M.barCenter(bar,geometry,columns,rows,scale)
            if count~=frame:GetAttribute("count") then
                A.RebuildBars()
                return
            end
            local resized=columns~=frame.layoutColumns or rows~=frame.layoutRows or scale~=frame.layoutScale
            if resized then
                frame.layoutColumns,frame.layoutRows,frame.layoutScale=columns,rows,scale
                frame:SetScale(scale)
                frame:SetSize(36*columns+bar.gap*(columns-1),36*rows+bar.gap*(rows-1))
                for i=1,count do
                    local button=frame.buttons[i]
                    if button then
                        local n=M.slotPosition(bar,i,count)
                        button:ClearAllPoints()
                        button:SetPoint("TOPLEFT",(n%columns)*(36+bar.gap),-math.floor(n/columns)*(36+bar.gap))
                    end
                end
            end
            if resized or frame.placedX~=x or frame.placedY~=y then A.PlaceOwnedBar(frame,x,y) end
        end
    end
end

