local rds = require("misc.redis-safe")

local MT = {}
MT.__index = MT

function MT:getcon()
	local opts = self.opts.redis
	return rds.create(opts.own and opts or {
		host = opts.host,
		port = tonumber(opts.port),
		password = opts.pass,
		copas_wrap = true,
		-- tcp_nodelay = false
	})
end

function MT:get_updates(channel, offset)
	local prefix = self.opts.data_prefix
	local redis = self:getcon()

	local total = tonumber(redis:get(prefix .. "total:" .. channel)) or 0
	if offset >= total then return {}, total end -- redis can't return empty list when need_elements == 0

	local need_elements = total - offset
	local updates = redis:lrange(prefix .. "updates:" .. channel, -need_elements, -1)
	return updates, total
end

function MT:add_update(channel, data)
	local opts = self.opts
	local prefix, ttl, max_updates = opts.data_prefix, opts.data_ttl, opts.max_updates
	local redis = self:getcon()
	local total = tonumber(redis:incr(prefix .. "total:" .. channel))
	redis:expire(prefix .. "total:"   .. channel, ttl)
	redis:rpush (prefix .. "updates:" .. channel, data)
	redis:ltrim (prefix .. "updates:" .. channel, -max_updates, -1)
	redis:expire(prefix .. "updates:" .. channel, ttl)
	return total
end

function MT.new(opts)
	opts = opts or {}
	opts.data_prefix = opts.data_prefix or os.getenv("REDIS_PREFIX") or "lpolling:"
	opts.data_ttl    = opts.data_ttl    or os.getenv("REDIS_DATA_TTL") or (60 * 60 * 24 * 7) -- 1 week
	opts.max_updates = opts.max_updates or tonumber(os.getenv("CHANNEL_STORAGE_MAXSIZE")) or 30

	opts.redis = opts.redis or {}
	opts.redis.host = opts.redis.host or os.getenv("REDIS_HOST")
	opts.redis.port = opts.redis.port or os.getenv("REDIS_PORT")
	opts.redis.pass = opts.redis.pass or os.getenv("REDIS_PASS")

	local obj = setmetatable({opts = opts}, MT)

	-- require("gmod.globals").PrintTable({opts = opts})
	-- require("copas").addthread(function()
	-- 	local redis = obj:getcon()
	-- 	redis:set("keklol", "kek")
	-- 	print("keklol", redis:get("keklol"))
	-- end)

	return obj
end

return MT
