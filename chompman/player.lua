local class = require 'ext.class'
local vec3d = require 'vec-ffi.vec3d'
local Object = require 'chompman.object'

local Player = class(Object)

function Player:init(...)
	Player.super.init(self, ...)
	self.color:set(1,1,0,1)
end

function Player:update(...)
	if self.deadTime then
		self.size = vec3d(1,1,1) * math.max(0, 1 - (self.game.time - self.deadTime))
		return
	end
	Player.super.update(self, ...)
	if self.moveFrac == 0 then
		local map = self.game.map
		local pi = map.pellets:find(nil, function(pos)
			return math.floor(pos.x) == math.floor(self.pos.x)
				and math.floor(pos.y) == math.floor(self.pos.y)
				and math.floor(pos.z) == math.floor(self.pos.z)
		end)
		if pi then
			map.pellets:remove(pi)
--			self:playSound'pacman_chomp'
		end

		local pi = map.pills:find(nil, function(pos)
			return math.floor(pos.x) == math.floor(self.pos.x)
				and math.floor(pos.y) == math.floor(self.pos.y)
				and math.floor(pos.z) == math.floor(self.pos.z)
		end)
		if pi then
			map.pills:remove(pi)
			self.game.pillTime = self.game.time + self.game.pillDuration
		end

		if #map.pellets == 0
		and #map.pills == 0
		then
			self:playSound'pacman_intermission'
			-- ... and end the level
		end
	end
end

function Player:die()
	self.deadTime = self.game.time
--	self:playSound'pacman_death'
end

return Player
