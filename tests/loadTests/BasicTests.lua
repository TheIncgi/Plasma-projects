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
  local common = testUtils.common(env)
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local printProxy = env:proxy("print", function() end)

  --test code
  local test = testUtils.codeTest(tester, "print hello world", env, libs, src)
  
  --expect
  printProxy{ "Hello world!" }.exact()
end

---------------
-- negative --
---------------
do
  --given
  local src = [=[
    local t = -0.99
    return t
  ]=]
  local env = Env:new()
  local libs = testUtils.libs()
  local common = testUtils.common(env)
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  --test code
  local test = testUtils.codeTest(tester, "negative", env, libs, src)
  
  --expect
  test:var_eq(1, -0.99)
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
  local common = testUtils.common(env)
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
  local common = testUtils.common(env)
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
  local common = testUtils.common(env)
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
  local common = testUtils.common(env)
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local test = testUtils.codeTest( tester, ",(), order", env, libs, src )
  
  test:var_eq(1, 5)
  test:var_eq(2, 1)
  test:var_eq(3, 7)
end

---------
--next --
---------
do
  --given
  local src = [=[
    t = {10,20, foo="bar"}
    a,b = next(t)
    c,d = next(t,a)
    e,f = next(t,c)
    return a,b,c,d,e,f
  ]=]
  local env = Env:new()
  local libs = testUtils.libs()
  local common = testUtils.common(env)
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local test = testUtils.codeTest( tester, "next", env, libs, src )
  
  test:var_eq(1, 1)
  test:var_eq(2, 10)
  test:var_eq(3, 2)
  test:var_eq(4, 20)
  test:var_eq(5, "foo")
  test:var_eq(6, "bar")
end

------------------------------
-- optional comma for table --
------------------------------
do
  --given
  local src = [=[
    t = {
      10,
      20, 
      30,
    }
    return table.unpack(t)
  ]=]
  local env = Env:new()
  local libs = testUtils.libs()
  local common = testUtils.common(env)
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local test = testUtils.codeTest( tester, "opt table comma", env, libs, src )
  
  test:var_eq(1, 10)
  test:var_eq(2, 20)
  test:var_eq(3, 30)
end

-----------------------
--print(function)    --
-----------------------
do
  --given
  local src = [=[
    function example(x,y)
      return x+y
    end
    print( example )
  ]=]
  local env = Env:new()
  local libs = testUtils.libs()
  local common = testUtils.common(env)
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  common.printProxy{ function(x)
    return type(x) == "string" and x:find"function"
  end }.matched()

  local test = testUtils.codeTest( tester, "next", env, libs, src ) 
end

---------
-- ..# --
---------
do
  --given
  local src = [=[
    x = "foo"
    return "len: "..#x
  ]=]
  local env = Env:new()
  local libs = testUtils.libs()
  local common = testUtils.common(env)
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local test = testUtils.codeTest( tester, "..#", env, libs, src )

  test:var_eq(1,"len: 3")
end

-----------------------
-- unm table element --
-----------------------
do
  --given
  local src = [=[
    t = {x=45}
    u = -t.x
    return u
  ]=]
  local env = Env:new()
  local libs = testUtils.libs()
  local common = testUtils.common(env)
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local test = testUtils.codeTest( tester, "unm table element", env, libs, src )

  test:var_eq(1,-45)
end

-------------------
-- declare local --
-------------------
do
  --given
  local src = [=[
    x = 15
    do
      local x,y,z
      x = 10
    end
    return x
  ]=]
  local env = Env:new()
  local libs = testUtils.libs()
  local common = testUtils.common(env)
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local test = testUtils.codeTest( tester, "unm table element", env, libs, src )

  test:var_eq(1,15)
end

return tester