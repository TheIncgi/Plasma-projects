-- Author: TheIncgi
-- Components:
--  - Normalizer
--  - NeuralNetwork (NNet)
--  - Neuron

require"TheIncgi/Plasma-projects/main/libs/class"

activation = {}
NNet = class"theincgi.NNet"
Neuron = class"theincgi.Neuron"
Normalizer = class"theincgi.Normalizer"

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
  for i,v in ipairs(values) do
    self:fitRange( i, v )
  end
end
function Normalizer:map( values )
	local out = {}
  if type( values ) ~= "table" then
    error( "expected table, got "..type(values),2 )
  end
  for i,v in ipairs( values ) do
    local range = self:getRange( i )
			out[i] = map( v, range[1] or -1, range[2] or 1, -1, 1 )
  end
  return out
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
  obj.config = layerConfig
  obj.layers = {}
  obj.normalizer = Normalizer:new() --sync
  obj.learningDecay = math.max( 0, math.min( layerConfig.learningDecay or 1, 1 ) )
  obj.learningFactor = 1

  print"init NNet"
  obj:_build() 
  return obj
end

function NNet:_build()
  print"queue NNet:_build"
  local this = self
  for layerNum, config in ipairs( this.config ) do
    print("_build", layerNum)
    local layer = {}
    self.layers[ layerNum ] = layer
    for i = 1, config.size do
      print("_build", layerNum, n)
      print"createNeuron"
      local neuron = Neuron:new( config.activation or "signedSigmoid", config.inputs or #self.layers[ layerNum-1 ], config.size )
      print"storeNeuron"
      layer[ n ] = neuron
		end
  end
end

function NNet:feedForward( features )
	local this = self
  local args = features
  local features = self.normalizer:map( args )
  local prev = features
  for layerNum, layer in ipairs( self.layers ) do
    for n, neuron in ipairs( layer ) do
      neuron:feedForward( prev )
    end
    prev = self:getOutputs( layerNum )
  end
end

function NNet:backProp( inputs, targets )
  local this = self
  local errorValues = {} -- as network value + errorValue = actual value
  local prevErrorValues -- accumulator of change requests from later networks

  for layerNum = #self.layers, 1, -1 do
    local layer = this.layers[ layerNum ]
    local prevLayer = this.layers[ layerNum-1 ]
    local config = this.config[ layerNum ]
    local layerInputs
    local outputs

    if prevLayer then
      for n, neuron in ipairs( prevLayer ) do
        layerInputs[n] = neuron.value
      end
    else
      layerInputs = inputs
    end

    outputs = self:getOutputs( layerNum )

    --backprop neuron
    for n, neuron in ipairs( layer ) do
      local errorValue = errorValues[ n ] or (targets[n] - neuron.value)
      local learningRate = self.config[layerNum].learningRate or self.config.learningRate or .005
      learningRate = learningRate * self.learningFactor
      local errors = neuron:backProp( layerInputs, errorValue, learningRate ) 

      --accumulate
      for e, err in ipairs(errors) do
        prevErrorValues[ e ] = (prevErrorValues[e] or 0) + err
      end

      --transfer for next layer
      errorValues = prevErrorValues
    end
  end
end

function NNet:getOutput( n, layerNum  )
	local layer = self.layers[ layerNum or #self.layers ]
	return layer[ n ].value
end

function NNet:getOutputs( layerNum )
	local layer= self.layers[ layerNum or #self.layers ]
	local out = {}
  for n, neuron in ipairs( layer ) do
    out[n] = neuron.value
  end
  return out
end

--single example
function NNet:fitNormalizer( ... )
	self.normalizer:fit( ... )
end

--skipped values permitted?
function NNet:fitExample( features, labels )
  self:feedForward( features )
  self:backProp( features, labels )
end

function NNet:fitExamples( featureSet, labelSet )
	if #featureSet ~= #labelSet then
		error(#featureSet.." features doesn't match "..#labelSet.." labels", 2)
	end
  for i = 1, #featureSet do
    self:fitExample( featureSet[i], labelSet[i] )
  end
end

function NNet:decayLearningRate()
  self.learningFactor = self.learningFactor * self.learningDecay
end

function NNet:score(labels, predictions)
  local numExamples = #labels
  local numClasses = #labels[1]
  local totalError = 0
  local totalSquaredError = 0

  for j = 1, numExamples do
    local exampleError = 0
      local exampleSquaredError = 0

      for i = 1, numClasses do
         local label = labels[j][i]
          local prediction = predictions[j][i]
          local error = label - prediction
          exampleError = exampleError + error
          exampleSquaredError = exampleSquaredError + error^2
      end
      totalError = totalError + exampleError
      totalSquaredError = totalSquaredError + exampleSquaredError
  end
  local meanError = totalError / (numExamples * numClasses)
  local meanSquaredError = totalSquaredError / (numExamples * numClasses)
  local rootMeanSquaredError = math.sqrt(meanSquaredError)

  local errors = {}
  errors["mean_error"] = meanError
  errors["mean_squared_error"] = meanSquaredError
  errors["root_mean_squared_error"] = rootMeanSquaredError
  return errors
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

  obj.activation = activation[ activationName ]
  obj.weights = xavier_weights_init( prevLayerSize, thisLayerSize )
  obj.rawValue = 0
  obj.value = 0

  return obj
end

function Neuron:feedForward( withInputs )
	if #withInputs ~= #self.weights then
		error("input / weights mismatch [got "..#withInputs.." inputs, expected "..#self.weights.." (# of weights)]",2) 
	end
	local sum = self.weights[0] --bias
  
  for i, input in ipairs( withInputs ) do
    local v
			if type( input ) ~= "number" then
				v = input.value
			else
				v = input
			end
			sum = sum + self.weights[i] * v
  end

  self.rawValue = sum
  self.value = self.activation( sum )
end

function Neuron:backProp( inputs, errAmount, learningRate )
	local slope = lazyDerivitive( self.activation, self.rawValue )
  local prevErrors = {}
  local this = self
  for weightNum = 0, #self.weights do
    local weight = this.weights[ weightNum ]
      local input  = inputs[ weightNum ] or weightNum == 0 and weight --bias
      local adjust = input * errAmount * slope * learningRate
      this.weights[ weightNum ] = weight + adjust
      prevErrors[ weightNum ] = adjust * weight
  end
end



--memory?
function saveModel()
end
function loadModel()
end

return {
  Neuron = Neuron,
  NNet = NNet,
  Normalizer = Normalizer,
  activation = activation
}