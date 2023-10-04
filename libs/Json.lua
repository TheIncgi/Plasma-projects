require "TheIncgi/Plasma-projects/main/libs/class"
local utils = {}
function utils.trimLeft( str )
  return str:match( "^[ \t\n\v]*([^ ]-.*)" ) or ""
end
function utils.trimRight( str )
  for i=#str, 1, -1 do
    if str:sub(i,i):match"[^ \n\t\v]" then
      return str:sub(1,i)
    end
  end
  return ""
end
function utils.trim( str )
  return utils.trimLeft( utils.trimRight(str) )
end
-------------------------------------------------------------

local Json = class"common.Json"

Json.static = {}

function Json.static.toString( value )
  if isClass( value ) then
    return value:toString()
  elseif type( value ) == "string" then
    return '"'..value:gsub('"','\\"')..'"'
  elseif type( value ) == "number" then
    return tostring(value)
  elseif type( value ) == "boolean" then
    return value and "true" or "false"
  else
    error("Unsupported type '"..type(value).."'",2)
  end
end

function Json.static.fromString( value )
  assert(value,"fromString missing value")
  value = utils.trim(value)
  assert(value,"trim'd value is empty!")
  if value:sub(1,1) =='"' then
    local subst = string.char(26)
    return value:gsub('\\"',subst):match([["([^"]*)"]]):gsub(subst,'"')
  elseif value:sub(1,1) == "[" then
    return Json.static.JsonArray:new(value)
  elseif value:sub(1,1) == "{" then
    return Json.static.JsonObject:new(value)
  elseif value == "true" then
    return true
  elseif value == "false" then
    return false
  elseif value == "null" then
    return nil
  elseif tonumber( value ) then
    return tonumber( value )
  else
    error("Unexpected value: ->"..value.."<-",2)
  end
end

function Json.static.readTill( src, char, n )
  for i=n,#src do
    if src:sub(i,i):match(char) then
      return i
    end
  end
  return #src+1
end

--src:sub(start,start) == " 
--returns with quotes
function Json.static.readString( src, start )
  local skipNext = false
  for i=start+1, #src do
    if not skipNext then
      if src:sub(i,i) == "\\" then
        skipNext = true
      elseif src:sub(i,i) == '"' then
        return i, src:sub(start,i)
      end
    else
      skipNext = false
    end
  end
end
--src:sub(start,start) == { or [
  --TODO handle brackets in string
function Json.static.readBlock( src, start )
  local blockStart = src:sub(start,start)
  local blockEnd = ({
    ["{"] = "}",
    ["["] = "]"
  })[blockStart]
  local lvl = 1
  for i=start+1, #src do
    if src:sub(i,i):match"[%]%}]" then
      lvl = lvl-1
      if lvl == 0 then
        return i, src:sub( start, i )
      end
    end
    if src:sub(i,i):match"[%[%{]" then
      lvl = lvl+1
    end
  end
  error"End of string reached, malformed json"
end

function Json.static.readValue( src, start )
  local x = src:sub(start,start)
  if x == '"' then
    local n, v = Json.static.readString( src, start )
    return n, v
  elseif x == '{' or x == "[" then
    return Json.static.readBlock( src, start )
  else
    for i=start,#src do
      if src:sub(i,i)==","
      or src:sub(i,i)=="]"
      or src:sub(i,i)=="}" then
        return i-1, src:sub( start, i-1 )
      end
    end
    local v = utils.trim(src:sub(start))
    return #src, #v > 0 and v
  end
end

local _newJson = Json.new
function Json:new( src )
  if self==Json and not src then
    error("Json is abstract, can not call new without source")
  end
  
  if src then
    return Json.static.fromString( src )
  end
  return _newJson( self )
end

function Json:toString()
  error("not implemented!")
end

function Json:isObject()
  return false
end

function Json:isArray()
  return false
end

function Json:toTable()
  return {}
end

--------------------------------------------------------------

local JsonObject = class("common.JsonObject",Json)

local _newJsonObject = JsonObject.new
function JsonObject:new( src )
  local obj = _newJsonObject( self )
  print("obj [1]: "..tostring(obj))
  print("meta [1]: "..tostring(getmetatable(obj)))
  obj.values = {}
  if src then
   --print("NEW|"..src)
    local n = 1
    src = utils.trim(utils.trim( src ):sub(2,-2))
    --print("TRIM|"..src)
    while true do
      local key, val = nil, nil
      n, key = Json.static.readString( src, n )
      if not n then break end
      --print("subn|"..tostring(src:sub(n)))
      n = Json.static.readTill(src,":", n+1)+1
      n = Json.static.readTill(src, "[^ \n\t\v]", n)
      key = key:sub(2,-2)
      n, val = Json.static.readValue( src, n )
      --print(val)
      assert(val,"No val from readVal")
      val = Json.static.fromString( val )
      
      obj.values[key] = val
      n = Json.static.readTill(src, "[,}]", n)+1
      n = Json.static.readTill(src, "[^ \n\t\v]", n)
      
    end
  end
  print("obj [2]: "..tostring(obj))
  local meta = getmetatable(obj)
  meta.__len = function(t)
    return t:len()
  end

  meta.__pairs = function(t)
    return t:pairs()
  end

  meta.__ipairs = function(t)
    return t:ipairs()
  end

  return obj
end

function JsonObject:put( key, val )
  self.values[key] = val
end

function JsonObject:get( key, def )
  return self.values[key] or def
end

function JsonObject:toString()
  local out = {}
  for k,v in pairs( self.values ) do
    table.insert( out, ([["%s":%s]]):format(
      k, Json.static.toString( v )
    ))
  end
  return "{"..table.concat( out, "," ).."}"
end

function JsonObject:isObject()
  return true
end

function JsonObject:ipairs()
  error"Use of ipairs on JsonObject"
end

function JsonObject:pairs()
  return pairs( self.values )
end

function JsonObject:toTable()
  local out = {}
  for k,v in self:pairs() do
    if isClass(v) then
      out[k] = v:toTable()
    else
      out[k] = v
    end
  end
  return out
end

Json.static.JsonObject = JsonObject

--------------------------------------------------------------------------------

local JsonArray = class("common.JsonArray",Json)

local _newJsonArray = JsonArray.new
function JsonArray:new( src )
  local obj = _newJsonArray( self )
  print("obj [3]: "..tostring(obj))
  print("meta [2]: "..tostring(getmetatable(obj)))
  obj.values = {}

  if src then
    local n = 1
    local val
    src = utils.trim(utils.trim( src ):sub(2,-2))
    while true do
      n, val = Json.static.readValue( src, n )
      if not val then break end
      assert(val,"No val from readVal")
      val = Json.static.fromString( val )
      --print("val:",val)
      table.insert( obj.values, val )
      n = Json.static.readTill(src, "[,%]]", n+1)+1
      n = Json.static.readTill(src, "[^ \n\t\v]", n)
    end
  end

  print("obj [4]: "..tostring(obj))
  local meta = getmetatable(obj)
  meta.__len = function(t)
    return t:len()
  end

  meta.__pairs = function(t)
    return t:pairs()
  end

  --broken!
  -- meta.__ipairs = function(t)
  --   return t:ipairs()
  -- end

  return obj
end

function JsonArray:fromTable( tbl )
  if isClass( tbl ) and tbl:isA( JsonArray ) then
    return tbl
  end
  local j = JsonArray:new()
  for k,v in ipairs( tbl ) do
    j:put(v)
  end
  return j
end

function JsonArray:put( val, index )
  self.values[ index or (#self.values+1) ] = val
end

function JsonArray:get( key, def )
  return self.values[key] or def
end

function JsonArray:toString()
  local out = {}
  for i=1,#self.values do
    table.insert(out, Json.static.toString(self.values[i]))
  end
  return "["..table.concat( out, "," ).."]"
end

function JsonArray:isArray()
  return true
end

function JsonArray:len()
  return #self.values
end

function JsonArray:ipairs()
  return ipairs( self.values )
end

function JsonArray:pairs()
  return ipairs( self.values )
end

function JsonArray:toTable()
  local out = {}
  for k,v in self:ipairs() do
    if isClass(v) then
      out[k] = v:toTable()
    else
      out[k] = v
    end
  end
  return out
end

Json.static.JsonArray = JsonArray

return Json