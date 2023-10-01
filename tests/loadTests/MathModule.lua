local Tester = require"TestRunner"
local Env = require"MockEnv"
local testUtils = require"libs/testUtils"

local matchers = require"MockProxy".static
local eq = matchers.eq
local any = matchers.any

local tester = Tester:new()

local tests = {
  {func = "abs",    args = {-25}},
  {func = "acos",   args = {0}},
  {func = "asin",   args = {1}},
  {func = "atan",   args = {1}},
  {func = "atan2",  args = {1,2}},
  {func = "ceil",   args = {4.5}},
  {func = "cos",    args = {9}},
  {func = "cosh",   args = {9}},
  {func = "deg",    args = {3.14}},
  {func = "exp",    args = {10}},
  {func = "floor",  args = {4.5}},
  {func = "fmod",   args = {143.145, 15}},
  {func = "frexp",  args = {23452345}}, --invserse of ldexp
  {func = "ldexp",  args = {.75, 8}}, --https://www.gammon.com.au/scripts/doc.php?lua=math.ldexp (m,n) -> m*2^n
  {func = "log",    args = {10}},
  {func = "max",    args = {-10, 10, 99, 0}},
  {func = "min",    args = {-10, 10, 99, 0}},
  {func = "modf",   args = {143.145, 15}}, --like fmod, but has int and fractional part as different return values
  {func = "pow",    args = {7,5}},
  {func = "sin",    args = {1}},
  {func = "sinh",   args = {1}},
  {func = "sqrt",   args = {64}},
  {func = "rad",    args = {360}},
  {func = "tan",    args = {1}},
  {func = "tanh",   args = {1}},
}

-----------------------------------------------------------------
-- Tests
-----------------------------------------------------------------

-----------
-- multi --
-----------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local src = [=[
    return "%.4f":format( math.$1($2) )
  ]=]

  for i, info in ipairs( tests ) do
    local expected
    if #info.args > 0 then
      expected = math[ info.func ]( table.unpack(info.args) )
    else
      expected = math[ info.func ]()
    end

    local testSrc = src:gsub( "$1", info.func ):gsub("$2", table.concat(info.args,","))

    local test = testUtils.codeTest(tester, info.func, env, libs, testSrc)
  
    test:var_eq(1, ("%.4f"):format(expected))

  end

  
end

--------
-- pi --
--------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local src = [=[
    return "%.4f":format( math.pi )
  ]=]

  local test = testUtils.codeTest(tester, "pi", env, libs, src)

  test:var_eq(1, "3.1416")
end

---------------------
-- random and seed --
---------------------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local src = [=[
    math.randomseed(1234)
    return "%.4f, %.4f, %.4f":format(math.random(), math.random(), math.random())
  ]=]

  math.randomseed(1234)
  local expected = ("%.4f, %.4f, %.4f"):format(math.random(), math.random(), math.random())

  local test = testUtils.codeTest(tester, "random and seed", env, libs, src)

  test:var_eq(1, expected)
end


return tester