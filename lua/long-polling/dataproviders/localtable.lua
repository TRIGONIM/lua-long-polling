local MT = {}
MT.__index = MT

function MT:get_updates(channel, offset)
	local storage = self.storage
	local total = storage[channel] and #storage[channel] or 0
	local updates = {}
	for i = offset + 1, total do
		updates[#updates + 1] = storage[channel][i]
	end
	return updates, total
end

function MT:add_update(channel, data)
	local storage = self.storage
	if not storage[channel] then storage[channel] = {} end
	storage[channel][#storage[channel] + 1] = data
	if #storage[channel] > self.opts.max_updates then
		table.remove(storage[channel], 1)
	end
	return #storage[channel]
end

function MT.new(opts)
	opts = opts or {}
	opts.max_updates = opts.max_updates or tonumber(os.getenv("CHANNEL_STORAGE_MAXSIZE")) or 30
	return setmetatable({storage = {}, opts = opts}, MT)
end

return MT
