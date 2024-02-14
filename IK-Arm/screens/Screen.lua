print"Loading Screen (build 2)"

print"require class.."
require"TheIncgi/Plasma-projects/main/libs/class"
print"require json.."
local Json = require"TheIncgi/Plasma-projects/main/libs/Json"
print"Create Screen class"
local Screen = class("TheIncgi/Plasma-projects/IK-Arm/IK-Arm/screens/Screen")

local _new = Screen.new
function Screen:new( ... )
  local obj = _new( self )
  obj["elements"] = { ... }
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