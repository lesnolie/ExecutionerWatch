-- Bootstrap: .toc loads the modules first; this file owns lifecycle only.
local addonName, EW = ...
if not EW.enabled then return end

local frame=CreateFrame("Frame")
local initialized=false
local scanClock, renderClock, idClock=0,0,0
local lastError, lastErrorAt
local function Ready()
  if EW.view or InCombatLockdown() then return end
  EW.view=EW.View.New()
  if EW.view.native.failed then EW.Say("原生显示初始化失败，请查看 /ew status。") end
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
function EW.SetOption(key,value)
  if EW.defaults[key]==nil then return end
  local old=EW.db[key]
  EW.db[key]=value
  EW.db=EW.LoadSettings(EW.db)
  if EW.db[key]==old then return end
  if InCombatLockdown() then EW.deferred=true
  elseif EW.view then EW.view:Layout() end
end
function EW.ResetPosition()
  EW.db.point=nil; EW.db.scale=1; EW.db.alpha=1; EW.db.alertScale=1
  if InCombatLockdown() then EW.deferred=true
  elseif EW.view then EW.view:Layout() end
end
local function Status()
  if not EW.model then return end
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
  local numbers={scale="scale",alpha="alpha",idle="idleAlpha",cancel="alertScale",at="alertAt"}
  if command=="" or command=="config" or command=="options" then EW.Settings:Toggle()
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
    EW.source.generation=EW.source.generation+1; EW.source.pending=nil
    EW.model:Uncertain(GetTime(),"等待公开数据或新的完整增益周期")
    EW.source:Observe(GetTime())
  elseif command=="preview" then
    local modes={normal=true,debt=true,cancel=true,uncertain=true,off=true}
    if modes[arg] and EW.view then EW.view.previewMode=arg~="off" and arg or nil
    else EW.Say("/ew preview normal|debt|cancel|uncertain|off") end
  else EW.Say("/ew 设置 · status 状态 · resync 同步 · pips/text/timers/debt/gradient/alert/sound on|off") end
  EW.Settings:Sync()
end
SLASH_EXECUTIONERWATCH1="/ew"
SlashCmdList.EXECUTIONERWATCH=Slash

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
-- Passive Slayer's Strike did not emit a public success event in the saved
-- combat traces. Do not depend on (or double-count) that speculative source.
frame:SetScript("OnEvent",function(_,event,a1,a2,a3)
  local ok,err=pcall(function()
    if event=="ADDON_LOADED" and a1==addonName then
      EW.db=EW.LoadSettings(ExecutionerWatchDB); ExecutionerWatchDB=EW.db
      EW.model=EW.Model.New(EW.db.duration,EW.Record)
      EW.source=EW.Source.New(EW.model)
      EW.model:Uncertain(GetTime(),"等待初始同步")
      initialized=true
    elseif initialized then
      local now=GetTime()
      if event=="PLAYER_LOGIN" then
        Ready(); EW.source:LoadIDs(); EW.source:Scan(now); EW.source:Observe(now)
        EW.Say(EW.version.." 已载入，/ew 打开设置。~ 表示预测，? 表示预测暂停。")
      elseif event=="PLAYER_ENTERING_WORLD" then
        EW.source.generation=EW.source.generation+1; EW.source.pending=nil
        EW.model:Uncertain(now,"进入世界，等待同步")
        Ready(); EW.source:LoadIDs(); EW.source:Scan(now); EW.source:Observe(now)
      elseif event=="PLAYER_REGEN_ENABLED" then
        Ready(); EW.source:Observe(now)
        if EW.view and (EW.deferred or EW.view.deferred) then EW.view:Layout() end
        EW.deferred=false
      elseif event=="PLAYER_REGEN_DISABLED" then
        if EW.view then EW.view.root:StopMovingOrSizing(); EW.view.previewMode=nil end
      elseif event=="PLAYER_SPECIALIZATION_CHANGED" and not EW.IsSecret(a1) and a1=="player" then
        EW.source:Removed(now)
        EW.model:Uncertain(now,"专精变化，等待同步")
        EW.source:LoadIDs(); EW.source:Scan(now); EW.source:Observe(now)
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
