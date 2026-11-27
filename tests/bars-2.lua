-- Run from the repository root using Lua 5.3+.
local A={Translate=function(_,en) return en end}
unpack = table.unpack or unpack
local function loadModule(name) assert(loadfile(name..".lua"))("KeyLayers",A) end
local loadedBT,combat=false,false
function IsAddOnLoaded() return loadedBT end
function IsAltKeyDown() return false end
function IsControlKeyDown() return false end
function IsShiftKeyDown() return false end
function InCombatLockdown() return combat end
function wipe(t) for k in pairs(t) do t[k]=nil end end
function A.Copy(t)
    local copy={}
    for k,v in pairs(t) do copy[k]=type(v)=="table" and A.Copy(v) or v end
    return copy
end
function A.NewPanel(name)
    return {name=name,kind="free",x=0,y=0,width=240,height=100,padding=8,
        fill="101821",fillAlpha=.64,border="65CCFF",borderAlpha=1,thickness=4}
end
function A.BarLabel(_,id) return tostring(id),"Bar "..id end
function A.GetPanelGeometry(p) return p end
A.OwnedParentGeometry=A.GetPanelGeometry
function A.NativeBarBinding(kind,id,slot)
    if kind=="owned" then return "CLICK KeyLayersBar"..id.."Button"..slot..":LeftButton" end
    return "ACTION"..id.."."..slot
end
function A.InvalidateGameplayHotkeys() end

loadModule("BarLayout")
do
    local M = A.BarLayout
    local scope = {panels={
        {barFrameId=3, kind="owned", x=71, width=240, padding=8},
        {barFrameId=4, kind="owned", x=90, width=315, padding=12},
    }, barWorkspace={mode="KeyLayers",bars={
        {id=1, kind="action", parent=3, x=31, y=22, columns=12, gap=3, scale=1, page=1},
        {id=2, kind="totem", parent=4, x=47, gap=9, count=6},
    }}}
    local state = M.init(scope)
    local inherited, custom = state.bars[1], state.bars[2]
    local firstFrame, secondFrame = scope.panels[1], scope.panels[2]
    assert(inherited.columns == 12 and inherited.page == 1 and custom.gap == 9)
    M.setFrameDefaults(scope, nil, {width=400, padding=21})
    M.setFrameDefaults(scope, "free", {padding=27})
    assert(firstFrame.width == 400 and firstFrame.padding == 21 and firstFrame.x == 71)
    assert(secondFrame.width == 315 and secondFrame.padding == 12 and secondFrame.x == 90)
    local global = M.barTemplate(scope)
    global.columns, global.gap, global.keys, global.count = 4, 6, false, 2
    global.x = 99
    assert(inherited.columns == 4 and inherited.gap == 6 and inherited.keys == false and inherited.x == 31)
    assert(custom.count == 4 and custom.gap == 9 and custom.keys == false)
    assert(state.barDefaults.x == nil)
    local actionDefaults = M.barTemplate(scope, "action")
    actionDefaults.gap, actionDefaults.keys = 11, true
    assert(inherited.gap == 11 and inherited.keys and custom.gap == 9)
    inherited.parent = 4
    assert(inherited.gap == 11 and inherited.keys)
    inherited.gap = 17
    actionDefaults.gap = 19
    assert(inherited.gap == 17)
    M.clearBarOverrides(inherited)
    assert(inherited.gap == 19 and inherited.x == 31 and inherited.y == 22 and inherited.page == 1)
    M.clearFrameOverrides(secondFrame)
    assert(secondFrame.width == 400 and secondFrame.padding == 21 and secondFrame.x == 90)
    M.clearBarTemplate(scope, "action")
    assert(inherited.gap == 6 and inherited.keys == false)
    local newFree = M.newFrame(scope, "New free frame")
    assert(newFree.padding == 27 and newFree.width == 400)
    local typedDraft = M.frameDefaultsDraft(scope, "free")
    assert(typedDraft.width == 400 and typedDraft.padding == 27 and typedDraft.x == nil)
    M.clearFrameOverrides(typedDraft)
    assert(typedDraft.padding == 21)
    local restored = A.Copy(scope)
    M.init(restored)
    assert(restored.barWorkspace.bars[1].keys == false and restored.panels[1].padding == 21)
end
print("OK inherited frame and bar properties, local overrides, false values, coordinates and profile round trip")
do
    local model = A.BarLayout
    local owned = {kind="owned", name="Inherited"}
    local custom = {kind="owned", name="Customized", fillTexture="parchment"}
    local free = {kind="free", name="Free"}
    local layout = {panels={owned,custom,free}, frameDefaults={fillTexture="solid"},
        frameTypeDefaults={owned={fillTexture="dialog"}}}
    for _, panel in ipairs(layout.panels) do model.inheritFrame(layout,panel) end
    local draft = model.frameDefaultsDraft(layout,"owned")
    draft.fillTexture = "marble"
    local previews = model.previewFrameDefaults(layout,"owned",draft)
    assert(previews[owned].fillTexture=="marble" and previews[custom].fillTexture=="parchment" and not previews[free])
    assert(owned.fillTexture=="dialog" and layout.frameTypeDefaults.owned.fillTexture=="dialog")
    draft = model.frameDefaultsDraft(layout)
    draft.fillTexture = "marble"
    previews = model.previewFrameDefaults(layout,nil,draft)
    assert(previews[free].fillTexture=="marble" and previews[owned].fillTexture=="dialog")
end
local M=A.BarLayout
local old={kind="bars",name="1.x",bars={[4]=true},border="123456",toggleKey="F8",inactiveStyle={fill="ABCDEF"}}
KeyLayersCharLayout={panels={old},neutralKey="F7"}
local state=M.init(KeyLayersCharLayout)
assert(state.mode=="Bartender4" and M.mode(state)=="Blizzard")
loadedBT=true
assert(M.init({panels={{kind="blizzard"}}}).mode=="Blizzard")
assert(M.mode(state)=="Bartender4" and M.init(KeyLayersCharLayout)==state)
assert(KeyLayersCharLayout.panels[1]==old and old.inactiveStyle.fill=="ABCDEF" and old.toggleKey=="F8")
loadedBT=false; state.mode="KeyLayers"
local p=A.NewPanel("Druid")
p.x,p.y=60,25
table.insert(KeyLayersCharLayout.panels,p)
local one,two=M.new("action",p),M.new("action",p)
one.count,two.count,one.columns,two.columns=6,6,3,6
local plan=M.fit(p)
assert(#plan==2 and one.scale==1 and two.y<0)
for _,item in ipairs(plan) do
    local w,h=M.size(item.bar,item.scale)
    assert(w<=p.width-2*p.padding+.001)
    assert(math.abs(item.y)+h/2<=p.height/2-p.padding+.001)
    item.bar.x,item.bar.y,item.bar.scale=item.x,item.y,item.scale
end
local x,y=M.position(one)
p.x=p.x+9
assert(M.position(one)==x+9)
local beforeX,beforeY=M.position(two)
local idx=M.wrap({one,two},11,"Wrapped")
local new=KeyLayersCharLayout.panels[idx]
assert(M.frame(one)==new and #M.children(p)==0)
local xx,yy=M.position(two); assert(xx==beforeX and yy==beforeY)
M.attach(two,nil); xx,yy=M.position(two); assert(xx==beforeX and yy==beforeY and not two.parent)
M.attach(two,new)
new.formPages={[1]={[one.id]=5,[two.id]=6}}
assert(M.driver(new,one)=="[form:1] 5; 1" and M.driver(new,two)=="[form:1] 6; 2")
assert(A.AttachedActionIds(new)[one.id])
local snapshot=A.Copy(KeyLayersCharLayout)
KeyLayersCharLayout=A.Copy(snapshot)
assert(M.init(KeyLayersCharLayout).bars[one.id].parent==new.barFrameId)
state=M.init(KeyLayersCharLayout); one=state.bars[one.id]; two=state.bars[two.id]
print("OK legacy data, provider fallback, profile round trip, fit, wrap, detach and page configuration")

local function noop() end
local methods={}
local function obj(name,parent)
    return setmetatable({name=name,parent=parent,attrs={},refs={},scripts={},bindings={},drivers={},wrappers={},shown=true},
        {__index=function(_,k) return methods[k] or (k:match("^[A-Z]") and noop or nil) end})
end
local events={}
function methods:SetFrameLevel(level) self.frameLevel = level end
function methods:GetFrameLevel() return self.frameLevel or 2 end
function methods:GetStringWidth() return 80 end
function CreateFrame(_,name,parent)
    local f=obj(name,parent)
    if name then _G[name]=f end
    events[#events+1]=f; return f
end
UIParent=obj("UIParent")
function methods:SetAttribute(k,v) self.attrs[k]=v end
function methods:GetAttribute(k) return self.attrs[k] end
function methods:SetFrameRef(k,v) self.refs[k]=v end
function methods:GetFrameRef(k) return self.refs[k] end
function methods:SetScript(k,v) self.scripts[k]=v end
function methods:EnableKeyboard(enabled) self.keyboardEnabled = enabled end
function methods:EnableMouse(enabled) self.mouseEnabled = enabled end
function methods:IsMouseEnabled() return not not self.mouseEnabled end
function methods:GetName() return self.name end
function methods:GetParent() return self.parent end
function methods:WrapScript(target,k,s) target.wrappers[k]={owner=self,body=s} end
function methods:IsShown() return self.shown end
function methods:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
function methods:SetShown(v) self.shown=not not v end
function methods:Show() self.shown=true end
function methods:Hide() self.shown=false end
function methods:SetText(t) self.text=t end
function methods:SetTexture(t, ...) assert(select("#",...)==0 or select("#",...)==2); self.texture=t end
function methods:SetSwipeTexture(t, ...) assert(select("#",...)==0); self.swipe=t end
function methods:SetWidth(v) self.width=v end
function methods:SetPoint(...) self.point={...} end
function methods:SetAlpha(v) self.alpha=v end
function methods:AddMaskTexture(m) self.masked=m end
function methods:RemoveMaskTexture(m) assert(self.masked==m); self.masked=nil end
function methods:CreateTexture() return obj(nil,self) end
methods.CreateMaskTexture=methods.CreateTexture
methods.CreateLine=methods.CreateTexture
methods.CreateFontString=methods.CreateTexture
function methods:SetBindingClick(_,key,target,button) self.bindings[key]={target,button} end
function methods:ClearBindings() wipe(self.bindings) end
function methods:CallMethod(k,...) return self[k](self,...) end
local function snippet(body,env)
    return assert(load(body,"snippet","t",setmetatable(env,{__index=_G})))()
end
function methods:RunAttribute(k, ...)
    return assert(load(self.attrs[k], "secure attribute", "t", setmetatable({self=self},{__index=_G})))(...)
end
function RegisterStateDriver(f,name,text) f.drivers[name]=text; if name=="visibility" then f:Show() end end
function UnregisterStateDriver(f,name) f.drivers[name]=nil end
function ClearOverrideBindings(f) f:ClearBindings() end
function UnitClass() return "Shaman","SHAMAN" end
function GetBindingKey(c) if c=="ACTION1.1" then return "1" end end
function GetBindingText(k) return k end
function GetNumShapeshiftForms() return 2 end
function GetShapeshiftFormInfo(i) return i,false,true,300+i end
function GetShapeshiftFormCooldown() return 0,0 end
function GetTime() return 105 end
function GetActionTexture(i) return i+1000 end
function GetActionCooldown() return 100,10,1,1 end
function GetActionText() return "macro" end
local rank=1
function GetMultiCastTotemSpells(slot) if slot==2 then return 100+rank,200 end end
C_Spell={GetSpellName=function(id) return ({[101]="Earth A",[102]="Earth A",[200]="Earth B"})[id] end,
    GetSpellTexture=function(id) return id end,GetSpellCooldown=function() return {startTime=0,duration=0} end}
local placed=true
function GetTotemInfo(slot) if slot==2 then return placed,placed and "Earth A" or "",100,25 end end
loadModule("Totems")
local coreFile=assert(io.open("Core.lua"))
local coreSource=coreFile:read("*a"); coreFile:close()
local function coreSection(first,last)
    local start=assert(coreSource:find(first,1,true))
    return coreSource:sub(start,assert(coreSource:find(last,start,true))-1)
end
local labelSource=coreSection("local function rgb", "local strataOrder")
    ..coreSection("local hintAnchors", "local function newEffect")
A.borderTextures, A.fillTextures = {}, {}
assert(load("local addon=...\nlocal addonName='KeyLayers'\n"..labelSource,"label drawing","t",_G))(A)
loadModule("OwnedBars")
do
    local microSource = coreSection("local function boundsForMicroMenu", "function addon.BarActionButton")
    local updatePosition = assert(load([[
        local root = UIParent
        local unpack = table.unpack
        local function includeFrame(_, frame, scale)
            local x, y = frame:GetCenter()
            local width, height = 220, 28
            return {left = x - width / 2, right = x + width / 2,
                bottom = y - height / 2, top = y + height / 2}
        end
    ]] .. microSource .. "\nreturn updateMicroMenuPosition"))()
    local originalMenu, originalContainer = MicroMenu, MicroMenuContainer
    local oldWidth, oldHeight = methods.GetWidth, methods.GetHeight
    function methods:GetWidth() return 1000 end
    function methods:GetHeight() return 800 end
    local container = obj(nil, UIParent)
    local menu = obj(nil, container)
    MicroMenu, MicroMenuContainer = menu, container
    function container:GetCenter()
        if self.point[1] == "CENTER" then return 500 + self.point[4], 400 + self.point[5] end
        return 820, 55
    end
    function container:GetNumPoints() return 1 end
    function container:GetPoint() return table.unpack(self.point) end
    function container:GetEffectiveScale() return 1 end
    function menu:GetCenter()
        local x, y = container:GetCenter()
        return x - 10, y + 5
    end
    function menu:GetChildren() end
    container:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -6, 6)
    local original = container.point
    updatePosition({x = -200, y = 180}, 1)
    assert(container.point[1] == "CENTER" and menu.point == nil)
    local x, y = menu:GetCenter()
    assert(x == 300 and y == 580)
    local moved = container.point
    updatePosition({x = -200, y = 180}, 1)
    assert(container.point == moved)
    combat = true
    updatePosition(nil, 1)
    assert(container.point == moved)
    combat = false
    updatePosition(nil, 1)
    for i = 1, 5 do assert(container.point[i] == original[i]) end
    methods.GetWidth, methods.GetHeight = oldWidth, oldHeight
    MicroMenu, MicroMenuContainer = originalMenu, originalContainer
end
print("OK Blizzard micro-menu position, combat guard and original anchors")
local ticker=events[#events]
ticker.testHoldWatcher=events[#events-1]
local totems=M.new("totem")
local stance=M.new("stance")
one.shape="round";one.border=false
A.RebuildBars()
local f=A.ownedBars[one.id]
assert(f.buttons[1].icon.masked and f.buttons[1].nativeKey=="1")
for _,form in ipairs({true,false}) do
    for _,b in ipairs({one,two}) do
        local frame=A.ownedBars[b.id]
        local page=frame.drivers.page:match(form and "form:1%] (%d+)" or "; (%d+)$")
        snippet(frame.attrs["_onstate-page"],{self=frame,newstate=page})
        assert(frame.buttons[1].attrs.action==((form and (b==one and 5 or 6) or b.page)-1)*12+1)
    end
end
assert(f.drivers.input:match("vehicleui") and f.drivers.visibility:match("possessbar"))
local sb=A.ownedBars[stance.id];assert(sb.buttons[2].shown and not sb.buttons[3].shown)
for _,round in ipairs({true,false}) do
    for _,border in ipairs({true,false}) do
        for _,style in ipairs({"edge","veil"}) do
            one.shape=round and "round" or "square"; one.border=border;one.cooldown=style
            A.RebuildBars()
            ticker.scripts.OnUpdate(ticker,.2)
            local b=f.buttons[1]
            assert(not not b.icon.masked==round)
            assert(b.lines[1].shown==(border or style=="edge"))
            assert(b.lines[48].shown==border)
            assert(b.bands[1].shown==(style=="veil") and not b.bands[18].shown)
        end
    end
end
print("OK two-bar secure paging and base return, inherited key, class slots and eight cooldown configurations")

local elem=A.ownedBars[totems.id].buttons[1]
local owner=elem.selector
local function press(down)
    snippet(elem.wrappers.OnClick.body,{control=owner,self=elem,button="LeftButton",down=down})
end
press(true);assert(owner.bindings.MOUSEWHEELUP);press(false)
assert(elem.attrs.type1=="spell" and elem.attrs.spell=="Earth A" and not next(owner.bindings))
press(true)
local wheel=_G[owner.attrs.wheel]
owner:GetFrameRef("elapsed"):Show()
snippet(wheel.attrs._onclick,{self=wheel,button="LeftButton"})
press(false)
assert(not elem.attrs.type1 and elem.attrs.spell=="Earth B" and not next(owner.bindings))
local tex,_,_,active=A.TotemVisual(elem)
assert(tex==200 and active:match("20"))
placed=false;assert(select(4,A.TotemVisual(elem))==nil)
press(true);combat=true
snippet(owner.attrs["_onstate-combat"],{self=owner,newstate="on"})
owner:SetAttribute("state-combat","on")
press(false); assert(not next(owner.bindings) and not elem.attrs.type1)
assert(not A.SelectTotemProfile("Dungeon",true))
combat=false
owner:SetAttribute("state-combat",nil)
press(true);snippet(elem.wrappers.OnHide.body,{control=owner,self=elem})
press(false);assert(not next(owner.bindings) and not elem.attrs.type1)
elem:SetChoice("Earth A");assert(A.SelectTotemProfile("Dungeon",true))
rank=2;A.RebuildBars()
local sets=A.TotemProfiles().sets
assert(sets.Solo[1]==102 and sets.Dungeon[1]==102)
KeyLayersStepTotemProfile(1);assert(A.TotemProfiles().active=="Solo")
KeyLayersStepTotemProfile(-1);assert(A.TotemProfiles().active=="Dungeon")
state.mode="Blizzard";A.RebuildBars()
assert(not f.shown and not f.buttons[1].attrs.type)
state.mode="KeyLayers";A.RebuildBars()
assert(f.model==one and f.buttons[1].attrs.action==1)
print("OK totem tap, wheel, active totem, interruption, combat transition, profile cycling and rank upgrade")
do
    local oldBook, oldEnum, oldHook, oldTooltip = PlayerSpellsFrame, Enum, hooksecurefunc, GameTooltip
    Enum = {SpellBookSpellBank = {Player = 0, Pet = 1}, SpellBookItemType = {Spell = 1}}
    function hooksecurefunc(frame, method, callback)
        local original = frame[method]
        frame[method] = function(self) original(self); callback(self) end
    end
    local function spellBookItem(id, bank)
        local anim = {Stop = function(self) self.playing = false end}
        return {
            spellBank = bank or 0, spellBookItemInfo = {spellID = id, actionID = 102, itemType = 1},
            Button = {ActionBarHighlight = {Anim = anim}},
            UpdateActionBarAnim = function() anim.playing = true end,
            anim = anim,
        }
    end
    local extraRank, otherRank, activeTotem, pet = spellBookItem(800),
        spellBookItem(801), spellBookItem(102), spellBookItem(800, 1)
    PlayerSpellsFrame = {SpellBookFrame = {
        IsVisible = function() return true end,
        ForEachDisplayedSpell = function(_, fn)
            for _, item in ipairs({extraRank, otherRank, activeTotem, pet}) do fn(item) end
        end,
    }}
    local oldExtra, oldCount = one.extra, one.count
    one.count = 13
    one.extra = {[13] = {kind = "spell", id = 800}}
    A.RebuildBars()
    assert(not extraRank.anim.playing and otherRank.anim.playing and not activeTotem.anim.playing and pet.anim.playing)
    extraRank:UpdateActionBarAnim()
    assert(not extraRank.anim.playing)
    GameTooltip = {
        SetOwner = noop, Show = noop,
        SetSpellByID = function(_, id, isPet, showSubtext)
            assert(id == 800 and isPet == false and showSubtext == true)
        end,
    }
    f.buttons[13].scripts.OnEnter(f.buttons[13])
    local totemChoice = elem:GetAttribute("choiceIndex")
    for index, name in ipairs(elem.choices) do
        if elem.ids[name] == 200 then elem:SyncTotemChoice(index) end
    end
    assert(activeTotem.anim.playing)
    elem:SyncTotemChoice(totemChoice)
    one.extra, one.count = oldExtra, oldCount
    A.RebuildBars()
    assert(extraRank.anim.playing and not activeTotem.anim.playing)
    PlayerSpellsFrame, Enum, hooksecurefunc, GameTooltip = oldBook, oldEnum, oldHook, oldTooltip
end
print("OK extra spell rank tooltip and assigned glow for exact ranks and active totem choices")
do
    local fire = A.ownedBars[totems.id].buttons[2]
    local selector = fire.selector
    local oldParse = SecureCmdOptionParse
    fire:SetAttribute("spell", "Fire Totem")
    function SecureCmdOptionParse() return combat and "on" or "off" end
    local function fireClick(down)
        return snippet(fire.wrappers.OnClick.body,{control=selector,self=fire,button="LeftButton",down=down})
    end
    combat=true
    selector:SetAttribute("state-combat", "off")
    assert(fireClick(false)~=false and fire.attrs.type1=="spell")
    assert(not next(selector.bindings) and not selector.attrs.held)
    fireClick(true)
    assert(not fire.attrs.type1 and selector.attrs.held and selector.bindings.MOUSEWHEELUP)
    assert(fireClick(false)~=false and fire.attrs.type1=="spell")
    combat=false
    selector:SetAttribute("state-combat", "on")
    fireClick(true)
    assert(selector.bindings.MOUSEWHEELUP and selector.attrs.held)
    fireClick(false)
    assert(fire.attrs.type1=="spell" and not next(selector.bindings))
    SecureCmdOptionParse=oldParse
end
print("OK fire totem casts on combat release even without a press or a synchronized state driver")


local switchFile=assert(io.open("Switch.lua"))
local switchSource=switchFile:read("*a"); switchFile:close()
local reservedStart=assert(switchSource:find("function addon.ReservedShortcutMessage",1,true))
local reservedEnd=assert(switchSource:find("local function assignKey",reservedStart,true))
assert(load("local addon=...; local tr=addon.Translate; "..switchSource:sub(reservedStart,reservedEnd-1)))(A)
local picked,dropped
function GetCursorInfo() end
function IsShiftKeyDown() return false end
function PickupAction(slot) picked=slot end
function PlaceAction(slot) dropped=slot end
local first=f.buttons[1]
first.scripts.OnDragStart(first); first.scripts.OnReceiveDrag(first)
assert(picked==1 and dropped==1)
state.lockActions=true; picked,dropped=nil,nil
first.scripts.OnDragStart(first); first.scripts.OnReceiveDrag(first)
assert(not picked and not dropped)
function GetTime() return 200 end
one.border=false;one.cooldown="edge";A.RebuildBars()
ticker.scripts.OnUpdate(ticker,.2)
assert(not first.lines[1].shown and not first.bands[1].shown)
print("OK unlocked and locked drag/drop callbacks and expired cooldown")

-- Navigate the real bar editor controls with lightweight frame/region doubles.
function methods:SetParent(p) self.parent=p end
function methods:GetText() return self.text end
function methods:GetWidth() return self.width or 100 end
UIParent.width=1920
function methods:GetHeight() if self==UIParent then return 1080 end end
function methods:GetScale() return 1 end
function methods:GetStringWidth() return 100 end
function methods:SetupMenu(fn) self.menu=fn end
function methods:OverrideText(t) self.text=t end
A.SetHoveredPanel=noop
A.ShowBarOutline=noop
A.Refresh=noop
A.barCounts={bars=15,blizzard=8}
A.BarActionButton=function() end
A.BarSelection=function(panel) return panel.bars end
-- Preview the new paint immediately without writing to the destination bar.
local button = A.ownedBars[one.id].buttons[1]
local originalShape = one.shape
local staged = A.Copy(one)
staged.shape, staged.border, staged.borderWidth = "square", true, 4
function methods:SetStartPoint(...) self.lineStart = {...} end
function methods:SetEndPoint(...) self.lineEnd = {...} end
A.SetDraftBarStyles({[one]=staged})
assert(one.shape == originalShape and button.shape == "square")
assert(button.lines[1].parent ~= button and button.lines[1].parent == button.decor.parent)
assert(button.lines[1].lineStart[2] == button and button.lines[1].lineStart[4] == 16)
assert(button.lines[7].lineStart[3] == 16 and button.lines[7].lineStart[4] == 16)
A.SetDraftBarStyles(nil)
assert(button.shape == originalShape)
print("OK copied style renders immediately and restores on discard, with inset centered borders")

local page=CreateFrame("Frame",nil,UIParent)
local function factory(parent,text) local w=CreateFrame("Button",nil,parent); w:SetText(text); return w end
local controls={button=factory,label=factory,menu=factory,radio=noop,confirm=noop}
local ctx={editing=function() return true end,openFrame=function(i) assert(i==idx) end}
loadModule("Navigation")
loadModule("BarEditor")
local editor=A.CreateBarEditor(page,controls,ctx)
local function find(text)
    for _,w in ipairs(events) do if w.text==text and w:IsVisible() and w.scripts.OnClick then return w end end
    error("missing control "..text)
end
local function click(text) local w=find(text);w.scripts.OnClick(w,"LeftButton") end
editor.open(idx,one.id)
do
    local pencil, input
    for _, control in ipairs(events) do
        if control:GetParent()==page and control.scripts.OnEditFocusLost then input=control end
        if control:GetParent()==page and control:IsVisible() and control.point
            and control.point[3]==-24 and control.scripts.OnClick then pencil=control end
        assert(not (control:IsVisible() and control.text=="Name"))
    end
    local original = one.name
    input.ClearFocus = function(self) self.scripts.OnEditFocusLost(self) end
    pencil.scripts.OnClick(pencil)
    assert(input:IsShown() and input:GetText()==original and not pencil:IsShown())
    input:SetText("  New |title  ")
    input.scripts.OnEnterPressed(input)
    assert(one.name=="New title" and pencil:IsShown() and not input:IsShown())
    pencil.scripts.OnClick(pencil)
    input:SetText("Discarded")
    input.scripts.OnEscapePressed(input)
    assert(one.name=="New title" and pencil:IsShown() and not input:IsShown())
    one.name=original
    editor.refresh()
end
click("‹"); assert(editor.selectedFrame()==idx)
click("›")
editor.open(idx,nil)
click(one.name.." ›")
assert(A.barPreview==one)
page.scripts.OnHide()
assert(not A.barPreview)
print("OK bar selection, folded tree, parent navigation and preview cleanup")

local prompt,command
do
    local treeProbe = {}
    A.CreateWorkspaceTree=function(_, choose, _, _, toggle)
        treeProbe.choose, treeProbe.toggle = choose, toggle
        return {SetShown=noop,Update=function(_,items) treeProbe.items=items end}
    end
    local treeEditor
    local treeStart = #events
    treeEditor=A.CreateBarEditor(page,controls,{parent=UIParent,editing=ctx.editing,newFrame=function() treeProbe.created = true end,
        isGlobal=function() return treeProbe.globalActive end,
        openGlobal=function(section) treeProbe.globalRoute = section end,
        openFrame=function(index, section) treeProbe.frameRoute = {index, section} end,
        openFrameDefaults=function(kind, section) treeProbe.templateRoute = {kind, section} end,
        openBar=function(index,id,after) treeEditor.open(index,id); if after then after() end end})
    treeProbe.globalActive = true
    treeEditor.navigation(true,nil)
    assert(treeProbe.items[1].active and treeProbe.items[1].defaultCollapsed)
    for _, item in ipairs(treeProbe.items[1].children) do assert(not item.active) end
    local folders=treeProbe.items[2].children
    assert(folders[1].hoverBindings and not folders[1].active)
    local firstFrame=folders[2]
    assert(firstFrame.defaultCollapsed and not firstFrame.active)
    assert(firstFrame.children[1].section=="target" and firstFrame.children[2].section=="geometry"
        and firstFrame.children[3].section=="activation" and firstFrame.children[4].section=="appearance"
        and firstFrame.children[5].section=="frameHint")
    assert(treeProbe.items[1].globalSettings and treeProbe.items[3].barDefaults)
    local barSections = treeProbe.items[3].children
    assert(barSections[1].barSection=="layout" and barSections[2].barSection=="appearance"
        and barSections[3].barSection=="cooldown")
    treeProbe.choose(barSections[2])
    assert(treeProbe.items[3].active and treeProbe.items[3].children[2].active)
    local globalSections = treeProbe.items[1].children
    assert(#globalSections == 4 and globalSections[1].globalSection == "interface")
    assert(globalSections[2].globalSection == "buttons" and globalSections[4].globalSection == "editing")
    treeProbe.choose(globalSections[3])
    assert(treeProbe.globalRoute == "hotkeys")
    treeProbe.choose(firstFrame.children[5])
    assert(treeProbe.frameRoute[1] == firstFrame.index and treeProbe.frameRoute[2] == "frameHint")
    treeProbe.toggle()
    treeEditor.navigation(true,nil)
    assert(treeEditor.isInheritance() and treeProbe.items[2].frameDefaults and treeProbe.items[3].barDefaults)
    assert(#treeProbe.items == 3 and treeProbe.items[1].globalSettings and treeProbe.items[2].text == "Frames")
    assert(#treeProbe.items[2].children == 3 and #treeProbe.items[3].children == 2)
    assert(not treeProbe.items[2].defaultCollapsed and not treeProbe.items[3].defaultCollapsed)
    for i=2,3 do
        for _, item in ipairs(treeProbe.items[i].children) do assert(item.defaultCollapsed and not item.active) end
    end
    treeProbe.globalActive = false
    assert(treeProbe.items[2].children[2].templateKind == "owned" and treeProbe.items[3].children[2].templateKind == "totem")
    assert(treeProbe.items[2].children[2].text == "KeyLayers frame" and treeProbe.items[2].children[3].text == "Blizzard frame")
    assert(#treeProbe.items[2].children[2].children == 7)
    treeProbe.choose(treeProbe.items[2].children[2].children[5])
    assert(treeProbe.templateRoute[1] == "owned" and treeProbe.templateRoute[2] == "frameHint")
    treeProbe.choose(treeProbe.items[3])
    assert(treeProbe.items[3].active)
    treeProbe.choose(treeProbe.items[3].children[2])
    assert(treeProbe.items[3].children[2].active)
    treeProbe.choose(treeProbe.items[3].children[2].children[2])
    assert(treeProbe.items[3].children[2].children[2].active)
    treeProbe.toggle()
    treeEditor.navigation(true,nil)
    treeProbe.choose(treeProbe.items[2])
    local byName = {}
    for i=treeStart+1,#events do
        local control = events[i]
        if control:IsVisible() and control.text then byName[control.text]=control end
    end
    local addFrame, addBar = byName["New frame"], byName["New bar"]
    assert(addFrame.parent==page and addBar.parent==page and not addFrame.menu and addBar.menu)
    assert(addFrame.point[5]==addBar.point[5] and addFrame.point[4]+addFrame.width < addBar.point[4])
    addFrame.scripts.OnClick()
    assert(treeProbe.created)
    assert(not byName["Select bars"] and not byName["Frame selection"])
    local frameChoices = {}
    byName["Sections"].menu(nil,{CreateButton=function(_, label, click) frameChoices[label]=click end})
    frameChoices[KeyLayersCharLayout.panels[1].name]()
    assert(treeProbe.frameRoute[1]==1)
    treeProbe.choose(treeProbe.items[3])
    assert(treeProbe.items[3].active and not treeProbe.items[3].children[1].active)
    local createFromBars
    for i=treeStart+1,#events do
        local control=events[i]
        if control:IsVisible() and control.text=="New bar" then createFromBars=control end
    end
    assert(createFromBars and createFromBars.menu)
    local beforeHover=#events
    frameChoices["Bind by hovering"]()
    local heading
    for i=treeStart+1,#events do
        local control=events[i]
        if control:IsVisible() and control.text=="Frames" then heading=control end
    end
    assert(heading and heading.parent==page)
    assert(treeProbe.items[2].children[1].active)
    local toggle
    for i=beforeHover+1,#events do
        local control=events[i]
        if rawget(control,"SetActive") then toggle=control end
    end
    assert(toggle and toggle:IsVisible())
    toggle.scripts.OnClick()
    function IsControlKeyDown() return false end
    function IsAltKeyDown() return false end
    function IsShiftKeyDown() return false end
    function GetBindingAction() return "JUMP" end
    function SetBinding(_,c) command=c; return true end
    function GetCurrentBindingSet() return 1 end
    function SaveBindings(set) assert(set==1) end
    controls.confirm=function(_,accept) prompt=accept end
    for _,w in ipairs(events) do
        if w.scripts.OnKeyDown and w:IsVisible() then w.scripts.OnKeyDown(w,"G"); break end
    end
    assert(prompt and not command)
    prompt()
    assert(command:match("^CLICK KeyLayersBar%d+Button%d+:LeftButton$"))
    local capture
    for _, control in ipairs(events) do
        if control.scripts.OnKeyDown and control:IsVisible() and control.parent==UIParent then
            capture=control
            break
        end
    end
    assert(capture)
    capture.scripts.OnKeyDown(capture,"ESCAPE")
    assert(not capture:IsVisible())
    treeProbe.choose(treeProbe.items[2])
    assert(treeProbe.items[2].active and not treeProbe.items[2].children[1].active)
    treeProbe.choose(treeProbe.items[3])
    assert(treeProbe.items[3].active and not treeProbe.items[3].children[1].active)
    print("OK hover binding category, switch, conflict confirmation and Escape")
end

local legacyOwned=A.NewPanel("Existing KeyLayers container")
legacyOwned.barFrameId=99
local legacyBeta={panels={legacyOwned},barWorkspace={bars={{parent=99}}}}
M.init(legacyBeta)
assert(legacyOwned.kind=="owned" and M.init(legacyBeta).attachmentTypesMigrated)
local background=A.NewPanel("Background")
background.width,background.height=2000,1400
table.insert(KeyLayersCharLayout.panels,background)
KeyLayersCharLayout.panels[2].x=800
assert(M.dropTarget(new.x,new.y)==idx)
local native=CreateFrame("Frame","MainActionBar",UIParent)
function methods:SetAllPoints() end
state.hideBlizzard=true
A.RebuildBars()
local holder=native:GetParent()
assert(holder~=UIParent and holder.drivers.visibility:match("vehicleui"))
state.hideBlizzard=false
A.RebuildBars()
assert(native:GetParent()==UIParent)
one.shape="rounded"
A.RebuildBars()
assert(first.shape=="rounded" and first.icon.masked and first.base.masked)
print("OK beta1 attachment migration, smallest drop target, Blizzard reparent/restore, and rounded mask")

one.count=36
one.extra={[13]={kind="spell",id=200,texture=200}}
A.RebuildBars()
assert(f.buttons[36]:IsShown() and f.buttons[13]:GetAttribute("spell")==200)
snippet(f.attrs["_onstate-page"],{self=f,newstate="5"})
assert(f.buttons[1]:GetAttribute("action")==49)
assert(f.buttons[13]:GetAttribute("action")==nil and f.buttons[13]:GetAttribute("spell")==200)
function IsShiftKeyDown() return true end
picked=nil
first.scripts.OnDragStart(first)
assert(picked==49)
print("OK 36 slots, independent extra spell through paging, and Shift unlock")
local legacyLock={panels={},barWorkspace={bars={[2]={kind="action",locked=true,unlockModifier="CTRL"}}}}
assert(M.init(legacyLock).lockActions and M.init(legacyLock).actionEditModifier=="CTRL")
M.init(legacyLock).lockActions=false
assert(not M.init(legacyLock).lockActions)
state.actionEditModifier="CTRL"
A.RebuildBars()
local ctrlDown, cursor, clears = false, nil, 0
function IsControlKeyDown() return ctrlDown end
function GetCursorInfo() return cursor end
function PickupAction(slot) picked=slot; cursor="action" end
function ClearCursor() cursor=nil; clears=clears+1 end
local function gameplayClick(button, down)
    return snippet(button.wrappers.OnClick.body,{self=button,control=f,button="RightButton",down=down})
end
picked=nil
first.scripts.OnDragStart(first)
gameplayClick(first,false)
assert(not picked and clears==0)
ctrlDown=true
first.scripts.OnDragStart(first)
assert(picked==1 and cursor=="action")
cursor=nil
snippet(f.attrs["_onstate-page"],{self=f,newstate="5"})
assert(gameplayClick(first,true)==false and clears==0)
assert(gameplayClick(first,false)==false and picked==49 and clears==1 and not cursor)
cursor="item"; gameplayClick(first,false)
assert(cursor=="item" and clears==1)
cursor=nil
combat=true; gameplayClick(first,false); assert(clears==1)
combat=false
assert(gameplayClick(f.buttons[13],false)==false and one.extra[13]==nil)
local element=A.ownedBars[totems.id].buttons[1]
assert(not element:GetAttribute("editableAction"))
state.actionEditModifier="SHIFT"
A.RebuildBars()
print("OK global lock migration, configured modifier, safe removal from paged and extra action slots")
do
    local oldPickup = PickupAction
    local before = clears
    function PickupAction(slot) picked=slot; cursor="spell" end
    cursor=nil
    first:RemoveAction()
    assert(not cursor and clears==before+1)
    PickupAction=oldPickup
end
print("OK clear slot handles inherited native spell cursors")

do
    local shiftDown, underMouse = true, true
    function IsShiftKeyDown() return shiftDown end
    function methods:IsUnderMouse() return underMouse end
    local function leftMouse(event)
        return snippet(first.attrs[event],{self=first,button="LeftButton"})
    end
    local function leftClick(down)
        return snippet(first.wrappers.OnClick.body,{self=first,control=f,button="LeftButton",down=down})
    end
    assert(leftClick(true)~=false and leftClick(false)~=false) -- Keyboard shortcut with Maj.
    leftMouse("_onmousedown")
    assert(leftClick(true)==false)
    shiftDown=false
    leftMouse("_onmouseup")
    assert(leftClick(false)==false and not first.attrs.mouseLeftClick)
    leftMouse("_onmousedown")
    assert(leftClick(true)~=false)
    leftMouse("_onmouseup")
    assert(leftClick(false)~=false)
    shiftDown=true
    leftMouse("_onmousedown")
    assert(leftClick(true)==false)
    snippet(first.wrappers.OnDragStart.body,{self=first,control=f})
    leftMouse("_onmouseup")
    assert(leftClick(false)~=false) -- The real drag has no click up; a later keybind works.
    state.lockActions=false
    A.RebuildBars()
    leftMouse("_onmousedown")
    assert(leftClick(true)~=false)
    leftMouse("_onmouseup")
    assert(leftClick(false)~=false)
    state.lockActions=true
    A.RebuildBars()
    print("OK mouse edit clicks suppressed on press and release, with direct keybinds and dragging preserved")
end



do
    local savedCursor, savedPlace, savedClear = GetCursorInfo, PlaceAction, ClearCursor
    local savedShift, savedItem, savedPickup = IsShiftKeyDown, C_Item, PickupAction
    local cursor, count, native = nil, 17, {}
    local item, cursorId = 12345, 12345
    function GetCursorInfo() return cursor, cursor and cursorId end
    function ClearCursor() cursor=nil end
    function HasAction(slot) return native[slot]~=nil end
    function GetActionInfo(slot) if native[slot] then return "item", native[slot] end end
    function PlaceAction(slot)
        local old = native[slot]
        native[slot], cursor, cursorId = cursorId, old and "action" or nil, old
    end
    function PickupAction(slot)
        picked = slot
        if native[slot] then cursor, cursorId, native[slot] = "action", native[slot], nil end
    end
    function IsShiftKeyDown() return false end
    C_Item = {
        GetItemCount=function(id, bank, uses)
            assert(type(id)=="number" and bank==false and uses==false)
            return count
        end,
        GetItemIconByID=function() return 558 end,
        PickupItem=function(link)
            cursor, cursorId = "item", tonumber(link:match("item:(%d+)"))
        end,
    }
    local extra = f.buttons[14]
    local totemExtra = A.ownedBars[totems.id].buttons[5]
    local totemElement = A.ownedBars[totems.id].buttons[1]
    assert(state.lockActions and state.actionEditModifier=="SHIFT")
    local slot=first:GetAttribute("action")
    cursor,cursorId="item",item; first.scripts.OnReceiveDrag(first)
    assert(native[slot]==item and not cursor)
    cursor,cursorId="item",item; first.scripts.OnReceiveDrag(first)
    assert(cursor=="item") -- A locked occupied slot does not swap an existing action out.
    local lower = f.buttons[16]
    local normalCursorInfo = GetCursorInfo
    function GetCursorInfo() return cursor, 5, "spell", 131 end
    cursor="spell"; lower.scripts.OnReceiveDrag(lower)
    assert(one.extra[16].kind=="spell" and one.extra[16].id==131 and not cursor)
    assert(lower:GetAttribute("spell")==131 and lower:GetAttribute("type")=="spell")
    function GetCursorInfo() return cursor, 6, "spell", 132 end
    cursor="spell"; lower.scripts.OnReceiveDrag(lower)
    assert(one.extra[16].id==131 and cursor=="spell")
    GetCursorInfo=normalCursorInfo
    one.extra[16]=nil
    cursor,cursorId="item",item; extra.scripts.OnReceiveDrag(extra)
    assert(one.extra[14].id==item and not cursor)
    cursor,cursorId="item",item; totemElement.scripts.OnReceiveDrag(totemElement)
    assert(cursor=="item")
    totemExtra.scripts.OnReceiveDrag(totemExtra)
    assert(totems.extra[5].id==item and not cursor)
    ticker.scripts.OnUpdate(ticker,.2)
    assert(first.itemCount.text=="17" and extra.itemCount.text=="17" and totemExtra.itemCount.text=="17")
    count=0
    ticker.scripts.OnUpdate(ticker,.2)
    assert(first.itemCount.text=="0" and extra.itemCount.text=="0")
    picked=nil
    first.scripts.OnDragStart(first)
    assert(not picked)
    function IsShiftKeyDown() return true end
    first.scripts.OnDragStart(first)
    assert(cursor=="item" and cursorId==item and native[slot]==item)
    assert(first.attrs.useOnKeyDown==false and extra.attrs.useOnKeyDown==false)
    local otherNative = f.buttons[2]
    local otherSlot = otherNative:GetAttribute("action")
    native[otherSlot]=23456
    otherNative.scripts.OnReceiveDrag(otherNative)
    assert(native[slot]==23456 and native[otherSlot]==item and not cursor)
    first.scripts.OnDragStart(first)
    extra.scripts.OnReceiveDrag(extra)
    assert(native[slot]==item and one.extra[14].id==23456 and not cursor)
    extra.scripts.OnDragStart(extra)
    first.scripts.OnReceiveDrag(first)
    assert(native[slot]==23456 and one.extra[14].id==item and not cursor)
    totems.extra[5].id=34567
    extra.scripts.OnDragStart(extra)
    totemExtra.scripts.OnReceiveDrag(totemExtra)
    assert(one.extra[14].id==34567 and totems.extra[5].id==item and not cursor)
    extra.scripts.OnDragStart(extra)
    ClearCursor()
    ticker.scripts.OnEvent(ticker,"CURSOR_CHANGED")
    assert(one.extra[14].id==34567)
    local casts=8
    local oldConsumable, oldCastCount = C_Spell.IsConsumableSpell, C_Spell.GetSpellCastCount
    C_Spell.IsConsumableSpell=function(id) return id==131 end
    C_Spell.GetSpellCastCount=function() return casts end
    one.extra[14]={kind="spell",id=131}
    function GetActionInfo(index)
        if index==slot then return "spell",131 end
        if index==otherSlot then return "spell",100 end
    end
    ticker.scripts.OnUpdate(ticker,.2)
    assert(extra.itemCount.text=="8" and first.itemCount.text=="8" and otherNative.itemCount.text=="")
    casts=0
    ticker.scripts.OnUpdate(ticker,.2)
    assert(extra.itemCount.text=="0" and first.itemCount.text=="0")
    do
        local hiddenCount, rawText = {}, {}
        local oldSecret, oldDisplay, oldActionAPI = issecretvalue, C_Spell.GetSpellDisplayCount, C_ActionBar
        function issecretvalue(value) return value == hiddenCount or value == rawText end
        casts = hiddenCount
        count = 7
        combat = true
        ticker.scripts.OnUpdate(ticker,.2)
        assert(extra.itemCount.text=="7" and first.itemCount.text=="7")
        count = 0
        ticker.scripts.OnUpdate(ticker,.2)
        assert(extra.itemCount.text=="0" and first.itemCount.text=="0")
        one.extra[14]={kind="spell",id=100}
        C_Spell.IsConsumableSpell=function(id) return id==100 end
        C_Spell.GetSpellDisplayCount=function() return rawText end
        ticker.scripts.OnUpdate(ticker,.2)
        assert(extra.itemCount.text==rawText and otherNative.itemCount.text==rawText)
        C_ActionBar = {GetActionDisplayCount=function() return rawText end}
        function GetActionInfo(index) if index==slot then return hiddenCount,hiddenCount end end
        ticker.scripts.OnUpdate(ticker,.2)
        assert(first.itemCount.text==rawText)
        issecretvalue,C_Spell.GetSpellDisplayCount,C_ActionBar=oldSecret,oldDisplay,oldActionAPI
        combat = false
    end
    C_Spell.IsConsumableSpell,C_Spell.GetSpellCastCount=oldConsumable,oldCastCount
    local free = f.buttons[15]
    combat=true
    cursor="item"; free.scripts.OnReceiveDrag(free)
    assert(not one.extra[15] and cursor=="item")
    combat=false
    one.extra[14], totems.extra[5]=nil,nil
    GetCursorInfo,PlaceAction,ClearCursor=savedCursor,savedPlace,savedClear
    IsShiftKeyDown,C_Item,PickupAction=savedShift,savedItem,savedPickup
    HasAction,GetActionInfo=nil,nil
    A.RebuildBars()
    ticker.scripts.OnUpdate(ticker,.2)
    assert(first.itemCount.text=="" and extra.itemCount.text=="")
end
print("OK locked bag drops, release-only item use, four swap paths, and inventory and reagent counts")

function GetTime() return 105 end
function methods:GetAlpha() return self.alpha or 1 end
one.shape,one.cooldown,one.showCooldownText="rounded","edge",true
A.RebuildBars()
ticker.scripts.OnUpdate(ticker,.2)
assert(first.roundedCD.shown and first.cooldownText.text=="5")
assert(first.roundedCD:GetFrameLevel() > first.decor.parent:GetFrameLevel())
assert(first.roundedCD.swipe:find("Solid3", 1, true))
one.cooldown="none"
ticker.scripts.OnUpdate(ticker,.2)
assert(not first.roundedCD.shown and first.cooldownText.text=="5")
one.showCooldownText=false
ticker.scripts.OnUpdate(ticker,.2)
assert(first.cooldownText.text=="")
local totemButton=A.ownedBars[totems.id].buttons[1]
placed=true
totems.totemProgress="bar"
ticker.scripts.OnUpdate(ticker,.2)
assert(totemButton.totemTrack.shown and not totemButton.totemRing.shown)
assert(not totemButton.caption.text:find("●",1,true))
totems.totemProgress="ring"
ticker.scripts.OnUpdate(ticker,.2)
assert(not totemButton.totemTrack.shown and totemButton.totemRing.shown)
placed=false
ticker.scripts.OnUpdate(ticker,.2)
assert(not totemButton.totemRing.shown)
BagsBar=CreateFrame("Frame","BagsBar",UIParent)
native.BorderArt=CreateFrame("Frame",nil,native)
native.EndCaps=CreateFrame("Frame",nil,native)
state.hideBlizzardArt,state.hideBlizzardBags=true,true
A.RebuildBars()
assert(native.BorderArt.alpha==0 and BagsBar:GetParent()~=UIParent)
state.hideBlizzardArt,state.hideBlizzardBags=false,false
A.RebuildBars()
assert(native.BorderArt.alpha==1 and BagsBar:GetParent()==UIParent)
do
    assert(A.FormatRemaining(179) == "3m" and A.FormatRemaining(15) == "15")
    local oldAuraAPI, oldInfo, oldSecret = C_UnitAuras, GetActionInfo, issecretvalue
    local private, auraApplied = {}, true
    local auraDuration = {}
    function auraDuration:GetRemainingDuration() return 180 end
    function auraDuration:GetTotalDuration() return 600 end
    C_UnitAuras = {
        GetPlayerAuraBySpellID = function(spell)
            if auraApplied and spell == 324 and not combat then
                return {duration=600, expirationTime=285, auraInstanceID=42}
            end
        end,
        GetAuraDataByAuraInstanceID = function(unit, instance)
            assert(unit == "player" and instance == 42)
            if auraApplied then return {duration=private, expirationTime=private, auraInstanceID=42} end
        end,
        GetAuraDuration = function() return auraDuration end,
    }
    function issecretvalue(value) return value == private end
    function GetActionInfo(slot)
        if slot == first:GetAttribute("action") then
            if combat then return private, private end
            return "spell", 324
        end
    end
    one.auraProgress = "bar"
    ticker.scripts.OnUpdate(ticker,.2)
    assert(first.totemTrack:IsShown() and first.cooldownText.text == "3m")
    one.auraProgress = "ring"
    ticker.scripts.OnUpdate(ticker,.2)
    assert(first.totemRing:IsShown() and not first.totemTrack:IsShown())
    one.auraProgress = "clock"
    ticker.scripts.OnUpdate(ticker,.2)
    assert(first.totemClock:IsShown())
    combat, one.auraProgress = true, "bar"
    ticker.scripts.OnUpdate(ticker,.2)
    assert(first.totemTrack:IsShown() and first.cooldownText.text == "3m")
    function auraDuration:GetRemainingDuration() return private end
    function methods:SetCooldownFromDurationObject(object) self.durationObject = object end
    ticker.scripts.OnUpdate(ticker,.2)
    assert(first.totemClock:IsShown() and first.totemClock.durationObject == auraDuration)
    auraApplied = false
    ticker.scripts.OnUpdate(ticker,.2)
    assert(not first.totemClock:IsShown() and not first.totemTrack:IsShown())
    combat = false
    one.auraProgress = nil
    C_UnitAuras, GetActionInfo, issecretvalue = oldAuraAPI, oldInfo, oldSecret
    ticker.scripts.OnUpdate(ticker,.2)
    assert(not first.totemClock:IsShown())
    local dismiss = totemButton.dismissTotem
    placed=true
    ticker.scripts.OnUpdate(ticker,.2)
    assert(dismiss:GetAttribute("totem-slot") == 2)
    assert(math.abs(dismiss.point[4] - 25 * math.sin(math.rad(38))) < .0001
        and math.abs(dismiss.point[5] - 25 * math.cos(math.rad(38))) < .0001)
    assert(dismiss.dismissible:IsShown() and dismiss:GetAlpha() == 1 and dismiss:IsMouseEnabled())
    local function clickDismiss(down)
        return snippet(dismiss.wrappers.OnClick.body, {self=dismiss, button="LeftButton", down=down})
    end
    assert(clickDismiss(true) == false and not dismiss:GetAttribute("type1"))
    clickDismiss(false)
    assert(dismiss:GetAttribute("type1") == "destroytotem")
    function GetTotemCannotDismiss() return true end
    ticker.scripts.OnUpdate(ticker,.2)
    assert(not dismiss.dismissible:IsShown())
    GetTotemCannotDismiss=nil
    placed=false
    ticker.scripts.OnUpdate(ticker,.2)
    assert(dismiss:GetAlpha()==0 and not dismiss:IsMouseEnabled())
    combat = true
    snippet(dismiss:GetAttribute("_onstate-combat"), {self=dismiss, newstate="on"})
    function totemButton:IsUnderMouse() return true end
    clickDismiss(true)
    clickDismiss(false)
    assert(dismiss:GetAttribute("type1") == "spell")
    function totemButton:IsUnderMouse() return false end
    assert(clickDismiss(true) == false and clickDismiss(false) == false and not dismiss:GetAttribute("type1"))
    combat = false
    totems.totemDismissAngle, totems.totemDismissDistance = 90, 10
    totems.totemDismissBorderWidth = 4
    totems.totemDismissBorderColor, totems.totemDismissBackground = "FF0000", "0000FF"
    function dismiss.rim:SetVertexColor(r, g, b) self.rgb = {r, g, b} end
    function dismiss.fill:SetVertexColor(r, g, b) self.rgb = {r, g, b} end
    function dismiss.fill:SetSize(w, h) self.size = {w, h} end
    A.RebuildBars()
    assert(dismiss.point[4] == 10 and math.abs(dismiss.point[5]) < .0001)
    ticker.scripts.OnUpdate(ticker,.2)
    assert(dismiss.rim:IsShown() and dismiss.fill.size[1] == 4 and dismiss.fill.size[2] == 4)
    assert(dismiss.rim.rgb[1] == 1 and dismiss.rim.rgb[2] == 0 and dismiss.rim.rgb[3] == 0)
    assert(dismiss.fill.rgb[1] == 0 and dismiss.fill.rgb[2] == 0 and dismiss.fill.rgb[3] == 1)
    totems.totemDismissBorderWidth = 0
    ticker.scripts.OnUpdate(ticker,.2)
    assert(not dismiss.rim:IsShown() and dismiss.fill.size[1] == 12)
    totems.totemDismissDistance = 0
    A.RebuildBars()
    assert(dismiss.point[4] == 0 and dismiss.point[5] == 0)
    totems.showTotemDismiss = false
    A.RebuildBars()
    assert(not dismiss:IsShown())
    totems.showTotemDismiss, totems.totemDismissAngle, totems.totemDismissDistance = nil, nil, nil
    totems.totemDismissBorderWidth, totems.totemDismissBorderColor, totems.totemDismissBackground = nil, nil, nil
    A.RebuildBars()
    TotemFrame=CreateFrame("Frame",nil,UIParent)
    state.hideBlizzardActiveTotems=true
    A.RebuildBars()
    assert(TotemFrame:GetParent()~=UIParent)
    state.hideBlizzardActiveTotems=false
    A.RebuildBars()
    assert(TotemFrame:GetParent()==UIParent)
    TotemFrame=nil
end
print("OK active aura duration modes, minute time, dismiss controls and independent Blizzard tracker toggle")
print("OK rounded cooldown, independent countdown, totem duration modes and Blizzard art/bag restoration")
do
    local hidden, actionDuration, spellDuration, activeDuration = {}, {}, {}, {}
    local oldActionBar, oldSecret, oldGetActionCooldown = C_ActionBar, issecretvalue, GetActionCooldown
    local oldSpellCooldown, oldSpellDuration = C_Spell.GetSpellCooldown, C_Spell.GetSpellCooldownDuration
    local oldTotemInfo, oldTotemDuration = GetTotemInfo, GetTotemDuration
    function issecretvalue(value) return value == hidden end
    function GetActionCooldown() return hidden, hidden, 1, 1 end
    C_ActionBar = {GetActionCooldownDuration=function() return actionDuration end}
    C_Spell.GetSpellCooldown=function() return {startTime=hidden,duration=hidden} end
    C_Spell.GetSpellCooldownDuration=function() return spellDuration end
    function GetTotemInfo() return hidden, hidden, hidden, hidden end
    function GetTotemDuration() return activeDuration end
    function methods:SetCooldownFromDurationObject(object) self.durationObject=object end
    local oldTotemCooldown, oldActionStyle=totems.cooldown, one.cooldown
    totems.cooldown, one.cooldown="veil", "edge"
    combat=true
    ticker.scripts.OnUpdate(ticker,.2)
    assert(first.nativeCD:IsShown() and first.nativeCD.durationObject==actionDuration)
    assert(totemButton.nativeCD:IsShown() and totemButton.nativeCD.durationObject==spellDuration)
    assert(totemButton.totemClock:IsShown() and totemButton.totemClock.durationObject==activeDuration)
    local oldShape, oldExtra = totems.shape, totems.extra[5]
    totems.shape, totems.cooldown = "rounded", "edge"
    totems.extra[5] = {kind = "spell", id = 36936}
    combat = false
    A.RebuildBars()
    local recall = A.ownedBars[totems.id].buttons[5]
    combat = true
    ticker.scripts.OnUpdate(ticker,.2)
    assert(recall.nativeCD:IsShown() and recall.nativeCD.swipe:find("Solid3", 1, true))
    assert(recall.nativeCD:GetFrameLevel() > recall.decor.parent:GetFrameLevel())
    C_Spell.GetSpellCooldown = function() return {startTime = 100, duration = 30} end
    ticker.scripts.OnUpdate(ticker,.2)
    assert(recall.roundedCD:IsShown() and recall.roundedCD:GetFrameLevel() > recall.decor.parent:GetFrameLevel())
    combat=false
    totems.shape, totems.extra[5] = oldShape, oldExtra
    A.RebuildBars()
    C_ActionBar,issecretvalue,GetActionCooldown=oldActionBar,oldSecret,oldGetActionCooldown
    C_Spell.GetSpellCooldown,C_Spell.GetSpellCooldownDuration=oldSpellCooldown,oldSpellDuration
    GetTotemInfo,GetTotemDuration=oldTotemInfo,oldTotemDuration
    totems.cooldown, one.cooldown=oldTotemCooldown, oldActionStyle
    ticker.scripts.OnUpdate(ticker,.2)
    assert(not first.nativeCD:IsShown() and not totemButton.nativeCD:IsShown())
end
print("OK combat duration objects render action, totem spell and active totem cooldowns")


local idxBefore=#KeyLayersCharLayout.panels
local created=M.wrap({one},8,"Nouveau cadre")
assert(created==idxBefore+1 and M.frame(one)==KeyLayersCharLayout.panels[created])
local movable={x=0,y=0,width=300,height=120}
local x,y=M.placeBeside(movable,{left=-50,right=400,top=270,bottom=-270},1200,800)
assert(x+150<=-62 and y==0)
editor.open(created,one.id)
local countBefore=0
for _ in pairs(state.bars) do countBefore=countBefore+1 end
for id,b in pairs(state.bars) do if b~=one then assert(M.remove(b)) end end
assert(countBefore>1)
prompt=nil
local removedFrame=A.ownedBars[one.id]
local shortcutCommand=A.NativeBarBinding("owned",one.id,1)
local previousBindingKey, previousBindingAction, previousSetBinding=GetBindingKey,GetBindingAction,SetBinding
local bound=true
function GetBindingKey(binding)
    if bound and binding==shortcutCommand then return "F7" end
    return previousBindingKey(binding)
end
function GetBindingAction(key, ...)
    if bound and key=="F7" then return shortcutCommand end
    return previousBindingAction(key,...)
end
function SetBinding(key, binding, ...)
    if key=="F7" and not binding then
        assert(not removedFrame:IsShown(), "bar stayed visible while removing its bindings")
        bound=false
        return true
    end
    return previousSetBinding(key,binding,...)
end
A.barPreview, A.totemCooldownPreview=one, one
click("Delete bar")
local dialog=CreateFrame("Frame",nil,UIParent)
assert(prompt and dialog:IsShown())
prompt(dialog)
assert(not dialog:IsShown() and not next(state.bars))
assert(not removedFrame:IsShown() and not removedFrame.model and not next(removedFrame.drivers))
assert(not removedFrame.buttons[1]:IsShown() and removedFrame.buttons[1].model==nil)
assert(not A.barPreview and not A.totemCooldownPreview and not bound)
GetBindingKey,GetBindingAction,SetBinding=previousBindingKey,previousBindingAction,previousSetBinding
local replacement=M.new("action")
assert(replacement.id==1)
A.RebuildBars()
assert(removedFrame:IsShown() and removedFrame.model==replacement and removedFrame.buttons[1]:IsShown())
print("OK last-bar deletion immediately hides runtime and clears previews and bindings before slot reuse")

local testParent=KeyLayersCharLayout.panels[created]
local linkedTotem=assert(M.new("totem"))
assert(M.attach(linkedTotem,testParent))
A.RebuildBars()
local removedTotem=A.ownedBars[linkedTotem.id]
local totemElement=removedTotem.buttons[1]
totemElement.selector.bindings.MOUSEWHEELUP={"mock","LeftButton"}
assert(A.DeleteOwnedBars(M.children(testParent))==1)
assert(not removedTotem:IsShown() and not next(totemElement.selector.bindings))
assert(state.bars[replacement.id]==replacement and removedFrame:IsShown())
print("OK deleting linked bars leaves independent bars visible and clears totem selector bindings")
replacement.parent=999999
replacement.x,replacement.y=30,20
A.RebuildBars()
assert(replacement.parent==nil and M.children(nil)[1]==replacement)
assert(replacement.x==30 and replacement.y==20 and removedFrame:IsShown())
print("OK surviving orphan bars are recovered into the independent-bar list without moving")


local container=A.NewPanel("Nouveau cadre")
container.x,container.y=100,50
table.insert(KeyLayersCharLayout.panels,container)
local left=M.new("action",container)
local right=M.new("action",container)
left.x,left.y,left.count,left.columns=-100,0,2,2
right.x,right.y,right.count,right.columns=120,70,2,2
local geometry=M.envelope(container,container)
assert(geometry.x==110 and geometry.y==85 and geometry.width==311 and geometry.height==122)
local oldPositionX,oldPositionY=M.position(left)
assert(oldPositionX==0 and oldPositionY==50)
assert(M.uniqueName("Nouveau cadre")=="Nouveau cadre 1")
local former=A.NewPanel("Former Bartender frame")
former.kind,former.x,former.y,former.width,former.height="bars",270,-110,400,140
former.activationMode,former.layer,former.toggleId="hold","alt",17
former.bars={[1]=true}
table.insert(KeyLayersCharLayout.panels,former)
state.mode="KeyLayers"
loadedBT=false
M.syncProvider(KeyLayersCharLayout)
assert(former.kind=="owned" and former.bartenderAttachment=="bars")
assert(former.x==270 and former.y==-110 and former.width==400 and former.height==140)
assert(former.toggleId==17 and former.layer=="alt" and former.bars[1])
assert(M.envelope(former,former)==former)
state.mode="Bartender4"
loadedBT=true
M.syncProvider(KeyLayersCharLayout)
assert(former.kind=="bars" and former.bars[1] and former.toggleId==17)
loadedBT=false
state.mode="KeyLayers"
state.hideBlizzard=true
for _,bar in pairs(state.bars) do M.remove(bar) end
A.RebuildBars()
assert(native:GetParent()~=UIParent)
state.hideBlizzard=false
A.RebuildBars()
assert(native:GetParent()==UIParent)
print("OK bounds follow attached bars, unique names, provider round trip, and Blizzard hiding without owned bars")

local empty=A.NewPanel("Empty")
table.insert(KeyLayersCharLayout.panels,empty)
local emptyIndex=#KeyLayersCharLayout.panels
state.mode="KeyLayers"
editor.openFrameBars(emptyIndex)
local attached=M.children(empty)
assert(#attached==1 and attached[1].kind=="action" and empty.kind=="owned")
do
    local function hasVisibleText(text)
        for _, widget in ipairs(events) do
            if widget.text == text and widget:IsVisible() then return true end
        end
    end
    assert(hasVisibleText("Attach to frame") and not hasVisibleText("Columns"))
    editor.openSection("layout")
    assert(hasVisibleText("Columns") and not hasVisibleText("Attach to frame"))
    editor.openSection("attachment")
end
editor.openFrameBars(emptyIndex)
assert(#M.children(empty)==1)
print("OK empty frame creates one action bar and the inspector switches dedicated pages")
do
    local bar=M.children(empty)[1]
    local frame=A.ownedBars[bar.id]
    assert(bar.fitFrame)
    local originalWidth,originalHeight,originalPadding=empty.width,empty.height,empty.padding
    empty.width,empty.height,empty.padding=314,149,12
    A.UpdateOwnedFramePositions()
    local columns,rows,scale,count=M.barGrid(bar)
    assert(columns==7 and rows==3 and count==21 and scale==1)
    assert(frame:GetAttribute("count")==21 and frame.buttons[21]:IsShown())
    local width,height=M.size(bar)
    assert(width+24<=empty.width and height+24<=empty.height)
    assert(M.envelope(empty,empty)==empty and empty.padding==12)
    local horizontal,vertical=M.fitMargins(empty,empty)
    assert(horizontal==(314-width)/2 and vertical==(149-height)/2)
    local resized={x=empty.x,y=empty.y,width=320,height=150,padding=12}
    local resizedPadding=M.fitMargins(empty,resized)
    assert(resizedPadding==horizontal+3 and empty.padding==12)
    resized.padding=25
    local largerMargin=M.fitMargins(empty,resized)
    assert(largerMargin>=25 and empty.padding==12)
    resized.paddingX,resized.paddingY=41,12
    local separateX,separateY=M.fitMargins(empty,resized)
    assert(separateX>=41 and separateY==vertical+.5)
    resized.paddingX,resized.paddingY=nil,nil
    local inheritedX,inheritedY=M.framePadding(empty)
    assert(inheritedX==12 and inheritedY==12)

    bar.extra = {[21]={kind="spell",id=42}}
    empty.width,empty.height=220,100
    A.UpdateOwnedFramePositions()
    columns,rows,scale,count=M.barGrid(bar)
    assert(columns==5 and rows==2 and count==10)
    assert(frame:GetAttribute("count")==10 and not frame.buttons[21]:IsShown() and bar.extra[21].id==42)
    empty.width,empty.height=314,149
    A.UpdateOwnedFramePositions()
    assert(frame.buttons[21]:IsShown() and frame.buttons[21]:GetAttribute("spell")==42)
    bar.extra = nil

    local fittedWidth, fittedHeight = empty.width, empty.height
    assert(M.resizeToPadding(empty,4,9))
    local exactX, exactY = M.fitMargins(empty,empty)
    local exactColumns, exactRows, _, exactCount = M.barGrid(bar,empty)
    assert(exactX==4 and exactY==9 and exactColumns==7 and exactRows==3 and exactCount==21)
    local minimumX, minimumY = M.framePadding(empty)
    assert(minimumX==12 and minimumY==12)
    local resizedGeometry = {x=empty.x,y=empty.y,width=220,height=100,paddingX=12,paddingY=12}
    local _, _, _, resizedCount = M.barGrid(bar,resizedGeometry)
    assert(resizedCount==10)
    empty.manualFit=nil
    empty.width,empty.height=fittedWidth,fittedHeight

    M.setFitFrame(bar,false)
    A.RebuildBars()
    assert(bar.columns==7 and bar.count==21 and frame.layoutRows==3 and frame.layoutScale==1)
    empty.width,empty.height,empty.padding=originalWidth,originalHeight,originalPadding
    A.UpdateOwnedFramePositions()
    assert(frame.layoutColumns==7 and frame.layoutRows==3)
    print("OK frame-led fit changes grid capacity, preserves actions and freezes the current layout")
end
do
    local panel = A.NewPanel("Manual frame")
    table.insert(KeyLayersCharLayout.panels,panel)
    state.autoFitFrames = false
    local bar = M.new("action",panel,true)
    local global = M.barTemplate(KeyLayersCharLayout)
    M.changeBarLayout(function() global.columns=4; global.count=12 end)
    assert(not M.followsFrame(bar) and M.barGrid(bar)==4)
    panel.width,panel.height,panel.frameSized=450,250,true
    local drawn=M.envelope(panel,panel)
    assert(drawn.width==450 and drawn.height==250 and drawn.x==panel.x)
    M.changeBarLayout(function() global.columns=6 end)
    drawn=M.envelope(panel,panel)
    local w,h=M.size(bar)
    assert(M.barGrid(bar)==6 and drawn.width==w+2*panel.padding and drawn.height==h+2*panel.padding)
    M.clearBarTemplate(KeyLayersCharLayout)
    M.remove(bar)
    table.remove(KeyLayersCharLayout.panels)
    state.autoFitFrames = nil
    print("OK manual frame sizing and inherited bar-grid precedence")
end
do
    local panel = M.newFrame(KeyLayersCharLayout, "Inherited dimensions")
    table.insert(KeyLayersCharLayout.panels, panel)
    state.autoFitFrames = false
    local bar = M.new("action", panel, true)
    local draft = M.frameDefaultsDraft(KeyLayersCharLayout, "owned")
    draft.width, draft.height = 450, 250
    local preview = M.previewFrameDimensions(KeyLayersCharLayout, "owned", draft)[panel]
    assert(preview and preview.width==450 and panel.width~=450)
    local outline = M.envelope(preview,preview)
    assert(outline.width>=450 and outline.height>=250 and outline.x==panel.x)
    local _, _, _, manualCount = M.barGrid(bar,preview)
    state.autoFitFrames = true
    local _, _, _, autoCount = M.barGrid(bar,preview)
    assert(autoCount>manualCount)
    local second = M.new("action",panel,true)
    assert(second and not M.followsFrame(bar) and not M.followsFrame(second))
    assert(M.envelope(preview,preview)~=preview)
    M.remove(second)
    assert(M.followsFrame(bar))
    M.setFitFrame(bar,false)
    assert(not M.followsFrame(bar) and M.autoFitEnabled())
    M.remove(bar)
    table.remove(KeyLayersCharLayout.panels)
    state.autoFitFrames = nil
end
local movingBar=M.children(empty)[1]
local movingFrame=A.ownedBars[movingBar.id]
local saved=M.envelope(empty,empty)
movingBar.dragging=true
A.PlaceOwnedBar(movingFrame,saved.x+140,saved.y-60)
local live=M.envelope(empty,empty)
assert(live.x==saved.x+140 and live.y==saved.y-60)
assert(M.envelope(empty,empty,true).x==saved.x)
assert(movingBar.x==0 and movingBar.y==0)
movingBar.dragging=nil
print("OK the frame follows the dragged bar without moving its saved anchor or drop target")
local destination=A.NewPanel("Destination")
destination.x,destination.y=360,210
table.insert(KeyLayersCharLayout.panels,destination)
local second=M.new("action",destination)
assert(M.attachInside(movingBar,destination))
local movedX,movedY=M.position(movingBar)
assert(movedX==destination.x and movedY<destination.y)
local savedOffset=movingBar.y
assert(M.attachInside(movingBar,destination) and movingBar.y==savedOffset)
A.RebuildBars()
destination.x,destination.y=460,300
A.UpdateOwnedFramePositions()
assert(A.ownedBars[movingBar.id].placedX==460 and A.ownedBars[second.id].placedY==300)
local testingTotems=M.new("totem",destination)
testingTotems.totemProgress="clock"
testingTotems.totem_clockSize=.5
testingTotems.totem_clockOpacity=.4
placed=true
A.RebuildBars()
ticker.scripts.OnUpdate(ticker,.2)
local clockButton=A.ownedBars[testingTotems.id].buttons[1]
assert(clockButton.totemClock.shown and clockButton.totemClock.inset==9 and not clockButton.totemTrack.shown)
placed=false
ticker.scripts.OnUpdate(ticker,.2)
assert(not clockButton.totemClock.shown)
print("OK reattachment, shared parent movement and configurable totem clock")

local shifted=M.new("action")
shifted.count,shifted.columns,shifted.slotOffset=16,4,4
A.RebuildBars()
local shiftedFrame=A.ownedBars[shifted.id]
assert(M.slotPosition(shifted,1)==4 and M.slotPosition(shifted,13)==0)
assert(shiftedFrame.buttons[1].point[3]==-(36+shifted.gap))
assert(shiftedFrame.buttons[13].point[3]==0)
assert(shiftedFrame.buttons[1]:GetAttribute("action")==12*(shifted.page-1)+1)
assert(A.NativeBarBinding("owned",shifted.id,13):match("Button13:LeftButton$"))
shifted.shape="rounded"
A.RebuildBars()
assert(shiftedFrame.buttons[1].hover.masked)
local kbSource=assert(io.open("Keybinds.lua")):read("*a")
-- Export the local eligibility function for this fixture.
local eligibleEnd=assert(kbSource:find("\nlocal ",assert(kbSource:find("\n    return bases, targets",1,true)),true))
local getBars=assert(load(kbSource:sub(1,eligibleEnd-1).."\nreturn eligibleBars","eligibility","t",_G))("KeyLayers",A)
local group=A.NewPanel("Sixteen")
table.insert(KeyLayersCharLayout.panels,group)
M.attach(shifted,group)
A.HoldLayer=function(p) if p==group then return "unmodified" end end
A.PanelToggle=function() end
local ownedButton=A.BarActionButton
A.BarActionButton=function(kind,id,slot)
    if kind=="owned" and slot<=16 and id==shifted.id then return shiftedFrame.buttons[slot] end
    if ownedButton then return ownedButton(kind,id,slot) end
end
local sources=getBars({})
assert(#sources==1 and sources[1].slotCount==16 and sources[1].slots[16])
print("OK offset keeps button and binding identity, rounded hover is masked, and 16 slots are assignable")

local placement=A.NewPanel("Placement")
table.insert(KeyLayersCharLayout.panels,placement)
local existing=M.new("action",placement)
existing.count,existing.columns=1,1
local incoming={count=1,columns=1,gap=3,scale=1}
UIParent.width=200
local beforeHeight=methods.GetHeight
function methods:GetHeight() if self==UIParent then return 200 end end
local function expectPosition(x,y,wantX,wantY)
    placement.x,placement.y=x,y
    local gotX,gotY=M.attachmentPosition(incoming,placement)
    assert(gotX==wantX and gotY==wantY)
end
expectPosition(0,0,0,-40)
expectPosition(0,-65,40,-65)
expectPosition(55,-65,15,-65)
existing.count,existing.columns=4,4
expectPosition(0,-65,0,-25)
UIParent.width=1920
methods.GetHeight=beforeHeight
testingTotems.showCooldownText=true
A.barPreview=testingTotems
A.totemCooldownPreview=testingTotems
ticker.scripts.OnUpdate(ticker,.2)
assert(clockButton.cooldownText.text=="8")
A.totemCooldownPreview=nil
ticker.scripts.OnUpdate(ticker,.2)
assert(clockButton.cooldownText.text=="")
print("OK placement priority below, right, left, above and immediate totem countdown preview")

local bare=A.NewPanel("Unlinked")
assert(not M.hasAssignableBars(bare))
local totemParent=A.NewPanel("Totem fixture")
table.insert(KeyLayersCharLayout.panels,totemParent)
assert(M.attach(testingTotems,totemParent))
testingTotems.count=8
testingTotems.totemOrder={4,2,3,1}
testingTotems.extra={[7]={kind="macro",id="Recall test",texture=123}}
A.RebuildBars()
assert(M.hasAssignableBars(totemParent))
assert(M.slotPosition(testingTotems,1)==3 and M.slotPosition(testingTotems,4)==0)
local runtimeTotems=A.ownedBars[testingTotems.id]
assert(runtimeTotems.buttons[1].slot==2)
assert(runtimeTotems.buttons[7]:GetAttribute("type")=="macro")
assert(runtimeTotems.buttons[7]:GetAttribute("macro")=="Recall test")
assert(runtimeTotems.profileText.text==A.TotemProfiles().active)
A.BarActionButton=function(kind,id,slot)
    if kind=="owned" and A.ownedBars[id] and A.ownedBars[id].model then
        return A.ownedBars[id].buttons[slot]
    end
end
local frameSources=getBars({},totemParent)
local direct=frameSources[#frameSources]
assert(direct.panel==totemParent and direct.direct and direct.slots[8].direct)
local firstTotem=runtimeTotems.buttons[1]
firstTotem:ShowCarousel()
assert(firstTotem.carousel:IsShown())
firstTotem.selector:HideCarousel()
assert(not firstTotem.carousel:IsShown())
A.barPreview=testingTotems
placed=false
testingTotems.totemProgress="bar"
ticker.scripts.OnUpdate(ticker,.2)
assert(firstTotem.totemTrack:IsShown())
A.barPreview=nil
ticker.scripts.OnUpdate(ticker,.2)
assert(not firstTotem.totemTrack:IsShown())
print("OK empty frames, generic totem slots, stable element order, profile badge and live duration preview")

local timing={}
C_Timer={After=function(delay,fn) timing.delay=delay; timing.fire=fn end}
elem=A.ownedBars[testingTotems.id].buttons[1]
owner=elem.selector
testingTotems.totemHoldMs=200
A.RebuildBars()
press(true)
assert(timing.delay==.2 and owner.bindings.MOUSEWHEELUP)
press(false)
assert(elem.attrs.type1=="spell" and not next(owner.bindings))
timing.fire()
assert(not owner:GetFrameRef("elapsed"):IsShown())
press(true);timing.fire()
assert(owner:GetFrameRef("elapsed"):IsShown() and elem.carousel:IsShown())
press(false)
assert(not elem.attrs.type1 and not next(owner.bindings) and not elem.carousel:IsShown())
print("OK configurable hold threshold, release-only tap, suppressed long press and restored wheel")
do
    local function verifyTotemInput()
        local oldMouse, oldUsable = IsMouseButtonDown, C_Spell.IsSpellUsable
        local mouseDown = true
        function IsMouseButtonDown() return mouseDown end
        press(true)
        mouseDown = false
        owner.releaseMouse()
        press(false)
        assert(elem.attrs.type1 == "spell", "mouse cleanup blocked a short tap")

        local oldMulticast, oldName = GetMultiCastTotemSpells, C_Spell.GetSpellName
        local profiles = A.TotemProfiles()
        local oldSets = A.Copy(profiles.sets)
        function GetMultiCastTotemSpells(slot) return 300 + slot, 400 + slot end
        function C_Spell.GetSpellName(id)
            if id >= 301 and id <= 404 then return "Totem " .. id end
            return oldName(id)
        end
        A.RebuildBars()
        for index = 1, 4 do
            local button = A.ownedBars[testingTotems.id].buttons[index]
            local selector = button.selector
            local function clickTotem(down)
                snippet(button.wrappers.OnClick.body, {self=button, control=selector, button="LeftButton", down=down})
            end
            function IsMouseButtonDown() return false end
            clickTotem(true)
            timing.fire()
            assert(button.carousel:IsShown() and selector.bindings.MOUSEWHEELUP)
            clickTotem(false)
            assert(not button.carousel:IsShown() and not button.attrs.type1)
            clickTotem(true)
            clickTotem(false)
            assert(button.attrs.type1 == "spell" and button.attrs.spell1 == button.spellId)
        end

        function elem.pressed:SetColorTexture(r, g, b) self.rgb = {r, g, b} end
        C_Spell.IsSpellUsable = function() return false, true end
        press(true)
        assert(elem.pressed:IsShown() and elem.pressed.rgb[2] == elem.blockedPressColor[2])
        press(false)
        C_Spell.IsSpellUsable = function() return true, false end
        press(true)
        press(false)
        assert(elem.pressed.rgb[2] == elem.pressColor[2])
        ticker.scripts.OnEvent(ticker, "UNIT_SPELLCAST_FAILED", "player", "cast", elem.spellId)
        assert(elem.pressed.rgb[2] == elem.blockedPressColor[2])
        local oldActive = profiles.active
        local oldSet, oldGet = SetMultiCastSpell, GetActionInfo
        local oldCalls, oldKnown = TOTEM_MULTI_CAST_SUMMON_SPELLS, IsSpellKnown
        local oldGetPage = GetMultiCastBarIndex
        local native = {[137] = 999, [141] = 998}
        TOTEM_MULTI_CAST_SUMMON_SPELLS = {66842}
        function IsSpellKnown(id) return id == 66842 end
        function GetMultiCastBarIndex() return 12 end
        function GetActionInfo(slot) if native[slot] then return "spell", native[slot] end end
        function SetMultiCastSpell(slot, spell)
            assert(not combat and slot >= 133 and slot <= 136)
            native[slot] = spell
        end
        profiles.sets = {Alpha={}, Bravo={}}
        for index, button in ipairs(A.ownedBars[testingTotems.id].buttons) do
            if index <= 4 then
                profiles.sets.Alpha[index] = 300 + button.slot
                profiles.sets.Bravo[index] = 400 + button.slot
            end
        end
        assert(A.SelectTotemProfile("Alpha"))
        assert(native[133] == 301 and native[134] == 302 and native[135] == 303 and native[136] == 304)
        combat = true
        local profileButton = KeyLayersTotemProfileSwitch
        snippet(profileButton:GetAttribute("_onclick"), {self=profileButton, button="Next", down=true})
        assert(profiles.active == "Bravo" and native[133] == 301)
        snippet(profileButton:GetAttribute("_onclick"), {self=profileButton, button="Next", down=false})
        combat = false
        A.RebuildBars()
        assert(native[133] == 401 and native[134] == 402 and native[135] == 403 and native[136] == 404)
        assert(native[137] == 999 and native[141] == 998)
        profiles.active = oldActive
        SetMultiCastSpell, GetActionInfo, GetMultiCastBarIndex = oldSet, oldGet, oldGetPage
        TOTEM_MULTI_CAST_SUMMON_SPELLS, IsSpellKnown = oldCalls, oldKnown
        elem.pressed.SetColorTexture = nil
        IsMouseButtonDown, C_Spell.IsSpellUsable = oldMouse, oldUsable
        GetMultiCastTotemSpells, C_Spell.GetSpellName = oldMulticast, oldName
        profiles.sets = oldSets
        A.RebuildBars()
    end
    verifyTotemInput()
end
print("OK short mouse tap, held carousel on all four elements, rejected cast feedback and native Call of the Elements sync")

local start=assert(kbSource:find("local function previewChanges",1,true))
local stop=assert(kbSource:find("local function saveChanges",start,true))
local keyFixture=[[
local addon=...
local tr=addon.Translate
local function baseKey(key) return key end
local function keyForAction(action) return action.key end
local function canUsePrefix() return true end
]]
local positionStart=assert(kbSource:find("local function visualSlotFor",1,true))
local positionEnd=assert(kbSource:find("local function compareSlots",positionStart,true))
local selectionStart=assert(kbSource:find("local function selectionKey",1,true))
local testPreview, selectionKey=assert(load(keyFixture..kbSource:sub(positionStart,positionEnd-1)
    ..kbSource:sub(selectionStart,stop-1).."return previewChanges, selectionKey","binding preview","t",_G))(A)
A.NeutralKey=function() end
local oldBindings={["SHIFT-F5"]="Totem1",["SHIFT-F4"]="Other"}
function GetBindingAction(key) return oldBindings[key] end
local groupBase={label="Base",slots={},slotCount=5}
for i=1,5 do groupBase.slots[i]={key="F"..i,command="Base"..i} end
local target={label="Totems",sourceIndex=1,prefix="SHIFT-",slotCount=2,
    slots={{command="Totem1"},{command="Totem2"}}}
local rows=testPreview({groupBase},{target},{[target]=true},{},{},1)
assert(#rows==3 and rows[1].key=="SHIFT-F2" and rows[2].key=="SHIFT-F3")
assert(rows[3].clear and rows[3].key=="SHIFT-F5")
local totemLayer=A.HoldLayer
A.HoldLayer=function(panel) if panel==totemParent then return "maj" end return totemLayer(panel) end
A.LayerLabel=function(layer) return layer end
local _,destinations=getBars({},totemParent)
assert(#destinations==1 and destinations[1].panel==totemParent and destinations[1].prefix=="SHIFT-")
print("OK Shift totem generation, shorter target, slider offset and safe surplus release")

local directExisting={label="Totems",direct=true,slotCount=2,
    slots={{key="SHIFT-F2",command="Totem1",direct=true},{key="SHIFT-F3",command="Totem2",direct=true}}}
oldBindings["SHIFT-F2"]="Totem1"
oldBindings["SHIFT-F3"]="Totem2"
local proposed=testPreview({groupBase,directExisting},{target},{[target]=true},{},{},1)
assert(proposed[1].current and not proposed[1].blocked and proposed[2].current and not proposed[2].blocked)
oldBindings["SHIFT-F2"]="Other"
proposed=testPreview({groupBase,directExisting},{target},{[target]=true},{},
    {["SHIFT-F2"]={from="Other",to="Totem1"}},1)
assert(proposed[1].conflict and proposed[1].approved and not proposed[1].blocked)

local pressed=runtimeTotems.buttons[1]
pressed:FlashPressed()
assert(pressed.pressed:IsShown())
local pressTime=GetTime
function GetTime() return pressTime()+1 end
ticker.scripts.OnUpdate(ticker,.2)
assert(not pressed.pressed:IsShown())
GetTime=pressTime
function methods:GetCenter() return 300,310 end
function methods:GetEffectiveScale() return self~=UIParent and 1.2 or 1 end
elem:ShowCarousel()
local centered
for _,cell in ipairs(elem.carouselRows) do
    if cell:IsShown() and cell.point[4]==360 and cell.point[5]==372 then centered=cell end
end
assert(centered and centered.icon.texture==elem.spellId and not centered.icon:IsShown())
elem.selector:HideCarousel()
assert(not elem.carousel:IsShown())
print("OK binding preview ignores stale direct rows, press flash expires, and selected icon is centered")

testingTotems.slotOffset=3
testingTotems.totemOrder=nil
assert(M.slotPosition(testingTotems,1)==0 and M.slotPosition(testingTotems,5)==4)
testingTotems.totemOrder={2,1,3,4}
assert(M.slotPosition(testingTotems,1)==1 and M.slotPosition(testingTotems,2)==0)
target.slots[1].totemElement=true
local previousGetBindingKey=GetBindingKey
function GetBindingKey(command) if command=="Totem1" then return "SHIFT-F5" end end
local guarded=testPreview({groupBase},{target},{[target]=true},{},{},1)
assert(#guarded==2 and guarded[1].current and guarded[1].key=="SHIFT-F5" and guarded[2].key=="SHIFT-F3")
target.slots[1].button={model=testingTotems}
target.slots[2].totemElement=true
target.slots[2].button={model=testingTotems}
oldBindings["SHIFT-F1"]=nil
local reordered=testPreview({groupBase},{target},{[target]=true},{},{},0)
assert(reordered[1].key=="SHIFT-F5" and reordered[1].current and reordered[2].key=="SHIFT-F1")
GetBindingKey=previousGetBindingKey
reordered=testPreview({groupBase},{target},{[target]=true},{},{},0,
    {[selectionKey(target.slots[2],"SHIFT-F1")]=true})
assert(reordered[1].key=="SHIFT-F2" and reordered[1].action==target.slots[1])
for _,row in ipairs(reordered) do assert(row.key~="SHIFT-F1") end
function IsMouseButtonDown() return true end
press(true)
timing.fire()
assert(elem.carousel:IsShown() and owner.bindings.MOUSEWHEELUP)
owner.releaseMouse()
assert(not elem.carousel:IsShown() and not next(owner.bindings))
press(false)
assert(not elem.attrs.type1)
print("OK totem offset isolation, existing element key protected and missed mouse-up cleanup")
do
    local watcher=ticker.testHoldWatcher
    local oldMouse,oldTime=IsMouseButtonDown,GetTime
    local down=true
    function IsMouseButtonDown() return down end
    press(true); timing.fire()
    assert(elem.carousel:IsShown())
    down=false
    watcher.scripts.OnUpdate(watcher, .2)
    assert(not elem.carousel:IsShown() and not next(owner.bindings))
    press(false)
    press(true); timing.fire()
    assert(elem.carousel:IsShown())
    function GetTime() return oldTime()+11 end
    watcher.scripts.OnUpdate(watcher, .2)
    assert(not elem.carousel:IsShown() and not next(owner.bindings))
    press(false)
    GetTime=oldTime
    press(true); timing.fire()
    combat=true
    watcher.scripts.OnEvent(watcher,"PLAYER_REGEN_DISABLED")
    assert(not elem.carousel:IsShown())
    snippet(owner.attrs["_onstate-combat"],{self=owner,newstate="on"})
    owner:SetAttribute("state-combat","on")
    press(true)
    assert(owner.bindings.MOUSEWHEELUP)
    press(false)
    assert(elem.attrs.type1=="spell" and not next(owner.bindings))
    combat=false
    owner:SetAttribute("state-combat",nil)
    IsMouseButtonDown=oldMouse
end
print("OK carousel closes on missed release, absolute expiry and entering combat without blocking a combat tap")
do
    local p=A.TotemProfiles()
    local oldSets, oldActive=p.sets,p.active
    local oldBinding, oldOverride, oldMouse=GetBindingKey,SetOverrideBindingClick,IsMouseButtonDown
    p.sets={Alpha={102},Bravo={200}}
    p.active="Alpha"
    function GetBindingKey(command)
        if command=="KEYLAYERSTOTEMNEXT" then return "F11" end
        if command=="KEYLAYERSTOTEMPREV" then return "F10" end
        return oldBinding(command)
    end
    function SetOverrideBindingClick(frame,priority,key,name,button)
        assert(not combat)
        frame:SetBindingClick(priority,key,name,button)
    end
    function IsMouseButtonDown() return false end
    A.RebuildBars()
    local controller=KeyLayersTotemProfileSwitch
    assert(controller.bindings.F11[2]=="Next" and controller.bindings.F10[2]=="Previous")
    local function profileKey(button)
        snippet(controller.attrs._onclick,{self=controller,button=button,down=true})
        local selected = p.active
        snippet(controller.attrs._onclick,{self=controller,button=button,down=false})
        assert(p.active == selected)
    end
    combat=true
    owner:SetAttribute("state-combat","on")
    snippet(elem.wrappers.OnClick.body,{control=owner,self=elem,button="MiddleButton",down=false})
    assert(p.active=="Bravo")
    local middleShift = IsShiftKeyDown
    function IsShiftKeyDown() return true end
    snippet(elem.wrappers.OnClick.body,{control=owner,self=elem,button="MiddleButton",down=false})
    assert(p.active=="Alpha")
    IsShiftKeyDown = middleShift
    profileKey("Next")
    assert(p.active=="Bravo" and elem.attrs.spell=="Earth B" and elem.spellId==200)
    press(true); timing.fire()
    assert(elem.carousel:IsShown() and owner.bindings.MOUSEWHEELUP)
    local combatWheel=_G[owner.attrs.wheel]
    snippet(combatWheel.attrs._onclick,{self=combatWheel,button="LeftButton"})
    assert(elem.attrs.spell=="Earth A" and p.sets.Bravo[1]==102)
    press(false)
    assert(not elem.attrs.type1 and not elem.carousel:IsShown() and not next(owner.bindings))
    local oldShift = IsShiftKeyDown
    function IsShiftKeyDown() return true end
    press(true); timing.fire()
    assert(owner.bindings["SHIFT-MOUSEWHEELUP"])
    press(false)
    IsShiftKeyDown = oldShift
    snippet(elem.wrappers.OnClick.body,{control=owner,self=elem,button="RightButton",down=false})
    assert(elem.carousel:IsShown() and owner.attrs.latchedCarousel)
    snippet(elem.wrappers.OnClick.body,{control=owner,self=elem,button="RightButton",down=false})
    assert(not elem.carousel:IsShown() and not next(owner.bindings))
    profileKey("Previous")
    assert(p.active=="Alpha")
    profileKey("Next")
    assert(p.active=="Bravo" and elem.spellId==102)
    press(true); timing.fire()
    assert(elem.carousel:IsShown())
    profileKey("Previous")
    assert(not elem.carousel:IsShown() and not next(owner.bindings))
    press(false)
    assert(not elem.attrs.type1)
    press(true); press(false)
    assert(elem.attrs.type1=="spell")
    combat=false
    owner:SetAttribute("state-combat",nil)
    p.sets,p.active=oldSets,oldActive
    GetBindingKey,SetOverrideBindingClick,IsMouseButtonDown=oldBinding,oldOverride,oldMouse
    A.RebuildBars()
end
print("OK combat profile shortcuts, carousel wheel, saved profile choices and direct cast")



MultiCastActionBarFrame = CreateFrame("Frame",nil,UIParent)
local settings=M.init(KeyLayersCharLayout)
settings.hideBlizzardTotems=true
A.RebuildBars()
assert(MultiCastActionBarFrame:GetParent()~=UIParent)
assert(not MultiCastActionBarFrame:GetParent():IsShown())
settings.hideBlizzardTotems=false
A.RebuildBars()
assert(MultiCastActionBarFrame:GetParent()==UIParent)
print("OK Blizzard totem action bar hides and restores independently")

-- Exercise the actual assignment controls with multiple generation layers.
local assistantStart = #events
local previewSlider
local createFrame = CreateFrame
function CreateFrame(kind, name, parent, template)
    local frame = createFrame(kind, name, parent)
    if kind == "Slider" and template == "OptionsSliderTemplate" then
        frame.Low, frame.High = obj(nil,frame), obj(nil,frame)
        previewSlider = frame
    end
    return frame
end
function methods:SetValue(value)
    self.value = value
    if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self,value) end
end
function methods:SetAllPoints(anchor) self.anchor = anchor end
local basePanel = {name="Base fixture", fixtureLayer="unmodified", barFrameId=101}
local mainTotems = {name="Totem fixture", fixtureLayer="maj", barFrameId=102}
local otherPanel = {name="Other fixture", fixtureLayer="ctrl", barFrameId=103}
local models = {
    {id=1, kind="action", count=6, parent=101},
    {id=2, kind="totem", count=4, parent=102, totemOrder={3,1,2,4}},
    {id=3, kind="action", count=1, parent=103},
}
KeyLayersCharLayout = {panels={basePanel,mainTotems,otherPanel}, barWorkspace={mode="KeyLayers",bars=models}}
local liveButtons = {}
for id,model in ipairs(models) do
    liveButtons[id] = {}
    for slot=1,model.count do
        local button = obj(nil,UIParent)
        button.model = model
        liveButtons[id][slot] = button
    end
end
A.HoldLayer = function(panel) return panel.fixtureLayer end
A.PanelToggle = noop
A.BarActionButton = function(kind,id,slot) return kind=="owned" and liveButtons[id][slot] end
A.SetBindingOutlines = noop
A.SyncSwitch = noop
function GetNumBindings() return 0 end
local savedKeys = {}
for slot=1,6 do savedKeys[tostring(slot)] = A.NativeBarBinding("owned",1,slot) end
savedKeys["SHIFT-1"] = A.NativeBarBinding("owned",2,1)
savedKeys["SHIFT-F8"] = A.NativeBarBinding("owned",2,1)
savedKeys["SHIFT-3"] = A.NativeBarBinding("owned",2,3)
savedKeys["CTRL-1"] = A.NativeBarBinding("owned",3,1)
function GetBindingKey(command)
    local keys={}
    for key,owner in pairs(savedKeys) do if owner==command then keys[#keys+1]=key end end
    table.sort(keys)
    return table.unpack(keys)
end
function GetBindingAction(key) return savedKeys[key] end
function SetBinding(key, command) savedKeys[key]=command; return true end
function SaveBindings() end
function GetCurrentBindingSet() return 1 end
local function control(parent, label, _, _, _, onClick)
    local frame = CreateFrame("Button",nil,parent)
    frame:SetText(label)
    frame:SetScript("OnClick",onClick)
    return frame
end
local ui = {button=control,label=control,radio=noop,
    menu=function(parent) return CreateFrame("Frame",nil,parent) end,
    confirm=function(_, accept) accept() end}
loadModule("Keybinds")
local assistant = A.CreateKeybindingAssistant(UIParent,ui,UIParent)
assistant:Open(mainTotems)
local function overlayAt(slot)
    for i=assistantStart+1,#events do
        local frame=events[i]
        if frame.anchor==liveButtons[2][slot] and frame:IsVisible() then return frame:GetText() end
    end
end
click("Clear frame keybindings")
assert(not savedKeys["SHIFT-1"] and not savedKeys["SHIFT-F8"] and not savedKeys["SHIFT-3"])
assert(savedKeys["CTRL-1"] and savedKeys["1"])
assert(overlayAt(3)=="1" and overlayAt(1)=="2" and overlayAt(2)=="3")
previewSlider:SetValue(1)
assert(overlayAt(3):find("SHIFT-2",1,true) and overlayAt(1):find("SHIFT-3",1,true))
previewSlider:SetValue(2)
assert(overlayAt(3):find("SHIFT-3",1,true) and overlayAt(1):find("SHIFT-4",1,true))
assert(not savedKeys["SHIFT-2"] and not savedKeys["SHIFT-3"])
assistant:Open(mainTotems)
assert(overlayAt(3):find("SHIFT-1",1,true) and overlayAt(1):find("SHIFT-2",1,true))
print("OK clearing a reordered totem frame keeps live offset preview with multiple modifier combinations")

local pendingTotem={label="Direct",slotCount=1,
    slots={{direct=true,command="Totem1"}}}
local mixed=testPreview({groupBase,pendingTotem},{target},{[target]=true},
    {[pendingTotem]={"SHIFT-F1"}},{},0)
assert(#mixed==1 and mixed[1].action.direct and mixed[1].key=="SHIFT-F1" and not mixed[1].blocked)
print("OK staged manual shortcut takes precedence over generated totem shortcuts")

-- With all six destination buttons bound, both rows of the totem bar slide together.
models[1].count, models[2].count = 8, 6
for id=1,2 do
    for slot=#liveButtons[id]+1,models[id].count do
        local button=obj(nil,UIParent)
        button.model=models[id]
        liveButtons[id][slot]=button
    end
end
local visualOrder = {3,1,2,4,5,6}
for slot=1,8 do savedKeys[tostring(slot)] = A.NativeBarBinding("owned",1,slot) end
for position,slot in ipairs(visualOrder) do
    savedKeys["SHIFT-"..position] = A.NativeBarBinding("owned",2,slot)
end
savedKeys["SHIFT-F8"] = A.NativeBarBinding("owned",2,3)
savedKeys["ALT-F9"] = A.NativeBarBinding("owned",2,3)
assistant:Open(mainTotems)
previewSlider:SetValue(1)
for position,slot in ipairs(visualOrder) do
    assert(overlayAt(slot):find("SHIFT-"..(position+1),1,true))
    assert(savedKeys["SHIFT-"..position]==A.NativeBarBinding("owned",2,slot))
end
click("Apply")
for position,slot in ipairs(visualOrder) do
    assert(savedKeys["SHIFT-"..(position+1)]==A.NativeBarBinding("owned",2,slot))
    assert(savedKeys[tostring(position)]==A.NativeBarBinding("owned",1,position))
end
assert(not savedKeys["SHIFT-1"] and not savedKeys["SHIFT-F8"])
assert(savedKeys["ALT-F9"]==A.NativeBarBinding("owned",2,3))
assert(savedKeys["CTRL-1"]==A.NativeBarBinding("owned",3,1))
assistant:Open(mainTotems)
for position,slot in ipairs(visualOrder) do
    assert(overlayAt(slot):find("SHIFT-"..(position+1),1,true))
end
previewSlider:SetValue(1)
previewSlider:SetValue(0)
for position,slot in ipairs(visualOrder) do
    assert(overlayAt(slot):find("SHIFT-"..position,1,true))
end
click("Apply")
assert(not savedKeys["SHIFT-7"])
for position,slot in ipairs(visualOrder) do
    assert(savedKeys["SHIFT-"..position]==A.NativeBarBinding("owned",2,slot))
end
print("OK offset remaps all saved totem and auxiliary bindings in visual order, including back to zero")

-- Appearance can be copied without taking layout, spells, or ordering with it.
local sourceBar={kind="totem",shape="round",borderColor="FFCC22",alpha=.8,totemProgress="ring",
    totem_ringOpacity=.4,count=9,x=42,columns=3,page=5,extra={{id=2}},totemOrder={3,1,4,2}}
local targetBar={kind="totem",shape="square",count=6,x=-22,columns=6,page=2,extra={{id=7}},totemOrder={1,2,3,4}}
M.copyBarStyle(sourceBar,targetBar)
assert(targetBar.shape=="round" and targetBar.alpha==.8 and targetBar.borderColor=="FFCC22")
assert(targetBar.totemProgress=="ring" and targetBar.totem_ringOpacity==.4)
assert(targetBar.count==6 and targetBar.x==-22 and targetBar.columns==6 and targetBar.page==2
    and targetBar.extra[1].id==7 and targetBar.totemOrder[1]==1)
print("OK bar style copy preserves geometry, assigned actions, and element order")

A.PanelToggleKey=noop
mainTotems.profileHint={hintSide="top-start",defaultStyle=A.NewPanel("default"),activeStyle=A.NewPanel("active")}
mainTotems.profileHint.defaultStyle.fillAlpha=.2
mainTotems.profileHint.activeStyle.fillAlpha=.8
local labelHost=obj(nil,UIParent)
A.CreateHint(labelHost)
local frameStyle=A.NewPanel("Frame")
assert(A.UpdateProfileHint(labelHost,mainTotems,frameStyle,false))
assert(labelHost.profileTab.side=="bottom-start" and labelHost.profileTab.bg.alpha==.2)
assert(A.UpdateProfileHint(labelHost,mainTotems,frameStyle,true) and labelHost.profileTab.bg.alpha==.8)
mainTotems.hintVisible=false
assert(A.UpdateProfileHint(labelHost,mainTotems,frameStyle,false) and labelHost.profileTab.side=="top-start")
mainTotems.profileHint.hint=false
assert(not A.UpdateProfileHint(labelHost,mainTotems,frameStyle,false) and not labelHost.profileTab:IsShown())
print("OK profile label uses shared anchors, avoids the frame label, and switches styles")

loadModule("Switch")
local nextProfile, previousProfile = "KEYLAYERSTOTEMNEXT", "KEYLAYERSTOTEMPREV"
local contexts = {SCREENSHOT=1, [nextProfile]=2, [previousProfile]=2}
C_KeyBindings={GetBindingContextForAction=function(command) return contexts[command] end}
savedKeys.F10, savedKeys.F11, savedKeys.PRINTSCREEN = "SCREENSHOT", nextProfile, "SCREENSHOT"
local savedCount = 0
function SaveBindings() savedCount=savedCount+1 end
function SetBinding(key, command, context)
    assert(context==contexts[command or savedKeys[key]], "incorrect binding context")
    if command and savedKeys[key] then return false end
    savedKeys[key]=command
    return true
end
local ok, reason, bindingOwner=A.AssignTotemProfileKey(previousProfile,"F10")
assert(not ok and reason=="occupied" and bindingOwner=="SCREENSHOT" and savedCount==0)
assert(A.AssignTotemProfileKey(previousProfile,"F10",bindingOwner))
assert(savedKeys.F10==previousProfile and savedKeys.F11==nextProfile and savedKeys.PRINTSCREEN=="SCREENSHOT" and savedCount==1)
do
    local function checkProfileCapture()
        local rebuild = A.RebuildBars
        local shiftDown, controlDown = IsShiftKeyDown, IsControlKeyDown
        A.RebuildBars = noop
        IsShiftKeyDown, IsControlKeyDown = noop, noop
        models[2].columns, models[2].scale, models[2].gap = 4, 1, 3
        savedKeys.F10 = "SCREENSHOT"
        prompt = nil
        editor.open(2, 2)
        editor.openSection("totemBindings")
        local control = find("Assign…")
        local clearedFocus
        function GetCurrentKeyBoardFocus()
            return {ClearFocus=function() clearedFocus = true end}
        end
        control.scripts.OnClick(control, "LeftButton")
        assert(clearedFocus and not control.scripts.OnKeyDown)
        local keyboard
        for _, frame in ipairs(events) do
            if frame:GetParent() == page and frame:IsShown() and frame.keyboardEnabled then keyboard = frame; break end
        end
        assert(keyboard and control.text == "Press a key…")
        keyboard.scripts.OnKeyDown(keyboard, "F10")
        assert(prompt and not keyboard:IsShown() and savedKeys.F10 == "SCREENSHOT")
        prompt()
        assert(savedKeys.F10 == previousProfile and savedKeys.F11 == nextProfile and savedCount == 2)
        GetCurrentKeyBoardFocus = nil
        local arrows = labelHost.profileTab.profileArrows
        local before = A.TotemProfiles().active
        arrows[2].scripts.OnClick(arrows[2])
        assert(A.TotemProfiles().active ~= before)
        arrows[1].scripts.OnClick(arrows[1])
        assert(A.TotemProfiles().active == before)
        A.RebuildBars = rebuild
        IsShiftKeyDown, IsControlKeyDown = shiftDown, controlDown
    end
    checkProfileCapture()
end
print("OK conflicting F10 is reassigned on confirmation, with F11 and Print Screen intact")

local styleSource=coreSection("addon.styleKeys", "function addon.EditStyle")
assert(load("local addon=...\n"..styleSource,"frame styles","t",_G))(A)
local origin=A.NewPanel("Origin")
origin.useDefaultStyle=false
origin.activationMode,origin.layer="hold","maj"
origin.fill="AABBCC"
origin.inactiveStyle={fill="001122"}
local twoStates=A.NewPanel("Two states")
twoStates.useDefaultStyle=false
twoStates.activationMode,twoStates.layer="hold","ctrl"
twoStates.inactiveStyle={}
twoStates.x,twoStates.width=-32,377
A.CopyFrameStyle(origin,twoStates)
assert(twoStates.fill=="AABBCC" and twoStates.inactiveStyle.fill=="001122")
assert(twoStates.x==-32 and twoStates.width==377 and twoStates.layer=="ctrl")
local oneState=A.NewPanel("One state")
oneState.useDefaultStyle=true
oneState.activationMode="none"
A.CopyFrameStyle(origin,oneState)
assert(oneState.fill=="001122" and oneState.inactiveStyle==nil and oneState.useDefaultStyle)
print("OK frame style copy matches states and leaves geometry and triggers intact")

assert(A.ReservedShortcutMessage("F4",true):find("F5",1,true))
assert(A.ReservedShortcutMessage("ALT-CTRL-F4") and A.ReservedShortcutMessage("SHIFT-ALT-F4"))
assert(not A.ReservedShortcutMessage("F4") and not A.ReservedShortcutMessage("ALT-F5"))
local assigned, reserved = A.AssignTotemProfileKey(nextProfile,"ALT-F4")
assert(not assigned and reserved=="reserved" and not savedKeys["ALT-F4"] and savedKeys.F11==nextProfile)
local altBase={label="Base",slotCount=2,slots={{key="F4",command="BASE4"},{key="F5",command="BASE5"}}}
local altTarget={label="Alt",slotCount=2,slots={{command="TARGET4"},{command="TARGET5"}},sourceIndex=1,prefix="ALT-"}
local altRows=testPreview({altBase},{altTarget},{[altTarget]=true},{},{},0)
assert(altRows[1].key=="ALT-F4" and altRows[1].blocked:find("F5",1,true))
assert(altRows[2].key=="ALT-F5" and not altRows[2].blocked)
print("OK reserved Alt + F4 blocked in capture, generated preview and save")

;(function()
    loadModule("Edit")
    A.CreatePaint=function(frame) frame.paint=obj(nil,frame); frame.borderPaint=obj(nil,frame) end
    A.CreateHint=function(frame) frame.tab=obj(nil,frame) end
    A.SetMapAwareStrata=noop
    A.HasHint=function() return false end
    local painted
    A.PaintStyle=function(frame, panel) painted=panel; frame.paint.style=panel end
    A.EditStyle=function(panel) return panel end
    A.UpdateProfileHint=noop
    A.kindLabels={}
    local cursorX, cursorY=0,0
    GetCursorPosition=function() return cursorX,cursorY end
    local panels={A.NewPanel("Free"), A.NewPanel("Owned"), A.NewPanel("Micro"), A.NewPanel("Linked")}
    panels[2].kind, panels[3].kind, panels[4].kind="owned","micro","blizzard"
    KeyLayersCharLayout={panels=panels}
    local selected, committed, preview=1
    local appearance, previews
    local initial=#events
    A.SetEditor({
        current=function() return selected, panels[selected] end,
        name=function() return panels[selected].name end,
        previewAppearance=function() return appearance, previews end,
        select=function(index) selected=index; return panels[index] end,
        previewGeometry=function(...) preview={...} end,
        commitGeometry=function(...) committed={...} end,
    })
    local function bounds(panel) return 0,0,panel.width,panel.height end
    A.UpdateEditOverlays(bounds, noop, KeyLayersCharLayout, 1)
    local movers={}
    for i=initial+1,#events do
        local widget=events[i]
        if widget.moveHighlight then movers[widget.index]=widget end
    end
    assert(movers[1].moveHighlight:IsShown() and movers[2].moveHighlight:IsShown()
        and movers[3].moveHighlight:IsShown() and not movers[4].moveHighlight:IsShown())
    assert(movers[1].moveHighlight.alpha > movers[2].moveHighlight.alpha)
    appearance=true
    panels[1].fillTexture="marble"
    A.UpdateEditOverlays(bounds, noop, KeyLayersCharLayout, 1)
    assert(painted==panels[1] and movers[1].paint:IsShown() and not movers[1].moveHighlight:IsShown())
    previews={[panels[2]]={fillTexture="marble"}}
    A.UpdateEditOverlays(bounds, noop, KeyLayersCharLayout, 1)
    assert(movers[2].paint:IsShown() and not movers[2].moveHighlight:IsShown())
    assert(A.IsEditingPanel(panels[2]) and not A.IsEditingPanel(panels[3]))
    previews=nil
    appearance=false
    A.UpdateEditOverlays(bounds, noop, KeyLayersCharLayout, 1)
    assert(movers[1].moveHighlight:IsShown() and not movers[1].paint:IsShown())
    movers[2].scripts.OnClick(movers[2],"LeftButton")
    assert(selected==2)
    movers[3].scripts.OnDragStart(movers[3])
    assert(selected==3 and A.DraggedFrame()==panels[3])
    cursorX,cursorY=8,9
    movers[3].scripts.OnUpdate(movers[3])
    assert(preview[1]==3 and preview[2].x==8 and preview[2].y==9 and not committed)
    cursorX,cursorY=11,13
    movers[3].scripts.OnUpdate(movers[3])
    assert(preview[1]==3 and preview[2].x==11 and preview[2].y==13 and not committed)
    movers[3].scripts.OnDragStop(movers[3])
    assert(committed[1]==3 and committed[2]==11 and committed[3]==13)
    A.SetEditor(nil)
    assert(not movers[1]:IsVisible() and not movers[2]:IsVisible() and not movers[3]:IsVisible())
    print("OK movable frame highlights, click selection, selection on drag and cleanup")
end)()

;(function()
    local panel=A.NewPanel("Drag container")
    KeyLayersCharLayout={panels={panel},barWorkspace={mode="KeyLayers",bars={},nextFrame=1}}
    local first=M.new("action",panel,true)
    first.name="Drag first"
    function A.OwnedParentGeometry(parent) return A.MovingFrameGeometry(parent) or parent end
    local cursorX,cursorY=0,0
    GetCursorPosition=function() return cursorX,cursorY end
    local preview
    A.Refresh=function()
        preview=M.envelope(panel,A.OwnedParentGeometry(panel))
    end
    A.SetEditor({
        current=function() end,
        dragPanel=function(index) return KeyLayersCharLayout.panels[index] end,
        commitGeometry=function(index,x,y)
            assert(index==1)
            panel.x,panel.y=x,y
            A.RebuildBars()
            A.Refresh()
        end,
    })
    A.RebuildBars()
    local start=#events
    local dragEditor=A.CreateBarEditor(page,controls,ctx)
    local function handle(text)
        for i=start+1,#events do
            local widget=events[i]
            if widget.text==text and widget:IsShown() and widget.scripts.OnDragStart then return widget end
        end
        error("missing bar handle "..text)
    end
    dragEditor.open(1,first.id)
    local firstHandle=handle(first.name)
    local runtime=A.ownedBars[first.id]
    firstHandle.scripts.OnDragStart(firstHandle)
    cursorX,cursorY=50,25
    firstHandle.scripts.OnUpdate(firstHandle)
    assert(panel.x==0 and panel.y==0 and first.x==0 and first.y==0)
    assert(preview.x==50 and preview.y==25 and runtime.placedX==50 and runtime.placedY==25)
    firstHandle.scripts.OnDragStop(firstHandle)
    assert(panel.x==50 and panel.y==25 and first.x==0 and first.y==0)

    local second=M.new("action",panel,true)
    assert(second)
    second.name="Drag second"
    A.RebuildBars()
    dragEditor.open(1,first.id)
    local secondRuntime=A.ownedBars[second.id]
    local otherX,otherY=secondRuntime.placedX,secondRuntime.placedY
    local initialWidth=M.envelope(panel,panel).width
    firstHandle.scripts.OnDragStart(firstHandle)
    cursorX=cursorX+90
    firstHandle.scripts.OnUpdate(firstHandle)
    assert(preview.width>initialWidth and panel.x==50 and first.x==0)
    assert(secondRuntime.placedX==otherX and secondRuntime.placedY==otherY)
    firstHandle.scripts.OnDragStop(firstHandle)
    assert(first.x==90 and panel.x==50 and preview.width>initialWidth)
    A.SetEditor(nil)
    print("OK red handle moves a single-bar frame and resizes a multi-bar frame live")
end)()
