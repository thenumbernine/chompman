local class = require 'ext.class'
local Object = require 'chompman.object'

local Ghost = class(Object)

function Ghost:update(...)
	Ghost.super.update(self, ...)

	-- if a move finished then issue a new command
	if self.moveFrac == 0 then
		self.cmd = self.dirs[math.random(1,#self.dirs)]
	end

	for _,player in ipairs(self.game.players) do
		local delta = player.pos - self.pos
		local distSq = delta:lenSq()
		if distSq <= (math.max(self.size:unpack()) + math.max(player.size:unpack()))^2 then
			player:die()
		end
	end
end

return Ghost
