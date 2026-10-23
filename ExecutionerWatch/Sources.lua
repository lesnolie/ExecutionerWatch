local _, EW = ...
if not EW.isWarrior then return end
local Source = {}
Source.__index = Source
EW.Source = Source
local secret = EW.IsSecret
local function Public(value) return not secret(value) end
local function Number(value) return Public(value) and type(value)=="number" end
local function Active() return EW.enabled and EW.runtimeEnabled end

function Source.New(model)
  return setmetatable({model=model, ids={}, hooks=setmetatable({}, {__mode="k"}),
    found=false, generation=0, lastSignal=-math.huge}, Source)
end
function Source:Invalidate()
  self.generation = self.generation + 1
  self.pending = nil
end
function Source:Resync(now, reason)
  if not Active() then return end
  self:Invalidate()
  self.model:Uncertain(now, reason or "等待公开数据重新同步")
  self:LoadIDs()
  self:Scan(now)
  self:Observe(now)
end
function Source:Removed(at)
  if not Active() then return end
  -- Always reset, including UNCERTAIN with an empty queue. Invalidate deferred
  -- updates so they cannot reopen an old aura after a removal/spec change.
  self:Invalidate()
  self.model:Reset(at, "增益整体移除")
end
function Source:Applied(at)
  if not Active() then return end
  self.lastSignal = at
  self.model:Applied(at)
end
function Source:Updated(at)
  if not Active() then return end
  self.lastSignal = at
  self.model:TargetRefresh(at)
end
function Source:Step(now)
  if not Active() then return end
  self.model:Advance(now)
end
function Source:Observe(now)
  if not Active() then return end
  -- Out of combat is NOT proof a field is readable: test every value before
  -- branching, formatting or arithmetic. Never feed a secret into the model.
  if InCombatLockdown() or self.pending or now-self.lastSignal < 0.30 then return end
  if not (C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID) then return end
  local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, EW.spellID)
  if not ok or not Public(aura) then return end
  if aura == nil then self.model:Observe(now, 0); return end
  if type(aura) ~= "table" then return end
  local n, d, exp = aura.applications, aura.duration, aura.expirationTime
  if not Number(n) or n < 0 or n > EW.cap or n ~= math.floor(n) then return end
  if not Number(d) or d <= 0 or d > 120 then d=nil end
  if not Number(exp) or exp <= 0 then exp=nil end
  self.model:Observe(now, n, d, exp)
  if d then EW.db.duration=d end
end
function Source:LoadIDs()
  if not Active() then return end
  self.ids = {}
  if not (C_CooldownViewer and Enum and Enum.CooldownViewerCategory) then return end
  for _, category in pairs(Enum.CooldownViewerCategory) do
    local ok, ids = pcall(C_CooldownViewer.GetCooldownViewerCategorySet, category, true)
    if ok and Public(ids) and type(ids)=="table" then
      for _, id in ipairs(ids) do
        if Number(id) then
          local good, info = pcall(C_CooldownViewer.GetCooldownViewerCooldownInfo, id)
          if good and Public(info) and type(info)=="table" then
            local hit = (Number(info.spellID) and info.spellID == EW.spellID)
              or (Number(info.overrideSpellID) and info.overrideSpellID == EW.spellID)
            if Public(info.linkedSpellIDs) and type(info.linkedSpellIDs)=="table" then
              for _, linked in ipairs(info.linkedSpellIDs) do
                if Number(linked) and linked==EW.spellID then hit=true end
              end
            end
            if hit then self.ids[id]=true end
          end
        end
      end
    end
  end
end
function Source:Mine(frame)
  local cid=frame.cooldownID
  return Number(cid) and self.ids[cid] == true
end
function Source:Hook(frame)
  if self.hooks[frame] then return end
  self.hooks[frame]=true
  local function Bind(method, callback)
    if type(frame[method]) ~= "function" then return end
    hooksecurefunc(frame, method, function()
      -- Only one viewer supplies evidence. No secret arguments are observed.
      local ok,err=pcall(function()
        if Active() and self.frame==frame and self:Mine(frame) then callback(self, GetTime()) end
      end)
      if not ok then EW.ReportError("source:"..method,err) end
    end)
  end
  -- OnUnitAuraAddedEvent is broadcast for ALL added auras. Never hook it as a
  -- proc. TriggerAuraAppliedAlert is the targeted whole-aura application.
  Bind("TriggerAuraAppliedAlert", Source.Applied)
  Bind("OnUnitAuraUpdatedEvent", Source.Updated)
  if type(frame.OnUnitAuraRemovedEvent)=="function" then
    Bind("OnUnitAuraRemovedEvent", Source.Removed)
  else
    Bind("TriggerAuraRemovedAlert", Source.Removed)
  end
end
function Source:Scan(now)
  if not Active() then return end
  local selected
  for _, name in ipairs({"BuffIconCooldownViewer", "BuffBarCooldownViewer"}) do
    local viewer=_G[name]
    if viewer then
      local ok, frames=pcall(function()
        if viewer.GetItemFrames then return viewer:GetItemFrames() end
        return {viewer:GetChildren()}
      end)
      if ok and Public(frames) and type(frames)=="table" then
        for _, frame in ipairs(frames) do
          if self:Mine(frame) then
            if not selected or frame==self.frame then selected=frame end
          end
        end
      end
    end
  end
  if selected ~= self.frame then
    if self.model.state=="ACTIVE" then self.model:Uncertain(now,"事件来源变化，等待同步") end
    self.generation=self.generation+1
    self.pending=nil
    self.frame=selected
  end
  self.found=selected~=nil
  if selected then self:Hook(selected) end
end
