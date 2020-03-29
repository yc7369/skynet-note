local skynet = require "skynet"

local function print_t(t)
    local str = "{"
    for k,v in pairs(t) do
        if type(v) == "table" then
            v = print_t(v)
        end
        str = str .. k .. "=" .. v .. ","
    end
    str = str .. "}"
    return str
end

skynet.start(function()
  skynet.error("Server start")

    local s = skynet.newservice("lesson11_db")

    skynet.call(s, "lua", "open", {
        host = "222.73.139.48",
        port = 3306,
        database = "test",
        user = "root",
        password = "system"
    })

    local gate = skynet.newservice("lesson11_gate")
    skynet.call(gate,"lua","open","0.0.0.0",3000)
end)
