local D = {}
local wide = LCD_W == 480 and LCD_H >= 272
local L = assert(loadScript("/WIDGETS/DLGDash/locale.lua"))()
function D.language(value) D.lang = value end
D.colors = {
  bg = lcd.RGB(14, 16, 17), band = lcd.RGB(31, 34, 35), line = lcd.RGB(73, 78, 80),
  text = lcd.RGB(247, 248, 248), muted = lcd.RGB(181, 188, 190), cyan = lcd.RGB(49, 213, 235),
  green = lcd.RGB(106, 226, 139), amber = lcd.RGB(255, 196, 68), red = lcd.RGB(255, 108, 103),
  pink = lcd.RGB(241, 132, 209)
}
local c = D.colors
local fonts = { XXLSIZE, DBLSIZE, MIDSIZE, BOLD, SMLSIZE, TINSIZE }
local fontStart = {}
for i, font in ipairs(fonts) do fontStart[font] = i end
-- Parentheses avoid a broken C tail call in the EdgeTX 2.10 Lua VM.
local function round(v) return (math.floor(v + 0.5)) end
function D.fill(x, y, w, h, color)
  if w > 0 and h > 0 then lcd.drawFilledRectangle(round(x), round(y), round(w), round(h), color) end
end
function D.line(x, y, x2, y2, color) lcd.drawLine(round(x), round(y), round(x2), round(y2), SOLID, color or c.line) end
function D.text(text, x, y, w, h, color, maxFont, align)
  text = tostring(text)
  if D.lang == 1 and L.draw(text, x, y, w, h, color or c.text, maxFont, align) then return end
  local chosen, tw, th = TINSIZE, 0, 0
  for i = fontStart[maxFont] or 1, #fonts do
    local font = fonts[i]
    tw, th = lcd.sizeText(text, font)
    if tw <= w and th <= h then chosen = font; break end
  end
  tw, th = lcd.sizeText(text, chosen)
  -- Long names are ellipsized, never painted over neighboring controls.
  while tw > w and #text > 3 do
    text = string.sub(text, 1, -5) .. "..."
    tw, th = lcd.sizeText(text, chosen)
  end
  if tw > w or th > h then return end
  local dx = align == "right" and w - tw or align == "center" and (w - tw) / 2 or 0
  lcd.drawText(round(x + dx), round(y + (h - th) / 2), text, chosen + (color or c.text))
end

local function height(value) return value and string.format("%.1f", value) or "--.-" end
local function metric(x, y, w, h, label, value, color)
  local labelH = wide and 18 or 16
  D.text(label, x + 4, y, w - 8, labelH, c.muted, SMLSIZE, "center")
  D.text(height(value), x + 3, y + labelH + 1, w - 21, h - labelH - 2, color, DBLSIZE, "right")
  D.text("m", x + w - 16, y + h - 25, 13, 22, color, BOLD)
end
local function battery(s, x, y, w, h)
  local b = s.data.battery or {}
  local color = b.voltage and (b.low and c.red or c.green) or c.muted
  local labelH, fullH = wide and 18 or 16, wide and 21 or 19
  D.text(b.label or "BATTERY", x + 4, y, w - 8, labelH, c.muted, SMLSIZE, "center")
  D.text(b.voltage and string.format("%.2fV", b.voltage) or "--.--V", x + 4, y + labelH, w - 8, h - labelH - fullH, color, DBLSIZE, "center")
  D.text(b.full and string.format(b.hv and "FULL /%.2fV" or "FULL /%.1fV", b.full) or "FULL /--.-V", x + 4, y + h - fullH, w - 8, fullH, c.text, BOLD, "center")
end
local function servo(s, x, y, w, h, index)
  local value = s.data.channels[index]
  local color = ({ c.amber, c.cyan, c.green, c.pink, c.amber, c.cyan })[index]
  D.text(s.profile.roles[index], x + 4, y + 1, wide and 30 or 21, h - 5, color, BOLD)
  -- Reserve the same signed three-digit slot for every output; % has its own slot.
  local valueX, unitW = wide and 39 or 28, wide and 14 or 10
  local valueWidth = w - valueX - unitW - 2
  local maxWidth, maxHeight = lcd.sizeText("+888", MIDSIZE)
  local font = maxWidth <= valueWidth and maxHeight <= h - 5 and MIDSIZE or BOLD
  local text, textColor = value and string.format("%+.0f", value) or "--", c.text
  local tw, th = lcd.sizeText(text, font)
  if tw > valueWidth then text, textColor = "OVR", c.red; tw, th = lcd.sizeText(text, font) end
  local ty = round(y + 1 + (h - 5 - th) / 2)
  lcd.drawText(round(x + valueX + valueWidth - tw), ty, text, font + textColor)
  local _, unitHeight = lcd.sizeText("%", SMLSIZE)
  lcd.drawText(round(x + w - unitW - 1), ty + th - unitHeight, "%", SMLSIZE + c.muted)
  local bx, bw, by = x + 4, w - 9, y + h - 3
  D.fill(bx, by, bw, 1, c.line)
  if value then
    local offset = math.max(-1, math.min(1, value / 150)) * (bw / 2 - 1)
    D.fill(bx + bw / 2 + math.min(0, offset), by - 1, math.max(1, math.abs(offset)), 2, color)
  end
  D.fill(bx + bw / 2, by - 1, 1, 3, c.muted)
end
local function graph(s, core, x, y, w, h)
  D.line(x, y, x, y + h - 1)
  local labelH, inset = wide and 21 or 17, wide and 32 or 25
  D.text(s.config.window .. "s", x + 5, y, wide and 48 or 38, labelH, c.muted, SMLSIZE)
  local speed = s.data.vario
  local speedX = wide and 59 or 45
  D.text(speed and string.format("%+.1fm/s", speed) or "--m/s", x + speedX, y, w - speedX - 5, labelH,
    speed and (speed > 0 and c.green or c.amber) or c.muted, BOLD, "right")
  local px, py, pw, ph = x + inset, y + labelH + 3, w - inset - 5, h - labelH - 8
  if ph < 15 then return end
  local low, high
  for _, point in ipairs(s.history) do
    if point.altitude and core.elapsed(s.now, point.tick) <= s.config.window * 100 then
      low = math.min(low or point.altitude, point.altitude)
      high = math.max(high or point.altitude, point.altitude)
    end
  end
  local mid = low and (high + low) / 2 or 0
  local range = low and math.max(4, (high - low) * 1.15) or 4
  low, high = mid - range / 2, mid + range / 2
  for i = 0, 2 do D.line(px, py + ph * i / 2, px + pw - 1, py + ph * i / 2) end
  D.text(string.format("%.0f", high), x + 2, py, inset - 4, 13, c.muted, TINSIZE, "right")
  D.text(string.format("%.0f", low), x + 2, py + ph - 13, inset - 4, 13, c.muted, TINSIZE, "right")
  local lastX, lastY, lastTick
  for _, point in ipairs(s.history) do
    local age = core.elapsed(s.now, point.tick)
    if point.altitude and age <= s.config.window * 100 then
      local pointX = math.floor(px + (1 - age / (s.config.window * 100)) * (pw - 1) + 0.5)
      local pointY = math.floor(py + (high - point.altitude) / range * ph + 0.5)
      if lastX and not point.gap and core.elapsed(point.tick, lastTick) <= s.effectivePeriod * 2 then
        lcd.drawLine(lastX, lastY, pointX, pointY, SOLID, c.cyan)
      else lcd.drawFilledRectangle(pointX, pointY, 1, 1, c.cyan) end
      lastX, lastY, lastTick = pointX, pointY, point.tick
    else lastX, lastY, lastTick = nil, nil, nil end
  end
  if s.graphReset then D.text("RESET", px + 2, py + ph / 2 - 10, pw - 4, 20, c.muted, SMLSIZE, "center")
  elseif not s.data.altitude then D.text("NO ALT", px + 2, py + ph / 2 - 10, pw - 4, 20, c.muted, SMLSIZE, "center") end
end
function D.dashboard(s, core, zone, fullscreen)
  D.language(s.config.language)
  local x, y, w, h = zone.x or 0, zone.y or 0, zone.w, zone.h
  D.fill(x, y, w, h, c.bg)
  if w < 300 or h < 220 then
    D.text("DLG: full-screen 1x1", x + 4, y, w - 8, h, c.amber, BOLD, "center"); return
  end
  local header, timerH, statsH = 20, 56, 70
  if wide then header, timerH, statsH = 24, h >= 260 and 70 or 56, h >= 260 and 82 or 70 end
  D.fill(x, y, w, header, c.band)
  D.text((s.profile.api.mixedOutputs and "MIX " or "DLG ") .. (s.modeName or "--"), x + 4, y, w - (wide and 198 or 170), header, c.text, BOLD)
  D.text(s.data.link and "LINK" or "LOST", x + w - (wide and 192 or 164), y, wide and 52 or 42, header, s.data.link and c.green or c.red, SMLSIZE)
  local audible = s.toneActive and s.config.toneVolume ~= -1
  D.text(audible and "BEEP" or "MUTE", x + w - (wide and 136 or 118), y, wide and 62 or 44, header, audible and c.green or c.muted, SMLSIZE)
  D.text(fullscreen and "SET" or "Sail", x + w - 67, y, 62, header, fullscreen and c.amber or c.muted, BOLD, "right")
  D.text(core.timer(s.data.timer), x + 4, y + header, w - 8, timerH, s.data.timer and s.data.timer < 0 and c.red or c.text, XXLSIZE, "center")
  local sy, sw = y + header + timerH, w / 3
  D.line(x + 4, sy, x + w - 5, sy)
  battery(s, x, sy + 1, sw, statsH - 2)
  local label = "LAUNCH"
  if s.launchState == "tracking" then label = "IN MODE"
  elseif s.launchState == "delay" then label = string.format("WAIT %.1fs", math.max(0, s.config.delay / 10 - core.elapsed(s.now, s.exitTick) / 100))
  elseif s.launchState == "lost" then label = "NO FIX"
  elseif s.config.launchMode < 0 then label = "SET MODE" end
  metric(x + sw, sy + 1, sw, statsH - 2, label, s.launchHeight, c.amber)
  metric(x + sw * 2, sy + 1, sw, statsH - 2, "ALTITUDE", s.data.altitude, c.cyan)
  for i = 1, 2 do D.line(x + sw * i, sy + 4, x + sw * i, sy + statsH - 4) end
  local by, bh, left = sy + statsH, h - header - timerH - statsH, math.floor(w * 0.54)
  D.line(x + 4, by, x + w - 5, by)
  local columns = 2
  local rows = s.config.servos / columns
  for i = 1, s.config.servos do
    local col, row = (i - 1) % columns, math.floor((i - 1) / columns)
    servo(s, x + col * left / columns, by + row * bh / rows, left / columns, bh / rows, i)
  end
  graph(s, core, x + left, by, w - left, bh)
end
return D
