-- Read-only voltage probes. Recording is explicitly started in the settings page.
local P = ...
local T = { directory = "/WIDGETS/DLGDash/diagnostics/", count = 24, period = 25 }
local header = "tick_cs,firmware,model,selection,selected_id,selected_name,selected_display,selected_unit,selected_value,selected_current,selected_fresh,selected_legacy,selected_centi,rxbt_id,rxbt_name,rxbt_unit,rxbt_by_name,rxbt_current,rxbt_fresh,rxbt_by_id,rxbt_id_current,rxbt_id_fresh,rxbt_legacy,rxbt_centi,rxbt_min,rxbt_max,tx_voltage"
local function number(value)
  if type(value) == "table" then
    local sum = 0
    for _, v in ipairs(value) do if type(v) ~= "number" then return nil end; sum = sum + v end
    value = sum
  end
  return type(value) == "number" and value == value and math.abs(value) < 1000000 and value or nil
end
local function probe(request)
  if not request then return { current = false, fresh = false } end
  local value, current, fresh = getSourceValue(request)
  return { value = number(value), current = current == true, fresh = fresh == true }
end
function T.voltage(probeValue)
  if not probeValue or not probeValue.current or not probeValue.value then return "--.--V" end
  return string.format("%.2fV", probeValue.value)
end
function T.sample(config)
  local selected = P.field(config.voltage)
  local named = getFieldInfo("RxBt")
  local s = { selectedField = selected, namedField = named, tick = getTime(),
    selected = probe(selected and selected.id), named = probe("RxBt"),
    byId = probe(named and named.id), minimum = probe("RxBt-"), maximum = probe("RxBt+"), tx = probe("tx-voltage") }
  s.selectedLegacy = selected and number(getValue(selected.id)) or nil
  s.namedLegacy = named and number(getValue(named.id)) or nil
  s.display = selected and getSourceName and getSourceName(selected.id) or ""
  return s
end
local function csv(value)
  return '"' .. string.gsub(value == nil and "" or tostring(value), '"', '""') .. '"'
end
local function centi(value) return value and math.floor(value * 100 + 0.5) or "" end
function T.row(s, config)
  local a, b = s.selectedField or {}, s.namedField or {}
  local _, name = P.identity()
  local fields = { s.tick, getVersion(), name, config.voltage, a.id or "", a.name or "", s.display,
    a.unit or "", s.selected.value or "", s.selected.current, s.selected.fresh, s.selectedLegacy or "", centi(s.selected.value),
    b.id or "", b.name or "", b.unit or "", s.named.value or "", s.named.current, s.named.fresh,
    s.byId.value or "", s.byId.current, s.byId.fresh, s.namedLegacy or "", centi(s.named.value),
    s.minimum.value or "", s.maximum.value or "", s.tx.value or "" }
  for i, value in ipairs(fields) do fields[i] = csv(value) end
  return table.concat(fields, ",")
end
function T.save(key, rows)
  if not key or #rows ~= T.count then return false, "Incomplete record" end
  if mkdir then mkdir(T.directory) end
  local path
  for i = 0, 99 do
    local candidate = T.directory .. key .. "_" .. getTime() .. "_" .. i .. ".csv"
    local existing = io.open(candidate, "r")
    if existing then io.close(existing) else path = candidate; break end
  end
  if not path then return false, "SD write failed" end
  local text = header .. "\n" .. table.concat(rows, "\n") .. "\n"
  local f = io.open(path, "w")
  if not f then return false, "SD write failed" end
  local ok = pcall(io.write, f, text)
  io.close(f)
  if not ok then return false, "SD write failed" end
  f = io.open(path, "r")
  if not f then return false, "SD verify failed" end
  for offset = 1, #text, 512 do
    local expected = string.sub(text, offset, offset + 511)
    local readOK, actual = pcall(io.read, f, #expected)
    if not readOK or actual ~= expected then io.close(f); return false, "SD verify failed" end
  end
  io.close(f)
  return true, path
end
return T
