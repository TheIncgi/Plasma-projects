--copied & modified from plasmaNN.lua

Async = {}

--async
local tasks = {}
Async.tasks = tasks
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
			error( "Invalid task result during sync ["..(t.label or "?").."]",2 )
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

local insertTasks = Async.insertTasks
local forEach = Async.forEach
local sync = Async.sync
local removeTask = Async.removeTask
local range = Async.range
local RETURN = Async.RETURN
--=====================================================================================

Loader = {}
Scope = {}

--[table][raw key] -> wrapped key
Loader.tableIndexes = {}
setmetatable( Loader.tableIndexes, {
  __mode = "k"
})

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
	str = { "'^[^'\n]+'$", '^"[^"\n]+"$' },
	num = { 
		int="^[0-9]+$", 
		float="^[0-9]*%.[0-9]*$",
		hex="^0x[0-9a-fA-F]+$",
		bin="^0b[01]+$"
	},
	var = { "^[a-zA-Z_][a-zA-Z0-9_]*$" },
	op = { "^[()%{%}%[%]%%.%!%#%^%*%/%+%-%=%~%&|;,%<%>]+$" }
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
	--not,len
  ["not"] = 8,
	-- ["!"] = 8,
	["#"] = 8,
	--math
	["^"] = 7, --exponent
	-- ["**"] = 6, --cross
	["/"] = 6,
	["*"] = 6,
	["%"] = 6, --mod
	["+"] = 5,
	["-"] = 5,
  [".."] = 4.5, --concat
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
	["^"] = true
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

      if tokenType == "num" then
        infoToken.value = tonumber(infoToken.value)

        if prior and prior.value == "-"
        and (twicePrior and twicePrior.type == "op" and (
          twicePrior.value ~= ")" and twicePrior.value ~= "}" and twicePrior.value ~= "]" ))
         or twicePrior == nil then
          table.remove(tokens, index-1)
          infoToken.value = -infoToken.value
          index = index-1
        end
      
      elseif tokenType == "op" or (tokenType=="keyword" and token == "in") then
        if (token == "=" or token == "in") and prior then
          local newToken = {
            type = "assignment-set",
            token = token,
            value = {prior},
            line = line
          }
          tokens[index-1] = newToken
          
          while twicePrior.type == "op" and twicePrior.value == "," do
            table.remove( tokens, index-2 ) -- ,
            local v = table.remove( tokens, index-3)
            index = index - 2
            table.insert(newToken.value, 1, v)
            twicePrior = tokens[index-2]
          end
          table.remove(tokens, index)
          return --continue
        elseif token == "(" or token == "{" then -- " doesn't"
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

      if token.value == "[" then
        local infix, nextIndex = Loader._collectExpression( tokens, index+1, false, token.line, true )
        key = infix
        if tokens[nextIndex].value ~= "=" then
          error("'=' expected in table near line "..token.line)
        end
        index = nextIndex +1
      elseif token.type == "var" and tokens[index+1] and tokens[index+1].value == "=" then
        key = {{type="str", value = token.value}}
        index = index + 2
      else
        N = N + 1
        key = {Loader._val(N)}
      end

      local infix, nextToken = Loader._collectExpression(tokens, index, false, tokens[index].line, true, true)
      local value = infix
      table.insert(tableInit, {line = line, infix = {key=key,value=value}})

      token = tokens[nextToken]

      if token.value ~= "," and token.value ~= "}" then
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
  }
  if tokens[start].type=="op"then
    if not startPermitted[tokens[start].value] then
      error("Can't start an expression with an op besides #, not, (, {, or [")
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
          return --continue into inserted tasks
        else          
          requiresValue = false
        end
      elseif token.type == "op" then
        if token.value == ")" or token.value == "}" or token.value == "]" then
          local topBracket = table.remove(brackets)
          if tableMode and token.value == "}" and not topBracket then
            return {index}
          end
          if token.value ~= Loader._closePar(topBracket.value) then
            error("Mis-matched brackets opening with "..topBracket.value.." on line "..topBracket.line.." and "..token.value.." on line"..token.line)
          end
          -- requiresValue = false again
        elseif token.call then
          if token.value == "{" or token.value == "(" or token.value=="[" then
            table.insert(brackets, token)
            if token.empty then
              requiresValue = false
            else
              requiresValue = true
            end
          end
        elseif startPermitted[token.value] then
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
  for i=index, endTokenPos-1 do
    table.insert(infix, tokens[i])
    tokens[i].globalIndex = i
    tokens[i].localIndex = #infix
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
          else
            table.insert(instruction, {op="createScope", line=token.line, index = #instructions+1}) 
            --scope used by any if/elseif/else, shared since only one can use it
            --scope also holds if state
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
          if #opStack == 0 then
            table.insert(opStack, token)
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
            if par.call then
              table.insert( out, par )
            end
          else
            if token.value ~= "(" and token.value ~= "[" and token.value ~="{" then
              if (Loader._ops[opStack[#opStack].value] > priority) 
              or (Loader._rightAssociate[token.value] and Loader._ops[opStack[#opStack].value] == priority) then
                table.insert(out, table.remove(opStack))
                while #opStack > 0 and (Loader._ops[opStack[#opStack].value] > priority)  do
                  table.insert(out, table.remove(opStack))
                end
              end
            end
            table.insert(opStack, token)
          end
        else
          table.insert( out, token )
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
  if not token then error("Error, empty stack from expression on line "..line) end
  local value = Loader._tokenValue( token, scope )
  if value.type == "varargs" and not keepVarargs then
    return value.value
  end
  return value
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
      func.unpacker( fArgs )
    end
    --call
    local results
    if #fArgs > 0 then
      results = {func.value( table.unpack(fArgs) )}
    else
      results = {func.value()}
    end
    if func.packer then
      func.packer( results )
    end
    result = Loader._varargs(table.unpack(results))
    callback( result )
    
  else
    for i=1,#func.args do
      func.env:set(true,func.args[i], fArgs[i] or Loader.constants["nil"])
    end
    Async.insertTasks({
      label = "callFunc-callback-return",
      func = function( result )
        callback( result )
        return true
      end
    })
    Loader.execute(func.instructions, func.env, table.unpack(fArgs))
  end
end

function Loader._initalizeTable( tableToken, scope, line )
  local newTable = {}
  local var = Loader._val(newTable)
  local indexer = {}
  Loader.tableIndexes[newTable] = indexer
  setmetatable(indexer, {
    __mode = "v"
  })
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
      label = "_initalizeTable-value-result",
      func = function(tKey)
        key = tKey[1]
        indexer[key.value] = key
        return true
      end
    })
    Loader.eval( entry.postfix.value, scope, line )

  end, ipairs, tableToken.init), 
  Async.RETURN("_initalizeTable", var))
end

function Loader.eval( postfix, scope, line )
  if not postfix then error("expected postfix",2) end
  local stack = {}
  local pop = Loader._popVal
  local val = Loader._val
  Async.insertTasks(
    Async.forEach("eval-postfix", function(index, token)
      if token.type == "op" then
        if token.call then
          local args =  pop(stack, scope, line, true)
          local func
          if (not args.instructions) and (not args.env) and (not token.empty) then
            func = pop(stack, scope, line)
          else
            func = args
            args = Loader._varargs()
          end
          
          Loader.callFunc( func, args, function( result )
            table.insert( stack, result )
          end)

        elseif token.value == "." then --TODO use b.name not [b]
          local b, a = pop(stack, scope, line), pop(stack, scope, line)
          if a.type ~= "table" then
            error("attempt to index "..a.type.." on line "..token.line)
          end
          local indexer = Loader.tableIndexes[a.value]
          if not indexer then
            error("internal error: missing table index from table on line "..token)
          else
            local k = indexer[b.value]
            table.insert(stack, val(a[b] or a[k]))
          end

        elseif token.value == "not" then
          local a = pop(stack, scope, line)
          if a.type == "function" then
            table.insert( stack,  Loader.constants["false"] )
            return --continue
          end
          table.insert(stack, val(not a.value))

        elseif token.value == "#" then
          local a = pop(stack, scope, line)
          if a.value == "function" then
            error("attempt to get the length of a function on line "..token.line)
          end
          table.insert(stack, val(#a.value))

        elseif token.value == "^" then
          local b, a = pop(stack, scope, line), pop(stack, scope, line)
          if a.type == "function" or b.type == "function" then
            error("attempt to preform exponent opperation with "..a.type.." and "..b.type.." on line "..token.line)
          end
          table.insert(stack, val(a.value^b.value))

        elseif token.value == "*" then
          local b, a = pop(stack, scope, line), pop(stack, scope, line)
          if a.type == "function" or b.type == "function" then
            error("attempt to multiply "..a.type.." with "..b.type.." on line "..token.line)
          end
          table.insert(stack, val(a.value*b.value))

        elseif token.value == "/" then
          local b, a = pop(stack, scope, line), pop(stack, scope, line)
          if a.type == "function" or b.type == "function" then
            error("attempt to divide "..a.type.." with "..b.type.." on line "..token.line)
          end
          table.insert(stack, val(a.value/b.value))

        elseif token.value == "+" then
          local b, a = pop(stack, scope, line), pop(stack, scope, line)
          if a.type == "function" or b.type == "function" then
            error("attempt to add "..a.type.." with "..b.type.." on line "..token.line)
          end
          table.insert(stack, val(a.value+b.value))

        elseif token.value == "-" then
          local b, a = pop(stack, scope, line), pop(stack, scope, line)
          if a.type == "function" or b.type == "function" then
            error("attempt to subtract "..a.type.." from "..b.type.." on line "..token.line)
          end
          table.insert(stack, val(a.value-b.value))

        elseif token.value == "==" then
          local b, a = pop(stack, scope, line), pop(stack, scope, line)
          if a.type == "function" and b.type == "function" then
            table.insert(stack, val(a == b))
            return --continue
          end
          table.insert(stack, val(a.value == b.value))

        elseif token.value == "~=" then
          local b, a = pop(stack, scope, line), pop(stack, scope, line)
          if a.type == "function" and b.type == "function" then
            table.insert(stack, val(a ~= b))
            return --continue
          elseif a.type == "function" or b.type == "function" then --xor
            table.insert(stack, Loaders.constants["false"])
            return --continue
          end
          table.insert(stack, val(a.value ~= b.value))

        elseif token.value == "<=" then
          local b, a = pop(stack, scope, line), pop(stack, scope, line)
          if a.type == "function" or b.type == "function" then
            error("attempt to compare "..a.type.." with "..b.type.." using <= on line "..token.line)
          end
          table.insert(stack, val(a.value<=b.value))

        elseif token.value == ">=" then
          local b, a = pop(stack, scope, line), pop(stack, scope, line)
          if a.type == "function" or b.type == "function" then
            error("attempt to compare "..a.type.." with "..b.type.." using >= on line "..token.line)
          end
          table.insert(stack, val(a.value>=b.value))

        elseif token.value == "<" then
          local b, a = pop(stack, scope, line), pop(stack, scope, line)
          if a.type == "function" or b.type == "function" then
            error("attempt to compare "..a.type.." with "..b.type.." using < on line "..token.line)
          end
          table.insert(stack, val(a.value < b.value))

        elseif token.value == ">" then
          local b, a = pop(stack, scope, line), pop(stack, scope, line)
          if a.type == "function" or b.type == "function" then
            error("attempt to compare "..a.type.." with "..b.type.." using > on line "..token.line)
          end
          table.insert(stack, val(a.value > b.value))

        elseif token.value == "and" then
          local b, a = pop(stack, scope, line), pop(stack, scope, line)
          if a.type == "function" then
            a = true
          else
            a = a.value
          end

          if a and b.type == "function" then
            table.insert(stack, b)
            return --continue
          end
          table.insert(stack, val(a and b.value))

        elseif token.value == "or" then
          local b, a = pop(stack, scope, line), pop(stack, scope, line)
          if a.type == "function" then
            table.insert(stack, a)
            return --continue
          elseif b.type == "function" then
            table.insert(stack, b)
            return --continue
          end
          table.insert(stack, val(a.value or b.value))

        elseif token.value == ".." then
          local b, a = pop(stack, scope, line), pop(stack, scope, line)
          if a.type == "function" or b.type == "function" then
            error("attempt to concat "..a.type.." with "..b.type.." on line "..token.line)
          end
          table.insert(stack, val(a .. b))

        elseif token.value == "," then
          local b, a = pop(stack, scope, line), pop(stack, scope, line, true)
          if a.varargs and not a.weak then
            table.insert(a.varargs, b)
            table.insert(stack, a)
          else
            table.insert( stack, Loader._varargs(a,b) )
          end
        elseif token.value == ":" then
          error"this token should be expanded in a previous step before evaluation"

        elseif token.value == "%" then
          local b, a = pop(stack, scope, line), pop(stack, scope, line)
          if a.type == "function" or b.type == "function" then
            error("attempt to preform modulo on "..a.type.." with "..b.type.." on line "..token.line)
          end
          table.insert(stack, val(a.value % b.value))
        -- elseif token.value == "" then
        else
          error("Unhandled token "..token.value)
        end
      elseif token.value == "..." then --not op
        local a = Loader._tokenValue(token, scope) --{type="varargs", weak=true, value=, varargs=}
        table.insert( a )
      elseif token.value == "{" and token.init then
        Async.insertTasks({
          label = "eval-table-init-results",
          func = function( var )
            table.insert(stack, var)
            return true --task complete
          end
        })
        Loader._initalizeTable( token )
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
        if #stack > 0 and stack[#stack].varargs then
          local varargs = table.remove(stack).varargs
          for i=1, #stack-1 do
            stack[i].varargs = nil
          end
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
end

function Loader.UNPACKER( fArgs )
  for i=1, #fArgs do
    fArgs[i] = fArgs[i].value
  end
end


function Scope:new(name, line, parent, index, env)
  local obj = {
    env = env or {},
    index = index,
    name = name.."-"..line,
    parent = parent,
    ifState = false, --false, no block has run yet, true, a block has run
    isLoop = false,
  }
  self.__index = self
  setmetatable(obj, self)
  return obj
end

function Scope:getIndex()
  return self.index or self.parent and self.parent:getIndex()
end

function Scope:set(isLocal, name, value)
  if isLocal or self.env[name] or not self.parent then
    self.env[name] = value
  else
    self.parent:set(isLocal, name, value)
  end
end

function Scope:setNativeFunc( name, func, unpacker, packer )
  self:set(false, name, {
    type = "function",
    unpacker = unpacker ~= false and (unpacker or Loader.UNPACKER) or false,
    packer = packer ~= false and (packer or Loader.PACKER) or false,
    value = func,
    name = name
  })
end

function Scope:get(name)
  if self.env[name] then
    return self.env[name]
  end
  if self.parent then
    return self.parent:get(name)
  end
  return Loader.constants["nil"]
end

function Scope:captureLocals(fenv)
  local fenv = fenv or {}
  if not self.parent then return fenv end --don't capture globals
  for k,v in pairs( self.env ) do
    if not fenv[k] then
      fenv[k] = v
    end
  end
  return self.parent:captureLocals( fenv )
end

function Scope:addGlobals()
  self:setNativeFunc( "next",     next )
  self:setNativeFunc( "print",    print )
  self:setNativeFunc( "tonumber", function( x )
    return tonumber( x )
  end )
  --tostring(table.unpack{nil}) is an error
  --tostring( nil ) is not...
  self:setNativeFunc( "tostring", function( x )
    return tostring( x )
  end )

  self:setNativeFunc( "ipairs",   function(tbl)
    local indexer = Loader.tableIndexes[tbl.value]
    local gen, _, start = ipairs(indexer)
    local wrapGen = Loader._val(function(tbl, index, ...)
      local nextIndex, nextWrappedIndex = gen( indexer, index )
      return nextWrappedIndex, tbl[nextWrappedIndex]
    end)
    wrapGen.unpacker = Loader.UNPACKER
    return wrapGen, tbl, Loader._val(start)
  end, false, false )

  self:setNativeFunc( "pairs",    pairs, function( fArgs )
    fArgs[1] = fArgs[1].value
  end, false )
  -- self:setNativeFunc( "",  )
end

--index may be nil
function Loader._appendCallEnv( callStack, name, line, index, env )
  local scope = Scope:new( name, line, callStack[#callStack], index, env)
  table.insert(callStack, scope )
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
  callStack[1]:set("...", prgmArgs)

  local index = 1
  return Async.insertTasks(
    Async.whileLoop("exec", function () return instructions[index] end, function ()
      local inst = instructions[index]
      local top = callStack[#callStack]
      -- print("                       DEBUG: "..inst.line..": "..inst.op.."["..#callStack.."]")
      if inst.op == "assign" then
        -- local instruction = {
        --   op = "assign",
        --   vars = token.value,
        --   infix = { eval = infix },
        --   isLocal = localVar,
        --   index = #instructions+1
        -- }

        Async.insertTasks({
          label = "assignment eval results",
          func = function( stack )
            local target = top
            for i=1, #inst.vars do
              target:set(inst.isLocal, inst.vars[i].value, stack[i] or Loader.constants["nil"] )
            end
            return true
          end
        })

        --inserts task
        Loader.eval( inst.postfix.eval, top, inst.line )
        
      elseif inst.op == "eval" then
        --inserts task
        Loader.eval( inst.postfix.eval, top, inst.line )

      elseif inst.op == "return" then
        Async.insertTasks({
          label = "assignment eval results",
          func = function( stack )
            return { Loader._varargs(table.unpack(stack)) }
          end
        })
        --inserts task
        Loader.eval( inst.postfix.eval, top, inst.line )
        return true --exit, return values from task passed
      elseif inst.op == "function" then --capture locals & add to env
        local locals = callStack[#callStack]:captureLocals()
        local fenv = Scope:new("fenv: "..inst.name, inst.line, top, index, locals)
        local fval = {
          env = fenv,
          instructions = inst.instructions,
          line = inst.line,
          args = inst.args,
          type = "function"
        }

        local target = inst.isLocal and callStack[#callStack] or callStack[1]
        target:set( inst.isLocal, inst.name, fval )
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
  Scope = Scope
}