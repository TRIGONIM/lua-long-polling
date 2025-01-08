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
	local sem   = self.channel_sems[channel]
	if sem then
		sem:give( sem:get_wait() ) -- err is unreal, because of math.huge in sema.new()
	end
	return total
end

function MT:get_news(channel, offset, timeout)
	local data, total = self:get_updates(channel, offset)
	if (#data > 0) or (offset > total) or (timeout <= 0) then
		return data, total
	end

	-- \/ #data == 0, so we need to wait for updates

	if not self.channel_sems[channel] then
		self.channel_sems[channel] = copas.semaphore.new(math.huge, 0) -- max, start
	end
	local sem = self.channel_sems[channel]

	-- Stop coroutine. Wait for new data, or timeout
	local _, err = sem:take(1, timeout)
	if err == "timeout" then return {}, total end

	data, total = self:get_updates(channel, offset)
	return data, total
end

function server.new(dataprovider)
	local dp = dataprovider or "localtable" -- provide own Class or use default
	if type(dp) == "string" then -- choose from existing dataproviders
		dp = require("long-polling.dataproviders." .. dp).new()
	end

	assert(dp.get_updates and dp.add_update,
		"dataprovider must have get_updates and add_update methods")

	return setmetatable({
		channel_sems = setmetatable({}, { __mode = "kv" }),
		dataprovider = dp,
	}, MT)
end

return server
