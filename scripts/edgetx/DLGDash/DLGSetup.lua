-- Standalone entry: /SCRIPTS/TOOLS/DLGSetup.lua
-- TNS|DLG Setup|TNE
local editor, settings, done, unavailable
local function init()
  -- Check before compiling the settings/profile modules on older radios.
  if not getValue or not getFieldInfo or not sources then
    unavailable = true
    return
  end
  local root = "/WIDGETS/DLGDash/"
  local profile = assert(loadScript(root .. "profile.lua"))()
  if LCD_H == 64 and collectgarbage then collectgarbage("collect") end
  local draw = assert(loadScript(root .. (LCD_H == 64 and "mono-ui.lua" or "draw.lua")))()
  settings = assert(loadScript(root .. "settings.lua"))(profile, draw)
  local key = profile.identity()
  local config = profile.load(key) or profile.defaults()
  done = false
  editor = settings.new(key, config, function() end, function() done = true end)
end
local function run(event, touch)
  if not editor and not unavailable then init() end
  if unavailable then
    lcd.clear()
    lcd.drawText(1, 12, "Lua APIs", FIXEDWIDTH or 0)
    lcd.drawText(1, 26, "missing", FIXEDWIDTH or 0)
    lcd.drawText(1, 48, "EXIT: close", FIXEDWIDTH or 0)
    return event == EVT_VIRTUAL_EXIT and 2 or 0
  end
  settings.run(editor, event, touch, LCD_W, LCD_H)
  return done and 2 or 0
end
return { name = "DLG Setup", init = init, run = run }
