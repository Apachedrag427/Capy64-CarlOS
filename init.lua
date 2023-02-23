--[=[ 

[[== CarlOS ==]]

- init.lua {
	Setting up the OS
}

--]=]

function table.find(tbl, val)
	for i, v in next, tbl do
		if val == v then
			return i
		end
	end
	return false
end

function table.deepcopy(tbl)
	local res = {}
	for i, v in next, tbl do
		if type(v) == "table" then
			v = table.deepcopy(v)
		end
		res[i] = v
	end
	return res
end

function math.clamp(v, min, max)
	if v ~= v or v <= min then
		return min
	end
	if v >= max then
		return max
	end
	return v
end

_G.unpack = table.unpack

local expect
do -- Expect function pulled from cc:t
	local a,b=select,type;local function c(...)local d=table.pack(...)for e=d.n,1,-1 do if d[e]=="nil"then table.remove(d,e)end end;if#d<=1 then return tostring(...)else return table.concat(d,", ",1,#d-1).." or "..d[#d]end end;function expect(g,h,...)local i=b(h)for e=1,a("#",...)do if i==a(e,...)then return h end end;local j;local k,l=pcall(debug.getinfo,3,"nS")if k and l.name and l.name~=""and l.what~="C"then j=l.name end;local m=c(...)if j then error(("bad argument #%d to '%s' (expected %s, got %s)"):format(g,j,m,i),3)else error(("bad argument #%d (expected %s, got %s)"):format(g,m,i),3)end end
end

local function requirelist(...)
	local res = {}
	for _, name in ipairs({...}) do
		table.insert(res, require(name))
	end
	return unpack(res)
end

local oldevent, machine, fs, gpu, audio, http, timer, term = requirelist("event", "machine", "fs", "gpu", "audio", "http", "timer", "term")

function timer.sleep(s)
	local tid = timer.start(s)
	repeat 
		local _, id = oldevent.pull("timer")
	until id == tid
end

local color = {}

function color.isValid(col)
	if type(col) ~= "table" or not col.r or not col.g or not col.b or type(col.r) ~= "number" or type(col.g) ~= "number" or type(col.b) ~= "number" then
		return false
	end
	return true
end

function color.ensureValid(col)
	assert(color.isValid(col), "Invalid color object given")
end

function color.new(r, g, b)
	expect(1, r, "number", "nil")
	expect(2, g, "number", "nil")
	expect(3, b, "number", "nil")
	r = r or 0
	g = g or 0
	b = b or 0

	local obj = {}
	obj.r, obj.g, obj.b = r, g, b

	function obj:getBrightness()
		return (obj.r + obj.g + obj.b) / 3
	end

	function obj:getMonotone()
		local br = obj:getBrightness()
		return color.new(br, br, br)
	end

	function obj:toHex()
		return
			(math.floor(obj.r * 255) << 16) +
			(math.floor(obj.g * 255) << 8) +
			math.floor(obj.b * 255)
	end

	local function fixvals()
		obj.r = math.clamp(obj.r, 0, 1)
		obj.g = math.clamp(obj.g, 0, 1)
		obj.b = math.clamp(obj.b, 0, 1)
	end

	local function lerpSingle(a, b, t)
		return a * (1 - t) + b * t
	end

	function obj:fromRGB(r, g, b)
		expect(1, r, "number", "nil")
		expect(2, g, "number", "nil")
		expect(3, b, "number", "nil")
		r = r or 0
		g = g or 0
		b = b or 0

		obj.r = r / 255
		obj.g = g / 255
		obj.b = b / 255

		return obj
	end

	function obj:fromHex(packed)
		expect(1, packed, "number", "nil")
		packed = packed or 0

		obj.r = (packed >> 16) & 0xff
		obj.g = (packed >> 8) & 0xff
		obj.b = packed & 0xff

		return obj
	end

	function obj:fromHSV(h, s, v)
		expect(1, h, "number")
		expect(2, s, "number")
		expect(3, v, "number")


		local r, g, b

		local i = math.floor(h * 6)
		local f = h * 6 - i
		local p = v * (1 - s)
		local q = v * (1 - f * s)
		local t = v * (1 - (1 - f) * s)

		i = i % 6

		if i == 0 then r, g, b = v, t, p
			elseif i == 1 then r, g, b = q, v, p
			elseif i == 2 then r, g, b = p, v, t
			elseif i == 3 then r, g, b = p, q, v
			elseif i == 4 then r, g, b = t, p, v
			elseif i == 5 then r, g, b = v, p, q
		end

		obj.r = r
		obj.g = g
		obj.b = b

		return obj
	end

	function obj:lerp(goal, alpha)
		expect(1, goal, "table", "number")
		expect(2, alpha, "number")

		if type(goal) == "table" then
			obj.r = lerpSingle(obj.r, goal.r, alpha)
			obj.g = lerpSingle(obj.g, goal.g, alpha)
			obj.b = lerpSingle(obj.b, goal.b, alpha)
		else
			obj.r = lerpSingle(obj.r, goal, alpha)
			obj.g = lerpSingle(obj.g, goal, alpha)
			obj.b = lerpSingle(obj.b, goal, alpha)
		end
		fixvals()
		return obj
	end

	function obj:multiply(other)
		expect(1, other, "table", "number")
		if type(other) == "table" then
			color.ensureValid(other)
			obj.r = obj.r * other.r
			obj.g = obj.g * other.g
			obj.b = obj.b * other.b
		else
			obj.r = obj.r * other
			obj.g = obj.g * other
			obj.b = obj.b * other
		end
		fixvals()
		return obj
	end

	function obj:add(other)
		expect(1, other, "table", "number")
		if type(other) == "table" then
			color.ensureValid(other)
			obj.r = obj.r + other.r
			obj.g = obj.g + other.g
			obj.b = obj.b + other.b
		else
			obj.r = obj.r + other
			obj.g = obj.g + other
			obj.b = obj.b + other
		end
		fixvals()
		return obj
	end

	function obj:subtract(other)
		expect(1, other, "table", "number")
		if type(other) == "table" then
			color.ensureValid(other)
			obj.r = obj.r - other.r
			obj.g = obj.g - other.g
			obj.b = obj.b - other.b
		else
			obj.r = obj.r - other
			obj.g = obj.g - other
			obj.b = obj.b - other
		end
		fixvals()
		return obj
	end

	function obj:divide(other)
		expect(1, other, "table", "number")
		if type(other) == "table" then
			color.ensureValid(other)
			obj.r = obj.r / other.r
			obj.g = obj.g / other.g
			obj.b = obj.b / other.b
		else
			obj.r = obj.r / other
			obj.g = obj.g / other
			obj.b = obj.b / other
		end
		fixvals()
		return obj
	end

	local mt = {}

	mt.__mul = obj.multiply
	mt.__add = obj.add
	mt.__sub = obj.subtract
	mt.__div = obj.divide

	setmetatable(obj, mt)

	return obj
end

function color.fromRGB(r, g, b)
	expect(1, r, "number", "nil")
	expect(2, g, "number", "nil")
	expect(3, b, "number", "nil")
	r = r or 0
	g = g or 0
	b = b or 0

	return color.new(r / 255, g / 255, b / 255)
end

function color.fromHex(packed)
	expect(1, packed, "number", "nil")
	packed = packed or 0
	return color.fromRGB(
		(packed >> 16) & 0xff,
		(packed >> 8) & 0xff,
		packed & 0xff
	)
end

function color.fromHSV(h, s, v)
	expect(1, h, "number")
	expect(2, s, "number")
	expect(3, v, "number")

	local r, g, b

	local i = math.floor(h * 6)
	local f = h * 6 - i
	local p = v * (1 - s)
	local q = v * (1 - f * s)
	local t = v * (1 - (1 - f) * s)

	i = i % 6

	if i == 0 then r, g, b = v, t, p
		elseif i == 1 then r, g, b = q, v, p
		elseif i == 2 then r, g, b = p, v, t
		elseif i == 3 then r, g, b = p, q, v
		elseif i == 4 then r, g, b = t, p, v
		elseif i == 5 then r, g, b = v, p, q
	end

	return color.new(r, g, b)
end

local sys = {}

sys.windows = {}

local window = {}

function window.new(startx, starty, sizex, sizey, bordercolor)
	expect(1, startx, "number")
	expect(2, starty, "number")
	expect(3, sizex, "number")
	expect(4, sizey, "number")
	expect(5, bordercolor, "table", "number")

	local obj = {}

	obj.x, obj.y, obj.size, obj.borderSize, obj.borderless = startx, starty, {x = sizex, y = sizey}, {horizontal = 2, bottom = 2, topbar = 8}, false

	if type(bordercolor) == "table" then
		color.ensureValid(bordercolor)
		obj.borderColor = bordercolor
	else
		local col = color.fromHex(bordercolor)
		obj.borderColor = col
	end

	local redrawevent, fireredraw = sys.createEvent()

	function obj:setBorderless(bool)
		obj.borderless = bool
	end

	obj.onRedraw = redrawevent

	function obj:requestRedraw()
		if not obj.borderless then
			gpu.drawRectangle(obj.x, obj.y, obj.size.x, obj.size.y, obj.borderColor:toHex(), math.min(obj.size.x, obj.size.y))
		end
		fireredraw()
	end

	function obj:getBufferSize()
		return obj.size.x - ((not obj.borderless) and obj.borderSize.horizontal * 2 or 0), obj.size.y - ((not obj.borderless) and (obj.borderSize.bottom + obj.borderSize.topbar) or 0)
	end

	function obj:generateBuffer()
		local w, h = obj:getBufferSize()
		return gpu.newBuffer(w, h), w, h
	end

	function obj:getBufferCorner()
		return obj.x + ((not obj.borderless) and obj.borderSize.horizontal or 0), obj.y + ((not obj.borderless) and obj.borderSize.topbar or 0)
	end

	function obj:setBuffer(buffer)
		local x, y = obj:getBufferCorner()
		local w, h = obj:getBufferSize()
		gpu.drawBuffer(buffer, x, y, w, h)
	end

	function obj:coordinatesFromBuffer(idx)
		expect(1, idx, "number")
		local w, h = obj:getBufferSize()
		return idx % w, math.ceil(idx / h)
	end

	function obj:toAbsolute(x, y)
		local absx, absy = obj:getBufferCorner()
		return absx + x, absy + y
	end

	table.insert(sys.windows, obj)

	return obj
end

local requireoverrides = {
	color = color,
	sys = sys
}

function sys.createEvent()
	local obj = {}
	local connections = {}

	local function fire(...)
		for _, c in ipairs(connections) do
			c.callback(...)
		end
	end

	local function removeConnection(con)
		local idx = table.find(connections, con)
		if idx then
			table.remove(connections, idx)
		end
	end

	function obj:connect(callback)
		expect(1, callback, "function")
		local connection = {}
		local active = true

		local connectioninfo = {c = connection, callback = callback}

		local event = obj

		function connection:enable()
			active = true
		end

		function connection:disable()
			active = false
		end

		function connection:disconnect()
			active = false
			for i in next, connection do
				connection[i] = nil
			end
			removeConnection(connectioninfo)
		end

		function connection:isActive()
			return active
		end

		table.insert(connections, connectioninfo)

		return connection
	end

	function obj:once(callback)
		expect(1, callback, "function")
		local c; c = obj:connect(function(...)
			c:disconnect()
			callback(...)
		end)
		return c
	end

	return obj, fire
end

local oldrequire = require
function _G.require(...)
	local override = requireoverrides[(...)]
	if override then
		return override
	end
	return oldrequire(...)
end

gpu.setScale(0.5)
gpu.setSize(300, 200)

local newwindow = window.new(50, 50, 100, 75, 0xffffff)

local maincol = color.new()

newwindow.onRedraw:connect(function()
	local maxw, maxh = gpu.getSize()
	local buff <close>, w, h = newwindow:generateBuffer()
	local len = #buff
	for i = 0, len - 1 do
		local relx, rely = newwindow:coordinatesFromBuffer(i)
		local absx, absy = newwindow:toAbsolute(relx, rely)
		local xprog, yprog = absx / maxw, absy / maxh
		buff[i] = maincol:fromHSV(xprog, 1, 1):toHex()
	end
	newwindow:setBuffer(buff)
end)

gpu.clear()

newwindow:requestRedraw()

while true do
	local ev = {oldevent.pull()}
	if ev[1] == "mouse_down" then
		if ev[2] == 2 then
			newwindow:setBorderless(not newwindow.borderless)
		end
		gpu.clear()
		newwindow.x = ev[3]
		newwindow.y = ev[4]
		newwindow:requestRedraw()
	elseif ev[1] == "mouse_move" and #ev[2] > 0 then
		gpu.clear()
		newwindow.x = ev[3]
		newwindow.y = ev[4]
		newwindow:requestRedraw()
	elseif ev[1] == "screen_resize" then
		gpu.clear()
		newwindow:requestRedraw()
	end
end

--[[
while true do
	local maxx, maxy = gpu.getSize()
	gpu.clear()
	for x = 1, maxx do
		for y = 1, maxy do
			local xprog = x / maxx
			local yprog = y / maxy
			local col = color.fromHSV(xprog, 1 - yprog, 1)
			local hexcol = col:toHex()
			gpu.plot(x, y, hexcol)
		end
		timer.sleep(10)
	end
	timer.sleep(10000)
end
]]