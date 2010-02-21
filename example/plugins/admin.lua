--[[
	IRC Bot Administration
]]

PLUGIN.Name = "Administration"

local conf = require "ircbot.config"

local Bot
local Admins
function Load(bot)
	Bot = bot
	Admins = conf.load("admins.lua", {"admins"}).admins
end

local loggedIn = {}

function isAdmin()
	local host = context.user.host

	if loggedIn[host] then 
		return true 
	end

	local info = Bot:whois(context.user.nick)
	for k,accname in ipairs(Admins) do
		if accname == info.account then
			loggedIn[host] = true
			return true
		end
	end
	return false
end

Command "login"
{
	ExpectedArgs = 1;
	
	function(password)
		if CONFIG.password == password then
			reply("Welcome, %s", context.user.nick)
			loggedIn[context.user.host] = true
		end
	end
}

Command "reload"
{
	function(dir)
		if not isAdmin() then return end
		
		local succ, err = Bot:loadPlugins(dir or CONFIG.plugindir)
		reply(succ and "Reloaded plugins." or err)
	end
}
