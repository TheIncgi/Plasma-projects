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

  local test = tester:add("sub", env, function()
    local scope = testUtils.newScope(Scope)
    local results = testUtils.run(src, scope, Loader, Async).varargs
    if not results then error"Expected return value" end
    return results[1].value
  end)

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

  local test = tester:add("find", env, function()
    local scope = testUtils.newScope(Scope)
    local results = testUtils.run(src, scope, Loader, Async).varargs
    if not results[1] or not results[2] then error"Expected return value" end
    return results[1].value, results[2].value
  end)

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

  local test = tester:add("rep", env, function()
    local scope = testUtils.newScope(Scope)
    local results = testUtils.run(src, scope, Loader, Async).varargs
    if not results[1] then error"Expected return value" end
    return results[1].value
  end)

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

  local test = tester:add("match", env, function()
    local scope = testUtils.newScope(Scope)
    local results = testUtils.run(src, scope, Loader, Async).varargs
    if not results[1] then error"Expected return value" end
    return results[1].value
  end)

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

  local test = tester:add("gmatch", env, function()
    local scope = testUtils.newScope(Scope)
    local results = testUtils.run(src, scope, Loader, Async).varargs
    if not results[1] then error"Expected return value" end
    return results[1].value
  end)

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

  local test = tester:add("char", env, function()
    local scope = testUtils.newScope(Scope)
    local results = testUtils.run(src, scope, Loader, Async).varargs
    if not results[1] then error"Expected return value" end
    return results[1].value
  end)

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

  local test = tester:add("reverse", env, function()
    local scope = testUtils.newScope(Scope)
    local results = testUtils.run(src, scope, Loader, Async).varargs
    if not results[1] then error"Expected return value" end
    return results[1].value
  end)

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

  local test = tester:add("upper", env, function()
    local scope = testUtils.newScope(Scope)
    local results = testUtils.run(src, scope, Loader, Async).varargs
    if not results[1] then error"Expected return value" end
    return results[1].value
  end)

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

  local test = tester:add("len", env, function()
    local scope = testUtils.newScope(Scope)
    local results = testUtils.run(src, scope, Loader, Async).varargs
    if not results[1] then error"Expected return value" end
    return results[1].value
  end)

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

  local test = tester:add("gsub", env, function()
    local scope = testUtils.newScope(Scope)
    local results = testUtils.run(src, scope, Loader, Async).varargs
    if not results[1] then error"Expected return value" end
    return results[1].value
  end)

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

  local test = tester:add("byte", env, function()
    local scope = testUtils.newScope(Scope)
    local results = testUtils.run(src, scope, Loader, Async).varargs
    if not results[1] then error"Expected return value" end
    return results[1].value
  end)

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

  local test = tester:add("format", env, function()
    local scope = testUtils.newScope(Scope)
    local results = testUtils.run(src, scope, Loader, Async).varargs
    if not results[1] then error"Expected return value" end
    return results[1].value
  end)

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

  local test = tester:add("lower", env, function()
    local scope = testUtils.newScope(Scope)
    local results = testUtils.run(src, scope, Loader, Async).varargs
    if not results[1] then error"Expected return value" end
    return results[1].value
  end)

  test:var_eq(1, "hello world!")
end

return tester