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
-- __index table --
-------------------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local src = [=[
    local t = {}
    local u = { x = "ok" }
    setmetatable( t, {
      __index = u
    })
    return t.x
  ]=]

  local test = testUtils.codeTest(tester, "__index table", env, libs, src)

  test:var_eq(1, "ok")
end

----------------------
-- __index function --
----------------------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local src = [=[
    local t = {}
    setmetatable( t, {
      __index = function(t, k)
        return k + 1
      end
    })
    return t[122]
  ]=]

  local test = testUtils.codeTest(tester, "__index function", env, libs, src)

  test:var_eq(1, 123, "Expected index function to return k + 1 (123), got $1")
end

----------------------
-- __index defaults --
----------------------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local src = [=[
    local t = { x = "ok" }
    local u = { x = "not ok" }
    setmetatable( t, {
      __index = u
    })
    return t.x
  ]=]

  local test = testUtils.codeTest(tester, "__index defaults", env, libs, src)

  test:var_eq(1, "ok")
end

----------------
-- __newindex --
----------------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local src = [=[
    local t = {}

    setmetatable( t, {
      __newindex = function( t, k, v )
        rawset( t, "x", "ok" )
      end
    })

    t.foo = 10
    return t.x
  ]=]

  local test = testUtils.codeTest(tester, "__newindex", env, libs, src)

  test:var_eq(1, "ok")
end


return tester