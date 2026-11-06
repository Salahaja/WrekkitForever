--[[ The meter: Blizzard's own damage meter numbers (C_DamageMeter), in a
     Wrekkit window. There is no combat log for addons on Forever; this is
     the game's tally, per pull, which addons are given to show.

     In combat the numbers are hidden (secret): they still go on the bars
     and the text, in the order the game hands them over (already sorted),
     but percentages and the per-spell breakdown wait until the pull ends.

     Right-click the title: what to show (damage, healing, interrupts,
     deaths, ...) and which pull. Click a player for their spells; on
     Deaths, click a death for Blizzard's death recap. ]]

local W = WrekkitForever
local UI = W.UI
local M = {}
W.meter = M

-- In Enum.DamageMeterType order, so the index is the fallback value.
local METRICS = {
  { key = "DamageDone", label = "Damage" },
  { key = "Dps", label = "DPS", rate = true },
  { key = "HealingDone", label = "Healing" },
  { key = "Hps", label = "HPS", rate = true },
  { key = "Absorbs", label = "Absorbs" },
  { key = "Interrupts", label = "Interrupts", count = true },
  { key = "Dispels", label = "Dispels", count = true },
  { key = "DamageTaken", label = "Damage taken", taken = true },
  { key = "AvoidableDamageTaken", label = "Avoidable damage", taken = true },
  { key = "Deaths", label = "Deaths", deaths = true },
  { key = "EnemyDamageTaken", label = "Enemy damage taken" },
}
M.METRICS = METRICS

local DETAIL_ROWS = 15

local function metric()
  local key = W.db.meter.metric
  for i, m in ipairs(METRICS) do
    if m.key == key then return m, i end
  end
  return METRICS[1], 1
end

local function typeOf(m, index)
  local E = Enum and Enum.DamageMeterType
  return E and E[m.key] or index - 1
end

local function sessionTypes()
  local S = Enum and Enum.DamageMeterSessionType
  return S and S.Current or 1, S and S.Overall or 0
end

-- Large numbers the way Blizzard's meter writes them; it accepts hidden ones.
local function abbr(n)
  if AbbreviateLargeNumbers then return AbbreviateLargeNumbers(n) end
  return UI.Short(n)
end

function M.Available()
  if not C_DamageMeter then return false, "this client has no damage meter" end
  local ok, yes, why = pcall(C_DamageMeter.IsDamageMeterAvailable)
  if not ok then return false, "the game would not say" end
  return yes, why
end

----------------------------------------------------------------------
-- Reading
----------------------------------------------------------------------

-- The chosen pull's session for a meter type; falls back to the current
-- pull when a chosen older one has expired.
local function session(mtype)
  local current, overall = sessionTypes()
  local pick = W.db.meter.session
  local s
  if pick == "overall" then
    s = C_DamageMeter.GetCombatSessionFromType(overall, mtype)
  elseif type(pick) == "number" then
    s = C_DamageMeter.GetCombatSessionFromID(pick, mtype)
    if not s then
      W.db.meter.session = "current"
    end
  end
  return s or C_DamageMeter.GetCombatSessionFromType(current, mtype)
end

-- One player's spells in the chosen pull.
local function sourceSession(mtype, guid, creature)
  local current, overall = sessionTypes()
  local pick = W.db.meter.session
  if pick == "overall" then
    return C_DamageMeter.GetCombatSessionSourceFromType(overall, mtype, guid, creature)
  elseif type(pick) == "number" then
    return C_DamageMeter.GetCombatSessionSourceFromID(pick, mtype, guid, creature)
  end
  return C_DamageMeter.GetCombatSessionSourceFromType(current, mtype, guid, creature)
end

----------------------------------------------------------------------
-- Windows
----------------------------------------------------------------------

local function clickable(r)
  r:EnableMouse(true)
  r:SetScript("OnMouseUp", function(self, button)
    if self.onClick then self.onClick(self, button) end
  end)
  return r
end

function M:Init()
  local f = UI.Window("WrekkitForeverMeter", "Meter", W.db.meter)
  f.defaultX, f.defaultY = -260, -60
  f.titleBar:SetScript("OnMouseUp", function(_, button)
    if button == "RightButton" then M:Menu(f.titleBar) end
  end)
  self.frame = f

  -- Its own settings table: it sits beside the meter, never saved apart.
  local d = UI.Window("WrekkitForeverMeterDetail", "", {})
  d.titleBar:SetScript("OnMouseUp", function(_, button)
    if button == "RightButton" then M:CloseDetail() end
  end)
  d.Place = function(self)
    self:SetScale(W.db.meter.scale / 100)
    self:SetWidth(W.db.meter.width + 40)
    self:ClearAllPoints()
    self:SetPoint("TOPLEFT", f, "TOPRIGHT", 4, 0)
  end
  for i = 1, DETAIL_ROWS do d.rows[i] = UI.Row(d, i) end
  d:Hide()
  self.detail = d
  self:Apply()
end

function M:Apply()
  local f, cfg = self.frame, W.db.meter
  f:Place()
  self.detail:Place()
  for i = #f.rows + 1, cfg.rows do f.rows[i] = clickable(UI.Row(f, i)) end
  for i = cfg.rows + 1, #f.rows do f.rows[i]:Hide() end
  self:Refresh()
end

----------------------------------------------------------------------
-- The list
----------------------------------------------------------------------

local function clock(sec)
  return string.format("%d:%02d", math.floor(sec / 60), math.floor(sec % 60))
end

-- A source's figure: readable numbers get a share of the total.
local function paintValue(r, m, src, total)
  local amount, rate = src.totalAmount, src.amountPerSecond
  if m.deaths then
    local t = src.deathTimeSeconds
    if W.Readable(t) then r.value:SetText(t and clock(t) or "") else r.value:SetFormattedText("%.0fs", t) end
    return
  end
  local readable = W.Readable(amount) and W.Readable(rate) and W.Readable(total)
  if m.count then
    r.value:SetText(abbr(amount))
  elseif readable then
    local share = total and total > 0 and amount / total * 100 or 0
    if m.rate then
      r.value:SetFormattedText("%s (%s)  %.0f%%", abbr(rate), abbr(amount), share)
    else
      r.value:SetFormattedText("%s (%s)  %.0f%%", abbr(amount), abbr(rate), share)
    end
  elseif m.rate then
    r.value:SetFormattedText("%s (%s)", abbr(rate), abbr(amount))
  else
    r.value:SetFormattedText("%s (%s)", abbr(amount), abbr(rate))
  end
end

local function paintRow(r, m, src, sess)
  local c = RAID_CLASS_COLORS[src.classFilename]
  if c then r:SetStatusBarColor(c.r, c.g, c.b, 0.85) else r:SetStatusBarColor(0.5, 0.5, 0.5, 0.85) end
  r.name:SetText(src.name)
  r:SetMinMaxValues(0, sess.maxAmount)
  r:SetValue(src.totalAmount)
  paintValue(r, m, src, sess.totalAmount)
  r.src = src
  r.onClick = function(self) M:Clicked(self.src) end
  r.mark:Hide()
end

-- Which sources go on which rows: in the game's order, with your own row
-- moved onto the last line if it would fall off the end.
local order = {}
local function pick(sources, rows)
  for k in pairs(order) do order[k] = nil end
  local n = math.min(#sources, rows)
  for i = 1, n do order[i] = sources[i] end
  if W.db.meter.pinMe and #sources > rows then
    for i = rows + 1, #sources do
      if sources[i].isLocalPlayer then
        order[rows] = sources[i]
        break
      end
    end
  end
  return n
end

local function sessionLabel()
  local pick = W.db.meter.session
  if pick == "overall" then return "Overall" end
  if type(pick) == "number" then
    local ok, list = pcall(C_DamageMeter.GetAvailableCombatSessions)
    if ok and list then
      for _, s in ipairs(list) do
        if s.sessionID == pick then return W.Read(s.name) or "Pull" end
      end
    end
  end
  return "Current"
end

function M:Refresh()
  local f, cfg = self.frame, W.db.meter
  if not f then return end
  if not cfg.shown then f:Hide() self.detail:Hide() return end

  local m, index = metric()
  local yes, why = M.Available()
  local n, sess = 0, nil
  if yes then
    local ok, s = W.Try(session, typeOf(m, index))
    if ok and s then
      sess = s
      local okRows, count = W.Try(pick, s.combatSources or {}, cfg.rows)
      n = okRows and count or 0
    end
  end

  for i = 1, n do
    local r = f.rows[i]
    if W.Try(paintRow, r, m, order[i], sess) then r:Show() else r:Hide() end
  end
  for i = n + 1, #f.rows do f.rows[i]:Hide() end

  if not yes then
    f.title:SetText("Meter: " .. (W.Read(why) or "not available"))
  elseif n == 0 then
    f.title:SetFormattedText("%s: %s  (no data yet)", m.label, sessionLabel())
  else
    f.title:SetFormattedText("%s: %s", m.label, sessionLabel())
  end
  f:Fit(n)
  f:Show()
  if self.detail:IsShown() then self:PaintDetail() end
end

----------------------------------------------------------------------
-- A player's spells, and deaths
----------------------------------------------------------------------

function M:Clicked(src)
  local m = metric()
  if m.deaths then
    local id = src.deathRecapID
    if id and id > 0 and OpenDeathRecapUI then
      OpenDeathRecapUI(id)
    else
      W.Print("no death recap for that one")
    end
    return
  end
  if not W.Readable(src.sourceGUID) then
    W.Print("a player's spells open once the pull is over: the game hides who's who until then")
    return
  end
  local shown = self.detail:IsShown() and self.detailFor
  if shown and shown.guid == src.sourceGUID and shown.creature == src.sourceCreatureID then
    self:CloseDetail()
    return
  end
  self.detailFor = { guid = src.sourceGUID, creature = src.sourceCreatureID, name = src.name }
  self.detail:Show()
  self:PaintDetail()
end

function M:CloseDetail()
  self.detailFor = nil
  self.detail:Hide()
end

local function spellName(id)
  local ok, name = pcall(function()
    if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
    return (GetSpellInfo(id))
  end)
  if ok and name then return name end
  return "Spell " .. tostring(W.Read(id) or "?")
end

local function paintSpell(r, m, spell, total)
  local label = spellName(spell.spellID)
  local by = W.Read(spell.creatureName)
  if m.taken and by and by ~= "" then label = label .. " (" .. by .. ")" end
  r.name:SetText(label)
  -- Avoidable hits orange, deadly ones with a red marker (when readable).
  if W.Read(spell.isAvoidable) then r.name:SetTextColor(1, 0.6, 0.2) else r.name:SetTextColor(1, 1, 1) end
  if W.Read(spell.isDeadly) then
    r.mark:SetColorTexture(1, 0.15, 0.15, 1)
    r.mark:Show()
  else
    r.mark:Hide()
  end
  r:SetStatusBarColor(0.35, 0.45, 0.6, 0.85)
  r:SetMinMaxValues(0, total)
  r:SetValue(spell.totalAmount)
  local amount = spell.totalAmount
  if W.Readable(amount) and W.Readable(total) then
    local share = total > 0 and amount / total * 100 or 0
    r.value:SetFormattedText("%s  %.0f%%", abbr(amount), share)
  else
    r.value:SetText(abbr(amount))
  end
end

local function bySize(a, b) return (a.totalAmount or 0) > (b.totalAmount or 0) end

function M:PaintDetail()
  local d, who = self.detail, self.detailFor
  if not who then d:Hide() return end
  local m, index = metric()
  local ok, s = W.Try(sourceSession, typeOf(m, index), who.guid, who.creature)
  local spells = ok and s and s.combatSpells or {}
  local total = ok and s and s.totalAmount or 0
  -- Readable after the pull: biggest first.
  W.Try(table.sort, spells, bySize)
  local n = math.min(#spells, DETAIL_ROWS)
  for i = 1, n do
    local r = d.rows[i]
    if W.Try(paintSpell, r, m, spells[i], total) then r:Show() else r:Hide() end
  end
  for i = n + 1, DETAIL_ROWS do d.rows[i]:Hide() end
  d.title:SetFormattedText("%s: %s", who.name, m.label)
  d:Fit(n)
end

----------------------------------------------------------------------
-- The title's menu
----------------------------------------------------------------------

function M:Menu(owner)
  if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
  MenuUtil.CreateContextMenu(owner, function(_, root)
    root:CreateTitle("Show")
    for _, m in ipairs(METRICS) do
      root:CreateRadio(m.label, function() return W.db.meter.metric == m.key end, function()
        W.db.meter.metric = m.key
        M:CloseDetail()
        M:Refresh()
      end)
    end
    root:CreateDivider()
    root:CreateTitle("Pull")
    local function pull(label, value)
      root:CreateRadio(label, function() return W.db.meter.session == value end, function()
        W.db.meter.session = value
        M:CloseDetail()
        M:Refresh()
      end)
    end
    pull("Current", "current")
    pull("Overall", "overall")
    local ok, list = pcall(C_DamageMeter.GetAvailableCombatSessions)
    if ok and list then
      for i = #list, 1, -1 do
        local s = list[i]
        local label = W.Read(s.name) or "Pull"
        local dur = W.Read(s.durationSeconds)
        if dur then label = label .. "  " .. clock(dur) end
        pull(label, s.sessionID)
      end
    end
    root:CreateDivider()
    root:CreateButton("Reset all pulls", function()
      C_DamageMeter.ResetAllCombatSessions()
      W.db.meter.session = "current"
      M:CloseDetail()
      M:Refresh()
    end)
  end)
end

----------------------------------------------------------------------
-- Sample rows
----------------------------------------------------------------------

local SAMPLE = {
  { "Doegertz", "MAGE", 412000, 1890 }, { "Salahaja", "PALADIN", 355000, 1630 },
  { "Wiredbro", "WARRIOR", 301000, 1380 }, { "Nuse", "WARLOCK", 288000, 1320 },
  { "Bivrip", "HUNTER", 190000, 870 },
}

function M:Sample()
  local f, cfg = self.frame, W.db.meter
  if not (f and cfg.shown) then return end
  local n = math.min(#SAMPLE, cfg.rows)
  for i = 1, n do
    local s, r = SAMPLE[i], f.rows[i]
    local c = RAID_CLASS_COLORS[s[2]]
    r:SetStatusBarColor(c.r, c.g, c.b, 0.85)
    r.name:SetText(s[1])
    r:SetMinMaxValues(0, SAMPLE[1][3])
    r:SetValue(s[3])
    r.value:SetFormattedText("%s (%s)  %.0f%%", UI.Short(s[3]), UI.Short(s[4]), s[3] / 1546000 * 100)
    r.onClick = nil
    r.mark:Hide()
    r:Show()
  end
  for i = n + 1, #f.rows do f.rows[i]:Hide() end
  f.title:SetText("Damage: Sample")
  f:Fit(n)
  f:Show()
end

local updateSoon = false
local ev = CreateFrame("Frame")
for _, e in ipairs({ "DAMAGE_METER_COMBAT_SESSION_UPDATED", "DAMAGE_METER_CURRENT_SESSION_UPDATED",
                     "DAMAGE_METER_RESET", "PLAYER_REGEN_ENABLED" }) do
  pcall(ev.RegisterEvent, ev, e)
end
ev:SetScript("OnEvent", function() updateSoon = true end)

-- The core's tick (5 a second): test rows, else a refresh when the game
-- says the numbers changed, and at least every 0.6s.
local since = 0
function M:Update()
  if W.test then self:Sample() return end
  since = since + 1
  if updateSoon or since >= 3 then
    updateSoon, since = false, 0
    self:Refresh()
  end
end

W.Register(M)
