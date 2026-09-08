local P, option, field, numberChoices, fromValues = ...
return { title = "TONE SETTINGS", fields = {
  field("toneVolume", "Tone volume", P.api.toneVolume and { option(0, "Follow radio"), option(-1, "MUTE"),
    option(1, "1 / 5"), option(2, "2 / 5"), option(3, "3 / 5"), option(4, "4 / 5"), option(5, "5 / 5") }
    or { option(0, "Follow radio"), option(-1, "MUTE") }),
  field("climbTone", "Climb base pitch", fromValues({ 600, 720, 900, 1100, 1400 }, 1, "Hz")),
  field("sinkTone", "Sink base pitch", fromValues({ 250, 320, 390, 460, 550 }, 1, "Hz")),
  field("toneRate", "Beep cadence", { option(60, "Slow"), option(100, "Normal"), option(160, "Fast") }) } }
