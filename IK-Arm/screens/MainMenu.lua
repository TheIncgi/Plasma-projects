print("Creating Main Menu (build 4)")

local Screen = require"TheIncgi/Plasma-projects/IK-Arm/IK-Arm/screens/Screen"
local Button = require"TheIncgi/Plasma-projects/IK-Arm/IK-Arm/screens/Button"

testButton = Button:new({
  x = 5,
  y = 5,
  width = 20,
  height = 20,
  text = "Foo"
})

local mainMenu = Screen:new(testButton)

return mainMenu