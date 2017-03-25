require 'ext'
local class = require 'ext.class'
local ImGuiApp = require 'imguiapp'
local Game = require 'chompman.game'
local gl = require 'ffi.OpenGL'
local ig = require 'ffi.imgui'
local sdl = require 'ffi.sdl'
local quat = require 'vec.quat'
local Mouse = require 'gui.mouse'
local vec3d = require 'ffi.vec.vec3d'
local vec4f = require 'ffi.vec.vec4f'
local GLProgram = require 'gl.program'

local mouse = Mouse()

local App = class(ImGuiApp)

App.title = 'ChompMan'

function App:initGL(...)
	App.super.initGL(self, ...)
	
	App.app = self	-- singleton

	self.viewPos = vec3d(0, 0, 0)
	self.viewAngle = 
		quat():fromAngleAxis(0,0,1,45) *
		quat():fromAngleAxis(1,0,0,45)

	self.game = Game()
	self.viewDist = self.game.map.size.x
	self.viewPos = vec3d(0,0,self.viewDist) + self.game.player.pos

	gl.glEnable(gl.GL_CULL_FACE)
	gl.glEnable(gl.GL_DEPTH_TEST)
--[=[

	self.mainShader = GLProgram{
		vertexCode = [[
uniform vec3 playerPos;
uniform float aspectRatio;
varying vec4 color;

float cosh(float x) {
	return .5 * (exp(x) + exp(-x));
}

float sinh(float x) {
	return .5 * (exp(x) - exp(-x));
}

float tanh(float x) {
	return sinh(x) / cosh(x);
}

void main() {
	
	vec4 plrScrPos = gl_ProjectionMatrix * vec4(playerPos, 1.);
	vec3 plrDncPos = plrScrPos.xyz / plrScrPos.w;

	vec3 pos = gl_Vertex.xyz;
	vec4 mvPos = gl_ModelViewMatrix * vec4(pos, 1.);
	vec4 scrPos = gl_ProjectionMatrix * mvPos;
	vec3 dncPos = scrPos.xyz / scrPos.w;
	
	vec3 deltaMvPos = playerPos.xyz - mvPos.xyz;
	float mvLen = length(deltaMvPos);

	dncPos.xyz -= plrDncPos.xyz;
	dncPos.x *= aspectRatio;
	float scrLen = length(dncPos.xy);
	//if (scrPos.z < plrScrPos.z - 1.) {
	if (mvLen > 4.) {
		//dncPos.xy *= log(1. + exp(scrLen));
		//dncPos.xy *= 1. + 10. * exp(-10. * scrLen);
		//dncPos.xy *= cosh(scrLen) / scrLen;
		dncPos.xy *= max(scrLen, .5) / scrLen;
	}
	dncPos.x /= aspectRatio;
	dncPos.xyz += plrDncPos.xyz;

	color = gl_Color;

	gl_Position = vec4(dncPos, 1.);
}
]],
		fragmentCode = [[
varying vec4 color;
void main() {
	gl_FragColor = color;
}
]],
	}

	self.mainShader:use()

--]=]
end

function App:event(event, ...)
	App.super.event(self, event, ...)
	if ig.igGetIO()[0].WantCaptureKeyboard then return end
	if event.type == sdl.SDL_MOUSEBUTTONDOWN then
		--[[
		if event.button.button == sdl.SDL_BUTTON_WHEELUP then
			viewDist = viewDist * zoomFactor
		elseif event.button.button == sdl.SDL_BUTTON_WHEELDOWN then
			viewDist = viewDist / zoomFactor
		end
		--]]
	elseif event.type == sdl.SDL_KEYDOWN or event.type == sdl.SDL_KEYUP then
		if event.key.keysym.sym == sdl.SDLK_LSHIFT then
			leftShiftDown = event.type == sdl.SDL_KEYDOWN
		elseif event.key.keysym.sym == sdl.SDLK_RSHIFT then
			rightShiftDown = event.type == sdl.SDL_KEYDOWN
		end
		
		local player = self.game.player
		if event.type == sdl.SDL_KEYDOWN then
			if event.key.keysym.sym == sdl.SDLK_UP then
				player.cmd = bit.bor(player.cmd, self.game.player.CMD_UP)
			elseif event.key.keysym.sym == sdl.SDLK_DOWN then
				player.cmd = bit.bor(player.cmd, self.game.player.CMD_DOWN)
			elseif event.key.keysym.sym == sdl.SDLK_LEFT then
				player.cmd = bit.bor(player.cmd, self.game.player.CMD_LEFT)
			elseif event.key.keysym.sym == sdl.SDLK_RIGHT then
				player.cmd = bit.bor(player.cmd, self.game.player.CMD_RIGHT)
			elseif event.key.keysym.sym == sdl.SDLK_PAGEUP then
				player.cmd = bit.bor(player.cmd, self.game.player.CMD_FWD)
			elseif event.key.keysym.sym == sdl.SDLK_PAGEDOWN then
				player.cmd = bit.bor(player.cmd, self.game.player.CMD_BACK)
			end
		elseif event.type == sdl.SDL_KEYUP then
			if event.key.keysym.sym == sdl.SDLK_UP then
				player.cmd = bit.band(player.cmd, bit.bnot(self.game.player.CMD_UP))
			elseif event.key.keysym.sym == sdl.SDLK_DOWN then
				player.cmd = bit.band(player.cmd, bit.bnot(self.game.player.CMD_DOWN))
			elseif event.key.keysym.sym == sdl.SDLK_LEFT then
				player.cmd = bit.band(player.cmd, bit.bnot(self.game.player.CMD_LEFT))
			elseif event.key.keysym.sym == sdl.SDLK_RIGHT then
				player.cmd = bit.band(player.cmd, bit.bnot(self.game.player.CMD_RIGHT))
			elseif event.key.keysym.sym == sdl.SDLK_PAGEUP then
				player.cmd = bit.band(player.cmd, bit.bnot(self.game.player.CMD_FWD))
			elseif event.key.keysym.sym == sdl.SDLK_PAGEDOWN then
				player.cmd = bit.band(player.cmd, bit.bnot(self.game.player.CMD_BACK))
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
					local r = quat():fromAngleAxis(-normDelta[2], normDelta[1], 0, -magn)
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

	gl.glMatrixMode(gl.GL_PROJECTION)
	gl.glLoadIdentity()
	local ar = self.width / self.height
	local znear = 1
	local zfar = 1000
	local tanFov = .5
	gl.glFrustum(-ar * znear * tanFov, ar * znear * tanFov, -znear * tanFov, znear * tanFov, znear, zfar)

	gl.glMatrixMode(gl.GL_MODELVIEW)
	gl.glLoadIdentity()

	--[[
	gl.glEnable(gl.GL_LIGHTING)
	gl.glEnable(gl.GL_LIGHT0)
	gl.glLightfv(gl.GL_LIGHT0, gl.GL_POSITION, vec4f(0,0,-1,0):ptr())
	--]]

	local aa = self.viewAngle:toAngleAxis()
	gl.glRotated(-aa[4], aa[1], aa[2], aa[3])

	gl.glTranslated((-self.viewPos):unpack())

	if self.mainShader then
		if self.mainShader.uniforms.playerPos then
			gl.glUniform3f(self.mainShader.uniforms.playerPos.loc, self.game.player.pos:unpack())
		end
		if self.mainShader.uniforms.aspectRatio then
			gl.glUniform1f(self.mainShader.uniforms.aspectRatio.loc, self.width / self.height)
		end
	end

	-- [[
	gl.glDisable(gl.GL_DEPTH_TEST)
	gl.glBlendFunc(gl.GL_SRC_ALPHA, gl.GL_ONE)
	gl.glEnable(gl.GL_BLEND)
	gl.glColor4d(1,1,1,.05)
	--]]

	if not self.sysLastTime then self.sysLastTime = os.clock() end
	self.sysThisTime = os.clock()	
	self.sysDeltaTime = self.sysThisTime - self.sysLastTime
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
	ig.igText('map.center: '..map.center)
	ig.igText('player pos: '..player.pos)
	ig.igText('player cmd: '..player.cmd)
	ig.igText('player dir: '..player.dir)
	ig.igText('player:canMove(dir): '..player:canMove(player.dir))
	ig.igText('map:get(player.pos): '..map:get(player.pos:unpack()))
end

return App
