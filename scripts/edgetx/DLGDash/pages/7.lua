local P, option, field, numberChoices = ...
return { title = "AUDIO", fields = {
  field("toneSource", "Switch / button", "switch"),
  field("tonePosition", "Active position", { option(-1, "Low (-100)"), option(0, "Middle (0)"), option(1, "High (+100)") }),
  field("toneMode", "Button behavior", { option(0, "While active"), option(1, "Press to toggle") }),
  field("deadband", "Vario deadband", numberChoices(1, 20, 1, 10, "m/s")) } }
