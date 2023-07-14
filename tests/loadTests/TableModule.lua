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

------------------------
-- table insert first --
------------------------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local src = [=[
    local t = { "ok" }
    table.insert(t,1,"first")
    return t[1]
  ]=]

  local test = tester:add("insert first", env, function()
    local scope = testUtils.newScope(Scope)
    local results = testUtils.run(src, scope, Loader, Async).varargs
    if not results[1] then error"Expected return value" end
    return results[1].value
  end)

  test:var_eq(1, "first")
end

------------------------
-- table insert middle --
------------------------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local src = [=[
    local t = { "first","last" }
    table.insert(t,2,"middle")
    return t[2]
  ]=]

  local test = tester:add("insert middle", env, function()
    local scope = testUtils.newScope(Scope)
    local results = testUtils.run(src, scope, Loader, Async).varargs
    if not results[1] then error"Expected return value" end
    return results[1].value
  end)

  test:var_eq(1, "middle")
end

------------------------
-- table insert last --
------------------------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local src = [=[
    local t = { "ok" }
    table.insert(t,"last")
    return t[#t]
  ]=]

  local test = tester:add("insert last", env, function()
    local scope = testUtils.newScope(Scope)
    local results = testUtils.run(src, scope, Loader, Async).varargs
    if not results[1] then error"Expected return value" end
    return results[1].value
  end)

  test:var_eq(1, "last")
end

------------------------
-- table remove first --
------------------------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local src = [=[
    local t = { "first","middle","last" }
    local v = table.remove(t, 1)
    return v, t[1]
  ]=]

  local test = tester:add("remove first", env, function()
    local scope = testUtils.newScope(Scope)
    local results = testUtils.run(src, scope, Loader, Async).varargs
    if not results[1] or not results[2] then error"Expected return value" end
    return results[1].value, results[2].value
  end)

  test:var_eq(1, "first", "Expected return value \"first\" from `table.remove`, got $1")
  test:var_eq(2, "middle", "Expected first element removed, found $1")
end

------------------------
-- table remove middle --
------------------------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local src = [=[
    local t = { "first","middle","last" }
    local v = table.remove(t, 2)
    return v, t[2]
  ]=]

  local test = tester:add("remove middle", env, function()
    local scope = testUtils.newScope(Scope)
    local results = testUtils.run(src, scope, Loader, Async).varargs
    if not results[1] or not results[2] then error"Expected return value" end
    return results[1].value, results[2].value
  end)

  test:var_eq(1, "middle", "Expected return value \"middle\" from `table.remove`, got $1")
  test:var_eq(2, "last", "Expected middle element removed, found $1")
end

------------------------
-- table remove last --
------------------------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local src = [=[
    local t = { "first","middle","last" }
    local v = table.remove(t, 3)
    return v, #t
  ]=]

  local test = tester:add("remove last", env, function()
    local scope = testUtils.newScope(Scope)
    local results = testUtils.run(src, scope, Loader, Async).varargs
    if not results[1] or not results[2] then error"Expected return value" end
    return results[1].value, results[2].value
  end)

  test:var_eq(1, "last", "Expected return value \"last\" from `table.remove`, got $1")
  test:var_eq(2, 2, "Expected table length of 2, got $1")
end

----------------
-- table pack --
----------------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local src = [=[
    local t = table.pack( "first","middle","last" )
    return #t, t[1], t.n
  ]=]

  local test = tester:add("pack", env, function()
    local scope = testUtils.newScope(Scope)
    local results = testUtils.run(src, scope, Loader, Async).varargs
    if not results[1] or not results[2] or not results[3] then error"Expected return values" end
    return results[1].value, results[2].value, results[3]
  end)

  test:var_eq(1, 3, "Expected table length of 3, got $1")
  test:var_eq(2, "first", "Expected table index 1 to contain \"first\", got $1")
  test:var_eq(3, 3, "Expected table `.n` to contain table length (3), got $1")
end

------------------
-- table concat --
------------------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local src = [=[
    local t = { "first","middle","last" }
    return table.concat(t)
  ]=]

  local test = tester:add("concat", env, function()
    local scope = testUtils.newScope(Scope)
    local results = testUtils.run(src, scope, Loader, Async).varargs
    if not results[1] then error"Expected return value" end
    return results[1].value
  end)

  test:var_eq(1, "firstmiddlelast")
end

------------------------------
-- table concat with joiner --
------------------------------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local src = [=[
    local t = { "first","middle","last" }
    return table.concat(t, ",")
  ]=]

  local test = tester:add("concat with joiner", env, function()
    local scope = testUtils.newScope(Scope)
    local results = testUtils.run(src, scope, Loader, Async).varargs
    if not results[1] then error"Expected return value" end
    return results[1].value
  end)

  test:var_eq(1, "first,middle,last")
end

----------------------------------------
-- table concat with joiner and range --
----------------------------------------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local src = [=[
    local t = { "foo","first","middle","last","bar"  }
    return table.concat(t, ",", 2, 4)
  ]=]

  local test = tester:add("concat with joiner and range", env, function()
    local scope = testUtils.newScope(Scope)
    local results = testUtils.run(src, scope, Loader, Async).varargs
    if not results[1] then error"Expected return value" end
    return results[1].value
  end)

  test:var_eq(1, "first,middle,last")
end

------------
-- unpack --
------------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local src = [=[
    local t = { "first","middle","last"  }
    return table.unpack(t)
  ]=]

  local test = tester:add("unpack", env, function()
    local scope = testUtils.newScope(Scope)
    local results = testUtils.run(src, scope, Loader, Async).varargs
    if not results[1] or not results[2] or not results[3] then error"Expected return value" end
    return results[1].value, results[2].value, results[3].value
  end)

  test:var_eq(1, "first",  "Expected unpack value 1 to be \"first\", got $1")
  test:var_eq(2, "middle", "Expected unpack value 2 to be \"middle\", got $1")
  test:var_eq(3, "last",   "Expected unpack value 3 to be \"last\", got $1")
end

----------
-- sort --
----------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local src = [=[
    local t = { 4,50,9,1,12,6  }
    table.sort(t, function( a, b )
      return a < b
    end)
    return t
  ]=]

  local test = tester:add("sort", env, function()
    local scope = testUtils.newScope(Scope)
    local results = testUtils.run(src, scope, Loader, Async).varargs
    if not results[1] then error"Expected return value" end
    local t = results[1].value
    local indexer = Loader.tableIndexes[t]
    if not indexer then error("no table index available") end

    local n = 0
    local sorted = true
    for i=1, #indexer-1 do
      local k1 = indexer[i]
      local v1 = t[k1]
      local k2 = indexer[i+1]
      local v2 = t[k2]
      if v2.value < v1.value then
        sorted = false
      end
    end

    return #indexer == 6 and sorted
  end)

  test:var_isTrue(1)
end

--insert remove pack concat sort unpack

-----------
--       --
-----------
-- do
--   local env = Env:new()
--   local common = testUtils.common(env)
--   local libs = testUtils.libs()
--   local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

--   local src = [=[
    
--   ]=]

--   local test = tester:add("PLACE HOLDER", env, function()
--     local scope = testUtils.newScope(Scope)
--     local results = testUtils.run(src, scope, Loader, Async).varargs
--     if not results[1] or not results[2] then error"Expected return value" end
--     return results[1].value
--   end)

--   test:var_eq(1, 2)
-- end

return tester