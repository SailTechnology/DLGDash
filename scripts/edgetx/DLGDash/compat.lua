-- Keep compatibility local to this plugin; never replace firmware globals.
local A = { value = getSourceValue, output = getOutputValue }
local _, _, major, minor = getVersion()
A.toneVolume = type(major) == "number" and type(minor) == "number"
  and (major > 2 or major == 2 and minor >= 11)
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
    return getValue("ch" .. (index + 1))
  end
end
return A
