local class = require 'ext.class'
local vec3d = require 'ffi.vec.vec3d'
local gl = require 'ffi.OpenGL'
local cube = require 'chompman.cube'

local Object = class()

Object.size = vec3d(1,1,1)

function Object:init(args)
	self.game = assert(args.game)
	self.game.objs:insert(self)

	self.pos = self.game.map:wrapPos(vec3d(args.pos))
	self.destPos = vec3d(self.pos)

	self.moveFrac = 0
	self.speed = 5/50
	self.srcPos = vec3d(self.pos:unpack())
	self.destPos = vec3d(self.pos:unpack())

	self.color = vec3d(
		math.random(),
		math.random(),
		math.random()):normalize()
end

Object.CMD_LEFT = 1
Object.CMD_RIGHT = 2
Object.CMD_UP = 4
Object.CMD_DOWN = 8
Object.CMD_FWD = 16
Object.CMD_BACK = 32
Object.cmd = 0
Object.dir = 0

function Object:update()
	if self.srcPos ~= self.destPos then
		self.moveFrac = self.moveFrac + self.speed
		if self.moveFrac >= 1 then
			self.moveFrac = 0
			local map = self.game.map
			self.destPos = map:wrapPos(self.destPos)
			self.pos:set(self.destPos)
			self.srcPos:set(self.pos)
		else
			self.pos = self.destPos * self.moveFrac + self.srcPos * (1 - self.moveFrac)
		end
	else
		for _,cmd in ipairs{self.CMD_LEFT, self.CMD_RIGHT, self.CMD_UP, self.CMD_DOWN, self.CMD_FWD, self.CMD_BACK} do
			local canMove = self:canMove(cmd)
			if bit.band(self.cmd, cmd) ~= 0 then
				if canMove then
					self.dir = cmd
				end
			end
		end
		if self:canMove(self.dir) then
			self:doMove(self.dir)
		end
	end
end

function Object:canMove(dir)
	local map = self.game.map
	if dir == self.CMD_LEFT then
		return map:get((self.pos + vec3d(-1,0,0)):unpack()) == map.TYPE_EMPTY
	elseif dir == self.CMD_RIGHT then
		return map:get((self.pos + vec3d(1,0,0)):unpack()) == map.TYPE_EMPTY
	elseif dir == self.CMD_UP then
		return map:get((self.pos + vec3d(0,-1,0)):unpack()) == map.TYPE_EMPTY
	elseif dir == self.CMD_DOWN then
		return map:get((self.pos + vec3d(0,1,0)):unpack()) == map.TYPE_EMPTY
	elseif dir == self.CMD_FWD then
		return map:get((self.pos + vec3d(0,0,-1)):unpack()) == map.TYPE_EMPTY
	elseif dir == self.CMD_BACK then
		return map:get((self.pos + vec3d(0,0,1)):unpack()) == map.TYPE_EMPTY
	end
end

function Object:doMove(dir)
	if dir == self.CMD_LEFT then
		self.destPos = self.pos + vec3d(-1,0,0)
	elseif dir == self.CMD_RIGHT then
		self.destPos = self.pos + vec3d(1,0,0)
	elseif dir == self.CMD_UP then
		self.destPos = self.pos + vec3d(0,-1,0)
	elseif dir == self.CMD_DOWN then
		self.destPos = self.pos + vec3d(0,1,0)
	elseif dir == self.CMD_FWD then
		self.destPos = self.pos + vec3d(0,0,-1)
	elseif dir == self.CMD_BACK then
		self.destPos = self.pos + vec3d(0,0,1)
	end
end

function Object:draw()
	gl.glColor3d(self.color:unpack())
	gl.glPushMatrix()
	gl.glTranslated(self.pos:unpack())
	gl.glScaled(self.size:unpack())
	cube:draw()
	gl.glPopMatrix()
end

return Object
