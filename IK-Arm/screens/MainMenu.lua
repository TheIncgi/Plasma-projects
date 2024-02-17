print("Creating Main Menu (build 13)")

local Screen = require"TheIncgi/Plasma-projects/IK-Arm/IK-Arm/screens/Screen"
local Button = require"TheIncgi/Plasma-projects/IK-Arm/IK-Arm/screens/Button"
local Text   = require"TheIncgi/Plasma-projects/IK-Arm/IK-Arm/screens/Text"

local x = (Screen.WIDTH / 2) - (Screen.WIDTH / 4)
local reducedHeight = (Screen.HEIGHT * .9)
local paddingSize = (Screen.HEIGHT * .02)
local nElements = 4
local elemHeight = (reducedHeight - math.max(0,paddingSize*nElements-1) ) / nElements
local halfWidth = Screen.WIDTH / 2

local y = Screen.TOP + paddingSize * Screen.BOTTOM_DIR
print("%.2f = %.2f + %.2f * %.0f":format(y, Screen.TOP, paddingSize, Screen.BOTTOM_DIR))
print(tostring(y)..", "..tostring(elemHeight).." "..tostring(Screen.BOTTOM_DIR))
title = Text:new({
  x = x,
  y = y,
  width = halfWidth,
  y2 = y + elemHeight * Screen.BOTTOM_DIR,
  text = "Main Menu",
  id = 1
})
y = y + (elemHeight + paddingSize* Screen.BOTTOM_DIR)

dataButton = Button:new({
  x = x,
  y = y,
  width = halfWidth,
  y2 = y + elemHeight * Screen.BOTTOM_DIR,
  text = "Gen Data",
  id = 2
})
y = y + (elemHeight + paddingSize * Screen.BOTTOM_DIR)

trainButton = Button:new({
  x = x,
  y = y,
  width = halfWidth,
  y2 = y + elemHeight * Screen.BOTTOM_DIR,
  text = "Train",
  id = 3
})
y = y + (elemHeight + paddingSize * Screen.BOTTOM_DIR)

testButton = Button:new({
  x = x,
  y = y,
  width = halfWidth,
  y2 = y + elemHeight * Screen.BOTTOM_DIR,
  text = "Test",
  id = 4
})

local mainMenu = Screen:new(title,dataButton, trainButton, testButton)

return mainMenu