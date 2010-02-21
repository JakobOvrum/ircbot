local ircbot = require "ircbot"
local sleep = require "socket".sleep

local bot, config = ircbot.new("config.lua")

assert(bot:loadPlugins(config.plugindir))

while true do
	bot:think()
	sleep(0.5)
end
