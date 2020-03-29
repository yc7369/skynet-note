local skynet = require "skynet"

skynet.start(function()
  skynet.error("Server start")

  local s = skynet.newservice("lesson8_service",1,2,3,4)

  print("skynet.call",skynet.call(s,"lua","add",1,2))
  print("skynet.call",skynet.call(s,"lua","add",2,5))

  print("skynet.send",skynet.send(s,"lua","print","haha"))
  print("skynet.send",skynet.send(s,"lua","print1","haha"))
end)
