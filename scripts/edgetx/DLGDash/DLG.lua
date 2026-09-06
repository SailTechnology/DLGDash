-- Telemetry entry: /SCRIPTS/TELEMETRY/DLG.lua (6-character filename limit).
-- X9D / GX12 experimental. Only reads flight settings and output channels.
local ROOT = "/WIDGETS/DLGDash/"
local P, C, D, Settings, state, key, revision, pollTick, editor
local page, unavailable = 1, nil
local function bind()
  key = P.identity()
  local config
  config, revision = P.load(key)
  state = C.new(config or P.defaults(), P)
  pollTick, editor = getTime(), nil
end
local function init()
  if LCD_H ~= 64 or (LCD_W ~= 128 and LCD_W ~= 212) then unavailable = "Use color widget"; return end
  if not getSourceValue or not getOutputValue or not sources then unavailable = "EdgeTX 2.11 required"; return end
  P = assert(loadScript(ROOT .. "profile.lua"))()
  C = assert(loadScript(ROOT .. "core.lua"))()
  D = assert(loadScript(ROOT .. "mono-ui.lua"))()
  bind()
end
local function sample()
  if not P then init() end
  if unavailable then return false end
  if P.identity() ~= key then bind(); return false end
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
  if editor then Settings.run(editor, event); return end
  if event == EVT_VIRTUAL_ENTER then
    if not Settings then Settings = assert(loadScript(ROOT .. "settings.lua"))(P, D) end
    editor = Settings.new(key, state.config, function(config, rev)
      C.configure(state, config); revision = rev
    end, function() editor = nil end)
    state.muted = true
    -- Keep loading the controller separate from the first menu render.
    return
  end
  if event == EVT_VIRTUAL_NEXT or event == EVT_VIRTUAL_PREV then page = 3 - page end
  D.dashboard(state, C, page)
end
return { init = init, run = run, background = sample }
