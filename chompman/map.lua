local class = require 'ext.class'
local table = require 'ext.table'
local vec3d = require 'ffi.vec.vec3d'
local vec4d = require 'ffi.vec.vec4d'
local ffi = require 'ffi'
local cube = require 'chompman.cube'
local gl = require 'ffi.OpenGL'
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
Map.numCols = vec3d(10,7,7)
--Map.numCols = vec3d(5,5,1)
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

	self.pellets = table()

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
	end
end

function Map:draw()
	local app = require 'chompman.app'.app
	local fwd = -vec3d(app.viewAngle:zAxis():unpack())
	local screenPushRadius = .15
	local mvPushRadius = 5

	local function transform(vtx)
		local distFromPlayer3DSq = (vtx - self.game.player.pos):lenSq()

		vtx = vtx - app.viewPos	-- vtx is now relative to the view position 
		
		local vfwd = fwd:dot(vtx)	-- vertex screen depth 
		vtx = vtx - fwd * vfwd	-- vtx is now in the view plane
		vtx = vtx / vfwd
		local screenDistSq = vtx:lenSq()

		if distFromPlayer3DSq > mvPushRadius * mvPushRadius then
			local screenDist = math.sqrt(screenDistSq)
			vtx = vtx * math.max(screenPushRadius, screenDist) / screenDist 
		end
		vtx = vtx * vfwd	
		vtx = vtx + fwd * vfwd

		vtx = vtx + app.viewPos
		return vtx
	end

--	self.drawList = self.drawList or {}
--	glCallOrDraw(self.drawList, function()
		--[[ draw solid
		gl.glColor4d(1, 1, 1, .01)
		--gl.glPolygonMode(gl.GL_FRONT_AND_BACK, gl.GL_LINE)
		local e = 0
		for k=0,self.size.z-1 do
			for j=0,self.size.y-1 do
				for i=0,self.size.x-1 do
					if self.data[e] ~= 0 then
						gl.glPushMatrix()
						gl.glTranslated(i,j,k)
--gl.glScaled(.5, .5, .5)
						cube:draw()
						gl.glPopMatrix()
					end
					e=e+1
				end
			end
		end
		--gl.glPolygonMode(gl.GL_FRONT_AND_BACK, gl.GL_POLYGON)
		--]]
		--[[ draw non-solid inverse
		gl.glColor4d(1, 1, 1, .01)
		gl.glCullFace(gl.GL_FRONT)
		local e = 0
		for k=0,self.size.z-1 do
			for j=0,self.size.y-1 do
				for i=0,self.size.x-1 do
					if self.data[e] == 0 then
						-- TODO only on edges
						gl.glPushMatrix()
						gl.glTranslated(i,j,k)
--gl.glScaled(.5, .5, .5)
						cube:draw(-1)
						gl.glPopMatrix()
					end
					e=e+1
				end
			end
		end
		gl.glCullFace(gl.GL_BACK)
		--]]	
		--[=[ draw wireframe
		gl.glColor3d(1, 1, 1)
		gl.glBegin(gl.GL_LINES)
		for k=1,self.size.z do
			for j=1,self.size.y do
				for i=1,self.size.x do
					for s1=0,2 do
						local s2 = (s1 + 1) % 3	
						local s3 = (s2 + 1) % 3	
						local i0 = vec3d(i,j,k)
						local i1 = vec3d(i,j,k)
						i1:ptr()[s1] = i1:ptr()[s1]-1
						local i2 = vec3d(i,j,k)
						i2:ptr()[s2] = i2:ptr()[s2]-1
						local i3 = vec3d(i,j,k)
						i3:ptr()[s1] = i3:ptr()[s1]-1
						i3:ptr()[s2] = i3:ptr()[s2]-1
						local v0 = 0 ~= self:get(i0:unpack())
						local v1 = 0 ~= self:get(i1:unpack())
						local v2 = 0 ~= self:get(i2:unpack())
						local v3 = 0 ~= self:get(i3:unpack())
					
						--[[
						local vand = v0 and v1 and v2 and v3
						local vor = v0 or v1 or v2 or v3
						if vor and not vand then
						--]]
						-- single edge
						if (v0 and not v1 and not v2 and not v3)
						or (not v0 and v1 and not v2 and not v3)
						or (not v0 and not v1 and v2 and not v3)
						or (not v0 and not v1 and not v2 and v3)
						-- opposing edges
						or (v0 and not v1 and not v2 and v3) 
						or (not v0 and v1 and v2 and not v3)
						-- triple edges
						or (v0 and v1 and v2 and not v3)
						or (v0 and v1 and not v2 and v3)
						or (v0 and not v1 and v2 and v3)
						or (not v0 and v1 and v2 and v3)
						then
							local ih = i0-.5
							gl.glVertex3d(ih:unpack())
							ih:ptr()[s3] = ih:ptr()[s3]+1
							gl.glVertex3d(ih:unpack())
						end
					end
				end
			end
		end	
		gl.glEnd()
		--]=]
		-- [=[ draw paths
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
							local color = vec4d(0,0,0,.75)
							color:ptr()[s1] = 1
							gl.glColor4d(color:unpack())
							gl.glBegin(gl.GL_LINE_STRIP)
							local fmax = 10
							for f=0,fmax do
								local v = vec3d(i0:unpack())
								v:ptr()[s1] = v:ptr()[s1] + f/fmax
								v = transform(v)
								gl.glVertex3d(v:unpack())
							end
							gl.glEnd()	
						end
					end
				end
			end
		end	
		--]=]
--	end)
	local pelletSize = .3
	gl.glColor4d(1,1,1,.3)
	for _,pellet in ipairs(self.pellets) do
		gl.glPushMatrix()
		local v = transform(pellet)
		gl.glTranslated(v:unpack())
		gl.glScaled(pelletSize,pelletSize,pelletSize)
		cube:draw()	
		gl.glPopMatrix()
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
