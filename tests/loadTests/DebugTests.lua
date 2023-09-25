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
-- debug - traceback --
-------------------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local src = [=[
    function foo()
      return debug.traceback()
    end
    function bar()
      return foo()
    end
    return bar()
  ]=]

  local test = testUtils.codeTest(tester, "debug-traceback", env, libs, src)

  test:var_eq(1, [[stack traceback:
	line 2 in fenv: foo
	line 5 in fenv: bar
	line 7 in UNIT_TEST]])
end



return tester