local class = require 'ext.class'
local table = require 'ext.table'
local range = require 'ext.range'
local vec3d = require 'ffi.vec.vec3d'
local Map = require 'chompman.map'
local Player = require 'chompman.player'
local Ghost = require 'chompman.ghost'
local AudioSource = require 'audio.source'

local Game = class()

Game.maxAudioDist = 100
Game.volume = 1

Game.numGhosts = 4

function Game:init(args)
	self.time = 0

	self.app = args.app

	-- maybe this should go in App:init ... 
	local audio = self.app.audio
	audio:setDistanceModel'linear clamped'
	self.audioSourceIndex = 0
	-- 31 for DirectSound, 32 for iphone, infinite for all else?
	self.audioSources = range(32):map(function()
		local src = AudioSource()
		src:setReferenceDistance(math.max(
			Map.size:unpack()
		))
		src:setMaxDistance(self.maxAudioDist)
		src:setRolloffFactor(1)
		return src
	end)
	
	self.map = Map{game=self}

	self.objs = table()
	self.player = Player{
		game = self,
		pos = self.map.center + vec3d(self.map.colSize * 2, 0, 0),
	}
	self.players = table{self.player}
	
	local colors = {
		vec3d(1,0,0),	-- red
		vec3d(1,0,1),	-- pink 
		vec3d(0,1,1),	-- cyan 
		vec3d(1,.5,0),	-- orange
	}
	
	self.ghosts = range(self.numGhosts):map(function(i)
		return Ghost{
			game = self,
			pos = self.map.center,
			color = colors[(i-1)%#colors+1],
		}
	end)
end

-- how far from the player points are to be pushed out of the way 
Game.mvPushRadius = 3
-- coeff of how smooth they are pushed in 3D space
Game.push3DCoeff = 3
-- coeff of how smooth they are pushed in 2D space
Game.push2DCoeff = 3

function Game:draw()
	-- used for Game:transform	
	self.viewFwd = -vec3d(self.app.viewAngle:zAxis():unpack())
	--[[ fixed radius
	local screenPushRadius = .15
	--]]
	-- [[ this should be the screen distance of the modelview push radius at the player's distance from the camera
	local viewToPlayer = self.player.pos - self.app.viewPos
	local playerDist = self.viewFwd:dot(viewToPlayer)
	self.screenPushRadius = self.mvPushRadius / playerDist
	--]]
	
	for _,obj in ipairs(self.objs) do
		obj:draw()
	end

	self.map:draw()
end

function Game:transform(vtx)
	local distFromPlayer3DSq = (vtx - self.player.pos):lenSq()

	vtx = vtx - self.app.viewPos	-- vtx is now relative to the view position 
	
	local vtxFwd = self.viewFwd:dot(vtx)	-- vertex screen depth 
	vtx = vtx - self.viewFwd * vtxFwd	-- vtx is now in the view plane
	vtx = vtx / vtxFwd
	local screenDistSq = vtx:lenSq()

	-- pushInfl is whether we want to push the point outward
	--[[ C0-continuous 
	local pushExp = (distFromPlayer3DSq < self.mvPushRadius * self.mvPushRadius) and 0 or 1
	--]]
	-- [[ C-inf
	local pushExp = .5 + .5 * math.tanh(self.push3DCoeff * (math.sqrt(distFromPlayer3DSq) - self.mvPushRadius))
	--]]
	
	local screenDist = math.sqrt(screenDistSq)
		
	-- scale back, but with the near-screenPushRadius points pushed back past screenPushRadius
	-- using a ramp function
	--[[ C0 option would be:
	local scale = math.max(self.screenPushRadius, screenDist) / screenDist
	--]]
	-- [[ C-inf option:
	local scale = (self.screenPushRadius 
			+ math.log(1 
				+ math.exp(self.push2DCoeff * (screenDist - self.screenPushRadius))
			) / self.push2DCoeff
		) / screenDist
	--]]
	vtx = vtx * math.pow(scale, pushExp)
	
	vtx = vtx * vtxFwd	
	vtx = vtx + self.viewFwd * vtxFwd

	vtx = vtx + self.app.viewPos

	return vtx
end

function Game:update(dt)
	self.dt = dt
	self.time = self.time + dt
	for _,obj in ipairs(self.objs) do
		obj:update(dt)
	end
end

function Game:getNextAudioSource()
	if #self.audioSources == 0 then return end
	local startIndex = self.audioSourceIndex
	repeat
		self.audioSourceIndex = self.audioSourceIndex % #self.audioSources + 1
		local source = self.audioSources[self.audioSourceIndex]
		if not source:isPlaying() then
			return source
		end
	until self.audioSourceIndex == startIndex
end

return Game
