-- Shared by the full-screen widget and DLGSetup; no model.set* APIs.
local P, D = ...
local S, c = {}, D.colors
local Diagnostics
local function option(value, label) return { value = value, label = label or tostring(value) } end
local function field(key, label, choices) return { key = key, label = label, choices = choices } end
local function numberChoices(first, last, step, scale, unit)
  local choices = {}
  for i = first, last, step do choices[#choices + 1] = option(i, string.format(scale == 1 and "%d%s" or "%.1f%s", i / scale, unit)) end
  return choices
end
local function fromValues(values, scale, unit)
  local choices = {}
  for _, i in ipairs(values) do choices[#choices + 1] = option(i, string.format(scale == 1 and "%d%s" or "%.1f%s", i / scale, unit)) end
  return choices
end
function S.new(key, config, onSave, onClose)
  local modes = { option(-1, "None") }
  for i = 0, 8 do
    local _, name = getFlightMode(i)
    modes[#modes + 1] = option(i, "FM" .. i .. " " .. ((name and name ~= "") and name or "(unnamed)"))
  end
  local channels = { option(0, "Off") }
  for i = 1, 32 do
    local output = model.getOutput(i - 1) or {}
    channels[#channels + 1] = option(i, "CH" .. i .. (output.name and output.name ~= "" and " " .. output.name or ""))
  end
  local pages = {
    { title = "BATTERY", fields = {
      field("voltage", "Voltage source", "voltage"),
      field("cells", "Pack cells", { option(0, "Auto 1S / 2S"), option(1, "1S"), option(2, "2S") }),
      field("chemistry", "Battery type", { option(0, "Auto (HV uncertain)"), option(1, "LiPo 4.20V"), option(2, "HV 4.35V") }) } },
    { title = "TELEMETRY", fields = {
      field("altitude", "Altitude source", "altitude"), field("vario", "Vario source", "vario"),
      field("timer", "Timer display", { option(1, "Timer 1"), option(2, "Timer 2"), option(3, "Timer 3") }),
      field("smoothing", "Curve smoothing", { option(0, "Off"), option(3, "0.3s"), option(5, "0.5s"),
        option(10, "1.0s"), option(20, "2.0s"), option(30, "3.0s") }) } },
    { title = "LAUNCH", fields = {
      field("launchMode", "Exit this mode", modes),
      field("delay", "Delay after exit", numberChoices(0, 100, 1, 10, "s")),
      field("settle", "Height result", { option(0, "At end of delay"), option(1, "Peak: mode + delay") }) } },
    { title = "SERVOS 1", fields = {
      field("servos", "Servo version", { option(4, "4 servos"), option(6, "6 servos") }),
      field("ch1", "LA / Left aileron", channels), field("ch2", "RA / Right aileron", channels) } },
    { title = "SERVOS 2", fields = {
      field("ch3", "ELE / Elevator", channels), field("ch4", "RUD / Rudder", channels),
      field("ch5", "LF / Left flap", channels), field("ch6", "RF / Right flap", channels) } },
    { title = "GRAPH", fields = {
      field("window", "Time window", fromValues(P.windows, 1, "s")),
      field("period", "Sample / effective", fromValues(P.periods, 100, "s")),
      field("resetSource", "Preset / clear button", "switch"),
      field("resetPosition", "Clear position", { option(-1, "Low (-100)"), option(0, "Middle (0)"), option(1, "High (+100)") }) } },
    { title = "AUDIO", fields = {
      field("toneSource", "Switch / button", "switch"),
      field("tonePosition", "Active position", { option(-1, "Low (-100)"), option(0, "Middle (0)"), option(1, "High (+100)") }),
      field("toneMode", "Button behavior", { option(0, "While active"), option(1, "Press to toggle") }),
      field("deadband", "Vario deadband", numberChoices(1, 20, 1, 10, "m/s")) } },
    { title = "TONE SETTINGS", fields = {
      field("toneVolume", "Tone volume", { option(0, "Follow radio"), option(-1, "MUTE"),
        option(1, "1 / 5"), option(2, "2 / 5"), option(3, "3 / 5"), option(4, "4 / 5"), option(5, "5 / 5") }),
      field("climbTone", "Climb base pitch", fromValues({ 600, 720, 900, 1100, 1400 }, 1, "Hz")),
      field("sinkTone", "Sink base pitch", fromValues({ 250, 320, 390, 460, 550 }, 1, "Hz")),
      field("toneRate", "Beep cadence", { option(60, "Slow"), option(100, "Normal"), option(160, "Fast") }) } },
    { title = "LANGUAGE", fields = {
      field("language", "Language", { option(0, "English"), option(1, "Chinese") }) } },
    { title = "VOLTAGE CHECK", diagnostic = true, fields = {} }
  }
  local _, name = P.identity()
  return { key = key, modelName = name, config = P.copy(config), onSave = onSave, onClose = onClose,
    page = 1, focus = 1, pages = pages, dirty = false }
end
local function eventIs(event, name) return event ~= nil and _G[name] ~= nil and event == _G[name] end
local function tapped(touch) return touch and (touch.tapCount and touch.tapCount > 0) end
local function indexOf(choices, value)
  for i, entry in ipairs(choices) do if entry.value == value then return i end end
  return 1
end
local function choicesFor(s, row)
  if type(row.choices) == "table" then return row.choices end
  if not s.sources then s.sources = {} end
  if not s.sources[row.key] then
    local choices = P.sourceList(row.choices)
    local value, found = s.config[row.key], false
    local current = P.field(value)
    for _, entry in ipairs(choices) do
      if current and entry.id == current.id then entry.value = value end
      if entry.value == value then found = true end
    end
    if not found then choices[#choices + 1] = option(value, value .. " (missing)") end
    s.sources[row.key] = choices
  end
  return s.sources[row.key]
end
local function rowLabel(s, row)
  if row.key == "period" then
    return string.format("%.1fs / %.2fs", s.config.period / 100, math.max(s.config.period, math.ceil(s.config.window * 100 / 120)) / 100)
  end
  local choices = choicesFor(s, row)
  return choices[indexOf(choices, s.config[row.key])].label
end
local function voltageText(source)
  local value, current = getSourceValue(source)
  if not current then return "--.--V" end
  if type(value) == "table" then
    local sum = 0
    for _, cell in ipairs(value) do
      if type(cell) ~= "number" or cell < 1.5 or cell > 4.5 then return "--.--V" end
      sum = sum + cell
    end
    value = sum
  end
  if type(value) ~= "number" or value ~= value or value <= 0 or value > 100 then return "--.--V" end
  return string.format("%.2fV", value)
end
local function open(s, row)
  local choices = choicesFor(s, row)
  s.picker = { row = row, choices = choices, index = indexOf(choices, s.config[row.key]) }
end
local function choose(s)
  local p = s.picker
  local value = p.choices[p.index].value
  if s.config[p.row.key] ~= value then s.config[p.row.key] = value; s.dirty = true end
  s.picker = nil
end
local function changePage(s, delta)
  s.recording = nil
  s.page = (s.page - 1 + delta) % #s.pages + 1
  s.focus, s.message = 1, nil
end
local function diagnostics(s)
  if not Diagnostics then Diagnostics = assert(loadScript("/WIDGETS/DLGDash/diagnostics.lua"))(P) end
  local now = getTime()
  if s.probeTick and (now - s.probeTick) % 2147483648 < Diagnostics.period then return end
  s.probeTick = now
  s.probe = Diagnostics.sample(s.config)
  if s.recording then
    if P.identity() ~= s.key then s.recording = nil; s.message = "Model changed"; return end
    s.recording[#s.recording + 1] = Diagnostics.row(s.probe, s.config)
    s.message = "REC " .. #s.recording .. "/" .. Diagnostics.count
    if #s.recording == Diagnostics.count then
      local ok, result = Diagnostics.save(s.key, s.recording)
      s.recording = nil
      s.message = ok and "Record saved" or result
      s.recordPath = ok and result or nil
    end
  end
end
local function drawDiagnostics(s, w, top, rowH, labelH)
  diagnostics(s)
  local p = s.probe
  local selected, named = p.selectedField or {}, p.namedField or {}
  local rows = {
    { "Selected source", "#" .. (selected.id or "--") .. " " .. (selected.name or "--") .. " " .. Diagnostics.voltage(p.selected) },
    { "RxBt by name", "#" .. (named.id or "--") .. " " .. (named.name or "--") .. " " .. Diagnostics.voltage(p.named) },
    { "RxBt ID / getValue", Diagnostics.voltage(p.byId) .. " / " .. Diagnostics.voltage({ value = p.namedLegacy, current = p.byId.current }) },
    { "RxBt min / max", Diagnostics.voltage(p.minimum) .. " / " .. Diagnostics.voltage(p.maximum) }
  }
  for i, row in ipairs(rows) do
    local ry = top + (i - 1) * rowH
    D.text(row[1], 7, ry, w - 14, labelH, c.muted, SMLSIZE)
    D.text(row[2], 7, ry + labelH, w - 14, rowH - labelH - 1, c.text, BOLD)
  end
end
local function save(s)
  local ok, result = P.save(s.key, s.config)
  if not ok then s.message = result; return end
  s.dirty, s.message = false, "Saved"
  s.onSave(P.copy(s.config), result)
  s.savedThisFrame = true
end
local function leave(s)
  if s.dirty and not s.confirmDiscard then s.confirmDiscard = true; s.message = "EXIT again: discard"; return end
  s.onClose()
end
local function activate(s)
  local fields = s.pages[s.page].fields
  if s.focus <= #fields then open(s, fields[s.focus])
  elseif s.focus == #fields + 1 then changePage(s, -1)
  elseif s.focus == #fields + 2 then changePage(s, 1)
  elseif s.focus == #fields + 3 then
    if s.pages[s.page].diagnostic then s.recording, s.probeTick, s.recordPath = {}, nil, nil; s.message = "REC 0/24"
    else save(s) end
  else leave(s) end
end
function S.run(s, event, touch, w, h)
  local fields = s.pages[s.page].fields
  local nextEvent = eventIs(event, "EVT_VIRTUAL_NEXT") or eventIs(event, "EVT_VIRTUAL_INC")
  local prevEvent = eventIs(event, "EVT_VIRTUAL_PREV") or eventIs(event, "EVT_VIRTUAL_DEC")
  local enter, exit = eventIs(event, "EVT_VIRTUAL_ENTER"), eventIs(event, "EVT_VIRTUAL_EXIT")
  local wide = w == 480 and h == 272
  local top, labelH, footerH = wide and 46 or 38, wide and 19 or 16, wide and 40 or 36
  local footer = h - footerH
  local rowH = math.floor((footer - top - 4) / 4)
  if s.picker then
    local p = s.picker
    if nextEvent then p.index = math.min(#p.choices, p.index + 1) end
    if prevEvent then p.index = math.max(1, p.index - 1) end
    if exit then s.picker = nil end
    if enter then choose(s) end
    if tapped(touch) and s.picker then
      local start = math.max(1, math.min(p.index - 1, #p.choices - 3))
      if touch.y >= top and touch.y < top + rowH * 4 then
        local i = start + math.floor((touch.y - top) / rowH)
        if i <= #p.choices then p.index = i; choose(s) end
      elseif touch.y >= footer then
        if touch.x < w / 4 then p.index = math.max(1, p.index - 4)
        elseif touch.x < w / 2 then p.index = math.min(#p.choices, p.index + 4)
        elseif touch.x < w * 3 / 4 then choose(s)
        else s.picker = nil end
      end
    end
  else
    if nextEvent then s.focus = s.focus % (#fields + 4) + 1; s.confirmDiscard = false end
    if prevEvent then s.focus = (s.focus - 2) % (#fields + 4) + 1; s.confirmDiscard = false end
    if eventIs(event, "EVT_VIRTUAL_NEXT_PAGE") then changePage(s, 1) end
    if eventIs(event, "EVT_VIRTUAL_PREV_PAGE") then changePage(s, -1) end
    if enter then activate(s) end
    if exit then leave(s) end
    if tapped(touch) then
      if touch.y >= top and touch.y < top + rowH * #fields then
        s.focus = math.floor((touch.y - top) / rowH) + 1; open(s, fields[s.focus])
      elseif touch.y >= footer then s.focus = #fields + 1 + math.min(3, math.floor(touch.x / (w / 4))); activate(s) end
    end
  end
  fields = s.pages[s.page].fields
  D.language(s.config.language)
  -- Saving two verified SD slots and drawing every row can exceed 20k on PA01.
  if s.savedThisFrame then
    s.savedThisFrame = nil
    D.fill(0, 0, w, top - 2, c.band)
    D.text(s.message, 5, 0, w - 10, top - 2, c.green, BOLD)
    return
  end
  D.fill(0, 0, w, h, c.bg)
  local titleH = wide and 24 or 20
  D.fill(0, 0, w, top - 2, c.band)
  D.text(s.picker and s.picker.row.label or s.pages[s.page].title, 5, 0, w - 66, titleH, c.amber, BOLD)
  D.text(s.dirty and "*" or s.page .. "/" .. #s.pages, w - 58, 0, 52, titleH, c.text, BOLD, "right")
  D.text(s.message or s.modelName or "DLG", 5, titleH, w - 10, top - titleH - 3, s.message and c.amber or c.muted, SMLSIZE)
  if s.picker then
    local p = s.picker
    local start = math.max(1, math.min(p.index - 1, #p.choices - 3))
    for row = 0, 3 do
      local i = start + row
      if p.choices[i] then
        if i == p.index then D.fill(2, top + row * rowH, w - 4, rowH - 1, c.band) end
        D.text(p.choices[i].label, 8, top + row * rowH, w - 16, rowH - 2, i == p.index and c.cyan or c.text, BOLD)
      end
    end
  else
    for i, row in ipairs(fields) do
      local ry = top + (i - 1) * rowH
      if s.focus == i then D.fill(2, ry, w - 4, rowH - 1, c.band) end
      D.text(row.label, 7, ry, w - 14, labelH, c.muted, SMLSIZE)
      D.text(rowLabel(s, row), 7, ry + labelH, w - 14, rowH - labelH - 1, c.text, BOLD)
    end
    if s.pages[s.page].diagnostic then drawDiagnostics(s, w, top, rowH, labelH)
    elseif s.page == 1 then
      local source = P.field(s.config.voltage)
      local ry = top + 3 * rowH
      D.text("Live source / RxBt", 7, ry, w - 14, labelH, c.muted, SMLSIZE)
      D.text(voltageText(source and source.id or 0) .. " / " .. voltageText("RxBt"), 7, ry + labelH, w - 14, rowH - labelH - 1, c.green, BOLD)
    end
  end
  local labels = s.picker and { "^", "v", "OK", "Back" } or { "<", ">", s.pages[s.page].diagnostic and "Record" or "Save", "Exit" }
  for i, label in ipairs(labels) do
    local bx = (i - 1) * w / 4
    local focused = not s.picker and s.focus == #fields + i
    D.fill(bx + 1, footer, w / 4 - 2, footerH - 1, focused and c.line or c.band)
    D.text(label, bx + 3, footer, w / 4 - 6, footerH - 1, i == 3 and c.green or c.text, BOLD, "center")
  end
end
if LCD_H == 64 then
  return assert(loadScript("/WIDGETS/DLGDash/mono-settings.lua"))(S, D, {
    eventIs = eventIs, open = open, choose = choose, changePage = changePage,
    rowLabel = rowLabel, activate = activate, leave = leave, diagnostics = diagnostics,
    voltageText = voltageText, field = P.field
  })
end
return S
