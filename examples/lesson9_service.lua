local skynet = require "skynet"
local socketdriver = require "skynet.socketdriver"
local netpack = require "skynet.netpack"

local queue
local socket

local CMD = {}

function CMD.open(host,port)
    print("开始监听",host,port)
    local socket = socketdriver.listen(host,port)
    -- 这个函数的作用是告诉底层，开始处理socket连接消息，并且该socket对应的消息都发给当前服务进行处理
    socketdriver.start(socket)
end

function CMD.close()
    if socket then
        print("结束监听",host,port)
        socketdriver.close(socket)
        socket = nil
    end
end

local MSG = {}

function MSG.data(fd, msg, sz)
    local str = netpack.tostring(msg, sz)
    print("收到数据：",str)
    if str == "exit" then
        socketdriver.close(fd)
    else
        socketdriver.send(fd, string.pack(">s2", str))
    end
end

function MSG.more()
    local fd, msg, sz = netpack.pop(queue)
    if fd then
        -- may dispatch even the handler.message blocked
        -- If the handler.message never block, the queue should be empty, so only fork once and then exit.
        skynet.fork(dispatch_queue)
        MSG.data(fd, msg, sz)

        for fd, msg, sz in netpack.pop, queue do
            MSG.data(fd, msg, sz)
        end
    end
end

function MSG.open(fd, addr)
    print("接收到新连接fd=",fd,"addr=",addr)

    -- 这个函数的作用是告诉底层，开始处理该socket,并且该socket对应的消息都发给当前服务进行处理
    socketdriver.start(fd)
end

function MSG.close(fd)
    if fd ~= socket then
        print("连接关闭fd=",fd)
    else
        print("监听套接字关闭")
        socket = nil
    end
end

function MSG.error(fd, msg)
    if fd == socket then
        socketdriver.close(fd)
    else
        print("套接字出错fd=",fd,msg)
    end
end

function MSG.warning(fd, size)
end

skynet.register_protocol {
    name = "socket",
    id = skynet.PTYPE_SOCKET,   -- PTYPE_SOCKET = 6
    unpack = function ( msg, sz )
        return netpack.filter( queue, msg, sz)
    end,
    dispatch = function (_, _, q, type, ...)
        queue = q
        if type then
            MSG[type](...)
        end
    end
}

skynet.start(function()
    skynet.dispatch("lua",function(session, source, cmd, ...)
        local f = CMD[cmd]
        assert(f, "can't find cmd ".. (cmd or "nil"))

        if session == 0 then
            f(...)
        else
            skynet.ret(skynet.pack(f(...)))
        end
    end)
end)
