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

--------------------------
-- can create coroutine --
--------------------------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local src = [=[
    local thread = coroutine.create(function() return 1 end)
    return thread, type(thread)
  ]=]

  local test = testUtils.codeTest(tester, "create", env, libs, src)

  test:var_eq(2, "thread", "Expected type `thread`, got $1")
  test:var_eq(1, 2, "Expected thread with id == 2, got $1")
end

----------------------------------------
-- resume non yielding returns values --
----------------------------------------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local src = [=[
    local thread = coroutine.create(function() return "ok" end)
    return coroutine.resume( thread )
  ]=]

  local test = testUtils.codeTest(tester, "non-yielding returns", env, libs, src)

  test:var_eq(1, "ok", "Expected return value \"ok\" from coroutine.resume, got $1")
end

-------------------------
-- resume accepts args --
-------------------------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local src = [=[
    local thread = coroutine.create(function( v ) return v end)
    return coroutine.resume( thread, "ok" )
  ]=]

  local test = testUtils.codeTest(tester, "resume accepts args", env, libs, src)

  test:var_eq(1, "ok", "Expected return value \"ok\" from coroutine.resume, got $1")
end

------------
-- running --
------------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local src = [=[
    local current, isMain = coroutine.running()
    return type(current), current, isMain
  ]=]

  local test = testUtils.codeTest(tester, "running", env, libs, src)

  test:var_eq(1, "thread", "Expected thread from coroutine.running(), got $1")
  test:var_eq(1, 1, "Expected coroutine.running() to return main thread with id 1, got $1")
  test:var_eq(1, true, "Expected isMain to be `true`, got $1")
end

-----------------------
-- status is running --
-----------------------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local src = [=[
    local current = coroutine.running()
    return coroutine.status( current )
  ]=]

  local test = testUtils.codeTest(tester, "status-running", env, libs, src)

  test:var_eq(1, "running", "Expected main thread to have status `running`, got $1")
end

-------------------------
-- status is suspended --
-------------------------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local src = [=[
    local thread = coroutine.create(function() return "ok" end)
    return coroutine.status(thread)
  ]=]

  local test = testUtils.codeTest(tester, "status-suspended", env, libs, src)

  test:var_eq(1, "suspended", "Expected new thread to have status suspended, got $1")
end

-----------
-- yield --
-----------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local src = [=[
    local thread = coroutine.create(function( arg ) 
      coroutine.yield( arg + 1 )  
      return "returned" 
    end)
    local x = coroutine.resume( thread, 10 )
    return x
  ]=]

  local test = testUtils.codeTest(tester, "yield", env, libs, src)

  test:var_eq(1, 11, "Expected yield value of 11, got $1")
end

--------------------
-- yield & resume --
--------------------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local src = [=[
    local thread = coroutine.create(function( arg ) 
      coroutine.yield( arg + 1 )  
      return "returned" 
    end)
    local x = coroutine.resume( thread, 10 )
    local y = coroutine.resume( thread, 15 )
    return x, y
  ]=]

  local test = testUtils.codeTest(tester, "yield & resume", env, libs, src)

  test:var_eq(1, 11, "Expected 2st resume to yield value of 11, got $1")
  test:var_eq(2, "returned", "Expected 2nd resume to return \"returned\" from thread, got $1")
end

--------------------
-- yield & resume --
--------------------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local src = [=[
    local thread = coroutine.create(function() end)
    coroutine.resume( thread )
    local status = coroutine.status( thread )
    return status
  ]=]

  local test = testUtils.codeTest(tester, "status-dead", env, libs, src)

  test:var_eq(1, "dead", "Expected finished thread to have status \"dead\", got $1")
end

return tester