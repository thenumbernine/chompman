local table = require 'ext.table'
local Object = require 'chompman.object'
local vec3d = require 'vec-ffi.vec3d'

local Ghost = Object:subclass()

function Ghost:update(...)
	Ghost.super.update(self, ...)

	if not self.eyesOnly then
		-- if a move finished then issue a new command
		if self.moveFrac == 0 then
			self.cmd = self.dirs[math.random(1,#self.dirs)]
		end

		for _,player in ipairs(self.game.players) do
			if not player.deadTime then
				local delta = player.pos - self.pos
				local distSq = delta:lenSq()
				if distSq <= (math.max(self.size:unpack()) + math.max(player.size:unpack()))^2 then
					-- if we're in pill form then eat the ghost
					if self.game.pillTime >= self.game.time then
						self:die()
					-- otherwise, the ghost eats you
					else
						player:die()
					end
				end
			end
		end
	else
	-- go back to the base
	end
end

function Ghost:die()
	self:playSound'pacman_eatghost'
	self.eyesOnly = true
end

Ghost.eyeSize = .25

function Ghost:draw(...)
	if self.eyesOnly then
		solidTris.uniforms.color = {1,1,1,1}
		for _,ofs in ipairs{vec3d(-.25,0,.25),vec3d(.25,0,.25)} do
			local push = view.mvMat:clone()
			view.mvMat:applyTranslate(self.game:transform(self.pos + ofs):unpack())
			view.mvMat:applyScale(self.eyeSize,self.eyeSize,self.eyeSize)
			cube:draw()
			view.mvMat:set(push)
		end
	else
		Ghost.super.draw(self, ...)
	end
end

function Ghost:getColor(...)
	local pillTimeLeft = self.game.pillTime - self.game.time
	local flashTime = 1
	-- flash for the last few seconds
	if (pillTimeLeft >= 0
		and math.floor(pillTimeLeft*10)%2 == 0
	) or pillTimeLeft >= flashTime then
		return vec3d(0,0,1)
	end
	return Ghost.super.getColor(self, ...)
end

return Ghost
