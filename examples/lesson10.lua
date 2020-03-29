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

    local s = skynet.newservice("lesson10_service")

    skynet.call(s, "lua", "open", {
        host = "222.73.139.48",
        port = 3306,
        database = "test",
        user = "root",
        password = "system"
    })

    -- 插入数据
    skynet.call(s, "lua", "insert", "user", {name="zhang",age=10})
    skynet.call(s, "lua", "insert", "user", {name="wang",age=20})
    skynet.call(s, "lua", "insert", "user", {name="liu",age=30})

    -- 删除数据
    print(skynet.call(s, "lua", "delete", "user", "name", "zhang"))

    -- 修改数据
    print(skynet.call(s, "lua", "update", "user", "name", "wang", {age=25}))

    -- 条件查询
    local success, users = skynet.call(s, "lua", "select_by_key", "user", "age", 30)
    if success then
        print("条件查询结果")
        print(print_t(users))
    end

    -- 查询所有数据
    success, users = skynet.call(s, "lua", "select_all", "user")
    if success then
        print("查询所有结果")
        print(print_t(users))
    end
end)
