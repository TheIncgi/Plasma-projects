print"Loading UI (build 21)"
local Screen = require("TheIncgi/Plasma-projects/IK-Arm/IK-Arm/screens/Screen")

print"Loading menus..."
local UI = {
  screens = {}
}

UI.screens.main = require("TheIncgi/Plasma-projects/IK-Arm/IK-Arm/screens/MainMenu"):new( UI )
UI.screens.dataCollectionMenu = require("TheIncgi/Plasma-projects/IK-Arm/IK-Arm/screens/DataCollectionMenu"):new( UI )

UI.screen = UI.screens.main

function UI.setScreen( to )
  if type(to) == "string" then
    to = UI.screens[to]
  end
  UI.prevScreen = UI.screen
  UI.screen = to --or todo error
  UI.draw()
end

function UI.draw()
  if UI.screen then
    print"Force drawing UI..."
    UI.screen:onEvent("draw")
  else
    print"<color=#FF8800>MISSING SCREEN</color>"
  end
end

function UI._eventDispatcher()
  print("UI event dispatcher started")
  UI.draw()
  while true do
    local event = {os.pullEvent({"key","ui"})}
    --print("[UI EVENT]:"..event)
    if UI.screen then
      UI.screen:onEvent( table.unpack(event) )
    end
  end
end

os.queueTask( "ui-event-monitor", UI._eventDispatcher, true )

return UI