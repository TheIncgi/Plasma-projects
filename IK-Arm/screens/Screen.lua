print"Loading Screen"

require"TheIncgi/Plasma-Projects/main/libs/class"
local Json = require"TheIncgi/Plasma-Projects/main/libs/Json"

local Screen = class(_ROOT .. "/IK-Arm/screens/Screen")

local _new = Screen.new
function Screen:new( ... )
  local obj = _new( self )
  obj.elements = { ... }
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