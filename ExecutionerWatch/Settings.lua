local _, EW = ...
if not EW.isWarrior then return end
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
  f:SetSize(560,590); f:SetPoint("CENTER"); f:SetFrameStrata("DIALOG")
  f:SetClampedToScreen(true); f:SetMovable(true); f:EnableMouse(true)
  Panel(f,{0.045,0.06,0.07,0.98}); f:Hide()
  tinsert(UISpecialFrames,"ExecutionerWatchSettings")
  local header=CreateFrame("Frame",nil,f)
  header:SetSize(490,35); header:SetPoint("TOPLEFT",f,"TOPLEFT",0,0)
  header:EnableMouse(true); header:RegisterForDrag("LeftButton")
  header:SetScript("OnDragStart",function() f:StartMoving() end)
  header:SetScript("OnDragStop",function() f:StopMovingOrSizing() end)
  Label(header,"处刑者监控  ·  "..EW.version,16,-12,14)
  Button(f,"×",518,-8,28,function() f:Hide() end)

  Label(f,"角色与专精",16,-55,12):SetTextColor(0.30,0.76,0.65,1)
  local function Check(label,x,y,width,getter,setter)
    local b=CreateFrame("Button",nil,f)
    b:SetSize(width,23); b:SetPoint("TOPLEFT",f,"TOPLEFT",x,y)
    local box=CreateFrame("Frame",nil,b,"BackdropTemplate")
    box:SetSize(13,13); box:SetPoint("LEFT"); Panel(box,color)
    local mark=EW.Texture(box,"ARTWORK",{0.25,0.70,0.59,1})
    mark:SetPoint("TOPLEFT",3,-3); mark:SetPoint("BOTTOMRIGHT",-3,3)
    local text=EW.Font(b,11); text:SetPoint("LEFT",box,"RIGHT",8,0); text:SetText(label)
    b:SetScript("OnClick",function() setter(not getter()) end)
    self.controls[#self.controls+1]=function() mark:SetShown(getter() == true) end
  end

  Check("角色总开关（/ew on|off）",16,-80,226,
    function() return EW.GetMasterEnabled(EW.db) end,
    function(value) EW.SetMasterEnabled(value); self:Sync() end)
  Label(f,"各专精独立开关",16,-108,10)
  for i,spec in ipairs(EW.knownSpecs) do
    Check(spec.label.."（"..spec.name.."）",16,-128-(i-1)*26,226,
      function() return EW.IsSpecEnabled(EW.db,spec.id) end,
      function(value) EW.SetSpecEnabled(spec.id,value); self:Sync() end)
  end

  Label(f,"显示",16,-218,12):SetTextColor(0.30,0.76,0.65,1)
  local displays={
    {"五根竖条","showPips"},{"逐层秒数","showTimers"},
    {"原生层数","showText"},{"欠层动画","showDebtAnim"},
    {"柔和渐变","showGradient"},{"取消文字","showAlert"},
    {"提示音","sound"},{"锁定位置","locked"},
  }
  for i,entry in ipairs(displays) do
    local col=(i-1)%2
    local row=math.floor((i-1)/2)
    Check(entry[1],16+col*115,-240-row*26,110,
      function() return EW.db[entry[2]] end,
      function(value) EW.SetOption(entry[2],value); self:Sync() end)
  end
  Label(f,"外观预览（不改真实计时或声音）",16,-352,10)
  local modes={{"正常","normal"},{"欠层","debt"},{"取消","cancel"},{"失同步","uncertain"},{"退出","off"}}
  for i,entry in ipairs(modes) do
    Button(f,entry[1],16+((i-1)%2)*115,-375-math.floor((i-1)/2)*30,110,function()
      if EW.view then EW.view.previewMode=entry[2]~="off" and entry[2] or nil end
    end)
  end

  Label(f,"竖条尺寸与整体比例",290,-55,12):SetTextColor(0.30,0.76,0.65,1)
  local function Slider(label,key,lo,hi,step,y,format)
    Label(f,label,290,y,10)
    local value=EW.Font(f,10); value:SetPoint("TOPRIGHT",f,"TOPRIGHT",-16,y)
    local slider=CreateFrame("Slider",nil,f,"BackdropTemplate")
    slider:SetSize(254,8); slider:SetPoint("TOPLEFT",f,"TOPLEFT",290,y-19)
    slider:SetOrientation("HORIZONTAL"); Panel(slider,color)
    local thumb=EW.Texture(slider,"OVERLAY",{0.32,0.76,0.66,1})
    thumb:SetSize(5,14); slider:SetThumbTexture(thumb)
    slider:SetMinMaxValues(lo,hi); slider:SetValueStep(step); slider:SetObeyStepOnDrag(true)
    slider:SetScript("OnValueChanged",function(_,v)
      value:SetText(format(v))
      if not self.syncing then EW.SetOption(key,v) end
    end)
    self.controls[#self.controls+1]=function()
      slider:SetValue(EW.db[key]); value:SetText(format(EW.db[key]))
    end
  end
  local function Percent(v) return math.floor(v*100+0.5).."%" end
  local function Pixels(v) return math.floor(v+0.5).." px" end
  Slider("竖条宽度","width",16,60,1,-78,Pixels)
  Slider("竖条高度","height",24,140,2,-118,Pixels)
  Slider("竖条间距","gap",2,12,1,-158,Pixels)

  Label(f,"整体与透明度（复用整体比例）",290,-200,12):SetTextColor(0.30,0.76,0.65,1)
  Slider("整体比例","scale",0.2,3,0.05,-222,Percent)
  Slider("整体透明度","alpha",0.2,1,0.05,-262,Percent)
  Slider("空闲透明度","idleAlpha",0,1,0.05,-302,Percent)

  Label(f,"提醒",290,-343,12):SetTextColor(0.30,0.76,0.65,1)
  Slider("取消文字比例","alertScale",0.5,3,0.05,-365,Percent)
  Slider("提醒层数","alertAt",1,4,1,-405,function(v) return "≤ "..math.floor(v+0.5) end)
  Slider("红条显示上限","debtMax",1,5,1,-445,function(v) return math.floor(v+0.5).." 根" end)

  self.status=Label(f,"",16,-506,10)
  self.status:SetWidth(520); self.status:SetJustifyH("LEFT")
  Button(f,"复位位置、尺寸与比例",16,-534,190,function() EW.ResetPosition(); self:Sync() end)
  local qq=CreateFrame("EditBox",nil,f,"BackdropTemplate")
  qq:SetSize(270,24); qq:SetPoint("TOPLEFT",f,"TOPLEFT",266,-534)
  Panel(qq,color); qq:SetAutoFocus(false); qq:SetFont(EW.font,11,"OUTLINE")
  qq:SetTextInsets(8,8,0,0); qq:SetText("233489177")
  qq:SetScript("OnEditFocusGained",function(box) box:SetText("233489177"); box:HighlightText() end)
  qq:SetScript("OnEscapePressed",function(box) box:ClearFocus() end)
  qq:SetScript("OnEnterPressed",function(box) box:ClearFocus() end)
  qq:SetScript("OnTextChanged",function(box,user)
    if user then box:SetText("233489177"); box:HighlightText() end
  end)
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
  local spec=EW.currentSpecID and EW.SpecLabel(EW.currentSpecID) or "未知专精"
  local label=state=="ACTIVE" and "逐层预测中（~）"
    or state=="UNCERTAIN" and "原生显示 · 预测暂停"
    or "等待增益"
  if not EW.runtimeEnabled then
    label="监控已停用；开启角色总开关和当前专精开关后运行"
  end
  if EW.view and EW.view.native.failed then label="原生显示初始化失败，请查看 /ew status" end
  if EW.deferred or (EW.view and EW.view.deferred) then label=label.." · 布局脱战后应用" end
  self.status:SetText(spec.." · "..label)
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
