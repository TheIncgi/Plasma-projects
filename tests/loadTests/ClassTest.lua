local Tester = require"TestRunner"
local Env = require"MockEnv"
local testUtils = require"libs/testUtils"

local matchers = require"MockProxy".static
local eq = matchers.eq
local any = matchers.any

local tester = Tester:new()

local classCode
do
  local file = io.open("libs/class.lua", "r")
  classCode = file:read"*all"
  file:close()
end
local src = classCode..[=[

MyClass = class"MyClass"
MyClass.value = 0 --default

local _new = MyClass.new
function MyClass:new( v, ... )
  local obj = _new( self )
  obj.value = v
  return obj
end

function MyClass:getValue()
  return self.value
end

function MyClass:inc()
  self.value = self.value + 1
end

local a,b,c = MyClass:new( 10 ), MyClass:new( 20 ), MyClass:new()
a:inc()
return a:getValue(), b:getValue(), c:getValue()
]=]

-----------------------------------------------------------------
-- Tests
-----------------------------------------------------------------

-----------
-- class --
-----------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local test = testUtils.codeTest(tester, "class", env, libs, src)

  test:var_eq(1, 11)
  test:var_eq(2, 20)
  test:var_eq(3,  0)
end

return tester