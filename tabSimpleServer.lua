--author cs
--email 04nycs@gmail.com
--https://github.com/ThinEureka/tabMachine
--created on Oct 18 2022 

local socket = require "socket"

local tabMachine = require("tabMachine.tabMachine")
local tabSimpleServer = nil

tabSimpleServer = _{
    s1 = function(c, isUsingIpV6)
        c._isUsingIpV6 = isUsingIpV6
    end,

    s2 = function(c)
        c:suspend("s3")
    end,

    s3 = function(c, tabService, serviceParams, port, address, timeout)
        c._server = c._isUsingIpV6 and socket.tcp6() or socket.tcp()
        c._port = port
        c._address = address
        c._timeout = timeout 

		c._server:setoption("reuseaddr", true)
        c._server:bind(c._address, c._port)
		--c._server:setoption("reuseport", true)
        c._server:listen()
        c._server:settimeout(c._timeout)
        c._serviceGroup = c:call(tabSimpleServer.tabServiceGroup(tabService, serviceParams), "serviceGroup")
    end,

    s4 = function(c)
        c.socket = nil
        c:call(tabSimpleServer.tabAccept(c._server) >> "socket", "s5")
    end,

    s6 = function(c)
        c._serviceGroup:acceptSocket(c.socket)
        c:start("s4")
    end,


    final = function(c)
        c._server:close()
    end,

    event = g_t.empty_event,

    inner = {
        service = function(c, ip, port)
            local targetService = nil
            c:forEachService(function(service)
                if service:getIp() == ip and service:getPort() == port then
                    targetService = service
                    return true
                end
            end)
            return targetService
        end,

        serviceCount = function(c)
            return c._serviceGroup:getServiceCount()
        end,
    },

    --public:
    startService = function(c, tabService, serviceParams, port, address, timeout)
        address = address or "*"
        timeout = timeout or 0.0001
        c:resume("s3", tabService, serviceParams, port, address, timeout)
    end,

    forEachService = function(c, callback)
        return c._serviceGroup:forEachService(callback)
    end,
}

tabSimpleServer.tabServiceGroup = _{
    s1 = function(c, tabService, serviceParams)
        c.tabService = tabService
        c.serviceParams = serviceParams
        c._nextServiceId = 1
    end,

    event = {
        [tabMachine.event_context_stop] = function(c, p, name, target)
            if name == "service" then 
                c:upwardNotify("tabSimpleServer.serviceStopped", target)
            end
        end
    },

    --internal:
    acceptSocket = function(c, socket)
        local ip, port = socket:getsockname()
        local service = c:_("service", ip, port)
        if service ~= nil then
            if service:reconnect(socket) then
                return
            else
                service:stop()
                service = nil
            end
        end

        service = c:call(c.tabService, "service", nil, socket, c._nextServiceId, c.serviceParams)
        c._nextServiceId = c._nextServiceId + 1
        c:registerLifeTimeListener("service", c)
        c:upwardNotify("tabSimpleServer.serviceStarted", service)
    end,

    --public:
    getServiceCount = function(c)
        local count = 0
        c:forEachSub(function()
            count = count + 1
        end)
        return count
    end,

    forEachService = function(c, callback)
        c:forEachSub(function(sub)
            if sub.__name == "service" then
                return callback(sub)
            else
                return false
            end
        end)
    end,

}

tabSimpleServer.tabAccept = _{
    tabName = "tabSimpleServer:tabAccept",

    s1 = function(c, socket)
        c.socket = socket
    end,

    s1_update = function(c)
        local client = c.socket:accept()
        if client ~= nil then
            c:output(client)
            c:stop()
        end
    end,
}

return tabSimpleServer

