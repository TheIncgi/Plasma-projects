--copied & modified from plasmaNN.lua

Async = {}

--async
local tasks = {}
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

-- --sequential
-- function addTask( func )
-- 	table.insert( tasks, func )
-- end

--nested
function Async.insertTasks( ... )
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

function Async.removeTask( func )
  for i=1, #tasks do
    if tasks[i] == func then
      table.remove( tasks, i )
      return
    end
  end
end

--completes tasks up to `task`
--returns value(s) from `task`
function Async.sync( task )
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
            Async.removeTask( t )
      if t == task then
				return table.unpack( value )
			end
			args = value
		elseif value == true then
			Async.removeTask( t )
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
function Async.RETURN( label, ... )
  local r = {...}
	return {
    label = "RETURN-"..label,
    func = function() return r end
  }
end

--async task
--works like: repeat until forEach(print, range, 1, 7, 2) -> 1, 3, 5, 7
function Async.forEach( label, consumer, gen, ... )
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

function Async.whileLoop( label, condition, loop )
  if not loop then error("missing loop",2) end
  if not condition then error("missing condition",2) end
  if type( label ) ~= "string" then error( "label arg is not of type string" ) end
  if type( loop ) ~= "function" then error( "loop arg is not of type function" ) end
  if type( condition ) ~= "function" then error( "condition arg is not of type function" ) end

  return {
    label = "WhileLoop-"..label,
    func = function()
      if not condition() then return true end
      loop()
      return false
    end
  }
end

function Async.range( start, stop, inc )
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

local __args = {}
function Async.loop()
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
        Async.removeTask( t )
        __args = value
      elseif value == true then
        Async.removeTask( t )
      else
        error( "Invalid task result during sync",2 )
      end
    end
  end
end

return Async