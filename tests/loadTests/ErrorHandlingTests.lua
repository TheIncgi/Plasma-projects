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

-------------------
-- pcall - clean --
-------------------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local src = [=[
    local function safe(x)
      return x + 2
    end

    return pcall( safe, 10 )
  ]=]

  local test = testUtils.codeTest(tester, "pcall-clean", env, libs, src)

  test:var_eq(2, 12)
  test:var_eq(1, true)
end

-------------------
-- pcall - error --
-------------------
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

  local test = testUtils.codeTest(tester, "pcall-err", env, libs, src)

  test:var_eq(1, false)
  test:expect(function()
    local actual = test.actionResults[2]
    local expected = "attempt to perform arithmetic"
    local msg = ("Expected error containing `%s` got `%s`"):format(expected, actual)
    return not not actual:find(expected,1,true), msg
  end)
end

return tester