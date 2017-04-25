local class = require 'ext.class'
local table = require 'ext.table'
local vec3d = require 'ffi.vec.vec3d'
local vec4d = require 'ffi.vec.vec4d'
local ffi = require 'ffi'
local cube = require 'chompman.cube'
local gl = require 'gl'
local glCallOrDraw = require 'gl.call'

local Map = class()

Map.TYPE_EMPTY = 0
Map.TYPE_SOLID = 1

Map.isNotSolid = {
	[Map.TYPE_EMPTY] = true,
}

--[[
pacman grid is 41x29
a wall is 1 in size
a pellet is 1 in size
pacman is 3x3
typical corridors are 3 wide
in terms of pacman sizes, excluding walls, it is 10x7 = 70 units
--]]
Map.corridorSize = 1
Map.wallSize = 3
Map.colSize = Map.corridorSize + Map.wallSize
--Map.numCols = vec3d(10,7,7)
Map.numCols = vec3d(5,5,3)
Map.size = vec3d(1,1,1)*Map.numCols*Map.colSize

local function shuffle(src)
	local t = table(src)
	local s = table()
	while #t > 0 do
		s:insert((t:remove(math.random(#t))))
	end
	return s
end

local sides = table{
	{dim=0, dir=1},
	{dim=0, dir=-1},
	{dim=1, dir=1},
	{dim=1, dir=-1},
	{dim=2, dir=1},
	{dim=2, dir=-1},
}

function Map:init(args)
	self.game = args.game
	
	self.center = (self.size-1)/self.colSize/2
	for i=0,2 do self.center:ptr()[i] = math.floor(self.center:ptr()[i]) end
	self.center = self.center * self.colSize + self.wallSize

	local overlays = table()
	for overlay=1,2 do
		self.data = ffi.new('char[?]', self.size:volume())
		local e = 0
		for k=0,self.size.z-1 do
			for j=0,self.size.y-1 do
				for i=0,self.size.x-1 do
					self.data[e] = 0
					if i % self.colSize < self.wallSize
					or j % self.colSize < self.wallSize
					or k % self.colSize < self.wallSize then
						self.data[e] = self.TYPE_SOLID
					end
					e=e+1
				end
			end
		end

		--depth-first maze algorithm
		local touched = table()
		local pt = (self.size/self.colSize-1)/2
		local stack = table{pt}
		while #stack > 0 do
			local pt = stack:remove()
			for _,side in ipairs(shuffle(sides)) do
				local s1 = side.dim
				local s2 = (s1 + 1) % 3
				local s3 = (s2 + 1) % 3
				local offset = vec3d(0,0,0)
				offset:ptr()[side.dim] = side.dir
				local npt = pt + offset
				for i=0,2 do
					npt:ptr()[i] = npt:ptr()[i] % (self.size/self.colSize):ptr()[i]
				end
				local npts = tostring(npt)
				if not touched[npts] then
					touched[npts] = true
					stack:insert(npt)
					-- destroy the wall between them
					for i=self.wallSize,self.colSize-1 do
						for j=self.wallSize,self.colSize-1 do
							for k=0,self.wallSize-1 do
								local bpt = pt * self.colSize
								bpt:ptr()[s1] = bpt:ptr()[s1] + k
								if side.dir > 0 then
									bpt:ptr()[s1] = bpt:ptr()[s1] + self.colSize
								end
								bpt:ptr()[s2] = bpt:ptr()[s2] + i
								bpt:ptr()[s3] = bpt:ptr()[s3] + j
								self:set(bpt.x, bpt.y, bpt.z, self.TYPE_EMPTY)
							end
						end
					end
				end
			end
		end
		overlays:insert(self.data)
	end

	do
		self.pellets = table()
		local e = 0
		for k=0,self.size.z-1 do
			for j=0,self.size.y-1 do
				for i=0,self.size.x-1 do
					for _,overlay in ipairs(overlays) do
						if overlay[e] == self.TYPE_EMPTY then
							self.data[e] = self.TYPE_EMPTY
							break
						end
					end
					
					if self.data[e] == self.TYPE_EMPTY
					and (i % self.colSize == self.wallSize
					or j % self.colSize == self.wallSize
					or k % self.colSize == self.wallSize)
					then
						self.pellets:insert(vec3d(i,j,k))
					end
					
					e = e + 1
				end
			end
		end
	
		self.pills = table()
		for i=1,5 do
			self.pills:insert(self.pellets:remove(math.random(1,#self.pills)))
		end
	end
end

function Map:draw()
	-- TODO - use call lists and do this as a vertex shader
	-- or use draw lists
	-- or something 
	if not self.lineStrips then
		self.lineStrips = range(3):map(function(i) return table() end)	-- per axis 
		for k=0,self.size.z-1 do
			for j=0,self.size.y-1 do
				for i=0,self.size.x-1 do
					local i0 = vec3d(i,j,k)
					for s1=0,2 do
						local i1 = vec3d(i0:unpack())
						i1:ptr()[s1] = i1:ptr()[s1] + 1
						if self.isNotSolid[self:get(i0:unpack())]
						and self.isNotSolid[self:get(i1:unpack())]
						then
							local fmax = 100
							local lineStrip = table()
							for f=0,fmax do
								local v = vec3d(i0:unpack())
								v:ptr()[s1] = v:ptr()[s1] + f/fmax
								lineStrip:insert(v)
							end
							self.lineStrips[s1+1]:insert(lineStrip)
						end
					end
				end
			end
		end	
	end
	for axis,lineStrips in ipairs(self.lineStrips) do
		local c = vec4d(0,0,0,.75)
		c:ptr()[axis-1] = 1
		gl.glColor4dv(c:ptr())
		for _,lineStrip in ipairs(lineStrips) do
			gl.glBegin(gl.GL_LINE_STRIP)
			for _,vtx in ipairs(lineStrip) do
				gl.glVertex3dv(self.game:transform(vtx):ptr())
			end
			gl.glEnd()
		end
	end

	for _,info in ipairs{
		{size=.3, list=self.pellets},
		{size=.7, list=self.pills},
	} do
		gl.glColor4d(1,1,1,.3)
		for _,pos in ipairs(info.list) do
			gl.glPushMatrix()
			local v = self.game:transform(pos)
			gl.glTranslated(v:unpack())
			gl.glScaled(info.size, info.size, info.size)
			cube:draw()	
			gl.glPopMatrix()
		end
	end
end

function Map:get(i,j,k)
	i = math.floor(i)
	j = math.floor(j)
	k = math.floor(k)
	i = i % self.size.x
	j = j % self.size.y
	k = k % self.size.z
	return self.data[i+self.size.x*(j+self.size.y*k)]
end

function Map:set(i,j,k,x)
	i = i % self.size.x
	j = j % self.size.y
	k = k % self.size.z
	self.data[i+self.size.x*(j+self.size.y*k)] = x
end

function Map:wrapPos(v)
	v = vec3d(v)
	for i=0,2 do
		v:ptr()[i] = v:ptr()[i] % tonumber(self.size:ptr()[i])
	end
	return v
end

return Map
