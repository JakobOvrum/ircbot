--[[
	IRC Bot Administration
]]

Name = "Bot Administration"

-- uncomment to disable this plugin
-- disable()

--bot administration
Command "reload"
{
	help = "Reload all plugins from either a specified directory or from the `plugin_dir` configuration value.";
	
	admin = true;
	
	function(dir)
		self:unloadPlugins()

		local succ, err = self:loadDefaultPlugins()
		if not succ then
			raise(err)
		end
		succ, err = self:loadPluginsFolder(dir or CONFIG.plugin_dir)
		if not succ then
			raise(err)
		end
		reply("Reloaded plugins.")
	end
}

Command "unload"
{
	help = "Unload a previously loaded plugin by name.";

	expectedArgs = 1;
	admin = true;

	function(name)
		local plugin = self.plugins[name] or raise("Plugin \"%s\" not found.", name)
		self:unloadPlugin(plugin)
		reply("Unloaded plugin \"%s\" (%s).", name, plugin.Path)
	end
}

Command "load"
{
	help = "Load a plugin from file.";
	
	admin = true;

	function(path)
		if not path then
			raise("Expected path.")
		end
		
		local plugin, err = self:loadPlugin(path)
		if not plugin then
			raise(err)
		end

		self:installPlugin(plugin)

		reply("Plugin \"%s\" loaded and installed.", plugin.ModuleName)
	end
}

Command "loaddir"
{
	help = "Load all plugins from a directory.";
	
	admin = true;
	
	function(path)
		if not path then
			raise("Expected path.")
		end
		
		local plugins, err = self:loadPluginsFolder(path)
		if not plugins then
			raise(err)
		end
		
		reply("Loaded %d plugins from \"%s\"", #plugins, path)
	end
}

Command "quit" "exit"
{
	help = "Terminate the bot, optionally with a particular quit message.";
	
	admin = true;
	
	function(message)
		self:close(message)
		os.exit()
	end
}

Command "memory"
{
	help = "Display the current amount of memory in use by the Lua VM.";
	
	admin = true;

	function()
		reply("Memory use: %dkB", collectgarbage("count"))
	end
}

Command "pollinterval"
{
	help = "Display or set the message queue poll interval.";
	
	admin = true;

	function(new)
		if new then
			local seconds = tonumber(new)
			if not seconds then
				raise("Argument must be a number.")
			end
			self:setPollInterval(seconds)
			reply("The new poll interval is %fs", seconds)
		else
			reply("The current poll interval is %fs", self:getPollInterval())
		end
	end
}

--irc helpers
Command "join"
{
	help = "Join a channel.";
	
	expectedArgs = -1;
	admin = true;
	
	function(channel, key)
		self:join(channel, key)
		reply("Joined %s", channel)
	end
}

Command "part"
{
	help = "Leave a channel.";
	
	expectedArgs = 1;
	admin = true;

	function(channel)
		self:part(channel)
		reply("Left %s", channel)
	end
}

Command "pm" "send"
{
	help = "Send a message to a channel or user.";

	expectedArgs = "^(%S+) (.+)$";
	admin = true;

	function(target, message)
		self:sendChat(target, message)
		reply("Sent \"%s\" to \"%s\"", message, target)
	end
}
