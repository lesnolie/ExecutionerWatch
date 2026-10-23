local W=dofile("tests/wow.lua")
local EW=W.Load()
ExecutionerWatchDB={}
W.Event("ADDON_LOADED","ExecutionerWatch")
W.Event("PLAYER_LOGIN")
W.Advance(0.2)

assert(EW.layout.width==24 and EW.layout.height==48 and EW.layout.gap==4)
assert(EW.view.root.width==136 and EW.view.root.height==48)
assert(EW.view.slots[1].frame.width==24 and EW.view.slots[1].frame.height==48)

local oldNative=EW.view.native
local oldFrames={}
for i,frame in ipairs(oldNative.frames) do oldFrames[i]=frame end
EW.SetOption("width",36)
EW.SetOption("height",90)
EW.SetOption("gap",8)
assert(EW.layout.width==36 and EW.layout.height==90 and EW.layout.gap==8)
assert(EW.view.root.width==212 and EW.view.root.height==90)
assert(EW.view.slots[1].frame.width==36 and EW.view.slots[1].frame.height==90)
assert(EW.view.gaps[1].width==8 and EW.view.gaps[1].height==90)
assert(EW.view.native==oldNative,"native rebuild is coalesced across slider updates")
W.Advance(0.2)
assert(EW.view.native~=oldNative,"native Aura layers rebuild after the coalescing window")
assert(#oldFrames==6)
for _,frame in ipairs(oldFrames) do assert(not frame.shown) end

EW.SetOption("scale",1.5)
assert(EW.view.root.scale==1.5 and EW.view.root.width==212)
assert(EW.view.slots[5].frame.width==36)

-- Size edits inside combat update SavedVariables but cannot resize or rebuild
-- any protected Aura tree. Regen applies the final coalesced dimensions.
W.combat=true
local frameCount=#W.frames
local native=EW.view.native
EW.SetOption("height",120)
W.Advance(0.2)
assert(EW.db.height==120 and EW.layout.height==90)
assert(EW.view.root.height==90 and EW.view.native==native)
assert(#W.frames==frameCount)
assert(EW.deferred)
W.combat=false
W.Event("PLAYER_REGEN_ENABLED")
assert(EW.layout.height==120 and EW.view.root.height==120)
assert(EW.view.native~=native and not EW.deferred)
assert(#EW.diag.errors==0,table.concat(EW.diag.errors,"\n"))

print("LAYOUT_TESTS_OK")
