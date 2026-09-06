-- EdgeTX 2.11 monochrome APIs only. No color fonts, masks or widget calls.
local D = { colors = {} }
local labels, language = nil, 0
function D.language(value)
  language = value
  if value == 1 and not labels then labels = assert(loadScript("/WIDGETS/DLGDash/lang/mono.lua"))() end
end
function D.text(value, x, y, width, large, translate)
  value = tostring(value or "--")
  local label = language == 1 and translate ~= false and labels and labels[value]
  if label and label[2] <= width then
    local offset = 0
    for part = 1, math.ceil(label[2] / 64) do
      lcd.drawPixmap(x + offset, y, "/WIDGETS/DLGDash/lang/mono/" .. label[1] .. "_" .. part .. ".bmp")
      offset = offset + 64
    end
    return
  end
  -- FIXEDWIDTH makes the slot stable, including signed three-digit percentages.
  value = string.gsub(value, "[^ -~]", "?")
  local advance = large and 11 or 6
  if #value * advance > width and large then large, advance = false, 6 end
  local count = math.floor(width / advance)
  if #value > count then value = string.sub(value, 1, math.max(0, count - 1)) .. "~" end
  lcd.drawText(x, y, value, (large and DBLSIZE or 0) + FIXEDWIDTH)
end
local function number(value)
  return type(value) == "number" and string.format("%.1f", value) or "--.-"
end
local function graph(s, C, x, y, w, h)
  lcd.drawRectangle(x, y, w, h)
  if s.graphReset then return end
  if not s.data.altitude then D.text("NO ALT", x + 2, y + 2, w - 4, false, false); return end
  local lo, hi = 0, 1
  for _, p in ipairs(s.history) do
    if p.altitude and C.elapsed(s.now, p.tick) <= s.config.window * 100 then
      lo, hi = math.min(lo, p.altitude), math.max(hi, p.altitude)
    end
  end
  local lastX, lastY
  for _, p in ipairs(s.history) do
    local age = C.elapsed(s.now, p.tick)
    if p.altitude and age <= s.config.window * 100 then
      local px = x + 1 + math.floor((1 - age / (s.config.window * 100)) * (w - 3))
      local py = y + h - 2 - math.floor((p.altitude - lo) / (hi - lo) * (h - 3))
      if lastX and not p.gap then lcd.drawLine(lastX, lastY, px, py, SOLID, 0) end
      lastX, lastY = px, py
    else lastX, lastY = nil, nil end
  end
end
function D.dashboard(s, C, page)
  local w = LCD_W
  lcd.clear()
  D.language(s.config.language)
  D.text(s.modeName or "DLG", 0, 0, w - 66, false, false)
  D.text(s.data.link and "LNK" or "---", w - 60, 0, 18, false, false)
  D.text(s.toneActive and s.config.toneVolume ~= -1 and "B" or "M", w - 36, 0, 6, false, false)
  D.text("Sail", w - 24, 0, 24, false, false)
  if page == 2 then
    for i = 1, s.config.servos do
      local x = (i - 1) % 2 * math.floor(w / 2)
      local y = 11 + math.floor((i - 1) / 2) * 17
      local v = s.data.channels[i]
      D.text(s.profile.roles[i], x, y, 18, false, false)
      D.text(v and string.format("%+d%%", math.floor(v + 0.5)) or "--%", x + 21, y, math.floor(w / 2) - 22, false, false)
      local length = math.floor(w / 2) - 5
      lcd.drawLine(x + 1, y + 12, x + length, y + 12, SOLID, 0)
      if v then
        local tick = x + 1 + math.floor((math.max(-150, math.min(150, v)) + 150) / 300 * (length - 1))
        lcd.drawLine(tick, y + 10, tick, y + 14, SOLID, 0)
      end
    end
    return
  end
  local narrow = w == 128
  local split = narrow and 65 or 114
  D.text(C.timer(s.data.timer), 0, 10, w - 1, true, false)
  local b = s.data.battery or {}
  D.text(number(b.voltage) .. "V/" .. number(b.full) .. "V", 0, 29, w, false, false)
  if not narrow then D.text(b.label or "NO DATA", 124, 29, w - 124, false, false) end
  D.text("A " .. number(s.data.altitude), 0, 40, split - 1, false, false)
  local launch = s.launchState == "delay" and "WAIT" or number(s.launchHeight)
  D.text("L " .. launch, 0, 49, split - 1, false, false)
  D.text(number(s.data.vario) .. "m/s", 0, 57, split - 1, false, false)
  graph(s, C, split, 40, w - split, 24)
end
return D
