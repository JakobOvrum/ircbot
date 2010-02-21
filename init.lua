local irc = require "irc"
local lfs = require "lfs"

local rawget = rawget
local assert = assert
local ipairs = ipairs
local loadfile = loadfile
local setfenv = setfenv
local type = type
local setmetatable = setmetatable

local conf = require "ircbot.config"
local cmd = require "ircbot.command"

local bot = {}
do
	local temp = _BOT
	_BOT = bot
	require "ircbot.plugin"
	_BOT = temp
end

module(...)

function bot.__index(o, k)
	local v = rawget(bot, k)

	if v == nil then
		v = rawget(o, k)
	end

	if v == nil then
		local irc = rawget(o, "conn")
		v = irc[k]
	end

	return v
end

function new(tbl)
	if type(tbl) == "string" then
		tbl = conf.load(tbl, {"channels"})
	end
	
	local conn = irc.new(tbl)

	local authed = false
	conn:hook("OnConnect", function()
		authed = true
	end)

	local succ, err = conn:connect(assert(tbl.server, "Field 'server' is required"), tbl.port)
	if not succ then
		error(err, 2)
	end

	repeat
		conn:think()
	until authed

	if tbl.channels then
		for k,channel in ipairs(tbl.channels) do
			if type(channel) == "table" then
				conn:join(assert(channel.name, "Malformed channel object"), channel.key)
			else 
				conn:join(channel)
			end
		end
	end

	conn:hook("OnChat", "_commandparser", function(user, channel, msg)
		cmd.OnChat(conn, user, channel, msg)
	end)
	
	return setmetatable({conn = conn; 
						config = tbl; 
						plugins = {};
						thinks = {};
						}, bot), tbl
end

function bot:think()
	for k, think in ipairs(self.thinks) do
		think()
	end
	
	self.conn:think()
end
