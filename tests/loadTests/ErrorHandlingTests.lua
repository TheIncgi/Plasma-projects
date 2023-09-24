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
-- pcall --
-----------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local src = [=[
    local function unsafe()
      return x + 2
    end

    return pcall( unsafe )
  ]=]

  local test = testUtils.codeTest(tester, "pcall", env, libs, src)

  test:var_eq(1, false)
  test:var_eq(2, "attempt to add nil with number")
end

return tester