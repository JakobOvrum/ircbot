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

--- Unload a single plugin.
-- This removes all plugin hooks and commands, and removes the plugin from the shared plugin environment.
-- If a plugin has an Unload function, it is called with no parameters.
-- @param plugin plugin to unload
-- @note
-- The Unload function is not called in a protected environment.
function bot:unloadPlugin(plugin)
	local unload = plugin.Unload
	if unload then
		unload()
	end

	for k, h in ipairs(plugin.hooks) do
		self:unhook(h.type, h.id)
	end

	self:shutdownCommandSystem(plugin)

	self.shared[plugin.ModuleName] = nil
	self.plugins[plugin.ModuleName] = nil
	if plugin.Think then
		table.remove(self.thinks, plugin.thinkIndex)
	end
end

--- Unload all plugins.
-- @see [bot:unloadPlugin]
function bot:unloadPlugins()
	for name, plugin in pairs(self.plugins) do
		self:unloadPlugin(plugin)
	end

	self:log("Unloaded all plugins")
end

-- used to create constructs like Command "foo" "bar" { function(...) log(...) end }
local function pluginAggregate(callback)
	return function(...)
		local names = {...}
		local function register(arg)
			if type(arg) == "string" then
				table.insert(names, arg)
				return register
			else
				if not arg.callback then
					if arg[1] then
						arg.callback = arg[1]
						arg[1] = nil
					else
						error("callback not specified", 2)
					end
				end
				callback(names, arg)
			end
		end
		return register
	end
end

local disable_uid = {}

--- Load a plugin from file.
-- @param path path to plugin script
-- @returns the loaded plugin. On error, nil is returned followed by an error message.
-- @note
-- This method is not usually used directly; use bot:loadPluginsFolder instead.
-- @see [plugin]
function bot:loadPlugin(path)
	local modname = path:match("[/\\](.-)%.lua$") or path
	local function raise(message)
		return nil, table.concat{"Error loading plugin \"", modname, "\": ", message}
	end

	if self.plugins[modname] then
		return raise(("plugin already loaded (from \"%s\")"):format(self.plugins[modname].Path))
	end

	local f, err = loadfile(path)
	if not f then
		return raise(err)
	end

	local plugin = {
		color = irc.color;
		bold = irc.bold;
		underline = irc.underline;
		channels = self.channels;

		loadConfigTable = loadConfigTable;
		CONFIG = configProxy(self.config);
		public = {};
		self = self;

		ModuleName = modname;
		Path = path;

		hooks = {};
		commands = {};
	}
	plugin.PLUGIN = plugin
	setmetatable(plugin, {__index = self.shared})

	plugin.Command = pluginAggregate(
		function(alias, tbl)
			self:registerCommand(plugin, alias, tbl, 3) 
		end
	)

	plugin.Hook = pluginAggregate(
		function(hooks, tbl)
			self:registerHook(plugin, hooks, tbl, 3)
		end
	)

	function plugin.enableThink()
		if not plugin.Think then
			error("this plugin does not have a Think hook.", 2)
		end
		plugin.Think.enabled = true
	end
	
	function plugin.disableThink()
		if not plugin.Think then
			error("this plugin does not have a Think hook.", 2)
		end
		plugin.Think.enabled = false
	end

	--add send function
	function plugin.send(info)
		local target = info.target or error("missing target", 2)
		local message = info.message or error("missing message", 2)

		if info.method == "notice" then
			self:sendNotice(target, message)
		else
			self:sendChat(target, message)
		end
	end

	--add log function
	function plugin.log(message, ...)
		self:log(message, ...)
	end

	--add disable function
	function plugin.disable()
		error(disable_uid)
	end

	setfenv(f, plugin)

	local succ, err = pcall(f)
	if not succ then
		if err == disable_uid then
			return nil, err
		else
			return raise(err)
		end
	end	

	plugin.disable = nil

	if not plugin.Name then
		return raise("plugin name not specified")
	end

	--install plugin
	local load = plugin.Load
	if load then
		load(self)
	end

	self.shared[modname] = plugin.public

	return plugin
end

function bot:installPlugin(plugin)
	local postload = plugin.PostLoad
	if postload then
		postload(self)
	end

	local think = plugin.Think
	if think then
		local i = #self.thinks + 1
		table.insert(self.thinks, i, think)
		plugin.thinkIndex = i
	end

	self:initCommandSystem(plugin)
	self.plugins[plugin.ModuleName] = plugin
end

--hooks intercepted by the bot system
local botHooks = {}

function botHooks.Think(plugin, callback, env)
	if plugin.Think then
		error("there can only be one Think hook per plugin", 3)
	end

	plugin.Think = {
		think = wrap(function()
			while true do
				callback()
				yield()
			end
		end);
		schedule = 0;
		enabled = env.initiallyDisabled or true;
	}

	function env.wait(seconds)
		yield(seconds)
	end
end

function bot:registerHook(plugin, hooks, tbl, errorlevel)
	local function raise(message)
		error(("%s (in hook \"%s\")"):format(message, table.concat(hooks, ", ")), errorlevel + 2)
	end

	local f = tbl.callback

	if type(f) ~= "function" then
		raise("callback is not a function")
	end

	tbl.self = self
	setmetatable(tbl, {__index = plugin})
	setfenv(f, tbl)

	for k, hook in ipairs(hooks) do
		local botHook = botHooks[hook]
		if botHook then
			botHook(plugin, f, tbl)
		else
			local hookInfo = {
				type = hook;
				id = self:hook(hook, function(...)
					local succ, err = pcall(f, ...)
					if not succ then
						self:log("Error running hook \"%s\": %s", hook, err)
					end
				end);
			}
			table.insert(plugin.hooks, hookInfo)
		end
	end
end

--- Load all plugins in a folder.
function bot:loadPluginsFolder(dir)
	local newPlugins = {}

	for path in lfs.dir(dir) do
		if path:match("%.lua$") then
			local plugin, err = self:loadPlugin(table.concat{dir, "/", path})

			if not plugin then
				if err ~= disable_uid then
					-- unroll changes made for PostLoad
					for k, p in ipairs(newPlugins) do
						self.shared[p.ModuleName] = nil
					end
					return nil, err
				end
			else
				self:log("Loaded plugin \"%s\"", path)
				table.insert(newPlugins, plugin)
			end
		end
	end

	for k, plugin in ipairs(newPlugins) do
		self:installPlugin(plugin)
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
