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

--------------
-- Json Obj --
--------------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  testUtils.setupRequire( Async, Net, common, {
    "TheIncgi/Plasma-projects/main/libs/class",
    "TheIncgi/Plasma-projects/main/libs/Json",
  })

  local src = [=[
Json = require"TheIncgi/Plasma-projects/main/libs/Json"

local obj = Json.static.JsonObject:new() --{"obj": 10, "thing":[1,2,3]}'
obj:put("h", 10)
local tbl = obj:toTable()
return tbl.h--, table.unpack(tbl.thing)
]=]
  local test = testUtils.codeTest(tester, "Json Obj", env, libs, src)

  test:var_eq(1, 10)
  
end

----------------
-- Json Array --
----------------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  testUtils.setupRequire( Async, Net, common, {
    "TheIncgi/Plasma-projects/main/libs/class",
    "TheIncgi/Plasma-projects/main/libs/Json",
  })

  local src = [=[
Json = require"TheIncgi/Plasma-projects/main/libs/Json"

local obj = Json.static.JsonArray:new() --{"obj": 10, "thing":[1,2,3]}'
obj:put(1)
obj:put(3)
obj:put(5)
local tbl = obj:toTable()
return table.unpack(tbl)
]=]
  local test = testUtils.codeTest(tester, "Json Array", env, libs, src)

  test:var_eq(1, 1)
  test:var_eq(2, 3)
  test:var_eq(3, 5)
  
end

----------------
-- Json Mixed --
----------------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  testUtils.setupRequire( Async, Net, common, {
    "TheIncgi/Plasma-projects/main/libs/class",
    "TheIncgi/Plasma-projects/main/libs/Json",
  })

  local src = [=[
Json = require"TheIncgi/Plasma-projects/main/libs/Json"

local obj = Json:new'{"obj": 10, "thing":[1,2,3]}'

local tbl = obj:toTable()
return tbl.obj, table.unpack(tbl.thing)
]=]
  local test = testUtils.codeTest(tester, "Json Mixed", env, libs, src)

  test:var_eq(1, 10)
  test:var_eq(2, 1)
  test:var_eq(3, 2)
  test:var_eq(4, 3)
end

return tester