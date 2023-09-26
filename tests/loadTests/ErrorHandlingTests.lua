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
-- pcall - clean --
-------------------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local src = [=[
    local function safe(x)
      return x + 2
    end

    return pcall( safe, 10 )
  ]=]

  local test = testUtils.codeTest(tester, "pcall-clean", env, libs, src)

  test:var_eq(2, 12)
  test:var_eq(1, true)
end

-------------------
-- pcall - error --
-------------------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local src = [=[
    local function unsafe()
      return x + 2
    end

    return pcall( unsafe )
  ]=]

  local test = testUtils.codeTest(tester, "pcall-err", env, libs, src)

  test:var_eq(1, false)
  testUtils.var_pattern(test, 2, "attempt to perform arithmetic")
end

-------------------
-- xpcall - clean --
-------------------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local src = [=[
    local function safe(x)
      return x + 2
    end

    local function handler(msg, env)
      error"Should not call"
    end

    return xpcall( safe, handler, 10 )
  ]=]

  local test = testUtils.codeTest(tester, "xpcall-clean", env, libs, src)

  test:var_eq(1, true)
  test:var_eq(2, 12)
end

-------------------
-- xpcall - error --
-------------------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local src = [=[
    local function unsafe()
      return x + 2
    end

    local function handler(msg, env)
      return "handled"
    end

    return xpcall( unsafe, handler )
  ]=]

  local test = testUtils.codeTest(tester, "xpcall-err", env, libs, src)

  test:var_eq(1, false)
  test:var_eq(2, "handled")
end

-------------------
-- xpcall - inspect --
-------------------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local src = [=[
    local function unsafe( y )
      return x + 2
    end

    local function handler(msg, env)
      return "handled-"..env.y
    end

    return xpcall( unsafe, handler, 15 )
  ]=]

  local test = testUtils.codeTest(tester, "xpcall-inspect", env, libs, src)

  test:var_eq(1, false)
  test:var_eq(2, "handled-15")
end

------------------
-- asset - true --
------------------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local src = [=[
    function getThing()
      return 1, 2, 3
    end
    return assert( getThing() )
  ]=]

  local test = testUtils.codeTest(tester, "assert-true", env, libs, src)

  test:var_eq(1, 1)
  test:var_eq(2, 2)
  test:var_eq(3, 3)
end

------------------
-- asset - false --
------------------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local src = [=[
    function getThing()
      return false, "didn't work"
    end
    return assert( getThing() )
  ]=]

  local test = testUtils.codeTest(tester, "assert-false", env, libs, src)

  test:expectError("didn't work")
end

-----------
-- error --
-----------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local src = [=[
    return pcall(error, "oops")
  ]=]

  local test = testUtils.codeTest(tester, "error", env, libs, src)

  test:var_eq(1, false)
  testUtils.var_pattern(test, 2, "oops$")
end

-------------------
-- error - level --
-------------------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local src = [=[
    function foo()
      return pcall(error, "oops", 2)
    end
    function bar()
      return foo()
    end
    return bar()
  ]=]

  local test = testUtils.codeTest(tester, "error-level", env, libs, src)

  test:var_eq(1, false)
  testUtils.var_pattern(test, 2, "Error occured at function bar:5: oops$")
end

return tester