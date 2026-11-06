--[[ The options page: Esc > Options > AddOns > Wrekkit Forever, or /wf config.
     Every control reads and writes WrekkitForeverDB through a proxy
     setting and re-applies the windows when it changes. ]]

local W = WrekkitForever
local C = {}
W.config = C

local function percent(v) return string.format("%d%%", v) end
local function pixels(v) return string.format("%d px", v) end
local function count(v) return string.format("%d", v) end

function C:Init()
  if not (Settings and Settings.RegisterVerticalLayoutCategory) then return end
  local category, layout = Settings.RegisterVerticalLayoutCategory("Wrekkit Forever")
  self.category = category

  -- A checkbox or slider bound to t[key]; changes re-apply the windows.
  local function bind(id, t, key, name, kind, default)
    local function get() return t()[key] end
    local function set(v)
      t()[key] = v
      W.ApplyAll()
    end
    return Settings.RegisterProxySetting(category, "WREKKITFOREVER_" .. id, kind, name, default, get, set)
  end

  local function checkbox(id, t, key, name, default, tooltip)
    local s = bind(id, t, key, name, Settings.VarType.Boolean, default)
    Settings.CreateCheckbox(category, s, tooltip)
  end

  local function slider(id, t, key, name, default, lo, hi, step, label, tooltip)
    local s = bind(id, t, key, name, Settings.VarType.Number, default)
    local o = Settings.CreateSliderOptions(lo, hi, step)
    o:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, label)
    Settings.CreateSlider(category, s, o, tooltip)
  end

  local function header(text)
    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(text))
  end

  local db = function() return W.db end
  local threat = function() return W.db.threat end
  local mobs = function() return W.db.mobs end

  header("General")
  checkbox("LOCKED", db, "locked", "Lock windows", false,
    "Stops the windows being dragged, and hides each one while it has nothing to show.")
  local sample = Settings.RegisterProxySetting(category, "WREKKITFOREVER_SAMPLE", Settings.VarType.Boolean,
    "Show sample rows", false,
    function() return W.test == true end,
    function(v) W.test = v end)
  Settings.CreateCheckbox(category, sample, "Fills both windows with made-up rows so you can place and size them.")
  layout:AddInitializer(CreateSettingsButtonInitializer("Window positions", "Reset", function()
    W.db.threat.point, W.db.mobs.point = nil, nil
    W.ApplyAll()
  end, "Puts both windows back near the middle of the screen.", true))

  header("Threat list")
  checkbox("THREAT_SHOWN", threat, "shown", "Show the threat list", true)
  checkbox("THREAT_PIN", threat, "pinMe", "Keep my row on the list", true,
    "When there are more players than rows, your row takes the last line.")
  slider("THREAT_ROWS", threat, "rows", "Rows", 10, 1, 40, 1, count)
  slider("THREAT_WIDTH", threat, "width", "Width", 200, 120, 600, 10, pixels)
  slider("THREAT_SCALE", threat, "scale", "Size", 100, 50, 200, 5, percent)

  header("Mob frames")
  checkbox("MOBS_SHOWN", mobs, "shown", "Show the mob frames", true,
    "Enemies in combat: your target and focus, what your group targets, boss frames, and enemy nameplates. A mob nobody targets shows only with enemy nameplates on (V).")
  checkbox("MOBS_DEBUFFS", mobs, "debuffs", "My debuffs on each mob", true,
    "Up to five of your own debuffs to the left of each mob, with their timers.")
  slider("MOBS_ROWS", mobs, "rows", "Rows", 8, 1, 40, 1, count)
  slider("MOBS_WIDTH", mobs, "width", "Width", 220, 120, 600, 10, pixels)
  slider("MOBS_SCALE", mobs, "scale", "Size", 100, 50, 200, 5, percent)

  local meter = function() return W.db.meter end
  header("Meter")
  checkbox("METER_SHOWN", meter, "shown", "Show the meter", false,
    "Blizzard's own damage meter numbers, per pull. Right-click its title for damage, healing, interrupts, deaths and older pulls; click a player for their spells.")
  checkbox("METER_PIN", meter, "pinMe", "Keep my row on the meter", true)
  slider("METER_ROWS", meter, "rows", "Rows", 10, 1, 40, 1, count)
  slider("METER_WIDTH", meter, "width", "Width", 240, 120, 600, 10, pixels)
  slider("METER_SCALE", meter, "scale", "Size", 100, 50, 200, 5, percent)

  Settings.RegisterAddOnCategory(category)
end

function C:Open()
  if self.category then
    Settings.OpenToCategory(self.category:GetID())
  else
    W.Print("this client has no options panel: use /wf")
  end
end

W.Register(C)
