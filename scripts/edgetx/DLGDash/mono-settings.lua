-- Reuse the color settings controller and choices; only navigation/layout differ.
local S, D, H = ...
-- Invert after drawing so native text and Chinese pixmaps share one focus bar.
local function highlight(x, y, w, h)
  if lcd.drawFilledRectangle then lcd.drawFilledRectangle(x, y, w, h, 0)
  else lcd.drawRectangle(x, y, w, h) end
end
function S.run(s, event)
  local function is(code) return H.eventIs(event, code) end
  local next = is(EVT_VIRTUAL_NEXT) or is(EVT_VIRTUAL_INC)
  local prev = is(EVT_VIRTUAL_PREV) or is(EVT_VIRTUAL_DEC)
  local enter, exit = is(EVT_VIRTUAL_ENTER), is(EVT_VIRTUAL_EXIT)
  local fields = s.pages[s.page].fields
  if s.picker then
    local p = s.picker
    if next then p.index = math.min(#p.choices, p.index + 1) end
    if prev then p.index = math.max(1, p.index - 1) end
    if enter then H.choose(s) elseif exit then s.picker = nil end
  else
    if next then s.focus = s.focus % (#fields + 4) + 1; s.confirmDiscard = false end
    if prev then s.focus = (s.focus - 2) % (#fields + 4) + 1; s.confirmDiscard = false end
    if is(EVT_VIRTUAL_NEXT_PAGE) then H.changePage(s, 1) end
    if is(EVT_VIRTUAL_PREV_PAGE) then H.changePage(s, -1) end
    if enter then H.activate(s) elseif exit then H.leave(s) end
  end
  fields = nil
  fields = s.pages[s.page].fields
  D.language(s.config.language)
  lcd.clear()
  if s.savedThisFrame then s.savedThisFrame = nil; D.text(s.message, 1, 20, LCD_W - 2); return end
  local page = s.pages[s.page]
  D.text(s.picker and s.picker.row.label or page.title, 1, 0, LCD_W - 44)
  D.text((s.dirty and "*" or "") .. s.page .. "/10", LCD_W - 42, 0, 42, false, false)
  if s.picker then
    local p = s.picker
    local start = math.max(1, math.min(p.index, #p.choices - 1))
    for row = 0, 1 do
      local index = start + row
      if p.choices[index] then
        if index == p.index then D.text(">", 0, 17 + row * 16, 6, false, false) end
        D.text(p.choices[index].label, 7, 17 + row * 16, LCD_W - 8)
        if index == p.index then highlight(0, 16 + row * 16, LCD_W, 16) end
      end
    end
  elseif page.diagnostic then
    H.diagnostics(s)
    local p = s.probe
    D.text("SRC " .. H.voltageText((p.selectedField or {}).id or 0), 0, 16, LCD_W, false, false)
    D.text("RxBt " .. H.voltageText("RxBt"), 0, 26, LCD_W, false, false)
    D.text("ID " .. tostring((p.namedField or {}).id or "--"), 0, 36, LCD_W, false, false)
  else
    local index = math.min(s.focus, #fields)
    local row = fields[index]
    if row then
      D.text(row.label, 9, 17, LCD_W - 38)
      D.text(s.message or H.rowLabel(s, row), 1, 33, LCD_W - 2)
      if s.focus <= #fields then
        D.text(">", 0, 17, 6, false, false)
        D.text(index .. "/" .. #fields, LCD_W - 24, 17, 24, false, false)
        highlight(0, 16, LCD_W, 16)
      end
    end
    if s.page == 1 and row and row.key == "voltage" and not s.message then
      local f = H.field(s.config.voltage)
      D.text(H.voltageText(f and f.id or 0), 0, 42, LCD_W - 30, false, false)
    end
  end
  if s.message and page.diagnostic and not s.picker then D.text(s.message, 0, 43, LCD_W, false, false) end
  local labels = s.picker and { "^", "v", "OK", "Back" } or { "<", ">", page.diagnostic and "Record" or "Save", "Exit" }
  for i, label in ipairs(labels) do
    local width = math.floor(LCD_W / 4)
    local x = (i - 1) * width
    D.text(label, x + 1, 50, width - 2)
    if not s.picker and s.focus == #fields + i then highlight(x, 49, width - 1, 15) end
  end
end
return S
