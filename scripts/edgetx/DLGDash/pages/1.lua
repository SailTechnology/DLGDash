local P, option, field = ...
return { title = "BATTERY", fields = {
  field("voltage", "Voltage source", "voltage"),
  field("cells", "Pack cells", { option(0, "Auto 1S / 2S"), option(1, "1S"), option(2, "2S") }),
  field("chemistry", "Battery type", { option(0, "Auto (HV uncertain)"), option(1, "LiPo 4.20V"), option(2, "HV 4.35V") }) } }
