CLASS_REG = {}
--inherit( className, baseClass )
--class inheritance function
--baseClass may be nil for creating a class with no parent
--constructor can be overriden by saving it to a local variable then
--calling it durring the call to the 'new' function
--this will instantiate all parent classes for this object
function class( className, baseClass )
  local class = {}
  local classMeta = { 
    __index = baseClass,
    __class = className 
  }
  setmetatable( class, classMeta )

  function class:new( ... )
    assert(self, "self can not be nil")
    local obj = self.__constructing and self or {__constructing = true}
    
    setmetatable( obj, getmetatable(obj) or {
      __index = class,
      __instance = true, --kept after construct 
      __class = className,
    } )

    if baseClass then
      baseClass.new(obj, ... ) -- <-__instance used because of this
    end
    obj.__constructing = nil --cleanup so :new works normal when done
    return obj
  end

  function class:class()
    return class
  end
  
  function class:__enableMetaEvents()
    local meta = getmetatable( self )
    local this = self
    for a,b in ipairs{
      "index", --special handler
      "newindex",
      "mode",
      "call",
      "metatable",
      "tostring",
      "len",
      "pairs",
      "ipairs",
      "gc",
      "name",
      -- "__close", 5.4
      "unm",
      "add",
      "sub",
      "mul",
      "div",
      -- "idiv", 5.3
      "mod",
      "pow",
      "concat",
      -- "band", 5.3
      -- "bor",
      -- "bxor",
      -- "bnot",
      -- "shl",
      -- "shr",
      "eq",
      "lt",
      "le"
    } do
      local name = "__"..b
      if b == "index" then
        meta.__index = function( t, k )
          local values = { class[ k ] }
          if #values > 0 then return table.unpack( values ) end
          local indexer = this.__index
          if type( indexer ) == "function" then
            return indexer( t, k )
          else
            return indexer[ k ]
          end
        end
      else
        meta[ name ] = self[ name ]
      end
    end
  end

  class.className = function() return classMeta.__class end
  
  function class:super()
    return baseClass
  end

  function class:isA( someClass )
    if not self then error("Self can not be nil", 2) end
    if not isClass(someClass) then error("Argument provided is not a class",2) end
    local current = class
    while current do
      if current == someClass then
        return true
      end
      current = current:super()
    end
    return false
  end

  function class:isInstance()
    return getmetatable( self ).__instance or false
  end

  CLASS_REG[ className ] = class
  return class
end

function isClass( x )
  local t = type(x)
  if t == "table" then
    local meta = getmetatable( x )
    if meta then
      if meta.__class then
        return true
      end
    end
  end
  return false
end
--------------------------------------------------------------
utils = {}
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
----
--search a table for x
function utils.keys( tbl )
  if type(tbl) ~= "table" then error("utils.keys expected table, got "..type(tbl),2) end
  local out = {}
  for a in pairs( tbl ) do
    out[#out+1] = a
  end
  return out  
end
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

function utils.serializeOrdered( tbl, sortFunc, visited )
  if type(tbl)~="table" then return type(tbl)=="string" and ('"'..tostring(tbl)..'"') or tostring(tbl) end
  visited = visited or {}
  if visited[tbl] then
    return tostring(tbl)
  end
  visited[tbl] = true
  local out = { "{" }
  local keys = utils.keys(tbl)
  table.sort( keys, sortFunc or function( a,b )
    if type(a)~=type(b) then
      return type(a)<type(b)
    end
    return a<b
  end ) --sortFunc is optional
  for i,v in ipairs( tbl ) do
    if #out > 1 then table.insert( out, ', ' ) end
    table.insert( out, utils.serializeOrdered(v) )
  end
  for i,k in ipairs( keys ) do
    if type(k)~="number" then
      local v = tbl[k]
      local tv = type(v)
      if #out > 1 then table.insert( out, ', ' ) end
      table.insert( out, k )
      table.insert( out, ' = ' )
      table.insert( out,  utils.serializeOrdered(v, sortFunc))
    end
  end
  table.insert(out,"}")
  return table.concat(out)
end

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
function rgbToHsv(r, g, b, a)
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
function hsvToRgb(h, s, v, a)
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
--===========================================================================
--== UI
--===========================================================================
WIDTH = 680
HEIGHT = 512
TOP = HEIGHT
BOTTOM = 0
LEFT = 0
RIGHT = WIDTH

LEFT_DIR   = (LEFT < RIGHT) and -1 or  1
RIGHT_DIR  = (LEFT < RIGHT) and  1 or -1
TOP_DIR    = (BOTTOM < TOP) and  1 or -1
BOTTOM_DIR = (BOTTOM < TOP) and -1 or  1
-----------------------------------------------
local testUI;

local tickTasks = {}

-- function updateUI( ui )
--   error("deprecated",2)
--   if not ui then error("expected ui!",2) end
--   table.insert(tickTasks, function()
--     output(ui:build():toString(), 1)
--   end)
--   table.insert(tickTasks, function()
--     output(ui.id, 2)
--   end)
-- end

function updateUIs()
  local daw = DAW.INSTANCE
  local guis = daw.gui.all
  local list = {}
  for i=1, #guis do
    local gui = guis[i]
    table.insert(list, gui.id.."$\"$"..gui:build():toString())
  end
  output(table.concat(list, "$\"\"$"), 1)
end

-- playSounds(song, {{C1,1}, {B3,3},...}, "left")
function playSounds( song, noteSets, side )
  local out = {}
  for n=1, #noteSets do
    local set = noteSets[n]
    local note, channelID = set.note, set.channelID
    local channel = song.channels[channelID]
    if channel then
      local sound = channel:getSound( note.key )
      if sound then
        table.insert( out, sound ..":".. note:plasmaOctave() ..":".. note.volume )
      end
    end
  end
  output( table.concat(out, ",") ,side == "right" and 4 or 3 )
end

function testSound( channel, note )
  print("SOUND: "..tostring(note:displayName()).." ch:"..tostring(note.channel))
  -- local channel = song.channels[note.channel]
  local cmd
  if channel then
    local sound = channel:getSound( note.key )
    if sound then
      cmd = sound ..":".. note:plasmaOctave() ..":".. note.volume
      output( cmd , 3 )
      output( cmd , 4 )
    else
      print"no sound"
    end
  else
    print"no channel"
  end
end

function testUI()
  testUI = UI:new()
  activeUI = testUI
  local txt = Text:new{
    x=5,
    y=15,
    width=680,
    height=512,
    text="Test msg",
  }
  testUI:addElement( txt )

  local btn = Button:new{
    x = 170,
    y=128,
    width = 340,
    height = 256,
    -- textColor = {r=1,g=1,b=1},
    text = "button!",
  }

  testUI:addElement( btn )
end

local function colorToJson( color, name, addToJson )
  addToJson:put(name.."R",color.r or color[1] or 1)
  addToJson:put(name.."G",color.g or color[2] or 1)
  addToJson:put(name.."B",color.b or color[3] or 1)
end

function computeHighlight( r, g, b )
  if type(r)~="number" then error("expected numbers",2) end
  local h, s, v = rgbToHsv( r, g, b )
  v = 1-((1-v)/2)
  s = s/2
  return hsvToRgb( h, s, v )
end
function darken(color, f )
  f = f or .5
  return {r = (color.r or color[1])*f, g=(color.g or color[2])*f, b=(color.b or color[2])*f}
end

--===========================================================================
DAW = class"DAW"
Element = class"Element"
Button = class("Button",Element)
NoteCell = class("NoteCell", Button)
PianoButton = class("PianoButton", Button)
Text = class("Text", Element)
UI = class"UI"
Note = class"Note"
Scale = class"Scale"
Layer = class"Layer"
Pattern = class"Pattern"
Channel = class"Channel"
Song = class"Song"
--===========================================================================

local _new_daw = DAW.new
function DAW:new()
  local obj = _new_daw( self )

  obj.playing = false
  obj.loop = false
  obj.songs = {}
  obj.activeSongIndex = false
  obj.gui = {}
  obj.patternMode = true --play single pattern or arrangement
  obj:newSong()

  return obj
end

--quick defaults
function DAW:newSong()
  table.insert(self.songs, Song:new{
    daw = self,
    --default bmp
    --default sig
    patterns = {
      Pattern:new{
        daw = self
      }
    },
    --no arrangement (pattern play)
    channels = {
      Channel:new{
        instrument = "Keys"
      }
    }
  })
  self.activeSongIndex = #self.songs
end

--active song to songs, exports after
function DAW:save()
end

--song to active
function DAW:load()
end

--write to NFC/json
function DAW:export()
end

--read from NFC/json
function DAW:import()
end

function DAW:listLoadedSongs()
end


function DAW:setSong()
  
end

--based on song->pattern->layer->channel
--mostly for note preview
function DAW:currentChannel()
  local song = self:currentSong()
  local pat = song:getActivePattern()
  if not pat then return false end
  local layer = pat:getActiveLayer()
  if not layer then return false end
  return song.channels[ layer.channelID ]
end

function DAW:currentScale()
  local song = self:currentSong()
  local pat = song:getActivePattern()
  if not pat then return false end
  return pat:getScale()
end

function DAW:getActiveSong()
  return self.activeSongIndex and self.songs[self.activeSongIndex] or false
end
DAW.currentSong = DAW.getActiveSong

function DAW:getActivePattern()
  local song = self:getActiveSong()
  if not song then return false end
  return song:getActivePattern()
end
DAW.currentPattern = DAW.getActivePattern


function DAW:play()
  self.startTick = V3
  self.lastTick = V3
  self.beats = 0
  self.playing = true
end

function DAW:tick()
  if self.playing then
    local tick, TPS = V3, V4
    local ticksElapsed = tick - self.lastTick
    if ticksElapsed <= 0 then return end
    local secondsElapsed = ticksElapsed / TPS
    local song = self:currentSong()
    local beatsElapsed = secondsElapsed / (song.bpm/60) --time passed / beats per second
    local now = self.beats + secondsElapsed
    
    local notes = {} --list of {channel=channel, note=note}
    if self.patternMode then
      local pattern = self:currentPattern()
      if not pattern then 
        self.playing = false
        return
      end
      notes = pattern:getNotesInTimeRange( self.beats, now )
    else
      error"not implemented"
      --get patterns at time from arangement
      --for patterns getNotesInTimeRange adjusted by pattern start time in argmt.
      --accumulate
    end
    
    local soundsLeft = notes
    local soundsRight = notes
    
    if song.mixer then
      --error"not implemented :c"
    end
    local pattern = self:currentPattern()
    -- if pattern.playingCell ~= self.lastCell then
    --   self.lastCell = pattern.playingCell
    --   self:updateUI()
    -- end
    playSounds( song, notes, "left" )
    playSounds( song, notes, "right")

    self.lastTick = tick
    self.beats = now
  end
end

-- function DAW:updateRoll()
--   for i, gui in ipairs( self.gui.pianoRolls ) do
--     updateUI( gui )
--   end
--   self:updateBarCounter()
-- end

-- function DAW:updateControls()
--   udpateUI( self.gui.controls )
-- end

function DAW:updateUI()
  updateUIs()
  local first = self:currentPattern().offset
  output( first + 1, 5 )
end

--===========================================================================

Element.static = {
  nextUUID = 0
}
local _new_element = Element.new
function Element:new( ... )
  local obj = _new_element( self )
  
  obj.UUID = Element.static.nextUUID
  Element.static.nextUUID = Element.static.nextUUID + 1
  
  return obj
end
--===========================================================================

local _button_new = Button.new

function Button:new( ... )
  local obj = _button_new( self )
  local args = utils.kwargs({
    {x="number"},
    {y="number"},
    {width="number",nil,"wid","w"},
    {height="number",nil,"hei","h"},
    {textColor="table",{r=1,g=1,b=1}},
    {text="string",""},
    {fontSize="number", 60},
    {backgroundColor="table",{r=.05,g=.51,b=.72}},
    {highlightColor={"nil","table"}},
    {payload="string",""},
    {visible="boolean",true},
    {onClick={"function","nil"}, nil, "onPress"},
    {onRelease={"function","nil"},nil}
  },...)

  obj.id = false
  obj.x = args.x
  obj.y = args.y
  obj.width = args.width
  obj.height = args.height
  obj.textColor = args.textColor
  obj.text = args.text
  obj.fontSize = args.fontSize
  obj.backgroundColor = args.backgroundColor
  obj.highlightColor = args.highlightColor
  obj.payload = args.payload
  obj.visible = args.visible
  obj.onClick = args.onClick
  obj.onRelease = args.onRelease

  if obj.width < 0 then
    obj.width = -obj.width
    obj.x = obj.x - obj.width + 1
  end

  if obj.height < 0 then
    obj.height = -obj.height
    obj.y = obj.y - obj.height + 1
  end

  return obj
end

function Button:build()
  local obj = JsonObject:new()
  obj:put("id",self.UUID)
  obj:put("x", self.x)
  obj:put("y", self.y)
  obj:put("width", self.width)
  obj:put("height", self.height)
  obj:put("text", self.text)
  obj:put("fontSize", self.fontSize)
  obj:put("type",2)
  obj:put("payload",self.payload)
  colorToJson(self.backgroundColor, "backgroundColor", obj)
  colorToJson(self.highlightColor or self.backgroundColor,  "highlightColor",  obj)
  colorToJson(self.textColor,       "color",           obj)
  return obj
end
-----------------------------------
NoteCell.static = {}
NoteCell.static.noteColors = {} --call with note

setmetatable(NoteCell.static.noteColors, {__call=function(t,note)
  if not t[note.key] then
    local r,g,b = hsvToRgb( note.key / 12 * 360, 1, 1 )
    t[note.key] = {r=r,g=g,b=b}
  end
  return t[note.key]
end})

local _new_note_cell = NoteCell.new
function NoteCell:new( ... )
  local args = utils.kwargs({
    {note = "class:Note"},
    {cell = "number"}, --x
    --required button args
    {x="number"}, --coords
    {y="number"},
    {width="number",nil,"wid","w"},
    {height="number",nil,"hei","h"},
    {textColor="table",{r=1,g=1,b=1}},
    {fontSize="number", 60},
    {backgroundColor="table",{r=.05,g=.51,b=.72}},
    {visible="boolean",true},
  },...)

  local obj = _new_note_cell(self, {
    x               = args.x,
    y               = args.y,
    width           = args.width,
    height          = args.height,
    textColor       = args.backgroundColor, --visible on hover
    text            = args.note:displayName(),
    fontSize        = 12,
    backgroundColor = args.backgroundColor,
    highlightColor  = {computeHighlight(args.backgroundColor.r, args.backgroundColor.g, args.backgroundColor.b) }
  })

  obj.note = args.note
  obj.cell = args.cell
  obj.pattern = args.pattern
  obj.defaultBackground = args.backgroundColor
  obj.ghostBackground = {r = .75, b = .75, b = .75}

  return obj
end

--note in another layer
function NoteCell:hasGhost()
  return false
end

function NoteCell:setActive( daw, state )
  daw = daw or DAW.INSTANCE
  local song = daw:currentSong()
  if not song then return end
  local pattern = song:getActivePattern()
  if not pattern then return end
  local layer = pattern:getActiveLayer()
  if not layer then return end
  layer:set( self.cell, self.note, state )
  return self
end

function NoteCell:isActive( daw )
  daw = daw or DAW.INSTANCE
  local song = daw:currentSong()
  if not song then return false end
  local pattern = song:getActivePattern()
  if not pattern then return false end
  local layer = pattern:getActiveLayer()
  if not layer then return false end
  return layer:get( self.cell, self.note )
end

function NoteCell:onClick( daw, gui, payload )
  local newState = not self:isActive( daw )
  self:setActive( daw, newState  )
  if newState then
    -- print"active"
    local channel = daw:currentChannel()
    testSound( channel, self.note )
  end
  daw:updateUI()
end

function NoteCell:chooseBackground()
  local color
  local scale = DAW.INSTANCE:currentScale() or Scale:new()
  local inScale = scale and scale:inScale( self.note ) 
  if self:isActive() then
    color = NoteCell.static.noteColors( self.note )
  elseif self:hasGhost() then
    color = self.ghostBackground
  else
    color = self.defaultBackground
  end
  if not inScale then
    color = darken(color)
  end
  -- local pattern = DAW.INSTANCE:currentPattern()
  -- if DAW.INSTANCE.playing and pattern then
  --   if pattern.playingCell == self.cell then
  --     color = darken( color )
  --   end
  -- end
  return color
end

function NoteCell:build()
  self.backgroundColor = self:chooseBackground()
  self.textColor = self.backgroundColor
  return self:super().build(self)
end
-----------------------------------
PianoButton.static = {
  WHITE = {hsvToRgb( 0, 0, 1 )},
  BLACK = {hsvToRgb( 0, 0, .05 )},
  WHITE_HIGHLIGHT = {hsvToRgb(0,0,.75)},
  BLACK_HIGHLIGHT = {hsvToRgb(0,0,.25)},
  TEXT = {r=.5,g=.5,b=.5}
}
local _new_piano_button = PianoButton.new
function PianoButton:new( ... )
  local args = utils.kwargs({
    {x="number"},
    {y="number"},
    {width="number",nil,"wid","w"},
    {height="number",nil,"hei","h"},
    {textColor="table", PianoButton.static.TEXT},
    -- {text="string",""},
    {fontSize="number", 12},
    -- {backgroundColor="table", },
    -- {highlightColor={"nil","table"}},
    -- {payload="string",""},
    {visible="boolean",true},
    {note="class:Note"}
    -- {onClick={"function","nil"}, nil, "onPress"},
    -- {onRelease={"function","nil"},nil}
  },...)
  local obj = _new_piano_button( self, {
    x = args.x,
    y = args.y,
    width = args.width,
    height = args.height,
    textColor = args.textColor,
    text = args.note:displayName(),
    fontSize = args.fontSize,
    backgroundColor = PianoButton.static.WHITE,
    visible = args.visible
  } )
  
  obj.note = args.note

  return obj
end

function PianoButton:onClick( daw, gui, payload )
  local ch = daw:currentChannel()
  testSound( ch, self.note )
end

function PianoButton:build()
  local scale = DAW.INSTANCE:currentScale() or Scale:new()
  local inScale = scale and scale:inScale( self.note ) 
  self.backgroundColor = inScale
    and PianoButton.static.WHITE 
     or PianoButton.static.BLACK
  self.highlightColor = inScale 
    and PianoButton.static.WHITE_HIGHLIGHT
     or PianoButton.static.BLACK_HIGHLIGHT
  return self:super().build( self )
end
-----------------------------------

local TEXT_LEFT = 0
local TEXT_TOP = 0
local TEXT_CENTER = 1
local TEXT_RIGHT = 2
local TEXT_BOTTOM = 2
local _text_new = Text.new
function Text:new( ... )
  local obj = _text_new( self )
  
  local args = utils.kwargs({
    {x="number"},
    {y="number"},
    {width="number",nil,"wid","w"},
    {height="number",nil,"hei","h"},
    {textColor="table",{r=1,g=1,b=1}},
    {text="string",""},
    {fontSize="number", 60},
    {vertAlign="number",1,"vAlign"},
    {horzAlign="number",1,"hAlign"},
    {visible="boolean",true}
  },...)

  obj.id = false
  obj.x = args.x
  obj.y = args.y
  obj.width = args.width
  obj.height = args.height
  obj.textColor = args.textColor
  obj.text = args.text
  obj.fontSize = args.fontSize
  obj.highlightColor = args.highlightColor
  obj.hAlign = args.horzAlign
  obj.vAlign = args.vAlign
  obj.visible = args.visible

  return obj
end

function Text:build()
  local obj = JsonObject:new()
  obj:put("id",self.UUID)
  obj:put("x", self.x)
  obj:put("y", self.y)
  obj:put("width", self.width)
  obj:put("height", self.height)
  obj:put("text", self.text)
  obj:put("fontSize", self.fontSize)
  obj:put("horizontalAlignment", self.hAlign)
  obj:put("verticalAlignment", self.vAlign)
  obj:put("type",1)
  obj:put("payload","")
  colorToJson(self.textColor,       "color",           obj)
  return obj
end

--------------------------------------------------------
local _ui_new = UI.new
function UI:new( startID )
  local obj = _ui_new( self )
  obj.elements = {}
  obj.lookup = {}
  obj.onClick = false
  obj.onRelease = false
  obj.startID = startID or 0
  return obj
end

function UI:addElement( elem )
  table.insert(self.elements, elem)
end

function UI:build()
  self.lookup = {}
  local out = JsonArray:new()
  for i = 1, #self.elements do
    local v = self.elements[i]
    if v.visible==true or (type(v.visible)=="table" and v.visible[1]) then
      -- v.id = self.startID + i - 1
      self.lookup[v.UUID] = v
      out:put( v:build() )
    end
  end
  return out
end

function UI:onPress(daw, id, payload, x, y)
  if self.lookup[id] and self.lookup[id].onClick then
    self.lookup[id]:onClick( daw, self, payload )
  elseif self.onClick then
    x = x or -1
    y = y or -1
    self:onClick(daw, x,y) --not implemented in hardware, needs detect click outside buttton
  end
end

function UI:onRelease(x,y,id, payload)
  if self.lookup[id] and self.lookup[id].onRelease then
    self.lookup[id]:onRelease( daw, self, payload )
  elseif self.onRelease then
    self:onRelease(x,y)
  end
end

-- function UI:draw()
--   updateUI( self )
-- end

-----------------------------------------------
Note.static = {
  KEYS = {"C","C#","D","D#","E","F","F#","G","G#","A","A#","B","C2"},
  OCTAVE_RANGE = {3,5}, --does not include `C2`
  PLASMA_OCTAVE_LOW = -1 -- -1, 0, 1
}
local _new_note = Note.new
function Note:new(...)
  local obj = _new_note( self )
  local args = utils.kwargs({
    {key="number",1},
    {octave="number",4},
    --{channel="number",1},
    {delay="number",0} --0 to 1 (of 1/4th sig denominator)
  },...)

  obj.key = args.key
  obj.octave = args.octave
 -- obj.channel = args.channel
  obj.delay = args.delay
  obj.volume = 1

  return obj
end

function Note:transpose( keys )
  if keys == 0 then return self, true end
  local octs = math.floor( math.abs(keys / 12) )
  local newKey = ( self.key + keys -1 ) % 12 + 1

  if keys > 0 then
    octs = (newKey < self.key) and (octs + 1) or octs
  else
    octs = (newKey > self.key) and (-octs -1) or -octs
  end
  local newOctave = self.octave + octs
  --C2
  local nKeys = #Note.static.KEYS
  if newOctave == Note.static.OCTAVE_RANGE[2] + math.floor( (nKeys-1) / 12 ) --octaves containing notes like C2 or C3
     and newKey <= (nKeys - 12) then --number of extra keys, probably just C2
    self.octave = newOctave + 1
    self.key = newKey + 12
    return self, true
  elseif newOctave < Note.static.OCTAVE_RANGE[1]
  or newOctave > Note.static.OCTAVE_RANGE[2] then
    return self, false, "out of range"
  end
  self.octave = newOctave
  self.key = newKey
  return self, true
end

-- --for quick checking if note is already present in layer
-- function Note:rowID()
--   return Note.static.KEYS[self.key].."-"..self.octave
-- end

function Note:displayName()
  local octBump = math.floor((self.key-1) / 12)
  local key = ((self.key-1) % 12) + 1
  return Note.static.KEYS[key]..(self.octave+octBump)
end

function Note:noteName()
  local key = ((self.key-1) % 12) + 1
  return Note.static.KEYS[key]
end

function Note:plasmaOctave()
  return Note.static.PLASMA_OCTAVE_LOW + (self.octave - Note.static.OCTAVE_RANGE[1])
end

-- function Note:setChannel( ch )
--   self.channel = ch
--   return self
-- end

function Note:isSharp()
  return Note.static.KEYS[self.key]:find("#",1,true)
end

function Note:clone()
  local note = Note:new{
    key = self.key,
    octave = self.octave,
    channel = channel or self.channel
  }
  return note
end
-----------------------------------------------
Scale.static = {}
Scale.static.PRESETS = {
  ["Major (ionian)"            ] = {2,2,1,2,2,2,1},
  ["Major (harmonic)"          ] = {2,2,1,2,1,3,1},
  ["Major (bebop)"             ] = {2,2,1,2,1,1,2,1},
  ["Major (locrian)"           ] = {2,2,1,1,2,2,2},
  ["Major (pentatonic)"        ] = {2,2,3,2,3},
  ["Major (neapolitan)"        ] = {1,2,2,2,2,2,1},
  
  ["Minor (natural/aeolian)"   ] = {2,1,2,2,1,2,2},
  ["Minor (melodic-ascending)" ] = {2,1,2,2,2,2,1},
  ["Minor (melodic-descending)"] = {2,2,1,2,2,1,2 },
  ["Minor (harmonic)"          ] = {2,1,2,2,1,3,1},
  ["Minor (pentatonic)"        ] = {3,2,2,3,2},
  ["Minor (neapolitan)"        ] = {1,2,2,2,1,3,1},

  ["Algerian scale"            ] = {2,1,3,1,1,3,1,2,1,2},
  ["Augmented"                 ] = {3,1,3,1,3,1},
  ["Bebop dominant"            ] = {2,2,1,2,2,1,1,1},
  ["Blues"                     ] = {3,2,1,1,3,2},
  ["Chromatic"                 ] = {1,1,1,1,1,1,1,1,1,1,1,1},
  ["Dorian"                    ] = {2,1,2,2,2,1,2},
  ["Double Harmonic"           ] = {1,3,1,2,1,3,1},
  ["Enigmatic"                 ] = {1,3,2,2,2,1,1},
  ["Flamenco"                  ] = {1,3,1,2,1,3,1},
  ["Romani"                    ] = {2,1,3,1,1,2,2},
  ["Half diminished"           ] = {2,1,2,1,2,2,2},
  ["Hirajoshi"                 ] = {4,2,1,4,1},
  ["Hungarian minor"           ] = {2,1,3,1,1,3,1},
  ["Hungarian major"           ] = {3,1,2,1,2,1,2},
  ["In"                        ] = {1,4,2,1,4},
  ["Insen"                     ] = {1,4,2,3,2},
  ["Ionian mode or major"      ] = {2,2,1,2,2,2,1},
  ["Istrian"                   ] = {1,2,1,2,1,5},
  ["Iwato"                     ] = {1,4,1,4,2},
  ["Locrian"                   ] = {1,2,2,1,2,2,2},
  ["Locrian (super/altered)"   ] = {1,2,1,2,2,2,2},
  ["Lydian"                    ] = {2,2,2,1,2,2,1},
  ["Lydian (augmented)"        ] = {2,2,2,2,1,2,1},
  ["Lydian (diminished)"       ] = {2,1,3,1,1,2,1},
  ["Lydian dominant (acoustic)"] = {2,2,2,1,2,1,2},
  ["Mixolydian"                ] = {2,2,1,2,2,1,2},
  ["Octatonic"                 ] = {2,1,2,1,2,1,2,1},
  ["Octatonic (alt)"           ] = {1,2,1,2,1,2,1,2},
  ["Persian"                   ] = {1,3,1,1,2,3,1},
  ["Phrygian"                  ] = {1,2,2,2,1,2,2},
  ["Phrygian (dominant)"       ] = {1,3,1,2,1,2,2},
  ["Prometheus"                ] = {2,2,2,3,1,2},
  ["Scale of Harmonics"        ] = {3,1,1,2,2,3},
  ["Tritone"                   ] = {1,3,2,1,3,2},
  ["Two,semitone tritone"      ] = {1,1,4,1,1,4},
  ["Ukrainian Dorian"          ] = {2,1,3,1,2,1,2},
  ["Whole tone"                ] = {2,2,2,2,2,2},
  ["Yo"                        ] = {3,2,2,3,2}
}
local _new_scale = Scale.new
function Scale:new( name, baseNote )
  local obj = _new_scale(self)
  obj.name = name or "Major (ionian)"
  obj.baseNote = baseNote or Note:new{}

  obj.steps = Scale.static.PRESETS[obj.name]
  if not obj.steps then
    error("missing scale '"..tostring(obj.name).."'",2)
  end
  obj.notes = {}
  
  obj:compute()
  return obj
end

function Scale:compute()
  local notes = {}
  self.notes = {}
  local tmp = self.baseNote:clone()
  table.insert(notes, tmp.key % 12)
  for i, step in ipairs(self.steps) do
    tmp:transpose( step )
    self.notes[ tmp.key % 12 ] = true
  end
end

function Scale:inScale( note )
  if not note then error("expected note",2) end
  return self.notes[ note.key % 12 ] or false
end

-----------------------------------------------
local _new_layer = Layer.new
function Layer:new(...)
  local obj = _new_layer( self )
  local args = utils.kwargs({
    {pattern = "class:Pattern"},
    {name = "string"},
    {channel = "number", 1, "channelID"} --song channel id
  },...)

  obj.name      = args.name
  obj.channelID = args.channel
  obj.data      = {} -- [time][notesNum]
  obj.pattern   = args.pattern

  return obj
end

function Layer:set( cell, note, state )
  local offset = self.pattern:getCellOffset()
  if not self.data[cell + offset] then
    self.data[cell + offset] = {}
  end
  local notes = self.data[cell + offset]
  local name = note:displayName()
  local foundNote, index = self:get( cell, note )

  if foundNote then
    if state then
      notes[index] = note
      return
    else
      table.remove(notes, index)
      return
    end
  end

  if state then
    table.insert( notes, note )
  end
end

function Layer:get( cell, note, absolute )
  local offset = absolute and 0 or self.pattern:getCellOffset()
  if not self.data[cell + offset] then
    return false
  end
  local notes = self.data[cell + offset]
  local name = note:displayName()
  for i=1, #notes do
    if notes[i]:displayName() == name then
      return notes[i], i
    end
  end
  return false
end

function Layer:getNotesInTimeRange( startCell, endCell, out )
  local startIndex = math.floor(startCell)
  local endIndex = math.floor(endCell) --if cell 1.5, no need to check cell 2
  out = out or {}
  for cell=startIndex, endIndex do
    if self.data[cell] then
      for i=1, #self.data[ cell ] do
        local note = self.data[cell][i]
        local exactStart = cell + (note.offset or 0)
        if startCell <= exactStart and exactStart < endCell then
          table.insert( out, {channelID = self.channelID, note = note} )
        end
      end
    end
  end
  return out
end

-----------------------------------------------
local _new_pattern = Pattern.new
function Pattern:new(...)
  local args = utils.kwargs({
    {daw="class:DAW"}
  },...)
  local obj = _new_pattern(self)
  obj.timeline = {} --timeline[bar][cell] = {[layer]=note}
  obj.bars = 1
  obj.layers = {} --1 per channel
  obj.nextID = 1 --for autonaming only
  obj.activeLayer = false
  obj.daw = args.daw
  obj.cellsPerBeat = 4
  obj.offset = 0
  obj.scale = Scale:new()
  obj.playingCell = -1

  obj:addLayer( 1 )
  return obj
end

function Pattern:addLayer( channelID, name )
  name = name or ("Layer #"..self.nextID)
  self.nextID = self.nextID + 1
  for i, l in pairs(self.layers) do
    if l.name == name then
      error("Layer with name '"..name.."' already exists!",2)
    end
  end
  local layer = Layer:new{
    pattern = self,
    name = name,
    channel = channelID
  }
  table.insert(self.layers, layer)
  self.activeLayer = #self.layers
end

function Pattern:getActiveLayer()
  return self.layers[self.activeLayer]
end

--active
function Pattern:removeLayer()
  table.remove( self.layers, self.activeLayer )
  self.activeLayer = self.layers[self.activeLayer-1] and (self.activeLayer - 1) or false
end

function Pattern:getSignature()
  return self.signature or self.daw:currentSong().signature
end

function Pattern:getBeatsPerBar()
  local sig = self:getSignature()
  return sig[1]
end

function Pattern:getCellsPerBar()
  local sig = self:getSignature()
  return self.cellsPerBeat * sig[1]
end

function Pattern:getNotesInTimeRange( startBeat, endBeat )
  local notes = {}
  local startCell = startBeat * self.cellsPerBeat
  local endCell   =   endBeat * self.cellsPerBeat
  for layerID = 1, #self.layers do
    local layer = self.layers[layerID]
    layer:getNotesInTimeRange( startCell, endCell, notes )
  end
  self.playingCell = math.floor(startBeat)
  return notes
end

function Pattern:getCellOffset()
  return self.offset * self:getSignature()[1] * self.cellsPerBeat
end

function Pattern:getScale()
  return self.scale
end

function Pattern:scrollLeft()
  self.offset = math.max( 0, self.offset - 1)
end

function Pattern:scrollRight()
  self.offset = self.offset + 1
  print("OFFSET",self.offset)
end
-----------------------------------------------
local _new_channel = Channel.new
Channel.static = {
  instruments = {
    -- $INSTRUMENT $KEY $NUM
    ["Bass"  ] = {"Bass/$KEY",13,"sharp"},
    ["Car"   ] = {"Car/Horn $NUM", 2, "whole"},
    ["Clock" ] = {"Clock/Tick $NUM", 4,"whole"},
    ["Bip"   ] = {"Digital Sfx/Bip $NUM",8,"whole"},
    ["Drum"  ] = {"Drum/$INSTRUMENT", {"Crash","HH","Kick","Snare","Tom1","Tom2"}, "whole"},
    ["Keys"  ] = {"Keys/$KEY", 13, "sharp"},
    ["Pads"  ] = {"Pads/$KEY", 13, "sharp"},
    ["Radio" ] = {"Radio/$INSTRUMENT", {"Statics"}, "whole"},
    ["Sirens"] = {"Sirens/$INSTRUMENT", {"A Long", "A Short", "B Long","B Short","Police","Police Loop"}}
  },
  whole = {
    [ 1] = 1,
    [ 3] = 2,
    [ 5] = 3,
    [ 6] = 4,
    [ 8] = 5,
    [10] = 6,
    [12] = 7,
    [13] = 8
  }
}
function Channel:new( ... )
  local obj = _new_channel( self )
  local args = utils.kwargs({
    {instrument = "string"}
  },...)
  local name = args.instrument
  if not Channel.static.instruments[name] then
    error("Invalid instrument '"..tostring(name).."'", 2)
  end
  obj.name = name
  obj.inst = Channel.static.instruments[name]
  return obj
end

function Channel:getSound( key )
  local format, notes, locations = table.unpack( self.inst )
  if locations == "whole" then
    key = Channel.whole[key]
    if not key then return false end
  end

  if format:find("$KEY",1,true) then
    local k = Note.static.KEYS[key]
    return format:gsub("$KEY",k)
  elseif format:find("$NUM",1,true) then
    return format:gsub("$NUM", tostring(key) )
  elseif format:find("$INSTRUMENT",1,true) then
    return format:gsub("$INSTRUMENT", notes[key])
  end
  return false
end

-- CHANNELS = {}
-- for name, inst in pairs( Channel.static.instruments ) do
--   CHANNELS[ name ] = Channel:new( name )
-- end
-----------------------------------------------
local _new_song = Song.new
function Song:new(...)
  local obj = _new_song(self)
  local args = utils.kwargs({
    {daw="class:DAW"},
    {bpm = "number",135},
    {signature = "table", {4,4}, "sig"},
    {patterns = "table", {}},
    {arrangement = "table", {}},
    {channels = "table", {}}
  },...)

  obj.daw = args.daw
  obj.bpm = args.bpm
  obj.signature = args.signature
  obj.patterns = args.patterns
  obj.arrangement = args.arrangement
  obj.channels = args.channels
  obj.loop = false --{start={bar,cell},end={bar,cell}}
  obj.timeCursor = {bar=1, cell=1}
  obj.selection = false
  obj.activePatternIndex = false

  obj:newPattern()
  
  return obj
end

function Song:getActivePattern()
  return self.activePatternIndex and self.patterns[self.activePatternIndex]
end

function Song:newPattern()
  table.insert( self.patterns, Pattern:new{daw = self.daw})
  self.activePatternIndex = #self.patterns
end
-----------------------------------------------

function createRoll(rows, startNote, screenCol, signature)
  local showRoll = screenCol == 1
  local ui = UI:new()
  local note,transposed = startNote:clone(), true
  local cols = signature[1] * 4
  local noteCellsPerRow = cols
  local firstCell = showRoll and 2 or 1
  if showRoll then
    cols = cols + 1
  end
  local cellWidth = WIDTH / cols
  local cellHeight = HEIGHT / rows
  for row = 1, rows do
    local nR, nG, nB = hsvToRgb( row / 12 * 360, 1, 1)
    for col = 1, cols do
      local button
      if showRoll and col == 1 then
        button = PianoButton:new{
          x = LEFT + RIGHT_DIR * cellWidth  * (col-1),
          y = BOTTOM + TOP_DIR * cellHeight * (row-1),
          width = cellWidth,
          height = cellHeight,
          -- text = col ==1 and showRoll and note:displayName() or "",
          fontSize = 12,
          payload = note:displayName(),
          note = note:clone()
        }
      else
        local h,s,v  = 170, .22, .3
        if col % 4 ~= firstCell then
          s = s/3
          v = v * .5
        end
        local r,g,b = hsvToRgb(h,s,v)
        button = NoteCell:new{
          x = LEFT + RIGHT_DIR * cellWidth  * (col-1),
          y = BOTTOM + TOP_DIR * cellHeight * (row-1),
          width = cellWidth,
          height = cellHeight,
          backgroundColor = {r=r,g=g,b=b},
          -- text = col ==1 and showRoll and note:displayName() or "",
          fontSize = 12,
          payload = note:displayName(),
          note = note:clone(),
          cell = (screenCol-1) * noteCellsPerRow + col - (showRoll and 1 or 0)
        }
      end

      ui:addElement( button )
    end
    note, transposed = note:clone():transpose(1) --transposed up
    if not transposed then
      return ui
    end
  end
  return ui --next note or false
end

function createPatternSubUI( ... )
  local args = utils.kwargs({
    {ui="class:UI"},
    {left="number",LEFT},
    {right="number",RIGHT},
    {top="number",TOP},
    {bottom="number",BOTTOM},
  },...)

  local left, right, top, bottom = args.left, args.right, args.top, args.bottom

  local toolbarHeight = math.abs(top-bottom) / 8

  local colors = {
    scroll = { hsvToRgb( 41, 1, 1 ) },
    note   = { hsvToRgb(200,1,1) },
    select = { 0, 1, 0 },
    velocity={ hsvToRgb(290, 1, 1 )},
    shift  = { hsvToRgb(160, 1, 1)},
    loopMark = { hsvToRgb(337,1,1) },
    loop   = { hsvToRgb(337, 1, .5) },
    help   = { hsvToRgb( 240, 1, 1 ) }
  }

  local toolbarButtons = {
    {w=1, col = 1, text = "<",     bgCol = colors.scroll,   onClick = function(self, daw, gui)
      local pattern = daw:currentPattern()
      pattern:scrollLeft()
      daw:updateUI()
    end},   -- Scroll left
    {w=2, col = 2, text = "Note",  bgCol = colors.note,     onClick = function(self, daw, gui)

    end}, -- Note tool mode
    {w=2, col = 3, text = "Sel",   bgCol = colors.select,   onClick = function(self, daw, gui)

    end},  -- Selection tool mode
    {w=2, col = 4, text = "Vel",   bgCol = colors.velocity, onClick = function(self, daw, gui)

    end},  -- Velocity tool mode
    {w=2, col = 4, text = "shift", bgCol = colors.shift,    onClick = function(self, daw, gui)

    end},  -- Shift tool mode
    {w=1, col = 4, text = "[",     bgCol = colors.loopMark, onClick = function(self, daw, gui)

    end},    -- Set loop start
    {w=2, col = 5, text = "loop",  bgCol = colors.loop,     onClick = function(self, daw, gui)

    end}, -- Toggle looping
    {w=1, col = 6, text = "]",     bgCol = colors.loopMark, onClick = function(self, daw, gui)

    end},    -- Set loop end
    {w=1, col = 7, text = "?",     bgCol = colors.help,     onClick = function(self, daw, gui)

    end},    -- Help menu button
    {w=1, col = 8, text = ">",     bgCol = colors.scroll,   onClick = function(self, daw, gui)
      local pattern = daw:currentPattern()
      pattern:scrollRight()
      daw:updateUI()
    end},   -- Scroll right
  }
  local wTotal = 0
  do local last;
    for a,b in ipairs(toolbarButtons) do 
      wTotal = wTotal + b.w 
      b.col = last and (last.col + last.w) or b.col
      last = b
    end 
  end

  local buttonWidth = math.abs((right - left) / wTotal)

  for i, buttonInfo in ipairs(toolbarButtons) do
    local thisWidth = buttonWidth * buttonInfo.w
    local button = Button:new{
      x = left + RIGHT_DIR * (buttonWidth * (buttonInfo.col - 1)),
      y = top,
      width = thisWidth * RIGHT_DIR,
      height = toolbarHeight * BOTTOM_DIR,
      text = buttonInfo.text,
      backgroundColor = buttonInfo.bgCol,
      highlightColor = {computeHighlight( table.unpack( buttonInfo.bgCol ))},
      textColor = {r = 1, g = 1, b = 1},
      fontSize = 12,
      visible = true,
      onClick = buttonInfo.onClick
    }
    args.ui:addElement(button)
  end

  return args.ui

end

function createControlPanel()
  local controls = UI:new()
  local toolbar = {
    {label = "Play",  width = 50, onClick = function(self,daw,gui,payload) daw:play() end},
    {label = "Pause", width = 50, onClick = function(self,daw,gui,payload) daw:pause() end},
    {label = "Stop",  width = 50, onClick = function(self,daw,gui,payload) daw:stop() end},
    {width=10},
    {label = "-", width = 25, onClick = function(self,daw,gui,payload) end},
    {label = "+", width = 25, onClick = function(self,daw,gui,payload) end},
    {label = "BPM: ###", width = 50}
  }
  local sections = {
    {label = "File",     visible = {false}}, 
    {label = "Channels", visible = {true} },
    {label = "Mix",      visible = {false}},
    {label = "Arrange",  visible = {false}},
    {label = "Patterns", visible = {false}},
    {label = "Roll",     visible = {false}}
  }

  local button = Button:new{
    x = LEFT,
    y = TOP,
    width = 100 * RIGHT_DIR,
    height = 50 * BOTTOM_DIR,
    text = "play",
    fontSize = 12,
    onClick = function(self, daw, gui, payload)
      daw:play()
    end,
  }

  createPatternSubUI{
    ui = controls,
    top = TOP + (51 * BOTTOM_DIR)
  }

  controls:addElement( button )
  controls.id = 13 --screen number

  -- updateUI( controls )
  return controls
end

function setup()
  -- testUI()
  local guis = {}
  for row = 1, 3 do
    local startNote = Note:new{octave = 3 + row - 1}
    for col = 1, 4 do
      local gui = createRoll(row == 3 and 13 or 12,startNote, col, {4,4})
      gui.startID = row * 10000 + col * 1000
      table.insert(guis, gui)
      gui.id = #guis --screen
      -- updateUI( gui )
    end
  end
  local daw = DAW.INSTANCE
  daw.gui.all = {}
  daw.gui.pianoRolls = guis
  daw.gui.controls = createControlPanel()

  for a,b in pairs(daw.gui.pianoRolls) do
    table.insert(daw.gui.all, b)
  end
  table.insert(daw.gui.all, daw.gui.controls)

  daw:updateUI()
end

function loop()
  local task = table.remove(tickTasks, 1)
  if task then 
    --print(#tickTasks +1)
    task()
  end
  DAW.INSTANCE:tick()
end

function is_done()
  return false
end

function onPress()
  local elementID = V1
  local payload = V2
  local daw = DAW.INSTANCE
  local all = daw.gui.all
  for g=1,#all do
    if all[g].onPress then
      all[g]:onPress( daw, elementID, payload )
    end
  end
end

function onRelease()
  local elementID = V1
  local payload = V2
  local daw = DAW.INSTANCE
  local all = daw.gui.all
  for g=1,#all do
    if all[g].onRelease then
      all[g]:onRelease( daw, elementID, payload )
    end
  end
end

DAW.INSTANCE = DAW:new()