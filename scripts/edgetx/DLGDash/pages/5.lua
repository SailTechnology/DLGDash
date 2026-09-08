local P, option, field = ...
local channels = { option(0, "Off") }
for i = 1, 32 do
  local output = model.getOutput(i - 1) or {}
  channels[#channels + 1] = option(i, "CH" .. i .. (output.name and output.name ~= "" and " " .. output.name or ""))
end
return { title = "SERVOS 2", fields = {
  field("ch3", "ELE / Elevator", channels), field("ch4", "RUD / Rudder", channels),
  field("ch5", "LF / Left flap", channels), field("ch6", "RF / Right flap", channels) } }
