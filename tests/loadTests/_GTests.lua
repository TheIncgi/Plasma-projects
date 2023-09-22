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

--------
-- _G --
--------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope
  
  local src = [=[
    return _G.print == print
  ]=]
    
  local test = testUtils.codeTest(tester, "_G", env, libs, src)
    
  test:var_eq(1, true)
end

return tester