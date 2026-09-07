LCD_W, LCD_H = 480, 272
TINSIZE, SMLSIZE, MIDSIZE, BOLD, DBLSIZE, XXLSIZE, SOLID = 2, 3, 4, 1, 5, 6, 0
lcd = { RGB = __rgb, sizeText = __measure, drawText = __text, drawLine = __line, drawFilledRectangle = __rect }
local draw = loadScript("/WIDGETS/DLGDash/draw.lua")()
local function paint(depth)
  if depth > 0 then paint(depth - 1); return end
  draw.fill(2, 46.25, 476, 42.25, draw.colors.band)
  draw.text("RxBt", 8, 46.25, 464, 41.25, draw.colors.cyan, BOLD)
  draw.line(0, 46.25, 479, 46.25, draw.colors.line)
end
-- Force different stack-growth boundaries; an in-place realloc can hide the bug.
for i = 1, 10000 do
  paint(i % 64)
  if i % 10 == 0 then collectgarbage("collect") end
end
print("PASS actual draw.lua: 10000 rectangle/text/line cycles at 64 call depths")
