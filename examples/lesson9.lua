local skynet = require "skynet"

skynet.start(function()
  skynet.error("Server start")

  local s = skynet.newservice("lesson9_service")
  skynet.call(s,"lua","open","0.0.0.0",3000)

  skynet.timeout(60*100,function () skynet.call(s,"lua","close") end)
end)
