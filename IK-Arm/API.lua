print("Loading API (build 2)")
local api = {
  _nextRequestID = 1,
  _tasks = {},
  API_MODULE_PIN = 3
}

function api.getAndIncrementID()
  local id = api._nextRequestID
  api._nextRequestID = id + 1
  return id
end

function api.get(url, callback)
  local id = api.getAndIncrementID()
  api._tasks[id] = callback
  api._send("GET", id, url)
end

function api.post(url, body, callback)
  local id = api.getAndIncrementID()
  api._tasks[id] = callback
  api._send("POST", id, url, body)
end

function api._send(callback, ...)
  output_array({...}, api.API_MODULE_PIN)
end

--call in new coroutine on next tick... probably this tick actually
--it will be at the end of the task queue, cool
function api._callback(callback, ...)
  os.queueTask( function()
    callback( ... )
  end )
end

os.queueTask( function()
  print"<color=22FF22>Launching API manager</color>"
  while true do
    local event, detail = os.pullEvent("apiResult")
    local id, err, body = table.unpack(detail)
    local task = api._tasks[id]
    if task then
      api._tasks[id] = nil
      api._callback( task, {
        err = err,
        body = body
      } )
    else
      print("<color=#FF44>[API] WARN: no api task %s</color>":format(id))
    end
  end
end )

return api