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

Loader.keywords = {
  -- ["and"]      = true,
  ["break"]    = true,
  ["do"]       = true,
  ["false"]    = true,
  ["for"]      = true,
  ["function"] = true,
  ["if"]       = true,
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
        elseif token == "(" or token == "{" then -- " doesn't"
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
      elseif tokenType=="str" then
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
    Async.whileLoop("_findExpressionEnd", function () return true end, function()
      local token = tokens[index]
      
      if not token then
        if start == index then return {false} end
        if requiresValue then error("Incomplete expression at end of file") end
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
        -- local removeScope = false
        -- if token.value == "function"
        -- or token.value == "do"
        -- or token.value == "repeat" then
        --   addScope = true
        -- elseif token.value == "else" or token.value == "elseif" then
        --   addScope, removeScope = true, true
        -- elseif token.value == "end" or token.value == "until" then
        --   removeScope = true
        -- end

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
                  line = token.line
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
              startingBlock.skip = deleteScope
            end
            if token.blockLevel <= exitBlockLevel then
              return {instructions, index + 1}
            end
          end

          index = endTokenPos
          return --continue
        elseif token.value == "end" then
          local deleteScope = {op="deleteScope", token = token, index = #instructions+1, line = token.line}
          table.insert(instructions, deleteScope)
          local startingBlock = table.remove(blocks)
          if token.blockLevel <= exitBlockLevel then
            return {instructions, index + 1}
          end
          if startingBlock.skip == false then
            startingBlock.skip = deleteScope
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
          
          table.insert(instructions, instruction)
          table.insert(blocks, instruction)
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
          if nextToken.token == "in" then
            local generatorInit, nextTokenIndex = Loader._collectExpression(tokens, index+1, false, token.line, true)
            local doToken = tokens[nextTokenIndex]
            if doToken.type ~= "keyword" or doToken.value ~= "do" then
              error("Expected do for `for in` loop on line "..token.line)
            end
            local inst = {
              op = "for-in",
              vars = nextToken,
              infix = {
                generatorInit = generatorInit,
              },
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
              infix = {
                init = varInit,
                limit = limit,
                increment = increment or {type="num",value=1},
              },
              line = token.line,
              skip = false, --end inst
              index = #instructions+1
            }
            table.insert( instructions, inst )
            table.insert( blocks, inst )
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


function Loader._generatePostfix( infix )
  local out, opStack = {}, {} --opstack contains ops in ascending order only (except ())
  local index = 1
  return 
    Async.insertTasks(
      Async.whileLoop("_generatePostfix",function() return index <= #infix end, function()
        local token = infix[index]
        if token.type == "op" then
          local priority = Loader._ops[token.value] --higher happens first
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
            if (Loader._ops[opStack[#opStack].value] > priority) 
            or (Loader._rightAssociate[token.value] and Loader._ops[opStack[#opStack]] == priority) then
              table.insert(out, table.remove(opStack))
              while #opStack > 0 and (Loader._ops[opStack[#opStack]] > priority)  do
                table.insert(out, table.remove(opStack))
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

function Loader.eval( postfix, scope, line )
  local stack = {}
  local pop = Loader._popVal
  local val = Loader._val
  Async.insertTasks(
    Async.forEach("eval-postfix", function(index, token)
      if token.type == "op" then
        if token.call then
          local args =  pop(stack, scope, line, true)
          local func
          if args.value ~= "function" then
            func = pop(stack, scope, line)
          else
            func = args
            args = Loader._varargs()
          end
          if func.value then
            local results = {func.value( table.unpack(args.varargs or {args}) )}
            for i=1, #results do
              results[i] = Loader._val(results[i])
            end
            table.insert(stack, Loader._varargs(table.unpack(results)))
          else
            Async.insertTasks({
              label = "eval-call-result",
              func = function(varargsResult)
                table.insert(stack, varargsResult)
                return true
              end
            })
            for i=1,#func.args do
              func.env:set(true,func.args[i], table.remove(args.varargs) or Loader.constants["nil"])
            end
            Loader.execute(func.instructions, func.env, table.unpack(args.varargs or {args}))
          end
        elseif token.value == "." then
          local b, a = pop(stack, scope, line).value, pop(stack, scope, line).value
          local v = a[b]
          table.insert(stack, val(a[b]))

        elseif token.value == "not" then
          local a = pop(stack, scope, line).value
          table.insert(stack, val(not a))

        elseif token.value == "#" then
          local a = pop(stack, scope, line).value
          table.insert(stack, val(#a))

        elseif token.value == "^" then
          local b, a = pop(stack, scope, line).value, pop(stack, scope, line).value
          table.insert(stack, val(a^b))

        elseif token.value == "*" then
          local b, a = pop(stack, scope, line).value, pop(stack, scope, line).value
          table.insert(stack, val(a*b))

        elseif token.value == "/" then
          local b, a = pop(stack, scope, line).value, pop(stack, scope, line).value
          table.insert(stack, val(a/b))

        elseif token.value == "+" then
          local b, a = pop(stack, scope, line).value, pop(stack, scope, line).value
          table.insert(stack, val(a+b))

        elseif token.value == "-" then
          local b, a = pop(stack, scope, line).value, pop(stack, scope, line).value
          table.insert(stack, val(a-b))

        elseif token.value == "==" then
          local b, a = pop(stack, scope, line).value, pop(stack, scope, line).value
          table.insert(stack, val(a==b))

        elseif token.value == "~=" then
          local b, a = pop(stack, scope, line).value, pop(stack, scope, line).value
          table.insert(stack, val(a~=b))

        elseif token.value == "<=" then
          local b, a = pop(stack, scope, line).value, pop(stack, scope, line).value
          table.insert(stack, val(a<=b))

        elseif token.value == ">=" then
          local b, a = pop(stack, scope, line).value, pop(stack, scope, line).value
          table.insert(stack, val(a>=b))

        elseif token.value == "<" then
          local b, a = pop(stack, scope, line).value, pop(stack, scope, line).value
          table.insert(stack, val(a<b))

        elseif token.value == ">" then
          local b, a = pop(stack, scope, line).value, pop(stack, scope, line).value
          table.insert(stack, val(a>b))

        elseif token.value == "and" then
          local b, a = pop(stack, scope, line).value, pop(stack, scope, line).value
          table.insert(stack, val(a and b))

        elseif token.value == "or" then
          local b, a = pop(stack, scope, line).value, pop(stack, scope, line).value
          table.insert(stack, val(a or b))

        elseif token.value == ".." then
          local b, a = pop(stack, scope, line).value, pop(stack, scope, line).value
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
          table.insert(stack, val(a % b))
        -- elseif token.value == "" then
        else
          error("Unhandled token "..token.value)
        end
      elseif token.value == "..." then --not op
        local a = Loader._tokenValue(token, scope) --{type="varargs", weak=true, value=, varargs=}
        table.insert( a )
      else
        table.insert(stack, token)
      end
    end, ipairs, postfix),
    {
      label = "eval-expand-varargs",
      func = function()
        if stack[#stack].varargs then
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

local Scope = {}
function Scope:new(name, line, parent, index, env)
  local obj = {
    env = env or {},
    index = index,
    name = name.."-"..line,
    parent = parent
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
    self.parent:set(name, value)
  end
end

function Scope:setNativeFunc( name, func )
  self:set(false, name, {
    type = "function",
    value = func
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
  self:setNativeFunc( "print", print )
  self:setNativeFunc( "ipairs", ipairs )
  self:setNativeFunc( "pairs", pairs )
  self:setNativeFunc( "next", next )
  -- scope:setNativeFunc( "",  )
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
            local target = inst.isLocal and callStack[#callStack] or callStack[1]
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
        local fenv = Scope:new("fenv: "..inst.name, inst.line, callStack[1], index, locals)
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
      elseif inst.op == "elseif" then
      elseif inst.op == "else" then
      elseif inst.op == "while" then
      elseif inst.op == "for" then
      elseif inst.op == "for-in" then
      elseif inst.op == "until" then
        
      elseif inst.op == "createScope" then
        Loader._appendCallEnv( callStack, "block start", inst.line, inst.index )
      elseif inst.op == "deleteScope" then
        table.remove(callStack)
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
--TODO: local a,b,c declaring
--TODO: local function

local rawTokens = sync( Loader.tokenize(testCode) )
local tokens = sync( Loader.cleanupTokens( rawTokens ) )
local instructions = sync( Loader.buildInstructions(tokens)  )
sync( Loader.batchPostfix(instructions) )
sync( Loader.execute( instructions ) )
-- local tokens = Loader.tokenize(testCode)
print"done"