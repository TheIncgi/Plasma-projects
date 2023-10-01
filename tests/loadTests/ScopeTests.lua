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

--------------------
-- function param --
--------------------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local src = [=[
    local function paramTest( x )
      x = x
    end

    paramTest( 10 )

    return x, _G.x
  ]=]

  local test = testUtils.codeTest(tester, "function param", env, libs, src)

  test:var_eq(1, nil)
  test:var_eq(2, nil)
end


--------------------
-- function param --
--------------------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local src = [=[
    table.serialize( _G )
    return visited
  ]=]

  local test = testUtils.codeTest(tester, "table.serialize", env, libs, src)

  test:var_eq(1, nil)
end

return tester