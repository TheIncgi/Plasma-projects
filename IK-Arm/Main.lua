print"Setup... (build 5)"
print("Running on: ".._VERSION)

print"Loading MultiTaskBase"
require("TheIncgi/Plasma-projects/IK-Arm/libs/MultiTaskBase")

local UI = require("TheIncgi/Plasma-projects/IK-Arm/IK-Arm/UI")

print"Launching task manager"
main() --runs MultiTaskBase