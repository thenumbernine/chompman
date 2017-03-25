local class = require 'ext.class'
local Object = require 'chompman.object'

local Player = class(Object)

function Player:init(...)
	Player.super.init(self, ...)
	self.color:set(1,1,0)
end

function Player:update(...)
	Player.super.update(self, ...)
	local map = self.game.map
	local pi = map.pellets:find(nil, function(pellet)
		return math.floor(pellet.x) == math.floor(self.pos.x)
			and math.floor(pellet.y) == math.floor(self.pos.y)
			and math.floor(pellet.z) == math.floor(self.pos.z)
	end)
	if pi then
		map.pellets:remove(pi)
	end
end

return Player
