-- Color-only renderer; never compiled on memory-constrained monochrome radios.
local S, D, H = ...
local c = D.colors
local eventIs, choose, changePage = H.eventIs, H.choose, H.changePage
local activate, leave, open = H.activate, H.leave, H.open
local rowLabel, voltageText = H.rowLabel, H.voltageText
local P = { field = H.field }
local function tapped(touch) return touch and (touch.tapCount and touch.tapCount > 0) end
local function drawDiagnostics(s, w, top, rowH, labelH)
  local Diagnostics = H.diagnostics(s)
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
function S.run(s, event, touch, w, h)
  local fields = s.pages[s.page].fields
  local nextEvent = eventIs(event, EVT_VIRTUAL_NEXT) or eventIs(event, EVT_VIRTUAL_INC)
  local prevEvent = eventIs(event, EVT_VIRTUAL_PREV) or eventIs(event, EVT_VIRTUAL_DEC)
  local enter, exit = eventIs(event, EVT_VIRTUAL_ENTER), eventIs(event, EVT_VIRTUAL_EXIT)
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
    if eventIs(event, EVT_VIRTUAL_NEXT_PAGE) then changePage(s, 1) end
    if eventIs(event, EVT_VIRTUAL_PREV_PAGE) then changePage(s, -1) end
    if enter then activate(s) end
    if exit then leave(s) end
    if tapped(touch) then
      if touch.y >= top and touch.y < top + rowH * #fields then
        s.focus = math.floor((touch.y - top) / rowH) + 1; open(s, fields[s.focus])
      elseif touch.y >= footer then s.focus = #fields + 1 + math.min(3, math.floor(touch.x / (w / 4))); activate(s) end
    end
  end
  fields = nil
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
return S
