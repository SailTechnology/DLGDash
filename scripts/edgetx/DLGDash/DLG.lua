-- Telemetry entry: /SCRIPTS/TELEMETRY/DLG.lua (6-character filename limit).
-- Shared X9D / GX12 / Zorro / T14 entry. Only reads flight settings and outputs.
local ROOT = "/WIDGETS/DLGDash/"
local P, C, D, Settings, state, key, revision, pollTick, editor
local page, unavailable = 1, nil
local phase, pendingConfig, packedCount
local function collect()
  if collectgarbage then collectgarbage("collect") end
end
local function flightModules()
  C = assert(loadScript(ROOT .. "core.lua"))()
  collect()
  D = assert(loadScript(ROOT .. "mono-ui.lua"))()
end
local function packHistory()
  local h = state.history
  packedCount = #h
  -- Expand backwards in place: no second history array or per-point tables.
  for i = packedCount, 1, -1 do
    local p, j = h[i], (i - 1) * 3 + 1
    h[j], h[j + 1], h[j + 2] = p.tick, p.altitude or false, p.gap or false
  end
end
local function unpackHistory()
  local h = state.history
  for i = 1, packedCount do
    local j = (i - 1) * 3 + 1
    h[i] = { tick = h[j], altitude = h[j + 1] or nil, gap = h[j + 2] or nil }
  end
  for i = packedCount + 1, packedCount * 3 do h[i] = nil end
  packedCount = nil
end
local function bind()
  key = P.identity()
  local config
  config, revision = P.load(key)
  state = C.new(config or P.defaults(), P)
  pollTick, editor = getTime(), nil
end
local function init()
  if LCD_H ~= 64 or (LCD_W ~= 128 and LCD_W ~= 212) then unavailable = "Use color widget"; return end
  if not getValue or not getFieldInfo or not sources then unavailable = "Lua APIs missing"; return end
  P = assert(loadScript(ROOT .. "profile.lua"))()
  collect()
  flightModules()
  bind()
end
local function sample()
  if not P then init() end
  if unavailable then return false end
  if P.identity() ~= key then
    editor, Settings, phase, pendingConfig, C, D, state = nil, nil, nil, nil, nil, nil, nil
    packedCount = nil
    collect()
    flightModules()
    bind()
    return false
  end
  if phase or editor then return true end
  if not editor and C.elapsed(getTime(), pollTick) >= 200 then
    pollTick = getTime()
    local config, rev = P.load(key)
    if config and rev > revision then C.configure(state, config); revision = rev end
    return false
  end
  state.muted = editor ~= nil
  C.update(state)
  return true
end
local function run(event)
  local ready = sample()
  if unavailable then lcd.clear(); lcd.drawText(0, 20, unavailable, 0); return end
  if not ready then return end
  if phase == "open" then
    collect()
    Settings = assert(loadScript(ROOT .. "settings.lua"))(P, D)
    editor = Settings.new(key, state.config, function(config, rev)
      pendingConfig, revision = config, rev
    end, function()
      editor, Settings, D = nil, nil, nil
      phase = "close"
    end)
    phase = nil
    return
  end
  if phase == "close" then
    -- Reload only after the settings callback has left the Lua stack.
    collect()
    flightModules()
    if pendingConfig then
      C.configure(state, pendingConfig)
      pendingConfig, packedCount = nil, nil
    else unpackHistory() end
    state.dataTick, state.muted, phase = nil, false, nil
    pollTick = getTime()
    return
  end
  if editor then Settings.run(editor, event); return end
  if event == EVT_VIRTUAL_ENTER then
    -- Retain flight history, but release the flight code before compiling menus.
    state.muted = true
    C = nil
    D = { text = D.text, language = D.language, colors = D.colors }
    packHistory()
    phase = "open"
    collect()
    return
  end
  if event == EVT_VIRTUAL_NEXT or event == EVT_VIRTUAL_PREV then page = 3 - page end
  D.dashboard(state, C, page)
end
return { init = init, run = run, background = sample }
