-- Author: TheIncgi
-- Components:
--  - Class
--  - Json
--  - Async
--  - Normalizer
--  - NeuralNetwork (NNet)
--  - Neuron
--  - plasma interface

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

-----------------------------------------------------------------
-- Async

activation = {}
NNet = class"theincgi.NNet"
Neuron = class"theincgi.Neuron"
Normalizer = class"theincgi.Normalizer"

--async
tasks = {}
-----------------
-- async task rules
-- return false if not done
-- return true or {} if done
-- return { ... } to pass args to next task
-- nil is invalid return state
-- Should return final outer task
function sourceLine(someFunc)
  -- local info = debug.getinfo(someFunc, "Sl")
  -- if info then
  --   return info.short_src..":"..info.linedefined
  -- else
  --   return nil, nil
  -- end
  return ""
end

local function lazyDerivitive( func, at )
  if type( func ) ~= "function" then error("Expected function for arg 1",2) end
  if type( at ) ~= "number" then error("Expected number for arg 2",2) end
	local delta = .001
	local a = func( at-delta/2 )
	local b = func( at+delta/2 )
	return (b-a) / delta
end

local function map( x,a,b,c,d )
	return (x-a)/(b-a) * (d-c) + c
end

-- --sequential
-- function addTask( func )
-- 	table.insert( tasks, func )
-- end

--nested
function insertTasks( ... )
	local t = {...}
  table.insert( t, {label="__endTaskSet",func=function(...) return {...} end} ) --ensure returned value is a task that finishes after any possible child tasks
	for i,func in ipairs(t) do
    if type( func ) ~= "table" then error("arg "..i.." is not a table",2) end
    if type( func.label ) ~= "string" then error("arg "..i.." is not labeled",2) end
    if type( func.func ) ~= "function" then error("arg "..i.." is missing func",2) end
		table.insert( tasks, i, func )
	end
	return t[ #t ] 
end

function removeTask( func )
  for i=1, #tasks do
    if tasks[i] == func then
      table.remove( tasks, i )
      return
    end
  end
end

--completes tasks up to `task`
--returns value(s) from `task`
function sync( task )
  --print( "SYNC: "..tostring(task).." | "..task.label )
	local args = {}
	while #tasks > 0 do
		local t = tasks[1]
    --print(" > ", t.label ,sourceLine(t.func), t.func)
		local value =  t.func( table.unpack(args) ) 
    args = {}
		if value == false then
			--
		elseif type(value) == "table" then
      removeTask( t )
      if t == task then
				return table.unpack( value )
			end
			args = value
		elseif value == true then
			removeTask( t )
      if t == task then
        return
      end
		else
			error( "Invalid task result during sync",2 )
		end
	end
	error( "Exausted tasks during sync", 2 )
end

--async, return task
function RETURN( label, ... )
  local r = {...}
	return {
    label = "RETURN-"..label,
    func = function() return r end
  }
end

--async task
--works like: repeat until forEach(print, range, 1, 7, 2) -> 1, 3, 5, 7
function forEach( label, consumer, gen, ... )
  if not consumer then error("missing consumer",2) end
  if not gen then error("missing generator",2) end
  if type( label ) ~= "string" then error( "label arg is not of type string" ) end
  if type( consumer ) ~= "function" then error( "consumer arg is not of type function" ) end
  if type( gen ) ~= "function" then error( "gen arg is not of type function" ) end
	local itterator,a,b,c = gen( ... )
  local values = {b, c}
	return {
    label = "ForEach-"..label,
    func = function()
      values = {itterator( a, table.unpack( values ) )}
      if #values == 0 then
        return true
      end
      consumer(table.unpack(values))
      return false
	  end
  }
end

function range( start, stop, inc )
  if type(start)~="number" then error("range: start must be number", 2) end
  if type(stop)~="number" then error("range: stop must be number", 2) end
	local i = start
	inc = inc or 1
  if type(inc)~="number" then error("range: inc must be number or nil", 2) end
	return function()
		if inc > 0 and i > stop
		or inc < 0 and i < stop then
			return
		elseif inc == 0 then
			error"Invalid increment"
		end
		local r = i
		i = i + inc
		return r
	end
end
----------------------------------------------------
-- NNet
----------------------------------------------------
--https://www.desmos.com/calculator/rl32ktfczm
activation.saw = function( x )
  local t = -0.99
  local op = t*math.sin(x) --y
  local adj = 1 - t*math.cos(x) --x
  return 1/x * math.atan2( adj, op ) / 1.44369379 --idk, but it makes it go -1 to 1, when t = -.99
end

activation.sigmoid = function ( x )
  return 1 / ( 1 + math.exp( -x ) )
end

activation.signedSigmoid = function ( x )
  return 2 / ( 1 + math.exp( -x ) ) - 1 
  -- -1 to 1
end

activation.relu = function( x )
	return x < 0 and 0 or x
end 

activation.leakyRelu = function( x )
	return x < 0 and .005*x or x
end 

activation.sin = math.sin
activation.cos = math.cos

--output layer only
activation.identity = function( x ) return x end

-----------------------------------------------------------------
local _newNormalizer = Normalizer.new
function Normalizer:new()
	local obj = _newNormalizer( self )
	obj.ranges = {}
	return obj
end
function Normalizer:getRange( i )
	self.ranges[i] = self.ranges[i] or {}
	return self.ranges[i]
end
function Normalizer:fitRange( i, value )
	local range = self:getRange( i )
	range[1] = math.min( value, range[1] )
	range[2] = math.max( value, range[2] )
end
function Normalizer:fit( values )
	--i,v in ipairs(values)
	return insertTasks( 
		forEach( "Normalizer:fit", function(i,v)
			  self:fitRange( i, v )
		  end, -- in
		  ipairs, values
    )
	)
end
function Normalizer:map( values )
	local out = {}
  if type( values ) ~= "table" then
    error( "expected table, got "..type(values),2 )
  end
	return insertTasks(
		forEach( "Normalizer:map", function(i,v)
			local range = self:getRange( i )
			out[i] = map( v, range[1] or -1, range[2] or 1, -1, 1 )
		end, ipairs, values),
		RETURN("Normalizer:map",out)
	)
end

-----------------------------------------------------------------
-- Layer Config Table
-- {
--    --default for layers
--    learningRate = .0001
--    -- layer
--    { 
--       size = 10, 
--       activation = "sigmoid",
--      --optional
--       learningRate = .001
--    }, ...
-- }
local _newNNet = NNet.new
function NNet:new( layerConfig )
  if not layerConfig then
    error("missing config",2)
  end
	local obj = _newNNet( self )
  print"queue new NNet"
	return insertTasks(
		{
      label = "NNet:new#init",
      func = function()
        obj.config = layerConfig
        obj.layers = {}
        obj.normalizer = Normalizer:new() --sync
        obj.learningDecay = math.max( 0, math.min( layerConfig.learningDecay or 1, 1 ) )
        obj.learningFactor = 1

        print"init NNet"
        obj:_build() --async
        return true
		  end
    },
		RETURN( "NNet:new", obj )
	)
end

function NNet:_build()
  print"queue NNet:_build"
  local this = self
	return insertTasks(
		forEach( "NNet:_build | config", function(layerNum, config)
      print("_build", layerNum)
			local layer = {}
			self.layers[ layerNum ] = layer
      insertTasks(
        forEach( "NNet:_build | layerNum: "..layerNum.." | n->config.size",  function( n )
            print("_build", layerNum, n)
            insertTasks(
              {
                label = "NNet:_build | config | "..n.." | Neuron:new",
                func = function() 
                  print"createNeuron"
                  Neuron:new( config.activation or "signedSigmoid", config.inputs or #self.layers[ layerNum-1 ], config.size )
                  return true
                end
              },
              {
                label = "NNet:_build | config | "..n.." | store neuron",
                func = function( neuron )
                  print"storeNeuron"
                  layer[ n ] = neuron
                  return true
                end
              }
            )
          end, range, 1, config.size
        )
      )
		end, ipairs, this.config)
	)
end

function NNet:feedForward( features )
	local this = self
  local args = features
	return insertTasks( 
    {
      label = "NNet:feedForward - normalize",
      func = function()
        this.normalizer:map( args ) --returns features
        return true
      end
    },
    {
      label = "NNet:feedForward",
      func = function( features )
        local prev = features
        insertTasks(
          forEach( "NNet:FeedForward", function(layerNum, layer) --ipairs(self.layers)
            
            insertTasks(
              forEach( "NNet:FeeedForward | LayerNum: "..layerNum, function(n, neuron)  --ipairs( layer )
                neuron:feedForward( prev )
              end, ipairs, layer),
              {
                label = "NNet:feedForward - get layer "..layerNum.." outputs",
                func = function()
                  this:getOutputs( layerNum )
                  return true
                end
              },{
                label = "NNet:feedForward - previousOut to next in",
                func = function( outputs )
                  prev = outputs
                  return true
                end
              }
            )
            
          end, ipairs, self.layers )
        )
        return true
      end
    }
  )
end

function NNet:backProp( inputs, targets )
  local this = self
  local errorValues = {} -- as network value + errorValue = actual value
  local prevErrorValues -- accumulator of change requests from later networks
  return insertTasks(
    forEach( "NNet:backProp - layers", function( layerNum )
      local layer = this.layers[ layerNum ]
      local prevLayer = this.layers[ layerNum-1 ]
      local config = this.config[ layerNum ]
      local layerInputs
      local outputs
      insertTasks(
        {
          label = "NNet:backProp - clear inputs & prevError",
          func = function()
            layerInputs = {}
            prevErrorValues = {}
            return true
          end
        },{
          label = "NNet:backProp - queue layer input",
          func = function()
            if prevLayer then
              insertTasks(
                forEach("NNet:backProp - get layer inputs", function( n, neuron )
                  layerInputs[ n ] = neuron.value
                end, ipairs, prevLayer )
              )
            else
              layerInputs = inputs
            end
            return true
          end
        },

        {
          label = "NNet:backProp - getOutputs of layer",
          func = function()
            this:getOutputs( layerNum )
            return true
          end
        },{
          label = "NNet:backProp - store outputs of layer as source",
          func = function( layerOutputs )
            outputs = layerOutputs
            return true
          end
        },  
        forEach( "NNet:backProp - neuron", function( n, neuron ) 
          insertTasks(
            {
              label = "NNet:backProp - queue neuron backprop",
              func = function()
                local errorValue = errorValues[ n ] or (targets[n] - neuron.value)
                local learningRate = self.config[layerNum].learningRate or self.config.learningRate or .005
                learningRate = learningRate * self.learningFactor
                neuron:backProp( layerInputs, errorValue, learningRate ) 
                return true
              end
            },{
              label = "NNet:backProp - accumulate errors",
              func = function( errors )
                insertTasks(
                  forEach("NNet:backprop - accumulate error", function(e, err)
                    prevErrorValues[ e ] = (prevErrorValues[e] or 0) + err
                  end, ipairs, errors)
                )
                return true
              end
            }
          )
        end, ipairs, layer ),
        {
          label = "NNet:backProp - transfer errorValues for next layer",
          func = function()
            errorValues = prevErrorValues
            return true
          end
        }
      )
    end, range, #self.layers, 1, -1)
  )
end

function NNet:getOutput( n, layerNum  )
	local layer = self.layers[ layerNum or #self.layers ]
	return layer[ n ].value
end

function NNet:getOutputs( layerNum )
	local layer= self.layers[ layerNum or #self.layers ]
	local out = {}
	return insertTasks(
		forEach( "NNet:getOutputs", function(n, neuron)
			out[n] = neuron.value
		end, ipairs, layer),
		RETURN( "NNet:getOutputs", out )
	)
end

--single example
function NNet:fitNormalizer( ... )
	self.normalizer:fit( ... )
end

--skipped values permitted?
function NNet:fitExample( features, labels )
	return insertTasks(
		{ 
      label = "NNet:fitExample - feedForward",
      func = function()
			  self:feedForward( features ) --async
        return true
		  end
    },
		{
      label = "NNet:fitExample - backProp",
      func = function()
        self:backProp( features, labels )
        return true
      end
    }
	)
end

function NNet:fitExamples( featureSet, labelSet )
	if #featureSet ~= #labelSet then
		error(#featureSet.." features doesn't match "..#labelSet.." labels", 2)
	end
	return insertTasks(
		forEach( "NNet:fitExamples",function(i)
			self:fitExample( featureSet[i], labelSet[i] )
		end, range, 1, #featureSet )
	)
end

function NNet:decayLearningRate()
  self.learningFactor = self.learningFactor * self.learningDecay
end

------------------------------------------------------------------------
-- Neuron
------------------------------------------------------------------------
local function xavier_weight(input_size, output_size)
   local variance = 2 / (input_size + output_size)
   local std_deviation = math.sqrt(variance)
   return std_deviation * math.random()
end

local function xavier_weights_init( input_size, output_size )
	local weights = {}
	for i=0, input_size do
		weights[i] = xavier_weight( input_size, output_size )
	end
	return weights
end

local _newNeuron = Neuron.new
function Neuron:new( activationName, prevLayerSize, thisLayerSize )
	local obj = _newNeuron( self )
	return insertTasks(
		{
      label = "Neuron:new",
      func = function()
        obj.activation = activation[ activationName ]
        obj.weights = xavier_weights_init( prevLayerSize, thisLayerSize )
        obj.rawValue = 0
        obj.value = 0
        return true
      end
    },
		RETURN( "Neuron:new", obj )
	)
end

function Neuron:feedForward( withInputs )
	if #withInputs ~= #self.weights then
		error("input / weights mismatch [got "..#withInputs.." inputs, expected "..#self.weights.." (# of weights)]",2) 
	end
	local sum = self.weights[0] --bias
	return insertTasks(
		forEach( "Neuron:feedForward", function(i,input)
			local v
			if type( input ) ~= "number" then
				v = input.value
			else
				v = input
			end
			sum = sum + self.weights[i] * v
		end, ipairs, withInputs),
		{
      label = "Neuron:feedForward - store result",
      func = function()
        self.rawValue = sum
        self.value = self.activation( sum )
        return true
      end
    }
	)
end

function Neuron:backProp( inputs, errAmount, learningRate )
	local slope = lazyDerivitive( self.activation, self.rawValue )
  local prevErrors = {}
  local this = self
  insertTasks(
    forEach( "Neuron:backProp", function( weightNum )
      local weight = this.weights[ weightNum ]
      local input  = inputs[ weightNum ] or weightNum == 0 and weight --bias
      local adjust = input * errAmount * slope * learningRate
      this.weights[ weightNum ] = weight + adjust
      prevErrors[ weightNum ] = adjust * weight
    end, range, 0, #self.weights ),
    RETURN("Neuron:backProp errors", prevErrors)
  )
end

----------------------------------------------------------------------------
-- Plasma interfacing
----------------------------------------------------------------------------
plasma = {}

local function onComplete()
  trigger( 8 )
  return true
end

function init()
  local config = Json:new( V1 ):toTable()
  insertTasks(
    {
      label = "init",
      func = function()
        plasma.nnet = NNet:new( config )
        return true
      end
    },{
      label = "init - store NNet",
      func = function( nnet )
        plasma.nnet = nnet
        return true
      end
    },{
      label = "init - complete",
      func = onComplete
    }
  )
end

function feedForward()
  local values = Json:new( V1 ):toTable()
  insertTasks(
    {
      label = "plasma - feedForward",
      func = function()
        plasma.nnet:feedForward( values )
        return true
      end
    },{
      label = "plasma - feedForward - getOutputs",
      func = function()
        plasma.nnet:getOutputs()
        return true
      end
    },{
      label = "plasma - feedForward - serialize results",
      func = function( outputs )
        local results = JsonArray:new()
        insertTasks(
          forEach("plasma - feedForward - serialize result", function(n,v)
            results:put( v )
          end, ipairs, outputs),
          {
            label = "plasma - feedForward - output results",
            func = function()
              output( results:toString(), 1 )
              onComplete()
              return true
            end
          }
        )
        return true
      end
    }
  )
end

function fitNormalizer(values)
  values = values or Json:new( V1 ):toTable()
  insertTasks(
    forEach("plasma - fitNormalizer", function( i, example )
      plasma.nnet:fitNormalizer( example )
    end, ipairs, values),
    {
      label = "plasma - fitNormalizer - complete",
      func = onComplete
    }
  )
end

function fitAndTrain( values )
  local values = values or Json:new( V1 ):toTable()
  insertTasks(
    {
      label="fitAndTrain - fit",
      func = function()
        forEach("plasma - fitNormalizer", function( i, example )
          plasma.nnet:fitNormalizer( example )
        end, ipairs, values.features) --inputs
        return true
      end
    },{
      label = "fitAndTrain - train",
      func = function()
          train(values)
          return true
      end
    },{
      label = "plasma - train - complete",
      func = onComplete
    }
  )
end


function train( values )
  local data = values or Json:new( V1 ):toTable()
  local features = data.features
  local labels = data.labels
  local epochs = data.epochs or 1
  local learningFactor = 1
  insertTasks(
    {
      label = "plasma - train - clear epoch progress",
      func = function()
        output( 0, 2 )
        return true
      end
    },
    forEach("plasma - train - epoch", function( epoch )
      plasma.nnet:fitExamples( features, labels ) --train
      plasma.nnet:decayLearningRate()
      output(epoch / epochs * 100, 2)
    end, range, 1, epochs ),
    {
      label = "plasma - train - complete",
      func = onComplete
    }
  )
end

-- chatGPT helped for this one, then converted to async by hand
-- then I gave it my modifications and asked for modifications
-- it was a team effort lol
function score(labels, predictions)
  if not labels or not predictions then
    local data = Json:new( V1 ):toTable()
    labels = data.labels
    local features = data.features
    predictions = {}
    return insertTasks(
      forEach("score-feedForward", function(n, featureSet)
        insertTasks(
          {
            label="score-feedForward sample",
            func=function()
              plasma.nnet:feedForward( featureSet )
              return true
            end
          },{
            label="score-feedForward getOutputs",
            func=function()
              plasma.nnet:getOutputs()
              return true
            end
          },{
            label="score-store predictions",
            func=function( outputs )
              predictions[n] = outputs
              return true
            end
          }
        )
      end, ipairs, features),
      {
        label = "score - call with predictions",
        func = function()
          score( labels, predictions )
          return true
        end
      }
    )
  end

  local numExamples = #labels
  local numClasses = #labels[1]
  local totalError = 0
  local totalSquaredError = 0

  return insertTasks(
    -- Calculate error metrics for each example and each class
    forEach("score-each example", function(j)
      local exampleError = 0
      local exampleSquaredError = 0

      insertTasks(
        forEach("score-each output", function(i)
          local label = labels[j][i]
          local prediction = predictions[j][i]
          local error = label - prediction
          exampleError = exampleError + error
          exampleSquaredError = exampleSquaredError + error^2
        end, range, 1, numClasses),
        {
          label="score-each-total",
          func = function()
            totalError = totalError + exampleError
            totalSquaredError = totalSquaredError + exampleSquaredError
            return true
          end
        }
      )

    end, range, 1, numExamples),
    {
      label = "score-Calculate error metrics",
      func = function()
        local meanError = totalError / (numExamples * numClasses)
        local meanSquaredError = totalSquaredError / (numExamples * numClasses)
        local rootMeanSquaredError = math.sqrt(meanSquaredError)

        -- Return error metrics in a table
        local errorJson = JsonObject:new()
        errorJson:put("mean_error", meanError)
        errorJson:put("mean_squared_error", meanSquaredError)
        errorJson:put("root_mean_squared_error", rootMeanSquaredError)
        output( errorJson:toString(), 1 )
        return true
      end
    },{
      label="score-done",
      func=onComplete
    }
  )
end



--memory?
function saveModel()
end
function loadModel()
end



local __args = {}
function loop()
  stepsPerLoop = V2 or 10
  for steps = 1, stepsPerLoop do
    if #tasks > 0 then
      local t = tasks[1]
      --print(" > ", t.label ,sourceLine(t.func), t.func)
      local value =  t.func( table.unpack(__args) ) 
      __args = {}
      if value == false then
        --
      elseif type(value) == "table" then
        removeTask( t )
        __args = value
      elseif value == true then
        removeTask( t )
      else
        error( "Invalid task result during sync",2 )
      end
    end
  end
end
----------------------------------------------------------------------------
----------------------------------------------------------------------------
----------------------------------------------------------------------------
----------------------------------------------------------------------------
--completes tasks up to `task`
--returns value(s) from `task`

----------------------------------------------------------------------------
function trigger( pin )
  print("TRIGGER -> "..pin)
end
function output( value, pin )
  print("OUTPUT "..pin.." ->".. tostring(value))
end

--as table
function splitData( data )
  local train = data
  local test = {features={},labels={}}
  train.epochs = data.epochs
  for i = 1, math.ceil(#data.features * .05) do
    table.insert( test.features, table.remove(data.features) )
    table.insert( test.labels, table.remove(data.labels) )
  end
  return {train=train, test=test}
end

local function transformAngle( degrees )
  local rads = math.rad( degrees )
  return math.cos( rads ), math.sin( rads )
end

function transformData( jsonDataset )
  local transformedFeatures = JsonArray:new()
  local transformedLabels = JsonArray:new()
  local transformedDataset = JsonObject:new()
  local rawFeatures = jsonDataset:get"features"
  local rawLabels = jsonDataset:get"labels"
  transformedDataset:put("epochs", jsonDataset:get"epochs")
  transformedDataset:put("features", transformedFeatures)
  transformedDataset:put("labels", transformedLabels)

  for exampleNum, example in rawFeatures:ipairs() do
    local transformedExample = JsonArray:new()
    transformedExample:put( example:get(1) ) --forward
    transformedExample:put( example:get(2) ) --up
    transformedExample:put( example:get(3) ) --right
    local angleX, angleY = transformAngle( example:get(4) )
    transformedExample:put( angleX )
    transformedExample:put( angleY )
    transformedFeatures:put( transformedExample )
  end

  --shoulder twist, shoulder bend, elbow 1 elbow 2, wristbend, wrist twst (ignored)
  for exampleNum, example in rawLabels:ipairs() do
    local transformedExample = JsonArray:new()
    for index, label in example:ipairs() do
      if index < 6 then
        local xFactor, yFactor = transformAngle( label )
        transformedExample:put( xFactor )
        transformedExample:put( yFactor )
      end
    end
    transformedLabels:put( transformedExample )
  end

  return transformedDataset
end

function demo1()
  V1 = [[
    [{
      "size": 10,
      "learningRate":10,
      "inputs":2
    },{
      "size":2,
      "learningRate":2
    }]
  ]]
  init()
  sync( tasks[#tasks] )



  V1 = [[{	"epochs": 500,	"features":[		[0,0],		[0,1],		[1,0],		[1, 1]	],"labels":[		[0,0],		[0,1],		[0,1],		[1, 0]	]}]]
  train()
  sync( tasks[#tasks] )



  V1 = "[0,0]"
  feedForward()
  sync( tasks[#tasks] )
  local config = {
    learningDecay = .999,
    { size = 5, activation = "sigmoid", inputs = 2, learningRate = 10 },
    { size = 2, activation = "sigmoid", learningRate = 2 },
  }
  local features, labels = 
  {
    {0,0},
    {0,1},
    {1,0},
    {1,1},
  },
  {
    {0,0},
    {0,1},
    {0,1},
    {1,0},
  }
  local dataset = JsonObject:new()
  do
    local featJson = JsonArray:new()
    local labJson = JsonArray:new()
    for i=1,#features do
      local f = features[i]
      local l = labels[i]
      featJson:put( JsonArray:fromTable( f ) )
      labJson:put( JsonArray:fromTable( l ) )
    end
    dataset:put("features",featJson)
    dataset:put("labels",labJson)
  end

  local net = sync( NNet:new( config ) )
  assert( #tasks == 0, #tasks.." leftover tasks!" )

  local function show( input )
    sync( net:feedForward( input ) )
    assert( #tasks == 0, #tasks.." leftover tasks!" )

    local results = sync( net:getOutputs() )
    assert( #tasks == 0, #tasks.." leftover tasks!" )

    print"=========================="
    print("Input: "..table.concat( input, ", " ))
    for k,v in ipairs( results ) do
      print( k, v )
    end
  end

  local function showAll()
    for k, v in ipairs( features ) do
      show( v )
    end
  end

  ---------------------------------------------------

  showAll()

  print"============================ After training =========================="
  for i = 1, 3000 do
    print("FACTOR: "..net.learningFactor)
    sync( net:fitExamples( --binary adder example
      features, labels, learningRateFactor
    ) )
    net:decayLearningRate()
  end

  showAll()

  V1 = dataset:toString()
  plasma.nnet = net
  sync(score()) --outputs to pin 1 JSON
end

function getData()
  local dataset = JsonObject:new()
  local features = JsonArray:new()
  local labels = JsonArray:new()
  dataset:put("features", features)
  dataset:put("labels", labels)

  for _,src in ipairs{"data/armJson","data/armJson2"} do
    local ARM_JSON = require( src )
    local armData = Json:new(ARM_JSON)
    armData = transformData( armData )
    for i, v in armData:get"features":ipairs() do
      features:put( v )
    end
    for i, v in armData:get"labels":ipairs() do
      labels:put( v )
    end
  end
  return dataset
end

function demo2()
  require"data/armJson"
  armData = getData()
  print("examples: "..armData:get"features":len())
  ARM_JSON = armData:toString()
  armData:put("epochs", 1)
  local config = {
    learningDecay = 1,
    {size=20, inputs=5, learningRate = .01, activation="signedSigmoid"},
    -- {size=20, learningRate = .2, activation="signedSigmoid"},
    -- {size=20, learningRate = .2, activation="signedSigmoid"},
    -- {size=20, learningRate = .2, activation="signedSigmoid"},
    -- {size=20, learningRate = .2, activation="signedSigmoid"},
    -- {size=20, learningRate = .2, activation="signedSigmoid"},
    -- {size=20, learningRate = .02, activation="signedSigmoid"},
    {size=10, learningRate = .01, activation="signedSigmoid"}
  }
  local nnet = sync( NNet:new( config ) )
  
  plasma.nnet = nnet
  local armTable = armData:toTable()
  local dataset = splitData( armTable )
  local testFeat = JsonArray:new()
  local testLab  = JsonArray:new()
  local testJson = JsonObject:new()
  for i=1, #dataset.test.features do
    testFeat:put(JsonArray:fromTable(dataset.test.features[i]))
    testLab:put(JsonArray:fromTable(dataset.test.labels[i]))
  end

  testJson:put("features", testFeat)
  testJson:put("labels", testLab)
  -- print("BEFORE - all")
  -- V1 = ARM_JSON
  -- score()
  -- sync( tasks[#tasks] )
  
  print("BEFORE - test")
  V1 = testJson:toString()
  score()
  sync( tasks[#tasks] )
  
  for i = 1, 5000 do
    fitAndTrain( dataset.train )
    sync( tasks[#tasks] )
    
    -- print("AFTER - all")
    -- V1 = ARM_JSON
    -- score()
    -- sync( tasks[#tasks] )
    
    print("AFTER - test - EPOCH: "..i)
    V1 = testJson:toString()
    score()
    sync( tasks[#tasks] )
  end

  local t1F, t1L = dataset.test.features[1], dataset.test.labels[1]
  sync( nnet:feedForward( t1F ) )
  local out = sync( nnet:getOutputs() )
  print("expected vs actual ")
  for i, o in ipairs(out) do
    print( t1L[i]," | ", o ) --FIXME, PROB NOT SCALED 
  end 
end

demo2()