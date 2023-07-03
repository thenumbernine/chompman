#!/usr/bin/env luajit
local App = require 'chompman.app'
local app = App()
math.randomseed(os.time())
return app:run()
