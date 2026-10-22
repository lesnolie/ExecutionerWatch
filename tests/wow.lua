-- Deliberately finite API mock. Unknown APIs are nil (NOT silent no-ops).
-- Validates textures, dimensions, lifecycle, hook selection, secret guards,
-- and post-initialization access to sealed native children. It cannot prove
-- real WoW protected-frame semantics or render fonts/pixels.
local W={now=100,combat=false,frames={},logs={},sounds=0,aura=nil,warrior=true}
local methods={}
local function object(kind,parent,name)
  local o=setmetatable({kind=kind,parent=parent,name=name,scripts={},events={},shown=true,
    width=1,height=1,scale=1,alpha=1,points={},children={},frameLevel=parent and (parent.frameLevel or 0)+1 or 0}, {__index=methods})
  if parent then parent.children[#parent.children+1]=o end
  if name then _G[name]=o end
  if kind~="Texture" and kind~="FontString" then W.frames[#W.frames+1]=o end
  return o
end
local function mutable(o) assert(not o.sealed,"mutated sealed native child: "..o.kind) end
for _,name in ipairs({"SetClampedToScreen","SetMovable","RegisterForDrag","SetHitRectInsets",
  "SetFrameStrata","SetClipsChildren","SetOrientation","SetStatusBarColor","SetShadowOffset",
  "SetJustifyH","SetBackdrop","SetBackdropColor","SetBackdropBorderColor","SetFlowLayoutAnchorPoint",
  "SetFlowLayoutGrowthDirection","SetAutoFocus","SetTextInsets","SetValueStep","SetObeyStepOnDrag",
  "SetCursorPosition","HighlightText","SetOwner","AddLine"}) do
  methods[name]=function(self,...) mutable(self); self[name.."Args"]={...} end
end
function methods:SetPoint(...) mutable(self); self.points[#self.points+1]={...} end
function methods:ClearAllPoints() mutable(self); self.points={} end
function methods:GetPoint() return "CENTER",UIParent,"CENTER",0,-160 end
function methods:SetAllPoints(other) mutable(self); self.allPoints=other or self.parent end
function methods:SetSize(w,h) self:SetWidth(w); self:SetHeight(h) end
function methods:SetWidth(w) mutable(self); assert(type(w)=="number" and w>=0); self.width=w end
function methods:SetHeight(h) mutable(self); assert(type(h)=="number" and h>=0); self.height=h end
function methods:GetWidth() return self.width end
function methods:GetHeight() return self.height end
function methods:SetScale(s) mutable(self); assert(s>0); self.scale=s end
function methods:GetScale() return self.scale end
function methods:SetAlpha(a) mutable(self); assert(type(a)=="number" and a>=0 and a<=1); self.alpha=a end
function methods:SetFrameLevel(n) mutable(self); self.frameLevel=n end
function methods:GetFrameLevel() return self.frameLevel end
function methods:EnableMouse(b) mutable(self); self.mouse=b end
function methods:EnableMouseWheel(b) mutable(self); self.wheel=b end
function methods:StartMoving() assert(not W.combat,"move in combat") end
function methods:StopMovingOrSizing() end
function methods:CreateTexture() return object("Texture",self) end
function methods:CreateFontString() return object("FontString",self) end
function methods:SetTexture(path) mutable(self); self.texture=path end
function methods:SetColorTexture(...) mutable(self); self.texture="solid"; self.color={...} end
function methods:SetGradient(...) mutable(self); assert(self.texture,"gradient without base texture"); self.gradient={...} end
function methods:SetFont(path,size) mutable(self); assert(size>0); self.font={path,size} end
function methods:SetTextColor(...) mutable(self); self.textColor={...} end
function methods:SetText(text) mutable(self); self.text=text end
function methods:GetText() return self.text end
function methods:SetStatusBarTexture(path)
  mutable(self); self.fill=object("Texture",self); self.fill:SetTexture(path)
end
function methods:GetStatusBarTexture() return self.fill end
function methods:SetMinMaxValues(lo,hi) mutable(self); assert(hi>lo,"empty range"); self.lo,self.hi=lo,hi end
function methods:SetValue(v)
  mutable(self); self.value=v
  if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self,v) end
end
function methods:GetValue() return self.value end
function methods:SetThumbTexture(tex) self.thumb=tex end
function methods:SetScript(event,callback) mutable(self); self.scripts[event]=callback end
function methods:RegisterEvent(name) self.events[name]=true end
function methods:RegisterUnitEvent(name) self.events[name]=true end
function methods:SetShown(b)
  mutable(self)
  if self.shown==b then return end
  self.shown=b
  local cb=self.scripts[b and "OnShow" or "OnHide"]
  if cb then cb(self) end
end
function methods:Show() self:SetShown(true) end
function methods:Hide() self:SetShown(false) end
function methods:IsShown() return self.shown end
function methods:ClearFocus() end
function methods:GetChildren() return table.unpack(self.children) end
function methods:SetUnit() end
function methods:SetEnabled() end
function methods:UpdateAllAuras() end
function methods:SetApplicationBar(bar,options)
  assert(not W.combat,"native creation in combat")
  assert(options.minApplications==nil,"12.1.0 unsupported option")
  assert(options.maxApplications>=1)
  self.nativeBar=bar; self.nativeOptions=options
end
function methods:SetApplicationCount(text) self.nativeText=text end
local function seal(o)
  o.sealed=true
  for _,child in ipairs(o.children) do seal(child) end
end
function methods:AddAuraSlot(_,_,options)
  assert(not W.combat,"native initialization in combat")
  local button=object("AuraButton",self)
  assert(options.initializeFrame(button),"native init failed")
  seal(button)
end
function CreateFrame(kind,name,parent,template)
  if kind=="AuraContainer" and W.missingNative then error("AuraContainer unavailable") end
  return object(kind,parent,name)
end
unpack=table.unpack
tinsert=table.insert
UIParent=object("Frame",nil,"UIParent")
GameTooltip=object("Frame",nil,"GameTooltip")
UISpecialFrames={}; SlashCmdList={}; STANDARD_TEXT_FONT="Font"
SOUNDKIT={RAID_WARNING=1}
Enum={CooldownViewerCategory={Buff=1},StatusBarInterpolation={Immediate=0}}
AuraContainerSortMethod={Default=0}; AuraContainerSortDirection={Normal=0}
AnchorUtil={FlowDirection={Right=1,Down=1}}
function UnitClass() return "Warrior",W.warrior and "WARRIOR" or "MAGE" end
function GetTime() return W.now end
function InCombatLockdown() return W.combat end
function IsControlKeyDown() return false end
function IsShiftKeyDown() return false end
function PlaySound() W.sounds=W.sounds+1 end
function CreateColor(...) return {...} end
function strtrim(s) return s:match("^%s*(.-)%s*$") end
function issecretvalue(v) return type(v)=="table" and rawget(v,"secret")==true end
function W.Secret()
  return setmetatable({secret=true},{__tostring=function() error("formatted secret") end,
    __lt=function() error("compared secret") end,__le=function() error("compared secret") end,
    __add=function() error("arithmetic on secret") end})
end
C_UI={Reload=function() end}
C_UnitAuras={GetPlayerAuraBySpellID=function() return W.aura end}
local function Item()
  local f=object("Frame",UIParent); f.cooldownID=9001
  for _,method in ipairs({"OnUnitAuraAddedEvent","TriggerAuraAppliedAlert","OnUnitAuraUpdatedEvent",
    "OnUnitAuraRemovedEvent","TriggerAuraRemovedAlert"}) do f[method]=function() end end
  return f
end
W.icon=Item(); W.bar=Item()
BuffIconCooldownViewer={GetItemFrames=function() return W.icon and {W.icon} or {} end}
BuffBarCooldownViewer={GetItemFrames=function() return W.bar and {W.bar} or {} end}
C_CooldownViewer={GetCooldownViewerCategorySet=function() return {9001} end,
  GetCooldownViewerCooldownInfo=function() return {spellID=445584,linkedSpellIDs={}} end}
function hooksecurefunc(frame,method,callback)
  local original=frame[method]
  frame[method]=function(...) original(...); callback(...) end
end
function W.Event(name,...)
  for _,f in ipairs(W.frames) do
    if f.events[name] and f.scripts.OnEvent then f.scripts.OnEvent(f,name,...) end
  end
end
function W.Advance(seconds)
  local steps=math.max(1,math.ceil(seconds/0.04))
  for _=1,steps do
    W.now=W.now+seconds/steps
    for _,f in ipairs(W.frames) do
      if f.shown and f.scripts.OnUpdate then f.scripts.OnUpdate(f,seconds/steps) end
    end
  end
end
function W.Load()
  local EW={}
  for _,file in ipairs({"Core","Model","Diagnostics","Sources","Native","Alerts","View","Settings","ExecutionerWatch"}) do
    assert(loadfile("ExecutionerWatch/"..file..".lua"))("ExecutionerWatch",EW)
  end
  return EW
end
return W
