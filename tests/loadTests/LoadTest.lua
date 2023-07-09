--Template file
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

-----------------
-- Hello world --
-----------------
do
  --given
  local src = [=[
    print("Hello world!")
  ]=]
  local env = Env:new()
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local printProxy = env:proxy("print", function() end)
  --test code
  tester:add("executes hello world", env, function()
    local scope = testUtils.newScope(Scope)
    testUtils.run( src, scope, Loader, Async )
  end)
  --expect
  printProxy{ "Hello world!" }.exact()
end

return tester