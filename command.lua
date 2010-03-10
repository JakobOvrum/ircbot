local error = error
local table = table
local type = type
local select = select
local pcall = pcall
local unpack = unpack
local assert = assert
local setmetatable = setmetatable
local setfenv = setfenv

module "ircbot"

local bot = _META

local argHandlers = {
	string = function(expected, args)
		local t = {args:match(expected)}
		if #t == 0 then
			return nil, "invalid argument format"
		end
		return t
	end;

	number = function(expected, args)
		if not args then
			return nil, "arguments expected"
		end
		local t = {}
		args:gsub("(%S*)", function(word) table.insert(t, word) end)

		if #t > -1 and #t < expected then
			return nil, ("got %d arguments, expected %d"):format(#t, expected)
		end
		return t
	end;
}

function bot:RegisterCommand(plugin, name, tbl)
	tbl.Callback = assert(tbl.Callback or tbl[1], "Callback not specified")
	local f = tbl.Callback
	
	assert(type(f) == "function", "Callback is not a function")
	tbl.Name = assert(tbl.Name or name, "Command name not specified")

	if tbl.ExpectedArgs then
		tbl.ArgParser = assert(argHandlers[type(tbl.ExpectedArgs)], "ExpectedArgs is of unsupported type")
	end
	
	setmetatable(tbl, {__index = plugin})
	setfenv(f, tbl)
	self.commands[tbl.Name] = tbl
end

function bot:hasCommandSystem()
	return not self.config.no_command_system
end

function bot:initCommandSystem(plugin)
	self.commands = self.commands or {}
	local commands = self.commands
	
	plugin.Command = function(name)
		return function(tbl)
			self:RegisterCommand(plugin, name, tbl)
		end
	end
	
	self:hook("OnChat", "_cmdhandler", function(user, channel, msg)
		local cmdPrefix = plugin.CommandPrefix
		local cmdname = msg:match(table.concat{"^", cmdPrefix, "(.+)%s*"})
		if not cmdname then return end

		local cmd = commands[cmdname]
		if not cmd then
			self:invoke("UnknownCommand", user, channel, cmdname)
			return
		end

		if cmd.admin and not self:isAdmin(user) then
			return
		end

		local function raise(err)
			local redirect = self.config.redirect_errors
			if type(redirect) == true then return end
			self:sendChat(type(redirect) == "string" and redirect or channel, ("Error in command \"%s\": %s"):format(cmdname, err))
		end
		
		local args = msg:match("^(.-) (.+)$")

		local argParser = cmd.ArgParser
		if argParser then
			local parsed, err = argParser(cmd.ExpectedArgs, args)
			if not parsed then
				return raise(err)
			end
			args = parsed
		end
		
		cmd.user, cmd.channel = user, channel
		cmd.reply = function(fmt, ...)
			self:sendChat(channel, fmt:format(...))
		end

		local succ, err
		if type(args) == "table" then
			succ, err = pcall(cmd.Callback, unpack(args))
		else
			succ, err = pcall(cmd.Callback, args)
		end
		
		if not succ then
			return raise(err)
		end
	end)
end
