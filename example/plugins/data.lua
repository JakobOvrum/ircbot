--[[
	Data storage

  note: this plugin requires luaSolidState which you can get from the following url:
    http://github.com/TheLinx/luaSolidState
]]
local state = require("state")

PLUGIN.Name = "Data Storage"

local cfg = CONFIG.data

function Load()
	local saved = state.load(cfg.name)
	if saved then public = saved end
end

function Unload()
	state.store(cfg.name, public)
end

Hook "Think"
{
	lastSave = os.time();

	function()
		if lastSave+cfg.saveInterval < os.time() then
			state.store(cfg.name, public)
			lastSave = os.time()
		end
	end
}