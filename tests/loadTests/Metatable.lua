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

----------------
-- __call --
----------------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local src = [=[
    local t = {}

    setmetatable( t, {
      __call = function( t, arg )
        return arg + 1
      end
    })

    return t( 10 )
  ]=]

  local test = testUtils.codeTest(tester, "__call", env, libs, src)

  test:var_eq(1, 11)
end

----------------
-- getmetatable --
----------------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local src = [=[
    local t = {}
    local u = {}
    setmetatable( t, u )
    
    return getmetatable( t ) == u
  ]=]

  local test = testUtils.codeTest(tester, "getmetatable", env, libs, src)

  test:var_isTrue(1)
end

-----------------
-- __metatable --
-----------------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local src = [=[
    local t = {}
    local u = {}
    setmetatable( t, {
      __metatable = u
    })

    return getmetatable( t ) == u
  ]=]

  local test = testUtils.codeTest(tester, "__metatable", env, libs, src)

  test:var_isTrue(1)
end

------------------------------
-- __metatable is protected --
------------------------------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local src = [=[
    local t = {}
    local u = {}

    setmetatable( t, {
      __metatable = u
    })

    setmetatable( t, {
      __metatable = u
    })
  ]=]

  local test = testUtils.codeTest(tester, "__metatable is protected", env, libs, src)

  test:expectError("cannot change a protected metatable")
end

-----------------------
-- __tostring string --
-----------------------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local src = [=[
    local t = {}
    
    setmetatable( t, {
      __tostring = "ok"
    })

    return tostring( t )
  ]=]

  local test = testUtils.codeTest(tester, "__tostring string", env, libs, src)

  test:var_eq(1, "ok")
end

---------------------
-- __tostring func --
---------------------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local src = [=[
    local t = {
      z = "ok"
    }
    
    setmetatable( t, {
      __tostring = function( x )
        return x.z
      end
    })

    return tostring( t )
  ]=]

  local test = testUtils.codeTest(tester, "__tostring func", env, libs, src)

  test:var_eq(1, "ok")
end

return tester