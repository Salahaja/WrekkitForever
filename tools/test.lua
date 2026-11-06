--[[ Runs Wrekkit Forever against stubbed game API, in two modes:
       readable  the game hands back plain numbers
       hidden    threat numbers, "is tanking" and aura times are secrets:
                 any comparison or sum on them raises, as in the client
   lua tools/test.lua   (from the repo root) ]]

local failures, checks = 0, 0
local function check(label, got, want)
  checks = checks + 1
  if got ~= want then
    failures = failures + 1
    print("FAIL " .. label .. ": got " .. tostring(got) .. ", want " .. tostring(want))
  end
end

----------------------------------------------------------------------
-- Secrets: opaque, raise on anything but being passed along
----------------------------------------------------------------------

local SecretMT = {}
local function boom() error("attempt to use a secret value", 2) end
for _, m in ipairs({ "__lt", "__le", "__add", "__sub", "__mul", "__div", "__concat", "__unm", "__index", "__len" }) do
  SecretMT[m] = boom
end
SecretMT.__eq = boom
local function secret(v) return setmetatable({ v = v }, SecretMT) end
local function isSecret(v) return type(v) == "table" and getmetatable(v) == SecretMT end
local function reveal(v) if isSecret(v) then return rawget(v, "v") end return v end

canaccessvalue = function(v) return not isSecret(v) end
issecretvalue = isSecret

----------------------------------------------------------------------
-- Frames: every method exists; a few remember what they were given
----------------------------------------------------------------------

local Widget = {}
-- Fields a test reads back (text, value, scripts...) are nil until set;
-- any method name not stubbed below does nothing.
local FIELDS = { text = 1, barValue = 1, shown = 1, color = 1, textColor = 1, texture = 1,
  scripts = 1, cooldown = 1, raidIndex = 1, cd = 1, icons = 1, raid = 1, name = 1,
  title = 1, rows = 1, mark = 1, count = 1, tex = 1, kind = 1 }
Widget.__index = function(t, k)
  local own = rawget(Widget, k)
  if own then return own end
  if FIELDS[k] then return nil end
  return function() end
end
function Widget.SetText(self, s) self.text = reveal(s) end
function Widget.SetFormattedText(self, fmt, ...)
  local args = { ... }
  for i = 1, select("#", ...) do args[i] = reveal(args[i]) end
  self.text = string.format(fmt, table.unpack(args, 1, select("#", ...)))
end
function Widget.GetText(self) return self.text end
function Widget.SetValue(self, v) self.barValue = reveal(v) end
function Widget.Show(self) self.shown = true end
function Widget.Hide(self) self.shown = false end
function Widget.IsShown(self) return self.shown end
function Widget.SetStatusBarColor(self, r, g, b) self.color = { r, g, b } end
function Widget.SetTextColor(self, r, g, b) self.textColor = { r, g, b } end
function Widget.SetTexture(self, t) self.texture = reveal(t) end
function Widget.SetScript(self, name, f) self.scripts = self.scripts or {}; self.scripts[name] = f end
function Widget.GetPoint() return "CENTER", nil, "CENTER", 0, 0 end
function Widget.CreateFontString(self) return setmetatable({}, Widget) end
function Widget.CreateTexture(self) return setmetatable({}, Widget) end
function Widget.SetCooldown(self, start, dur)
  if isSecret(start) or isSecret(dur) then boom() end
  self.cooldown = { start, dur }
end
function Widget.SetCooldownFromDurationObject(self, d) self.cooldown = { "object", d } end
function Widget.Clear(self) self.cooldown = nil end

local frames = {}
function CreateFrame(kind, name)
  local f = setmetatable({ kind = kind }, Widget)
  if name then _G[name] = f end
  frames[#frames + 1] = f
  return f
end
UIParent = CreateFrame("Frame")
DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) end }
STANDARD_TEXT_FONT = "font"
RAID_CLASS_COLORS = setmetatable({}, { __index = function() return { r = 0.5, g = 0.5, b = 0.5 } end })
function CreateColor(r, g, b, a)
  return { r = r, g = g, b = b, a = a, GetRGBA = function(c) return c.r, c.g, c.b, c.a end,
           GetRGB = function(c) return c.r, c.g, c.b end }
end
function GetThreatStatusColor(s) return 1, 0.5 * s, 0 end
function SetRaidTargetIconTexture(tex, i) tex.raidIndex = i end
SlashCmdList = {}
function strsplit(sep, s)
  local out = {}
  for w in string.gmatch(s, "[^" .. sep .. "]+") do out[#out + 1] = w end
  return table.unpack(out)
end
strlower, strtrim = string.lower, function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
local now = 100
function GetTime() return now end

----------------------------------------------------------------------
-- The world: a party of three on two mobs
----------------------------------------------------------------------

local hide = false
local function maybe(v) if hide and v ~= nil then return secret(v) end return v end

local PARTY = { player = "Salahaja", party1 = "Tankyboi", party2 = "Zylla" }
local THREAT = {}         -- [mob][unit] = { tanking, status, scaled, raw, threat }
local NAMES = { target = "Molten Giant", nameplate1 = "Molten Giant", nameplate2 = "Lava Surger" }
local SAME = { nameplate1 = "target", target = "nameplate1" }

function IsInRaid() return false end
function GetNumSubgroupMembers() return 2 end
function GetNumGroupMembers() return 3 end
function UnitExists(u) return PARTY[u] ~= nil or NAMES[u] ~= nil end
function UnitName(u) return PARTY[u] or NAMES[u] end
function UnitClass(u) return "x", "WARRIOR" end
function UnitGUID(u) return "guid-" .. u end
function UnitIsUnit(a, b) return a == b or SAME[a] == b end
function UnitCanAttack(_, u) return NAMES[u] ~= nil end
function UnitAffectingCombat(u) return true end
function UnitHealth(u) return maybe(500) end
function UnitHealthMax(u) return maybe(1000) end
function GetRaidTargetIndex(u) if u == "nameplate1" or u == "target" then return maybe(8) end end
function UnitDetailedThreatSituation(u, mob)
  if mob == "target" then mob = "nameplate1" end
  local t = THREAT[mob] and THREAT[mob][u]
  if not t then return end
  return maybe(t[1]), maybe(t[2]), maybe(t[3]), maybe(t[4]), maybe(t[5])
end

C_AddOns = { GetAddOnMetadata = function() return "test" end }
C_CurveUtil = {
  EvaluateColorFromBoolean = function(b, yes, no) if reveal(b) then return yes end return no end,
}
local AURAS = { nameplate1 = { { icon = "judgement", duration = 10, expirationTime = 108, auraInstanceID = 7 } } }
C_UnitAuras = {
  GetAuraDataByIndex = function(u, i, filter)
    local a = AURAS[u] and AURAS[u][i]
    if not a then return nil end
    return { icon = a.icon, duration = maybe(a.duration), expirationTime = maybe(a.expirationTime),
             auraInstanceID = a.auraInstanceID }
  end,
  GetAuraDuration = function(u, id) return { id = id } end,
  GetAuraApplicationDisplayCount = function() return "" end,
}

-- The options panel: remembers each proxy setting by its variable name.
local proxies, registered, opened = {}, nil, nil
Settings = {
  VarType = { Boolean = "boolean", Number = "number", String = "string" },
  RegisterVerticalLayoutCategory = function(name)
    local cat = { name = name, GetID = function() return 42 end }
    return cat, { AddInitializer = function() end }
  end,
  RegisterProxySetting = function(cat, var, kind, name, default, get, set)
    local s = { get = get, set = set, default = default, kind = kind }
    proxies[var] = s
    return s
  end,
  CreateCheckbox = function() end,
  CreateSlider = function() end,
  CreateSliderOptions = function() return { SetLabelFormatter = function() end } end,
  RegisterAddOnCategory = function(cat) registered = cat end,
  OpenToCategory = function(id) opened = id end,
}
MinimalSliderWithSteppersMixin = { Label = { Right = 1 } }
function CreateSettingsListSectionHeaderInitializer() return {} end
function CreateSettingsButtonInitializer() return {} end

----------------------------------------------------------------------
-- Load
----------------------------------------------------------------------

local ADDON = "WrekkitForever"
for _, file in ipairs({ "core.lua", "widgets.lua", "threat.lua", "mobs.lua", "config.lua" }) do
  local chunk = assert(loadfile(ADDON .. "/" .. file))
  chunk(ADDON)
end
local W = WrekkitForever
local loader
for _, f in ipairs(frames) do
  if f.scripts and f.scripts.OnEvent and not loader then loader = f end
end
loader.scripts.OnEvent(loader, "ADDON_LOADED", ADDON)

-- In readable mode nothing may fail quietly: an error is a bug.
local realTry = W.Try
local quiet = 0
W.Try = function(f, ...)
  local ok, r = pcall(f, ...)
  if not ok then
    if hide then quiet = quiet + 1 else error(r, 0) end
  end
  return ok, r
end

local function plates()
  for _, f in ipairs(frames) do
    if f.scripts and f.scripts.OnEvent then
      f.scripts.OnEvent(f, "NAME_PLATE_UNIT_ADDED", "nameplate1")
      f.scripts.OnEvent(f, "NAME_PLATE_UNIT_ADDED", "nameplate2")
    end
  end
end
plates()

local T, M = W.threat, W.mobs
local tf, mf = T.frame, M.frame

----------------------------------------------------------------------
-- Readable
----------------------------------------------------------------------

THREAT.nameplate1 = {
  party1 = { true, 3, 100, 100, 50000 },
  player = { false, 1, 82, 90, 45000 },
  party2 = { false, 0, 40, 44, 22000 },
}
THREAT.nameplate2 = {
  player = { true, 3, 100, 100, 9000 },
  party2 = { false, 0, 30, 30, 2700 },
}
T:Update()
check("readable: three rows", tf.rows[3].shown, true)
check("  the tank first", tf.rows[1].name.text, "Tankyboi")
check("  then you", tf.rows[2].name.text, "Salahaja")
check("  the tank's hold", tf.rows[1].value.text, "hold 18%")
check("  your pull %", tf.rows[2].value.text, "82%")
check("  your bar", tf.rows[2].barValue, 82)
check("  the title", tf.title.text, "Threat: Molten Giant")
-- Two seconds on, your threat up by 2000 (hundredths): 10 a second.
now = now + 2
THREAT.nameplate1.player[5] = 47000
T:Update()
check("  threat per second", tf.rows[2].value.text, "10/s  82%")

-- Pinned: one row only, you are not the top.
W.db.threat.rows = 1
T:Apply()
check("pinned: your row stays", tf.rows[1].name.text, "Salahaja")
W.db.threat.pinMe = false
T:Update()
check("unpinned: the tank", tf.rows[1].name.text, "Tankyboi")
W.db.threat.rows, W.db.threat.pinMe = 10, true
T:Apply()

M:Update()
check("mobs: both listed", mf.rows[2].shown, true)
check("  your target first", mf.rows[1].name.text, "Molten Giant")
check("  not tanking it: your pull %", mf.rows[1].value.text, "82%")
check("  tanking the other: your hold", mf.rows[2].value.text, "hold 70%")
check("  your judgement on it", mf.rows[1].icons[1].shown, true)
check("  with its timer", mf.rows[1].icons[1].cd.cooldown and mf.rows[1].icons[1].cd.cooldown[1], 98)
check("  none on the other", mf.rows[2].icons[1].shown, false)
check("  the skull", mf.rows[1].raid.raidIndex, 8)
check("  health on the bar", mf.rows[1].barValue, 500)

----------------------------------------------------------------------
-- Hidden
----------------------------------------------------------------------

hide = true
quiet = 0
T:Update()
check("hidden: still three rows", tf.rows[3].shown, true)
check("  you first", tf.rows[1].name.text, "Salahaja")
check("  your pull % still shows", tf.rows[1].value.text, "82%")
check("  the bar still fills", tf.rows[1].barValue, 82)
check("  the title says so", tf.title.text, "Threat: Molten Giant  (hidden by game)")
local tankRow
for i = 1, 3 do if tf.rows[i].name.text == "Tankyboi" then tankRow = tf.rows[i] end end
check("  the tank's bar is the tank colour", tankRow and tankRow.color[1], 0.33)

M:Update()
check("hidden mobs: both listed", mf.rows[2].shown, true)
check("  your pull % as it is", mf.rows[1].value.text, "82%")
check("  aggro reddens the name", mf.rows[2].name.textColor[1], 1)
check("  and not where you have none", mf.rows[1].name.textColor[2], 1)
check("  judgement still shows", mf.rows[1].icons[1].shown, true)
check("  its timer from the game's duration", mf.rows[1].icons[1].cd.cooldown[1], "object")
check("  health on the bar", mf.rows[1].barValue, 500)
print("  (hidden mode: " .. quiet .. " quiet fallbacks)")

----------------------------------------------------------------------
-- No target, test rows, slash
----------------------------------------------------------------------

hide = false
NAMES.target = nil
SAME.nameplate1 = nil
T:Update()
check("no target: empty frame while unlocked", tf.title.text, "Threat: no target")
W.db.locked = true
T:Update()
check("  hidden when locked", tf.shown, false)
W.db.locked = false

SlashCmdList.WREKKITFOREVER("test")
T:Update(); M:Update()
check("test rows: threat", tf.rows[2].name.text, "Salahaja")
check("test rows: mobs", mf.rows[1].name.text, "Molten Giant")
SlashCmdList.WREKKITFOREVER("test")
SlashCmdList.WREKKITFOREVER("rows threat 3")
check("/wf rows", W.db.threat.rows, 3)
SlashCmdList.WREKKITFOREVER("threat")
check("/wf threat hides it", tf.shown, false)
SlashCmdList.WREKKITFOREVER("")

----------------------------------------------------------------------
-- Options page
----------------------------------------------------------------------

check("options: the page is registered", registered and registered.name, "Wrekkit Forever")
local p = proxies
check("  every control has a setting", p.WREKKITFOREVER_LOCKED and p.WREKKITFOREVER_MOBS_SCALE and true, true)
for var, s in pairs(p) do
  check("  " .. var .. " reads back", type(s.get()), s.kind)
  check("  " .. var .. " default matches", s.default == s.get() or var == "WREKKITFOREVER_THREAT_SHOWN"
    or var == "WREKKITFOREVER_THREAT_ROWS", true)
end
p.WREKKITFOREVER_THREAT_SHOWN.set(true)
check("  show the threat list", tf.shown, true)
p.WREKKITFOREVER_THREAT_WIDTH.set(300)
check("  width saved", W.db.threat.width, 300)
p.WREKKITFOREVER_MOBS_DEBUFFS.set(false)
check("  debuffs off saved", W.db.mobs.debuffs, false)
p.WREKKITFOREVER_SAMPLE.set(true)
check("  sample rows on", W.test, true)
p.WREKKITFOREVER_SAMPLE.set(false)
SlashCmdList.WREKKITFOREVER("config")
check("/wf config opens it", opened, 42)

print(string.format("%d checks, %d failed", checks, failures))
os.exit(failures == 0 and 0 or 1)
