-- Per-radio/model settings. Never writes EdgeTX model or radio configuration.
local P = { directory = "/WIDGETS/DLGDash/profiles/", schema = 5 }
P.api = assert(loadScript("/WIDGETS/DLGDash/compat.lua"))()
P.roles = { "LA", "RA", "ELE", "RUD", "LF", "RF" }
P.windows = { 30, 60, 90, 120, 180, 300, 600 }
P.periods = { 10, 20, 50, 100, 200, 500 }
P.fields = {
  voltage = { "RxBt" }, altitude = { "Alt" }, vario = { "VSpd" },
  cells = { 0, 0, 2 }, chemistry = { 0, 0, 2 }, timer = { 1, 1, 3 },
  servos = { 4, 4, 6 }, launchMode = { -1, -1, 8 }, delay = { 0, 0, 100 },
  settle = { 0, 0, 1 }, window = { 90, 30, 600 }, period = { 100, 10, 500 },
  toneSource = { "SF" }, tonePosition = { 1, -1, 1 }, toneMode = { 0, 0, 1 },
  deadband = { 3, 1, 20 }, resetSource = { "SE" }, resetPosition = { 1, -1, 1 },
  language = { 0, 0, 1 }, smoothing = { 5, 0, 30 },
  toneVolume = { 0, -1, 5 }, climbTone = { 720, 600, 1400 },
  sinkTone = { 390, 250, 550 }, toneRate = { 100, 60, 160 }
}
for i = 1, 6 do P.fields["ch" .. i] = { i, 0, 32 } end

function P.copy(value)
  local result = {}
  for k, v in pairs(value) do result[k] = v end
  return result
end

function P.defaults()
  local config = {}
  for key, rule in pairs(P.fields) do config[key] = rule[1] end
  local _, radio = getVersion()
  if radio ~= "pa01" then config.toneSource, config.resetSource = "", "" end
  for i = 0, 8 do
    local _, name = getFlightMode(i)
    if name and string.find(string.lower(name), "zoom", 1, true) then config.launchMode = i; break end
  end
  return config
end

local function escaped(value)
  -- EdgeTX can omit LUA_ENABLE_STRLIB_MT; call the string library explicitly.
  return (string.gsub(tostring(value), "[^%w%-]", function(c) return (string.format("_%02X", string.byte(c))) end))
end

function P.identity()
  local info = model.getInfo() or {}
  local _, radio = getVersion()
  -- Do not fall back to display name: two models can have the same name.
  if not info.filename or info.filename == "" then return nil, "Model filename unavailable" end
  return escaped(radio or "unknown") .. "_" .. escaped(info.filename), info.name or info.filename
end

function P.validate(config)
  for key, rule in pairs(P.fields) do
    local v = config[key]
    if type(rule[1]) == "string" then
      if type(v) ~= "string" or #v > 32 or string.find(v, "[%z\r\n]") then return false end
    elseif type(v) ~= "number" or v ~= math.floor(v) or v < rule[2] or v > rule[3] then
      return false
    end
  end
  return config.servos == 4 or config.servos == 6
end

local function checksum(text)
  local a, b, i = 1, 0, 1
  -- Eight-byte Adler blocks keep SD validation inside PA01's 20k callback budget.
  while i + 7 <= #text do
    local p, q, r, s, t, u, v, w = string.byte(text, i, i + 7)
    b = (b + 8 * a + 8 * p + 7 * q + 6 * r + 5 * s + 4 * t + 3 * u + 2 * v + w) % 65521
    a = (a + p + q + r + s + t + u + v + w) % 65521
    i = i + 8
  end
  for j = i, #text do a = (a + string.byte(text, j)) % 65521; b = (b + a) % 65521 end
  return (string.format("%04x%04x", b, a))
end

-- Table replacements avoid a Lua callback per byte during verified two-slot saves.
local byteHex, hexByte = {}, {}
if LCD_H == 64 then
  -- Small radios only retain the bytes actually present in their profiles.
  setmetatable(byteHex, { __index = function(t, char)
    local code = string.format("%02x", string.byte(char))
    t[char] = code
    return code
  end })
  setmetatable(hexByte, { __index = function(t, code)
    local char = string.char(tonumber(code, 16))
    t[code] = char
    return char
  end })
else
  for i = 0, 255 do
    local char, code = string.char(i), string.format("%02x", i)
    byteHex[char], hexByte[code] = code, char
  end
end
local function hex(text) return (string.gsub(text, ".", byteHex)) end

local function unhex(text)
  if #text % 2 ~= 0 or string.find(text, "[^%da-f]") then return nil end
  return (string.gsub(text, "..", hexByte))
end

function P.encode(config, key, revision)
  local keys, lines = {}, { "DLG5", "id=" .. key, "rev=" .. revision }
  for k in pairs(P.fields) do keys[#keys + 1] = k end
  table.sort(keys)
  for _, k in ipairs(keys) do
    lines[#lines + 1] = k .. "=" .. (type(config[k]) == "string" and hex(config[k]) or tostring(config[k]))
  end
  local body = table.concat(lines, "\n") .. "\n"
  return body .. "sum=" .. checksum(body) .. "\n"
end

function P.decode(text, key)
  if type(text) ~= "string" or #text > 2048 then return nil end
  local body, sum = string.match(text, "^(DLG[2345]\n.*\n)sum=(%x+)\n$")
  if not body then return nil end
  local version = tonumber(string.sub(body, 4, 4))
  local found, seen = {}, {}
  local identity, revision
  for k, v in string.gmatch(body, "([%w]+)=([^\n]*)\n") do
    if seen[k] then return nil end
    seen[k] = true
    if k == "id" then identity = v; if identity ~= key then return nil end
    elseif k == "rev" then revision = tonumber(v)
    elseif P.fields[k] then
      if #v > 64 then return nil end
      found[k] = type(P.fields[k][1]) == "string" and unhex(v) or tonumber(v)
    else return nil end
  end
  -- Migrate only newly introduced fields; never discard the user's mappings.
  if version == 2 then
    for _, k in ipairs({ "resetSource", "resetPosition", "language" }) do
      if found[k] == nil then found[k] = P.fields[k][1] end
    end
  end
  if version < 4 and found.smoothing == nil then found.smoothing = P.fields.smoothing[1] end
  if version < 5 then
    for _, k in ipairs({ "toneVolume", "climbTone", "sinkTone", "toneRate" }) do
      if found[k] == nil then found[k] = P.fields[k][1] end
    end
  end
  if identity ~= key or not revision or revision < 1 or revision ~= math.floor(revision) or not P.validate(found) then return nil end
  if checksum(body) ~= sum then return nil end
  return found, revision
end

local function read(path)
  local f = io.open(path, "r")
  if not f then return nil end
  local ok, value = pcall(io.read, f, 4096)
  io.close(f)
  return ok and value or nil
end

function P.load(key)
  if not key then return nil, 0 end
  local a, ar = P.decode(read(P.directory .. key .. ".a"), key)
  local b, br = P.decode(read(P.directory .. key .. ".b"), key)
  if b and (not a or br > ar) then return b, br, "b" end
  return a, ar or 0, a and "a" or nil
end

function P.stamp(key)
  if not key or not fstat then return "" end
  local parts = {}
  for _, slot in ipairs({ ".a", ".b" }) do
    local stat = fstat(P.directory .. key .. slot)
    local t = stat and stat.time or {}
    parts[#parts + 1] = stat and table.concat({ stat.size, t.year or 0, t.mon or 0, t.day or 0,
      t.hour or 0, t.min or 0, t.sec or 0 }, ":") or "-"
  end
  return (table.concat(parts, "|"))
end

function P.save(key, config)
  if not key or not P.validate(config) then return false, "Invalid profile" end
  if mkdir then mkdir(P.directory) end
  local _, revision, slot = P.load(key)
  local path = P.directory .. key .. (slot == "a" and ".b" or ".a")
  local text = P.encode(config, key, revision + 1)
  -- Alternate slots and verify after close. A failed write leaves the last good slot intact.
  local f = io.open(path, "w")
  if not f then return false, "SD write failed" end
  local ok = pcall(io.write, f, text)
  io.close(f)
  if not ok or read(path) ~= text then return false, "SD verify failed" end
  return true, revision + 1
end

local sourceChoices = {
  __len = function(t) return #t.names end,
  __index = function(t, index)
    if type(index) ~= "number" or index < 1 or index > #t.names then return nil end
    local name = t.names[index]
    return { value = index == t.selectedIndex and t.selectedValue or name,
      label = index == 1 and "None" or name, id = t.ids[index] }
  end,
  __ipairs = function(t)
    return function(_, i) i = i + 1; if i <= #t then return i, t[i] end end, t, 0
  end
}
function P.sourceList(kind, selected)
  -- Compact columns avoid hundreds of permanently allocated option tables.
  local list = setmetatable({ names = { "" }, ids = {}, selectedValue = selected,
    selectedIndex = selected == "" and 1 or nil }, sourceChoices)
  if not sources then return list end
  local current = P.field(selected)
  for id, name in sources() do
    local info = getFieldInfo(id)
    local unit = info and info.unit
    local allowed = kind == "switch" and (not unit) or kind == "all"
    if kind == "voltage" then allowed = unit == UNIT_VOLTS or unit == UNIT_CELLS end
    if kind == "altitude" then allowed = unit == UNIT_METERS or unit == UNIT_FEET end
    if kind == "vario" then allowed = unit == UNIT_METERS_PER_SECOND or unit == UNIT_FEET_PER_SECOND end
    -- A live telemetry selector must not offer historical minima or maxima.
    if allowed and unit and info.name then
      local suffix = string.sub(info.name, -1)
      if suffix == "+" or suffix == "-" then
        local base = getFieldInfo(string.sub(info.name, 1, -2))
        if base and info.id == base.id + (suffix == "+" and 2 or 1) then allowed = false end
      end
    end
    if allowed and name and name ~= "" then
      local index = #list.names + 1
      list.names[index], list.ids[index] = name, id
      if selected == name or current and current.id == id then list.selectedIndex = index end
    end
  end
  if selected and not list.selectedIndex then
    list.selectedIndex = #list.names + 1
    list.names[list.selectedIndex] = selected .. " (missing)"
  end
  return list
end

function P.field(name)
  if not name or name == "" then return nil end
  local field = getFieldInfo(name) or getFieldInfo(string.lower(name))
  if field then return field end
  if getSourceIndex then
    local id = getSourceIndex(name)
    return id and id > 0 and getFieldInfo(id) or nil
  end
  if sources then
    for id, label in sources() do if label == name then return (getFieldInfo(id)) end end
  end
end

return P
