local socket = require("socket")
local redis  = require("redis") -- https://github.com/nrk/redis-lua/blob/version-2.0/src/redis.lua

local redq = {}

local MT = {}
function MT.__index(wrapped_client, method_name)
	local redis_client = wrapped_client.redis_client

	local has_method = redis.commands[method_name]
	if has_method then
		return function(_, ...)
			return redq.run_method_safe(wrapped_client, method_name, ...)
		end
	else
		-- print("redis-safe: Attempting to access a field instead of the method", method_name)
		return redis_client[method_name]
	end
end

function redq.run_method_safe(wrapped_client, method_name, ...)
	local redis_client = wrapped_client.redis_client
	local method_func  = redis_client[method_name]

	-- wrapped_client.opts.socket:settimeout(1)
	-- local args = {...}
	-- print("args", wrapped_client.opts.socket, args[1], args[2], args[3], args[4])
	local ok, res = pcall(method_func, redis_client, ...)
	if ok then
		wrapped_client._retry_attemps = 0
		return res
	end

	print("Redis Wrapper. Error with command " .. method_name .. "(" .. table.concat({...}, " ") .. "):" .. res)
	local opts = wrapped_client.opts

	local want_reconnect = opts.reconnect_condition == nil
		or opts.reconnect_condition(res)

	if not want_reconnect then error(res) end

	local max_retries = opts.max_retries_per_request or 3
	local retry_attempt = wrapped_client._retry_attemps
	if retry_attempt >= max_retries then
		wrapped_client._retry_attemps = 0
		error(res)
	end
	wrapped_client._retry_attemps = retry_attempt + 1

	local retry_delay = opts.retry_delay
	if not retry_delay then
		retry_delay = 1
	elseif type(retry_delay) == "function" then
		retry_delay = retry_delay(retry_attempt)
	end

	retry_delay = retry_delay or 3

	if opts.copas_wrap then
		require("copas").pause(retry_delay) -- only thread (coro)
	else
		socket.sleep(retry_delay) -- whole process
	end

	local reconnect_ok, err = pcall(redq.reconnect, redis_client, opts)
	print("Redis Wrapper: " .. (reconnect_ok and "reconnected" or "reconnect failed: " .. err) .. " after " .. wrapped_client._retry_attemps .. " attempts")
	return redq.run_method_safe(wrapped_client, method_name, ...)
end

function redq.wrap(redis_client, opts)
	local wrapped_client = setmetatable({
		redis_client = redis_client,
		opts = opts,

		_retry_attemps = 0,
	}, MT)

	return wrapped_client
end

function redq.copas_socket(host, port, timeout, tcp_nodelay)
	local sock = socket.tcp()
	sock = require("copas").wrap(sock)
	sock:connect(host, port) -- #todo check for errors?
	sock:setoption("tcp-nodelay", tcp_nodelay)
	sock:settimeouts(timeout, nil, nil) -- conn, send, recv
	return sock
end

local auth_client = function(redis_client, password)
	if password then
		local auth_ok, err = pcall(redis_client.auth, redis_client, password)
		local all_ok = auth_ok or err:find("called without any password configured")
		if not all_ok then
			print("redis auth error: " .. err)
			error(err)
		end
	end
end

function redq.reconnect(redis_client, opts)
	local sock = redis_client.network.socket
	sock:close()

	if opts.copas_wrap then
		sock = redq.copas_socket(opts.host, opts.port, opts.timeout, opts.tcp_nodelay)
		redis_client.network.socket = sock
	else
		if opts.socket then error("we can't recreate custom socket") end
		local new_redis_client = redis.connect(opts)
		redis_client.network.socket = new_redis_client.network.socket
	end

	auth_client(redis_client, opts.password)
	if opts.db then redis_client:select(opts.db) end
end

function redq.connect(opts)
	if opts.copas_wrap then
		opts.socket = redq.copas_socket(opts.host, opts.port, opts.timeout, opts.tcp_nodelay)
	end

	local redis_client = redis.connect(opts) -- has .network.socket field
	auth_client(redis_client, opts.password)
	if opts.db then redis_client:select(opts.db) end
	opts.socket = nil -- we don't need it anymore
	return redis_client
end

function redq.create(...)
	local opts = {
		host = "127.0.0.1",
		port = 6379,
		-- sock = "redis.sock",
		tcp_nodelay = true,
		copas_wrap = false,
		-- socket = socket.tcp(),

		-- timeout = 10, -- connect timeout
		-- password = "pass",
		-- db = 0,
		-- reconnect_condition = function(err) return err:match("timeout") end,
		-- max_retries_per_request = 3,
		-- retry_delay = function(times) return times * 1 end, -- in seconds
	}

	local args = {...}
	if type(args[1]) == "string" then
		opts.sock = args[1]
	elseif type(args[1]) == "number" then
		opts.port, opts.host = args[1], args[2]
	elseif type(args[1]) == "table" then
		for k, v in pairs( args[1] ) do -- merge with overrides
			opts[k] = v
		end
	end

	local redis_client = redq.connect(opts)
	return redq.wrap(redis_client, opts)
end

return redq
