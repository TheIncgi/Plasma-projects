local testUtils = {}

-- cleaning out mocked functions
function testUtils.libs()
  package.loaded["libs/Load"] = nil
  local libs = require"libs/Load"
  return libs
end

-- execute source code
function testUtils.run( src, scope, Loader, Async )
  if Async.threads
    and Async.threads[Async.activeThread]  then
      local t = Async.threads[Async.activeThread]
      Async.sync( t[#t] )
  end
  local rawTokens = Async.sync( Loader.tokenize(src) )
  local tokens = Async.sync( Loader.cleanupTokens( rawTokens ) )
  local instructions = Async.sync( Loader.buildInstructions(tokens)  )
  Async.sync( Loader.batchPostfix(instructions) )
  return Async.sync( Loader.execute( instructions, scope ) )
end

function testUtils.newScope(Scope, testName)
  error"DEPRECATED"
  -- testName = testName or "?"
  -- local scope =  Scope:new("UNIT_TEST-"..testName, 1, nil, 1)
  -- scope:addGlobals()
  -- scope:addPlasmaGlobals()
  -- return scope
end

function testUtils.codeTest(tester, name, env, libs, src, expectedResultCount)
  return tester:add(name, env, function()
    --local scope = testUtils.newScope(libs.Scope, name)
    libs.setup()
    local scope = libs.Plasma.scope
    scope.name = "UNIT_TEST-"..name
    local results = testUtils.run(src, scope, libs.Loader, libs.Async)
    results = results and results.varargs or {}
    if expectedResultCount and #results ~= expectedResultCount then
      error("Expected "..expectedResultCount.." return value(s)")
    end
    local tmp = {}
    for i=1,#results do
      tmp[i] = results[i].value
    end
    return table.unpack(tmp,1,#results)
  end)
end

function testUtils.common(env)
  local printProxy = env:proxy("print", function() end)
  printProxy.realDefault = true

  local output = env:proxy("output", function() end)
  local trigger = env:proxy("trigger", function() end)
  local write_var = env:proxy("write_var", function() end)
  local read_var = env:proxy("read_var", function() end)
  
  write_var.realDefault = true

  return {
    printProxy = printProxy,
    output = output,
    write_var = write_var,
    read_var = read_var
  }
end

function testUtils.var_pattern(test, argN, pattern)
  test:expect(function()
    local value = test.actionResults[argN]
    if type(value) ~= "string" then
      return false
    end
    return not not value:match(pattern), 
      ("Expected string matching `%s` got `%s`")
      :format(pattern, value)
  end)
end

function testUtils.readSource( path )
  local module = path:match("^TheIncgi/Plasma%-projects/[^/]+/(.+)")
  local file = io.open(module..".lua","r")
  local data = file:read("*all")
  file:close()
  return data
end


function testUtils.setupRequire( Async, Net, commonProxies, paths )
  local sources = {}
  local lastURL = false
  for i, path in ipairs(paths) do
    local src = testUtils.readSource( path )
    local url = "https://raw.githubusercontent.com/"..path..".lua"
    if not sources[url] then
      sources[url] = src
      commonProxies.write_var{ url, "url"}.exactCompute(function()
        lastURL = url
      end)
    end
  end

  --uncomment if require loop happens
  -- commonProxies.write_var{
  --   function(a)
  --     return true
  --   end, 
  --   function(a) 
  --     return a=="url" 
  --   end
  -- }.matchedCompute(function(a, b)
  --   error("Missing require setup for path `"..a.."`")
  -- end)
  commonProxies.read_var{"src"}.exactCompute(function()
    return sources[ lastURL ]
  end)

  commonProxies.output{ "require", 1 }.exactCompute(function(...)
    Async.insertTasks(
      {
        label = "UNIT TESTING - Require - Net result: "..lastURL,
        func = function()
          -- V1 = sources[ lastURL ]
          Net.sourceCode()
          return true --task complete
          end
      }
    )
  end)
end

return testUtils