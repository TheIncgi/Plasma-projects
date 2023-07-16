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
----------------------------------------------------------------------------------------------------------------------------------------
-- arithmetic
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

-----------
-- __sub --
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
      __sub = function(a, b)
        if type(a) == "table" then
          a = a.x
        end
        if type(b) == "table" then
          b = b.x
        end
        return a - b
      end
    }
    
    setmetatable( t, m )
    setmetatable( u, m )

    return 
      1 - t, 
      t - 1,
      t - u
  ]=]

  local test = testUtils.codeTest(tester, "__sub", env, libs, src)

  test:var_eq(1, -4)
  test:var_eq(2,  4)
  test:var_eq(3, -5)
end

-----------
-- __mul --
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
      __mul = function(a, b)
        if type(a) == "table" then
          a = a.x
        end
        if type(b) == "table" then
          b = b.x
        end
        return a * b
      end
    }
    
    setmetatable( t, m )
    setmetatable( u, m )

    return 
      2 * t, 
      t * 2,
      t * u
  ]=]

  local test = testUtils.codeTest(tester, "__mul", env, libs, src)

  test:var_eq(1, 10)
  test:var_eq(2, 10)
  test:var_eq(3, 50)
end

-----------
-- __div --
-----------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local src = [=[
    local t = { x = 8 }
    local u = { x = 4 }
    local m = {
      __div = function(a, b)
        if type(a) == "table" then
          a = a.x
        end
        if type(b) == "table" then
          b = b.x
        end
        return a / b
      end
    }
    
    setmetatable( t, m )
    setmetatable( u, m )

    return 
      64 / t, 
       t / 2,
       t / u
  ]=]

  local test = testUtils.codeTest(tester, "__div", env, libs, src)

  test:var_eq(1, 8)
  test:var_eq(2, 4)
  test:var_eq(3, 2)
end

-----------
-- __idiv --
-----------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local src = [=[
    local t = { x = 17 }
    local u = { x = 3 }
    local m = {
      __idiv = function(a, b)
        if type(a) == "table" then
          a = a.x
        end
        if type(b) == "table" then
          b = b.x
        end
        return a // b
      end
    }
    
    setmetatable( t, m )
    setmetatable( u, m )

    return 
      100 // t, 
        t // 2,
        t // u
  ]=]

  local test = testUtils.codeTest(tester, "__idiv", env, libs, src)

  test:var_eq(1, 5)
  test:var_eq(2, 8)
  test:var_eq(3, 5)
end

-----------
-- __mod --
-----------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local src = [=[
    local t = { x = 17 }
    local u = { x = 3 }
    local m = {
      __mod = function(a, b)
        if type(a) == "table" then
          a = a.x
        end
        if type(b) == "table" then
          b = b.x
        end
        return a % b
      end
    }
    
    setmetatable( t, m )
    setmetatable( u, m )

    return 
      100 % t, 
        t % 2,
        t % u
  ]=]

  local test = testUtils.codeTest(tester, "__mod", env, libs, src)

  test:var_eq(1, 15)
  test:var_eq(2,  1)
  test:var_eq(3,  2)
end

-----------
-- __pow --
-----------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local src = [=[
    local t = { x = 5 }
    local u = { x = 3 }
    local m = {
      __pow = function(a, b)
        if type(a) == "table" then
          a = a.x
        end
        if type(b) == "table" then
          b = b.x
        end
        return a ^ b
      end
    }
    
    setmetatable( t, m )
    setmetatable( u, m )

    return 
      2 ^ t, 
      t ^ 2,
      t ^ u
  ]=]

  local test = testUtils.codeTest(tester, "__pow", env, libs, src)

  test:var_eq(1,  32)
  test:var_eq(2,  25)
  test:var_eq(3, 125)
end

--------------
-- __concat --
--------------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local src = [=[
    local t = { x = "world" }
    local u = { x = "!" }
    local m = {
      __concat = function(a, b)
        if type(a) == "table" then
          a = a.x
        end
        if type(b) == "table" then
          b = b.x
        end
        return a .. b
      end
    }
    
    setmetatable( t, m )
    setmetatable( u, m )

    return 
      "hello " .. t, 
        t .. "!",
        t .. u
  ]=]

  local test = testUtils.codeTest(tester, "__concat", env, libs, src)

  test:var_eq(1, "hello world")
  test:var_eq(2, "world!")
  test:var_eq(3, "world!")
end

--------------------------------------------------------------------------------------------------------------------------
-- Bitwise
-----------
-- __band --
-----------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local src = [=[
    local t = { x = 17 }
    local u = { x = 3 }
    local m = {
      __band = function(a, b)
        if type(a) == "table" then
          a = a.x
        end
        if type(b) == "table" then
          b = b.x
        end
        return a & b
      end
    }
    
    setmetatable( t, m )
    setmetatable( u, m )

    return 
      0x3A & t, 
         t & 0x3A,
         t & u
  ]=]

  local test = testUtils.codeTest(tester, "__band", env, libs, src)

  test:var_eq(1, 16)
  test:var_eq(2, 16)
  test:var_eq(3,  1)
end

-----------
-- __bor --
-----------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local src = [=[
    local t = { x = 17 }
    local u = { x = 3 }
    local m = {
      __bor = function(a, b)
        if type(a) == "table" then
          a = a.x
        end
        if type(b) == "table" then
          b = b.x
        end
        return a | b
      end
    }
    
    setmetatable( t, m )
    setmetatable( u, m )

    return 
      0x3A | t, 
         t | 0x3A,
         t | u
  ]=]

  local test = testUtils.codeTest(tester, "__bor", env, libs, src)

  test:var_eq(1, 59)
  test:var_eq(2, 59)
  test:var_eq(3, 19)
end

-----------
-- __bnot --
-----------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local src = [=[
    local t = { x = 17 }
    local m = {
      __bnot = function(a)
        return ~a.x
      end
    }
    
    setmetatable( t, m )

    return ~t
  ]=]

  local test = testUtils.codeTest(tester, "__bnot", env, libs, src)

  test:var_eq(1, bit32.bnot(17))
end

------------
-- __bxor --
------------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local src = [=[
    local t = { x = 17 }
    local u = { x = 3 }
    local m = {
      __bxor = function(a, b)
        if type(a) == "table" then
          a = a.x
        end
        if type(b) == "table" then
          b = b.x
        end
        return a ~ b
      end
    }
    
    setmetatable( t, m )
    setmetatable( u, m )

    return 
      0x3A ~ t, 
         t ~ 0x3A,
         t ~ u
  ]=]

  local test = testUtils.codeTest(tester, "__bxor", env, libs, src)

  test:var_eq(1, 43)
  test:var_eq(2, 43)
  test:var_eq(3, 18)
end

------------
-- __shl --
------------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local src = [=[
    local t = { x = 17 }
    local u = { x = 3 }
    local m = {
      __shl = function(a, b)
        if type(a) == "table" then
          a = a.x
        end
        if type(b) == "table" then
          b = b.x
        end
        return a << b
      end
    }
    
    setmetatable( t, m )
    setmetatable( u, m )

    return 
      3 << t, 
      t << 3,
      t << u
  ]=]

  local test = testUtils.codeTest(tester, "__shl", env, libs, src)

  test:var_eq(1, 393216)
  test:var_eq(2,    136)
  test:var_eq(3,    136)
end

------------
-- __shr -- (arithmetic)
------------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local src = [=[
    local t = { x = 5 }
    local u = { x = 2 }
    local m = {
      __shr = function(a, b)
        if type(a) == "table" then
          a = a.x
        end
        if type(b) == "table" then
          b = b.x
        end
        return a >> b
      end
    }
    
    setmetatable( t, m )
    setmetatable( u, m )

    return 
      0xF17C >> t, 
      t >> 1,
      t >> u
  ]=]

  local test = testUtils.codeTest(tester, "__shr", env, libs, src)

  test:var_eq(1, 1931)
  test:var_eq(2,    2)
  test:var_eq(3,    1)
end

------------
-- __ashr -- (logical)
------------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local src = [=[
    local t = { x = 5 }
    local u = { x = 2 }
    local m = {
      __ashr = function(a, b)
        if type(a) == "table" then
          a = a.x
        end
        if type(b) == "table" then
          b = b.x
        end
        return a >>> b
      end
    }
    
    setmetatable( t, m )
    setmetatable( u, m )

    return 
      0xF17C >>> t, 
      t >>> 1,
      t >>> u
  ]=]

  local test = testUtils.codeTest(tester, "__ashr", env, libs, src)

  test:var_eq(1, 1931)
  test:var_eq(2,    2)
  test:var_eq(3,    1)
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- Equivalence / Comparison
----------
-- __eq --
----------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local src = [=[
    local t = { x = "world" }
    local u = { x = "world" }
    local v = { x = "world" }
    local m = {
      __eq = function(a, b)
        return a.x == b.x
      end
    }
    local m2 = {
      __eq = function(a, b)
        return a.x == b.x
      end
    }
    
    setmetatable( t, m )
    setmetatable( u, m )
    setmetatable( v, m2 )

    return 
      "hello " == t, 
        t == "!",
        t == u,
        not (t ~= u),
        t == v
  ]=]

  local test = testUtils.codeTest(tester, "__eq", env, libs, src)

  test:var_isFalse(1, "Expected false for arg #1, got $1")
  test:var_isFalse(2, "Expected false for arg #2, got $1")
  test:var_isTrue( 3, "Expected true for arg #3, got $1")
  test:var_isTrue( 4, "Expected true for arg #4, got $1")
  test:var_isFalse( 5, "Expected false for arg #5, got $1")
end

----------
-- __lt --
----------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local src = [=[
    local t = { x = 2 }
    local u = { x = 3 }
    local m = {
      __lt = function(a, b)
        if type(a) == "table" then
          a = a.x
        end
        if type(b) == "table" then
          b = b.x
        end
        return a < b
      end
    }
    
    setmetatable( t, m )
    setmetatable( u, m )

    return 
      1 < t, 
      t < 5,
      t < u,
      2 < t
  ]=]

  local test = testUtils.codeTest(tester, "__lt", env, libs, src)

  test:var_isTrue(1)
  test:var_isTrue(2)
  test:var_isTrue(3)
  test:var_isFalse(4)
end

----------
-- __le --
----------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local src = [=[
    local t = { x = 2 }
    local u = { x = 3 }
    local m = {
      __le = function(a, b)
        if type(a) == "table" then
          a = a.x
        end
        if type(b) == "table" then
          b = b.x
        end
        return a <= b
      end
    }
    
    setmetatable( t, m )
    setmetatable( u, m )

    return 
      1 <= t, 
      t <= 5,
      t <= u,
      2 <= t,
      99 <= t
  ]=]

  local test = testUtils.codeTest(tester, "__le", env, libs, src)

  test:var_isTrue(1)
  test:var_isTrue(2)
  test:var_isTrue(3)
  test:var_isTrue(4)
  test:var_isFalse(5)
end

return tester