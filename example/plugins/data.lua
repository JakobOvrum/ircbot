--[[
	Data storage
  
  note: this plugin requires luaSolidState which you can get from the following url:
    http://github.com/TheLinx/luaSolidState
]]
require("state")

PLUGIN.Name = "Data Storage"
public.data = {}

local cfg = CONFIG.data

function Load()
	local saved = state.load(cfg.name)
  if saved then public.data = saved end
end

function Unload()
	state.store(cfg.name, public.data)
end

Hook "Think"
{
	lastSave = os.time();

	function()
		if lastSave+cfg.saveInterval < os.time() then
			state.store(cfg.name, public.data)
			lastSave = os.time()
		end
	end
}