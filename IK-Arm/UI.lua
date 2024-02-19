print"Loading UI (build 13)"
local Screen = require("TheIncgi/Plasma-projects/IK-Arm/IK-Arm/screens/Screen")

print"Loading menus..."
local UI = {
  screens = {
    main = require("TheIncgi/Plasma-projects/IK-Arm/IK-Arm/screens/MainMenu"):new()
  }
}
UI.screen = UI.screens.main

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
    local event, detail = os.pullEvent({"key","ui"})
    print("[UI EVENT]:"..event)
    if UI.screen then
      UI.screen:onEvent( event, detail )
    end
  end
end

os.queueTask( UI._eventDispatcher )

return UI