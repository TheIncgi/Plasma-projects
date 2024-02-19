local _TASKS = {}
local _EVENTS = {}

os = os or {}
os.queueEvent = function(eventName, ...)
  assert(type(eventName)=="string", "arg 1 `eventName` expects a string, got "..type(eventName))
  table.insert(_EVENTS, {eventName, ...})
end

--use: os.pullEvent"gamepad"
--os.pullEvent{gamepad = true, foo = true}
os.pullEvent = function(filters)
  if type(filters) == "string" then
    filters = {[filters] = true}
  end
  local event
  repeat
    --trigger(5)
    event = coroutine.yield() or {}
  until filters[event[1]]
  return table.unpack(event)
end

--allow all coroutines to yield independently
local nativeYield = yield
function yield()
  os.pullEvent("tick")
end

function os.queueTask( task, preload )
  local initialType = type(task)
  if initialType == "function" then
    task = coroutine.create( task )
    if preload then
      coroutine.resume()
    end
  end
  if type(task) ~= "thread" then
    error("task must be of type function or thread, got "..initalType)
  end
  table.insert(_TASKS, task)
end

--main loop, call this after you've setup your startup tasks
function main()
  while true do
    local toRemove = {} --don't alter while itterating
    os.queueEvent("tick")
    while _EVENTS[1] do --while events in queue
      local event = table.remove(_EVENTS, 1)      --remove first
      for task in pairs(_TASKS) do                --all threads get the event
        if coroutine.status(task) == "dead" then  --dead/suspended/running
          table.insert(toRemove, task)            --mark for cleanup
          continue
        end
        coroutine.resume( task, event ) --modify with pcall/xpcall if you want
      end

      --cleanup completed tasks
      while toRemove[1] do
        _TASKS[ table.remove(toRemove) ] = nil 
      end
    end

    nativeYield() --wait for next tick
  end
end