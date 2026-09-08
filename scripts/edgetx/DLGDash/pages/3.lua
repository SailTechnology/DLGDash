local P, option, field, numberChoices = ...
local modes = { option(-1, "None") }
for i = 0, 8 do
  local _, name = getFlightMode(i)
  modes[#modes + 1] = option(i, "FM" .. i .. " " .. ((name and name ~= "") and name or "(unnamed)"))
end
return { title = "LAUNCH", fields = {
  field("launchMode", "Exit this mode", modes),
  field("delay", "Delay after exit", numberChoices(0, 100, 1, 10, "s")),
  field("settle", "Height result", { option(0, "At end of delay"), option(1, "Peak: mode + delay") }) } }
