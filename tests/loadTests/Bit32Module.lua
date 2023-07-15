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
--band lrotate extract
--rshift bor bnot arshift
--bxor replace lshift btest rrotate
local tests = {
  {func = "", 10}
}

-----------
-- bit32 --
-----------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  for i, t in ipairs(tests) do
    local src = [=[
      return bit32.$1( $2 )
    ]=]

    src:gsub("$1", t.func):gsub("$2", table.concat(t,", "))
    local expected = { bit32[t.func]( table.unpack(t) ) }

    local test = testUtils.codeTest(tester, "t.func", env, libs, src, #t)

    for j = 1, #expected do
      test:var_eq(1, expected[j], ("Expected return value #%d to be %s, got $1"):format(j, tostring(expected[j])))
    end
  end
end

return tester