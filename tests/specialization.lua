local W=dofile("tests/wow.lua")
local EW=W.Load()
ExecutionerWatchDB={}
W.Event("ADDON_LOADED","ExecutionerWatch")
W.Event("PLAYER_LOGIN")
W.Advance(0.1)

assert(EW.currentSpecID==71 and EW.runtimeEnabled and EW.view.root.shown)
local profile=EW.GetProfile(EW.db)
assert(profile.specEnabled["72"]==false and profile.specEnabled["73"]==false)
W.icon:TriggerAuraAppliedAlert(); W.Advance(0.1)
assert(EW.model.count==1)

-- Fury starts disabled. Switching specialization stops evidence, resets stale
-- prediction state, and hides the HUD without changing the Arms preference.
W.spec=72
W.Event("PLAYER_SPECIALIZATION_CHANGED","player")
assert(not EW.runtimeEnabled and EW.model.state=="IDLE" and not EW.view.root.shown)
assert(profile.specEnabled["71"]==true and profile.specEnabled["72"]==false)
local sounds=W.sounds
W.icon:TriggerAuraAppliedAlert(); W.Advance(0.4)
assert(EW.model.count==0 and W.sounds==sounds and not EW.Alerts.active)

-- A spec may be enabled independently while the character master stays on.
SlashCmdList.EXECUTIONERWATCH("spec on")
assert(EW.runtimeEnabled and EW.view.root.shown and profile.specEnabled["72"]==true)
W.icon:TriggerAuraAppliedAlert(); W.Advance(0.1)
assert(EW.model.count==1)

-- /ew off is a character-wide master switch and clears an active alert state.
EW.Alerts.active=true
SlashCmdList.EXECUTIONERWATCH("off")
assert(not EW.GetMasterEnabled(EW.db) and not EW.runtimeEnabled)
assert(EW.model.count==0 and not EW.Alerts.active and not EW.view.root.shown)
assert(profile.specEnabled["72"]==true,"master off does not erase the spec preference")

W.spec=71
W.Event("PLAYER_SPECIALIZATION_CHANGED","player")
assert(not EW.runtimeEnabled,"master off overrides the Arms default")
SlashCmdList.EXECUTIONERWATCH("on")
assert(EW.GetMasterEnabled(EW.db) and EW.runtimeEnabled and EW.view.root.shown)

-- Combat can stop processing immediately, but protected frame visibility and
-- layout only change after regen.
W.combat=true
SlashCmdList.EXECUTIONERWATCH("off")
assert(not EW.runtimeEnabled and EW.model.state=="IDLE")
assert(EW.view.root.shown,"protected root visibility must be deferred in combat")
assert(EW.deferred)
W.combat=false
W.Event("PLAYER_REGEN_ENABLED")
assert(not EW.view.root.shown)

W.combat=true
SlashCmdList.EXECUTIONERWATCH("on")
assert(EW.runtimeEnabled and not EW.view.root.shown)
W.combat=false
W.Event("PLAYER_REGEN_ENABLED")
assert(EW.view.root.shown and EW.source.found)
assert(#EW.diag.errors==0,table.concat(EW.diag.errors,"\n"))

print("SPECIALIZATION_TESTS_OK")
