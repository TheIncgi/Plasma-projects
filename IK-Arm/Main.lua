print"Setup... (build 3)"
print("Check table: "..tostring(table.serialize))

print"Loading MultiTaskBase"
require("TheIncgi/Plasma-projects/IK-Arm/libs/MultiTaskBase")

local UI = require("TheIncgi/Plasma-projects/IK-Arm/IK-Arm/UI")

print"Launching task manager"
main() --runs MultiTaskBase