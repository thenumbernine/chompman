local class = require 'ext.class'
local AudioBuffer = require 'audio.buffer'
local ResourceCache = require 'resourcecache'

local SoundCache = class(ResourceCache)

function SoundCache:loaduncached(filename)
	return AudioBuffer(filename)
end

return SoundCache
