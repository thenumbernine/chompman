local class = require 'ext.class'
local table = require 'ext.table'
local range = require 'ext.range'
local vec3d = require 'ffi.vec.vec3d'
local Map = require 'chompman.map'
local Player = require 'chompman.player'
local Ghost = require 'chompman.ghost'

local Game = class()

Game.numGhosts = 4

function Game:init()
	self.map = Map{game=self}

	self.objs = table()
	self.player = Player{
		game = self,
		pos = self.map.center + vec3d(8, 0, 0),
	}
	self.ghosts = range(self.numGhosts):map(function(i)
		return Ghost{
			game = self,
			pos = self.map.center,
		}
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

return Game
