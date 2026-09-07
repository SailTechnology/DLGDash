-- V16-specific layout, navigation, identity and cold-start checks.
SOURCE, BOOL, VALUE, PLAY_BACKGROUND, SOLID = 1, 2, 3, 4, 0
STDSIZE, BOLD, TINSIZE, SMLSIZE, MIDSIZE, DBLSIZE, XXLSIZE = 0, 1, 2, 3, 4, 5, 6
UNIT_VOLTS, UNIT_CELLS, UNIT_METERS, UNIT_FEET = 1, 15, 9, 10
UNIT_METERS_PER_SECOND, UNIT_FEET_PER_SECOND = 5, 6
LCD_W, LCD_H = 480, 272
EVT_VIRTUAL_NEXT, EVT_VIRTUAL_PREV, EVT_VIRTUAL_ENTER, EVT_VIRTUAL_EXIT = 10, 11, 12, 13
EVT_VIRTUAL_INC, EVT_VIRTUAL_DEC = 10, 11
EVT_VIRTUAL_NEXT_PAGE, EVT_VIRTUAL_PREV_PAGE = 14, 15
debug.setmetatable("", nil)
lcd = { RGB = __rgb, sizeText = __measure, drawText = __text, drawLine = __line,
  drawFilledRectangle = __rect, drawBitmapPattern = __mask, exitFullScreen = function() end }
Bitmap = { open = __bitmap, getSize = __bitmapSize, toMask = function(bitmap) return bitmap end }
local sim = { clock = 0, radio = "v16", filename = "demo.yml", current = true, altitude = 12.3,
  voltage = 7.8, speed = 1.2, mode = 0, timer = 128, switch = -1024, output = 0, tones = {} }
local count = 0
local function eq(value, expected, message)
  count = count + 1
  assert(value == expected, (message or "assertion") .. ": " .. tostring(value) .. " != " .. tostring(expected))
end
local sensors = {
  { id = 301, name = "RxBt", unit = UNIT_VOLTS, key = "voltage" },
  { id = 304, name = "Alt", unit = UNIT_METERS, key = "altitude" },
  { id = 307, name = "VSpd", unit = UNIT_METERS_PER_SECOND, key = "speed" },
  { id = 341, name = "SF", key = "switch" }, { id = 342, name = "SE", key = "switch" }
}
local fieldsByKey = {}
for i = 1, 24 do sensors[#sensors + 1] = { id = 400 + i, name = "Voltage" .. i, unit = UNIT_VOLTS, key = "voltage" } end
for i = 1, 32 do sensors[#sensors + 1] = { id = 500 + i, name = "CH" .. i, key = "output" } end
for _, f in ipairs(sensors) do fieldsByKey[f.id], fieldsByKey[string.lower(f.name)] = f, f end
function getFieldInfo(value)
  return fieldsByKey[type(value) == "string" and string.lower(value) or value]
end
function sources()
  local i = 0
  return function() i = i + 1; if sensors[i] then return sensors[i].id, sensors[i].name end end
end
function getTime() return sim.clock end
function getVersion()
  local minor = __firmwareMinor or 11
  return minor == 10 and "2.10.1-selfbuild" or "2.11.3", sim.radio, 2, minor, minor == 10 and 1 or 3, "EdgeTX"
end
function getFlightMode(index)
  index = index or sim.mode
  return index, ({ [0] = "Cruise", "Preset", "Zoom", "Thermal" })[index] or ""
end
function getSourceValue(value)
  local f = getFieldInfo(value)
  if not f then return nil, false, false end
  return sim[f.key], not f.unit or sim.current, false
end
function getValue(value) local v, current = getSourceValue(value); return current and v or 0 end
function getOutputValue(index) return sim.output * 10.24 end
function getSourceName(id) local f = getFieldInfo(id); return f and f.name end
function playTone(frequency, duration, pause, flags, increment, volume)
  sim.tones[#sim.tones + 1] = { frequency, duration, pause, flags, increment, volume }
end
model = setmetatable({}, { __index = function(_, key) error("Unexpected model API: " .. key) end })
function model.getInfo() return { name = "DLG Demo", filename = sim.filename } end
function model.getTimer(index) return { value = sim.timer } end
function model.getOutput(index) return { name = "Servo " .. (index + 1) } end
local storage, revision = {}, 0
io = {}
function io.open(path, mode)
  if mode == "r" and not storage[path] then return nil end
  return { path = path, mode = mode }
end
function io.read(file, size) return string.sub(storage[file.path] or "", 1, size) end
function io.write(file, text) storage[file.path] = text; revision = revision + 1 end
function io.close() end
function mkdir() return 0 end
function fstat(path) if storage[path] then return { size = #storage[path], time = { sec = revision } } end end
local function budget(name, fn)
  local instructions = 0
  debug.sethook(function() instructions = instructions + 100 end, "", 100)
  fn(); debug.sethook()
  print("V16 instructions " .. name .. ": " .. instructions)
  assert(instructions < 20000, name .. " exceeded instruction budget")
end
local P = loadScript("/WIDGETS/DLGDash/profile.lua")()
local C = loadScript("/WIDGETS/DLGDash/core.lua")()
local D = loadScript("/WIDGETS/DLGDash/draw.lua")()
local Settings = loadScript("/WIDGETS/DLGDash/settings.lua")(P, D)
local key = P.identity()
eq(key, "v16_demo_2Eyml")
local config = P.defaults()
eq(config.toneSource, "", "new V16 must not guess a sound switch")
eq(config.resetSource, "", "new V16 must not guess a clear switch")
eq(config.launchMode, 2)
local api = loadScript("/WIDGETS/DLGDash/main.lua")()
eq(api.options[1][3], 0); eq(api.version, "1.0.1-beta.3")
eq(P.save(key, config), true)
sim.radio = "pa01"; eq(P.load(P.identity()), nil, "radio profiles are independent"); sim.radio = "v16"
local function flight(servos, language)
  local cfg = P.defaults(); cfg.servos, cfg.language = servos, language
  local s = C.new(cfg, P)
  sim.clock = sim.clock + 5; C.update(s)
  for i = 1, 120 do s.history[i] = { tick = sim.clock - (120 - i) * 75, altitude = 10 + 6 * math.sin(i / 9) } end
  s.launchHeight = 52.7
  return s
end
for _, language in ipairs({ 0, 1 }) do
  for _, servos in ipairs({ 4, 6 }) do
    local s = flight(servos, language)
    for _, value in ipairs({ -150, -100, -99, 0, 99, 100, 150 }) do
      for ch = 1, servos do s.data.channels[ch] = value end
      __begin("v16-" .. language .. "-" .. servos .. "-" .. value)
      D.dashboard(s, C, { w = 480, h = 272 }, false); __brand(false); __v16Layout(servos, 272); __end()
    end
    for _, h in ipairs({ 232, 240, 252 }) do
      __begin("v16-home-" .. language .. "-" .. servos .. "-" .. h)
      D.dashboard(s, C, { w = 480, h = h }, false); __brand(false); __v16Layout(servos, h); __end()
    end
    s.launchState, s.exitTick, s.config.delay = "delay", s.now, 10
    __begin("v16-wait-" .. language .. "-" .. servos); D.dashboard(s, C, { w = 480, h = 272 }, true); __end()
    sim.current = false; sim.clock = sim.clock + 5; C.update(s)
    __begin("v16-lost-" .. language .. "-" .. servos); D.dashboard(s, C, { w = 480, h = 272 }, false); __altStatus(true); __end()
    sim.current = true
  end
end
local s = flight(6, 1)
s.data.timer, s.data.altitude, s.launchHeight = -3661, -1234.5, 1234.5
__begin("v16-long-values"); D.dashboard(s, C, { w = 480, h = 272 }, false); __end()
__begin("v16-small-zone"); D.dashboard(s, C, { w = 240, h = 140 }, false); __end()
local saved, closed = false, false
local editor = Settings.new(key, config, function() saved = true end, function() closed = true end)
for _, language in ipairs({ 0, 1 }) do
  editor.config.language = language
  for page, info in ipairs(editor.pages) do
    editor.page, editor.focus = page, 1
    __begin("v16-settings-" .. language .. "-" .. page); Settings.run(editor, 0, nil, 480, 272); __end()
    for row in ipairs(info.fields) do
      editor.focus = row; Settings.run(editor, EVT_VIRTUAL_ENTER, nil, 480, 272)
      assert(editor.picker)
      for _, pick in ipairs({ 1, #editor.picker.choices }) do
        editor.picker.index = pick
        __begin("v16-picker-" .. language .. "-" .. page .. "-" .. row .. "-" .. pick)
        Settings.run(editor, 0, nil, 480, 272); __end()
      end
      Settings.run(editor, EVT_VIRTUAL_EXIT, nil, 480, 272)
    end
  end
end
editor.page, editor.focus = 8, 1
Settings.run(editor, 0, { x = 100, y = 66, tapCount = 1 }, 480, 272); assert(editor.picker)
editor.picker.index = P.api.toneVolume and 3 or 2; Settings.run(editor, EVT_VIRTUAL_ENTER, nil, 480, 272)
local chosenVolume = P.api.toneVolume and 1 or -1
eq(editor.config.toneVolume, chosenVolume)
Settings.run(editor, 0, { x = 300, y = 252, tapCount = 1 }, 480, 272)
eq(saved, true); eq(P.load(key).toneVolume, chosenVolume)
Settings.run(editor, 0, { x = 430, y = 252, tapCount = 1 }, 480, 272); eq(closed, true)
local widget
budget("cold create", function() widget = api.create({ w = 480, h = 272 }, { ToneSw = 0 }) end)
widget.state = flight(6, 1); widget.state.config.toneSource = "SF"; widget.state.config.toneVolume = 5
sim.switch = 1024
budget("full graph Chinese", function() api.refresh(widget, 0, nil) end)
budget("settings entry", function() api.refresh(widget, 0, { x = 460, y = 10, tapCount = 1 }) end)
assert(widget.editor)
widget.editor.focus = #widget.editor.pages[1].fields + 3
budget("settings save", function() api.refresh(widget, EVT_VIRTUAL_ENTER, nil) end)
api.refresh(widget, EVT_VIRTUAL_EXIT, nil); eq(widget.editor, nil)
api.refresh(widget, EVT_VIRTUAL_ENTER, nil)
sim.current = false
budget("roller voltage picker no telemetry", function() api.refresh(widget, EVT_VIRTUAL_ENTER, nil) end)
eq(widget.editor.picker.row.key, "voltage")
assert(#widget.editor.picker.choices >= 25)
for i = 1, 26 do api.refresh(widget, EVT_VIRTUAL_NEXT, nil) end
__begin("v16-widget-voltage-picker"); api.refresh(widget, 0, nil); __end()
api.refresh(widget, EVT_VIRTUAL_PREV, nil)
api.refresh(widget, EVT_VIRTUAL_EXIT, nil)
eq(widget.editor.picker, nil)
api.refresh(widget, EVT_VIRTUAL_EXIT, nil)
sim.current = true
-- Keep an unsaved draft across a firmware-controlled full-screen interruption.
api.refresh(widget, EVT_VIRTUAL_ENTER, nil)
api.refresh(widget, EVT_VIRTUAL_NEXT, nil)
api.refresh(widget, EVT_VIRTUAL_ENTER, nil)
api.refresh(widget, EVT_VIRTUAL_NEXT, nil)
api.refresh(widget, EVT_VIRTUAL_ENTER, nil)
local draft = widget.editor
eq(draft.dirty, true)
local draftCells, savedCells = draft.config.cells, P.load(key).cells
for i = 1, 1800 do
  sim.clock = sim.clock + 10
  if i == 450 then
    api.refresh(widget, nil, nil)
    eq(widget.state.muted, false, "hidden settings must not mute flight tones")
    api.background(widget)
  else api.refresh(widget, 0, nil) end
  assert(widget.editor == draft, "idle/non-interactive refresh discarded settings draft at " .. i / 10 .. "s")
end
eq(draft.config.cells, draftCells); eq(P.load(key).cells, savedCells)
eq(widget.state.muted, true, "visible settings mute tones")
api.refresh(widget, EVT_VIRTUAL_EXIT, nil)
eq(widget.editor, draft, "dirty exit requires confirmation")
api.refresh(widget, EVT_VIRTUAL_EXIT, nil); eq(widget.editor, nil)
api.refresh(widget, EVT_VIRTUAL_ENTER, nil)
eq(widget.editor.config.cells, savedCells, "discard must not save")
api.refresh(widget, EVT_VIRTUAL_EXIT, nil)
local long = P.defaults()
for _, k in ipairs({ "voltage", "altitude", "vario", "toneSource", "resetSource" }) do long[k] = string.rep("X", 32) end
P.save(key, long); P.save(key, long)
local cold = loadScript("/WIDGETS/DLGDash/main.lua")()
budget("cold create longest sources", function() widget = cold.create({ w = 480, h = 272 }, {}) end)
budget("save longest sources", function() P.save(key, long) end)
local tool = loadScript("/WIDGETS/DLGDash/DLGSetup.lua")()
budget("standalone cold init", function() tool.init() end)
budget("standalone paint", function() tool.run(0) end)
tool.run(EVT_VIRTUAL_ENTER)
tool.run(EVT_VIRTUAL_NEXT)
tool.run(EVT_VIRTUAL_EXIT)
for i = 1, 900 do sim.clock = sim.clock + 10; assert(tool.run(0) == 0, "standalone closed during idle") end
eq(tool.run(EVT_VIRTUAL_EXIT), 2, "standalone exits only on request")
cold.refresh(widget, 0, nil)
cold.refresh(widget, EVT_VIRTUAL_ENTER, nil)
assert(widget.editor)
sim.filename = "second.yml"; sim.clock = sim.clock + 5; cold.background(widget)
eq(widget.key, "v16_second_2Eyml"); eq(widget.state.config.resetSource, "")
eq(widget.editor, nil, "model change never carries settings draft")
print("PASS V16: " .. count .. " assertions; experimental layout and API simulation, not hardware acceptance")
