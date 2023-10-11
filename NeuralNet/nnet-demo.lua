NNetModule = require"TheIncgi/Plasma-projects/main/libs/NeuralNet"
Normalizer = NNetModule.Normalizer
NNet = NNetModule.NNet
activation = NNetModule.activation
Neuron = NNetModule.Neuron

config = {
  learningDecay = .985,
  {
    size = 10,
    learningRate = 10,
    inputs = 2,
  },{
      size = 2,
      learningRate = 2
  }
}

net = NNet:new( config )
data = {
  epochs = 500,
  features = { --aka input examples
      {0,0},
      {0,1},
      {1,0},
      {1,1}
  },
  labels = {  --aka answers for examples
      {0,0},
      {0,1},
      {0,1},
      {1,0}
  }
}

function printScore(i)
  yield() --sync task queue with screen/tick
  local score, predictions = net:scoreWithFeatures( data.features, data.labels )
  print("Epoch: "..i)
  print( "Learning Rate Multiplier: ", net.learningFactor )
  print( "Learning Decay: ", net.learningDecay )
  print( "ME:   "..score.mean_error )
  print( "MSE:  "..score.mean_squared_error )
  print( "RMSE: "..score.root_mean_squared_error )
  print( "====== Predictions ======")
  print( "[features]  ->  [predicted]  |  [labels]")
  for ex = 1, 4 do
    print("[%1d, %1d] -> [%2.4d, %2.4d] | [%1d, %1d]":format(
      data.features[ex][1],
      data.features[ex][2],
      predictions[ex][1],
      predictions[ex][2],
      data.labels[ex][1],
      data.labels[ex][2],
    ))
  end
end

printScore( 0 )
print"Training..."
sleep(1)
--train, more complex examples should split to test and training data
for i = 1, data.epochs do
  net:fitExamples( data.features, data.labels )
  net:decayLearningRate()
  printScore( i )
end