local lfs = require "lfs"
local irc = require "irc"

local setmetatable = setmetatable
local error = error
local setfenv = setfenv
local loadfile = loadfile
local pcall = pcall
local pairs = pairs
local ipairs = ipairs
local table = table

local shared = setmetatable({}, {__index = _G})

module "ircbot"

local bot = _META

local function readonly(t)
	return setmetatable({}, {
		__index = t;
		__newindex = function()
			error("Table is read-only", 2)
		end;
	})
end

function bot:unloadPlugins()
	local plugins = self.plugins
	
	for k, plugin in ipairs(plugins) do
		local unload = plugin.Unload
		if unload then
			unload()
		end
		
		shared[plugin.ModuleName] = nil
		plugins[k] = nil
	end

	local thinks = self.thinks
	for k = 1,#thinks do
		thinks[k] = nil
	end

	if self:hasCommandSystem() then
		self:flushCommands()
	end
end

function bot:loadPlugin(path)
	local modname = path:match("/(.-).lua$")
	local function raise(message)
		return nil, table.concat{"Error loading plugin \"", modname, "\": ", message}
	end
	
	local f, err = loadfile(path)
	if not f then 
		return raise(err)
	end

	local p = {
		color = irc.color;
		bold = irc.bold;
		underline = irc.underline;

		CONFIG = readonly(self.config);
		public = {};
		
		ModuleName = modname;
		Path = path;
	}
	p.PLUGIN = p
	setmetatable(p, {__index = shared})
	shared[modname] = p.public

	if self:hasCommandSystem() then
		self:initCommandSystem(p)
	end
	
	setfenv(f, p)
	
	local succ, err = pcall(f)
	if not succ then
		return raise(err)
	end

	if not p.Name then
		return raise("Plugin name not specified")
	end

	p.CommandPrefix = p.CommandPrefix or "!"

	local load = p.Load
	if load then
		load(self)
	end

	local think = p.Think
	if think then
		table.insert(self.thinks, think)
	end

	return p
end

function bot:loadPluginsFolder(dir)
	self:unloadPlugins()

	local plugins = self.plugins
	
	for path in lfs.dir(dir) do
		if path:match("%.lua$") then
			local plugin, err = self:loadPlugin(dir.."/"..path)
		
			if not plugin then
				return nil, err
			end

			table.insert(plugins, plugin)
		end
	end

	return plugins
end
