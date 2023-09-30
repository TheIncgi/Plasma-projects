local ok, func = pcall( load, [==========[function a()
    error"oh no!"
  end
  
  function b()
    a()
  end
  
  b()]==========], "REPL" )
  if not ok then
    print"SYNTAX:"
  else
    local result = {pcall( func )}
    if not result[1] then
      print"REPL:"
      print( tostring( result[2] ))
    else
      for i=2,#result do
        print"RESULT"
      end
    end
  end
  