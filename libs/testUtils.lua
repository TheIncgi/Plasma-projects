local testUtils = {}

-- cleaning out mocked functions
function testUtils.libs()
  package.loaded["libs/Load"] = nil
  local libs = require"libs/Load"
  return libs
end

-- execute source code
function testUtils.run( src, scope, Loader, Async )
  local rawTokens = Async.sync( Loader.tokenize(src) )
  local tokens = Async.sync( Loader.cleanupTokens( rawTokens ) )
  local instructions = Async.sync( Loader.buildInstructions(tokens)  )
  Async.sync( Loader.batchPostfix(instructions) )
  return Async.sync( Loader.execute( instructions, scope ) )
end

function testUtils.newScope(Scope)
  local scope =  Scope:new("UNIT_TEST", 1, nil, 1)
  scope:addGlobals()
  scope:addPlasmaGlobals()
  return scope
end

function testUtls.codeTest(tester, name, env, libs, src, expectedResultCount)
  return tester:add(name, env, function()
    local scope = testUtils.newScope(libs.Scope)
    local results = testUtils.run(src, scope, libs.Loader, libs.Async).varargs
    if expectedResultCount and #results ~= expectedResultCount then
      error("Expected "..expectedResultCount.." return value(s)")
    end
    local tmp = {}
    for i=1,#results do
      tmp[i] = results[i].value
    end
    return table.unpack(i)
  end)
end

function testUtils.common(env)
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

function testUtils.readSource( path )
  local file = io.open(path:sub(#("TheIncgi/Plasma-projects/main/")+1)..".lua","r")
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

return testUtils