require 'ext'
local class = require 'ext.class'
local ImGuiApp = require 'imguiapp'
local Mouse = require 'glapp.mouse'
local Game = require 'chompman.game'
local gl = require 'gl'
local ig = require 'imgui'
local sdl = require 'ffi.req' 'sdl'
local quat = require 'vec.quat'
local vec3d = require 'vec-ffi.vec3d'
local vec4f = require 'vec-ffi.vec4f'
local GLSceneObject = require 'gl.sceneobject'
local GLProgram = require 'gl.program'

local Audio = require 'audio'

local mouse = Mouse()

local App = ImGuiApp:subclass()
App.viewUseGLMatrixMode = true
App.title = 'ChompMan'

function App:initGL()
	App.super.initGL(self)

	self.viewPos = vec3d(0, 0, 0)
	self.viewAngle = 
		quat():fromAngleAxis(0,0,1,10) *
		quat():fromAngleAxis(1,0,0,45)

	self.audio = Audio()	-- audio system
	local SoundCache = require 'chompman.soundcache'
	self.sounds = SoundCache()

	do -- background music...
		local bgMusicFileName = 'background.wav' 
		if os.fileexists(bgMusicFileName ) then 
			local AudioBuffer = require 'audio.buffer'
			local AudioSource = require 'audio.source'
			
			local bgMusic = AudioBuffer(bgMusicFileName)	-- TODO specify by mod init or something
			local bgAudioSource = AudioSource()
			bgAudioSource:setBuffer(bgMusic)
			bgAudioSource:setLooping(true)
			bgAudioSource:setGain(.5)
			bgAudioSource:play()
		end
	end

	self.game = Game{app=self}
	self.viewDist = self.game.map.size.x
	self.viewPos = vec3d(0,0,self.viewDist) + self.game.player.pos

	gl.glEnable(gl.GL_CULL_FACE)
	gl.glEnable(gl.GL_DEPTH_TEST)

	local solidProgram = GLProgram{
		version = 'latest',
		precision = 'best',
		vertexCode = [[
in vec3 vertex;
uniform mat4 mvProjMat;
void main() {
	gl_Position = mvProjMat * vec4(vertex, 1.);
}
]],
		fragmentCode = [[
out vec4 fragColor;
uniform vec4 color;
void main() {
	fragColor = color;
}
]],
	}:useNone()

	solidTris = GLSceneObject{
		program = solidProgram,
		geometry = {
			mode = gl.GL_TRIANGLES,
		},
		vertexes = {
			type = gl.GL_FLOAT,
			dim = 3,
			useVec = true,
		},
		uniforms = {
			color = {1,1,1,1},
		},
	}

	solidLines = GLSceneObject{
		program = solidProgram,
		geometry = {
			mode = gl.GL_LINE_STRIP,
		},
		vertexes = {
			type = gl.GL_FLOAT,
			dim = 3,
			useVec = true,
		},
		uniforms = {
			color = {1,1,1,1},
		},
	}

	mvProjMat = require 'matrix.ffi'({4,4}, 'float'):zeros()
	solidTris.uniforms.mvProjMat = mvProjMat.ptr
	solidLines.uniforms.mvProjMat = mvProjMat.ptr
end

local Object = require 'chompman.object'
local dirForKey = {
	-- keys + pgup/pgdn
	[sdl.SDLK_DOWN] = Object.CMD_UP,
	[sdl.SDLK_UP] = Object.CMD_DOWN,
	[sdl.SDLK_LEFT] = Object.CMD_LEFT,
	[sdl.SDLK_RIGHT] = Object.CMD_RIGHT,
	[sdl.SDLK_END] = Object.CMD_FWD,
	[sdl.SDLK_HOME] = Object.CMD_BACK,
	-- numpad
	[sdl.SDLK_KP_2] = Object.CMD_UP,
	[sdl.SDLK_KP_8] = Object.CMD_DOWN,
	[sdl.SDLK_KP_4] = Object.CMD_LEFT,
	[sdl.SDLK_KP_6] = Object.CMD_RIGHT,
	[sdl.SDLK_KP_1] = Object.CMD_FWD,
	[sdl.SDLK_KP_7] = Object.CMD_BACK,


}

function App:event(event)
	App.super.event(self, event)
	if ig.igGetIO()[0].WantCaptureKeyboard then return end
	if event[0].type == sdl.SDL_MOUSEBUTTONDOWN then
		--[[
		if event[0].button.button == sdl.SDL_BUTTON_WHEELUP then
			viewDist = viewDist * zoomFactor
		elseif event[0].button.button == sdl.SDL_BUTTON_WHEELDOWN then
			viewDist = viewDist / zoomFactor
		end
		--]]
	elseif event[0].type == sdl.SDL_KEYDOWN or event[0].type == sdl.SDL_KEYUP then
		if event[0].key.keysym.sym == sdl.SDLK_LSHIFT then
			leftShiftDown = event[0].type == sdl.SDL_KEYDOWN
		elseif event[0].key.keysym.sym == sdl.SDLK_RSHIFT then
			rightShiftDown = event[0].type == sdl.SDL_KEYDOWN
		end
			
		local player = self.game.player
		if player then
			for key,dir in pairs(dirForKey) do
				if event[0].key.keysym.sym == key then
					if event[0].type == sdl.SDL_KEYDOWN then
						player.cmd = bit.bor(player.cmd, dir) 
					elseif event[0].type == sdl.SDL_KEYUP then
						player.cmd = bit.band(player.cmd, bit.bnot(dir))
					end
				end
			end
		end
	end

end

function App:update()
	mouse:update()

	if not ig.igGetIO()[0].WantCaptureKeyboard then 
		if mouse.leftDragging then
			--[[
			if leftShiftDown or rightShiftDown then
				viewDist = viewDist * math.exp(100 * zoomFactor * mouse.deltaPos[2])
			else --]] do
				local magn = mouse.deltaPos:length() * 1000
				if magn > 0 then
					local normDelta = mouse.deltaPos / magn
					local r = quat():fromAngleAxis(-normDelta.y, normDelta.x, 0, -magn)
					self.viewAngle = (self.viewAngle * r):normalize()
				end
			end
		end
	end

	self.viewPos = vec3d(
		self.viewAngle:rotate{
			0, 0, self.viewDist
		}:unpack()
	) + self.game.player.pos

	gl.glClear(bit.bor(gl.GL_COLOR_BUFFER_BIT, gl.GL_DEPTH_BUFFER_BIT))

	local ar = self.width / self.height
	local znear = 1
	local zfar = 1000
	local tanFov = .5
	mvProjMat:setFrustum(-ar * znear * tanFov, ar * znear * tanFov, -znear * tanFov, znear * tanFov, znear, zfar)

	local aa = self.viewAngle:toAngleAxis()
	mvProjMat:applyRotate(-aa[4], aa[1], aa[2], aa[3])
	mvProjMat:applyTranslate((-self.viewPos):unpack())

	gl.glDisable(gl.GL_DEPTH_TEST)
	gl.glBlendFunc(gl.GL_SRC_ALPHA, gl.GL_ONE_MINUS_SRC_ALPHA)
	gl.glEnable(gl.GL_BLEND)
	gl.glColor4d(1,1,1,.05)

	if not self.sysLastTime then self.sysLastTime = os.clock() end
	self.sysThisTime = os.clock()	
	self.sysDeltaTime = self.sysThisTime - self.sysLastTime
	local fps = 1/self.sysDeltaTime
	if not self.frameTimeLeft then self.frameTimeLeft = 0 end
	self.frameTimeLeft = self.frameTimeLeft + self.sysDeltaTime
	self.dt = 1/50
	while self.frameTimeLeft > self.dt do
		self.frameTimeLeft = self.frameTimeLeft - self.dt
		self.game:update(self.dt)
	end	
	self.sysLastTime = self.sysThisTime

	self.game:draw()

	App.super.update(self)
end

function App:updateGUI()
	local player = self.game.player
	local map = self.game.map
end

function App:exit(...)
	App.super.exit(self, ...)
	self.audio:shutdown()
end

return App
