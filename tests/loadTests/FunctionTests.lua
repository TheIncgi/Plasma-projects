local Tester = require"TestRunner"
local Env = require"MockEnv"

local matchers = require"MockProxy".static
local eq = matchers.eq
local any = matchers.any

local tester = Tester:new()

-----------------------------------------------------------------
-- Test data
-----------------------------------------------------------------

-----------------------------------------------------------------
-- Test utils
-----------------------------------------------------------------

-- cleaning out mocked functions
local function libs()
  package.loaded["libs/Load"] = nil
  local libs = require"libs/Load"
  return libs
end

-- execute source code
local function run( src, scope, Loader, Async )
  local rawTokens = Async.sync( Loader.tokenize(src) )
  local tokens = Async.sync( Loader.cleanupTokens( rawTokens ) )
  local instructions = Async.sync( Loader.buildInstructions(tokens)  )
  Async.sync( Loader.batchPostfix(instructions) )
  Async.sync( Loader.execute( instructions, scope ) )
end

local function newScope(Scope)
  local scope =  Scope:new("UNIT_TEST", 1, nil, 1)
  scope:addGlobals()
  scope:addPlasmaGlobals()
  return scope
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

local function readSource( path )
  local file = io.open(path:sub(#("TheIncgi/Plasma-projects/main/")+1)..".lua","r")
  local data = file:read("*all")
  file:close()
  return data
end


local function setupRequire( Async, Net, commonProxies, paths )
  local sources = {}
  local lastURL = false
  for i, path in ipairs(paths) do
    local src = readSource( path )
    local url = "https://raw.githubusercontent.com/"..path..".lua"
    if not sources[url] then
      sources[url] = src
      commonProxies.write_var{ url, "url"}.exactCompute(function()
        lastURL = url
      end)
    end
  end

  commonProxies.output{ "require", 1 }.exactCompute(function(...)
    Async.insertTasks(
      {
        label = "UNIT TESTING - Require - Net result: "..lastURL,
        func = function()
          V1 = sources[ lastURL ]
          Net.sourceCode()
          return true --task complete
          end
      }
    )
  end)
end

-----------------------------------------------------------------
-- Tests
-----------------------------------------------------------------

-----------------
-- scope test  --
-----------------
do
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
  local libs = libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  --test code
  local test = tester:add("scope test", env, function()
    local scope = newScope(Scope)
    run( src, scope, Loader, Async )
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
do
  local src = [=[
    local HelloRequire = require"TheIncgi/Plasma-projects/main/testLibs/HelloRequire"
    print( HelloRequire.msg )
  ]=]
  local HelloRequire = require"testLibs/HelloRequire"
  local env = Env:new()
  local common = common(env)
  local libs = libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope
  local path = "TheIncgi/Plasma-projects/main/testLibs/HelloRequire"
  
  --expect print call with msg
  common.printProxy{ HelloRequire.msg }.exact()

  setupRequire( Async, Net, common, {path} )
    
  --test code
  local test = tester:add("requires code", env, function()
    local scope = newScope(Scope)
    run( src, scope, Loader, Async )
  end)
    
end


-----------------
--  Table Func --
-----------------
do
  local src = [=[
    local Lib = require"TheIncgi/Plasma-projects/main/testLibs/TableFunc"
    Lib.test()
  ]=]
  local env = Env:new()
  local common = common(env)
  local libs = libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope
  local path = "TheIncgi/Plasma-projects/main/testLibs/TableFunc"

  setupRequire( Async, Net, common, {path} )
  
  --expect print call with msg
  common.printProxy{ "ok" }.exact()
    
  --test code
  local test = tester:add("table function", env, function()
    local scope = newScope(Scope)
    run( src, scope, Loader, Async )
  end)
    
end

return tester