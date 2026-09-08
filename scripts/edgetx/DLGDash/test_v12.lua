-- V12: 320x240, rotary/key navigation only. No touch events are supplied.
SOURCE, BOOL, VALUE, PLAY_BACKGROUND, SOLID = 1, 2, 3, 4, 0
STDSIZE, BOLD, TINSIZE, SMLSIZE, MIDSIZE, DBLSIZE, XXLSIZE = 0, 1, 2, 3, 4, 5, 6
UNIT_VOLTS, UNIT_CELLS, UNIT_METERS, UNIT_FEET = 1, 15, 9, 10
UNIT_METERS_PER_SECOND, UNIT_FEET_PER_SECOND = 5, 6
LCD_W, LCD_H = 320, 240
EVT_VIRTUAL_NEXT, EVT_VIRTUAL_PREV, EVT_VIRTUAL_ENTER, EVT_VIRTUAL_EXIT = 10, 11, 12, 13
EVT_VIRTUAL_INC, EVT_VIRTUAL_DEC = 10, 11
EVT_VIRTUAL_NEXT_PAGE, EVT_VIRTUAL_PREV_PAGE = 14, 15
debug.setmetatable("", nil)
_G, table = nil, nil
lcd = { RGB = __rgb, sizeText = __measure, drawText = __text, drawLine = __line,
  drawFilledRectangle = __rect, drawBitmapPattern = __mask, exitFullScreen = function() end }
Bitmap = { open = __bitmap, getSize = __bitmapSize, toMask = function(b) return b end }
local clock, radio, filename, linked = 0, "v12", "demo.yml", true
local count, storage, stamp = 0, {}, 0
local function eq(a, b) count = count + 1; assert(a == b, tostring(a) .. " != " .. tostring(b)) end
function getTime() return clock end
function getVersion() return "2.12.3", radio, 2, 12, 3, "EdgeTX" end
function getFlightMode(i) return i or 0, i == 2 and "Zoom" or "Cruise" end
local sensors = {
  { id = 301, name = "RxBt", unit = UNIT_VOLTS, value = 8.1 },
  { id = 304, name = "Alt", unit = UNIT_METERS, value = 12.3 },
  { id = 307, name = "VSpd", unit = UNIT_METERS_PER_SECOND, value = 1.2 },
  { id = 341, name = "SA", value = -1024 } }
for i = 1, 24 do sensors[#sensors + 1] = { id = 400 + i, name = "Voltage" .. i, unit = UNIT_VOLTS, value = 8.1 } end
function getFieldInfo(value)
  for _, f in ipairs(sensors) do
    if f.id == value or type(value) == "string" and string.lower(f.name) == string.lower(value) then return f end
  end
end
function sources()
  local i = 0
  return function() i = i + 1; local f = sensors[i]; if f then return f.id, f.name end end
end
function getSourceValue(value)
  local f = getFieldInfo(value)
  return f and f.value, f ~= nil and linked, false
end
function getValue(value) return (getSourceValue(value)) end
function getOutputValue() return 1024 end
function playTone() end
model = setmetatable({}, { __index = function(_, key) error("Unexpected model write/API: " .. key) end })
function model.getInfo() return { name = "V12 DLG", filename = filename } end
function model.getOutput(i) return { name = "Servo " .. (i + 1) } end
function model.getTimer() return { value = 128 } end
io = {}
function io.open(path, mode) if mode == "r" and not storage[path] then return nil end; return { path = path } end
function io.read(f, size) return string.sub(storage[f.path] or "", 1, size) end
function io.write(f, text) storage[f.path] = text; stamp = stamp + 1 end
function io.close() end
function mkdir() end
function fstat(path) if storage[path] then return { size = #storage[path], time = { sec = stamp } } end end
local function budget(name, fn)
  local n = 0
  debug.sethook(function() n = n + 100 end, "", 100); fn(); debug.sethook()
  print("V12 instructions " .. name .. ": " .. n); assert(n < 20000, name)
end
local P = loadScript("/WIDGETS/DLGDash/profile.lua")()
local C = loadScript("/WIDGETS/DLGDash/core.lua")()
local D = loadScript("/WIDGETS/DLGDash/draw.lua")()
local Settings = loadScript("/WIDGETS/DLGDash/settings.lua")(P, D)
local key, cfg = P.identity(), P.defaults()
eq(key, "v12_demo_2Eyml"); eq(cfg.toneSource, ""); eq(cfg.resetSource, ""); eq(cfg.launchMode, 2)
eq(P.save(key, cfg), true)
for _, other in ipairs({ "pa01", "v16", "t14" }) do radio = other; eq(P.load(P.identity()), nil) end
radio = "v12"
local state = C.new(cfg, P); clock = 5; C.update(state)
for i = 1, 120 do state.history[i] = { tick = clock - (120 - i) * 75, altitude = 22 + 16 * math.sin(i / 9) } end
state.launchHeight = 52.7
for _, lang in ipairs({ 0, 1 }) do
  state.config.language = lang
  for _, servos in ipairs({ 4, 6 }) do
    state.config.servos = servos
    for _, value in ipairs({ -150, -100, -99, 0, 99, 100, 150 }) do
      for i = 1, servos do state.data.channels[i] = value end
      __begin("v12-" .. lang .. "-" .. servos .. "-" .. value)
      D.dashboard(state, C, { w = 320, h = 240 }, false); __brand(false); __servoFont(servos); __end()
    end
    __begin("v12-zone-" .. lang .. "-" .. servos)
    D.dashboard(state, C, { x = 8, y = 28, w = 304, h = 204 }, false); __end()
    linked = false; clock = clock + 5; C.update(state)
    __begin("v12-lost-" .. lang .. "-" .. servos)
    D.dashboard(state, C, { w = 320, h = 240 }, false); __altStatus(true); __end()
    linked = true; clock = clock + 5; C.update(state)
  end
end
state.data.timer, state.data.altitude, state.launchHeight = -3661, -1234.5, 1234.5
__begin("v12-long-values"); D.dashboard(state, C, { w = 320, h = 240 }, false); __end()
local editor = Settings.new(key, cfg, function() end, function() end)
for _, lang in ipairs({ 0, 1 }) do
  editor.config.language = lang
  for page, info in ipairs(editor.pages) do
    editor.page, editor.focus = page, 1
    __begin("v12-settings-" .. lang .. "-" .. page); Settings.run(editor, 0, nil, 320, 240); __end()
    for row in ipairs(info.fields) do
      editor.focus = row; Settings.run(editor, EVT_VIRTUAL_ENTER, nil, 320, 240)
      eq(editor.picker ~= nil, true)
      for _, pick in ipairs({ 1, #editor.picker.choices }) do
        editor.picker.index = pick
        __begin("v12-picker-" .. lang .. "-" .. page .. "-" .. row .. "-" .. pick)
        Settings.run(editor, 0, nil, 320, 240); __end()
      end
      Settings.run(editor, EVT_VIRTUAL_EXIT, nil, 320, 240)
    end
  end
end
local api, widget = loadScript("/WIDGETS/DLGDash/main.lua")()
eq(api.options[1][3], 0)
budget("cold create", function() widget = api.create({ w = 320, h = 240 }, {}) end)
budget("roller enter", function() api.refresh(widget, EVT_VIRTUAL_ENTER, nil) end)
eq(widget.editor ~= nil, true)
api.refresh(widget, EVT_VIRTUAL_ENTER, nil); eq(widget.editor.picker.row.key, "voltage")
api.refresh(widget, EVT_VIRTUAL_NEXT, nil); api.refresh(widget, EVT_VIRTUAL_ENTER, nil)
local chosen = widget.editor.config.voltage
for i = 1, 5 do api.refresh(widget, EVT_VIRTUAL_NEXT, nil) end
budget("roller save", function() api.refresh(widget, EVT_VIRTUAL_ENTER, nil) end)
eq(widget.editor.message, "Saved"); eq(P.load(key).voltage, chosen)
api.refresh(widget, EVT_VIRTUAL_EXIT, nil); eq(widget.editor, nil)
api.refresh(widget, EVT_VIRTUAL_ENTER, nil); eq(widget.editor.config.voltage, chosen)
for i = 1, 1300 do clock = clock + 10; api.refresh(widget, 0, nil); assert(widget.editor) end
filename = "second.yml"; api.background(widget)
eq(widget.editor, nil); eq(widget.key, "v12_second_2Eyml"); eq(widget.state.config.toneSource, "")
filename = "demo.yml"
local tool = loadScript("/WIDGETS/DLGDash/DLGSetup.lua")()
budget("SYS tool init", function() tool.init(); tool.run(0) end)
tool.run(EVT_VIRTUAL_NEXT_PAGE); tool.run(EVT_VIRTUAL_ENTER)
tool.run(EVT_VIRTUAL_NEXT); tool.run(EVT_VIRTUAL_ENTER)
for i = 1, 6 do tool.run(EVT_VIRTUAL_NEXT) end
tool.run(EVT_VIRTUAL_ENTER); eq(tool.run(EVT_VIRTUAL_EXIT), 2)
print("PASS V12: " .. count .. " assertions; key-only simulation, hardware acceptance pending")
