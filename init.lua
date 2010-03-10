local irc, lfs = require "irc", require "lfs"

local rawget = rawget
local assert = assert
local ipairs = ipairs
local loadfile = loadfile
local setfenv = setfenv
local type = type
local setmetatable = setmetatable
local require = require
local rawget = rawget

module "ircbot"

local bot = {}
_META = bot

require "ircbot.plugin"
require "ircbot.config"
require "ircbot.command"
require "ircbot.admin"

function new(tbl)
	if type(tbl) == "string" then
		tbl = assert(loadConfigTable(tbl, {"channels"}))
	end
	
	local conn = irc.new(tbl)

	conn:connect(assert(tbl.server, "Field 'server' is required"), tbl.port)

	if tbl.channels then
		for k,channel in ipairs(tbl.channels) do
			if type(channel) == "table" then
				conn:join(assert(channel.name, "Malformed channel object"), channel.key)
			else
				conn:join(channel)
			end
		end
	end

	local b = {
		conn = conn;
		config = tbl;
		plugins = {};
		thinks = {};
	}
	
	setmetatable(b, {__index = function(o,k)
		local v = rawget(o,k)
		if v == nil then
			v = bot[k]
			if v == nil then
				v = conn[k]
			end
		end
		return v
	end})

	if b:hasAdminSystem() then
		b:initAdminSystem()
	end
	
	return b, tbl
end

function bot:think()
	for k, think in ipairs(self.thinks) do
		think()
	end
	
	self.conn:think()
end
