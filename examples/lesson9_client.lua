package.cpath = "luaclib/?.so"
package.path = "lualib/?.lua;examples/?.lua"

local socket = require "client.socket"

local fd = assert(socket.connect("127.0.0.1", 3000))

local function send_package(fd, pack)
    local package = string.pack(">s2", pack)
    socket.send(fd, package)
end

local function unpack_package(text)
    local size = #text
    if size < 2 then
        return nil, text
    end
    local s = text:byte(1) * 256 + text:byte(2)
    if size < s+2 then
        return nil, text
    end

    return text:sub(3,2+s), text:sub(3+s)
end

local function recv_package(last)
    local result
    result, last = unpack_package(last)
    if result then
        return result, last
    end
    local r = socket.recv(fd)
    if not r then
        return nil, last
    end
    if r == "" then
        error "Server closed"
    end
    return unpack_package(last .. r)
end

local session = 0

local function send_request(str)
    print("send msg:",str)
    send_package(fd, str)
end

local last = ""

local function dispatch_package()
    while true do
        local v
        v, last = recv_package(last)
        if not v then
            break
        end
        print("recv msg;",v)
    end
end

send_request("handshake")
while true do
    dispatch_package()
    local cmd = socket.readstdin()
    if cmd then
        if cmd == "quit" then
            socket.close(fd)
            break
        else
            send_request(cmd)
        end
    else
        socket.usleep(100)
    end
end
