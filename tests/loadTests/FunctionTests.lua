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
-- scope test  --
-----------------
do
  --given
  local src = [=[
    function test()
      local function x(...)
        return ...
      end
      IN_FUNC = not not x --fails not not function
    end
    test()
    OUT_FUNC = not not x
  ]=]
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  --test code
  local test = tester:add("scope test", env, function()
    local scope = testUtils.newScope(Scope)
    testUtils.run( src, scope, Loader, Async )
    return scope:get"IN_FUNC".value, scope:get"OUT_FUNC".value
  end)

  --expect
  test:var_isTrue(1, "expected global `IN_FUNC` to be `true`, actual: $1") --1, first return value
  test:var_isFalse(2, "expected global `OUT_FUNC` to be `false`, actual: $1") --2, second return value
  V1,V2,V3,V4,V5,V6,V7,V8 = nil, nil, nil, nil, nil, nil, nil, nil
end

-----------------
--   Require   --
-----------------
do
  local src = [=[
    local HelloRequire = require"TheIncgi/Plasma-projects/main/testLibs/HelloRequire"
    print( HelloRequire.msg )
  ]=]
  local HelloRequire = require"testLibs/HelloRequire"
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope
  local path = "TheIncgi/Plasma-projects/main/testLibs/HelloRequire"
  
  --expect print call with msg
  common.printProxy{ HelloRequire.msg }.exact()

  testUtils.setupRequire( Async, Net, common, {path} )
    
  --test code
  local test = tester:add("requires code", env, function()
    local scope = testUtils.newScope(Scope)
    testUtils.run( src, scope, Loader, Async )
  end)
    
end


-----------------
--  Table Func --
-----------------
do
  local src = [=[
    local Lib = require"TheIncgi/Plasma-projects/main/testLibs/TableFunc"
    Lib.test()
  ]=]
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope
  local path = "TheIncgi/Plasma-projects/main/testLibs/TableFunc"

  testUtils.setupRequire( Async, Net, common, {path} )
  
  --expect print call with msg
  common.printProxy{ "ok" }.exact()
    
  --test code
  local test = tester:add("table function", env, function()
    local scope = testUtils.newScope(Scope)
    testUtils.run( src, scope, Loader, Async )
  end)
    
end

return tester