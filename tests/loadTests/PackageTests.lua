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
--   Require once   --
-----------------
do
  local src = [=[
    local path = "TheIncgi/Plasma-projects/main/testLibs/HelloRequire"
    local HelloRequire = require(path)
    require(path) --from package.loaded
    return not not package.loaded[path]
  ]=]
  local HelloRequire = require"testLibs/HelloRequire"
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope
  local path = "TheIncgi/Plasma-projects/main/testLibs/HelloRequire"

  testUtils.setupRequire( Async, Net, common, {path} )
  
  --test code
  local test = testUtils.codeTest(tester, "require", env, libs, src)
  test:var_eq(function()
    return common.output.records.totalCalls
  end, 1, "Expected 1 hit to output (from require), had $1 ")  
end


return tester