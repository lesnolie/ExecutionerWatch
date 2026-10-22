local W=dofile("tests/wow.lua")
assert(loadfile("ExecutionerProbe/ExecutionerProbe.lua"))("ExecutionerProbe",{})
W.Event("ADDON_LOADED","ExecutionerProbe")
W.aura={applications=W.Secret(),duration=W.Secret(),expirationTime=W.Secret()}
W.Advance(0.3)
SlashCmdList.EXECUTIONERPROBE("show"); W.Advance(0.3)
ExecutionerWatchDiag={state="ACTIVE",stacks=2,debt=1,errors={},lastReason="",events={
  {seq=1,at=W.now,kind="add",detail="test"}}}
W.Advance(0.3)
SlashCmdList.EXECUTIONERPROBE("model")
SlashCmdList.EXECUTIONERPROBE("mark")
W.Event("ADDON_ACTION_BLOCKED","ExecutionerWatch","test")
local lines=ExecutionerProbeDB.sessions[1].lines
assert(#lines>=4)
assert(table.concat(lines,"\n"):find("MODEL"))
assert(table.concat(lines,"\n"):find("ADDON_ACTION_BLOCKED"))
SlashCmdList.EXECUTIONERPROBE("hide")
SlashCmdList.EXECUTIONERPROBE("clear")
assert(#ExecutionerProbeDB.sessions[1].lines==1)
print("PROBE_TESTS_OK")
