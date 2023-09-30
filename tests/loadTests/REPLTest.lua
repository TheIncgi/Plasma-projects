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

  local file = io.open("libs/REPL.lua","r")
  local src = file:read"*all"
  file:close()

  local printProxy = common.printProxy

  local test = testUtils.codeTest(tester, "REPL", env, libs, src)

  test:var_eq(2, 12)
  test:var_eq(1, true)
end

return tester