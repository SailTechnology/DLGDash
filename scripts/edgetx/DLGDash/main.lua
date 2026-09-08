-- DLGDash v1.1.0 by Sail. Color-screen widget; read-only model/radio APIs.
local ROOT = "/WIDGETS/DLGDash/"
local P, C, D, Settings
local function modules()
  if P then return end
  P = assert(loadScript(ROOT .. "profile.lua"))()
  C = assert(loadScript(ROOT .. "core.lua"))()
  D = assert(loadScript(ROOT .. "draw.lua"))()
end
-- Preserve existing home-screen option slots. Detailed settings live separately.
local sf = getFieldInfo("sf")
local _, radio = getVersion()
local options = {
  { "ToneSw", SOURCE, radio == "pa01" and sf and sf.id or 0 }, { "SwHigh", BOOL, 1 },
  { "ToneMin", VALUE, 3, 1, 20 }, { "Timer", VALUE, 1, 1, 3 }
}
local function import(config, opts, before)
  if opts.ToneSw and (not before or opts.ToneSw ~= before.ToneSw) then
    local info = getFieldInfo(opts.ToneSw)
    local name = info and (getSourceName and getSourceName(opts.ToneSw) or info.name)
    if opts.ToneSw == 0 then config.toneSource = ""
    elseif name and name ~= "" then config.toneSource = name end
  end
  if opts.SwHigh ~= nil and (not before or opts.SwHigh ~= before.SwHigh) then config.tonePosition = opts.SwHigh % 2 == 1 and 1 or -1 end
  if opts.ToneMin and (not before or opts.ToneMin ~= before.ToneMin) then config.deadband = math.max(1, math.min(20, opts.ToneMin)) end
  if opts.Timer and (not before or opts.Timer ~= before.Timer) then config.timer = math.max(1, math.min(3, opts.Timer)) end
end
local function bind(w)
  w.key, w.modelName = P.identity()
  local config, revision = P.load(w.key)
  if not config then config = P.defaults(); import(config, w.options) end
  w.revision, w.state = revision, C.new(config, P)
  w.stamp = P.stamp(w.key)
  w.pollTick = getTime()
end
local function create(zone, initialOptions)
  modules()
  local w = { zone = zone, options = P.copy(initialOptions or {}) }
  bind(w)
  return w
end
local function update(w, opts)
  if not w then return end
  local config = P.copy(w.state.config)
  import(config, opts, w.options)
  local changed = false
  for k, value in pairs(config) do if value ~= w.state.config[k] then changed = true end end
  w.options = P.copy(opts)
  if changed then
    local ok, revision = P.save(w.key, config)
    if ok then w.error = nil; w.revision = revision; w.stamp = P.stamp(w.key); C.configure(w.state, config)
    else w.error = "Settings not saved" end
  end
end
local function sample(w)
  local key = P.identity()
  if key ~= w.key then w.editor, w.editorVisible = nil, false; bind(w) end
  if not w.editorVisible and C.elapsed(getTime(), w.pollTick) >= 200 then
    w.pollTick = getTime()
    local stamp = P.stamp(w.key)
    local resumed = C.elapsed(getTime(), w.state.dataTick) > 100
    if stamp ~= w.stamp or resumed then
      local config, revision = P.load(w.key)
      w.stamp = stamp
      if config and revision > w.revision then C.configure(w.state, config); w.revision = revision end
      -- SD parsing and a full graph render must not share one 20k-instruction callback.
      return false
    end
  end
  w.state.muted = w.editorVisible == true
  C.update(w.state)
  return true
end
local function openSettings(w)
  if not Settings then Settings = assert(loadScript(ROOT .. "settings.lua"))(P, D) end
  w.editor = Settings.new(w.key, w.state.config, function(config, revision)
    C.configure(w.state, config); w.revision = revision; w.stamp = P.stamp(w.key)
  end, function() w.editor, w.editorVisible = nil, false end)
  w.editorVisible = true
end
local function refresh(w, event, touch)
  if not w then return end
  local fullscreen = event ~= nil
  w.editorVisible = fullscreen and w.editor ~= nil
  local ready = sample(w)
  local zone = fullscreen and { x = 0, y = 0, w = LCD_W, h = LCD_H } or w.zone
  if not ready then
    D.fill(zone.x or 0, zone.y or 0, zone.w, zone.h, D.colors.bg)
    D.text("DLG", zone.x or 0, zone.y or 0, zone.w, zone.h, D.colors.muted, BOLD, "center")
    return
  end
  if w.editor and fullscreen then Settings.run(w.editor, event, touch, zone.w, zone.h); return end
  -- Firmware can leave full-screen independently of our Exit button. Keep the
  -- draft for re-entry, but do not mute flight tones while settings are hidden.
  if fullscreen then
    local enter = EVT_VIRTUAL_ENTER ~= nil and event == EVT_VIRTUAL_ENTER
    local large = LCD_W >= 800 and LCD_H >= 480
    local tap = touch and touch.tapCount and touch.tapCount > 0 and touch.y < (large and 40 or 25) and touch.x > zone.w - (large and 108 or 72)
    if enter or tap then openSettings(w); Settings.run(w.editor, 0, nil, zone.w, zone.h); return end
    if EVT_VIRTUAL_EXIT ~= nil and event == EVT_VIRTUAL_EXIT then lcd.exitFullScreen(); return end
  end
  D.dashboard(w.state, C, zone, fullscreen)
  if w.error then D.text(w.error, zone.x or 0, (zone.y or 0) + 20, zone.w, 16, D.colors.red, SMLSIZE, "center") end
end
local function background(w)
  if w then w.editorVisible = false; sample(w) end
end
return { name = "DLGDash", options = options, create = create, update = update,
  refresh = refresh, background = background, version = "1.1.0" }
