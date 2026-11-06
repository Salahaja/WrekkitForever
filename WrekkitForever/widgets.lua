--[[ The window and row pieces both lists are built from. ]]

local W = WrekkitForever
local UI = {}
W.UI = UI

local FONT = STANDARD_TEXT_FONT
local TITLE_H = 16
UI.ROW_H = 16

local BAR_TEXTURE = "Interface\\TargetingFrame\\UI-StatusBar"

-- A movable window: a title strip to drag by, rows below it. cfg is its
-- settings table (point, width, scale are kept there).
function UI.Window(name, title, cfg)
  local f = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
  f.cfg = cfg
  f:SetFrameStrata("MEDIUM")
  f:SetClampedToScreen(true)
  f:SetMovable(true)
  f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
  f:SetBackdropColor(0, 0, 0, 0.45)

  local bar = CreateFrame("Frame", nil, f)
  bar:SetPoint("TOPLEFT")
  bar:SetPoint("TOPRIGHT")
  bar:SetHeight(TITLE_H)
  bar:EnableMouse(true)
  bar:RegisterForDrag("LeftButton")
  bar:SetScript("OnDragStart", function()
    if not W.db.locked then f:StartMoving() end
  end)
  bar:SetScript("OnDragStop", function()
    f:StopMovingOrSizing()
    local p, _, rp, x, y = f:GetPoint()
    cfg.point = { p, rp, x, y }
  end)
  local bg = bar:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(0.1, 0.1, 0.12, 0.85)
  f.titleBar = bar

  f.title = bar:CreateFontString(nil, "OVERLAY")
  f.title:SetFont(FONT, 11, "")
  f.title:SetPoint("LEFT", 4, 0)
  f.title:SetPoint("RIGHT", -4, 0)
  f.title:SetJustifyH("LEFT")
  f.title:SetWordWrap(false)
  f.title:SetText(title)
  f.baseTitle = title

  f.rows = {}
  f.Place = UI.Place
  f.Fit = UI.Fit
  return f
end

-- Size, scale and position from the settings.
function UI.Place(f)
  local cfg = f.cfg
  f:SetScale(cfg.scale / 100)
  f:SetWidth(cfg.width)
  f:ClearAllPoints()
  if cfg.point then
    f:SetPoint(cfg.point[1], UIParent, cfg.point[2], cfg.point[3], cfg.point[4])
  else
    f:SetPoint("CENTER", UIParent, "CENTER", f.defaultX or 0, f.defaultY or 0)
  end
end

-- Height to the rows in use.
function UI.Fit(f, used)
  f:SetHeight(TITLE_H + math.max(used, 1) * UI.ROW_H + 2)
end

-- A row: a bar, a name on the left, a figure on the right, and a small
-- marker square before the name (aggro state).
function UI.Row(parent, index)
  local r = CreateFrame("StatusBar", nil, parent)
  r:SetStatusBarTexture(BAR_TEXTURE)
  r:SetMinMaxValues(0, 100)
  r:SetHeight(UI.ROW_H - 1)
  r:SetPoint("TOPLEFT", parent, "TOPLEFT", 1, -(TITLE_H + 1 + (index - 1) * UI.ROW_H))
  r:SetPoint("RIGHT", parent, "RIGHT", -1, 0)

  local bg = r:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(0.15, 0.15, 0.15, 0.6)

  r.mark = r:CreateTexture(nil, "OVERLAY")
  r.mark:SetSize(4, UI.ROW_H - 1)
  r.mark:SetPoint("LEFT")
  r.mark:SetColorTexture(1, 1, 1, 1)
  r.mark:Hide()

  r.value = r:CreateFontString(nil, "OVERLAY")
  r.value:SetFont(FONT, 11, "OUTLINE")
  r.value:SetPoint("RIGHT", -3, 0)
  r.value:SetJustifyH("RIGHT")
  r.value:SetWordWrap(false)

  r.name = r:CreateFontString(nil, "OVERLAY")
  r.name:SetFont(FONT, 11, "OUTLINE")
  r.name:SetPoint("LEFT", 7, 0)
  r.name:SetPoint("RIGHT", r.value, "LEFT", -4, 0)
  r.name:SetJustifyH("LEFT")
  r.name:SetWordWrap(false)

  r:Hide()
  return r
end

-- A unit's class colour, or grey.
function UI.ClassColor(unit)
  local ok, _, class = pcall(UnitClass, unit)
  local c = ok and W.Read(class) and RAID_CLASS_COLORS[class]
  if c then return c.r, c.g, c.b end
  return 0.5, 0.5, 0.5
end

-- The game's colours for threat states 0-3, or nil for a hidden state.
function UI.StatusColor(status)
  status = W.Read(status)
  if not status or status < 1 then return nil end
  return GetThreatStatusColor(status)
end

-- Short figures: 950, 12.4k, 1.9m.
function UI.Short(n)
  if n >= 1e6 then return string.format("%.1fm", n / 1e6) end
  if n >= 1e4 then return string.format("%.0fk", n / 1e3) end
  if n >= 1e3 then return string.format("%.1fk", n / 1e3) end
  return string.format("%.0f", n)
end
