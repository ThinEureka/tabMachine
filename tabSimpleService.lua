-- author cs
-- email 04nycs@gmail.com
-- https://github.com/ThinEureka/tabMachine
-- created on Oct 18 2022
local tabSocket = require("tabMachine.tabSocket")
local tabSimpleService = nil

tabSimpleService = _{

    tabName = "tabSimpleService",

    s1 = function(c, socket, serviceId, serviceParams)
        local ip, port = socket:getpeername()
        c._nickName = serviceId .. "[" .. ip .. ":" .. port .. "]"
        c._ip = ip
        c._port = port
        c._socket = socket
        c._serviceId = serviceId
        c._tabCmdHandler = c:call(serviceParams.cmdHandler(serviceParams.debugCmd), "cmdHandler")
    end,

    s2 = function(c)
        c._tabSocket = c:call(tabSocket, "socket", nil, 15)
        c._tabSocket:acceptSocket(c._socket)
        c:call(c._tabSocket:tabInState(tabSocket.STATE.CONNECTED), "s3")
        c:call(c._tabSocket:tabPullSegments(c._tabCmdHandler.decodeSegment, function(msg)
            c._tabCmdHandler:onNewSegment(msg)
        end), "pullMsgs")
    end,

    s4 = function(c)
        -- for current implementation we only provide once service per tab lifetime and 
        -- further optimization will be done only when necessarcy
        -- c:stop("pullMsgs")
        c:stop()
        c._isDead = true
    end,

    -- event & inner
    event = g_t.empty_event,

    inner = {
        tabSocket = function(c)
            return c._tabSocket
        end,

        tabCmdHandler = function(c)
            return c._tabCmdHandler
        end,

        service = function(c)
            return c
        end,
    },

    sendRpc = function(c, ...)
        return c._tabCmdHandler:sendRpc(...)
    end,

    sendRequest = function(c, ...)
        return c._tabCmdHandler:sendRequest(...)
    end,

}

--------------------------------------------------------------------------------
-- public:
function tabSimpleService:isDead()
    return self._isDead
end

function tabSimpleService:reconnect(socket)
    return false
end

function tabSimpleService:getTabSocket()
    return self._tabSocket
end

function tabSimpleService:getIp()
    return self._ip
end

function tabSimpleService:getPort()
    return self._port
end

function tabSimpleService:getSocketName()
    return self._ip, self._port
end

function tabSimpleService:getServiceId()
    return self._serviceId
end

return tabSimpleService

