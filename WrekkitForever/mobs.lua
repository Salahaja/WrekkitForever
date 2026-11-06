--[[ Mob frames: every enemy in combat, with its health, your threat on
     it, and your own debuffs on it.

     The figure on the right:
       you are tanking it   "hold 45%" - 100 minus the closest other
                            player's pull %; 0% means someone is about to
                            take it
       you are not          your pull %, coloured by the game's aggro state
     With hidden (secret) numbers, it is your pull % either way and the
     name turns red when the game says you have aggro.

     Mobs come from your target and focus, enemy nameplates, what your
     group is targeting, and the boss frames. A mob nobody targets shows
     only with enemy nameplates on (V). ]]

local W = WrekkitForever
local UI = W.UI
local MF = {}
W.mobs = MF

local MAX_DEBUFFS = 5
local AGGRO = CreateColor(1, 0.3, 0.3, 1)
local PLAIN = CreateColor(1, 1, 1, 1)

local list = {}
local units = {}

function MF:Init()
  local f = UI.Window("WrekkitForeverMobs", "Mobs", W.db.mobs)
  f.defaultX, f.defaultY = 260, 120
  self.frame = f
  self:Apply()
end

----------------------------------------------------------------------
-- Rows
----------------------------------------------------------------------

local function debuffIcon(r, i)
  local b = CreateFrame("Frame", nil, r)
  local size = UI.ROW_H - 1
  b:SetSize(size, size)
  b:SetPoint("RIGHT", r, "LEFT", -1 - (i - 1) * (size + 1), 0)
  b.tex = b:CreateTexture(nil, "ARTWORK")
  b.tex:SetAllPoints()
  b.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  b.cd = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
  b.cd:SetAllPoints()
  b.cd:SetDrawEdge(false)
  b.cd:SetReverse(true)
  b.count = b:CreateFontString(nil, "OVERLAY")
  b.count:SetFont(STANDARD_TEXT_FONT, 9, "OUTLINE")
  b.count:SetPoint("BOTTOMRIGHT", 1, 0)
  b:Hide()
  return b
end

local function makeRow(f, i)
  local r = UI.Row(f, i)
  r:SetStatusBarColor(0.55, 0.12, 0.12, 0.9)
  r.icons = {}
  for k = 1, MAX_DEBUFFS do r.icons[k] = debuffIcon(r, k) end
  r.raid = r:CreateTexture(nil, "OVERLAY")
  r.raid:SetSize(UI.ROW_H - 3, UI.ROW_H - 3)
  r.raid:SetPoint("LEFT", 6, 0)
  r.raid:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
  r.raid:Hide()
  return r
end

function MF:Apply()
  local f, cfg = self.frame, W.db.mobs
  f:Place()
  for i = #f.rows + 1, cfg.rows do f.rows[i] = makeRow(f, i) end
  for i = cfg.rows + 1, #f.rows do f.rows[i]:Hide() end
  self:Update()
end

----------------------------------------------------------------------
-- Reading
----------------------------------------------------------------------

-- An enemy in combat. A hidden answer counts as yes.
local function wanted(u)
  if not UnitExists(u) then return false end
  local attack = UnitCanAttack("player", u)
  if W.Readable(attack) and not attack then return false end
  local fighting = UnitAffectingCombat(u)
  if W.Readable(fighting) and not fighting then return false end
  return true
end

-- Where enemies can be found, best first: your target and focus, every
-- nameplate (the only way to see a mob nobody targets), what each group
-- member is targeting, and the boss frames.
local SOURCES = { "target", "focus" }
for i = 1, 40 do SOURCES[#SOURCES + 1] = "nameplate" .. i end
local BOSSES = {}
for i = 1, 8 do BOSSES[i] = "boss" .. i end

local seen, kept = {}, {}

-- Already listed under another token? By GUID when the game shows it,
-- else by asking whether the two tokens are the same unit.
local function duplicate(u, n)
  local guid = W.Read(UnitGUID(u))
  if guid then
    if seen[guid] then return true end
    seen[guid] = true
    return false
  end
  for i = 1, n do
    if W.Read(UnitIsUnit(u, kept[i])) == true then return true end
  end
  return false
end

local function consider(u, n)
  local ok, yes = pcall(wanted, u)
  if not (ok and yes) then return n end
  local okDup, dup = pcall(duplicate, u, n)
  if okDup and dup then return n end
  n = n + 1
  kept[n] = u
  return n
end

-- Enemies to list, your target first.
local function collect()
  for k in pairs(seen) do seen[k] = nil end
  for k in pairs(kept) do kept[k] = nil end
  local n = 0
  for _, u in ipairs(SOURCES) do n = consider(u, n) end
  local count = W.GroupUnits(units)
  for i = 1, count do
    local u = units[i]
    n = consider(u == "player" and "target" or u .. "target", n)
  end
  for _, u in ipairs(BOSSES) do n = consider(u, n) end
  for k in pairs(list) do list[k] = nil end
  for i = 1, n do list[i] = kept[i] end
  return n
end

local function nameplatesOff()
  return GetCVarBool and not GetCVarBool("nameplateShowEnemies")
end

-- 100 minus the closest other player's pull % on the mob.
local function holdOn(mob)
  local top = 0
  local count = W.GroupUnits(units)
  for i = 1, count do
    local u = units[i]
    if u ~= "player" then
      local tanking, _, scaled = UnitDetailedThreatSituation(u, mob)
      if W.Readable(scaled) and W.Readable(tanking) and scaled and not tanking and scaled > top then
        top = scaled
      end
    end
  end
  return math.max(0, 100 - top)
end

----------------------------------------------------------------------
-- Drawing
----------------------------------------------------------------------

local function paintHealth(r, u)
  r:SetMinMaxValues(0, UnitHealthMax(u))
  r:SetValue(UnitHealth(u))
end

local function paintRaidIcon(r, u)
  local idx = W.Read(GetRaidTargetIndex(u))
  if idx then
    SetRaidTargetIconTexture(r.raid, idx)
    r.raid:Show()
    r.name:SetPoint("LEFT", 6 + UI.ROW_H, 0)
  else
    r.raid:Hide()
    r.name:SetPoint("LEFT", 7, 0)
  end
end

local function paintThreat(r, u)
  local tanking, status, scaled = UnitDetailedThreatSituation("player", u)
  if W.Readable(tanking) and W.Readable(scaled) then
    r.name:SetTextColor(1, 1, 1)
    if tanking == nil then
      r.value:SetText("")
    elseif tanking then
      r.value:SetFormattedText("hold %.0f%%", holdOn(u))
      r.value:SetTextColor(0.45, 0.7, 1)
    else
      r.value:SetFormattedText("%.0f%%", scaled or 0)
      local sr, sg, sb = UI.StatusColor(status)
      if sr then r.value:SetTextColor(sr, sg, sb) else r.value:SetTextColor(1, 1, 1) end
    end
    return
  end
  -- Hidden: show the number as it is, and let the game colour the name.
  r.value:SetTextColor(1, 1, 1)
  local readableNil = W.Readable(scaled) and scaled == nil
  if readableNil then r.value:SetText("") else r.value:SetFormattedText("%.0f%%", scaled) end
  local ok, c = pcall(C_CurveUtil.EvaluateColorFromBoolean, tanking, AGGRO, PLAIN)
  if ok and c then r.name:SetTextColor(c:GetRGB()) else r.name:SetTextColor(1, 1, 1) end
end

-- One debuff icon's timer: from the numbers when readable, else from the
-- game's duration object.
local function paintTimer(b, u, aura)
  local exp, dur = aura.expirationTime, aura.duration
  if W.Readable(exp) and W.Readable(dur) then
    if dur and dur > 0 and exp then
      b.cd:SetCooldown(exp - dur, dur)
    else
      b.cd:Clear()
    end
    return
  end
  local d = C_UnitAuras.GetAuraDuration(u, aura.auraInstanceID)
  b.cd:SetCooldownFromDurationObject(d)
end

local function paintDebuffs(r, u)
  local shown = 0
  if W.db.mobs.debuffs then
    for i = 1, MAX_DEBUFFS do
      local aura = C_UnitAuras.GetAuraDataByIndex(u, i, "HARMFUL|PLAYER")
      if W.Readable(aura) and aura == nil then break end
      local b = r.icons[i]
      b.tex:SetTexture(aura.icon)
      W.Try(paintTimer, b, u, aura)
      local okCount, text = pcall(C_UnitAuras.GetAuraApplicationDisplayCount, u, aura.auraInstanceID, 2)
      b.count:SetText(okCount and text or "")
      b:Show()
      shown = i
    end
  end
  for i = shown + 1, MAX_DEBUFFS do r.icons[i]:Hide() end
end

local SAMPLE = {
  { "Molten Giant", 82, "hold 41%", { 0.45, 0.7, 1 }, 8 },
  { "Lava Surger", 55, "73%", { 1, 0.6, 0 } },
  { "Firewalker", 100, "12%", { 1, 1, 1 } },
}

local SAMPLE_ICONS = {
  "Interface\\Icons\\Spell_Holy_HolySmite",
  "Interface\\Icons\\Spell_Shadow_ShadowWordPain",
  "Interface\\Icons\\Ability_Hunter_Quickshot",
}

local function sample(f, rows)
  local n = math.min(#SAMPLE, rows)
  for i = 1, n do
    local s, r = SAMPLE[i], f.rows[i]
    r:SetMinMaxValues(0, 100)
    r:SetValue(s[2])
    r.name:SetText(s[1])
    r.name:SetTextColor(1, 1, 1)
    r.value:SetText(s[3])
    r.value:SetTextColor(s[4][1], s[4][2], s[4][3])
    if s[5] then
      SetRaidTargetIconTexture(r.raid, s[5])
      r.raid:Show()
      r.name:SetPoint("LEFT", 6 + UI.ROW_H, 0)
    else
      r.raid:Hide()
      r.name:SetPoint("LEFT", 7, 0)
    end
    for k = 1, MAX_DEBUFFS do
      local b = r.icons[k]
      if k <= 3 - i + 1 then
        b.tex:SetTexture(SAMPLE_ICONS[k])
        b.cd:Clear()
        b.count:SetText("")
        b:Show()
      else
        b:Hide()
      end
    end
    r:Show()
  end
  for i = n + 1, #f.rows do f.rows[i]:Hide() end
  f.title:SetText("Mobs")
  f:Fit(n)
  f:Show()
end

function MF:Update()
  local f, cfg = self.frame, W.db.mobs
  if not f then return end
  if not cfg.shown then f:Hide() return end
  if W.test then sample(f, cfg.rows) return end

  local ok, n = W.Try(collect)
  n = ok and n or 0
  if n == 0 then
    for i = 1, #f.rows do f.rows[i]:Hide() end
    if W.db.locked then f:Hide() return end
    f.title:SetText(nameplatesOff() and "Mobs: none (enemy nameplates off: V)" or "Mobs: none in combat")
    f:Fit(0)
    f:Show()
    return
  end

  local rows = math.min(n, cfg.rows)
  for i = 1, rows do
    local r, u = f.rows[i], list[i]
    r.name:SetText(UnitName(u))
    W.Try(paintHealth, r, u)
    W.Try(paintRaidIcon, r, u)
    if not W.Try(paintThreat, r, u) then r.value:SetText("") end
    if not W.Try(paintDebuffs, r, u) then
      for k = 1, MAX_DEBUFFS do r.icons[k]:Hide() end
    end
    r:Show()
  end
  for i = rows + 1, #f.rows do f.rows[i]:Hide() end
  f.title:SetFormattedText(nameplatesOff() and "Mobs (%d)  nameplates off: V" or "Mobs (%d)", n)
  f:Fit(rows)
  f:Show()
end

W.Register(MF)
