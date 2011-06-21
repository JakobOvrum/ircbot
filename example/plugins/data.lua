--[[
	Data storage
  
  note: this plugin requires state which you can get from the following url:
	https://github.com/TheLinx/lstate
]]
Name = "Data Storage"
Hidden = true

-- comment to enable this plugin
disable()

local state = require("state")
local cfg = CONFIG.data

local function load()
	local saved = state.load(cfg.name)
	if saved then public = saved end
end
local function save()
	state.store(cfg.name, public)
end

function Load()
	load()
end
function Unload()
	save()
end

Hook "Think"
{
	function()
		save()
		wait(cfg.saveInterval)
	end
}
