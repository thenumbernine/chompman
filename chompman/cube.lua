local vec3d = require 'ffi.vec.vec3d'
local gl = require 'gl'

local cube = {
	vtxIndexes = {
		3,4,2,1,
		5,6,8,7,
		1,2,6,5,
		2,4,8,6,
		4,3,7,8,
		3,1,5,7,
	},
	vtxs = {
		vec3d(-.5,-.5,-.5),
		vec3d(.5,-.5,-.5),
		vec3d(-.5,.5,-.5),
		vec3d(.5,.5,-.5),
		vec3d(-.5,-.5,.5),
		vec3d(.5,-.5,.5),
		vec3d(-.5,.5,.5),
		vec3d(.5,.5,.5),
	},
	normalIndexes = {
		5,5,5,5,
		6,6,6,6,
		3,3,3,3,
		2,2,2,2,
		4,4,4,4,
		1,1,1,1,
	},
	normals = {
		vec3d(1,0,0),
		vec3d(-1,0,0),
		vec3d(0,1,0),
		vec3d(0,-1,0),
		vec3d(0,0,1),
		vec3d(0,0,-1),
	},
}

function cube:draw(normalScale)
	normalScale = normalScale or 1
	gl.glBegin(gl.GL_QUADS)
	for i=1,#self.vtxIndexes do
		local n = self.normals[self.normalIndexes[i]]
		gl.glNormal3d((n * normalScale):unpack())
		local v = self.vtxs[self.vtxIndexes[i]]
		gl.glVertex3d(v:unpack())
	end
	gl.glEnd()
end

return cube
