local Tester = require"TestRunner"
local Env = require"MockEnv"

local matchers = require"MockProxy".static
local eq = matchers.eq
local any = matchers.any


local tester = Tester:new()


return tester