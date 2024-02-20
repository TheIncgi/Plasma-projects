local _THREADS = {}
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
  elseif type(filters)=="table" and filters[1] then
    local tmp = {}
    for _, v in ipairs(filters) do
      tmp[v] = true
    end
    filters = tmp
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

function os.queueTask( label, task, preload )
  print("QUEUE: "..label)
  if type(label) ~= "string" then
    error"Expected label for queueTask"
  end
  local initialType = type(task)
  if initialType == "function" then
    task = coroutine.create( task )
    if preload then
      coroutine.resume(task)
    end
  end
  if type(task) ~= "thread" then
    error("task must be of type function or thread, got "..initalType)
  end
  table.insert(_THREADS, {
    label = label,
    thread = task
  })
end

--main loop, call this after you've setup your startup tasks
function main()
  while true do
    local toRemove = {} --don't alter while itterating
    os.queueEvent("tick")
    while _EVENTS[1] do --while events in queue
      local event = table.remove(_EVENTS, 1)      --remove first
      for _, labeledTask in pairs(_THREADS) do                --all threads get the event
        local thread = labeledTask.thread
        if type(thread) ~= "thread" then
          error("[MTB] queued task '%s' is not a thread":format(labeledTask.label))
        end
        if coroutine.status(thread) == "dead" then  --dead/suspended/running
          table.insert(toRemove, thread)            --mark for cleanup
          continue
        end
        coroutine.resume( thread, event ) --modify with pcall/xpcall if you want
      end

      --cleanup completed threads
      while toRemove[1] do
        _THREADS[ table.remove(toRemove) ] = nil 
      end
    end

    nativeYield() --wait for next tick
  end
end