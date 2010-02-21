--[[
	IRC Bot Administration
]]

PLUGIN.Name = "Administration"

local conf = require "ircbot.config"

local whois, reloadPlugins

function Load(bot)
	whois = function(nick)
		return bot:whois(nick)
	end

	reloadPlugins = function(path)
		return bot:reloadPlugins(path)
	end
end

local loggedIn = {}
local Admins = conf.load("admins.lua", {"admins"}).admins

function public.isAdmin(nick, host)
	if loggedIn[host] then 
		return true 
	end

	local info = whois(nick)
	for k,accname in ipairs(Admins) do
		if accname == info.account then
			loggedIn[host] = true
			return true
		end
	end
	return false
end

function public.check()
	return isAdmin(user.nick, user.host)
end

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
		
		local succ, err = reloadPlugins(dir or CONFIG.plugindir)
		reply(succ and "Reloaded plugins." or err)
	end
}
