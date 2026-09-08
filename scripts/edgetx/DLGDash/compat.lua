-- Keep compatibility local to this plugin; never replace firmware globals.
local A = { value = getSourceValue, output = getOutputValue }
-- Some small-radio builds omit the optional table library entirely.
A.concat = table and table.concat or function(values, separator)
  local text = ""
  for i = 1, #values do text = text .. (i == 1 and "" or separator) .. values[i] end
  return text
end
A.sort = table and table.sort or function(values)
  for i = 2, #values do
    local value, j = values[i], i - 1
    while j > 0 and values[j] > value do values[j + 1] = values[j]; j = j - 1 end
    values[j + 1] = value
  end
end
local _, _, major, minor = getVersion()
A.toneVolume = type(major) == "number" and type(minor) == "number"
  and (major > 2 or major == 2 and minor >= 10)
A.legacy = not getSourceValue
A.mixedOutputs = not getOutputValue
if not A.value then
  function A.value(source, field)
    field = field or getFieldInfo(source)
    if not field then return nil, false, false end
    -- 2.7 exposes link validity, but no individual sensor age/validity flag.
    -- Do not infer packet age from an unchanged value: level flight is valid.
    if field.unit ~= nil and (not getRSSI or getRSSI() <= 0) then return nil, false, false end
    local value = getValue(field.id)
    return value, value ~= nil, false
  end
end
if not A.output then
  function A.output(index)
    -- Old getValue(CHn) is BEFORE limits/reverse, not the final servo output.
    return (getValue("ch" .. (index + 1)))
  end
end
return A
