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
    i = 0
    for a,b in ipairs( t ) do
      print(a,b)
      i = i + 1
    end
    return i
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
  test:var_eq(1, 3)
end

---------------
-- for break --
---------------
do
  --given
  local src = [=[
    i = 0
    for j=1,10 do
      i = i + 1
      break
    end
    return i
  ]=]
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  --test code
  local test = testUtils.codeTest(tester, "for break", env, libs, src)

  --expect
  test:var_eq(1, 1)
end

------------------
-- for continue --
------------------
do
  --given
  local src = [=[
    i = 0
    for j=1,10 do
      if j < 5 then continue end
      i = i + 1
    end
    return i
  ]=]
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  --test code
  local test = testUtils.codeTest(tester, "for continue", env, libs, src)

  --expect
  test:var_eq(1, 6)
end

------------------
-- repeat until --
------------------
do
  --given
  local src = [=[
    local i = 0
    repeat
      i = i+1
    until i > 5
    return i
  ]=]
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  --test code
  local test = testUtils.codeTest(tester, "repeat until", env, libs, src)

  --expect
  test:var_eq(1, 6)
end


return tester