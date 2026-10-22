-- Optional diagnostics. Only public snapshots and addon-owned model events
-- are logged. Never reads protected-frame visibility/text as combat evidence.
local VERSION, SPELL, LIMIT, SESSION_LIMIT="0.9.1",445584,5000,8
local secret=issecretvalue or function() return false end
local session,lastSequence,lastState,poll= nil,0,nil,0
local function Public(v) return not secret(v) end
local function Value(v)
  if not Public(v) then return "S" end
  if type(v)=="number" then return string.format("%.3f",v) end
  if type(v)=="string" or type(v)=="boolean" then return tostring(v) end
  return "-"
end
local function Log(kind,text)
  if not session then return end
  if #session.lines>=LIMIT then session.truncated=true; return end
  session.lines[#session.lines+1]=string.format("%.3f %s %s",GetTime(),kind,text or "")
end
local function Model()
  local d=ExecutionerWatchDiag
  if type(d)~="table" then return end
  local events={}
  for _,entry in pairs(d.events or {}) do
    if entry.seq>lastSequence then events[#events+1]=entry end
  end
  table.sort(events,function(a,b) return a.seq<b.seq end)
  for _,entry in ipairs(events) do
    Log("MODEL",string.format("#%d at=%.3f %s %s",entry.seq,entry.at,entry.kind,entry.detail))
    lastSequence=entry.seq
  end
end
local function Observe()
  if InCombatLockdown() then return end
  if not (C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID) then return end
  local ok,a=pcall(C_UnitAuras.GetPlayerAuraBySpellID,SPELL)
  if not ok or not Public(a) then return end
  local state="absent"
  if type(a)=="table" then
    state="stacks="..Value(a.applications).." duration="..Value(a.duration).." expiration="..Value(a.expirationTime)
  end
  if state~=lastState then Log("PUBLIC-AURA",state); lastState=state end
end
local frame=CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("ADDON_ACTION_BLOCKED")
frame:RegisterEvent("ADDON_ACTION_FORBIDDEN")
frame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED","player")
frame:SetScript("OnEvent",function(_,event,a1,a2,a3)
  if event=="ADDON_LOADED" and a1=="ExecutionerProbe" then
    if type(ExecutionerProbeDB)~="table" then ExecutionerProbeDB={} end
    if type(ExecutionerProbeDB.sessions)~="table" then ExecutionerProbeDB.sessions={} end
    session={version=VERSION,t0=GetTime(),lines={}}
    local sessions=ExecutionerProbeDB.sessions
    sessions[#sessions+1]=session
    while #sessions>SESSION_LIMIT do table.remove(sessions,1) end
    Log("START",VERSION)
    print("|cff55c9af处刑者探针|r /eprobe model 查看状态，/eprobe mark 打标记。")
  elseif event=="PLAYER_REGEN_DISABLED" then Log("COMBAT","start")
  elseif event=="PLAYER_REGEN_ENABLED" then Log("COMBAT","end"); Observe()
  elseif event=="UNIT_SPELLCAST_SUCCEEDED" then
    if Public(a3) and type(a3)=="number" and a3==445579 then Log("PUBLIC-PROC",Value(a2)) end
  elseif event=="ADDON_ACTION_BLOCKED" or event=="ADDON_ACTION_FORBIDDEN" then
    if Public(a1) and (a1=="ExecutionerWatch" or a1=="ExecutionerProbe") then Log(event,Value(a2)) end
  end
end)
frame:SetScript("OnUpdate",function(_,elapsed)
  if not session then return end
  poll=poll+elapsed
  if poll<0.2 then return end
  poll=0; Model(); Observe()
end)
local display
local function Display()
  if display then return display end
  display=CreateFrame("Frame","ExecutionerProbeFrame",UIParent,"BackdropTemplate")
  display:SetSize(250,48); display:SetPoint("TOP",0,-120)
  display:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
  display:SetBackdropColor(0.04,0.06,0.07,0.95)
  local text=display:CreateFontString(nil,"OVERLAY")
  text:SetFont(STANDARD_TEXT_FONT or "Fonts\\ARKai_T.ttf",11,"OUTLINE")
  text:SetPoint("CENTER")
  display:SetScript("OnUpdate",function()
    local d=ExecutionerWatchDiag
    text:SetText(d and string.format("处刑者探针 · %s\n预测 %d/5 · 欠层 %d · 错误 %d",d.state,d.stacks,d.debt,#(d.errors or {})) or "处刑者监控尚未载入")
  end)
  return display
end
SLASH_EXECUTIONERPROBE1="/eprobe"
SlashCmdList.EXECUTIONERPROBE=function(message)
  local command=strtrim(message or ""):lower()
  if command=="mark" then Log("MARK","manual")
  elseif command=="clear" and session then
    session.lines={}; session.t0=GetTime(); ExecutionerProbeDB.sessions={session}; Log("CLEARED")
  elseif command=="show" then Display():Show()
  elseif command=="hide" then if display then display:Hide() end
  elseif command=="model" then
    local d=ExecutionerWatchDiag
    print(d and string.format("处刑者：%s 预测%d/5 欠层%d %s",d.state,d.stacks,d.debt,d.lastReason or "") or "未找到处刑者监控。")
  else print("/eprobe model 状态 · mark 标记 · clear 清空 · show/hide 诊断框。记录在退出或重载后保存。") end
end
