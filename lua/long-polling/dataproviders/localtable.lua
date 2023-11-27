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
	return #storage[channel]
end

function MT.new()
	return setmetatable({storage = {}}, MT)
end

return MT
