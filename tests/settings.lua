local W=dofile("tests/wow.lua")
local EW=W.Load()

local migrated=EW.LoadSettings({
  masterEnabled=false,
  specEnabled={["71"]=false,["72"]=true,["73"]="bad"},
  width=999,height=-1,gap=0,scale=0/0,
})
local main=EW.GetProfile(migrated)
assert(EW.characterKey=="Main-TestRealm")
assert(main.masterEnabled==false,"master off must survive migration")
assert(main.specEnabled["71"]==false)
assert(main.specEnabled["72"]==true)
assert(main.specEnabled["73"]==false,"missing or invalid spec values use the off default")
assert(migrated.masterEnabled==nil and migrated.specEnabled==nil)
assert(migrated.width==60 and migrated.height==24 and migrated.gap==2 and migrated.scale==1)
assert(EW.layout.width==60 and EW.layout.height==24 and EW.layout.gap==2)

local fresh=EW.LoadSettings({})
local mainFresh=EW.GetProfile(fresh)
assert(mainFresh.masterEnabled==true)
assert(mainFresh.specEnabled["71"]==true,"Arms defaults on")
assert(mainFresh.specEnabled["72"]==false,"Fury defaults off")
assert(mainFresh.specEnabled["73"]==false,"Protection defaults off")
assert(fresh.width==24 and fresh.height==48 and fresh.gap==4)

-- Different characters have independent master and spec preferences.
mainFresh.masterEnabled=false
mainFresh.specEnabled["71"]=false
W.playerName="Alt"
local alt=EW.LoadSettings(fresh)
local altProfile=EW.GetProfile(alt)
assert(EW.characterKey=="Alt-TestRealm")
assert(altProfile.masterEnabled==true and altProfile.specEnabled["71"]==true)
W.playerName="Main"
local mainAgain=EW.LoadSettings(alt)
local mainAgainProfile=EW.GetProfile(mainAgain)
assert(mainAgainProfile.masterEnabled==false and mainAgainProfile.specEnabled["71"]==false)

print("SETTINGS_TESTS_OK")
