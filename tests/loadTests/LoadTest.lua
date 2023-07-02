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
  LoaderLibs.Scope = libs.AScopeend
end

-- execute source code
local function run( src, env )
  local Loader, Async = LoaderLibs.Loader, LoaderLibs.Async

  local rawTokens = Async.sync( Loader.tokenize(src) )
  local tokens = Async.sync( Loader.cleanupTokens( rawTokens ) )
  local instructions = Async.sync( Loader.buildInstructions(tokens)  )
  Async.sync( Loader.batchPostfix(instructions) )
  Async.sync( Loader.execute( instructions ) )
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
    print("Hello world!")
  ]=]
  local env = Env:new()
  local printProxy = env:proxy("print", function() end)
  --test code
  tester:add("executes hello world", env, function()
    run( src )
  end)
  --expect
  printProxy{ "Hello world!" }.exact()
end

return tester