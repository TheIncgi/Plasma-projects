print"Loading Screen (build 6)"

require"TheIncgi/Plasma-projects/main/libs/class"
local Json = require"TheIncgi/Plasma-projects/main/libs/Json"

print"Create Screen class"
local Screen = class("TheIncgi/Plasma-projects/IK-Arm/IK-Arm/screens/Screen")

Screen.WIDTH = 680
Screen.HEIGHT = 512
Screen.TOP = HEIGHT
Screen.BOTTOM = 0
Screen.LEFT = 0
Screen.RIGHT = WIDTH

Screen.LEFT_DIR   = (LEFT < RIGHT) and -1 or  1
Screen.RIGHT_DIR  = (LEFT < RIGHT) and  1 or -1
Screen.TOP_DIR    = (BOTTOM < TOP) and  1 or -1
Screen.BOTTOM_DIR = (BOTTOM < TOP) and -1 or  1

local _new = Screen.new
function Screen:new( elems )
  local obj = _new( self )
  obj.elements = {...}
  return obj
end

function Screen:onEvent(event, detail)
  if event == "draw" then
  elseif event == "button" then

  end
end

function Screen:serialize()
  local json = Json.static.Array:new()
  
  for i, elem in ipairs(self.elements) do
    json:put( elem:build() )
  end

  return json:toString()
end

return Screen