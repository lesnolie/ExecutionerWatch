local _, EW = ...
if not EW.isWarrior then return end
-- Only this module creates AuraContainer children. References to sealed
-- bars/buttons never leave initializeFrame. No shown-state callbacks/readback.
local Native = {}
Native.__index = Native
EW.Native = Native
local TEMPLATE = "DisableUntrustedLayoutScriptsTemplate"

local function NoMouse(frame)
  if frame.EnableMouse then frame:EnableMouse(false) end
end
function Native:Layer(name, parent, width, height, build)
  local outer=CreateFrame("Frame",nil,parent)
  self.frames[#self.frames+1]=outer
  outer:SetSize(width,height)
  local clip=CreateFrame("Frame",nil,outer,TEMPLATE)
  clip:SetAllPoints(outer); clip:SetClipsChildren(true); NoMouse(clip)
  local ok, err=pcall(function()
    local container=CreateFrame("AuraContainer",nil,clip,"CustomAuraContainerTemplate")
    container:SetSize(1,1)
    container:SetPoint("TOPRIGHT",clip,"TOPLEFT",-2,0)
    if container.SetFlowLayoutAnchorPoint then container:SetFlowLayoutAnchorPoint("TOPLEFT") end
    local direction=AnchorUtil and AnchorUtil.FlowDirection
    if container.SetFlowLayoutGrowthDirection and direction then
      container:SetFlowLayoutGrowthDirection(direction.Right,direction.Down)
    end
    container:AddAuraSlot("ew-"..name,"HELPFUL|PLAYER",{
      candidateFilters={includeSpellIDs={[EW.spellID]=true}}, maxFrameCount=1,
      sortMethod=AuraContainerSortMethod and AuraContainerSortMethod.Default,
      sortDirection=AuraContainerSortDirection and AuraContainerSortDirection.Normal,
      initializeFrame=function(button)
        local built, why=pcall(function()
          button:SetSize(width,height); button:ClearAllPoints()
          button:SetPoint("TOPLEFT",clip,"TOPLEFT",0,0); NoMouse(button)
          build(button,clip)
        end)
        if not built then self:Failure(name,why) end
        return built
      end,
    })
    container:SetUnit("player"); NoMouse(container)
    container:Show()
    if container.SetEnabled then container:SetEnabled(true) end
    container:UpdateAllAuras()
    outer.container=container
  end)
  if not ok then self:Failure(name,err) end
  return outer
end
function Native:Failure(name, err)
  self.failed=true
  local message=EW.IsSecret(err) and "受限制的错误信息" or tostring(err)
  EW.Record("error",GetTime(),"原生层 "..name..": "..message)
end
local function Bar(button,clip,width,height)
  local bar=CreateFrame("StatusBar",nil,button,TEMPLATE)
  bar:SetSize(width,height); bar:SetPoint("TOPLEFT",clip,"TOPLEFT",0,0)
  bar:SetStatusBarTexture(EW.white); NoMouse(bar)
  return bar
end
function Native.New(root)
  local self=setmetatable({alerts={},failed=false,frames={}},Native)
  local L=EW.layout
  self.stacks=self:Layer("stacks",root,L.total,L.height,function(button,clip)
    -- Full pitch includes final gap; outer clip removes it. All 1..5 values
    -- end exactly after the corresponding slot on BOTH 12.1.0 and 12.1.5.
    local bar=Bar(button,clip,L.pitch*EW.cap,L.height)
    bar:SetStatusBarColor(0.10,0.40,0.35,1)
    -- Keep slot separators in the native aura hierarchy as well. Prediction
    -- fading must not turn the native fallback into one continuous rectangle.
    local mask=CreateFrame("Frame",nil,button,TEMPLATE)
    mask:SetAllPoints(clip); mask:SetFrameLevel(bar:GetFrameLevel()+1); NoMouse(mask)
    for i=1,EW.cap-1 do
      local gap=EW.Texture(mask,"OVERLAY",EW.colors.line)
      gap:SetSize(L.gap,L.height)
      gap:SetPoint("TOPLEFT",clip,"TOPLEFT",i*L.pitch-L.gap,0)
    end
    assert(button:SetApplicationBar(bar,{maxApplications=EW.cap})~=false,"application binding failed")
  end)
  self.stacks:SetPoint("TOPLEFT",root,"TOPLEFT",0,0)
  self.count=self:Layer("count",root,L.countWidth,L.countHeight,function(button)
    local text=EW.Font(button,L.timerFont); text:SetPoint("CENTER")
    assert(button:SetApplicationCount(text)~=false,"count binding failed")
  end)
  self.count:SetPoint("BOTTOM",root,"TOP",0,5)
  -- Prebuild every threshold while out of combat. Settings choose an outer
  -- alpha; changing alertAt never mutates a sealed native bar.
  for threshold=1,4 do
    local cells=threshold+1
    self.alerts[threshold]=self:Layer("cancel-"..threshold,root,L.total,L.alertHeight,function(button,clip)
      local pusher=Bar(button,clip,cells*L.total,L.alertHeight)
      pusher:SetStatusBarColor(1,1,1,0)
      local window=CreateFrame("Frame",nil,button,TEMPLATE)
      window:SetSize(cells*L.total,L.alertHeight); window:SetClipsChildren(true); NoMouse(window)
      window:SetPoint("RIGHT",pusher:GetStatusBarTexture(),"RIGHT",L.total,0)
      local carrier=CreateFrame("Frame",nil,window,TEMPLATE)
      carrier:SetSize(L.total,L.alertHeight); carrier:SetPoint("CENTER",clip,"CENTER"); NoMouse(carrier)
      local text=EW.Font(carrier,L.alertFont); text:SetPoint("CENTER")
      text:SetText("! 取消 !"); text:SetTextColor(0.96,0.36,0.31,1)
      assert(button:SetApplicationBar(pusher,{maxApplications=cells})~=false,"alert binding failed")
    end)
  end
  return self
end
function Native:Destroy()
  -- Called only outside combat. A protected AuraContainer tree cannot be
  -- resized safely after initialization, so replacement layers are built
  -- before their predecessors are hidden.
  for _,frame in ipairs(self.frames) do
    frame:Hide()
  end
  self.alerts={}
  self.frames={}
end
function Native:Layout(scale)
  for _, alert in ipairs(self.alerts) do
    alert:SetScale(scale); alert:ClearAllPoints()
    alert:SetPoint("TOP",self.stacks,"BOTTOM",0,-(EW.layout.timerHeight+7)/scale)
  end
end
function Native:Render(db, snapshot)
  self.stacks:SetAlpha(db.showPips and (snapshot.state=="ACTIVE" and 0.5 or 1) or 0)
  self.count:SetAlpha(db.showText and 1 or 0)
  for threshold,alert in ipairs(self.alerts) do
    -- Native stacks alone gate the threshold. The model only gates debt.
    local enabled=db.showAlert and snapshot.debt>0 and snapshot.state=="ACTIVE" and threshold==db.alertAt
    alert:SetAlpha(enabled and 1 or 0)
  end
end
