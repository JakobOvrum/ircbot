--[[
	IRC Bot Administration
]]

PLUGIN.Name = "Administration"

local conf = require "ircbot.config"

local BOT

function Load(bot)
	BOT = bot
end

--bot administration
Command "login"
{
	ExpectedArgs = 1;
	
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
		local succ, err = BOT:loadPluginsFolder(dir or CONFIG.plugin_dir)
		reply(succ and "Reloaded plugins." or err)
	end
}

Command "quit"
{
	admin = true;
	
	function(message)
		BOT:disconnect(message)
		os.exit()
	end
}

--irc helpers
Command "join"
{
	expectedArgs = -1;
	admin = true;
	
	function(channel, key)
		BOT:join(channel, key)
		reply("Joined %s", channel)
	end
}

Command "part"
{
	expectedArgs = 1;
	admin = true;

	function(channel)
		BOT:part(channel)
		reply("Left %s", channel)
	end
}
