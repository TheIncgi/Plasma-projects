--This file can be required after your code with
--require"TheIncgi/Plasma-projects/main/libs/MultiTaskBase"
_TASKS = {}
_EVENTS = {}

os = os or {}
os.queueEvent = function(eventName, ...)
  assert(type(event)=="string", "arg 1 `eventName` expects a string")
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
    event = coroutine.yield()
  until filters[details[1]]
  return table.unpack(event)
end

while true do
  for task in pairs(_TASKS) do
    local event = table.remove(_EVENTS) or {}
    coroutine.resume( event )
  end
  yield() --wait for next tick
end

-- creating a new task with interrupt
-- do  --limit scope
--   local task = coroutine.create(function()
--     --epic code  here
--   end)
--   _TASKS[ task ] = true
-- end