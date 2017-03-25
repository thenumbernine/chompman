local class = require 'ext.class'
local Object = require 'chompman.object'

local Ghost = class(Object)

function Ghost:update(...)
	Ghost.super.update(self, ...)

	-- if a move finished then issue a new command
	if self.moveFrac == 0 then
		self.cmd = self.dirs[math.random(1,#self.dirs)]
	end
end

return Ghost
