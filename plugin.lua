local bot = _BOT
local _G = _G

local cmd = require "ircbot.command"
local irc = require "irc"

local pluginMeta = {
	__index = function(o, k)
		local v = rawget(o, k)

		if v == nil then
			v = _G[k]
		end

		return v
	end
}

local function readonly(t)
	return setmetatable({}, {
		__index = t;
		__newindex = function()
			error("Table is read-only", 2)
		end;
	})
end

local function createPluginEnv(f, bot)
	local p = {}
	p.PLUGIN = p
	p.CONFIG = readonly(bot.config)
	function p.Command(name)
		return function(tbl)
			tbl.Plugin = p
			return cmd.RegisterCommand(name)(tbl)
		end
	end

	p.color, p.bold, p.underline = irc.color, irc.bold, irc.underline

	p.context = {}
	setfenv(f, p)
	
	return setmetatable(p, pluginMeta)
end

function bot:loadPlugin(path)
	local function raise(message)
		return nil, table.concat{"Error loading \"", path, "\": ", message}
	end
	
	local f, err = loadfile(path)
	if not f then
		return nil, err
	end

	local plugin = createPluginEnv(f, self)
	
	local succ, err = pcall(f)
	if not succ then
		return nil, err
	end

	if not plugin.Name then
		return raise("Plugin name not specified")
	end

	return plugin
end

function bot:loadPlugins(dir)
	local plugins = self.plugins
	
	for k, plugin in ipairs(plugins) do
		local unload = plugin.Unload
		if unload then
			unload()
		end
		plugins[k] = nil
	end

	local thinks = self.thinks
	for k = 1,#thinks do
		thinks[k] = nil
	end
	
	for path in lfs.dir(dir) do
		if path:match("%.lua$") then
			local plugin, err = self:loadPlugin(dir.."/"..path)
		
			if not plugin then
				return nil, err
			end

			local load = plugin.Load
			if load then
				load(self)
			end

			local think = plugin.Think
			if think then
				table.insert(thinks, think)
			end

			plugin.Path = path
			table.insert(plugins, plugin)
		end
	end

	return plugins
end
