local states = {}

SENSITIVITY = .01

function wrappedDif( a, b )
	return math.min(
		math.abs( a - b ),
		math.abs( a - (b+360) ),
		math.abs( (a+360) - b )
	)
end

function getStates()
	local s = {}
	for i=1,8 do
		s[i] = _G["V"..i] or 0
	end
	return s
end

function compare()
	print"compare"
	local states = getStates()	
	local any = false
	for i=1,8 do
		local old = states[i] or 0
		local new = _G["V"..i] or 0
		local dif = wrappedDif( old, new )
		if dif > SENSITIVITY then
			any = true
			states[i] = new
		end
	end
	trigger( any and 1 or 2 )
	print( any )
end

function setup()
end

function tick()
	print"tick"
	compare()
end