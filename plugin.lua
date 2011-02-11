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
local rawget = rawget
local wrap = coroutine.wrap
local yield = coroutine.yield
local package = package
local _G = _G

module "ircbot"

local bot = _META

--- Shared plugin environment.
shared = setmetatable({}, {__index = _G})

-- This function creates a proxy object which ensures that a table is read-only and will error if a non-existant field was requested.
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

function bot:unloadPlugin(i)
	local plugin = self.plugins[i]
	local unload = plugin.Unload
	if unload then
		unload()
	end

	for k, h in ipairs(plugin._hooks) do
		self:unhook(h.type, h.id)
	end

	shared[plugin.ModuleName] = nil
	self.plugins[i] = nil
	if plugin.Think then
		table.remove(self.thinks, plugin.thinkIndex)
	end
end

--- Unload all plugins.
-- If a plugin has an Unload function, it is called with no parameters.
function bot:unloadPlugins()
	local plugins = self.plugins

	for i = 1, #self.plugins do
		self:unloadPlugin(i)
	end

	-- TODO: move this to a per-plugin basis
	if self:hasCommandSystem() then
		self:flushCommands()
	end

	self:log("Unloaded all plugins")
end

--- Load a plugin from file.
-- @param path path to plugin script
-- @returns the loaded plugin. On error, nil is returned followed by an error message.
-- @note
-- This method is not usually used directly; use bot:loadPluginsFolder instead.
function bot:loadPlugin(path)
	local modname = path:match("/(.-)%.lua$") or path
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
		Think = function(f, env)
			if p.Think then
				error("There can only be one Think hook per plugin", 3)
			end

			p.Think = {
				think = wrap(function() 
					while true do 
						f() 
						yield() 
					end 
				end);
				schedule = 0;
			}

			if env.enabled ~= nil then
				p.Think.enabled = env.enabled
			else
				p.Think.enabled = true
			end
			
			function env.wait(seconds)
				yield(seconds)
			end
		end
	}

	function p.enableThink()
		if not p.Think then
			error("this plugin does not have a Think hook.", 2)
		end
		p.Think.enabled = true
	end
	
	function p.disableThink()
		if not p.Think then
			error("this plugin does not have a Think hook.", 2)
		end
		p.Think.enabled = false
	end

	function p.Hook(hook)
		return function(tbl)
			local f = assert(tbl.callback or tbl[1], "callback not provided")
			assert(type(f) == "function", "callback not a function value")

			tbl.self = self
			setmetatable(tbl, {__index = p})
			setfenv(f, tbl)

			local specialHook = specialHooks[hook]
			if specialHook then
				specialHook(f, tbl)
				return
			end

			local hookInfo = {type = hook}
			table.insert(p._hooks, hookInfo)
			hookInfo.id = self:hook(hook, function(...)
				local succ, err = pcall(f, ...)
				if not succ then
					self:log("Error running hook \"%s\": %s", hook, err)
				end
			end)
		end
	end

	--add send function
	function p.send(info)
		local target = info.target or error("missing target", 2)
		local message = info.message or error("missing message", 2)

		if info.method == "notice" then
			self:sendNotice(target, message)
		else
			self:sendChat(target, message)
		end
	end

	--add log function
	function p.log(message, ...)
		self:log(message, ...)
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
		local i = #self.thinks + 1
		table.insert(self.thinks, i, think)
		p.thinkIndex = i
	end

	return p
end

--- Load all plugins in a folder.
function bot:loadPluginsFolder(dir)
	local newPlugins = {}

	for path in lfs.dir(dir) do
		if path:match("%.lua$") then
			local plugin, err = self:loadPlugin(dir.."/"..path)

			if not plugin then
				return nil, err
			end

			self:log("Loaded plugin \"%s\"", path)

			table.insert(newPlugins, plugin)
		end
	end

	for k, plugin in ipairs(newPlugins) do
		local postload = plugin.PostLoad
		if postload then
			postload(self)
		end
		table.insert(self.plugins, plugin) 
  	end

	return newPlugins
end

local function exists(path)
	return not not lfs.attributes(path)
end

--- Load plugins from the ircbot/plugins directory.
-- ircbot is searched for in `package.path`.
function bot:loadDefaultPlugins()
	local libPath
	for path in package.path:gmatch("[^;]+") do
		path = path:gsub("%?", "ircbot")
		if exists(path) then
			libPath = path
		end
	end

	local notFound = "unable to find ircbot directory"

	if not libPath then
		return false, notFound
	end

	libPath = libPath:match("^(.-)[/\\][^/\\]+$")
	if not libPath then
		return false, notFound
	end

	return self:loadPluginsFolder(libPath .. "/plugins")	
end
