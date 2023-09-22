--copied & modified from plasmaNN.lua

local Async = {}
local Loader = {}
local Scope = {}
local Net = {}

Loader.tableIndexes = {}
Loader.strings = {}
Loader.metatables = {
  string = {value={}, type="table"}
}

Loader.tableIndexes[ Loader.metatables.string.value ] = {}

--[table][raw key] -> wrapped key
setmetatable(Loader.tableIndexes, {
  __mode = "k"
})

--["string"] -> {wrapped string}
setmetatable(Loader.strings, {
  __mode = "v"
})

setmetatable(Loader.metatables, {
  __mode = "v"
})

------------------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------------

--async
local threads = {
  [1] = {}
}

Async.threads = threads
Async.threadStack = {}
Async.activeThread = 1
Async._threadID = 1 --increments then gets
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
-- 	table.insert( threads[Async.activeThread], func )
-- end

--nested
function Async.insertTasks( ... )
	local t = {...}
  table.insert( t, {label="__endTaskSet",func=function(...) return {...} end} ) --ensure returned value is a task that finishes after any possible child tasks
  if not threads[ Async.activeThread ] then
    threads[ Async.activeThread ] = {}
  end
	for i,func in ipairs(t) do
    if type( func ) ~= "table" then error("arg "..i.." is not a table",2) end
    if type( func.label ) ~= "string" then error("arg "..i.." is not labeled",2) end
    if type( func.func ) ~= "function" then error("arg "..i.." is missing func",2) end
		table.insert( threads[Async.activeThread], i, func )
	end
	return t[ #t ] 
end

function Async.removeTask( func, threadID )
  local tasks = threads[ threadID or  Async.activeThread ]
  for i=1, #tasks do
    if tasks[i] == func then
      table.remove( tasks, i )
      if #tasks == 0 then
        threads[ threadID or Async.activeThread ] = nil
      end
      return
    end
  end
end

--completes tasks up to `task`
--returns value(s) from `task`
function Async.sync( task )
  --print( "SYNC: "..tostring(task).." | "..task.label )
	local args = {}
	while #threads[Async.activeThread] > 0 do
    local threadOnCall = Async.activeThread
		local t = threads[Async.activeThread][1]
    --print(" > ", t.label ,sourceLine(t.func), t.func)
		local value =  t.func( table.unpack(args) ) 
    args = {}
		if value == false then
			--
		elseif type(value) == "table" then
            Async.removeTask( t, threadOnCall )
      if t == task then
				return table.unpack( value )
			end
			args = value
		elseif value == true then
			Async.removeTask( t, threadOnCall )
      if t == task then
        return
      end
		else
			error( "Invalid task result during sync ["..(t.label or "?").."]",2 )
		end
	end
	error( "Exausted tasks during sync", 2 )
end

--async, return task
function Async.RETURN( label, ... )
  if type(label) ~= "string" then error("Label expected for Async.RETURN", 2) end
  local r = {...}
	return {
    label = "RETURN-"..label,
    func = function() return r end
  }
end

-- `return` in loop is continue
-- `return true` in loop is break
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
      local doBreak = loop()
      return doBreak or false
    end
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
      local doBreak = consumer(table.unpack(values))
      return doBreak or false
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
    if #threads[Async.activeThread] > 0 then
      local t = threads[Async.activeThread][1]
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

function Async.newThread()
  Async._threadID = Async._threadID + 1
  Async.threads[ Async._threadID ] = {}
  return Async._threadID
end

function Async.pushAndSetThread( switchTo )
  table.insert( Async.threadStack, Async.activeThread )
  Async.activeThread = switchTo
end

function Async.popThread()
  local old = Async.activeThread
  Async.activeThread = table.remove( Async.threadStack )
  if not Async.activeThread then
    error("yield called from main thread")
  end
  return old
end

function Async.threadStatus( threadID )
  if not threadID then error("threadID expected",2) end
  local tasks = Async.threads[ threadID ]
  if not tasks or #tasks == 0 then
    return "dead"
  elseif Async.activeThread == threadID then
    return "running"
  else
    return "suspended"
  end
end

--debug info
function Async.setLine( line )
  Async.threads[ Async.activeThread ].line = line
end

function Async.getLine()
  return Async.threads[ Async.activeThread ].line
end

local insertTasks = Async.insertTasks
local forEach = Async.forEach
local sync = Async.sync
local removeTask = Async.removeTask
local range = Async.range
local RETURN = Async.RETURN
--=====================================================================================



Loader.keywords = {
  -- ["and"]      = true,
  ["break"]    = true,
  ["do"]       = true,
  ["false"]    = true,
  ["for"]      = true,
  ["function"] = true,
  ["if"]       = true,
  ["elseif"]   = true,
  ["else"]     = true,
  ["in"]       = true,
  ["local"]    = true,
  ["nil"]      = true,
  -- ["not"]      = true,
  -- ["or"]       = true,
  ["repeat"]   = true,
  ["return"]   = true,
  ["then"]     = true,
  ["true"]     = true,
  ["until"]    = true,
  ["while"]    = true,
  ["end"]      = true,
}

local SINGLE_QUOTE = string.char(39)
local DOUBLE_QUOTE = string.char(34)
Loader._patterns = {
	str = { "^'[^'\n]+'$", '^"[^"\n]+"$' },
	num = { 
		int="^[0-9]+$", 
		float="^[0-9]*%.[0-9]*$",
		hex="^0x[0-9a-fA-F]+$",
		bin="^0b[01]+$"
	},
	var = { "^[a-zA-Z_][a-zA-Z0-9_]*$" },
	op = { "^[()%{%}%[%]%%.%!%#%^%*%/%+%-%=%~%&|:;,%<%>]+$" }
}

Loader._ops = {
 --op, priority (highest first)
	--()
	["("] = -10,
	[")"] = -10, 
	["["] = -10,
	["]"] = -10,
	["{"] = -10,
	["}"] = -10,
	--access
	["."] = 9,
	[":"] = 9,
  --unary minus, unary bitwise not
  ["-unm"] = 8.5, --not matched with pattern exactly, created during cleanup
  ["~ubn"] = 8.5, --not matched with pattern exactly, created during cleanup
	--not,len
  ["not"] = 8,
	-- ["!"] = 8,
	["#"] = 8,
	--math
	["^"] = 7, --exponent
	-- ["**"] = 6, --cross
	["/"] = 6,
	["//"] = 6, --floor div
	["*"] = 6,
	["%"] = 6, --mod
	["+"] = 5,
	["-"] = 5,
  --bitshift
  [">>"] = 4.75,
  [">>>"] = 4.75,
  ["<<"] = 4.75,
  --bitwise
  ["&"] = 4.6, --and
  ["|"] = 4.6, --or
  ["~"] = 4.6, --xor
  --concat
  [".."] = 4.5,
	--compare
	["=="] = 4,
	-- ["!="] = 4,
	["~="] = 4,
	["<"] = 4,
	[">"] = 4,
	[">="] = 4,
	["<="] = 4,
	--logic
	["and"] = 3,
	["or"] = 3,
	--assign
	["+="] = 1, ["-="] = 1, ["*="] = 1, ["/="] = 1, ["="] = 1,
	--non op
	[SINGLE_QUOTE] = false,
	[DOUBLE_QUOTE] = false, --quotes, highligher is buggy with '
	["--"] = false, -- comment
	[";"] = false, --line end
	["\n"] = false, --for debug line numbers
	[" "] = false, --prevent = = from being read as ==
	[","] = 0,
}

Loader._rightAssociate = {
	["^"] = true,
  ["not"] = true,
  ["-unm"] = true,
  ["~ubn"] = true,
}



function Loader._closePar( openPar )
	return (  { ["("]=")", ["["]="]", ["{"]="}" }) [ openPar ]
end


function Loader._chunkType( text )
	--if not text then return false end
  local longQuote = text:match"^%[=*%["
  if text:sub(1,2) == "--" then
    local block = text:sub(3):match"%[=*%["  
    local commentEnd = block and block:gsub("%[","]") or "\n"
    if text:sub(-#commentEnd) == commentEnd then
      return "comment"
    elseif text:find(commentEnd,1,true) then 
      return false
    else
      return "incomplete_comment"
    end
  elseif text == "[=" or longQuote then
    if longQuote then
      local endQuote = longQuote:gsub("%[","]")
      if text:sub(-#longQuote) == endQuote then
        return "str"
      end
      return not text:find(endQuote,1,true) and "unfinished_str" or false
    end
    return "unfinished_str"
	elseif text:match"[ \t\n\r]" and text~="\n" and not text:match"^['\"]" then
		return false
	elseif text=="\n" then
		return "line"
	-- elseif text:match"//.+" then 
	-- 	return false
  end
  
  if text:sub(1,3) == "..." then
    if text == "..." then 
      return "var"
    end
    return false
  elseif text == "0x" or text == "0b" then
    return "num" --incomplete
  end
	for _, name in ipairs{ "op","num","var","str" } do
		local group = Loader._patterns[ name ]
		local txt =  text
		if name == "str" then
			--hide escaped quotes for testing
			txt = txt:gsub("\\'",""):gsub('\\"',"")
		end
		for _,pat in pairs( group ) do
			if txt:match( pat ) then
				return name
			end
		end
	end
	return false
end

--todo unused?
function Loader._splitOp( token )
  local extras = {}
  local value = token.value
  local start, stop = 1, #value
  --TODO
  while Loader._ops[ value:sub(start, stop) ] == nil
      or stop ~= #value do
    if Loader._ops[ value:sub(start, stop) ] == nil then
      stop = stop - 1
    else
      table.insert(extras, value:sub(start,stop))
      start = stop + 1
      stop = #value
    end
  end
  table.remove(extras, 1)
  return extras
end

function Loader.tokenize( src )
  local start, stop = 1, 0
  local tokens = {}
	
	--print( ">tokenize> "..state.area[1]..", "..state.area[2] )
	return Async.insertTasks(
    Async.whileLoop("tokenize-loop",function() return stop <= #src end, function()
      local chunk = src:sub( start, stop )
      local chunk2 = src:sub( start, stop+1 )
      
      --prevent bad op merging
      --ex y=-4 being =- or () not being split
      local chunkType2 = Loader._chunkType( chunk2 )
      if chunkType2 == "op" and #chunk == 1 then
        chunkType2 = Loader._ops[ chunk2 ] ~= nil
      end
      if not chunkType2
        and (chunk2:sub(1,1) == '"' or chunk2:sub(1,1) == "'")
        and Loader._chunkType(chunk or "")~="str" then
          chunkType2 ="unfinished_str"
      end
      if not chunkType2 then --whitespace, end token
        if #chunk > 0 then
          table.insert( tokens, chunk )
          start = stop + 1 --symbol that broke the chunk
        else --prob whitespace
          start = start+1
        end
        stop = start - 1 --empty selection
      else
        stop = stop+1 --was still valid
      end
    end),
    {
      label = "tokenize-post-while",
      func = function()
        local chunk = src:sub( start, stop )
        if #chunk > 0 then --whitespace or chunk
          if Loader._chunkType( chunk ) then
            table.insert( tokens, chunk )
          end
        end
        return true --step done
      end
    },
    RETURN( "tokenize", tokens )
  )
end

function Loader.cleanupTokens( tokens )
  local blockLevel = 1
  local line = 1
  local index = 1
  local blockStack = {}
  local comment = false
  return insertTasks(
    Async.whileLoop("cleanupTokens",function() return index <= #tokens end,
    function()
      local token = tokens[index]

      if token == "\n" then
        table.remove(tokens, index)
        line = line + 1
        return --continue
      end

      local prior = tokens[index-1]
      local twicePrior = tokens[index-2]
      local tokenType = Loader._chunkType(token)

      if tokenType == "comment" then
        line = line + #token:gsub("[^\n]","")
        table.remove(tokens, index)
        return --continue
      end

      if Loader._ops[token] then tokenType = "op" end
      if Loader.keywords[token] then tokenType = "keyword" end
      if token=="or" or token=="and" or token=="not" then tokenType = "op" end
      local infoToken = {
        value = token,
        type = tokenType,
        line = line,
        blockLevel = blockLevel
      }

      if token == "~"
      and (
        ( 
          prior and (
            --is op or keyword, but not closing ) type
            prior.type == "op" and prior.value ~= ")" and prior.value ~= "}" and prior.value ~= "]"
          )
        ) or (
          prior and prior.type == "keyword"
        ) or (not prior)
      ) then
        infoToken.value = "~ubn"
      end

      if tokenType == "num" then
        local base
        if token:sub(1,2) == "0b" then
          base = 2
          infoToken.value = infoToken.value:sub(3)
        elseif token:sub(1,2) == "0x" then
          base = 16
          infoToken.value = infoToken.value:sub(3)
        end
        infoToken.value = tonumber(infoToken.value, base)

        if prior and prior.value == "-"
        and ((twicePrior and twicePrior.type == "op" and (
          twicePrior.value ~= ")" and twicePrior.value ~= "}" and twicePrior.value ~= "]" ))
         or twicePrior == nil or (twicePrior and twicePrior.type=="keyword")) then
          table.remove(tokens, index-1)
          infoToken.value = -infoToken.value
          index = index-1
        end

      elseif token == "true" or token == "false" then
        infoToken.type = "boolean"
        infoToken.value = token == "true"
      
      elseif tokenType == "op" or (tokenType=="keyword" and token == "in") then
        if (token == "=" or token == "in") and (prior and prior.type == "var") then
          local newToken = {
            type = "assignment-set",
            token = token,
            value = {prior},
            line = line
          }
          tokens[index-1] = newToken
          
          while twicePrior and twicePrior.type == "op" and (twicePrior.value == "," or twicePrior.value == ".") 
          and (tokens[index-3].type=="var") do
            local op = table.remove( tokens, index-2 ) -- , or .
            local v = table.remove( tokens, index-3) --____. or ____,
            
            index = index - 2
            if op.value == "," then
              table.insert(newToken.value, 1, v)
            else
              newToken.value[1].value = v.value ..".".. newToken.value[1].value
            end
            twicePrior = tokens[index-2]
          end
          table.remove(tokens, index)
          return --continue
        elseif token == "(" or token == "{" then -- " doesn't
          if prior and (
              (prior.type == "var")
            or (prior.type == "op" and (prior.value == ")" or prior.value == "]" or prior.value == "}"))
          ) then
            infoToken.call = true  
            if tokens[index+1] == ")" or tokens[index+1] == "]" or tokens[index+1] == "}" then
              infoToken.empty = true
            end
          elseif prior and prior.type == "keyword" and prior.value == "function" then
            prior.inlineFunc = true
          end
        elseif token == "[" then
          if prior and ( (prior.type == "var") or (prior.type == "op" and prior.value == "]") ) then
            infoToken.index = true
            if tokens[index+1] == "]" then
              error("index expected for [] on line "..line)
            end
          end
        end
      elseif tokenType=="keyword" then
        if token == "function"
        or token == "do"
        or token == "repeat"
        or token == "then" then
          blockLevel = blockLevel + 1
          -- table.insert(blockStack, infoToken)
        elseif token == "else" or token == "elseif" then
          infoToken.blockLevel = blockLevel-1
        elseif token == "end" or token=="until" then
          blockLevel = blockLevel-1
          infoToken.blockLevel = blockLevel
        end
      elseif tokenType=="str" then
        --remove quotes
        if token:match([=[^["']]=]) then
          infoToken.value = token:sub(2,-2)
        else
          local n = #token:match"^%[=*%[" + 1
          local newLine = token:sub(n,n) == "\n" and 1 or 0
          line = line + #token:gsub("[^\n]","")
          infoToken.value = token:sub(n + newLine, -n)
        end
        --as call
        if prior and prior.type == "var" then
          tokens[index] = infoToken
          table.insert( tokens, index, {
            type = "op",
            value = "(",
            line = line,
            call = true
          })
          -- index (, +1 "", +2 )
          table.insert( tokens, index+2, {
            type = "op",
            value = ")",
            line = line
          })
          index = index + 3 --skip to after )
          return --continue
        end
      elseif tokenType=="var" then
        if prior and prior.value == "-"
        and ((twicePrior and twicePrior.type == "op" and (
          twicePrior.value ~= ")" and twicePrior.value ~= "}" and twicePrior.value ~= "]" ))
         or twicePrior == nil or (twicePrior and twicePrior.type=="keyword")) then
          prior.value = "-unm"
        end
      end

      tokens[index] = infoToken
      index = index + 1
    end),
    RETURN("cleanupTokens", tokens)
  )
end

function Loader._readTable( tokens, start )
  local tableInit = {}
  if tokens[start].value ~= "{" then
    error("Table parsing must start on '{' token")
  end
  local index = start+1
  local N = 0
  local key, value

  return Async.insertTasks(
    Async.whileLoop("_readTable", function() return index <= #tokens end, function()
      local token = tokens[index]
      local line = token.line

      if token.value == "}" then
        return {tableInit, index + 1}
      end
      if not key then
        if token.value == "[" then
          local infix, nextIndex = Loader._collectExpression( tokens, index+1, false, token.line, true, true )
          key = infix
          if tokens[nextIndex].value ~= "]" then
            error("']' expected in table near line "..token.line)
          end
          nextIndex = nextIndex + 1
          if tokens[nextIndex].value ~= "=" then
            error("'=' expected in table near line "..token.line)
          end
          index = nextIndex +1
        elseif token.type == "var" and tokens[index+1] and tokens[index+1].value == "=" then
          key = {{type="str", value = token.value}}
          index = index + 2
        elseif token.type == "assignment-set" then
          for i = 1, #token.value -1 do
            --insert as value
            N = N + 1
            local k = {Loader._val(N)}
            local infix, nextIndex = Loader._collectExpression( tokens, index+1, false, token.line, true )
            local v = infix
            table.insert( tableInit, {line = line, infix = {key=k, value=v}} )
          end
          key = {{type="str", value = token.value[ #token.value ].value}}
          index = index + 1
        else
          N = N + 1
          key = {Loader._val(N)}
        end
      end

      local infix, nextToken = Loader._collectExpression(tokens, index, false, tokens[index].line, true, true)
      --{x = y, z = w} y,z
      local nextKey = nil
      if #infix == 1 and infix[1].type == "assignment-set" and #infix[1].value == 2 then
        nextKey = {Loader._val(infix[1].value[2].value)} --non var
        infix = {infix[1].value[1]}
      end
      local value = infix
      table.insert(tableInit, {line = line, infix = {key=key,value=value}})
      key, value = nextKey, nil

      token = tokens[nextToken]

      if token.value ~= "," and token.value ~= "}" and not nextKey then
        error("Expected `,` or `} near line "..token.line.." for table starting at line "..line)
      end
      if token.value == "," then
        index = nextToken + 1
      else
        index = nextToken
      end
    end)
  )
end

--returning next unhandled token
function Loader._findExpressionEnd( tokens, start, allowAssignment, ignoreComma, tableMode )
  local index = start
  local brackets = {}
  local requiresValue = true
  local argGroups = 1
  local inlineFunctions = 0

  local startPermitted = {
    ["#"]   = true,
    ["not"] = true,
    ["("]   = true,
    ["{"]   = true,
    ["["]   = true,
    ["-unm"] = true,
    ["~ubn"] = true,
  }
  if tokens[start].type=="op"then
    if not startPermitted[tokens[start].value] then
      local keys = {}
      for a in pairs(startPermitted) do 
        if a:sub(2,2) == "u" then
          table.insert(keys, a:sub(1,1))
        else
          table.insert(keys, a)
        end
      end
      error("Can't start an expression with op `"..tokens[start].value.."` must be one of: "..table.concat(keys,", "))
    end
  end
  return Async.insertTasks(
    Async.whileLoop("_findExpressionEnd", function () return true end, function()
      local token = tokens[index]
      
      if not token then
        if start == index then return {false} end
        if requiresValue then error("Incomplete expression at end of file") end
        return {index}
      end

      if token.type == "op" and token.value=="=" and not allowAssignment then
        return {index}
        --error("Assignment can not be use in expression on line "..token.line)
      end
      
      if requiresValue then
        if token.type == "op" then
          local allowingDot = token.value == "." and index ~= start
          if not startPermitted[token.value] and (not allowingDot) then
            error("Expected a value, found op "..token.value.." instead on line "..token.line)
          end
          if token.value == "{" then
            Async.insertTasks({
              label = "_findExpressionEnd-parseTable-result",
              func = function( tableInit, nextToken )
                token.init = tableInit
                token.skip = nextToken
                index = nextToken
                requiresValue = false --table is value
                return true --task complete
              end
            })
            Loader._readTable( tokens, index )
            return --continue
          elseif token.value == "(" or token.value=="[" then
            table.insert(brackets, token)
          end
          --requiresValue = true again
        elseif token.inlineFunc then
          local fname, args, instStart = Loader.readFunctionHeader(tokens, index, true)
          
          Async.insertTasks( 
            { --this task happens AFTER the .buildInstructions call because the buildInstructions inserts into the front of the queue
              label = "storeInlineFunctionInstructions",
              func = function( inst, nextIndex )
                token.instructions = inst
                token.name = fname
                token.args = args
                token.start = index
                token.skip = nextIndex
                token.op = "function"
                token.value = nil
                index = nextIndex
                Loader.batchPostfix(token.instructions)
                return true
              end
            }
          )
          Loader.buildInstructions(tokens, instStart, token.blockLevel) --returns instructions, nextIndex
          requiresValue = false
          return --continue into inserted tasks
        else          
          requiresValue = false
        end
      elseif token.type == "op" then
        if token.value == ")" or token.value == "}" or token.value == "]" then
          local topBracket = table.remove(brackets)
          if tableMode and (token.value == "}" or token.value == "]") and not topBracket then
            return {index}
          end
          if token.value ~= Loader._closePar(topBracket.value) then
            error("Mis-matched brackets opening with "..topBracket.value.." on line "..topBracket.line.." and "..token.value.." on line"..token.line)
          end
          -- requiresValue = false again
        elseif token.call or token.index then
          if token.value == "{" or token.value == "(" or token.value=="[" then
            table.insert(brackets, token)
            if token.empty then
              requiresValue = false
            else
              requiresValue = true
            end
          end
        elseif token.type == "op" and startPermitted[token.value] then
          error("Unexpected token "..token.value.." in expression on line "..token.line)
        else
          if token.value == "," then
            if ignoreComma and #brackets == 0 then
              return {index, argGroups}
            elseif #brackets == 0 then
              argGroups = argGroups + 1
            end
          end
          requiresValue = true
        end
      else
        if #brackets ~= 0 then
          error("unclosed bracket on line "..brackets[1].line)
        end
        return { index, argGroups } --index of the next token to handle (not handled by this)
      end

      index = index + 1
    end)
  )
end

function Loader._makeEvaluation( tokens, start, stop )
  local stack = {}
  local out = {}
  local group = {}
  local result = {
    op = "EVAL",
    postfix = out
  }
  local nextToken = start
  local acceptAnotherToken = true
  return insertTasks(
    forEach("Loader._makeEvaluation-main", function(i, token)
      if token.type~="op" and acceptAnotherToken then
        table.insert(group, token)
      else
        
      end


    end, range, start, stop),
    RETURN("RETURN-Loader._makeEvaluation", result, nextToken)
  )

end

function Loader._collectExpression( tokens, index, allowAssignment, line, ignoreComma, tableMode )
  local endTokenPos = Async.sync(Loader._findExpressionEnd(tokens, index, allowAssignment, ignoreComma, tableMode)) --todo possible improvment on async
  if not endTokenPos then
    error("Missing expression for assignment on line "..line)
  end
  local infix = {}
  local i = index
  while i <= endTokenPos-1 do
    table.insert(infix, tokens[i])
    tokens[i].globalIndex = i
    tokens[i].localIndex = #infix
    if tokens[i].inlineFunc then
      i = tokens[i].skip
    else
      i = i + 1
    end
  end

  return infix, endTokenPos
end

function Loader.readFunctionHeader(tokens, index, inline)
  local fname
  if not inline then
    local fToken = tokens[index-1]
    fname = tokens[index]
    if not fname or fname.type~="var" then
      error("Expected name for function on line"..fToken.line)
    end
    fname = fname.value
    while tokens[index+1].value == "." do
      if tokens[index+2].type=="var" then
        fname = fname .. "." .. tokens[index+2].value
        index = index + 2
      else
        error("Expected name after `.` in function on line "..fToken.line)
      end
    end
  end
  fname = fname or ("[func:"..tokens[index].line.."]")
  local par = tokens[index+1]
  if not par or par.type~="op" or par.value~="(" then
    error("Expected `(` for function on line"..fToken.line)
  end
  local args = {}
  index = index + 2
  while tokens[index] and tokens[index].value~=")" do
    local name = tokens[index]
    if not name or name.type~="var" then
      error("Expected arg name or ) for function '"..fname.."' on line"..tokens[index-1].line)
    end
    if (not tokens[index+1]) or (tokens[index+1].value~="," and tokens[index+1].value~=")") then
      error("Expected `,` or `)` in function '' on line "..fToken.line)
    end
    table.insert(args, name.value)
    index = index + (tokens[index+1].value==")" and 1 or 2)
  end
  return fname, args, index + 1
end

function Loader.buildInstructions( tokens, start, exitBlockLevel )
  local instructions = {}

  local blocks = {} --if/while/for/...

  local inAssignment = false -- or {names,...}
  local index = start or 1
  local exitBlockLevel = exitBlockLevel or 0

  table.insert(instructions, {op="createScope", line = tokens[index] and tokens[index].line or "[?]"})

  return insertTasks(
    Async.whileLoop("Loader.groupInstructions-main["..index.."]", function() return index <= #tokens end, function()
      local token = tokens[index]
      local nextToken = tokens[ index + 1 ]
      local localVar = false
      if token.type == "keyword" and token.value=="local" then
        localVar = true
        index = index + 1
        token, nextToken = tokens[index],tokens[index+1]
      end
      if token.type == "assignment-set" then
        if token.token == "in" then
          error("invalid use of keyword 'in' on line "..token.line)
        end
        if inAssignment then
          error("value expected for assignment on line "..token.line)
        end

        local infix, endTokenPos = Loader._collectExpression(tokens, index+1, false, token.line) --todo async improvment
        local instruction = {
          op = "assign",
          vars = token.value,
          infix = { eval = infix },
          isLocal = localVar,
          index = #instructions+1,
          line = token.line
        }

        table.insert(instructions, instruction)
        index = endTokenPos
        return --continue
      elseif token.type == "keyword" then

        if token.value=="function" then
          local name,args,instStart = Loader.readFunctionHeader(tokens, index+1)
          
          Async.insertTasks( 
            { --this task happens AFTER the .buildInstructions call because the buildInstructions inserts into the front of the queue
              label = "storeFunctionInstructions",
              func = function( inst, nextIndex )
                local instruction = {
                  op = "function",
                  name = name,
                  args = args,
                  instructions = inst,
                  index = #instructions+1,
                  line = token.line,
                  isLocal = localVar
                }
                table.insert(instructions, instruction)
                index = nextIndex
                return true
              end
            }
          )
          Loader.buildInstructions(tokens, instStart, token.blockLevel) --returns instructions, nextIndex
          return --continue into inserted tasks
        

        --instructions with expresssions
        elseif token.value == "do" then
          table.insert(instructions, {
            op = "createScope",
            line = token.line,
            index = #instructions+1
          })
          local inst = {
            op = "do",
            line = token.line,
            index = #instructions+1,
            skip = false,
          }
          table.insert(instructions, inst)
          table.insert(blocks, inst)
        elseif token.value == "return" or token.value=="until" then
          local infix, endTokenPos = Loader._collectExpression(tokens, index+1, false, token.line) --todo async improvment
          local instruction = {
            op = token.value,
            infix = { [token.value=="until" and "condition" or "eval"] = infix },
            index = #instructions+1,
            line = token.line
          }
          
          table.insert(instructions, instruction)

          if token.value == "until" then
            local deleteScope = {op="deleteScope", token = token, index = #instructions+1, line = token.line}
            table.insert(instructions, deleteScope)
            local startingBlock = table.remove(blocks)
            if startingBlock.skip == false then
              startingBlock.skip = instruction
              instruction.start = startingBlock
            end
            if token.blockLevel <= exitBlockLevel then
              return {instructions, index + 1}
            end
          end

          index = endTokenPos
          return --continue
        elseif token.value == "end" then
          local startingBlock = table.remove(blocks)
          local endInst = {op="end", line = token.line, index = #instructions+1}
          table.insert(instructions, endInst)
          if startingBlock and startingBlock.skip == false then
            startingBlock.skip = endInst
            endInst.start = startingBlock
          end
          local deleteScope = {op="deleteScope", token = token, index = #instructions+1, line = token.line}
          table.insert(instructions, deleteScope)
          if token.blockLevel <= exitBlockLevel then
            return {instructions, index + 1}
          end
          index = index + 1
          return --continue
        elseif token.value == "if" or token.value == "elseif" then
          --TODO prevent varargs evaluation
          local infix, endTokenPos = Loader._collectExpression(tokens, index+1, false, token.line) --todo async improvment

          if token.value == "if" then
            table.insert(instructions, {op="createScope", line=token.line, index = #instructions+1}) 
            --scope used by any if/elseif/else, shared since only one can use it
            --scope also holds if state
          end

          local instruction = {
            op = token.value,
            infix = {condition = infix},
            skip = false, --not set
            index = #instructions+1,
            line = token.line
          }
          
          if token.value == "elseif" then
            local ifInst = table.remove(blocks)
            ifInst.skip = instruction
          end
          table.insert(instructions, instruction)
          table.insert(blocks, instruction)
          local nextToken = tokens[endTokenPos]
          if nextToken.type ~="keyword" or nextToken.value ~= "then" then
            error("`then` expected on line "..(tokens[endTokenPos-1].line))
          end
          index = endTokenPos + 1
          return --continue

        elseif token.value == "else" then
          local ifInst = table.remove(blocks)
          local instruction = {op="else",line = token.line, index = #instructions+1, skip=false}
          ifInst.skip = instruction
          table.insert(instructions, instruction)
          table.insert(blocks, instruction)
          index = index + 1
          return --continue

        elseif token.value == "while" then
          --TODO prevent varargs evaluation
          table.insert(instructions, {op="createScope", line=token.line, index = #instructions+1})
          local infix, endTokenPos = Loader._collectExpression(tokens, index+1, false, token.line) --todo async improvment
          local instruction = {
            op = "while",
            infix = {condition = infix},
            skip = false, --not set
            index = #instructions+1,
            line = token.line
          }

          table.insert(instructions, instruction)
          table.insert(blocks, instruction)
          local nextToken = tokens[endTokenPos]
          if nextToken.type ~="keyword" or nextToken.value ~= "do" then
            error("`do` expected on line "..(tokens[endTokenPos-1].line))
          end
          index = endTokenPos + 1
          return --continue
        elseif token.value == "for" then
          if nextToken.type ~= "assignment-set" then
            error("expected variable(s) for `for` loop on line "..token.line)
          end
          table.insert(instructions, {op="createScope", line = token.line, index = #instructions+1})
          if nextToken.token == "in" then
            local generatorInit, nextTokenIndex = Loader._collectExpression(tokens, index+2, false, token.line, true)
            local doToken = tokens[nextTokenIndex]
            if doToken.type ~= "keyword" or doToken.value ~= "do" then
              error("Expected do for `for in` loop on line "..token.line)
            end

            local initGenerator = {
              op="for-in-init",
              --vars = {"$generator"}, --invalid var name as private variable
              infix = {eval = generatorInit},
              line = token.line,
              index = #instructions + 1
            }
            table.insert(instructions, initGenerator)

            local inst = {
              op = "for-in",
              vars = nextToken,
              line = token.line,
              skip = false, --end block inst link
              index = #instructions+1
            }
            table.insert(instructions, inst )
            table.insert(blocks, inst)
            index = nextTokenIndex+1
            return --continue
          elseif #nextToken.value ~= 1 then
            error("varargs can't be used on initalization of a for loop with `=` on line "..token.line)
          else -- =
            local varInit, nextTokenIndex = Loader._collectExpression(tokens, index+2, false, token.line, true)
            local expectedComma = tokens[nextTokenIndex]
            if expectedComma.type ~= "op" or expectedComma.value~="," then
              error("Expected comma after variable init for `for = ` loop on line "..token.line)
            end
            local limit, nextTokenIndex = Loader._collectExpression(tokens, nextTokenIndex+1, false, token.line, true)
            local doOrComma = tokens[nextTokenIndex]
            local increment
            if doOrComma.type=="op" and doOrComma.value == "," then
              increment, nextTokenIndex = Loader._collectExpression(tokens, nextTokenIndex+1,false, token.line, true)
            elseif doOrComma.type ~= "keyword" or doOrComma.value ~="do" then
              error("Expected `do` or increment after variable limit for `for = ` loop on line "..token.line)
            end
            local mustBeDo = tokens[nextTokenIndex]
            if mustBeDo.type ~= "keyword" or mustBeDo.value ~= "do" then
              error("Expected `do` for `for = ` loop on line "..token.line)
            end

            local forInit = {
              op="assign", 
              vars = {nextToken.value[1]},
              infix = {eval = varInit},
              line = token.line,
              index = #instructions+1,
              isLocal = true
            }
            table.insert(instructions, forInit)
            
            local forLimit = {
              op="assign",
              vars = {{type="var", value="$limit"}},
              infix = {eval=limit},
              line = token.line,
              index = #instructions+1,
              isLocal = true
            }
            table.insert(instructions, forLimit)
            
            local forIncrement = {
              op="assign",
              vars = {{type="var", value="$increment"}},
              infix = {
                eval = increment or {{type="num",value=1}},
              },
              line = token.line,
              index = #instructions+1,
              isLocal = true
            }
            table.insert(instructions, forIncrement)
            
            local forOp = {
              op = "for",
              skip = false,
              line = token.line,
              index = #instructions + 1,
              var = nextToken.value[1]
            }

            table.insert( instructions, forOp )
            table.insert( blocks, forOp )
            index = nextTokenIndex + 1
            return --continue
          end

        end --token.value == keyword



        
      else --generic expression
        --TODO prevent varargs evaluation
        local infix, endTokenPos = Loader._collectExpression(tokens, index, false, token.line) --todo async improvment
        local instruction = {
          op = "eval",
          infix = {
            eval = infix
          },
          index = #instructions+1,
          line = token.line
        }
        
        table.insert(instructions, instruction)
        index = endTokenPos
        return --continue
      end



      index = index + 1
    end),
    {
      label="RETURN-buildInstructions",
      func = function( inst, nextTokenIndex )
        return {
          inst or instructions,
          nextTokenIndex or false
        }
      end
    }
  )
end

--1 If the input character is an operand, print it.
--2 If the input character is an operator- 
-- a  If stack is empty push it to the stack.
-- b  If ((its precedence value is greater than the precedence value of the character on top) OR (precedence is same AND associativity is right to left)), push.
-- c  If ((its precedence value is lower) OR (precedence is same AND associativity is left to right)), 
--    then pop from stack and 
--    print while precedence of top char is more than the precedence value of the input character.
--3 If the input character is ‘)’, then pop and print until top is ‘(‘. (Pop ‘(‘ but don’t print it.)
--4 If stack becomes empty before encountering ‘(‘, then it’s a invalid expression.
--5 Repeat steps 1-4 until input expression is completely read.
--6 Pop the remaining elements from stack and print them.

-- foo ( a + b )
--foo a b + call

function Loader._generateTablePostfix( tableToken )
  return Async.insertTasks(Async.forEach("_generateTablePostfix", function(i, entry)
    Async.insertTasks({
      label = "_generateTablePostfix-key-results",
      func = function(postfix)
        entry.postfix = entry.postfix or {}
        entry.postfix.key = postfix
        return true
      end
    })
    Loader._generatePostfix( entry.infix.key )

    Async.insertTasks({
      label = "_generateTablePostfix-value-results",
      func = function(postfix)
        entry.postfix = entry.postfix or {}
        entry.postfix.value = postfix
        return true
      end
    })
    Loader._generatePostfix( entry.infix.value )
    
  end, ipairs, tableToken.init))
end

function Loader._generatePostfix( infix )
  local out, opStack = {}, {} --opstack contains ops in ascending order only (except ())
  local index = 1
  return 
    Async.insertTasks(
      Async.whileLoop("_generatePostfix",function() return index <= #infix end, function()
        local token = infix[index]
        

        if token.type == "op" then
          local priority = Loader._ops[token.value] --higher happens first
          if token.value == "{" and token.init then
            index = token.skip - token.globalIndex + token.localIndex
            Loader._generateTablePostfix( token )
            token.type = "val"
            table.insert( out, token ) --treated as value
            return --continue
          end

          if #opStack == 0 
          or (token.value == "(" or token.value == "[" or token.value == "{")
          or ((opStack[#opStack].value == "(" or opStack[#opStack].value == "[" or opStack[#opStack].value == "{") and (
              token.value ~= ")" and token.value ~= "]" and token.value~= "}"
            )) then
              while #opStack > 0 and (opStack[#opStack].value == "." or opStack[#opStack].value == ":") do --happens before () sets
                table.insert(out, table.remove(opStack))
              end
            table.insert(opStack, token)
            if token.call then
              table.insert(out, {type="argsMarker"})
            end
          elseif token.value == ")" or token.value == "]" or token.value == "}" then
            while #opStack > 0 and (
              opStack[#opStack].value  ~= "(" and
              opStack[#opStack].value  ~= "[" and
              opStack[#opStack].value  ~= "{"
            ) do
              table.insert(out, table.remove(opStack))
            end
            if #opStack == 0 then 
              error("postfix conversion failed, missing (),{} or [], this error should have been caught by an eariler step in the compiler...")
            end
            local par = table.remove(opStack) --pop ([{
            if par.call or par.index then
              table.insert( out, par )
            end
          else
              if (Loader._ops[opStack[#opStack].value] > priority) 
              or ((not Loader._rightAssociate[token.value]) and Loader._ops[opStack[#opStack].value] == priority) then
                table.insert(out, table.remove(opStack))
                while #opStack > 0 and (Loader._ops[opStack[#opStack].value] > priority)  do
                  table.insert(out, table.remove(opStack))
                end
              end
            --end
            table.insert(opStack, token)
          end
        else
          table.insert( out, token )
        end
        if token.value == "and" or token.value == "or" then
          --flag insertion
          table.insert(out, {
            type = "op",
            value = "short_circuit"
          })
        end
        index = index + 1
      end),
      Async.whileLoop("_generatePostfix-leftovers", function() return #opStack>0 end, function()
        table.insert(out, table.remove(opStack))
      end),
      RETURN( "_generatePostfix", out )
    )
end

function Loader.batchPostfix( instructions )
  return Async.insertTasks(
    Async.forEach( "Batch-Infix", function(i, inst)
      if inst.instructions then
        Loader.batchPostfix( inst.instructions ) --inserts task
        --continues into subtask at end of loop itteration
      end
      if inst.infix then
        inst.postfix = {}
        for k, v in pairs(inst.infix) do
          Async.insertTasks(
            {label="store-postfix",func=function(postfix) --received from _generatePostfix bellow
              inst.postfix[k] = postfix
              return true
            end}
          )
          Loader._generatePostfix( v ) --inserts a task before the return code, also returns postfix into async task
        end
      end
    end, ipairs, instructions )
  )
end

function Loader._tokenValue( token, scope )
  if token.type ~= "var" then
    return token
  end
  return scope:get( token.value )
end
 
--TODO varargs issue
function Loader._popVal( stack, scope, line, keepVarargs )
  local token = table.remove(stack)
  if not token then error("Error, empty stack from expression on line "..line, 2) end
  local value = Loader._tokenValue( token, scope )
  if value.type == "varargs" and not keepVarargs then
    return value.value
  end
  return value
end

function Loader._tokenValues( scope, keepVarargs, tokens )
  return Async.insertTasks(
    {
      label = "Loader._tokenValues - queueAll",
      func = function()
        for i, token in ipairs( tokens ) do
          local varargsTask = {
            label = "Loader._tokenValues - result",
            func = function( value )
              value = value or token
              if value.type == "varargs" and not keepVarargs then
                value = value.value
              end
              tokens[ i ] = value
              return true --task complete
            end
          }

          if token.type == "var" then
            Async.insertTasks(
              {
                label = "Loader._tokenValues - queue",
                func = function()
                  scope:getAsync( token.value ) --queued
                  return true --task complete
                end
              },varargsTask
            )
          else
            Async.insertTasks(varargsTask)
          end
        end
        return true
      end
    },{
      label = "Loader._tokenValues - results",
      func = function()
        return tokens --will be unpacked
      end
    }
  )
end

function Loader._asyncPopValues( stack, scope, line, keepVarargs, nValues, callback )
  local tokens = {}
  for i = 1, nValues do
    local token = table.remove(stack)
    if not token then
      error("Error, empty stack from expression on line "..line, 2)
    end
    table.insert(tokens, 1, token)
  end
  Async.insertTasks(
    {
      label = "Loader._asyncPopValues - tokenValues",
      func = function ()
        Loader._tokenValues( scope, keepVarargs, tokens )
        return true
      end
    },{
      label = "Loader._asyncPopValues - callback",
      func = function( ... )
        callback( ... )
        return true
      end
    }
  )
end

function Loader._val( v, tName )
  return {
    type = tName or type(v),
    value = v
  }
end

Loader.constants = {
  ["nil"] = Loader._val(nil),
  ["true"] = Loader._val(true),
  ["false"] = Loader._val(false),
}

function Loader._varargs( ... )
  return {
    type = "varargs",
    value = ..., --first value
    varargs = {...}
  }
end

function Loader.callFunc( func, args, callback )
  local fArgs = args.varargs or {args}
  if func.value then
    local result
    if func.unpacker then
      fArgs = func.unpacker( fArgs )
    end
    
    Async.insertTasks(
      {
        label = "Loader.callFunc - native",
        func = function()
          local results
          if #fArgs > 0 then
            results = {func.value( table.unpack(fArgs) )}
          else
            results = {func.value()}
          end
          
          return {results} --ok if async and returns nothing, inserted task in queue will
        end
      },{
        label = "Loader.callFunc - native - packer",
        func = function( results )
          if func.packer then
            results = func.packer( results )
          end
          return {results}
        end
      },{
        label = "Loader.callFunc - native - result",
        func = function( results )
          local result = Loader._varargs(table.unpack(results or {}))
          callback( result )
          return true
        end
      }
    )
    
  else
    
    Async.insertTasks(
      {
        label = "callFunc-setArgs",
        func = function()
          local named = 0
          for i=1,#func.args do --TODO feature trailing named args? (a, b, ..., c)
            if func.args[i] == "..." then break end
            func.env:setAsync(true,func.args[i], fArgs[i] or Loader.constants["nil"])
            named = i
          end
          if func.args[named+1] == "..." then
            func.env:setVarargs(Loader._varargs( table.unpack(fArgs, named+1) ))
          else
            func.env:setVarargs(nil)
          end
          return true
        end
      },{
        label = "callFunc-execute",
        func = function()
          Loader.execute(func.instructions, func.env, table.unpack(fArgs))
          return true
        end
      },{
        label = "callFunc-callback-return",
        func = function( result )
          callback( result )
          return true
        end
      }
    )
    
  end
end

function Loader.newTable()
  local newTable = {}
  local val = Loader._val(newTable)
  local indexer = {}
  Loader.tableIndexes[newTable] = indexer,
  setmetatable(indexer, {__mode = "v"})
  return val, newTable, indexer
end

function Loader.assignToTable( tableValue, keyValue, valueValue )
  tableValue.value[keyValue] = valueValue
  Loader.tableIndexes[tableValue.value][keyValue.value] = keyValue
end

function Loader.getTableIndex( tableValue )
  if tableValue.type ~= "table" then
    error("expected table, got "..(tableValue.type or "nil"), 2 )
  end
  local index = Loader.tableIndexes[ tableValue.value ]
  if not index then error("internal error, index missing for table") end
  return index
end

--async
function Loader.assignToTableWithEvents( tableValue, keyValue, valueValue )
  if not tableValue then error("expected tableValue",2 ) end
  if not keyValue then error("expected keyValue",2 ) end
  --if not valueValue then error("expected valueValue",2 ) end
  if valueValue and valueValue.varargs then
    valueValue = valueValue.value
  end
  if valueValue and valueValue.type == "nil" then
    valueValue = nil
  end
  local index = Loader.getTableIndex( tableValue )
  local k = index[ keyValue.value ]
  local v = tableValue.value[ keyValue ] or tableValue.value[ k ]

  --exists
  if v then
    Loader.assignToTable( tableValue, keyValue, valueValue )
    return
  end
  
  local __newindex = Loader.getMetaEvent( tableValue, "__newindex" )
  if __newindex.type == "function" then
    Loader.callFunc( __newindex, Loader._varargs( tableValue, keyValue, valueValue ), function() end )
  else
    Loader.assignToTable( tableValue, keyValue, valueValue )
  end
end

function Loader.getMetaEvent( tableValue, eventName )
  local meta = Loader.getmetatable( tableValue, true )
  local NIL = Loader.constants["nil"]
  if not meta or meta.type == "nil" then
    return NIL
  end
  
  local index = Loader.getTableIndex( meta )
  local k = index[ eventName ]
  return meta.value[ k ] or NIL
end

function Loader.indexTable( tableValue, keyValue )
  local index = Loader.getTableIndex( tableValue )
  local k = index[ keyValue.value ]
  local v = tableValue.value[keyValue] or tableValue.value[ k ]
  return v or Loader.constants["nil"]
end

--async
function Loader.indexTableWithEvents( tableValue, keyValue, callback, loop )
  loop = loop or {} --will not protect against loops with functions on __index
  local LOOP_INDEX = tostring(tableValue.value)..":"..keyValue.type..":"..tostring(keyValue.value)
  if loop[ LOOP_INDEX ] then
    error("Cycle detected indexing table")
  end
  loop[ LOOP_INDEX ] = true
  local index = Loader.getTableIndex( tableValue )
  local k = index[ keyValue.value ]
  local v = tableValue.value[ keyValue ] or tableValue.value[ k ]
  if v then
    callback( v )
    return
  end
  
  local __index = Loader.getMetaEvent( tableValue, "__index" )

  if __index.type == "function" then
    Loader.callFunc( __index, Loader._varargs( tableValue, keyValue ), function( values )
      --only first value is returned
      callback( values.varargs[1] )
    end )
  elseif __index.type == "table" then
    Async.insertTasks({
      label = "index-with-events-table", func = function()
        Loader.indexTableWithEvents( __index, keyValue, callback, loop )
        return true
      end
    })
  else
    --unsupported __index type
    callback( Loader.constants["nil"] )
  end
end

--sync
function Loader.setmetatable( tableValue, metatableValue )
  if tableValue.type ~= "table" then
    error("expected table for arg 1", 2)
  end
  local tbl, protected = Loader.getmetatable( tableValue )
  if protected then
    error("cannot change a protected metatable")
  end
  Loader.metatables[ tableValue.value ] = metatableValue.value
  return table
end

--sync
--returns table/nil, protected
function Loader.getmetatable( tableValue, raw )
  if tableValue.type == "string" then
    return Loader.metatables.string
  elseif tableValue.type ~= "table" then
    return Loader.constants["nil"]
  end
  local rawMeta = Loader.metatables[ tableValue.value ]
  
  if rawMeta == nil then
    return Loader.constants["nil"], false

  elseif raw then
    return Loader._val(rawMeta), false

  else
    local indexer = Loader.tableIndexes[ rawMeta ]
    local k = indexer.__metatable
    local event = rawMeta[k]
    if event then
      return event, true
    else
      return Loader.getmetatable( tableValue, true )
    end
  end
end

function Loader._initalizeTable( tableToken, scope, line )
  local var, newTable, indexer = Loader.newTable()
  
  local key
  return Async.insertTasks(Async.forEach("_initalizeTable", function(i, entry)
    Async.insertTasks({
      label = "_initalizeTable-value-result",
      func = function(val)
        newTable[key] = val[1]

        return true
      end
    })
    Loader.eval( entry.postfix.value, scope, line )

    Async.insertTasks({
      label = "_initalizeTable-key-result",
      func = function(tKey)
        key = tKey[1]
        indexer[key.value] = key
        return true
      end
    })
    Loader.eval( entry.postfix.key, scope, line )

  end, ipairs, tableToken.init), 
  Async.RETURN("_initalizeTable", var))
end

function Loader.eval( postfix, scope, line )
  if not postfix then error("expected postfix",2) end
  if not scope then error("scope expected for arg 2",2) end
  local stack = {}
  local popAsync = Loader._asyncPopValues
  local val = Loader._val
  local skip = 0
  Async.insertTasks(
    Async.forEach("eval-postfix", function(index, token)
      if token.line then Async.setLine( token.line ) end
      if index < skip then
        return --continue
      end
      if token.type == "op" then
        if token.value == "short_circuit" then
          popAsync(stack, scope, line, false, 1, function(left)
            local truthy = false
            if left.type == "function" then
              truthy = true
            else
              truthy = not not left.value
            end

            local flagCount = 1
            local circuitMethod = false
            local aheadIndex = false
            for lookAheadIndex = index + 1, #postfix do
              local ahead = postfix[lookAheadIndex]
              if ahead.type == "op" then
                if ahead.value == "and" or ahead.value == "or" then
                  flagCount = flagCount - 1
                elseif ahead.value == "short_circuit" then
                  flagCount = flagCount + 1
                end
                if flagCount == 0 then
                  circuitMethod = ahead.value
                  aheadIndex = lookAheadIndex
                  break
                end
              end
            end

            if circuitMethod == "and" then
              if truthy then
                --evaluate normaly, left value discarded
              else
                --skip to aheadIndex + 1, left value pushed back to stack
                skip = aheadIndex + 1
                table.insert(stack, left)
              end
            elseif circuitMethod == "or" then
              if truthy then
                --skip to aheadIndex + 1, right evaluation skipped until and/or in postfix
                skip = aheadIndex + 1
                table.insert(stack, left)
              else
                --evaluate normaly
              end
            else
              error("invalid syntax: use of and/or")
            end
          end)
        elseif token.call then
          popAsync(stack, scope, line, true, 1, function(args)
            local func
            local expectedMarker
            Async.insertTasks(
              {
                label = "eval token.call - args marker",
                func = function()
                  if args.type == "argsMarker" then
                    popAsync(stack, scope, line, false, 1, function(popped)
                      func = popped
                      expectedMarker = args
                      args = Loader._varargs()
                    end)
                  else
                    popAsync(stack, scope, line, true, 1, function(popped)
                      expectedMarker = popped
                      popAsync(stack, scope, line, false, 1, function(popped)
                        func = popped
                      end)
                    end)
                  end
                  return true
                end
              },{
                label = "eval token.call - check & self",
                func = function()
                  if expectedMarker.type ~= "argsMarker" then
                    error("internal error, missing args marker for call")
                  end

                  if func.type == "self" then
                    if args.type ~= "varargs" then
                      args = Loader._varargs( args )
                    end
                    args.value = func
                    table.insert(args.varargs, 1, func)
                    popAsync(stack, scope, line, false, 1, function(popped)
                      func = popped
                    end)
                  end
                  return true
                end
              },{
                label = "eval token.call - table.__call & call",
                func = function()
                  if func.type == "table" then
                    local __call = Loader.getMetaEvent( func, "__call" )
                    if __call and __call.type=="function" then
                      if args.type ~= "varargs" then
                        args = Loader._varargs( func, args )
                      else
                        table.insert( args.varargs, func )
                      end
                      args.value = func
                      func = __call
                    end
                  end
      
                  if func.type ~= "function" then
                    error("attempt to call "..func.type.." on line "..token.line)
                  end
      
                  if args.type ~= "varargs" then
                    args = Loader._varargs( args )
                  end
      
                  Loader.callFunc( func, args, function( result )
                    if result and result.varargs then
                      result.len = math.min(1, #result.varargs )
                    end
                    table.insert( stack, result )
                  end)
                  return true
                end
              }
            )
          end) --pop async

        elseif token.index then
          popAsync(stack, scope, line, false, 2, function(a, b)
            if a.type == "str" then
              a = scope:getRootScope():get("string")
            end
            if a.type ~= "table" then
              error("attempt to index "..a.type.." on line "..token.line)
            end
            
            Loader.indexTableWithEvents( a, b, function(v)
              table.insert(stack, v)
            end )
          end)
          --local b, a = pop(stack, scope, line), pop(stack, scope, line)
          

        elseif token.value == "." then
          local b = table.remove(stack)
          popAsync(stack, scope, line, false, 1, function(a)
            if a.type == "str" then
              a = scope:getRootScope():get("string")
            end
            if a.type ~= "table" then
              error("attempt to index "..a.type.." on line "..token.line)
            end

            Loader.indexTableWithEvents( a, b, function(v)
              table.insert(stack, v)
            end)
          end)

        elseif token.value == ":" then
          local b = table.remove(stack)
          popAsync(stack, scope, line, false, 1, function(a)
          
            local selfVal = a
            if a.type == "str" then
              a = scope:getRootScope():get("string")
            end
            if a.type ~= "table" then
              error("attempt to index "..a.type.." on line "..token.line)
            end

            Loader.indexTableWithEvents( a, b, function(v)
              table.insert(stack, v)
              table.insert(stack, val(selfVal.value, "self"))
            end)
          end)

        elseif token.value == "not" then
          popAsync(stack, scope, line, false, 1, function(a)
            if a.type == "function" then
              table.insert( stack,  Loader.constants["false"] )
              return --continue
            end
            table.insert(stack, val(not a.value))
          end)

        elseif token.value == "#" then
          popAsync(stack, scope, line, false, 1, function(a)
            if a.value == "function" then
              error("attempt to get the length of a function on line "..token.line)
            end
            local event = Loader.getMetaEvent(a, "__len")
            if event.type ~= "nil" then
              Loader.callFunc( event, Loader._varargs( a ), function( size )
                table.insert(stack, size.value)
              end)
            else
              table.insert(stack, val(#(a.type=="table" and Loader.tableIndexes[a.value] or a.value)))
            end
          end)

        elseif token.value == "^" then
          popAsync(stack, scope, line, false, 2, function(a, b)
            if a.type == "function" or b.type == "function" then
              error("attempt to preform exponent opperation with "..a.type.." and "..b.type.." on line "..token.line)
            end

            local event
            if a.type == "table" then
              event = Loader.getMetaEvent( a, "__pow" )
            end
            if not event and b.type == "table" then
              event = Loader.getMetaEvent( b, "__pow" )
            end

            if event and event.type == "function" then
              Loader.callFunc( event, Loader._varargs( a, b ), function(result) --varargs result
                table.insert(stack, result.value)
              end)
            else
              table.insert(stack, val(a.value^b.value))
            end
          end)

        elseif token.value == "*" then
          popAsync(stack, scope, line, false, 2, function(a, b)
            if a.type == "function" or b.type == "function" then
              error("attempt to multiply "..a.type.." with "..b.type.." on line "..token.line)
            end

            local event
            if a.type == "table" then
              event = Loader.getMetaEvent( a, "__mul" )
            end
            if not event and b.type == "table" then
              event = Loader.getMetaEvent( b, "__mul" )
            end

            if event and event.type == "function" then
              Loader.callFunc( event, Loader._varargs( a, b ), function(result) --varargs result
                table.insert(stack, result.value)
              end)
            else
              table.insert(stack, val(a.value*b.value))
            end
          end)

        elseif token.value == "/" then
          popAsync(stack, scope, line, false, 2, function(a,b)
            if a.type == "function" or b.type == "function" then
              error("attempt to divide "..a.type.." with "..b.type.." on line "..token.line)
            end

            local event
            if a.type == "table" then
              event = Loader.getMetaEvent( a, "__div" )
            end
            if not event and b.type == "table" then
              event = Loader.getMetaEvent( b, "__div" )
            end

            if event and event.type == "function" then
              Loader.callFunc( event, Loader._varargs( a, b ), function(result) --varargs result
                table.insert(stack, result.value)
              end)
            else
              table.insert(stack, val(a.value/b.value))
            end
          end)
        
        elseif token.value == "//" then
          popAsync(stack, scope, line, false, 2, function(a,b)
            if a.type == "function" or b.type == "function" then
              error("attempt to divide "..a.type.." with "..b.type.." on line "..token.line)
            end

            local event
            if a.type == "table" then
              event = Loader.getMetaEvent( a, "__idiv" )
            end
            if not event and b.type == "table" then
              event = Loader.getMetaEvent( b, "__idiv" )
            end

            if event and event.type == "function" then
              Loader.callFunc( event, Loader._varargs( a, b ), function(result) --varargs result
                table.insert(stack, result.value)
              end)
            else
              table.insert(stack, val(math.floor(a.value/b.value)))
            end
          end)

        elseif token.value == "+" then
          popAsync(stack, scope, line, false, 2, function(a,b)
            if a.type == "function" or b.type == "function" then
              error("attempt to add "..a.type.." with "..b.type.." on line "..token.line)
            end

            local event
            if a.type == "table" then
              event = Loader.getMetaEvent( a, "__add" )
            end
            if not event and b.type == "table" then
              event = Loader.getMetaEvent( b, "__add" )
            end

            if event and event.type == "function" then
              Loader.callFunc( event, Loader._varargs( a, b ), function(result) --varargs result
                table.insert(stack, result.value)
              end)
            else
              table.insert(stack, val(a.value+b.value))
            end
          end)

        elseif token.value == "-" then
          popAsync(stack, scope, line, false, 2, function(a,b)
            if a.type == "function" or b.type == "function" then
              error("attempt to subtract "..a.type.." from "..b.type.." on line "..token.line)
            end

            local event
            if a.type == "table" then
              event = Loader.getMetaEvent( a, "__sub" )
            end
            if not event and b.type == "table" then
              event = Loader.getMetaEvent( b, "__sub" )
            end

            if event and event.type == "function" then
              Loader.callFunc( event, Loader._varargs( a, b ), function(result) --varargs result
                table.insert(stack, result.value)
              end)
            else
              table.insert(stack, val(a.value-b.value))
            end
          end)

        elseif token.value == "==" then
          popAsync(stack, scope, line, false, 2, function(a,b)
            if a.type == "function" and b.type == "function" then
              table.insert(stack, val(a == b))
              return --continue
            end

            local eventA = Loader.getMetaEvent( a, "__eq" )
            local eventB = Loader.getMetaEvent( b, "__eq" )
            if eventA and eventA.type == "function" and eventA == eventB then
              Loader.callFunc( eventA, Loader._varargs( a, b ), function(result) --varargs result
                table.insert(stack, result.value)
              end)
            else
              table.insert(stack, val(a.value == b.value))
            end
          end)

        elseif token.value == "~=" then
          popAsync(stack, scope, line, false, 2, function(a,b)
            if a.type == "function" and b.type == "function" then
              table.insert(stack, val(a ~= b))
              return --continue
            elseif a.type == "function" or b.type == "function" then --xor
              table.insert(stack, Loaders.constants["false"])
              return --continue
            end

            local eventA = Loader.getMetaEvent( a, "__eq" )
            local eventB = Loader.getMetaEvent( b, "__eq" )
            if eventA and eventA.type == "function" and eventA == eventB then
              Loader.callFunc( eventA, Loader._varargs( a, b ), function(result) --varargs result
                table.insert(stack, Loader._val(not result.value))
              end)
            else
              table.insert(stack, val(a.value ~= b.value))
            end
          end)

        elseif token.value == "<=" then
          popAsync(stack, scope, line, false, 2, function(a,b)
            if a.type == "function" or b.type == "function" then
              error("attempt to compare "..a.type.." with "..b.type.." using <= on line "..token.line)
            end

            local eventA = Loader.getMetaEvent( a, "__le" )
            local eventB = Loader.getMetaEvent( b, "__le" )
            if (eventA and eventA.type == "function") or (eventB and eventB.type == "function") then
              Loader.callFunc( eventA.type=="function" and eventA or eventB, Loader._varargs( a, b ), function(result) --varargs result
                table.insert(stack, result.value)
              end)
            else
              table.insert(stack, val(a.value<=b.value))
            end
          end)
          

        elseif token.value == ">=" then
          popAsync(stack, scope, line, false, 2, function(a,b)
            if a.type == "function" or b.type == "function" then
              error("attempt to compare "..a.type.." with "..b.type.." using >= on line "..token.line)
            end

            local eventA = Loader.getMetaEvent( a, "__le" )
            local eventB = Loader.getMetaEvent( b, "__le" )
            if (eventA and eventA.type == "function") or (eventB and eventB.type == "function") then
              Loader.callFunc( eventA.type=="function" and eventA or eventB, Loader._varargs( b, a ), function(result) --varargs result, args swapped
                table.insert(stack, result.value)
              end)
            else
              table.insert(stack, val(a.value>=b.value))
            end
          end)

        elseif token.value == "<" then
          popAsync(stack, scope, line, false, 2, function(a,b)
            if a.type == "function" or b.type == "function" then
              error("attempt to compare "..a.type.." with "..b.type.." using < on line "..token.line)
            end

            local eventA = Loader.getMetaEvent( a, "__lt" )
            local eventB = Loader.getMetaEvent( b, "__lt" )
            if (eventA and eventA.type == "function") or (eventB and eventB.type == "function") then
              Loader.callFunc( eventA.type=="function" and eventA or eventB, Loader._varargs( a, b ), function(result) --varargs result
                table.insert(stack, result.value)
              end)
            else
              table.insert(stack, val(a.value < b.value))
            end
          end)

        elseif token.value == ">" then
          popAsync(stack, scope, line, false, 2, function(a,b)
            if a.type == "function" or b.type == "function" then
              error("attempt to compare "..a.type.." with "..b.type.." using > on line "..token.line)
            end

            local eventA = Loader.getMetaEvent( a, "__lt" )
            local eventB = Loader.getMetaEvent( b, "__lt" )
            if (eventA and eventA.type == "function") or (eventB and eventB.type == "function") then
              Loader.callFunc( eventA.type=="function" and eventA or eventB, Loader._varargs( b, a ), function(result) --varargs result, args swapped
                table.insert(stack, result.value)
              end)
            else
              table.insert(stack, val(a.value > b.value))
            end
          end)

        elseif token.value == "and" then
          --handled in short_circuit

        elseif token.value == "or" then
          --handled in short_circuit

        elseif token.value == ".." then
          popAsync(stack, scope, line, false, 2, function(a,b)
            if a.type == "function" or b.type == "function" then
              error("attempt to concat "..a.type.." with "..b.type.." on line "..token.line)
            end

            local event
            if a.type == "table" then
              event = Loader.getMetaEvent( a, "__concat" )
            end
            if not event and b.type == "table" then
              event = Loader.getMetaEvent( b, "__concat" )
            end

            if event and event.type == "function" then
              Loader.callFunc( event, Loader._varargs( a, b ), function(result) --varargs result
                table.insert(stack, result.value)
              end)
            else
              table.insert(stack, val(a.value .. b.value))
            end
          end)

        elseif token.value == "," then
          popAsync(stack, scope, line, true, 2, function(a,b)
            if a.varargs and b.varargs then
              local aN = a.len or 1
              local bN = b.len or 1
              
              for i=aN + 1, math.max(#a.varargs, aN + #b.varargs) do
                a.varargs[i] = b.varargs[ i - aN ]
              end
              a.len = aN + bN
              table.insert(stack, a)
            elseif a.varargs then
              a.len = (a.len or 1) + 1
              for i = a.len, #a.varargs do
                a.varargs[i] = nil
              end
              table.insert(a.varargs, b)
              table.insert(stack, a)
            elseif b.varargs then
              table.insert(b.varargs, 1, a)
              b.value = a
              b.len = (b.len or 1) + 1
              table.insert( stack, b )
            else
              local vargs = Loader._varargs(a, b)
              vargs.len = 2 --, ops used + 1
              table.insert( stack, vargs )
            end
          end)

        elseif token.value == "%" then
          popAsync(stack, scope, line, false, 2, function(a,b)
            if a.type == "function" or b.type == "function" then
              error("attempt to preform modulo on "..a.type.." with "..b.type.." on line "..token.line)
            end
            local event
            if a.type == "table" then
              event = Loader.getMetaEvent( a, "__mod" )
            end
            if not event and b.type == "table" then
              event = Loader.getMetaEvent( b, "__mod" )
            end

            if event and event.type == "function" then
              Loader.callFunc( event, Loader._varargs( a, b ), function(result) --varargs result
                table.insert(stack, result.value)
              end)
            else
              table.insert(stack, val(a.value % b.value))
            end
          end)

        elseif token.value == "-unm" then --token cleanup does some of this already
          popAsync(stack, scope, line, false, 1, function(a)
            if a.type == "function" then
              error("can't do unary minus on a function")
            end

            if a.type == "table" then
              local event = Loader.getMetaEvent( a, "__unm" )
              if event and event.type == "function" then
                Loader.callFunc( event, Loader._varargs( a ), function( result ) --varargs
                  table.insert(stack, result.value )
                end)
              end
            else
              table.insert(stack, val(-a.value))
            end
          end)
        
        elseif token.value == "~ubn" then --token cleanup does some of this already
          popAsync(stack, scope, line, false, 1, function(a)
            if a.type == "function" then
              error("can't do unary minus on a function")
            end

            if a.type == "table" then
              local event = Loader.getMetaEvent( a, "__bnot" )
              if event and event.type == "function" then
                Loader.callFunc( event, Loader._varargs( a ), function( result ) --varargs
                  table.insert(stack, result.value )
                end)
              end
            else
              table.insert(stack, val(bit32.bnot(a.value)))
            end
          end)
        
        elseif token.value == "&" then
          popAsync(stack, scope, line, false, 2, function(a,b)
            if a.type == "function" or b.type == "function" then
              error("attempt to add "..a.type.." with "..b.type.." on line "..token.line)
            end

            local event
            if a.type == "table" then
              event = Loader.getMetaEvent( a, "__band" )
            end
            if not event and b.type == "table" then
              event = Loader.getMetaEvent( b, "__band" )
            end

            if event and event.type == "function" then
              Loader.callFunc( event, Loader._varargs( a, b ), function(result) --varargs result
                table.insert(stack, result.value)
              end)
            else
              table.insert(stack, val(bit32.band(a.value,b.value)))
            end
          end)
        
        elseif token.value == "|" then
          popAsync(stack, scope, line, false, 2, function(a,b)
            if a.type == "function" or b.type == "function" then
              error("attempt to add "..a.type.." with "..b.type.." on line "..token.line)
            end

            local event
            if a.type == "table" then
              event = Loader.getMetaEvent( a, "__bor" )
            end
            if not event and b.type == "table" then
              event = Loader.getMetaEvent( b, "__bor" )
            end

            if event and event.type == "function" then
              Loader.callFunc( event, Loader._varargs( a, b ), function(result) --varargs result
                table.insert(stack, result.value)
              end)
            else
              table.insert(stack, val(bit32.bor(a.value,b.value)))
            end
          end)
        
        elseif token.value == "~" then
          popAsync(stack, scope, line, false, 2, function(a,b)
            if a.type == "function" or b.type == "function" then
              error("attempt to add "..a.type.." with "..b.type.." on line "..token.line)
            end

            local event
            if a.type == "table" then
              event = Loader.getMetaEvent( a, "__bxor" )
            end
            if not event and b.type == "table" then
              event = Loader.getMetaEvent( b, "__bxor" )
            end

            if event and event.type == "function" then
              Loader.callFunc( event, Loader._varargs( a, b ), function(result) --varargs result
                table.insert(stack, result.value)
              end)
            else
              table.insert(stack, val(bit32.bxor(a.value, b.value)))
            end
          end)

        elseif token.value == ">>" then --logical shift
          popAsync(stack, scope, line, false, 2, function(a,b)
            if a.type == "function" or b.type == "function" then
              error("attempt to add "..a.type.." with "..b.type.." on line "..token.line)
            end

            local event
            if a.type == "table" then
              event = Loader.getMetaEvent( a, "__shr" )
            end
            if not event and b.type == "table" then
              event = Loader.getMetaEvent( b, "__shr" )
            end

            if event and event.type == "function" then
              Loader.callFunc( event, Loader._varargs( a, b ), function(result) --varargs result
                table.insert(stack, result.value)
              end)
            else
              table.insert(stack, val(bit32.rshift(a.value, b.value)))
            end
          end)

        elseif token.value == ">>>" then --logical shift
          popAsync(stack, scope, line, false, 2, function(a,b)
            if a.type == "function" or b.type == "function" then
              error("attempt to add "..a.type.." with "..b.type.." on line "..token.line)
            end

            local event
            if a.type == "table" then
              event = Loader.getMetaEvent( a, "__ashr" )
            end
            if not event and b.type == "table" then
              event = Loader.getMetaEvent( b, "__ashr" )
            end

            if event and event.type == "function" then
              Loader.callFunc( event, Loader._varargs( a, b ), function(result) --varargs result
                table.insert(stack, result.value)
              end)
            else
              table.insert(stack, val(bit32.arshift(a.value, b.value)))
            end
          end)
        
        elseif token.value == "<<" then --logical shift
          popAsync(stack, scope, line, false, 2, function(a,b)
            if a.type == "function" or b.type == "function" then
              error("attempt to add "..a.type.." with "..b.type.." on line "..token.line)
            end

            local event
            if a.type == "table" then
              event = Loader.getMetaEvent( a, "__shl" )
            end
            if not event and b.type == "table" then
              event = Loader.getMetaEvent( b, "__shl" )
            end

            if event and event.type == "function" then
              Loader.callFunc( event, Loader._varargs( a, b ), function(result) --varargs result
                table.insert(stack, result.value)
              end)
            else
              table.insert(stack, val(bit32.lshift(a.value, b.value)))
            end
          end)
        -- elseif token.value == "" then
        else
          error("Unhandled token "..token.value)
        end
      elseif token.value == "..." then --not op
        table.insert(stack, scope:getVarargs())
      elseif token.value == "{" and token.init then
        Async.insertTasks({
          label = "eval-table-init-results",
          func = function( var )
            table.insert(stack, var)
            return true --task complete
          end
        })
        Loader._initalizeTable( token, scope, line )
      elseif token.type == "keyword" and token.op == "function" then
          local locals = scope:captureLocals()
          local fenv = Scope:new("fenv: "..token.name, token.line, scope, index, locals)
          local fval = {
            env = fenv,
            instructions = token.instructions,
            line = token.line,
            args = token.args,
            type = "function"
        }
        table.insert(stack, fval)
      else
        table.insert(stack, token)
      end
    end, ipairs, postfix),
    {
      label = "eval-expand-varargs",
      func = function()
        --var -> value
        for i=1, #stack do
          if stack[i].type == "var" then
            stack[i] = scope:get( stack[i].value )
          end
        end
        
        for i=1, #stack-1 do
          stack[i].varargs = nil
        end

        if #stack > 0 and stack[#stack].varargs then
          local varargs = table.remove(stack).varargs
          for i=1,#varargs do
            table.insert(stack, varargs[i])
          end
        end
        return {stack} --return stack
      end
    }
  )
end

function Loader.PACKER( results )
  for i=1, #results do
    results[i] = Loader._val(results[i])
  end
  return results
end

function Loader.UNPACKER( fArgs )
  for i=1, #fArgs do
    fArgs[i] = fArgs[i].value
  end
  return fArgs
end


function Scope:new(name, line, parent, index, env)
  local obj = {
    env = env or {},
    index = index,
    name = name.."-"..line,
    parent = parent,
    ifState = false, --false, no block has run yet, true, a block has run
    isLoop = false,
    varargs = nil,
  }
  self.__index = self
  setmetatable(obj, self)
  return obj
end

function Scope:fromTableValue(tableValue, scopeName, line, index )
  local obj = {
    tableValue = tableValue,
    index = index or 1,
    name = scopeName.."-"..line,
    --parent = nil,
    ifState = false,
    isLoop = false,
  }
  self.__index = self
  return setmetatable(obj, self)
end

function Scope:getIndex()
  return self.index or self.parent and self.parent:getIndex()
end

function Scope:set(isLocal, name, value)
  if self.tableValue then
    error("Scope based on table value, must be async", 2)
  end
  if isLocal or self.env[name] or not self.parent then
    self.env[name] = value
  else
    self.parent:set(isLocal, name, value)
  end
end

--internal use
function Scope:setVarargs( varargs )
  if varargs == nil or varargs.varargs then
    self.varargs = varargs
  else
    error("Expected varagrs or nil",2)
  end
end

function Scope:getVarargs()
  if self.varargs then
    return self.varargs
  end
  if self.parent then
    return self.parent:getVarargs()
  end
  return Loader.constants["nil"]
end

--name must be unwraped type
function Scope:setAsync(isLocal, name, value)
  return Async.insertTasks(
    {
      label = "Scope:setAsync",
      func = function()
        if self.env then
          if isLocal or self.env[name] or not self.parent then
            self.env[name] = value
          else
            self.parent:setAsync(isLocal, name, value)
          end
        else
          name = Loader._val(name)
          if isLocal or Loader.indexTable( self.tableValue, name ).type~="nil" or not self.parent then
            Loader.assignToTableWithEvents( self.tableValue, name, value)
          else
            self.parent:setAsync(isLocal, name, value)
          end
        end
        return true
      end
    }
  )
end

function Scope:makeNativeFunc( name, func, unpacker, packer )
  return {
    type = "function",
    unpacker = unpacker ~= false and (unpacker or Loader.UNPACKER) or false,
    packer = packer ~= false and (packer or Loader.PACKER) or false,
    value = func,
    name = name
  }
end

function Scope:setNativeFunc( name, func, unpacker, packer )
  self:set(false, name, self:makeNativeFunc( name, func, unpacker, packer ))
end

--only usable with plain scopes, not with `fromTableValue` scopes due to metaevents and possible function calls
function Scope:get(name)
  if self.tableValue then error("Scope based on table value, must be async", 2) end
  if self.env[name] then
    return self.env[name]
  end
  if self.parent then
    return self.parent:get(name)
  end
  return Loader.constants["nil"]
end

--name must be unwraped type
function Scope:getAsync(name)
  return Async.insertTasks(
    {
      label = "Scope:getAsync",
      func = function()
        if self.env then
          if self.env[name] then
            return {self.env[name]}
          end
        else
          name = Loader._val(name)
          if Loader.indexTable( self.tableValue, name ) then
            Loader.indexTableWithEvents( self.tableValue, name, function( value )
              Async.insertTasks(
                {
                  label = "Scope:getAsync-callback return",
                  func = function()
                    return {value}
                  end
                }
              )
            end )
          end
        end
        return true
      end
    },{
      label = "Scope:getAsync-pass or parent",
      func = function(value)
        if value then
          return {value}
        end
        if self.parent then
          self.parent:getAsync(name)
        end
        return true
      end
    },{
      label = "Scope:getAsync-pass or nil",
      func = function(value)
        if value then
          return {value}
        end
        return {Loader.constants["nil"]}
      end
    }
  )
end

function Scope:getRootScope()
  local s = self
  while s.parent do
    s =  s.parent
  end
  return s
end

function Scope:captureLocals(fenv)
  local fenv = fenv or {}
  if not self.parent then return fenv end --don't capture globals
  if self.env then
    for k,v in pairs( self.env ) do
      if not fenv[k] then
        fenv[k] = v
      end
    end
  else
    for k,v in pairs( self.tableValue ) do
      if not fenv[k.value] then
        fenv[k.value] = v
      end
    end
  end
  return self.parent:captureLocals( fenv )
end

function Scope:addPlasmaGlobals()
  self:setNativeFunc( "output",     output      )
  self:setNativeFunc( "trigger",    trigger     )
  self:setNativeFunc( "read_var",   read_var    )
  self:setNativeFunc( "write_var",  write_var   )
  self:setNativeFunc( "require",    Net.require, nil, function( results )
    return results.varargs
  end ) --use default unpacker, do not use packer (run returns varargs)
end

function Scope:setPlasmaInputs()
  self:set(false, "V1", V1) -- V1-V8 isn't in _G
  self:set(false, "V2", V2)
  self:set(false, "V3", V3)
  self:set(false, "V4", V4)
  self:set(false, "V5", V5)
  self:set(false, "V6", V6)
  self:set(false, "V7", V7)
  self:set(false, "V8", V8)
end

function Scope:addGlobals()
  self:setNativeFunc( "next",     next )
  self:setNativeFunc( "print",    print )
  self:setNativeFunc( "tonumber", function( x )
    return tonumber( x )
  end )
  self:setNativeFunc( "error", function( msg, lvl )
    error( "Error on line line "..Async.getLine()..": "..tostring(msg.value), (lvl and lvl.value + 1) or 2)
  end, false, false)
  --tostring(table.unpack{nil}) is an error
  --tostring( nil ) is not...
  self:setNativeFunc( "tostring", function( x )
    if x.type == "table" then
      local event = Loader.getMetaEvent( x, "__tostring" )
      if event and event.type == "function" then
        Loader.callFunc( event, x, function( str ) --varargs result
          Async.insertTasks(Async.RETURN("tostring metaevent result", {str.value} ))
        end)
      elseif event and event.type == "str" then
        return event
      else
        return Loader._val(tostring( x.value ))
      end
    end
    return Loader._val(tostring( x.value ))
  end, false, false )

  self:setNativeFunc( "ipairs",   function(tbl)
    if tbl.type ~= "table" then
      error("expected table for ipairs, got "..tbl.type)
    end
    local event = Loader.getMetaEvent( tbl, "__ipairs" )
    if event and event.type == "function" then
      Loader.callFunc( event, Loader._varargs( tbl ), function( results )
        Async.insertTasks(Async.RETURN("__ipairs result", results.varargs))
      end)
    else
      local indexer = Loader.getTableIndex( tbl )
      local gen, _, start = ipairs(indexer)
      local wrapGen = Loader._val(function(tbl, index, ...)
        local nextIndex, nextWrappedIndex = gen( indexer, index )
        return nextWrappedIndex, tbl[nextWrappedIndex]
      end)
      wrapGen.unpacker = Loader.UNPACKER
      return wrapGen, tbl, Loader._val(start)
    end
  end, false, false )

  self:setNativeFunc( "pairs", function( tbl )
    if tbl.type ~= "table" then
      error("expected table for pairs, got "..tbl.type)
    end
    local event = Loader.getMetaEvent( tbl, "__pairs" )
    if event and event.type == "function" then
      Loader.callFunc( event, Loader._varargs( tbl ), function( results )
        Async.insertTasks(Async.RETURN("__pairs result", results.varargs))
      end)
    else
      local indexer = Loader.getTableIndex( tbl )
      local gen, _, start = pairs(indexer)
      local wrapGen = Loader._val(function(tbl, index, ...)
        local nextIndex, nextWrappedIndex = gen( indexer, index )
        return nextWrappedIndex, tbl[nextWrappedIndex]
      end)
      wrapGen.unpacker = Loader.UNPACKER
      return wrapGen, tbl, Loader._val(start)
    end
  end, false, false )

  self:setNativeFunc( "type", function( value ) return value.type end, false, nil )
  self:setNativeFunc( "getmetatable", Loader.getmetatable, false, false )
  self:setNativeFunc( "setmetatable", Loader.setmetatable, false, false )
  self:setNativeFunc( "rawset", Loader.assignToTable, false, false )
  self:setNativeFunc( "rawget", Loader.indexTable, false, false )
  self:setNativeFunc( "load", function(src, blockName, mode, env)
    src = src.value
    blockName = blockName and blockName.value or "[?]"
    mode = mode and mode.value or "t"
    if mode ~= "t" then
      error("load with mode '"..mode.."' is not supported, use 't' or nil")
    end
    local scope
    local line = Async.getLine()
    if env then
      scope = Scope:fromTableValue( env, blockName, line, 1 )
    else
      scope = self:getRootScope()
    end
    Loader.load(src, scope, blockName, line) --async return
  end, false, function( fVal ) return { Loader._varargs(fVal) } end)

  ---------------------------------------------------------
  -- math
  ---------------------------------------------------------
  local mathModule = Loader.newTable()
  for name, func in pairs( math ) do
    if type(func) == "function" then
      local nf = self:makeNativeFunc( name, func )
      Loader.assignToTable( mathModule, Loader._val(name), nf )
    else
      Loader.assignToTable( mathModule, Loader._val(name), Loader._val(func)) --pi, e, huge...
    end
  end
  self:set(false, "math", mathModule)
  
  ---------------------------------------------------------
  -- string
  ---------------------------------------------------------
  local strModule = Loader.newTable()
  for name, func in pairs( string ) do
    local nf = self:makeNativeFunc( name, func )
    Loader.assignToTable( strModule, Loader._val(name), nf )
  end
  self:set(false, "string", strModule)
  ---------------------------------------------------------
  -- table
  ---------------------------------------------------------
  local tblModule = Loader.newTable()
  
  Loader.assignToTable( tblModule, Loader._val("remove"), self:makeNativeFunc("remove",function(tbl, index)
    local indexer = Loader.tableIndexes[ tbl.value ]
    if not indexer then
      error("internal error, missing table index durring remove operation")
    end
    local k = indexer[index.value]
    if not k then
      return Loader.constants["nil"]
    end
    local r = tbl.value[k]
    tbl.value[k] = nil
    table.remove(indexer, index.value)
    return r
  end, false, false) )
  
  Loader.assignToTable( tblModule, Loader._val("pack"), self:makeNativeFunc( "pack", function(...)
    local out = Loader.newTable()
    for i, v in ipairs{...} do
      Loader.assignToTable( out, Loader._val(i), v )
    end
    Loader.assignToTable( out, Loader._val"n", Loader._val(select("#",...)))
    return out
  end, false, false ))
  
  Loader.assignToTable( tblModule, Loader._val("concat"), self:makeNativeFunc( "concat", function(tbl, joiner, i, j)
    local unpacked = {}
    local indexer = Loader.tableIndexes[tbl.value]
    i = i and i.value or 1
    j = j and j.value or #indexer
    if not indexer then error("internal error, missing table index durring table.concat opperation") end
    for I = i, math.min(j,#indexer) do
      unpacked[I-i+1] = tbl.value[ indexer[I] ].value
    end
    return Loader._val( table.concat(unpacked, joiner and joiner.value) )
  end, false, false ))
  
  Loader.assignToTable( tblModule, Loader._val("sort"), self:makeNativeFunc("sort", function(tbl, aIsBeforeB)
    Loader._heapSort( tbl, aIsBeforeB )
  end, false, false ))

  Loader.assignToTable( tblModule, Loader._val("insert"), self:makeNativeFunc("insert", function(tbl, x, y)
    local indexer = Loader.tableIndexes[tbl.value]
    local N = #indexer
    if y then
      if N > 0 then
        Loader.assignToTable(tbl, Loader._val(N+1), tbl.value[indexer[N]])
      end
      for i=N-1, x.value, -1 do
        local targetKey = indexer[i]
        local sourceKey = indexer[i-1]
        if sourceKey then
          tbl.value[targetKey] = tbl.value[sourceKey]
        end
      end 
      tbl.value[indexer[x.value]] = y
    else
      Loader.assignToTable(tbl, Loader._val(N+1), x)
    end
  end, false, false))

  Loader.assignToTable( tblModule, Loader._val("unpack"), self:makeNativeFunc("unpack", function (tbl, i, j)
    local indexer = Loader.tableIndexes[tbl.value]
    i = i and i.value or 1
    j = j and j.value or #indexer
    local values = {}
    for index=i, j, i<j and 1 or -1 do
      table.insert( values, tbl.value[ indexer[index] ] )
    end
    return table.unpack(values)
  end, false, false))
  
  self:set(false, "table", tblModule)

  ---------------------------------------------------------
  -- bit32
  ---------------------------------------------------------
  local bitModule = Loader.newTable()
  for name, func in pairs(bit32) do
    Loader.assignToTable( bitModule, Loader._val(name), self:makeNativeFunc(name, func))
  end
  self:set(false, "bit32", bitModule)

  ---------------------------------------------------------
  -- coroutine
  ---------------------------------------------------------
  local coroutineModule = Loader.newTable()
  Loader.assignToTable( coroutineModule, Loader._val("create"), self:makeNativeFunc("create", function( sFunc )
    if sFunc.type ~= "function" then
      error("arg 1 must be of type function for coroutine.create, got "..(sFunc.type))
    end
    local originalThread = Async.activeThread
    local id = Async.newThread()
    Async.pushAndSetThread( id )
    Async.insertTasks(
      {
        label = "coroutine-create", func = function( ... ) --receives from `resume` call
          Loader.callFunc( sFunc, Loader._varargs(...), function( result )
            if result then
              Async.insertTasks( Async.RETURN( "create-return to resume", result.varargs ) ) --pass to resume
            else
              Async.insertTasks( Async.RETURN( "create-return to resume") ) --pass to resume
            end
          end)
          return true -- task done
        end
      }
    )
    local endOfThread = Async.threads[id][#Async.threads[id]]
    endOfThread.label = "__endOfThread"
    endOfThread.func = function(...)
      Async.popThread()
      
      return {...}
    end
    Async.popThread()
    return Loader._val( id, "thread" )
  end, false, false))

  Loader.assignToTable( coroutineModule, Loader._val("resume"), self:makeNativeFunc("resume", function( threadID, ... )
    if threadID.type ~= "thread" then
      error("Expected thread for arg 1 of coroutine.resume, got "..threadID.type)
    end

    local status = Async.threadStatus( threadID.value )
    if status == "dead" then
      return Loader._val(false), Loader._val( "cannot resume dead coroutine" )
    end
    
    Async.pushAndSetThread( threadID.value )
    Async.insertTasks( --in thread's tasks
      Async.RETURN( "resume-pass args", ... ) --pass args to coroutine
    )
  end, false, false))

  Loader.assignToTable( coroutineModule, Loader._val("yield"), self:makeNativeFunc("yield", function(...) --stuff to pass to resume
    if Async.activeThread == 1 then
      error("Can't yield on main thread!")
    end
    Async.popThread()
    Async.insertTasks( --in caller of resume's thread
      Async.RETURN( "yield-return values", {...} ) --stack of values 
    )
  end, false, false))

  Loader.assignToTable( coroutineModule, Loader._val("status"), self:makeNativeFunc("status", function(threadID) --stuff to pass to resume
    if threadID.type ~= "thread" then
      error("Expected thread for arg 1 of coroutine.resume, got "..threadID.type)
    end
    return Async.threadStatus( threadID.value  )
  end, false, nil))

  Loader.assignToTable( coroutineModule, Loader._val("running"), self:makeNativeFunc("running", function() --stuff to pass to resume
    return Loader._val( Async.activeThread, "thread" ), Loader._val( Async.activeThread == 1 )
  end, false, false))

  Loader.assignToTable( coroutineModule, Loader._val("wrap"), self:makeNativeFunc("wrap", function() --stuff to pass to resume
    error("feature requires metatables to be implemented!") --TODO
  end, false, false))

  self:set(false, "coroutine", coroutineModule)
  -- self:setNativeFunc( "",  )
end

--proxy for scripts
function Scope:getTableValue()
  if self.tableValue then return self.tableValue end
  local t = {}
  local m = {
    __index = function(t,k)
      self:get( k.value )
    end
  }
  return Loader._val(setmetatable(t, m))
end



function Loader.load( str, scope, envName, line )
  --TODO
  local inst
  Async.insertTasks(
    {
      label = "Loader.load - tokenize",
      func = function()
        Loader.tokenize(str)
        return true
      end
    },{
      label = "Loader.load - cleanupTokens",
      func = function(rawTokens)
        Loader.cleanupTokens(rawTokens)
        return true
      end
    },{
      label = "Loader.load - buildInstructions",
      func = function(tokens)
        Loader.buildInstructions(tokens)
        return true
      end
    },{
      label = "Loader.load - batchPostfix",
      func = function(instructions)
        inst = instructions
        Loader.batchPostfix(instructions)
        return true
      end
    },{
      label = "Loader.load - wrap instructions",
      func = function()
        local fval = {
          env = scope,
          instructions = inst,
          line = line,
          args = {"..."},
          name = envName,
          type = "function"
        }

        return{fval}
      end
    }
  )
end
------------------
--Heap sort
--i is current tree node
--left/right is child nodes
------------------
function Loader._heapSort(tbl, aIsBeforeB)
  local heapify
  local buildMaxHeap

  local indexer = Loader.tableIndexes[tbl.value]
  local N = #indexer

  local function swap(i, j)
    tbl.value[indexer[i]], tbl.value[indexer[j]] = tbl.value[indexer[j]], tbl.value[indexer[i]]
  end

  function buildMaxHeap( n )
    local start = math.floor(n / 2) 
    Async.insertTasks(
      --for i=floor(n/2) -> 1
      --  heapify( tbl, i )
      Async.forEach("sort-buildMaxHeap", function( i )
        heapify( i, n )
      end, Async.range, start, 1, -1 )
    )
  end

  function heapify( i, n )
    local left = 2 * i
    local right = left + 1
    local max = i

    -- if( left <= n ) && [left] > [i]
    --   max = left
    -- else
    --   max = i
    -- end
    -- if right <=n && [right] > [max]
    --   max = right

    -- if max ~= i 
    --   swap (i, max)
    --   heapify( max )
    Async.insertTasks(
      { 
        label = "sort-checkLeft", func = function()
          if left <= n then
            local args = Loader._varargs( tbl.value[indexer[max]], tbl.value[indexer[left]] ) --must do >, so swapped
            Loader.callFunc( aIsBeforeB, args, function(result)
              if result.value.value then
                max = left
              end
            end)
          end
          return true --task complete
        end
      },{
        label = "sort-checkRight", func = function()
          if right <= n then
            local args = Loader._varargs( tbl.value[indexer[max]], tbl.value[indexer[right]] ) --must do >, so swapped
            Loader.callFunc( aIsBeforeB, args, function(result)
              if result.value.value then
                max = right
              end
            end)
          end
          return true --task complete
        end
      },{
        label = "sort-swap", func = function()
          if max ~= i then
            swap( i, max )
            heapify( max, n )
          end
          return true
        end
      }
    )
  end

  --sort main
  
  Async.insertTasks(
    {
      label = "sort-init-buildMaxHeap", func = function()
        buildMaxHeap( N )
        return true
      end
    },
    Async.forEach("sort-main", function(i)
        swap( 1, i )
        heapify( 1, i - 1 )
    end, Async.range, N, 1, -1),
    Async.RETURN("sort result", tbl)
  )
end
------------------
--End Heap sort
------------------


--index may be nil
function Loader._appendCallEnv( callStack, name, line, index, env )
  local scope = Scope:new( name, line, callStack[#callStack], index, env)
  table.insert(callStack, scope )
end

function Loader._getTableAssignmentTargets(vars, top)
  local targets = {}
  return {
    label = "Loader._getTableAssignmentTargets - setup",
    func = function()
      Async.insertTasks(
        Async.forEach("Loader._getTableAssignmentTargets", 
          function(i,var)
            local tmp = {}
            for x in var.value:gmatch"[^.]+" do
              table.insert(tmp, x)
            end

            if #tmp == 1 then
              table.insert(targets,{
                place = "scope",
                name = tmp[1]
              })
            else
              local tmpPostfix = {}
              for i=1, #tmp-1 do
                table.insert(tmpPostfix,{
                  type = "var",
                  line = var.line,
                  value = tmp[i],
                  blockLevel = var.blockLevel
                })
              end
              for i=1, #tmp-2 do
                table.insert(tmpPostfix,{
                  type = "op",
                  line = var.line,
                  value = ".",
                  blockLevel = var.blockLevel
                })
              end
              Async.insertTasks(
                {
                  label = "Loader._getTableAssignmentTargets - eval",
                  func = function()
                    Loader.eval( tmpPostfix, top, var.line )
                    return true
                  end
                },{
                  label = "Loader._getTableAssignmentTargets - eval result",
                  func = function( results )
                    table.insert(targets,{
                      place = results[1], 
                      name = tmp[#tmp]
                    })
                    return true
                  end
                }
              )
            end
          end, ipairs, vars
        ), 
        Async.RETURN("Loader._getTableAssignemnetTargets - return",targets)
      )
      return true
    end
  }
  
end

function Loader.execute( instructions, env, ... )
  local callStack = {
  }
  if not env then
    Loader._appendCallEnv( callStack, "MAIN_CHUNK", 1, 1 )
    callStack[1]:addGlobals()
  else
    callStack[1] = env
  end
  -- callStack[1].env = env or callStack[1].env
  local prgmArgs = {
    type="varargs",
    weak = true, -- ..., 10 | 10 is not appended, first value from ... used
    value = ...,
    varargs = {...}
  }
  
  local index = 1
  return Async.insertTasks(
    {
      label = "Loader.execute - setup",
      func = function()
        callStack[1]:setAsync("...", prgmArgs)
        return true
      end
    },
    Async.whileLoop("exec", function () return instructions[index] end, function ()
      local inst = instructions[index]
      local top = callStack[#callStack]
      if inst.line then Async.setLine( inst.line ) end
      -- print("                       DEBUG: "..inst.line..": "..inst.op.."["..#callStack.."]")
      if inst.op == "assign" then
        -- local instruction = {
        --   op = "assign",
        --   vars = token.value,
        --   infix = { eval = infix },
        --   isLocal = localVar,
        --   index = #instructions+1
        -- }

        local targets
        Async.insertTasks(
          Loader._getTableAssignmentTargets(inst.vars, top)
          ,{
            label = "Execute - assign - call eval",
            func = function(_targets)
              targets = _targets
              Loader.eval( inst.postfix.eval, top, inst.line ) --inserts new task
              return true --this task complete
            end
          },{
            label = "assignment eval results",
            func = function( stack )
              for i=1, #targets do
                local target = targets[i]
                if target.place == "scope" then
                  top:set(inst.isLocal, target.name, stack[i] or Loader.constants["nil"] )
                else
                  local nameVal = Loader._val(target.name)
                  Loader.assignToTableWithEvents( target.place, nameVal, stack[i] )
                end
              end
              return true
            end
          }
        )
        
      elseif inst.op == "eval" then
        --inserts task
        Loader.eval( inst.postfix.eval, top, inst.line )

      elseif inst.op == "return" then
        Async.insertTasks({
          label = "return eval results",
          func = function( stack )
            return { Loader._varargs(table.unpack(stack)) }
          end
        })
        --inserts task
        Loader.eval( inst.postfix.eval, top, inst.line )
        return true --exit, return values from task passed
      elseif inst.op == "function" then --capture locals & add to env
        local locals = callStack[#callStack]:captureLocals()

        Async.insertTasks(
          Loader._getTableAssignmentTargets({Loader._val(inst.name)}, top),
          {
            label = "Execute - function",
            func = function( targets )
              local fenv = Scope:new("fenv: "..inst.name, inst.line, top, index, locals)
              local fval = {
                env = fenv,
                instructions = inst.instructions,
                line = inst.line,
                args = inst.args,
                name = targets[1].name,
                type = "function"
              }

              local isLocal = inst.isLocal
              local target = targets[1]
              if target.place == "scope" then
                top:setAsync( inst.isLocal, target.name, fval )
              else
                local nameVal = Loader._val(target.name)
                target.place.value[nameVal] = fval
                Loader.tableIndexes[target.place.value][target.name] = nameVal
              end
              return true
            end
          }
        )

        
      elseif inst.op == "if" then
        Async.insertTasks({
          label = "if condition results",
          func = function( stack )
            local value = (stack[1] or Loader.constants["nil"]).value
            top.ifState = value
            if not value then
              index = inst.skip.index
            else
              index = index + 1
            end
            return true --task complete
          end
        })

        --inserts task
        Loader.eval( inst.postfix.condition, top, inst.line )
        return --continue
      elseif inst.op == "elseif" then
        if top.ifState then
          index = inst.skip.index
          return --continue
        else --no block run yet
          Async.insertTasks({
            label = "elseif results",
            func = function( stack )
              local value = (stack[1] or Loader.constants["nil"]).value
              top.ifState = value
              if not value then
                index = inst.skip.index
              end
              return true --task complete
            end
          })
          
          --inserts task
          Loader.eval( inst.postfix.condition, top, inst.line )
        end
      elseif inst.op == "else" then
        if top.ifState then
          index = inst.skip.index
          return --continue
        end
      elseif inst.op == "end" then
        local loop = inst.start

        if loop and loop.op == "for" then --initalized with an assign, incremented on end
          local var = top:get(inst.start.var.value).value
          local inc = top:get"$increment".value
          top:set(true, inst.start.var.value, Loader._val(var + inc))
      
          index = inst.start.index
          return --continue

        elseif loop and loop.op == "for-in" then
          index = inst.start.index
          return --continue
        elseif loop and loop.op == "while" then
          index = inst.start.index --loop false -> end.index+1
          return --continue
        end
      elseif inst.op == "break" then
      elseif inst.op == "while" then
        top.isLoop = true
        top.start = inst
        top.stop = inst.skip

        Async.insertTasks({
          label = "assignment eval results",
          func = function( stack )
            local value = (stack[1] or Loader.constants["nil"]).value
            if not value then
              index = inst.skip.index + 1 -- skip end instruction which sends back to this instruction
            end
          end
        })

        --inserts task
        Loader.eval( inst.postfix.condition, top, inst.line )
        return --continue
      elseif inst.op == "for" then
        top.isLoop = true
        top.stop = inst.skip

        local inc = top:get"$increment".value
        local limit = top:get"$limit".value
        local var = top:get(inst.var.value).value
        if (inc > 0 and limit >= var)
        or (inc < 0 and limit <= var) then
          index = index + 1
        else
          index = inst.skip.index+1 --past end to exit loop
        end
        return --continue

      
      elseif inst.op == "for-in-init" then
        Async.insertTasks({
          label = "for-in-init-result",
          func = function( stack )
            top.generator = stack[1]
            top.previousFor = Loader._varargs( table.unpack(stack,2) )
            return true --task complete
          end
        })
        Loader.eval( inst.postfix.eval, top, inst.line )
      elseif inst.op == "for-in" then
        top.isLoop = true
        top.start = inst
        top.stop = inst.skip

        local gen = top.generator
        if (not gen) or gen.type ~= "function" then
          error("generator must be function for `for-in` loop on line"..inst.line)
        end

        Loader.callFunc( gen, Loader._varargs(table.unpack(top.previousFor.varargs)), function ( genVals )
          -- top.previousFor = genVals
          if #genVals.varargs == 0 then
            index = inst.skip.index + 1
            return --just a regular callback, task done
          else
            index = index + 1
          end
          for i=1, #inst.vars.value do
            top.previousFor.varargs[i+1]  = genVals.varargs[i] 
            top:set(true, inst.vars.value[i].value, genVals.varargs[i])
          end
        end)
        return --continue
      elseif inst.op == "until" then
        Async.insertTasks({
          label = "until condition results",
          func = function( stack )
            local value = (stack[1] or Loader.constants["nil"]).value
            if value then --exit on true
              index = index + 1
            else
              index = inst.start.index
            end
            return true --task complete
          end
        })

        --inserts task
        Loader.eval( inst.postfix.condition, top, inst.line )
        return --continue
        
      elseif inst.op == "createScope" then
        Loader._appendCallEnv( callStack, "block start", inst.line, inst.index )
      elseif inst.op == "deleteScope" then
        table.remove(callStack)
      elseif inst.op == "do" then
        --nothing, marker
      else
        error("unhandled instruction '"..inst.op.."'")
      end

      index = index + 1
    end)
  )
end

--===================================================================================

function Net.require( path )
  --result handling
  Async.insertTasks(
    {
      label = "Net.require",
      func = function()
        if not Net.result then
          return false -- wait till next tick
        end
        Loader.run(Net.result) -- returns values
        return true --task complete
      end
    }
  )
  --network call
  Net.result = false
  path = "https://raw.githubusercontent.com/"..path..".lua"
  write_var(path, "url")
  output("require", 1)
end

function Net.sourceCode()
  Net.result = V1
end

--===================================================================================
--===================================================================================
--==============================        Plasma        ===============================
--===================================================================================
--===================================================================================
local Plasma = {}
------------------
--  interfaces  --
------------------
function Loader.run(src)
  src = src or V1
  if src then
    Async.insertTasks(
      {
        label = "run-tokenize",
        func = function()
          Loader.tokenize(src)
          return true
        end
      },{
        label = "run-tokenize->cleanup",
        func = function( rawTokens )
          Loader.cleanupTokens( rawTokens )
          return true
        end
      },{
        label = "run-cleanup->buildInstructions",
        func = function( tokens )
          Loader.buildInstructions(tokens)
          return true
        end
      },{
        label = "run-buildInstructions->...",
        func = function(instructions)
          Async.insertTasks(
            {
              label = "run-batchPostfix",
              func = function()
                Loader.batchPostfix(instructions)
                return true
              end
            },{
              label = "run-execute",
              func = function()
                Loader.execute(instructions, Plasma.scope)
                return true
              end
            }
          )
          return true
        end
      }
    )
  end
end
------------------
--     main     --
------------------
function setup()
  Plasma.scope = Scope:new("PLASMA",1,nil,1)
  Plasma.scope:addGlobals()
  Plasma.scope:addPlasmaGlobals()
end

function loop()
  Async.loop()
end

function is_done()
  return false
end


--===================================================================================
--===================================================================================
--===================================================================================
--===================================================================================
--===================================================================================
local function test()
  local testCode = [===[
    function foo(x, y)
      return x+y
    end

    local t = 15 / -2
    local z,e = foo(10, 20) or 100, 33
    print(z)
    if z%10 ==0 then
      print("%10!")
    elseif z%5==0 then
      print"foo"
    else
      print(foo(3,4)-1)
    end

    for i=1,3 do
      print( i )
    end

    local t = {1,2,3}
    print( "Len t:" .. #t )
    for k, v in ipairs( t ) do
      print("  ["..tostring(k).."] = "..tostring(v))
    end

    do
      local tmp = 10
      print("tmp in scope: "..tostring(tmp))
    end
    print("tmp out of scope: "..tostring(tmp))

    local r = 1
    do
      print( "r: "..r )
      r = r + 1
    until r > 6
    print"end of until"

    local inlineFunc = function(x)
      print( x )
    end

    print"inline set"

    inlineFunc("inline works")

    print[==[
      Multiline
      string!
    ]==]

    --print"comments"
    --[[
      print"block comments
    ]]
    --[==[
      print"long block comments"
    ]==]

    print"done"
  ]===]
  --TODO: local a,b,c declaring
  --TODO: local function

  local rawTokens = sync( Loader.tokenize(testCode) )
  local tokens = sync( Loader.cleanupTokens( rawTokens ) )
  local instructions = sync( Loader.buildInstructions(tokens)  )
  sync( Loader.batchPostfix(instructions) )
  sync( Loader.execute( instructions ) )
  -- local tokens = Loader.tokenize(testCode)
  print"done"
end



-- test()
return {
  Loader = Loader,
  Async = Async,
  Scope = Scope,
  Net = Net
}