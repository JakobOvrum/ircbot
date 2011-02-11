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
local time = os.time
local remove = table.remove
local insert = table.insert
local pcall = pcall
local unpack = unpack
local min = math.min

local _G = _G

module "ircbot"

local bot = {}
_META = bot

require "ircbot.plugin"
require "ircbot.config"
require "ircbot.command"
require "ircbot.admin"

function new(config)
	if type(config) == "string" then
		config = assert(loadConfigTable(config, {"channels", "admins"}))
	end
	
	local conn = irc.new(config)

	conn:connect(assert(config.server, "field 'server' is required"), config.port)
	
	local b = {
		conn = conn;
		config = config;
		plugins = {};
		thinks = {};
		queue = {interval = config.sendInterval or 0.5, lastSend = 0};
		logger = config.logger and setfenv(config.logger) or function(message)
			print(("[%s] %s"):format(date(), message))
		end;
	}
	
	setmetatable(b, {
		__index = function(self, key)
			local value = rawget(self, key)
			if value == nil then
				value = bot[key]
				if value == nil then
					value = conn[key]
				end
			end
			return value
		end
	})

	b:log("Connected to %s", config.server)
	
	local on_connect = config.on_connect
	if on_connect then
		setfenv(on_connect, _G)
		on_connect(b)
	end

	if config.channels then
		for k, channel in ipairs(config.channels) do
			if type(channel) == "table" then
				conn:join(assert(channel.name, "malformed channel object"), channel.key)
			else
				conn:join(channel)
			end
		end
	end

	if b:hasCommandSystem() then
		b:initCommandSystem()
	end
	
	if b:hasAdminSystem() then
		b:initAdminSystem()
	end
	
	return b, config
end

function bot:close(message)
	self:unloadPlugins()
	self.conn:disconnect(message)
end

local function fastremove(t, pos)
	t[pos] = nil
	t[pos] = remove(t)
end

function bot:think()
	self.conn:think()
	
	local now = time()
	for k, entry in ipairs(self.thinks) do
		if entry.schedule <= now then
			local succ, result, arg = pcall(entry.think)
			if not succ then
				self:log("Error in Think: %s", result)
				fastremove(self.thinks, k)
			elseif result then
				entry.schedule = now + result
			end
		end
	end

	local queue = self.queue
	local timePassed = now - queue.lastSend
	if #queue > 0 and timePassed >= queue.interval then
		local entry = remove(queue)
		entry.cb(unpack(entry))
		queue.lastSend = now
	end
end

--- Log a message using the bot logger.
-- The default logger prints the message to stdout with a timestamp.
-- @param message message to log
-- @param ... format parameters to message (uses `string.format`)
-- @note To supply a custom logger, define a `logger(message)` function in the configuration file.
function bot:log(message, ...)
	self.logger(message:format(...))
end

--- Enqueue an event for later execution.
-- A single queued event is dispatched at every poll interval.
-- @param callback function to call
-- @param ... parameters to pass to callback
function bot:pollMessage(callback, ...)
	insert(self.queue, 1, {cb = callback, ...})
end

--- Set the poll interval.
-- The default is the `sendInterval` config value, or 0.5 if not set.
-- @param interval new interval in seconds
function bot:setPollInterval(interval)
	self.queue.interval = interval
	self.queue.lastSend = time()
end

--- Sends a message to a channel or user, or polls the message for delayed transmission depending on the poll interval.
-- @param target user or channel to send to
-- @param message message to send
-- @see [bot:pollMessage]
function bot:sendChat(target, message)
	local conn = self.conn
	if self.queue.interval <= 0 then
		conn:sendChat(target, message)	
	else
		self:pollMessage(conn.sendChat, conn, target, message)
	end
end

--- Sends a notice to a channel or user, or polls the notice for delayed transmission depending on the poll interval.
-- @param target user or channel to send to
-- @param message message to send
-- @see [bot:pollMessage]
function bot:sendNotice(target, message)
	local conn = self.conn
	if self.queue.interval <= 0 then
		conn:sendNotice(target, message)	
	else
		self:pollMessage(conn.sendNotice, conn, target, message)
	end
end

