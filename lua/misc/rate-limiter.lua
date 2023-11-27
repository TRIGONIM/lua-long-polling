

local limit_on_ip = function(req) return req:ip() end

return function(opts)
	opts = opts or {}
	opts.frame_time   = opts.frame_time or 60 -- in seconds
	opts.limit_amount = opts.limit_amount or 120 -- per frame_time
	opts.limit_on     = opts.limit_on or limit_on_ip
	opts.response     = opts.response or function(res, retry_after)
		res:set("Retry-After", retry_after)
		res:status(429)
		res:send("request limit of " .. opts.limit_amount .. "/" .. opts.frame_time .. "s exceeded")
	end

	local memory = {} -- key => {current, create_time}

	local function key_ttl(key)
		if not memory[key] then return -1 end
		return os.time() - memory[key].create_time
	end

	local function gc_key(key)
		if not memory[key] then return end
		if key_ttl(key) > opts.frame_time then
			memory[key] = nil
		end
	end

	local function gc_all()
		for key in pairs(memory) do gc_key(key) end
	end

	local total_hits = 0
	return function(req, res, next)
		total_hits = total_hits + 1
		if total_hits % 10 == 0 then gc_all() end -- gc every 10 requests

		local key = opts.limit_on(req)
		gc_key(key)

		memory[key] = memory[key] or {
			current = 0,
			create_time = os.time(),
		}

		local hits = memory[key].current + 1
		memory[key].current = hits

		res:set("X-RateLimit-Limit", opts.limit_amount)
		res:set("X-RateLimit-Remaining", opts.limit_amount - hits)

		if hits > opts.limit_amount then
			local retry_after = opts.frame_time - key_ttl(key)
			opts.response(res, retry_after)
			return
		end

		next()
	end
end
