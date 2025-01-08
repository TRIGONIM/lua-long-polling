# Long Polling Server Application

In this folder you can find the source code of the [server](server.lua) (and [client](client.lua)), which works at `poll.def.pm` (working name – kupol).

## Features

- Can be used to deliver messages to multiple clients at the same time.
- Tested in a production environment
- docker ready
- You can specify predefined parameters to be added to each update object, which is useful when you want to recognize different services that send updates to the same link.
- Ability to customize the amount of data stored and the storage time (for redis) so that no garbage is stored


## Run the application

```bash
# git clone this repo
# cd directory_with_this_file/

# run server via docker-compose.yml (will build fresh image)
# 👍 nice for development
docker-compose up --build polling

# alternatively run server via docker run (will use image from registry)
docker run --env-file .env -p 3000:3000 ghcr.io/trigonim/lua-long-polling:latest
```

All available settings are listed in [`.env-example`](.env-example)

## Application REST API:

![api demo](https://file.def.pm/uV3R6f28.gif)

- **GET** `http://your.app/anySecretPath?ts=0&sleep=10`, where `ts` is the last update id you received from polling server. Take it as an offset. The `sleep` parameter is the timeout during which the connection will be kept open until a new update is available. If an update arrives within this timeout, the connection will be immediately closed with the new update in the response in the following format: `{ts = 123, ok = true, updates = {your_update}}`
- **POST** with json data to `http://your.app/anySecretPath?merge=me`. The final update will looks like this: `{"a": "b", "merge": "me"}`.
  Curl example: `curl --verbose -d '{"a": 1}' "http://localhost:3000/SECRET_UID?merge=me"`

No authorization. With API features in mind, you can use your server as a public API, because no one client will be able to get the other's data without knowing its "secret path". It's like in blockchain.

**Pro tip:** If you want to use Traefik as web proxy (nginx is fine without it), you may need to configure `maxIdleConnsPerHost=-1` as Traefik has a limit of active connections and disconnects the excess ones with error 500

**👀 Test server:** poll.def.pm. But please, don't use it in production because I can turn it off at any moment.

## Client Example

Works both in pure Lua and on Garry's Mod server.

On pure Lua requires copas (and luasocket), lua-requests-async (it also requires copas) and cjson.

### Usage

**In gmod** put the `client.lua` file at any place, then get access to the library through `kupol = include("path/to/client.lua")`. Nothing is added to the global space automatically.

In pure Lua you can use the same principle: `kupol = require("kupol.client")`.

### Example

```lua
local kupol  = require("kupol.client") -- also works in Garry's Mod with include()
local Client = kupol.new("https://poll.def.pm/SomeSecretWord")


-- Getting data
Client:subscribe(function(upd, last_id)
	print("LP server received " .. tostring(last_id) .. " updates in all time")
	print("Last update: " .. kupol.json_encode(upd))
end, nil, 30) -- 30 is timeout in seconds.
-- nil – this is the last id, which was received (offset)


-- Sending data
kupol.thread_new(function()
	for i = 1, 10 do
		local ok, err = Client:publish({any = "value", counter = i})
		print(ok and "published" or "pub failed: " .. tostring(err))
		kupol.thread_pause(.05)
	end
end)
```





<!--
Testing shit. Don't pay attention. It's here just in case.


local function run_tests()
	print("\n🧪 Запуск тестов...")

	local copas = require("copas")
	local new_thread = copas.addthread
	local sleep = copas.sleep

	local test_channel = "test_channel_" .. tostring({}):sub(8)
	print("Channel: " .. test_channel)

	-- Тест 1: Быстрая публикация с медленным чтением
	local function test_rapid_publish()
		local total_updates = 100
		local results = {received = 0}

		print("\n📝 Тест 1: Быстрая публикация с медленным чтением")

		-- Создаем читателя с начальным offset=0
		local received_ids = {}
		new_thread(function()
			local offset = 0
			while offset < total_updates do
				local updates, new_total = longpolling:get_news(test_channel, offset, 1)
				if #updates > 0 then
					results.received = results.received + #updates
					offset = new_total
					print(string.format("   📥 Получено %d обновлений (total: %d)", #updates, new_total))

					for i = 1, #updates do
						local id = json_decode(updates[i]).id
						received_ids[id] = true
						print(string.format("      #%d. id %d", i, id))
					end
				end
			end
		end)

		-- for reader_id = 1, 3 do
		-- 	new_thread(function()
		-- 		local offset = 0
		-- 		while offset < total_updates do
		-- 			local updates, new_total = longpolling:get_news(test_channel, offset, 1)
		-- 			if #updates > 0 then
		-- 				results.received = results.received + #updates
		-- 				offset = new_total
		-- 				print(string.format("   📥 Получено %d обновлений (total: %d, reader: %d)", #updates, new_total, reader_id))
		-- 			end
		-- 		end
		-- 	end)
		-- end

		-- Быстро публикуем сообщения
		new_thread(function()
			for i = 1, total_updates do
				local total = longpolling:publish_new(test_channel, json_encode({id = i}))
				print(string.format("   📤 Опубликовано сообщение %d (total: %d)", i, total))
				sleep(0.001) -- Небольшая пауза между публикациями
			end
		end)

		-- Ждем завершения теста
		sleep(5)

		-- Проверяем результаты
		local missed = total_updates - results.received
		print(string.format("\n📊 Результаты теста 1:"))
		print(string.format("   ✓ Отправлено: %d", total_updates))
		print(string.format("   ✓ Получено: %d", results.received))
		print(string.format("   %s Пропущено: %d", missed > 0 and "⚠" or "✓", missed))

		print("Missings ids:")
		for i = 1, total_updates do
			if not received_ids[i] then
				print(string.format("   ✗ id %d", i))
			end
		end
	end

	-- Тест 2: Проверка параллельных читателей
	local function test_multiple_readers()
		print("\n📝 Тест 2: Параллельные читатели")

		local readers = 5
		local reader_results = {}

		-- Запускаем несколько читателей
		for reader_id = 1, readers do
			new_thread(function()
				local offset = 0
				reader_results[reader_id] = {received = 0}

				while reader_results[reader_id].received < 10 do
					local updates, new_total = longpolling:get_news(test_channel, offset, 1)
					if #updates > 0 then
						reader_results[reader_id].received = reader_results[reader_id].received + #updates
						offset = new_total
						print(string.format("   📥 Читатель %d получил %d обновлений (total: %d)",
							reader_id, #updates, new_total))
					end
				end
			end)
		end

		-- Публикуем сообщения
		new_thread(function()
			for i = 1, 10 do
				local total = longpolling:publish_new(test_channel, json_encode({id = i}))
				print(string.format("   📤 Опубликовано сообщение %d (total: %d)", i, total))
				sleep(0.1)
			end
		end)

		-- Ждем завершения теста
		sleep(5)

		-- Проверяем результаты
		print("\n📊 Результаты теста 2:")
		for reader_id, result in ipairs(reader_results) do
			print(string.format("   Читатель %d получил %d сообщений",
				reader_id, result.received))
		end
	end

	-- Почти одновременно публикуем данные
	-- Читатель при получении данных делает offset = offset + #updates
	-- Не должно быть таких случаев, когда (new_total - offset) > #updates или offset > new_total
	local function test_data_shifting()
		print("\n📝 Тест 3: Сдвиг данных")

		local total_updates = 2500
		local received_total = 0

		local reader_offset = 0

		local tracked_ids = {}

		new_thread(function()
			local expected_id = 0
			while received_total < total_updates do
				print("poll")
				local updates, new_total = longpolling:get_news(test_channel, reader_offset, 1)

				local offset_diff = new_total - reader_offset

				local REM = reader_offset > new_total -- REMOTE FUCKUP. e.g. remote ts 0, local ts 1000
				local LOC = offset_diff > #updates -- LOCAL FUCKUP. e.g. remote ts 100, local ts 0, but 30 updates instead of 100

				if REM or LOC then
					print(string.format("🚧 offset_diff: %d, #updates: %d", offset_diff, #updates))
					print("offset requested", reader_offset)
					print("offset remote", new_total)
					reader_offset = new_total
				else
					reader_offset = new_total
					-- reader_offset = reader_offset + #updates
				end

				received_total = received_total + #updates

				for i, update in ipairs(updates) do
					expected_id = expected_id + 1

					local id = json_decode(update).id
					local emoji = expected_id == id and "✅" or "🆘"
					print("  " .. emoji .. " " .. i .. ". " .. id .. " (expected: " .. expected_id .. ")")

					-- if expected_id ~= id then
					-- 	os.exit(1)
					-- end
				end

				sleep(0.5)

				-- print(string.format("  📊 received_total: %d, reader_offset: %d", received_total, reader_offset))
			end
		end)

		new_thread(function()
			for shift = 0, total_updates, 25 do -- 0, 25, ..., 2500
				new_thread(function()
					for publish_id = shift + 1, shift + 25 do -- 1-25, 26-50, ...
						local remote_total = longpolling:publish_new(test_channel, json_encode({id = publish_id}))
						print(string.format("📤 Опубликовано сообщение id: %d", publish_id))
					end
				end)

				sleep(1)
			end
		end)

		sleep(5)

		print(string.format("📊 Результаты теста 3: %d", received_total))
	end

	-- print("publish_new_res", longpolling:publish_new(test_channel, json_encode({test = "value"})))

	local function multiple_readers_waits()
		for reader_id = 1, 3 do
			new_thread(function()
				local updates, total = longpolling:get_news(test_channel, 0, 3)
				print("reader received update(s)", reader_id, #updates, total)
			end)
		end

		sleep(1)

		for publish_id = 1, 5 do
			new_thread(function()
				local remote_total = longpolling:publish_new(test_channel, json_encode({id = publish_id}))
				print("remote published", publish_id, remote_total)
			end)
		end
	end

	-- test_rapid_publish()
	-- test_multiple_readers()
	-- test_data_shifting()
	new_thread(multiple_readers_waits)

	print("\n✅ Тесты завершены\n")
end

-->
