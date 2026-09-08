-- Chinese labels are bundled bitmaps, independent of the firmware language.
local L = {}
if not Bitmap or not Bitmap.toMask or not lcd.drawBitmapPattern then
  function L.draw() return false end
  return L
end
local labels = assert(loadScript("/WIDGETS/DLGDash/lang/zh.lua"))()
local cache, order = {}, {}
local function bitmap(id, size)
  local key = id .. "_" .. size
  if cache[key] ~= nil then return cache[key] end
  local image = Bitmap.open("/WIDGETS/DLGDash/lang/zh/" .. key .. ".png")
  local width, height
  if image then width, height = Bitmap.getSize(image) end
  local entry = false
  if width and height and width > 0 and height == size then
    entry = { mask = Bitmap.toMask(image), w = width, h = height }
  end
  if #order >= 24 then
    cache[order[1]] = nil
    for i = 1, #order - 1 do order[i] = order[i + 1] end
    order[#order] = nil
  end
  order[#order + 1], cache[key] = key, entry
  return entry
end

function L.draw(text, x, y, w, h, color, font, align)
  local id, suffix = labels[text], nil
  if not id and string.sub(text, 1, 5) == "WAIT " then
    id, suffix = labels.WAIT, string.sub(text, 6)
  elseif not id and string.sub(text, 1, 5) == "FULL " then
    id, suffix = labels.FULL, string.sub(text, 6)
  elseif not id and string.sub(text, 1, 4) == "REC " then
    id, suffix = labels.Record, string.sub(text, 5)
  elseif not id and string.sub(text, -10) == " (missing)" then
    id, suffix = labels.Missing, string.sub(text, 1, -11)
  end
  if not id then return false end
  local size = (h < 17 or font == SMLSIZE or font == TINSIZE) and 14 or 17
  if LCD_W == 480 and h >= 17 then size = h >= 21 and font ~= SMLSIZE and font ~= TINSIZE and 21 or 17 end
  local entry = bitmap(id, size)
  if not entry or entry.h > h then return false end
  local suffixFont = (size == 14 or LCD_W == 480 and size == 17) and SMLSIZE or BOLD
  local sw, sh = 0, 0
  if suffix then sw, sh = lcd.sizeText(suffix, suffixFont); sw = sw + 4 end
  if sh > h then return false end
  local width = entry.w + sw
  if width > w then return false end
  local dx = align == "right" and w - width or align == "center" and (w - width) / 2 or 0
  lcd.drawBitmapPattern(entry.mask, math.floor(x + dx + 0.5), math.floor(y + (h - entry.h) / 2 + 0.5), color)
  if suffix then lcd.drawText(math.floor(x + dx + entry.w + 4 + 0.5), math.floor(y + (h - sh) / 2 + 0.5), suffix, suffixFont + color) end
  return true
end
return L
