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

Loader.keywords = {
  ["and"]      = true,
  ["break"]    = true,
  ["do"]       = true,
  ["false"]    = true,
  ["for"]      = true,
  ["function"] = true,
  ["if"]       = true,
  ["in"]       = true,
  ["local"]    = true,
  ["nil"]      = true,
  ["not"]      = true,
  ["or"]       = true,
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
	["//"] = false, -- comment
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
	if text:match"[ \t\n\r]" and text~="\n" and not text:match"^['\"]" then
		return false
	elseif text=="\n" then
		return "line"
	elseif text:match"//.+" then 
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
      if Loader._ops[token] then tokenType = "op" end
      if Loader.keywords[token] then tokenType = "keyword" end
      local infoToken = {
        value = token,
        type = tokenType,
        line = line,
        blockLevel = blockLevel
      }

      if tokenType == "num" then
        infoToken.value = tonumber(infoToken.value)

        if prior and prior.value == "-"
        and (twicePrior and twicePrior.type == "op")
         or twicePrior == nil then
          table.remove(tokens, index-1)
          infoToken.value = -infoToken.value
          index = index-1
        end
      
      elseif tokenType == "op" then
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
        elseif token == "(" or token == "{" or token:sub(1,1)=="'" or token:sub(1,1) =='"' then
          if prior and (
              (prior.type == "var")
            or (prior.type == "op" and (prior.value == ")" or prior.value == "]"))
          ) then
            infoToken.call = true  
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
      end

      tokens[index] = infoToken
      index = index + 1
    end),
    RETURN("cleanupTokens", tokens)
  )
end

--returning next unhandled token
function Loader._findExpressionEnd( tokens, start, allowAssignment, ignoreComma )
  local index = start
  local brackets = {}
  local requiresValue = true
  local argGroups = 1

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
    Async.whileLoop("_findExpressionEnd", function () return index < #tokens end, function()
      local token = tokens[index]
      
      if not token then
        if start == index then return {false} end
        return {index}
      end

      if token.type == "op" and token.value=="=" and not allowAssignment then
        error("Assignment can not be use in expression on line "..token.line)
      end
      
      if requiresValue then
        if token.type == "op" then
          if not startPermitted[token.value] then
            error("Expected a value, found op "..token.value.." instead on line "..token.line)
          end
          if token.value == "{" or token.value == "(" or token.value=="[" then
            table.insert(brackets, token)
          end
          --requiresValue = true again
        else
          requiresValue = false
        end
      elseif token.type == "op" then
        if token.value == ")" or token.value == "}" or token.value == "]" then
          local topBracket = table.remove(brackets)
          if token.value ~= Loader._closePar(topBracket.value) then
            error("Mis-matched brackets opening with "..topBracket.value.." on line "..topBracket.line.." and "..token.value.." on line"..token.line)
          end
          -- requiresValue = false again
        elseif token.call then
          if token.value == "{" or token.value == "(" or token.value=="[" then
            table.insert(brackets, token)
            requiresValue = true
          end
        elseif startPermitted[token.value] then
          error("Unexpected token "..token.value.." in expression on line "..token.line)
        else
          if token.value == "," then
            if ignoreComma then
              return {index, argGroups}
            end
            argGroups = argGroups + 1
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

function Loader._collectExpression( tokens, index, allowAssignment, line, ignoreComma )
  local endTokenPos = Async.sync(Loader._findExpressionEnd(tokens, index, allowAssignment, ignoreComma)) --todo possible improvment on async
  if not endTokenPos then
    error("Missing expression for assignment on line "..line)
  end
  local infix = {}
  for i=index, endTokenPos-1 do
    table.insert(infix, tokens[i])
  end

  return infix, endTokenPos
end

function Loader.readFunctionHeader(tokens, index)
  local fToken = tokens[index-1]
  local fname = tokens[index]
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
  local par = tokens[index+1]
  if not par or par.type~="op" or par.value~="(" then
    error("Expected `(` for function on line"..fToken.line)
  end
  local args = {}
  index = index + 2
  while tokens[index] and tokens[index].value~=")" do
    local name = tokens[index]
    if not name or name.type~="var" then
      error("Expected arg name or ) for function '"..fname.."' on line"..fToken.line)
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

  table.insert(instructions, {op="createScope"})

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
          infix = infix,
          isLocal = localVar
        }

        table.insert(instructions, instruction)
        index = endTokenPos
        return --continue
      elseif token.type == "keyword" then
        local addScope, removeScope = false, false
        if token.value == "function"
        or token.value == "do"
        or token.value == "repeat"
        or token.value == "then" then
          addScope = true
        elseif token.value == "else" or token.value == "elseif" then
          addScope, removeScope = true, true
        elseif token.value == "end" then
          removeScope = true
        end

        if addScope then
          
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
                    instructions = inst
                  }
                  table.insert(instructions, instruction)
                  index = nextIndex
                  return true
                end
              }
            )
            Loader.buildInstructions(tokens, instStart, token.blockLevel) --returns instructions, nextIndex
            return --continue into inserted tasks
          else
            table.insert(instructions, {op="createScope", token = token})
          end
        end

        --instructions with expresssions
        if token.value == "return" then
          local infix, endTokenPos = Loader._collectExpression(tokens, index+1, false, token.line) --todo async improvment
          local instruction = {
            op = "return",
            infix = infix,
          }
          
          table.insert(instructions, instruction)
          index = endTokenPos
          return --continue
        elseif token.value == "if" or token.value == "elseif" then
          --TODO prevent varargs evaluation
          local infix, endTokenPos = Loader._collectExpression(tokens, index+1, false, token.line) --todo async improvment
          local instruction = {
            op = token.value,
            infix = infix,
            skip = false --not set
          }
          
          table.insert(instructions, instruction)
          local nextToken = tokens[endTokenPos]
          if nextToken.type ~="keyword" or nextToken.value ~= "then" then
            error("`then` expected on line "..(tokens[endTokenPos-1].line))
            end
          index = endTokenPos + 1
          return --continue
        elseif token.value == "while" then
          --TODO prevent varargs evaluation
          local infix, endTokenPos = Loader._collectExpression(tokens, index+1, false, token.line) --todo async improvment
          local instruction = {
            op = "while",
            infix = infix,
            skip = false --not set
          }

          table.insert(instructions, instruction)
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
          if nextToken.token == "in" then
            local generatorInit, nextTokenIndex = Loader._collectExpression(tokens, index+1, false, token.line, true)
            local doToken = tokens[nextTokenIndex]
            if doToken.type ~= "keyword" or doToken.value ~= "do" then
              error("Expected do for `for in` loop on line "..token.line)
            end
            local inst = {
              op = "for-in",
              vars = nextToken,
              generatorInit = generatorInit,
              line = token.line,
              skip = false, --end block inst link
            }
            table.insert(instructions, inst )
            table.insert(blocks, inst)
            index = nextTokenIndex+1
            return --continue
          elseif #nextToken.value ~= 1 then
            error("varargs can't be used on initalization of a for loop with `=` on line "..token.line)
          else -- =
            local varInit, nextTokenIndex = Loader._collectExpression(tokens, index+1, false, token.line, true)
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
            local inst = {
              op = "for",
              vars = token.value,
              init = varInit,
              limit = limit,
              increment = increment or {type="num",value=1},
              line = token.line,
              skip = false --end inst
            }
            table.insert( instructions, inst )
            table.insert( blocks, inst )
            index = nextTokenIndex + 1
            return --continue
          end

        end --token.value == keyword



        if removeScope then
          table.insert(instructions, {op="deleteScope", token = token})
          if token.blockLevel <= exitBlockLevel then
            return {instructions, index + 1}
          end
        end
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

--===================================================================================
--===================================================================================
--===================================================================================
--===================================================================================
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
]===]

local rawTokens = sync( Loader.tokenize(testCode) )
local tokens = sync( Loader.cleanupTokens( rawTokens ) )
local instructions = sync( Loader.buildInstructions(tokens)  )
-- local tokens = Loader.tokenize(testCode)
print"done"