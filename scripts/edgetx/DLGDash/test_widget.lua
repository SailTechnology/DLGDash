-- Run with: pnpm --dir tests test. Device APIs and SD writes are isolated mocks.
SOURCE, BOOL, VALUE, PLAY_BACKGROUND, SOLID = 1, 2, 3, 4, 0
STDSIZE, BOLD, TINSIZE, SMLSIZE, MIDSIZE, DBLSIZE, XXLSIZE = 0, 1, 2, 3, 4, 5, 6
UNIT_VOLTS, UNIT_CELLS, UNIT_METERS, UNIT_FEET = 1, 15, 9, 10
UNIT_METERS_PER_SECOND, UNIT_FEET_PER_SECOND = 5, 6
LCD_W, LCD_H = 320, 240
EVT_VIRTUAL_NEXT, EVT_VIRTUAL_PREV, EVT_VIRTUAL_ENTER, EVT_VIRTUAL_EXIT = 10, 11, 12, 13
EVT_VIRTUAL_INC, EVT_VIRTUAL_DEC = EVT_VIRTUAL_NEXT, EVT_VIRTUAL_PREV
EVT_VIRTUAL_NEXT_PAGE, EVT_VIRTUAL_PREV_PAGE = 14, 15
lcd = { RGB = __rgb, sizeText = __measure, drawText = __text, drawLine = __line, drawFilledRectangle = __rect, drawBitmapPattern = __mask, exitFullScreen = function() end }
Bitmap = { open = __bitmap, getSize = __bitmapSize, toMask = function(bitmap) return bitmap end }
local sim, count = {}, 0
local function eq(actual, expected, message)
  count = count + 1
  assert(actual == expected, (message or "assertion") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function near(actual, expected, message)
  count = count + 1
  if not actual or math.abs(actual - expected) >= 0.001 then
    error((message or "numeric mismatch") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end
-- PA01 firmware may build without LUA_ENABLE_STRLIB_MT. Keep the entire suite
-- in that environment, including cold start, profile I/O and long-name drawing.
debug.setmetatable("", nil)
eq(getmetatable(""), nil, "string metatable disabled")
local methodOK, methodError = pcall(function() return ("model09.yml"):gsub("%.", "_") end)
eq(methodOK, false, "negative control must reproduce the string indexing failure")
assert(string.find(methodError, "attempt to index a string value", 1, true))
local sensors = {
  { id = 301, name = "Alt", unit = UNIT_METERS, key = "altitude" },
  { id = 304, name = "VSpd", unit = UNIT_METERS_PER_SECOND, key = "vario" },
  { id = 307, name = "RxBt", unit = UNIT_VOLTS, key = "voltage" },
  { id = 308, name = "RxBt-", unit = UNIT_VOLTS, key = "voltageMin" },
  { id = 309, name = "RxBt+", unit = UNIT_VOLTS, key = "voltageMax" },
  { id = 310, name = "Cells", unit = UNIT_CELLS, key = "cells" },
  { id = 313, name = "AltFeet", unit = UNIT_FEET, key = "feet" },
  { id = 316, name = "SpeedFeet", unit = UNIT_FEET_PER_SECOND, key = "speedFeet" },
  { id = 319, name = "Bat", unit = 13, key = "badPercent" },
  { id = 341, name = "SE", key = "preset" },
  { id = 342, name = "SF", key = "switch" },
  { id = 348, name = "L03", key = "logical" }
}
local modeNames = { [0] = "Speed", "Preset", "Zoom", "Cruise", "C1", "C2", "Therml", "", "" }
function getFieldInfo(value)
  for _, sensor in ipairs(sensors) do
    if value == sensor.id or type(value) == "string" and string.lower(value) == string.lower(sensor.name) then return sensor end
  end
end
function sources()
  local index = 0
  return function()
    index = index + 1
    if sensors[index] then
      local sensor = sensors[index]
      local prefix = sim.nativeLabels and string.char(194, sensor.unit and 147 or 140) or ""
      return sensor.id, prefix .. sensor.name
    end
  end
end
function getSourceIndex(name)
  if sim.sourceOverrides and sim.sourceOverrides[name] then return sim.sourceOverrides[name] end
  for id, label in sources() do if label == name then return id end end
end
function getSourceName(id)
  for index, label in sources() do if index == id then return label end end
end
function getTime() return sim.clock end
function getVersion() return "2.11.3", sim.radio, 2, 11, 3, "EdgeTX" end
function getFlightMode(index) index = index or sim.mode; return index, modeNames[index] end
function getSourceValue(id)
  local sensor = getFieldInfo(id)
  if not sensor then return nil, false, false end
  if not sensor.unit then return sim[sensor.key], true, true end
  if id == "RxBt" and sim.namedVoltage then return sim.namedVoltage, sim.link, sim.fresh end
  return sim[sensor.key], sim.link and sim.current[sensor.key] ~= false, sim.fresh and sim.freshness[sensor.key] ~= false
end
function getValue(id)
  local value, current = getSourceValue(id)
  return current and value or 0
end
function getOutputValue(index) return sim.outputs[index + 1] end
function playTone(freq, duration, pause, flags, increment, volume)
  assert(freq == math.floor(freq) and duration == math.floor(duration), "EdgeTX tone parameters must be integers")
  assert(volume == nil or volume >= 1 and volume <= 5, "zero is not the native mute/default volume")
  sim.tones[#sim.tones + 1] = { freq = freq, duration = duration, pause = pause,
    flags = flags, increment = increment, volume = volume, tick = sim.clock }
end
model = setmetatable({}, { __index = function(_, key) error("Unexpected model mutation/API: " .. key) end })
function model.getInfo() return { name = "DLG Demo", filename = sim.filename } end
function model.getTimer(index) return { value = sim.timer - index, start = 180 } end
function model.getOutput(index) return { name = ({ "LA", "RA", "E", "R", "LF", "RF" })[index + 1] or "" } end
local storage, denyWrite, truncateWrite, writeSequence, stamps = {}, false, false, 0, {}
io = {}
function io.open(path, mode)
  if mode == "r" and storage[path] == nil or mode == "w" and denyWrite then return nil end
  if mode == "w" then storage[path] = "" end
  return { path = path, mode = mode, position = 1 }
end
function io.read(file, length)
  assert(file.mode == "r")
  local value = string.sub(storage[file.path], file.position, file.position + length - 1)
  file.position = file.position + #value
  return value
end
function io.write(file, text)
  assert(file.mode == "w"); storage[file.path] = truncateWrite and string.sub(text, 1, 20) or text
  writeSequence = writeSequence + 1; stamps[file.path] = writeSequence
  return file
end
function io.close(file) file.closed = true end
function mkdir() return 0 end
function fstat(path)
  if storage[path] then return { size = #storage[path], time = { year = 2026, mon = 9, day = 6, hour = 20, min = 0, sec = stamps[path] or 0 } } end
end
local function reset()
  sim = { clock = 0, altitude = 0, vario = 0, voltage = 7.4, badPercent = 0, timer = 128, mode = 0,
    link = true, fresh = true, current = {}, freshness = {}, switch = -1024, preset = -1024, logical = 0, radio = "pa01", filename = "model47.yml",
    outputs = { 215, 276, -92, 0, 512, -512 }, tones = {} }
end
reset()
local P, C = loadScript("/WIDGETS/DLGDash/profile.lua")(), loadScript("/WIDGETS/DLGDash/core.lua")()
eq(P.identity(), "pa01_model47_2Eyml", "cold-start profile filename without string methods")
local D = loadScript("/WIDGETS/DLGDash/draw.lua")()
local Settings = loadScript("/WIDGETS/DLGDash/settings.lua")(P, D)
local function state(overrides)
  reset()
  local config = P.defaults()
  for k, v in pairs(overrides or {}) do config[k] = v end
  return C.new(config, P)
end
local function step(s, ticks)
  for _ = 1, (ticks or 5) / 5 do sim.clock = sim.clock + 5; C.update(s) end
end

-- Pack voltage: never consumes the bogus zero-valued percentage sensor.
local s = state()
step(s); near(s.data.battery.voltage, 7.4); near(s.data.battery.full, 8.4); eq(s.data.battery.cells, 2)
eq(s.data.battery.label, "2S AUTO?", "low-voltage chemistry must not be claimed certain")
sim.voltage = 3.9; step(s); eq(s.data.battery.cells, 1); near(s.data.battery.full, 4.2)
sim.voltage = 4.34; step(s, 15); near(s.data.battery.full, 4.35); eq(s.data.battery.label, "1S HV")
sim.voltage = 4.05; step(s); eq(s.data.battery.label, "1S HV", "HV remembered during one pack session")
sim.link = false; step(s, 250); eq(s.data.battery.voltage, nil)
sim.link = true; sim.voltage = 4.1; step(s); near(s.data.battery.full, 4.2, "HV not inherited by replacement pack")
sim.voltage = 8.68; step(s, 15); near(s.data.battery.full, 8.7)
sim.voltage = 5.2; step(s); eq(s.data.battery.full, nil, "regulated voltage must request pack setup")
s = state({ cells = 1, chemistry = 2 }); sim.voltage = 3.8; step(s); near(s.data.battery.full, 4.35)
s = state({ voltage = "Cells" }); sim.cells = { 3.8, 3.9 }; step(s); near(s.data.battery.voltage, 7.7); eq(s.data.battery.cells, 2)
sim.cells = { 0, 3.9 }; step(s); eq(s.data.battery.voltage, nil, "invalid cell array")
s = state({ voltage = "unknown" }); step(s); eq(s.data.battery.voltage, nil)
s = state(); sim.voltage = 8.14; sim.voltageMax = 8.5; step(s)
sim.freshness.voltage = false
for i = 1, 40 do step(s); near(s.data.battery.voltage, 8.14, "current battery remains visible between packets") end
sim.current.voltage = false; step(s); eq(s.data.battery.voltage, nil, "lost battery is never reported live")
sim.current.voltage = true; sim.voltage = 8.12; step(s); near(s.data.battery.voltage, 8.12, "no filtering or voltage offset")
s = state({ voltage = string.char(194, 147) .. "RxBt" }); sim.nativeLabels = true; sim.voltage = 8.14; sim.voltageMax = 8.5
step(s); near(s.data.battery.voltage, 8.14, "actual PA01 icon-prefixed source resolves to current RxBt")

-- Launch result is a mode EXIT, not L3 or a timer decrement.
s = state(); step(s); eq(s.config.launchMode, 2); eq(s.launchHeight, nil)
sim.mode = 2; sim.altitude = 20; step(s); eq(s.launchState, "tracking")
sim.altitude = 50; step(s); sim.altitude = 45; sim.mode = 3; step(s); near(s.launchHeight, 45)
sim.timer = 120; sim.altitude = 40; step(s); near(s.launchHeight, 45, "countdown must not reset result")
s = state({ delay = 15 }); step(s); sim.mode = 2; sim.altitude = 20; step(s)
sim.mode = 3; sim.altitude = 40; step(s); eq(s.launchState, "delay")
step(s, 145); eq(s.launchHeight, nil); sim.altitude = 52; step(s); near(s.launchHeight, 52)
sim.altitude = 60; step(s); near(s.launchHeight, 52, "result must freeze")
s = state({ delay = 5, settle = 1 }); step(s); sim.mode = 2; sim.altitude = 45; step(s)
sim.mode = 3; sim.altitude = 55; step(s); sim.altitude = 51; step(s, 50); near(s.launchHeight, 55, "include exit sample in peak")
s = state({ delay = 10 }); step(s); sim.mode = 2; sim.altitude = 20; step(s); sim.mode = 3; step(s)
step(s, 40); sim.mode = 2; sim.altitude = 30; step(s); step(s, 100); eq(s.launchState, "tracking")
sim.mode = 3; sim.altitude = 48; step(s); step(s, 100); near(s.launchHeight, 48, "re-entry must rearm delay")
s = state({ delay = 5 }); step(s); sim.mode = 2; step(s); sim.mode = 3; step(s); sim.link = false; step(s, 50)
eq(s.launchState, "lost"); sim.link = true; sim.altitude = 200; step(s); eq(s.launchHeight, nil, "no late fix after telemetry loss")
s = state({ launchMode = 3 }); step(s); sim.mode = 2; step(s); sim.mode = 0; step(s); eq(s.launchHeight, nil)
sim.mode = 3; step(s); sim.mode = 0; sim.altitude = 12; step(s); near(s.launchHeight, 12)
s = state({ settle = 1 }); step(s); sim.mode = 2; sim.altitude = 40; step(s)
sim.link = false; step(s); sim.link = true; sim.mode = 3; sim.altitude = 30; step(s)
eq(s.launchState, "lost", "a partially observed peak must not be reported as complete")

-- Six mapped FINAL outputs, including disabled channels and imperial telemetry.
s = state({ servos = 6, ch1 = 6, ch6 = 1, ch3 = 0 }); step(s)
near(s.data.channels[1], -50); near(s.data.channels[6], 215 / 10.24); eq(s.data.channels[3], nil)
s = state({ altitude = "AltFeet", vario = "SpeedFeet" }); sim.feet = 100; sim.speedFeet = 10; step(s)
near(s.data.altitude, 30.48); near(s.data.vario, 3.048)
s = state({ vario = "" }); step(s)
for i = 1, 20 do sim.altitude = i / 10; step(s) end
assert(s.data.vario and s.data.vario > 1, "20Hz altitude derivative must not starve")
sim.link = false; step(s); eq(s.data.vario, nil); sim.link = true; sim.altitude = 200; step(s); eq(s.data.vario, nil, "no reconnect derivative spike")
sim.fresh = false; step(s); near(s.data.altitude, 200, "current altitude survives the short freshness window")
eq(s.data.vario, nil, "held reconnect sample cannot create a derivative")
sim.current.altitude = false; step(s); eq(s.data.altitude, nil); eq(s.data.vario, nil)

-- Slow, still-current telemetry never flashes NO ALT or inserts false gaps.
for _, interval in ipairs({ 50, 100, 200, 300 }) do
  s = state({ window = 30, period = 10 }); step(s)
  for tick = 5, interval * 5, 5 do
    local phase = tick % interval
    sim.fresh = phase < 30
    if phase == 0 then sim.altitude = sim.altitude + 2; sim.vario = 200 / interval end
    step(s)
    assert(s.data.altitude ~= nil and s.data.vario ~= nil, "slow current packets must remain visible")
  end
  for i = 2, #s.history do assert(s.history[i].altitude ~= nil and not s.history[i].gap, "no false gap between packets") end
  near(s.data.altitude, 10); near(s.data.vario, 200 / interval)
end
s = state({ language = 1, period = 10 }); step(s)
for tick = 5, 3000, 5 do
  local phase = tick % 100
  sim.fresh = phase < 30
  if phase == 0 then sim.altitude = 20 + 8 * math.sin(tick / 500); sim.vario = 1 end
  step(s)
end
__begin("slow-altitude-new-packet"); D.dashboard(s, C, { w = 320, h = 240 }, true); __altStatus(false); __end()
sim.fresh = false; step(s, 80)
__begin("slow-altitude-held-packet"); D.dashboard(s, C, { w = 320, h = 240 }, true); __altStatus(false); __end()
sim.current.altitude, sim.current.vario = false, false; step(s)
eq(s.data.altitude, nil); eq(s.data.vario, nil); eq(s.graphAltitude, nil)
__begin("slow-altitude-lost"); D.dashboard(s, C, { w = 320, h = 240 }, true); __altStatus(true); __end()
sim.current.altitude, sim.current.vario, sim.altitude = true, true, 70; step(s)
near(s.graphAltitude, 70, "reconnect starts at the real sample, not a blend across missing telemetry")
__begin("slow-altitude-recovered"); D.dashboard(s, C, { w = 320, h = 240 }, true); __altStatus(false); __end()
step(s, 100); eq(s.history[#s.history].gap, true)

-- Curve filtering is bounded and independent of raw readouts and launch results.
s = state({ smoothing = 5, settle = 1, window = 30, period = 10 }); sim.altitude = 10; step(s)
sim.mode = 2; sim.altitude = 50; step(s)
near(s.data.altitude, 50); assert(s.graphAltitude > 10 and s.graphAltitude < 50)
local beforeSmooth = s.graphAltitude
sim.fresh = false; sim.mode = 3; step(s)
near(s.launchHeight, 50, "raw peak survives normal inter-packet freshness gaps")
for _ = 1, 40 do
  step(s)
  assert(s.graphAltitude >= beforeSmooth and s.graphAltitude <= 50, "filter must not overshoot")
  beforeSmooth = s.graphAltitude
end
assert(s.graphAltitude > 49); near(s.launchHeight, 50)
sim.altitude = -10
for _ = 1, 20 do
  step(s)
  assert(s.graphAltitude <= beforeSmooth and s.graphAltitude >= -10, "descent filter must not overshoot")
  beforeSmooth = s.graphAltitude
end
s = state({ smoothing = 0 }); step(s); sim.altitude = 50; step(s)
near(s.graphAltitude, 50, "filter off preserves raw trace")
s = state({ smoothing = 30 }); step(s); sim.altitude = 50; step(s)
assert(s.graphAltitude < 1, "stronger smoothing slows graph only")
sim.clock = sim.clock + 150; sim.altitude = 100; C.update(s)
near(s.graphAltitude, 100, "script suspension must reset filter continuity")
s = state({ altitude = "AltFeet" }); sim.feet = 100; step(s); near(s.graphAltitude, 30.48)

-- Derived vario uses sensor update intervals, not redraw intervals.
for _, interval in ipairs({ 50, 100, 200, 300 }) do
  s = state({ vario = "" }); step(s)
  for tick = 5, interval * 4, 5 do
    local phase = tick % interval
    sim.fresh = phase < 30
    if phase == 0 then sim.altitude = sim.altitude + interval * 0.03 end
    step(s)
    assert(not s.data.vario or math.abs(s.data.vario) <= 3.001, "held altitude must not cause artificial vario spikes")
  end
  near(s.data.vario, 3)
  sim.fresh = false; step(s, interval)
  near(s.data.vario, 3, "hold derived speed through a normal slow packet interval")
  step(s, interval * 2 + 100); near(s.data.vario, 0, "unchanging observations must not beep indefinitely")
end

-- Timestamped history bounds and telemetry gaps.
s = state({ window = 600, period = 10 }); step(s, 65000)
assert(#s.history <= 121); eq(s.effectivePeriod, 500)
assert(C.elapsed(s.now, s.history[1].tick) <= 60000)
sim.link = false; step(s, 10); sim.link = true; step(s, 500); eq(s.history[#s.history].gap, true)
near(C.elapsed(3, 2147483640), 11)

-- Preset clears once on press, stays empty while held, and starts a new trace.
s = state({ vario = "" }); step(s, 500); assert(#s.history > 1)
s.launchHeight = 42
sim.preset = 1024; step(s); eq(#s.history, 0); eq(s.graphReset, true)
eq(s.graphAltitude, nil, "Preset also clears filter memory")
local cleared = s.history
step(s, 100); eq(s.history, cleared, "holding Preset must not repeatedly allocate/reset history"); eq(#s.history, 0)
sim.link = false; step(s); eq(s.data.vario, nil)
__begin("pa01-preset-held-no-telemetry"); D.dashboard(s, C, { w = 320, h = 240 }, false); __end()
sim.preset = -1024; step(s); step(s, 45); eq(#s.history, 0)
sim.link = true; sim.altitude = 200; step(s); eq(#s.history, 1); eq(s.data.vario, nil, "native reset causes no derivative spike")
near(s.history[1].altitude, 200, "Preset release does not blend with the previous flight")
near(s.launchHeight, 42, "graph reset does not alter settled launch result")
step(s, 100); sim.preset = 1024; step(s); eq(#s.history, 0, "second press clears the new flight")
s = state({ resetSource = "", resetPosition = 1 }); sim.preset = 1024; step(s, 500); assert(#s.history > 1)
s = state({ resetSource = "L03", resetPosition = 1 }); step(s, 500); sim.logical = 1024; step(s); eq(#s.history, 0)
s = state({ resetPosition = -1 }); sim.preset = 1024; step(s, 500); sim.preset = -1024; step(s); eq(#s.history, 0)

-- Audio distinguishability and safe hold/toggle behavior.
s = state(); sim.switch = 1024; sim.vario = 2; step(s, 100)
assert(#sim.tones > 0); assert(sim.tones[#sim.tones].freq >= 760)
sim.vario = -2; step(s, 100); assert(sim.tones[#sim.tones].freq <= 360)
sim.fresh = false
local slowTones = #sim.tones; step(s, 100)
assert(#sim.tones > slowTones, "current slow vario packets must not chop the audio")
sim.current.altitude, sim.current.vario = false, false
slowTones = #sim.tones; step(s, 100); eq(#sim.tones, slowTones, "expired sensors stop audio even while battery telemetry remains linked")
sim.current.altitude, sim.current.vario, sim.fresh = true, true, true
local tones = #sim.tones; sim.switch = -1024; step(s, 100); eq(#sim.tones, tones)
sim.switch = 1024; sim.link = false; step(s, 100); eq(#sim.tones, tones)
s = state({ toneMode = 1 }); sim.switch = 1024; sim.vario = 2; step(s, 100); eq(s.toneActive, false, "startup pressed is not a toggle edge")
sim.switch = -1024; step(s); sim.switch = 1024; step(s); eq(s.toneActive, true)
step(s, 100); sim.switch = -1024; step(s); sim.switch = 1024; step(s); eq(s.toneActive, false)
s = state({ toneSource = "L03" }); sim.logical = 1024; step(s); eq(s.toneActive, true)

-- Per-model tone controls preserve defaults and never alter radio/alert volume.
s = state(); sim.switch = 1024; sim.vario = 2; step(s)
eq(sim.tones[1].freq, 1180); eq(sim.tones[1].duration, 55); eq(sim.tones[1].volume, nil)
sim.vario = -2; step(s, 100)
eq(sim.tones[#sim.tones].freq, 300); eq(sim.tones[#sim.tones].duration, 190)
for volume = 1, 5 do
  s = state({ toneVolume = volume, climbTone = 1100, sinkTone = 460 })
  sim.switch = 1024; sim.vario = 2; step(s)
  eq(sim.tones[1].freq, 1560); eq(sim.tones[1].volume, volume)
  eq(sim.tones[1].flags, PLAY_BACKGROUND); eq(sim.tones[1].increment, 0)
  sim.vario = -2; step(s, 100)
  eq(sim.tones[#sim.tones].freq, 370); eq(sim.tones[#sim.tones].volume, volume)
end
for _, speed in ipairs({ -100, -2, -0.3, 0, 0.3, 2, 100 }) do
  for _, rate in ipairs({ 60, 100, 160 }) do
    s = state({ toneVolume = 5, climbTone = 600, sinkTone = 550, toneRate = rate })
    sim.switch = 1024; sim.vario = speed; step(s, 200)
    if speed == 0 then eq(#sim.tones, 0, "deadband stays quiet") end
    for i, tone in ipairs(sim.tones) do
      assert(speed > 0 and tone.freq >= 640 or speed < 0 and tone.freq <= 520, "up/down pitch ranges stay distinguishable")
      assert(tone.freq >= 150 and tone.freq <= 2580)
      if i > 1 then assert((tone.tick - sim.tones[i - 1].tick) * 10 >= tone.duration + tone.pause, "cadence must allow each tone to finish") end
    end
  end
end
local cadenceCounts = {}
for _, rate in ipairs({ 60, 100, 160 }) do
  s = state({ toneRate = rate }); sim.switch = 1024; sim.vario = 2; step(s, 200)
  cadenceCounts[#cadenceCounts + 1] = #sim.tones
end
assert(cadenceCounts[1] < cadenceCounts[2] and cadenceCounts[2] < cadenceCounts[3], "slow/normal/fast cadence changes actual beep rate")
s = state({ toneVolume = -1 }); sim.switch = 1024; sim.vario = 2; step(s, 100)
eq(s.toneActive, true); eq(#sim.tones, 0, "mute is separate from switch state")
__begin("pa01-audio-muted"); D.dashboard(s, C, { w = 320, h = 240 }, true); __end()
s = state({ toneVolume = 5 }); sim.switch = 1024; sim.vario = 2; s.muted = true; step(s, 100)
eq(#sim.tones, 0, "settings editing remains quiet")
s.muted = false; step(s, 100); assert(#sim.tones > 0)
local beforeLoss = #sim.tones; sim.link = false; step(s, 100); eq(#sim.tones, beforeLoss)
sim.link = true; sim.preset = 1024; step(s, 100); eq(#sim.tones, beforeLoss, "Preset suppresses even maximum-volume audio")

-- Independent profiles, checksums, interrupted writes, and no model mutations.
reset()
local key = P.identity()
local config = P.defaults()
eq(P.save(key, config), true); local loaded, revision = P.load(key); eq(revision, 1); eq(loaded.servos, 4)
config.servos = 6; eq(P.save(key, config), true); loaded, revision = P.load(key); eq(revision, 2); eq(loaded.servos, 6)
truncateWrite = true; config.timer = 3; eq(P.save(key, config), false); loaded, revision = P.load(key); eq(revision, 2); eq(loaded.timer, 1); truncateWrite = false
denyWrite = true; eq(P.save(key, config), false); denyWrite = false
sim.filename = "model48.yml"; local other = P.identity(); eq(P.load(other), nil); config.ch1 = 8; P.save(other, config)
eq(P.load(key).ch1, 1, "models with the same display name must not share settings")
sim.radio = "other-radio"; eq(P.load(P.identity()), nil)
eq(P.decode(P.encode(config, other, 1) .. "junk", other), nil)
local invalid = P.copy(config); invalid.servos = 5; eq(P.validate(invalid), false)
invalid = P.copy(config); invalid.smoothing = 31; eq(P.validate(invalid), false)
for k, rule in pairs({ toneVolume = P.fields.toneVolume, climbTone = P.fields.climbTone,
  sinkTone = P.fields.sinkTone, toneRate = P.fields.toneRate }) do
  invalid = P.copy(config); invalid[k] = rule[2] - 1; eq(P.validate(invalid), false)
  invalid[k] = rule[3] + 1; eq(P.validate(invalid), false)
end
eq(#P.sourceList("voltage"), 3, "percentage and min/max sensors excluded from live voltage choices")
local migrated, migratedRevision = P.decode(__fixture("sample-v2.profile"), "pa01_demo_2Eyml")
eq(migratedRevision, 3); eq(migrated.servos, 6); eq(migrated.delay, 5); eq(migrated.launchMode, 2)
eq(migrated.voltage, string.char(194, 147) .. "RxBt"); eq(migrated.resetSource, "SE"); eq(migrated.language, 0)
eq(migrated.smoothing, 5, "DLG2 gains only the new default smoothing")
eq(P.decode(P.encode(migrated, "pa01_demo_2Eyml", 4), "pa01_demo_2Eyml").voltage, migrated.voltage)
local fromV3, fromV3Revision = P.decode(__fixture("sample-v3.profile"), "pa01_demo_2Eyml")
eq(fromV3Revision, 5); eq(fromV3.language, 1); eq(fromV3.deadband, 2); eq(fromV3.smoothing, 5)
eq(fromV3.servos, 4); eq(fromV3.delay, 5); eq(fromV3.voltage, string.char(194, 147) .. "RxBt")
eq(P.decode(P.encode(fromV3, "pa01_demo_2Eyml", 6), "pa01_demo_2Eyml").smoothing, 5)
local fromV4, fromV4Revision = P.decode(__fixture("sample-v4.profile"), "pa01_demo_2Eyml")
eq(fromV4Revision, 6); eq(fromV4.period, 50); eq(fromV4.window, 120); eq(fromV4.chemistry, 1)
eq(fromV4.toneSource, string.char(194, 140) .. "SA"); eq(fromV4.smoothing, 5)
for _, old in ipairs({ migrated, fromV3, fromV4 }) do
  eq(old.toneVolume, 0); eq(old.climbTone, 720); eq(old.sinkTone, 390); eq(old.toneRate, 100)
end
config.toneVolume, config.climbTone, config.sinkTone, config.toneRate = 2, 1400, 250, 160
eq(P.save(key, config), true)
loaded = P.load(key); eq(loaded.toneVolume, 2); eq(loaded.climbTone, 1400); eq(loaded.sinkTone, 250); eq(loaded.toneRate, 160)
eq(P.load(other).toneVolume, 0, "audio preferences must not leak into another model")
invalid = P.copy(config); invalid.toneVolume = nil
eq(P.decode(P.encode(invalid, key, 1), key), nil, "DLG5 requires the new fields; only older schemas gain defaults")

-- Every settings page, source picker and setting value is keyboard/touch reachable.
reset()
local saved, closed = false, false
local editor = Settings.new(key, P.defaults(), function() saved = true end, function() closed = true end)
for page, pageData in ipairs(editor.pages) do
  editor.page, editor.focus = page, 1
  __begin("settings-" .. page); Settings.run(editor, 0, nil, 320, 240); __end()
  for row in ipairs(pageData.fields) do
    editor.focus = row
    Settings.run(editor, EVT_VIRTUAL_ENTER, nil, 320, 240)
    assert(editor.picker)
    local before = editor.picker.index
    Settings.run(editor, EVT_VIRTUAL_NEXT, nil, 320, 240)
    eq(editor.picker.index, math.min(before + 1, #editor.picker.choices), "NEXT/INC aliases advance exactly once")
    __begin("picker-" .. page .. "-" .. row); Settings.run(editor, 0, nil, 320, 240); __end()
    Settings.run(editor, EVT_VIRTUAL_ENTER, nil, 320, 240)
    eq(editor.picker, nil)
  end
end
editor.page = 1; editor.focus = #editor.pages[1].fields + 3
Settings.run(editor, EVT_VIRTUAL_ENTER, nil, 320, 240); eq(saved, true); eq(editor.dirty, false)
local persisted = P.load(key)
for k, value in pairs(editor.config) do eq(persisted[k], value, "persist " .. k) end
Settings.run(editor, 0, { x = 30, y = 52, tapCount = 1 }, 320, 240); assert(editor.picker)
Settings.run(editor, 0, { x = 30, y = 90, tapCount = 1 }, 320, 240); eq(editor.picker, nil)
editor.dirty = true; Settings.run(editor, EVT_VIRTUAL_EXIT, nil, 320, 240); eq(closed, false)
Settings.run(editor, EVT_VIRTUAL_EXIT, nil, 320, 240); eq(closed, true)

-- Existing plain source names and native icon labels must refer to one choice.
sim.nativeLabels = true
editor = Settings.new(key, P.defaults(), function() end, function() end)
Settings.run(editor, EVT_VIRTUAL_ENTER, nil, 320, 240)
eq(editor.picker.choices[editor.picker.index].value, "RxBt")
eq(editor.picker.choices[editor.picker.index].id, 307)
sim.nativeLabels = false

-- Chinese labels use bundled raster glyphs even with English-only firmware fonts.
editor = Settings.new(key, P.defaults(), function() end, function() end)
editor.config.language = 1
for page in ipairs(editor.pages) do
  editor.page = page
  __begin("zh-settings-" .. page); Settings.run(editor, 0, nil, 320, 240); __end()
end
editor.page, editor.focus = 9, 1
Settings.run(editor, EVT_VIRTUAL_ENTER, nil, 320, 240)
__begin("zh-language-picker"); Settings.run(editor, 0, nil, 320, 240); __end()
Settings.run(editor, EVT_VIRTUAL_PREV, nil, 320, 240)
Settings.run(editor, EVT_VIRTUAL_ENTER, nil, 320, 240); eq(editor.config.language, 0)
editor.config.language = 1; editor.page = 8
for row = 1, 4 do
  editor.focus = row; Settings.run(editor, EVT_VIRTUAL_ENTER, nil, 320, 240)
  __begin("zh-tone-picker-" .. row); Settings.run(editor, 0, nil, 320, 240); __end()
  for i = 1, #editor.picker.choices do
    editor.picker.index = i
    __begin("zh-tone-choice-" .. row .. "-" .. i); Settings.run(editor, 0, nil, 320, 240); __end()
  end
  Settings.run(editor, EVT_VIRTUAL_EXIT, nil, 320, 240)
end

-- Preserve divergent name/ID readings as evidence; never silently pick an offset.
reset()
local Diagnostics = loadScript("/WIDGETS/DLGDash/diagnostics.lua")(P)
config = P.defaults(); sim.voltage, sim.namedVoltage, sim.voltageMin, sim.voltageMax = 8.1, 8.5, 8.05, 8.6
local probe = Diagnostics.sample(config)
near(probe.selected.value, 8.1); near(probe.named.value, 8.5); near(probe.byId.value, 8.1)
eq(probe.selectedField.id, probe.namedField.id); near(probe.namedLegacy, 8.1)
local probeRows = {}
for i = 1, Diagnostics.count do probeRows[i] = Diagnostics.row(probe, config) end
local recorded, recordPath = Diagnostics.save(key, probeRows)
eq(recorded, true); assert(string.find(storage[recordPath], '"810"', 1, true)); assert(string.find(storage[recordPath], '"850"', 1, true))
local recordedAgain, secondPath = Diagnostics.save(key, probeRows)
eq(recordedAgain, true); assert(recordPath ~= secondPath, "diagnostic records must not overwrite one another")
denyWrite = true; eq(Diagnostics.save(key, probeRows), false); denyWrite = false
truncateWrite = true; eq(Diagnostics.save(key, probeRows), false); truncateWrite = false
eq(Diagnostics.save(key, {}), false)
config.voltage = string.char(194, 147) .. "RxBt"; sim.nativeLabels = true
sim.sourceOverrides = { [config.voltage] = 308 }
probe = Diagnostics.sample(config); eq(probe.selectedField.name, "RxBt-"); eq(probe.selectedField.id, 308); eq(probe.namedField.id, 307)
config.voltage = "unknown"; probe = Diagnostics.sample(config); eq(probe.selected.current, false)
eq(Diagnostics.voltage(probe.selected), "--.--V")
reset(); sim.voltage, sim.namedVoltage = 8.1, 8.5
editor = Settings.new(key, P.defaults(), function() error("Diagnostics must not save model settings") end, function() end)
editor.config.language, editor.page, editor.focus = 1, 10, 3
Settings.run(editor, EVT_VIRTUAL_ENTER, nil, 320, 240)
__begin("zh-voltage-path-mismatch"); Settings.run(editor, 0, nil, 320, 240); __end()
for i = 1, Diagnostics.count - 1 do sim.clock = sim.clock + Diagnostics.period; Settings.run(editor, 0, nil, 320, 240) end
eq(editor.recording, nil); eq(editor.message, "Record saved"); assert(storage[editor.recordPath])
__begin("zh-voltage-record-saved"); Settings.run(editor, 0, nil, 320, 240); __end()
Settings.run(editor, EVT_VIRTUAL_ENTER, nil, 320, 240); assert(editor.recording)
Settings.run(editor, EVT_VIRTUAL_NEXT_PAGE, nil, 320, 240); eq(editor.recording, nil, "leaving diagnostics stops acquisition")

-- Real-font screenshot fixtures from the actual Lua renderer, not an HTML mockup.
for _, servos in ipairs({ 4, 6 }) do
  s = state({ servos = servos, chemistry = 1 }); step(s)
  for i = 1, 900 do sim.altitude = 20 + 15 * math.sin(i / 130); step(s, 10) end
  s.launchHeight, s.launchState = 48.6, "settled"
  __begin("pa01-" .. servos .. "-servo"); D.dashboard(s, C, { w = 320, h = 240 }, true); __end()
  __begin("pa01-" .. servos .. "-home"); D.dashboard(s, C, { w = 320, h = 240 }, false); __brand(false); __end()
  sim.link = false; step(s)
  __begin("pa01-" .. servos .. "-no-telemetry"); D.dashboard(s, C, { w = 320, h = 240 }, false); __end()
end
for _, servos in ipairs({ 4, 6 }) do
  for _, output in ipairs({ -150, -100, -99, 0, 99, 100, 150 }) do
    s = state({ servos = servos, language = 1 }); step(s)
    for ch = 1, servos do s.data.channels[ch] = output end
    __begin("servo-fixed-" .. servos .. "-" .. output); D.dashboard(s, C, { w = 320, h = 240 }, true)
    __servoFont(servos); __end()
  end
end
s = state(); step(s); sim.timer = -3661; sim.altitude = -1234.5; step(s)
__begin("pa01-long-values"); D.dashboard(s, C, { w = 320, h = 240 }, true); __end()
s = state({ cells = 1, chemistry = 2 }); sim.voltage = 4.28; step(s)
__begin("pa01-1s-hv"); D.dashboard(s, C, { w = 320, h = 240 }, true); __end()
__begin("pa01-small-zone"); D.dashboard(s, C, { x = 8, y = 28, w = 304, h = 204 }, false); __end()
__begin("pa01-long-label"); D.text(string.rep("W", 64), 4, 4, 80, 24, D.colors.text, BOLD); __end()
for _, servos in ipairs({ 4, 6 }) do
  s = state({ language = 1, servos = servos }); sim.voltage = 8.14; step(s, 1000)
  s.launchHeight = 52.7
  __begin("zh-pa01-" .. servos); D.dashboard(s, C, { w = 320, h = 240 }, true); __end()
  s.launchState = "delay"; s.exitTick = s.now; s.config.delay = 15
  __begin("zh-pa01-wait-" .. servos); D.dashboard(s, C, { w = 320, h = 240 }, true); __end()
end

-- Full widget/tool integration: stale native options must not overwrite saved settings.
reset()
local api = loadScript("/WIDGETS/DLGDash/main.lua")()
eq(#api.options, 4)
config = P.defaults(); config.servos = 6; config.timer = 3; P.save(key, config)
local native = { ToneSw = 125, SwHigh = 1, ToneMin = 3, Timer = 1 }
local widget = api.create({ w = 320, h = 240 }, native)
api.update(widget, native); eq(widget.state.config.timer, 3); eq(widget.state.config.servos, 6)
sim.clock = sim.clock + 5; api.refresh(widget, 0, nil)
api.refresh(widget, 0, { x = 300, y = 10, tapCount = 1 }); assert(widget.editor)
api.refresh(widget, EVT_VIRTUAL_EXIT, nil); eq(widget.editor, nil)
config.timer = 2; P.save(key, config); sim.clock = sim.clock + 205
api.refresh(widget, 0, nil); eq(widget.state.config.timer, 2, "standalone settings changes reload into the widget")
sim.filename = "new.yml"; sim.clock = sim.clock + 5; api.background(widget); eq(widget.state.config.servos, 4)
local disabled = api.create({ w = 320, h = 240 }, { ToneSw = 0 })
eq(disabled.state.config.toneSource, "", "native None must keep audio disabled")
local tool = loadScript("/WIDGETS/DLGDash/DLGSetup.lua")(); tool.init(); eq(tool.run(EVT_VIRTUAL_EXIT), 2)
local function budget(name, fn)
  local instructions = 0
  debug.sethook(function() instructions = instructions + 100 end, "", 100)
  fn()
  debug.sethook()
  print("Instructions " .. name .. ": " .. instructions)
  assert(instructions < 20000, name .. " exceeds PA01 instruction budget")
end
reset()
sim.filename = "model47.yml"
budget("create saved profile", function() widget = api.create({ w = 320, h = 240 }, native) end)
for i = 1, 120 do widget.state.history[i] = { tick = i * 100, altitude = i % 60 } end
sim.clock = 12000; widget.state.config.window = 600
budget("refresh graph + profile poll", function() api.refresh(widget, 0, nil) end)
budget("refresh full graph", function() api.refresh(widget, 0, nil) end)
budget("open settings", function() api.refresh(widget, EVT_VIRTUAL_ENTER, nil) end)
widget.editor.config.servos = 4; widget.editor.focus = #widget.editor.pages[1].fields + 3
budget("save settings", function() api.refresh(widget, EVT_VIRTUAL_ENTER, nil) end)
local longConfig = P.defaults()
for _, k in ipairs({ "voltage", "altitude", "vario", "toneSource", "resetSource" }) do longConfig[k] = string.rep("X", 32) end
P.save(key, longConfig); P.save(key, longConfig)
budget("load max source names", function() P.load(key) end)
budget("save max source names", function() P.save(key, longConfig) end)
widget.editor.config = longConfig
budget("settings callback max names", function() api.refresh(widget, EVT_VIRTUAL_ENTER, nil) end)
reset()
config = P.defaults(); config.language = 1; config.servos = 6; P.save(key, config)
budget("create Chinese profile", function() widget = api.create({ w = 320, h = 240 }, native) end)
for i = 1, 120 do widget.state.history[i] = { tick = i * 100, altitude = i % 60 } end
sim.clock = 12000; widget.state.config.window = 600
api.refresh(widget, 0, nil)
budget("Chinese full graph cold labels", function() api.refresh(widget, 0, nil) end)
sim.clock = sim.clock + 5
budget("Chinese full graph cached labels", function() api.refresh(widget, 0, nil) end)
widget.state.config.vario = ""; widget.state.resolveTick = nil
sim.clock = sim.clock + 5; sim.fresh = false
budget("Chinese graph with slow altitude", function() api.refresh(widget, 0, nil) end)
budget("Chinese settings", function() api.refresh(widget, EVT_VIRTUAL_ENTER, nil) end)
widget.editor.focus = #widget.editor.pages[1].fields + 3
budget("Chinese save", function() api.refresh(widget, EVT_VIRTUAL_ENTER, nil) end)
widget.editor.page, widget.editor.focus = 10, 3
budget("start voltage recording", function() api.refresh(widget, EVT_VIRTUAL_ENTER, nil) end)
for i = 1, Diagnostics.count - 2 do sim.clock = sim.clock + Diagnostics.period; api.refresh(widget, 0, nil) end
sim.clock = sim.clock + Diagnostics.period
budget("finish voltage recording", function() api.refresh(widget, 0, nil) end)
local encoded = P.encode(longConfig, key, 99)
local body, sum = string.match(encoded, "^(.*\n)sum=(%x+)\n$")
local a, b = 1, 0
for i = 1, #body do a = (a + string.byte(body, i)) % 65521; b = (b + a) % 65521 end
eq(sum, string.format("%04x%04x", b, a), "block checksum matches bytewise Adler")
local byteChunk = ""
for i = 1, 255 do
  if i ~= 10 and i ~= 13 then byteChunk = byteChunk .. string.char(i) end
  if #byteChunk == 32 or i == 255 then
    local byteConfig = P.defaults(); byteConfig.voltage = byteChunk
    eq(P.decode(P.encode(byteConfig, key, 1), key).voltage, byteChunk, "byte lookup preserves UTF-8 and native source icons")
    byteChunk = ""
  end
end
budget("reject oversized corrupt profile", function() eq(P.decode("DLG2\n" .. string.rep("x", 4090), key), nil) end)
local coldApi = loadScript("/WIDGETS/DLGDash/main.lua")()
reset()
budget("cold widget with module initialization", function() widget = coldApi.create({ w = 320, h = 240 }, native) end)
P.save(key, longConfig); P.save(key, longConfig)
coldApi = loadScript("/WIDGETS/DLGDash/main.lua")()
budget("cold widget with maximum source names", function() widget = coldApi.create({ w = 320, h = 240 }, native) end)
reset()
config = P.defaults(); config.language = 1; config.servos = 6; config.toneVolume = 5; config.toneRate = 160
P.save(key, config); P.save(key, config)
widget = coldApi.create({ w = 320, h = 240 }, native)
for i = 1, 120 do widget.state.history[i] = { tick = i * 100, altitude = i % 60 } end
sim.clock = 12000; widget.state.config.window = 600; sim.switch = 1024; sim.vario = 100
coldApi.refresh(widget, 0, nil)
budget("Chinese full graph with loud fast climb", function() coldApi.refresh(widget, 0, nil) end)
sim.clock = sim.clock + 10; sim.vario = -100
budget("Chinese full graph with loud fast sink", function() coldApi.refresh(widget, 0, nil) end)
local coldTool = loadScript("/WIDGETS/DLGDash/DLGSetup.lua")()
budget("cold standalone settings", function() coldTool.init() end)
budget("standalone settings first paint", function() coldTool.run(0) end)
print("PASS: " .. count .. " assertions; profiles, launch, telemetry, 4/6 outputs, audio, settings and widget/tool integration")
