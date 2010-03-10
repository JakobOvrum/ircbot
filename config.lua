local pcall = pcall
local setfenv = setfenv
local ipairs = ipairs
local loadfile = loadfile

module "ircbot"

local function tableField(tbl, name)
	tbl[name] = function(t)
		tbl[name] = t
	end
end

function loadConfigTable(path, tableFields)
	local f, err = loadfile(path)
	if not f then return nil, err end

	local config = {}

	if tableFields then
		for k, field in ipairs(tableFields) do
			tableField(config, field)
		end
	end
	
	setfenv(f, config)

	f, err = pcall(f)
	if not f then return nil, err end
	
	return config
end
