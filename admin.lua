local assert = assert
local ipairs = ipairs

module "ircbot"

local bot = _META

local loggedIn
local admins

function bot:reloadAdmins()
	admins = self.config.admins or {}
	loggedIn = {}
end

local function isAdmin(self, user)
	local host = user.host
	
	if loggedIn[host] == nil then
		local info = self:whois(user.nick)
		for k,accname in ipairs(admins) do
			if accname == info.account then
				loggedIn[host] = true
				break
			else
				loggedIn[host] = false
			end
		end
	end
	
	return loggedIn[host]
end

function bot:initAdminSystem()
	self:reloadAdmins()
	self.isAdmin = isAdmin
end

function bot:hasAdminSystem()
	return not self.config.no_admin_system
end
