-- B&W API simulation deliberately provides no Bitmap, color or sizeText APIs.
local radio, legacy, minor
radio, LCD_W, legacy, minor = __radio()
LCD_H, DBLSIZE, FIXEDWIDTH, SOLID, PLAY_BACKGROUND = 64, 1024, 16, 0, 4
UNIT_VOLTS, UNIT_CELLS, UNIT_METERS, UNIT_FEET = 1, 15, 9, 10
UNIT_METERS_PER_SECOND, UNIT_FEET_PER_SECOND = 5, 6
EVT_VIRTUAL_NEXT, EVT_VIRTUAL_PREV, EVT_VIRTUAL_ENTER, EVT_VIRTUAL_EXIT = 10, 11, 12, 13
EVT_VIRTUAL_INC, EVT_VIRTUAL_DEC = 10, 11
EVT_VIRTUAL_NEXT_PAGE, EVT_VIRTUAL_PREV_PAGE = 14, 15
debug.setmetatable("", nil)
-- EdgeTX's reduced Lua environment need not expose the desktop _G table.
_G = nil
table = nil
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
function getVersion() return "2." .. minor .. ".0", radio, 2, minor, 0, "EdgeTX" end
function getFlightMode(index) index = index or sim.mode; return index, index == 2 and "Zoom" or "Cruise" end
function getSourceValue(value)
  local f = getFieldInfo(value)
  if f then return sim[f.key], not f.unit or sim.current, not f.unit or sim.fresh end
  return nil, false, false
end
local sensorValue = getSourceValue
function getValue(value)
  if type(value) == "string" and string.match(value, "^ch%d+$") then return sim.output * 10.24 end
  return sensorValue(value)
end
function getRSSI() return sim.current and 85 or 0 end
function getOutputValue(index) sim.outputReads = (sim.outputReads or 0) + 1; return sim.output * 10.24 end
if legacy then getSourceValue, getOutputValue = nil, nil end
function playTone(...) sim.tones = sim.tones + 1; sim.lastTone = { ... } end
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
eq(_G, nil, "Radio tests must not rely on desktop globals")
eq(table, nil, "Small-radio builds can omit the table library")
local function budget(label, fn)
  local n = 0
  debug.sethook(function() n = n + 100 end, "", 100); fn(); debug.sethook()
  print(radio .. " instructions " .. label .. ": " .. n); assert(n < 20000, label)
end
local P = loadScript("/WIDGETS/DLGDash/profile.lua")()
eq(P.api.legacy, legacy)
eq(P.api.mixedOutputs, legacy)
eq(P.api.toneVolume, minor >= 10)
local C = loadScript("/WIDGETS/DLGDash/core.lua")()
local D = loadScript("/WIDGETS/DLGDash/mono-ui.lua")()
__begin("font-sentinel"); D.text("1.i", 0, 0, 30, false, false); __fontRegression(); __end()
local Settings = loadScript("/WIDGETS/DLGDash/settings.lua")(P, D)
local cfg, key = P.defaults(), P.identity()
eq(cfg.toneSource, ""); eq(cfg.resetSource, ""); eq(cfg.launchMode, 2)
eq(key, radio .. "_demo_2Eyml"); eq(P.save(key, cfg), true)
do
  local testKey, draft = key .. "_savecheck", P.copy(cfg)
  for name, rule in pairs(P.fields) do
    if type(rule[1]) == "string" then draft[name] = string.rep("S", 32) end
  end
  budget("save longest sources without table", function() eq(P.save(testKey, draft), true) end)
  local loaded, revision = P.load(testKey)
  eq(revision, 1); eq(loaded.voltage, draft.voltage)
  local firstStamp = P.stamp(testKey)
  draft.timer = 2
  budget("resave longest sources without table", function() eq(P.save(testKey, draft), true) end)
  eq(P.load(testKey).timer, 2); eq(P.stamp(testKey) == firstStamp, false)
  storage[P.directory .. testKey .. ".b"] = "incomplete"
  eq(P.load(testKey).timer, 1, "Corrupt newer slot must retain previous settings")
  local write = io.write
  io.write = function() error("SD removed") end
  eq(P.save(testKey, draft), false)
  io.write = write
  eq(P.load(testKey).timer, 1, "Failed save must retain previous settings")
end
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
eq(#sim.lastTone, P.api.toneVolume and 6 or 5)
eq(sim.lastTone[6], P.api.toneVolume and 5 or nil)
cfg.toneVolume = 0; tick(100); eq(#sim.lastTone, 5)
local tonesBeforeMute = sim.tones
cfg.toneVolume = -1; tick(100); eq(sim.tones, tonesBeforeMute)
cfg.toneVolume = 5
local saved, closed = false, false
local e = Settings.new(key, cfg, function() saved = true end, function() closed = true end)
do
  local loader, loaded = loadScript, {}
  loadScript = function(path) loaded[#loaded + 1] = path; return loader(path) end
  eq(e.pages[1].title, "BATTERY"); eq(#loaded, 1)
  eq(loaded[1], "/WIDGETS/DLGDash/pages/1.lua")
  eq(e.pages[1].title, "BATTERY"); eq(#loaded, 1, "Cache current page")
  eq(e.pages[2].title, "TELEMETRY"); eq(#loaded, 2)
  eq(loaded[2], "/WIDGETS/DLGDash/pages/2.lua")
  loadScript = loader
end
local inc, dec, nextPage, prevPage = EVT_VIRTUAL_INC, EVT_VIRTUAL_DEC, EVT_VIRTUAL_NEXT_PAGE, EVT_VIRTUAL_PREV_PAGE
EVT_VIRTUAL_INC, EVT_VIRTUAL_DEC, EVT_VIRTUAL_NEXT_PAGE, EVT_VIRTUAL_PREV_PAGE = nil, nil, nil, nil
Settings.run(e, nil); eq(e.focus, 1); eq(e.page, 1); eq(e.picker, nil)
Settings.run(e, 0); eq(e.focus, 1)
Settings.run(e, EVT_VIRTUAL_NEXT); eq(e.focus, 2)
Settings.run(e, EVT_VIRTUAL_PREV); eq(e.focus, 1)
EVT_VIRTUAL_INC, EVT_VIRTUAL_DEC, EVT_VIRTUAL_NEXT_PAGE, EVT_VIRTUAL_PREV_PAGE = inc, dec, nextPage, prevPage
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
e.page, e.focus, e.message = 9, 1, nil
e.config.language = 0
Settings.run(e, EVT_VIRTUAL_ENTER); e.picker.index = 2; Settings.run(e, EVT_VIRTUAL_ENTER)
eq(e.config.language, 1)
e.page, e.focus = 8, 1
Settings.run(e, EVT_VIRTUAL_ENTER); e.picker.index = P.api.toneVolume and 3 or 2; Settings.run(e, EVT_VIRTUAL_ENTER)
eq(e.config.toneVolume, P.api.toneVolume and 1 or -1)
e.focus = #e.pages[8].fields + 3
budget("save settings", function() Settings.run(e, EVT_VIRTUAL_ENTER) end)
eq(saved, true); eq(P.load(key).toneVolume, P.api.toneVolume and 1 or -1); eq(P.load(key).language, 1)
Settings.run(e, EVT_VIRTUAL_EXIT); eq(closed, true)
local entryLoader, entryState = loadScript, nil
loadScript = function(path)
  local chunk = entryLoader(path)
  if path ~= "/WIDGETS/DLGDash/core.lua" then return chunk end
  return function()
    local engine = chunk()
    local create = engine.new
    engine.new = function(...)
      local result = create(...)
      entryState = entryState or result
      return result
    end
    return engine
  end
end
local api = loadScript("/WIDGETS/DLGDash/DLG.lua")()
budget("cold init", api.init)
sim.clock = sim.clock + 5
budget("background", api.background)
__begin("entry"); budget("entry draw", function() api.run(0) end); __end()
budget("open settings", function() api.run(EVT_VIRTUAL_ENTER) end)
budget("load settings", function() api.run(0) end)
__begin("entry-settings"); api.run(0); __end()
local readsBeforeMenu, tonesBeforeMenu = sim.outputReads, sim.tones
for i = 1, 150 do sim.clock = sim.clock + 100; api.background() end
eq(sim.outputReads, readsBeforeMenu, "Menu must release and suspend flight modules")
eq(sim.tones, tonesBeforeMenu, "Menu must stay muted")
api.run(EVT_VIRTUAL_ENTER); api.run(EVT_VIRTUAL_PREV); api.run(EVT_VIRTUAL_ENTER)
for i = 1, 5 do api.run(EVT_VIRTUAL_NEXT) end
api.run(EVT_VIRTUAL_ENTER)
eq(P.load(key).voltage, "", "Telemetry menu save must reach storage")
api.run(EVT_VIRTUAL_EXIT)
budget("restore dashboard", function() api.run(0) end)
sim.clock = sim.clock + 5
__begin("entry-restored"); api.run(0); __end()
if not legacy then eq(sim.outputReads > readsBeforeMenu, true, "Flight sampling must resume") end
local history = {}
for i = 1, 120 do
  local altitude = i == 1 and 0 or -i / 10
  if i == 2 then altitude = nil end
  history[i] = { tick = sim.clock - 120 + i, altitude = altitude, gap = i % 7 == 0 or nil }
end
entryState.history, entryState.launchHeight = history, 32.1
local expected = {}
for i, p in ipairs(history) do expected[i] = { tick = p.tick, altitude = p.altitude, gap = p.gap } end
budget("pack full history", function() api.run(EVT_VIRTUAL_ENTER) end)
eq(#history, 360)
api.run(0); api.run(0); api.run(EVT_VIRTUAL_EXIT)
budget("unpack full history", function() api.run(0) end)
eq(#entryState.history, 120); eq(entryState.launchHeight, 32.1)
for i, p in ipairs(expected) do
  eq(entryState.history[i].tick, p.tick)
  eq(entryState.history[i].altitude, p.altitude)
  eq(entryState.history[i].gap, p.gap)
end
for i = 1, 3 do
  api.run(EVT_VIRTUAL_ENTER); api.run(0); api.run(0)
  api.run(EVT_VIRTUAL_EXIT); api.run(0)
  sim.clock = sim.clock + 5; api.run(0)
end
api.run(EVT_VIRTUAL_ENTER); api.run(0)
sim.filename = "second.yml"; api.background(); eq(P.load(P.identity()), nil)
loadScript = entryLoader
local tool = loadScript("/WIDGETS/DLGDash/DLGSetup.lua")()
budget("standalone init", tool.init)
__begin("standalone"); eq(tool.run(0), 0); __end()
eq(tool.run(EVT_VIRTUAL_EXIT), 2)
local modernSource, modernOutput, modernSources, savedValue = getSourceValue, getOutputValue, sources, getValue
getSourceValue, getOutputValue, sources, getValue = nil, nil, nil, nil
local originalLoader = loadScript
local legacyTool = originalLoader("/WIDGETS/DLGDash/DLGSetup.lua")()
loadScript = function() error("Old firmware must not load any runtime modules") end
legacyTool.init()
__begin("old-firmware"); eq(legacyTool.run(0), 0); __end()
eq(legacyTool.run(EVT_VIRTUAL_EXIT), 2)
loadScript = originalLoader
getSourceValue, getOutputValue, sources, getValue = modernSource, modernOutput, modernSources, savedValue
print("PASS " .. radio .. ": " .. count .. " assertions; simulation only, hardware validation pending")
