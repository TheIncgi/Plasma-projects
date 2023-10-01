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

---------
-- sub --
---------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local src = [=[
    local str = "Hello world!"
    return str:sub(2,5)
  ]=]

  local test = testUtils.codeTest(tester, "sub", env, libs, src)

  test:var_eq(1, "ello")
end

----------
-- find --
----------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local src = [=[
    local str = "Hello world!"
    return str:find"ello"
  ]=]

  local test = testUtils.codeTest(tester, "find", env, libs, src)

  test:var_eq(1, 2)
  test:var_eq(2, 5)
end

---------
-- rep --
---------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local src = [=[
    local str = "*"
    return #str:rep(10)
  ]=]

  local test = testUtils.codeTest(tester, "rep", env, libs, src)

  test:var_eq(1, 10)
end

-----------
-- match --
-----------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local src = [=[
    local str = "Hello world!"
    return str:match"e."
  ]=]

  local test = testUtils.codeTest(tester, "match", env, libs, src)

  test:var_eq(1, "el")
end

------------
-- gmatch --
------------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local src = [=[
    local str = "Hello world!"
    local t = {}
    local i = 0
    for x in str:gmatch"[^ ]+" do
      i = i+1
    end
    return i
  ]=]

  local test = testUtils.codeTest(tester, "gmatch", env, libs, src)

  test:var_eq(1, 2)
end

----------
-- char --
----------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local src = [=[
    return string.char( 97 )
  ]=]

  local test = testUtils.codeTest(tester, "char", env, libs, src)

  test:var_eq(1, "a")
end

-----------
-- dump --
-----------
do
  --TODO
end

-------------
-- reverse --
-------------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local src = [=[
    local str = "Hello world!"
    return str:reverse()
  ]=]

  local test = testUtils.codeTest(tester, "reverse", env, libs, src)

  test:var_eq(1, "!dlrow olleH")
end

-----------
-- upper --
-----------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local src = [=[
    local str = "Hello world!"
    return str:upper()
  ]=]

  local test = testUtils.codeTest(tester, "upper", env, libs, src)

  test:var_eq(1, "HELLO WORLD!")
end

---------
-- len --
---------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local src = [=[
    local str = "Hello world!"
    return str:len()
  ]=]

  local test = testUtils.codeTest(tester, "len", env, libs, src)

  test:var_eq(1, 12)
end

----------
-- gsub --
----------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local src = [=[
    local str = "Hello world!"
    return str:gsub("l","L")
  ]=]

  local test = testUtils.codeTest(tester, "gsub", env, libs, src)

  test:var_eq(1, "HeLLo worLd!")
end

----------
-- byte --
----------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local src = [=[
    return string.byte"a"
  ]=]

  local test = testUtils.codeTest(tester, "byte", env, libs, src)

  test:var_eq(1, 97)
end

------------
-- format --
------------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local src = [=[
    local str = "%s %s!"
    return str:format("Hello", "world")
  ]=]

  local test = testUtils.codeTest(tester, "format", env, libs, src)

  test:var_eq(1, "Hello world!")
end

-----------
-- lower --
-----------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local src = [=[
    local str = "Hello world!"
    return str:lower()
  ]=]

  local test = testUtils.codeTest(tester, "lower", env, libs, src)

  test:var_eq(1, "hello world!")
end

return tester