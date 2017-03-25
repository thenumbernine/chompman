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

function Game:init()
	self.map = Map{game=self}

	self.objs = table()
	self.player = Player{
		game = self,
		pos = self.map.center + vec3d(8, 0, 0),
	}
	self.players = table{self.player}
	self.ghosts = range(self.numGhosts):map(function(i)
		return Ghost{
			game = self,
			pos = self.map.center,
		}
	end)

	local audio = require 'chompman.app'.app.audio
	audio:setDistanceModel('linear clamped')
	self.audioSourceIndex = 0
	-- 31 for DirectSound, 32 for iphone, infinite for all else?
	self.audioSources = range(32):map(function()
		local src = AudioSource()
		src:setReferenceDistance(math.max(
			self.map.size:unpack()
		))
		src:setMaxDistance(self.maxAudioDist)
		src:setRolloffFactor(1)
		return src
	end)
end

function Game:draw()
	for _,obj in ipairs(self.objs) do
		obj:draw()
	end

	self.map:draw()
end

function Game:update()
	for _,obj in ipairs(self.objs) do
		obj:update()
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
