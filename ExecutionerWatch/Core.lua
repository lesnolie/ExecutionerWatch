local _, EW = ...

EW.version, EW.spellID, EW.procID, EW.cap = "0.10.0", 445584, 445579, 5
EW.white = "Interface\\Buttons\\WHITE8X8"
EW.font = STANDARD_TEXT_FONT or "Fonts\\ARKai_T.ttf"
EW.IsSecret = issecretvalue or function() return false end

-- Class is the only static load gate. The effective enabled state is resolved
-- per character and specialization after SavedVariables are available.
local classOK, _, classFile = pcall(UnitClass, "player")
EW.isWarrior = classOK and not EW.IsSecret(classFile) and classFile == "WARRIOR"
EW.enabled = false
EW.runtimeEnabled = false
if not EW.isWarrior then return end

EW.knownSpecs = {
  { id = 71, label = "武器", name = "Arms" },
  { id = 72, label = "狂暴", name = "Fury" },
  { id = 73, label = "防护", name = "Protection" },
}
EW.specDefaults = { [71] = true, [72] = false, [73] = false }
EW.layout = { width = 24, height = 48, gap = 4 }
EW.defaults = {
  locked = true, scale = 1, alpha = 1, idleAlpha = 0,
  alertScale = 1, alertAt = 2, sound = true, showPips = true, showText = false,
  showAlert = true, showTimers = true, showGradient = true, showDebtAnim = true,
  debtMax = 3, width = 24, height = 48, gap = 4,
}
EW.colors = {
  slot = {0.055, 0.065, 0.075, 0.85}, line = {0.015, 0.022, 0.026, 1},
  low = {0.08, 0.49, 0.44, 1}, high = {0.20, 0.73, 0.62, 1},
  debtLow = {0.61, 0.12, 0.13, 1}, debtHigh = {0.88, 0.25, 0.23, 1},
  muted = {0.57, 0.64, 0.65, 1}, text = {0.85, 0.92, 0.90, 1},
}

function EW.Number(value, fallback, lo, hi)
  if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then return fallback end
  return math.max(lo, math.min(hi, value))
end

function EW.UpdateLayout(db)
  local L, defaults = EW.layout, EW.defaults
  L.width = math.floor(EW.Number(db.width, defaults.width, 16, 60) + 0.5)
  L.height = math.floor(EW.Number(db.height, defaults.height, 24, 140) + 0.5)
  L.gap = math.floor(EW.Number(db.gap, defaults.gap, 2, 12) + 0.5)
  L.pitch = L.width + L.gap
  L.total = L.pitch * EW.cap - L.gap
  L.debtWidth, L.debtGap = L.width, L.gap
  L.timerHeight = math.max(14, math.min(30, math.floor(L.height / 3 + 0.5)))
  L.timerFont = math.max(8, math.min(16, math.floor(L.width * 0.46 + 0.5)))
  L.alertFont = math.max(10, math.min(20, math.floor(L.width * 0.58 + 0.5)))
  L.alertHeight = math.max(16, math.min(34, math.floor(L.height * 0.42 + 0.5)))
  L.countWidth = math.max(40, math.min(84, L.width + 16))
  L.countHeight = L.timerHeight
  return L
end

local function MigrateSpecEnabled(raw)
  local result = {}
  if type(raw) == "table" then
    for id, value in pairs(raw) do
      if type(value) == "boolean" then result[tostring(id)] = value end
    end
  end
  -- Fill only absent values. Existing true/false choices are always retained.
  for _, spec in ipairs(EW.knownSpecs) do
    local key = tostring(spec.id)
    if result[key] == nil then result[key] = EW.specDefaults[spec.id] end
  end
  return result
end

function EW.GetCharacterKey()
  local ok,name=pcall(UnitName,"player")
  local realmOK,realm=pcall(GetRealmName)
  if not ok or EW.IsSecret(name) or type(name)~="string" or name=="" then name="Default" end
  if not realmOK or EW.IsSecret(realm) or type(realm)~="string" or realm=="" then realm="UnknownRealm" end
  return name.."-"..realm
end

function EW.GetProfile(db)
  db=db or EW.db
  if type(db)~="table" or type(db.characters)~="table" then return nil end
  return db.characters[EW.characterKey]
end

function EW.GetMasterEnabled(db)
  local profile=EW.GetProfile(db)
  return profile ~= nil and profile.masterEnabled == true
end

function EW.LoadSettings(saved)
  local db = type(saved) == "table" and saved or {}
  for key, default in pairs(EW.defaults) do
    if type(default) == "boolean" and type(db[key]) ~= "boolean" then db[key] = default end
  end
  db.scale = EW.Number(db.scale, 1, 0.2, 3)
  db.alpha = EW.Number(db.alpha, 1, 0.2, 1)
  db.idleAlpha = EW.Number(db.idleAlpha, 0, 0, 1)
  db.alertScale = EW.Number(db.alertScale, 1, 0.5, 3)
  db.alertAt = math.floor(EW.Number(db.alertAt, 2, 1, 4))
  db.debtMax = math.floor(EW.Number(db.debtMax, 3, 1, 5))
  db.duration = EW.Number(db.duration, 18, 1, 120)
  db.width = math.floor(EW.Number(db.width, 24, 16, 60) + 0.5)
  db.height = math.floor(EW.Number(db.height, 48, 24, 140) + 0.5)
  db.gap = math.floor(EW.Number(db.gap, 4, 2, 12) + 0.5)
  EW.characterKey=EW.GetCharacterKey()
  if type(db.characters)~="table" then db.characters={} end
  local profile=db.characters[EW.characterKey]
  if type(profile)~="table" then
    profile={}
    db.characters[EW.characterKey]=profile
    if type(db.masterEnabled)=="boolean" then profile.masterEnabled=db.masterEnabled end
    if type(db.specEnabled)=="table" then profile.specEnabled=db.specEnabled end
  end
  if type(profile.masterEnabled)~="boolean" then profile.masterEnabled=true end
  profile.specEnabled=MigrateSpecEnabled(profile.specEnabled)
  db.masterEnabled=nil
  db.specEnabled=nil
  local points = {CENTER=true, TOP=true, BOTTOM=true, LEFT=true, RIGHT=true,
    TOPLEFT=true, TOPRIGHT=true, BOTTOMLEFT=true, BOTTOMRIGHT=true}
  local p = db.point
  if type(p) ~= "table" or type(p[1]) ~= "string" or not points[p[1]]
    or type(p[2]) ~= "string" or not points[p[2]]
    or EW.Number(p[3], nil, -100000, 100000) ~= p[3]
    or EW.Number(p[4], nil, -100000, 100000) ~= p[4]
    or type(p[3]) ~= "number" or type(p[4]) ~= "number" then db.point = nil end
  db.version = EW.version
  EW.UpdateLayout(db)
  return db
end

function EW.GetCurrentSpecID()
  local api = C_SpecializationInfo
  if type(api) ~= "table" then return nil end
  local getSpec, getInfo = api.GetSpecialization, api.GetSpecializationInfo
  if type(getSpec) ~= "function" or type(getInfo) ~= "function" then return nil end
  local ok, index = pcall(getSpec)
  if not ok or EW.IsSecret(index) or type(index) ~= "number"
    or index ~= index or index < 1 or index ~= math.floor(index) then return nil end
  local infoOK, id = pcall(getInfo, index)
  if not infoOK or EW.IsSecret(id) or type(id) ~= "number"
    or id ~= id or id < 1 or id ~= math.floor(id) then return nil end
  return id
end

function EW.IsKnownSpec(id)
  if type(id) ~= "number" then return false end
  return EW.specDefaults[id] ~= nil
end

function EW.IsWarriorSpec(id)
  return EW.IsKnownSpec(id)
end

function EW.SpecKey(id)
  return tostring(id)
end

function EW.IsSpecEnabled(db, id)
  local profile=EW.GetProfile(db)
  if not EW.IsKnownSpec(id) or not profile or type(profile.specEnabled) ~= "table" then return false end
  return profile.specEnabled[EW.SpecKey(id)] == true
end

function EW.SpecLabel(id)
  for _, spec in ipairs(EW.knownSpecs) do
    if spec.id == id then return spec.label .. "（" .. spec.name .. "）" end
  end
  return "未知专精"
end

function EW.Say(text) print("|cff55c9af处刑者监控|r " .. text) end
function EW.Texture(parent, layer, color)
  local texture = parent:CreateTexture(nil, layer)
  texture:SetColorTexture(unpack(color))
  return texture
end
function EW.Font(parent, size)
  local text = parent:CreateFontString(nil, "OVERLAY")
  text:SetFont(EW.font, size, "OUTLINE")
  text:SetTextColor(unpack(EW.colors.text))
  return text
end
function EW.Gradient(texture, low, high, enabled)
  -- SetGradient only colors an existing texture. Always initialize white.
  texture:SetColorTexture(1, 1, 1, 1)
  if enabled and texture.SetGradient and CreateColor then
    texture:SetGradient("VERTICAL", CreateColor(unpack(low)), CreateColor(unpack(high)))
  else
    texture:SetColorTexture(unpack(high))
  end
end
