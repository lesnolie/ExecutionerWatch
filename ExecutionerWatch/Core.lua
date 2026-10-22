local _, EW = ...
EW.enabled = select(2, UnitClass("player")) == "WARRIOR"
if not EW.enabled then return end

EW.version, EW.spellID, EW.procID, EW.cap = "0.9.1", 445584, 445579, 5
EW.white = "Interface\\Buttons\\WHITE8X8"
EW.font = STANDARD_TEXT_FONT or "Fonts\\ARKai_T.ttf"
EW.IsSecret = issecretvalue or function() return false end
EW.layout = { width = 24, gap = 4, height = 48, timerHeight = 16, debtWidth = 24, debtGap = 4 }
EW.layout.pitch = EW.layout.width + EW.layout.gap
EW.layout.total = EW.layout.pitch * EW.cap - EW.layout.gap
EW.defaults = {
  locked = true, scale = 1, alpha = 1, idleAlpha = 0, alertScale = 1, alertAt = 2,
  sound = true, showPips = true, showText = false, showAlert = true,
  showTimers = true, showGradient = true, showDebtAnim = true, debtMax = 3,
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
  local points = {CENTER=true, TOP=true, BOTTOM=true, LEFT=true, RIGHT=true,
    TOPLEFT=true, TOPRIGHT=true, BOTTOMLEFT=true, BOTTOMRIGHT=true}
  local p = db.point
  if type(p) ~= "table" or type(p[1]) ~= "string" or not points[p[1]]
    or type(p[2]) ~= "string" or not points[p[2]]
    or EW.Number(p[3], nil, -100000, 100000) ~= p[3]
    or EW.Number(p[4], nil, -100000, 100000) ~= p[4]
    or type(p[3]) ~= "number" or type(p[4]) ~= "number" then db.point = nil end
  db.version = EW.version
  return db
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
