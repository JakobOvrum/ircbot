local irc, lfs = require "irc", require "lfs"

local rawget = rawget
local assert = assert
local ipairs = ipairs
local setfenv = setfenv
local type = type
local setmetatable = setmetatable
local require = require
local print = print
local date = os.date
local pcall = pcall

local _G = _G

module "ircbot"

local bot = {}
_META = bot

require "ircbot.plugin"
require "ircbot.config"
require "ircbot.command"
require "ircbot.admin"

function new(tbl)
	if type(tbl) == "string" then
		tbl = assert(loadConfigTable(tbl, {"channels", "admins"}))
	end
	
	local conn = irc.new(tbl)

	conn:connect(assert(tbl.server, "field 'server' is required"), tbl.port)

	local on_connect = tbl.on_connect
	if on_connect then
		setfenv(on_connect, _G)
		on_connect(conn)
	end

	if tbl.channels then
		for k,channel in ipairs(tbl.channels) do
			if type(channel) == "table" then
				conn:join(assert(channel.name, "malformed channel object"), channel.key)
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
		logger = function(message)
			print(("[%s] %s"):format(date(), message))
		end;
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

	if b:hasCommandSystem() then
		b:initCommandSystem()
	end
	
	if b:hasAdminSystem() then
		b:initAdminSystem()
	end
	
	return b, tbl
end

function bot:close(message)
	self:unloadPlugins()
	self.conn:disconnect(message)
end

function bot:think()
	for k, think in ipairs(self.thinks) do
		local succ, err = pcall(think)
		if not succ then
			print("Error in Think: "..err)
		end
	end

	self.conn:think()
end

function bot:log(message)
	self.logger(message)
end
