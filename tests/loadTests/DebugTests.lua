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

-- -----------------------
-- -- debug - traceback --
-- -----------------------
-- do
--   local env = Env:new()
--   local common = testUtils.common(env)
--   local libs = testUtils.libs()
--   local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

--   local src = [=[
--     function foo()
--       return debug.traceback()
--     end
--     function bar()
--       return foo()
--     end
--     return bar()
--   ]=]

--   local test = testUtils.codeTest(tester, "debug-traceback", env, libs, src)

--   test:var_eq(1, [[stack traceback:
-- 	line 2 in function foo
-- 	line 5 in function bar
-- 	line 7 in UNIT_TEST]])
-- end

-- -----------------------------
-- -- debug - traceback table --
-- -----------------------------
-- do
--   local env = Env:new()
--   local common = testUtils.common(env)
--   local libs = testUtils.libs()
--   local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

--   local src = [=[
--     function foo()
--       return debug.tracebackTable()
--     end
--     function bar()
--       return foo()
--     end
--     local tb = bar()
--     return tb[1].name, tb[1].line, tb[2].name, tb[2].line, tb[3].name, tb[3].line
--   ]=]

--   local test = testUtils.codeTest(tester, "debug-traceback-table", env, libs, src)
  
--   test:var_eq(1, "function foo")
--   test:var_eq(2, 2)
--   test:var_eq(3, "function bar")
--   test:var_eq(4, 5)
--   test:var_eq(5, "UNIT_TEST")
--   test:var_eq(6, 7)
-- end

---------------------
-- debug - sethook --
---------------------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local src = [=[
    function foo(x)                                                   -- 1
      return 4 + x                                                    -- 2
    end                                                               -- 3
    function bar()                                                    -- 4
      return foo(99)                                                  -- 5
    end                                                               -- 6
                                                                      -- 7
    local log = {}                                                    -- 8
    debug.sethook(function(event, line, ...)                          -- 9
      local args = table.concat({...}, ", ") --call & return only     --10
      table.insert(log, "%s:%s {%s}":format(event,line or "", args))  --11
    end, "clr")                                                       --12
    bar()                                                             --13 first hooked line
    return table.unpack(log)                                          --14
  ]=]

  local test = testUtils.codeTest(tester, "debug-sethook", env, libs, src)
  
  local events = {
    "^line:13 {}",      --1
    "^call:4 {}",       --2
    "^line:5 {}",       --3
    "^call:1 {99}",     --4
    "^line:2 {}",       --5
    "^return:2 {103}",  --6
    "^return:5 {103}",  --7
    "^line:14 {}",      --8
    "^call:14 {.+",     --9
  }

  for i, info in ipairs(events) do
    test:expect(function()
      local actual = test.actionResults[i] or ""
      return not not actual:match(info), 
      ("Expected event %d to match `%s`, got `%s`"):format(i, info, actual)
    end)
  end
end

return tester