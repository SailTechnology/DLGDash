-- Construct one page at a time; the loader can release all unused labels.
local page, P, option, field, numberChoices, fromValues = ...
local modes, channels
if page == 3 then
  modes = { option(-1, "None") }
  for i = 0, 8 do
    local _, name = getFlightMode(i)
    modes[#modes + 1] = option(i, "FM" .. i .. " " .. ((name and name ~= "") and name or "(unnamed)"))
  end
elseif page == 4 or page == 5 then
  channels = { option(0, "Off") }
  for i = 1, 32 do
    local output = model.getOutput(i - 1) or {}
    channels[#channels + 1] = option(i, "CH" .. i .. (output.name and output.name ~= "" and " " .. output.name or ""))
  end
end
if page == 1 then
  return { title = "BATTERY", fields = {
    field("voltage", "Voltage source", "voltage"),
    field("cells", "Pack cells", { option(0, "Auto 1S / 2S"), option(1, "1S"), option(2, "2S") }),
    field("chemistry", "Battery type", { option(0, "Auto (HV uncertain)"), option(1, "LiPo 4.20V"), option(2, "HV 4.35V") }) } }
elseif page == 2 then
  return { title = "TELEMETRY", fields = {
    field("altitude", "Altitude source", "altitude"), field("vario", "Vario source", "vario"),
    field("timer", "Timer display", { option(1, "Timer 1"), option(2, "Timer 2"), option(3, "Timer 3") }),
    field("smoothing", "Curve smoothing", { option(0, "Off"), option(3, "0.3s"), option(5, "0.5s"),
      option(10, "1.0s"), option(20, "2.0s"), option(30, "3.0s") }) } }
elseif page == 3 then
  return { title = "LAUNCH", fields = {
    field("launchMode", "Exit this mode", modes),
    field("delay", "Delay after exit", numberChoices(0, 100, 1, 10, "s")),
    field("settle", "Height result", { option(0, "At end of delay"), option(1, "Peak: mode + delay") }) } }
elseif page == 4 then
  return { title = "SERVOS 1", fields = {
    field("servos", "Servo version", { option(4, "4 servos"), option(6, "6 servos") }),
    field("ch1", "LA / Left aileron", channels), field("ch2", "RA / Right aileron", channels) } }
elseif page == 5 then
  return { title = "SERVOS 2", fields = {
    field("ch3", "ELE / Elevator", channels), field("ch4", "RUD / Rudder", channels),
    field("ch5", "LF / Left flap", channels), field("ch6", "RF / Right flap", channels) } }
elseif page == 6 then
  return { title = "GRAPH", fields = {
    field("window", "Time window", fromValues(P.windows, 1, "s")),
    field("period", "Sample / effective", fromValues(P.periods, 100, "s")),
    field("resetSource", "Preset / clear button", "switch"),
    field("resetPosition", "Clear position", { option(-1, "Low (-100)"), option(0, "Middle (0)"), option(1, "High (+100)") }) } }
elseif page == 7 then
  return { title = "AUDIO", fields = {
    field("toneSource", "Switch / button", "switch"),
    field("tonePosition", "Active position", { option(-1, "Low (-100)"), option(0, "Middle (0)"), option(1, "High (+100)") }),
    field("toneMode", "Button behavior", { option(0, "While active"), option(1, "Press to toggle") }),
    field("deadband", "Vario deadband", numberChoices(1, 20, 1, 10, "m/s")) } }
elseif page == 8 then
  return { title = "TONE SETTINGS", fields = {
    field("toneVolume", "Tone volume", P.api.toneVolume and { option(0, "Follow radio"), option(-1, "MUTE"),
      option(1, "1 / 5"), option(2, "2 / 5"), option(3, "3 / 5"), option(4, "4 / 5"), option(5, "5 / 5") }
      or { option(0, "Follow radio"), option(-1, "MUTE") }),
    field("climbTone", "Climb base pitch", fromValues({ 600, 720, 900, 1100, 1400 }, 1, "Hz")),
    field("sinkTone", "Sink base pitch", fromValues({ 250, 320, 390, 460, 550 }, 1, "Hz")),
    field("toneRate", "Beep cadence", { option(60, "Slow"), option(100, "Normal"), option(160, "Fast") }) } }
elseif page == 9 then
  return { title = "LANGUAGE", fields = {
    field("language", "Language", { option(0, "English"), option(1, "Chinese") }) } }
elseif page == 10 then
  return { title = "VOLTAGE CHECK", diagnostic = true, fields = {} }
end
