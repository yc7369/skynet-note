local skynet = require "skynet"

skynet.start(function()
  skynet.error("Server start")
        local a = skynet.getenv("a")
        print(type(a),a)
        local b = skynet.getenv("b")
        print(type(b),b)
end)
