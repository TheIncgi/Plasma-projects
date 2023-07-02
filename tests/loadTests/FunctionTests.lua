local Tester = require"TestRunner"
local Env = require"MockEnv"

local matchers = require"MockProxy".static
local eq = matchers.eq
local any = matchers.any

local LoaderLibs = {}


local tester = Tester:new()

-----------------------------------------------------------------
-- Test data
-----------------------------------------------------------------

-----------------------------------------------------------------
-- Test utils
-----------------------------------------------------------------

-- cleaning out mocked functions
local function resetLibs()
  package.loaded["libs/Load"] = nil
  local libs = require"libs/Load"
  LoaderLibs.Loader = libs.Loader
  LoaderLibs.Async = libs.Async
  LoaderLibs.Scope = libs.Scope
end

-- execute source code
local function run( src, scope )
  local Loader, Async = LoaderLibs.Loader, LoaderLibs.Async

  local rawTokens = Async.sync( Loader.tokenize(src) )
  local tokens = Async.sync( Loader.cleanupTokens( rawTokens ) )
  local instructions = Async.sync( Loader.buildInstructions(tokens)  )
  Async.sync( Loader.batchPostfix(instructions) )
  Async.sync( Loader.execute( instructions, scope ) )
end

local function newScope()
  local scope =  LoaderLibs.Scope:new("UNIT_TEST", 1, nil, 1)
  scope:addGlobals()
  return scope
end

local function val( v )
  return LoaderLibs.Loader._val( v )
end

local function common(env)
  local printProxy = env:proxy("print", function() end)
  printProxy.realDefault = true

  return {printProxy = printProxy}
end

-----------------------------------------------------------------
-- Tests
-----------------------------------------------------------------

-----------------
-- Hello world --
-----------------
do resetLibs()
  --given
  local src = [=[
    function test()
      local function x(...)
        return ...
      end
      IN_FUNC = not not x --fails not not function
    end
    test()
    OUT_FUNC = not not x
  ]=]
  local env = Env:new()
  local scope = newScope()
  local common = common(env)

  --test code
  local test = tester:add("executes hello world", env, function()
    run( src, scope )
    return scope:get"IN_FUNC".value, scope:get"OUT_FUNC".value
  end)

  --expect
  test:var_isTrue(1, "expected global `IN_FUNC` to be `true`, actual: $1") --1, first return value
  test:var_isFalse(2, "expected global `OUT_FUNC` to be `false`, actual: $1") --2, second return value
end

return tester