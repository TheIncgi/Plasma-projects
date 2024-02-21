print("Creating Data Collection Menu (build 2)")

local Screen = require"TheIncgi/Plasma-projects/IK-Arm/IK-Arm/screens/Screen"
local Button = require"TheIncgi/Plasma-projects/IK-Arm/IK-Arm/screens/Button"
local Text   = require"TheIncgi/Plasma-projects/IK-Arm/IK-Arm/screens/Text"

local DataCollectionMenu = class("TheIncgi/Plasma-projects/IK-Arm/IK-Arm/screens/DataCollectionMenu", Screen)
DCM = DataCollectionMenu

local _new = DCM.new
function DCM:new( UI, ... )
  local obj = _new( self )

  local margins = Screen.HEIGHT * .05
  local buttonHeight = Screen.HEIGHT * .10
  local ButtonWidth = Screen.WIDTH / 2

  local back = Button:new({
    x = Screen.LEFT + (Screen.RIGHT_DIR * margins),
    y = Screen.TOP + (Screen.BOTTOM_DIR * margins),
    x2 = Screen.LEFT + (Screen.RIGHT_DIR * margins) + buttonHeight,
    y2 = Screen.TOP + (Screen.BOTTOM_DIR * margins) + buttonHeight,
    text = "<",
    backgroundColor = {r=1, g=0, b=0},
    onClick=function()
      UI.setScreen("main")
    end
  })

  return obj
end

return DCM