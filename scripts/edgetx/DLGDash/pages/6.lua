local P, option, field, numberChoices, fromValues = ...
return { title = "GRAPH", fields = {
  field("window", "Time window", fromValues(P.windows, 1, "s")),
  field("period", "Sample / effective", fromValues(P.periods, 100, "s")),
  field("resetSource", "Preset / clear button", "switch"),
  field("resetPosition", "Clear position", { option(-1, "Low (-100)"), option(0, "Middle (0)"), option(1, "High (+100)") }) } }
