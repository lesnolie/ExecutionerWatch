local _, EW = ...
if not EW.enabled then return end
local D = {version=EW.version, revision=0, eventSeq=0, events={}, errors={}, state="IDLE", stacks=0, debt=0}
EW.diag, ExecutionerWatchDiag = D, D
function EW.Record(kind, at, detail)
  D.eventSeq = D.eventSeq + 1
  D.revision = D.revision + 1
  D.events[(D.eventSeq-1)%100+1] = {seq=D.eventSeq, at=at, kind=kind, detail=detail or ""}
  if kind == "error" then
    D.errors[#D.errors+1] = detail
    if #D.errors > 20 then table.remove(D.errors, 1) end
  end
end
function EW.UpdateDiagnostics(snapshot, source)
  D.state, D.stacks, D.debt, D.records = snapshot.state, snapshot.count, snapshot.debt, snapshot.records
  D.duration, D.lastReason, D.cdm = snapshot.duration, snapshot.reason, source and source.found or false
end
