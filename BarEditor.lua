local _,A=...
local M,tr=A.BarLayout,A.Translate
local independent=tr("Indépendantes","Independent")
local kinds={action=tr("Barre d’action","Action bar"),stance=tr("Barre de classe","Class bar"),totem=tr("Totems","Totems")}
local visibility={always=tr("Toujours visible","Always visible"),combat=tr("En combat","In combat"),hover=tr("Au survol","On hover"),hidden=tr("Masquée","Hidden")}

local barSections={
    {key="attachment", title=tr("Rattachement", "Attachment")},
    {key="layout", title=tr("Disposition", "Layout")},
    {key="appearance", title=tr("Apparence", "Appearance")},
    {key="cooldown", title=tr("Recharge", "Cooldown")},
    {key="totems", title=tr("Totems", "Totems")},
    {key="totemStyle", title=tr("Style de la durée", "Duration style")},
    {key="totemBindings", title=tr("Configuration des totems", "Totem setup")},
    {key="auraStyle", title=tr("Style de la durée", "Duration style")},
    {key="totemDismiss", title=tr("Icône de destruction du totem", "Totem dismiss icon")},
    {key="position", title=tr("Position et dimensions", "Position and size")},
}

local globalSections = {
    {key="interface", title=tr("Masquage de l’interface", "Interface visibility")},
    {key="buttons", title=tr("Style des boutons", "Button style")},
    {key="hotkeys", title=tr("Affichage des raccourcis", "Keybinding display")},
    {key="editing", title=tr("Édition des actions", "Action editing")},
}

local function hasBarSection(spec, kind, isTemplate, templateKind)
    return (not isTemplate or (spec.key~="attachment" and spec.key~="position"))
        and (not spec.key:match("^totem") or kind=="totem")
        and (spec.key~="auraStyle" or kind=="action" and (not isTemplate or templateKind))
end

function A.CreateBarEditor(page,ui,context)
    local selected,frameIndex,collapsed,branches=nil,nil,false,{}
    -- Frames persist until reload. Reuse rows when the tree or inspector changes.
    local pools,used,outline,handles={},{},{},{}
    local external
    local state,panel,bar,refresh
    local inheritedView, templateScope = false, nil
    local globalSection
    local globalPages, globalTitle = {}, nil
    local sectionKey
    local hoverPage = false
    local hoverTitle = tr("Assigner par survol","Bind by hovering")
    local right
    local function revealSection(key)
        sectionKey=key
        refresh()
        right:SetVerticalScroll(0)
    end
    local function clear()
        for kind,n in pairs(used) do
            for i=1,n do pools[kind][i]:Hide() end
        end
        wipe(used)
        for _,w in ipairs(outline) do w:Hide() end
    end
    local function acquire(kind,parent,x,y,make)
        local i=(used[kind] or 0)+1
        used[kind]=i
        pools[kind]=pools[kind] or {}
        local w=pools[kind][i]
        if not w then w=make(); pools[kind][i]=w end
        w:SetParent(parent)
        if w.SetFrameLevel then
            w:SetFrameLevel(parent:GetFrameLevel()+2)
        end
        w:ClearAllPoints()
        w:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y)
        w:Show()
        return w
    end
    local function btn(parent,caption,x,y,width,fn)
        local w=acquire("button",parent,x,y,function() return ui.button(parent,caption,x,y,width,fn) end)
        w:SetWidth(width)
        w:SetText(caption)
        w:SetScript("OnClick",function() if not InCombatLockdown() then fn() end end)
        return w
    end
    local function title(parent,caption,x,y)
        local w=acquire("label",parent,x,y,function() return ui.label(parent,caption,x,y) end)
        w:SetText(caption)
        w:SetTextColor(1,.82,0)
        return w
    end
    local function dropdown(p,x,y,width,text,build)
        local w=acquire("menu",p,x,y,function()
            return ui.menu(p,x,y,width,function() end)
        end)
        w:SetWidth(width)
        w:SetupMenu(function(_,root) if not InCombatLockdown() then build(root) end end)
        w:OverrideText(text)
        return w
    end
    local function apply() A.RebuildBars(); A.Refresh(); refresh() end
    local function pickBar(b)
        external=nil
        hoverPage=false
        selected=b.id
        sectionKey=nil
        local _,idx=M.frame(b)
        frameIndex=idx
        refresh()
    end
    local heading = page:CreateTexture(nil,"BACKGROUND")
    heading:SetPoint("TOPLEFT",10,-3)
    heading:SetPoint("TOPRIGHT",-10,-3)
    heading:SetHeight(35)
    heading:SetColorTexture(unpack(M.workspaceSelectionColor))
    local titleX = context.parent and 18 or 54
    local barTitle = ui.label(page, "", titleX, -27, "GameFontNormalLarge")
    barTitle:SetWidth(325)
    barTitle:SetJustifyH("LEFT")
    barTitle:SetWordWrap(false)
    barTitle:Hide()

    local rename = A.CreateRenameButton(page, tr("Renommer la barre", "Rename bar"))
    local nameInput = CreateFrame("EditBox", nil, page, "InputBoxTemplate")
    nameInput:SetPoint("TOPLEFT", titleX + 5, -23)
    nameInput:SetSize(315, 23)
    nameInput:SetAutoFocus(false)
    nameInput:SetMaxLetters(48)
    nameInput:Hide()
    rename:Hide()

    local renamingBar
    local function cancelRename()
        renamingBar = nil
        nameInput:ClearFocus()
        nameInput:Hide()
    end
    rename:SetScript("OnClick", function()
        if not bar or templateScope or InCombatLockdown() then return end
        renamingBar = bar
        nameInput:SetText(bar.name)
        barTitle:Hide()
        rename:Hide()
        nameInput:Show()
        nameInput:SetFocus()
        nameInput:HighlightText()
    end)
    nameInput:SetScript("OnEditFocusLost", function(self)
        local target = renamingBar
        renamingBar = nil
        self:Hide()
        if not target or not page:IsVisible() then return end
        local name = self:GetText():gsub("|", ""):match("^%s*(.-)%s*$")
        if target == bar and not InCombatLockdown() and name ~= "" and name ~= target.name then
            target.name = name
            apply()
        else
            refresh()
        end
    end)
    nameInput:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    nameInput:SetScript("OnEscapePressed", function()
        cancelRename()
        refresh()
    end)
    local surface = page:CreateTexture(nil,"BACKGROUND")
    surface:SetPoint("TOPLEFT",10,-71)
    surface:SetPoint("BOTTOMRIGHT",-10,24)
    surface:SetColorTexture(unpack(M.workspacePageColor))
    right=CreateFrame("ScrollFrame",nil,page,"UIPanelScrollFrameTemplate")
    right:SetPoint("TOPLEFT",22,-82)
    right:SetPoint("TOPRIGHT",-32,-82)
    right:SetPoint("BOTTOMRIGHT",-32,32)
    right:EnableMouseWheel(true)
    right:SetScript("OnMouseWheel", function(self, delta)
        local target = self:GetVerticalScroll() - delta * (bar and bar.kind == "totem" and 18 or 32)
        self:SetVerticalScroll(math.max(0, math.min(self:GetVerticalScrollRange(), target)))
    end)
    local form=CreateFrame("Frame",nil,right)
    right:SetScrollChild(form)
    local function selectMode(mode)
        local api=C_AddOns
        local wantsBT=mode=="Bartender4"
        local function change()
            if InCombatLockdown() then return end
            external=nil
            state.mode=mode
            M.syncProvider(KeyLayersCharLayout)
            A.RebuildBars()
            A.Refresh()
            refresh()
        end
        local player=UnitGUID and UnitGUID("player")
        local enabled=api and api.GetAddOnEnableState and M.installed() and api.GetAddOnEnableState("Bartender4",player)
        if (wantsBT~=not not M.available() or (enabled and wantsBT~=(enabled>0))) and api and M.installed() then
            ui.confirm(tr("Activer ou désactiver Bartender4 pour ce personnage et recharger l’interface ?","Switch Bartender4 on or off for this character and reload the UI?"),function()
                if InCombatLockdown() then return end
                if not wantsBT then M.rememberBartenderFrames(KeyLayersCharLayout) end
                if wantsBT then api.EnableAddOn("Bartender4",player) else api.DisableAddOn("Bartender4",player) end
                if api.GetAddOnEnableState and (api.GetAddOnEnableState("Bartender4",player)>0)~=wantsBT then
                    UIErrorsFrame:AddMessage(tr("Impossible de modifier l’état de Bartender4.","Could not change the Bartender4 enable state."))
                    return
                end
                if api.SaveAddOns then api.SaveAddOns() end
                state.mode=mode
                ReloadUI()
            end)
        elseif not wantsBT or M.available() then change() end
    end
    local function showGhosts(plan,p)
        local geo=A.GetPanelGeometry(p)
        for i,item in ipairs(plan) do
            local w=outline[i]
            if not w then
                w=CreateFrame("Frame",nil,UIParent,"BackdropTemplate")
                w:SetFrameStrata("HIGH")
                w:SetBackdrop({edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=2})
                w:SetBackdropBorderColor(.4,1,.6,1)
                outline[i]=w
            end
            w:ClearAllPoints()
            w:SetPoint("CENTER",UIParent,"CENTER",geo.x+item.x,geo.y+item.y)
            w:SetSize(M.size(item.bar,item.scale)); w:Show()
        end
    end
    local capturing, captureButtons = false, {}
    local profileCapture
    local profileKeyboard = CreateFrame("Frame", nil, page)
    profileKeyboard:SetFrameStrata("FULLSCREEN_DIALOG")
    profileKeyboard:SetFrameLevel(100)
    profileKeyboard:Hide()
    profileKeyboard:RegisterEvent("PLAYER_REGEN_DISABLED")
    profileKeyboard:SetScript("OnEvent", function()
        if profileCapture then profileCapture() end
    end)
    local attach
    local function bindCommand(command,label,key)
        if InCombatLockdown() then return end
        if key=="ESCAPE" then capturing=false; refresh(); return end
        if key:match("SHIFT$") or key:match("CTRL$") or key:match("ALT$") then return end
        local warning = A.ReservedShortcutMessage(key, IsAltKeyDown())
        if warning then
            if UIErrorsFrame then UIErrorsFrame:AddMessage(warning) end
            return
        end
        local binding=(IsAltKeyDown() and "ALT-" or "")..(IsControlKeyDown() and "CTRL-" or "")..
            (IsShiftKeyDown() and "SHIFT-" or "")..key
        local bindingContext=C_KeyBindings and C_KeyBindings.GetBindingContextForAction
            and C_KeyBindings.GetBindingContextForAction(command)
        local current=GetBindingAction(binding,false,bindingContext) or ""
        local effective=GetBindingAction(binding,true) or ""
        if effective~="" and effective~=current and effective~=command then
            UIErrorsFrame:AddMessage(tr("Touche temporairement utilisée par %s.","Key temporarily used by %s."):format(effective))
            return
        end
        local function save()
            if InCombatLockdown() or (GetBindingAction(binding,false,bindingContext) or "")~=current then return end
            if SetBinding(binding,command,bindingContext) then SaveBindings(GetCurrentBindingSet()); A.RebuildBars(); refresh()
                if UIErrorsFrame then UIErrorsFrame:AddMessage(binding.." → "..label) end
            elseif UIErrorsFrame then UIErrorsFrame:AddMessage(tr("Raccourci refusé","Binding rejected")) end
        end
        if current~="" and current~=command then
            ui.confirm(tr("%s est affecté à « %s ». Réattribuer cette touche à « %s » ?",
                "%s is assigned to “%s”. Reassign this key to “%s”?"):format(binding,current,label),save)
        else save() end
    end
    local function showCapture(f)
        for i,b in ipairs(f.buttons) do
            if b:IsShown() then
                local name=b:GetName()
                local h=captureButtons[name]
                if not h then
                    h=CreateFrame("Button",nil,UIParent,"UIPanelButtonTemplate")
                    h:SetFrameStrata("HIGH"); h:SetFrameLevel(9600)
                    h:SetText(tostring(i))
                    h:SetScript("OnEnter",function(w)
                        if InCombatLockdown() then return end
                        w:EnableKeyboard(true); w:SetPropagateKeyboardInput(false)
                        GameTooltip:SetOwner(w,"ANCHOR_RIGHT")
                        GameTooltip:SetText(tr("Appuie sur une touche · Échap pour annuler","Press a key · Escape to cancel"))
                        GameTooltip:Show()
                    end)
                    local function release(w) w:EnableKeyboard(false); GameTooltip:Hide() end
                    h:SetScript("OnLeave",release); h:SetScript("OnHide",release)
                    h:SetScript("OnKeyDown",function(_,key) bindCommand("CLICK "..b:GetName()..":LeftButton",b.model.name,key) end)
                    captureButtons[name]=h
                end
                h:ClearAllPoints(); h:SetAllPoints(b); h:Show()
            end
        end
    end
    local function showHandles()
        for _,h in pairs(handles) do h:Hide() end
        for _,h in pairs(captureButtons) do h:Hide() end
        if not page:IsVisible() or not context.editing() or (hoverPage and not capturing) then return end
        for id,f in pairs(A.ownedBars) do
            if f.model and f:IsShown() and capturing then
                if (selected and id==selected) or (not selected and (not frameIndex or select(2,M.frame(f.model))==frameIndex)) then showCapture(f) end
            elseif f.model and f:IsShown() then
                local h=handles[id]
                if not h then
                    h=CreateFrame("Button",nil,UIParent,"UIPanelButtonTemplate")
                    h:SetFrameStrata("HIGH"); h:SetFrameLevel(9500)
                    h:RegisterForDrag("LeftButton")
                    h:RegisterForClicks("LeftButtonUp","RightButtonUp")
                    h:SetScript("OnClick",function(self,button)
                        if button=="RightButton" then
                            MenuUtil.CreateContextMenu(self,function(_,root)
                                root:CreateButton(independent,function() M.attach(f.model,nil); pickBar(f.model); apply() end)
                                for _,p in ipairs(KeyLayersCharLayout.panels) do
                                    if p.kind=="free" or p.kind=="owned" then
                                        root:CreateButton(p.name,function() if M.attachInside(f.model,p) then pickBar(f.model); apply() end end)
                                    end
                                end
                            end)
                            return
                        end
                        pickBar(f.model)
                    end)
                    h:SetScript("OnDragStart",function(self)
                        if InCombatLockdown() then return end
                        local parent,parentIndex=M.frame(f.model)
                        if parent and M.singleFrameBar(parent)==f.model then
                            self.movingParent=A.BeginAttachedBarDrag(self,parentIndex)
                            if self.movingParent then A.ShowBarOutline(nil) end
                            return
                        end
                        self.cx,self.cy=GetCursorPosition()
                        self.bx,self.by=f.placedX,f.placedY
                        self:SetScript("OnUpdate",function(w)
                            if InCombatLockdown() then return end
                            local x,y=GetCursorPosition()
                            local scale=UIParent:GetEffectiveScale()
                            f.model.dragging=true
                            local nextX,nextY=w.bx+(x-w.cx)/scale,w.by+(y-w.cy)/scale
                            if nextX~=f.placedX or nextY~=f.placedY then
                                A.PlaceOwnedBar(f,nextX,nextY)
                                A.Refresh()
                                A.ShowBarOutline(f)
                            end
                        end)
                    end)
                    h:SetScript("OnHide",function(self)
                        if self.movingParent then self.movingParent=nil; A.FinishAttachedBarDrag(self) end
                        if not self.cx then return end
                        self:SetScript("OnUpdate",nil)
                        self.cx=nil
                        if f.model then
                            f.model.dragging=nil
                            if not InCombatLockdown() then A.PlaceOwnedBar(f,M.position(f.model)) end
                        end
                    end)
                    h:SetScript("OnDragStop",function(self)
                        if self.movingParent then
                            self.movingParent=nil
                            A.FinishAttachedBarDrag(self)
                            return
                        end
                        self:SetScript("OnUpdate",nil)
                        if f.model then f.model.dragging=nil end
                        if not self.cx then return end
                        local startX,startY=self.cx,self.cy
                        self.cx,self.cy=nil,nil
                        if InCombatLockdown() then return end
                        local x,y=GetCursorPosition()
                        local scale=UIParent:GetEffectiveScale()
                        local bar = f.model
                        if not bar then return end
                        local target
                        if not M.frame(bar) then
                            target=M.dropTarget(x/scale-UIParent:GetWidth()/2,y/scale-UIParent:GetHeight()/2)
                        end
                        local dx, dy = (x-startX)/scale, (y-startY)/scale
                        if target then attach(bar,target)
                        else
                            bar.x, bar.y = bar.x + dx, bar.y + dy
                            apply()
                        end
                    end)
                    handles[id]=h
                end
                h:ClearAllPoints()
                h:SetPoint("BOTTOM",f,"TOP",0,3)
                h:SetFrameLevel(selected==id and 9550 or 9500)
                h:SetSize(math.max(36,math.min(f:GetWidth()*f:GetScale(),130)),24)
                h:SetText(f.model.name); h:Show()
            end
        end
    end
    local navigation
    local function noPlacement()
        if UIErrorsFrame then UIErrorsFrame:AddMessage(tr("Espace insuffisant autour du cadre.","Not enough space around the frame.")) end
    end
    attach = function(bar,index)
        if InCombatLockdown() then return end
        local target=KeyLayersCharLayout.panels[index]
        if not target or (target.kind~="free" and target.kind~="owned") then return end
        if not M.attachInside(bar,target) then noPlacement(); return end
        pickBar(bar)
        apply()
    end
    local function wrapBars(bars)
        if InCombatLockdown() then return end
        local index=M.wrap(bars,8,tr("Nouveau cadre","New frame"))
        if not index then return end
        if context.placeNew then context.placeNew(KeyLayersCharLayout.panels[index]) end
        apply()
        context.openFrame(index)
    end
    local function choose(item)
        if item.globalSettings then
            context.openGlobal(item.globalSection)
        elseif item.frameDefaults then
            if context.openFrameDefaults then context.openFrameDefaults(item.templateKind, item.section) end
        elseif item.barDefaults then
            context.openBar(nil, nil, function()
                templateScope = item.templateKind or "global"
                revealSection(item.barSection)
            end)
        elseif item.bar then
            context.openBar(item.index,item.bar.id,item.barSection and function() revealSection(item.barSection) end)
        elseif item.bindings then context.openBindings(item.index)
        elseif item.index then context.openFrame(item.index, item.section)
        elseif item.hoverBindings then
            context.openBar(nil, nil, function()
                hoverPage = true
                refresh()
            end)
        elseif item.framesRoot then context.openBar(nil, nil) end
    end
    local function frameSections(destination, dimensions)
        local entries = {}
        local function add(title, section)
            local entry = A.Copy(destination)
            entry.text, entry.section = title, section
            entries[#entries+1] = entry
        end
        add(tr("Rattachement", "Attachment"), "target")
        if dimensions then add(dimensions, "geometry") end
        if not destination.frameDefaults then add(tr("Activation", "Activation"), "activation") end
        add(tr("Apparence", "Appearance"), "appearance")
        add(tr("Étiquette de cadre", "Frame label"), "frameHint")
        add(tr("Transition", "Transition"), "transition")
        add(tr("Niveau d’affichage", "Display level"), "display")
        local activeScope, activeSection
        if context.frameTemplate then activeScope, activeSection = context.frameTemplate() end
        if not activeScope or activeScope~=(destination.templateKind or "global") then activeSection=nil end
        if not destination.frameDefaults and context.frameSection then activeSection=context.frameSection(destination.index) end
        for _, entry in ipairs(entries) do
            entry.active = entry.section == activeSection
        end
        return entries
    end
    if context.parent then
        navigation = A.CreateWorkspaceTree(context.parent, choose, function(bar, index)
            if index==0 then
                local function wrap()
                    wrapBars({bar})
                end
                if context.isFrame() then context.openBar(nil,nil,wrap) else wrap() end
            elseif context.isFrame() then
                context.openBar(index,bar.id,function() attach(bar,index) end)
            else attach(bar,index) end
        end,function(item)
            local target=item and item.frame and KeyLayersCharLayout.panels[item.index]
            A.SetHoveredPanel(target or (page:IsVisible() and not bar and panel) or nil)
        end,function()
            inheritedView = not inheritedView
            if context.viewChanged then context.viewChanged() end
        end)
    end
    local function updateTree(shown, currentFrame, draftName, reveal)
        if not navigation then return end
        navigation:SetShown(shown)
        if not shown then return end
        local workspace = M.init(KeyLayersCharLayout)
        local globalActive = context.isGlobal and context.isGlobal()
        local globalItems = {}
        for _, spec in ipairs(globalSections) do
            globalItems[#globalItems+1] = {text=spec.title, globalSettings=true, globalSection=spec.key,
                active=globalActive and globalSection==spec.key}
        end
        local globalSettings = {text=tr("Réglage global", "Global settings"), key="globalSettings", heading=true,
            globalSettings=true, active=globalActive, children=globalItems, defaultCollapsed=true}
        local function barTemplate(title, kind)
            local scope = kind or "global"
            local active = page:IsShown() and templateScope==scope
            local activeSection = sectionKey
            if inheritedView or kind then activeSection = activeSection or "layout" end
            local children = {}
            for _, spec in ipairs(barSections) do
                if hasBarSection(spec, kind or "action", true, kind) then
                    children[#children+1] = {text=spec.title,barDefaults=true,templateKind=kind,barSection=spec.key,
                        active=active and spec.key==activeSection}
                end
            end
            return {text=title,key="barStyles:"..scope,heading=not kind,barDefaults=true,
                templateKind=kind,active=active,children=children,defaultCollapsed=kind~=nil}
        end
        if inheritedView then
            local active = context.frameTemplate and context.frameTemplate()
            local function template(title, kind)
                local destination = {frameDefaults=true, templateKind=kind}
                return {text=title, key="frameStyles:" .. (kind or "global"), frameDefaults=true, templateKind=kind,
                    heading=kind==nil, active=active==(kind or "global"), defaultCollapsed=kind~=nil,
                    children=frameSections(destination, tr("Dimensions", "Size"))}
            end
            local frames = template(tr("Cadres", "Frames"))
            frames.children = {
                template(tr("Cadre libre", "Free frame"), "free"),
                template(tr("Cadre KeyLayers", "KeyLayers frame"), "owned"),
                template(tr("Cadre Blizzard", "Blizzard frame"), "blizzard"),
            }
            local bars = barTemplate(tr("Barres", "Bars"))
            bars.children = {
                barTemplate(kinds.action, "action"),
                barTemplate(tr("Barre de totems", "Totem bar"), "totem"),
            }
            navigation:Update({
                globalSettings, frames, bars,
            }, nil, nil, true)
            return
        end
        local function barItem(child,index)
            local sections={}
            local active=page:IsShown() and selected==child.id
            for _,spec in ipairs(barSections) do
                if hasBarSection(spec, child.kind) then
                    local row = {text=spec.title,bar=child,index=index,barSection=spec.key,
                        active=active and spec.key==(sectionKey or "attachment")}
                    if spec.key=="position" then table.insert(sections, 2, row) else sections[#sections+1]=row end
                end
            end
            return {text=child.name,bar=child,index=index,active=active,
                key="bar:"..child.id,children=sections,defaultCollapsed=true}
        end
        local frameItems = {}
        for index, target in ipairs(KeyLayersCharLayout.panels) do
            local entries = frameSections({index=index}, tr("Position et dimensions", "Position and size"))
            if M.totemBar(target) then
                entries[#entries+1] = {text=tr("Étiquette de profil", "Totem profile label"), index=index, section="profileHint",
                    active=context.frameSection and context.frameSection(index)=="profileHint"}
            end
            if M.hasAssignableBars(target) then
                entries[#entries+1]={text=tr("Assignation des raccourcis","Assign keybindings"),index=index,bindings=true,
                    active=context.bindingFrame and context.bindingFrame()==index}
            end
            if M.mode(workspace) == "KeyLayers" then
                for _, child in ipairs(M.children(target)) do
                    entries[#entries+1] = barItem(child,index)
                end
            end
            frameItems[#frameItems+1] = {text=index==currentFrame and draftName and draftName~="" and draftName or target.name,
                key="frame:"..index, index=index, frame=true, drop=(target.kind=="free" or target.kind=="owned") and target, children=entries, active=index==currentFrame, defaultCollapsed=index~=currentFrame}
        end
        if M.mode(workspace)=="KeyLayers" then
            table.insert(frameItems, 1, {text=hoverTitle, hoverBindings=true, active=page:IsShown() and hoverPage})
        end
        local items = {
            globalSettings,
            {text=tr("Cadres", "Frames"), key="frames", heading=true, framesRoot=true, children=frameItems,
                active=page:IsShown() and (hoverPage or not selected and not frameIndex and not templateScope)},
        }
        local bars = barTemplate(tr("Barres", "Bars"))
        bars.key = "barDefaults"
        if M.mode(workspace) == "KeyLayers" then
            for id = 1, 12 do
                local child = workspace.bars[id]
                if child and not child.parent then
                    bars.children[#bars.children+1] = barItem(child, select(2,M.frame(child)))
                end
            end
        end
        items[#items+1] = bars
        navigation:Update(items,currentFrame,page:IsShown() and selected or nil,inheritedView,reveal)
    end
    local function providerModes()
        local modes = {"KeyLayers", "Blizzard"}
        if M.installed() then modes[#modes+1] = "Bartender4" end
        return modes
    end
    local function providerMenu(parent,x,y,width)
        local current=M.init(KeyLayersCharLayout)
        return dropdown(parent,x,y,width,M.mode(current),function(root)
            for _,mode in ipairs(providerModes()) do
                root:CreateRadio(mode,function() return M.mode(current)==mode end,function()
                    state=current
                    selectMode(mode)
                end)
            end
        end)
    end
    if context.global then
        local heading = CreateFrame("Frame", nil, context.global, "BackdropTemplate")
        heading:SetPoint("TOPLEFT")
        heading:SetPoint("TOPRIGHT")
        heading:SetHeight(35)
        heading:SetBackdrop({bgFile=[[Interface\Buttons\WHITE8X8]]})
        heading:SetBackdropColor(unpack(M.workspaceSelectionColor))
        globalTitle = ui.label(heading, globalSections[1].title, 12, -9, "GameFontNormalLarge")
        local function currentSection() return globalSection or globalSections[1].key end
        local sections = ui.menu(heading, 0, -5, 201, function(root)
            for _, spec in ipairs(globalSections) do
                ui.radio(root, spec.title, spec.key, currentSection, context.openGlobal)
            end
        end)
        sections:ClearAllPoints()
        sections:SetPoint("TOPRIGHT", -12, -5)
        sections:SetSize(201, 24)
        sections:OverrideText(tr("Rubriques", "Sections"))
        for _, spec in ipairs(globalSections) do
            local panel = CreateFrame("Frame", nil, context.global, "BackdropTemplate")
            panel:SetPoint("TOPLEFT", 0, -41)
            panel:SetPoint("BOTTOMRIGHT")
            panel:SetBackdrop({bgFile=[[Interface\Buttons\WHITE8X8]]})
            panel:SetBackdropColor(unpack(M.workspacePageColor))
            panel:SetShown(spec == globalSections[1])
            globalPages[spec.key] = panel
        end
        local interface, buttons, hotkeys, editing = globalPages.interface, globalPages.buttons,
            globalPages.hotkeys, globalPages.editing
        ui.label(interface,tr("Fournisseur des barres","Bar provider"),18,-20)
        local provider=ui.menu(interface,220,-14,245,function(root)
            local current=M.init(KeyLayersCharLayout)
            for _,mode in ipairs(providerModes()) do
                root:CreateRadio(mode,function() return M.mode(current)==mode end,function()
                    state=current
                    selectMode(mode)
                    context.global:GetScript("OnShow")()
                end)
            end
        end)
        local function setting(parent,key,title,y)
            return ui.check(parent,title,18,y,function(value)
                if InCombatLockdown() then return end
                M.init(KeyLayersCharLayout)[key]=value
                A.RebuildBars()
            end)
        end
        local stock=setting(interface,"hideBlizzard",tr("Masquer les barres d’action Blizzard","Hide Blizzard action bars"),-56)
        local art=setting(interface,"hideBlizzardArt",tr("Masquer les éléments décoratifs Blizzard","Hide Blizzard bar artwork"),-90)
        local bags=setting(interface,"hideBlizzardBags",tr("Masquer les sacs Blizzard","Hide Blizzard bags"),-124)
        local totems=setting(interface,"hideBlizzardTotems",tr("Masquer la barre de totems Blizzard","Hide Blizzard totem bar"),-158)
        local activeTotems = setting(interface,"hideBlizzardActiveTotems",
            tr("Masquer les totems sous le portrait et les gérer avec KeyLayers",
                "Hide totems under the portrait and manage them with KeyLayers"), -192)
        local function colorSetting(key,default,title,y)
            ui.label(buttons,title,18,y-6)
            local swatch=CreateFrame("Button",nil,buttons,"BackdropTemplate")
            swatch:SetPoint("TOPLEFT",280,y)
            swatch:SetSize(28,24)
            swatch:SetBackdrop({bgFile=[[Interface\Buttons\WHITE8X8]],edgeFile=[[Interface\Buttons\WHITE8X8]],edgeSize=1})
            swatch:SetBackdropBorderColor(.8,.8,.8,1)
            local function refreshColor()
                local hex=M.init(KeyLayersCharLayout)[key] or default
                local r,g,b=tonumber(hex:sub(1,2),16)/255,tonumber(hex:sub(3,4),16)/255,tonumber(hex:sub(5,6),16)/255
                swatch:SetBackdropColor(r,g,b,1)
                return r,g,b
            end
            swatch:SetScript("OnClick",function()
                if InCombatLockdown() then return end
                local workspace=M.init(KeyLayersCharLayout)
                local previous=workspace[key]
                local r,g,b=refreshColor()
                local function applyColor(hex)
                    workspace[key]=hex
                    refreshColor()
                    A.RebuildBars()
                end
                ColorPickerFrame:SetupColorPickerAndShow({r=r,g=g,b=b,
                    swatchFunc=function()
                        local red,green,blue=ColorPickerFrame:GetColorRGB()
                        applyColor(("%02X%02X%02X"):format(math.floor(red*255+.5),math.floor(green*255+.5),math.floor(blue*255+.5)))
                    end,
                    cancelFunc=function() applyColor(previous) end})
            end)
            return refreshColor
        end
        local showHover=colorSetting("actionHoverColor","65CCFF",tr("Survol des boutons d’action","Action button hover"),-14)
        local showPress=colorSetting("actionPressColor","FFD250",tr("Appui sur un bouton","Button press"),-49)
        local showBlockedPress=colorSetting("actionBlockedPressColor","FF4242",tr("Appui sur une action indisponible","Press on an unavailable action"),-84)
        local opacityLabel=ui.label(buttons,"",18,-127)
        local opacity=CreateFrame("Slider",nil,buttons,"OptionsSliderTemplate")
        opacity:SetPoint("TOPLEFT",280,-123)
        opacity:SetSize(180,17)
        opacity:SetMinMaxValues(0,100)
        opacity:SetValueStep(5)
        opacity:SetObeyStepOnDrag(true)
        local refreshing
        local function opacityCaption(value)
            opacityLabel:SetText(tr("Opacité de l’appui : %d%%","Press opacity: %d%%"):format(math.floor(value+.5)))
        end
        opacity:SetScript("OnValueChanged",function(_,value)
            opacityCaption(value)
            if refreshing or InCombatLockdown() then return end
            M.init(KeyLayersCharLayout).actionPressOpacity=value/100
            A.RebuildBars()
        end)
        ui.label(hotkeys,tr("Afficher les raccourcis","Show keybindings"),18,-20)
        local refreshHotkeyMode=A.CreateHotkeyModeMenu(hotkeys,ui,220,-14)
        local style = CreateFrame("Frame", nil, hotkeys)
        style:SetPoint("TOPLEFT", 0, -56)
        style:SetPoint("BOTTOMRIGHT")
        local refreshHotkeyStyle=A.CreateHotkeyStylePage(style,ui)
        local lockActions = setting(editing,"lockActions", tr("Verrouiller le déplacement des actions",
            "Lock action dragging"), -14)
        local modifiers = {{"SHIFT", tr("Maj", "Shift")}, {"CTRL", "Ctrl"}, {"ALT", "Alt"}}
        local function modifierValue() return M.init(KeyLayersCharLayout).actionEditModifier end
        local modifierMenu
        local function refreshModifier()
            for _, choice in ipairs(modifiers) do
                if choice[1] == modifierValue() then modifierMenu:OverrideText(choice[2]); return end
            end
        end
        ui.label(editing, tr("Modificateur d’édition", "Action edit modifier"), 18, -60)
        modifierMenu = ui.menu(editing, 220, -54, 245, function(root)
            for _, choice in ipairs(modifiers) do
                ui.radio(root, choice[2], choice[1], modifierValue, function(value)
                    if InCombatLockdown() then return end
                    M.init(KeyLayersCharLayout).actionEditModifier = value
                    A.RebuildBars()
                    refreshModifier()
                end)
            end
        end)
        ui.label(editing, tr("Maintiens ce modificateur pour déplacer une action verrouillée ou la retirer par clic droit.",
            "Hold this modifier to drag a locked action or remove it with a right-click."), 18, -88,
            "GameFontHighlightSmall")
        context.global:SetScript("OnShow",function()
            refreshHotkeyMode()
            refreshHotkeyStyle()
            showHover()
            showPress()
            showBlockedPress()
            refreshing=true
            local value=(M.init(KeyLayersCharLayout).actionPressOpacity or .55)*100
            opacity:SetValue(value)
            opacityCaption(value)
            refreshing=false
            local current=M.init(KeyLayersCharLayout)
            provider:OverrideText(M.mode(current))
            stock:SetChecked(current.hideBlizzard~=false)
            art:SetChecked(current.hideBlizzardArt==true)
            bags:SetChecked(current.hideBlizzardBags==true)
            totems:SetChecked(current.hideBlizzardTotems==true)
            activeTotems:SetChecked(current.hideBlizzardActiveTotems==true)
            lockActions:SetChecked(current.lockActions)
            refreshModifier()
        end)
    end
    local function openGlobalSection(key)
        local previous = globalSection or globalSections[1].key
        globalSection = key or previous
        if globalSection ~= previous then
            globalPages[previous]:Hide()
            globalPages[globalSection]:Show()
            for _, spec in ipairs(globalSections) do
                if spec.key == globalSection then globalTitle:SetText(spec.title); break end
            end
        end
        if context.isGlobal() then updateTree(true) end
    end
    refresh=function()
        clear()
        state=M.init(KeyLayersCharLayout)
        if hoverPage and (inheritedView or M.mode(state)~="KeyLayers") then
            hoverPage, capturing = false, false
        end
        if capturing and not context.editing() then capturing=false end
        local globalBarsPage = templateScope=="global" and not inheritedView
        local barsOverview = globalBarsPage and not sectionKey
        local templateKind = templateScope ~= "global" and templateScope or nil
        bar=templateScope and not barsOverview and M.barTemplate(KeyLayersCharLayout, templateKind)
            or state.bars[selected]
        panel=KeyLayersCharLayout.panels[frameIndex]
        A.barPreview=page:IsVisible() and not templateScope and bar or nil
        if page:IsVisible() then
            A.SetHoveredPanel(not bar and panel or nil)
            A.ShowBarOutline(bar and A.ownedBars[bar.id])
        end
        if not navigation then
            btn(page,collapsed and "›" or "‹",12,-8,32,function() collapsed=not collapsed; refresh() end)
        end
        local name = barsOverview and tr("Barres", "Bars") or hoverPage and hoverTitle or templateScope and (templateKind and kinds[templateKind] or tr("Propriétés globales des barres","Global bar properties"))
            or external and select(2,A.BarLabel(external.kind,external.id)) or bar and bar.name or panel and panel.name
            or tr("Cadres", "Frames")
        local overview = not bar and not panel and not external and not hoverPage and not barsOverview
        local globalFit = inheritedView and templateScope=="global"
        local fitPanel = not templateScope and (bar and M.frame(bar) or panel)
        if fitPanel and (fitPanel.kind~="owned" or #M.children(fitPanel)==0) then fitPanel=nil end
        local showFit = globalFit or fitPanel ~= nil
        local headingOffset = ((bar or hoverPage) and 21 or 0) + (showFit and 23 or 0)
        local commandY = -44-headingOffset
        heading:SetHeight(35+headingOffset)
        if renamingBar and (renamingBar ~= bar or templateScope) then cancelRename() end
        barTitle:SetShown(hoverPage or (bar ~= nil and not renamingBar))
        rename:SetShown(bar ~= nil and not templateScope and not renamingBar)
        surface:SetPoint("TOPLEFT",10,-71-headingOffset)
        right:SetPoint("TOPLEFT",22,-82-headingOffset)
        right:SetPoint("TOPRIGHT",-32,-82-headingOffset)
        local activeKey = sectionKey or (templateScope and "layout" or "attachment")
        local choices = {}
        if bar then
            for _, spec in ipairs(barSections) do
                if hasBarSection(spec, bar.kind, templateScope, templateKind) then
                    choices[#choices+1]=spec
                end
            end
            local active
            for _, spec in ipairs(choices) do if spec.key==activeKey then active=spec end end
            active=active or choices[1]
            activeKey=active.key
            local caption=title(page,active.title,titleX,-9)
            caption:SetTextColor(1,1,1)
            caption:SetWidth(325)
            caption:SetJustifyH("LEFT")
            caption:SetWordWrap(false)
            barTitle:SetText(name)
            rename:ClearAllPoints()
            rename:SetPoint("TOPLEFT", titleX + math.min(325, barTitle:GetStringWidth()) + 8, -24)
            dropdown(page,410,-19,201,tr("Rubriques", "Sections"),function(root)
                for _, spec in ipairs(choices) do
                    root:CreateButton(spec.title,function() revealSection(spec.key) end)
                end
            end)
        else
            local caption=title(page,name,titleX,hoverPage and -9 or -14)
            caption:SetTextColor(1,1,1)
            if hoverPage then barTitle:SetText(tr("Cadres", "Frames")) end
        end
        if barsOverview then
            dropdown(page,410,-9,201,tr("Rubriques", "Sections"),function(root)
                for _, spec in ipairs(barSections) do
                    if hasBarSection(spec, "action", true) then
                        root:CreateButton(spec.title,function() revealSection(spec.key) end)
                    end
                end
            end)
        elseif (overview or hoverPage) and navigation then
            dropdown(page,410,hoverPage and -19 or -9,201,tr("Rubriques", "Sections"),function(root)
                if M.mode(state)=="KeyLayers" and not inheritedView then
                    root:CreateButton(hoverTitle,function() choose({hoverBindings=true}) end)
                end
                for index, target in ipairs(KeyLayersCharLayout.panels) do
                    root:CreateButton(target.name,function() context.openFrame(index) end)
                end
                if #KeyLayersCharLayout.panels==0 then
                    root:CreateButton(tr("Aucun cadre", "No frames")):SetEnabled(false)
                end
            end)
        elseif not context.global and not bar then
            providerMenu(page,400,-8,230)
        end
        form:SetWidth(right:GetWidth())
        if page:IsShown() then updateTree(true, nil) end
        local y=0
        local function action(text,fn) btn(form,text,0,y,380,fn); y=y-28 end
        local function choice(label,text,build)
            title(form,label,0,y-6); dropdown(form,176,y,204,text,build); y=y-29
        end
        local function option(name,caption,values)
            choice(caption,tostring(values[bar[name]] or bar[name] or values.game),function(root)
                for k,v in pairs(values) do ui.radio(root,tostring(v),k,function() return bar[name] end,function(key) bar[name]=key; apply() end) end
            end)
        end
        local function input(caption,value,save)
            title(form,caption,0,y)
            local box=acquire("field",form,5,y-16,function()
                local w=CreateFrame("EditBox",nil,form,"InputBoxTemplate")
                w:SetSize(230,23); w:SetAutoFocus(false)
                w:SetScript("OnEscapePressed",w.ClearFocus)
                return w
            end)
            box:ClearFocus()
            box:SetText(tostring(value))
            local function commit()
                if not InCombatLockdown() then save(box:GetText()); apply() end
            end
            box:SetScript("OnEnterPressed",commit)
            btn(form,OKAY or "OK",246,y-15,62,commit); y=y-45
        end
        local function section(spec,render)
            if spec.key==activeKey then render() end
        end
        local function color(key,caption,default)
            local target=bar
            local saved=target[key]
            local current=saved or default
            local function rgb(hex)
                return tonumber(hex:sub(1,2),16)/255,tonumber(hex:sub(3,4),16)/255,tonumber(hex:sub(5,6),16)/255
            end
            local r,g,b=rgb(current)
            local swatch=acquire("swatch",form,316,y-15,function()
                local widget=CreateFrame("Button",nil,form,"BackdropTemplate")
                widget:SetSize(24,22)
                widget:SetBackdrop({bgFile=[[Interface\Buttons\WHITE8X8]],edgeFile=[[Interface\Buttons\WHITE8X8]],edgeSize=1})
                widget:SetBackdropBorderColor(.8,.8,.8,1)
                return widget
            end)
            swatch:SetBackdropColor(r,g,b,1)
            swatch:SetScript("OnClick",function()
                if InCombatLockdown() then return end
                ColorPickerFrame:SetupColorPickerAndShow({
                    r=r,g=g,b=b,
                    swatchFunc=function()
                        local red,green,blue=ColorPickerFrame:GetColorRGB()
                        target[key]=("%02X%02X%02X"):format(math.floor(red*255+.5),math.floor(green*255+.5),math.floor(blue*255+.5))
                        apply()
                    end,
                    cancelFunc=function() target[key]=saved;apply() end,
                })
            end)
            input(caption,current,function(text)
                local hex=text:gsub("^#",""):upper()
                if #hex==6 and hex:match("^%x+$") then target[key]=hex end
            end)
        end
        local function range(label,value,min,max,step,save,disabled)
            local caption=title(form,label,0,y-4)
            local sliderX=math.max(270, caption:GetStringWidth()+14)
            local readout=title(form,step==1 and ("%d"):format(value) or ("%.1f"):format(value),sliderX+217,y-4)
            local slider=acquire("slider",form,sliderX,y,function()
                local control=CreateFrame("Slider",nil,form,"OptionsSliderTemplate")
                control:SetSize(200,17)
                control:SetObeyStepOnDrag(true)
                return control
            end)
            slider:SetScript("OnValueChanged",nil)
            slider:SetMinMaxValues(min,max)
            slider:SetValueStep(step)
            slider:SetValue(value)
            slider:SetEnabled(not disabled)
            if disabled then
                caption:SetTextColor(.55,.55,.55)
                readout:SetTextColor(.55,.55,.55)
            end
            slider:SetScript("OnValueChanged",function(_,n)
                n=math.floor(n/step+.5)*step
                readout:SetText(step==1 and ("%d"):format(n) or ("%.1f"):format(n))
                if disabled or InCombatLockdown() or n==value then return end
                value=n
                M.changeBarLayout(function() save(n) end)
                A.RebuildBars()
                A.Refresh()
            end)
            slider:SetScript("OnMouseUp",function() refresh() end)
            y=y-32
        end
        local function number(key,label,min,max,integer)
            range(label,bar[key] or 1,min,max,integer and 1 or .1,function(n) bar[key]=n end)
        end
        local function countdownCheckbox()
            local cooldownCheck=acquire("cooldownCheck",form,0,y,function()
                local widget=CreateFrame("CheckButton",nil,form,"UICheckButtonTemplate")
                widget:SetSize(24,24)
                return widget
            end)
            cooldownCheck:SetChecked(bar.showCooldownText==true)
            cooldownCheck:SetScript("OnClick",function(widget)
                if InCombatLockdown() then widget:SetChecked(bar.showCooldownText==true); return end
                bar.showCooldownText=not not widget:GetChecked()
                if bar.kind=="totem" then
                    A.totemCooldownPreview=bar.showCooldownText and bar or nil
                end
                apply()
            end)
            title(form,tr("Afficher le temps de recharge","Show cooldown countdown"),28,y-5)
            y=y-28
        end
        local canCreateBar = M.mode(state)=="KeyLayers" and not hoverPage
            and (not templateScope or globalBarsPage)
        if canCreateBar then
            dropdown(page,overview and context.newFrame and 222 or 12,commandY,bar and not templateScope and 143 or 198,tr("Nouvelle barre","New bar"),function(root)
                for _,kind in ipairs({"action","stance","totem"}) do
                    local _,class=UnitClass("player")
                    if kind=="action" or (kind=="totem" and class=="SHAMAN") or (kind=="stance" and GetNumShapeshiftForms()>0) then
                        root:CreateButton(kinds[kind],function()
                            local b,reason=M.new(kind,panel,true)
                            if reason=="no-placement" then noPlacement() end
                            if b then
                                if not b.parent and context.placeNew then
                                    local w,h=M.size(b)
                                    local bounds={x=b.x,y=b.y,width=w,height=h}
                                    context.placeNew(bounds)
                                    b.x,b.y=bounds.x,bounds.y
                                end
                                templateScope=nil; selected=b.id; sectionKey=nil; apply()
                            end
                        end)
                    end
                end
            end)
        end
        if templateScope then
            btn(page,templateKind and tr("Rétablir les propriétés globales des barres", "Use global bar properties")
                or tr("Rétablir les valeurs par défaut des barres", "Restore default bar properties"),
                canCreateBar and 222 or 12,commandY,280,function()
                ui.confirm(tr("Réinitialiser ces propriétés de barre ?", "Reset these bar properties?"), function()
                    M.changeBarLayout(function() M.clearBarTemplate(KeyLayersCharLayout, templateKind) end)
                    apply()
                end)
            end)
        end
        if showFit then
            local toggle = acquire("headingFitSwitch",page,titleX,bar and -47 or -28,function()
                local control = A.CreateWorkspaceSwitch(page, function() end)
                control:SetScript("OnEnter",function(self)
                    GameTooltip:SetOwner(self,"ANCHOR_TOP")
                    GameTooltip:SetText(M.autoFitLabel)
                    GameTooltip:Show()
                end)
                control:SetScript("OnLeave",function() GameTooltip:Hide() end)
                return control
            end)
            local only = fitPanel and M.singleFrameBar(fitPanel)
            local enabled = globalFit or only ~= nil
            toggle:SetEnabled(enabled)
            toggle:SetAlpha(enabled and 1 or .55)
            toggle:SetActive(globalFit and M.autoFitEnabled() or fitPanel and M.autoFitEnabled(fitPanel))
            toggle:SetScript("OnClick",function()
                if InCombatLockdown() then return end
                if globalFit then state.autoFitFrames = not M.autoFitEnabled()
                elseif only then M.setFitFrame(only, not M.autoFitEnabled(fitPanel))
                else return end
                apply()
            end)
            local caption = title(page,tr("Ajustement auto","Auto fit"),titleX+44,bar and -48 or -29)
            caption:SetTextColor(enabled and 1 or .55, enabled and .82 or .55, enabled and 0 or .55)
        end
        if overview and context.newFrame then
            btn(page,tr("Nouveau cadre","New frame"),12,commandY,198,context.newFrame)
        end
        if hoverPage then
            local toggle = acquire("hoverSwitch", form, 0, y, function()
                return A.CreateWorkspaceSwitch(form, function()
                    if InCombatLockdown() then return end
                    if not capturing and not context.editing() then context.startEditing() end
                    capturing = not capturing and context.editing()
                    refresh()
                end)
            end)
            toggle:SetActive(capturing)
            title(form,tr("Activer l’assignation par survol","Enable hover binding"),44,y-2)
            local help = title(form,tr(
                "Survole un bouton numéroté sur une barre, puis appuie sur la touche à lui assigner. Échap désactive ce mode.",
                "Hover over a numbered button on an action bar, then press the key to assign. Escape turns this mode off."),0,y-33)
            help:SetWidth(570)
            help:SetWordWrap(true)
            help:SetTextColor(1,1,1)
            y=y-84
        end
        if external then
            local kind,id=external.kind,external.id
            if panel then action(panel.name.." ›",function() context.openFrame(frameIndex) end) end
            choice(tr("Rattacher au cadre","Attach to frame"),panel and panel.name or independent,function(root)
                root:CreateButton(independent,function() M.linkExternal(kind,id,nil); frameIndex=nil; apply() end)
                for idx,p in ipairs(KeyLayersCharLayout.panels) do
                    root:CreateButton(p.name,function() M.linkExternal(kind,id,p); frameIndex=idx; apply() end)
                end
            end)
            if kind=="bars" and SlashCmdList.BARTENDER4 then
                action("Bartender4",function() SlashCmdList.BARTENDER4("") end)
            elseif kind=="blizzard" and EditModeManagerFrame then
                action(tr("Édition","Edit").." · Blizzard",function() ShowUIPanel(EditModeManagerFrame) end)
            end
        elseif bar then
            if not templateScope then
            btn(page,tr("Hériter du style", "Use inherited style"),316,commandY,143,function()
                local target = bar
                ui.confirm(tr("Retirer les réglages locaux de cette barre ?", "Clear this bar’s local overrides?"), function()
                    M.changeBarLayout(function() M.clearBarOverrides(target) end)
                    apply()
                end)
            end)
            section(barSections[1],function()
                local parent,idx=M.frame(bar)

                choice(tr("Rattacher au cadre","Attach to frame"),parent and ("["..parent.name.."]") or tr("Sans cadre","No frame"),function(root)
                    local target=bar
                    root:CreateButton(tr("Nouveau cadre","New frame"),function() wrapBars({target}) end)
                    root:CreateButton(tr("Sans cadre","No frame"),function() M.attach(target,nil); frameIndex=nil; apply() end)
                    for i,p in ipairs(KeyLayersCharLayout.panels) do
                        if p.kind=="free" or p.kind=="owned" then
                            root:CreateButton(p.name,function() if M.attachInside(bar,p) then frameIndex=i; apply() else noPlacement() end end)
                        end
                    end
                end)
                choice(tr("Type de barre","Bar type"),kinds[bar.kind],function(root)
                    local _,class=UnitClass("player")
                    for _,kind in ipairs({"action","stance","totem"}) do
                        if kind=="action" or (kind=="totem" and class=="SHAMAN") or (kind=="stance" and GetNumShapeshiftForms()>0) then
                            root:CreateButton(kinds[kind],function()
                                bar.kind=kind
                                bar.count=kind=="totem" and 6 or kind=="stance" and 10 or (bar.actionCount or 12)
                                apply()
                            end)
                        end
                    end
                end)
            end)
            if activeKey=="attachment" and (bar.kind == "action" or bar.kind == "totem") then
                local target = bar
                choice(tr("Actions de la barre", "Bar actions"),
                    tr("Vider un emplacement…", "Clear a slot…"), function(root)
                    local frame = A.ownedBars[target.id]
                    if not frame or frame.model ~= target then return end
                    local byPosition = {}
                    for _, button in ipairs(frame.buttons) do
                        if button:IsShown() and button:GetAttribute("editableAction") then
                            byPosition[M.slotPosition(target, button.index) + 1] = button
                        end
                    end
                    for position = 1, target.count do
                        local button = byPosition[position]
                        if button then
                            local name = tr("Emplacement %d", "Slot %d"):format(position)
                            local key = button.HotKey:GetText()
                            if key and key ~= "" then name = name .. " · " .. key end
                            local slot = button:GetAttribute("action")
                            root:CreateButton(name, function()
                                ui.confirm(tr("Vider « %s » ?", "Clear “%s”?"):format(name), function(dialog)
                                    if dialog then dialog:Hide() end
                                    if button.model == target and button:IsShown()
                                        and button:GetAttribute("action") == slot then button:RemoveAction() end
                                end)
                            end)
                        end
                    end
                end)
            end
            end
            if not templateScope and not inheritedView then
                section(barSections[10], function()
                    local function coordinate(key, value)
                        local number = tonumber(value:gsub(",", "."))
                        if number then bar[key] = math.max(-10000, math.min(10000, number)) end
                    end
                    input("X", bar.x, function(value) coordinate("x", value) end)
                    input("Y", bar.y, function(value) coordinate("y", value) end)
                    local width, height = M.size(bar)
                    title(form, tr("Largeur × hauteur · %d × %d", "Width × height · %d × %d")
                        :format(math.floor(width + .5), math.floor(height + .5)), 0, y - 4)
                    y = y - 25
                end)
            end
            section(barSections[2],function()
                local columns, rows, _, count = M.barGrid(bar)
                local parent = not templateScope and M.frame(bar)
                local fitted = parent and M.followsFrame(bar)
                if bar.kind=="totem" then
                    range(tr("Nombre de boutons","Button count"),count,4,36,1,function(n) bar.count=n end,fitted)
                elseif bar.kind=="action" then
                    range(tr("Nombre de boutons","Button count"),count,1,36,1,function(n) bar.count=n; bar.actionCount=n end,fitted)
                    if not templateScope then number("page",tr("Page de base","Base page"),1,15,true) end
                end
                if bar.kind=="stance" then
                    title(form,tr("Nombre de boutons","Button count").." · "..bar.count,0,y-4); y=y-27
                end
                range(tr("Colonnes","Columns"),fitted and columns or bar.columns,1,36,1,
                    function(n) bar.columns=n end,fitted)
                range(tr("Lignes","Rows"),rows,1,count,1,function(n)
                    bar.columns=math.ceil(bar.count/n)
                end,fitted)
                if bar.kind=="action" and not templateScope then
                    range(tr("Décalage des actions (cases)","Action offset (slots)"),(bar.slotOffset or 0)%count,
                        0,count-1,1,function(n) bar.slotOffset=n end)
                end
                number("gap",tr("Espacement","Spacing"),0,40,true)
                number("scale",tr("Échelle","Scale"),.1,6)
                number("alpha",tr("Opacité","Opacity"),0,1)
                option("visibility",tr("Visibilité","Visibility"),visibility)
            end)
            section(barSections[3],function()
                option("shape",tr("Forme","Shape"),{square=tr("Carré","Square"),round=tr("Rond","Round"),rounded=tr("Carré arrondi","Rounded square")})
                choice(tr("Style du contour","Border style"),({solid=tr("Uni","Solid"),dashed=tr("Tirets","Dashed"),none=tr("Aucun","None")})[bar.borderStyle or "solid"],function(root)
                    for k,text in pairs({solid=tr("Uni","Solid"),dashed=tr("Tirets","Dashed"),none=tr("Aucun","None")}) do
                        root:CreateButton(text,function() bar.borderStyle=k;bar.border=k~="none";apply() end)
                    end
                end)
                number("borderWidth",tr("Épaisseur","Thickness"),1,8,true)
                range(tr("Opacité du contour","Border opacity"),bar.borderOpacity or .9,0,1,.1,function(n) bar.borderOpacity=n end)
                color("borderColor",tr("Couleur du contour (hex)","Border color (hex)"),"787D85")
                for _,entry in ipairs({{"reverse",tr("Sens inversé","Reverse order")},{"keys",tr("Raccourcis","Keybindings")},
                    {"border",tr("Bordure","Border")},{"macros",tr("Nom de macro","Macro name")},{"empty",tr("Cases vides","Empty slots")}}) do
                    local box=acquire("check",form,0,y,function()
                        local w=CreateFrame("CheckButton",nil,form,"UICheckButtonTemplate")
                        w:SetSize(24,24); return w
                    end)
                    local lab=title(form,entry[2],26,y-4)
                    box:SetHitRectInsets(0,-lab:GetStringWidth(),0,0)
                    box:SetScript("OnClick",function(w)
                        if not InCombatLockdown() then bar[entry[1]]=not not w:GetChecked(); apply() end
                    end)
                    box:SetChecked(bar[entry[1]]); y=y-26
                end
            end)
            local modes = {bar=tr("Barre de progression","Progress bar"), ring=tr("Contour intérieur","Inner ring"),
                clock=tr("Assombrissement progressif","Clock sweep"), none=tr("Aucun","None")}
            local function durationChoice(key, default, title)
                choice(title, modes[bar[key] or default], function(root)
                    for _, mode in ipairs({"bar", "ring", "clock", "none"}) do
                        root:CreateButton(modes[mode], function() bar[key]=mode; apply() end)
                    end
                end)
            end
            local function durationStyle(mode, prefix)
                if mode=="none" then
                    title(form,tr("Choisis un indicateur de durée active.","Select an active duration indicator."),0,y-5)
                    y=y-28
                    return
                end
                prefix = prefix .. mode
                local clock = mode=="clock"
                color(prefix.."Color",tr("Couleur de la durée (hex)","Duration color (hex)"),clock and "17251C" or "59FF7D")
                range(tr("Opacité","Opacity"),bar[prefix.."Opacity"] or (clock and .65 or .95),
                    0,1,.1,function(n) bar[prefix.."Opacity"]=n end)
                range(tr("Taille","Size"),bar[prefix.."Size"] or (clock and 1 or 3),
                    clock and .1 or 1,clock and 1 or 8,clock and .1 or 1,function(n) bar[prefix.."Size"]=n end)
            end
            section(barSections[4],function()
                option("cooldown",tr("Recharge","Cooldown"),{edge=tr("Contour horaire","Clockwise outline"),veil=tr("Voile progressif","Progressive veil"),none=tr("Aucun","None")})
                if bar.kind~="totem" then countdownCheckbox() end
                color("cooldownColor",tr("Couleur de recharge (hex)","Cooldown color (hex)"),"FFD42E")
                if bar.kind == "action" and (not templateScope or templateKind) then
                    durationChoice("auraProgress", "none", tr("Durée active", "Active duration"))
                end
            end)
            if bar.kind == "action" and (not templateScope or templateKind) then
                section(barSections[8], function() durationStyle(bar.auraProgress or "none", "aura_") end)
            end
            if not templateScope then btn(page,tr("Supprimer","Delete bar"),468,commandY,143,function()
                local target=bar
                ui.confirm(tr("Supprimer cette barre ?","Delete this bar?"),function(dialog)
                    if dialog then dialog:Hide() end
                    if A.DeleteOwnedBars({target}) == 0 then return end
                    capturing=false
                    if selected==target.id then
                        selected=nil
                        frameIndex=select(2,M.frame(target))
                    end
                    apply()
                    right:SetVerticalScroll(0)

                end)
            end) end
            if bar.kind=="totem" then
                section(barSections[5],function()
                countdownCheckbox()
                durationChoice("totemProgress", "bar", tr("Durée du totem actif", "Active totem duration"))
                if not templateScope then
                local p=A.TotemProfiles()
                choice(tr("Profil de totems","Totem profile"),p.active,function(root)
                    for name in pairs(p.sets) do root:CreateButton(name,function() A.SelectTotemProfile(name); refresh() end) end
                end)
                input(tr("Nouveau profil","New profile"),"",function(name) A.SelectTotemProfile(name,true) end)
                end
                end)
                section(barSections[6],function() durationStyle(bar.totemProgress or "bar", "totem_") end)
                section(barSections[9], function()
                    local dismissCheck = acquire("check", form, 0, y, function()
                        local box = CreateFrame("CheckButton", nil, form, "UICheckButtonTemplate")
                        box:SetSize(24, 24)
                        return box
                    end)
                    local dismissLabel = title(form, tr("Afficher le bouton de retrait du totem", "Show the totem dismiss button"), 26, y - 4)
                    dismissCheck:SetHitRectInsets(0, -dismissLabel:GetStringWidth(), 0, 0)
                    dismissCheck:SetChecked(bar.showTotemDismiss ~= false)
                    dismissCheck:SetScript("OnClick", function(self)
                        if InCombatLockdown() then return end
                        bar.showTotemDismiss = not not self:GetChecked()
                        apply()
                    end)
                    y = y - 28
                    if bar.showTotemDismiss ~= false then
                        local defaults = M.totemDismissDefaults
                        range(tr("Angle (0° en haut)", "Angle (0° at top)"),
                            bar.totemDismissAngle or defaults.angle, 0, 359, 1, function(n) bar.totemDismissAngle = n end)
                        range(tr("Distance au centre", "Distance from center"),
                            bar.totemDismissDistance or defaults.distance, 0, 60, 1, function(n) bar.totemDismissDistance = n end)
                        range(tr("Largeur de la bordure", "Border width"),
                            bar.totemDismissBorderWidth or math.max(1, math.min(2, bar.borderWidth or 1)), 0, 4, 1,
                            function(n) bar.totemDismissBorderWidth = n end)
                        color("totemDismissBorderColor", tr("Couleur de la bordure (hex)", "Border color (hex)"),
                            bar.borderColor or "787D85")
                        color("totemDismissBackground", tr("Fond de l’icône (hex)", "Icon background (hex)"),
                            defaults.background)
                    end
                end)
                section(barSections[7],function()
                    title(form,tr("Les touches des éléments et leurs modificateurs se règlent dans l’assignation du cadre.",
                        "Set element keys and modifiers in the frame’s keybinding panel."),0,y-5)
                    y=y-26
                    title(form,tr("Maintiens un raccourci d’élément puis défile pour changer de totem.",
                        "Hold an element shortcut and scroll to change totems."),0,y-5)
                    y=y-26
                    range(tr("Seuil du maintien (ms)","Hold threshold (ms)"),bar.totemHoldMs or 150,50,600,1,
                        function(n) bar.totemHoldMs=n end)
                    local host = not templateScope and M.frame(bar)
                    if host then
                        action(tr("Étiquette de profil de totems","Totem profile label").." ›",
                            function() context.openFrame(select(2, M.frame(bar)), "profileHint") end)
                    else
                        option("profileAnchor",tr("Ancre du profil","Profile anchor"),{
                            ["top-start"]=tr("Haut gauche","Top left"), top=tr("Haut centre","Top center"),
                            ["top-end"]=tr("Haut droit","Top right"), ["bottom-start"]=tr("Bas gauche","Bottom left"),
                            bottom=tr("Bas centre","Bottom center"), ["bottom-end"]=tr("Bas droit","Bottom right"),
                            ["left-start"]=tr("Gauche haut","Left top"), left=tr("Gauche centre","Left center"),
                            ["left-end"]=tr("Gauche bas","Left bottom"), ["right-start"]=tr("Droite haut","Right top"),
                            right=tr("Droite centre","Right center"), ["right-end"]=tr("Droite bas","Right bottom")})
                        option("profileFont",tr("Police du profil","Profile font"),{game=tr("Jeu","Game"),
                            chat=tr("Discussion","Chat"),numbers=tr("Chiffres","Numbers")})
                        range(tr("Taille de police du profil","Profile font size"),bar.profileFontSize or 12,8,32,1,
                            function(n) bar.profileFontSize=n end)
                    end
                    local elements={tr("Terre","Earth"),tr("Feu","Fire"),tr("Eau","Water"),tr("Air","Air")}
                    local order=bar.totemOrder or {1,2,3,4}
                    for position=1,4 do
                        choice(tr("Position %d","Position %d"):format(position),elements[order[position]],function(root)
                            for element,label in ipairs(elements) do
                                root:CreateButton(label,function()
                                    local order=A.Copy(bar.totemOrder or {1,2,3,4})
                                    for index,value in ipairs(order) do
                                        if value==element then
                                            order[index],order[position]=order[position],order[index]
                                            break
                                        end
                                    end
                                    bar.totemOrder=order
                                    apply()
                                end)
                            end
                        end)
                    end
                    if not templateScope then
                    local names={tr("Profil de totems suivant","Next totem profile"),tr("Profil de totems précédent","Previous totem profile")}
                    for slot,label in ipairs(names) do
                        local command=slot==1 and "KEYLAYERSTOTEMNEXT" or "KEYLAYERSTOTEMPREV"
                        local bindingContext=C_KeyBindings and C_KeyBindings.GetBindingContextForAction
                            and C_KeyBindings.GetBindingContextForAction(command)
                        local key=GetBindingKey(command,nil,bindingContext)
                        title(form,label,0,y-4)
                        local control=acquire("keyCapture",form,200,y,function()
                            return ui.button(form,"",200,y,180,function() end)
                        end)
                        control:SetText(key and GetBindingText(key) or tr("Assigner…","Assign…"))
                        local function stop()
                            if profileCapture == stop then
                                profileCapture = nil
                                profileKeyboard:EnableKeyboard(false)
                                profileKeyboard:Hide()
                                profileKeyboard:SetScript("OnKeyDown", nil)
                            end
                            control:SetText(key and GetBindingText(key) or tr("Assigner…","Assign…"))
                        end
                        local function assign(binding, replace)
                            local ok, reason, owner = A.AssignTotemProfileKey(command, binding, replace)
                            if ok then
                                A.SyncTotemProfileBindings()
                                apply()
                            elseif reason == "occupied" then
                                ui.confirm(tr("%s est affecté à « %s ». Réattribuer cette touche à « %s » ?",
                                    "%s is assigned to “%s”. Reassign this key to “%s”?")
                                    :format(GetBindingText(binding), A.ShortcutActionLabel(owner), label), function(dialog)
                                        if dialog then dialog:Hide() end
                                        assign(binding, owner)
                                    end)
                            elseif UIErrorsFrame then
                                UIErrorsFrame:AddMessage((reason == "reserved" and A.ReservedShortcutMessage(binding))
                                    or (reason == "temporary" and tr("Touche temporairement utilisée par %s.",
                                        "Key temporarily used by %s."):format(owner))
                                    or tr("Raccourci refusé","Binding rejected"))
                            end
                        end
                        local function onKeyDown(_, pressed)
                            if profileCapture ~= stop then return end
                            if pressed=="ESCAPE" then stop(); return end
                            if pressed:match("SHIFT$") or pressed:match("CTRL$") or pressed:match("ALT$")
                                or pressed=="UNKNOWN" then return end
                            local warning = A.ReservedShortcutMessage(pressed, IsAltKeyDown())
                            if warning then
                                if UIErrorsFrame then UIErrorsFrame:AddMessage(warning) end
                                return
                            end
                            local binding = (IsAltKeyDown() and "ALT-" or "")..(IsControlKeyDown() and "CTRL-" or "")..
                                (IsShiftKeyDown() and "SHIFT-" or "")..pressed
                            stop()
                            assign(binding)
                        end
                        control:RegisterForClicks("LeftButtonUp","RightButtonUp")
                        control:SetScript("OnHide",stop)
                        control:SetScript("OnClick",function(_,mouse)
                            if InCombatLockdown() then return end
                            if profileCapture then profileCapture() end
                            if mouse=="RightButton" then
                                assign(nil)
                                return
                            end
                            local focus = GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()
                            if focus then focus:ClearFocus() end
                            profileCapture = stop
                            profileKeyboard:SetScript("OnKeyDown", onKeyDown)
                            profileKeyboard:Show()
                            profileKeyboard:EnableKeyboard(true)
                            profileKeyboard:SetPropagateKeyboardInput(false)
                            control:SetText(tr("Appuie sur une touche…","Press a key…"))
                        end)
                        y=y-28
                    end
                    title(form,tr("Clic droit pour retirer un raccourci.","Right-click to clear a shortcut."),0,y-5)
                    y=y-27
                    end
                end)
            end
        elseif panel then
            action(tr("Habillage et déclencheurs","Appearance and triggers").." ›",function() context.openFrame(frameIndex) end)
            choice(tr("Visibilité","Visibility"),visibility[panel.visibility or "always"],function(root)
                for key,text in pairs(visibility) do root:CreateButton(text,function() panel.visibility=key; apply() end) end
            end)
            action(tr("Aperçu de l’ajustement","Preview fit"),function()
                local plan=M.fit(panel)
                if not plan then return end
                showGhosts(plan,panel)
                ui.confirm(tr("Appliquer cette disposition ?","Apply this layout?"),function()
                    if not InCombatLockdown() then for _,v in ipairs(plan) do v.bar.x,v.bar.y,v.bar.scale=v.x,v.y,v.scale end end
                    apply()
                end,refresh)
            end)
            for _,b in ipairs(M.children(panel)) do
                action(b.name.." ›",function() pickBar(b) end)
                if b.kind=="action" then
                    for formID=1,GetNumShapeshiftForms() do
                        local _,_,_,spell=GetShapeshiftFormInfo(formID)
                        local name=spell and C_Spell and C_Spell.GetSpellName(spell) or tostring(formID)
                        local pages=panel.formPages and panel.formPages[formID]
                        input(b.name.." · "..name,pages and pages[b.id] or b.page,function(text)
                            local n=tonumber(text)
                            if not n or n<1 or n>15 then return end
                            panel.formPages=panel.formPages or {}
                            panel.formPages[formID]=panel.formPages[formID] or {}
                            panel.formPages[formID][b.id]=math.floor(n)
                        end)
                    end
                end
            end
        end
        form:SetHeight(math.max(1,-y))
        showHandles()
    end
    page:SetScript("OnShow",refresh)
    page:SetScript("OnHide",function()
        cancelRename()
        if profileCapture then profileCapture() end
        capturing=false
        A.SetHoveredPanel(nil)
        A.ShowBarOutline(nil)
        A.barPreview=nil
        A.totemCooldownPreview=nil
        for _,h in pairs(handles) do h:Hide() end
        for _,h in pairs(captureButtons) do h:Hide() end
        for _,w in ipairs(outline) do w:Hide() end
    end)
    return {open=function(index,id)
        hoverPage=false
        templateScope=nil
        sectionKey=nil
        frameIndex=index; selected=id; external=nil; capturing=false
        refresh()
        right:SetVerticalScroll(0)
    end,
        openFrameBars=function(index)
            hoverPage=false
            templateScope=nil
            sectionKey=nil
            local target=KeyLayersCharLayout.panels[index]
            local id
            if not InCombatLockdown() and target and (target.kind=="free" or target.kind=="owned")
                and M.mode(M.init(KeyLayersCharLayout))=="KeyLayers" and #M.children(target)==0 then
                local created=M.new("action",target,true)
                if created then id=created.id; A.RebuildBars(); A.Refresh() end
            end
            frameIndex=index; selected=id; external=nil; capturing=false
            refresh()
            right:SetVerticalScroll(0)
        end,
        navigation=updateTree, selectedFrame=function() return frameIndex end,
        isInheritance=function() return inheritedView end,
        showContainers=function() inheritedView=false end,
        follow=function(index) if frameIndex~=index then frameIndex=index; selected=nil; external=nil; sectionKey=nil end end,
        openSection=revealSection, openGlobalSection=openGlobalSection,
        refresh=refresh}
end
