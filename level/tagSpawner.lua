tick = 0
tickRate = 10 --per second
indicatorTicks = 0
lastSpawn = -1
extenderTarget = 0
written = false

function seconds(s)
  return math.ceil(s * tickRate)
end

spawnDelay = seconds(2)


--sensors
function isOn()
  return V1
end

function isSpawnerBlocked()
  return V2 < 1.5
end

function isAtWriter()
  return V3 < .2
end

function isAtEnd()
  return V4 < .2
end

function readNFC()
  trigger(5)
  return V6  
end

function frontalForce()
  return V5
end

--actuators
function setConveyor(state)
  output(state, 1)
end

function writeNFC(value, channel)
  write_var(value, "value")
  write_var(channel, "channel")
  trigger(6)
end

function pulseWriteIndicator()
  --indicator
  indicatorTicks = seconds(.5)
  output(true, 3)
end

function spawn()
  trigger(2)
  lastSpawn = tick
end

local writeStart = false
function extendWrite()
  writeStart = writeStart or tick
  if tick - writeStart > seconds(2.25) then
    extenderTarget = math.max(0, extenderTarget - .4)
    output(extenderTarget, 4)
    if V7 < 5 then
      writeStart = false
      if attempts > 1 then
        cancel()
        writeStart = false
        attempts = 1
        extenderTarget = 0
        output(extenderTarget, 4)
        return
      end
      attempts = attempts + 1
      print("Try #"..attempts)
    end
    return
  end
  if frontalForce() > 90 then
    return true
  end
  extenderTarget = math.min(9, extenderTarget + .3)
  output(extenderTarget, 4)
end


function retractWrite()
  writeStart = false
  attempts = 1
  print""
  extenderTarget = math.max(0, extenderTarget - .4)
  output(extenderTarget, 4)
  return extenderTarget <= 0
end

function cancel()
  trigger(8)
end

----------------------------------------
function setup()
end

function loop()
  tick = V8 or 0

  --write success indicator
  if indicatorTicks > 0 then
    indicatorTicks = indicatorTicks -1
  elseif indicatorTicks == 0 then
    output(false, 3) --indicator
    indicatorTicks = indicatorTicks -1
  end

  --belt & power
  --print(frontalForce())
  
  if isOn() then
    local belt = true

    --spawn
    if lastSpawn < 0 or (tick - lastSpawn >= spawnDelay) then
      if not isSpawnerBlocked() then
        spawn()
      end
    end

    --print( isAtWriter() )
    if isAtWriter() then
      --write
      if written then
        belt = retractWrite() and (frontalForce() < 0) and (V7 <  5)
      else
        belt = false
        if extendWrite() then
          if not value then
            value = math.random(1,1000)
          end
          writeNFC( value, 1 )
          --check
          if readNFC() == value then
            written = true
            pulseWriteIndicator()
          end
        end
      end
    else
      written = false
    end


    setConveyor( belt )
  else
    setConveyor( false )
  end

end

function is_done()
end