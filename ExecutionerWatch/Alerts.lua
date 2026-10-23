local _, EW = ...
if not EW.isWarrior then return end
EW.Alerts = {active=false}
function EW.Alerts:Stop()
  self.active = false
end
function EW.Alerts:Update(snapshot, db)
  if not EW.enabled or not EW.runtimeEnabled then
    self:Stop()
    return
  end
  local active=snapshot.state=="ACTIVE" and snapshot.debt>0 and snapshot.count>0 and snapshot.count<=db.alertAt
  if active and not self.active and db.sound and SOUNDKIT and SOUNDKIT.RAID_WARNING then
    PlaySound(SOUNDKIT.RAID_WARNING,"Master")
    EW.Record("alert",GetTime(),"预测欠层且达到提醒阈值")
  end
  self.active=active
end
