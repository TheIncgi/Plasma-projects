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
--band lrotate extract
--rshift bor bnot arshift
--bxor replace lshift btest rrotate
local tests = {
  {func = "arshift",    16, 2,                                      label = "arshift +"                },                                               
  {func = "arshift",    16, 2,                                      label = "arshift -"                },                                               
  {func = "band",       0x7ABC1625, 0x3F4F9FAF,                                                        },                                  
  {func = "bnot",       0x59AB35EF,                                                                    },                                             
  {func = "bor",        0x0F0F0F0F, 0xF0F0F0F0,                                                        },                                   
  {func = "btest",      0xFFFF0000, 0x00FF0000,                                                        },                                
  {func = "btest",      0xFFFF0000, 0x00FF0000, 0x0000FF00,                                            }, --band all ~= 0    
  {func = "bxor",       0x00123456, 0xF734AB,                                                          },                                   
  {func = "extract",    0x0A, 0,                                    label = "extract @ 0"              },                                              
  {func = "extract",    0x0A, 1,                                    label = "extract @ 1"              },                                              
  {func = "extract",    0x0A, 2,                                    label = "extract @ 2"              },                                              
  {func = "extract",    0x0A, 3,                                    label = "extract @ 3"              },                                              
  {func = "extract",    0x0A, 4,                                    label = "extract @ 4"              },                                              
  {func = "extract",    0x0A, 0, 3,                                 label = "extract @ 0 with width"   },                                           
  {func = "replace",    0x00000000, 1, 3,                                                              },                                     
  {func = "lrotate",    0x12345678,  4,                             label = "lrotate +4"               },                                       
  {func = "lrotate",    0x12345678, -4,                             label = "lrotate -4"               },                                       
  {func = "lshift",     0x12345678,  5,                             label = "lshift +5"                },                                        
  {func = "lshift",     0x12345678, -5,                             label = "lshift -5"                },                                        
  {func = "rrotate",    0x12345678,  4,                             label = "rrotate +4"               },                                       
  {func = "rrotate",    0x12345678, -4,                             label = "rrotate -4"               },                                       
  {func = "rshift",     0x12345678,  5,                             label = "rshift +5"                },                                        
  {func = "rshift",     0x12345678, -5,                             label = "rshift -5"                },                                        
}

-----------
-- bit32 --
-----------
do
  local env = Env:new()
  local common = testUtils.common(env)
  local libs = testUtils.libs()
  local Loader, Async, Net, Scope = libs.Loader, libs.Async, libs.Net, libs.Scope

  for i, t in ipairs(tests) do
    local src = [=[
      return bit32.$1( $2 )
    ]=]

    src = src:gsub("$1", t.func):gsub("$2", table.concat(t,", "))
    local expected = { bit32[t.func]( table.unpack(t) ) }

    local test = testUtils.codeTest(tester, "bit32."..t.func..(t.label and (" - "..t.label) or ""), env, libs, src, #expected)

    for j = 1, #expected do
      test:var_eq(1, expected[j], ("Expected return value #%d to be %s, got $1"):format(j, tostring(expected[j])))
    end
  end
end

return tester