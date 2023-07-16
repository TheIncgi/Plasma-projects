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
-- or --
--------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local src = [=[
    local function doNotCall()
      error"called function that was meant to be skipped!"
    end

    return true or doNotCall()
  ]=]

  local test = testUtils.codeTest(tester, "or", env, libs, src)

  test:var_eq(1, true)
end

---------
-- and --
---------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local src = [=[
    local function doNotCall()
      error"called function that was meant to be skipped!"
    end

    return false and doNotCall()
  ]=]

  local test = testUtils.codeTest(tester, "and", env, libs, src)

  test:var_eq(1, false)
end

------------
-- and or --
------------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local src = [=[
    local function doNotCall()
      error"called function that was meant to be skipped!"
    end

    return false and doNotCall() or true
  ]=]

  local test = testUtils.codeTest(tester, "and or", env, libs, src)

  test:var_eq(1, true)
end

------------
-- or and --
------------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local src = [=[
    local function doNotCall()
      error"called function that was meant to be skipped!"
    end

    return true or doNotCall() and 3
  ]=]

  local test = testUtils.codeTest(tester, "or and", env, libs, src)

  test:var_eq(1, 3)
end

------------
-- and , or --
------------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local src = [=[
    local function doNotCall()
      error"called function that was meant to be skipped!"
    end

    return false and doNotCall(), true or doNotCall()
  ]=]

  local test = testUtils.codeTest(tester, "and or", env, libs, src)

  test:var_eq(1, false)
end

return tester