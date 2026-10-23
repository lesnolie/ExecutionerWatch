local _, EW = ...
if not EW.isWarrior then return end
local View = {}
View.__index = View
EW.View = View
local L, C = EW.layout, EW.colors

local function Border(parent,color)
  local lines={}
  for i=1,4 do lines[i]=EW.Texture(parent,"OVERLAY",color) end
  lines[1]:SetPoint("TOPLEFT"); lines[1]:SetPoint("TOPRIGHT"); lines[1]:SetHeight(1)
  lines[2]:SetPoint("BOTTOMLEFT"); lines[2]:SetPoint("BOTTOMRIGHT"); lines[2]:SetHeight(1)
  lines[3]:SetPoint("TOPLEFT"); lines[3]:SetPoint("BOTTOMLEFT"); lines[3]:SetWidth(1)
  lines[4]:SetPoint("TOPRIGHT"); lines[4]:SetPoint("BOTTOMRIGHT"); lines[4]:SetWidth(1)
  return lines
end

function View.New()
  local self=setmetatable({slots={},debts={},gaps={},texts={},fade=0,clock=0,enabled=false},View)
  local root=CreateFrame("Frame","ExecutionerWatchFrame",UIParent)
  self.root=root
  root:SetSize(L.total,L.height); root:SetPoint("CENTER",0,-160)
  root:SetMovable(true); root:SetClampedToScreen(true); root:Hide()
  self.native=EW.Native.New(root)
  -- Addon-owned animation lives on siblings of the sealed native controls.
  local overlay=CreateFrame("Frame",nil,root)
  self.overlay=overlay
  overlay:SetAllPoints(); overlay:SetFrameLevel(root:GetFrameLevel()+25)
  overlay:EnableMouse(false)
  for i=1,EW.cap do
    local slot=CreateFrame("Frame",nil,overlay)
    slot:SetSize(L.width,L.height)
    slot:SetPoint("TOPLEFT",root,"TOPLEFT",(i-1)*L.pitch,0)
    slot:EnableMouse(false)
    Border(slot,C.line)
    local previewNative=EW.Texture(slot,"BACKGROUND",{0.10,0.40,0.35,1})
    previewNative:SetAllPoints(); previewNative:SetAlpha(0)
    local back=EW.Texture(root,"BACKGROUND",C.slot)
    back:SetSize(L.width,L.height)
    back:SetPoint("TOPLEFT",root,"TOPLEFT",(i-1)*L.pitch,0)
    local fill=CreateFrame("StatusBar",nil,slot)
    fill:SetPoint("TOPLEFT",1,-1); fill:SetPoint("BOTTOMRIGHT",-1,1)
    fill:SetOrientation("VERTICAL"); fill:SetMinMaxValues(0,1)
    fill:SetStatusBarTexture(EW.white); fill:SetStatusBarColor(1,1,1,1)
    fill:SetValue(0); fill:EnableMouse(false)
    local text=EW.Font(overlay,L.timerFont)
    text:SetWidth(L.width+2); text:SetJustifyH("CENTER")
    text:SetPoint("TOP",slot,"BOTTOM",0,-4)
    self.slots[i]={frame=slot,fill=fill,back=back,previewNative=previewNative}
    self.texts[i]=text
    if i<EW.cap then
      local gap=EW.Texture(overlay,"OVERLAY",C.line)
      gap:SetSize(L.gap,L.height)
      gap:SetPoint("TOPLEFT",root,"TOPLEFT",i*L.pitch-L.gap,0)
      self.gaps[i]=gap
    end
  end
  self.warning=Border(overlay,{0.9,0.48,0.21,0.65})
  self.badge=EW.Font(overlay,L.timerFont)
  self.badge:SetPoint("BOTTOMLEFT",root,"TOPLEFT",0,4)
  self.debtLane=CreateFrame("Frame",nil,root)
  self.debtLane:SetSize(EW.cap*(L.debtWidth+L.debtGap)-L.debtGap,L.height)
  self.debtLane:SetPoint("TOPLEFT",root,"TOPRIGHT",8,0)
  self.debtLane:EnableMouse(false)
  for i=1,EW.cap do
    local bar=CreateFrame("Frame",nil,self.debtLane)
    bar:SetSize(L.debtWidth,L.height)
    bar:SetPoint("TOPLEFT",self.debtLane,"TOPLEFT",(i-1)*(L.debtWidth+L.debtGap),0)
    bar:EnableMouse(false)
    local back=EW.Texture(bar,"BACKGROUND",{0.20,0.045,0.045,0.85}); back:SetAllPoints()
    Border(bar,C.line)
    local fill=CreateFrame("StatusBar",nil,bar)
    fill:SetPoint("TOPLEFT",1,-1); fill:SetPoint("BOTTOMRIGHT",-1,1)
    fill:SetOrientation("VERTICAL"); fill:SetMinMaxValues(0,1)
    fill:SetStatusBarTexture(EW.white); fill:SetStatusBarColor(1,1,1,1)
    fill:SetValue(0); fill:EnableMouse(false)
    local text=EW.Font(bar,L.timerFont); text:SetWidth(L.debtWidth+2)
    text:SetJustifyH("CENTER"); text:SetPoint("TOP",bar,"BOTTOM",0,-4)
    text:SetTextColor(1,0.58,0.53,1)
    bar.fill,bar.text=fill,text
    self.debts[i]=bar
  end
  self.overflow=EW.Font(self.debtLane,L.timerFont)
  self.overflow:SetText("…")
  local textLayer=CreateFrame("Frame",nil,root)
  textLayer:SetAllPoints(); textLayer:SetFrameLevel(root:GetFrameLevel()+30); textLayer:EnableMouse(false)
  self.previewAlert=EW.Font(textLayer,L.alertFont)
  self.previewAlert:SetText("! 取消 !"); self.previewAlert:SetTextColor(0.96,0.36,0.31,1)
  self.previewCount=EW.Font(textLayer,L.timerFont)
  self.previewCount:SetPoint("BOTTOM",root,"TOP",0,5)
  -- Input lives on its own frame, avoiding both invisible click blockers and
  -- any attempt to read or mutate protected native display state.
  local handle=CreateFrame("Frame",nil,UIParent)
  self.handle=handle
  handle:SetFrameStrata("HIGH"); handle:SetSize(L.total,L.height+L.timerHeight+28)
  handle:RegisterForDrag("LeftButton"); handle:EnableMouseWheel(true); handle:Hide()
  handle:SetScript("OnDragStart",function()
    if self.enabled and not EW.db.locked and not InCombatLockdown() then root:StartMoving() end
  end)
  handle:SetScript("OnDragStop",function()
    root:StopMovingOrSizing()
    local point,_,relative,x,y=root:GetPoint()
    EW.db.point={point,relative,x,y}
  end)
  handle:SetScript("OnMouseUp",function(_,button)
    if button=="RightButton" then EW.Settings:Toggle() end
  end)
  handle:SetScript("OnMouseWheel",function(_,delta)
    if IsControlKeyDown() then EW.SetOption("scale",EW.db.scale*(delta>0 and 1.1 or 1/1.1))
    elseif IsShiftKeyDown() then EW.SetOption("alpha",EW.db.alpha+delta*0.05) end
  end)
  handle:SetScript("OnEnter",function()
    GameTooltip:SetOwner(handle,"ANCHOR_TOP")
    GameTooltip:AddLine("处刑者监控")
    GameTooltip:AddLine("亮色高度和秒数是预测；暗色整槽与总层数由游戏控制。",0.8,0.9,0.86,true)
    if EW.model.reason~="" then GameTooltip:AddLine(EW.model.reason,1,0.7,0.35,true) end
    if not EW.source.found then GameTooltip:AddLine("请在冷却管理器追踪处刑者。",1,0.7,0.35,true) end
    GameTooltip:AddLine("右键设置 · Ctrl+滚轮缩放 · Shift+滚轮透明度",1,1,1,true)
    GameTooltip:Show()
  end)
  handle:SetScript("OnLeave",function() GameTooltip:Hide() end)
  self.unlock=Border(handle,{0.8,0.65,0.28,0.7})
  self:Layout(true)
  self:SetEnabled(false)
  return self
end

function View:SetEnabled(enabled)
  self.enabled=enabled == true
  -- Alpha is already used on this addon-owned root during combat rendering.
  -- Clear the whole HUD immediately without changing protected visibility.
  self.root:SetAlpha(self.enabled and EW.db.alpha or 0)
  if not self.enabled then
    self.previewMode=nil
    self.handle:EnableMouse(false)
    GameTooltip:Hide()
  end
  if InCombatLockdown() then self.deferred=true; return end
  if self.enabled then self.root:Show(); self.handle:Show()
  else self.root:Hide(); self.handle:Hide(); GameTooltip:Hide() end
end

function View:ApplyGeometry()
  local db=EW.db
  self.root:SetSize(L.total,L.height)
  self.root:SetScale(db.scale)
  self.handle:SetSize(L.total,L.height+L.timerHeight+28)
  self.handle:SetScale(db.scale)
  self.handle:ClearAllPoints(); self.handle:SetPoint("TOPLEFT",self.root,"TOPLEFT")
  for i,slot in ipairs(self.slots) do
    slot.frame:SetSize(L.width,L.height)
    slot.frame:ClearAllPoints()
    slot.frame:SetPoint("TOPLEFT",self.root,"TOPLEFT",(i-1)*L.pitch,0)
    slot.back:SetSize(L.width,L.height)
    slot.back:ClearAllPoints()
    slot.back:SetPoint("TOPLEFT",self.root,"TOPLEFT",(i-1)*L.pitch,0)
    self.texts[i]:SetFont(EW.font,L.timerFont,"OUTLINE")
    self.texts[i]:SetWidth(L.width+2)
    if self.gaps[i] then
      self.gaps[i]:SetSize(L.gap,L.height)
      self.gaps[i]:ClearAllPoints()
      self.gaps[i]:SetPoint("TOPLEFT",self.root,"TOPLEFT",i*L.pitch-L.gap,0)
    end
  end
  self.badge:SetFont(EW.font,L.timerFont,"OUTLINE")
  self.debtLane:SetSize(EW.cap*(L.debtWidth+L.debtGap)-L.debtGap,L.height)
  for i,bar in ipairs(self.debts) do
    bar:SetSize(L.debtWidth,L.height)
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT",self.debtLane,"TOPLEFT",(i-1)*(L.debtWidth+L.debtGap),0)
    bar.text:SetFont(EW.font,L.timerFont,"OUTLINE")
    bar.text:SetWidth(L.debtWidth+2)
  end
  self.overflow:SetFont(EW.font,L.timerFont,"OUTLINE")
  self.previewAlert:SetWidth(L.total)
  self.previewAlert:SetFont(EW.font,L.alertFont*db.alertScale,"OUTLINE")
  self.previewAlert:ClearAllPoints()
  self.previewAlert:SetPoint("TOP",self.root,"BOTTOM",0,-L.timerHeight-7)
  self.previewCount:SetFont(EW.font,L.timerFont,"OUTLINE")
end

function View:Layout(forceNative)
  if InCombatLockdown() then self.deferred=true; return end
  local db=EW.db
  self:ApplyGeometry()
  self.root:ClearAllPoints()
  if db.point then self.root:SetPoint(db.point[1],UIParent,db.point[2],db.point[3],db.point[4])
  else self.root:SetPoint("CENTER",0,-160) end
  if self.native then self.native:Layout(db.alertScale) end
  for _, slot in ipairs(self.slots) do
    EW.Gradient(slot.fill:GetStatusBarTexture(),C.low,C.high,db.showGradient)
  end
  for _,bar in ipairs(self.debts) do
    EW.Gradient(bar.fill:GetStatusBarTexture(),C.debtLow,C.debtHigh,db.showGradient)
  end
  self:SetEnabled(EW.runtimeEnabled)
  self.deferred=false
end

function View:Preview(now, real)
  if not self.enabled then return nil end
  local panel=EW.Settings and EW.Settings:IsOpen()
  if InCombatLockdown() then return nil end
  local mode=self.previewMode
  if not mode and real.state=="IDLE" and (panel or not EW.db.locked) then mode="normal" end
  if not mode then return nil end
  local count=mode=="cancel" and 2 or mode=="debt" and 5 or 3
  local result={state=mode=="uncertain" and "UNCERTAIN" or "ACTIVE", count=count,
    debt=(mode=="debt" or mode=="cancel") and 2 or 0, rows={}, debtRows={}, reason="预览"}
  for i=1,count do
    result.rows[i]={duration=18,expiresAt=now+4.6+(i-1)*2.7}
  end
  for i=1,result.debt do
    result.debtRows[i]={id=count+i,duration=18,expiresAt=now+16+(i-1)*2}
  end
  return result
end

function View:Render(snapshot, now, elapsed)
  if not self.enabled then return end
  local db=EW.db
  local preview=self:Preview(now,snapshot)
  local s=preview or snapshot
  local active=s.state=="ACTIVE"
  if self.native then self.native:Render(db,snapshot) end
  if preview and self.native then
    self.native.stacks:SetAlpha(0); self.native.count:SetAlpha(0)
    for _,alert in ipairs(self.native.alerts) do alert:SetAlpha(0) end
  end
  -- Preview is addon-owned and never changes the model or plays sounds.
  self.previewCount:SetText(preview and tostring(s.count) or "")
  self.previewCount:SetAlpha(db.showText and preview and 1 or 0)
  self.previewAlert:SetAlpha(preview and s.debt>0 and s.count<=db.alertAt and db.showAlert and 1 or 0)
  for i,slot in ipairs(self.slots) do
    local record=active and s.rows[i]
    local left=record and math.max(0,record.expiresAt-now) or 0
    slot.fill:SetValue(record and math.min(1,left/record.duration) or 0)
    slot.fill:SetAlpha(record and db.showPips and 1 or 0)
    slot.frame:SetAlpha(db.showPips and 1 or 0)
    slot.back:SetAlpha(db.showPips and 1 or 0)
    slot.previewNative:SetAlpha(preview and i<=s.count and (active and 0.5 or 1) or 0)
    self.texts[i]:SetText(record and db.showTimers and db.showPips and string.format("%.1f",left) or "")
    self.texts[i]:SetTextColor(unpack(C.text))
  end
  self.badge:SetText(preview and "预览" or (active and "~" or s.state=="UNCERTAIN" and "?" or ""))
  self.badge:SetTextColor(unpack(C.muted))
  for _,line in ipairs(self.warning) do line:SetAlpha(s.debt>0 and 0.7 or 0) end
  local visible=active and db.showDebtAnim and math.min(db.debtMax,s.debt) or 0
  for i,bar in ipairs(self.debts) do
    local record=active and s.debtRows and s.debtRows[i]
    local left=record and math.max(0,record.expiresAt-now) or 0
    bar:SetAlpha(i<=visible and record and 1 or 0)
    bar.fill:SetValue(record and math.min(1,left/record.duration) or 0)
    bar.text:SetText(i<=visible and record and db.showTimers and string.format("%.1f",left) or "")
  end
  self.overflow:ClearAllPoints()
  self.overflow:SetPoint("BOTTOMLEFT",self.debtLane,"TOPLEFT",
    math.max(0,visible-1)*(L.debtWidth+L.debtGap),2)
  self.overflow:SetAlpha(visible>0 and s.debt>visible and 1 or 0)
  if visible>0 then
    local phase=(now/1.6)%1
    local x=8-3*(0.5-0.5*math.cos(2*math.pi*phase))
    self.debtLane:ClearAllPoints(); self.debtLane:SetPoint("TOPLEFT",self.root,"TOPRIGHT",x,0)
    self.debtLane:SetAlpha(1)
  else self.debtLane:SetAlpha(0) end
  local any=db.showPips or db.showText or db.showAlert or db.showDebtAnim
  local shown=s.state~="IDLE" or preview or not db.locked
  local target=any and (shown and 1 or db.idleAlpha) or 0
  local speed=target>self.fade and 10 or 3
  if target>self.fade then self.fade=math.min(target,self.fade+elapsed*speed)
  else self.fade=math.max(target,self.fade-elapsed*speed) end
  self.root:SetAlpha(db.alpha)
  self.overlay:SetAlpha(db.showPips and self.fade or 0)
  for _,slot in ipairs(self.slots) do slot.back:SetAlpha(db.showPips and self.fade or 0) end
  self.handle:EnableMouse(any and self.fade>0.05 and not InCombatLockdown())
  for _,line in ipairs(self.unlock) do line:SetAlpha(not db.locked and self.fade or 0) end
end
