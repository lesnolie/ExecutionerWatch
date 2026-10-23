-- Bootstrap: the TOC loads data modules first; this file owns lifecycle only.
local addonName, EW = ...
if not EW.isWarrior then return end

local frame=CreateFrame("Frame")
local initialized=false
local scanClock, renderClock, idClock=0,0,0
local lastError, lastErrorAt
local activeGeometry

local function SnapshotLayout()
  local L=EW.layout
  return {width=L.width,height=L.height,gap=L.gap,pitch=L.pitch,total=L.total,
    debtWidth=L.debtWidth,debtGap=L.debtGap,timerHeight=L.timerHeight,
    timerFont=L.timerFont,alertFont=L.alertFont,alertHeight=L.alertHeight,
    countWidth=L.countWidth,countHeight=L.countHeight}
end

local function RestoreLayout(saved)
  for key,value in pairs(saved) do EW.layout[key]=value end
end

local function RestoreActiveGeometry()
  if activeGeometry then RestoreLayout(activeGeometry) end
  EW.reloadRequired=activeGeometry and (EW.db.width~=activeGeometry.width
    or EW.db.height~=activeGeometry.height or EW.db.gap~=activeGeometry.gap) or false
end

local function Ready()
  if not EW.runtimeEnabled or EW.view or InCombatLockdown() then return end
  EW.view=EW.View.New()
  EW.view:Layout(true)
  if EW.view.native.failed then EW.Say("原生显示初始化失败，请查看 /ew status。") end
end

local function ApplyLayout(forceNative)
  if InCombatLockdown() then EW.deferred=true; return end
  RestoreActiveGeometry()
  if EW.view then EW.view:Layout(forceNative == true) end
  EW.deferred=false
end

local function ReportError(where,err)
  local message=EW.IsSecret(err) and "受限制的错误信息" or tostring(err)
  local detail=where..": "..message
  local now=GetTime()
  if detail~=lastError or not lastErrorAt or now-lastErrorAt>=5 then
    EW.Record("error",now,detail)
    lastError,lastErrorAt=detail,now
  end
  if not EW.errorShown then EW.errorShown=true; EW.Say("检测到错误："..message.."；详情见 /ew status。") end
  if EW.model then EW.model:Uncertain(GetTime(),"运行异常，预测已暂停") end
end
EW.ReportError=ReportError

function EW.RefreshEnabledState(now, reason)
  if not initialized or not EW.db then
    EW.enabled=false; EW.runtimeEnabled=false
    return false
  end
  local previous=EW.runtimeEnabled == true
  EW.currentSpecID=EW.GetCurrentSpecID()
  EW.enabled=EW.GetMasterEnabled(EW.db)
  local specEnabled=EW.IsSpecEnabled(EW.db,EW.currentSpecID)
  EW.runtimeEnabled=EW.enabled and specEnabled
  if previous~=EW.runtimeEnabled then
    if InCombatLockdown() then EW.deferred=true end
    if EW.runtimeEnabled then
      Ready()
      if EW.view then EW.view:SetEnabled(true) end
      if EW.source then EW.source:Resync(now or GetTime(),reason or "启用监控") end
      if EW.Settings and EW.Settings.frame then EW.Settings:Sync() end
    else
      if EW.Alerts then EW.Alerts:Stop() end
      if EW.source then EW.source:Invalidate() end
      if EW.model then EW.model:Reset(now or GetTime(),reason or "监控已关闭") end
      if EW.view then EW.view:SetEnabled(false) end
      if EW.Settings and EW.Settings.frame then EW.Settings:Sync() end
    end
  end
  return EW.runtimeEnabled
end

function EW.SetMasterEnabled(value)
  if not EW.db or type(value)~="boolean" then return end
  local profile=EW.GetProfile(EW.db)
  if not profile then return end
  profile.masterEnabled=value
  EW.RefreshEnabledState(GetTime(),value and "已启用监控" or "已关闭监控")
  if EW.Settings and EW.Settings.Sync then EW.Settings:Sync() end
end

function EW.SetSpecEnabled(id,value)
  if not EW.db or not EW.IsKnownSpec(id) or type(value)~="boolean" then return end
  local profile=EW.GetProfile(EW.db)
  if not profile then return end
  profile.specEnabled[EW.SpecKey(id)]=value
  EW.RefreshEnabledState(GetTime(),EW.SpecLabel(id)..(value and "已启用" or "已关闭"))
  if EW.Settings and EW.Settings.Sync then EW.Settings:Sync() end
end

function EW.SetOption(key,value)
  if EW.defaults[key]==nil or not EW.db then return end
  local old=EW.db[key]
  EW.db[key]=value
  EW.db=EW.LoadSettings(EW.db)
  RestoreActiveGeometry()
  if EW.db[key]==old then return end
  if InCombatLockdown() then
    EW.deferred=true
    if EW.Settings and EW.Settings.frame then EW.Settings:Sync() end
    return
  end
  ApplyLayout(false)
  if EW.Settings and EW.Settings.frame then EW.Settings:Sync() end
end

function EW.ResetPosition()
  EW.db.point=nil; EW.db.scale=1; EW.db.alpha=1; EW.db.alertScale=1
  EW.db.width=EW.defaults.width; EW.db.height=EW.defaults.height; EW.db.gap=EW.defaults.gap
  EW.db=EW.LoadSettings(EW.db)
  RestoreActiveGeometry()
  if InCombatLockdown() then
    EW.deferred=true
  else
    ApplyLayout(true)
  end
  if EW.Settings and EW.Settings.Sync then EW.Settings:Sync() end
end

local function Status()
  if not EW.model then return end
  local spec=EW.currentSpecID and EW.SpecLabel(EW.currentSpecID) or "未知专精"
  local master=EW.GetMasterEnabled(EW.db) and "角色开关开" or "角色开关关"
  local specEnabled=EW.IsSpecEnabled(EW.db,EW.currentSpecID) and "专精开关开" or "专精开关关"
  local runtime=EW.runtimeEnabled and "运行中" or "已停用"
  EW.Say(spec.." · "..master.." · "..specEnabled.." · "..runtime)
  local s=EW.model:Snapshot()
  EW.Say(string.format("%s · 预测 %d/5 · 欠层 %d · %.1f 秒 · 来源%s",s.state,s.count,s.debt,s.duration,
    EW.source.found and "已连接" or "未连接"))
  if s.reason~="" then EW.Say(s.reason) end
  if #EW.diag.errors==0 then EW.Say("尚未记录运行错误（不等于已通过游戏内验收）。") end
  for _,err in ipairs(EW.diag.errors) do EW.Say(err) end
end

local function Slash(message)
  if not initialized then return end
  local command,arg=strtrim(message or ""):lower():match("^(%S*)%s*(.-)$")
  local booleans={pips="showPips",timers="showTimers",text="showText",alert="showAlert",
    debt="showDebtAnim",gradient="showGradient",sound="sound"}
  local numbers={scale="scale",alpha="alpha",idle="idleAlpha",cancel="alertScale",at="alertAt",
    width="width",height="height",gap="gap"}
  if command=="" or command=="config" or command=="options" then EW.Settings:Toggle()
  elseif command=="on" then EW.SetMasterEnabled(true)
  elseif command=="off" then EW.SetMasterEnabled(false)
  elseif command=="spec" then
    if not EW.currentSpecID then EW.Say("当前专精尚不可读。"); return end
    if arg~="" and arg~="on" and arg~="off" then EW.Say("请输入 /ew spec on 或 /ew spec off。"); return end
    local value=arg=="on"
    if arg=="" then value=not EW.IsSpecEnabled(EW.db,EW.currentSpecID) end
    EW.SetSpecEnabled(EW.currentSpecID,value)
  elseif command=="status" or command=="state" then Status()
  elseif booleans[command] then
    local key=booleans[command]
    if arg~="" and arg~="on" and arg~="off" then EW.Say("请输入 on 或 off。"); return end
    local value=arg=="on"
    if arg=="" then value=not EW.db[key] end
    EW.SetOption(key,value)
  elseif numbers[command] then
    local value=tonumber(arg)
    if not value then EW.Say("请输入数值。"); return end
    EW.SetOption(numbers[command],value)
  elseif command=="lock" then EW.SetOption("locked",true)
  elseif command=="unlock" then EW.SetOption("locked",false)
  elseif command=="reset" then EW.ResetPosition()
  elseif command=="resync" then
    if not EW.runtimeEnabled then EW.Say("监控当前已关闭，请先使用 /ew on。")
    else EW.source:Resync(GetTime(),"手动重新同步") end
  elseif command=="preview" then
    local modes={normal=true,debt=true,cancel=true,uncertain=true,off=true}
    if modes[arg] and EW.view then EW.view.previewMode=arg~="off" and arg or nil
    else EW.Say("/ew preview normal|debt|cancel|uncertain|off") end
  else EW.Say("/ew 设置 · on/off 总开关 · spec on/off 当前专精 · status 状态 · resync 同步") end
  if EW.Settings and EW.Settings.Sync then EW.Settings:Sync() end
end
SLASH_EXECUTIONERWATCH1="/ew"
SlashCmdList.EXECUTIONERWATCH=Slash

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
frame:SetScript("OnEvent",function(_,event,a1,a2,a3)
  local ok,err=pcall(function()
    if event=="ADDON_LOADED" and a1==addonName then
      EW.db=EW.LoadSettings(ExecutionerWatchDB); ExecutionerWatchDB=EW.db
      activeGeometry=SnapshotLayout()
      EW.currentSpecID=EW.GetCurrentSpecID()
      EW.enabled=EW.GetMasterEnabled(EW.db)
      EW.runtimeEnabled=EW.enabled and EW.IsSpecEnabled(EW.db,EW.currentSpecID)
      EW.model=EW.Model.New(EW.db.duration,EW.Record)
      EW.source=EW.Source.New(EW.model)
      EW.model:Uncertain(GetTime(),"等待初始同步")
      initialized=true
    elseif initialized then
      local now=GetTime()
      if event=="PLAYER_LOGIN" then
        EW.RefreshEnabledState(now,"登录")
        if EW.runtimeEnabled then
          Ready(); EW.source:LoadIDs(); EW.source:Scan(now); EW.source:Observe(now)
        end
        EW.Say(EW.version.." 已载入。武器战首次默认开启；狂暴/防护默认关闭。/ew 设置，/ew on|off 切换。")
      elseif event=="PLAYER_ENTERING_WORLD" then
        EW.RefreshEnabledState(now,"进入世界")
        if EW.runtimeEnabled then
          EW.source:Invalidate()
          EW.model:Uncertain(now,"进入世界，等待同步")
          Ready(); EW.source:LoadIDs(); EW.source:Scan(now); EW.source:Observe(now)
        end
      elseif event=="PLAYER_REGEN_ENABLED" then
        if EW.deferred or (EW.view and EW.view.deferred) then
          RestoreActiveGeometry()
          if EW.view then EW.view:Layout(true) else Ready() end
        end
        EW.deferred=false
        if EW.runtimeEnabled then Ready(); EW.source:Observe(now) end
      elseif event=="PLAYER_REGEN_DISABLED" then
        if EW.view and EW.view.root then EW.view.root:StopMovingOrSizing(); EW.view.previewMode=nil end
      elseif event=="PLAYER_SPECIALIZATION_CHANGED" and not EW.IsSecret(a1) and a1=="player" then
        EW.RefreshEnabledState(now,"专精变化")
        if EW.runtimeEnabled then EW.source:Resync(now,"专精变化") end
      end
    end
  end)
  if not ok then ReportError(event,err) end
end)

frame:SetScript("OnUpdate",function(_,elapsed)
  if not initialized then return end
  renderClock=renderClock+elapsed; scanClock=scanClock+elapsed; idClock=idClock+elapsed
  if renderClock<1/30 then return end
  local delta=renderClock; renderClock=0
  local ok,err=pcall(function()
    local now=GetTime()
    if not EW.runtimeEnabled then return end
    EW.source:Step(now)
    if scanClock>=1 then
      scanClock=0
      if idClock>=5 then idClock=0; EW.source:LoadIDs() end
      EW.source:Scan(now); EW.source:Observe(now)
    end
    local s=EW.model:Snapshot()
    if EW.view and EW.view.native.failed then
      EW.model:Uncertain(now,"原生显示不可用"); s=EW.model:Snapshot()
    end
    EW.UpdateDiagnostics(s,EW.source)
    EW.Alerts:Update(s,EW.db)
    if EW.view then EW.view:Render(s,now,delta) end
  end)
  if not ok then ReportError("update",err) end
end)
