local W=dofile("tests/wow.lua")
local EW=W.Load()
W.Event("ADDON_LOADED","ExecutionerWatch")
W.Event("PLAYER_LOGIN")
W.Advance(0.1)
assert(EW.view and not EW.view.native.failed)
assert(EW.model.state=="IDLE")
W.combat=true
local tests=0
local function test(name,run)
  EW.source:Removed(W.now); W.Advance(0.3)
  run(); assert(#EW.diag.errors==0,table.concat(EW.diag.errors,"\n"))
  tests=tests+1; print("PASS "..name)
end
local function Cast()
  if EW.model.state=="IDLE" then W.icon:TriggerAuraAppliedAlert()
  else W.icon:OnUnitAuraUpdatedEvent() end
end
test("unrelated added buff cannot create Executioner stack",function()
  W.icon:OnUnitAuraAddedEvent({addedAuras={{spellId=999999}}})
  W.Advance(0.3); assert(EW.model.count==0)
end)
test("repeated application separated by 100ms produces one stack",function()
  W.icon:TriggerAuraAppliedAlert(); W.Advance(0.1); W.icon:TriggerAuraAppliedAlert()
  W.Advance(0.1); assert(EW.model.count==1)
end)
test("dual viewers never double count targeted updates",function()
  W.icon:TriggerAuraAppliedAlert(); W.bar:TriggerAuraAppliedAlert()
  W.Advance(1)
  W.icon:OnUnitAuraUpdatedEvent(); W.bar:OnUnitAuraUpdatedEvent()
  W.Advance(0.1); assert(EW.model.count==2)
end)
test("two targeted updates 100ms apart are not coalesced",function()
  Cast(); W.Advance(1)
  W.icon:OnUnitAuraUpdatedEvent(); W.Advance(0.1); Cast(); W.Advance(0.3)
  assert(EW.model.state=="ACTIVE" and EW.model.count==3)
end)
test("unclassified update pauses predictions in combat",function()
  Cast(); W.Advance(1); EW.model:Updated(W.now); W.Advance(0.3)
  assert(EW.model.state=="UNCERTAIN" and #EW.model:Snapshot().rows==0)
  assert(EW.view.native.stacks.alpha==1,"fallback native layer remains visible")
end)
test("uncertain + remove + new application recovers",function()
  EW.model:Uncertain(W.now,"test")
  W.icon:OnUnitAuraRemovedEvent(); W.Advance(0.1)
  W.icon:TriggerAuraAppliedAlert(); W.Advance(0.1)
  assert(EW.model.count==1 and EW.model.state=="ACTIVE")
end)
test("remove and immediately reapply opens a new timeline",function()
  Cast(); W.Advance(1); W.icon:OnUnitAuraUpdatedEvent()
  W.icon:OnUnitAuraRemovedEvent(); W.icon:TriggerAuraAppliedAlert()
  W.Advance(0.4); assert(EW.model.state=="ACTIVE" and EW.model.count==1)
end)
test("speculative cast source is not used; secret frame IDs are rejected",function()
  W.Event("UNIT_SPELLCAST_SUCCEEDED","player",W.Secret(),W.Secret())
  W.Advance(0.1); assert(EW.model.count==0)
  W.Event("UNIT_SPELLCAST_SUCCEEDED","player","unused",445579)
  assert(EW.model.count==0)
  local cid=W.icon.cooldownID; W.icon.cooldownID=W.Secret()
  W.icon:TriggerAuraAppliedAlert(); assert(EW.model.count==0)
  W.icon.cooldownID=cid
end)
test("native layer is never faded out merely because prediction is idle",function()
  EW.db.idleAlpha=0; EW.db.locked=true
  W.Advance(1)
  assert(EW.model.state=="IDLE" and EW.view.fade==0)
  assert(EW.view.root.alpha==EW.db.alpha and EW.view.native.stacks.alpha==1)
  assert(EW.view.overlay.alpha==0)
end)
test("fresh application recovers from unknown timeline without removal",function()
  EW.model:Uncertain(W.now,"missed removal")
  W.icon:TriggerAuraAppliedAlert(); W.Advance(.1)
  assert(EW.model.state=="ACTIVE" and EW.model.count==1)
end)
test("sound is independent from alert text and fires on transition only",function()
  EW.db.showAlert=false; EW.db.sound=true
  local start=W.sounds
  for _=1,6 do Cast(); W.Advance(1) end
  assert(EW.model:Debt()==1)
  W.Advance(14.2)
  assert(EW.model.count==2 and W.sounds==start+1)
  W.Advance(0.3); assert(W.sounds==start+1)
  EW.db.showAlert=true
end)
test("changing threshold during combat needs no native reconstruction",function()
  EW.SetOption("alertAt",3)
  assert(EW.db.alertAt==3)
  W.Advance(0.1)
  EW.SetOption("scale",1.25)
  assert(EW.view.root.scale==1,"layout deferred")
  W.combat=false; W.Event("PLAYER_REGEN_ENABLED")
  assert(EW.view.root.scale==1.25)
  EW.SetOption("scale",1); W.combat=true
end)
test("partial native aura during reload never creates five fake timers",function()
  W.combat=false; W.aura={applications=3,duration=18,expirationTime=W.now+10}
  W.Event("PLAYER_ENTERING_WORLD"); W.Advance(0.4)
  assert(EW.model.state=="UNCERTAIN")
  W.aura=nil; W.Event("PLAYER_REGEN_ENABLED"); assert(EW.model.state=="IDLE")
  W.combat=true
end)
test("secret aura values even out of combat never enter model",function()
  W.combat=false; W.aura={applications=W.Secret(),duration=W.Secret(),expirationTime=W.Secret()}
  EW.source:Observe(W.now+1)
  assert(EW.model.count==0)
  W.aura=nil; W.combat=true
end)
test("settings and all slash controls operate without unknown methods",function()
  W.combat=false; W.aura=nil
  SlashCmdList.EXECUTIONERWATCH("")
  assert(ExecutionerWatchSettings:IsShown())
  for _,command in ipairs({"pips off","pips on","timers off","timers on","text on","text off",
    "debt off","debt on","gradient off","gradient on","alert off","alert on",
    "unlock","lock","scale 0.8","alpha 0.8","idle 0.1","cancel 1.25","at 2",
    "sound off","sound on","preview normal","preview debt","preview cancel","preview uncertain",
    "preview off","resync","reset","status"}) do
    SlashCmdList.EXECUTIONERWATCH(command); W.Advance(0.1)
  end
  assert(EW.view.root.scale==1)
  ExecutionerWatchSettings:Hide()
  W.combat=true
end)
test("preview shows all states without changing model or playing sound",function()
  W.combat=false
  local sound=W.sounds
  for _,mode in ipairs({"normal","debt","cancel","uncertain"}) do
    EW.view.previewMode=mode; W.Advance(0.2)
    assert(EW.model.state=="IDLE" and W.sounds==sound)
  end
  EW.view.previewMode=nil; W.combat=true
end)
test("native init failure is surfaced and disables false predictions",function()
  -- Run constructor with an unavailable intrinsic to test explicit failure.
  W.combat=false; W.missingNative=true
  local old=EW.view
  local broken=EW.View.New()
  assert(broken.native.failed and #EW.diag.errors>0)
  EW.diag.errors={}; W.missingNative=false; EW.view=old; W.combat=true
end)
test("hook errors are contained and repeated failures do not flood diagnostics",function()
  local refresh=EW.model.TargetRefresh
  EW.model.TargetRefresh=function() error("injected callback fault") end
  for _=1,10 do W.icon:OnUnitAuraUpdatedEvent() end
  assert(EW.model.state=="UNCERTAIN" and #EW.diag.errors==1)
  EW.model.TargetRefresh=refresh; EW.diag.errors={}
end)
test("red timer transfers into green slot with remaining seconds intact",function()
  EW.db.showTimers=true; EW.db.showDebtAnim=true
  EW.view.previewMode=nil
  local now=W.now
  EW.model:Reset(now)
  for t=1,6 do EW.model:Add(now+t-19,"fixture") end
  EW.model:Advance(now)
  EW.view:Render(EW.model:Snapshot(),now,.04)
  assert(EW.view.debts[1].text.text=="5.0")
  EW.model:Add(now,"fixture")
  EW.view:Render(EW.model:Snapshot(),now,.04)
  assert(EW.view.texts[5].text=="5.0")
  assert(EW.view.debts[1].text.text=="18.0")
  EW.view:Render(EW.model:Snapshot(),now+1,.04)
  assert(EW.view.debts[1].text.text=="17.0")
  EW.db.showTimers=false
  EW.view:Render(EW.model:Snapshot(),now+1,.04)
  assert(EW.view.debts[1].text.text=="")
  EW.db.showTimers=true
  EW.model:Reset(now+2)
  EW.view:Render(EW.model:Snapshot(),now+2,.04)
  assert(EW.view.debts[1].alpha==0 and EW.view.debts[1].text.text=="")
end)
print("INTEGRATION_TESTS_OK "..tests)
