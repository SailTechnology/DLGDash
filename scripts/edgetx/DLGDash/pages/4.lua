local P, option, field = ...
local channels = { option(0, "Off") }
for i = 1, 32 do
  local output = model.getOutput(i - 1) or {}
  channels[#channels + 1] = option(i, "CH" .. i .. (output.name and output.name ~= "" and " " .. output.name or ""))
end
return { title = "SERVOS 1", fields = {
  field("servos", "Servo version", { option(4, "4 servos"), option(6, "6 servos") }),
  field("ch1", "LA / Left aileron", channels), field("ch2", "RA / Right aileron", channels) } }
