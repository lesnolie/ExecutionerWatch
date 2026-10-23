local W=dofile("tests/wow.lua")
local EW=W.Load()
ExecutionerWatchDB={}
W.Event("ADDON_LOADED","ExecutionerWatch")
W.Event("PLAYER_LOGIN")
W.Advance(0.2)
assert(EW.view.root.width==136 and EW.layout.width==24)
local frames=#W.frames
local native=EW.view.native
for i=1,30 do
  EW.SetOption("width",i%2==0 and 36 or 25)
  EW.SetOption("height",90)
  EW.SetOption("gap",8)
  W.Advance(.2)
end
assert(#W.frames==frames and EW.view.native==native,"size edits never allocate native trees")
assert(EW.db.width==36 and EW.db.height==90 and EW.db.gap==8)
assert(EW.layout.width==24 and EW.view.root.width==136 and EW.reloadRequired)
EW.SetOption("scale",1.5)
assert(EW.view.root.scale==1.5)
W.combat=true
EW.SetOption("height",120)
EW.SetOption("alpha",EW.db.alpha)
assert(EW.layout.height==48 and EW.layout.width==24,"same-value edits cannot leak saved geometry")
EW.SetOption("scale",2)
assert(EW.view.root.scale==1.5)
W.combat=false
W.Event("PLAYER_REGEN_ENABLED")
assert(EW.view.root.scale==2 and EW.layout.height==48 and EW.reloadRequired)
assert(#W.frames==frames)
assert(#EW.diag.errors==0,table.concat(EW.diag.errors,"\n"))
-- Simulate a reload with persisted configuration and a fresh frame registry.
W.frames={}
local reloaded=W.Load()
W.Event("ADDON_LOADED","ExecutionerWatch")
W.Event("PLAYER_LOGIN")
assert(reloaded.view.root.width==212 and reloaded.view.root.height==120)
assert(reloaded.view.slots[1].frame.width==36 and reloaded.view.gaps[1].width==8)
assert(not reloaded.reloadRequired and not reloaded.view.native.failed)
assert(#reloaded.diag.errors==0,table.concat(reloaded.diag.errors,"\n"))
print("LAYOUT_TESTS_OK")
