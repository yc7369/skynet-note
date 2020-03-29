local skynet = require "skynet"
require "skynet.manager"

skynet.register_protocol {
  name = "text",
  id = skynet.PTYPE_TEXT,
  pack = skynet.packstring,
  unpack = skynet.tostring,
  dispatch = function(_, address, msg)
    print(string.format(":%08x(%.2f): %s", address, skynet.time(), msg))
  end
}

skynet.start(function()
  skynet.error("Server start")

  local servera = skynet.launch("a", "123")

  skynet.send(servera, skynet.PTYPE_TEXT, "456")
end)
