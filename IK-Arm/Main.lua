print"Setup..."

if true then
  debug.sethook(function(event, line, ...)
    local args = table.concat({...}, ",") --call & return only
    print("%s:%s {%s}":format(event, line or "", args))
  end, "clr")
end

require("TheIncgi/Plasma-Projects/IK-Arm/libs/MultiTaskBase")

require("TheIncgi/Plasma-Projects/IK-Arm/IK-Arm/UI")





main() --runs MultiTaskBase