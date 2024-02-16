print"Loading Screen (build 11)"

require"TheIncgi/Plasma-projects/main/libs/class"
local Json = require"TheIncgi/Plasma-projects/main/libs/Json"

print"Create Screen class"
local Screen = class("TheIncgi/Plasma-projects/IK-Arm/IK-Arm/screens/Screen")

Screen.WIDTH = 680
Screen.HEIGHT = 512
Screen.TOP = Screen.HEIGHT
Screen.BOTTOM = 0
Screen.LEFT = 0
Screen.RIGHT = Screen.WIDTH

Screen.LEFT_DIR   = (Screen.LEFT < Screen.RIGHT) and -1 or  1
Screen.RIGHT_DIR  = (Screen.LEFT < Screen.RIGHT) and  1 or -1
Screen.TOP_DIR    = (Screen.BOTTOM < Screen.TOP) and  1 or -1
Screen.BOTTOM_DIR = (Screen.BOTTOM < Screen.TOP) and -1 or  1

local _new = Screen.new
function Screen:new( elems )
  local obj = _new( self )
  obj.elements = {...}
  return obj
end

function Screen:onEvent(event, detail)
  if event == "draw" then
    print( "DOC: ", self:serialize())
    output( self:serialize(), 1 )
  elseif event == "button" then

  end
end

function Screen:serialize()
  local json = Json.static.JsonArray:new()
  
  for i, elem in ipairs(self.elements) do
    json:put( elem:build() )
  end

  return json:toString()
end

return Screen