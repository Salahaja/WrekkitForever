--[[ The threat list: everyone in your group on one mob, from the game's
     UnitDetailedThreatSituation.

     Readable numbers: sorted by threat, each bar is how close that player
     is to pulling (100% pulls), the tank's row shows its hold (100 minus the
     closest player's pull %), and a threat-per-second figure.
     Hidden (secret) numbers: the game still lets them onto the bars and
     the text, but they can't be sorted or used in sums, so the list keeps
     group order with you first, the bars still fill, and the tank's bar
     is coloured by the game itself. ]]

local W = WrekkitForever
local UI = W.UI
local T = {}
W.threat = T

local TPS_SPAN = 6        -- seconds of history behind threat per second
local TANK_R, TANK_G, TANK_B = 0.33, 0.55, 0.95

local units, entries, history = {}, {}, {}
local pool = {}           -- reused entry tables

function T:Init()
  local f = UI.Window("WrekkitForeverThreat", "Threat", W.db.threat)
  f.defaultX, f.defaultY = 260, -60
  self.frame = f
  self:Apply()
end

function T:Apply()
  local f, cfg = self.frame, W.db.threat
  f:Place()
  for i = #f.rows + 1, cfg.rows do f.rows[i] = UI.Row(f, i) end
  for i = cfg.rows + 1, #f.rows do f.rows[i]:Hide() end
  self:Update()
end

----------------------------------------------------------------------
-- Reading
----------------------------------------------------------------------

local function entry(n)
  local e = pool[n]
  if not e then e = {}; pool[n] = e end
  return e
end

-- Threat per second from the last few seconds of a player's raw threat.
local function perSecond(key, threat, now)
  local h = history[key]
  if not h then h = {}; history[key] = h end
  h[#h + 1] = { now, threat }
  while #h > 1 and now - h[1][1] > TPS_SPAN do table.remove(h, 1) end
  local first = h[1]
  local span = now - first[1]
  if span < 1 then return nil end
  return math.max(0, (threat - first[2]) / span)
end

-- Fills `entries` for the mob; returns how many, and whether the game
-- hid the numbers.
local function read(mob)
  local n, hidden = 0, false
  local count = W.GroupUnits(units)
  local now = GetTime()
  for i = 1, count do
    local u = units[i]
    local ok, tanking, status, scaled, raw, threat = pcall(UnitDetailedThreatSituation, u, mob)
    -- Nothing back (not on the mob's list) arrives as a plain nil.
    if ok and not (W.Readable(tanking) and tanking == nil) then
      n = n + 1
      local e = entry(n)
      e.unit, e.tanking, e.status, e.scaled, e.threat = u, tanking, status, scaled, threat
      e.isMe = u == "player" or W.Read(UnitIsUnit(u, "player")) == true
      e.tps = nil
      if W.Readable(scaled) and W.Readable(threat) and W.Readable(tanking) then
        local key = W.Read(UnitGUID(u)) or u
        -- The game's threat is in hundredths.
        e.tps = threat and perSecond(key, threat / 100, now)
      else
        hidden = true
      end
    end
  end
  for i = n + 1, #entries do entries[i] = nil end
  for i = 1, n do entries[i] = pool[i] end
  return n, hidden
end

local function byThreat(a, b)
  if a.tanking ~= b.tanking then return a.tanking end
  return (a.threat or 0) > (b.threat or 0)
end

-- Readable: highest first; hidden: you first, then group order.
local function order(n, hidden)
  if hidden then
    for i = 1, n do
      if entries[i].isMe and i > 1 then
        table.insert(entries, 1, table.remove(entries, i))
        break
      end
    end
  else
    table.sort(entries, byThreat)
  end
end

-- Your row onto the last shown line if it would fall off the end.
local function pinMe(n, rows)
  if n <= rows or not W.db.threat.pinMe then return end
  for i = rows + 1, n do
    if entries[i].isMe then
      entries[rows], entries[i] = entries[i], entries[rows]
      return
    end
  end
end

-- The tank's hold: 100 minus the closest other player's pull %.
local function hold(n)
  local top = 0
  for i = 1, n do
    local e = entries[i]
    if not e.tanking and e.scaled and e.scaled > top then top = e.scaled end
  end
  return math.max(0, 100 - top)
end

----------------------------------------------------------------------
-- Drawing
----------------------------------------------------------------------

local function paintReadable(r, e, holdPct)
  local cr, cg, cb = UI.ClassColor(e.unit)
  if e.tanking then
    r:SetValue(100)
    r:SetStatusBarColor(TANK_R, TANK_G, TANK_B, 0.85)
    r.value:SetFormattedText("hold %.0f%%", holdPct)
  else
    r:SetValue(math.min(100, e.scaled or 0))
    r:SetStatusBarColor(cr, cg, cb, 0.85)
    if e.tps and e.tps >= 1 then
      r.value:SetFormattedText("%s/s  %.0f%%", UI.Short(e.tps), e.scaled or 0)
    else
      r.value:SetFormattedText("%.0f%%", e.scaled or 0)
    end
  end
  local sr, sg, sb = UI.StatusColor(e.status)
  if sr and not e.tanking then
    r.mark:SetColorTexture(sr, sg, sb, 1)
    r.mark:Show()
  else
    r.mark:Hide()
  end
end

-- Secret numbers go straight onto the bar and the text; the tank's colour
-- comes from the game's own reading of the hidden "is tanking".
local function paintHidden(r, e)
  local cr, cg, cb = UI.ClassColor(e.unit)
  -- No "or 0" here: even testing a secret for nil is not allowed.
  local scaled = e.scaled
  if W.Readable(scaled) and scaled == nil then scaled = 0 end
  r:SetValue(scaled)
  r.value:SetFormattedText("%.0f%%", scaled)
  local color
  local known = not W.Readable(e.tanking) or e.tanking ~= nil
  if C_CurveUtil and C_CurveUtil.EvaluateColorFromBoolean and known then
    local ok, c = pcall(C_CurveUtil.EvaluateColorFromBoolean, e.tanking,
      CreateColor(TANK_R, TANK_G, TANK_B, 0.85), CreateColor(cr, cg, cb, 0.85))
    if ok then color = c end
  end
  if color then
    r:SetStatusBarColor(color:GetRGBA())
  else
    r:SetStatusBarColor(cr, cg, cb, 0.85)
  end
  r.mark:Hide()
end

local SAMPLE = {
  { "Tankyboi", "WARRIOR", 100, true }, { "Salahaja", "PALADIN", 82 },
  { "Zylla", "PRIEST", 64 }, { "Doegertz", "MAGE", 47 }, { "Nuse", "WARLOCK", 31 },
}

local function sample(f, rows)
  local n = math.min(#SAMPLE, rows)
  for i = 1, n do
    local s, r = SAMPLE[i], f.rows[i]
    local c = RAID_CLASS_COLORS[s[2]]
    r.name:SetText(s[1])
    r:SetValue(s[3])
    if s[4] then
      r:SetStatusBarColor(TANK_R, TANK_G, TANK_B, 0.85)
      r.value:SetText("hold 18%")
    else
      r:SetStatusBarColor(c.r, c.g, c.b, 0.85)
      r.value:SetFormattedText("%s/s  %d%%", UI.Short(900 + s[3] * 20), s[3])
    end
    r.mark:Hide()
    r:Show()
  end
  for i = n + 1, #f.rows do f.rows[i]:Hide() end
  f.title:SetText("Threat: Sample Mob")
  f:Fit(n)
  f:Show()
end

function T:Update()
  local f, cfg = self.frame, W.db.threat
  if not f then return end
  if not cfg.shown then f:Hide() return end
  if W.test then sample(f, cfg.rows) return end

  local mob = W.WatchedMob()
  local n, hidden = 0, false
  if mob then
    local ok, got = W.Try(function() return { read(mob) } end)
    if ok then n, hidden = got[1], got[2] end
  end
  -- Nothing to show: hidden when locked, an empty frame to drag when not.
  if n == 0 then
    for i = 1, #f.rows do f.rows[i]:Hide() end
    if W.db.locked then f:Hide() return end
    f.title:SetText(mob and "Threat" or "Threat: no target")
    f:Fit(0)
    f:Show()
    return
  end

  if not W.Try(order, n, hidden) then hidden = true end
  local rows = math.min(n, cfg.rows)
  if not hidden then pinMe(n, cfg.rows) end
  local holdPct = 0
  if not hidden then
    local ok, h = W.Try(hold, n)
    holdPct = ok and h or 0
  end

  for i = 1, rows do
    local r, e = f.rows[i], entries[i]
    r.name:SetText(UnitName(e.unit))
    local painted = not hidden and W.Try(paintReadable, r, e, holdPct)
    if not painted then W.Try(paintHidden, r, e) end
    r:Show()
  end
  for i = rows + 1, #f.rows do f.rows[i]:Hide() end

  f.title:SetFormattedText(hidden and "Threat: %s  (hidden by game)" or "Threat: %s", UnitName(mob))
  f:Fit(rows)
  f:Show()
end

-- Forget threat history when the mob changes.
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_TARGET_CHANGED")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:SetScript("OnEvent", function()
  for k in pairs(history) do history[k] = nil end
end)

W.Register(T)
