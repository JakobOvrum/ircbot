--[[
	IRC Bot Administration
]]

PLUGIN.Name = "Administration"

local conf = require "ircbot.config"

local whois, reloadPlugins

function Load(bot)
	BOT = bot
end

local loggedIn = {}
local Admins = conf.load("admins.lua", {"admins"}).admins

function public.isAdmin(nick, host)
	nick = nick or user.nick
	host = host or user.host
	
	if loggedIn[host] then
		return true 
	end

	local info = BOT:whois(nick)
	for k,accname in ipairs(Admins) do
		if accname == info.account then
			loggedIn[host] = true
			return true
		end
	end
	return false
end

--bot administration
Command "login"
{
	ExpectedArgs = 1;
	
	function(password)
		if CONFIG.password == password then
			reply("Welcome, %s", user.nick)
			loggedIn[user.host] = true
		end
	end
}

Command "reload"
{
	function(dir)
		if not isAdmin() then return end
		
		local succ, err = BOT:loadPlugins(dir or CONFIG.plugindir)
		reply(succ and "Reloaded plugins." or err)
	end
}

Command "quit"
{
	function(message)
		if not isAdmin() then return end
		BOT:disconnect(message)
		os.exit()
	end
}

--irc helpers
Command "join"
{
	expectedArgs = -1;
	
	function(channel, key)
		if not isAdmin() then return end
		BOT:join(channel, key)
		reply("Joined %s", channel)
	end
}

Command "part"
{
	expectedArgs = 1;

	function(channel)
		if not isAdmin() then return end
		BOT:part(channel)
		reply("Left %s", channel)
	end
}
