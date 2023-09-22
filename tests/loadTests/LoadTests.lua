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

------------------
-- load - print --
------------------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  common.printProxy.realDefault = false
  
  local src = [=[
    local loaded = load("print'Hello world!' return 'ok'")
    return type(loaded), loaded()
  ]=]
    
  local test = testUtils.codeTest(tester, "load-print", env, libs, src)
    
  common.printProxy{ "Hello world!" }.exact()
  test:var_eq(1, "function")
end

--------------------
-- load - sandbox --
--------------------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  common.printProxy.realDefault = false
  
  local src = [==[
    local sandbox = {
      print = print
    }
    loaded = load([=[
      function hello()
        print"Hello"
      end
    ]=], "test", "t", sandbox)
    loaded() --load hello function into sandbox
    return type(hello), type(sandbox.hello)
  ]==]
    
  local test = testUtils.codeTest(tester, "load-sandbox", env, libs, src)
  
  test:var_eq(1, "nil")
  test:var_eq(2, "function")
end

----------------------------
-- load - sandbox - empty --
----------------------------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  common.printProxy.realDefault = false
  
  local src = [==[
    local sandbox = {}
    loaded = load([=[
      function hello()
        print"Hello"
      end
    ]=], "test", "t", sandbox)
    loaded()
    sandbox.hello() --should err: attempt to call nil
  ]==]
    
  local test = testUtils.codeTest(tester, "load-sandboxed-empty", env, libs, src)
  test:expectError("attempt to call nil on line 2") --print"Hello"
  
end

------------------------------------
-- load - sandboxed - pass in var --
------------------------------------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  common.printProxy.realDefault = false
  
  local src = [==[
    local sandbox = {
      print = print,
      x = 10
    }
    loaded = load([=[
      function test()
        print(x)
      end
    ]=], "test", "t", sandbox)
    loaded() --load hello function into sandbox
    sandbox.test()
  ]==]
    
  local test = testUtils.codeTest(tester, "load-sandboxed-pass-in-var", env, libs, src)
  
  common.printProxy{10}.exact()
end

-----------------
-- load - args --
-----------------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  common.printProxy.realDefault = false
  
  local src = [==[
    local sandbox = {
      print = print
    }
    loaded = load([=[
      local foo = ...
      print(...)
    ]=], "test", "t", sandbox)
    loaded("ok")
  ]==]
    
  local test = testUtils.codeTest(tester, "load-args", env, libs, src)
  
  common.printProxy{"ok"}.exact()
end

return tester