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

----------------
-- MainMenu --
----------------
-- do
--   local env = Env:new()
--   local common = testUtils.common(env)
--   local libs = testUtils.libs()
--   local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

--   common.printProxy.target = print

--   local src = [=[
--     g = {}
--     t = {z=1}

--     function t:foo( x )
--       return g.bar( self, x )
--     end

--     function g:bar( x )
--       print(self, self.z, x)
--       return self.z + x
--     end

--     print("g: "..tostring(g))
--     print("t: "..tostring(t))
--     return t:foo( 10 )
--   ]=]
--   local test = testUtils.codeTest(tester, "self", env, libs, src)

--   test:var_eq(1, 11)
-- end

----------------
-- MainMenu --
----------------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  common.printProxy.target = print

  testUtils.setupRequire( Async, Net, common, {
    "TheIncgi/Plasma-projects/main/libs/class",
    "TheIncgi/Plasma-projects/main/libs/Json",
    "TheIncgi/Plasma-projects/IK-Arm/libs/utils",
    "TheIncgi/Plasma-projects/IK-Arm/IK-Arm/screens/MainMenu",
    "TheIncgi/Plasma-projects/IK-Arm/IK-Arm/screens/Button",
    "TheIncgi/Plasma-projects/IK-Arm/IK-Arm/screens/Text",
    "TheIncgi/Plasma-projects/IK-Arm/IK-Arm/screens/Screen",
    "TheIncgi/Plasma-projects/IK-Arm/IK-Arm/UI",
    "TheIncgi/Plasma-projects/IK-Arm/IK-Arm/Main",
    "TheIncgi/Plasma-projects/IK-Arm/libs/MultiTaskBase",
    -- "TheIncgi/Plasma-projects/IK-Arm/IK-Arm/API",
    -- "TheIncgi/Plasma-projects/IK-Arm/IK-Arm/DataManager",
  })

  local src = [=[
    require"TheIncgi/Plasma-projects/IK-Arm/IK-Arm/Main"
]=]
  local test = testUtils.codeTest(tester, "Json Mixed", env, libs, src)

end

return tester