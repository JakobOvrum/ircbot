--[[
	IRC Bot Administration
]]

PLUGIN.Name = "Administration"

-- uncomment to disable this plugin
-- disable()

--bot administration
Command "login"
{	
	function(password)
		if CONFIG.password and CONFIG.password == password then
			reply("Welcome, %s", user.nick)
			loggedIn[user.host] = true
		end
	end
}

Command "reload"
{
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

Command "quit" "exit"
{
	admin = true;
	
	function(message)
		self:close(message)
		os.exit()
	end
}

--irc helpers
Command "join"
{
	expectedArgs = -1;
	admin = true;
	
	function(channel, key)
		self:join(channel, key)
		reply("Joined %s", channel)
	end
}

Command "part"
{
	expectedArgs = 1;
	admin = true;

	function(channel)
		self:part(channel)
		reply("Left %s", channel)
	end
}

Command "pm" "send"
{
	expectedArgs = "^(%S+) (.+)$";
	admin = true;

	function(target, message)
		self:sendChat(target, message)
		reply("Sent \"%s\" to \"%s\"", message, target)
	end
}

Command "memory"
{
	admin = true;

	function()
		reply("Memory use: %dkB", collectgarbage("count"))
	end
}

Command "pollinterval"
{
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
