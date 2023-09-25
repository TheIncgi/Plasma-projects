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

-----------------------
-- debug - traceback --
-----------------------
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
	line 2 in function foo
	line 5 in function bar
	line 7 in UNIT_TEST]])
end

-----------------------
-- debug - traceback table --
-----------------------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local src = [=[
    function foo()
      return debug.tracebackTable()
    end
    function bar()
      return foo()
    end
    local tb = bar()
    return tb[1].name, tb[1].line, tb[2].name, tb[2].line, tb[3].name, tb[3].line
  ]=]

  local test = testUtils.codeTest(tester, "debug-traceback-table", env, libs, src)
  
  test:var_eq(1, "function foo")
  test:var_eq(2, 2)
  test:var_eq(3, "function bar")
  test:var_eq(4, 5)
  test:var_eq(5, "UNIT_TEST")
  test:var_eq(6, 7)
end

return tester