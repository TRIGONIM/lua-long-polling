# Long Polling Server

A simple [long-polling](https://javascript.info/long-polling) server (and client) written in Lua.

![demo image](https://file.def.pm/wq86G74W.svg)

_source: javascript.info_

## Use cases:

- In environments where it is not possible to create a web server (e.g. in a Garry's Mod game), but getting "webhooks" is necessary
- As a single point of collecting webhooks, for example to get updates from all your Telegram bots with just one request. To do this, make `https://api.telegram.org/bot$TOKEN/setWebhook?url=https://your.app/SomeS3cretP@th?this_key=and_value&will_be=merged_with_updates_sent_by_telegram&botname=some_id`.
- Simple chat-like services implementations

## Project structure

```
│ .
├── examples
│   ├── advanced
│   │   ├── client.lua
│   │   ├── docker-compose.yml
│   │   ├── Dockerfile
│   │   ├── README.MD
│   │   └── server.lua
│   └── simple
│       ├── README.MD
│       └── server.lua
├── lua
│   └── long-polling
│       ├── dataproviders
│       │   ├── localtable.lua
│       │   └── redis.lua
│       ├── misc
│       │   ├── pubsub.lua
│       │   └── redis-safe.lua
│       └── init.lua
├── LICENSE
└── README.MD

```

## Documentation:

Not ready yet. I am lazy. **But if you create an issue** so I can see that someone needs it, I will create code documentation instantly ⚡.

But you can look at the examples below to understand what is what. Also, in the examples there are README files with a lot of useful information.

## Application examples:

- 🔥 [advanced](/examples/advanced). Source code of real-working application
- [simple](/examples/simple). Simple to understand example of using the library

## TODO:

- Move out `redis-safe` into separate repo
- Split the library and application examples into separate repos. Need for the ability to do `require("kupol.server")` and `require("kupol.client")`
- Create the `mysql` dataprovider, using [luasocket-mysql](https://github.com/TRIGONIM/luasocket-mysql) driver
- Also create the `filesystem` dataprovider

