local _, EW = ...
if not EW.enabled then return end

-- Pure Lua model: only public, normalized evidence enters here. No game API,
-- frames, saved variables, or secret values. Records predict stack-loss times;
-- they are NOT independent aura instances supplied by the game.
local Model = {}
Model.__index = Model
EW.Model = Model

function Model.New(duration, emit)
  return setmetatable({state="IDLE", reason="", count=0, queue={}, duration=duration or 18,
    nextID=0, generation=0, revision=0, lastExpiry=-math.huge, recentExpiries={},
    lastCast=-math.huge, lastApply=-math.huge, emit=emit or function() end}, Model)
end
function Model:Changed(kind, at, detail)
  self.revision = self.revision + 1
  self.emit(kind, at, detail or "")
end
function Model:Reset(at, reason)
  self.generation = self.generation + 1
  self.queue, self.count, self.state, self.reason = {}, 0, "IDLE", ""
  self.lastCast, self.lastApply, self.lastExpiry = -math.huge, -math.huge, -math.huge
  self.recentExpiries = {}
  self:Changed("reset", at, reason)
end
function Model:Uncertain(at, reason)
  if self.state == "UNCERTAIN" and self.reason == reason then return end
  self.queue, self.count, self.state, self.reason = {}, 0, "UNCERTAIN", reason
  self.lastCast, self.lastApply = -math.huge, -math.huge
  self:Changed("uncertain", at, reason)
end
function Model:Debt() return math.max(0, #self.queue - self.count) end
function Model:Add(at, source, expiration)
  if #self.queue >= 128 then self:Uncertain(at,"触发数量异常"); return end
  self.nextID = self.nextID + 1
  self.queue[#self.queue + 1] = {id=self.nextID, createdAt=at,
    expiresAt=expiration or at+self.duration, duration=self.duration, source=source}
  table.sort(self.queue, function(a,b)
    if a.expiresAt == b.expiresAt then return a.id < b.id end
    return a.expiresAt < b.expiresAt
  end)
  self.count = math.min(EW.cap, self.count + 1)
  self.state, self.reason = "ACTIVE", ""
  self:Changed(self:Debt() > 0 and "overflow" or "add", at, source)
end
function Model:Advance(now)
  if self.state ~= "ACTIVE" then return end
  local removed = 0
  while self.queue[1] and self.queue[1].expiresAt <= now do
    self.lastExpiry = self.queue[1].expiresAt
    self.recentExpiries[#self.recentExpiries+1] = {at=self.lastExpiry}
    table.remove(self.queue, 1)
    self.count = math.max(0, self.count - 1)
    removed = removed + 1
  end
  if removed > 0 then self:Changed("expire", now, tostring(removed)) end
  while self.recentExpiries[1] and now-self.recentExpiries[1].at>0.20 do
    table.remove(self.recentExpiries,1)
  end
  if self.count == 0 then
    -- Predicted exhaustion is not proof that the native aura is absent.
    self:Uncertain(now, "等待增益结束确认")
  end
end
function Model:NearExpiry(at)
  if math.abs(at - self.lastExpiry) <= 0.20 then return true end
  for _, record in ipairs(self.queue) do
    if math.abs(record.expiresAt - at) <= 0.20 then return true end
  end
  return false
end
function Model:Cast(at)
  local canRestart=self.state=="ACTIVE" and self:Debt()==0
  self:Advance(at)
  if canRestart and self.state=="UNCERTAIN" and self.reason=="等待增益结束确认" then self.state="IDLE" end
  if self.state == "UNCERTAIN" then return end
  -- Initial application and its proc callback describe the SAME new aura.
  local paired = self.lastApply > self.lastCast and at - self.lastApply <= 0.25
  self.lastCast = at
  if not paired then self:Add(at, "公开触发事件（预测）") end
end
function Model:Applied(at)
  self:Advance(at)
  -- A targeted NEW aura application supplies a fresh cycle even if its prior
  -- removal was missed. Generic updates may never perform this recovery.
  if self.state == "UNCERTAIN" then self:Reset(at,"新的完整增益周期") end
  if at - self.lastApply <= 0.25 then return end -- icon + bar viewers
  self.lastApply = at
  if at - self.lastCast <= 0.25 then return end
  if self.state == "IDLE" then
    self:Add(at, "新增增益（预测）")
  elseif self.state == "ACTIVE" then
    self:Uncertain(at, "应用事件无法与当前时间轴对应")
  end
end
function Model:TargetRefresh(at)
  -- Only the selected Executioner CDM item's targeted update enters here.
  -- Historical combat logs support the legacy 18-second loss-queue model;
  -- a generic UNIT_AURA refresh must continue to use Updated(), not this.
  if self.state ~= "ACTIVE" then return end
  self:Advance(at)
  if self.state ~= "ACTIVE" then return end
  for _,expiry in ipairs(self.recentExpiries) do
    if not expiry.matched and math.abs(at-expiry.at)<=0.20 then
      expiry.matched=true
      self:Changed("matched-expiry",at)
      return
    end
  end
  local first=self.queue[1]
  if first and first.expiresAt-at<=0.20 then
    -- Server removal can arrive slightly before its predicted local time.
    table.remove(self.queue,1)
    self.count=math.max(0,self.count-1)
    self.lastExpiry=first.expiresAt
    self:Changed("matched-expiry",at)
    if self.count==0 then self:Uncertain(at,"等待增益结束确认") end
    return
  end
  self:Add(at,"处刑者定向刷新（预测）")
end
function Model:Updated(at)
  if self.state == "UNCERTAIN" then return end
  if math.abs(at-self.lastCast) <= 0.25 or math.abs(at-self.lastApply) <= 0.25 or self:NearExpiry(at) then
    self:Changed("matched-update", at)
    return
  end
  -- An unexplained refresh may be a missed gain, loss, or overflow.
  self:Uncertain(at, "增益刷新无法区分加层与掉层")
end
function Model:Observe(at, count, duration, expiration)
  if count == 0 then
    if self.state ~= "IDLE" then self:Reset(at, "确认增益消失") end
    if duration then self.duration = duration end
    return
  end
  if duration and math.abs(duration-self.duration) > 0.1 then
    self.duration = duration
    if self.state == "ACTIVE" then self:Uncertain(at, "持续时间变化") end
  end
  self:Advance(at)
  -- Only a SINGLE readable application can reconstruct an individual timer.
  -- Multi-stack aggregate expiration has no validated per-stack meaning.
  if self.state ~= "ACTIVE" and count == 1 and expiration and expiration > at then
    self:Reset(at, "单层公开数据同步")
    self:Add(expiration-self.duration, "公开单层同步", expiration)
    self.lastCast, self.lastApply = at, at
  elseif self.state == "ACTIVE" and count ~= self.count then
    self:Uncertain(at, "公开层数与预测不一致")
  elseif self.state == "IDLE" and count > 0 then
    self:Uncertain(at, "已有多层，缺少独立时间记录")
  end
end
function Model:Snapshot()
  local rows, debtRows = {}, {}
  for i,r in ipairs(self.queue) do
    local target=i<=self.count and rows or debtRows
    target[#target+1]={id=r.id, createdAt=r.createdAt, expiresAt=r.expiresAt, duration=r.duration}
  end
  return {state=self.state, reason=self.reason, count=self.count, debt=self:Debt(),
    records=#self.queue, rows=rows, debtRows=debtRows, duration=self.duration, revision=self.revision}
end
