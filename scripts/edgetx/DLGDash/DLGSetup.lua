-- Standalone entry: /SCRIPTS/TOOLS/DLGSetup.lua
-- TNS|DLG Setup|TNE
local editor, settings, done
local function init()
  local root = "/WIDGETS/DLGDash/"
  local profile = assert(loadScript(root .. "profile.lua"))()
  local draw = assert(loadScript(root .. (LCD_H == 64 and "mono-ui.lua" or "draw.lua")))()
  settings = assert(loadScript(root .. "settings.lua"))(profile, draw)
  local key = profile.identity()
  local config = profile.load(key) or profile.defaults()
  done = false
  editor = settings.new(key, config, function() end, function() done = true end)
end
local function run(event, touch)
  if not editor then init() end
  settings.run(editor, event, touch, LCD_W, LCD_H)
  return done and 2 or 0
end
return { name = "DLG Setup", init = init, run = run }
