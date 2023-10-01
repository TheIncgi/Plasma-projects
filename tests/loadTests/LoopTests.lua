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

-----------
-- while --
-----------
do
  --given
  local src = [=[
    x = 1
    while x <= 3 do
      print(x)
      x = x + 1
    end
  ]=]
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  --test code
  local test = testUtils.codeTest(tester, "while", env, libs, src)


  --expect
  local printProxy = common.printProxy
  for i = 1, 3 do
    printProxy{tostring(i)}:exact()
  end
end

----------------
-- for ipairs --
----------------
do
  --given
  local src = [=[
    t = {11,12,13,e="nope",f="don't"}
    for a,b in ipairs( t ) do
      print(a,b)
    end
  ]=]
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  --test code
  local test = testUtils.codeTest(tester, "for ipairs", env, libs, src)

  --expect
  local printProxy = common.printProxy
  for i = 1, 3 do
    printProxy{tostring(i), tostring(i+10)}:exact()
  end
end


return tester