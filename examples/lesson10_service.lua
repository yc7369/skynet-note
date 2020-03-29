local skynet = require "skynet"
local mysql = require "skynet.db.mysql"

local db

local function ping()
    while true do
        if db then
            db:query("select 1;")
        end
        skynet.sleep(3600*1000)
    end
end

local CMD = {}

function CMD.open(conf)
    db = mysql.connect(conf)
    skynet.fork(ping)
end

function CMD.close()
    if db then
        db:disconnect()
        db = nil
    end
end

function CMD.insert(tablename, row)
    local columns = {}
    local values = {}
    for k, v in pairs(row) do
        table.insert(columns, k)
        if type(v) == "string" then
            v = mysql.quote_sql_str(v)
        end
        table.insert(values,v)
    end
    values = table.concat(values,",")
    columns = table.concat(columns, ",")

    local sql = string.format("insert into %s(%s) values(%s);", tablename, columns, values)

    local result = db:query(sql)
    if result.errno then
        skynet.error(result.err)
        return false
    end
    return true
end

function CMD.delete(tablename, key, value)
    local sql = string.format("delete from %s where %s = %s;", tablename, key, mysql.quote_sql_str(tostring(value)))

    local result = db:query(sql)
    if result.errno then
        skynet.error(result.err)
        return false
    end
    return true
end

function CMD.update(tablename, key, value, row)
    local t = {}
    for k, v in pairs(row) do
        if type(v) == "string" then
            v = mysql.quote_sql_str(v)
        end
        table.insert(t, k.."="..v)
    end
    local setvalues = table.concat(t, ",")
    local sql = string.format("update %s set %s where %s ='%s';", tablename, setvalues, key, value)
    local result = db:query(sql)
    if result.errno then
        skynet.error(result.err)
        return false
    end
    return true
end

function CMD.select_by_key(tablename, key, value)
    local sql = string.format("select * from %s where %s = '%s';", tablename, key, value)
    local result = db:query(sql)
    if result.errno then
        skynet.error(result.err)
        return false
    end
    return true,result
end

function CMD.select_all(tablename)
    local sql = string.format("select * from %s",tablename)
    local result = db:query(sql)
    if result.errno then
        skynet.error(result.err)
        return false
    end

    return true,result
end

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
