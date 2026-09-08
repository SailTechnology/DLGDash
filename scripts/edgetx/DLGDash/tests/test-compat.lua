local count = 0
local function eq(a, b) count = count + 1; assert(a == b, tostring(a) .. " != " .. tostring(b)) end
for _, minor in ipairs({ 7, 8, 9, 10, 11 }) do
  local link, current, voltage, altitude = true, true, 8.1, 0
  function getVersion() return "2." .. minor, "zorro", 2, minor, 1 end
  function getFieldInfo(source)
    if source == "RxBt" or source == 301 then return { id = 301, unit = 1 } end
    if source == "Alt" or source == 304 then return { id = 304, unit = 9 } end
    if source == "SA" or source == 5 then return { id = 5 } end
  end
  function getValue(source)
    if source == 301 then return voltage end
    if source == 304 then return altitude end
    if source == 5 then return -1024 end
    if source == "ch1" then return 512 end
    return 0
  end
  function getRSSI() return link and 90 or 0 end
  if minor >= 10 then
    function getSourceValue(source)
      local field = getFieldInfo(source)
      if not field then return nil, false, false end
      return getValue(field.id), not field.unit or link and current, false
    end
    function getOutputValue() return -256 end
  else getSourceValue, getOutputValue = nil, nil end
  local savedGlobal = getSourceValue
  local A = assert(loadScript("/WIDGETS/DLGDash/compat.lua"))()
  eq(getSourceValue, savedGlobal)
  eq(A.legacy, minor < 10); eq(A.mixedOutputs, minor < 10)
  eq(A.toneVolume, minor >= 10)
  eq(A.output(0), minor >= 10 and -256 or 512)
  local value, valid, fresh = A.value(301)
  eq(value, 8.1); eq(valid, true); eq(fresh, false)
  value, valid = A.value(304)
  eq(value, 0); eq(valid, true)
  eq(A.value("missing"), nil)
  link = false
  value, valid = A.value(301)
  eq(valid, false)
  value, valid = A.value(5)
  eq(value, -1024); eq(valid, true)
  link, current = true, false
  value, valid = A.value(304)
  eq(valid, minor < 10) -- Missing modern APIs cannot expose individual sensor expiry.
end
Bitmap, lcd = {}, {}
local locale = assert(loadScript("/WIDGETS/DLGDash/locale.lua"))()
eq(locale.draw("BATTERY"), false)
print("PASS compatibility: " .. count .. " assertions, EdgeTX 2.7-2.11 capability cases")
