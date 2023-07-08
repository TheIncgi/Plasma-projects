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
  LoaderLibs.Async  = libs.Async
  LoaderLibs.Scope  = libs.Scope
  LoaderLibs.Net    = libs.Net
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
  scope:addPlasmaGlobals()
  return scope
end

local function val( v )
  return LoaderLibs.Loader._val( v )
end

local function common(env)
  local printProxy = env:proxy("print", function() end)
  printProxy.realDefault = true

  local output = env:proxy("output", function() end)
  local trigger = env:proxy("trigger", function() end)
  local write_var = env:proxy("write_var", function() end)
  local read_var = env:proxy("read_var", function() end)

  return {
    printProxy = printProxy,
    output = output,
    write_var = write_var,
    read_var = read_var
  }
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
  local common = common(env)
  
  --test code
  local test = tester:add("executes hello world", env, function()
    local scope = newScope()
    run( src, scope )
    return scope:get"IN_FUNC".value, scope:get"OUT_FUNC".value
  end)

  --expect
  test:var_isTrue(1, "expected global `IN_FUNC` to be `true`, actual: $1") --1, first return value
  test:var_isFalse(2, "expected global `OUT_FUNC` to be `false`, actual: $1") --2, second return value
  V1,V2,V3,V4,V5,V6,V7,V8 = nil, nil, nil, nil, nil, nil, nil, nil
end

-----------------
--   Require   --
-----------------
do resetLibs()
  local src = [=[
    local HelloRequire = require"TheIncgi/Plasma-projects/main/libs/HelloRequire"
    print( HelloRequire.msg )
  ]=]
  local HelloRequire = require"libs/HelloRequire"
  local env = Env:new()
  local common = common(env)
  local Net = LoaderLibs.Net
  local Async = LoaderLibs.Async
  
  local path = "TheIncgi/Plasma-projects/main/libs/HelloRequire"
  local url = "https://raw.githubusercontent.com/TheIncgi/Plasma-projects/main/libs/HelloRequire.lua"
  
  --expect print call with msg
  common.printProxy{ HelloRequire.msg }.exact()
  common.write_var{ url, "url"}.exact()
  common.output{ "require", 1 }.exactCompute(function(...)
    Async.insertTasks(
      {
        label = "UNIT TESTING - Require - Net result",
        func = function()
          V1 = [==[
            local foo = {}
            foo.msg = "$1"
            return foo
            ]==]
            V1 = V1:gsub( "$1", HelloRequire.msg ) --$ doesn't need escape since it's not at the end of the pattern
            Net.sourceCode()
            return true --task complete
          end
        }
      )
      --no return
    end)
    
    --test code
    local test = tester:add("requires code", env, function()
      local scope = newScope()
      run( src, scope )
    end)
    
end

return tester