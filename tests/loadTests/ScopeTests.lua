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

--------------------
-- function param --
--------------------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local src = [=[
    local function paramTest( x )
      x = x
    end

    paramTest( 10 )

    return x, _G.x
  ]=]

  local test = testUtils.codeTest(tester, "function param", env, libs, src)

  test:var_eq(1, nil)
  test:var_eq(2, nil)
end

---------------
-- nil local --
---------------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local src = [=[
    local function paramTest( x )
      x = x or 11
    end

    paramTest()

    return x, _G.x
  ]=]

  local test = testUtils.codeTest(tester, "nil local", env, libs, src)

  test:var_eq(1, nil)
  test:var_eq(2, nil)
end


--------------------
-- function param --
--------------------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local src = [=[
    table.serialize( _G )
    return visited
  ]=]

  local test = testUtils.codeTest(tester, "table.serialize", env, libs, src)

  test:var_eq(1, nil)
end

-------------------
-- local declare --
-------------------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local src = [=[
do
  local x
  do
    x = 10
  end
  y = x
end
return x, y
  ]=]

  local test = testUtils.codeTest(tester, "local declare", env, libs, src)

  test:var_eq(1, nil)
  test:var_eq(2, 10)
end

-------------------
-- Block Level 1 --
-------------------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local src = [=[
    local foo = 1                  --1 1+
    function x()                   --1 4+ 
      for i=1,1 do                 --2 8+
        for y in ipairs({}) do     --3 14+
          while false do           --4 22+
            if false then          --5 25+
              repeat               --6 28
                test = 0           --7 29+
              until true           --6 31+
            elseif false then      --5 33+
            else                   --5 36
            end                    --5 37
          end                      --4 38
        end                        --3 39
      end                          --2 40
    end                            --1 41
    local bar = 0                  --1 42
  ]=]

  local tokenLevels = {
    --token = level
    [ 1] = 1,
    [ 8] = 2,
    [14] = 3,
    [22] = 4,
    [25] = 5,
    [28] = 6,
    [29] = 7,
    [31] = 6,
    [33] = 5,
    [38] = 4,
    [39] = 3,
    [40] = 2,
    [41] = 1,
  }

  local test = tester:add("block level 1", env, function()
    libs.setup()
    if Async.threads and Async.threads[Async.activeThread]  then
      local t = Async.threads[Async.activeThread]
      Async.sync( t[#t] )
    end
    local rawTokens = Async.sync( Loader.tokenize(src) )
    local tokens = Async.sync( Loader.cleanupTokens( rawTokens ) )
    local expected = 1
    for i, expected in pairs(tokenLevels) do
      local t = tokens[i]
      
      if t.blockLevel and t.blockLevel ~= expected then
        error(("Token `%s` at index %d had block level %d, expected %d"):format(
          tokens[i].value,
          i, t.blockLevel,
          expected
        ))
      end
    end
  end)

end

-------------------
-- Block Level 2 --
-------------------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  local src = [=[
    function Json.static.readValue( src, start )            --   [2] -> 2 after 'function'
      local x = src:sub(start,start)                        --   
      if x == '"' then                                      --   [26] 2 ->3 after then
        local n, v = Json.static.readString( src, start )   --   [27] 3
        return n, v                                         --        3
      elseif x == '{' or x == "[" then                      --   [43] 2 @ elseif [51 then]
        return Json.static.readBlock( src, start )          --   [52] 4 * should be 3 after then
      else                                                  --   [63] 2
        for i=start,#src do                                 --   [64][70] do = 3, then 4
          if src:sub(i,i)==","                              --   [71] 4
          or src:sub(i,i)=="]"                              --
          or src:sub(i,i)=="}" then                         --   
            return i-1, src:sub( start, i-1 )               --   [105] 5
          end                                               --   [120] 4
        end                                                 --   [121] 3
        local v = utils.trim(src:sub(start))                --   
        return #src, #v > 0 and v                           --
      end                                                   --   [145] 2
    end                                                     --   [146] 1
  ]=]

  local tokenLevels = {
    --token = level
    [  1] = 1,
    [  2] = 2,
    [ 27] = 3,
    [ 43] = 2,
    [ 51] = 2,
    [ 52] = 3,
    [ 63] = 2,
    [ 64] = 3,
    [ 71] = 4,
    [105] = 5,
    [120] = 4,
    [121] = 3,
    [145] = 2,
    [146] = 1,
  }

  local test = tester:add("block level 2", env, function()
    libs.setup()
    if Async.threads and Async.threads[Async.activeThread]  then
      local t = Async.threads[Async.activeThread]
      Async.sync( t[#t] )
    end
    local rawTokens = Async.sync( Loader.tokenize(src) )
    local tokens = Async.sync( Loader.cleanupTokens( rawTokens ) )
    local expected = 1
    for i, expected in pairs(tokenLevels) do
      local t = tokens[i]
      
      if t.blockLevel and t.blockLevel ~= expected then
        error(("Token `%s` at index %d had block level %d, expected %d"):format(
          tokens[i].value,
          i, t.blockLevel,
          expected
        ))
      end
    end
  end)

end

return tester