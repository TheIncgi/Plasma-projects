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

------------------
-- load - print --
------------------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  common.printProxy.realDefault = false
  
  local src = [=[
    local loaded = load("print'Hello world!' return 'ok'")
    return type(loaded), loaded()
  ]=]
    
  local test = testUtils.codeTest(tester, "load-print", env, libs, src)
    
  common.printProxy{ "Hello world!" }.exact()
  test:var_eq(1, "function")
end

----------------------
-- load - sandboxed --
----------------------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  common.printProxy.realDefault = false
  
  local src = [==[
    local sandbox = {}
    loaded = load([=[
      function hello()
        print"Hello"
      end
    ]=], "test", "t", sandbox)
    loaded() --load hello function into sandbox
    return type(hello), type(sandbox.hello)
  ]==]
    
  local test = testUtils.codeTest(tester, "load-print", env, libs, src)
  
  test:var_eq(1, "nil")
  test:var_eq(2, "function")
end

return tester