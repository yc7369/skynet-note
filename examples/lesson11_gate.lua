local skynet = require "skynet"
local socketdriver = require "skynet.socketdriver"
local netpack = require "skynet.netpack"
local cjson = require "cjson"

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

local function sendto(fd, data)
    local str = cjson.encode(data)
    socketdriver.send(fd,string.pack(">s2",str))
end

local MSG = {}

function MSG.data(fd, msg, sz)
    local str = netpack.tostring(msg, sz)
    print("收到数据：",str)

    local data = cjson.decode(str)
    if data.cmd == "register" then
        -- 检查用户名
        if type(data.account) ~= "string" or #data.account ==0 or #data.account >16 then
            sendto(fd,{err="invalid account!"})
            return
        end

        -- 检查密码
        if type(data.password) ~= "string" or #data.password < 6 or #data.password > 16 then
            sendto(fd,{err="invalid password!"})
            return
        end

        -- 检查昵称
        if type(data.name) ~= "string" or #data.name < 1 or #data.name > 16 then
            sendto(fd,{err="invalid name!"})
            return
        end

        -- 检查age字段
        if type(data.age) ~= "number" or data.age < 10 or data.age > 100 then
            sendto(fd, {err="invalid age!"})
            return
        end

        -- 检查account是否已经存在
        local success,users = skynet.call("db","lua","select_by_key","user","account",data.account)
        if not success then
            sendto(fd,{err="db error"})
            return
        end
        if #users > 0 then
            sendto(fd, {err="user account exist!"})
            return
        end

        -- 检查name是否已经存在
        success,users = skynet.call("db","lua","select_by_key","user","name",data.name)
        if not success then
            sendto(fd,{err="db error"})
            return
        end
        if #users > 0 then
            sendto(fd, {err="user name exist!"})
            return
        end

        success = skynet.call("db","lua","insert","user",{
            account = data.account,
            password = data.password,
            name = data.name,
            age = data.age
        })
        if not success then
            sendto(fd,{err="db err!"})
            return
        end

        sendto(fd,{account=account,token=data.account.."temp"})
    elseif data.cmd == "login" then
        -- 检查用户名
        if type(data.account) ~= "string" or #data.account ==0 or #data.account >16 then
            sendto(fd,{err="invalid account!"})
            return
        end

        -- 检查密码
        if type(data.password) ~= "string" or #data.password < 6 or #data.password > 16 then
            sendto(fd,{err="invalid password!"})
            return
        end

        -- 检查account是否已经存在
        local success,users = skynet.call("db","lua","select_by_key","user","account",data.account)
        if not success then
            sendto(fd,{err="db error"})
            return
        end
        local user = users[1]
        if not user then
            sendto(fd, {err="user account not exist!"})
            return
        end

        if user.password ~= data.password then
            sendto(fd, {err="invalid password!"})
            return
        end

        sendto(fd,{account=data.account,token=data.account.."temp"})
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
