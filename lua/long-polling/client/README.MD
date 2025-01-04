# Lua Long Polling Client Example

> 🇺🇸 English version not ready for now (I am lazy and don't want to translate it). You can use https://www.deepl.com/ to translate text on your own.

Работает как в чистом Lua, так и на Garry's Mod сервере.

На чистом Lua требует copas (а он luasocket), lua-requests-async (он тоже требует copas) и cjson.

## Использование

**В гмоде** закинуть по любому пути, потом получить доступ к библиотеке через `kupol = include("path/to/client.lua")`. Автоматически в глобальное пространство ничего не добавляется.

В чистом Lua можно использовать `kupol = require("long-polling.client")`.

## Пример

```lua
local kupol  = require("long-polling.client") -- also works in Garry's Mod with include()
local Client = kupol.new("https://poll.def.pm/SomeSecretWord")


-- Получение данных
Client:subscribe(function(upd, last_id)
	print("LP сервер за все время принял " .. tostring(last_id) .. " обновлений")
	print("Последнее обновление: " .. kupol.json_encode(upd))
end, nil, 30) -- 30 это timeout в секундах.
-- nil – это последний id, который был получен (offset)


-- Отправка данных
kupol.thread_new(function()
	for i = 1, 10 do
		local ok, err = Client:publish({any = "value", counter = i})
		print(ok and "published" or "pub failed: " .. tostring(err))
		kupol.thread_pause(.05)
	end
end)
```
