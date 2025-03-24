local vec3d = require 'vec-ffi.vec3d'

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
	--normalScale = normalScale or 1
	local vtxs = solidTris:beginUpdate()
	for i=1,#self.vtxIndexes,4 do
		-- TODO also normals?
		vtxs:emplace_back():set(self.vtxs[self.vtxIndexes[i+0]]:unpack())
		vtxs:emplace_back():set(self.vtxs[self.vtxIndexes[i+1]]:unpack())
		vtxs:emplace_back():set(self.vtxs[self.vtxIndexes[i+2]]:unpack())

		vtxs:emplace_back():set(self.vtxs[self.vtxIndexes[i+2]]:unpack())
		vtxs:emplace_back():set(self.vtxs[self.vtxIndexes[i+3]]:unpack())
		vtxs:emplace_back():set(self.vtxs[self.vtxIndexes[i+0]]:unpack())
	end
	solidTris:endUpdate()
end

return cube
