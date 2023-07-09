local Tester = require"TestRunner"
local Env = require"MockEnv"
local testUtils = require"libs/testUtils"

local matchers = require"MockProxy".static
local eq = matchers.eq
local any = matchers.any

local tester = Tester:new()

-----------------------------------------------------------------
-- Test data
-----------------------------------------------------------------

local tests = {
  ["1234"] = 1234,
  ["3 * 4 + 5 * 6"] = 42,
  ["5 * 9 - (-3+1)^2"] = 41,
  ["2 * (3 * 4)"] = 24,
  ["(3 * 4) * 2"] = 24,
  ["4^3^2"] = 262144, --4^9 not 64^2
  ["20 / 5 / 2"] = 2,
  ["20 / (5 / 2)"] = 8,
  ["t.add( 3,4 )"] = 7,
  ["10 + t.add( 5*6, 20/5 ) - 4"] = 40,
  ["10 - 5 == 20 / 4"] = true,
  ["10 .. 1 * 3"] = "103",
  ["1 * 3 .. 10"] = "310",
  ["not not 1"] = true,
}

-----------------------------------------------------------------
-- Tests
-----------------------------------------------------------------

do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope
  
  local setup = [=[
    t = {}
    
    function t.add( x, y )
      return x + y
    end

    t.inner = {
      value = 100
    }
  ]=]
  
  for expression, expected in pairs( tests ) do
    local test = tester:add("Order: "..expression, env, function()
      local scope = testUtils.newScope( Scope )
      local fullExpression = "return "..expression
      testUtils.run( setup, scope, Loader, Async )
      local results = testUtils.run( fullExpression, scope, Loader, Async ).varargs
      return results[1].value
    end)

    test:var_eq(1, expected, "Expression "..expression.." expected a value of "..tostring(expected)..", but got $1")
  end

end

return tester