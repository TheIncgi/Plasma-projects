local Tester = require"TestRunner"
local Env = require"MockEnv"

local matchers = require"MockProxy".static
local eq = matchers.eq
local any = matchers.any

local tester = Tester:new()

-----------------------------------------------------------------
-- Test data
-----------------------------------------------------------------

local tests = {
  ["1234"] = 1234,
  ["3 * 4 + 5 * 6"] = 42,
  ["5 * 9 - (-3+1)^2"] = 41,
  ["2 * (3 * 4)"] = 24,
  ["(3 * 4) * 2"] = 24,
  ["4^3^2"] = 262144, --4^9 not 64^2
  ["20 / 5 / 2"] = 2,
  ["20 / (5 / 2)"] = 8,
  ["t.add( 3,4 )"] = 7,
  ["10 + t.add( 5*6, 20/5 ) - 4"] = 40,
  ["10 - 5 == 20 / 4"] = true,
  ["10 .. 1 * 3"] = "103",
  ["1 * 3 .. 10"] = "310",
  ["not not 1"] = true,
}

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
  return Async.sync( Loader.execute( instructions, scope ) )
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

do
  local env = Env:new()
  local common = common(env)
  local libs = libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope
  
  local setup = [=[
    t = {}
    
    function t.add( x, y )
      return x + y
    end

    t.inner = {
      value = 100
    }
  ]=]
  
  for expression, expected in pairs( tests ) do
    local test = tester:add("Order: "..expression, env, function()
      local scope = newScope( Scope )
      local fullExpression = "return "..expression
      run( setup, scope, Loader, Async )
      local results = run( fullExpression, scope, Loader, Async ).varargs
      return results[1].value
    end)

    test:var_eq(1, expected, "Expression "..expression.." expected a value of "..tostring(expected)..", but got $1")
  end

end

return tester