local _, EW = ...
if not EW.enabled then return end
EW.Settings={}
local S=EW.Settings
local color={0.12,0.15,0.17,1}
local function Panel(frame,bg)
  frame:SetBackdrop({bgFile=EW.white,edgeFile=EW.white,edgeSize=1})
  frame:SetBackdropColor(unpack(bg)); frame:SetBackdropBorderColor(0.02,0.03,0.04,1)
end
local function Label(parent,text,x,y,size)
  local fs=EW.Font(parent,size or 12); fs:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y); fs:SetText(text)
  return fs
end
local function Button(parent,text,x,y,width,callback)
  local b=CreateFrame("Button",nil,parent,"BackdropTemplate")
  b:SetSize(width,24); b:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y); Panel(b,color)
  local fs=EW.Font(b,11); fs:SetPoint("CENTER"); fs:SetText(text)
  b:SetScript("OnClick",callback)
  b:SetScript("OnEnter",function() b:SetBackdropBorderColor(0.23,0.65,0.55,1) end)
  b:SetScript("OnLeave",function() b:SetBackdropBorderColor(0.02,0.03,0.04,1) end)
  return b
end
function S:IsOpen() return self.frame and self.frame:IsShown() or false end
function S:Build()
  local f=CreateFrame("Frame","ExecutionerWatchSettings",UIParent,"BackdropTemplate")
  self.frame=f; self.controls={}
  f:SetSize(448,476); f:SetPoint("CENTER"); f:SetFrameStrata("DIALOG")
  f:SetClampedToScreen(true); f:SetMovable(true); f:EnableMouse(true)
  Panel(f,{0.045,0.06,0.07,0.98}); f:Hide()
  tinsert(UISpecialFrames,"ExecutionerWatchSettings")
  local header=CreateFrame("Frame",nil,f)
  header:SetSize(392,35); header:SetPoint("TOPLEFT",f,"TOPLEFT",0,0)
  header:EnableMouse(true); header:RegisterForDrag("LeftButton")
  header:SetScript("OnDragStart",function() f:StartMoving() end)
  header:SetScript("OnDragStop",function() f:StopMovingOrSizing() end)
  Label(header,"处刑者监控  ·  "..EW.version,16,-12,14)
  Button(f,"×",409,-8,28,function() f:Hide() end)
  Label(f,"显示",16,-55):SetTextColor(0.30,0.76,0.65,1)
  Label(f,"尺寸与提醒",232,-55):SetTextColor(0.30,0.76,0.65,1)
  local function Check(label,key,row)
    local b=CreateFrame("Button",nil,f)
    b:SetSize(198,23); b:SetPoint("TOPLEFT",f,"TOPLEFT",16,-80-(row-1)*26)
    local box=CreateFrame("Frame",nil,b,"BackdropTemplate")
    box:SetSize(13,13); box:SetPoint("LEFT"); Panel(box,color)
    local mark=EW.Texture(box,"ARTWORK",{0.25,0.70,0.59,1})
    mark:SetPoint("TOPLEFT",3,-3); mark:SetPoint("BOTTOMRIGHT",-3,3)
    local text=EW.Font(b,12); text:SetPoint("LEFT",box,"RIGHT",8,0); text:SetText(label)
    b:SetScript("OnClick",function() EW.SetOption(key,not EW.db[key]); self:Sync() end)
    self.controls[#self.controls+1]=function() mark:SetShown(EW.db[key]) end
  end
  for i,entry in ipairs({{"五根竖条","showPips"},{"逐层预测秒数","showTimers"},
    {"原生总层数文字","showText"},{"红色欠层动画","showDebtAnim"},
    {"柔和渐变","showGradient"},{"取消提醒文字","showAlert"},
    {"提示音（独立开关）","sound"},{"锁定位置","locked"}}) do Check(entry[1],entry[2],i) end
  local function Slider(label,key,lo,hi,step,row,format)
    local y=-80-(row-1)*43
    Label(f,label,232,y,11)
    local value=EW.Font(f,11); value:SetPoint("TOPRIGHT",f,"TOPRIGHT",-16,y)
    local slider=CreateFrame("Slider",nil,f,"BackdropTemplate")
    slider:SetSize(198,8); slider:SetPoint("TOPLEFT",f,"TOPLEFT",232,y-21)
    slider:SetOrientation("HORIZONTAL"); Panel(slider,color)
    local thumb=EW.Texture(slider,"OVERLAY",{0.32,0.76,0.66,1})
    thumb:SetSize(5,14); slider:SetThumbTexture(thumb)
    slider:SetMinMaxValues(lo,hi); slider:SetValueStep(step); slider:SetObeyStepOnDrag(true)
    slider:SetScript("OnValueChanged",function(_,v)
      value:SetText(format(v))
      if not self.syncing then EW.SetOption(key,v) end
    end)
    self.controls[#self.controls+1]=function() slider:SetValue(EW.db[key]); value:SetText(format(EW.db[key])) end
  end
  local function Percent(v) return math.floor(v*100+0.5).."%" end
  Slider("整体大小","scale",0.2,3,0.05,1,Percent)
  Slider("透明度","alpha",0.2,1,0.05,2,Percent)
  Slider("空闲透明度","idleAlpha",0,1,0.05,3,Percent)
  Slider("取消文字大小","alertScale",0.5,3,0.05,4,Percent)
  Slider("提醒层数","alertAt",1,4,1,5,function(v) return "≤ "..math.floor(v+0.5) end)
  Slider("红条显示上限","debtMax",1,5,1,6,function(v) return math.floor(v+0.5).." 根" end)
  Label(f,"外观预览（不影响真实计时或声音）",16,-351,11)
  local modes={{"正常","normal"},{"欠层","debt"},{"取消","cancel"},{"失同步","uncertain"},{"退出预览",false}}
  for i,entry in ipairs(modes) do
    local mode=entry[2]
    Button(f,entry[1],16+(i-1)*84,-374,78,function()
      if EW.view then EW.view.previewMode=mode or nil end
    end)
  end
  self.status=Label(f,"",16,-409,10)
  self.status:SetWidth(416); self.status:SetJustifyH("LEFT")
  Button(f,"复位位置与大小",16,-440,132,function() EW.ResetPosition(); self:Sync() end)
  local qq=CreateFrame("EditBox",nil,f,"BackdropTemplate")
  qq:SetSize(260,24); qq:SetPoint("TOPLEFT",f,"TOPLEFT",164,-440)
  Panel(qq,color); qq:SetAutoFocus(false); qq:SetFont(EW.font,11,"OUTLINE")
  qq:SetTextInsets(8,8,0,0); qq:SetText("233489177")
  qq:SetScript("OnEditFocusGained",function(box) box:SetText("233489177"); box:HighlightText() end)
  qq:SetScript("OnEscapePressed",function(box) box:ClearFocus() end)
  qq:SetScript("OnEnterPressed",function(box) box:ClearFocus() end)
  qq:SetScript("OnTextChanged",function(box,user) if user then box:SetText("233489177"); box:HighlightText() end end)
  local qLabel=EW.Font(qq,10); qLabel:SetPoint("RIGHT",-8,0); qLabel:SetText("QQ 群 · 选中复制")
  f:SetScript("OnShow",function() self:Sync() end)
  f:SetScript("OnHide",function()
    qq:ClearFocus()
    if EW.view then EW.view.previewMode=nil end
  end)
  f:SetScript("OnUpdate",function(_,elapsed)
    self.acc=(self.acc or 0)+elapsed
    if self.acc>=0.5 then self.acc=0; self:Status() end
  end)
end
function S:Status()
  if not self.status then return end
  local state=EW.model and EW.model.state or "IDLE"
  local label=state=="ACTIVE" and "逐层预测中（~）" or state=="UNCERTAIN" and "原生显示 · 预测暂停" or "等待增益"
  if EW.view and EW.view.native.failed then label="原生显示初始化失败，请查看 /ew status" end
  if EW.deferred then label=label.." · 布局设置脱战后应用" end
  self.status:SetText(label)
end
function S:Sync()
  if not self.frame then return end
  self.syncing=true
  for _,update in ipairs(self.controls) do update() end
  self.syncing=false
  self:Status()
end
function S:Toggle()
  if not self.frame then self:Build() end
  self.frame:SetShown(not self.frame:IsShown())
end
