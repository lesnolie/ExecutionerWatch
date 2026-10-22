local W=dofile("tests/wow.lua")
-- Non-warrior must not create any plugin frames or register slash commands.
W.warrior=false
local before=#W.frames
local disabled=W.Load()
assert(not disabled.enabled and #W.frames==before and SlashCmdList.EXECUTIONERWATCH==nil)
W.warrior=true
ExecutionerWatchDB={scale=0/0,alpha="bad",point={"INVALID","CENTER",1,2},
  showText=true,showPips=false,sound=false,alertAt=99,debtMax=-4}
W.combat=true
local EW=W.Load()
W.Event("ADDON_LOADED","ExecutionerWatch"); W.Event("PLAYER_LOGIN")
assert(EW.view==nil,"combat reload must defer native construction")
assert(EW.db.showText and not EW.db.showPips and not EW.db.sound,"old booleans retained")
assert(EW.db.scale==1 and EW.db.alpha==1 and EW.db.point==nil and EW.db.alertAt==4)
W.combat=false; W.Event("PLAYER_REGEN_ENABLED"); W.Advance(0.1)
assert(EW.view and not EW.view.native.failed)
assert(#EW.diag.errors==0,table.concat(EW.diag.errors,"\n"))
print("LIFECYCLE_TESTS_OK")
