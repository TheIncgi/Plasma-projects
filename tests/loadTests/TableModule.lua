local Tester = require"TestRunner"
local Env = require"MockEnv"
local testUtils = require"libs/testUtils"

local matchers = require"MockProxy".static
local eq = matchers.eq
local any = matchers.any

local tester = Tester:new()

-----------------------------------------------------------------
-- Tests
-----------------------------------------------------------------

-----------
--       --
-----------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local src = [=[
    
  ]=]

  local test = tester:add("PLACE HOLDER", env, function()
    local scope = testUtils.newScope(Scope)
    local results = testUtils.run(src, scope, Loader, Async).varargs
    if not results[1] or not results[2] then error"Expected return value" end
    return results[1].value
  end)

  test:var_eq(1, 2)
end

return tester