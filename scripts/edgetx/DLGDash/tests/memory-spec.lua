-- Separate from Fengari: exercise native Lua's allocator, parser and GC.
-- Absolute figures include desktop Lua's standard library and API stubs.
local readFile = loadfile
local legacy = string.find(__scenario, "legacy", 1, true) ~= nil
local telemetry = string.find(__scenario, "telemetry", 1, true) ~= nil
local clock, bytes, tool = 0, {}, nil
LCD_W, LCD_H, DBLSIZE, FIXEDWIDTH, SOLID = 128, 64, 1024, 16, 0
UNIT_VOLTS, UNIT_CELLS, UNIT_METERS, UNIT_FEET = 1, 15, 9, 10
UNIT_METERS_PER_SECOND, UNIT_FEET_PER_SECOND = 5, 6
EVT_VIRTUAL_NEXT, EVT_VIRTUAL_PREV, EVT_VIRTUAL_ENTER, EVT_VIRTUAL_EXIT = 10, 11, 12, 13
EVT_VIRTUAL_NEXT_PAGE, EVT_VIRTUAL_PREV_PAGE = 14, 15
local function noop() end
lcd = { clear = noop, drawText = noop, drawPixmap = noop, drawLine = noop, drawRectangle = noop }
function getVersion() return legacy and "2.7.1" or "2.11.3", "zorro", 2, legacy and 7 or 11, 1, "EdgeTX" end
function getTime() return clock end
function getFlightMode(i) return i or 0, i == 2 and "Zoom" or "Cruise" end
function getOutputValue() return 0 end
function getSourceValue() return 8.1, true, true end
getValue, playTone = getSourceValue, noop
function getRSSI() return 85 end
if legacy then getSourceValue, getOutputValue = nil, nil end
function getFieldInfo(value)
  if value == 301 or value == "RxBt" then return { id = 301, name = "RxBt", unit = 1 } end
  if value == 304 or value == "Alt" then return { id = 304, name = "Alt", unit = 9 } end
  if value == 307 or value == "VSpd" then return { id = 307, name = "VSpd", unit = 5 } end
  if type(value) == "number" then return { id = value, name = "Input " .. value } end
end
function sources()
  local i = 0
  return function()
    i = i + 1
    if i <= 150 then return i, "Input " .. i end
    local f = getFieldInfo(301 + (i - 151) * 3)
    if i <= 153 then return f.id, f.name end
  end
end
model = { getInfo = function() return { name = "Demo", filename = "demo.yml" } end,
  getOutput = function(i) return { name = "Servo " .. i } end,
  getTimer = function() return { value = 128 } end }
io = { open = function(path, mode)
  if mode == "r" and not bytes[path] then return nil end
  return { path = path }
end, read = function(f) return bytes[f.path] end,
write = function(f, text) bytes[f.path] = text end, close = noop }
mkdir = not legacy and noop or nil
function loadScript(path)
  local name = string.gsub(path, ".*/DLGDash/", "")
  __stage("compile " .. name)
  return readFile(__root .. "/" .. name)
end
debug.setmetatable("", nil)
__stage("entry")
tool = assert(loadScript("/WIDGETS/DLGDash/" .. (telemetry and "DLG.lua" or "DLGSetup.lua")))()
tool.init()
tool.run(0)
if telemetry then tool.run(EVT_VIRTUAL_ENTER); tool.run(0) end
-- Traverse every field and its largest picker, twice, including Chinese/save.
local counts = { 3, 4, 3, 3, 4, 4, 4, 4, 1, 0 }
for cycle = 1, 2 do
  for page, fields in ipairs(counts) do
    for row = 1, fields do
      __stage("page " .. page .. " row " .. row)
      tool.run(EVT_VIRTUAL_ENTER)
      for i = 1, 160 do tool.run(EVT_VIRTUAL_NEXT) end
      tool.run(EVT_VIRTUAL_ENTER)
      tool.run(EVT_VIRTUAL_NEXT)
      collectgarbage("collect")
    end
    tool.run(EVT_VIRTUAL_NEXT_PAGE)
  end
end
-- Save, close, reopen with a profile that must be parsed and checksum-verified.
for i = 1, 5 do tool.run(EVT_VIRTUAL_NEXT) end
tool.run(EVT_VIRTUAL_ENTER)
tool.run(EVT_VIRTUAL_EXIT)
assert(next(bytes), "Menu traversal must reach Save and create a profile")
tool = nil
collectgarbage("collect")
tool = assert(loadScript("/WIDGETS/DLGDash/DLGSetup.lua"))()
tool.init()
tool.run(0)
_G.__keepTool = tool
