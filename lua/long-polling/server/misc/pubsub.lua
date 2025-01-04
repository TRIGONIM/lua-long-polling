local MT = {}
MT.__index = MT

function MT:publish(channel, data)
	local clients = self.clients[channel]
	if not clients then return end
	for client_uid, callback in pairs(clients) do
		local ok, err = pcall(callback, client_uid, data)
		if not ok then
			print("Error in callback for " .. client_uid .. ": " .. err)
		end
	end
end

function MT:subscribe(channel, callback)
	local client_uid = tostring({}):sub(10)
	local cbs = self.clients[channel] or {}
	cbs[client_uid] = callback
	self.clients[channel] = cbs
	return client_uid
end

function MT:unsubscribe(channel, client_uid)
	if not self.clients[channel] then return nil end
	local cb = self.clients[channel][client_uid]
	self.clients[channel][client_uid] = nil
	if not next(self.clients[channel]) then -- gc
		self.clients[channel] = nil
	end
	return cb
end

function MT.new()
	return setmetatable({
		clients = {}, -- channel => {cl_uid = cb}
	}, MT)
end

return MT
