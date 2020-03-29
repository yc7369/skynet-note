local skynet = require "skynet"

local p1,p2,p3,p4 = ...
print("newservice params:",p1,p2,p3,p4)

local CMD = {}

function CMD.add(a,b)
    return a+b
end

function CMD.print(o)
    skynet.error(o)
end

skynet.start(function()
    skynet.dispatch("lua",function(session, source, cmd, ...)
        print("session=",session,"source=",source,"cmd=",cmd,"params=",...)

        local f = CMD[cmd]
        assert(f, "can't find cmd ".. (cmd or "nil"))

        if session == 0 then
            f(...)
        else
            skynet.ret(skynet.pack(f(...)))
        end
    end)

end)
