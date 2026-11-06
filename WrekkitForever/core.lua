--[[ Wrekkit Forever: the threat list and mob frames of Wrekkit, for the
     Midnight-based WoW Forever client.

     Everything comes from the game's own threat and aura queries; there is
     no combat log for addons here. In some states (combat, encounters, some
     maps) the game hands addons "secret" values: they can be put on screen
     (a bar's value, a font string's text, a texture) but not compared,
     sorted or used in sums. Every reading below asks whether it may be read
     first, and falls back to showing it as-is when it may not. ]]

local ADDON = ...
local W = {}
_G.WrekkitForever = W

W.version = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON, "Version") or "?"

local DEFAULTS = {
  locked = false,
  threat = { shown = true, width = 200, rows = 10, scale = 100, pinMe = true },
  mobs = { shown = true, width = 220, rows = 8, scale = 100, debuffs = true },
  meter = { shown = false, width = 240, rows = 10, scale = 100, pinMe = true,
            metric = "DamageDone", session = "current" },
}

----------------------------------------------------------------------
-- Secret values
----------------------------------------------------------------------

-- True when this code may read v: compare it, do sums with it, use it as
-- a table key. Older clients without the secret system: always.
local canaccess = canaccessvalue
local issecret = issecretvalue
function W.Readable(v)
  if canaccess then return canaccess(v) end
  if issecret then return not issecret(v) end
  return true
end

-- A readable value, or nil (a secret, or nothing).
function W.Read(v)
  if W.Readable(v) then return v end
  return nil
end

-- Calls f, swallowing the error a secret value raises when something
-- tries to compare or do sums with it. Returns ok and f's first result.
function W.Try(f, a, b, c, d)
  local ok, r = pcall(f, a, b, c, d)
  if ok then return true, r end
  if W.debug then W.Print("|cffd44f53" .. tostring(r) .. "|r") end
  return false
end

----------------------------------------------------------------------
-- Group
----------------------------------------------------------------------

-- The units whose threat is listed: you, your group and your pet.
function W.GroupUnits(out)
  for k in pairs(out) do out[k] = nil end
  local n = 0
  if IsInRaid() then
    for i = 1, GetNumGroupMembers() do
      n = n + 1
      out[n] = "raid" .. i
    end
  else
    n = n + 1
    out[n] = "player"
    for i = 1, GetNumSubgroupMembers() do
      n = n + 1
      out[n] = "party" .. i
    end
  end
  if UnitExists("pet") then
    n = n + 1
    out[n] = "pet"
  end
  return n
end

-- The mob to list threat for: your target if you can attack it, else your
-- target's target (a healer targeting the tank sees the tank's mob).
function W.WatchedMob()
  if UnitExists("target") and UnitCanAttack("player", "target") then return "target" end
  if UnitExists("targettarget") and UnitCanAttack("player", "targettarget") then return "targettarget" end
  return nil
end

----------------------------------------------------------------------
-- Output and settings
----------------------------------------------------------------------

function W.Print(msg)
  DEFAULT_CHAT_FRAME:AddMessage("|cff58c4ddWrekkit Forever|r: " .. msg)
end

local function fill(dst, src)
  for k, v in pairs(src) do
    if type(v) == "table" then
      if type(dst[k]) ~= "table" then dst[k] = {} end
      fill(dst[k], v)
    elseif dst[k] == nil then
      dst[k] = v
    end
  end
end

W.modules = {}
function W.Register(m) table.insert(W.modules, m) end

local function each(method)
  for _, m in ipairs(W.modules) do
    if m[method] then m[method](m) end
  end
end

function W.ApplyAll() each("Apply") end

----------------------------------------------------------------------
-- Events and the update tick
----------------------------------------------------------------------

local TICK = 0.2
local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:SetScript("OnEvent", function(self, event, name)
  if event == "ADDON_LOADED" and name == ADDON then
    WrekkitForeverDB = WrekkitForeverDB or {}
    fill(WrekkitForeverDB, DEFAULTS)
    W.db = WrekkitForeverDB
    each("Init")
    local since = 0
    self:SetScript("OnUpdate", function(_, elapsed)
      since = since + elapsed
      if since < TICK then return end
      since = 0
      each("Update")
    end)
    self:UnregisterEvent("ADDON_LOADED")
  end
end)

----------------------------------------------------------------------
-- /wf
----------------------------------------------------------------------

local HELP = {
  "/wf config - the options page (also Esc > Options > AddOns)",
  "/wf threat - show or hide the threat list",
  "/wf mobs - show or hide the mob frames",
  "/wf meter - show or hide the meter (right-click its title for more)",
  "/wf lock - lock or unlock both (drag the title to move)",
  "/wf test - fill both with sample rows to place them",
  "/wf rows <threat|mobs|meter> <n> - how many rows",
  "/wf width <threat|mobs|meter> <px> - width",
  "/wf scale <threat|mobs|meter> <50-200> - size in percent",
  "/wf debuffs - your debuffs on the mob frames on or off",
  "/wf pin - keep your own row on the threat list",
  "/wf reset - put both back in the middle of the screen",
  "/wf check - what the game lets addons read right now",
}

local function toggle(t, key, label)
  t[key] = not t[key]
  W.Print(label .. ": " .. (t[key] and "on" or "off"))
  each("Apply")
end

local function which(word)
  if word == "threat" or word == "mobs" or word == "meter" then return W.db[word] end
  W.Print("say threat, mobs or meter")
end

SLASH_WREKKITFOREVER1 = "/wf"
SLASH_WREKKITFOREVER2 = "/wrekf"
SlashCmdList.WREKKITFOREVER = function(msg)
  local cmd, a, b = strsplit(" ", strlower(strtrim(msg or "")))
  if cmd == "threat" then toggle(W.db.threat, "shown", "threat list")
  elseif cmd == "mobs" then toggle(W.db.mobs, "shown", "mob frames")
  elseif cmd == "meter" then toggle(W.db.meter, "shown", "meter")
  elseif cmd == "lock" then toggle(W.db, "locked", "locked")
  elseif cmd == "pin" then toggle(W.db.threat, "pinMe", "pin your row")
  elseif cmd == "debuffs" then toggle(W.db.mobs, "debuffs", "your debuffs")
  elseif cmd == "test" then
    W.test = not W.test
    W.Print("sample rows: " .. (W.test and "on" or "off"))
  elseif cmd == "reset" then
    W.db.threat.point, W.db.mobs.point = nil, nil
    each("Apply")
    W.Print("windows back in the middle")
  elseif cmd == "rows" or cmd == "width" or cmd == "scale" then
    local t, n = which(a), tonumber(b)
    if not t then return end
    local lo, hi = 1, 40
    if cmd == "width" then lo, hi = 120, 600 elseif cmd == "scale" then lo, hi = 50, 200 end
    if not n then W.Print(cmd .. " " .. a .. " is " .. t[cmd]) return end
    t[cmd] = math.max(lo, math.min(hi, math.floor(n)))
    W.Print(a .. " " .. cmd .. ": " .. t[cmd])
    each("Apply")
  elseif cmd == "config" or cmd == "options" then
    W.config:Open()
  elseif cmd == "check" then
    W.Check()
  elseif cmd == "debug" then
    W.debug = not W.debug
    W.Print("debug: " .. (W.debug and "on" or "off"))
  else
    W.Print("v" .. W.version)
    for _, line in ipairs(HELP) do DEFAULT_CHAT_FRAME:AddMessage("  " .. line) end
  end
end

-- What the game lets addons read right now, against your target.
function W.Check()
  local mob = W.WatchedMob()
  if not mob then
    W.Print("target a mob for the threat and aura checks")
    if W.meter then
      local yes, why = W.meter.Available()
      W.Print("damage meter: " .. (yes and "|cff6fd46favailable|r" or ("|cffd44f53off|r (" .. tostring(W.Read(why)) .. ")")))
    end
    return
  end
  local function say(label, secret)
    W.Print(label .. ": " .. (secret and "|cffd44f53hidden|r" or "|cff6fd46freadable|r"))
  end
  local S = C_Secrets
  if S and S.ShouldUnitThreatValuesBeSecret then
    say("threat numbers", S.ShouldUnitThreatValuesBeSecret("player", mob))
  end
  if S and S.ShouldUnitThreatStateBeSecret then
    say("who has aggro", S.ShouldUnitThreatStateBeSecret("player", mob))
  end
  if S and S.ShouldAurasBeSecret then say("auras", S.ShouldAurasBeSecret()) end
  if W.meter then
    local yes, why = W.meter.Available()
    W.Print("damage meter: " .. (yes and "|cff6fd46favailable|r" or ("|cffd44f53off|r (" .. tostring(W.Read(why)) .. ")")))
  end
  if not S then W.Print("no secret values on this client: everything is readable") end
end
