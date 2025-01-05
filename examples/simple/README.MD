# Simple Long Polling Server

This is a simplest realization of long-polling server.

All data is stored in RAM, so it will be lost after server restart.

There is no request logging or error handling features implemented,
	but you can find it in advanced app file located somewhere in this repo 😅

## API:

- `POST` example.com/any_string?data=any_data => 200 OK
- `GET ` example.com/any_string?last_id=0&timeout=60 => 200 OK {"any_data"}
