print("Creating Main Menu (build 3)")

print(table.serialize(package.loaded))

local Screen = require"TheIncgi/Plasma-projects/IK-Arm/IK-Arm/screens/Screen"
local Button = require"TheIncgi/Plasma-projects/IK-Arm/IK-Arm/screens/Button"

print(table.serialize(package.loaded))

testButton = Button:new({
  x = 5,
  y = 5,
  width = 20,
  height = 20,
  text = "Foo"
})

local mainMenu = Screen:new(testButton)

return mainMenu