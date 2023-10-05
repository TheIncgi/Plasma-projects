_TASKS = {} --allows defining before this library
_EVENTS = {}

os = os or {}
os.queueEvent = function(eventName, ...)
  assert(type(eventName)=="string", "arg 1 `eventName` expects a string, got "..type(eventName))
  table.insert(_EVENTS, {event, ...})
end

--use: os.pullEvent"gamepad"
--os.pullEvent{gamepad = true, foo = true}
os.pullEvent = function(filters)
  if type(filters) == "string" then
    filters = {filters = true}
  end
  local event
  repeat
    event = coroutine.yield() or {}
  until filters[event[1]]
  return table.unpack(event)
end

--example task, can also do this from `interrupt` command safely
do  --limit scope
  local task
  task = coroutine.create(function()
    print("Waiting for gamepad events")
    while true do
      local event, about, detail = os.pullEvent"gamepad"
      print(event, about, detail and table.serialize(detail) or "")
      if about == "back" then
        break
      end
    end
    print"EXIT!"
  end)
  coroutine.resume(task) --start task
  _TASKS[ task ] = true --register task
end

--main loop, call this after you've setup your startup tasks
function main()
  while true do
    local toRemove = {} --don't alter while itterating
    while _EVENTS[1] do --while events in queue
      local event = table.remove(_EVENTS, 1)      --remove first
      for task in pairs(_TASKS) do                --all threads get the event
        if coroutine.status(task) == "dead" then  --dead/suspended/running
          table.insert(toRemove, task)            --mark for cleanup
          continue
        end
        coroutine.resume( task ) --modify with pcall/xpcall if you want
      end

      --cleanup completed tasks
      while toRemove[1] do
        _TASKS[ table.remove(toRemove) ] = nil 
      end
    end

    yield() --wait for next tick
  end
end