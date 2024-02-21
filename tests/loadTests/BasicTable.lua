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

--------------
-- table [] --
--------------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local src = [=[
    local t = { "ok" }
    return t[1]
  ]=]

  local test = testUtils.codeTest(tester, "basic index by []", env, libs, src)

  test:var_eq(1, "ok")
end

-------------
-- [index] --
-------------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local src = [=[
    local a, b = "h", "ello"
    local t = {
        1000,
        ["foo bar"] = 15,
        cow = 10,
        [a..b] = true
    }

    return
        t[1], t["foo bar"], t["cow"], t["hello"]
  ]=]

  local test = testUtils.codeTest(tester, "multiple index by []", env, libs, src)

  test:var_eq(1, 1000, "value 1 expected 1000, got $1")
  test:var_eq(2, 15, "value 2 expected 15, got $1")
  test:var_eq(3, 10, "value 3 expected 10, got $1")
  test:var_eq(4, true, "value 4 expected true, got $1")
end

-----------
-- {...} --
-----------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local src = [=[
    function test(...)
      return {...}
    end

    return #test(1,2,3)
  ]=]

  local test = testUtils.codeTest(tester, "{...}", env, libs, src)

  test:var_eq(1, 3)
end

-----------
-- {x=(foo or bar),y=...} --
-----------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local src = [=[
    local utils = {}
    function utils.darken(clr, f )
      f = f or .5
      return {
        r = (clr.r or clr[1])*f, 
        g = (clr.g or clr[2])*f, 
        b = (clr.b or clr[2])*f
      }
    end

    return "ok"
  ]=]

  local test = testUtils.codeTest(tester, "table with ()", env, libs, src)

  test:var_eq(1, "ok")
end

----------------------------------
-- {} with assignment set spill --
----------------------------------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  -- common.printProxy.target = print

  local src = [==[
   z = {value = 5}

    zz = {
      r = z["value"],
      y2 = 5 * z.value,
      text = "Main Menu",
    }

    print"ok"
  ]==]
    
  local test = testUtils.codeTest(tester, "{} with assignment set spill", env, libs, src)
  
  common.printProxy{"ok"}.exact()
end


return tester