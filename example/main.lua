------------------------------------------------------------------------
-- To create a new bot, copy this file along with "config.lua"
-- and the "plugins" directory to a new directory.
-- Edit the config file to suit your needs.
-- Execute main.lua to start the bot.
------------------------------------------------------------------------

local ircbot = require "ircbot"
local sleep = require "socket".sleep

-- Create a new bot.
local bot, config = ircbot.new("config.lua")

-- Load default bot plugins (found in ircbot/plugins).
assert(bot:loadDefaultPlugins())

-- Load bot plugins.
local plugins, err = bot:loadPluginsFolder(config.plugin_dir)
if not plugins then
	bot:log(err)
end

while true do
	-- Call this for every bot you have to handle incoming data and events.
	bot:think()

	-- This is here to use less CPU time. Remove or modify to suit your needs.
	sleep(0.5)
end
