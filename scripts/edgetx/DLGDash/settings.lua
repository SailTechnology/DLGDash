-- Shared by the full-screen widget and DLGSetup; no model.set* APIs.
local P, D = ...
local S = {}
local Diagnostics
local function option(value, label) return { value = value, label = label or tostring(value) } end
local function field(key, label, choices) return { key = key, label = label, choices = choices } end
local numericChoices = {
  __len = function(t) return math.floor((t.last - t.first) / t.step) + 1 end,
  __index = function(t, index)
    if type(index) ~= "number" or index < 1 or index > #t then return nil end
    local value = t.first + (index - 1) * t.step
    return option(value, string.format(t.scale == 1 and "%d%s" or "%.1f%s", value / t.scale, t.unit))
  end
}
local function numberChoices(first, last, step, scale, unit)
  -- Do not allocate 101 tables/strings just to display a launch delay.
  return setmetatable({ first = first, last = last, step = step, scale = scale, unit = unit }, numericChoices)
end
local function fromValues(values, scale, unit)
  local choices = {}
  for _, i in ipairs(values) do choices[#choices + 1] = option(i, string.format(scale == 1 and "%d%s" or "%.1f%s", i / scale, unit)) end
  return choices
end
function S.new(key, config, onSave, onClose)
  local cached, cachedIndex
  local pages = setmetatable({}, {
    __len = function() return 10 end,
    __index = function(_, index)
      if type(index) ~= "number" or index < 1 or index > 10 then return nil end
      if cachedIndex ~= index then
        cached = assert(loadScript("/WIDGETS/DLGDash/settings-pages.lua"))(index, P, option, field, numberChoices, fromValues)
        cachedIndex = index
        if LCD_H == 64 and collectgarbage then collectgarbage("collect") end
      end
      return cached
    end,
    __ipairs = function(t)
      return function(_, i) i = i + 1; if i <= 10 then return i, t[i] end end, t, 0
    end
  })
  local _, name = P.identity()
  return { key = key, modelName = name, config = P.copy(config), onSave = onSave, onClose = onClose,
    page = 1, focus = 1, pages = pages, dirty = false }
end
local function eventIs(event, name) return event ~= nil and _G[name] ~= nil and event == _G[name] end
local function indexOf(choices, value)
  if choices.selectedIndex then return choices.selectedIndex end
  if getmetatable(choices) == numericChoices then
    local index = (value - choices.first) / choices.step + 1
    return index >= 1 and index <= #choices and index == math.floor(index) and index or 1
  end
  for i, entry in ipairs(choices) do if entry.value == value then return i end end
  return 1
end
local function choicesFor(s, row)
  if type(row.choices) == "table" then return row.choices end
  -- A picker owns its source list; closing it releases the list for GC.
  return P.sourceList(row.choices, s.config[row.key])
end
local function rowLabel(s, row)
  if row.key == "period" then
    return string.format("%.1fs / %.2fs", s.config.period / 100, math.max(s.config.period, math.ceil(s.config.window * 100 / 120)) / 100)
  end
  if type(row.choices) == "string" then
    local value = s.config[row.key]
    if value == "" then return "None" end
    local current = P.field(value)
    return current and current.name or value .. " (missing)"
  end
  local choices = choicesFor(s, row)
  return choices[indexOf(choices, s.config[row.key])].label
end
local function voltageText(source)
  local value, current = P.api.value(source)
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
  if s.probeTick and (now - s.probeTick) % 2147483648 < Diagnostics.period then return Diagnostics end
  s.probeTick = now
  s.probe = Diagnostics.sample(s.config)
  if s.recording then
    if P.identity() ~= s.key then s.recording = nil; s.message = "Model changed"; return Diagnostics end
    s.recording[#s.recording + 1] = Diagnostics.row(s.probe, s.config)
    s.message = "REC " .. #s.recording .. "/" .. Diagnostics.count
    if #s.recording == Diagnostics.count then
      local ok, result = Diagnostics.save(s.key, s.recording)
      s.recording = nil
      s.message = ok and "Record saved" or result
      s.recordPath = ok and result or nil
    end
  end
  return Diagnostics
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
local renderer = LCD_H == 64 and "mono-settings.lua" or "color-settings.lua"
return assert(loadScript("/WIDGETS/DLGDash/" .. renderer))(S, D, {
  eventIs = eventIs, open = open, choose = choose, changePage = changePage,
  rowLabel = rowLabel, activate = activate, leave = leave, diagnostics = diagnostics,
  voltageText = voltageText, field = P.field
})
