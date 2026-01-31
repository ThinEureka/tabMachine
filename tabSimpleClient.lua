-- author cs
-- email 04nycs@gmail.com
-- https://github.com/ThinEureka/tabMachine
-- created on Oct 18 2022
local tabSocket = require("tabMachine.tabSocket")
local tabSimpleClient = nil

tabSimpleClient = _{
    tabName = "tabSimpleClient",

    s1 = function(c, params)
        c._nickName = "client"
        c._tabSocket = c:call(tabSocket, "socket", nil, 15)
        c._tabCmdHandler = c:call(params.cmdHandler(params.debugCmd), "cmdHandler")
    end,

    s2 = function(c)
        c:suspend("s3")
    end,

    s3 = function(c, ip, port, timeout, tabErrHandler)
        c:call(c._tabSocket:connect(ip, port, timeout), "s4", {"isSuccess", "err"})
    end,

    s5 = function(c)
        if c.isSuccess then
            c:call(tabSimpleClient.tabWorking(), "s6")
        else
            c:start("s2")
        end
    end,

    s7 = function(c)
        c._tabSocket:disconnect()
        c:start("s2")
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

    -- public:
    connect = function(c, ip, port, timeout, tabErrHandler)
        c:resume("s3", ip, port, timeout, tabErrHandler)
        return c:tabProxy("s4", true)
    end,

    getTabSocket = function(c)
        return c._tabSocket
    end,

    tabInWorking = function(c, stopHostWhenStop)
        local sub = c:getSub("s6")
        if sub == nil then
            return nil
        else
            return sub:tabProxy(nil, stopHostWhenStop)
        end
    end,

    sendRpc = function(c, ...)
        return c._tabCmdHandler:sendRpc(...)
    end,

    sendRequest = function(c, ...)
        return c._tabCmdHandler:sendRequest(...)
    end,
}

tabSimpleClient.tabWorking = _{
    s1 = function(c)
        c:call(c:_("tabSocket"):tabInState(tabSocket.STATE.CONNECTED), "s2")
        local tabCmdHandler = c:_("tabCmdHandler")
        c:call(c:_("tabSocket"):tabPullSegments(tabCmdHandler.decodeSegment, function(msg)
            tabCmdHandler:onNewSegment(msg)
        end), "pullMsg")
    end,

    s3 = function(c)
        c:stop()
    end,

    event = g_t.empty_event,
}

return tabSimpleClient

