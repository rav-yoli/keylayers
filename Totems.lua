local addonName, A = ...
local tr=A.Translate
-- Blizzard uses Fire=1, Earth=2, Water=3, Air=4 on the multicast bar.
local elements={EARTH_TOTEM_SLOT or 2,FIRE_TOTEM_SLOT or 1,WATER_TOTEM_SLOT or 3,AIR_TOTEM_SLOT or 4}
local labels={tr("Terre","Earth"),tr("Feu","Fire"),
    tr("Eau","Water"),tr("Air","Air")}
local function profiles()
    KeyLayersTotemProfiles=KeyLayersTotemProfiles or {active="Solo",sets={Solo={}}}
    return KeyLayersTotemProfiles
end
A.TotemProfiles=profiles
local function spellName(id)
    return id and ((C_Spell and C_Spell.GetSpellName(id)) or (GetSpellInfo and GetSpellInfo(id)))
end
local function texture(id)
    return id and ((C_Spell and C_Spell.GetSpellTexture(id)) or (GetSpellTexture and GetSpellTexture(id)))
end
local function learned(id)
    if not id then return false end
    if C_SpellBook and C_SpellBook.IsSpellInSpellBook then
        return C_SpellBook.IsSpellInSpellBook(id,Enum.SpellBookSpellBank.Player,false)
    end
    return IsSpellKnown and IsSpellKnown(id)
end
-- Store the spell name (cast without a rank) and refresh the ID for icon/tooltip.
local function choices(slot)
    local result,seen={},{}
    if GetMultiCastTotemSpells then
        for _,id in ipairs({GetMultiCastTotemSpells(slot)}) do
            local name=spellName(id)
            if name and not seen[name] then result[#result+1]=name; seen[name]=id end
            if name and id>seen[name] then seen[name]=id end
        end
    end
    return result,seen
end

local function syncNativeTotemCall(runtime)
    if InCombatLockdown() or not SetMultiCastSpell then return end
    local call = TOTEM_MULTI_CAST_SUMMON_SPELLS and TOTEM_MULTI_CAST_SUMMON_SPELLS[1]
    if not learned(call) then return end
    local getBar = C_ActionBar and C_ActionBar.GetMultiCastBarIndex or GetMultiCastBarIndex
    local getAction = GetActionInfo or (C_ActionBar and C_ActionBar.GetActionInfo)
    if not getAction then return end
    local page = getBar and getBar()
    local offset = page and page > 0 and (page - 1) * (NUM_ACTIONBAR_BUTTONS or 12) or 132
    for barID = 1, 12 do
        local frame = runtime[barID]
        if frame and frame.model and frame.model.kind == "totem" then
            for index, slot in ipairs(elements) do
                local nextSpell = frame.buttons[index].spellId or 0
                local _, currentSpell = getAction(offset + slot)
                if not (issecretvalue and issecretvalue(currentSpell)) and nextSpell ~= (currentSpell or 0) then
                    SetMultiCastSpell(offset + slot, nextSpell)
                end
            end
            return
        end
    end
end

function A.SelectTotemProfile(name,create)
    if InCombatLockdown() then return false end
    local p=profiles()
    if not name or name:match("^%s*$") then return false end
    if not p.sets[name] and create then p.sets[name]=A.Copy(p.sets[p.active]) end
    if not p.sets[name] then return false end
    p.active=name
    A.RebuildBars()
    return true
end
function KeyLayersStepTotemProfile(delta)
    if InCombatLockdown() then UIErrorsFrame:AddMessage(ERR_NOT_IN_COMBAT or "Combat"); return end
    local p=profiles()
    local names={}
    for name in pairs(p.sets) do names[#names+1]=name end
    table.sort(names)
    for i,name in ipairs(names) do
        if name==p.active then A.SelectTotemProfile(names[(i-1+delta)%#names+1]); break end
    end
end

-- Key bindings stay in their existing WoW slots. Route the assigned keys
-- through a secure button while there is a KeyLayers totem bar.
local profileControl = CreateFrame("Button", "KeyLayersTotemProfileSwitch", UIParent, "SecureHandlerClickTemplate")
profileControl:SetSize(1, 1)
profileControl:EnableMouse(false)
profileControl:RegisterForClicks("AnyDown", "AnyUp")
profileControl:SetAttribute("_onclick", [[
    if button ~= "Next" and button ~= "Previous" then return end
    -- Override bindings can send only the press. When both edges arrive, step once.
    local latch = "pressed" .. button
    if down then
        self:SetAttribute(latch, true)
    elseif self:GetAttribute(latch) then
        self:SetAttribute(latch, nil)
        return
    end
    self:RunAttribute("stepProfile", button == "Next" and 1 or -1)
]])
profileControl:SetAttribute("stepProfile", [[
    local offset = ...
    local count = self:GetAttribute("profileCount") or 0
    if count < 2 then return end
    local index = (self:GetAttribute("profileIndex") - 1 + offset) % count + 1
    self:SetAttribute("profileIndex", index)
    for i = 1, self:GetAttribute("selectorCount") do
        local selector = self:GetFrameRef("selector" .. i)
        selector:RunAttribute("cancel")
        local totem = selector:GetFrameRef("button")
        local choice = self:GetAttribute("profileChoice" .. index .. ":" .. totem:GetAttribute("elementIndex"))
        totem:SetAttribute("choiceIndex", choice or 0)
        totem:SetAttribute("spell", choice and totem:GetAttribute("choice" .. choice) or nil)
        totem:CallMethod("SyncTotemChoice", choice or 0)
    end
    self:CallMethod("ShowProfile", self:GetAttribute("profileName" .. index))
]])
profileControl:SetAttribute("beginCarousel", [[
    local index = ...
    local previous = self:GetAttribute("carouselOwner")
    if previous and previous ~= index then
        self:GetFrameRef("selector" .. previous):RunAttribute("cancel")
    end
    self:SetAttribute("carouselOwner", index)
]])
profileControl:SetAttribute("rememberChoice", [[
    local element, choice = ...
    self:SetAttribute("profileChoice" .. self:GetAttribute("profileIndex") .. ":" .. element, choice)
    for i = 1, self:GetAttribute("selectorCount") do
        local totem = self:GetFrameRef("selector" .. i):GetFrameRef("button")
        if totem:GetAttribute("elementIndex") == element then
            totem:SetAttribute("choiceIndex", choice)
            totem:SetAttribute("spell", totem:GetAttribute("choice" .. choice))
            totem:CallMethod("SyncTotemChoice", choice)
        end
    end
]])
function profileControl:ShowProfile(name)
    profiles().active = name
    syncNativeTotemCall(A.ownedBars)
end
function A.SyncTotemProfileControls(runtime)
    if InCombatLockdown() then return end
    local p, names, byElement = profiles(), {}, {}
    local selectors = 0
    for id = 1, 12 do
        local bar = runtime[id]
        if bar and bar.model and bar.model.kind == "totem" then
            for element = 1, 4 do
                local totem = bar.buttons[element]
                if totem and totem.selector and totem.slot then
                    selectors = selectors + 1
                    profileControl:SetFrameRef("selector" .. selectors, totem.selector)
                    totem.selector:SetFrameRef("profileControl", profileControl)
                    totem.selector:SetAttribute("selectorIndex", selectors)
                    byElement[element] = totem
                end
            end
        end
    end
    for name in pairs(p.sets) do names[#names+1] = name end
    table.sort(names)
    profileControl:SetAttribute("selectorCount", selectors)
    profileControl:SetAttribute("carouselOwner", nil)
    profileControl:SetAttribute("profileCount", selectors > 0 and #names or 0)
    for index, name in ipairs(names) do
        if name == p.active then profileControl:SetAttribute("profileIndex", index) end
        profileControl:SetAttribute("profileName" .. index, name)
        for element, totem in pairs(byElement) do
            local wanted = spellName(p.sets[name][element])
            local choice = totem.choices[1] and 1 or nil
            for i, candidate in ipairs(totem.choices) do
                if wanted == candidate then choice = i; break end
            end
            profileControl:SetAttribute("profileChoice" .. index .. ":" .. element, choice)
        end
    end
    syncNativeTotemCall(runtime)
    A.SyncTotemProfileBindings()
end

local profileBindingSignature
function A.SyncTotemProfileBindings()
    if InCombatLockdown() or not SetOverrideBindingClick then return end
    local nextKeys, previousKeys = {}, {}
    if (profileControl:GetAttribute("profileCount") or 0) >= 2 then
        local function keys(command)
            local context = C_KeyBindings and C_KeyBindings.GetBindingContextForAction
                and C_KeyBindings.GetBindingContextForAction(command)
            return {GetBindingKey(command, nil, context)}
        end
        nextKeys = keys("KEYLAYERSTOTEMNEXT")
        previousKeys = keys("KEYLAYERSTOTEMPREV")
    end
    local signature = table.concat(nextKeys, ":") .. ";" .. table.concat(previousKeys, ":")
    if signature == profileBindingSignature then return end
    profileBindingSignature = signature
    ClearOverrideBindings(profileControl)
    for _, key in ipairs(nextKeys) do
        SetOverrideBindingClick(profileControl, true, key, profileControl:GetName(), "Next")
    end
    for _, key in ipairs(previousKeys) do
        SetOverrideBindingClick(profileControl, true, key, profileControl:GetName(), "Previous")
    end
end

local activeOwner
local holdWatcher = CreateFrame("Frame")
holdWatcher:RegisterEvent("GLOBAL_MOUSE_UP")
holdWatcher:RegisterEvent("PLAYER_REGEN_DISABLED")
holdWatcher:RegisterEvent("PLAYER_ENTERING_WORLD")
holdWatcher:SetScript("OnEvent", function(_, event, button)
    local owner = activeOwner
    if not owner then return end
    if event ~= "GLOBAL_MOUSE_UP" then
        owner:CancelHold()
    elseif button == "LeftButton" and owner.releaseMouse then
        local release = owner.releaseMouse
        if C_Timer then C_Timer.After(0, release) else release() end
    end
end)
holdWatcher:SetScript("OnUpdate", function()
    local owner = activeOwner
    if not owner then return end
    if GetTime() >= owner.holdDeadline then
        owner:CancelHold()
    elseif owner.releaseMouse and not IsMouseButtonDown("LeftButton") then
        owner.releaseMouse()
    end
end)

A.TotemClickBody = [[
    local totem = owner:GetFrameRef("button")
    if not totem:IsVisible() then return false end
    local combat = owner:GetAttribute("state-combat") == "on"
    if SecureCmdOptionParse then combat = SecureCmdOptionParse("[combat] on; off") == "on" end
    if button == "RightButton" then
        if not down then
            if combat then
                if owner:GetAttribute("held") and not owner:GetFrameRef("mouseReleased"):IsShown() then
                    owner:RunAttribute("cancel")
                else
                    owner:RunAttribute("open", true)
                end
            else
                totem:CallMethod("Choose")
            end
        end
        return false
    end
    if button == "MiddleButton" and combat then
        local profile = owner:GetFrameRef("profileControl")
        if profile and not down then profile:RunAttribute("stepProfile", IsShiftKeyDown() and -1 or 1) end
        return false
    end
    if button ~= "LeftButton" then return false end

    target:SetAttribute("type1", nil)
    if down then
        totem:CallMethod("FlashPressed")
        if owner:GetFrameRef("mouseReleased"):IsShown() then owner:RunAttribute("stop") end
        if owner:GetAttribute("held") then return false end
        owner:RunAttribute("open", false)
    else
        if owner:GetAttribute("latchedCarousel") then
            owner:RunAttribute("stop")
            return false
        end
        if not owner:GetAttribute("cancelledRelease")
            and not (owner:GetAttribute("held") and owner:GetAttribute("scrolled"))
            and not owner:GetFrameRef("elapsed"):IsShown() and not owner:GetFrameRef("mouseReleased"):IsShown() then
            local spell = totem:GetAttribute("spell")
            totem:CallMethod("FlashPressed", not spell, true)
            if spell then
                if target ~= totem then target:SetAttribute("spell", spell) end
                local index = totem:GetAttribute("choiceIndex")
                target:SetAttribute("spell1", index and totem:GetAttribute("choiceSpellID" .. index))
                target:SetAttribute("type1", "spell")
            end
        end
        owner:SetAttribute("cancelledRelease", nil)
        owner:RunAttribute("stop")
    end
]]

local function prepareCapture(b)
    local owner=CreateFrame("Frame",nil,b,"SecureHandlerStateTemplate")
    owner:SetAttribute("_onstate-combat", [[
        if newstate == "on" then
            self:SetAttribute("cancelledRelease", self:GetAttribute("held"))
            self:RunAttribute("stop")
        else
            self:SetAttribute("cancelledRelease", nil)
        end
    ]])
    owner:SetAttribute("stop", [[
        self:ClearBindings()
        self:SetAttribute("held", nil)
        self:SetAttribute("latchedCarousel", nil)
        self:CallMethod("HideCarousel")
    ]])
    for i, prefix in ipairs({"", "SHIFT-", "CTRL-", "CTRL-SHIFT-", "ALT-", "ALT-SHIFT-", "ALT-CTRL-", "ALT-CTRL-SHIFT-"}) do
        owner:SetAttribute("wheelPrefix" .. (i - 1), prefix)
    end
    owner:SetAttribute("open", [[
        local latched = ...
        local profile = self:GetFrameRef("profileControl")
        if profile then profile:RunAttribute("beginCarousel", self:GetAttribute("selectorIndex")) end
        self:SetAttribute("cancelledRelease", nil)
        self:SetAttribute("scrolled", false)
        self:SetAttribute("held", true)
        self:SetAttribute("latchedCarousel", latched)
        local wheel = self:GetAttribute("wheel")
        self:SetBindingClick(true, "ESCAPE", wheel, "MiddleButton")
        -- Keep scrolling available if the activation modifier changes mid-hold.
        for i = 0, 7 do
            local prefix = self:GetAttribute("wheelPrefix" .. i)
            self:SetBindingClick(true, prefix .. "MOUSEWHEELUP", wheel, "LeftButton")
            self:SetBindingClick(true, prefix .. "MOUSEWHEELDOWN", wheel, "RightButton")
        end
        self:CallMethod("StartHold", latched)
    ]])
    owner:SetAttribute("cancel", [[
        if self:GetAttribute("held") then self:SetAttribute("cancelledRelease", true) end
        self:RunAttribute("stop")
    ]])
    local elapsedSignal=CreateFrame("Frame",nil,UIParent)
    elapsedSignal:Hide()
    owner:SetFrameRef("elapsed",elapsedSignal)
    local mouseReleased=CreateFrame("Frame",nil,UIParent)
    mouseReleased:Hide()
    owner:SetFrameRef("mouseReleased",mouseReleased)
    local generation=0
    function owner:HideCarousel()
        generation=generation+1
        if activeOwner == self then activeOwner = nil end
        self.releaseMouse=nil
        mouseReleased:Hide()
        elapsedSignal:Hide()
        if b.carousel then b.carousel:Hide() end
    end
    function owner:CancelHold(allowTap)
        local cancelled = not allowTap or elapsedSignal:IsShown() or self:GetAttribute("scrolled")
        self:HideCarousel()
        if cancelled then mouseReleased:Show() end
        if not InCombatLockdown() then
            ClearOverrideBindings(self)
            self:SetAttribute("held", nil)
        end
    end
    function owner:StartHold(latched)
        self:HideCarousel()
        if activeOwner then activeOwner:CancelHold() end
        activeOwner = self
        self.holdDeadline = GetTime() + 10
        local token = generation
        local threshold = b:GetAttribute("totemHoldSeconds") or .15
        if latched then
            elapsedSignal:Show()
            b:ShowCarousel()
            return
        end
        if IsMouseButtonDown and IsMouseButtonDown("LeftButton") then
            self.releaseMouse = function()
                if token == generation then self:CancelHold(true) end
            end
        end
        if C_Timer then
            C_Timer.After(threshold, function()
                if token ~= generation then return end
                if not b:IsVisible() then
                    self:CancelHold()
                    return
                end
                if self.releaseMouse and not IsMouseButtonDown("LeftButton") then
                    self:CancelHold(true)
                    return
                end
                elapsedSignal:Show()
                b:ShowCarousel()
            end)
        end
    end
    RegisterStateDriver(owner,"combat","[combat] on; off")
    b.selector=owner
    owner:SetFrameRef("button",b)
    local wheel=CreateFrame("Button",b:GetName().."Wheel",owner,"SecureHandlerClickTemplate")
    wheel:RegisterForClicks("AnyDown")
    wheel:SetAttribute("_onclick",[[
        local owner=self:GetParent()
        if button=="MiddleButton" or owner:GetFrameRef("mouseReleased"):IsShown() then
            owner:RunAttribute("cancel")
            return
        end
        if owner:GetAttribute("held") then
            owner:SetAttribute("scrolled",true)
            if not owner:GetFrameRef("elapsed"):IsShown() then return end
            local b=owner:GetFrameRef("button")
            local count=b:GetAttribute("choiceCount")
            if count>0 then
                local ix=(b:GetAttribute("choiceIndex")-1+(button=="RightButton" and -1 or 1))%count+1
                local profiles = owner:GetFrameRef("profileControl")
                if profiles then
                    profiles:RunAttribute("rememberChoice", b:GetAttribute("elementIndex"), ix)
                else
                    b:SetAttribute("choiceIndex",ix)
                    b:SetAttribute("spell",b:GetAttribute("choice"..ix))
                end
                b:CallMethod("RememberChoice",ix)
            end
        end
    ]])
    owner:SetAttribute("wheel",wheel:GetName())
    owner:WrapScript(b,"OnClick",[[
        if not self:GetAttribute("element") then return end
        local target, owner = self, control
    ]] .. A.TotemClickBody)
    owner:WrapScript(b,"OnHide",[[control:RunAttribute("cancel")]])
    b:SetAttribute("useOnKeyDown",false)
    function b:ShowCarousel()
        if not self:IsVisible() then return end
        local count=#self.choices
        if count<2 then return end
        if not self.carousel then
            self.carousel=CreateFrame("Frame",nil,UIParent)
            self.carousel:SetFrameStrata("TOOLTIP")
            self.carousel:EnableMouse(false)
            self.carouselRows={}
        end
        local x,y=self:GetCenter()
        local scale=1
        if x and y then
            scale=self:GetEffectiveScale()/UIParent:GetEffectiveScale()
            x,y=x*scale,y*scale
        else x,y=UIParent:GetWidth()/2,UIParent:GetHeight()/2 end
        local size=36*scale
        local spacing=(36+(self.model.gap or 0))*scale
        local above=math.max(0,math.floor((UIParent:GetHeight()-y-size/2)/spacing))
        local below=math.max(0,math.floor((y-size/2)/spacing))
        local takeAbove=math.min(above,math.ceil((count-1)/2))
        local takeBelow=math.min(below,count-1-takeAbove)
        takeAbove=math.min(above,count-1-takeBelow)
        local current=math.max(1,self:GetAttribute("choiceIndex"))
        local shape=self.model.shape or "square"
        local mask=shape=="round" and [[Interface\CharacterFrame\TempPortraitAlphaMask]]
            or shape=="rounded" and ([[Interface\AddOns\]]..addonName..[[\Media\RoundedButton.tga]])
        local used=0
        for offset=-takeBelow,takeAbove do
            used=used+1
            local row=self.carouselRows[used]
            if not row then
                row=CreateFrame("Frame",nil,self.carousel,"BackdropTemplate")
                row:SetBackdrop({bgFile=[[Interface\Buttons\WHITE8X8]],edgeFile=[[Interface\Buttons\WHITE8X8]],edgeSize=1})
                row.icon=row:CreateTexture(nil,"ARTWORK")
                row.icon:SetAllPoints()
                row.icon:SetTexCoord(.055,.945,.055,.945)
                row.mask=row:CreateMaskTexture()
                row.mask:SetAllPoints()
                self.carouselRows[used]=row
            end
            if row.masked~=mask then
                if row.masked then row.icon:RemoveMaskTexture(row.mask) end
                if mask then
                    row.mask:SetTexture(mask,"CLAMPTOBLACKADDITIVE","CLAMPTOBLACKADDITIVE")
                    row.icon:AddMaskTexture(row.mask)
                end
                row.masked=mask
            end
            local name=self.choices[(current+offset-1)%count+1]
            row.icon:SetTexture(texture(self.ids[name]))
            row.icon:SetAlpha(.8)
            row.icon:SetShown(offset ~= 0)
            row:SetBackdropColor(.05, .08, .12, offset == 0 and 0 or .94)
            row:SetBackdropBorderColor(offset==0 and .29 or .34,offset==0 and .84 or .44,offset==0 and 1 or .5,1)
            row:SetSize(size,size)
            row:ClearAllPoints()
            row:SetPoint("CENTER",UIParent,"BOTTOMLEFT",x,y+offset*spacing)
            row:Show()
        end
        for i=used+1,#self.carouselRows do self.carouselRows[i]:Hide() end
        self.carousel:Show()
    end
    function b:SyncTotemChoice(index)
        local id = self.ids[self.choices[index]]
        if self.spellId == id then return end
        self.spellId = id
        if self.carousel and self.carousel:IsShown() then self:ShowCarousel() end
        A.RefreshOwnedSpellBook()
    end
    function b:RememberChoice(index)
        self:SyncTotemChoice(index)
        local p=profiles()
        p.sets[p.active][self.index]=self.spellId
        syncNativeTotemCall(A.ownedBars)
    end
    function b:SetChoice(name)
        if InCombatLockdown() then return end
        for i,candidate in ipairs(self.choices) do
            if candidate==name then
                self:SetAttribute("choiceIndex",i)
                self:SetAttribute("spell",name)
                self:RememberChoice(i)
                A.SyncTotemProfileControls(A.ownedBars)
                return
            end
        end
    end
    function b:Choose()
        if not InCombatLockdown() and MenuUtil then
            MenuUtil.CreateContextMenu(self,function(_,root)
                for _,name in ipairs(self.choices) do
                    root:CreateRadio(name,function() return self:GetAttribute("spell")==name end,function() self:SetChoice(name) end)
                end
            end)
        end
    end
end

function A.ConfigureTotem(b)
    local i=b.index
    if i<=4 then
        if not b.selector then prepareCapture(b) end
        b.slot=elements[i]
        b:SetAttribute("elementIndex", i)
        b.choices,b.ids=choices(b.slot)
        local p=profiles()
        for _,set in pairs(p.sets) do
            local name=spellName(set[i])
            if name and b.ids[name] then set[i]=b.ids[name] end
        end
        local chosen=spellName(p.sets[p.active][i])
        if not b.ids[chosen] and b.choices[1] then chosen=b.choices[1]; p.sets[p.active][i]=b.ids[chosen] end
        b:SetAttribute("choiceCount",#b.choices)
        b:SetAttribute("choiceIndex",0)
        for j,name in ipairs(b.choices) do
            b:SetAttribute("choice"..j,name)
            b:SetAttribute("choiceSpellID"..j,b.ids[name])
            if name==chosen then b:SetAttribute("choiceIndex",j) end
        end
        b.spellId=chosen and b.ids[chosen]
        b:SetAttribute("spell",b.spellId and chosen or nil)
        b:SetAttribute("type",nil)
    else
        local extra=b.model.extra and b.model.extra[i]
        local ids=i==5 and TOTEM_MULTI_CAST_SUMMON_SPELLS or i==6 and TOTEM_MULTI_CAST_RECALL_SPELLS
        local default=extra==nil and ids and learned(ids[1]) and ids[1] or nil
        b.spellId=extra and extra.kind=="spell" and extra.id or default
        b:SetAttribute("type",extra and extra.kind or default and "spell" or nil)
        if extra then
            b:SetAttribute(extra.kind,extra.kind=="item" and ("item:"..extra.id) or extra.id)
        else b:SetAttribute("spell",default) end
    end
end

local function active(b)
    if b.slot and GetTotemInfo then
        local placed,name,start,duration=GetTotemInfo(b.slot)
        if issecretvalue and (issecretvalue(placed) or issecretvalue(name) or issecretvalue(start) or issecretvalue(duration)) then
            return nil, nil, nil, GetTotemDuration and GetTotemDuration(b.slot)
        end
        if placed and name and name~="" and (not duration or duration>0) then return name,start,duration end
    end
end
function A.FormatRemaining(seconds)
    if seconds >= 60 then return math.ceil(seconds / 60) .. "m" end
    return tostring(math.ceil(seconds))
end

function A.TotemVisual(b)
    local start,duration
    if b.spellId and C_Spell and C_Spell.GetSpellCooldown then
        local cd=C_Spell.GetSpellCooldown(b.spellId)
        if cd then start,duration=cd.startTime,cd.duration end
    end
    local name,s,d,durationObject=active(b)
    local remaining=s and d and d>0 and s+d-GetTime()
    local text=remaining and remaining>0 and ("|cff66ff88"..A.FormatRemaining(remaining).."|r") or nil
    local extra=b.index>4 and b.model.extra and b.model.extra[b.index]
    return (extra and extra.texture) or texture(b.spellId),start,duration,text,s,d,durationObject
end
function A.TotemTooltip(b)
    GameTooltip:SetText(spellName(b.spellId) or labels[b.index] or b.model.name)
    GameTooltip:AddLine(profiles().active)
    local name=active(b)
    if name then GameTooltip:AddLine(name,.4,1,.5) end
    if b.slot then
        if InCombatLockdown() then
            GameTooltip:AddLine(tr("Maintenir ou clic droit : ouvrir le carrousel · Molette : choisir",
                "Hold or right-click: open carousel · Scroll: choose"))
            GameTooltip:AddLine(tr("Clic molette : profil suivant · Maj + clic molette : précédent",
                "Middle-click: next profile · Shift + middle-click: previous"))
        else
            GameTooltip:AddLine(tr("Clic droit pour choisir · Maintenir et défiler","Right-click to choose · Hold and scroll"))
        end
    end
end

BINDING_NAME_KEYLAYERSTOTEMNEXT=tr("Profil de totems suivant","Next totem profile")
BINDING_NAME_KEYLAYERSTOTEMPREV=tr("Profil de totems précédent","Previous totem profile")
for id=1,12 do
    for slot=1,36 do
        _G["BINDING_NAME_CLICK KeyLayersBar"..id.."Button"..slot..":LeftButton"]=
            "KeyLayers · "..select(2,A.BarLabel("owned",id)).." · "..tr("Bouton %d","Button %d"):format(slot)
    end
end
