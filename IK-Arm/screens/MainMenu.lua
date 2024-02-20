print("Creating Main Menu (build 24)")

local Screen = require"TheIncgi/Plasma-projects/IK-Arm/IK-Arm/screens/Screen"
local Button = require"TheIncgi/Plasma-projects/IK-Arm/IK-Arm/screens/Button"
local Text   = require"TheIncgi/Plasma-projects/IK-Arm/IK-Arm/screens/Text"

local MainMenu = class("TheIncgi/Plasma-projects/IK-Arm/IK-Arm/screens/MainMenu", Screen)

local _new = MainMenu.new
function MainMenu:new( ... )
  local obj = _new(self)

  local x = (Screen.WIDTH / 2) - (Screen.WIDTH / 4)
  local reducedHeight = (Screen.HEIGHT * .9)
  local paddingSize = (Screen.HEIGHT * .02)
  local nElements = 5
  local elemHeight = (reducedHeight - math.max(0,paddingSize*nElements-1) ) / nElements
  local halfWidth = Screen.WIDTH / 2

  local y = Screen.TOP + paddingSize * Screen.BOTTOM_DIR

  obj.title = Text:new({
    x = x,
    y = y,
    width = halfWidth,
    y2 = y + elemHeight * Screen.BOTTOM_DIR,
    text = "Main Menu",
    id = 1,
  })
  y = y + (elemHeight + paddingSize) * Screen.BOTTOM_DIR

  obj.samples = Text:new({
    x = x, 
    y = y,
    width = halfWidth,
    y2 = y + elemHeight * Screen.BOTTOM_DIR,
    text = "Samples: ...",
    id = 2
  })
  y = y + (elemHeight + paddingSize) * Screen.BOTTOM_DIR

  obj.dataButton = Button:new({
    x = x,
    y = y,
    width = halfWidth,
    y2 = y + elemHeight * Screen.BOTTOM_DIR,
    text = "Gen Data",
    id = 3,
    fontSize = 30,
    onClick = function() print"Clicked Data Button" end,
  })
  y = y + (elemHeight + paddingSize) * Screen.BOTTOM_DIR

  obj.trainButton = Button:new({
    x = x,
    y = y,
    width = halfWidth,
    y2 = y + elemHeight * Screen.BOTTOM_DIR,
    text = "Train",
    id = 4
  })
  y = y + (elemHeight + paddingSize) * Screen.BOTTOM_DIR

  obj.testButton = Button:new({
    x = x,
    y = y,
    width = halfWidth,
    y2 = y + elemHeight * Screen.BOTTOM_DIR,
    text = "Test",
    id = 5
  })

  table.insert(obj.elements, obj.title)
  table.insert(obj.elements, obj.samples)
  table.insert(obj.elements, obj.dataButton)
  table.insert(obj.elements, obj.trainButton)
  table.insert(obj.elements, obj.testButton)

  return obj
end

function MainMenu:updateSampleCount( n )

end

-- --@Override
-- function MainMenu:onEvent(event, ...)
--   self:super().onEvent( self, event, ... )
-- end

return MainMenu