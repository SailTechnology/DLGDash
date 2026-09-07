-- Read-only flight data/state. Time values are EdgeTX centiseconds.
local C = { maxPoints = 120 }
function C.elapsed(now, before)
  if before == nil then return 2147483648 end
  return (now - before) % 2147483648
end

local function finite(v) return type(v) == "number" and v == v and math.abs(v) < 1000000 end
local function clamp(v, lo, hi) return math.max(lo, math.min(v, hi)) end

function C.new(config, profile)
  return { config = config, profile = profile, data = { channels = {} }, history = {},
    launchState = "idle", launchHeight = nil, toneActive = false, ids = {}, now = getTime() }
end

function C.configure(state, config)
  local fresh = C.new(config, state.profile)
  for k in pairs(state) do state[k] = nil end
  for k, v in pairs(fresh) do state[k] = v end
end

local function source(state, key)
  local field = state.ids[key]
  if not field then return nil, false end
  -- 在控制链路可靠的前提下，ELRS 遥测回传率应尽可能高；不是只提高发射包率。
  -- 本插件不修改 ELRS 参数，平滑不能恢复两次真实回传之间缺失的测量。
  local value, current, fresh = state.profile.api.value(field.id, field)
  -- isFresh describes packet age, not validity; slow sensors remain current.
  if current ~= true then return nil, false, false end
  if type(value) == "table" then return value, true, fresh == true end
  if not finite(value) then return nil, false end
  if field.unit == UNIT_FEET or field.unit == UNIT_FEET_PER_SECOND then value = value * 0.3048 end
  return value, true, fresh == true
end

local function clearDerivative(s)
  s.altBaseline, s.altTick, s.derived, s.altSeen, s.altFresh = nil, nil, nil, nil, nil
  s.altPacketTick, s.altPacketPeriod = nil, nil
end

local function pressed(state, key, position)
  local value, valid = source(state, key)
  if not valid or not finite(value) then return false, false end
  if position == 1 then return value > 512, true end
  if position == -1 then return value < -512, true end
  return math.abs(value) <= 512, true
end

local function updateReset(s)
  local active = pressed(s, "resetSource", s.config.resetPosition)
  if active and not s.resetHeld then
    s.history, s.historyTick, s.graphGap = {}, nil, nil
    clearDerivative(s)
  end
  if active or s.resetHeld then s.resetTick = s.now end
  s.resetHeld = active
  -- Let the native telemetry reset finish before accepting new graph samples.
  s.graphReset = active or C.elapsed(s.now, s.resetTick) < 50
end

function C.battery(state, value, valid)
  local cfg = state.config
  local cellsFromSensor
  if valid and type(value) == "table" then
    cellsFromSensor = #value
    local sum = 0
    for i = 1, #value do
      if not finite(value[i]) or value[i] < 1.5 or value[i] > 4.5 then valid = false; break end
      sum = sum + value[i]
    end
    value = sum
  end
  if not valid or not finite(value) or value <= 0 then
    state.batteryGap = state.batteryGap or state.now
    state.hvCount = 0
    return { label = "NO DATA" }
  end
  -- A different pack after a telemetry disconnect must not inherit HV detection.
  if state.batteryGap and C.elapsed(state.now, state.batteryGap) >= 200 then state.autoHV = nil end
  state.batteryGap = nil
  local cells = cfg.cells > 0 and cfg.cells or cellsFromSensor
  if not cells then
    if value >= 2.5 and value <= 4.45 then cells = 1
    elseif value >= 5.8 and value <= 8.9 then cells = 2 end
  end
  if cells ~= 1 and cells ~= 2 then return { voltage = value, label = "SET PACK" } end
  local perCell = value / cells
  if perCell < 2.5 or perCell > 4.45 then return { voltage = value, label = "CHECK PACK" } end
  if state.autoCells ~= cells then state.autoHV = nil; state.hvCount = 0; state.autoCells = cells end
  if perCell > 4.24 then
    state.hvCount = (state.hvCount or 0) + 1
    if state.hvCount >= 3 then state.autoHV = true end
  else state.hvCount = 0 end
  local hv = cfg.chemistry == 2 or (cfg.chemistry == 0 and state.autoHV == true)
  local uncertain = cfg.chemistry == 0 and not hv
  return { voltage = value, cells = cells, hv = hv, full = cells * (hv and 4.35 or 4.2),
    low = perCell < 3.5, label = cells .. "S " .. (hv and "HV" or uncertain and "AUTO?" or "LiPo") }
end

local function updateLaunch(s, mode, altitude)
  local cfg = s.config
  local active = cfg.launchMode >= 0 and mode == cfg.launchMode
  if active and not s.modeActive then
    s.launchHeight, s.peak, s.exitTick = nil, nil, nil
    s.peakComplete = s.modeObserved == true
    s.launchState = "tracking"
  end
  if (active or s.modeActive or s.launchState == "delay") and not altitude then s.peakComplete = false end
  if (active or s.modeActive or s.launchState == "delay") and altitude then s.peak = math.max(s.peak or altitude, altitude) end
  if not active and s.modeActive then s.exitTick = s.now; s.launchState = "delay" end
  if s.launchState == "delay" and C.elapsed(s.now, s.exitTick) >= cfg.delay * 10 then
    -- Include the exit sample even for a zero-delay peak settlement.
    if altitude then s.peak = math.max(s.peak or altitude, altitude) end
    if cfg.settle == 1 then s.launchHeight = altitude and s.peakComplete and s.peak or nil
    else s.launchHeight = altitude end
    s.launchState = s.launchHeight and "settled" or "lost"
  end
  s.modeActive = active
  s.modeObserved = true
end

local function updateVario(s, altitude, speed, fresh)
  local d = s.data
  if speed then
    d.vario = speed
    clearDerivative(s)
  elseif altitude then
    -- A held sample is not a new measurement. Differentiate observable updates,
    -- not 20Hz redraws, so slow packets cannot produce large artificial spikes.
    local packet = altitude ~= s.altSeen or (fresh and not s.altFresh)
    s.altSeen, s.altFresh = altitude, fresh
    if packet then
      if s.altPacketTick then s.altPacketPeriod = C.elapsed(s.now, s.altPacketTick) end
      s.altPacketTick = s.now
      if s.altBaseline == nil then
        s.altBaseline, s.altTick = altitude, s.now
      elseif C.elapsed(s.now, s.altTick) >= 20 then
        local rate = (altitude - s.altBaseline) * 100 / C.elapsed(s.now, s.altTick)
        s.derived = s.derived and s.derived * 0.6 + rate * 0.4 or rate
        s.altBaseline, s.altTick = altitude, s.now
      end
    elseif s.derived and C.elapsed(s.now, s.altPacketTick) > math.max(100, (s.altPacketPeriod or 0) * 2) then
      s.derived = 0
    end
    d.vario = s.derived
  else
    d.vario = nil
    clearDerivative(s)
  end
end

local function smoothGraph(s, altitude)
  if s.graphReset or not altitude then
    s.graphAltitude, s.smoothTick = nil, nil
    return
  end
  local tau = s.config.smoothing * 10
  if s.graphAltitude == nil or tau == 0 then s.graphAltitude = altitude
  else
    local dt = C.elapsed(s.now, s.smoothTick)
    -- First-order low-pass, bounded between the old trace and the real sample.
    s.graphAltitude = s.graphAltitude + (altitude - s.graphAltitude) * dt / (tau + dt)
  end
  s.smoothTick = s.now
end

local function updateHistory(s)
  local cfg = s.config
  -- Bound history to the PA01 plot width and its 20k instruction budget.
  local period = math.max(cfg.period, math.ceil(cfg.window * 100 / C.maxPoints))
  s.effectivePeriod = period
  if s.graphReset then return end
  if not s.data.altitude then s.graphGap = true end
  if C.elapsed(s.now, s.historyTick) >= period then
    s.history[#s.history + 1] = { tick = s.now, altitude = s.graphAltitude, gap = s.graphGap }
    s.historyTick, s.graphGap = s.now, nil
  end
  while #s.history > 0 and C.elapsed(s.now, s.history[1].tick) > cfg.window * 100 do table.remove(s.history, 1) end
end

local function updateTone(s)
  local cfg = s.config
  local active, valid = pressed(s, "toneSource", cfg.tonePosition)
  if cfg.toneMode == 0 then s.toneActive = active
  elseif s.previousPressed ~= nil and active and not s.previousPressed then s.toneActive = not s.toneActive end
  s.previousPressed = active
  if not valid or cfg.toneSource == "" then s.toneActive = false end
  local speed = s.data.vario
  if s.muted or cfg.toneVolume == -1 or not s.toneActive or not speed or math.abs(speed) < cfg.deadband / 10 then
    s.toneTick = s.now; return
  end
  local scale = 100 / cfg.toneRate
  local interval = (speed > 0 and clamp(35 - speed * 5, 12, 34) or 38) * scale
  if C.elapsed(s.now, s.toneTick) < interval then return end
  local freq = speed > 0 and clamp(cfg.climbTone + speed * 230, cfg.climbTone + 40, cfg.climbTone + 1180)
    or clamp(cfg.sinkTone + speed * 45, math.max(150, cfg.sinkTone - 200), cfg.sinkTone - 30)
  local duration = math.floor((speed > 0 and 55 or 190) * scale + 0.5)
  -- EdgeTX 2.11 supports per-tone volume; never change global audio or flush alarms.
  if cfg.toneVolume == 0 or not s.profile.api.toneVolume then
    playTone(math.floor(freq + 0.5), duration, 20, PLAY_BACKGROUND or 0, 0)
  else
    playTone(math.floor(freq + 0.5), duration, 20, PLAY_BACKGROUND or 0, 0, cfg.toneVolume)
  end
  s.toneTick = s.now
end

function C.update(s)
  local now = getTime()
  if C.elapsed(now, s.dataTick) < 5 then return end
  local gap = C.elapsed(now, s.dataTick)
  s.now, s.dataTick = now, now
  if gap > 100 then
    clearDerivative(s)
    s.previousPressed, s.graphAltitude, s.smoothTick = nil, nil, nil
    s.graphGap = true
    s.modeObserved = false
    -- Do not settle an exit that could have happened while scripts were suspended.
    if s.modeActive or s.launchState == "delay" then s.modeActive = false; s.launchState = "lost"; s.launchHeight = nil end
  end
  if C.elapsed(now, s.resolveTick) >= 200 then
    for _, key in ipairs({ "altitude", "voltage", "vario", "toneSource", "resetSource" }) do s.ids[key] = s.profile.field(s.config[key]) end
    s.resolveTick = now
  end
  local altitude, _, altitudeFresh = source(s, "altitude")
  local speed = source(s, "vario")
  if not finite(altitude) then altitude = nil end
  if not finite(speed) then speed = nil end
  local voltage, voltageValid = source(s, "voltage")
  s.data.altitude = altitude
  s.data.battery = C.battery(s, voltage, voltageValid)
  s.data.link = altitude ~= nil or speed ~= nil or voltageValid
  s.mode, s.modeName = getFlightMode()
  updateReset(s)
  updateLaunch(s, s.mode, altitude)
  updateVario(s, not s.graphReset and altitude or nil, not s.graphReset and speed or nil, altitudeFresh)
  local timer = model.getTimer(s.config.timer - 1)
  s.data.timer = timer and timer.value or nil
  for i = 1, s.config.servos do
    local ch = s.config["ch" .. i]
    local raw = ch > 0 and s.profile.api.output(ch - 1) or nil
    s.data.channels[i] = finite(raw) and raw / 10.24 or nil
  end
  smoothGraph(s, altitude)
  updateHistory(s)
  updateTone(s)
end

function C.timer(value)
  if not finite(value) then return "--:--" end
  local seconds = math.floor(math.abs(value))
  local h, m = math.floor(seconds / 3600), math.floor(seconds / 60) % 60
  local text = h > 0 and string.format("%d:%02d:%02d", h, m, seconds % 60) or string.format("%02d:%02d", m, seconds % 60)
  return value < 0 and "-" .. text or text
end
return C
