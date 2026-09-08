local P, option, field = ...
return { title = "TELEMETRY", fields = {
  field("altitude", "Altitude source", "altitude"), field("vario", "Vario source", "vario"),
  field("timer", "Timer display", { option(1, "Timer 1"), option(2, "Timer 2"), option(3, "Timer 3") }),
  field("smoothing", "Curve smoothing", { option(0, "Off"), option(3, "0.3s"), option(5, "0.5s"),
    option(10, "1.0s"), option(20, "2.0s"), option(30, "3.0s") }) } }
