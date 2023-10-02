local Tester = require"TestRunner"
local Env = require"MockEnv"
local testUtils = require"libs/testUtils"

local matchers = require"MockProxy".static
local eq = matchers.eq
local any = matchers.any

local tester = Tester:new()

local src = [=[
LOADED = require"TheIncgi/Plasma-projects/main/libs/class"

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
return LOADED, a:getValue(), b:getValue(), c:getValue()
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

  testUtils.setupRequire( Async, Net, common, {"TheIncgi/Plasma-projects/main/libs/class"})

  local test = testUtils.codeTest(tester, "class", env, libs, src)

  test:var_eq(1, true)
  test:var_eq(2, 11)
  test:var_eq(3, 20)
  test:var_eq(4,  0)
end

return tester