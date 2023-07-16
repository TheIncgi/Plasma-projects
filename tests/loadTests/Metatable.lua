local Tester = require"TestRunner"
local Env = require"MockEnv"
local testUtils = require"libs/testUtils"

local matchers = require"MockProxy".static
local eq = matchers.eq
local any = matchers.any

local tester = Tester:new()

-----------------------------------------------------------------
-- Tests
-- http://lua-users.org/wiki/MetatableEvents
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

-----------
-- __len --
-----------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local src = [=[
    local t = {}
    
    setmetatable( t, {
      __len = function()
        return 123
      end
    })
    return #t
  ]=]

  local test = testUtils.codeTest(tester, "__len", env, libs, src)

  test:var_eq(1, 123)
end

-------------
-- __pairs --
-------------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local src = [=[
    local t = {}
    
    setmetatable( t, {
      __pairs = function()
        return "hello":gmatch"."
      end
    })
    
    local hits = 0
    for x in pairs( t ) do
      hits = hits + 1
    end

    return hits
  ]=]

  local test = testUtils.codeTest(tester, "__pairs", env, libs, src)

  test:var_eq(1, 5)
end

-------------
-- __ipairs --
-------------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local src = [=[
    local t = {}
    
    setmetatable( t, {
      __ipairs = function()
        return "hello":gmatch"."
      end
    })
    
    local hits = 0
    for x in ipairs( t ) do
      hits = hits + 1
    end

    return hits
  ]=]

  local test = testUtils.codeTest(tester, "__ipairs", env, libs, src)

  test:var_eq(1, 5)
end

-----------
-- __unm --
-----------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local src = [=[
    local t = {}
    
    setmetatable( t, {
      __unm = function()
        return "ok"
      end
    })

    return -t
  ]=]

  local test = testUtils.codeTest(tester, "__unm", env, libs, src)

  test:var_eq(1, "ok")
end

-----------
-- __add --
-----------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local src = [=[
    local t = { x =  5 }
    local u = { x = 10 }
    local m = {
      __add = function(a, b)
        if type(a) == "table" then
          a = a.x
        end
        if type(b) == "table" then
          b = b.x
        end
        return a + b
      end
    }
    
    setmetatable( t, m )
    setmetatable( u, m )

    return 
      1 + t, 
      t + 1,
      t + u
  ]=]

  local test = testUtils.codeTest(tester, "__add", env, libs, src)

  test:var_eq(1, 6)
  test:var_eq(2, 6)
  test:var_eq(3, 15)
end

return tester