local pubsub = require("long-polling.misc.pubsub")
local copas  = require("copas")

local server = {}

local MT = {}
MT.__index = MT

function MT:get_updates(channel, offset)
	return self.dataprovider:get_updates(channel, offset)
end

function MT:add_update(channel, data)
	return self.dataprovider:add_update(channel, data)
end

function MT:publish_new(channel, data)
	local total = self:add_update(channel, data)
	self.pubsub:publish(channel, {update = data, total = total})
	return total
end

function MT:get_news(channel, offset, timeout)
	local data, total = self:get_updates(channel, offset)
	if (#data > 0) or (offset > total) or (timeout <= 0) then return data, total end -- return immediately

	-- \/ #data == 0, so we need to wait for updates

	local release = false -- ugly hack to pause this thread until callback
	local client_uid = self.pubsub:subscribe(channel, function(client_uid, upd)
		-- print("new update in subscribed callback")
		self.pubsub:unsubscribe(channel, client_uid)

		data, total = {upd.update}, upd.total
		release = true
	end)

	-- lock this thread until update or timeout
    local start_time = os.time()
    while not release and os.time() - start_time <= timeout do
        copas.sleep(0.1)
    end

	if not release then
		self.pubsub:unsubscribe(channel, client_uid)
	end

	return data, total
end


function server.new(dataprovider_obj)
	local dp = dataprovider_obj
	if type(dataprovider_obj) == "string" then
		dp = require("long-polling.dataproviders." .. dataprovider_obj).new()
	else
		dp = dp or require("long-polling.dataproviders.localtable").new()
	end

	assert(dp.get_updates and dp.add_update,
		"dataprovider must have get_updates and add_update methods")

	return setmetatable({
		pubsub = pubsub.new(),
		dataprovider = dp,
	}, MT)
end

return server
