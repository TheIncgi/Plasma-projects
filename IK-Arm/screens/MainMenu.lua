print("Creating Main Menu (build 6)")

local Screen = require"TheIncgi/Plasma-projects/IK-Arm/IK-Arm/screens/Screen"
local Button = require"TheIncgi/Plasma-projects/IK-Arm/IK-Arm/screens/Button"
local Text   = require"TheIncgi/Plasma-projects/IK-Arm/IK-Arm/screens/Text"

local x = (Screen.WIDTH / 2) - (Screen.WIDTH / 4)
local reducedHeight = (Screen.HEIGHT * .9)
local paddingSize = (Screen.HEIGHT * .02)
local nElements = 4
local elemHeight = (reducedHeight - math.max(0,paddingSize*nElements-1) ) / nElements
local halfWidth = Screen.WIDTH / 2

local y = paddingSize
title = Text:new({
  x = x,
  y = y,
  width = halfWidth,
  height = elemHeight,
  text = "Main Menu"
})
y = y + elemHeight + paddingSize

dataButton = Button:new({
  x = x,
  y = y,
  width = halfWidth,
  height = elemHeight,
  text = "Gen Data"
})
y = y + elemHeight + paddingSize

trainButton = Button:new({
  x = x,
  y = y,
  width = halfWidth,
  height = elemHeight,
  text = "Train"
})
y = y + elemHeight + paddingSize

testButton = Button:new({
  x = x,
  y = y,
  width = halfWidth,
  height = elemHeight,
  text = "Test"
})

local mainMenu = Screen:new(dataButton, trainButton, testButton)

return mainMenu