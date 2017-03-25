local class = require 'ext.class'
local vec3d = require 'ffi.vec.vec3d'
local Object = require 'chompman.object'

local Player = class(Object)

function Player:init(...)
	Player.super.init(self, ...)
	self.color:set(1,1,0)
end

function Player:update(...)
	if self.deadTime then 
		self.size = vec3d(1,1,1) * math.max(0, 1 - (self.game.time - self.deadTime))
		return 
	end
	Player.super.update(self, ...)
	if self.moveFrac == 0 then
		local map = self.game.map
		local pi = map.pellets:find(nil, function(pellet)
			return math.floor(pellet.x) == math.floor(self.pos.x)
				and math.floor(pellet.y) == math.floor(self.pos.y)
				and math.floor(pellet.z) == math.floor(self.pos.z)
		end)
		if pi then
			map.pellets:remove(pi)
			self:playSound'pellet'
		end
	end
end

function Player:die()
	self.deadTime = self.game.time 
	self:playSound'die'
end

return Player
