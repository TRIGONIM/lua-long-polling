-- Just a launcher for the long-polling server

package.path = string.format("%s;%s", "./lua/?.lua", package.path)
package.path = string.format("%s;%s", "./lua/?/init.lua", package.path)

io.stdout:setvbuf("no") -- faster stdout without buffering

require("long-polling.app")
