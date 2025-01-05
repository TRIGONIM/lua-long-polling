local MT = {}
MT.__index = MT

function MT:get_updates(channel, offset)
	local storage = self.storages[channel] or {}
	if not storage.total then return {}, 0 end -- несуществующий channel, данные не добавлялись

	local sub_last_n = storage.total - offset
	local updates = {}
	for i = #storage - sub_last_n + 1, #storage do
		updates[#updates + 1] = storage[i]
	end
	return updates, storage.total
end

function MT:add_update(channel, data)
	self.storages[channel] = self.storages[channel] or {}

	local storage = self.storages[channel]
	storage[#storage + 1] = data
	storage.total = (storage.total or 0) + 1
	if #storage > self.opts.max_updates then
		table.remove(storage, 1)
	end
	return storage.total
end

function MT.new(opts)
	opts = opts or {}
	opts.max_updates = opts.max_updates or tonumber(os.getenv("CHANNEL_STORAGE_MAXSIZE")) or 30
	return setmetatable({storages = {}, opts = opts}, MT)
end

return MT
