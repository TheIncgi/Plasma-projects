--Template file
local Tester = require"TestRunner"
local Env = require"MockEnv"
local testUtils = require"libs/testUtils"

local matchers = require"MockProxy".static
local eq = matchers.eq
local any = matchers.any
local testUtils = require"libs/testUtils"

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

-------------
-- , order --
-------------
do
  --given
  local src = [=[
    return 1,2,3,4,5,6,7
  ]=]
  local env = Env:new()
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local test = testUtils.codeTest( tester, ", order", env, libs, src )
  
  for i=1,7 do
    test:var_eq(i, i)
  end
end

-------------
-- (), order --
-------------
do
  --given
  local src = [=[
    function t()
      return 1,2,3,4
    end
    return t(),5,6,7
  ]=]
  local env = Env:new()
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local test = testUtils.codeTest( tester, "(), order", env, libs, src )
  
  test:var_eq(1, 1)
  test:var_eq(2, 5)
  test:var_eq(3, 6)
  test:var_eq(4, 7)
end

-------------
-- ,() order --
-------------
do
  --given
  local src = [=[
    function t()
      return 1,2,3,4
    end
    return 5,6,7,t()
  ]=]
  local env = Env:new()
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local test = testUtils.codeTest( tester, ",() order", env, libs, src )
  
  test:var_eq(1, 5)
  test:var_eq(2, 6)
  test:var_eq(3, 7)
  test:var_eq(4, 1)
  test:var_eq(5, 2)
  test:var_eq(6, 3)
  test:var_eq(7, 4)
end

-------------
-- ,(), order --
-------------
do
  --given
  local src = [=[
    function t()
      return 1,2,3,4
    end
    return 5,t(),7
  ]=]
  local env = Env:new()
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local test = testUtils.codeTest( tester, ",(), order", env, libs, src )
  
  test:var_eq(1, 5)
  test:var_eq(2, 1)
  test:var_eq(3, 7)
end

return tester