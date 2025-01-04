local rds = require("long-polling.server.misc.redis-safe")

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

	-- The reason why there is script instead of just commands:
	-- https://chatgpt.com/share/67686def-c558-8004-893a-c372405c2a8f
	local script = [[
		local total_key, updates_key = KEYS[1], KEYS[2]
		local offset = tonumber(ARGV[1])

		local total = tonumber(redis.call('get', total_key)) or 0
		if offset >= total then return {{}, total} end

		local need_elements = total - offset
		local updates = redis.call('lrange', updates_key, -need_elements, -1)

		return {updates, total}
	]]

	local total_key   = prefix .. "total:"   .. channel
	local updates_key = prefix .. "updates:" .. channel
	local result = redis:eval(script, 2, total_key, updates_key, offset)
	redis:quit()

	return result[1], result[2]
end

function MT:add_update(channel, data)
	local opts = self.opts
	local prefix, ttl, max_updates = opts.data_prefix, opts.data_ttl, opts.max_updates
	local redis = self:getcon()

	-- Используем Lua-скрипт для атомарного выполнения всех операций
	-- multi/exec почему-то не справился с этим
	local script = [[
		local total_key, updates_key = KEYS[1], KEYS[2]
		local data, ttl, max_updates = ARGV[1], tonumber(ARGV[2]), tonumber(ARGV[3])

		local new_total = redis.call('incr', total_key)
		redis.call('expire', total_key, ttl)
		redis.call('rpush',  updates_key, data)
		redis.call('ltrim',  updates_key, -max_updates, -1)
		redis.call('expire', updates_key, ttl)

		return new_total
	]]

	local total_key   = prefix .. "total:"   .. channel
	local updates_key = prefix .. "updates:" .. channel
	local result = redis:eval(script, 2, total_key, updates_key, data, ttl, max_updates)
	redis:quit()

	return result
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

	return setmetatable({opts = opts}, MT)
end

return MT
