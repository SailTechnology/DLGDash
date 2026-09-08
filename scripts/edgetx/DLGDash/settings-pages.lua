-- Compatibility entry for older callers; compile only the requested page.
local page, P, option, field, numberChoices, fromValues = ...
if type(page) ~= "number" or page < 1 or page > 10 or page ~= math.floor(page) then return nil end
return assert(loadScript("/WIDGETS/DLGDash/pages/" .. page .. ".lua"))(P, option, field, numberChoices, fromValues)
