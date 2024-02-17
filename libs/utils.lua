local utils = {}

----
--search a table for x
utils.keys = table.keys
function utils.values( tbl )
  if type(tbl) ~= "table" then error("utils.values expected table, got "..type(tbl),2) end
  local out = {}
  for a,b in pairs( tbl ) do
    out[#out+1] = b
  end
  return out
end

function utils.inTable( x,tbl )
  if type(tbl) ~= "table" then
    error("utils.inTable arg 2 must be table",2)
  end
  for a,b in pairs(tbl) do
    if b==x then return true end
  end
  return false
end
function utils.multiGet( tbl, keys, unpack )
  local out = {}
  for i,k in ipairs(keys) do
    if unpack then
      table.insert( out, tbl[k] )
    else
      out[k] = tbl[k]
    end
  end
  if unpack then
    return table.unpack( out )
  end
  return out
end
local function argSplit( arg )
  local argTypes, default = {},nil
  local names = {false}
  local requiredTypes = {}
  for k,v in pairs( arg ) do
    if k==1 then
      default = v
    elseif type(k) == "string" then
      names[1] = k
      argTypes = v
    elseif type(k) == "number" then
      if type(v) == "table" then
        if not v[1] then
          error("formatting error",3)
        end
        requiredTypes[v[1]] = v[2]
        table.insert(names, v[1])
      else
        table.insert(names, v)
      end
    end
  end
  return names, argTypes, default, requiredTypes
end

--typical usage
--function foo( ... )
--  local args = utils.kwargs("foo", {
--    {x="number",0,"aliasOfX"},
--    {y={"string","boolean"},'ok'}
--  }, ...)
--  ...
--end
-- -- args"x" will tell you if an alias was used
--
--foo{x=100}
--foo{aliasOfX=100}
--foo{}
--foo{100,200}
--foo{y='h'}
--foo{100, x=3, aliasOfX=4} --very error

function utils.kwargs( argInfo, ... )
  local fName = debug.info(2,"n").name or "[function?]"
  local params = {...}
  if select("#",...) > 1 or type(params[1]) ~= "table" then error(("Incorrect usage, expected %s{...}, got %d params"):format(fName, select("#",...)), 3) end
  local params = params[1]

  for k in pairs(params) do
    if not utils.inTable(type(k), {"string","number"}) then
      error("only string or number keys are valid for kwargs",3)
    end
  end

  local used = {}
  local out = {}
  local metaInfo = {}
  local aliasLookup = {}

  local asserts = argInfo.asserts or {}

  for i, arg in ipairs(argInfo) do
    
    local argNames, argTypes, default, requiredTypes = argSplit( arg )
    
    if not argNames[1] then
      error(("Arg %d needs a name/type def"):format(i),2)
    end

    local requiredType
    table.insert( argNames, i )
    for i,argName in ipairs( argNames ) do
      if argName and used[argName] then
        error(("The variable '%s' is refered to more than once in the function definition"):format(argName),2)
        end
        used[argName] = true
      end
      
    do --check against mutliple possible matches ie foo{100, arg=101} where arg is arg 1
      if #utils.keys(utils.multiGet( params, argNames )) > 1 then
        error(("Duplicate argument for index #%d and key '%s'"):format(i, argNames[1]),3)
      end
    end
    local v
    local usedName = argNames[1]
    for _, name in ipairs( argNames ) do
      v = params[name]
      --print( tostring(name)..": "..tostring(v))
      usedName = name
      if v~=nil then break end
    end
    if type(argTypes) == "string" then
      argTypes = {argTypes}
    end
    if type(argTypes) ~= "table" then
      error(("arg types for '%s' need to be a string or list of strings"):format(argNames[1]),2)
    end
    if v == nil and not utils.inTable("nil", argTypes) then
      v = default
    end

    --type checks
    if requiredTypes[usedName] ~= nil then   -- has override
      if type(requiredTypes[usedName]) == "string" then -- force table
        requiredTypes[usedName] = {requiredTypes[usedName]}
      elseif type(requiredTypes[usedName])=="table" then --override must be table
        error(("Alias [%s] of [%s](%d) has a type restriction as type '%s', expected nil, string, or table of strings"):format(usedName, argNames[1],i, type(requiredTypes)),2)
      end
      if  not utils.inTable("*", argTypes) and not utils.typeMatches(v, requiredTypes[usedName]) then
      -- if not utils.inTable(type(v), requiredTypes[usedName]) then
        error(("When using arg %d (%s) as [%s], the type is restricted to '%s', got '%s'"):format(i, argNames[1], usedName, utils.serializeOrdered(requiredTypes[usedName]), type(v)),3)
      end
    elseif not utils.inTable("*", argTypes) and not utils.typeMatches( v, argTypes ) then
      error(("arg [%s](%s) was expected to be of type(s) %s, got %s"):format(usedName,utils.serializeOrdered(argNames):sub(2,-2), utils.serializeOrdered(argTypes), type(v)), 3 )
    end
    out[ argNames[1] ] = v
    out[ usedName ] = v
    metaInfo[argNames[1]] = usedName
    aliasLookup[usedName] = argNames[1]
  end

  metaInfo.__call = function( t, k )
    return metaInfo[k]
  end
  -- metaInfo.__index = function( t, k )
  --   if rawget(t, k) then return rawget(t, k) end
  --   return rawget(t, aliasLookup[k])
  -- end
  setmetatable(out, metaInfo)
  return out
end

function utils.typeMatches( value, options )
  local typeName = type(value)
  for _, opt in ipairs(options) do
    if typeName == opt then return true end
    if opt:sub(1,6) == "class:" then
      local cName = opt:sub(7)
      local cl = CLASS_REG[ cName ]
      if cl and isClass( value ) 
            and isClass( cl ) then
        if value:isA( cl ) then
          return true
        end
      end
    end
  end
  return false
end

utils.serializeOrdered = table.serialize

--edited to use [0, 1] instead of [0, 255]
--[[
  https://github.com/EmmanuelOga/columns/blob/master/utils/color.lua
 * Converts an RGB color value to HSV. Conversion formula
 * adapted from http://en.wikipedia.org/wiki/HSV_color_space.
 * Assumes r, g, and b are contained in the set [0, 1] and
 * returns h, s, and v in the set [0, 1].
 *
 * @param   Number  r       The red color value
 * @param   Number  g       The green color value
 * @param   Number  b       The blue color value
 * @return  Array           The HSV representation
]]
function utils.rgbToHsv(r, g, b, a)
  if type(r)~="number" then error("expected numbers",2) end
  local max, min = math.max(r, g, b), math.min(r, g, b)
  local h, s, v
  v = max

  local d = max - min
  if max == 0 then s = 0 else s = d / max end

  if max == min then
    h = 0 -- achromatic
  else
    if max == r then
    h = (g - b) / d
    if g < b then h = h + 6 end
    elseif max == g then h = (b - r) / d + 2
    elseif max == b then h = (r - g) / d + 4
    end
    h = h / 6
  end

  return h*360, s, v, a
end

--0<->360 hue, 0<->1 s,v
function utils.hsvToRgb(h, s, v, a)
  local r, g, b
  h = h % 360
  local c = v * s
  local x = c * (1 - math.abs((h / 60) % 2 - 1))
  local m = v - c

  local r, g, b

  if h >= 0 and h < 60 then
    r, g, b = c, x, 0
  elseif h >= 60 and h < 120 then
    r, g, b = x, c, 0
  elseif h >= 120 and h < 180 then
    r, g, b = 0, c, x
  elseif h >= 180 and h < 240 then
    r, g, b = 0, x, c
  elseif h >= 240 and h < 300 then
    r, g, b = x, 0, c
  else
    r, g, b = c, 0, x
  end

  return r + m, g + m, b + m, a
end

function utils.colorToJson( color, name, addToJson )
  addToJson:put(name.."R",color.r or color[1] or 1)
  addToJson:put(name.."G",color.g or color[2] or 1)
  addToJson:put(name.."B",color.b or color[3] or 1)
end

function utils.computeHighlight( r, g, b )
  if type(r) == "table" then
    return utils.computeHighlight( r.r or r[1], r.g or r[2], r.b or r[3] )
  end
  if type(r)~="number" then error("expected numbers",2) end
  local h, s, v = utils.rgbToHsv( r, g, b )
  v = 1-((1-v)/2)
  s = s/2
  return hsvToRgb( h, s, v )
end
function utils.darken(clr, f )
  f = f or .5
  return {
    r = (clr.r or clr[1])*f, 
    g = (clr.g or clr[2])*f, 
    b = (clr.b or clr[2])*f
  }
end

function utils.mathMap(x, a, b, c, d)
  return (x-a) * (d-c) / (b-a) + c
end

return utils