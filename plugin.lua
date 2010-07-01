local lfs = require "lfs"
local irc = require "irc"

local setmetatable = setmetatable
local error = error
local setfenv = setfenv
local getfenv = getfenv
local loadfile = loadfile
local pcall = pcall
local pairs = pairs
local ipairs = ipairs
local table = table
local type = type
local assert = assert
local print = print
local rawget = rawget

local shared = setmetatable({}, {__index = _G})

module "ircbot"

local bot = _META

local function configProxy(t)
	return setmetatable({}, {
		__index = function(proxy, k)
			local v = t[k]
			if v == nil then
				error(table.concat{"Requested nil config value \"",k,"\""}, 2)
			end
			return v
		end;
		__newindex = function()
			error("Config table is read-only", 2)
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

		for k, h in ipairs(plugin._hooks) do
			self:unhook(h.type, h.id)
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
	local modname = path:match("/(.-)%.lua$")
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
		channels = self.channels;

		loadConfigTable = loadConfigTable;
		CONFIG = configProxy(self.config);
		public = {};
		
		ModuleName = modname;
		Path = path;

		_hooks = {};
	}
	p.PLUGIN = p
	setmetatable(p, {__index = shared})
	shared[modname] = p.public

	--add Command function
	if self:hasCommandSystem() then
		p.Command = function(name)
			local names = {name}

			local function reg(tbl)
				if type(tbl) == "string" then
					table.insert(names, tbl)
					return reg
				else
					self:RegisterCommand(p, names, tbl)
				end
			end

			return reg
		end
	end

	--add Hook function
	local specialHooks = {
		Think = function(f)
			if p.Think then
				error("There can only be one Think hook per plugin", 3)
			end
			p.Think = f
		end
	}
	
	function p.Hook(hook)
		return function(tbl)
			local f = assert(tbl.callback or tbl[1], "callback not provided")
			assert(type(f) == "function", "callback not a function value")

			tbl.self = self
			setmetatable(tbl, {__index = p})
			setfenv(f, tbl)

			local specialHook = specialHooks[hook]
			if specialHook then
				specialHook(f)
				return
			end

			local hookInfo = {type = hook}
			table.insert(p._hooks, hookInfo)
			hookInfo.id = self:hook(hook, function(...)
				local succ, err = pcall(f, ...)
				if not succ then
					print(("Error running hook \"%s\": %s"):format(hook, err))
				end
			end)
		end
	end

	--add send function
	function p.send(info)
		local target = assert(info.target, "missing target")
		local message = assert(info.message, "missing message")
		
		if info.method == "notice" then
			self:sendNotice(target, message)
		else
			self:sendChat(target, message)
		end
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
