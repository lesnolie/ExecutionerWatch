local EW={enabled=true,cap=5}
assert(loadfile('ExecutionerWatch/Model.lua'))('ExecutionerWatch',EW)
local sessions=dofile('tests/fixtures/combat-history.lua')
local checked,updates=0,0
for _,events in ipairs(sessions) do
  local model=EW.Model.New(18)
  local started=false
  local tick=events[1].at
  local i=1
  while i<=#events do
    local at=events[i].at
    while tick+1/30<at do tick=tick+1/30; model:Advance(tick) end
    local batch={}
    while events[i] and events[i].at==at do batch[#batch+1]=events[i]; i=i+1 end
    -- The old probe logged public UNIT_AURA before the CDM hook in the same
    -- dispatch. Compare after all callbacks at this timestamp, not halfway.
    for _,e in ipairs(batch) do
      if e.kind=='apply' then model:Applied(at); started=true
      elseif e.kind=='remove' then model:Reset(at,'removed')
      elseif e.kind=='update' then model:TargetRefresh(at); updates=updates+1 end
    end
    model:Advance(at)
    for _,e in ipairs(batch) do
      if e.kind=='observe' and started then
        assert(model.count==e.count,string.format('at %.2f predicted %d actual %d state %s',at,model.count,e.count,model.state))
        checked=checked+1
      end
    end
  end
end
assert(checked>=10 and updates>100,'fixture coverage unexpectedly small')
print('HISTORY_TESTS_OK '..checked..' public checkpoints; '..updates..' targeted refreshes')
