-- B&W API simulation deliberately provides no Bitmap, color or sizeText APIs.
local radio
radio, LCD_W = __radio()
LCD_H, DBLSIZE, FIXEDWIDTH, SOLID, PLAY_BACKGROUND = 64, 1024, 16, 0, 4
UNIT_VOLTS, UNIT_CELLS, UNIT_METERS, UNIT_FEET = 1, 15, 9, 10
UNIT_METERS_PER_SECOND, UNIT_FEET_PER_SECOND = 5, 6
EVT_VIRTUAL_NEXT, EVT_VIRTUAL_PREV, EVT_VIRTUAL_ENTER, EVT_VIRTUAL_EXIT = 10, 11, 12, 13
EVT_VIRTUAL_INC, EVT_VIRTUAL_DEC = 10, 11
EVT_VIRTUAL_NEXT_PAGE, EVT_VIRTUAL_PREV_PAGE = 14, 15
debug.setmetatable("", nil)
local sim = { clock = 0, filename = "demo.yml", current = true, fresh = true, altitude = 12.3,
  voltage = 8.1, speed = 1.2, mode = 0, timer = 128, switch = -1024, output = 0, tones = 0 }
lcd = { clear = __clear, drawText = __text, drawLine = __line, drawRectangle = __rect, drawPixmap = __pixmap }
local sensors = {
  { id = 301, name = "RxBt", unit = UNIT_VOLTS, key = "voltage" },
  { id = 304, name = "Alt", unit = UNIT_METERS, key = "altitude" },
  { id = 307, name = "VSpd", unit = UNIT_METERS_PER_SECOND, key = "speed" },
  { id = 341, name = "SF", key = "switch" }, { id = 342, name = "SE", key = "switch" }
}
function getFieldInfo(value)
  for _, f in ipairs(sensors) do
    if value == f.id or type(value) == "string" and string.lower(value) == string.lower(f.name) then return f end
  end
end
function getTime() return sim.clock end
function getVersion() return "2.11.3", radio, 2, 11, 3, "EdgeTX" end
function getFlightMode(index) index = index or sim.mode; return index, index == 2 and "Zoom" or "Cruise" end
function getSourceValue(value)
  local f = getFieldInfo(value)
  if f then return sim[f.key], not f.unit or sim.current, not f.unit or sim.fresh end
  return nil, false, false
end
function getValue(value) return getSourceValue(value) end
function getOutputValue(index) return sim.output * 10.24 end
function playTone(...) sim.tones = sim.tones + 1 end
function sources()
  local i = 0
  return function() i = i + 1; local f = sensors[i]; if f then return f.id, f.name end end
end
model = setmetatable({}, { __index = function(_, key) error("Unexpected model API " .. key) end })
function model.getInfo() return { name = "DLG Demo", filename = sim.filename } end
function model.getTimer() return { value = sim.timer } end
function model.getOutput(index) return { name = "Servo " .. (index + 1) } end
local storage, stamp = {}, 0
io = {}
function io.open(path, mode) if mode == "r" and not storage[path] then return nil end; return { path = path } end
function io.read(f, size) return string.sub(storage[f.path] or "", 1, size) end
function io.write(f, text) storage[f.path] = text; stamp = stamp + 1 end
function io.close() end
function mkdir() end
function fstat(path) if storage[path] then return { size = #storage[path], time = { sec = stamp } } end end
local count = 0
local function eq(a, b, message) count = count + 1; assert(a == b, message or (tostring(a) .. " != " .. tostring(b))) end
local function budget(label, fn)
  local n = 0
  debug.sethook(function() n = n + 100 end, "", 100); fn(); debug.sethook()
  print(radio .. " instructions " .. label .. ": " .. n); assert(n < 20000, label)
end
local P = loadScript("/WIDGETS/DLGDash/profile.lua")()
local C = loadScript("/WIDGETS/DLGDash/core.lua")()
local D = loadScript("/WIDGETS/DLGDash/mono-ui.lua")()
__begin("font-sentinel"); D.text("1.i", 0, 0, 30, false, false); __fontRegression(); __end()
local Settings = loadScript("/WIDGETS/DLGDash/settings.lua")(P, D)
local cfg, key = P.defaults(), P.identity()
eq(cfg.toneSource, ""); eq(cfg.resetSource, ""); eq(cfg.launchMode, 2)
eq(key, radio .. "_demo_2Eyml"); eq(P.save(key, cfg), true)
local s = C.new(cfg, P)
local function tick(dt) sim.clock = sim.clock + (dt or 5); C.update(s) end
tick(); eq(s.data.battery.voltage, 8.1); eq(s.data.battery.full, 8.4)
sim.fresh = false; tick(); eq(s.data.altitude, 12.3, "slow sample remains current")
for _, lang in ipairs({ 0, 1 }) do
  for _, countServos in ipairs({ 4, 6 }) do
    cfg.language, cfg.servos = lang, countServos
    for _, value in ipairs({ -150, -100, -99, 0, 99, 100, 150 }) do
      sim.output = value; tick()
      for i = 1, 120 do s.history[i] = { tick = s.now - (120 - i) * 75, altitude = 22 + 21 * math.sin(i / 19) } end
      s.launchHeight = 52.7
      for page = 1, 2 do
        __begin(radio .. "-" .. lang .. "-" .. countServos .. "-" .. value .. "-" .. page)
        D.dashboard(s, C, page); __end()
      end
    end
  end
end
for _, value in ipairs({ -3661, 359999, -359999 }) do
  sim.timer, sim.altitude = value, -12345.6; tick()
  __begin("extreme-" .. value); D.dashboard(s, C, 1); __end()
end
sim.current = false; tick(); __begin("lost"); D.dashboard(s, C, 1); __end(); eq(s.data.altitude, nil)
sim.current, sim.altitude, sim.timer = true, 23.4, 128
cfg.resetSource, cfg.toneSource = "SE", "SF"; tick(200)
sim.switch = 1024; tick(); eq(#s.history, 0); eq(s.graphReset, true)
__begin("clear-held"); D.dashboard(s, C, 1); __end()
for i = 1, 100 do tick() end; eq(#s.history, 0)
sim.switch = -1024; tick(); tick(50); eq(s.graphReset, false)
sim.mode = 2; tick(); sim.mode = 0; sim.altitude = 45.6; tick(); eq(s.launchHeight, 45.6)
cfg.toneVolume = 5; sim.switch = 1024; cfg.resetSource = ""; tick(200); tick(50); assert(sim.tones > 0)
local saved, closed = false, false
local e = Settings.new(key, cfg, function() saved = true end, function() closed = true end)
for _, lang in ipairs({ 0, 1 }) do
  e.config.language = lang
  for page, info in ipairs(e.pages) do
    e.page, e.focus = page, 1
    __begin("settings-" .. lang .. "-" .. page); Settings.run(e, 0); __end()
    for row in ipairs(info.fields) do
      e.focus = row
      __begin("row-" .. lang .. "-" .. page .. "-" .. row); Settings.run(e, 0); __end()
      Settings.run(e, EVT_VIRTUAL_ENTER); assert(e.picker)
      for _, index in ipairs({ 1, #e.picker.choices }) do
        e.picker.index = index
        __begin("picker-" .. lang .. "-" .. page .. "-" .. row .. "-" .. index); Settings.run(e, 0); __end()
      end
      Settings.run(e, EVT_VIRTUAL_EXIT)
    end
  end
end
e.page, e.focus, e.message = 8, 1, nil
Settings.run(e, EVT_VIRTUAL_ENTER); e.picker.index = 3; Settings.run(e, EVT_VIRTUAL_ENTER)
eq(e.config.toneVolume, 1)
e.focus = #e.pages[8].fields + 3
budget("save settings", function() Settings.run(e, EVT_VIRTUAL_ENTER) end)
eq(saved, true); eq(P.load(key).toneVolume, 1)
Settings.run(e, EVT_VIRTUAL_EXIT); eq(closed, true)
local api = loadScript("/WIDGETS/DLGDash/DLG.lua")()
budget("cold init", api.init)
sim.clock = sim.clock + 5
budget("background", api.background)
__begin("entry"); budget("entry draw", function() api.run(0) end); __end()
budget("open settings", function() api.run(EVT_VIRTUAL_ENTER) end)
__begin("entry-settings"); api.run(0); __end()
api.run(EVT_VIRTUAL_EXIT)
sim.filename = "second.yml"; api.background(); eq(P.load(P.identity()), nil)
local tool = loadScript("/WIDGETS/DLGDash/DLGSetup.lua")()
budget("standalone init", tool.init)
__begin("standalone"); eq(tool.run(0), 0); __end()
eq(tool.run(EVT_VIRTUAL_EXIT), 2)
print("PASS " .. radio .. ": " .. count .. " assertions; simulation only, hardware validation pending")
