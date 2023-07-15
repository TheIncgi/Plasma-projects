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

  local test = tester:add("basic index by []", env, function()
    local scope = testUtils.newScope(Scope)
    local results = testUtils.run(src, scope, Loader, Async).varargs
    if not results[1] then error"Expected return value" end
    return results[1].value
  end)

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

  local test = tester:add("multiple index by []", env, function()
    local scope = testUtils.newScope(Scope)
    local results = testUtils.run(src, scope, Loader, Async).varargs
    if not results then error"Expected return value" end
    return 
        results[1].value,
        results[2].value,
        results[3].value,
        results[4].value
  end)

  test:var_eq(1, 1000, "value 1 expected 1000, got $1")
  test:var_eq(2, 15, "value 2 expected 15, got $1")
  test:var_eq(3, 10, "value 3 expected 10, got $1")
  test:var_eq(4, true, "value 4 expected true, got $1")
end

return tester