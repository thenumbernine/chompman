local class = require 'ext.class'
local vec3d = require 'vec-ffi.vec3d'
local vec4d = require 'vec-ffi.vec4d'
local cube = require 'chompman.cube'

local Object = class()

Object.size = vec3d(1,1,1)

function Object:init(args)
	self.game = assert(args.game)
	self.game.objs:insert(self)

	self.pos = self.game.map:wrapPos(vec3d(args.pos))
	self.vel = vec3d()
	self.destPos = vec3d(self.pos)

	self.moveFrac = 0
	self.speed = 5/50
	self.srcPos = vec3d(self.pos:unpack())
	self.destPos = vec3d(self.pos:unpack())

	local v = args.color
	and vec3d(args.color)
	or vec3d(
		math.random(),
		math.random(),
		math.random()):normalize()
	self.color = vec4d(v.x, v.y, v.z, 1)
end

Object.CMD_LEFT = 1
Object.CMD_RIGHT = 2
Object.CMD_UP = 4
Object.CMD_DOWN = 8
Object.CMD_FWD = 16
Object.CMD_BACK = 32
Object.cmd = 0
Object.dir = 0

Object.dirs = table{
	Object.CMD_LEFT,
	Object.CMD_RIGHT,
	Object.CMD_UP,
	Object.CMD_DOWN,
	Object.CMD_FWD,
	Object.CMD_BACK,
}

local oppositeDir = {
	[Object.CMD_LEFT] = Object.CMD_RIGHT,
	[Object.CMD_RIGHT] = Object.CMD_LEFT,
	[Object.CMD_UP] = Object.CMD_DOWN,
	[Object.CMD_DOWN] = Object.CMD_UP,
	[Object.CMD_FWD] = Object.CMD_BACK,
	[Object.CMD_BACK] = Object.CMD_FWD,
}

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
		for _,cmd in ipairs(self.dirs) do
			do --if cmd ~= oppositeDir[self.dir] then
				if bit.band(self.cmd, cmd) ~= 0 then
					if self:canMove(cmd) then
						self.dir = cmd
					end
				end
			end
		end
		if self:canMove(self.dir) then
			self:doMove(self.dir)
		else
			self.dir = 0	-- TODO moveDir vs displayDir
			self.vel:set(0,0,0)
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
		self.vel:set(-1,0,0)
	elseif dir == self.CMD_RIGHT then
		self.vel:set(1,0,0)
	elseif dir == self.CMD_UP then
		self.vel:set(0,-1,0)
	elseif dir == self.CMD_DOWN then
		self.vel:set(0,1,0)
	elseif dir == self.CMD_FWD then
		self.vel:set(0,0,-1)
	elseif dir == self.CMD_BACK then
		self.vel:set(0,0,1)
	end
	self.destPos = self.pos + self.vel
end

function Object:getColor()
	return self.color
end

function Object:draw()
	solidTris.uniforms.color = {self:getColor():unpack()}
	local push = mvProjMat:clone()
	mvProjMat:applyTranslate(self.game:transform(self.pos):unpack())
	mvProjMat:applyScale(self.size:unpack())
	cube:draw()
	mvProjMat:copy(push)
end

function Object:playSound(name, volume, pitch)
	local game = self.game
	-- openal supports only one listener
	-- rather than reposition the listener according to what player is closest ... position the sound!
	-- and don't bother with listener velocity
	local closestPlayer, closestDistSq
	-- TODO only cycle through local connections
	for _,player in ipairs(self.game.players) do
		local delta = player.pos - self.pos
		local distSq = delta:lenSq()	-- TODO use lattice metric ... for sounds as well as graphics
		if not closestDistSq or closestDistSq > distSq then
			closestDistSq = distSq
			closestPlayer = player
		end
	end
	if closestDistSq > game.maxAudioDist * game.maxAudioDist then return end

	-- clientside ...
	local source = game:getNextAudioSource()
	if not source then
		print('all audio sources used')
		return
	end

	local sounds = self.game.app.sounds
	local sound = sounds:load('sounds/'..name..'.wav')
	source:setBuffer(sound)
	source:setGain((volume or 1) * game.volume)
	source:setPitch(pitch or 1)
	source:setPosition((self.pos - closestPlayer.pos):unpack())
	source:setVelocity((self.vel - closestPlayer.vel):unpack())
	source:play()

	return source
end

return Object
