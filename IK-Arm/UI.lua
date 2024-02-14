print"Loading UI (build 7)"
local Screen = require("TheIncgi/Plasma-projects/IK-Arm/IK-Arm/screens/Screen")

print"Loading menus..."
local UI = {
  UI.screens = {
    main = require"TheIncgi/Plasma-projects/IK-Arm/IK-Arm/screens/MainMenu"
  }
}
UI.screen = UI.screens.main

function UI.printMenu()
  print"F1 - Collect Data"
  print"F2 - Train"
  print"F3 - Test"
end

function UI.eventDispatcher()
  print("UI event dispatcher started")
  while true do
    local event, detail = os.pullEvent({"key","ui"})
    print("[UI EVENT]:"..event)
    if UI.screen then
      UI.screen.onEvent( event, detail )
    end
  end
end

UI.task = coroutine.create( UI.eventDispatcher )
coroutine.resume( UI.task )

table.insert(_TASKS, UI.task)

return UI