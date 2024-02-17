print"Loading Data Collector (build 2)"
local Json = require"TheIncgi/Plasma-projects/main/libs/Json"
local utils = require"TheIncgi/Plasma-projects/main/libs/utils"

local dataManager = {}

function dataManager.convertRawToLabels(jsonText)
  local data = Json:new(jsonText):toTable()
  local features = {} --these will be the target angle and positon of the gripper
  local labels = {} --these will be target angles/positions for motors/axis/etc (solving for these)

  for index, prop in ipairs(data.features) do

  end

  for index, prop in ipairs(data.labels) do
    
  end
end

function dataManager.store(model, labels, features)
end

return dataManager